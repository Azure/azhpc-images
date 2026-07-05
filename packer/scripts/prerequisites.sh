#!/bin/bash
set -euox pipefail

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
#   TARGET_NODE_TYPE - Target image variant (regular/aks_host_image/baremetal_image)
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
    local target_variant="${TARGET_NODE_TYPE:-azure_vm_regular}"

    # Skip PARTUUID configuration for VR200, which is inconsistent with legacy image build now but both are placeholder
    if [[ "${GPU_SKU}" != "GB200" || "${partuuid}" == "None" || -z "${partuuid}" ]]; then
        echo "##[section]Skipping PARTUUID configuration (not GB200 or PARTUUID not specified)"
        return 0
    fi
    
    if [[ "${target_variant}" != "azure_vm_regular" ]]; then
        echo "##[section]Skipping PARTUUID configuration for ${target_variant}"
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
# @Brief        : Install NVIDIA Grace-aware kernel for Ubuntu 24.04
# @RetVal       : 0 on success
####
install_ubuntu_nvidia_kernel() {
    echo "##[section]Installing NVIDIA Grace-aware kernel for Ubuntu 24.04"
    
    export NEEDRESTART_MODE=a
    
    apt-get update

    # In-place refresh: ensure DKMS builds OFED modules in dependency order
    # (iser/isert/srp need mlnx-ofed-kernel built first, but DKMS autoinstall
    # processes modules alphabetically and would otherwise fail).
    if [[ -d /var/lib/dkms/mlnx-ofed-kernel ]]; then
        configure_ofed_dkms_build_depends
    fi
    local ubuntu_codename="noble"
    kernel_ver="${KERNEL_VERSION:-6.8}"
    if [ "$USE_UBUNTU_PPA_REPO" == "True" ]; then
        echo "##[section] PPA kernel repo is enabled, installing PPA kernel version: $UBUNTU_PPA_KERNEL_PATCH_VERSION"
        sudo add-apt-repository -y "$UBUNTU_PPA_REPO_NAME"
        install_from_ppa_repo "linux-azure-nvidia-${kernel_ver}" "$UBUNTU_PPA_KERNEL_PATCH_VERSION" "$UBUNTU_PPA_REPO_NAME"
    elif [ "$USE_UBUNTU_PROPOSED_SUITE" == "True" ]; then
        install_from_proposed_suite "${ubuntu_codename}" linux-azure-nvidia-${kernel_ver}
    else
        sudo apt-get install linux-azure-nvidia-"$kernel_ver" -y
    fi

    # Purge non-nvidia kernels
    apt-get purge -y linux-azure linux-image-azure

    # Remove non-nvidia kernel packages
    local packages_to_remove
    packages_to_remove=$(dpkg -l | awk '/linux-(azure|image|cloud-tools|headers|modules|tools)-6\.(14|17)/ && $2 !~ /nvidia/ {print $2}' || true)
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

    # Add GB200-specific kernel parameters
    if [[ "${TARGET_NODE_TYPE:-azure_vm_regular}" != baremetal_* ]]; then
        sed -i '/^GRUB_CMDLINE_LINUX=/ s/"$/ iommu.passthrough=1 irqchip.gicv3_nolpi=y arm_smmu_v3.disable_msipolling=1 init_on_alloc=0 net.ifnames=0"/' /etc/default/grub.d/50-cloudimg-settings.cfg
    else
        echo "FW dma fix"
        sudo sed -i 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="efi=disable_early_pci_dma"/g' /etc/default/grub
        if [[ "$NVLINK_RACKSCALE" == "true" && "${TARGET_NODE_TYPE:-azure_vm_regular}" == baremetal_1p && "${KERNEL_VERSION}" == "6.17" ]]; then
            cat > /etc/default/grub.d/config-acs.cfg <<'EOF'
# Generated by /usr/sbin/rdma_topo do not change. ACS settings for RDMA GPU Direct
GRUB_CMDLINE_LINUX="$GRUB_CMDLINE_LINUX pci=config_acs=\"xx111x0@0008:00:00.0;xx110x1@0008:02:00.0;xx101x1@0008:02:03.0;xx111x0@0009:00:00.0;xx110x1@0009:02:00.0;xx101x1@0009:02:01.0;xx111x0@0018:00:00.0;xx110x1@0018:02:00.0;xx101x1@0018:02:03.0;xx111x0@0019:00:00.0;xx110x1@0019:02:00.0;xx101x1@0019:02:01.0\""
EOF
            chmod 644 /etc/default/grub.d/config-acs.cfg
        fi
    fi

    # Blacklist nouveau driver
    echo 'blacklist nouveau' >> /etc/modprobe.d/blacklist.conf
    
    update-grub
    
    echo "NVIDIA kernel installation complete"
}

