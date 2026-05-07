#!/bin/bash

set -ex

source ${UTILS_DIR}/utilities.sh

aznhc_metadata=$(get_component_config "aznhc")
AZHC_VERSION=$(jq -r '.version' <<< $aznhc_metadata)
AZHC_SHA=$(jq -r '.sha256' <<< $aznhc_metadata)

DEST_TEST_DIR=/opt/azurehpc/test
GPU_PLAT=$1

TARBALL="v${AZHC_VERSION}.tar.gz"
AZHC_DOWNLOAD_URL=https://github.com/Azure/azurehpc-health-checks/archive/refs/tags/${TARBALL}
download_and_verify ${AZHC_DOWNLOAD_URL} ${AZHC_SHA} $DEST_TEST_DIR

pushd $DEST_TEST_DIR
mkdir azurehpc-health-checks && tar -xvf $TARBALL --strip-components=1 -C azurehpc-health-checks  
pushd azurehpc-health-checks
rm ./triggerGHR/triggerGHR.sh
cp $COMPONENT_DIR/trigger_aznhc_GHR.sh ./triggerGHR/triggerGHR.sh
dos2unix ./triggerGHR/config/*
chmod +x ./triggerGHR/triggerGHR.sh
chmod +x ./dockerfile/pull-image-mcr.sh
# Pull down docker container from MCR
if [ "${GPU_PLAT}" = "AMD" ]; then
   ./dockerfile/pull-image-mcr.sh rocm
else
   sed -i 's/\* || check_gpu_bw 10/\* || check_gpu_bw 9/' ./conf/nd40rs_v2.conf
   sed -i 's#\* || check_nccl_allreduce 431.0 1 16G $AZ_NHC_ROOT/topofiles/ndv5-topo.xml#\* || check_nccl_allreduce 431.0 1 16G#' ./conf/nd96isr_h200_v5.conf
   sed -i 's#\* || check_nccl_allreduce 460.0 1 16G $AZ_NHC_ROOT/topofiles/ndv5-topo.xml#\* || check_nccl_allreduce 460.0 1 16G#' ./conf/nd96isr_h100_v5.conf

   # Ubuntu 26.04: disable GDR-dependent checks.
   #
   # Why: Ubuntu 26.04 (linux-azure 7.0) doesn't ship the legacy
   # ib_register_peer_memory_client() kABI that `nvidia-peermem` requires,
   # and DOCA-OFED is intentionally skipped on this distro (see
   # install_doca.sh / install_nvidiagpudriver.sh). The hardware DOES
   # support GPUDirect RDMA via the modern DMABUF path
   # (CONFIG_DMABUF_MOVE_NOTIFY=y, NVIDIA open-driver gpu_dmabuf,
   # rdma-core's ibv_reg_dmabuf_mr) — verified locally with a
   # CUDA-enabled perftest build — but the aznhc-nv container ships an
   # `ib_write_bw` compiled without HAVE_CUDA/HAVE_CUDA_DMABUF, so
   # check_ib_bw_gdr aborts at parse time with "Unsupported memory type"
   # and check_nccl_allreduce_ib_loopback can't reach the GDR path either.
   # Re-enable these once aznhc-nv ships a CUDA-enabled perftest (and
   # add `--use_cuda_dmabuf` to azure_ib_write_bw_gdr.nhc).
   if [[ "$DISTRIBUTION" == "ubuntu26.04" ]]; then
      gdr_disabled_comment='# DISABLED on ubuntu26.04 (no nvidia-peermem; aznhc perftest lacks DMABUF):'
      for cfg in ./conf/*.conf; do
         # Use BRE with `@` as the s-delimiter so the literal `||` and the `#` in
         # the replacement are not reinterpreted (sed -E would parse `\|\|` as
         # alternation, and `#` would clash with `s###` delimiters).
         sed -i "s@^\([[:space:]]*\)\* || check_ib_bw_gdr @\1${gdr_disabled_comment} * || check_ib_bw_gdr @" "$cfg"
         sed -i "s@^\([[:space:]]*\)\* || check_nccl_allreduce_ib_loopback @\1${gdr_disabled_comment} * || check_nccl_allreduce_ib_loopback @" "$cfg"
      done
   fi

   ./dockerfile/pull-image-mcr.sh cuda
fi
popd
popd

write_component_version "AZ_HEALTH_CHECKS" ${AZHC_VERSION}

if [[ $DISTRIBUTION == "azurelinux3.0" ]]; then
   kernel_version=$(rpm -q kernel | sed 's/kernel\-//g')
   write_component_version "KERNEL" ${kernel_version::-12}
   os_version=$(rpm -qf /etc/os-release)
   write_component_version "OS" ${os_version::-12}
else
   write_component_version "KERNEL" $(uname -r)
fi