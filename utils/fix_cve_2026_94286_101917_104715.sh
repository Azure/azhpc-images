#!/bin/bash
# In-place refresh fix-up for:
#   - CVE-2026-94286  (libXtst, USN-8939-1)    -> libxtst6 (+ libxtst-dev)
#   - CVE-2026-101917 (PyJWT, USN-8934-1)      -> python3-jwt
#   - CVE-2026-104715 (cifs-utils, USN-8938-1) -> cifs-utils
# Upgrades only the affected packages (if installed) and verifies that the
# installed version is >= the fixed version for this Ubuntu release.
# libxtst-dev pins libxtst6 to the exact same version, so it is upgraded
# alongside libxtst6 to avoid apt removing it.
# https://ubuntu.com/security/CVE-2026-94286
# https://ubuntu.com/security/CVE-2026-101917
# https://ubuntu.com/security/CVE-2026-104715
#
# Usage (Packer): EXTRA_PROVISION_SCRIPT=utils/fix_cve_2026_94286_101917_104715.sh
#                 SKIP_PREREQUISITES=true REFRESH_MODE=true
set -euo pipefail

. /etc/os-release

if [[ "${ID}" != "ubuntu" ]]; then
    echo "CVE-2026-94286/CVE-2026-101917/CVE-2026-104715 fix-up applies to Ubuntu only (detected ${ID} ${VERSION_ID}); nothing to do."
    exit 0
fi

declare -A FIXED_VERSIONS
case "${VERSION_ID}" in
    22.04)
        FIXED_VERSIONS[libxtst6]="2:1.2.3-1ubuntu0.22.04.1"
        FIXED_VERSIONS[python3-jwt]="2.3.0-1ubuntu0.6"
        FIXED_VERSIONS[cifs-utils]="2:6.14-1ubuntu0.7"
        ;;
    24.04)
        FIXED_VERSIONS[libxtst6]="2:1.2.3-1.1ubuntu0.1"
        FIXED_VERSIONS[python3-jwt]="2.7.0-1ubuntu0.4"
        FIXED_VERSIONS[cifs-utils]="2:7.0-2ubuntu0.6"
        ;;
    26.04)
        FIXED_VERSIONS[libxtst6]="2:1.2.5-1ubuntu0.1"
        FIXED_VERSIONS[python3-jwt]="2.10.1-4ubuntu1.3"
        FIXED_VERSIONS[cifs-utils]="2:7.4-1ubuntu0.26.04.4"
        ;;
    *) echo "ERROR: no fixed versions known for Ubuntu ${VERSION_ID}"; exit 1 ;;
esac
FIXED_VERSIONS[libxtst-dev]="${FIXED_VERSIONS[libxtst6]}"
PACKAGES=(libxtst6 libxtst-dev python3-jwt cifs-utils)

export DEBIAN_FRONTEND=noninteractive
APT_OPTS=(-o DPkg::Lock::Timeout=600 -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold)

is_installed() { [[ "$(dpkg-query -W -f='${db:Status-Status}' "$1" 2>/dev/null || true)" == "installed" ]]; }
current_version() { dpkg-query -W -f='${Version}' "$1" 2>/dev/null || echo "none"; }

INSTALLED_PACKAGES=()
for pkg in "${PACKAGES[@]}"; do
    if is_installed "${pkg}"; then
        INSTALLED_PACKAGES+=("${pkg}")
        echo "${pkg} before: $(current_version "${pkg}") (fixed: ${FIXED_VERSIONS[${pkg}]})"
    else
        echo "${pkg} is not installed; not affected, skipping."
    fi
done

if [[ ${#INSTALLED_PACKAGES[@]} -eq 0 ]]; then
    echo "No affected packages installed; nothing to do."
    exit 0
fi

# Third-party repos on HPC images can be flaky; tolerate update errors and
# rely on the version check below to decide success.
apt-get "${APT_OPTS[@]}" update || echo "WARNING: apt-get update reported errors; continuing"
apt-cache policy "${INSTALLED_PACKAGES[@]}"

apt-get "${APT_OPTS[@]}" install -y --only-upgrade "${INSTALLED_PACKAGES[@]}"

failed=0
for pkg in "${INSTALLED_PACKAGES[@]}"; do
    installed_version="$(current_version "${pkg}")"
    echo "${pkg} after: ${installed_version}"
    if ! dpkg --compare-versions "${installed_version}" ge "${FIXED_VERSIONS[${pkg}]}"; then
        echo "ERROR: ${pkg} ${installed_version} is older than fixed version ${FIXED_VERSIONS[${pkg}]}"
        failed=1
    fi
done

if [[ ${failed} -ne 0 ]]; then
    exit 1
fi

echo "CVE-2026-94286/CVE-2026-101917/CVE-2026-104715 remediated: $(for p in "${INSTALLED_PACKAGES[@]}"; do printf '%s=%s ' "${p}" "$(current_version "${p}")"; done)"
