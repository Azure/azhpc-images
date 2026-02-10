#!/bin/bash
set -euo pipefail

# =============================================================================
# Prerequisites: mdatp, LTS kernel, package updates, GB200 config
# =============================================================================
# This script runs BEFORE the azhpc-images install.sh
# It handles:
#   - Microsoft Defender for Endpoint (mdatp) installation
#   - Kernel setup (LTS or GB200 nvidia kernel)
#   - Base package updates
#   - GB200-specific configurations (PARTUUID, GRUB args, nouveau blacklist)
#
# Environment variables:
#   OS_FAMILY        - OS family (ubuntu, alma, azurelinux)
#   OS_VERSION       - OS version (22.04, 24.04, etc.)
#   GPU_SKU          - GPU SKU (a100, h100, gb200, mi300x) - required
#   INSTALL_MDATP    - Install Microsoft Defender (true/false)
#   GB200_PARTUUID   - Disk PARTUUID for GB200 builds (None for non-GB200)
#   AKS_HOST_IMAGE   - Building AKS host image (true/false)
# =============================================================================

# Disable package manager progress bars for cleaner Packer output
OS_FAMILY="${OS_FAMILY:-ubuntu}"
if [[ "${OS_FAMILY}" == "ubuntu" ]]; then
    export DEBIAN_FRONTEND=noninteractive
    export APT_LISTCHANGES_FRONTEND=none
    # Disable all apt/dpkg progress indicators that use carriage returns
    cat > /etc/apt/apt.conf.d/99-disable-progress << 'EOF'
Dpkg::Progress-Fancy "0";
Dpkg::Progress "0";
APT::Color "0";
APT::Acquire::Progress "0";
Acquire::Progress::Fancy "0";
Acquire::Progress "0";
Dpkg::Use-Pty "0";
quiet "2";
EOF
    # Prevent apt cache staleness during long builds
    cat > /etc/apt/apt.conf.d/99-packer-build << 'EOF'
Acquire::Check-Valid-Until "false";
Acquire::AllowReleaseInfoChange "true";
APT::Get::AllowUnauthenticated "false";
EOF
elif [[ "${OS_FAMILY}" == "alma" ]]; then
    # Disable dnf progress bar
    echo "color_list_installed_older=" >> /etc/dnf/dnf.conf 2>/dev/null || true
elif [[ "${OS_FAMILY}" == "azurelinux" ]]; then
    # Azure Linux uses tdnf - no special progress handling needed
    # tdnf output is already clean for Packer
    :
fi

echo "========================================="
echo "Prerequisites: Kernel, MDATP, Package Updates"
echo "OS: ${OS_FAMILY:-unknown} ${OS_VERSION:-unknown}"
echo "GPU SKU: ${GPU_SKU:?GPU_SKU is required}"
echo "Install mdatp: ${INSTALL_MDATP:-true}"
echo "AKS Host Image: ${AKS_HOST_IMAGE:-false}"
echo "=========================================="

####
# @Brief        : Wait for apt lock to be released and cloud-init to complete
# @Param        : None
# @RetVal       : 0 on success
####
wait_for_apt() {
    echo "Waiting for cloud-init to complete..."
    cloud-init status --wait || true
    
    echo "Waiting for apt lock to be released..."
    local max_attempts=30
    local attempt=0
    while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || \
          fuser /var/lib/apt/lists/lock >/dev/null 2>&1 || \
          fuser /var/cache/apt/archives/lock >/dev/null 2>&1; do
        attempt=$((attempt + 1))
        if [[ $attempt -ge $max_attempts ]]; then
            echo "##[warning]Timeout waiting for apt lock after ${max_attempts} attempts"
            break
        fi
        echo "Apt is locked, waiting... (attempt ${attempt}/${max_attempts})"
        sleep 10
    done
    
    # Kill any running unattended-upgrades
    sudo systemctl stop unattended-upgrades.service 2>/dev/null || true
    sudo systemctl disable unattended-upgrades.service 2>/dev/null || true
    sudo pkill -9 unattended-upgr 2>/dev/null || true
    
    # Final wait for any remaining locks
    sleep 5
}

