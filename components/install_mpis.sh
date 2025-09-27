#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

# Load gcc
set CC=/usr/bin/gcc
set GCC=/usr/bin/gcc

INSTALL_PREFIX=/opt

pmix_metadata=$(get_component_config "pmix")
PMIX_VERSION=$(jq -r '.version' <<< $pmix_metadata)

# Install HPC-x
hpcx_metadata=$(get_component_config "hpcx")
HPCX_VERSION=$(jq -r '.version' <<< $hpcx_metadata)
HPCX_SHA256=$(jq -r '.sha256' <<< $hpcx_metadata)
HPCX_DOWNLOAD_URL=$(jq -r '.url' <<< $hpcx_metadata)
TARBALL=$(basename $HPCX_DOWNLOAD_URL)
HPCX_FOLDER=$(basename $HPCX_DOWNLOAD_URL .tbz)

download_and_verify ${HPCX_DOWNLOAD_URL} ${HPCX_SHA256}
tar -xvf ${TARBALL}

sed -i "s/\/build-result\//\/opt\//" ${HPCX_FOLDER}/hcoll/lib/pkgconfig/hcoll.pc
mv ${HPCX_FOLDER} ${INSTALL_PREFIX}
HPCX_PATH=${INSTALL_PREFIX}/${HPCX_FOLDER}
HCOLL_PATH=${HPCX_PATH}/hcoll
UCX_PATH=${HPCX_PATH}/ucx
write_component_version "HPCX" $HPCX_VERSION

# rebuild HPCX with PMIx
# PMIX is installed from AZL 3.0 PMC to default path
if [[ $DISTRIBUTION == "azurelinux3.0" ]]; then
    ${HPCX_PATH}/utils/hpcx_rebuild.sh --with-hcoll --ompi-extra-config "--with-pmix --enable-orterun-prefix-by-default"
else
    PMIX_PATH=${INSTALL_PREFIX}/pmix/${PMIX_VERSION:0:-2}
    ${HPCX_PATH}/utils/hpcx_rebuild.sh --with-hcoll --ompi-extra-config "--with-pmix=${PMIX_PATH} --enable-orterun-prefix-by-default"
fi
cp -r ${HPCX_PATH}/ompi/tests ${HPCX_PATH}/hpcx-rebuild

if [[ $DISTRIBUTION == almalinux* ]] || [[ $DISTRIBUTION == "azurelinux3.0" ]]; then
    # exclude ucx from updates
    sed -i "$ s/$/ ucx*/" /etc/dnf/dnf.conf
fi

# Install MVAPICH
mvapich_metadata=$(get_component_config "mvapich")
MVAPICH_VERSION=$(jq -r '.version' <<< $mvapich_metadata)
MVAPICH_SHA256=$(jq -r '.sha256' <<< $mvapich_metadata)
MVAPICH_DOWNLOAD_URL=$(jq -r '.url' <<< $mvapich_metadata)
TARBALL=$(basename $MVAPICH_DOWNLOAD_URL)
MVAPICH_FOLDER=$(basename $MVAPICH_DOWNLOAD_URL .tar.gz)

download_and_verify $MVAPICH_DOWNLOAD_URL $MVAPICH_SHA256
tar -xvf ${TARBALL}
pushd ${MVAPICH_FOLDER}
# Error exclusive to Ubuntu 22.04
# configure: error: The Fortran compiler gfortran will not compile files that call
# the same routine with arguments of different types.
./configure $(if [[ $DISTRIBUTION == *"ubuntu"* ]] || [[ $DISTRIBUTION == "azurelinux3.0" ]]; then echo "FFLAGS=-fallow-argument-mismatch"; fi) --prefix=${INSTALL_PREFIX}/mvapich-${MVAPICH_VERSION} --enable-g=none --enable-fast=yes && make -j$(nproc) && make install
popd
write_component_version "MVAPICH" ${MVAPICH_VERSION}

