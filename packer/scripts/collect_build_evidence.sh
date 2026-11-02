#!/bin/bash

set -euo pipefail

phase="${IMAGE_EVIDENCE_PHASE:?IMAGE_EVIDENCE_PHASE must be baseline, inputs, post-build, archive, or cleanup}"
evidence_root="/var/tmp/azhpc-image-evidence"
run_name="${IMAGE_EVIDENCE_RUN_NAME:-build}"
run_dir="${evidence_root}/${run_name}"
archive="/tmp/build-evidence.tgz"
repo_root="/home/${AZHPC_IMAGES_SSH_USERNAME}/azhpc-images"
# Collection shared with azhpc-diagnostics (components/diagnostics). Packer uploads it before the
# baseline phase, when the repository isn't staged on the VM yet.
collect_lib="/var/tmp/azhpc-collect-lib.sh"
# Kept in the image so azhpc-diagnostics can tell what hardware the image was built for
build_manifest="/opt/azurehpc/diagnostics/build-manifest.json"

capture() {
    local output=$1
    shift
    set +e
    "$@" >"${output}" 2>&1
    local rc=$?
    set -e
    printf '%s\n' "${rc}" >"${output}.exit-code"
    return 0
}

capture_shell() {
    local output=$1
    shift
    capture "${output}" bash -o pipefail -c "$*"
}

create_layout() {
    install -d -m 0700 \
        "${run_dir}/identity" \
        "${run_dir}/baseline" \
        "${run_dir}/inputs" \
        "${run_dir}/build" \
        "${run_dir}/health" \
        "${run_dir}/collected" \
        "${run_dir}/summary"
}

load_collect_lib() {
    if [[ ! -r "${collect_lib}" ]]; then
        echo "Missing ${collect_lib}" >&2
        exit 1
    fi
    # shellcheck source-path=SCRIPTDIR/../../components/diagnostics source=azhpc-collect-lib.sh
    source "${collect_lib}"
}

# collect_shared <phase>: the general tier of the collection shared with azhpc-diagnostics, into
# collected/<phase> with the same layout as a diagnostics bundle, plus facts.json and findings.
# Image builds may run on general-purpose VMs, so the hardware tier (InfiniBand and GPU tools)
# isn't used; the analyzer then only runs its general checks.
collect_shared() {
    local phase_name=$1
    load_collect_lib
    azc_init "${run_dir}/collected/${phase_name}"
    azc_collect_os
    azc_collect_platform
    azc_collect_kernel
    azc_collect_software_state
    # shellcheck disable=SC2086
    azc_collect_services ${AZC_SERVICES}
    azc_collect_network
    azc_collect_hpc_stack
    azc_collect_image
    azc_write_facts build build-evidence "${AZC_LIB_VERSION}" phase="${phase_name}"
    azc_analyze
    if [[ -s "${AZC_DIR}/findings.txt" ]]; then
        echo "Findings (${phase_name}):"
        cat "${AZC_DIR}/findings.txt"
    fi
}

