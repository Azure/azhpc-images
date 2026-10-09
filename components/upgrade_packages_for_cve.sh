#!/bin/bash
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
    echo "ERROR: run this script as root or with sudo." >&2
    exit 1
fi

for command_name in apt-cache apt-get apt-mark dpkg dpkg-query ldd realpath; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "ERROR: required command not found: $command_name" >&2
        exit 1
    fi
done

packages=(
    libevent-2.1-7t64
    libevent-core-2.1-7t64
    libevent-extra-2.1-7t64
    libevent-openssl-2.1-7t64
    libevent-dev
    libevent-pthreads-2.1-7t64
    libheif1
    libheif-plugin-aomdec
    libheif-plugin-aomenc
    libauthen-sasl-perl
    dracut-install
    python3-requests
    python3-jwt
)

restore_holds() {
    echo "Restoring PMIx-related package holds..."
    apt-mark hold pmix libevent-dev libhwloc-dev
}
trap restore_holds EXIT

export DEBIAN_FRONTEND=noninteractive

apt-get update

echo "Temporarily removing the libevent-dev hold..."
apt-mark unhold libevent-dev

echo "Upgrading installed packages from the requested list..."
apt-get install -y --only-upgrade "${packages[@]}"

echo
echo -e "Package\tInstalled\tCandidate\tStatus"
upgrade_incomplete=0
for package_name in "${packages[@]}"; do
    installed=$(dpkg-query -W -f='${Version}' "$package_name" 2>/dev/null || true)
    candidate=$(LC_ALL=C apt-cache policy "$package_name" | awk '$1 == "Candidate:" {print $2}')

    if [[ -z "$installed" ]]; then
        status=NOT_INSTALLED
    elif [[ -z "$candidate" || "$candidate" == "(none)" ]]; then
        status=NO_CANDIDATE
    elif dpkg --compare-versions "$candidate" gt "$installed"; then
        status=UPGRADE_STILL_AVAILABLE
        upgrade_incomplete=1
    else
        status=UP_TO_DATE
    fi

    printf '%s\t%s\t%s\t%s\n' \
        "$package_name" "${installed:-N/A}" "${candidate:-N/A}" "$status"
done

if (( upgrade_incomplete != 0 )); then
    echo "ERROR: one or more installed packages still have an upgrade available." >&2
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

trap - EXIT
restore_holds
echo "Package upgrade and PMIx linkage checks completed successfully."
