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

MOFED_LTS=${l} # true/ false

source /etc/profile

GCC_VERSION="9.2.0"

# Find distro
find_distro() {
    local os=`cat /etc/os-release | awk 'match($0, /^NAME="(.*)"/, result) { print result[1] }'`
    if [[ $os == "CentOS Linux" ]]
    then
        local centos_distro=`find_centos_distro`
        echo "${os} ${centos_distro}"
    elif [[ $os == "AlmaLinux" ]]
    then
        local alma_distro=`find_alma_distro`
        echo "${os} ${alma_distro}"
    elif [[ $os == "Ubuntu" ]]
    then
        local ubuntu_distro=`find_ubuntu_distro`
        echo "${os} ${ubuntu_distro}"
    elif [[ $os == "SLE_HPC" ]]
    then
        local sle_hpc_distro=`find_sle_hpc_distro`
        echo ${sle_hpc_distro}
    else
        echo "*** Error - invalid distro!"
        exit -1
    fi
}

# Find CentOS distro
find_centos_distro() {
    echo `cat /etc/redhat-release | awk '{print $4}'`
}

# Find Alma distro
find_alma_distro() {
    echo `cat /etc/redhat-release | awk '{print $3}'`
}

# Find Ubuntu distro
find_ubuntu_distro() {
    echo `cat /etc/os-release | awk 'match($0, /^PRETTY_NAME="(.*)"/, result) { print result[1] }' | awk '{print $2}' | cut -d. -f1,2`
}

# Find SUSE Linux Enterprise HPC distro
find_sle_hpc_distro() {
    echo $(cat /etc/os-release | awk 'match($0, /^PRETTY_NAME="(.*)"/, result) { print result[1] }')
}

distro=`find_distro`
echo "Detected distro: ${distro}"

if [ "${MOFED_LTS}" = true ]
then
    HPCX_VERSION_UBUNTU="v2.7.0"
    MOFED_VERSION_UBUNTU="MLNX_OFED_LINUX-4.9-6.0.6.0"
    HPCX_MOFED_INTEGRATION_VERSION="MLNX_OFED_LINUX-4.7-1.0.0.1"
    HPCX_OMB_PATH_UBUNTU_1804="/opt/hpcx-${HPCX_VERSION_UBUNTU}-gcc-${HPCX_MOFED_INTEGRATION_VERSION}-ubuntu18.04-x86_64/ompi/tests/osu-micro-benchmarks-5.6.2"
    IMPI_2021_VERSION_UBUNTU="2021.7.0"
    OMPI_VERSION_UBUNTU="4.1.3"
else
    OMPI_VERSION_UBUNTU="4.1.5"
    HPCX_MOFED_INTEGRATION_VERSION="MLNX_OFED_LINUX-5.4-1.0.3.0"
    case ${distro} in
        "Ubuntu 18.04") HPCX_VERSION_UBUNTU="v2.15";
            MOFED_VERSION_UBUNTU="MLNX_OFED_LINUX-23.04-0.5.3.3";
            IMPI_2021_VERSION_UBUNTU="2021.9.0";
            ;;
        "Ubuntu 20.04") HPCX_VERSION_UBUNTU="v2.15";
            MOFED_VERSION_UBUNTU="MLNX_OFED_LINUX-23.04-0.5.3.3";
            IMPI_2021_VERSION_UBUNTU="2021.9.0";
            ;;
        "Ubuntu 22.04") HPCX_VERSION_UBUNTU="v2.15";
            MOFED_VERSION_UBUNTU="MLNX_OFED_LINUX-23.04-0.5.3.3";
            IMPI_2021_VERSION_UBUNTU="2021.9.0";
            ;;
        *) ;;
    esac
    HPCX_OMB_PATH_UBUNTU_1804="/opt/hpcx-${HPCX_VERSION_UBUNTU}-gcc-MLNX_OFED_LINUX-5-ubuntu18.04-cuda12-gdrcopy2-nccl2.17-x86_64/ompi/tests/osu-micro-benchmarks-5.8"
fi

HPCX_VERSION_CENTOS="v2.9.0"
HPCX_VERSION_SUSE="2.12"

MVAPICH2_VERSION_CENTOS="2.3.6"
MVAPICH2_VERSION_ALMA="2.3.7"
MVAPICH2_VERSION_UBUNTU="2.3.7"
MVAPICH2_VERSION_SUSE="2.3.6"

OMPI_VERSION_CENTOS="4.1.1"
OMPI_VERSION_ALMA_86="4.1.3"
OMPI_VERSION_ALMA_87="4.1.5"
OMPI_VERSION_SUSE="4.1.1"

