#!/usr/bin/env bash
set -euxo pipefail

source ${UTILS_DIR}/utilities.sh

TRIVY_REPORT_DIRNAME=/opt/azurehpc
TRIVY_REPORT_ROOTFS_JSON_PATH=${TRIVY_REPORT_DIRNAME}/trivy-report-rootfs.json

trivy_metadata=$(get_component_config "trivy")
TRIVY_VERSION=$(jq -r '.version' <<< $trivy_metadata)
TRIVY_URL=$(jq -r '.url' <<< $trivy_metadata)
TRIVY_SHA256=$(jq -r '.sha256' <<< $trivy_metadata)
TRIVY_DB_REPOSITORIES=$(jq -r '.repo' <<< $trivy_metadata)
TARBALL=$(basename ${TRIVY_URL})

declare -a SKIP_DIRS=(
    "/var/lib/waagent"
    "/snap"
)
declare -a SKIP_FILES=(
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

download_and_verify ${TRIVY_URL} ${TRIVY_SHA256} /tmp
pushd /tmp
tar -xvzf $TARBALL
rm $TARBALL
chmod a+x trivy 

retrycmd_if_failure 10 30 600 ./trivy --scanners vuln rootfs -f json --db-repository ${TRIVY_DB_REPOSITORIES} ${SKIP_FILES[@]/#/ --skip-files } ${SKIP_DIRS[@]/#/ --skip-dirs } --ignore-unfixed -o "${TRIVY_REPORT_ROOTFS_JSON_PATH}" /

rm ./trivy
popd