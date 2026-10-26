#!/bin/bash

set -euo pipefail

phase="${IMAGE_EVIDENCE_PHASE:?IMAGE_EVIDENCE_PHASE must be baseline, inputs, post-build, archive, or cleanup}"
evidence_root="/var/tmp/azhpc-image-evidence"
run_name="${IMAGE_EVIDENCE_RUN_NAME:-build}"
run_dir="${evidence_root}/${run_name}"
archive="/tmp/build-evidence.tgz"
repo_root="/home/${AZHPC_IMAGES_SSH_USERNAME}/azhpc-images"
# Collection shared with azhpc-diagnostics. Packer uploads it before the baseline phase, when the
# repository isn't staged on the VM yet.
collect_lib="${AZHPC_COLLECT_LIB:-/var/tmp/azhpc-collect-lib.sh}"
analyzer="${repo_root}/components/diagnostics/azhpc-diagnostics-analyze.sh"
# Kept in the image so azhpc-diagnostics can tell what the image was built for
# (components/diagnostics/schema/build-manifest.schema.json)
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
        "${run_dir}/post-build" \
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

collect_baseline() {
    create_layout
    load_collect_lib

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

    azc_init "${run_dir}/baseline"
    azc_detect
    azc_collect_os
    azc_collect_hardware
    azc_collect_network
    # jq may not be on the base image yet; the facts are then skipped
    azc_write_facts build build-evidence "${AZC_LIB_VERSION}" '{"phase": "baseline"}'

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

write_build_manifest() {
    local tmp
    tmp=$(mktemp)
    (
        # shellcheck disable=SC1091
        . /etc/os-release
        jq -n \
            --arg image_version "${IMAGE_VERSION:-unknown}" \
            --arg target_vm_size "${TARGET_VM_SIZE:-unknown}" \
            --arg build_vm_size "${BUILD_VM_SIZE:-unknown}" \
            --arg gpu_sku "${GPU_SKU:-unknown}" \
            --arg gpu_platform "${GPU_PLATFORM:-unknown}" \
            --arg target_node_type "${TARGET_NODE_TYPE:-unknown}" \
            --arg built_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
            --arg kernel "$(uname -r)" \
            --arg arch "$(uname -m)" \
            --arg os_id "${ID:-}" \
            --arg os_version_id "${VERSION_ID:-}" \
            --argjson dkms "$(azc_dkms_json)" \
            '{schema_version: "1.0", image_version: $image_version, target_vm_size: $target_vm_size,
              build_vm_size: $build_vm_size, gpu_sku: $gpu_sku, gpu_platform: $gpu_platform,
              target_node_type: $target_node_type, built_at: $built_at, kernel: $kernel, arch: $arch,
              os: {id: $os_id, version_id: $os_version_id}, dkms: $dkms}'
    ) >"${tmp}"
    install -d -m 0755 "$(dirname "${build_manifest}")"
    install -m 0644 "${tmp}" "${build_manifest}"
    rm -f "${tmp}"
    cp "${build_manifest}" "${run_dir}/identity/build-manifest.json"
}

collect_post_build() {
    create_layout
    load_collect_lib

    azc_init "${run_dir}/post-build"
    azc_detect
    azc_collect_os
    azc_collect_hardware
    azc_collect_software_state
    # shellcheck disable=SC2086
    azc_collect_services ${AZC_SERVICES}
    azc_collect_network
    azc_collect_hpc_stack
    if azc_want_amd; then azc_collect_amd; fi
    if azc_want_nvidia; then azc_collect_nvidia; fi

    # jq is installed with the HPC components (absent on skip_hpc builds)
    if command -v jq >/dev/null 2>&1; then
        write_build_manifest
    else
        echo "WARNING: jq is not installed; ${build_manifest} not written" >&2
    fi
    azc_collect_image
    # shellcheck disable=SC2086
    azc_write_facts build build-evidence "${AZC_LIB_VERSION}" '{"phase": "post-build"}' ${AZC_SERVICES}
    if [[ -f "${run_dir}/post-build/facts.json" && -f "${analyzer}" ]]; then
        bash "${analyzer}" "${run_dir}/post-build" || echo "Automated checks failed" >&2
    fi

    if [[ -f /opt/azurehpc/component_versions.txt ]]; then
        cp /opt/azurehpc/component_versions.txt "${run_dir}/identity/component_versions.txt"
    fi
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
    rm -f -- "${archive}" "${archive}.sha256" /var/tmp/azhpc-collect-lib.sh
}

case "${phase}" in
    baseline) collect_baseline ;;
    inputs) collect_inputs ;;
    post-build) collect_post_build ;;
    archive) archive_evidence ;;
    cleanup) cleanup_evidence ;;
    *) echo "Unknown IMAGE_EVIDENCE_PHASE: ${phase}" >&2; exit 2 ;;
esac
