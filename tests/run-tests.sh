#!/bin/bash

# ------------------------------------------------------------------------------
# Script Name : run-tests.sh 
# Description : This script performs initialization and testing for a specified platform.
# Usage       : ./run-tests.sh [PLATFORM] [-a] [-d] [-v]
#
# Sample Usage:
#   ./run-tests.sh 
#   ./run-tests.sh NVIDIA 
#   ./run-tests.sh AMD
#   ./run-tests.sh NVIDIA -a
#   ./run-tests.sh AMD -a
#   ./run-tests.sh NVIDIA -a -d
#   ./run-tests.sh AMD -a -d
#   ./run-tests.sh NVIDIA -v
#
# Arguments:
#   PLATFORM     GPU platform type: "AMD" or "NVIDIA" (default: NVIDIA)
#
# Options:
#   -a           AKS host image mode - run sanity check for AKS host image
#   -d           Debug mode - continue running even if a single test fails
#   -v           Validation pipeline mode - skip build-time only checks
#
# ------------------------------------------------------------------------------
function set_sku_family_hook {
    return 1
}

function pre_test_suite_hook {
    if [[ "$gpu_platform" == "NVIDIA" ]]; then
        ensure_nvidia_fabricmanager_active || exit 1
    fi
    return 0
}

function verify_network_components_hook {
    return 1
}

function should_verify_ompi_installation {
    return 0
}

function test_service {
    local service=$1
    
    case $service in
        check_sku_customization) verify_sku_customization_service;;
        check_nvidia_fabricmanager) verify_nvidia_fabricmanager_service;;
        check_sunrpc_tcp_settings) verify_sunrpc_tcp_settings_service;;
        check_nvidia_imex) verify_nvidia_imex_service;;
        check_nvidia_persistenced) verify_nvidia_persistenced_service;;
        check_azure_persistent_rdma_naming) verify_azure_persistent_rdma_naming_service;;
        *) ;;
    esac
}

function test_component {
    # Print divider
    # echo "----------------------------------------------------------------"
    local component=$1
    
    case $component in
        check_impi_2021) verify_impi_2021_installation;;
        check_impi_2018) verify_impi_2018_installation;;
        check_gdrcopy) verify_gdrcopy_installation;;
        check_nvidia_driver) verify_nvidia_driver_installation;;
        check_cuda) verify_cuda_installation;;
        check_nccl) verify_nccl_installation;;
        check_rocm) verify_rocm_installation;;
        check_rccl) verify_rccl_installation;;
        check_aocl) verify_aocl_installation;;
        check_aocc) verify_aocc_installation;;
        check_docker) verify_docker_installation;;
        check_dcgm) verify_dcgm_installation;;
        check_lustre) verify_lustre_installation;;
        check_nvlink) verify_nvlink_setup;;
        check_nvbandwidth) verify_nvbandwidth_setup;;
        check_nvloom) verify_nvloom_setup;;
        check_mpifileutils) verify_mpifileutils_installation;;
        * ) ;;
    esac
}

# Verify common component installations accross all distros
function verify_common_components {
    # Skip package updates check in validation mode (only run at build time)
    if [[ -z "${validation_mode:-}" ]]; then
        verify_dnf_conf;
        verify_package_updates;
    fi

    if ! verify_network_components_hook; then
        if [[ "$(sku_network_mode)" == "standard_ib" ]]; then
            verify_ofed_installation;
            verify_ib_device_status;
            verify_ib_modules_and_devices;
        fi
    fi

    if [[ "${TARGET_NODE_TYPE:-azure_vm_regular}" == "azure_vm_akshost" ]]; then return; fi

    verify_gcc_installation;
    verify_azcopy_installation;
    verify_hpcx_installation;

    if should_verify_ompi_installation; then
        verify_ompi_installation;
    fi

    verify_pssh_installation;
    if [[ "${SKU_FAMILY:-}" != "gb-family" ]]; then
        # MVAPICH is intentionally not built on Ubuntu 26.04 (libfabric +
        # MVAPICH 4.1 don't compile on resolute's gcc 15; see install_mpis.sh).
        if [[ "$DISTRIBUTION" != "ubuntu26.04" && "$DISTRIBUTION" != "ubuntu26.04-aks" ]]; then
            verify_mvapich2_installation;
        fi
        verify_mkl_installation;
        verify_hpcdiag_installation;
        verify_aznfs_installation;
    fi
}

