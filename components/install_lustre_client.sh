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
    ./configure --with-linux=/usr/src/linux-headers-$(uname -r) --with-o2ib=/usr/src/ofa_kernel/default --disable-server --disable-ldiskfs --without-zfs --disable-snmp --enable-quota
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
    # RHEL-family build-from-source: mirrors the Ubuntu flow above so AMLFS
    # kmod ships as a DKMS RPM that auto-rebuilds against future host kernels
    # via `dnf upgrade kernel`. Same arsdragonfly/dkms-* branch -- its patches
    # only touch debian/* and a clang CFLAGS toggle, so the RPM path is
    # unchanged. Base toolchain (gcc/autotools/rpm-build/kernel-*-devel/dkms)
    # comes from distros/<rhel>/install_utils.sh; only the lustre-specific
    # libs are added below.
    #
    # openmpi-devel is satisfied below by an in-place marker RPM that
    # `Provides: openmpi-devel`, mirroring the Ubuntu `hpcx-provides-openmpi`
    # equivs trick in install_doca.sh. Installing appstream openmpi-devel
    # directly is not an option on EL+DOCA: appstream openmpi-devel requires
    # the namespaced `libmpi.so.40()(64bit)(openmpi-x86_64)` provide that
    # DOCA's openmpi 4.1.9a1 (strict-pinned by clusterkit on EL9 /
    # opensm-libs on EL8) does not ship, so `dnf install openmpi-devel`
    # aborts with an unresolved file dep before lustre builds.
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

    # Build & install an empty marker RPM that:
    #   (a) Provides: openmpi-devel       -- satisfies lustre-tests's BR so
    #       rpmbuild proceeds without dnf reaching for appstream openmpi-devel.
    #   (b) Owns %dir /usr/lib64/lustre-tests-mpi -- the destination for
    #       MPI-linked lustre test binaries (see _openmpi_load macro below);
    #       without an owning package the dir would be unowned in the final
    #       image (cosmetic, but rpm-build flags it as a warning).
    # Marker stays installed after the build so any future `dnf install` of a
    # package with `Requires: openmpi-devel` resolves through it instead of
    # re-tripping the EL+DOCA conflict above.
    marker_dir=$(mktemp -d)
    cat > "${marker_dir}/hpcx-provides-openmpi-devel.spec" <<'MARKER_SPEC'
Name:           hpcx-provides-openmpi-devel
Version:        1.0
Release:        1%{?dist}
Summary:        Marker: HPC-X provides Open MPI development headers
License:        MIT
BuildArch:      noarch

Provides:       openmpi-devel = %{version}-%{release}

%description
Marker package telling rpmbuild that HPC-X (installed under /opt by
install_mpis.sh) provides Open MPI development headers, satisfying the
BuildRequires: openmpi-devel of lustre-client-tests when built from source.
Without this, dnf would try to install appstream openmpi-devel which on
EL+DOCA cannot resolve: appstream openmpi-devel requires the namespaced
libmpi.so.40()(64bit)(openmpi-x86_64) provide that DOCA's openmpi 4.1.9a1
does not ship.

Also owns /usr/lib64/lustre-tests-mpi so the MPI-linked lustre test
binaries (installed there by lustre-client-tests) have a properly owned
parent directory.

%install
mkdir -p %{buildroot}/usr/lib64/lustre-tests-mpi

