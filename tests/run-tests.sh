#!/bin/bash
# transform long form MOFED-LTS flag to short
for arg in "$@"; do
    shift
    case "$arg" in
        "--mofed-lts") set -- "$@" "-l" ;;
        *) set -- "$@" "$arg"
    esac
done

# display the usage of lts flag for user
usage() { echo "Usage: $0 [--mofed-lts <true|false>]"  1>&2; exit 1; }

while getopts ":l:" o; do
    case "${o}" in
        l)
            l=${OPTARG}
            ((l == true || l == false)) || usage
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

if [ -z "${l}" ]; then
    usage
fi

source /etc/profile

GCC_VERSION="9.2.0"

# Find distro
find_distro() {
    local os=`cat /etc/os-release | awk 'match($0, /^NAME="(.*)"/, result) { print result[1] }'`
    if [[ $os == "AlmaLinux" ]]
    then
        local alma_distro=`find_alma_distro`
        echo "${os} ${alma_distro}"
    elif [[ $os == "Ubuntu" ]]
    then
        local ubuntu_distro=`find_ubuntu_distro`
        echo "${os} ${ubuntu_distro}"
    else
        echo "*** Error - invalid distro!"
        exit -1
    fi
}

# Find Alma distro
find_alma_distro() {
    echo `cat /etc/redhat-release | awk '{print $3}'`
}

# Find Ubuntu distro
find_ubuntu_distro() {
    echo `cat /etc/os-release | awk 'match($0, /^PRETTY_NAME="(.*)"/, result) { print result[1] }' | awk '{print $2}' | cut -d. -f1,2`
}

distro=`find_distro`
echo "Detected distro: ${distro}"

OMPI_VERSION_UBUNTU="5.0.2"
HPCX_MOFED_INTEGRATION_VERSION="MLNX_OFED_LINUX-24.01-0.3.3.1"

case ${distro} in
    "Ubuntu 20.04") HPCX_VERSION_UBUNTU="v2.18";
        MOFED_VERSION_UBUNTU="MLNX_OFED_LINUX-24.01-0.3.3.1";
        IMPI_2021_VERSION_UBUNTU="2021.11";
        ;;
    "Ubuntu 22.04") HPCX_VERSION_UBUNTU="v2.18";
        MOFED_VERSION_UBUNTU="MLNX_OFED_LINUX-24.01-0.3.3.1";
        IMPI_2021_VERSION_UBUNTU="2021.11";
        ;;
    *) ;;
esac

MVAPICH2_VERSION_ALMA="2.3.7-1"
MVAPICH2_VERSION_UBUNTU="2.3.7-1"

OMPI_VERSION_ALMA_87="5.0.2"
IMPI_2021_VERSION_ALMA_87="2021.11"

MVAPICH2X_INSTALLATION_DIRECTORY="/opt/mvapich2-x"
IMPI2018_PATH="/opt/intel/compilers_and_libraries_2018.5.274"

MOFED_VERSION_ALMA_87="MLNX_OFED_LINUX-24.01-0.3.3.1"
MODULE_FILES_ROOT_ALMA="/usr/share/Modules/modulefiles"
IMPI2021_PATH_ALMA_87="/opt/intel/oneapi/mpi/${IMPI_2021_VERSION_ALMA_87}"
MVAPICH2_PATH_ALMA="/opt/mvapich2-${MVAPICH2_VERSION_ALMA}/libexec"
OPENMPI_PATH_ALMA_87="/opt/openmpi-${OMPI_VERSION_ALMA_87}"

MODULE_FILES_ROOT_UBUNTU="/usr/share/modules/modulefiles"
IMPI2021_PATH_UBUNTU="/opt/intel/oneapi/mpi/${IMPI_2021_VERSION_UBUNTU}"
MVAPICH2_PATH_UBUNTU="/opt/mvapich2-${MVAPICH2_VERSION_UBUNTU}/libexec"
MVAPICH2X_PATH_UBUNTU="${MVAPICH2X_INSTALLATION_DIRECTORY}/gnu9.2.0/mofed5.0/advanced-xpmem/mpirun"
OPENMPI_PATH_UBUNTU="/opt/openmpi-${OMPI_VERSION_UBUNTU}"

CHECK_HPCX=0
CHECK_IMPI_2021=0
CHECK_IMPI_2018=0
CHECK_OMPI=0
CHECK_MVAPICH2=0
CHECK_MVAPICH2X=0
CHECK_CUDA=0
CHECK_AOCL=1
CHECK_NCCL=0
CHECK_GCC=1
CHECK_DOCKER=0

if [[ $distro == "Ubuntu"* ]]
then
    MKL_VERSION="2024.0"
