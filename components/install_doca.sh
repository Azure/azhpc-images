#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

doca_metadata=$(get_component_config "doca")
DOCA_VERSION=$(jq -r '.version' <<< $doca_metadata)
DOCA_SOURCE=$(jq -r '.source' <<< $doca_metadata)

if [[ "$DOCA_SOURCE" == "private" ]]; then
    DOCA_FILE=$(jq -r '.file' <<< $doca_metadata)
    DOCA_FILE="$TOP_DIR/internal_bits/$DOCA_FILE"
else
    DOCA_URL=$(jq -r '.url' <<< $doca_metadata)
    DOCA_SHA256=$(jq -r '.sha256' <<< $doca_metadata)
    download_and_verify $DOCA_URL $DOCA_SHA256
    DOCA_FILE=$(basename ${DOCA_URL})
fi

configure_mlnx_ofa_kernel_dkms_dpll_patch() {
    local kernel_header=/usr/src/kernels/$(uname -r)/include/linux/dpll.h
    local dkms_conf=/etc/dkms/mlnx-ofa_kernel.conf
    local patch_file=${COMPONENT_DIR}/patches/mlnx-ofa-kernel-dpll-ffo-param.patch
    local patch_dir=/etc/dkms/mlnx-ofa_kernel/patches

    # Alma/Rocky/RHEL 9.8 kernels use Red Hat's newer DPLL ffo_get callback
    # signature, while DOCA 3.2.x / MLNX OFED 25.10 still ships the older one.
    [[ -f "${kernel_header}" ]] || return 0
    grep -q 'struct dpll_ffo_param \*ffo,' "${kernel_header}" || return 0

    mkdir -p "${patch_dir}"
    cp "${patch_file}" "${patch_dir}/dpll-ffo-param.patch"
    cat > "${dkms_conf}" <<'EOF'
PATCH[0]="dpll-ffo-param.patch"
EOF
}

if [[ $DISTRIBUTION == *"ubuntu"* ]]; then
    dpkg -i $DOCA_FILE

    # we prefer distro-shipped dkms and ignore the one from DOCA, unless there is evidence to the contrary
    cat > /etc/apt/preferences.d/doca-dkms-pin <<PIN
Package: dkms
Pin: release l=DOCA-HOST*
Pin-Priority: -1
PIN

    apt-get update

    # Install a single equivs marker package telling apt that HPC-X provides Open MPI,
    # blocking two separate attempts to install an upstream Open MPI .deb:
    #
    #  1. doca-ofed strict-pins `openmpi (= <doca-version>)` which pulls in the
    #     DOCA-bundled Open MPI .deb. We never use that binary at runtime — HPC-X
    #     (installed later by install_mpis.sh) provides Open MPI at /opt — and the
    #     .deb ships /etc/pmix-mca-params.conf, colliding with the pmix package
    #     installed by install_pmix.sh (pmix >=4.2.9-2 dropped its
    #     `Conflicts: openmpi`, so dpkg now aborts with "trying to overwrite
    #     /etc/pmix-mca-params.conf").
    #
    #  2. lustre-tests (pulled in later by install_lustre_client.sh on builds that
    #     build AMLFS kmod from source) depends on `openmpi-bin`, `libopenmpi-dev`,
    #     `openmpi-common`, which would otherwise drag in Canonical's upstream
    #     Open MPI. Canonical's Open MPI is unsuitable for HPC purposes and on
    #     Jammy depends on a vulnerable PMIx with fixes behind the Ubuntu Pro
    #     paywall.
    #
    # We satisfy doca-ofed's strict-equality dep by `Provides: openmpi (= <doca-version>)`,
    # and the unversioned Canonical names with `Provides: openmpi-bin, libopenmpi-dev,
    # openmpi-common`. We additionally `Conflicts:` the Canonical names so any
    # already-installed Canonical Open MPI is removed when the marker is installed.
    # We deliberately do not touch `libopenmpi3` at all: on AMD/ROCm builds,
    # `libopenmpi3t64` is already installed (indirect dep of mivisionx-dev) and
    # provides it. Same pattern as ucx-provides-libucx0 in install_rocm.sh.
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
Provides: openmpi (= ${openmpi_version}), openmpi-bin, libopenmpi-dev, openmpi-common
Conflicts: openmpi-bin, libopenmpi-dev, openmpi-common
Version: ${openmpi_version}
Maintainer: Azure HPC Platform team <hpcplat@microsoft.com>
Description: marker package to indicate that HPC-X provides Open MPI
 HPC-X (installed by install_mpis.sh into /opt) provides Open MPI at runtime,
 so both the DOCA-bundled openmpi .deb and Canonical's upstream openmpi
 packages are redundant. The DOCA openmpi additionally collides with
 /etc/pmix-mca-params.conf from the separately-installed pmix package, and
 Canonical's openmpi on Jammy depends on a vulnerable PMIx with fixes behind
 the Ubuntu Pro paywall.
