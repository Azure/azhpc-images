#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

doca_metadata=$(get_component_config "doca")
DOCA_VERSION=$(jq -r '.version' <<< $doca_metadata)
DOCA_SHA256=$(jq -r '.sha256' <<< $doca_metadata)
DOCA_URL=$(jq -r '.url' <<< $doca_metadata)
DOCA_FILE=$(basename ${DOCA_URL})

if [[ "$DISTRIBUTION" == *"ubuntu"* && "$SKU" == "GB200" ]]; then
    DOCA_FILE=$TOP_DIR/internal_bits/doca-host_${DOCA_VERSION}_arm64.deb
else
    download_and_verify $DOCA_URL $DOCA_SHA256
fi

if [[ $DISTRIBUTION == *"ubuntu"* ]]; then
    dpkg -i $DOCA_FILE
    apt-get update
    if [[ "$ARCH" == "aarch64" ]]; then
        # Unset ARCH set by set_properties.sh. 
        # ARCH == uname -m (aarch64)
        # messes up some doca-ofed package post install scripts,
        # since kernel source dir only has arch/arm64
        unset ARCH
    fi
    apt-get -y install doca-ofed
elif [[ $DISTRIBUTION == almalinux* ]]; then
    rpm -i $DOCA_FILE
    dnf clean all
    
    # Install DOCA extras for compatibility
    VERSION_ID=$(. /etc/os-release;echo $VERSION_ID)
    KERNEL=( $(rpm -q kernel | sed 's/kernel\-//g' | sed 's/x86_64/noarch/'))
    wget --retry-connrefused --tries=3 --waitretry=5 https://repo.almalinux.org/almalinux/$VERSION_ID/BaseOS/x86_64/os/Packages/kernel-abi-stablelists-${KERNEL}.rpm
    rpm -i kernel-abi-stablelists-${KERNEL}.rpm
    dnf install -y doca-extra
    
    /opt/mellanox/doca/tools/doca-kernel-support
    FINAL_REPO_FILE=$(find /tmp/DOCA.*/ -name 'doca-kernel-repo-*.rpm' -printf '%T@ %p\n' | sort -n | tail -1 | cut -d' ' -f2-)
    rpm -i $FINAL_REPO_FILE
    dnf -y install doca-ofed-userspace
    dnf -y install doca-ofed
elif [[ $DISTRIBUTION == "azurelinux3.0" ]]; then
    rpm -i $DOCA_FILE
    dnf clean all
    dnf install -y doca-extra
    /opt/mellanox/doca/tools/doca-kernel-support
    dnf install -y doca-ofed-userspace
    dnf -y install doca-ofed
fi

write_component_version "DOCA" $DOCA_VERSION
OFED_VERSION=$(ofed_info | sed -n '1,1p' | awk -F'-' 'OFS="-" {print $3,$4}' | tr -d ':')
write_component_version "OFED" $OFED_VERSION

/etc/init.d/openibd restart
/etc/init.d/openibd status
error_code=$?
if [ ${error_code} -ne 0 ]
then
    echo "OpenIBD not loaded correctly!"
    exit ${error_code}
fi