collect_baseline() {
    create_layout

    cat >"${run_dir}/identity/build-context.env" <<EOF
IMAGE_VERSION=${IMAGE_VERSION:-unknown}
TARGET_VM_SIZE=${TARGET_VM_SIZE:-unknown}
BUILD_VM_SIZE=${BUILD_VM_SIZE:-unknown}
GPU_SKU=${GPU_SKU:-unknown}
GPU_PLATFORM=${GPU_PLATFORM:-unknown}
TARGET_NODE_TYPE=${TARGET_NODE_TYPE:-unknown}
INTERNAL_BITS_BLOB_NAME=${INTERNAL_BITS_BLOB_NAME:-none}
COLLECTED_AT_UTC=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

    capture "${run_dir}/baseline/uname.txt" uname -a
    capture "${run_dir}/baseline/page-size.txt" getconf PAGESIZE
    capture_shell "${run_dir}/baseline/cmdline.txt" 'cat /proc/cmdline'
    capture "${run_dir}/baseline/os-release.txt" cat /etc/os-release
    capture "${run_dir}/baseline/lsblk.txt" lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL
    capture "${run_dir}/baseline/findmnt.txt" findmnt -R /
    capture "${run_dir}/baseline/df.txt" df -hT
    if command -v dpkg >/dev/null 2>&1; then
        capture "${run_dir}/baseline/architecture.txt" dpkg --print-architecture
    else
        capture "${run_dir}/baseline/architecture.txt" uname -m
    fi
    capture "${run_dir}/baseline/virtualization.txt" systemd-detect-virt

    local metadata_url='http://169.254.169.254/metadata/instance/compute'
    capture_shell "${run_dir}/identity/build-machine-identity.txt" "
        while read -r label path; do
            value=\$(curl -fsS --max-time 5 -H Metadata:true \"${metadata_url}/\${path}?api-version=2025-04-07&format=text\") || value=unavailable
            printf '%s=%s\\n' \"\${label}\" \"\${value}\"
        done <<'EOF'
vm_size vmSize
location location
resource_group resourceGroupName
vm_name name
subscription_id subscriptionId
resource_id resourceId
source_image_id storageProfile/imageReference/id
source_image_publisher storageProfile/imageReference/publisher
source_image_offer storageProfile/imageReference/offer
source_image_sku storageProfile/imageReference/sku
source_image_version storageProfile/imageReference/version
EOF
    "

    collect_shared baseline
}

collect_inputs() {
    create_layout

    if [[ -d "${repo_root}/internal_bits" ]]; then
        (
            cd "${repo_root}/internal_bits"
            find . -type f -printf '%P\n' | LC_ALL=C sort
        ) | tee "${run_dir}/inputs/internal-bits-files.txt"
    fi

    if [[ -f "${repo_root}/versions.json" ]]; then
        capture "${run_dir}/inputs/versions-json.sha256" sha256sum "${repo_root}/versions.json"
    fi
    if [[ -d "${repo_root}/.git" ]]; then
        capture_shell "${run_dir}/identity/source-revision.txt" \
            "git -C '${repo_root}' rev-parse HEAD && git -C '${repo_root}' status --short"
    fi
}

collect_post_build() {
    create_layout

    capture "${run_dir}/build/uname.txt" uname -a
    capture "${run_dir}/build/page-size.txt" getconf PAGESIZE
    capture_shell "${run_dir}/build/boot-config.txt" 'cat /proc/cmdline'
    capture "${run_dir}/build/df.txt" df -hT
    capture "${run_dir}/build/dkms.txt" dkms status
    capture_shell "${run_dir}/build/service-state.txt" \
        'systemctl list-units --type=service --all --no-pager'
    capture_shell "${run_dir}/health/failed-units.txt" \
        'systemctl --failed --no-pager'
    capture_shell "${run_dir}/health/journal-errors.txt" \
        'journalctl -b -p err --no-pager'
    capture_shell "${run_dir}/health/dmesg.txt" 'dmesg -T'

    if command -v dpkg-query >/dev/null 2>&1; then
        capture_shell "${run_dir}/build/packages.tsv" \
            "dpkg-query -W -f='\${Package}\\t\${Version}\\n' | LC_ALL=C sort"
        capture_shell "${run_dir}/build/package-holds.txt" 'apt-mark showhold | LC_ALL=C sort'
        capture_shell "${run_dir}/build/repositories.txt" \
            "grep -RHsE '^[[:space:]]*(deb(-src)?[[:space:]]|Types:|URIs:|Suites:|Components:|Architectures:|Signed-By:[[:space:]]+/)' /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null"
    elif command -v rpm >/dev/null 2>&1; then
        capture_shell "${run_dir}/build/packages.tsv" \
            "rpm -qa --qf '%{NAME}\\t%{EPOCHNUM}:%{VERSION}-%{RELEASE}.%{ARCH}\\n' | LC_ALL=C sort"
        if command -v dnf >/dev/null 2>&1; then
            capture "${run_dir}/build/repositories.txt" dnf repolist --all
            capture "${run_dir}/build/package-holds.txt" dnf versionlock list
        fi
    fi

    if [[ -f /opt/azurehpc/component_versions.txt ]]; then
        cp /opt/azurehpc/component_versions.txt "${run_dir}/identity/component_versions.txt"
    fi

    write_build_manifest
    collect_shared post-build
}

# Records what the image was built for. Kept in the image when azhpc-diagnostics is installed, so
# it can detect an image deployed on hardware it wasn't built for (e.g. NVIDIA image on an AMD VM).
write_build_manifest() {
    local py tmp
    load_collect_lib
    if ! py=$(azc_python); then
        echo "WARNING: Python 3 is not installed; build manifest not written" >&2
        return 0
    fi
    tmp=$(mktemp)
    if ! "${py}" "${AZC_FACTS_SCRIPT}" build-manifest --output "${tmp}" --dkms-status "${run_dir}/build/dkms.txt"; then
        echo "WARNING: failed to write the build manifest" >&2
        rm -f "${tmp}"
        return 0
    fi
    install -m 0644 "${tmp}" "${run_dir}/identity/build-manifest.json"
    if [[ -x /opt/azurehpc/diagnostics/azhpc-diagnostics.sh ]]; then
        install -m 0644 "${tmp}" "${build_manifest}"
    fi
    rm -f "${tmp}"
}

archive_evidence() {
    create_layout
    (
        cd "${run_dir}"
        find . -type f ! -path './summary/SHA256SUMS' |
            LC_ALL=C sort |
            xargs -r sha256sum >summary/SHA256SUMS
    )
    tar -czf "${archive}" -C "${evidence_root}" "${run_name}"
    sha256sum "${archive}" >"${archive}.sha256"
}

cleanup_evidence() {
    case "${run_dir}" in
        /var/tmp/azhpc-image-evidence/*) rm -rf -- "${run_dir}" ;;
        *) echo "Refusing to remove unexpected evidence path: ${run_dir}" >&2; exit 1 ;;
    esac
    rm -f -- "${archive}" "${archive}.sha256" \
        /var/tmp/azhpc-collect-lib.sh /var/tmp/azhpc-diagnostics-facts.py /var/tmp/azhpc-diagnostics-analyze.py
}

case "${phase}" in
    baseline) collect_baseline ;;
    inputs) collect_inputs ;;
    post-build) collect_post_build ;;
    archive) archive_evidence ;;
    cleanup) cleanup_evidence ;;
    *) echo "Unknown IMAGE_EVIDENCE_PHASE: ${phase}" >&2; exit 2 ;;
esac
