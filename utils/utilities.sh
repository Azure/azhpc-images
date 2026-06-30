#!/bin/bash
############################################################################
# @Brief        : Function to extract component version from the versions.json file
# @Args        : (1) #Component name
# @RetVal       : json node value
# Lookup hierarchy:
#   1. component.distribution.architecture.<TARGET_NODE_TYPE>.<GPU_SKU> (e.g., baremetal_3p.nvidia_gb200)
#   2. component.distribution.architecture.<TARGET_NODE_TYPE>.default
#   3. component.distribution.architecture.<TARGET_NODE_TYPE> (direct config, if not nested by GPU_SKU)
#   4. component.distribution.architecture
#   5. component.common
############################################################################
normalize_component_config_key(){
    echo "$1" | awk '{ value=tolower($0); gsub(/[^a-z0-9]+/, "_", value); print value }'
}

get_component_config(){
    component=$1

    config="null"

    if [[ -n "${GPU:-}" && -n "${SKU:-}" ]]; then
        sku_key=$(normalize_component_config_key "${GPU}_${SKU}")
        node_type_key=$(normalize_component_config_key "${TARGET_NODE_TYPE:-azure_vm_regular}")

        config=$(jq -r '."'"${component}"'"."'"${DISTRIBUTION}"'"."'"${ARCHITECTURE}"'"."'"${node_type_key}"'"."'"${sku_key}"'"' <<< "${COMPONENT_VERSIONS}")

        if [[ "$config" = "null" ]]; then
            config=$(jq -r '."'"${component}"'"."'"${DISTRIBUTION}"'"."'"${ARCHITECTURE}"'"."'"${node_type_key}"'".default' <<< "${COMPONENT_VERSIONS}")
        fi

        if [[ "$config" = "null" ]]; then
            node_type_config=$(jq -r '."'"${component}"'"."'"${DISTRIBUTION}"'"."'"${ARCHITECTURE}"'"."'"${node_type_key}"'"' <<< "${COMPONENT_VERSIONS}")
            if [[ "$node_type_config" != "null" ]]; then
                has_nested_sku_config=$(jq -r 'type == "object" and (has("default") or ([keys[] | (startswith("nvidia_") or startswith("amd_"))] | any))' <<< "$node_type_config")
                if [[ "$has_nested_sku_config" != "true" ]]; then
                    config="$node_type_config"
                fi
            fi
        fi
    fi
    
    # If no SKU-specific config found, try architecture level
    if [[ "$config" = "null" ]]; then
        config=$(jq -r '."'"${component}"'"."'"${DISTRIBUTION}"'"."'"${ARCHITECTURE}"'"' <<< "${COMPONENT_VERSIONS}")
    fi
    
    # If still null, fall back to common
    if [[ "$config" = "null" ]]; then
        config=$(jq -r '."'"${component}"'".common' <<< "${COMPONENT_VERSIONS}")
    fi
    
    echo "$config"
}

############################################################################
# @Brief	: Write the component and its version
#
# @Args		: (1) Component Name
# 			  (2) Version
############################################################################
write_component_version(){
    component=$1
    version=$2

    install_dir="/opt/azurehpc"
    mkdir -p ${install_dir}
    component_versions_json="${install_dir}/component_versions.txt"

    if [ ! -f "${component_versions_json}" ]
    then
        jq -n "{ \"${component}\": \"${version}\" }" > ${component_versions_json}
    else
        component_versions=$(cat "${component_versions_json}")
        echo "${component_versions}" | jq ". + {\"${component}\": \"${version}\"}" > ${component_versions_json}
    fi
    chmod 644 ${component_versions_json}
}

############################################################################
# @Brief	: Download the file and verify its checksum
#
# @Args		: (1) Download URL
# 			  (2) SHA256 CHECKSUM
############################################################################
download_and_verify(){
    DOWNLOAD_URL=$1
    DOWNLOADED_FILE_NAME=$(basename $1)
    FILE_CHECKSUM=$2
    FILE_PATH=$3

    if [ $# -eq 2 ] || [ $# -eq 3 ]
    then
        wget --retry-connrefused --tries=3 --waitretry=5 $DOWNLOAD_URL
        verify_checksum $(readlink -f $DOWNLOADED_FILE_NAME) $FILE_CHECKSUM
        if [ -n "$FILE_PATH" ]; then
            mkdir -p $FILE_PATH
            mv $DOWNLOADED_FILE_NAME $FILE_PATH
        fi
    else
        echo "*** Error - Invalid inputs!"
        return 1
    fi
    return 0
}

# Find and verify checksum
verify_checksum() {
    local checksum=`sha256sum $1 | awk '{print $1}'`
    if [[ $checksum == $2 ]]
    then
        echo "Checksum verified!"
    else
        echo "*** Error - Checksum verification failed"
        return 1
    fi
}

# Private helper that matches NCv6.
function _is_ncv6_sku {
    case "$SKU" in
        NCv6) return 0 ;;
        *)    return 1 ;;
    esac
}

