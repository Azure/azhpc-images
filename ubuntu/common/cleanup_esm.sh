#!/bin/bash

# Remove packages requiring Ubuntu Pro for security updates
apt-get update
apt-get remove --auto-remove -y graphviz
