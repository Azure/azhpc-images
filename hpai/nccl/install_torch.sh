#!/bin/bash
set -ex

# Install CuDNN

OS=ubuntu2004
CUDNN_DIR=/opt/cudnn
mkdir -p ${CUDNN_DIR}
cd ${CUDNN_DIR}
wget https://developer.download.nvidia.com/compute/cuda/repos/${OS}/x86_64/cuda-${OS}.pin
mv cuda-${OS}.pin /etc/apt/preferences.d/cuda-repository-pin-600
apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/${OS}/x86_64/7fa2af80.pub
add-apt-repository "deb https://developer.download.nvidia.com/compute/cuda/repos/${OS}/x86_64/ /"
apt update

CUDNN_VERSION=8.2.4.15
CUDA_VERSION=cuda11.4
apt install libcudnn8=${CUDNN_VERSION}-1+${CUDA_VERSION}
apt install libcudnn8-dev=${CUDNN_VERSION}-1+${CUDA_VERSION}

# Install MAGMA
apt update

apt install --yes \
    libopenblas-dev \
	gfortran

MAGMA_DIR=/opt/magma
mkdir -p ${MAGMA_DIR}
git clone https://bitbucket.org/icl/magma.git ${MAGMA_DIR}
cd ${MAGMA_DIR}

cat << EOF >> make.inc
BACKEND = cuda
FORT = true
EOF

GPU_TARGET=Ampere make generate

mkdir ${MAGMA_DIR}/build
cd ${MAGMA_DIR}/build
rm -rf ${MAGMA_DIR}/build/*
cmake -DGPU_TARGET="Volta, Turing, Ampere" ..
make -j

# Install PyTorch

apt update

# Install some required Python dependencies
apt install --yes \
	python3-dev \
	python3-pip \
	python3-venv \
	ninja-build

NCCL_VERSION="2.12.10-1"
PYTORCH_VERSION="1.10.2"

TORCH_DIR=/opt/pytorch

git clone https://github.com/pytorch/pytorch.git ${TORCH_DIR}
cd ${TORCH_DIR}
git checkout tags/v${PYTORCH_VERSION} -b v${PYTORCH_VERSION}_nccl
git submodule sync third_party/nccl
git submodule update --init --recursive
git submodule update --init --recursive --remote third_party/nccl

cd ${TORCH_DIR}/third_party/nccl/nccl

git checkout tags/v${NCCL_VERSION} -b v${NCCL_VERSION}

cd ${TORCH_DIR}

python3 -m pip install --upgrade pip
pip3 install \
    astunparse \
    numpy \
	ninja \
	pyyaml \
	setuptools \
	cmake \
	cffi \
	typing_extensions \
	future \
	six \
	requests \
	dataclasses \
	expecttest \
	pytest \
	hypothesis \
	pybind11 \
	regex \
	tensorboard \

# For ONNX
pip3 install \
    protobuf==3.16.0 \
	onnx \
	onnxruntime

MAX_JOBS=16 USE_MAGMA=1 python3 setup.py install

# Torchvision
# v 0.11.3 goes with Pytorch 1.10.2, see https://github.com/pytorch/vision for correct mapping
TORCHVISION_VERSION=0.11.3

TORCHVISION_DIR=/opt/torchvision
mkdir -p ${TORCHVISION_DIR}
cd ${TORCHVISION_DIR}
git clone https://github.com/pytorch/vision.git .
git checkout tags/v${TORCHVISION_VERSION} -b v${TORCHVISION_VERSION}_build
python3 setup.py install

# Torchaudio
# v 0.10.0 goes with Pytorch 1.10.2, https://github.com/pytorch/audio for correct mapping
TORCHAUDIO_VERSION=0.10.0

TORCHAUDIO_DIR=/opt/torchaudio
mkdir -p ${TORCHAUDIO_DIR}
cd ${TORCHAUDIO_DIR}
git clone https://github.com/pytorch/vision.git .
git checkout tags/v${TORCHAUDIO_VERSION} -b v${TORCHAUDIO_VERSION}_build
python3 setup.py install

# Apex
COMMON_DIR=`pwd`

cd /tmp

git clone https://github.com/NVIDIA/apex.git
cd apex
# Fix a specific commit.  We can change this to a stable tag if Apex stablizes.
git checkout 7950a82d89c07422b4f6638ce773306a879e3ff7

# Apply a patch to fix a broken CUDA version check.
patch -u setup.py ${COMMON_DIR}/apex_cuda_version.patch

pip3 install -v --disable-pip-version-check --no-cache-dir --global-option="--cpp_ext" --global-option="--cuda_ext" ./

rm -rf /tmp/apex