####
# @Brief        : Install Microsoft Defender for Endpoint (mdatp)
# @Param        : None (uses MDATP_ONBOARDING_SCRIPT environment variable)
# @RetVal       : 0 on success
####
install_mdatp() {
    local install_mdatp="${INSTALL_MDATP:-true}"
    
    if [[ "${install_mdatp}" != "true" ]]; then
        echo "##[section]Skipping mdatp installation (INSTALL_MDATP=${install_mdatp})"
        return 0
    fi
    
    echo "##[section]Installing Microsoft Defender for Endpoint (mdatp)"
    
    # Check if onboarding script was provided via file provisioner
    local onboarding_script="/tmp/mdatp/MicrosoftDefenderATPOnboardingLinuxServer.py"
    
    if [[ ! -f "${onboarding_script}" ]]; then
        echo "##[warning]mdatp onboarding script not found at ${onboarding_script}"
        echo "##[warning]Skipping mdatp installation - onboarding package must be provisioned"
        return 0
    fi
    
    # Ensure curl is available (wget may not be installed on minimal images)
    if ! command -v curl &>/dev/null; then
        echo "Installing curl..."
        if command -v dnf &>/dev/null; then
            sudo dnf install -y curl
        elif command -v yum &>/dev/null; then
            sudo yum install -y curl
        elif command -v apt-get &>/dev/null; then
            sudo apt-get update && sudo apt-get install -y curl
        elif command -v tdnf &>/dev/null; then
            sudo tdnf install -y curl
        fi
    fi
    
    # Download MDE installer using curl (more portable than wget)
    curl -sL https://raw.githubusercontent.com/microsoft/mdatp-xplat/refs/heads/master/linux/installation/mde_installer.sh -o /tmp/mde_installer.sh
    chmod +x /tmp/mde_installer.sh
    
    # Install and onboard mdatp
    sudo /tmp/mde_installer.sh --install --onboard "${onboarding_script}" --channel prod
    
    # Disable potentially unwanted application detection (reduces noise)
    sudo mdatp threat policy set --type potentially_unwanted_application --action off
    
    # Cleanup
    rm -f "${onboarding_script}" /tmp/mde_installer.sh
    
    echo "mdatp installation complete"
}

####
# @Brief        : Configure GB200-specific disk PARTUUID
# @Param        : partuuid - The PARTUUID to set
# @RetVal       : 0 on success
####
configure_gb200_partuuid() {
    local partuuid="${1:-None}"
    local aks_host="${AKS_HOST_IMAGE:-false}"
    
    if [[ "${partuuid}" == "None" || -z "${partuuid}" ]]; then
        echo "##[section]Skipping PARTUUID configuration (not GB200 or PARTUUID not specified)"
        return 0
    fi
    
    if [[ "${aks_host}" == "true" ]]; then
        echo "##[section]Skipping PARTUUID configuration for AKS host image"
        return 0
    fi
    
    echo "##[section]Configuring GB200 disk PARTUUID: ${partuuid}"
    
    # Get boot device info
    local boot_device
    boot_device=$(df -h /boot/efi | awk 'NR==2 {print $1}')
    local disk="${boot_device%p[0-9]*}"
    local partition="${boot_device##*p}"
    
    echo "Boot device: ${boot_device}"
    echo "Disk: ${disk}, Partition: ${partition}"
    
    # Set PARTUUID using sgdisk
    sudo sgdisk --partition-guid="${partition}:${partuuid}" "${disk}"
    
    # Update EFI boot entry
    sudo efibootmgr -b 0001 -B || true
    sudo efibootmgr -c -d "${disk}" -p "${partition}" -L "Ubuntu" -l '\EFI\ubuntu\shimaa64.efi'
    
    echo "GB200 PARTUUID configuration complete"
}

