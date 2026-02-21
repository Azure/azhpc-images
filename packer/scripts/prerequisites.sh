#!/bin/bash
set -euo pipefail

# =============================================================================
# Prerequisites: LTS kernel, package updates, GB200 config
# =============================================================================
# This script runs BEFORE the azhpc-images install.sh
# It handles:
#   - Kernel setup (LTS or GB200 nvidia kernel)
#   - Base package updates
#   - GB200-specific configurations (PARTUUID, GRUB args, nouveau blacklist)
#
# Environment variables:
#   OS_FAMILY        - OS family (ubuntu, alma, azurelinux)
#   DISTRO_VERSION   - Distro version (22.04, 24.04, etc.)
#   GPU_SKU          - GPU SKU (a100, h100, gb200, mi300x) - required
#   GB200_PARTUUID   - Disk PARTUUID for GB200 builds (None for non-GB200)
#   AKS_HOST_IMAGE   - Building AKS host image (true/false)
# =============================================================================

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
    systemctl stop unattended-upgrades.service 2>/dev/null || true
    systemctl disable unattended-upgrades.service 2>/dev/null || true
    pkill -9 unattended-upgr 2>/dev/null || true
    
    # Final wait for any remaining locks
    sleep 5
}

####
# @Brief        : Configure GB200-specific disk PARTUUID
# @Param        : partuuid - The PARTUUID to set
# @RetVal       : 0 on success
####
configure_gb200_partuuid() {
    local partuuid="${1:-None}"
    local aks_host="${AKS_HOST_IMAGE:-false}"

    if [[ "${GPU_SKU,,}" != "gb200" || "${partuuid}" == "None" || -z "${partuuid}" ]]; then
        echo "##[section]Skipping PARTUUID configuration (not GB200 or PARTUUID not specified)"
        return 0
    fi
    
    if [[ "${aks_host}" == "true" ]]; then
        echo "##[section]Skipping PARTUUID configuration for AKS host image"
        return 0
    fi
    
    echo "##[section]Configuring GB200 disk PARTUUID: ${partuuid}"
    
    # Get boot device info
    local boot_device=$(df -h /boot/efi | awk 'NR==2 {print $1}')
    local disk="${boot_device%p[0-9]*}"
    local partition="${boot_device##*p}"
    
    echo "Boot device: ${boot_device}"
    echo "Disk: ${disk}, Partition: ${partition}"
    
    # Set PARTUUID using sgdisk
    sgdisk --partition-guid="${partition}:${partuuid}" "${disk}"
    
    # Update EFI boot entry
    efibootmgr -b 0001 -B || true
    efibootmgr -c -d "${disk}" -p "${partition}" -L "Ubuntu" -l '\EFI\ubuntu\shimaa64.efi'
    
    echo "GB200 PARTUUID configuration complete"
}

