
#!/bin/bash
set -ex

# set properties
source ./set_properties.sh

# install utils
./install_utils.sh

# install compilers
./install_gcc.sh

# install mellanox ofed
./install_mellanoxofed.sh

# install mpi libraries
./install_mpis.sh

# cleanup downloaded tarballs
rm -rf *.tgz *.bz2 *.tbz *.tar.gz
rm -Rf -- */

# install nvidia gpu driver
./install_nvidiagpudriver.sh

# install Intel libraries
./install_intel_libs.sh

# optimizations
./hpc-tuning.sh

# copy test file
$COMMON_DIR/copy_test_file.sh