####
# @Brief        : Install GB200-specific NVIDIA kernel for Ubuntu 24.04
# @RetVal       : 0 on success
####
install_ubuntu_gb200_kernel() {
    echo "##[section]Installing GB200 NVIDIA kernel for Ubuntu 24.04"
    
    export DEBIAN_FRONTEND=noninteractive
    export NEEDRESTART_MODE=a
    
    sudo apt-get update
    sudo apt-get install -y linux-azure-nvidia
    sudo apt-mark hold linux-azure-nvidia
    
    # Purge non-nvidia kernels
    sudo DEBIAN_FRONTEND=noninteractive apt-get purge -y linux-azure linux-image-azure || true
    
    # Remove non-nvidia kernel packages
    local packages_to_remove
    packages_to_remove=$(dpkg -l | awk '/linux-(azure|image|cloud-tools|headers|modules|tools)-6\.14/ && $2 !~ /nvidia/ {print $2}' || true)
    if [[ -n "${packages_to_remove}" ]]; then
        sudo DEBIAN_FRONTEND=noninteractive apt-get purge -y ${packages_to_remove} || true
    fi
    
    sudo apt autoremove -y
    sudo apt-get upgrade -y
    
    # Keep only the latest installed linux-azure-nvidia kernel
    local target_kernel
    target_kernel=$(dpkg -l | awk '/linux-image-[0-9].*-azure-nvidia/ {print $2}' | sed 's/linux-image-//g' | sort -V | tail -n1)
    
    for prefix in vmlinuz initrd.img config System.map; do
        for f in /boot/${prefix}-*-azure*; do
            [[ $f == *${target_kernel}* ]] || sudo rm -f "$f"
        done
    done
    
    # Configure GRUB for GB200
    # Add GB200-specific kernel parameters
    sudo sed -i '/^GRUB_CMDLINE_LINUX=/ s/"$/ iommu.passthrough=1 irqchip.gicv3_nolpi=y arm_smmu_v3.disable_msipolling=1 init_on_alloc=0 net.ifnames=0"/' /etc/default/grub.d/50-cloudimg-settings.cfg
    
    # Blacklist nouveau driver
    echo 'blacklist nouveau' | sudo tee -a /etc/modprobe.d/blacklist.conf
    
    sudo update-grub
    
    echo "GB200 NVIDIA kernel installation complete"
}

# Determine OS type from environment or detect it
if [[ -z "${OS_FAMILY:-}" ]]; then
    source /etc/os-release
    case "$ID" in
        ubuntu) OS_FAMILY="ubuntu"; OS_VERSION="${VERSION_ID}" ;;
        almalinux) OS_FAMILY="alma"; OS_VERSION="${VERSION_ID}" ;;
        azurelinux|mariner) OS_FAMILY="azurelinux"; OS_VERSION="${VERSION_ID}" ;;
        *) echo "Unknown OS: $ID"; exit 1 ;;
    esac
fi

# Combine OS family and version for matching
OS_TYPE="${OS_FAMILY}${OS_VERSION}"

