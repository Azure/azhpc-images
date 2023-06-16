#!/bin/bash
set -ex

# Load gcc
set CC=/usr/bin/gcc
set GCC=/usr/bin/gcc

install_prefix=/opt

# Install HPC-x
hpcx_metadata=$(jq -r '.hpcx."'"$DISTRIBUTION"'"' <<< $COMPONENT_VERSIONS)
hpcx_version=$(jq -r '.version' <<< $hpcx_metadata)
hpcx_sha256=$(jq -r '.sha256' <<< $hpcx_metadata)
hpcx_download_url=$(jq -r '.url' <<< $hpcx_metadata)
tarball=$(basename $hpcx_download_url)
hpcx_folder=$(basename $hpcx_download_url .tbz)

$COMMON_DIR/download_and_verify.sh $hpcx_download_url $hpcx_sha256
tar -xvf $tarball
mv $hpcx_folder $install_prefix
hpcx_path=$install_prefix/$hpcx_folder

# Module Files
module_files_directory=/usr/share/modules/modulefiles/mpi
mkdir -p $module_files_directory

# HPC-X
cat << EOF >> $module_files_directory/hpcx-$hpcx_version
#%Module 1.0
#
#  HPCx $hpcx_version
#
conflict        mpi
module load $hpcx_path/modulefiles/hpcx
EOF

# Softlink for HPC-x
ln -s $module_files_directory/hpcx-$hpcx_version $module_files_directory/hpcx

# Add the MPIs to the environment
# Install MVAPICH2
mvapich2_version=$(jq -r '.mvapich2."'"$DISTRIBUTION"'".version' <<< $COMPONENT_VERSIONS)
spack add mvapich2@$mvapich2_version

# Add UCX, HCOLL as externals for Open MPI installation
# /opt/azurehpc/spack/etc/spack/defaults/packages.yaml
# packages:
#   hcoll:
#     externals:
#     - spec: hcoll@3.9.1927
#       prefix: /opt/hpcx-v2.15-gcc-MLNX_OFED_LINUX-5-ubuntu22.04-cuda12-gdrcopy2-nccl2.17-x86_64/hcoll
#     buildable: false
#   ucx:
#     externals:
#     - spec: ucx@1.14.0
#       prefix: /opt/hpcx-v2.15-gcc-MLNX_OFED_LINUX-5-ubuntu22.04-cuda12-gdrcopy2-nccl2.17-x86_64/ucx
#     buildable: false

# MODULEPATH only refers to spack's reference of modules
export_modulepath="export MODULEPATH=/usr/share/modules/modulefiles:$MODULEPATH"
eval $export_modulepath
# Preserve module path on reboots
echo $export_modulepath | tee -a /etc/profile

source /etc/profile.d/modules.sh
module load mpi/hpcx
ucx_path=$hpcx_path/ucx
ucx_version=$($ucx_path/bin/ucx_info -v | grep "Library version" | awk -F' ' '{print $NF}')

hcoll_path=$hpcx_path/hcoll
hcoll_version=$($hcoll_path/bin/hcoll_info -v | awk -F' ' '{split($2, version, "v"); print version[2]}')
module unload mpi/hpcx

packages_yaml=$HPC_ENV/spack/etc/spack/defaults/packages.yaml
hcoll_config=$(cat <<EOF
  hcoll:
    externals:
    - spec: hcoll@$hcoll_version
      prefix: $hcoll_path
    buildable: false
EOF
)

ucx_config=$(cat <<EOF
  ucx:
    externals:
    - spec: ucx@$ucx_version
      prefix: $ucx_path
    buildable: false
EOF
)

# Add the configuration to the packages.yaml file
ed -s "$packages_yaml" <<EOF
/packages:/a
$hcoll_config
$ucx_config
.
w
q
EOF

# Install Open MPI
ompi_version=$(jq -r '.ompi."'"$DISTRIBUTION"'".version' <<< $COMPONENT_VERSIONS)
spack add openmpi@$ompi_version fabrics=ucx,hcoll ^ucx@$ucx_version ^hcoll@$hcoll_version

# Install Intel MPI 2021
impi_2021_version=$(jq -r '.impi_2021."'"$DISTRIBUTION"'".version' <<< $COMPONENT_VERSIONS)
spack add intel-oneapi-mpi@$impi_2021_version

# Install the MPIs
spack install

# Set the installation directories
mvapich2_path=$(spack location -i mvapich2@$mvapich2_version)
ompi_path=$(spack location -i openmpi@$ompi_version)
impi_2021_path=$(spack location -i intel-oneapi-mpi@$impi_2021_version)/mpi/$impi_2021_version
mv $(echo $impi_2021_path)/modulefiles/mpi $(echo $impi_2021_path)/modulefiles/impi

# MVAPICH2
cat << EOF >> $module_files_directory/mvapich2-$mvapich2_version
#%Module 1.0
#
#  MVAPICH2 $mvapich2_version
#
conflict        mpi
prepend-path    PATH            $(echo $mvapich2_path)/bin
prepend-path    LD_LIBRARY_PATH $(echo $mvapich2_path)/lib
prepend-path    MANPATH         $(echo $mvapich2_path)/share/man
setenv          MPI_BIN         $(echo $mvapich2_path)/bin
setenv          MPI_INCLUDE     $(echo $mvapich2_path)/include
setenv          MPI_LIB         $(echo $mvapich2_path)/lib
setenv          MPI_MAN         $(echo $mvapich2_path)/share/man
setenv          MPI_HOME        $(echo $mvapich2_path)
EOF

# OpenMPI
cat << EOF >> $module_files_directory/openmpi-$ompi_version
#%Module 1.0
#
#  OpenMPI $ompi_version
#
conflict        mpi
prepend-path    PATH            $(echo $ompi_path)/bin
prepend-path    LD_LIBRARY_PATH $(echo $ompi_path)/lib
prepend-path    MANPATH         $(echo $ompi_path)/share/man
setenv          MPI_BIN         $(echo $ompi_path)/bin
setenv          MPI_INCLUDE     $(echo $ompi_path)/include
setenv          MPI_LIB         $(echo $ompi_path)/lib
setenv          MPI_MAN         $(echo $ompi_path)/share/man
setenv          MPI_HOME        $(echo $ompi_path)
EOF

# Intel 2021
cat << EOF >> $module_files_directory/impi_$impi_2021_version
#%Module 1.0
#
#  Intel MPI $impi_2021_version
#
conflict        mpi
module load $(echo $impi_2021_path)/modulefiles/impi
setenv          MPI_BIN         $(echo $impi_2021_path)/bin
setenv          MPI_INCLUDE     $(echo $impi_2021_path)/include
setenv          MPI_LIB         $(echo $impi_2021_path)/lib
setenv          MPI_MAN         $(echo $impi_2021_path)/man
setenv          MPI_HOME        $(echo $impi_2021_path)
EOF

# Softlinks for MVAPICH2, Open MPI and IMPI 2021
ln -s $module_files_directory/mvapich2-$mvapich2_version $module_files_directory/mvapich2
ln -s $module_files_directory/openmpi-$ompi_version $module_files_directory/openmpi
ln -s $module_files_directory/impi_$impi_2021_version $module_files_directory/impi-2021

# Write MPI component versions
$COMMON_DIR/write_component_version.sh "hpcx" $hpcx_version
$COMMON_DIR/write_component_version.sh "mvapich2" $mvapich2_version
$COMMON_DIR/write_component_version.sh "ompi" $ompi_version
$COMMON_DIR/write_component_version.sh "impi_2021" $impi_2021_version

# Remove Stale files
rm -rf /tmp/tmp*
