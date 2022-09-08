#!/bin/bash
set -e

DEST_TEST_DIR=/opt/azurehpc/test

mkdir -p $DEST_TEST_DIR

cp $TEST_DIR/run-tests.sh $DEST_TEST_DIR

#Test if nvcc is installed and if so install gpu-copy test.
if test -f "/usr/local/cuda/bin/nvcc"; then
	#Download the host to device and device to host test from 
	#superbench v0.5.
	string="https://raw.githubusercontent.com/microsoft/"
	string+="superbenchmark/release/0.5/superbench/benchmarks/"
	string+="micro_benchmarks/gpu_copy_performance/gpu_copy.cu"
	wget -q -o /dev/null $string -P $TEST_DIR/health_checks/NDv4/
	
	#Compile the gpu-copy benchmark.
	NVCC=/usr/local/cuda/bin/nvcc
	cufile="$TEST_DIR/health_checks/NDv4/gpu_copy.cu"
	outfile="$TEST_DIR/health_checks/NDv4/gpu-copy"

	#Test if the default gcc compiler is new enough to compile gpu-copy.
	#If it is not then use the 9.2 compiler, that should be installed in 
	#/opt.
	if [ $(gcc -dumpversion | cut -d. -f1) -gt 6 ]; then
		$NVCC -lnuma $cufile -o $outfile
	else
		$NVCC --compiler-bindir /opt/gcc-9.2.0/bin \
			-lnuma $cufile -o $outfile
	fi
	#remove gpu_copy.cu
	rm $cufile
fi
cp -r $TEST_DIR/health_checks $DEST_TEST_DIR

exit 0
