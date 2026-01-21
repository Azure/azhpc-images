#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

# Install Moby Engine and CLI
if [[ $DISTRIBUTION == *"ubuntu"* ]]; then
    if [[ "$ARCHITECTURE" == "aarch64" ]]; then
        moby_metadata=$(get_component_config "moby")
        MOBY_VERSION=$(jq -r '.version' <<< $moby_metadata)
        apt-get install -y moby-engine=${MOBY_VERSION}
        apt-get install -y moby-cli=${MOBY_VERSION}
    else
        apt-get install -y moby-engine
        apt-get install -y moby-cli
    fi
elif [[ $DISTRIBUTION == almalinux* ]]; then
    yum install -y moby-engine
    yum install -y moby-cli
elif [[ $DISTRIBUTION == "azurelinux3.0" ]]; then
    tdnf install -y moby-engine
    tdnf install -y moby-cli
fi

$COMPONENT_DIR/install_nvidia_container_toolkit.sh

# enable and restart the docker daemon to complete the installation
systemctl enable docker
systemctl restart docker

# restart containerd service
systemctl restart containerd

# status of containerd snapshotter plugins
ctr plugin ls

# Write the docker version to components file
docker_version=$(docker --version | awk -F' ' '{print $3}')
write_component_version "DOCKER" ${docker_version::-1}

if [[ $DISTRIBUTION == ubuntu* ]]; then
    moby_version=$(apt list --installed | grep moby-engine | awk -F' ' '{print $2}')
elif [[ $DISTRIBUTION == almalinux* ]]; then
    moby_version=$(yum list installed | grep moby-engine | awk -F' ' '{print $2}')
elif [[ $DISTRIBUTION == "azurelinux3.0" ]]; then
    moby_version=$(rpm -qa | grep moby | cut -d'-' -f3,4)
fi
write_component_version "MOBY_ENGINE" ${moby_version}
