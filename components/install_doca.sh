#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

# Ubuntu 26.04 (Resolute Raccoon): NVIDIA's official DOCA-Host .deb is not
# yet published for kernel 7.0 / Ubuntu resolute, but Canonical ships the
# DOCA-OFED kernel-module source in their universe repo as
# `doca-ofed-26.01-dkms`. That package provides the same MLNX-patched
# ib_core/ib_uverbs/mlx5_ib that nvidia-peermem requires for line-rate
# GDR; functionally it's equivalent to running `mlnxofedinstall
# --kernel-only` from NVIDIA's tarball on older Ubuntu releases.
#
# Differences from the older Ubuntu flow that this branch handles:
#   * No DOCA-Host meta-package yet      -> use Canonical universe DKMS source
#   * No userspace `doca-ofed` package   -> rdma-core / ibverbs-utils etc.
#                                            from Ubuntu universe
#   * No openibd service from Canonical  -> not needed: depmod pre-resolves
#     every IB module name to /lib/modules/$(uname -r)/updates/dkms/
#     (DKMS path wins over the inbox kernel/drivers/infiniband/ path), and
#     the customer VM's first boot loads the DOCA-OFED stack via PCI probe.
#
# One side step is required: NVIDIA's GPU-driver DKMS conftest looks for
# the peer_mem framework symbols in /usr/src/ofa_kernel/default/Module.symvers.
# Canonical's doca-ofed-26.01-dkms `dkms.conf` does not run the upstream
# post-build hook that lays down that symvers tree, so we generate it
# ourselves here. Without this step nvidia-peermem.ko gets built as a
# stub (NV_MLNX_IB_PEER_MEM_SYMBOLS_PRESENT undefined) and modprobe
# returns EINVAL.
if [[ "${DISTRIBUTION}" == "ubuntu26.04" ]]; then
    if command -v add-apt-repository >/dev/null 2>&1; then
        add-apt-repository -y universe || true
    fi
    apt-get update

    # 1. Install the DKMS source package only. The dkms post-install
    #    trigger builds ib_core / ib_uverbs / mlx5_ib / etc. into
    #    /lib/modules/$(uname -r)/updates/dkms/ and re-runs depmod and
    #    update-initramfs.
    #
    #    Do NOT install the prebuilt `linux-modules-doca-ofed-26.01-azure`:
    #    its modules and a fresh DKMS rebuild produce different symbol
    #    CRCs (built in different environments), and mixing them causes
    #    nvidia-peermem to fail loading with
    #    "disagrees about version of symbol ib_register_peer_memory_client".
    apt-get install -y --no-install-recommends doca-ofed-26.01-dkms

    # 2. Userspace IB/RDMA tools from Ubuntu universe (Canonical does not
    #    yet ship a userspace `doca-ofed` for resolute). These give us
    #    ibstat, ibv_devinfo, ibdev2netdev, perftest etc. that the rest of
    #    the pipeline (HPC-X build, persistent-rdma-naming, NHC checks)
    #    expects.
    apt-get install -y --no-install-recommends \
        rdma-core ibverbs-utils ibverbs-providers infiniband-diags perftest \
        libibverbs-dev libibumad-dev librdmacm-dev libibmad-dev

    # 3. Generate Module.symvers and place it where NVIDIA's conftest looks.
    DOCA_DKMS_SRC=$(ls -1d /usr/src/doca-ofed-26.01-dkms-* 2>/dev/null | head -1)
    if [[ -z "${DOCA_DKMS_SRC}" ]]; then
        echo "##[error]install_doca.sh: doca-ofed-26.01-dkms source tree not found under /usr/src" >&2
        exit 1
    fi

    DOCA_BUILD_TMP=$(mktemp -d)
    cp -a "${DOCA_DKMS_SRC}/." "${DOCA_BUILD_TMP}/"
    (
        cd "${DOCA_BUILD_TMP}/mlnx-ofed-kernel"
        ./configure \
            --kernel-version="$(uname -r)" \
            --kernel-sources="/lib/modules/$(uname -r)/build" \
            --with-core-mod \
            --with-user_mad-mod \
            --with-user_access-mod \
            --with-addr_trans-mod \
            --with-mlx5-mod \
            --with-mlxfw-mod \
            --with-ipoib-mod
        make -j"$(nproc)"
    )

    OFA_DST=/usr/src/ofa_kernel-dkms/default
    mkdir -p "${OFA_DST}"
    cp -ar "${DOCA_BUILD_TMP}/mlnx-ofed-kernel/include"        "${OFA_DST}/"
    cp -ar "${DOCA_BUILD_TMP}/mlnx-ofed-kernel"/config*        "${OFA_DST}/"
    cp -ar "${DOCA_BUILD_TMP}/mlnx-ofed-kernel"/compat*        "${OFA_DST}/"
    cp -ar "${DOCA_BUILD_TMP}/mlnx-ofed-kernel"/ofed_scripts   "${OFA_DST}/"
    cp -a  "${DOCA_BUILD_TMP}/mlnx-ofed-kernel"/Module.symvers "${OFA_DST}/"

    mkdir -p /usr/src/ofa_kernel
    update-alternatives --install \
        /usr/src/ofa_kernel/default ofa_kernel_headers "${OFA_DST}" 17

    # Sanity check: peer_mem and dmabuf framework symbols must be visible
    # to NVIDIA's conftest, otherwise nvidia-peermem.ko ships as a stub.
    if ! grep -q 'ib_register_peer_memory_client' "${OFA_DST}/Module.symvers" \
       || ! grep -q 'ib_umem_dmabuf_get_pinned'   "${OFA_DST}/Module.symvers"; then
        echo "##[error]install_doca.sh: peer_mem / dmabuf exports missing from generated Module.symvers" >&2
        exit 1
    fi

    rm -rf "${DOCA_BUILD_TMP}"

    DOCA_OFED_VERSION=$(dpkg-query -W -f='${Version}' doca-ofed-26.01-dkms 2>/dev/null || echo "unknown")
    write_component_version "DOCA" "26.01-canonical"
    write_component_version "OFED" "${DOCA_OFED_VERSION}"

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
