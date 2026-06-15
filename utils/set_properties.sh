#!/bin/bash
set -ex

export TOP_DIR="$(dirname "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)")"
export COMPONENT_DIR=$TOP_DIR/components
export AZHPC_IMAGES_TEST_DIR=$TOP_DIR/tests
export UTILS_DIR=$TOP_DIR/utils
export DISTRIBUTION=$(. /etc/os-release;echo $ID$VERSION_ID)

if [[ $DISTRIBUTION == *"ubuntu"* ]]; then
    export ARCHITECTURE_DISTRO=$(dpkg --print-architecture)
else    
    export ARCHITECTURE_DISTRO=$(rpm --eval '%{_arch}')
fi
export ARCHITECTURE=$(uname -m)

# TARGET_NODE_TYPE identifies the deployment context:
#   'azure_vm_regular'  (default) — Azure Virtual Machine image build/test
#   'azure_vm_akshost'            — Azure Virtual Machine image build/test for AKS Host OS image
#   'baremetal_3p'        — 3P Bare-metal node (e.g. Nebius), no Azure IMDS,
#                           IB not brought up, IPoIB not used.
#   'baremetal_1p'        — 1P Bare-metal node (e.g. Nebius), no Azure IMDS,
#                           Azure Specialized Image.
# Baremetal_3P callers must set TARGET_NODE_TYPE=baremetal_3p in their environment
# before sourcing this script.
export TARGET_NODE_TYPE="${TARGET_NODE_TYPE:-azure_vm_regular}"

# Derive SKU_FAMILY from SKU so all downstream scripts use a single canonical
# GPU-family identifier instead of repeated per-SKU string comparisons.
# This captures GPU hardware capability (e.g. NVLink, CDMM) shared by both
# Azure VM and baremetal GB200/GB300 deployments.
# Callers may set SKU_FAMILY directly in their environment to override.
if [[ -z "${SKU_FAMILY:-}" ]]; then
    case "${SKU:-}" in
        GB200|GB300) export SKU_FAMILY="gb-family" ;;
        *)           export SKU_FAMILY="${SKU:-}" ;;
    esac
fi

if [[ $DISTRIBUTION == *"ubuntu"* ]]; then
    if [[ "${TARGET_NODE_TYPE}" == "baremetal_3p" ]]; then
        # Baremetal: skip apt upgrade — the offline ISO installer cannot reach
        # online package mirrors; the base image is already validated.
        echo "[set_properties.sh] Skipping apt update/upgrade on baremetal 3P node"
    else
        # Azure VM: pin the kernel package to prevent unintended kernel upgrades,
        # then upgrade all other pre-installed components.
        # Kept for legacy image build workflow
        if [[ "${SKU_FAMILY}" == "gb-family" ]]; then
            apt-mark hold linux-azure-nvidia
        else
            apt-mark hold linux-azure-${KERNEL_VERSION:-6.8}
        fi
        apt update
        apt upgrade -y
    fi
    # jq is needed to parse the component versions from the versions.json file
    apt install -y jq
    export MODULE_FILES_DIRECTORY=/usr/share/modules/modulefiles
elif [[ $DISTRIBUTION == almalinux* ]]; then
    if [[ $DISTRIBUTION == "almalinux8.10" ]]; then
        # Import the newest AlmaLinux GPG key
        rpm --import https://repo.almalinux.org/almalinux/RPM-GPG-KEY-AlmaLinux
    elif [[ $DISTRIBUTION == almalinux9* ]]; then
        rpm --import https://repo.almalinux.org/almalinux/RPM-GPG-KEY-AlmaLinux-9
    fi
    yum install -y jq    
    export MODULE_FILES_DIRECTORY=/usr/share/Modules/modulefiles
elif [[ $DISTRIBUTION == "azurelinux3.0" ]]; then
    tdnf install -y jq
    export MODULE_FILES_DIRECTORY=/usr/share/Modules/modulefiles
else
    # Rocky Linux, RHEL, and other RHEL-family distros
    dnf install -y jq
    export MODULE_FILES_DIRECTORY=/usr/share/Modules/modulefiles
fi

# Component Versions
export COMPONENT_VERSIONS=$(jq -r . $TOP_DIR/versions.json)

source ${UTILS_DIR}/utilities.sh
