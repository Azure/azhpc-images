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

# verify OFED installation
function verify_ofed_installation {
    # verify OFED installation
    ofed_info | grep ${VERSION_OFED}
    check_exit_code "OFED installed" "OFED not installed"
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
    # verify mpi installations and their modulefiles
    module avail

    check_exists "${MODULE_FILES_ROOT}/mpi/hpcx"
    
    module load mpi/hpcx
    mpirun -np 2 --map-by ppr:2:node -x UCX_TLS=rc ${HPCX_OSU_DIR}/osu_latency
    check_exit_code "HPC-X" "Failed to run HPC-X"
    module unload mpi/hpcx

    check_exists "${MODULE_FILES_ROOT}/mpi/hpcx-pmix"

    module load mpi/hpcx-pmix
    mpirun -np 2 --map-by ppr:2:node -x UCX_TLS=rc ${HPCX_OSU_DIR}/osu_latency
    check_exit_code "HPC-X with PMIx" "Failed to run HPC-X with PMIx"
    module unload mpi/hpcx-pmix
    module purge
}

function verify_mvapich2_installation {
    check_exists "${MODULE_FILES_ROOT}/mpi/mvapich2"

    module load mpi/mvapich2
    # Env MV2_FORCE_HCA_TYPE=22 explicitly selects EDR
    local mvapich2_omb_path=${MPI_HOME}/libexec/osu-micro-benchmarks/mpi/pt2pt
    mpiexec -np 2 -ppn 2 -env MV2_USE_SHARED_MEM=0  -env MV2_FORCE_HCA_TYPE=22 ${mvapich2_omb_path}/osu_latency
    check_exit_code "MVAPICH2 ${VERSION_MVAPICH2}" "Failed to run MVAPICH2"
    module unload mpi/mvapich2
}

function verify_impi_2021_installation {
    check_exists "${MODULE_FILES_ROOT}/mpi/impi-2021"
    
    module load mpi/impi-2021
    mpiexec -np 2 -ppn 2 -env FI_PROVIDER=mlx -env I_MPI_SHM=0 ${MPI_BIN}/IMB-MPI1 pingpong
    check_exit_code "Intel MPI 2021 ${VERSION_IMPI}" "Failed to run Intel MPI 2021"
    module unload mpi/impi-2021
}

function verify_ompi_installation {
    check_exists "${MODULE_FILES_ROOT}/mpi/openmpi"
    check_exists "/opt/openmpi-${VERSION_OMPI}"
    check_exit_code "Open MPI ${VERSION_OMPI}" "Failed to run Open MPI"
}

function verify_cuda_installation {
    # Verify NVIDIA Driver installation
    nvidia-smi
    check_exit_code "Nvidia Driver ${VERSION_NVIDIA}" "Failed to run Nvidia SMI"
    
    # Verify if NVIDIA peer memory module is inserted
    lsmod | grep nvidia_peermem
    check_exit_code "NVIDIA Peer memory module is inserted" "NVIDIA Peer memory module is not inserted!"

    # Verify if CUDA is installed
    # re-enable this after testing
    # nvcc --version
    # check_exit_code "CUDA Driver ${VERSION_CUDA}" "CUDA not installed"
    check_exists "/usr/local/cuda/"
    
    # Verify the compilation of CUDA samples
    /usr/local/cuda/samples/0_Introduction/mergeSort/mergeSort
    check_exit_code "CUDA Samples ${VERSION_CUDA}" "Failed to perform merge sort using CUDA Samples"
}

function verify_nccl_installation {
    # Print nccl.conf if it exists
    if test -f /etc/nccl.conf; then
        cat /etc/nccl.conf
    fi

    module load mpi/hpcx

    case ${VMSIZE} in
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
    check_exit_code "NCCL ${VERSION_NCCL}" "Failed to run NCCL all reduce perf"
    
    module unload mpi/hpcx
}