function initiate_test_suite {
    # Run the common component tests
    verify_common_components

    # Read the variable component test matrix
    readarray -t components <<< "$(jq -r '.components[]' <<< $TEST_MATRIX)"
    for component in "${components[@]}"; do
        test_component $component;
    done

    # Read the variable service test matrix
    readarray -t services <<< "$(jq -r '.services[]' <<< $TEST_MATRIX)"
    for service in "${services[@]}"; do
        test_service $service;
    done
}

# Ensure nvidia-fabricmanager is active on NVSwitch SKUs before running tests.
# On NDv4/NDv5 (NVSwitch) systems, cuInit() returns CUDA_ERROR_SYSTEM_NOT_READY
# until Fabric Manager finishes setting up the NVLink fabric, which would cause
# gdrcopy_sanity (and other CUDA tools) to fail during build-time validation.
# This is a no-op on non-NVSwitch SKUs and idempotent on running VMs.
#
# Note: This script is invoked by the Packer "shell" provisioner as the
# non-root build user (e.g. hpcuser), so any state-changing systemctl call
# must go through sudo or polkit will reject it with "Interactive
# authentication required".
function ensure_nvidia_fabricmanager_active {
    # Match the same SKU set used by verify_nvidia_fabricmanager_service:
    # NDv4 A100 (NVSwitch) and NDv5 H100/H200 (NVSwitch).
    if ! sku_has_nvswitch; then
        return 0
    fi
    if ! systemctl list-unit-files nvidia-fabricmanager.service &>/dev/null; then
        echo "nvidia-fabricmanager.service unit not present; skipping FM start"
        return 0
    fi
    if systemctl is-active --quiet nvidia-fabricmanager.service; then
        return 0
    fi
    echo "Starting nvidia-fabricmanager.service for build-time validation..."
    sudo -n systemctl start nvidia-fabricmanager.service || true
    # Wait up to 60s for FM to reach active state and complete fabric setup.
    local retries=0
    while ! systemctl is-active --quiet nvidia-fabricmanager.service; do
        if (( retries++ >= 60 )); then
            echo "Warning: nvidia-fabricmanager.service did not become active within 60s"
            sudo -n systemctl --no-pager status nvidia-fabricmanager.service || true
            return 0
        fi
        sleep 1
    done
    echo "nvidia-fabricmanager.service is active."
}