# Install Open MPI
ompi_metadata=$(get_component_config "ompi")
OMPI_VERSION=$(jq -r '.version' <<< $ompi_metadata)
OMPI_SHA256=$(jq -r '.sha256' <<< $ompi_metadata)
OMPI_DOWNLOAD_URL=$(jq -r '.url' <<< $ompi_metadata)
TARBALL=$(basename $OMPI_DOWNLOAD_URL)
OMPI_FOLDER=$(basename $OMPI_DOWNLOAD_URL .tar.gz)

download_and_verify $OMPI_DOWNLOAD_URL $OMPI_SHA256
tar -xvf $TARBALL
cd $OMPI_FOLDER
./configure $(if [[ $DISTRIBUTION == *"ubuntu"* ]] || [[ $DISTRIBUTION == "azurelinux3.0" ]]; then echo "LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${HCOLL_PATH}/lib"; fi) --prefix=${INSTALL_PREFIX}/openmpi-${OMPI_VERSION} --with-ucx=${UCX_PATH} --with-hcoll=${HCOLL_PATH} --with-pmix=${PMIX_PATH} --enable-mpirun-prefix-by-default --with-platform=contrib/platform/mellanox/optimized
make -j$(nproc) 
make install
cd ..
write_component_version "OMPI" ${OMPI_VERSION}

if [[ $DISTRIBUTION == almalinux* ]]  || [[ $DISTRIBUTION == "azurelinux3.0" ]]; then
    # exclude openmpi, perftest from updates
    sed -i "$ s/$/ openmpi perftest/" /etc/dnf/dnf.conf
fi

# Install Intel MPI
impi_metadata=$(get_component_config "impi")
IMPI_VERSION=$(jq -r '.version' <<< $impi_metadata)
IMPI_SHA256=$(jq -r '.sha256' <<< $impi_metadata)
IMPI_DOWNLOAD_URL=$(jq -r '.url' <<< $impi_metadata)
IMPI_OFFLINE_INSTALLER=$(basename $IMPI_DOWNLOAD_URL)

download_and_verify $IMPI_DOWNLOAD_URL $IMPI_SHA256
bash $IMPI_OFFLINE_INSTALLER -s -a -s --eula accept

impi_2021_version=${IMPI_VERSION:0:-2}
mv ${INSTALL_PREFIX}/intel/oneapi/mpi/${impi_2021_version}/etc/modulefiles/mpi ${INSTALL_PREFIX}/intel/oneapi/mpi/${impi_2021_version}/etc/modulefiles/impi
write_component_version "IMPI" ${IMPI_VERSION}

# Setup module files for MPIs
MPI_MODULE_FILES_DIRECTORY=${MODULE_FILES_DIRECTORY}/mpi
mkdir -p ${MPI_MODULE_FILES_DIRECTORY}

# HPC-X
cat << EOF >> ${MPI_MODULE_FILES_DIRECTORY}/hpcx-${HPCX_VERSION}
#%Module 1.0
#
#  HPCx ${HPCX_VERSION}
#
conflict        mpi
module load ${HPCX_PATH}/modulefiles/hpcx
EOF

# HPC-X with PMIX
cat << EOF >> ${MPI_MODULE_FILES_DIRECTORY}/hpcx-pmix-${HPCX_VERSION}
#%Module 1.0
#
#  HPCx ${HPCX_VERSION}
#
conflict        mpi
module load ${HPCX_PATH}/modulefiles/hpcx-rebuild
EOF

# MVAPICH
cat << EOF >> ${MPI_MODULE_FILES_DIRECTORY}/mvapich-${MVAPICH_VERSION}
#%Module 1.0
#
#  MVAPICH ${MVAPICH_VERSION}
#
conflict        mpi
prepend-path    PATH            /opt/mvapich-${MVAPICH_VERSION}/bin
prepend-path    LD_LIBRARY_PATH /opt/mvapich-${MVAPICH_VERSION}/lib
prepend-path    MANPATH         /opt/mvapich-${MVAPICH_VERSION}/share/man
setenv          MPI_BIN         /opt/mvapich-${MVAPICH_VERSION}/bin
setenv          MPI_INCLUDE     /opt/mvapich-${MVAPICH_VERSION}/include
setenv          MPI_LIB         /opt/mvapich-${MVAPICH_VERSION}/lib
setenv          MPI_MAN         /opt/mvapich-${MVAPICH_VERSION}/share/man
setenv          MPI_HOME        /opt/mvapich-${MVAPICH_VERSION}
EOF

