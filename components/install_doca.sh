#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

doca_metadata=$(get_component_config "doca")
DOCA_VERSION=$(jq -r '.version' <<< $doca_metadata)
DOCA_SOURCE=$(jq -r '.source' <<< $doca_metadata)
HPCX_DOCA_OFED_DEPS_MARKER=hpcx-provides-doca-ofed-deps

if [[ "$DOCA_SOURCE" == "private" ]]; then
    DOCA_FILE=$(jq -r '.repo_file' <<< $doca_metadata)
    DOCA_SHA256=$(jq -r '.sha256' <<< $doca_metadata)
    DOCA_FILE="$TOP_DIR/internal_bits/$DOCA_FILE"
    verify_checksum "$DOCA_FILE" "$DOCA_SHA256"
else
    DOCA_URL=$(jq -r '.url' <<< $doca_metadata)
    DOCA_SHA256=$(jq -r '.sha256' <<< $doca_metadata)
    download_and_verify $DOCA_URL $DOCA_SHA256
    DOCA_FILE=$(basename ${DOCA_URL})
fi

configure_doca_dkms_patches() {
    local dkms_module=$1
    local dkms_conf=/etc/dkms/${dkms_module}.conf
    local patch_dir=/etc/dkms/${dkms_module}/patches

    mkdir -p "${patch_dir}"
    # V100's proprietary nvidia-peermem cannot use GPL-only exports.
    if [[ "${SKU}" != "V100" ]]; then
        cp "${COMPONENT_DIR}/patches/mlnx-ofa-kernel-peer-mem-gpl.patch" "${patch_dir}/peer-mem-gpl.patch"
        cat > "${dkms_conf}" <<'EOF'
PATCH+=("peer-mem-gpl.patch")
EOF
    fi
}

configure_mlnx_ofed_kernel_dkms_xdp_patch() {
    local module_version=25.10.OFED.25.10.3.1.8.1-1
    local dkms_conf=/etc/dkms/mlnx-ofed-kernel-${module_version}.conf
    local patch_dir=/etc/dkms/mlnx-ofed-kernel/patches

    [[ "${DISTRIBUTION}" == "ubuntu22.04" && "${DOCA_VERSION}" == "3.2.3" ]] || return 0

    # TODO: Remove when DOCA fixes detection of partially backported XDP APIs.
    # Install even on older kernels so subsequent DKMS rebuilds get the fix.
    mkdir -p "${patch_dir}"
    cp "${COMPONENT_DIR}/patches/mlnx-ofed-kernel-xdp-fragments.patch" "${patch_dir}/xdp-fragments.patch"
    # Append after the optional module-wide PeerDirect patch, without index gaps.
    cat > "${dkms_conf}" <<'EOF'
PATCH+=("xdp-fragments.patch")
EOF
    # install_cuda_repo_and_dkms.sh provides support for /etc/dkms patch overlays.
}

install_hpcx_doca_ofed_deps_apt_marker() {
    local marker_control=/tmp/${HPCX_DOCA_OFED_DEPS_MARKER}
    local openmpi_version=""
    local sharp_provides=""
    local sharp_version=""
    local ucx_version=""

    # Install a single equivs marker package telling apt that HPC-X provides the
    # MPI-adjacent libraries that DOCA would otherwise install from its OFED repo.
    # This blocks two separate attempts to install an upstream Open MPI .deb:
    #
    #  1. doca-ofed strict-pins `openmpi (= <doca-version>)` which pulls in the
    #     DOCA-bundled Open MPI .deb. We never use that binary at runtime -- HPC-X
    #     (installed later by install_mpis.sh) provides Open MPI at /opt -- and the
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
    # The same marker also provides DOCA's strict `ucx` dependency and, before
    # DOCA 3.3.0, its `sharp` dependency so apt does not install the DOCA-bundled
    # copies. HPC-X is installed later by install_mpis.sh; on AMD builds,
    # install_mpis.sh rebuilds HPC-X UCX with ROCm support before ROCm components
    # use it.
    apt-get install -y equivs
    openmpi_version=$(apt-cache show openmpi 2>/dev/null | awk '/^Version:/ {print $2; exit}')
    if [[ -z "$openmpi_version" ]]; then
        echo "ERROR: could not read openmpi version from DOCA repo" >&2
        exit 1
    fi
    ucx_version=$(apt-cache show ucx 2>/dev/null | awk '/^Version:/ {print $2; exit}')
    if [[ -z "$ucx_version" ]]; then
        echo "ERROR: could not read ucx version from DOCA repo" >&2
        exit 1
    fi
    if dpkg --compare-versions "${DOCA_VERSION}" lt 3.3.0; then
        sharp_version=$(apt-cache show sharp 2>/dev/null | awk '/^Version:/ {print $2; exit}')
        if [[ -z "$sharp_version" ]]; then
            echo "ERROR: could not read sharp version from DOCA repo" >&2
            exit 1
        fi
        sharp_provides=", sharp (= ${sharp_version})"
    fi
    cat > "${marker_control}" <<EOF
Section: misc
Priority: optional
Homepage: https://github.com/Azure/azhpc-images
Standards-Version: 3.9.2

Package: ${HPCX_DOCA_OFED_DEPS_MARKER}
Provides: openmpi (= ${openmpi_version}), openmpi-bin, libopenmpi-dev, openmpi-common, ucx (= ${ucx_version}), libucx0${sharp_provides}
Conflicts: openmpi-bin, libopenmpi-dev, openmpi-common
Version: ${DOCA_VERSION}
Maintainer: Azure HPC Platform team <hpcplat@microsoft.com>
Description: marker package to indicate that HPC-X provides DOCA OFED dependencies
 HPC-X (installed by install_mpis.sh into /opt) provides Open MPI, UCX, and
 SHARP at runtime, so the DOCA-bundled openmpi and ucx packages are redundant.
 Before DOCA 3.3.0, the bundled sharp package is redundant too. The DOCA
 openmpi collides with /etc/pmix-mca-params.conf from the separately-installed
 pmix package, Canonical's Open MPI can pull unsuitable PMIx dependencies, and
 older DOCA SHARP packages can inject stale libtool dependencies on DOCA UCX
 paths under /usr/lib. The libucx0 virtual provide also satisfies later
 Ubuntu/ROCm dependency chains that require libucx0.
EOF
    (
        cd /tmp
        equivs-build "${marker_control}"
        apt install -y /tmp/${HPCX_DOCA_OFED_DEPS_MARKER}_*_all.deb
    )
    rm -f /tmp/${HPCX_DOCA_OFED_DEPS_MARKER}_*_all.deb "${marker_control}"
}

