# Load gcc-8.2.0
export PATH=/opt/gcc-8.2.0/bin:$PATH
export LD_LIBRARY_PATH=/opt/gcc-8.2.0/lib64:$LD_LIBRARY_PATH
set CC=/opt/gcc-8.2.0/bin/gcc
set GCC=/opt/gcc-8.2.0/bin/gcc


INSTALL_PREFIX=/opt

# HPC-X v2.5.0
HPCX_VERSION="v2.5.0"
wget http://content.mellanox.com/hpc/hpc-x/v2.5/hpcx-v2.5.0-gcc-MLNX_OFED_LINUX-4.7-1.0.0.1-redhat7.7-x86_64.tbz
tar -xvf hpcx-v2.5.0-gcc-MLNX_OFED_LINUX-4.7-1.0.0.1-redhat7.7-x86_64.tbz
mv hpcx-v2.5.0-gcc-MLNX_OFED_LINUX-4.7-1.0.0.1-redhat7.7-x86_64 ${INSTALL_PREFIX}
HPCX_PATH=${INSTALL_PREFIX}/hpcx-v2.5.0-gcc-MLNX_OFED_LINUX-4.7-1.0.0.1-redhat7.7-x86_64
HCOLL_PATH=${HPCX_PATH}/hcoll
UCX_PATH=${HPCX_PATH}/ucx

# MVAPICH2 2.3.2
MV2_VERSION="2.3.2"
wget http://mvapich.cse.ohio-state.edu/download/mvapich/mv2/mvapich2-${MV2_VERSION}.tar.gz
tar -xvf mvapich2-${MV2_VERSION}.tar.gz
cd mvapich2-${MV2_VERSION}
./configure --prefix=${INSTALL_PREFIX}/mvapich2-${MV2_VERSION} --enable-g=none --enable-fast=yes && make -j$(nproc) && make install
cd ..


# OpenMPI 4.0.1
OMPI_VERSION="4.0.1"
wget https://download.open-mpi.org/release/open-mpi/v4.0/openmpi-${OMPI_VERSION}.tar.gz
tar -xvf openmpi-${OMPI_VERSION}.tar.gz
cd openmpi-${OMPI_VERSION}
./configure --prefix=${INSTALL_PREFIX}/openmpi-${OMPI_VERSION} --with-ucx=${UCX_PATH} --with-hcoll=${HCOLL_PATH} --enable-mpirun-prefix-by-default --with-platform=contrib/platform/mellanox/optimized && make -j$(nproc) && make install
cd ..


# Intel MPI 2019 (update 5)
IMPI_2019_VERSION="2019.5.281"
wget http://registrationcenter-download.intel.com/akdlm/irc_nas/tec/15838/l_mpi_${IMPI_2019_VERSION}.tgz
tar -xvf l_mpi_${IMPI_2019_VERSION}.tgz
cd l_mpi_${IMPI_2019_VERSION}
sed -i -e 's/ACCEPT_EULA=decline/ACCEPT_EULA=accept/g' silent.cfg
./install.sh --silent ./silent.cfg
cd ..


# Intel MPI 2018 (update 4)
IMPI_VERSION="2018.4.274"
wget http://registrationcenter-download.intel.com/akdlm/irc_nas/tec/13651/l_mpi_${IMPI_VERSION}.tgz
tar -xvf l_mpi_${IMPI_VERSION}.tgz
cd l_mpi_${IMPI_VERSION}
sed -i -e 's/ACCEPT_EULA=decline/ACCEPT_EULA=accept/g' silent.cfg
./install.sh --silent ./silent.cfg
cd ..


# Setup module files for MPIs
mkdir -p /usr/share/Modules/modulefiles/mpi/

# HPC-X
cat << EOF >> /usr/share/Modules/modulefiles/mpi/hpcx-${HPCX_VERSION}
#%Module 1.0
#
#  HPCx ${HPCX_VERSION}
#
conflict        mpi
module load /opt/hpcx-${HPCX_VERSION}-gcc-MLNX_OFED_LINUX-4.7-1.0.0.1-redhat7.7-x86_64/modulefiles/hpcx
EOF


