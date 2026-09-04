#!/bin/bash
set -ex

# Check if arguments are passed
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Error: Missing arguments. Please provide both GPU type (NVIDIA/AMD) and SKU."
    exit 1
fi

export GPU=$1
export SKU=$2

if [[ "$#" -gt 0 ]]; then
   if [[ "$GPU" != "NVIDIA" && "$GPU" != "AMD" ]]; then
       echo "Error: Invalid GPU type. Please specify 'NVIDIA' or 'AMD'."
       exit 1
    fi
fi

# TODO(ubuntu26.04): add ROCm, RCCL, HPC-X AMD metadata, and an AMD test matrix
# before enabling this path.
if [[ "$GPU" == "AMD" ]]; then
    echo "##[error]AMD GPUs are not supported on Ubuntu 26.04 yet."
    exit 1
fi

# These SKUs need driver, architecture, or network paths that have not been
# validated on Ubuntu 26.04 yet.
if [[ "$SKU" == "GB200" || "$SKU" == "VR200" || "$SKU" == "NCv6" ]]; then
    echo "##[error]$SKU is not supported on Ubuntu 26.04 yet."
    exit 1
fi

source ../../utils/set_properties.sh
source ${UTILS_DIR}/utilities.sh

./install_utils.sh

# install DOCA OFED
$COMPONENT_DIR/install_doca.sh

# Install MPI libraries. HPC-X 2.51 supplies the Open MPI 5, PMIx 5, hwloc,
# and libevent stack used on Ubuntu 26.04.
$COMPONENT_DIR/install_mpis.sh

if [ "$GPU" = "NVIDIA" ]; then
    # install nvidia gpu driver
    $COMPONENT_DIR/install_nvidiagpudriver.sh
    
    # Install NCCL
    $COMPONENT_DIR/install_nccl.sh
fi

# Install Docker container runtime
$COMPONENT_DIR/install_docker.sh

if [ "$GPU" = "NVIDIA" ]; then
    # Install DCGM
    $COMPONENT_DIR/install_dcgm.sh
fi

# install Lustre client; the shared installer skips kernel 7.0 until AMLFS
# publishes a compatible package.
$COMPONENT_DIR/install_lustre_client.sh

# install mpifileutils
$COMPONENT_DIR/install_mpifileutils.sh

if [ "$ARCHITECTURE" == "x86_64" ]; then

    # install AMD libs
    $COMPONENT_DIR/install_amd_libs.sh

    # install Intel libraries
    $COMPONENT_DIR/install_intel_libs.sh
fi

# install dynolog and dyno-relay-logger
$COMPONENT_DIR/install_dynolog_drl.sh

# cleanup downloaded tarballs - clear some space
rm -rf *.tgz *.bz2 *.tbz *.tar.gz *.run *.deb *_offline.sh
rm -rf /tmp/MLNX_OFED_LINUX* /tmp/*conf*
rm -rf /var/intel/
(
    shopt -s dotglob nullglob
    rm -rf -- /var/cache/* || true
    rm -Rf -- */ || true
)

# optimizations
$COMPONENT_DIR/hpc-tuning.sh

# install Azure Linux Agent
$COMPONENT_DIR/install_waagent.sh

# install persistent rdma naming
$COMPONENT_DIR/install_azure_persistent_rdma_naming.sh

# Install AZNFS Mount Helper
$COMPONENT_DIR/install_aznfs.sh

# install diagnostic script
$COMPONENT_DIR/install_hpcdiag.sh

# install monitor tools
$COMPONENT_DIR/install_monitoring_tools.sh

# install Azure/NHC Health Checks
$COMPONENT_DIR/install_health_checks.sh "$GPU"

# write kernel and OS version metadata
$COMPONENT_DIR/write_kernel_os_version.sh

$COMPONENT_DIR/install_azsecpack_prereqs.sh

# add udev rule
$COMPONENT_DIR/add-udev-rules.sh

# copy test file
$COMPONENT_DIR/copy_test_file.sh

# disable cloud-init
$COMPONENT_DIR/disable_cloudinit.sh

# SKU Customization
$COMPONENT_DIR/setup_sku_customizations.sh

# scan vulnerabilities using Trivy
$COMPONENT_DIR/trivy_scan.sh

# Disable unattended upgrades
./disable_auto_upgrade.sh

# Disable Predictive Network interface renaming
./disable_predictive_interface_renaming.sh

# clear history
# Uncomment the line below if you are running this on a VM
# $UTILS_DIR/clear_history.sh
