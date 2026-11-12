#!/bin/bash
# In-place refresh fix-up for USN-8954-1 (zlib, CVE-2026-85091).
# Upgrades only the installed zlib binary packages and verifies that each
# installed one is at or above the fixed version for this Ubuntu release.
# https://ubuntu.com/security/notices/USN-8954-1
#
# Usage (Packer): EXTRA_PROVISION_SCRIPT=utils/fix_usn_8954_1_zlib.sh
#                 SKIP_PREREQUISITES=true REFRESH_MODE=true
set -euo pipefail

. /etc/os-release

if [[ "${ID}" != "ubuntu" ]]; then
    echo "USN-8954-1 applies to Ubuntu only (detected ${ID} ${VERSION_ID}); nothing to do."
    exit 0
fi

case "${VERSION_ID}" in
    24.04) FIXED_VERSION="1:1.3.dfsg-3.1ubuntu2.3" ;;
    26.04) FIXED_VERSION="1:1.3.dfsg+really1.3.1-1ubuntu3.2" ;;
    22.04) echo "ERROR: USN-8954-1 has no fix for Ubuntu 22.04 yet (CVE status: needs evaluation)"; exit 1 ;;
    *) echo "ERROR: no USN-8954-1 fixed version known for Ubuntu ${VERSION_ID}"; exit 1 ;;
esac

PACKAGES=(zlib1g zlib1g-dev lib32z1 lib32z1-dev lib64z1 lib64z1-dev libx32z1 libx32z1-dev)

export DEBIAN_FRONTEND=noninteractive
APT_OPTS=(-o DPkg::Lock::Timeout=600 -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold)

is_installed() { [[ "$(dpkg-query -W -f='${db:Status-Status}' "$1" 2>/dev/null || true)" == "installed" ]]; }
current_version() { dpkg-query -W -f='${Version}' "$1" 2>/dev/null || echo "none"; }

INSTALLED_PACKAGES=()
for pkg in "${PACKAGES[@]}"; do
    if is_installed "${pkg}"; then
        INSTALLED_PACKAGES+=("${pkg}")
        echo "${pkg} before: $(current_version "${pkg}") (fixed: ${FIXED_VERSION})"
    fi
done

# zlib1g is a core dependency of Ubuntu, so finding none means the wrong image.
if [[ ${#INSTALLED_PACKAGES[@]} -eq 0 ]]; then
    echo "ERROR: no zlib packages installed; expected at least zlib1g"
    exit 1
fi

# Third-party repos on HPC images can be flaky; tolerate update errors and
# rely on the version check below to decide success.
apt-get "${APT_OPTS[@]}" update || echo "WARNING: apt-get update reported errors; continuing"
apt-cache policy "${INSTALLED_PACKAGES[@]}"

apt-get "${APT_OPTS[@]}" install -y --only-upgrade "${INSTALLED_PACKAGES[@]}"

failed=0
for pkg in "${INSTALLED_PACKAGES[@]}"; do
    version="$(current_version "${pkg}")"
    echo "${pkg} after: ${version}"
    if ! dpkg --compare-versions "${version}" ge "${FIXED_VERSION}"; then
        echo "ERROR: ${pkg} ${version} is older than fixed version ${FIXED_VERSION}"
        failed=1
    fi
done

if [[ ${failed} -ne 0 ]]; then
    exit 1
fi

echo "USN-8954-1 remediated: ${INSTALLED_PACKAGES[*]} >= ${FIXED_VERSION}"
