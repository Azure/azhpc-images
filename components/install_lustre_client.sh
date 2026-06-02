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
    # RHEL-family build-from-source path: same approach as the Ubuntu
    # path above, but produces RPMs. Builds the lustre kmod as a DKMS
    # package so it auto-rebuilds when the host kernel is upgraded, and
    # uses the same lustre source branch as Ubuntu.
    #
    # Lustre's standard build tools (gcc, autotools, rpm-build,
    # kernel-*-devel, dkms) are already installed by
    # distros/<rhel>/install_utils.sh; only lustre-specific dev
    # libraries are added below.
    #
    # Note on openmpi-devel: lustre-tests needs it to build, but on
    # EL+DOCA the stock appstream openmpi-devel cannot install -- it
    # requires a namespaced provide that DOCA's pinned openmpi does not
    # ship, so dnf aborts before lustre builds. The workaround below
    # uses an empty marker RPM (analogous to the hpcx-provides-openmpi
    # equivs package in install_doca.sh) plus an rpm macro override
    # that points rpmbuild at HPC-X for the actual MPI headers.
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

    # Build and install an empty marker RPM that does two things:
    #   (a) Provides openmpi-devel, so rpmbuild's BuildRequires check
    #       passes without dnf trying to install the appstream package.
    #   (b) Owns /usr/lib64/lustre-tests-mpi, the directory where the
    #       MPI-linked lustre test binaries will be installed (set up
    #       by the rpm macros below). Without an owning package the
    #       directory would be unowned in the final image -- cosmetic,
    #       but rpm-build flags it as a warning.
    # The marker stays installed after the build, so any future package
    # that requires openmpi-devel resolves through it instead of
    # hitting the same DOCA conflict.
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
Empty marker package: tells rpmbuild that HPC-X (installed under /opt
by install_mpis.sh) satisfies lustre-client-tests's openmpi-devel
BuildRequires, and owns /usr/lib64/lustre-tests-mpi as the install
directory for the MPI-linked lustre test binaries. See the comments
in install_lustre_client.sh for why the appstream openmpi-devel
package cannot be installed on EL+DOCA.

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

    # Override the _openmpi_load rpm macro so rpmbuild loads HPC-X when
    # it builds the lustre-tests subpackage. The stock macro (shipped by
    # appstream openmpi-devel) loads mpi/openmpi-x86_64; with only the
    # marker package installed, the macro would expand to empty, lustre's
    # autoconf would fail to find mpicc, and lustre-tests would build
    # with zero MPI binaries.
    #
    # We want MPI_BIN to land at a lustre-private path so:
    #   * lustre's tests/Makefile installs the MPI test binaries there,
    #   * lustre.spec's tests-files section records that path -- rather
    #     than a versioned /opt/hpcx-<ver>/ompi/bin path that would
    #     collide with HPC-X's own files and change across HPC-X bumps.
    # Libtool RPATHs each test binary against /opt/hpcx-*/ompi/lib at
    # build time, so they find libmpi.so.40 at runtime without needing
    # `module load` to have been run first.
    #
    # Two distinct consumers expect MPI_BIN to be set, and each reads it
    # in a different way:
    #
    # (1) lustre's configure (LB_CONFIG_MPITESTS m4 macro) -- recomputes
    #     MPI_BIN from `which mpicc | xargs dirname`, discarding any
    #     env-var override. The autoconf-substituted value lands in
    #     lustre/tests/mpi/Makefile as `testdir = @MPI_BIN@`, and that's
    #     where libtool installs the MPI test binaries at %install.
    #     -> Handled by symlinking HPC-X's mpicc into
    #        /usr/lib64/lustre-tests-mpi and prepending that dir to PATH
    #        (in this macro and in the outer shell below), so
    #        `which mpicc` returns /usr/lib64/lustre-tests-mpi/mpicc.
    #
    # (2) lustre.spec's `%files lustre-tests` shell script -- reads
    #     $MPI_BIN as a shell env var:
    #
    #         if [ -n "$MPI_BIN" ]; then
    #             echo "$MPI_BIN/*" >>lustre-tests.files
    #         fi
    #
    #     The stock /etc/rpm/macros.openmpi gets away without an
    #     explicit export because the appstream `mpi/openmpi-x86_64`
    #     modulefile sets MPI_BIN as a tcl env var. HPC-X's modulefile
    #     does not set MPI_BIN, so without an explicit export here, the
    #     test evaluates false, the glob never gets added to
    #     lustre-tests.files, and rpmbuild's check-files stage aborts
    #     with "Installed (but unpackaged) file(s)" for every
    #     /usr/lib64/lustre-tests-mpi/* binary -- plus duplicate
    #     build-id warnings because the orphan .debug files get
    #     claimed by both lustre-client-debuginfo and
    #     lustre-client-tests-debuginfo.
    #     -> Handled by the explicit `export MPI_BIN=...` below.
    #
    # The file is placed at /etc/rpm/macros.hpcx-lustre so rpm picks it
    # up automatically for every nested rpmbuild invocation (rpm reads
    # any file matching /etc/rpm/macros.*). It's removed after the
    # build to avoid affecting unrelated rpmbuild calls later in the bake.
    cat > /etc/rpm/macros.hpcx-lustre <<'RPM_MACROS'
