#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

# Set Lustre version
lustre_metadata=$(get_component_config "lustre")
LUSTRE_VERSION=$(jq -r '.version' <<< $lustre_metadata)
# build_from_source_version is the upstream Lustre tag matching the
# arsdragonfly/dkms-<ver> branch used when building from source. It can
# differ from `version` (which on RHEL points at the AMLFS yumrepo's
# git-describe build, e.g. 2.15.7_33_g79ddf99). Fall back to LUSTRE_VERSION
# for backwards compatibility when the field is not declared.
LUSTRE_BUILD_FROM_SOURCE_VERSION=$(jq -r '.build_from_source_version // empty' <<< $lustre_metadata)
LUSTRE_BUILD_FROM_SOURCE_VERSION=${LUSTRE_BUILD_FROM_SOURCE_VERSION:-$LUSTRE_VERSION}

# Toggle between building AMLFS kmod from source vs installing DKMS packages from the repo.
# Set to "true" to build from source (current default), "false" to use prebuild binaries.
KERNEL_MINOR=$(uname -r | grep -oP '^\d+\.\d+')
LUSTRE_BUILD_FROM_SOURCE=$(echo "${LUSTRE_BUILD_FROM_SOURCE:-false}" | tr '[:upper:]' '[:lower:]')

if [[ $DISTRIBUTION == *"ubuntu"* && $LUSTRE_BUILD_FROM_SOURCE == "true" ]]; then
    source /etc/lsb-release
    UBUNTU_VERSION=$(cat /etc/os-release | grep VERSION_ID | cut -d= -f2 | cut -d\" -f2)

    # The hpcx-provides-openmpi marker package (installed earlier by install_doca.sh)
    # already tells apt that HPC-X provides openmpi-bin, libopenmpi-dev and
    # openmpi-common, so lustre-tests can install without pulling in Canonical's
    # upstream Open MPI.

    # use dev headers from HPC-X OpenMPI installation for lustre-tests
    source /etc/profile.d/modules.sh
    module load mpi/hpcx

    # temporary workaround to build AMLFS kmod from source, until we have AMLFS team publish DKMS packages usable on day-1 of new kernel module release
    lustre_branch="arsdragonfly/dkms-$LUSTRE_BUILD_FROM_SOURCE_VERSION"
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
elif [[ $DISTRIBUTION == *"ubuntu"* ]]; then
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

    CURRENT_KERNEL=$(uname -r)
    # Extract kernel minor version (e.g., "6.8" from "6.8.0-1052-azure")
    KERNEL_MINOR=$(echo "$CURRENT_KERNEL" | grep -oP '^\d+\.\d+')

    if apt-cache show amlfs-lustre-client-${LUSTRE_VERSION}=${CURRENT_KERNEL} 2>/dev/null | grep -q "Version:"; then
        echo "Lustre client package for kernel ${CURRENT_KERNEL} is available in the repo."
        apt-get install -y amlfs-lustre-client-${LUSTRE_VERSION}=${CURRENT_KERNEL}
        apt-mark hold amlfs-lustre-client-${LUSTRE_VERSION}
    elif apt-cache showpkg amlfs-lustre-client-${LUSTRE_VERSION} 2>/dev/null | grep -q "^${KERNEL_MINOR}\."; then
        # Packages exist for this kernel minor version but not for the exact patch version.
        # This likely means the repo hasn't published a package for the latest kernel update yet.
        echo "##[error]Lustre client packages exist for kernel ${KERNEL_MINOR}.x but not for the exact version ${CURRENT_KERNEL}."
        echo "##[error]The AMLFS repo likely hasn't published a package for this kernel patch version yet."
        apt-cache showpkg amlfs-lustre-client-${LUSTRE_VERSION} 2>/dev/null | grep "^${KERNEL_MINOR}\." | head -5
        exit 1
    else
        # No packages exist for this kernel minor version at all (e.g., HWE kernel 6.14, 6.17).
        echo "##[warning]No Lustre client packages available for kernel minor version ${KERNEL_MINOR}. Skipping Lustre installation."
        exit 0
    fi
elif [[ $LUSTRE_BUILD_FROM_SOURCE == "true" ]]; then
    # RHEL-family build from source: AlmaLinux, Rocky Linux, RHEL, etc.
    # Mirrors the Ubuntu build-from-source flow above so that AMLFS kmod can be
    # rebuilt for any kernel rather than depending on the kernel-specific binary
    # packages published in the AMLFS yumrepo. The same upstream branch is used
    # because the patches in arsdragonfly/dkms-${LUSTRE_BUILD_FROM_SOURCE_VERSION}
    # only touch debian/* and a clang-specific CFLAGS toggle in
    # config/lustre-toolchain.m4; nothing in the RPM build path is altered.

    # Install Lustre build dependencies. Most of the base toolchain (gcc, make,
    # autoconf, automake, libtool, rpm-build, kernel-rpm-macros, libnl3-devel,
    # python3-devel, kernel-devel/headers/modules-extra for the running kernel)
    # is already pulled in by distros/<rhel>/install_utils.sh via the
    # "Development Tools" group + the explicit yum install lists. Here we add
    # only the packages that are specific to compiling the Lustre client
    # userland + kmod from source.
    #
    # openmpi-devel is required because lustre.spec.in declares
    # `BuildRequires: openmpi-devel` (under `%{with mpi}`, default on) on RHEL.
    # rpmbuild's dep check inspects the installed RPM set only -- HPC-X under
    # /opt does not satisfy it -- so the from-source build aborts at the
    # `make rpms` stage without this package. We only install the kmod and
    # lustre-client userland RPMs below, so the openmpi runtime never lands
    # in the baked image; openmpi-devel is purely a build-host dep.
    dnf install -y \
        libyaml-devel \
        openssl-devel \
        libmount-devel \
        keyutils-libs-devel \
        libselinux-devel \
        libaio-devel \
        elfutils-libelf-devel \
        libtirpc-devel \
        openmpi-devel \
        swig \
        bison \
        flex

    # Temporary workaround to build AMLFS kmod from source, until we have the
    # AMLFS team publish kernel-tracking kmod packages usable on day-1 of new
    # kernel module release.
    lustre_branch="arsdragonfly/dkms-$LUSTRE_BUILD_FROM_SOURCE_VERSION"
    git clone --branch ${lustre_branch} https://github.com/arsdragonfly/amlFilesystem-lustre.git
    pushd amlFilesystem-lustre
    sh ./autogen.sh
    ./configure --with-linux=/usr/src/kernels/$(uname -r) \
                --with-o2ib=/usr/src/ofa_kernel/default \
                --disable-server \
                --disable-ldiskfs \
                --disable-zfs \
                --disable-snmp \
                --enable-quota

    # Build the full RPM set (kmod-lustre-client tied to the running kernel,
    # plus lustre-client userland utils, lustre-iokit and lustre-tests). The
    # RPMs are dropped at the top of the source tree by the lustre `rpms`
    # target. Install only the kmod and userland utils; lustre-tests Requires
    # an MPI runtime package and is not needed in the baked image.
    IB_OPTIONS="--with-o2ib=/usr/src/ofa_kernel/default" make rpms
    dnf install -y ./kmod-lustre-client-[0-9]*.$(uname -m).rpm \
                   ./lustre-client-[0-9]*.$(uname -m).rpm
    popd
    rm -rf amlFilesystem-lustre
    LUSTRE_VERSION=$(rpm -q --queryformat '%{VERSION}\n' lustre-client | head -1)
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

    CURRENT_KERNEL=$(uname -r)
    # Extract kernel minor version for RHEL (e.g., "4.18" from "4.18.0-553.22.1.el8_10.x86_64")
    KERNEL_MINOR=$(echo "$CURRENT_KERNEL" | grep -oP '^\d+\.\d+')
    LUSTRE_KERNEL_SUFFIX=$(echo "$CURRENT_KERNEL" | sed -e "s/\.$(uname -p)$//" | sed -re 's/[-_]/\./g')

    if sudo dnf list --available amlfs-lustre-client-${LUSTRE_VERSION_UNDERSCORE}-${LUSTRE_KERNEL_SUFFIX}-1 2>/dev/null | grep -q "Available Packages"; then
        echo "Lustre client package for kernel ${CURRENT_KERNEL} is available in the repo."
        dnf install -y --disableexcludes=main --refresh amlfs-lustre-client-${LUSTRE_VERSION_UNDERSCORE}-${LUSTRE_KERNEL_SUFFIX}-1
        sed -i "$ s/$/ amlfs*/" /etc/dnf/dnf.conf
    elif sudo dnf list --available "amlfs-lustre-client-${LUSTRE_VERSION_UNDERSCORE}-${KERNEL_MINOR}.*" 2>/dev/null | grep -q "Available Packages"; then
        # Packages exist for this kernel minor version but not for the exact patch version.
        echo "##[error]Lustre client packages exist for kernel ${KERNEL_MINOR}.x but not for the exact version ${CURRENT_KERNEL}."
        echo "##[error]The AMLFS repo likely hasn't published a package for this kernel patch version yet."
        sudo dnf list --available "amlfs-lustre-client-${LUSTRE_VERSION_UNDERSCORE}-${KERNEL_MINOR}.*" 2>/dev/null | tail -5
        exit 1
    else
        # No packages exist for this kernel minor version at all.
        echo "##[warning]No Lustre client packages available for kernel minor version ${KERNEL_MINOR}. Skipping Lustre installation."
        exit 0
    fi
fi

write_component_version "LUSTRE" ${LUSTRE_VERSION}
