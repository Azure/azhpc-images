#!/bin/bash
set -euo pipefail

source /etc/os-release
if [[ "${ID}" != "azurelinux" || "${VERSION_ID}" != "3.0" ]]; then
    echo "ERROR: The PMC HPC repository is only supported on Azure Linux 3.0." >&2
    exit 1
fi

architecture=${ARCHITECTURE:-$(uname -m)}
case "${architecture}" in
    x86_64|aarch64) ;;
    *)
        echo "ERROR: Unsupported PMC HPC repository architecture: ${architecture}" >&2
        exit 1
        ;;
esac

repo_url="https://packages.microsoft.com/azurelinux/3.0/prod/hpc/${architecture}/config.repo"
repo_config=$(mktemp)
trap 'rm -f "${repo_config}"' EXIT

echo "Configuring PMC HPC repository from ${repo_url}"
curl -fsSL --retry 3 --connect-timeout 15 -o "${repo_config}" "${repo_url}"
# Prefer HPC packages over other repositories, even when older. Lower values win.
sed -i -E -e '/^[[:space:]]*priority[[:space:]]*=/d' -e '/^\[/a priority=10' "${repo_config}"
install -m 0644 "${repo_config}" /etc/yum.repos.d/azurelinux-hpc.repo
