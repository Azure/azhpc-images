#!/bin/bash
set -ex

# set properties
source ./set_properties.sh

kernel_with_dots=${KERNEL/-/.}

nvidia_driver_metadata=$(jq -r '.nvidia."'"$DISTRIBUTION"'".driver' <<< $COMPONENT_VERSIONS)
nvidia_driver_version=$(jq -r '.version' <<< $nvidia_driver_metadata)

echo $kernel_with_dots
echo $nvidia_driver_version

echo ${nvidia_driver_version}_${kernel_with_dots}
echo cuda-${nvidia_driver_version}_${kernel_with_dots}.rpm