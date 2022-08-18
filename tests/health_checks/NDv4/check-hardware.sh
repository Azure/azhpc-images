#!/bin/bash

##This is a test to verify an NDv4 vm is seeing the expected number of GPUs
##and NICs.

#Catch error codes that may be thrown by the executable passed as the first
#input, and if an error code is tripped throw the second input as a message
catch_error() {
	output=$($1)
	err_code=$?
	if [ $err_code -ne 0 ]; then
		echo "$2 $err_code" >&2
		exit $err_code;
	fi
}

#Store output from calls passed to catch_error
output=""

#Count the number of gpu-name nvidia-smi outputs.
gpu_names="timeout 3m nvidia-smi --query-gpu=name --format=csv,noheader"
error_smi="Fail: nvidia-smi failed with error code"
catch_error "$gpu_names" "$error_smi"
ngpus=$(echo "$output" | wc -l)

smi_warnings="timeout 3m nvidia-smi"
catch_error "$smi_warnings" "$error_smi"
out_warn=$(echo "$output")
nwarn=$(echo "$out_warn" | grep "WARNING" | wc -l)


#Count the number of nics lshw detects.
find_nics="sudo timeout 3m lshw -C network"
error_nics="Fail: lshw failed with error code"
catch_error "$find_nics" "$error_nics"
nnics=$(echo "$output" | grep -i ConnectX-6 | wc -l)

#Count the number of nvmedrives.
find_nvme="sudo timeout 3m lshw -C storage" 
error_nvme="Fail: lshw failed with error code"
catch_error "$find_nvme" "$error_nvme"
nnvme=$(echo "$output" | grep nvme | grep logical | wc -l)

#Did either test fail?
passed=1
if [ $nwarn -ne 0 ]; then
	passed=0
	echo "nvidia-smi reported warnings, see output below:"
	echo "$out_warn" 
fi

if [ $ngpus -ne 8 ]; then
	passed=0
	echo "$ngpus GPUs detected with 8 expected."
fi

if [ $nnics -ne 8 ]; then
	passed=0
	echo "$nnics NICs detected with 8 expected."
fi

if [ $nnvme -ne 8 ]; then
	passed=0
	echo "$nnvme NVMEs detected with 8 expected."
fi

if [ $passed -ne 1 ]; then
	echo "Fail: Error when detecting GPUs, NVMEs, and NICs."
	exit 1;
else
	echo "Correct number of GPUs, NVMEs, and NICs detected."
fi
