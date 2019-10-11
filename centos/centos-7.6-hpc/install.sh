#!/bin/bash
set -ex

# install utils
./install_utils.sh

# install compilers
./install_gcc-8.2.sh

# install mellanox ofed
./install_mellanoxofed.sh

# install mpi libraries
./install_mpis.sh

# optimizations
./hpc-tuning.sh

