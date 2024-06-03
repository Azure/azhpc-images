#!/bin/bash
set -ex

tdnf -y install rdma-core
tdnf -y install rdma-core-devel

$COMMON_DIR/install_azure_persistent_rdma_naming.sh