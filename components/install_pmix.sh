#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

pmix_metadata=$(get_component_config "pmix")
PMIX_VERSION=$(jq -r '.version' <<< $pmix_metadata)

if [[ $DISTRIBUTION == *"ubuntu"* ]]; then
    UBUNTU_VERSION=$(cat /etc/os-release | grep VERSION_ID | cut -d= -f2 | cut -d\" -f2)
    if [ $UBUNTU_VERSION == 24.04 ]; then
        REPO=slurm-ubuntu-noble
        SIGNED_BY="/usr/share/keyrings/microsoft-prod.gpg"
    elif [ $UBUNTU_VERSION == 22.04 ]; then
        REPO=slurm-ubuntu-jammy
        SIGNED_BY="/etc/apt/trusted.gpg.d/microsoft-prod.gpg"
    else echo "$DISTRIBUTION not supported for pmix installation."
    fi
    echo "deb [arch=$ARCHITECTURE_DISTRO signed-by=$SIGNED_BY] https://packages.microsoft.com/repos/$REPO/ insiders main" > /etc/apt/sources.list.d/slurm.list

    cp ${COMPONENT_DIR}/slurm-repo/slurm-u.pin /etc/apt/preferences.d/slurm-repository-pin-990
    ## This package is pre-installed in all hpc images used by cyclecloud, but if customer wants to
    ## use generic ubuntu marketplace image then this package sets up the right gpg keys for PMC.
    if [ ! -e /etc/apt/sources.list.d/microsoft-prod.list ]; then
        curl -sSL -O https://packages.microsoft.com/config/ubuntu/$UBUNTU_VERSION/packages-microsoft-prod.deb
        dpkg -i packages-microsoft-prod.deb
        rm packages-microsoft-prod.deb
    fi
    apt update
    apt install -y pmix=${PMIX_VERSION} libevent-dev libhwloc-dev # libmunge-dev
    # Hold versions of packages to prevent accidental updates. Packages can still be upgraded explictly by
    # '--allow-change-held-packages' flag.
    apt-mark hold pmix=${PMIX_VERSION} libevent-dev libhwloc-dev # libmunge-dev
elif [[ $DISTRIBUTION == "azurelinux3.0" ]]; then
    tdnf -y install pmix pmix-devel pmix-tools
    tdnf -y install hwloc-devel libevent-devel munge-devel
    if [ "$ARCHITECTURE" = "aarch64" ]; then
        postfix="aarch64"
    else
        postfix="x86_64"
    fi
    PMIX_VERSION=$(tdnf list installed | grep -i pmix.${postfix} | sed 's/.*[[:space:]]\([0-9.]*-[0-9]*\)\..*/\1/')
elif [[ $DISTRIBUTION == almalinux10* ]] || [[ $DISTRIBUTION == rocky10* ]] || [[ $DISTRIBUTION == rhel10* ]]; then
    # EL10: PMC does not yet ship a slurm-el10/pmix package. Build PMIx from the
    # upstream openpmix GitHub release into /opt/pmix/<ver> so install_mpis.sh can
    # rebuild HPC-X's Open MPI against it via --with-pmix=${PMIX_PATH}.
    # NOTE: this diverges from the PMC-sourced, Slurm-ABI-matched model. See caveats.

    # PMIX_VERSION comes from versions.json (e.g. "5.0.11-1"). The build tree/tarball
    # uses the bare X.Y.Z; strip the trailing "-N" release suffix.
    PMIX_FULL="${PMIX_VERSION}"          # 5.0.11-1
    PMIX_TRIPLE="${PMIX_FULL%-*}"        # 5.0.11
    PMIX_PREFIX="/opt/pmix/${PMIX_TRIPLE}"

    # Build dependencies (libevent + hwloc are hard requirements for PMIx;
    # munge for auth; devel headers for the later HPC-X/OMPI rebuild).
    dnf -y install gcc gcc-c++ make \
        libevent-devel hwloc-devel munge-devel \
        zlib-devel wget tar

    # Fetch the matching upstream release tarball (pre-bundled, no autogen needed).
    PMIX_TARBALL="pmix-${PMIX_TRIPLE}.tar.bz2"
    PMIX_URL="https://github.com/openpmix/openpmix/releases/download/v${PMIX_TRIPLE}/${PMIX_TARBALL}"

    wget -O "${PMIX_TARBALL}" "${PMIX_URL}"

    tar -xf "${PMIX_TARBALL}"
    cd "pmix-${PMIX_TRIPLE}"

    ./configure \
        --prefix="${PMIX_PREFIX}" \
        --with-libevent=/usr \
        --with-hwloc=/usr \
        --with-munge=/usr
    make -j"$(nproc)"
    make install
    cd ..

    # Make the shared libs discoverable at runtime.
    echo "${PMIX_PREFIX}/lib" > /etc/ld.so.conf.d/pmix.conf
    ldconfig

    # Sanity check: pmix_info should report the version we expect.
    "${PMIX_PREFIX}/bin/pmix_info" --version || true
else
    # RHEL-family: AlmaLinux, Rocky Linux, RHEL, etc.
    OS_MAJOR_VERSION=$(sed -n 's/^VERSION_ID="\([0-9]\+\).*/\1/p' /etc/os-release)
    cp ${COMPONENT_DIR}/slurm-repo/slurm-el${OS_MAJOR_VERSION}.repo /etc/yum.repos.d/slurm.repo

    if [ ! -e /etc/yum.repos.d/microsoft-prod.repo ];then
        curl -sSL -O https://packages.microsoft.com/config/rhel/${OS_MAJOR_VERSION}/packages-microsoft-prod.rpm
        rpm -i packages-microsoft-prod.rpm
        rm packages-microsoft-prod.rpm
    fi

    case "$OS_MAJOR_VERSION" in
        10|9) dnf config-manager --set-enabled crb ;;
        8)    dnf config-manager --set-enabled powertools ;;
    esac
    yum update -y
    yum -y install pmix-${PMIX_VERSION}.el${OS_MAJOR_VERSION} hwloc-devel libevent-devel munge-devel
fi

write_component_version "PMIX" ${PMIX_VERSION}
