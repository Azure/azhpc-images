#!/bin/bash

# ------------------------------------------------------------------------------
# Script Name : run-tests.sh 
# Description : This script performs initialization and testing for a specified platform.
# Usage       : ./run-tests.sh  <platform> [aks_host_image_flag] [debug_flag]
#
# Sample Usage:
#   ./run-tests.sh 
#   ./run-tests.sh NVIDIA 
#   ./run-tests.sh AMD
#   ./run-tests.sh NVIDIA -aks-host
#   ./run-tests.sh AMD -aks-host
#   ./run-tests.sh NVIDIA -aks-host -d
#   ./run-tests.sh AMD -aks-host -d
# Arguments   :
#   $1 - Platform type (optional):
#        "AMD" or "NVIDIA"
#        "NVIDIA" when omitted
#
#   $2 - AKS-HOST image flag (optional):
#        Specify "-aks-host" to do sanity check for aks host image.
#        If omitted or not "-aks-host", the script does sanity check for regular vm image.
#
#   $3 - Debug mode flag (optional):
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
        * ) ;;
    esac
}

# Verify common component installations accross all distros
function verify_common_components {
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
    test_matrix_file=$(jq -r . $HPC_ENV/sanity-check/test-matrix_${gpu_platform}.json)

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
    export VMSIZE="standard_nd128isr_ndr_gb200_v6"
    export DISTRIBUTION=$(. /etc/os-release;echo $ID$VERSION_ID)
}

# Function to set component versions from JSON file
function set_component_versions {
    export VERSION_OFED="25.10-1.7.1"
    export VERSION_AZCOPY="10.31.1"
    export VERSION_OMPI="5.0.8"
    export VERSION_NVIDIA="580.105.08"
    export VERSION_DOCKER="29.1.4-1"
    export VERSION_NCCL="2.28.3-1"
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

gpu_platform=$1
aks_host_flag=$2
debug_flag=$3

# Load profile
. /etc/profile
# Set HPC environment
HPC_ENV=/home/hpcgb200
# Set test definitions
. $HPC_ENV/sanity-check/test-definitions.sh
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
