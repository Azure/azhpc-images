#!/bin/bash

MODULE_FILES_DIRECTORY=/usr/share/modules/modulefiles

mkdir -p ${MODULE_FILES_DIRECTORY}

../../common/install_gcc-9.2.sh ${MODULE_FILES_DIRECTORY}
