#!/bin/bash

#Lock the graphics clock.
sudo nvidia-smi -lgc 1400 > /dev/null

#Count the GPUs.
ngpus=$(nvidia-smi --query-gpu=name --format=csv,noheader | wc -l)

#Download the host to device and device to host test from superbench v0.5.
string="https://raw.githubusercontent.com/microsoft/superbenchmark/release/0.5"\
"/superbench/benchmarks/micro_benchmarks/gpu_copy_performance/gpu_copy.cu"
wget -q $string

#Compile the gpu-copy benchmark.
nvcc -I/usr/include/ -L/usr/lib/x86_64-linux-gnu/ -lnuma gpu_copy.cu -o gpu-copy


#Run the superbench device to host bandwidth test.
x_htod=$(./gpu-copy --size 134217728 --num_warm_up 5 \
	--num_loops 10 --htod --dma_copy)
err_htod=$?
if [ $err_htod -ne 0 ]; then
	echo "Fail: The htod gpu_copy test failed to execute."\
		"It exited with error code $err_htod"
	exit $err_htod
fi

#Run the superbench host to device bandwidth test.
x_dtoh=$(./gpu-copy --size 134217728 --num_warm_up 5 \
	--num_loops 10 --dtoh --dma_copy)

err_dtoh=$?
if [ $err_dtoh -ne 0 ]; then
	echo "Fail: The dtoh gpu_copy test failed to execute."\
		"It exited with error code $err_dtoh"
	exit $err_dtoh
fi

rm "gpu-copy"
rm "gpu_copy.cu"

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
if [ $pass -lt 1 ]; then
	echo "Fail: At least one device reported low htod or dtoh bandwidth."
else
	echo "bandwidth test passed"
fi
#Unlock the graphics clock.
sudo nvidia-smi -rgc > /dev/null


