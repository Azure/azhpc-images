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
function test_service {
    local service=$1
    
    case $service in
        check_sku_customization) verify_sku_customization_service;;
        check_nvidia_fabricmanager) verify_nvidia_fabricmanager_service;;
        check_sunrpc_tcp_settings) verify_sunrpc_tcp_settings_service;;
        check_nvidia_imex) verify_nvidia_imex_service;;
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
    verify_package_updates;
    verify_ofed_installation;
    verify_ib_device_status;
    verify_ib_modules_and_devices;
    if [[ "$DISTRIBUTION" == *-aks ]]; then return; fi
    verify_gcc_installation;
    verify_azcopy_installation;
    verify_hpcx_installation;
    verify_ompi_installation;
    verify_pssh_installation;
    if [[ "$VMSIZE" != "standard_nd128isr_ndr_gb200_v6" && "$VMSIZE" != "standard_nd128isr_gb300_v6" ]]; then
        verify_mvapich2_installation;
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

    case ${VMSIZE} in
        standard_nd128isr_ndr_gb200_v6|standard_nd128isr_gb300_v6) sku="gb-family";;
        *) sku="common";;
    esac
    export TEST_MATRIX=$(jq -r --arg d "$DISTRIBUTION" --arg s "$sku" '(.[$d] // empty) | (.[$s] // empty)' <<< "$test_matrix_file")

    if [[ -z "$TEST_MATRIX" ]]; then
        echo "*****No test matrix found for sku $sku and distribution $DISTRIBUTION!*****"
        exit 1
    fi
}

function set_vm_properties {
    aks_host=$1
    local metadata_endpoint="http://169.254.169.254/metadata/instance?api-version=2019-06-04"
    local vm_size=$(curl -H Metadata:true $metadata_endpoint | jq -r ".compute.vmSize")
    export VMSIZE=$(echo "$vm_size" | awk '{print tolower($0)}')
    if [ "$aks_host" != "-aks-host" ]; then
        export DISTRIBUTION=$(. /etc/os-release;echo $ID$VERSION_ID)
    else
        export DISTRIBUTION=$(. /etc/os-release;echo $ID$VERSION_ID)-aks
    fi
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
    almalinux) 
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

aks_host_flag=""
debug_flag=""
validation_mode=""

while getopts "adv" opt; do
    case $opt in
        a)
            aks_host_flag="-aks-host"
            ;;
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
# Set HPC environment
HPC_ENV=/opt/azurehpc
# Set test definitions
. $HPC_ENV/test/test-definitions.sh
# Set module files directory
. /etc/os-release
set_module_files_path
# Set component versions
set_component_versions
# Set current SKU and distro
set_vm_properties $aks_host_flag
# Set test matrix
set_test_matrix $gpu_platform
# Initiate test suite
if [[ -n "$debug_flag" && "$debug_flag" == "-d" ]]; then export HPC_DEBUG=$debug_flag; else export HPC_DEBUG=; fi 
initiate_test_suite

echo "ALL OK!"