IMPI_2021_VERSION_CENTOS="2021.4.0"
IMPI_2021_VERSION_ALMA_86="2021.7.0"
IMPI_2021_VERSION_ALMA_87="2021.9.0"
IMPI_2021_VERSION_SUSE="2021.9.0"

MVAPICH2X_INSTALLATION_DIRECTORY="/opt/mvapich2-x"
IMPI2018_PATH="/opt/intel/compilers_and_libraries_2018.5.274"

MOFED_VERSION_CENTOS="MLNX_OFED_LINUX-5.4-1.0.3.0"
MOFED_VERSION_CENTOS_79="MLNX_OFED_LINUX-5.4-3.0.0.0"
MOFED_VERSION_CENTOS_83="MLNX_OFED_LINUX-5.2-1.0.4.0"
MOFED_VERSION_ALMA_86="MLNX_OFED_LINUX-5.8-1.0.1.1"
MOFED_VERSION_ALMA_87="MLNX_OFED_LINUX-23.04-0.5.3.3"
MOFED_VERSION_SUSE="MLNX_OFED_INBOX_5.14.21-4.0.0"
#MOFED_VERSION_SUSE="MLNX_OFED-5.7-1.0.2.0"

HPCX_OMB_PATH_CENTOS_76="/opt/hpcx-${HPCX_VERSION_CENTOS}-gcc${GCC_VERSION}-${MOFED_VERSION_CENTOS}-redhat7.6-x86_64/ompi/tests/osu-micro-benchmarks-5.6.2"
HPCX_OMB_PATH_CENTOS_77="/opt/hpcx-${HPCX_VERSION_CENTOS}-gcc${GCC_VERSION}-${MOFED_VERSION_CENTOS}-redhat7.7-x86_64/ompi/tests/osu-micro-benchmarks-5.6.2"
HPCX_OMB_PATH_CENTOS_78="/opt/hpcx-${HPCX_VERSION_CENTOS}-gcc${GCC_VERSION}-${MOFED_VERSION_CENTOS}-redhat7.8-x86_64/ompi/tests/osu-micro-benchmarks-5.6.2"
HPCX_OMB_PATH_CENTOS_79="/opt/hpcx-${HPCX_VERSION_CENTOS}-gcc${GCC_VERSION}-${HPCX_MOFED_INTEGRATION_VERSION}-redhat7.9-x86_64/ompi/tests/osu-micro-benchmarks-5.6.2"
HPCX_OMB_PATH_CENTOS_81="/opt/hpcx-${HPCX_VERSION_CENTOS}-gcc${GCC_VERSION}-${MOFED_VERSION_CENTOS}-redhat8.1-x86_64/ompi/tests/osu-micro-benchmarks-5.6.2"
HPCX_OMB_PATH_CENTOS_83="/opt/hpcx-v2.8.0-gcc-${MOFED_VERSION_CENTOS_83}-redhat8.3-x86_64/ompi/tests/osu-micro-benchmarks-5.6.2"
MODULE_FILES_ROOT_CENTOS="/usr/share/Modules/modulefiles"
IMPI2021_PATH_CENTOS="/opt/intel/oneapi/mpi/${IMPI_2021_VERSION_CENTOS}"
# added "libexec" to the path, as centos and ubuntu use "libexec", but SUSE only "lib"
MVAPICH2_PATH_CENTOS="/opt/mvapich2-${MVAPICH2_VERSION_CENTOS}/libexec"
MVAPICH2X_PATH_CENTOS="${MVAPICH2X_INSTALLATION_DIRECTORY}/gnu9.2.0/mofed5.1/azure-xpmem/mpirun"
OPENMPI_PATH_CENTOS="/opt/openmpi-${OMPI_VERSION_CENTOS}"

HPCX_OMB_PATH_ALMA_86="/opt/hpcx-v2.14-gcc-MLNX_OFED_LINUX-5-redhat8-cuda11-gdrcopy2-nccl2.16-x86_64/ompi/tests/osu-micro-benchmarks-5.8"
HPCX_OMB_PATH_ALMA_87="/opt/hpcx-v2.15-gcc-MLNX_OFED_LINUX-5-redhat8-cuda12-gdrcopy2-nccl2.17-x86_64/ompi/tests/osu-micro-benchmarks-5.8"
MODULE_FILES_ROOT_ALMA="/usr/share/Modules/modulefiles"
IMPI2021_PATH_ALMA_86="/opt/intel/oneapi/mpi/${IMPI_2021_VERSION_ALMA_86}"
IMPI2021_PATH_ALMA_87="/opt/intel/oneapi/mpi/${IMPI_2021_VERSION_ALMA_87}"
# added "libexec" to the path, as rh+clones and ubuntu use "libexec", but SUSE only "lib"
MVAPICH2_PATH_ALMA="/opt/mvapich2-${MVAPICH2_VERSION_ALMA}/libexec"
OPENMPI_PATH_ALMA_86="/opt/openmpi-${OMPI_VERSION_ALMA_86}"
OPENMPI_PATH_ALMA_87="/opt/openmpi-${OMPI_VERSION_ALMA_87}"