# MVAPICH2
cat << EOF >> /usr/share/Modules/modulefiles/mpi/mvapich2-${MV2_VERSION}
#%Module 1.0
#
#  MVAPICH2 ${MV2_VERSION}
#
conflict        mpi
prepend-path    PATH            /opt/mvapich2-${MV2_VERSION}/bin
prepend-path    LD_LIBRARY_PATH /opt/mvapich2-${MV2_VERSION}/lib
prepend-path    MANPATH         /opt/mvapich2-${MV2_VERSION}/share/man
setenv          MPI_BIN         /opt/mvapich2-${MV2_VERSION}/bin
setenv          MPI_INCLUDE     /opt/mvapich2-${MV2_VERSION}/include
setenv          MPI_LIB         /opt/mvapich2-${MV2_VERSION}/lib
setenv          MPI_MAN         /opt/mvapich2-${MV2_VERSION}/share/man
setenv          MPI_HOME        /opt/mvapich2-${MV2_VERSION}
EOF

# OpenMPI
cat << EOF >> /usr/share/Modules/modulefiles/mpi/openmpi-${OMPI_VERSION}
#%Module 1.0
#
#  OpenMPI ${OMPI_VERSION}
#
conflict        mpi
prepend-path    PATH            /opt/openmpi-${OMPI_VERSION}/bin
prepend-path    LD_LIBRARY_PATH /opt/openmpi-${OMPI_VERSION}/lib
prepend-path    MANPATH         /opt/openmpi-${OMPI_VERSION}/share/man
setenv          MPI_BIN         /opt/openmpi-${OMPI_VERSION}/bin
setenv          MPI_INCLUDE     /opt/openmpi-${OMPI_VERSION}/include
setenv          MPI_LIB         /opt/openmpi-${OMPI_VERSION}/lib
setenv          MPI_MAN         /opt/openmpi-${OMPI_VERSION}/share/man
setenv          MPI_HOME        /opt/openmpi-${OMPI_VERSION}
EOF

#IntelMPI-v2018
cat << EOF >> /usr/share/Modules/modulefiles/mpi/impi_${IMPI_VERSION}
#%Module 1.0
#
#  Intel MPI ${IMPI_VERSION}
#
conflict        mpi
prepend-path    PATH            /opt/intel/impi/${IMPI_VERSION}/intel64/bin
prepend-path    LD_LIBRARY_PATH /opt/intel/impi/${IMPI_VERSION}/intel64/lib
prepend-path    MANPATH         /opt/intel/impi/${IMPI_VERSION}/man
setenv          MPI_BIN         /opt/intel/impi/${IMPI_VERSION}/intel64/bin
setenv          MPI_INCLUDE     /opt/intel/impi/${IMPI_VERSION}/intel64/include
setenv          MPI_LIB         /opt/intel/impi/${IMPI_VERSION}/intel64/lib
setenv          MPI_MAN         /opt/intel/impi/${IMPI_VERSION}/man
setenv          MPI_HOME        /opt/intel/impi/${IMPI_VERSION}/intel64
EOF

#IntelMPI-v2019
cat << EOF >> /usr/share/Modules/modulefiles/mpi/impi_${IMPI_2019_VERSION}
#%Module 1.0
#
#  Intel MPI ${IMPI_2019_VERSION}
#
conflict        mpi
prepend-path    PATH            /opt/intel/impi/${IMPI_2019_VERSION}/intel64/bin
prepend-path    LD_LIBRARY_PATH /opt/intel/impi/${IMPI_2019_VERSION}/intel64/lib
prepend-path    MANPATH         /opt/intel/impi/${IMPI_2019_VERSION}/man
setenv          MPI_BIN         /opt/intel/impi/${IMPI_2019_VERSION}/intel64/bin
setenv          MPI_INCLUDE     /opt/intel/impi/${IMPI_2019_VERSION}/intel64/include
setenv          MPI_LIB         /opt/intel/impi/${IMPI_2019_VERSION}/intel64/lib
setenv          MPI_MAN         /opt/intel/impi/${IMPI_2019_VERSION}/man
setenv          MPI_HOME        /opt/intel/impi/${IMPI_2019_VERSION}/intel64
EOF

# Create symlinks for modulefiles
ln -s /usr/share/Modules/modulefiles/mpi/hpcx-${HPCX_VERSION} /usr/share/Modules/modulefiles/mpi/hpcx
ln -s /usr/share/Modules/modulefiles/mpi/mvapich2-${MV2_VERSION} /usr/share/Modules/modulefiles/mpi/mvapich2
ln -s /usr/share/Modules/modulefiles/mpi/openmpi-${OMPI_VERSION} /usr/share/Modules/modulefiles/mpi/openmpi
ln -s /usr/share/Modules/modulefiles/mpi/impi_${IMPI_2019_VERSION} /usr/share/Modules/modulefiles/mpi/impi-2019
ln -s /usr/share/Modules/modulefiles/mpi/impi_${IMPI_VERSION} /usr/share/Modules/modulefiles/mpi/impi

