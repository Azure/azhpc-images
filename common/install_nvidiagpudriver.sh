#!/bin/bash
set -ex

# Install Cuda
CUDA_URL=https://developer.download.nvidia.com/compute/cuda/11.2.2/local_installers/cuda_11.2.2_460.32.03_linux.run
$COMMON_DIR/download_and_verify.sh $CUDA_URL "0a2e477224af7f6003b49edfd2bfee07667a8148fe3627cfd2765f6ad72fa19d"
chmod +x cuda_11.2.2_460.32.03_linux.run
sudo ./cuda_11.2.2_460.32.03_linux.run --silent
echo 'export PATH=$PATH:/usr/local/cuda/bin' | sudo tee -a /etc/bash.bashrc
echo 'export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/cuda/lib64' | sudo tee -a /etc/bash.bashrc
