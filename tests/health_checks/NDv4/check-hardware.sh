#!/bin/bash

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

#Count the number of gpu-names nvidia-smi outputs.
executable="sudo timeout 3m nvidia-smi --query-gpu=name --format=csv,noheader"
error="Fail: nvidia-smi failed counting GPUs with error code"
catch_error "$executable" "$error"
ngpus=$(echo "$output" | wc -l)


#Count the number of nics lshw detects.
executable="sudo timeout 3m lshw -C network"
error="Fail: lshw failed with error code"
catch_error "$executable" "$error"
nnics=$(echo "$output" | grep -i ConnectX-6 | wc -l)

#Did either test fail?
passed=1

if [ $ngpus -ne 8 ]; then
	passed=0
	echo "$ngpus GPUs detected with 8 expected."
fi

if [ $nnics -ne 8 ]; then
	passed=0
	echo "$nnics NICs detected with 8 expected."
fi

if [ $passed -ne 1 ]; then
	echo "Fail: Error when detecting GPUs and NICs."
else
	echo "Correct number of GPUs and NICs detected."
fi
