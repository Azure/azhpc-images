#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

# Set Lustre version
lustre_metadata=$(get_component_config "lustre")
LUSTRE_VERSION=$(jq -r '.version' <<< $lustre_metadata)

if [[ $DISTRIBUTION == *"ubuntu"* ]]; then
    source /etc/lsb-release
    UBUNTU_VERSION=$(cat /etc/os-release | grep VERSION_ID | cut -d= -f2 | cut -d\" -f2)

    # if [ $UBUNTU_VERSION == 24.04 ]; then
    #     SIGNED_BY="/usr/share/keyrings/microsoft-prod.gpg"
    # elif [ $UBUNTU_VERSION == 22.04 ]; then
    #     SIGNED_BY="/etc/apt/trusted.gpg.d/microsoft-prod.gpg"
    # fi
    # echo "deb [arch=amd64 signed-by=$SIGNED_BY] https://packages.microsoft.com/repos/amlfs-${DISTRIB_CODENAME}/ ${DISTRIB_CODENAME} main" | sudo tee /etc/apt/sources.list.d/amlfs.list
    # # Enable these lines if the MS PMC repo was not already setup.
    # #curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
    # #cp ./microsoft.gpg /etc/apt/trusted.gpg.d/
    # apt-get update
    # apt-get install -y amlfs-lustre-client-${LUSTRE_VERSION}=$(uname -r)
    # apt-mark hold amlfs-lustre-client-${LUSTRE_VERSION}

    # temporary workaround to build AMLFS kmod from source, until we have AMLFS team publish DKMS packages usable on day-1 of new kernel module release
    lustre_branch="arsdragonfly/dkms-$LUSTRE_VERSION"
    git clone --branch ${lustre_branch} https://github.com/arsdragonfly/amlFilesystem-lustre.git
    pushd amlFilesystem-lustre
    apt update
    if [ $UBUNTU_VERSION == 24.04 ]; then
        apt install -y module-assistant libselinux-dev libsnmp-dev mpi-default-dev quilt libssl-dev swig
    elif [ $UBUNTU_VERSION == 22.04 ]; then
        apt install -y module-assistant dpatch libselinux-dev libsnmp-dev mpi-default-dev quilt libssl-dev swig
    fi
    # Protect ../tests from accidental deletion/move by make dkms-debs
    # We use a bind mount because mv cannot move a mount point
    # TEST_DIR is defined in utils/set_properties.sh
    if [ -d "$TEST_DIR" ]; then
        if mountpoint -q "$TEST_DIR"; then
            umount "$TEST_DIR"
        fi
        mount --bind "$TEST_DIR" "$TEST_DIR"
    fi

    set +e
    sh ./autogen.sh
    ./configure --with-linux=/usr/src/linux-headers-$(uname -r) --disable-server --disable-ldiskfs --disable-zfs --disable-snmp --enable-quota
    make dkms-debs
    MAKE_RC=$?
    set -e

    if [ -d "$TEST_DIR" ]; then
        if mountpoint -q "$TEST_DIR"; then
            umount "$TEST_DIR"
        fi
    fi

    if [ $MAKE_RC -ne 0 ]; then
        exit $MAKE_RC
    fi

    apt install -y ./debs/lustre-*.deb
    popd
    rm -rf amlFilesystem-lustre
    LUSTRE_VERSION=$(dpkg-query -W -f='${Version}\n' lustre-client-utils | cut -d~ -f1)
elif [[ $DISTRIBUTION == almalinux* ]]; then
    ALMA_LUSTRE_VERSION=${LUSTRE_VERSION//-/_}
    OS_MAJOR_VERSION=$(sed -n 's/^VERSION_ID="\([0-9]\+\).*/\1/p' /etc/os-release)
    DISTRIB_CODENAME=el$OS_MAJOR_VERSION
    REPO_PATH=/etc/yum.repos.d/amlfs.repo

    rpm --import https://packages.microsoft.com/keys/microsoft.asc

    echo -e "[amlfs]" > ${REPO_PATH}
    echo -e "name=Azure Lustre Packages" >> ${REPO_PATH}
    echo -e "baseurl=https://packages.microsoft.com/yumrepos/amlfs-${DISTRIB_CODENAME}" >> ${REPO_PATH}
    echo -e "enabled=1" >> ${REPO_PATH}
    echo -e "gpgcheck=1" >> ${REPO_PATH}
    echo -e "gpgkey=https://packages.microsoft.com/keys/microsoft.asc" >> ${REPO_PATH}

    dnf install -y --disableexcludes=main --refresh amlfs-lustre-client-${ALMA_LUSTRE_VERSION}-$(uname -r | sed -e "s/\.$(uname -p)$//" | sed -re 's/[-_]/\./g')-1
    sed -i "$ s/$/ amlfs*/" /etc/dnf/dnf.conf
fi

write_component_version "LUSTRE" ${LUSTRE_VERSION}
