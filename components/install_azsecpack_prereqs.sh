#!/bin/bash
set -ex

install_nmap() {
    if command -v nmap >/dev/null 2>&1; then
        echo "nmap already installed: $(nmap --version 2>/dev/null | head -1 || true)"
        return 0
    fi
    
    if [[ $DISTRIBUTION == *"ubuntu"* ]]; then
        apt-get install -y nmap
    elif [[ $DISTRIBUTION == "azurelinux"* ]]; then
        tdnf install -y nmap
    else
        # RHEL-family: AlmaLinux, Rocky Linux, RHEL, etc.
        yum install -y nmap
    fi

    if ! command -v nmap >/dev/null 2>&1; then
        echo "[ERROR] nmap package installed but nmap binary is not available"
        exit 1
    fi
    echo "OK - nmap installed: $(nmap --version 2>/dev/null | head -1 || true)"
}


# nmap shipped with azsecpack doesn't work on 64KB page size
# Install nmap from packeger manager when kernel page size is 64KB (65536 bytes)
PAGE_SIZE=$(getconf PAGE_SIZE)
if [ "$PAGE_SIZE" = "65536" ]; then
    install_nmap
fi