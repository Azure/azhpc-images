#!/bin/bash
set -ex

# Install NVIDIA Container Toolkit
# Reference: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html
# Setting up NVIDIA Container Toolkit
if [[ $DISTRIBUTION == *"ubuntu"* ]]; then
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
    && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
        sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
        sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

    sed -i -e '/experimental/ s/^#//g' /etc/apt/sources.list.d/nvidia-container-toolkit.list

    apt-get update
    # Install NVIDIA container toolkit and mark NVIDIA packages on hold
    apt-get install -y nvidia-container-toolkit
    apt-mark hold nvidia-container-toolkit
    apt-mark hold libnvidia-container-tools
    apt-mark hold libnvidia-container1

    # Remove unwanted repos
    rm -f /etc/apt/sources.list.d/nvidia*
elif [[ $DISTRIBUTION == almalinux* ]]; then
    curl -s -L https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo | \
    sudo tee /etc/yum.repos.d/nvidia-container-toolkit.repo

    if [[ $DISTRIBUTION == almalinux8.10 ]]; then
        yum-config-manager --enable nvidia-container-toolkit-experimental
    elif [[ $DISTRIBUTION == almalinux9.6 ]]; then
        dnf config-manager --enable nvidia-container-toolkit-experimental
    fi
    yum update -y

    yum clean expire-cache
    yum install -y nvidia-container-toolkit

    # Mark the installed packages on hold to disable updates
    sed -i "$ s/$/ *nvidia-container*/" /etc/dnf/dnf.conf

    # Clean repos
    rm -rf /etc/yum.repos.d/nvidia-*
    rm -rf /var/cache/yum/x86_64/8/nvidia-*
    rm -rf /var/cache/yum/x86_64/8/libnvidia-container/
elif [[ $DISTRIBUTION == "azurelinux3.0" ]]; then
    tdnf install --noplugins -y nvidia-container-toolkit-base nvidia-container-toolkit
    tdnf install --noplugins -y nvidia-container-runtime
    sed -i "$ s/$/ *nvidia-container*/" /etc/dnf/dnf.conf
fi

# Configure NVIDIA Container Toolkit
nvidia-ctk runtime configure --runtime=docker

# Configure containerd to use NVIDIA runtime
mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
if [[ $DISTRIBUTION == *"ubuntu"* ]] || [[ $DISTRIBUTION == *"almalinux"* ]]; then
    sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml  
fi
nvidia-ctk runtime configure --runtime=containerd --set-as-default
if [[ $DISTRIBUTION == "azurelinux3.0" ]]; then
    sed -i '/\[plugins\.\"io\.containerd\.cri\.v1\.runtime\".containerd\.runtimes\.runc\.options\]/a \ \ \ \ \ \ \ \ \ \ \ \ SystemdCgroup = true' /etc/containerd/config.toml
    sed -i '/\[plugins\.\"io\.containerd\.cri\.v1\.runtime\".containerd\.runtimes\.nvidia\.options\]/a \ \ \ \ \ \ \ \ \ \ \ \ SystemdCgroup = true' /etc/containerd/config.toml
fi