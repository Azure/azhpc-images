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
    # Verify NVIDIA Driver installation
    nvidia-smi
    check_exit_code "Nvidia Driver $nvidia" "Failed to run Nvidia SMI"
    
    # Verify if NVIDIA peer memory module is inserted
    lsmod | grep nvidia_peermem
    check_exit_code "NVIDIA Peer memory module is inserted" "NVIDIA Peer memory module is not inserted!"

    # Verify if CUDA is installed
    nvcc --version
    check_exit_code "CUDA Driver $cuda" "CUDA not installed"
    check_exists "/usr/local/cuda/"
    
    # Verify the compilation of CUDA samples
    /usr/local/cuda/samples/0_Introduction/mergeSort/mergeSort
    check_exit_code "CUDA Samples $cuda" "Failed to perform merge sort using CUDA Samples"
}

function verify_nccl_installation {
    module load mpi/hpcx

    # Check the type of Mellanox card in use
    mellanox_card=$(lspci -nn | grep -m 1 Mellanox | awk '{print $9 " " $10}' | sed 's/\[//' | sed 's/\]//')
    
    # Run NCCL test based on Mellanox card
    case $mellanox_card in
        "ConnectX-3/ConnectX-3 Pro") mpirun -np 4 \
            -x LD_LIBRARY_PATH \
            --allow-run-as-root \
            --map-by ppr:4:node \
            -mca coll_hcoll_enable 0 \
            -x UCX_TLS=tcp \
            -x CUDA_DEVICE_ORDER=PCI_BUS_ID \
            -x NCCL_SOCKET_IFNAME=eth0 \
            -x NCCL_DEBUG=WARN \
            /opt/nccl-tests/build/all_reduce_perf -b1K -f2 -g1 -e 4G;;
        * ) mpirun -np 8 \
            --allow-run-as-root \
            --map-by ppr:8:node \
            -x LD_LIBRARY_PATH=/usr/local/nccl-rdma-sharp-plugins/lib:$LD_LIBRARY_PATH \
            -mca coll_hcoll_enable 0 \
            -x UCX_TLS=tcp \
            -x CUDA_DEVICE_ORDER=PCI_BUS_ID \
            -x NCCL_SOCKET_IFNAME=eth0 \
            -x NCCL_DEBUG=WARN \
            -x NCCL_NET_GDR_LEVEL=5 \
            /opt/nccl-tests/build/all_reduce_perf -b1K -f2 -g1 -e 4G;;
    esac
    check_exit_code "NCCL $nccl" "Failed to run NCCL all reduce perf"
    
    module unload mpi/hpcx
}

function verify_spack_installation {
    spack --version
    check_exit_code "Spack $spack" "Failed to install Spack"
}

function verify_azcopy_installation {
    sudo azcopy --version
    check_exit_code "azcopy $azcopy" "Failed to install azcopy"
}

function verify_mkl_installation {
    intelmkl_path=$(spack location -i intel-oneapi-mkl@$intel_one_mkl)
    check_exists $intelmkl_path
    check_exit_code "Intel Oneapi MKL $intel_one_mkl" "Intel Oneapi MKL installation not found!"
}

function verify_hpcdiag_installation {
    hpcdiag_path="$HPC_ENV/diagnostics/gather_azhpc_vm_diagnostics.sh"
    check_exists $hpcdiag_path
}

# Internal/ external installation of GCC
function verify_gcc_installation {
    gcc --version
    check_exit_code "GCC is installed" "GCC doesn't exist!"
}

# Check module file for the explicit installations
function verify_gcc_modulefile {
    # Verify GCC Software installation path
    check_exists "/opt/gcc-$gcc_version/"
    # Verify GCC module file path
    check_exists "$MODULE_FILES_ROOT/gcc-$gcc_version"
}

function verify_aocl_installation {
    # verify AMD modulefiles
    check_exists "$MODULE_FILES_ROOT/amd/aocl"
    check_exists "/opt/amd/lib/"
    check_exists "/opt/amd/include/"
}

function verify_docker_installation {
    sudo docker pull hello-world
    sudo docker run hello-world
    check_exit_code "NVIDIA Docker $nvidia_docker" "Problem with Docker!"
}

function verify_ipoib_status {
    # Check if the module ib_ipoib is inserted
    lsmod | grep ib_ipoib
    check_exit_code "ib_ipoib module is inserted" "ip_ipoib module not inserted!"

    # Check if ib devices are listed
    ifconfig | grep ib
    check_exit_code "IPoIB is working" "IPoIB is not working!"
}