MODULE_FILES_ROOT_UBUNTU="/usr/share/modules/modulefiles"
HPCX_OMB_PATH_UBUNTU_2004="/opt/hpcx-${HPCX_VERSION_UBUNTU}-gcc-MLNX_OFED_LINUX-5-ubuntu20.04-cuda12-gdrcopy2-nccl2.17-x86_64/ompi/tests/osu-micro-benchmarks-5.8"
HPCX_OMB_PATH_UBUNTU_2204="/opt/hpcx-${HPCX_VERSION_UBUNTU}-gcc-MLNX_OFED_LINUX-5-ubuntu22.04-cuda12-gdrcopy2-nccl2.17-x86_64/ompi/tests/osu-micro-benchmarks-5.8"
IMPI2021_PATH_UBUNTU="/opt/intel/oneapi/mpi/${IMPI_2021_VERSION_UBUNTU}"
# added "libexec" to the path, as centos and ubuntu use "libexec", but SUSE only "lib"
MVAPICH2_PATH_UBUNTU="/opt/mvapich2-${MVAPICH2_VERSION_UBUNTU}/libexec"
MVAPICH2X_PATH_UBUNTU="${MVAPICH2X_INSTALLATION_DIRECTORY}/gnu9.2.0/mofed5.0/advanced-xpmem/mpirun"
OPENMPI_PATH_UBUNTU="/opt/openmpi-${OMPI_VERSION_UBUNTU}"

MODULE_FILES_ROOT_SUSE="/usr/share/lmod/modulefiles"
HPCX_OMB_PATH_SUSE="/opt/hpcx-v${HPCX_VERSION_SUSE}-gcc-inbox-suse15.4-cuda11-gdrcopy2-nccl${HPCX_VERSION_SUSE}-x86_64/ompi/tests/osu-micro-benchmarks-5.8"
IMPI2021_PATH_SUSE="/opt/intel/oneapi/mpi/${IMPI_2021_VERSION_SUSE}"
# SUSE use lib instead of libexec
MVAPICH2_PATH_SUSE="/usr/lib/hpc/gnu7/mpi/mvapich2-psm2/2.3.6/lib"
MVAPICH2X_PATH_SUSE=""
OPENMPI_PATH_SUSE="/usr/lib/hpc/gnu7/mpi/openmpi/4.1.1"

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

if [[ $distro == *"CentOS Linux"* ]]
then
    MKL_VERSION="2021.1.1"
elif [[ $distro == "Ubuntu"* ]]
then
    MKL_VERSION="2023.1.0"
elif [[ $distro == "AlmaLinux 8.6" ]]
then
    MKL_VERSION="2022.1.0"
else
    MKL_VERSION="2023.1.0"
fi

if [[ $distro == "CentOS Linux 7.6.1810" ]]
then
    HPCX_OMB_PATH=${HPCX_OMB_PATH_CENTOS_76}
    CHECK_HPCX=1
    CHECK_IMPI_2021=1
    CHECK_IMPI_2018=1
    CHECK_OMPI=1
    CHECK_MVAPICH2=1
    CHECK_MVAPICH2X=0
    MODULE_FILES_ROOT=${MODULE_FILES_ROOT_CENTOS}
    MOFED_VERSION=${MOFED_VERSION_CENTOS}
    IMPI2021_PATH=${IMPI2021_PATH_CENTOS}
    MVAPICH2_PATH=${MVAPICH2_PATH_CENTOS}
    MVAPICH2X_PATH=${MVAPICH2X_PATH_CENTOS}
    OPENMPI_PATH=${OPENMPI_PATH_CENTOS}