function set_test_matrix {
    gpu_platform="NVIDIA"
    if [[ "$#" -gt 0 ]]; then
       GPU_PLAT=$1
       if [[ ${GPU_PLAT} == "AMD" ]]; then
          gpu_platform="AMD"
       elif [[ ${GPU_PLAT} != "NVIDIA" ]]; then
          echo "${GPU_PLAT} is not a valid GPU platform"
          exit 1

       fi
    fi
    test_matrix_file=$(jq -r . $HPC_ENV/test/test-matrix_${gpu_platform}.json)

    # SKU_FAMILY is already derived by set_vm_properties; default to "common".
    local sku="${SKU_FAMILY:-common}"
    local node_type="${TARGET_NODE_TYPE:-azure_vm_regular}"
    # Look up order: distribution -> node_type -> sku/common.
    export TEST_MATRIX=$(jq -r --arg d "$DISTRIBUTION" --arg s "$sku" --arg n "$node_type" \
        '
        (.[$d] // empty)
        | if type == "object" then
            if has($n) then
                .[$n]
                | if type == "object" then
                    if has($s) then .[$s]
                    elif has("common") then .["common"]
                    else empty
                    end
                  else empty
                  end
            else empty
            end
          else empty
          end
        ' <<< "$test_matrix_file")

    if [[ -z "$TEST_MATRIX" ]]; then
        echo "*****No test matrix found for distribution=$DISTRIBUTION sku=$sku node_type=$node_type!*****"
        exit 1
    fi
}

function set_vm_properties {
    # VMSIZE may be pre-set by the caller (e.g. from the environment on baremetal_3p)
    # to avoid Azure IMDS dependency on non-Azure nodes. Otherwise, query IMDS.
    if [[ -z "${VMSIZE:-}" ]]; then
        local metadata_endpoint="http://169.254.169.254/metadata/instance?api-version=2019-06-04"
        local vm_size=$(curl -H Metadata:true $metadata_endpoint | jq -r ".compute.vmSize")
        export VMSIZE=$(echo "$vm_size" | awk '{print tolower($0)}')
    fi
    # Derive SKU_FAMILY from VMSIZE if not already set by the caller (e.g. via
    # set_properties.sh). This ensures SKU_FAMILY is always available to test
    # functions like verify_common_components regardless of caller environment.
    if [[ -z "${SKU_FAMILY:-}" ]]; then
        if ! set_sku_family_hook; then
            case "${VMSIZE}" in
                standard_nd128is*_gb[2-3]00_v6) export SKU_FAMILY="gb-family" ;;
                standard_nc*_rtxpro6000bse_v6)  export SKU_FAMILY="ncv6" ;;
            esac
        fi
    fi
    # DISTRIBUTION is kept as pure OS identity (e.g. ubuntu24.04), no node-type suffixes.
    export DISTRIBUTION=$(. /etc/os-release;echo $ID$VERSION_ID)
}

# Function to set component versions from JSON file
function set_component_versions {
    local component_versions_file=$HPC_ENV/component_versions.txt
    # read and set the component versions
    local component_versions=$(cat ${component_versions_file} | jq -r 'to_entries | .[] | "VERSION_\(.key)=\(.value)"')
    echo "Component versions: $component_versions"

    # Set the component versions based on the keys and values
    while read -r component; do
        if [[ ! -z "$component" ]]; then
            eval "export $component" # Associates component name as variable and version as value
        fi
    done <<< "$component_versions"
}

function set_module_files_path {
    case $ID in
    ubuntu)
        export MODULE_FILES_ROOT="/usr/share/modules/modulefiles"
        ;;
    almalinux|rocky|rhel) 
        export MODULE_FILES_ROOT="/usr/share/Modules/modulefiles"
        ;;
    azurelinux)
        export MODULE_FILES_ROOT="/usr/share/Modules/modulefiles"
        ;;
    * ) ;;
esac
}

# Parse command line arguments
gpu_platform="${1:-NVIDIA}"
shift 2>/dev/null || true

debug_flag=""
validation_mode=""

while getopts "dv" opt; do
    case $opt in
        d)
            debug_flag="-d"
            ;;
        v)
            validation_mode="true"
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            exit 1
            ;;
    esac
done

# Load profile
. /etc/profile
# Set HPC environment — may be pre-set by caller via environment variables.
HPC_ENV="${HPC_ENV:-/opt/azurehpc}"
# Set test definitions
. $HPC_ENV/test/test-definitions.sh
if [[ -f "$HPC_ENV/test/test-overrides.sh" ]]; then
    . $HPC_ENV/test/test-overrides.sh
fi
# Set module files directory
. /etc/os-release
set_module_files_path
# Set component versions
set_component_versions
# Set current SKU and distro
set_vm_properties
# Pre test suite hook for any SKU-specific pre-test setup (e.g. start nvidia-fabricmanager on NVSwitch SKUs)
pre_test_suite_hook
# Set test matrix
set_test_matrix $gpu_platform
# Initiate test suite
if [[ -n "$debug_flag" && "$debug_flag" == "-d" ]]; then export HPC_DEBUG=$debug_flag; else export HPC_DEBUG=; fi 
initiate_test_suite

echo "ALL OK!"