install_hpcx_doca_ofed_deps_rpm_marker() {
    if ! command -v rpmbuild >/dev/null 2>&1; then
        dnf -y install rpm-build
    fi

    local rpm_topdir=/tmp/${HPCX_DOCA_OFED_DEPS_MARKER}-rpmbuild
    local spec_file=${rpm_topdir}/SPECS/${HPCX_DOCA_OFED_DEPS_MARKER}.spec
    local marker_rpm=""
    local provides=()

    rm -rf "${rpm_topdir}"
    mkdir -p "${rpm_topdir}"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
    mapfile -t provides < <(
        dnf repoquery --quiet --requires doca-ofed \
            | awk '
                $1 ~ /^(openmpi|sharp|hcoll|mpitests_openmpi|ucx|ucx-cma|ucx-devel|ucx-ib|ucx-ib-mlx5|ucx-knem|ucx-rdmacm|ucx-xpmem)$/ {
                    if ($2 ~ /^[<>=]+$/ && $3 != "") {
                        print $1 " = " $3
                    } else {
                        print $1
                    }
                }' \
            | sort -u
    )
    if [[ ${#provides[@]} -eq 0 ]]; then
        echo "ERROR: could not derive DOCA OFED Open MPI/UCX/SHARP RPM dependencies" >&2
        exit 1
    fi

    cat > "${spec_file}" <<EOF
Name: ${HPCX_DOCA_OFED_DEPS_MARKER}
Version: ${DOCA_VERSION}
Release: 1
Summary: Marker package to indicate that HPC-X provides DOCA OFED dependencies
License: MIT
BuildArch: noarch
EOF
    printf 'Provides: %s\n' "${provides[@]}" >> "${spec_file}"
    cat >> "${spec_file}" <<'EOF'

%description
HPC-X, installed later by install_mpis.sh into /opt, provides the Open MPI,
UCX, HCOLL, and SHARP runtime stack used by this image. This marker package
satisfies DOCA OFED RPM dependencies that would otherwise install the
DOCA-bundled MPI-adjacent packages.

%prep

%build

%install
mkdir -p %{buildroot}/usr/share/doc/%{name}
cat > %{buildroot}/usr/share/doc/%{name}/README <<'README'
HPC-X provides the MPI-adjacent DOCA OFED dependencies for this image.
README

%files
/usr/share/doc/%{name}/README
EOF

    rpmbuild --define "_topdir ${rpm_topdir}" -bb "${spec_file}"
    marker_rpm=$(find "${rpm_topdir}/RPMS" -type f -name "${HPCX_DOCA_OFED_DEPS_MARKER}-*.rpm" | head -n1)
    if [[ -z "${marker_rpm}" ]]; then
        echo "ERROR: failed to build ${HPCX_DOCA_OFED_DEPS_MARKER} marker RPM" >&2
        exit 1
    fi
    rpm -Uvh --replacepkgs "${marker_rpm}"
    rm -rf "${rpm_topdir}"
}

if [[ $DISTRIBUTION == *"ubuntu"* ]]; then
    apt install -y "$(realpath "${DOCA_FILE}")"

    # Prefer CUDA repo's newer dkms and ignore the older copy from DOCA.
    cat > /etc/apt/preferences.d/doca-dkms-pin <<PIN
Package: dkms
Pin: release l=DOCA-HOST*
Pin-Priority: -1
PIN

    apt-get update
    install_hpcx_doca_ofed_deps_apt_marker
    configure_doca_dkms_patches mlnx-ofed-kernel
    configure_mlnx_ofed_kernel_dkms_xdp_patch
    apt-get -y install doca-ofed
    check_dkms_status mlnx-ofed-kernel iser isert srp
elif [[ $DISTRIBUTION == "azurelinux3.0" ]]; then
    download_and_verify $DOCA_URL $DOCA_SHA256
    rpm -i $DOCA_FILE
    dnf clean all
    install_hpcx_doca_ofed_deps_rpm_marker
    dnf -y install doca-ofed
else
    # RHEL-family: AlmaLinux, Rocky Linux, RHEL, etc.
    rpm -i $DOCA_FILE
    dnf clean all

    # Backup
    cp /etc/dnf/dnf.conf /etc/dnf/dnf.conf.bak
    sed -i '/^exclude=/d' /etc/dnf/dnf.conf
    install_hpcx_doca_ofed_deps_rpm_marker
    configure_doca_dkms_patches mlnx-ofa_kernel
    baseos_repo=baseos
    if [[ $DISTRIBUTION == rhel* ]]; then
        rhel_version=${DISTRIBUTION#rhel}
        baseos_repo=rhel-${rhel_version%%.*}-for-${ARCHITECTURE}-baseos-rhui-rpms
    fi
    dnf -y install --setopt="${baseos_repo}.excludepkgs=perftest" doca-ofed
    check_dkms_status mlnx-ofa_kernel iser isert srp
    # Restore exclusion
    mv /etc/dnf/dnf.conf.bak /etc/dnf/dnf.conf

    # Keep the DOCA stack together across OS repos: BaseOS supplies rdma-core
    # and opensm-libs, CRB supplies opensm-devel, and AppStream supplies rshim.
    # Repo-local exclusions leave unrelated OS updates and DOCA updates available.
    if ! installed_doca_pkgs=$(dnf repoquery --installed --quiet --qf '%{name} %{from_repo}\n'); then
        echo "ERROR: could not query installed DOCA packages" >&2
        exit 1
    fi
    mapfile -t doca_pkgs < <(awk '$2 ~ /^doca/ {print $1}' <<< "${installed_doca_pkgs}" | sort -u)
    if [[ ${#doca_pkgs[@]} -eq 0 ]]; then
        echo "ERROR: no packages found from doca* repos after doca-ofed install" >&2
        exit 1
    fi
    # Include already-excluded candidates so reruns preserve the protection.
    if ! available_doca_pkgs=$(dnf repoquery --available --quiet --disableexcludes=all \
        --qf '%{repoid} %{name}\n' "${doca_pkgs[@]}"); then
        echo "ERROR: could not query OS alternatives to DOCA packages" >&2
        exit 1
    fi
    os_conflicts=$(awk '
        $1 ~ /^(baseos|appstream|crb|powertools)$/ ||
        $1 ~ /^rhel-[0-9]+-for-.+-(baseos|appstream)-rhui-rpms$/ ||
        $1 ~ /^codeready-builder-for-rhel-[0-9]+-.+-rhui-rpms$/ {
            print $1, $2
        }' <<< "${available_doca_pkgs}" | sort -u)
    mapfile -t os_repos < <(
        awk 'NF == 2 {print $1}' <<< "${os_conflicts}" | sort -u
    )
    for os_repo in "${os_repos[@]}"; do
        mapfile -t repo_conflicts < <(
            awk -v repo="${os_repo}" '$1 == repo {print $2}' <<< "${os_conflicts}"
        )
        if ! repo_config=$(dnf config-manager --dump "${os_repo}"); then
            echo "ERROR: could not read exclusions for ${os_repo}" >&2
            exit 1
        fi
        existing_excludes=$(awk '/^excludepkgs[[:space:]]*=/ {sub(/^[^=]*=[[:space:]]*/, ""); print}' <<< "${repo_config}")
        echo "Excluding ${#repo_conflicts[@]} ${os_repo} package(s) shadowed by DOCA: ${repo_conflicts[*]}"
        dnf config-manager --save \
            --setopt="${os_repo}.excludepkgs=${existing_excludes:+${existing_excludes} }${repo_conflicts[*]}" \
            >/dev/null
    done
fi

write_component_version "DOCA" $DOCA_VERSION
# DOCA >= 3.6 (OFED 26.10) no longer ships ofed_info; fall back to the mlnx-ofa_kernel package version.
if command -v ofed_info >/dev/null 2>&1; then
    OFED_VERSION=$(ofed_info | sed -n '1,1p' | awk -F'-' 'OFS="-" {print $3,$4}' | tr -d ':')
elif [[ $DISTRIBUTION == *"ubuntu"* ]]; then
    OFED_VERSION=$(dpkg-query -W -f='${Version}' mlnx-ofed-kernel-utils 2>/dev/null || true)
else
    OFED_VERSION=$(rpm -q --qf '%{VERSION}-%{RELEASE}' mlnx-ofa_kernel 2>/dev/null || true)
fi
if [[ -z "${OFED_VERSION}" ]]; then
    echo "ERROR: unable to determine OFED version" >&2
    exit 1
fi
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
