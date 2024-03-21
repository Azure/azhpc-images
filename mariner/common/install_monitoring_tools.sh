#!/bin/bash
set -ex

# Dependencies
# python3 -m pip install --upgrade pip
# Adding path to sudo user
sed -i 's/.*secure_path.*/Defaults    secure_path = "\/usr\/local\/sbin:\/usr\/local\/bin:\/sbin:\/bin:\/usr\/sbin:\/usr\/bin\/"/' /etc/sudoers

$COMMON_DIR/install_monitoring_tools.sh
