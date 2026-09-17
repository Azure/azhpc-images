#!/bin/bash
set -ex

if [[ "${1:-}" != "NVIDIA" || -z "${2:-}" ]]; then
    echo "ERROR: RHEL requires GPU type NVIDIA and a SKU argument" >&2
    exit 1
fi
export GPU=$1
export SKU=$2

source ../../utils/set_properties.sh

bash "${COMPONENT_DIR}/install_rhel_utils.sh"
"${COMPONENT_DIR}/install_doca.sh"
"${COMPONENT_DIR}/install_nvidiagpudriver.sh" "${SKU}"
"${COMPONENT_DIR}/install_pmix.sh"
"${COMPONENT_DIR}/install_mpis.sh"
"${COMPONENT_DIR}/install_lustre_client.sh"
"${COMPONENT_DIR}/install_mpifileutils.sh"
"${COMPONENT_DIR}/install_nccl.sh"
"${COMPONENT_DIR}/install_docker.sh"
"${COMPONENT_DIR}/install_dcgm.sh"
"${COMPONENT_DIR}/install_amd_libs.sh"
"${COMPONENT_DIR}/install_intel_libs.sh"

rm -rf *.tgz *.bz2 *.tbz *.tar.gz *.run *.deb *_offline.sh
rm -rf /tmp/MLNX_OFED_LINUX* /tmp/*conf*
rm -rf /var/intel/
(
    shopt -s dotglob nullglob
    rm -rf -- /var/cache/* || true
    rm -rf -- */ || true
)

"${COMPONENT_DIR}/hpc-tuning.sh"
"${COMPONENT_DIR}/install_waagent.sh"
"${COMPONENT_DIR}/install_hpcdiag.sh"
"${COMPONENT_DIR}/install_aznfs.sh"
"${COMPONENT_DIR}/install_monitoring_tools.sh"
"${COMPONENT_DIR}/install_azure_persistent_rdma_naming.sh"
"${COMPONENT_DIR}/copy_test_file.sh"
"${COMPONENT_DIR}/install_health_checks.sh" "${GPU}"
"${COMPONENT_DIR}/write_kernel_os_version.sh"
"${COMPONENT_DIR}/install_azsecpack_prereqs.sh"
"${COMPONENT_DIR}/disable_cloudinit.sh"
"${COMPONENT_DIR}/setup_sku_customizations.sh"
"${COMPONENT_DIR}/trivy_scan.sh"

sed -i '/\[main\]/a no-auto-default=*' /etc/NetworkManager/NetworkManager.conf
mkdir -p /lib/systemd/system/cloud-init-local.service.d/
cat > /lib/systemd/system/cloud-init-local.service.d/50-azure-clear-persistent-obj-pkl.conf <<'EOF'
[Service]
ExecStartPre=-/bin/sh -xc 'if [ -e /var/lib/cloud/instance/obj.pkl ]; then echo "cleaning persistent cloud-init object"; rm /var/lib/cloud/instance/obj.pkl; fi; exit 0'
EOF

"${UTILS_DIR}/clear_history.sh"