#!/bin/bash
set -ex

$COMMON_DIR/install_nccl.sh $nccl_version
# Hold nccl packages from updates
sed -i "$ s/$/ libnccl*/" /etc/dnf/dnf.conf
