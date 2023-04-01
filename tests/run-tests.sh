#!/bin/bash
set -e

# check if the file is present
function check_exists {
    ls $1
    if [ $? -eq 0 ]
    then
        echo "$1 [OK]"
    else
        echo "*** Error - $1 not found!" >&2
        exit -1
    fi
}

# check exit code
function check_exit_code {
    if [ $? -eq 0 ]
    then
        echo "[OK] : $1"
    else
        echo "*** Error - $2!" >&2
        exit -1
    fi
}

# verify MOFED installation
function verify_mofed_installation {
    # verify MOFED installation
    ofed_info | grep $mofed
    check_exit_code "MOFED installed" "MOFED not installed"
}

# verify IB device status
function verify_ib_device_status {
    # verify IB device is listed
    lspci | grep "Infiniband controller\|Network controller"
    check_exit_code "IB device is listed" "IB device not found"

    # verify IB device is up
    ibstatus | grep "LinkUp"
    check_exit_code "IB device state: LinkUp" "IB link not up"
}

function verify_hpcx_installation {
    check_exists "$MODULE_FILES_ROOT/mpi/hpcx"
    
    module load mpi/hpcx
    local hpcx_omb_path=$MPI_HOME/tests/osu-micro-benchmarks-5.8
    mpirun -np 2 --map-by ppr:2:node -x UCX_TLS=rc $hpcx_omb_path/osu_latency
    check_exit_code "HPC-X $hpcx" "Failed to run HPC-X"
    module unload mpi/hpcx
    module purge
}

function verify_mvapich2_installation {
    check_exists "$MODULE_FILES_ROOT/mpi/mvapich2"

    module load mpi/mvapich2
    # Env MV2_FORCE_HCA_TYPE=22 explicitly selects EDR
    local mvapich2_omb_path=$MPI_HOME/libexec/osu-micro-benchmarks/mpi/pt2pt
    mpiexec -np 2 -ppn 2 -env MV2_USE_SHARED_MEM=0  -env MV2_FORCE_HCA_TYPE=22  $mvapich2_omb_path/osu_latency
    check_exit_code "MVAPICH2 $mvapich2" "Failed to run MVAPICH2"
    module unload mpi/mvapich2
}

function verify_impi_2021_installation {
    check_exists "$MODULE_FILES_ROOT/mpi/impi-2021"
    
    module load mpi/impi-2021
    mpiexec -np 2 -ppn 2 -env FI_PROVIDER=mlx -env I_MPI_SHM=0 $MPI_BIN/IMB-MPI1 pingpong
    check_exit_code "Intel MPI 2021 $impi_2021" "Failed to run Intel MPI 2021"
    module unload mpi/impi-2021
}

function verify_impi_2018_installation {
    # This needs modification
    check_exists "$MODULE_FILES_ROOT/mpi/impi"

    module load mpi/impi
    mpiexec -np 2 -ppn 2 -env I_MPI_FABRICS=ofa ${IMPI2018_PATH}/linux/mpi/intel64/bin/IMB-MPI1 pingpong
    check_exit_code "Intel MPI 2018: $impi_2018" "Failed to run Intel MPI 2018"
    module unload mpi/impi
}

function verify_ompi_installation {
    check_exists "$MODULE_FILES_ROOT/mpi/openmpi"
    openmpi_path=$(spack location -i openmpi@$ompi)
    check_exists $openmpi_path
    check_exit_code "Open MPI $ompi" "Failed to run Open MPI"
}

function verify_cuda_installation {
    nvidia-smi
    check_exit_code "Nvidia Driver $nvidia" "Failed to run Nvidia SMI"
    nvcc --version
    check_exit_code "CUDA Driver $cuda" "CUDA not installed"
    check_exists "/usr/local/cuda/"
    /usr/local/cuda/samples/0_Introduction/mergeSort/mergeSort
    check_exit_code "CUDA Samples $cuda" "Failed to perform merge sort using CUDA Samples"
}

function test_component {
    component_index=$1
    #######################################################################
    # 0: mofed, 1: hpcx, 2: mvapich2, 3: impi_2021, 4: impi_2018. 5: ompi #
    # 6: cuda
    #######################################################################
    case $component_index in
    0) verify_mofed_installation; verify_ib_device_status;;
    1) verify_hpcx_installation;;
    2) verify_mvapich2_installation;;
    3) verify_impi_2021_installation;;
    4) verify_impi_2018_installation;;
    5) verify_ompi_installation;;
    6) verify_cuda_installation;;
    * ) ;;
esac
}

function initiate_test_suite {
    readarray -d ' ' -t TEST_MATRIX <<<"${TEST_MATRIX[0]}"
    for index in "${!TEST_MATRIX[@]}"; do
        # the component is represented by the index
        # value represents whether to test the component or not
        component=${TEST_MATRIX[$index]}
        # echo "Index: $i, Value: ${TEST_MATRIX[$i]}"
        if [[ $component -eq 1 ]]; then
            test_component $index
        fi
    done
}

function set_test_matrix {
    export distro=$(. /etc/os-release;echo $ID$VERSION_ID)
    declare -A distro_values=(
        # ["distribution"]="check_mofed check_hpcx check_mvapich2 check_impi_2021 check_impi_2018 check_ompi check_cuda"
        ["ubuntu22.04"]="1 1 1 1 0 1 1"
        # Add more distro mappings here
    )

    if [[ ! -n "${distro_values[$distro]}" ]]; then
        echo "*****No test matrix found for distribution $distro!*****"
        exit 1
    fi
    export TEST_MATRIX=("${distro_values[$distro]}")
}

# Function to set component versions from JSON file
function set_component_versions {
    local component_versions_file=$HPC_ENV/component_versions.json
    # read and set the component versions
    local component_versions=$(cat "$component_versions_file" | jq -r 'to_entries | .[] | "\(.key)=\(.value)"')

    # Set the component versions based on the keys and values
    while read -r component; do
        if [[ ! -z "$component" ]]; then
            eval "export $component" # Associates component name as variable and version as value
        fi
    done <<< "$component_versions"
}

function set_module_files_path {
    . /etc/os-release
    case $ID in
    ubuntu)
        export MODULE_FILES_ROOT="/usr/share/modules/modulefiles"
        ;;
    centos | almalinux) 
        export MODULE_FILES_ROOT="/usr/share/Modules/modulefiles"
        ;;
    * ) ;;
esac
}

# Set HPC environment
HPC_ENV=/opt/azurehpc
# Set module files directory
set_module_files_path
# Set component versions
set_component_versions
# Set test matrix
set_test_matrix
# Initiate test suite
initiate_test_suite
