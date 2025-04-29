#!/bin/bash

# ------------------------------------------------------------------------------
# Script Name : example.sh
# Description : This script performs initialization and testing for a specified platform.
# Usage       : ./example.sh <platform> [debug_flag]
#
# Sample Usage:
#   ./run-tests.sh 
#   ./example.sh NVIDIA -d
#   ./example.sh AMD -d

# Arguments   :
#   $1 - Platform type (optional):
#        "AMD" or "NVIDIA"
#        "NVIDIA" when omitted
#
#   $2 - Debug mode flag (optional):
#        Specify "-d" to enable debug mode. 
#        In debug mode, the script continues running even if a single test fails.
#        If omitted or not "-d", the script runs in normal mode (strict failure handling).

# ------------------------------------------------------------------------------
function test_service {
    local service=$1
    
    case $service in
        check_sku_customization) verify_sku_customization_service;;
        check_nvidia_fabricmanager) verify_nvidia_fabricmanager_service;;
        check_sunrpc_tcp_settings) verify_sunrpc_tcp_settings_service;;
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
        check_cuda) verify_cuda_installation;;
        check_nccl) verify_nccl_installation;;
	check_rocm) verify_rocm_installation;;
        check_rccl) verify_rccl_installation;;
        check_gcc) verify_gcc_modulefile;;
        check_aocl) verify_aocl_installation;;
        check_aocc) verify_aocc_installation;;
        check_docker) verify_docker_installation;;
        check_dcgm) verify_dcgm_installation;;
        * ) ;;
    esac
}

# Verify common component installations accross all distros
function verify_common_components {
    verify_package_updates;
    verify_gcc_installation;
    verify_azcopy_installation;
    verify_ofed_installation;
    verify_ib_device_status;
    verify_hpcx_installation;
    verify_mvapich2_installation;
    verify_ompi_installation;
    verify_mkl_installation;
    verify_hpcdiag_installation;
    verify_ipoib_status;
    verify_lustre_installation;
    verify_pssh_installation;
    verify_aznfs_installation;
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
    export distro=$(. /etc/os-release;echo $ID$VERSION_ID)
    test_matrix_file=$(jq -r . $HPC_ENV/test/test-matrix_${gpu_platform}.json)
    export TEST_MATRIX=$(jq -r '."'"$distro"'" // empty' <<< $test_matrix_file)

    if [[ -z "$TEST_MATRIX" ]]; then
        echo "*****No test matrix found for distribution $distro!*****"
        exit 1
    fi
}

function set_sku_configuration {
    local metadata_endpoint="http://169.254.169.254/metadata/instance?api-version=2019-06-04"
    local vm_size=$(curl -H Metadata:true $metadata_endpoint | jq -r ".compute.vmSize")
    export VMSIZE=$(echo "$vm_size" | awk '{print tolower($0)}')
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
# Set current SKU
set_sku_configuration
# Set test matrix
set_test_matrix $1
# Initiate test suite
if [[ -n "$2" && "$2" == "-d" ]]; then export HPC_DEBUG=$2; else export HPC_DEBUG=; fi 
initiate_test_suite

echo "ALL OK!"