elif [[ $distro == "CentOS Linux 7.7.1908" ]]
then
    HPCX_OMB_PATH=${HPCX_OMB_PATH_CENTOS_77}
    CHECK_HPCX=1
    CHECK_IMPI_2021=1
    CHECK_IMPI_2018=1
    CHECK_OMPI=1
    CHECK_MVAPICH2=1
    CHECK_MVAPICH2X=0
    MODULE_FILES_ROOT=${MODULE_FILES_ROOT_CENTOS}
    MOFED_VERSION=${MOFED_VERSION_CENTOS}
    IMPI2021_PATH=${IMPI2021_PATH_CENTOS}
    MVAPICH2_PATH=${MVAPICH2_PATH_CENTOS}
    MVAPICH2X_PATH=${MVAPICH2X_PATH_CENTOS}
    OPENMPI_PATH=${OPENMPI_PATH_CENTOS}
elif [[ $distro == "CentOS Linux 7.8.2003" ]]
then
    HPCX_OMB_PATH=${HPCX_OMB_PATH_CENTOS_78}
    CHECK_HPCX=1
    CHECK_IMPI_2021=1
    CHECK_IMPI_2018=1
    CHECK_OMPI=1
    CHECK_MVAPICH2=1
    CHECK_MVAPICH2X=0
    MODULE_FILES_ROOT=${MODULE_FILES_ROOT_CENTOS}
    MOFED_VERSION=${MOFED_VERSION_CENTOS}
    IMPI2021_PATH=${IMPI2021_PATH_CENTOS}
    MVAPICH2_PATH=${MVAPICH2_PATH_CENTOS}
    MVAPICH2X_PATH=${MVAPICH2X_PATH_CENTOS}
    OPENMPI_PATH=${OPENMPI_PATH_CENTOS}
elif [[ $distro == "CentOS Linux 7.9.2009" ]]
then
    HPCX_OMB_PATH=${HPCX_OMB_PATH_CENTOS_79}
    CHECK_HPCX=1
    CHECK_IMPI_2021=1
    CHECK_IMPI_2018=1
    CHECK_OMPI=1
    CHECK_MVAPICH2=1
    CHECK_MVAPICH2X=0
    CHECK_DOCKER=1
    MODULE_FILES_ROOT=${MODULE_FILES_ROOT_CENTOS}
    MOFED_VERSION=${MOFED_VERSION_CENTOS_79}
    IMPI2021_PATH=${IMPI2021_PATH_CENTOS}
    MVAPICH2_PATH=${MVAPICH2_PATH_CENTOS}
    MVAPICH2X_PATH=${MVAPICH2X_PATH_CENTOS}
    OPENMPI_PATH=${OPENMPI_PATH_CENTOS}
    CHECK_AOCL=1
    CHECK_NCCL=1
elif [[ $distro == "CentOS Linux 8.1.1911" ]]
then
    HPCX_OMB_PATH=${HPCX_OMB_PATH_CENTOS_81}
    CHECK_HPCX=1
    CHECK_IMPI_2021=1
    CHECK_OMPI=1
    CHECK_MVAPICH2=1
    CHECK_MVAPICH2X=0
    MODULE_FILES_ROOT=${MODULE_FILES_ROOT_CENTOS}
    MOFED_VERSION=${MOFED_VERSION_CENTOS}
    IMPI2021_PATH=${IMPI2021_PATH_CENTOS}
    MVAPICH2_PATH=${MVAPICH2_PATH_CENTOS}
    MVAPICH2X_PATH=${MVAPICH2X_PATH_CENTOS}
    OPENMPI_PATH=${OPENMPI_PATH_CENTOS}
elif [[ $distro == "CentOS Linux 8.3.2011" ]]
then
    HPCX_OMB_PATH=${HPCX_OMB_PATH_CENTOS_83}
    CHECK_HPCX=1
    CHECK_IMPI_2021=1
    CHECK_OMPI=1
    CHECK_MVAPICH2=1
    CHECK_MVAPICH2X=0
    MODULE_FILES_ROOT=${MODULE_FILES_ROOT_CENTOS}
    MOFED_VERSION=${MOFED_VERSION_CENTOS}
    IMPI2021_PATH=${IMPI2021_PATH_CENTOS}
    MVAPICH2_PATH=${MVAPICH2_PATH_CENTOS}
    MVAPICH2X_PATH=${MVAPICH2X_PATH_CENTOS}
    OPENMPI_PATH=${OPENMPI_PATH_CENTOS}
elif [[ $distro == "AlmaLinux 8.6" ]]
then
    HPCX_OMB_PATH=${HPCX_OMB_PATH_ALMA_86}
    CHECK_HPCX=1
    CHECK_IMPI_2021=1
    CHECK_IMPI_2018=0
    CHECK_OMPI=1
    CHECK_MVAPICH2=1
    CHECK_MVAPICH2X=0
    MODULE_FILES_ROOT=${MODULE_FILES_ROOT_ALMA}
    MOFED_VERSION=${MOFED_VERSION_ALMA_86}
    IMPI2021_PATH=${IMPI2021_PATH_ALMA_86}
    MVAPICH2_PATH=${MVAPICH2_PATH_ALMA}
    OPENMPI_PATH=${OPENMPI_PATH_ALMA_86}
    CHECK_AOCL=1
    CHECK_NCCL=1
    CHECK_DOCKER=1
