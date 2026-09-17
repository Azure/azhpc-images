#!/bin/bash
set -euo pipefail

source "${UTILS_DIR}/utilities.sh"

OS_MAJOR_VERSION=$(. /etc/os-release; echo "${VERSION_ID%%.*}")
if [[ "${OS_MAJOR_VERSION}" != "8" && "${OS_MAJOR_VERSION}" != "9" ]]; then
    echo "ERROR: RHEL dependency setup supports only RHEL 8 and 9" >&2
    exit 1
fi

"${COMPONENT_DIR}/install_microsoft_tls_root_g2.sh"
curl -fsSL "https://packages.microsoft.com/config/rhel/${OS_MAJOR_VERSION}/prod.repo" -o /etc/yum.repos.d/microsoft-prod.repo
if [[ "${OS_MAJOR_VERSION}" == "8" ]]; then
    sed -i '/^\[/a module_hotfixes=1' /etc/yum.repos.d/microsoft-prod.repo
fi

dnf install -y dnf-plugins-core
CODEREADY_REPO=$(get_rhel_rhui_repo codeready-builder)
dnf config-manager --set-enabled "${CODEREADY_REPO}"
dnf install -y "https://dl.fedoraproject.org/pub/epel/epel-release-latest-${OS_MAJOR_VERSION}.noarch.rpm"

KERNEL=$(uname -r)
dnf install -y "kernel-devel-${KERNEL}" "kernel-headers-${KERNEL}" "kernel-modules-extra-${KERNEL}" kernel-abi-stablelists
dnf groupinstall -y "Development Tools"
dnf install -y wget net-tools python3-devel python3-setuptools python3.12 \
    numactl numactl-devel libxml2-devel byacc gtk2 atk cairo tcl tk m4 \
    glibc-devel libudev-devel binutils binutils-devel selinux-policy-devel \
    nfs-utils fuse-libs libpciaccess cmake libnl3-devel libsecret rpm-build \
    make check check-devel lsof kernel-rpm-macros tcsh gcc-gfortran perl \
    json-c-devel dos2unix azcopy mdadm pssh dkms subunit subunit-devel

dnf install -y environment-modules

git clone --depth 1 https://github.com/Azure/azure-vm-utils.git /tmp/azure-vm-utils
pushd /tmp/azure-vm-utils
cmake -S . -B build -DENABLE_TESTS=0
cmake --build build
cmake --install build
popd
rm -rf /tmp/azure-vm-utils

"${COMPONENT_DIR}/copy_kvp_client.sh"
"${COMPONENT_DIR}/copy_torset_tool.sh"