%_openmpi_load \
    . /etc/profile.d/modules.sh; \
    module load mpi/hpcx; \
    export PATH=/usr/lib64/lustre-tests-mpi:$PATH; \
    export MPI_BIN=/usr/lib64/lustre-tests-mpi
%_openmpi_unload \
    module unload mpi/hpcx; \
    unset MPI_BIN
RPM_MACROS

    lustre_branch="arsdragonfly/dkms-$LUSTRE_BUILD_FROM_SOURCE_VERSION"
    git clone --branch ${lustre_branch} https://github.com/arsdragonfly/amlFilesystem-lustre.git
    pushd amlFilesystem-lustre
    sh ./autogen.sh

    # Prepare the environment the outer ./configure and the nested
    # rpmbuild's ./configure will both consume:
    #   - HPC-X loaded so libmpi/headers are visible and mpicc works.
    #   - /usr/lib64/lustre-tests-mpi/mpicc symlinked to HPC-X's mpicc
    #     so `which mpicc` resolves to our path -> autoconf substitutes
    #     MPI_BIN=/usr/lib64/lustre-tests-mpi.
    #   - PATH prepended with our private dir so the symlink wins over
    #     HPC-X's own ompi/bin/mpicc.
    #   - MPI_BIN exported explicitly: see the long comment above; HPC-X
    #     doesn't set it via its modulefile, and the spec's
    #     `%files lustre-tests` shell script gates `echo "$MPI_BIN/*"`
    #     on `[ -n "$MPI_BIN" ]`. This export covers the outer ./configure;
    #     the macros file above covers rpmbuild's nested shells.
    # The macros file above re-applies the PATH prepend inside rpmbuild;
    # the symlink is on-disk so it's visible to every shell.
    source /etc/profile.d/modules.sh
    module load mpi/hpcx
    ln -sf "$(command -v mpicc)" /usr/lib64/lustre-tests-mpi/mpicc
    export PATH=/usr/lib64/lustre-tests-mpi:$PATH
    export MPI_BIN=/usr/lib64/lustre-tests-mpi
    
    ./configure --with-linux=/usr/src/kernels/$(uname -r) \
                --with-o2ib=/usr/src/ofa_kernel/default \
                --disable-server \
                --disable-ldiskfs \
                --without-zfs \
                --disable-snmp \
                --enable-quota

    # Two build targets (Ubuntu does the equivalent in a single
    # `make dkms-debs`):
    #   `make rpms`      -> userland RPMs (lustre-client, -devel, -iokit,
    #                       -tests) plus the kmod RPMs (kmod-lustre-client
    #                       and kmod-lustre-client-tests). We install the
    #                       test kmod from this set; the core kmod is
    #                       replaced by the DKMS package.
    #   `make dkms-rpms` -> lustre-client-dkms (noarch). Its postinstall
    #                       runs `dkms autoinstall` for the bake kernel,
    #                       and dkms rebuilds on future `dnf upgrade
    #                       kernel`. It also provides kmod-lustre-client,
    #                       satisfying lustre-client's dep without the
    #                       static kmod RPM.
    # `kver=$(uname -r)` is required on the make command line: the
    # upstream Makefile passes it through as a --define to rpmbuild, and
    # rpmbuild aborts with `Macro %kver has empty body` if it's unset.
    IB_OPTIONS="--with-o2ib=/usr/src/ofa_kernel/default" make kver=$(uname -r) rpms
    make kver=$(uname -r) dkms-rpms
    # Install everything we built (the same set as the Ubuntu
    # `apt install ./debs/lustre-*.deb` step above) except the static kmod,
    # which is intentionally left out to let DKMS do its job.
    dnf install -y ./lustre-client-[0-9]*.$(uname -m).rpm \
                   ./lustre-client-devel-[0-9]*.$(uname -m).rpm \
                   ./lustre-iokit-[0-9]*.$(uname -m).rpm \
                   ./lustre-client-tests-[0-9]*.$(uname -m).rpm \
                   ./kmod-lustre-client-tests-[0-9]*.$(uname -m).rpm \
                   ./lustre-client-dkms-[0-9]*.noarch.rpm
    popd
    rm -rf amlFilesystem-lustre
    # Remove the lustre-specific rpm macro file so it doesn't affect any
    # later rpmbuild calls in this bake. The marker RPM stays installed
    # -- it keeps /usr/lib64/lustre-tests-mpi owned and continues to
    # satisfy any future openmpi-devel requirement. The mpicc symlink
    # inside the marker dir is also cleaned up: it pointed at a
    # versioned HPC-X path that would silently dangle on the next HPC-X
    # upgrade, and nothing post-build needs it.
    rm -f /etc/rpm/macros.hpcx-lustre /usr/lib64/lustre-tests-mpi/mpicc
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
