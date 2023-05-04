#!/bin/bash

# With SLE HPC 15 SP4 we have gcc7 and gcc11 provided as the base compiler toolchain
# and requires lua-lmod to supply environment module support.
# the default is gnu/7 within package gnu-compilers-hpc, gcc11 is in gnu11-compilers-hpc
# MODULE_FILES_DIRECTORY=/usr/share/lmod/modulefiles
COMPILER_VERSION=11

zypper in -y gnu${COMPILER_VERSION}-compilers-hpc
