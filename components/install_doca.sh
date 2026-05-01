#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

# Ubuntu 26.04 (Resolute Raccoon): skip DOCA-OFED kmod installation entirely.
# Instead, install the upstream rdma-core userspace tools (ibstat, ibv_devinfo,
# ibdev2netdev, etc.) from Ubuntu universe so the rest of the build pipeline
# (HPC-X inbox build, persistent-rdma-naming, IB sanity checks) has the
# binaries it expects. Kernel-side IB modules are provided by linux-azure.
#
# Note: The Mellanox/NVIDIA-proprietary `ofed_info` tool is NOT shipped by
# Ubuntu, so OFED-version-string-based checks remain skipped on 26.04.
if [[ "${DISTRIBUTION}" == "ubuntu26.04" ]]; then
    echo "##[warning]install_doca.sh: skipping DOCA-OFED kmod installation on Ubuntu 26.04 (using inbox HPC-X + rdma-core userspace)."

    if command -v add-apt-repository >/dev/null 2>&1; then
        add-apt-repository -y universe || true
    fi
    apt-get update

    # Userspace IB/RDMA tools from Ubuntu universe (all confirmed published for
    # resolute as of Apr 2026; no DOCA-Host equivalent on 26.04).
    apt-get install -y --no-install-recommends \
        rdma-core ibverbs-utils ibverbs-providers infiniband-diags \
        libibverbs-dev libibumad-dev librdmacm-dev libibmad-dev

    # Record placeholder component versions so write_component_version's downstream
    # consumers don't choke on missing keys.
    write_component_version "DOCA" "skipped-ubuntu26.04"
    write_component_version "OFED" "inbox-rdma-core"

    exit 0
fi

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
    apt-get -y install doca-ofed
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

systemctl daemon-reload
systemctl enable openibd

/etc/init.d/openibd restart
/etc/init.d/openibd status
error_code=$?
if [ ${error_code} -ne 0 ]
then
    echo "OpenIBD not loaded correctly!"
    exit ${error_code}
fi
