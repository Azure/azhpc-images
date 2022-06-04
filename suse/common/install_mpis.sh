#!/bin/bash
set -e

# MVAPICH
zypper install --no-confirm \
    mpich-gnu-hpc \
    mpich-gnu-hpc-devel

# MVAPICH2
zypper install --no-confirm \
    mvapich2-gnu-hpc \
    mvapich2-gnu-hpc-devel \
    mvapich2-gnu-hpc-doc

# OpenMPI v3
zypper install --no-confirm \
    openmpi3-gnu-hpc \
    libopenmpi3-gnu-hpc \
    openmpi3-gnu-hpc-devel \
    openmpi3-gnu-hpc-docs

# OpenMPI v4
zypper install --no-confirm \
    openmpi4-gnu-hpc \
    libopenmpi4-gnu-hpc \
    openmpi4-gnu-hpc-devel \
    openmpi4-gnu-hpc-docs
