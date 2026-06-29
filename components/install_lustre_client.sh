#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

# Set Lustre version
lustre_metadata=$(get_component_config "lustre")
LUSTRE_VERSION=$(jq -r '.version' <<< $lustre_metadata)

configure_lustre_dkms_no_o2ib() {
    local config_file=$1

    mkdir -p "$(dirname "${config_file}")"
    cat > "${config_file}" <<'EOF'
# Azure clients do not have IB line of sight to Lustre servers, so use TCP LNet.
# EL DKMS captures stdout from sourcing this file into DKMS_CONFIG_OPTS.
echo --with-o2ib=no
EOF
}

install_cuda_dkms_3_4_1_for_jammy_amd() {
    local dkms_url=https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/dkms_3.4.1-1ubuntu1_all.deb
    local dkms_sha256=16ce508e74cbe8426fe19c1c56de5ea6e9f3dbe05d85ba5cbf5a8a271d34c2be
    local dkms_deb=$(basename "${dkms_url}")
    local current_version

    [[ "${DISTRIBUTION}" == "ubuntu22.04" && "${GPU:-}" == "AMD" ]] || return 0

    current_version=$(dkms --version 2>/dev/null | sed -n 's/^dkms-\(.*\)$/\1/p' || true)
    if [[ -n "${current_version}" ]] && dpkg --compare-versions "${current_version}" ge 3.4.1; then
        return 0
    fi

    rm -f "./${dkms_deb}"
    download_and_verify "${dkms_url}" "${dkms_sha256}"
    apt-get install -y "./${dkms_deb}"
    rm -f "./${dkms_deb}"
}

configure_lustre_dkms_skip_artifact() {
    local module=$1
    local module_version=$2
    local slot=$3
    local description=$4
    local dkms_conf=/etc/dkms/${module}-${module_version}.conf

    mkdir -p "$(dirname "${dkms_conf}")"
    cat >> "${dkms_conf}" <<EOF
# ${description}
BUILD_EXCLUSIVE_KERNEL[${slot}]="^$"
EOF
}

configure_lustre_dkms_lu20071_patch() {
    local module=lustre-client
    local module_version=$1
    local kernel_header=/lib/modules/$(uname -r)/build/include/linux/timer.h
    local dkms_conf=/etc/dkms/${module}-${module_version}.conf
    local patch_file=${COMPONENT_DIR}/patches/lustre-client-lu-20071-timer-container-of.patch
    local patch_dir=/etc/dkms/${module}/patches

    # RHEL 9.8 kernels 5.14.0-687+ dropped from_timer(); LU-20071 rewires
    # Lustre's cfs_from_timer wrapper to timer_container_of.
    [[ -f "${kernel_header}" ]] || return 0
    grep -q 'from_timer' "${kernel_header}" && return 0

    mkdir -p "${patch_dir}"
    cp "${patch_file}" "${patch_dir}/lu-20071-timer-container-of.patch"
    mkdir -p "$(dirname "${dkms_conf}")"
    cat >> "${dkms_conf}" <<'EOF'
PATCH[0]="lu-20071-timer-container-of.patch"
EOF
}

