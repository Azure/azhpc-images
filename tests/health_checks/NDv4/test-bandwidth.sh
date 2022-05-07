#!/bin/bash

##This script tests host to device bandwidth and device to host bandwidth using
##the superbench gpu-copy benchmark. Users may pass a directory containing the
##gpu-copy benchmar to the script. If no directory is passed a default 
##location is used. If the gpu-copy benchmark has not installed succesfully
##installationt can be done following these steps:
##
##Download the host to device and device to host test from superbench v0.5.
#string="https://raw.githubusercontent.com/microsoft/superbenchmark/release/"\
#	"0.5/superbench/benchmarks/micro_benchmarks/gpu_copy_performance/"\
#	"gpu_copy.cu"
#timeout 3m wget -q -o /dev/null $string
#err_wget=$?
#if [ $err_wget -ne 0 ]; then
#	echo "wget exited with error code $err_wget"
#	exit $err_wget;
#fi
#
#
##Compile the gpu-copy benchmark.
#compile="nvcc -lnuma gpu_copy.cu -o gpu-copy"
#error_nvcc="Fail: nvvc failed to compile gpu_copy.cu with error code"
#catch_error "$compile" "$error_nvcc"


#Catch error codes that may be thrown by the executable passed as the first
#input, and if an error code is tripped throw the second input as a message
catch_error() {
	output=$($1)
	err_code=$?
	if [ $err_code -ne 0 ]; then
		echo -e "\t $2 $err_code" >&2
		exit $err_code;
	fi
}

echo "htod and dtoh bandwidth check:"

#If no arguments are passed to the script assume the gpu-copy test is located
#in the default location. Otherwise check if it the gpu-copy test is in the 
#location indicated by the argument. 
if [ "$#" -eq 0 ]; then
	CHECK_DIR="/opt/azurehpc/test/health_checks/NDv4/"
else
	pass=1
	if test -f "$1/gpu-copy"; then
		CHECK_DIR=$1
	else
		echo -e "\t **Fail** Directory $1 is missing the gpu-copy test."
		exit 1;
	fi
fi
#Store output from calls passed to catch_error
output=""

#Count the number of gpu-name nvidia-smi outputs.
error_smi="**Fail** nvidia-smi failed with error code"
#Lock graphics clocks to 1400 to eliminate any time for the GPUs to boost.
#This likely isn't important for performance here, but we will do it anyway
#to be safe.
lock_clocks="sudo nvidia-smi -lgc 1400"
catch_error "$lock_clocks" "$error_smi"

#Count the GPUs.
gpu_list="sudo timeout 3m nvidia-smi --query-gpu=name --format=csv,noheader"
catch_error "$gpu_list" "$error_smi"
ngpus=$(echo "$output" | wc -l)





#Run the superbench device to host bandwidth test.
exec_htod="timeout 3m $CHECK_DIR/gpu-copy --size 134217728 --num_warm_up 5"
exec_htod+=" --num_loops 10 --htod --dma_copy"

error_htod="**Fail** The htod gpu_copy test failed to execute."
error_htod+="It exited with error code"

catch_error "$exec_htod" "$error_htod"
x_htod=$(echo "$output")

#Run the superbench host to device bandwidth test.
exec_dtoh="timeout 3m $CHECK_DIR/gpu-copy --size 134217728 --num_warm_up 5"
exec_dtoh+=" --num_loops 10 --dtoh --dma_copy"

error_dtoh="**Fail** The dtoh gpu_copy test failed to execute."
error_dtoh+="It exited with error code"
catch_error "$exec_dtoh" "$error_dtoh"
x_dtoh=$(echo "$output")

pass=1

#Loop over all of the detected GPUs.
for i in $(seq 0 $((ngpus-1))); do
	#Collect host to device bandwidths computed in each numa zone.
	bw_htod=$(echo "$x_htod" | grep "gpu$i" | cut -d' ' -f2 | cut -d. -f1)
	max_htodbw=0
	min_bw=100
	#Loop over the bandwidths observed in each numa zone and find max.
	for bw in $bw_htod; do
		if [ $max_htodbw -lt $bw ]; then
			max_htodbw=$bw
		fi
	done

	#Collect device to host bandwidths computed in each numa zone.
	bw_dtoh=$(echo "$x_dtoh" | grep "gpu$i" | cut -d' ' -f2 | cut -d. -f1)
	max_dtohbw=0
	#Loop over bandwidths observed in each numa zone and find max.
	for bw in $bw_dtoh; do
		if [ $max_dtohbw -lt $bw ]; then
			max_dtohbw=$bw
		fi
	done
	#Find minimum of the htod and dtoh bandwidths.
	if [ $max_htodbw -lt $max_dtohbw ]; then
		min_bw=$max_htodbw
	else
		min_bw=$max_dtohbw
	fi

	#If the min bandwidth is too low the test has failed.
	if [ $min_bw -lt 23 ]; then
		echo "Bandwidth is low on device $i. Reported bandwidth is"\
			"$min_bw GB/s."
		pass=0
	fi
done
#Unlock the graphics clock.
unlock_clocks="sudo timeout 3m nvidia-smi -rgc"
catch_error "$unlock_clocks" "$error_smi"

if [ $pass -ne 1 ]; then
	echo -e "\t **Fail** At least one device reported low htod or dtoh"\
		"bandwidth."
	exit 1;
else
	echo -e "\t **Pass** The htod and dtoh bandwidth checks both passed"
fi
