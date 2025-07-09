#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

# Set Lustre version
lustre_metadata=$(get_component_config "lustre")
LUSTRE_VERSION=$(jq -r '.version' <<< $lustre_metadata)

if [[ $DISTRIBUTION == "ubuntu22.04" ]]; then
    source /etc/lsb-release
    echo "deb [arch=amd64] https://packages.microsoft.com/repos/amlfs-${DISTRIB_CODENAME}/ ${DISTRIB_CODENAME} main" | sudo tee /etc/apt/sources.list.d/amlfs.list
    # Enable these lines if the MS PMC repo was not already setup.
    #curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
    #cp ./microsoft.gpg /etc/apt/trusted.gpg.d/
    apt-get update
    apt-get install -y amlfs-lustre-client-${LUSTRE_VERSION}=$(uname -r)
    apt-mark hold amlfs-lustre-client-${LUSTRE_VERSION}
elif [[ $DISTRIBUTION == "almalinux8.10" ]]; then
    ALMA_LUSTRE_VERSION=${LUSTRE_VERSION//-/_}
    DISTRIB_CODENAME="el8"
    REPO_PATH=/etc/yum.repos.d/amlfs.repo

    rpm --import https://packages.microsoft.com/keys/microsoft.asc

    echo -e "[amlfs]" > ${REPO_PATH}
    echo -e "name=Azure Lustre Packages" >> ${REPO_PATH}
    echo -e "baseurl=https://packages.microsoft.com/yumrepos/amlfs-${DISTRIB_CODENAME}" >> ${REPO_PATH}
    echo -e "enabled=1" >> ${REPO_PATH}
    echo -e "gpgcheck=1" >> ${REPO_PATH}
    echo -e "gpgkey=https://packages.microsoft.com/keys/microsoft.asc" >> ${REPO_PATH}
    
    dnf install -y --disableexcludes=main --refresh amlfs-lustre-client-${ALMA_LUSTRE_VERSION}-$(uname -r | sed -e "s/\.$(uname -p)$//" | sed -re 's/[-_]/\./g')-1
    sed -i "$ s/$/ amlfs*/" /etc/dnf/dnf.conf
fi

write_component_version "LUSTRE" ${LUSTRE_VERSION}
