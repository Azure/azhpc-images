#!/bin/bash

check_hardware=$(./check-hardware.sh)
detect=$(echo "$check_hardware" | grep "Fail:" | wc -l)

if [ $detect -gt 0 ]; then
	echo "Failed to detect GPUs and NICs, run check-hardware.sh"
else
        #run 'dcgmi diag -r 1' and check for failures
	./dcgmi-check.sh
        #run 'nvidia-smi -q -d ROW_REMAPPER' and check for problems 
	./ecc-errors.sh
        #run ibstat and check all devices are set up as expected
	./test-ib.sh
        #test that host to device/device to host bandwidth meet expectations.
	./test-bandwidth.sh
        #test nccl using nvlink and ib
	./test-nccl.sh
fi
