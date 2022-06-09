#!/bin/bash
set -ex

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]:-$0}"; )" &> /dev/null && pwd 2> /dev/null; )";

CCL=nccl

${SCRIPT_DIR}/${CCL}/install_torch.sh

${SCRIPT_DIR}/install_deepspeed.sh