EOF
    (
        cd /tmp
        equivs-build /tmp/hpcx-provides-openmpi
        dpkg -i /tmp/hpcx-provides-openmpi_*_all.deb
    )
    rm -f /tmp/hpcx-provides-openmpi_*_all.deb /tmp/hpcx-provides-openmpi

    apt-get -y install doca-ofed
    check_dkms_status mlnx-ofed-kernel iser isert srp
else
    # RHEL-family: AlmaLinux, Rocky Linux, RHEL, etc.
    rpm -i $DOCA_FILE
    dnf clean all

    # Backup
    cp /etc/dnf/dnf.conf /etc/dnf/dnf.conf.bak
    sed -i '/^exclude=/d' /etc/dnf/dnf.conf
    configure_mlnx_ofa_kernel_dkms_dpll_patch
    dnf -y install doca-ofed
    check_dkms_status mlnx-ofa_kernel iser isert srp
    # Restore exclusion
    mv /etc/dnf/dnf.conf.bak /etc/dnf/dnf.conf

    # Repo-local exclude (deliberately NOT a global /etc/dnf/dnf.conf
    # pin) so 'dnf check-update' in verify_package_updates only flags
    # legitimate non-conflicting updates -- not the entire DOCA package
    # set. The cuda-rhel9 mft exclude is set in install_nvidiagpudriver.sh
    # at the point cuda-rhel9.repo is added (this repo does not exist yet).
    #
    # EL9.x baseos rdma-core refresh: AlmaLinux/Rocky 9.8 (in 2026-05)
    # split out a brand-new RDMA-core stack with a separate libhns
    # provider and ABI-bumped libibverbs/perftest (IBVERBS_1.15 / HNS_1.0
    # symbols) incompatible with DOCA's libibverbs-2510.0.11-1.el9.
    # Without this exclude, install_pmix.sh's 'yum update -y' aborts with:
    #   cannot install both libibverbs-61.0-2.el9 from baseos and
    #   libibverbs-2510.0.11-1.el9 from @System
    # DOCA's 'doca' (userland) repo provides the only rdma-core stack
    # we want at runtime; baseos must never offer alternatives.
    mapfile -t doca_pkgs < <(
        dnf repoquery --installed --quiet --qf '%{name} %{from_repo}\n' \
            | awk '$2 ~ /^doca/ {print $1}' | sort -u
    )
    if [[ ${#doca_pkgs[@]} -eq 0 ]]; then
        echo "ERROR: no packages found from doca* repos after doca-ofed install" >&2
        exit 1
    fi
    mapfile -t baseos_pkgs < <(
        dnf repoquery --quiet --repo=baseos --qf '%{name}\n' '*' | sort -u
    )
    mapfile -t baseos_conflicts < <(
        comm -12 \
            <(printf '%s\n' "${doca_pkgs[@]}") \
            <(printf '%s\n' "${baseos_pkgs[@]}")
    )
    if [[ ${#baseos_conflicts[@]} -gt 0 ]]; then
        echo "Pinning ${#baseos_conflicts[@]} baseos package(s) shadowed by DOCA: ${baseos_conflicts[*]}"
        dnf config-manager --save \
            --setopt="baseos.excludepkgs=${baseos_conflicts[*]}" \
            >/dev/null
    fi
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

if ! sku_uses_ipoib; then
    echo -e "\n# Load IPoIB\nIPOIB_LOAD=no" | sudo tee -a /etc/infiniband/openib.conf
fi

# Enable only; do not restart at build time. Restarting openibd here probes
# the build VM's IB hardware (which may be absent on general-purpose build
# SKUs) and is not required before possible tests post-reboot.
systemctl daemon-reload
systemctl enable openibd
