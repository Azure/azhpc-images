#!/bin/bash
source /etc/profile

GCC_VERSION="9.2.0"
MKL_VERSION="2019.5.281"
MVAPICH2X_INSTALLATION_DIRECTORY="/opt/mvapich2-x"
IMPI2018_PATH="/opt/intel/compilers_and_libraries_2018.5.274"

CENTOS_MOFED_VERSION="MLNX_OFED_LINUX-5.1-0.6.6.0"
HPCX_PATH_CENTOS_76="/opt/hpcx-v2.7.0-gcc-MLNX_OFED_LINUX-5.1-0.6.6.0-redhat7.6-x86_64"
HPCX_PATH_CENTOS_77="/opt/hpcx-v2.7.0-gcc-MLNX_OFED_LINUX-5.1-0.6.6.0-redhat7.7-x86_64"
HPCX_PATH_CENTOS_81="/opt/hpcx-v2.7.0-gcc-MLNX_OFED_LINUX-5.1-0.6.6.0-redhat8.1-x86_64"
CENTOS_MODULE_FILES_ROOT="/usr/share/Modules/modulefiles"
CENTOS_IMPI2019_PATH="/opt/intel/compilers_and_libraries_2020.2.254"
CENTOS_MVAPICH2_PATH="/opt/mvapich2-2.3.4"
CENTOS_MVAPICH2X_PATH="${MVAPICH2X_INSTALLATION_DIRECTORY}/gnu9.2.0/mofed5.1/azure-xpmem/mpirun"
CENTOS_OPENMPI_PATH="/opt/openmpi-4.0.4"

UBUNTU_MOFED_VERSION="MLNX_OFED_LINUX-5.0-1.0.0.0"
HPCX_PATH_UBUNTU_1804="/opt/hpcx-v2.7.0-gcc-MLNX_OFED_LINUX-5.0-1.0.0.0-ubuntu18.04-x86_64"
UBUNTU_MODULE_FILES_ROOT="/usr/share/modules/modulefiles"
UBUNTU_IMPI2019_PATH="/opt/intel/compilers_and_libraries_2020.1.217"
UBUNTU_MVAPICH2_PATH="/opt/mvapich2-2.3.3"
UBUNTU_MVAPICH2X_PATH="${MVAPICH2X_INSTALLATION_DIRECTORY}/gnu9.2.0/mofed5.0/advanced-xpmem/mpirun"
UBUNTU_OPENMPI_PATH="/opt/openmpi-4.0.3"

CHECK_HPCX=0
CHECK_IMPI_2019=0
CHECK_IMPI_2018=0
CHECK_OMPI=0
CHECK_MVAPICH2=0
CHECK_MVAPICH2X=0
CHECK_CUDA=0
CHECK_LUSTRE=0
CHECK_BLIS_MT=0

# Find distro
find_distro() {
    local os=`cat /etc/os-release | awk 'match($0, /^NAME="(.*)"/, result) { print result[1] }'`
    if [[ $os == "CentOS Linux" ]]
    then
        local centos_distro=`find_centos_distro`
        echo "${os} ${centos_distro}"
    elif [[ $os == "Ubuntu" ]]
    then
        local ubuntu_distro=`find_ubuntu_distro`
        echo "${os} ${ubuntu_distro}"
    else
        echo "*** Error - invalid distro!"
        exit -1
    fi
}

# Find CentOS distro
find_centos_distro() {
    echo `cat /etc/redhat-release | awk '{print $4}'`
}

# Find Ubuntu distro
find_ubuntu_distro() {
    echo `cat /etc/os-release | awk 'match($0, /^PRETTY_NAME="(.*)"/, result) { print result[1] }' | awk '{print $2}' | cut -d. -f1,2`
}

distro=`find_distro`
echo "Detected distro: ${distro}"

if [[ $distro == "CentOS Linux 7.6.1810" ]]
then
    HPCX_PATH=${HPCX_PATH_CENTOS_76}
    CHECK_HPCX=1
    CHECK_IMPI_2019=1
    CHECK_IMPI_2018=1
    CHECK_OMPI=1
    CHECK_MVAPICH2=1
    CHECK_MVAPICH2X=1
    MODULE_FILES_ROOT=${CENTOS_MODULE_FILES_ROOT}
    MOFED_VERSION=${CENTOS_MOFED_VERSION}
    IMPI2019_PATH=${CENTOS_IMPI2019_PATH}
    MVAPICH2_PATH=${CENTOS_MVAPICH2_PATH}
    MVAPICH2X_PATH=${CENTOS_MVAPICH2X_PATH}
    OPENMPI_PATH=${CENTOS_OPENMPI_PATH}
