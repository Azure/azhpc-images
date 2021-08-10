#!/bin/bash
############################################################################
# @Brief	: Write the component and its version
#
# @Args		: (1) Component Name
# 			  (2) Version
############################################################################

set -e

DEST_DIR=/opt/azurehpc

mkdir -p $DEST_DIR

echo $1=$2 | sudo tee -a $DEST_DIR/component_versions.txt

exit 0
