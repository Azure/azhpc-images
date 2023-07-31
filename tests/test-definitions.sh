#!/bin/bash

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
    exit_code=$?
    if [ $exit_code -eq 0 ]
    then
        echo "[OK] : $1"
    else
        echo "*** Error - $2!" >&2
        echo "*** Failed with exit code - $exit_code" >&2
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
    local openmpi_path=$(spack location -i openmpi@$ompi)
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
    # Print nccl.conf if it exists
    if test -f /etc/nccl.conf; then
        cat /etc/nccl.conf
    fi

    module load mpi/hpcx

    case $VMSIZE in
        standard_nc24rs_v3) mpirun -np 4 \
            -x LD_LIBRARY_PATH \
            --allow-run-as-root \
            --map-by ppr:4:node \
            -mca coll_hcoll_enable 0 \
            -x UCX_TLS=tcp \
            -x CUDA_DEVICE_ORDER=PCI_BUS_ID \
            -x NCCL_SOCKET_IFNAME=eth0 \
            -x NCCL_DEBUG=WARN \
            /opt/nccl-tests/build/all_reduce_perf -b1K -f2 -g1 -e 4G;;
        standard_nd40rs_v2 | standard_nd96*v4 | standard_nc*ads_a100_v4) mpirun -np 8 \
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
        *) ;;
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
    local intelmkl_path=$(spack location -i intel-oneapi-mkl@$intel_one_mkl)
    check_exists $intelmkl_path
    check_exit_code "Intel Oneapi MKL $intel_one_mkl" "Intel Oneapi MKL installation not found!"
}

function verify_hpcdiag_installation {
    local hpcdiag_path="$HPC_ENV/diagnostics/gather_azhpc_vm_diagnostics.sh"
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
    case $ID in
        ubuntu) dpkg -l | grep datacenter-gpu-manager;;
        centos | almalinux) dnf list installed | grep datacenter-gpu-manager;;
        * ) ;;
    esac
    check_exit_code "DCGM Installed" "DCGM not installed!"

    # Check if the NVIDIA DCGM service is active
    systemctl is-active --quiet nvidia-dcgm
    check_exit_code "NVIDIA DCGM service is active" "NVIDIA DCGM service is inactive/dead!"
}

function verify_sku_customization_service {
    # Check if the SKU customization service is active
    local valid_sizes="standard_nc.*ads_a100_v4|standard_nd96.*v4|standard_nd40rs_v2|standard_hb176.*v4|standard_nd96is*_h100_v5"
    if [[ "$VMSIZE" =~ ^($valid_sizes)$ ]]
    then
        systemctl is-active --quiet sku-customizations
        check_exit_code "SKU Customization is active" "SKU Customization is inactive/dead!"
    fi
}

function verify_nvidia_fabricmanager_service {
    # Check if the NVIDIA Fabricmanager service is active
    local valid_sizes="standard_nd96.*v4|standard_nd96is*_h100_v5"
    if [[ "$VMSIZE" =~ ^($valid_sizes)$ ]]
    then
        systemctl is-active --quiet nvidia-fabricmanager
        check_exit_code "NVIDIA Fabricmanager is active" "NVIDIA Fabricmanager is inactive/dead!"
    fi
}

function verify_sunrpc_tcp_settings_service {
    # Check if the sunrpc TCP settings service is active
    systemctl is-active --quiet sunrpc_tcp_settings
    check_exit_code "sunrpc TCP settings service is active" "sunrpc TCP settings service is inactive/dead!"
}

function verify_apt_yum_update {
    case $ID in
        ubuntu) sudo apt-get -q --assume-no update;;
        centos | almalinux) sudo yum update -y --setopt tsflags=test;
            sudo yum clean packages;;
        * ) ;;
    esac
    check_exit_code "Package update works" "Package update fails!"
}