####
# @Brief        : Install LTS kernel for Ubuntu (non-GB200)
# @Param        : OS version (e.g., 24.04, 22.04)
# @RetVal       : 0 on success
####
install_ubuntu_lts_kernel() {
    local version=$1
    local gpu_sku="${GPU_SKU}"
    
    # GB200 uses a special nvidia kernel, not LTS
    if [[ "${gpu_sku,,}" == "gb200" ]]; then
        install_ubuntu_gb200_kernel
        return $?
    fi
    
    echo "##[section]Installing LTS kernel for Ubuntu ${version}"
    
    # Configure needrestart to prevent interactive prompts
    sudo sed -i "s/#\$nrconf{restart} = 'i';/\$nrconf{restart} = 'a';/g" /etc/needrestart/needrestart.conf || true
    sudo sed -i "s/#\$nrconf{kernelhints} = -1;/\$nrconf{kernelhints} = -1;/g" /etc/needrestart/needrestart.conf || true
    
    export DEBIAN_FRONTEND=noninteractive
    export NEEDRESTART_MODE=a
    
    # Configure GRUB for saved default
    sudo sed -i 's/GRUB_DEFAULT=0/GRUB_DEFAULT=saved\nGRUB_SAVEDEFAULT=true/' /etc/default/grub
    
    case "${version}" in
        24.04)
            sudo apt update
            sudo apt install -y linux-azure-lts-24.04 linux-modules-extra-azure-6.8
            sudo apt-mark hold linux-azure-lts-24.04
            
            # Purge non-LTS kernels
            sudo DEBIAN_FRONTEND=noninteractive apt-get purge -y \
                linux-azure linux-image-azure \
                "linux-image-6.11*" "linux-image-6.14*" \
                "linux-azure-6.11*" "linux-azure-6.14*" \
                "linux-cloud-tools-6.11*" "linux-cloud-tools-6.14*" \
                "linux-headers-6.11*" "linux-headers-6.14*" \
                "linux-modules-6.11*" "linux-modules-6.14*" \
                "linux-tools-6.11*" "linux-tools-6.14*" || true
            
            sudo apt autoremove -y
            sudo apt upgrade -y
            
            # Set default kernel
            local kernel_version
            kernel_version=$(dpkg-query -l | grep linux-image-azure-lts-24.04 | awk '{print $3}' | sed -E 's/^([0-9]+\.[0-9]+\.[0-9]+-[0-9]+)\..*/\1/')
            sudo grub-set-default "Advanced options for Ubuntu>Ubuntu, with Linux ${kernel_version}-azure"
            sudo update-grub
            ;;
            
        22.04)
            sudo apt update
            sudo apt install -y linux-azure-lts-22.04
            sudo apt-mark hold linux-azure-lts-22.04
            
            # Purge non-LTS kernels
            sudo DEBIAN_FRONTEND=noninteractive apt-get purge -y \
                linux-azure linux-image-azure \
                "linux-image-6.*" "linux-azure-6.*" \
                "linux-cloud-tools-6.*" "linux-headers-6.*" \
                "linux-modules-6.*" "linux-tools-6.*" || true
            
            sudo apt upgrade -y
            
            # Set default kernel
            local kernel_version
            kernel_version=$(dpkg-query -l | grep linux-azure-lts-22.04 | awk '{print $3}' | awk -F. 'OFS="." {print $1,$2,$3,$4}' | sed 's/\(.*\)\./\1-/')
            sudo grub-set-default "Advanced options for Ubuntu>Ubuntu, with Linux ${kernel_version}-azure"
            sudo update-grub
            ;;
            
        *)
            echo "##[warning]No LTS kernel configuration for Ubuntu ${version}"
            sudo apt update && sudo apt upgrade -y
            ;;
    esac
    
    echo "Ubuntu LTS kernel installation complete"
}

####
# @Brief        : Update packages for RHEL-based distros (Alma, Azure Linux)
# @Param        : OS type (alma, azurelinux)
# @RetVal       : 0 on success
####
update_rhel_packages() {
    local os_type=$1
    
    echo "##[section]Updating packages for ${os_type}"
    
    sudo dnf update -y --refresh
    sudo dnf install -y git
    
    if [[ "${os_type}" == "azurelinux"* ]]; then
        echo "Configuring Azure Linux specific settings..."
        sudo sed -i 's/lockdown=integrity /lockdown=integrity ipv6.disable=1/' /etc/default/grub || true
        sudo grub2-mkconfig -o /boot/grub2/grub.cfg || true
        sudo sed -i '/umask 007/d' /etc/profile || true
    fi
    
    echo "Package update complete"
}

# =============================================================================
# Main execution
# =============================================================================

echo "Starting prerequisites installation for ${OS_TYPE}"

# Install Microsoft Defender for Endpoint (mdatp)
install_mdatp

# Configure GB200 PARTUUID if specified
configure_gb200_partuuid "${GB200_PARTUUID:-None}"

# Wait for apt lock and cloud-init before any package operations (Ubuntu)
if [[ "${OS_FAMILY}" == "ubuntu" ]]; then
    wait_for_apt
fi

# OS-specific prerequisites
case "${OS_FAMILY}" in
    ubuntu)
        install_ubuntu_lts_kernel "${OS_VERSION}"
        ;;
    alma|almalinux)
        update_rhel_packages "alma"
        ;;
    azurelinux|mariner)
        update_rhel_packages "azurelinux"
        ;;
    *)
        echo "##[warning]Unknown OS family: ${OS_FAMILY}"
        ;;
esac

echo "=========================================="
echo "Prerequisites Complete"
echo "Kernel: $(uname -r)"
echo "=========================================="