elif [[ $distro == "AlmaLinux 8.7" ]]
then
    HPCX_OMB_PATH=${HPCX_OMB_PATH_ALMA_87}
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
elif [[ $distro == "Ubuntu 18.04" ]]
then
    HPCX_OMB_PATH=${HPCX_OMB_PATH_UBUNTU_1804}
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
    CHECK_GCC=0
    CHECK_NCCL=1
    CHECK_DOCKER=1
elif [[ $distro == "Ubuntu 20.04" ]]
then
    HPCX_OMB_PATH=${HPCX_OMB_PATH_UBUNTU_2004}
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
    HPCX_OMB_PATH=${HPCX_OMB_PATH_UBUNTU_2204}
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
elif [[ $distro == "SUSE Linux Enterprise High Performance Computing 15 SP4" ]]
then
    # add /sbin and /usr/sbin to the path to allow lscpi and ibstatus called without path
    # as only UID=0 get it by default
    export PATH=$PATH:/sbin:/usr/sbin
    MKL_VERSION="2023.1.0"
    #
    CHECK_GCC=0
    CHECK_ONEAPI=1
    CHECK_AZURE_HPC_DIAG=1

    HPCX_OMB_PATH=${HPCX_OMB_PATH_SUSE}
    CHECK_HPCX=1
    CHECK_IMPI_2021=1
    CHECK_MVAPICH2=1
    CHECK_MVAPICH2X=0
    CHECK_CUDA=1
    CHECK_OMPI=1
    CHECK_BLIS_MT=1

    MODULE_FILES_ROOT=${MODULE_FILES_ROOT_SUSE}
    MOFED_VERSION=${MOFED_VERSION_SUSE}
    IMPI2021_PATH=${IMPI2021_PATH_SUSE}
    MVAPICH2_PATH=${MVAPICH2_PATH_SUSE}
    OPENMPI_PATH=${OPENMPI_PATH_SUSE}

    CHECK_AOCL=1
    CHECK_NV_PMEM=0
    CHECK_NCCL=1
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
    CentOS* | AlmaLinux*) sudo yum update -y --setopt tsflags=test;;
    * ) ;;
esac
check_exit_code "Package update works" "Package update fails!"

# verify MOFED installation
if [[ $distro == "SUSE Linux Enterprise High Performance Computing 15 SP4" ]]
then
  echo "ofed inbox driver does miss the ofed_info tool"
else
  ofed_info | grep ${MOFED_VERSION}
  check_exit_code "MOFED installed" "MOFED not installed"
fi

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

if [ $CHECK_DOCKER -eq 1 ] && [ "${MOFED_LTS}" = false ]
then
    sudo docker pull hello-world
    sudo docker run hello-world
    check_exit_code "Docker installed and working correctly!" "Problem with Docker!"
fi

# verify mpi installations and their modulefiles
module avail

# hpcx
if [ $CHECK_HPCX -eq 1 ]
then
    check_exists "${MODULE_FILES_ROOT}/mpi/hpcx"

    module load mpi/hpcx
    mpirun -np 2 --map-by ppr:2:node -x UCX_TLS=rc ${HPCX_OMB_PATH}/osu_latency
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
    # SUSE module load gnu/7 mvapich2
    if [[ $distro == "SUSE Linux Enterprise High Performance Computing 15 SP4" ]]
    then
        module load gnu/7 mvapich2
    else
    module load mpi/mvapich2
    fi

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

    if [ "${MOFED_LTS}" = true ]
    then
        mpirun -np 4 \
        -x LD_LIBRARY_PATH \
        --allow-run-as-root \
        --map-by ppr:4:node \
        -mca coll_hcoll_enable 0 \
        -x UCX_TLS=tcp \
        -x CUDA_DEVICE_ORDER=PCI_BUS_ID \
        -x NCCL_SOCKET_IFNAME=eth0 \
        -x NCCL_DEBUG=WARN \
        /opt/nccl-tests/build/all_reduce_perf -b1K -f2 -g1 -e 4G
    else
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
    fi

    check_exit_code "Single Node NCCL Test" "Failed"

    module unload mpi/hpcx
fi

echo "ALL OK!"

exit 0
