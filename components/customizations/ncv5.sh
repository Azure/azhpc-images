#!/bin/bash
set -ex

if nvidia-smi nvlink --status | grep -qa inActive; then
    # Ensure Hyper-V PCI devices is ready
    retries=0
    while ! ls /sys/bus/vmbus/drivers/hv_pci/ | grep -q '[0-9a-f-]\{8\}-'; do
        error_code=$?
        if (( retries++ >= 5 )); then
            echo "Hyper-V PCI devices Inactive!"
            exit ${error_code}
        fi
        echo "Waiting for Hyper-V PCI devices..."
        sleep 1
    done

    # Ensure NVIDIA GPU PCI devices is ready
    retries=0
    while ! lspci | grep -qi nvidia; do
        error_code=$?
        if (( retries++ >= 5 )); then
            echo "NVIDIA GPU PCI Inactive!"
            exit ${error_code}
        fi
        echo "Waiting for NVIDIA GPU PCI devices..."
        sleep 1
    done

    echo "Reloading NVIDIA kernel modules..."
    sudo systemctl stop nvidia-dcgm.service
    sudo modprobe -r nvidia_drm nvidia_modeset gdrdrv nvidia_peermem nvidia_uvm nvidia  
    sudo modprobe nvidia nvidia_modeset nvidia_uvm nvidia_peermem gdrdrv nvidia_drm
    sudo systemctl start nvidia-dcgm.service
fi

echo "Check NVLink status after reloading NVIDIA kernel modules..."
if nvidia-smi nvlink --status | grep -qa inActive; then
    echo "NVLink is still Inactive after reloading NVIDIA kernel modules!"
    exit 1
else
    echo "NVLink is Active."
fi