configure_lustre_dkms_no_o2ib_with_tr_workaround() {
    local config_file=$1

    mkdir -p "$(dirname "${config_file}")"
    cat > "${config_file}" <<'EOF'
# Azure clients do not have IB line of sight to Lustre servers, so use TCP LNet.
# TODO: Drop the tr() workaround after AMLFS publishes Lustre DKMS with LU-19792.
OPTS=$(printf '%s\n' "${OPTS:-}" | sed -E 's#(^|[[:space:]])--with-o2ib=[^[:space:]]+##g')
LUSTRE_DKMS_CONFIGURE_EXTRA="--with-o2ib=no"
tr() {
    if [[ $# -eq 2 && "$1" == " " && ( "$2" == "\\n" || "$2" == "\\\\n" ) ]]; then
        command tr ' ' '\n'
    else
        command tr "$@"
    fi
}
EOF
}

configure_legacy_lustre_dkms_no_o2ib() {
    local module=lustre-client-modules
    local module_version=$1
    local dkms_conf=/etc/dkms/${module}-${module_version}.conf

    mkdir -p /etc/dkms
    cat > "${dkms_conf}" <<'EOF'
# Azure clients do not have IB line of sight to Lustre servers, so use TCP LNet.
# Ubuntu 22.04's published AMLFS Lustre DKMS package has a static dkms.conf with
# ko2iblnd in record 11, so configure without o2ib and skip only that artifact.
MAKE="sh autogen.sh && ./configure --with-linux=$kernel_source_dir --with-linux-obj=$kernel_source_dir --disable-server --disable-quilt --disable-dependency-tracking --disable-doc --disable-utils --disable-iokit --disable-snmp --disable-tests --enable-quota --with-kmp-moddir=updates --with-o2ib=no --enable-gss && make"
EOF
    configure_lustre_dkms_skip_artifact "${module}" "${module_version}" 11 \
        "Ubuntu 22.04 ko2iblnd is record 11; --with-o2ib=no intentionally skips it."
}

if [[ $DISTRIBUTION == *"ubuntu"* ]]; then
    source /etc/lsb-release
    UBUNTU_VERSION=$(cat /etc/os-release | grep VERSION_ID | cut -d= -f2 | cut -d\" -f2)

    if [ $UBUNTU_VERSION == 24.04 ]; then
        SIGNED_BY="/usr/share/keyrings/microsoft-prod.gpg"
    elif [ $UBUNTU_VERSION == 22.04 ]; then
        SIGNED_BY="/etc/apt/trusted.gpg.d/microsoft-prod.gpg"
    fi
    echo "deb [arch=$ARCHITECTURE_DISTRO signed-by=$SIGNED_BY] https://packages.microsoft.com/repos/amlfs-${DISTRIB_CODENAME}/ ${DISTRIB_CODENAME} main" | tee /etc/apt/sources.list.d/amlfs.list
    # Enable these lines if the MS PMC repo was not already setup.
    #curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
    #cp ./microsoft.gpg /etc/apt/trusted.gpg.d/
    apt-get update

    LUSTRE_CLIENT_PACKAGE="lustre-client-${LUSTRE_VERSION}"
    LUSTRE_PACKAGE="amlfs-lustre-client-dkms-${LUSTRE_VERSION}"
    # Install the userspace package first because it owns /etc/sysconfig/dkms-lustre.
    # Pre-creating that conffile makes noninteractive dpkg stop at a prompt.
    apt-get install -y "${LUSTRE_CLIENT_PACKAGE}"
    if [[ $UBUNTU_VERSION == 22.04 ]]; then
        install_cuda_dkms_3_4_1_for_jammy_amd
        configure_legacy_lustre_dkms_no_o2ib "${LUSTRE_VERSION}"
    else
        configure_lustre_dkms_no_o2ib_with_tr_workaround /etc/sysconfig/dkms-lustre
    fi
    apt-get install -y "${LUSTRE_PACKAGE}"
    check_dkms_status lustre-client-modules
else
    # RHEL-family: AlmaLinux, Rocky Linux, RHEL, etc.
    LUSTRE_VERSION_UNDERSCORE=${LUSTRE_VERSION//-/_}
    OS_MAJOR_VERSION=$(sed -n 's/^VERSION_ID="\([0-9]\+\).*/\1/p' /etc/os-release)
    REPO_PATH=/etc/yum.repos.d/amlfs.repo

    rpm --import https://packages.microsoft.com/keys/microsoft.asc

    echo -e "[amlfs]" > ${REPO_PATH}
    echo -e "name=Azure Lustre Packages" >> ${REPO_PATH}
    echo -e "baseurl=https://packages.microsoft.com/yumrepos/amlfs-el${OS_MAJOR_VERSION}" >> ${REPO_PATH}
    echo -e "enabled=1" >> ${REPO_PATH}
    echo -e "gpgcheck=1" >> ${REPO_PATH}
    echo -e "gpgkey=https://packages.microsoft.com/keys/microsoft.asc" >> ${REPO_PATH}

    LUSTRE_PACKAGES=(
        "lustre-client-dkms-${LUSTRE_VERSION_UNDERSCORE}"
        "lustre-client-${LUSTRE_VERSION_UNDERSCORE}-devel"
    )
    configure_lustre_dkms_no_o2ib /etc/sysconfig/lustre
    configure_lustre_dkms_skip_artifact lustre-client "${LUSTRE_VERSION_UNDERSCORE}" 3 \
        "EL ko2iblnd is record 3; --with-o2ib=no intentionally skips it."
    configure_lustre_dkms_lu20071_patch "${LUSTRE_VERSION_UNDERSCORE}"
    dnf install -y --disableexcludes=main --refresh "${LUSTRE_PACKAGES[@]}"
    check_dkms_status lustre-client
    LUSTRE_VERSION=${LUSTRE_VERSION_UNDERSCORE}
fi

write_component_version "LUSTRE" ${LUSTRE_VERSION}