####
# @Brief        : Add OFED DKMS dependency overrides under /etc/dkms
# @Param        : None
# @RetVal       : 0 on success
####
configure_ofed_dkms_build_depends() {
    [[ -d /var/lib/dkms/mlnx-ofed-kernel ]] || return 0
    mkdir -p /etc/dkms

    cat > /etc/dkms/iser.conf <<'EOF'
BUILD_DEPENDS="mlnx-ofed-kernel"
EOF
    cat > /etc/dkms/isert.conf <<'EOF'
BUILD_DEPENDS="mlnx-ofed-kernel"
EOF
    cat > /etc/dkms/srp.conf <<'EOF'
BUILD_DEPENDS="mlnx-ofed-kernel"
EOF
}

####
# @Brief        : Ensure Ubuntu proposed suite exists and keep it at low priority
# @Desc         : Keeps proposed available but pinned low; explicit installs use -t <codename>-proposed
# @Param        : codename - Ubuntu codename (noble, jammy, ...)
# @RetVal       : 0 on success
####
configure_ubuntu_proposed_suite() {
    local codename=$1
    local pref_file=/etc/apt/preferences.d/99-ubuntu-proposed-low-priority.pref
    local has_proposed=false
    
    # Find any Deb822 .sources file that contains this codename
    local deb822_file
    deb822_file="/etc/apt/sources.list.d/ubuntu.sources"
    
    if [[ -f "${deb822_file}" ]]; then
        if grep -q "^Suites:.*${codename}-proposed" "${deb822_file}"; then
            has_proposed=true
        fi
        if [[ "${has_proposed}" != "true" ]]; then
            echo "##[section]Adding ${codename}-proposed in Deb822 format (${deb822_file})"
            sudo sed -i "/^Suites:.*${codename}[^-]/ s/$/ ${codename}-proposed/" "${deb822_file}"
            # Avoid duplicates
            sudo sed -i "s/ ${codename}-proposed ${codename}-proposed/ ${codename}-proposed/g" "${deb822_file}"
        fi
    else
        if [[ -f "/etc/apt/sources.list.d/${codename}-proposed.list" ]]; then
            has_proposed=true
        fi

        if [[ "${has_proposed}" != "true" ]]; then
            echo "##[section]Adding ${codename}-proposed in old list format"
            local mirror
            mirror=$(grep "^deb http" /etc/apt/sources.list 2>/dev/null | grep " ${codename} " | head -1 | awk '{print $2}')
            if [[ -z "${mirror}" ]]; then
                echo "##[warning]Could not detect mirror for ${codename}, skipping proposed suite"
                return 0
            fi
            sudo tee /etc/apt/sources.list.d/${codename}-proposed.list > /dev/null <<EOF
deb ${mirror} ${codename}-proposed main restricted universe multiverse
EOF
        fi
    fi
    
    echo "##[section]Ensuring ${codename}-proposed is low priority (pin file: ${pref_file})"
    # Keep proposed enabled but low priority unless explicitly targeted via -t
    sudo tee "${pref_file}" > /dev/null <<EOF
Package: *
Pin: release a=${codename}-proposed
Pin-Priority: 100
EOF
    sudo chmod 644 "${pref_file}"
    sudo apt-get -y update
}

####
# @Brief        : Install a package version explicitly from a Launchpad PPA
# @Desc         : Creates a temporary package pin to the PPA origin, installs the exact
#                 version, then removes the temporary pin file.
# @Param        : package_name    - Package name
# @Param        : package_version - Package version string
# @Param        : ppa_repo_name   - PPA repo in format ppa:<owner>/<name>
# @RetVal       : 0 on success
####
install_from_ppa_repo() {
    local package_name=$1
    local package_version=$2
    local ppa_repo_name=$3
    local ppa_ref="${ppa_repo_name#ppa:}"
    local ppa_origin="LP-PPA-${ppa_ref//\//-}"

    echo "##[section]Installing ${package_name}=${package_version} from ${ppa_repo_name} (origin: ${ppa_origin})"
    sudo apt-get install -y "${package_name}=${package_version}"

    echo "##[section]Installed ${package_name}=${package_version} from ${ppa_origin}, removing temporary pin"
    configure_ppa_low_priority "$ppa_repo_name"
}

####
# @Brief        : Keep Launchpad PPA at low priority
# @Desc         : Prevents accidental package upgrades from PPA unless explicitly requested
# @RetVal       : 0 on success
####
configure_ppa_low_priority() {
    local ppa_repo_name=$1
    local ppa_ref="${ppa_repo_name#ppa:}"
    local ppa_origin="LP-PPA-${ppa_ref//\//-}"

    local pref_file=/etc/apt/preferences.d/99-ubuntu-ppa-low-priority.pref

    echo "##[section]Configuring default low priority for Launchpad PPA packages: ${pref_file}"
    sudo tee "${pref_file}" > /dev/null <<EOF
Package: *
Pin: release o=${ppa_origin}
Pin-Priority: 100
EOF
    sudo chmod 644 "${pref_file}"
    sudo apt-get -y update
}

