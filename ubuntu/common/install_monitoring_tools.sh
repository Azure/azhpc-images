#!/bin/bash

set -e

MONEO_VERSION=v0.2.4.1
MDM_DOCKER_VERSION=2.2023.316.006-5d91fa-20230316t1622
MONITOR_DIR=/opt/azurehpc/tools

# Dependencies 
python3 -m pip install --upgrade pip
python3 -m pip install prometheus_client psutil filelock opentelemetry-sdk opentelemetry-exporter-otlp

# clone Moneo
mkdir -p $MONITOR_DIR

pushd $MONITOR_DIR

git clone https://github.com/Azure/Moneo  --branch $MONEO_VERSION

chmod 777 Moneo

# install geneva agent
echo '{ 
    "AccountName": "moneo", 
    "MDMEndPoint": "https://ppe2.ppe.microsoftmetrics.com", 
    "UmiObjectId": "ec68530e-9f0e-4bb0-bb63-c2f6690dd154" 
}' >  Moneo/src/worker/publisher/config/geneva_config.json

# configure geneva agent

echo '{
    "common_config": {
        "metrics_ports": "8000,8001,8002",
        "metrics_namespace": "MoneoH100_pilot",
        "interval": "20"
    },
    "geneva_agent_config": {
        "metrics_account": "moneo"
    },
    "azure_monitor_agent_config": {
        "connection_string": "<connectionString>"
    }
}' > Moneo/src/worker/publisher/config/publisher_config.json


# Pull Geneva Metrics Extension(MA) docker image
docker pull linuxgeneva-microsoft.azurecr.io/genevamdm:$MDM_DOCKER_VERSION
docker tag linuxgeneva-microsoft.azurecr.io/genevamdm:$MDM_DOCKER_VERSION genevamdm
docker rmi linuxgeneva-microsoft.azurecr.io/genevamdm:$MDM_DOCKER_VERSION


# set up and enable moneo services
$MONITOR_DIR/Moneo/linux_service/configure_service.sh $MONITOR_DIR/Moneo geneva 

popd

$COMMON_DIR/write_component_version.sh "MONEO" ${MONEO_VERSION}
