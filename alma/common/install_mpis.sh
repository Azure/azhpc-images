#!/bin/bash
set -ex

$COMMON_DIR/install_mpis.sh

# exclude updates on certain packages
sed -i "$ s/$/ ucx*/" /etc/dnf/dnf.conf
sed -i "$ s/$/ openmpi perftest/" /etc/dnf/dnf.conf