%files
%dir /usr/lib64/lustre-tests-mpi
MARKER_SPEC
    rpmbuild -bb \
        --define "_topdir ${marker_dir}/rpmbuild" \
        "${marker_dir}/hpcx-provides-openmpi-devel.spec"
    dnf install -y "${marker_dir}"/rpmbuild/RPMS/noarch/hpcx-provides-openmpi-devel-*.noarch.rpm
    rm -rf "${marker_dir}"

    # Tell rpmbuild how to load HPC-X inside the lustre.spec's %build,
    # %install, and tests-files-generation sections. Appstream openmpi-devel
    # ships /etc/rpm/macros.openmpi defining `_openmpi_load` as
    #   `. /etc/profile.d/modules.sh; module load mpi/openmpi-x86_64`
    # which the spec expands via `%{?_openmpi_load}`. With the marker package
    # (not the real openmpi-devel) installed, `_openmpi_load` would expand to
    # empty, lustre's autoconf would fail to find mpicc (`lb_cv_mpi_tests=no`),
    # and the lustre-tests RPM would ship with no MPI test binaries.
    #
    # We define our own pointing at the HPC-X modulefile that install_mpis.sh
    # creates at /usr/share/Modules/modulefiles/mpi/hpcx (load-once symlink to
    # the versioned hpcx-${HPCX_VERSION}). MPI_BIN is forced to a lustre-private
    # path so:
    #   * lustre's autoconf finds mpicc via PATH (module load adds HPC-X's bin),
    #   * lustre's tests/Makefile installs MPI test binaries to $(MPI_BIN), and
    #   * the spec's `echo "$MPI_BIN/*" >>lustre-tests.files` records that path
    #     (NOT a versioned /opt/hpcx-<ver>/ompi/bin path that would collide
    #     with HPC-X's own files and would change across HPC-X bumps).
    # Libtool RPATHs each MPI binary against /opt/hpcx-*/ompi/lib at build
    # time, so the binaries find libmpi.so.40 at runtime without depending on
    # `module load` having been run first.
    #
    # File lives at /etc/rpm/macros.hpcx-lustre: rpm auto-loads any file
    # matching `/etc/rpm/macros.*` (rpmrc Macrofiles glob), so every nested
    # rpmbuild invocation -- including the make rpms -> srpm -> --rebuild
    # chain in lustre's autoMakefile.am -- picks it up without needing
    # --define plumbing through the lustre Makefile. Removed after the build
    # since `_openmpi_load` is normally an appstream-openmpi-only concept and
    # would silently alter any future rpmbuild call against a spec using it.
    cat > /etc/rpm/macros.hpcx-lustre <<'RPM_MACROS'
%_openmpi_load \
    . /etc/profile.d/modules.sh; \
    module load mpi/hpcx; \
    export MPI_BIN=/usr/lib64/lustre-tests-mpi
%_openmpi_unload \
    module unload mpi/hpcx