elif [[ $distro == "AlmaLinux 8.7" ]]
then
    MKL_VERSION="2024.0"
else
    MKL_VERSION="2023.1.0"
fi

if [[ $distro == "AlmaLinux 8.7" ]]
then
    CHECK_HPCX=1
    CHECK_IMPI_2021=1
    CHECK_IMPI_2018=0
    CHECK_OMPI=1
    CHECK_MVAPICH2=1
    CHECK_MVAPICH2X=0
    MODULE_FILES_ROOT=${MODULE_FILES_ROOT_ALMA}
    MOFED_VERSION=${MOFED_VERSION_ALMA_87}
    IMPI2021_PATH=${IMPI2021_PATH_ALMA_87}
    MVAPICH2_PATH=${MVAPICH2_PATH_ALMA}
    OPENMPI_PATH=${OPENMPI_PATH_ALMA_87}
    CHECK_AOCL=1
    CHECK_NCCL=1
    CHECK_DOCKER=1
elif [[ $distro == "Ubuntu 20.04" ]]
then
    CHECK_HPCX=1
    CHECK_IMPI_2021=1
    CHECK_MVAPICH2=1
    CHECK_OMPI=1
    CHECK_BLIS_MT=1
    MODULE_FILES_ROOT=${MODULE_FILES_ROOT_UBUNTU}
    MOFED_VERSION=${MOFED_VERSION_UBUNTU}
    IMPI2021_PATH=${IMPI2021_PATH_UBUNTU}
    MVAPICH2_PATH=${MVAPICH2_PATH_UBUNTU}
    MVAPICH2X_PATH=${MVAPICH2X_PATH_UBUNTU}
    OPENMPI_PATH=${OPENMPI_PATH_UBUNTU}
    CHECK_AOCL=0
    CHECK_NCCL=1
    CHECK_GCC=0
    CHECK_DOCKER=1
elif [[ $distro == "Ubuntu 22.04" ]]
then
    CHECK_HPCX=1
    CHECK_IMPI_2021=1
    CHECK_MVAPICH2=1
    CHECK_OMPI=1
    CHECK_BLIS_MT=1
    MODULE_FILES_ROOT=${MODULE_FILES_ROOT_UBUNTU}
    MOFED_VERSION=${MOFED_VERSION_UBUNTU}
    IMPI2021_PATH=${IMPI2021_PATH_UBUNTU}
    MVAPICH2_PATH=${MVAPICH2_PATH_UBUNTU}
    MVAPICH2X_PATH=${MVAPICH2X_PATH_UBUNTU}
    OPENMPI_PATH=${OPENMPI_PATH_UBUNTU}
    CHECK_AOCL=0
    CHECK_NCCL=1
    CHECK_GCC=0
    CHECK_DOCKER=1
else
    echo "*** Error - invalid distro!"
    exit -1
fi

module use ${MODULE_FILES_ROOT}

# check file is present
check_exists() {
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
check_exit_code() {
    if [ $? -eq 0 ]
    then
        echo "[OK] : $1"
    else
        echo "*** Error - $2!" >&2
        exit -1
    fi
}

# verify if package updates work
case ${distro} in
    Ubuntu*) sudo apt-get -q --assume-no update;;
    AlmaLinux*) sudo yum update -y --setopt tsflags=test;;
    * ) ;;
esac
check_exit_code "Package update works" "Package update fails!"

# verify MOFED installation
ofed_info | grep ${MOFED_VERSION}
check_exit_code "MOFED installed" "MOFED not installed"

# verify IB device is listed
lspci | grep "Infiniband controller\|Network controller"
check_exit_code "IB device is listed" "IB device not found"

# verify IB device is up
ibstatus | grep "LinkUp"
check_exit_code "IB device state: LinkUp" "IB link not up"

# verify GCC modulefile
if [ $CHECK_GCC -eq 1 ]
then
    # Not using gcc 9.2.0 in Ubuntu 20.04 (9.3.0 used)
    check_exists "${MODULE_FILES_ROOT}/gcc-${GCC_VERSION}"
fi

# verify s/w package installations
if [ $CHECK_GCC -eq 1 ]
then
    # Not using gcc 9.2.0 in Ubuntu 20.04 (9.3.0 used)
    check_exists "/opt/gcc-${GCC_VERSION}/"
fi

check_exists "/opt/intel/oneapi/mkl/${MKL_VERSION}/"

# verify hpcdiag installation
check_exists '/opt/azurehpc/diagnostics/gather_azhpc_vm_diagnostics.sh'

if [ $CHECK_AOCL -eq 1 ]
then
    # verify AMD modulefiles
    check_exists "${MODULE_FILES_ROOT}/amd/aocl"

    check_exists "/opt/amd/lib/"
    check_exists "/opt/amd/include/"
