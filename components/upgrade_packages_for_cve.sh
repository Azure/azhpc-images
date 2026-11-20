#!/bin/bash
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
    echo "ERROR: run this script as root or with sudo." >&2
    exit 1
fi

for command_name in apt-cache apt-get dpkg dpkg-query ldd realpath; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "ERROR: required command not found: $command_name" >&2
        exit 1
    fi
done

packages=(
    libperl5.38t64
    perl-base
    perl
    perl-modules-5.38
    locales
    libc6-dev
    libc-dev-bin
    libc-bin
    libc-devtools
    libc6
    python3-pyasn1
)

# Minimum non-ESM versions from the CRD 1.0.12 Ubuntu 24.04 scan.
# Allow newer candidates; python3-pip and python3-wheel require Pro/ESM fixes.
declare -A required_versions=(
    [libperl5.38t64]=5.38.2-3.2ubuntu0.7
    [perl-base]=5.38.2-3.2ubuntu0.7
    [perl]=5.38.2-3.2ubuntu0.7
    [perl-modules-5.38]=5.38.2-3.2ubuntu0.7
    [locales]=2.39-0ubuntu8.12
    [libc6-dev]=2.39-0ubuntu8.12
    [libc-dev-bin]=2.39-0ubuntu8.12
    [libc-bin]=2.39-0ubuntu8.12
    [libc-devtools]=2.39-0ubuntu8.12
    [libc6]=2.39-0ubuntu8.12
    [python3-pyasn1]=0.4.8-4ubuntu0.4
)

export DEBIAN_FRONTEND=noninteractive

apt-get update

echo "Upgrading installed packages from the requested list..."
apt-get install -y --only-upgrade "${packages[@]}"

echo
echo -e "Package\tInstalled\tRequired\tCandidate\tStatus"
upgrade_incomplete=0
for package_name in "${packages[@]}"; do
    installed=$(dpkg-query -W -f='${Version}' "$package_name" 2>/dev/null || true)
    candidate=$(LC_ALL=C apt-cache policy "$package_name" | awk '$1 == "Candidate:" {print $2}')
    required=${required_versions[$package_name]:-}

    if [[ -z "$installed" ]]; then
        status=NOT_INSTALLED
    elif [[ -n "$required" ]] && dpkg --compare-versions "$installed" lt "$required"; then
        status=BELOW_REQUIRED_VERSION
        upgrade_incomplete=1
    elif [[ -z "$candidate" || "$candidate" == "(none)" ]]; then
        status=NO_CANDIDATE
        upgrade_incomplete=1
    elif dpkg --compare-versions "$candidate" gt "$installed"; then
        status=UPGRADE_STILL_AVAILABLE
        upgrade_incomplete=1
    else
        status=UP_TO_DATE
    fi

    printf '%s\t%s\t%s\t%s\t%s\n' \
        "$package_name" "${installed:-N/A}" "${required:-N/A}" "${candidate:-N/A}" "$status"
done

if (( upgrade_incomplete != 0 )); then
    echo "ERROR: one or more installed packages failed the required-version or candidate checks." >&2
    exit 1
fi

echo
echo "Checking PMIx shared-library resolution..."
pmix_broken=0
while IFS= read -r pmix_library; do
    [[ -f "$pmix_library" ]] || continue
    resolved_library=$(realpath "$pmix_library")
    missing=$(ldd "$resolved_library" 2>/dev/null | grep 'not found' || true)
    if [[ -n "$missing" ]]; then
        echo "BROKEN: $pmix_library" >&2
        echo "$missing" >&2
        pmix_broken=1
    fi
done < <(dpkg-query -L pmix | grep -E '\.so($|\.)' | sort -u)

if (( pmix_broken != 0 )); then
    echo "ERROR: PMIx has unresolved shared-library dependencies after upgrade." >&2
    exit 1
fi

echo "Package upgrade and PMIx linkage checks completed successfully."