# OpenMPI
cat << EOF >> ${MPI_MODULE_FILES_DIRECTORY}/openmpi-${OMPI_VERSION}
#%Module 1.0
#
#  OpenMPI ${OMPI_VERSION}
#
conflict        mpi
prepend-path    PATH            /opt/openmpi-${OMPI_VERSION}/bin
prepend-path    LD_LIBRARY_PATH /opt/openmpi-${OMPI_VERSION}/lib:${HCOLL_PATH}/lib
prepend-path    MANPATH         /opt/openmpi-${OMPI_VERSION}/share/man
setenv          MPI_BIN         /opt/openmpi-${OMPI_VERSION}/bin
setenv          MPI_INCLUDE     /opt/openmpi-${OMPI_VERSION}/include
setenv          MPI_LIB         /opt/openmpi-${OMPI_VERSION}/lib
setenv          MPI_MAN         /opt/openmpi-${OMPI_VERSION}/share/man
setenv          MPI_HOME        /opt/openmpi-${OMPI_VERSION}
EOF

#IntelMPI-v2021
cat << EOF >> ${MPI_MODULE_FILES_DIRECTORY}/impi_${impi_2021_version}
#%Module 1.0
#
#  Intel MPI ${impi_2021_version}
#
conflict        mpi
module load /opt/intel/oneapi/mpi/${impi_2021_version}/etc/modulefiles/impi/${impi_2021_version}
setenv          MPI_BIN         /opt/intel/oneapi/mpi/${impi_2021_version}/bin
setenv          MPI_INCLUDE     /opt/intel/oneapi/mpi/${impi_2021_version}/include
setenv          MPI_LIB         /opt/intel/oneapi/mpi/${impi_2021_version}/lib
setenv          MPI_MAN         /opt/intel/oneapi/mpi/${impi_2021_version}/share/man
setenv          MPI_HOME        /opt/intel/oneapi/mpi/${impi_2021_version}
EOF

if [[ $DISTRIBUTION == "almalinux8.10" ]]; then
    cat << EOF >> ${MPI_MODULE_FILES_DIRECTORY}/impi_${impi_2021_version}
# see https://community.intel.com/t5/Intel-MPI-Library/Suspected-unfixed-Intel-MPI-race-condition-in-collectives/td-p/1693452 for Intel MPI bug
setenv          I_MPI_STARTUP_MODE         pmi_shm
EOF
fi

# Create symlinks for modulefiles
ln -s ${MPI_MODULE_FILES_DIRECTORY}/hpcx-${HPCX_VERSION} ${MPI_MODULE_FILES_DIRECTORY}/hpcx
ln -s ${MPI_MODULE_FILES_DIRECTORY}/hpcx-pmix-${HPCX_VERSION} ${MPI_MODULE_FILES_DIRECTORY}/hpcx-pmix
ln -s ${MPI_MODULE_FILES_DIRECTORY}/mvapich-${MVAPICH_VERSION} ${MPI_MODULE_FILES_DIRECTORY}/mvapich
ln -s ${MPI_MODULE_FILES_DIRECTORY}/openmpi-${OMPI_VERSION} ${MPI_MODULE_FILES_DIRECTORY}/openmpi
ln -s ${MPI_MODULE_FILES_DIRECTORY}/impi_${impi_2021_version} ${MPI_MODULE_FILES_DIRECTORY}/impi-2021

# cleanup downloaded tarballs and other installation files/folders
rm -rf *.tbz *.tar.gz *offline.sh
rm -rf -- */
