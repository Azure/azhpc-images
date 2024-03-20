#!/bin/bash

# Disable some unneeded services by default (administrators can re-enable if desired)
systemctl disable wpa_supplicant
systemctl disable abrtd

../../common/hpc-tuning.sh
