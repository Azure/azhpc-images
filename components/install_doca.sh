#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

doca_metadata=$(get_component_config "doca")
DOCA_VERSION=$(jq -r '.version' <<< $doca_metadata)
DOCA_SHA256=$(jq -r '.sha256' <<< $doca_metadata)
DOCA_URL=$(jq -r '.url' <<< $doca_metadata)
DOCA_FILE=$(basename ${DOCA_URL})

download_and_verify $DOCA_URL $DOCA_SHA256

if [[ $DISTRIBUTION == *"ubuntu"* ]]; then
    dpkg -i $DOCA_FILE

    # we prefer distro-shipped dkms and ignore the one from DOCA, unless there is evidence to the contrary
    cat > /etc/apt/preferences.d/doca-dkms-pin <<PIN
Package: dkms
Pin: release l=DOCA-HOST*
Pin-Priority: -1
PIN

    apt-get update

    # doca-ofed strict-pins `openmpi (= <doca-version>)` which pulls in the DOCA-bundled
    # Open MPI .deb. We never use that binary at runtime — HPC-X (installed later by
    # install_mpis.sh) provides Open MPI at /opt — and the .deb ships
    # /etc/pmix-mca-params.conf, colliding with the pmix package installed by
    # install_pmix.sh (pmix >=4.2.9-2 dropped its `Conflicts: openmpi`, so dpkg now
    # aborts with "trying to overwrite /etc/pmix-mca-params.conf").
    #
    # Inhibit the DOCA openmpi by installing an empty equivs marker that
    # `Provides: openmpi (= <doca-version>)`, satisfying doca-ofed's strict-equality
    # dep so apt never pulls in the real openmpi .deb. Same pattern as
    # ucx-provides-libucx0 in install_rocm.sh.
    apt-get install -y equivs
    openmpi_version=$(apt-cache show openmpi 2>/dev/null | awk '/^Version:/ {print $2; exit}')
    if [[ -z "$openmpi_version" ]]; then
        echo "ERROR: could not read openmpi version from DOCA repo" >&2
        exit 1
    fi
    cat > /tmp/hpcx-provides-openmpi <<EOF
Section: misc
Priority: optional
Homepage: https://github.com/Azure/azhpc-images
Standards-Version: 3.9.2

Package: hpcx-provides-openmpi
Provides: openmpi (= ${openmpi_version})
Version: ${openmpi_version}
Maintainer: Azure HPC Platform team <hpcplat@microsoft.com>
Description: marker package to inhibit the DOCA-bundled openmpi
 HPC-X (installed by install_mpis.sh into /opt) provides Open MPI at runtime,
 so the DOCA openmpi .deb is redundant and additionally collides with
 /etc/pmix-mca-params.conf from the separately-installed pmix package.
EOF
    (
        cd /tmp
        equivs-build /tmp/hpcx-provides-openmpi
        dpkg -i /tmp/hpcx-provides-openmpi_*_all.deb
    )
    rm -f /tmp/hpcx-provides-openmpi_*_all.deb /tmp/hpcx-provides-openmpi

    apt-get -y install doca-ofed

    # Mark doca-ofed's dependencies (the OFED userspace + kernel modules) as
    # manually-installed so they survive any subsequent `apt autoremove`.
    # Later components (e.g. install_pmix.sh installing libevent-dev/libhwloc-dev)
    # may remove the doca-ofed meta-package due to conflicts with openmpi, which
    # would otherwise leave the entire OFED stack flagged auto-installed and
    # liable to be swept away by autoremove (e.g. in install_dynolog_drl.sh).
    # Scoped to Ubuntu 22.04 where this conflict has been observed.
    if [[ $DISTRIBUTION == "ubuntu22.04" ]]; then
        DOCA_OFED_DEPS=$(apt-cache depends --recurse --no-recommends --no-suggests \
            --no-conflicts --no-breaks --no-replaces --no-enhances doca-ofed \
            2>/dev/null | awk '/^\w/ {print $1}' | sort -u)
        if [[ -n "$DOCA_OFED_DEPS" ]]; then
            apt-mark manual $DOCA_OFED_DEPS || true
        fi
    fi
elif [[ $DISTRIBUTION == "azurelinux3.0" ]]; then
    rpm -i $DOCA_FILE
    dnf clean all
    dnf install -y doca-extra
    /opt/mellanox/doca/tools/doca-kernel-support
    dnf install -y doca-ofed-userspace
    dnf -y install doca-ofed
else
    # RHEL-family: AlmaLinux, Rocky Linux, RHEL, etc.
    rpm -i $DOCA_FILE
    dnf clean all
    
    # Install DOCA extras for compatibility
    dnf install -y doca-extra
    
    /opt/mellanox/doca/tools/doca-kernel-support
    FINAL_REPO_FILE=$(find /tmp/DOCA.*/ -name 'doca-kernel-repo-*.rpm' -printf '%T@ %p\n' | sort -n | tail -1 | cut -d' ' -f2-)
    rpm -i $FINAL_REPO_FILE
    # Backup
    cp /etc/dnf/dnf.conf /etc/dnf/dnf.conf.bak
    sed -i '/^exclude=/d' /etc/dnf/dnf.conf
    dnf -y install doca-ofed-userspace
    dnf -y install doca-ofed
    # Restore exclusion
    mv /etc/dnf/dnf.conf.bak /etc/dnf/dnf.conf
fi

write_component_version "DOCA" $DOCA_VERSION
OFED_VERSION=$(ofed_info | sed -n '1,1p' | awk -F'-' 'OFS="-" {print $3,$4}' | tr -d ':')
write_component_version "OFED" $OFED_VERSION

# Create systemd drop-in configuration for openibd.service
# This adds restart on failure and ensures it starts after udev settles
mkdir -p /etc/systemd/system/openibd.service.d
cat > /etc/systemd/system/openibd.service.d/override.conf <<EOF
[Unit]
After=systemd-udev-settle.service
Wants=systemd-udev-settle.service

[Service]
Restart=on-failure
RestartSec=5
EOF

if [[ "${NODE_TYPE:-azure-vm}" == "baremetal" ]]; then
    echo -e "\n# Load IPoIB\nIPOIB_LOAD=no" | sudo tee -a /etc/infiniband/openib.conf
fi

# Enable only; do not restart at build time. Restarting openibd here probes
# the build VM's IB hardware (which may be absent on general-purpose build
# SKUs) and is not required before possible tests post-reboot.
systemctl daemon-reload
systemctl enable openibd