# Private helper that matches current MRC scope.
# MRC currently applies to baremetal_1p regardless of SKU.
function _is_mrc_network {
    [[ "${TARGET_NODE_TYPE:-azure_vm_regular}" == "baremetal_1p" ]]
}

# Return current network mode for this build target.
# Values:
#   - no_rdma: no RDMA-capable fabric (e.g. NCv6)
#   - mrc : MRC network mode (currently baremetal_1p)
#   - ib  : regular InfiniBand-capable path
function sku_network_mode {
    if _is_ncv6_sku; then
        echo "no_rdma"
    elif _is_mrc_network; then
        echo "mrc"
    else
        echo "standard_ib"
    fi
}

# Whether this SKU uses UCX as its MPI transport layer.
# Backward-compatible: only "no_rdma" (NCv6) disables UCX.
function sku_uses_ucx {
    ! [[ "$(sku_network_mode)" == "no_rdma" ]]
}

# Whether this SKU enables ipoib (InfiniBand over IPoIB) for MPI transport.
function sku_uses_ipoib {
    # Current Baremetal_3p nodes are equipped with IB cards but IPoIB is not required by customer.
    [[ "${TARGET_NODE_TYPE:-azure_vm_regular}" != "baremetal_3p" && "$(sku_network_mode)" == "standard_ib" ]]
}

############################################################################
# @Brief    : Idempotently pin packages so 'dnf'/'yum update' won't upgrade
#             them. Maintains a single 'exclude=PKG1 PKG2 ...' line in
#             /etc/dnf/dnf.conf, creating it if absent.
#
# Replaces the legacy
#     sed -i "$ s/$/ PKG/" /etc/dnf/dnf.conf
# pattern, which silently corrupted the last line of dnf.conf (e.g.
# 'skip_if_unavailable=False') on distros/configurations where the
# 'exclude=' line wasn't seeded first (e.g. Rocky/Alma 9.7 with
# LUSTRE_BUILD_FROM_SOURCE=true). A broken pin lets subsequent
# 'yum update -y' upgrade pinned packages -- most critically
# nvidia-fabricmanager, which must match the NVIDIA driver version exactly.
#
# @Args     : One or more package names/globs (e.g. "ucx*" "openmpi").
#             Empty-string arguments are rejected: callers must not pass
#             unset variables or empty array expansions. There is no
#             legitimate "pin nothing" use case -- such a call almost
#             always indicates a bug (e.g. unset $PACKAGE_NAME or an
#             empty mapfile result) and would silently corrupt the
#             'exclude=' line with stray whitespace.
# @Returns  : 0 on success, 0 (no-op) if /etc/dnf/dnf.conf is absent,
#             1 if no non-empty package arguments were provided.
############################################################################
function dnf_pin_packages {
    [[ -f /etc/dnf/dnf.conf ]] || return 0
    local pkgs=()
    local arg
    for arg in "$@"; do
        [[ -n "$arg" ]] && pkgs+=("$arg")
    done
    if [[ ${#pkgs[@]} -eq 0 ]]; then
        echo "dnf_pin_packages: no non-empty package arguments provided (likely an unset variable or empty array)" >&2
        return 1
    fi
    local current="" new=""
    if grep -q '^exclude=' /etc/dnf/dnf.conf; then
        current=$(sed -n 's/^exclude=//p' /etc/dnf/dnf.conf | head -n1)
        new="$current"
        for p in "${pkgs[@]}"; do
            # Skip if already present (whitespace-bounded match).
            case " $current " in
                *" $p "*) continue ;;
            esac
            new="$new $p"
        done
        new="${new# }"
        if [[ "$new" != "$current" ]]; then
            # '|' is safe as a sed delimiter: package globs contain only
            # [A-Za-z0-9._*-], never '|' or '\'.
            sed -i "s|^exclude=.*|exclude=${new}|" /etc/dnf/dnf.conf
        fi
    else
        echo "exclude=${pkgs[*]}" >> /etc/dnf/dnf.conf
    fi
}
