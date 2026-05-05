#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

pmix_metadata=$(get_component_config "pmix")
PMIX_VERSION=$(jq -r '.version' <<< $pmix_metadata)

if [[ $DISTRIBUTION == *"ubuntu"* ]]; then
    UBUNTU_VERSION=$(cat /etc/os-release | grep VERSION_ID | cut -d= -f2 | cut -d\" -f2)

    # Ubuntu 26.04 (Resolute Raccoon): PMC does not yet publish a
    # `slurm-ubuntu-resolute` pool. Rather than fall back to Ubuntu universe
    # (which ships PMIx 5.x as `libpmix-dev`), we install the PMC `pmix_4.2.9-1`
    # .deb out of the noble pool. This keeps U26 nodes wire-compatible at the
    # PMIx layer with the rest of the matrix (RHEL family, Azure Linux, U22,
    # U24 — all on PMC's PMIx 4.2.9), and preserves the /opt/pmix/<version>/
    # install layout that install_mpis.sh expects.
    #
    # All Depends: of pmix_4.2.9-1 are satisfiable from resolute repos:
    #   zlib1g-dev, libc6 (>=2.38), libevent-core-2.1-7t64,
    #   libevent-pthreads-2.1-7t64, libhwloc15, zlib1g
    #
    # The PMC slurm-ubuntu-noble pool is signed with the older Microsoft
    # release-signing key (gpgsecurity@microsoft.com, fingerprint
    # ...EB3E94ADBE1229CF), which is NOT in the keyring shipped with the
    # resolute packages-microsoft-prod.deb. We fetch it from
    # packages.microsoft.com/keys/microsoft.asc and place it in a separate
    # keyring referenced only by the noble sources file.
    #
    # The repo is then pinned so it can ONLY supply the `pmix` package; every
    # other package from packages.microsoft.com via this entry is held at
    # priority -1 (never install). This prevents apt from accidentally pulling
    # noble-built dependencies onto a resolute host.
    #
    # TODO(ubuntu26.04): once PMC publishes slurm-ubuntu-resolute, switch this
    # branch to that pool and drop the legacy-key bootstrap.
    if [ "$UBUNTU_VERSION" == "26.04" ]; then
        apt-get install -y curl gnupg ca-certificates

        # Install legacy MS release-signing key into a dedicated keyring.
        legacy_keyring=/usr/share/keyrings/azhpc-microsoft-legacy.gpg
        if [ ! -f "${legacy_keyring}" ]; then
            tmp_asc=$(mktemp --suffix=.asc)
            curl -fsSL https://packages.microsoft.com/keys/microsoft.asc -o "${tmp_asc}"
            gpg --dearmor --yes -o "${legacy_keyring}" "${tmp_asc}"
            chmod 0644 "${legacy_keyring}"
            rm -f "${tmp_asc}"
        fi

        cat > /etc/apt/sources.list.d/azhpc-pmc-slurm-noble.list <<EOF
deb [arch=${ARCHITECTURE_DISTRO} signed-by=${legacy_keyring}] https://packages.microsoft.com/repos/slurm-ubuntu-noble/ insiders main
EOF

        # Hard pin: the noble pool is allowed to supply ONLY `pmix`.
        cat > /etc/apt/preferences.d/azhpc-pmc-slurm-noble.pref <<'EOF'
Package: *
Pin: origin packages.microsoft.com
Pin-Priority: -1

Package: pmix
Pin: origin packages.microsoft.com
Pin-Priority: 1001
EOF

        apt-get update
        # libevent-dev / libhwloc-dev still come from resolute main/universe;
        # only `pmix` is sourced from the pinned noble pool.
        apt-get install -y pmix libevent-dev libhwloc-dev
        apt-mark hold pmix libevent-dev libhwloc-dev

        PMIX_VERSION=$(dpkg-query -W -f='${Version}' pmix 2>/dev/null || echo "${PMIX_VERSION}")
        write_component_version "PMIX" "${PMIX_VERSION}"
        exit 0
    fi

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
else
    # RHEL-family: AlmaLinux, Rocky Linux, RHEL, etc.
    OS_MAJOR_VERSION=$(sed -n 's/^VERSION_ID="\([0-9]\+\).*/\1/p' /etc/os-release)
    cp ${COMPONENT_DIR}/slurm-repo/slurm-el${OS_MAJOR_VERSION}.repo /etc/yum.repos.d/slurm.repo

    if [ ! -e /etc/yum.repos.d/microsoft-prod.repo ];then
        curl -sSL -O https://packages.microsoft.com/config/rhel/${OS_MAJOR_VERSION}/packages-microsoft-prod.rpm
        rpm -i packages-microsoft-prod.rpm
        rm packages-microsoft-prod.rpm
    fi

    if [[ $OS_MAJOR_VERSION == "9" ]]; then 
        dnf config-manager --set-enabled crb
    elif  [[ $OS_MAJOR_VERSION == "8" ]]; then
        dnf config-manager --set-enabled powertools
    fi
    yum update -y
    yum -y install pmix-${PMIX_VERSION}.el${OS_MAJOR_VERSION} hwloc-devel libevent-devel munge-devel
fi

write_component_version "PMIX" ${PMIX_VERSION}
