#!/bin/bash

#get the number of GPUs
ngpus=$(sudo nvidia-smi --query-gpu=name --format=csv,noheader | wc -l)
#array to hold status of persistence mode for each gpu
declare -a pmvals=()

#Find which GPUs have persistence mode off, record that information in pmvals.
#Enable persistence mode on GPUs that have it disabled. 
for i in $(seq 0 $((ngpus-1))); do
	pmvals[$i]=$(nvidia-smi -i $i -q | grep "Persistence Mode" \
		| awk '{print $4}')
	if [ ${pmvals[$i]} == "Disabled" ]; then
		sudo nvidia-smi -i $i -pm 1 > /dev/null
	fi	       
done

#Turn on persistence mode.

#Run the basic (r=1) dcgmi diag tests.
fails=$(dcgmi diag -r 1 | grep "Fail" | wc -l)

#Disable persistence mode on GPUs that started with it disabled.
for i in $(seq 0 $((ngpus-1))); do
	if [ ${pmvals[$i]} == "Disabled" ]; then
	       sudo nvidia-smi -i $i -pm 0 > /dev/null
	fi	       
done

if [ $fails -gt 0 ]; then
	echo "Fail: dcgmi tests have hit errors. Execute the command"\
		"'dcgmi diag -r 1' to see specific failures"
else
	echo "dcgmi test passes"
fi
