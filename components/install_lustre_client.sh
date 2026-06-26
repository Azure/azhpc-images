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
LUSTRE_DKMS_CONFIGURE_EXTRA="--with-o2ib=no"
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
# ko2iblnd in the expected module list, so override both configure and artifacts.
MAKE="sh autogen.sh && ./configure --with-linux=$kernel_source_dir --with-linux-obj=$kernel_source_dir --disable-server --disable-quilt --disable-dependency-tracking --disable-doc --disable-utils --disable-iokit --disable-snmp --disable-tests --enable-quota --with-kmp-moddir=updates --with-o2ib=no --enable-gss && make"
BUILT_MODULE_NAME[11]="ksocklnd"
BUILT_MODULE_LOCATION[11]="lnet/klnds/socklnd"
DEST_MODULE_LOCATION[11]="/updates/kernel/net/lustre"
BUILT_MODULE_NAME[12]="libcfs"
BUILT_MODULE_LOCATION[12]="libcfs/libcfs"
DEST_MODULE_LOCATION[12]="/updates/kernel/net/lustre"
BUILT_MODULE_NAME[13]="lnet"
BUILT_MODULE_LOCATION[13]="lnet/lnet"
DEST_MODULE_LOCATION[13]="/updates/kernel/net/lustre"
BUILT_MODULE_NAME[14]="lnet_selftest"
BUILT_MODULE_LOCATION[14]="lnet/selftest"
DEST_MODULE_LOCATION[14]="/updates/kernel/net/lustre"
BUILT_MODULE_NAME[15]="ptlrpc_gss"
BUILT_MODULE_LOCATION[15]="lustre/ptlrpc/gss"
DEST_MODULE_LOCATION[15]="/updates/kernel/fs/lustre"
EOF
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

    LUSTRE_PACKAGE="amlfs-lustre-client-dkms-${LUSTRE_VERSION}"
    if [[ $UBUNTU_VERSION == 22.04 ]]; then
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
    dnf install -y --disableexcludes=main --refresh "${LUSTRE_PACKAGES[@]}"
    check_dkms_status lustre-client
    LUSTRE_VERSION=${LUSTRE_VERSION_UNDERSCORE}
fi

write_component_version "LUSTRE" ${LUSTRE_VERSION}
