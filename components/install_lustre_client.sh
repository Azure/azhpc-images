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
    # Mirrors the Ubuntu build-from-source flow above so that AMLFS kmod is
    # delivered as a DKMS package and auto-rebuilds against any future host
    # kernel (via `dnf upgrade kernel`). The same upstream branch is used
    # because the patches in arsdragonfly/dkms-${LUSTRE_BUILD_FROM_SOURCE_VERSION}
    # only touch debian/* and a clang-specific CFLAGS toggle in
    # config/lustre-toolchain.m4; nothing in the RPM build path is altered.

    # Install Lustre build dependencies. Most of the base toolchain (gcc, make,
    # autoconf, automake, libtool, rpm-build, kernel-rpm-macros, libnl3-devel,
    # python3-devel, kernel-devel/headers/modules-extra for the running kernel,
    # and `dkms` from EPEL) is already pulled in by distros/<rhel>/install_utils.sh
    # via the "Development Tools" group + the explicit yum install lists. Here
    # we add only the packages that are specific to compiling the Lustre client
    # userland + kmod from source. Note that `kernel-devel` is required at both
    # bake time (initial dkms autoinstall) AND on the running host whenever the
    # kernel is upgraded -- install_utils.sh deliberately omits `kernel*` from
    # /etc/dnf/dnf.conf `exclude=` on the build-from-source path so kernel and
    # kernel-devel can be upgraded together by `dnf upgrade`.
    #
    # NOTE: We deliberately do NOT install openmpi-devel. lustre.spec.in only
    # declares `BuildRequires: openmpi-devel` inside the lustre-tests subpackage
    # (gated by `%{with lustre_tests}` AND `%{with mpi}`), and we pass
    # `--disable-tests` to configure below which makes lustre append
    # `--without lustre_tests` to RPMBUILD_BINARY_ARGS, dropping that BR. We
    # don't install the lustre-tests RPM in the baked image anyway. Installing
    # the appstream openmpi-devel here would conflict with the DOCA-bundled
    # OpenMPI (clusterkit on EL9 / opensm-libs on EL8 pin DOCA's openmpi
    # `4.1.9a1`, while the appstream `openmpi-devel` requires the namespaced
    # provide `libmpi.so.40()(64bit)(openmpi-x86_64)` which DOCA's openmpi
    # doesn't carry), aborting `dnf install` before lustre is even built.
    dnf install -y \
        libyaml-devel \
        openssl-devel \
        libmount-devel \
        keyutils-libs-devel \
        libselinux-devel \
        libaio-devel \
        elfutils-libelf-devel \
        libtirpc-devel \
        swig \
        bison \
        flex

    # Workaround for the same day-1 gap that motivates the Ubuntu branch above:
    # the AMLFS yumrepo publishes per-kernel `kmod-lustre-client` RPMs that lag
    # behind new RHEL kernel patch releases (see the prebuilt branch's
    # "##[error]The AMLFS repo likely hasn't published a package for this
    # kernel patch version yet" path). Building from source as a DKMS package
    # decouples lustre from a specific kernel: the `lustre-client-dkms` RPM
    # ships only the kernel module source under /usr/src/lustre-client-<ver>/,
    # and `dkms` rebuilds the module on each kernel change. This matches the
    # Ubuntu `make dkms-debs` flow and is what allows the `kernel*` exclude in
    # distros/<rhel>/install_utils.sh to be skipped on the build-from-source
    # path (see the "DKMS-style rebuilds can keep up with kernel upgrades"
    # note there) so the host can run `dnf upgrade` without holding the kernel.
    lustre_branch="arsdragonfly/dkms-$LUSTRE_BUILD_FROM_SOURCE_VERSION"
    git clone --branch ${lustre_branch} https://github.com/arsdragonfly/amlFilesystem-lustre.git
    pushd amlFilesystem-lustre
    sh ./autogen.sh
    # --disable-tests: skip building the lustre-tests subpackage. This also
    # propagates `--without lustre_tests` into RPMBUILD_BINARY_ARGS (see
    # config/lustre-build.m4 LB_CONFIG_RPMBUILD_OPTIONS), which removes the
    # `BuildRequires: openmpi-devel` that would otherwise fail dep-check given
    # the DOCA-bundled OpenMPI installed earlier (see note above). The
    # --with-o2ib path here is consumed by `make rpms` for the userland build
    # only; the DKMS rebuild on the host runs its own `./configure` via
    # lustre-dkms_pre-build.sh which auto-detects OFED headers under
    # /usr/src/ofa_kernel/default (the symlink installed by DOCA).
    ./configure --with-linux=/usr/src/kernels/$(uname -r) \
                --with-o2ib=/usr/src/ofa_kernel/default \
                --disable-server \
                --disable-ldiskfs \
                --disable-zfs \
                --disable-snmp \
                --disable-tests \
                --enable-quota

    # Two-target build (unlike Ubuntu's unified `dkms-debs`, RHEL splits this):
    #   1. `make rpms`      -> lustre.spec.in -> lustre-client (userland),
    #                          lustre-client-devel, lustre-iokit, and
    #                          kmod-lustre-client (a kernel-pinned kmod we
    #                          deliberately DO NOT install -- DKMS replaces it).
    #   2. `make dkms-rpms` -> lustre-dkms.spec.in -> lustre-client-dkms (noarch).
    #                          Packages the source tree + a generated dkms.conf;
    #                          the RPM postinst then runs `dkms autoinstall`
    #                          which compiles the module against `uname -r`.
    #                          On future `dnf upgrade kernel`, dkms hooks
    #                          rebuild against the new kernel automatically.
    # The DKMS RPM `Provides: kmod-lustre-client = %{version}`, satisfying
    # lustre-client's dependency without the static kmod-lustre-client RPM.
    #
    # The version-digit glob `[0-9]*` after `lustre-client-` matches only the
    # userland `lustre-client-<ver>...rpm` (and `lustre-client-dkms-<ver>...rpm`
    # in the second glob) -- it excludes the sibling `lustre-client-devel-*`,
    # `lustre-client-tests-*`, and `kmod-lustre-client-*` RPMs because `d`/`t`/
    # `kmod-` are not digits.
    IB_OPTIONS="--with-o2ib=/usr/src/ofa_kernel/default" make rpms
    make dkms-rpms
    dnf install -y ./lustre-client-[0-9]*.$(uname -m).rpm \
                   ./lustre-client-dkms-[0-9]*.noarch.rpm
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