elif [[ $distro == "CentOS Linux 7.7.1908" ]]
then
    HPCX_PATH=${HPCX_PATH_CENTOS_77}
    CHECK_HPCX=1
    CHECK_IMPI_2019=1
    CHECK_IMPI_2018=1
    CHECK_OMPI=1
    CHECK_MVAPICH2=1
    CHECK_MVAPICH2X=1
    MODULE_FILES_ROOT=${CENTOS_MODULE_FILES_ROOT}
    MOFED_VERSION=${CENTOS_MOFED_VERSION}
    IMPI2019_PATH=${CENTOS_IMPI2019_PATH}
    MVAPICH2_PATH=${CENTOS_MVAPICH2_PATH}
    MVAPICH2X_PATH=${CENTOS_MVAPICH2X_PATH}
    OPENMPI_PATH=${CENTOS_OPENMPI_PATH}
elif [[ $distro == "CentOS Linux 8.1.1911" ]]
then
    HPCX_PATH=${HPCX_PATH_CENTOS_81}
    CHECK_HPCX=1
    CHECK_IMPI_2019=1
    CHECK_OMPI=1
    CHECK_MVAPICH2=1
    CHECK_MVAPICH2X=1
    MODULE_FILES_ROOT=${CENTOS_MODULE_FILES_ROOT}
    MOFED_VERSION=${CENTOS_MOFED_VERSION}
    IMPI2019_PATH=${CENTOS_IMPI2019_PATH}
    MVAPICH2_PATH=${CENTOS_MVAPICH2_PATH}
    MVAPICH2X_PATH=${CENTOS_MVAPICH2X_PATH}
    OPENMPI_PATH=${CENTOS_OPENMPI_PATH}
elif [[ $distro == "Ubuntu 18.04.4" ]]
then
    HPCX_PATH=${HPCX_PATH_UBUNTU_1804}
    CHECK_HPCX=1
    CHECK_IMPI_2019=1
    CHECK_MVAPICH2=1
    CHECK_CUDA=1
    CHECK_BLIS_MT=1
    MODULE_FILES_ROOT=${UBUNTU_MODULE_FILES_ROOT}
    MOFED_VERSION=${UBUNTU_MOFED_VERSION}
    IMPI2019_PATH=${UBUNTU_IMPI2019_PATH}
    MVAPICH2_PATH=${UBUNTU_MVAPICH2_PATH}
    MVAPICH2X_PATH=${UBUNTU_MVAPICH2X_PATH}
    OPENMPI_PATH=${UBUNTU_OPENMPI_PATH}
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

# verify MOFED installation
ofed_info | grep ${MOFED_VERSION}
check_exit_code "MOFED installed" "MOFED not installed"

# verify IB device is listed
lspci | grep "Infiniband controller"
check_exit_code "IB device is listed" "IB device not found"

# verify IB device is up
ibstat | grep "LinkUp"
check_exit_code "IB device state: LinkUp" "IB link not up"

# verify GCC modulefile
check_exists "${MODULE_FILES_ROOT}/gcc-${GCC_VERSION}"

# verify AMD modulefiles
check_exists "${MODULE_FILES_ROOT}/amd/fftw"
check_exists "${MODULE_FILES_ROOT}/amd/libflame"
check_exists "${MODULE_FILES_ROOT}/amd/blis"

# verify s/w package installations
check_exists "/opt/gcc-${GCC_VERSION}/"
check_exists "/opt/amd/blis/"
check_exists "/opt/amd/fftw/"
check_exists "/opt/amd/libflame/"
check_exists "/opt/intel/compilers_and_libraries_${MKL_VERSION}/linux/mkl/"

# blis-mt
if [ $CHECK_BLIS_MT -eq 1 ]
then
    check_exists "${MODULE_FILES_ROOT}/amd/blis-mt"
    check_exists "/opt/amd/blis-mt/"
fi

# verify mpi installations and their modulefiles
module avail

# hpcx
if [ $CHECK_HPCX -eq 1 ]
then
    check_exists "${MODULE_FILES_ROOT}/mpi/hpcx"

    module load mpi/hpcx
    mpirun -np 2 --map-by ppr:2:node -x UCX_TLS=rc ${HPCX_PATH}/ompi/tests/osu-micro-benchmarks-5.6.2/osu_latency
    check_exit_code "HPC-X" "Failed to run HPC-X"
    module unload mpi/hpcx
fi

# impi 2019
if [ $CHECK_IMPI_2019 -eq 1 ]
then
    check_exists "${MODULE_FILES_ROOT}/mpi/impi-2019"

    module load mpi/impi-2019
    mpiexec -np 2 -ppn 2 -env FI_PROVIDER=mlx -env I_MPI_SHM=0 ${IMPI2019_PATH}/linux/mpi/intel64/bin/IMB-MPI1 pingpong
    check_exit_code "Intel MPI 2019" "Failed to run Intel MPI 2019"
    module unload mpi/impi-2019
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
    mpiexec -np 2 -ppn 2 -env MV2_USE_SHARED_MEM=0  ${MVAPICH2_PATH}/libexec/osu-micro-benchmarks/mpi/pt2pt/osu_latency
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

# Check if lustre client is installed properly
if [ $CHECK_LUSTRE -eq 1 ]
then
    modprobe -v lustre
    check_exit_code "Lustre Client" "Failed to load Lustre Client"
fi

echo "ALL OK!"

exit 0