function verify_package_updates {
    case ${ID} in
        ubuntu) sudo apt -q --assume-no update;;
        almalinux) sudo yum update -y --setopt tsflags=test;
            sudo yum clean packages;;
        * ) ;;
    esac
    check_exit_code "Package update works" "Package update fails!"
}

function verify_azcopy_installation {
    sudo azcopy --version
    check_exit_code "azcopy ${VERSION_AZCOPY}" "Failed to install azcopy"
}

function verify_mkl_installation {
    check_exists "/opt/intel/oneapi/mkl/${VERSION_INTEL_ONE_MKL:0:6}/"
    check_exit_code "Intel Oneapi MKL ${VERSION_INTEL_ONE_MKL}" "Intel Oneapi MKL installation not found!"
}

function verify_hpcdiag_installation {
    local hpcdiag_path="${HPC_ENV}/diagnostics/gather_azhpc_vm_diagnostics.sh"
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
    check_exists "/opt/gcc-${VERSION_GCC}/"
    # Verify GCC module file path
    check_exists "${MODULE_FILES_ROOT}/gcc-${VERSION_GCC}"
}

function verify_aocl_installation {
    # verify AMD modulefiles
    check_exists "${MODULE_FILES_ROOT}/amd/aocl"
    check_exists "/opt/amd/lib/"
    check_exists "/opt/amd/include/"
}

function verify_aocc_installation {
    # verify AMD compiler installation
    check_exists "/opt/AMD/aocc-compiler-${VERSION_AOCC:0:2}/"
}

function verify_docker_installation {
    sudo docker pull hello-world
    sudo docker run hello-world
    check_exit_code "Docker ${VERSION_DOCKER}" "Problem with Docker!"
    sudo docker rm $(sudo docker ps -aq)
    sudo docker rmi hello-world
}

function verify_ipoib_status {
    # Check if the module ib_ipoib is inserted
    lsmod | grep ib_ipoib
    check_exit_code "ib_ipoib module is inserted" "ip_ipoib module not inserted!"

    # Check if ib devices are listed
    ip addr | grep ib
    check_exit_code "IPoIB is working" "IPoIB is not working!"
}

function verify_lustre_installation {
    # Verify lustre client package installation
    case ${ID} in
        ubuntu) dpkg -l | grep lustre-client;;
        almalinux) dnf list installed | grep lustre-client;;
        * ) ;;
    esac
    check_exit_code "Lustre Installed" "Lustre not installed!"
}

function verify_gdrcopy_installation {
    # Verify GDRCopy package installation
    case ${ID} in
        ubuntu) dpkg -l | grep gdrcopy;;
        almalinux) dnf list installed | grep gdrcopy;;
        * ) ;;
    esac
    check_exit_code "GDRCopy Installed" "GDRCopy not installed!"
}

function verify_pssh_installation {
    # Verify PSSH package installation
    case ${ID} in
        ubuntu) dpkg -l | grep pssh;;
        almalinux) dnf list installed | grep pssh;;
        * ) ;;
    esac
    check_exit_code "PSSH Installed" "PSSH not installed!"
}

function verify_aznfs_installation {
    # verify AZNFS Mount Helper installation
    check_exists "/opt/microsoft/aznfs/"
}

function verify_dcgm_installation {
    # Verify DCGM package installation
    case ${ID} in
        ubuntu) dpkg -l | grep datacenter-gpu-manager;;
        almalinux) dnf list installed | grep datacenter-gpu-manager;;
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
    if [[ "${VMSIZE}" =~ ^($valid_sizes)$ ]]
    then
        systemctl is-active --quiet sku-customizations
        check_exit_code "SKU Customization is active" "SKU Customization is inactive/dead!"
    fi
}

function verify_nvidia_fabricmanager_service {
    # Check if the NVIDIA Fabricmanager service is active
    local valid_sizes="standard_nd96.*v4|standard_nd96is*_h100_v5"
    if [[ "${VMSIZE}" =~ ^($valid_sizes)$ ]]
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
