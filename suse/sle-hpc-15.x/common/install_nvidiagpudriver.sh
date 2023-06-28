#!/bin/bash
set -ex

#
## Nvidia provide certified packages for SLES 15 SP4, so we only need to add the repositories and install the packages
#
DRIVER_BRANCH_VERSION=${NVIDIA_VERSION%.*.*} # branch is like main version e.g. 525 from 525.85.12
CUDA_DASH_VERSION=${CUDA_VERSION/./-}

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
# cuda-libraries-devel-11-8 	Installs all development CUDA Library packages.
# cuda-drivers 	            Installs all Driver packages. Handles upgrading to the next version of the Driver packages when they're released.

# due to NVIDIA bug in post-install of the nvidia-drivers for kernel-azure, we need to select and install nvidia-gfxG05-kmp-azure manually
# The cuda dependencies select packages with "-default" and then the (wrong) modules for kernel-default instead of kernel-azure got installed
#
# Don't install cuda-drivers: this introduces X11 and Wayland - instead install nvidia-computeGXX
# Don't install cuda-toolkit: this introduces visualization tools
# - instead install cuda-compilers, cuda-command-line-tools, gds-tools and cuda_libraries
zypper -n install -y -l --no-recommends cuda-toolkit-${CUDA_DASH_VERSION} cuda-compiler-${CUDA_DASH_VERSION} cuda-command-line-tools-${CUDA_DASH_VERSION} gds-tools-${CUDA_DASH_VERSION} cuda-libraries-${CUDA_DASH_VERSION}  nvidia-fabricmanager = ${NVIDIA_VERSION} "nvidia-gfxG05-kmp-azure = ${NVIDIA_VERSION}" "nvidia-computeG05 = ${NVIDIA_VERSION}"


$COMMON_DIR/write_component_version.sh "CUDA" ${CUDA_VERSION}
$COMMON_DIR/write_component_version.sh "NVIDIA" ${NVIDIA_VERSION}

# Post-install tasks (version its set through 'alternatives')
echo 'export PATH=$PATH:/usr/local/cuda/bin' | tee -a /etc/bash.bashrc.local
echo '/usr/local/cuda/lib64' | tee /etc/ld.so.conf.d/cuda.conf

# start the fabricmanager - needed for run-tests on ND96asr_v4
# systemctl start nvidia-fabricmanager.service
