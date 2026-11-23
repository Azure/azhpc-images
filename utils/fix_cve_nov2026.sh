#!/bin/bash
# In-place refresh fix-up for the November 2026 refresh CVE findings (Trivy,
# Ubuntu CVE Tracker) across the HPC Ubuntu images (MI300X, A100, ...):
#   - src:linux userspace packages (linux-libc-dev, linux-tools-common,
#     linux-cloud-tools-common), CRITICAL/HIGH, e.g. CVE-2026-89652 (22.04),
#     CVE-2026-63825 (24.04). The running linux-azure kernel is NOT changed.
#   - pyjwt         (python3-jwt)            CVE fixed 2026-11-19
#   - gstreamer1.0  (libgstreamer1.0-0, ...) USN-9152-1
#   - openjdk-21    (openjdk-21-jre, ...)    USN-9156-1
#   - libcpanel-json-xs-perl                 USN-9092-1
# Only packages that are installed AND older than the fixed version are
# upgraded; if nothing is affected the script exits without touching apt, so it
# is safe to run on every Ubuntu image. Non-Ubuntu images are a no-op.
#
# Usage (Packer): EXTRA_PROVISION_SCRIPT=utils/fix_cve_nov2026.sh
#                 SKIP_PREREQUISITES=true REFRESH_MODE=true
set -euo pipefail

. /etc/os-release

if [[ "${ID}" != "ubuntu" ]]; then
    echo "Nov 2026 CVE fix-up applies to Ubuntu only (detected ${ID} ${VERSION_ID}); nothing to do."
    exit 0
fi

# Binaries built from the same source pin each other's exact version (e.g.
# libgstreamer1.0-dev = libgstreamer1.0-0), so every installed binary of an
# affected source is upgraded together.
SOURCES=(linux pyjwt gstreamer1.0 openjdk-21 libcpanel-json-xs-perl)
declare -A SOURCE_BINARIES=(
    [linux]="linux-libc-dev linux-tools-common linux-cloud-tools-common"
    [pyjwt]="python3-jwt"
    [gstreamer1.0]="libgstreamer1.0-0 libgstreamer1.0-dev gstreamer1.0-tools gir1.2-gstreamer-1.0"
    [openjdk-21]="openjdk-21-jre-headless openjdk-21-jre openjdk-21-jre-zero openjdk-21-jdk-headless openjdk-21-jdk openjdk-21-demo openjdk-21-source openjdk-21-doc openjdk-21-testsupport"
    [libcpanel-json-xs-perl]="libcpanel-json-xs-perl"
)

declare -A FIXED_SOURCE_VERSIONS
case "${VERSION_ID}" in
    22.04)
        FIXED_SOURCE_VERSIONS=(
            [linux]="5.15.0-204.214"
            [pyjwt]="2.3.0-1ubuntu0.7"
            [gstreamer1.0]="1.20.3-0ubuntu1.2"
            [openjdk-21]="21.0.13.1+2-1~22.04.1"
            [libcpanel-json-xs-perl]="4.27-1ubuntu0.3"
        )
        ;;
    24.04)
        FIXED_SOURCE_VERSIONS=(
            [linux]="6.8.0-151.151"
            [pyjwt]="2.7.0-1ubuntu0.5"
            [gstreamer1.0]="1.24.2-1ubuntu0.2"
            [openjdk-21]="21.0.13.1+2-1~24.04.1"
            [libcpanel-json-xs-perl]="4.37-1ubuntu0.2"
        )
        ;;
    26.04)
        # No src:linux entry: not covered by the November scans for 26.04.
        FIXED_SOURCE_VERSIONS=(
            [pyjwt]="2.10.1-4ubuntu1.4"
            [gstreamer1.0]="1.28.2-1ubuntu0.1"
            [openjdk-21]="21.0.13.1+2-1~26.04.1"
            [libcpanel-json-xs-perl]="4.40-1ubuntu0.1"
        )
        ;;
    *) echo "ERROR: no fixed versions known for Ubuntu ${VERSION_ID}"; exit 1 ;;
esac

export DEBIAN_FRONTEND=noninteractive
APT_OPTS=(-o DPkg::Lock::Timeout=600 -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold)

is_installed() { [[ "$(dpkg-query -W -f='${db:Status-Status}' "$1" 2>/dev/null || true)" == "installed" ]]; }
current_version() { dpkg-query -W -f='${Version}' "$1" 2>/dev/null || echo "none"; }
list_kernels() { find /boot -maxdepth 1 -name 'vmlinuz-*' 2>/dev/null | sort; }

declare -A FIXED_VERSIONS
UPGRADE_PACKAGES=()
for src in "${SOURCES[@]}"; do
    fixed="${FIXED_SOURCE_VERSIONS[${src}]:-}"
    [[ -n "${fixed}" ]] || continue
    for pkg in ${SOURCE_BINARIES[${src}]}; do
        is_installed "${pkg}" || continue
        version="$(current_version "${pkg}")"
        if dpkg --compare-versions "${version}" ge "${fixed}"; then
            echo "${pkg} ${version} already >= fixed ${fixed}; skipping."
        else
            echo "${pkg} ${version} < fixed ${fixed}; will upgrade."
            FIXED_VERSIONS[${pkg}]="${fixed}"
            UPGRADE_PACKAGES+=("${pkg}")
        fi
    done
done

if [[ ${#UPGRADE_PACKAGES[@]} -eq 0 ]]; then
    echo "No affected packages need upgrading on Ubuntu ${VERSION_ID}; nothing to do."
    exit 0
fi

KERNELS_BEFORE="$(list_kernels)"

# Third-party repos on HPC images can be flaky; tolerate update errors and
# rely on the version check below to decide success.
apt-get "${APT_OPTS[@]}" update || echo "WARNING: apt-get update reported errors; continuing"
apt-cache policy "${UPGRADE_PACKAGES[@]}"

apt-get "${APT_OPTS[@]}" install -y --only-upgrade "${UPGRADE_PACKAGES[@]}"

failed=0
for pkg in "${UPGRADE_PACKAGES[@]}"; do
    version="$(current_version "${pkg}")"
    echo "${pkg} after: ${version}"
    if ! dpkg --compare-versions "${version}" ge "${FIXED_VERSIONS[${pkg}]}"; then
        echo "ERROR: ${pkg} ${version} is older than fixed version ${FIXED_VERSIONS[${pkg}]}"
        failed=1
    fi
done

# These packages must not drag in a new kernel image; fail if one appeared.
NEW_KERNELS="$(comm -13 <(echo "${KERNELS_BEFORE}") <(list_kernels))"
if [[ -n "${NEW_KERNELS}" ]]; then
    echo "ERROR: upgrade installed new kernel image(s): ${NEW_KERNELS//$'\n'/ }"
    failed=1
fi

if [[ ${failed} -ne 0 ]]; then
    exit 1
fi

echo "Nov 2026 CVE fix-up complete: $(for p in "${UPGRADE_PACKAGES[@]}"; do printf '%s=%s ' "${p}" "$(current_version "${p}")"; done)"