####
# @Brief        : Install packages from Ubuntu proposed suite
# @Desc         : Ensures proposed exists and is low-priority by default,
#                 then installs with "-t <codename>-proposed" for explicit source selection.
#                 due to APT's default lower priority for proposed.
# @Param        : codename  - Ubuntu codename (noble, jammy, ...)
# @Param        : ...       - Package names to install
# @RetVal       : 0 on success
####
install_from_proposed_suite() {
    local codename=$1
    shift
    local packages=("$@")

    configure_ubuntu_proposed_suite "${codename}"
    echo "##[section]Installing from ${codename}-proposed: ${packages[*]}"
    apt-get install -y -t "${codename}-proposed" "${packages[@]}"
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
    if [[ "${NVLINK_RACKSCALE}" == "true" ]]; then
        install_ubuntu_nvidia_kernel
        return $?
    fi
    
    echo "##[section]Installing LTS kernel for Ubuntu ${version}"
    
    # Configure needrestart to prevent interactive prompts
    sed -i "s/#\$nrconf{restart} = 'i';/\$nrconf{restart} = 'a';/g" /etc/needrestart/needrestart.conf || true
    sed -i "s/#\$nrconf{kernelhints} = -1;/\$nrconf{kernelhints} = -1;/g" /etc/needrestart/needrestart.conf || true
    
    export NEEDRESTART_MODE=a

    case "${version}" in
        24.04)
            apt update

            local kernel_ver="${KERNEL_VERSION:-6.8}"
            echo "##[section]Installing kernel ${kernel_ver} for Ubuntu 24.04"

            # Build list of kernel minor versions to purge (everything except the target)
            local all_kernel_minors="6.8 6.11 6.14 6.17"
            local purge_patterns=""
            for minor in $all_kernel_minors; do
                if [[ "$minor" != "$kernel_ver" ]]; then
                    purge_patterns+=" \"linux-image-${minor}*\" \"linux-azure-${minor}*\" \"linux-cloud-tools-${minor}*\" \"linux-headers-${minor}*\" \"linux-modules-${minor}*\" \"linux-tools-${minor}*\""
                fi
            done
            if [[ -d /var/lib/dkms/mlnx-ofed-kernel ]]; then
                configure_ofed_dkms_build_depends
            fi

            local ubuntu_codename="noble"

            # Install the versioned kernel meta-package
            if [ "$USE_UBUNTU_PROPOSED_SUITE" == "True" ]; then
                local pkgs=("linux-azure-${kernel_ver}")
                if apt-cache show linux-modules-extra-azure-${kernel_ver} &>/dev/null; then
                    pkgs+=("linux-modules-extra-azure-${kernel_ver}")
                fi
                install_from_proposed_suite "${ubuntu_codename}" "${pkgs[@]}"
            else
                apt install -y linux-azure-${kernel_ver}
                if apt-cache show linux-modules-extra-azure-${kernel_ver} &>/dev/null; then
                    apt install -y linux-modules-extra-azure-${kernel_ver}
                fi
            fi
            
            # Purge non-target kernels
            eval apt-get purge -y linux-azure linux-image-azure $purge_patterns || true
            # Also purge the LTS meta-package if we're not using it
            if [[ "$kernel_ver" != "6.8" ]]; then
                apt-get purge -y linux-azure-lts-24.04 || true
            fi

            apt autoremove -y
            apt upgrade -y

            ;;
            
        22.04)
            apt update
            local ubuntu_codename="jammy"
            if [ "$USE_UBUNTU_PROPOSED_SUITE" == "True" ]; then
                install_from_proposed_suite "${ubuntu_codename}" linux-azure-lts-22.04
            else
                apt install -y linux-azure-lts-22.04
            fi        
            # Purge non-LTS kernels
            apt-get purge -y \
                linux-azure linux-image-azure \
                "linux-image-6.*" "linux-azure-6.*" \
                "linux-cloud-tools-6.*" "linux-headers-6.*" \
                "linux-modules-6.*" "linux-tools-6.*"
            
            apt upgrade -y

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
    
    # Workaround for tdnf repo_gpgcheck bug (https://github.com/vmware/tdnf/issues/471)
    # tdnf-plugin-repogpgcheck fails when GPG keys aren't in the root keyring,
    # causing repo sync failures. Disable the plugin entirely until the bug is fixed.
    if [[ "${os_family}" == "azurelinux"* ]]; then
        sed -i 's/^enabled.*=.*1/enabled=0/' /etc/tdnf/pluginconf.d/tdnfrepogpgcheck.conf 2>/dev/null || true
    fi

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
echo "Target Image Variant: ${TARGET_NODE_TYPE:-azure_vm_regular}"
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
