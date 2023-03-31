#!/bin/bash
set -e

destination_test_path=$HPC_ENV/test

mkdir -p $destination_test_path

cp $TEST_DIR/run-tests.sh $destination_test_path

#Test if nvcc is installed and if so install gpu-copy test.
if test -f "/usr/local/cuda/bin/nvcc"; then
	#Compile the gpu-copy benchmark.
	NVCC=/usr/local/cuda/bin/nvcc
	cufile="$TEST_DIR/health_checks/NDv4/gpu-copy.cu"
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
fi
cp -r $TEST_DIR/health_checks $destination_test_path

exit 0