RPM_MACROS

    # DKMS build decouples lustre from the running kernel: lustre-client-dkms
    # ships only the kernel-module source under /usr/src/lustre-client-<ver>/
    # and dkms rebuilds on each kernel change. Same intent as the Ubuntu
    # `make dkms-debs` flow above; works around the AMLFS yumrepo's day-1 gap
    # after new RHEL kernel patches, and lets distros/<rhel>/install_utils.sh
    # skip pinning `kernel*` on this path so the host can `dnf upgrade kernel`.
    lustre_branch="arsdragonfly/dkms-$LUSTRE_BUILD_FROM_SOURCE_VERSION"
    git clone --branch ${lustre_branch} https://github.com/arsdragonfly/amlFilesystem-lustre.git
    pushd amlFilesystem-lustre
    sh ./autogen.sh
    # Tests are enabled (default `%bcond_without lustre_tests`). The marker
    # RPM + _openmpi_load macro override (above) make HPC-X visible to
    # rpmbuild so lustre-client-tests builds MPI-linked binaries
    # (mpi_test_lock, simul, mdsrate, etc.) under $MPI_BIN.
    # --with-o2ib applies only to the userland `make rpms`; the DKMS rebuild
    # on the host runs its own ./configure via lustre-dkms_pre-build.sh and
    # auto-detects OFED headers at /usr/src/ofa_kernel/default (DOCA symlink).
    ./configure --with-linux=/usr/src/kernels/$(uname -r) \
                --with-o2ib=/usr/src/ofa_kernel/default \
                --disable-server \
                --disable-ldiskfs \
                --without-zfs \
                --disable-snmp \
                --enable-quota

    # Two-target build (RHEL splits what Ubuntu's `make dkms-debs` does in one):
    #   `make rpms`      -> lustre-client (userland) + -devel + -iokit +
    #                       -tests + kmod-lustre-client + kmod-lustre-client-tests
    #                       (core kmod NOT installed -- DKMS replaces it; test
    #                       kmod IS installed, see note below).
    #   `make dkms-rpms` -> lustre-client-dkms (noarch); postinst runs
    #                       `dkms autoinstall` for the bake kernel, and dkms
    #                       hooks rebuild on future `dnf upgrade kernel`.
    #                       Provides: kmod-lustre-client = %{version}, so
    #                       lustre-client's dep is satisfied without the static RPM.
    # `kver=$(uname -r)` MUST be on the make command line: upstream's
    # srpm/dkms-srpm targets pass `--define "kver ${kver}"` as a Make variable
    # (overriding the spec's `%(uname -r)` fallback); unset -> rpmbuild aborts
    # with `Macro %kver has empty body`.
    IB_OPTIONS="--with-o2ib=/usr/src/ofa_kernel/default" make kver=$(uname -r) rpms
    make kver=$(uname -r) dkms-rpms
    # Install set (parity with Ubuntu's `apt install ./debs/lustre-*.deb`):
    #   lustre-client            - userland (`[0-9]*` glob excludes -devel,
    #                              -tests, -dkms whose next char after
    #                              `lustre-client-` is non-digit; lustre-iokit
    #                              also excluded -- different prefix).
    #   lustre-client-devel      - required by -tests (`Requires: lustre-devel`).
    #   lustre-iokit             - benchmarking helpers (obdfilter-survey,
    #                              sgpdd-survey, ost-survey, ior-survey,
    #                              mds-survey, stats-collect). NOTE: the
    #                              lustre.spec iokit subpackage is named
    #                              `lustre-iokit` -- the `lustre_name=lustre-client`
    #                              rename only applies to the userland + kmod
    #                              subpackages, not iokit. Installed here for
    #                              parity with the Ubuntu `lustre-*.deb` glob;
    #                              not a hard dep of lustre-client-tests.
    #   lustre-client-tests      - userland tests + MPI binaries built against
    #                              HPC-X, installed under /usr/lib64/lustre-tests-mpi.
    #   kmod-lustre-client-tests - test-only kmods (obd_test.ko, llog_test.ko,
    #                              ec_test.ko, kinode.ko). lustre-client-dkms
    #                              does NOT rebuild these on kernel upgrade --
    #                              its postinst only auto-installs the core
    #                              lustre-client kmod, not lustre-client-tests.
    #                              Accepted limitation: test modules are CI/dev
    #                              use only; customers running tests on a
    #                              non-bake kernel would need to rebuild them
    #                              manually. Required at install time by
    #                              lustre-client-tests's
    #                              `Requires: kmod-lustre-client-tests >= X.Y`.
    #   lustre-client-dkms       - core kmod source, dkms-rebuilds on each kernel.
    # kmod-lustre-client (static, non-tests) is NOT installed: lustre-client-dkms
    # `Provides: kmod-lustre-client = %{version}` satisfies lustre-client's dep.
    dnf install -y ./lustre-client-[0-9]*.$(uname -m).rpm \
                   ./lustre-client-devel-[0-9]*.$(uname -m).rpm \
                   ./lustre-iokit-[0-9]*.$(uname -m).rpm \
                   ./lustre-client-tests-[0-9]*.$(uname -m).rpm \
                   ./kmod-lustre-client-tests-[0-9]*.$(uname -m).rpm \
                   ./lustre-client-dkms-[0-9]*.noarch.rpm
    popd
    rm -rf amlFilesystem-lustre
    # Cleanup the rpm macro override (lustre-specific, should not leak into
    # any subsequent rpmbuild calls in this bake). Marker RPM stays installed
    # to keep /usr/lib64/lustre-tests-mpi owned and to short-circuit any
    # future `dnf install` of a package that needs openmpi-devel.
    rm -f /etc/rpm/macros.hpcx-lustre
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
        dnf_pin_packages "amlfs*"
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
