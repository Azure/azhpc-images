#!/usr/bin/env bash
set -euxo pipefail

TRIVY_REPORT_DIRNAME=/opt/azurehpc
TRIVY_REPORT_ROOTFS_JSON_PATH=${TRIVY_REPORT_DIRNAME}/trivy-report-rootfs.json
TRIVY_CYCLONEDX_ROOTFS_JSON_PATH=${TRIVY_REPORT_DIRNAME}/trivy-cyclonedx-rootfs.json

TRIVY_VERSION=$(curl -L   -H "Accept: application/vnd.github+json"   -H "X-GitHub-Api-Version: 2022-11-28"   https://api.github.com/repos/aquasecurity/trivy/releases/latest | jq -r ".name")
TRIVY_VERSION=${TRIVY_VERSION:1} # remove the leading 'v'
TRIVY_ARCH="Linux-64bit"

TRIVY_DB_REPOSITORIES="mcr.microsoft.com/mirror/ghcr/aquasecurity/trivy-db:2,ghcr.io/aquasecurity/trivy-db:2,public.ecr.aws/aquasecurity/trivy-db"

declare -a SKIP_DIRS=(
    "/var/lib/waagent"
    "/snap"
    "/mnt"
    "$(pwd)/trivy"
)

retrycmd_if_failure() {
    retries=$1; wait_sleep=$2; timeout=$3; shift && shift && shift
    for i in $(seq 1 $retries); do
        timeout $timeout "${@}" && break || \
        if [ $i -eq $retries ]; then
            echo Executed \"$@\" $i times;
            return 1
        else
            sleep $wait_sleep
        fi
    done
    echo Executed \"$@\" $i times;
}

mkdir -p "${TRIVY_REPORT_DIRNAME}"

TARFILE="trivy_${TRIVY_VERSION}_${TRIVY_ARCH}.tar.gz"
wget "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/${TARFILE}" -O "${TARFILE}"
mkdir -p trivy
tar -xvzf "${TARFILE}" -C trivy
rm "${TARFILE}"
chmod a+x trivy/trivy

retrycmd_if_failure 10 30 600 ./trivy/trivy --scanners vuln rootfs -f json --db-repository ${TRIVY_DB_REPOSITORIES} ${SKIP_FILES[@]/#/ --skip-files } ${SKIP_DIRS[@]/#/ --skip-dirs } --ignore-unfixed --list-all-pkgs=false -o "${TRIVY_REPORT_ROOTFS_JSON_PATH}" /
retrycmd_if_failure 10 30 600 ./trivy/trivy --scanners vuln rootfs -f cyclonedx --db-repository ${TRIVY_DB_REPOSITORIES} ${SKIP_FILES[@]/#/ --skip-files } ${SKIP_DIRS[@]/#/ --skip-dirs } --ignore-unfixed -o "${TRIVY_CYCLONEDX_ROOTFS_JSON_PATH}" /

rm -rf ./trivy