function verify_dcgm_installation {
    # Verify DCGM package installation
    dpkg -l | grep datacenter-gpu-manager
    check_exit_code "DCGM Installed" "DCGM not installed!"

    # Check if the NVIDIA DCGM service is active
    systemctl is-active --quiet nvidia-dcgm
    check_exit_code "NVIDIA DCGM service is active" "NVIDIA DCGM service is inactive/dead!"
}

function verify_sku_customization_service {
    # Check if the SKU customization service is active
    systemctl is-active --quiet sku-customizations
    check_exit_code "SKU Customization is active" "SKU Customization is inactive/dead!"
}

function verify_nvidia_fabricmanager_service {
    # Check if the SKU customization service is active
    systemctl is-active --quiet nvidia-fabricmanager
    check_exit_code "NVIDIA Fabricmanager is active" "NVIDIA Fabricmanager is inactive/dead!"
}

function test_service {
    service_index=$1
    #######################################################################
    # 0: SKU Customization, 1: NVIDIA Fabricmanager
    #######################################################################
    case $service_index in
        0) verify_sku_customization_service;;
        1) verify_nvidia_fabricmanager_service;;
        *) ;;
    esac
}

function test_component {
    # Print divider
    # echo "----------------------------------------------------------------"
    component_index=$1
    #######################################################################
    # 0: Intel MPI 2021, 1: Intel MPI 2018, 2: NVIDIA and CUDA, 3: NCCL   #
    # 4: GCC module, 5: AOCL, 6: Docker, 7: DCGM
    #######################################################################
    case $component_index in
        0) verify_impi_2021_installation;;
        1) verify_impi_2018_installation;;
        2) verify_cuda_installation;;
        3) verify_nccl_installation;;
        4) verify_gcc_modulefile;;
        5) verify_aocl_installation;;
        6) verify_docker_installation;;
        7) verify_dcgm_installation;;
        * ) ;;
    esac
}

# Verify common component installations accross all distros
function verify_common_components {
    verify_spack_installation;
    verify_gcc_installation;
    verify_azcopy_installation;
    verify_mofed_installation;
    verify_ib_device_status;
    verify_hpcx_installation;
    verify_mvapich2_installation;
    verify_ompi_installation;
    verify_mkl_installation;
    verify_hpcdiag_installation;
    verify_ipoib_status;
}

function initiate_test_suite {
    # Run the common component tests
    verify_common_components

    # Read the variable component test matrix
    components=$(echo ${TEST_MATRIX[0]} | jq -r '.components')
    readarray -d ' ' -t components <<<"${components[0]}"
    for index in "${!components[@]}"; do
        # the component is represented by the index
        # value represents whether to test the component or not (0/1)
        component=${components[$index]}
        # echo "Index: $i, Value: ${TEST_MATRIX[$i]}"
        if [[ $component -eq 1 ]]; then
            test_component $index
        fi
    done

    # Read the variable service test matrix
    services=$(echo ${TEST_MATRIX[0]} | jq -r '.services')
    readarray -d ' ' -t services <<<"${services[0]}"
    for index in "${!services[@]}"; do
        # the service is represented by the index
        # value represents whether to test the service or not (0/1)
        service=${services[$index]}
        # echo "Index: $i, Value: ${TEST_MATRIX[$i]}"
        if [[ $service -eq 1 ]]; then
            test_service $index
        fi
    done
}

function set_test_matrix {
    export distro=$(. /etc/os-release;echo $ID$VERSION_ID)
    # declare -A distro_values=(
    #     # ["distribution"]="check_impi_2021 check_impi_2018 check_cuda check_nccl check_gcc check_aocl check_docker check_dcgm"
    #     ["ubuntu22.04"]="1 0 1 1 0 0 1 1"
    #     # Add more distro mappings here
    # )

    declare -A distro_values=(
        
        # ["distribution"]='{
        #   "components": "check_impi_2021 check_impi_2018 check_cuda check_nccl check_gcc check_aocl check_docker check_dcgm"
        #   "services": "check_sku_customization check_nvidia_fabricmanager"
        #}'

        ["ubuntu22.04"]='{
            "components": "1 0 1 1 0 0 1 1", 
            "services": "1 1"
        }'
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

echo "ALL OK!"
