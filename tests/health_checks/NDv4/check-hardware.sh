#!/bin/bash

#Count the number of gpu-names nvidia-smi outputs.
ngpus=$(sudo nvidia-smi --query-gpu=name --format=csv,noheader | wc -l)

#Count the number of nics lshw detects.
nnics=$(sudo lshw -C network | grep -i product | wc -l)

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
