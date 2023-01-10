#!/bin/bash
set -ex

#
## Nvidia provide certified packages for SLES 15 SP4, so we only need to add the repositories and install the packages
#

# Install Cuda
#NVIDIA_VERSION="520.61"
#CUDA_VERSION="11.8.0"

# to check whats all available in the repo
# zypper se --repo cuda-sles15-x86_64

# install latest cuda package
# the repo contains more versions, so for example we want cuda 11.3 the package name is "cuda-11-3"
#
# cuda 	                    Installs all CUDA Toolkit and Driver packages. Handles upgrading to the next version of the cuda package when it's released.
# cuda-11-8 	            Installs all CUDA Toolkit and Driver packages. Remains at version 11.8 until an additional version of CUDA is installed.
# cuda-toolkit-11-8 	    Installs all CUDA Toolkit packages required to develop CUDA applications. Does not include the driver.
# cuda-tools-11-8 	        Installs all CUDA command line and visual tools.
# cuda-runtime-11-8      	Installs all CUDA Toolkit packages required to run CUDA applications, as well as the Driver packages.
# cuda-compiler-11-8    	Installs all CUDA compiler packages.
# cuda-libraries-11-8 	    Installs all runtime CUDA Library packages.
# cuda-libraries-dev-11-8 	Installs all development CUDA Library packages.
# cuda-drivers 	            Installs all Driver packages. Handles upgrading to the next version of the Driver packages when they're released.
zypper install -y -l cuda cuda-drivers

CUDA_VERSION=$(rpm -q --qf="%{VERSION}" cuda)
$COMMON_DIR/write_component_version.sh "CUDA" ${CUDA_VERSION}

NVIDIA_VERSION=$(rpm -q --qf="%{VERSION}" cuda-drivers)
$COMMON_DIR/write_component_version.sh "NVIDIA" ${NVIDIA_VERSION}

# Post-install tasks (version its set through 'alternatives')
echo 'export PATH=$PATH:/usr/local/cuda/bin' | tee -a /etc/bash.bashrc.local
echo 'export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/cuda/lib64' | tee -a /etc/bash.bashrc.local
