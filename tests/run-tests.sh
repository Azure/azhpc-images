#!/bin/bash

GCC_VERSION="9.2.0"
MKL_VERSION="2019.5.281"
MOFED_VERSION="MLNX_OFED_LINUX-5.0-1.0.0.0"
HPCX_PATH_76="/opt/hpcx-v2.6.0-gcc-MLNX_OFED_LINUX-5.0-1.0.0.0-redhat7.6-x86_64"
HPCX_PATH_77="/opt/hpcx-v2.6.0-gcc-MLNX_OFED_LINUX-5.0-1.0.0.0-redhat7.7-x86_64"

IMPI2019_PATH="/opt/intel/compilers_and_libraries_2020.0.166"
IMPI2018_PATH="/opt/intel/compilers_and_libraries_2018.5.274"

MVAPICH2_PATH="/opt/mvapich2-2.3.3"
MVAPICH2X_PATH="/opt/mvapich2-x/gnu9.2.0/mofed5.0/advanced-xpmem/mpirun"

OPENMPI_PATH="/opt/openmpi-4.0.3"


distro=`cat /etc/redhat-release | awk '{print $4}'`
if [ $distro == "7.6.1810" ]
then
    HPCX_PATH=${HPCX_PATH_76}
elif [ $distro == "7.7.1908" ]
then
    HPCX_PATH=${HPCX_PATH_77}
else
    echo "*** Error - invalid distro!"
    exit -1
fi

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

# verify modulefiles
check_exists "/usr/share/Modules/modulefiles/mpi/hpcx"
check_exists "/usr/share/Modules/modulefiles/mpi/impi"
check_exists "/usr/share/Modules/modulefiles/mpi/impi-2019"
check_exists "/usr/share/Modules/modulefiles/mpi/mvapich2"
check_exists "/usr/share/Modules/modulefiles/mpi/mvapich2x"
check_exists "/usr/share/Modules/modulefiles/mpi/openmpi"

check_exists "/usr/share/Modules/modulefiles/gcc-${GCC_VERSION}"

# verify AMD modulefiles
check_exists "/usr/share/Modules/modulefiles/amd/fftw"
check_exists "/usr/share/Modules/modulefiles/amd/libflame"
check_exists "/usr/share/Modules/modulefiles/amd/blis"
check_exists "/usr/share/Modules/modulefiles/amd/blis-mt"

# verify s/w package installations
check_exists "/opt/gcc-${GCC_VERSION}/"
check_exists "/opt/amd/blis/"
check_exists "/opt/amd/blis-mt/"
check_exists "/opt/amd/fftw/"
check_exists "/opt/amd/libflame/"
check_exists "/opt/intel/compilers_and_libraries_${MKL_VERSION}/linux/mkl/"

# verify mpi installations

# hpcx
module load mpi/hpcx
mpirun -np 2 --map-by ppr:2:node -x UCX_TLS=rc ${HPCX_PATH}/ompi/tests/osu-micro-benchmarks-5.3.2/osu_latency
check_exit_code "HPC-X" "Failed to run HPC-X"
module unload mpi/hpcx

# impi 2019
module load mpi/impi-2019
mpiexec -np 2 -ppn 2 -env FI_PROVIDER=mlx -env UCX_TLS=rc -env I_MPI_SHM=0 ${IMPI2019_PATH}/linux/mpi/intel64/bin/IMB-MPI1 pingpong
check_exit_code "Intel MPI 2019" "Failed to run Intel MPI 2019"
module unload mpi/impi-2019

# impi 2018
module load mpi/impi
mpiexec -np 2 -ppn 2 -env I_MPI_FABRICS=ofa ${IMPI2018_PATH}/linux/mpi/intel64/bin/IMB-MPI1 pingpong
check_exit_code "Intel MPI 2018" "Failed to run Intel MPI 2018"
module unload mpi/impi

# mvapich2
module load mpi/mvapich2
mpiexec -np 2 -ppn 2 -env MV2_USE_SHARED_MEM=0  ${MVAPICH2_PATH}/libexec/osu-micro-benchmarks/mpi/pt2pt/osu_latency
check_exit_code "MVAPICH2" "Failed to run MVAPICH2"

# Note: no need to run MVAPICH2-x and OpenMPI, as these are already covered by MVAPICH2 and HPC-X runs
# But make sure they are installed
check_exists ${MVAPICH2X_PATH}
check_exists ${OPENMPI_PATH}

echo "ALL OK!"

exit 0
