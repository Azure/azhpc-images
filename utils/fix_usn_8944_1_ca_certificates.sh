#!/bin/bash
# In-place refresh fix-up for USN-8944-1 (ca-certificates).
# Upgrades only the ca-certificates package and verifies the fix:
#   - installed version >= the fixed version for this Ubuntu release
#   - "emSign ECC Root CA - G3" is no longer trusted
# https://ubuntu.com/security/notices/USN-8944-1
#
# Usage (Packer): EXTRA_PROVISION_SCRIPT=utils/fix_usn_8944_1_ca_certificates.sh
#                 SKIP_PREREQUISITES=true REFRESH_MODE=true
set -euo pipefail

. /etc/os-release

if [[ "${ID}" != "ubuntu" ]]; then
    echo "USN-8944-1 applies to Ubuntu only (detected ${ID} ${VERSION_ID}); nothing to do."
    exit 0
fi

case "${VERSION_ID}" in
    22.04) FIXED_VERSION="20260816ubuntu0.22.04.1" ;;
    24.04) FIXED_VERSION="20260816ubuntu0.24.04.1" ;;
    26.04) FIXED_VERSION="20260816ubuntu0.26.04.1" ;;
    *) echo "ERROR: no USN-8944-1 fixed version known for Ubuntu ${VERSION_ID}"; exit 1 ;;
esac

export DEBIAN_FRONTEND=noninteractive
APT_OPTS=(-o DPkg::Lock::Timeout=600 -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold)

current_version() { dpkg-query -W -f='${Version}' ca-certificates 2>/dev/null || echo "none"; }

echo "ca-certificates before: $(current_version) (fixed: ${FIXED_VERSION})"

# Third-party repos on HPC images can be flaky; tolerate update errors and
# rely on the version check below to decide success.
apt-get "${APT_OPTS[@]}" update || echo "WARNING: apt-get update reported errors; continuing"
apt-cache policy ca-certificates

apt-get "${APT_OPTS[@]}" install -y --only-upgrade ca-certificates

INSTALLED_VERSION="$(current_version)"
echo "ca-certificates after: ${INSTALLED_VERSION}"

if ! dpkg --compare-versions "${INSTALLED_VERSION}" ge "${FIXED_VERSION}"; then
    echo "ERROR: ca-certificates ${INSTALLED_VERSION} is older than fixed version ${FIXED_VERSION}"
    exit 1
fi

if [[ -e /usr/share/ca-certificates/mozilla/emSign_ECC_Root_CA_-_G3.crt ]] \
    || ls /etc/ssl/certs/emSign_ECC_Root_CA_-_G3* >/dev/null 2>&1; then
    echo "ERROR: emSign ECC Root CA - G3 is still present in the trust store"
    exit 1
fi

echo "USN-8944-1 remediated: ca-certificates ${INSTALLED_VERSION}"