fi

if [ $CHECK_DOCKER -eq 1 ]
then
    sudo docker pull hello-world
    sudo docker run hello-world
    check_exit_code "Docker installed and working correctly!" "Problem with Docker!"
    sudo docker rm $(sudo docker ps -aq)
fi

# verify mpi installations and their modulefiles
module avail

# hpcx
if [ $CHECK_HPCX -eq 1 ]
then
    check_exists "${MODULE_FILES_ROOT}/mpi/hpcx"

    module load mpi/hpcx
    mpirun -np 2 --map-by ppr:2:node -x UCX_TLS=rc ${HPCX_MPI_DIR}/tests/osu-micro-benchmarks/osu_latency
    check_exit_code "HPC-X" "Failed to run HPC-X"
    module unload mpi/hpcx
fi

# impi 2021
if [ $CHECK_IMPI_2021 -eq 1 ]
then
    check_exists "${MODULE_FILES_ROOT}/mpi/impi-2021"

    module load mpi/impi-2021
    mpiexec -np 2 -ppn 2 -env FI_PROVIDER=mlx -env I_MPI_SHM=0 ${IMPI2021_PATH}/bin/IMB-MPI1 pingpong
    check_exit_code "Intel MPI 2021" "Failed to run Intel MPI 2021"
    module unload mpi/impi-2021
fi

# impi 2018
if [ $CHECK_IMPI_2018 -eq 1 ]
then
    check_exists "${MODULE_FILES_ROOT}/mpi/impi"

    module load mpi/impi
    mpiexec -np 2 -ppn 2 -env I_MPI_FABRICS=ofa ${IMPI2018_PATH}/linux/mpi/intel64/bin/IMB-MPI1 pingpong
    check_exit_code "Intel MPI 2018" "Failed to run Intel MPI 2018"
    module unload mpi/impi
fi

# mvapich2
if [ $CHECK_MVAPICH2 -eq 1 ]
then
    check_exists "${MODULE_FILES_ROOT}/mpi/mvapich2"
    module load mpi/mvapich2

    # Env MV2_FORCE_HCA_TYPE=22 explicitly selects EDR
    mpiexec -np 2 -ppn 2 -env MV2_USE_SHARED_MEM=0  -env MV2_FORCE_HCA_TYPE=22  ${MVAPICH2_PATH}/osu-micro-benchmarks/mpi/pt2pt/osu_latency
    check_exit_code "MVAPICH2" "Failed to run MVAPICH2"
    module unload mpi/mvapich2
fi

# mvapich2x
if [ $CHECK_MVAPICH2X -eq 1 ]
then
    check_exists "${MODULE_FILES_ROOT}/mpi/mvapich2x"
    check_exists ${MVAPICH2X_PATH}

    module load mpi/mvapich2x
    mpiexec -np 2 -ppn 2 -env MV2_USE_SHARED_MEM=0  ${MVAPICH2X_INSTALLATION_DIRECTORY}/libexec/osu-micro-benchmarks/mpi/pt2pt/osu_latency
    check_exit_code "MVAPICH2X" "Failed to run MVAPICH2X"
    module unload mpi/mvapich2x
fi

# Note: no need to run OpenMPI, as it is already covered by HPC-X runs, but make sure it is installed
if [ $CHECK_OMPI -eq 1 ]
then
    check_exists "${MODULE_FILES_ROOT}/mpi/openmpi"
    check_exists ${OPENMPI_PATH}
fi

# Check Cuda drivers by running Nvidia SMI
if [ $CHECK_CUDA -eq 1 ]
then
    nvidia-smi
    check_exit_code "Nvidia SMI - Cuda Drivers" "Failed to run Nvidia SMI - Cuda Drivers"
fi

# Perform Single Node NCCL Test
if [ $CHECK_NCCL -eq 1 ]
then
    module load mpi/hpcx

    mpirun -np 8 \
    --allow-run-as-root \
    --map-by ppr:8:node \
    -x LD_LIBRARY_PATH=/usr/local/nccl-rdma-sharp-plugins/lib:$LD_LIBRARY_PATH \
    -mca coll_hcoll_enable 0 \
    -x UCX_TLS=tcp \
    -x CUDA_DEVICE_ORDER=PCI_BUS_ID \
    -x NCCL_SOCKET_IFNAME=eth0 \
    -x NCCL_DEBUG=WARN \
    -x NCCL_NET_GDR_LEVEL=5 \
    /opt/nccl-tests/build/all_reduce_perf -b1K -f2 -g1 -e 4G

    check_exit_code "Single Node NCCL Test" "Failed"

    module unload mpi/hpcx
fi

echo "ALL OK!"

exit 0