####
# @Brief        : Install GB200-specific NVIDIA kernel for Ubuntu 24.04
# @RetVal       : 0 on success
####
install_ubuntu_gb200_kernel() {
    echo "##[section]Installing GB200 NVIDIA kernel for Ubuntu 24.04"
    
    export NEEDRESTART_MODE=a
    
    apt-get update
    apt-get install -y linux-azure-nvidia
    apt-mark hold linux-azure-nvidia
    
    # Purge non-nvidia kernels
    apt-get purge -y linux-azure linux-image-azure

    # Remove non-nvidia kernel packages
    local packages_to_remove
    packages_to_remove=$(dpkg -l | awk '/linux-(azure|image|cloud-tools|headers|modules|tools)-6\.14/ && $2 !~ /nvidia/ {print $2}' || true)
    if [[ -n "${packages_to_remove}" ]]; then
        apt-get purge -y ${packages_to_remove}
    fi
    
    apt autoremove -y
    apt-get upgrade -y
    
    # Keep only the latest installed linux-azure-nvidia kernel
    local target_kernel
    target_kernel=$(dpkg -l | awk '/linux-image-[0-9].*-azure-nvidia/ {print $2}' | sed 's/linux-image-//g' | sort -V | tail -n1)
    
    for prefix in vmlinuz initrd.img config System.map; do
        for f in /boot/${prefix}-*-azure*; do
            [[ $f == *${target_kernel}* ]] || rm -f "$f"
        done
    done
    
    # Configure GRUB for GB200
    # Add GB200-specific kernel parameters
    sed -i '/^GRUB_CMDLINE_LINUX=/ s/"$/ iommu.passthrough=1 irqchip.gicv3_nolpi=y arm_smmu_v3.disable_msipolling=1 init_on_alloc=0 net.ifnames=0"/' /etc/default/grub.d/50-cloudimg-settings.cfg
    
    # Blacklist nouveau driver
    echo 'blacklist nouveau' >> /etc/modprobe.d/blacklist.conf
    
    update-grub
    
    echo "GB200 NVIDIA kernel installation complete"
}

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
    sed -i "s/#\$nrconf{restart} = 'i';/\$nrconf{restart} = 'a';/g" /etc/needrestart/needrestart.conf || true
    sed -i "s/#\$nrconf{kernelhints} = -1;/\$nrconf{kernelhints} = -1;/g" /etc/needrestart/needrestart.conf || true
    
    export NEEDRESTART_MODE=a
    
    # Configure GRUB for saved default
    sed -i 's/GRUB_DEFAULT=0/GRUB_DEFAULT=saved\nGRUB_SAVEDEFAULT=true/' /etc/default/grub
    
    case "${version}" in
        24.04)
            apt update
            apt install -y linux-azure-lts-24.04 linux-modules-extra-azure-6.8
            apt-mark hold linux-azure-lts-24.04
            
            # Purge non-LTS kernels
            apt-get purge -y \
                linux-azure linux-image-azure \
                "linux-image-6.11*" "linux-image-6.14*" \
                "linux-azure-6.11*" "linux-azure-6.14*" \
                "linux-cloud-tools-6.11*" "linux-cloud-tools-6.14*" \
                "linux-headers-6.11*" "linux-headers-6.14*" \
                "linux-modules-6.11*" "linux-modules-6.14*" \
                "linux-tools-6.11*" "linux-tools-6.14*"
            
            apt autoremove -y
            apt upgrade -y
            
            # Set default kernel
            local kernel_version=$(dpkg-query -l | grep linux-image-azure-lts-24.04 | awk '{print $3}' | sed -E 's/^([0-9]+\.[0-9]+\.[0-9]+-[0-9]+)\..*/\1/')
            grub-set-default "Advanced options for Ubuntu>Ubuntu, with Linux ${kernel_version}-azure"
            update-grub
            ;;
            
        22.04)
            apt update
            apt install -y linux-azure-lts-22.04
            apt-mark hold linux-azure-lts-22.04
            
            # Purge non-LTS kernels
            apt-get purge -y \
                linux-azure linux-image-azure \
                "linux-image-6.*" "linux-azure-6.*" \
                "linux-cloud-tools-6.*" "linux-headers-6.*" \
                "linux-modules-6.*" "linux-tools-6.*"
            
            apt upgrade -y
            
            # Set default kernel
            local kernel_version=$(dpkg-query -l | grep linux-azure-lts-22.04 | awk '{print $3}' | awk -F. 'OFS="." {print $1,$2,$3,$4}' | sed 's/\(.*\)\./\1-/')
            grub-set-default "Advanced options for Ubuntu>Ubuntu, with Linux ${kernel_version}-azure"
            update-grub
            ;;
            
        *)
            echo "##[warning]No LTS kernel configuration for Ubuntu ${version}"
            apt update && apt upgrade -y
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
    local os_family=$1

    if ! command -v dnf &> /dev/null; then
        echo "##[warning]dnf package manager not found. Cannot update packages for ${os_family}."
        return 0
    fi
    
    echo "##[section]Updating packages for ${os_family}"
    
    dnf update -y --refresh
    dnf install -y git
    
    if [[ "${os_family}" == "azurelinux"* ]]; then
        echo "Configuring Azure Linux specific settings..."
        sed -i 's/lockdown=integrity /lockdown=integrity ipv6.disable=1/' /etc/default/grub
        grub2-mkconfig -o /boot/grub2/grub.cfg
        sed -i '/umask 007/d' /etc/profile
    fi
    
    echo "Package update complete"
}

# =============================================================================
# Main execution
# =============================================================================

echo "========================================="
echo "Prerequisites: Kernel, Package Updates"
echo "OS: ${OS_FAMILY:-unknown} ${DISTRO_VERSION:-unknown}"
echo "GPU SKU: ${GPU_SKU:?GPU_SKU is required}"
echo "AKS Host Image: ${AKS_HOST_IMAGE:-false}"
echo "=========================================="

# Configure GB200 PARTUUID if specified
configure_gb200_partuuid "${GB200_PARTUUID:-None}"

# Wait for apt lock and cloud-init before any package operations (Ubuntu)
if [[ "${OS_FAMILY}" == "ubuntu" ]]; then
    wait_for_apt
fi

# OS-specific prerequisites
case "${OS_FAMILY}" in
    ubuntu)
        install_ubuntu_lts_kernel "${DISTRO_VERSION}"
        ;;
    *)
        update_rhel_packages "${OS_FAMILY}"
        ;;
esac

echo "=========================================="
echo "Prerequisites Complete"
echo "Kernel: $(uname -r)"
echo "=========================================="
