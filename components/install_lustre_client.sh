#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

# Set Lustre version
lustre_metadata=$(get_component_config "lustre")
LUSTRE_VERSION=$(jq -r '.version' <<< $lustre_metadata)

if [[ $DISTRIBUTION == *"ubuntu"* ]]; then
    source /etc/lsb-release
    UBUNTU_VERSION=$(cat /etc/os-release | grep VERSION_ID | cut -d= -f2 | cut -d\" -f2)

    # we need to make a marker package to tell apt that HPC-X provides its own OpenMPI, so that lustre-tests can install properly
    apt install -y equivs
    cat <<EOF > /tmp/hpcx-provides-openmpi-bin
Section: misc
Priority: optional
Homepage: https://github.com/Azure/azhpc-images
Standards-Version: 3.9.2

Package: hpcx-provides-openmpi-bin
Provides: openmpi-bin, libopenmpi-dev, libopenmpi3, openmpi-common
Conflicts: openmpi-bin, libopenmpi-dev, libopenmpi3, openmpi-common
Version: 4.1
Maintainer: Azure HPC Platform team <hpcplat@microsoft.com>
Description: marker package in Azure HPC Image to indicate that HPC-X provides OpenMPI binaries
 Upstream OpenMPI (i.e. OpenMPI packaged by Ubuntu) is unsuitable for HPC purposes, and depends on vulnerable PMIx with fixes behind Ubuntu Pro paywall on Jammy.
EOF

    equivs-build /tmp/hpcx-provides-openmpi-bin
    dpkg -i ./hpcx-provides-openmpi-bin_4.1_all.deb
    rm -f ./hpcx-provides-openmpi-bin_4.1_all.deb
    rm -f /tmp/hpcx-provides-openmpi-bin

    # use dev headers from HPC-X OpenMPI installation for lustre-tests
    source /etc/profile.d/modules.sh
    module load mpi/hpcx

    # if [ $UBUNTU_VERSION == 24.04 ]; then
    #     SIGNED_BY="/usr/share/keyrings/microsoft-prod.gpg"
    # elif [ $UBUNTU_VERSION == 22.04 ]; then
    #     SIGNED_BY="/etc/apt/trusted.gpg.d/microsoft-prod.gpg"
    # fi
    # echo "deb [arch=$ARCHITECTURE_DISTRO signed-by=$SIGNED_BY] https://packages.microsoft.com/repos/amlfs-${DISTRIB_CODENAME}/ ${DISTRIB_CODENAME} main" | tee /etc/apt/sources.list.d/amlfs.list
    # # Enable these lines if the MS PMC repo was not already setup.
    # #curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
    # #cp ./microsoft.gpg /etc/apt/trusted.gpg.d/
    # apt-get update
    # if apt-cache show amlfs-lustre-client-${LUSTRE_VERSION}=$(uname -r) 2>/dev/null | grep -q "Version:"; then
    #     echo "Lustre client package for kernel $(uname -r) is already available in the repo."
    #     apt-get install -y amlfs-lustre-client-${LUSTRE_VERSION}=$(uname -r)
    #     apt-mark hold amlfs-lustre-client-${LUSTRE_VERSION}
    # else
    #     echo "Lustre client package for kernel $(uname -r) is not available in the repo. Please check the repository or the kernel version."
    #     exit 0
    # fi

    # temporary workaround to build AMLFS kmod from source, until we have AMLFS team publish DKMS packages usable on day-1 of new kernel module release
    lustre_branch="arsdragonfly/dkms-$LUSTRE_VERSION"
    git clone --branch ${lustre_branch} https://github.com/arsdragonfly/amlFilesystem-lustre.git
    pushd amlFilesystem-lustre
    sh ./autogen.sh
    apt update
    if [ $UBUNTU_VERSION == 24.04 ]; then
        apt install -y module-assistant libselinux-dev libsnmp-dev mpi-default-dev quilt libssl-dev swig
    elif [ $UBUNTU_VERSION == 22.04 ]; then
        apt install -y module-assistant dpatch libselinux-dev libsnmp-dev mpi-default-dev quilt libssl-dev swig
    fi
    ./configure --with-linux=/usr/src/linux-headers-$(uname -r) --with-o2ib=/usr/src/ofa_kernel/default --disable-server --disable-ldiskfs --disable-zfs --disable-snmp --enable-quota
    #make dkms-debs
    IB_OPTIONS="--with-o2ib=/usr/src/ofa_kernel/default" make dkms-debs
    apt install -y ./debs/lustre-*.deb
    popd
    rm -rf amlFilesystem-lustre
    LUSTRE_VERSION=$(dpkg-query -W -f='${Version}\n' lustre-client-utils | cut -d~ -f1)
else
    # RHEL-family: AlmaLinux, Rocky Linux, RHEL, etc.
    LUSTRE_VERSION_UNDERSCORE=${LUSTRE_VERSION//-/_}
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

    if sudo dnf list --available amlfs-lustre-client-${LUSTRE_VERSION_UNDERSCORE}-$(uname -r | sed -e "s/\.$(uname -p)$//" | sed -re 's/[-_]/\./g')-1 2>/dev/null | grep -q "Available Packages"; then
        echo "Lustre client package for kernel $(uname -r) is already available in the repo."
        dnf install -y --disableexcludes=main --refresh amlfs-lustre-client-${LUSTRE_VERSION_UNDERSCORE}-$(uname -r | sed -e "s/\.$(uname -p)$//" | sed -re 's/[-_]/\./g')-1
        sed -i "$ s/$/ amlfs*/" /etc/dnf/dnf.conf
    else
        echo "Lustre client package for kernel $(uname -r) is not available in the repo. Please check the repository or the kernel version."
        exit 0
    fi
fi

write_component_version "LUSTRE" ${LUSTRE_VERSION}
