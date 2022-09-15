#!/bin/bash

#Users may pass a directory where health checks are located to this script.
#If no directory is passed the script assumes health checks are in the opt
#directory.

#Verify if an argument was passed to the script. Test if the argument is
#a directory that contains all the expected health checks. If no arguments
#are passed use the default directory.
declare -a files=("check-hardware.sh" "dcgmi-check.sh" "ecc-errors.sh"\
	   "test-bandwidth.sh" "test-ib.sh" "test-nccl.sh"\
	   "test-MaxPayLoad.sh" "gpu-copy.cu")
if [ "$#" -gt 1 ]; then
	echo "Usage: run-health-checks.sh [DIRECTORY]"
	echo "DIRECTORY is an optional argument that specifies the location of"
	echo "the test scripts to run. It defaults to the install location of"
	echo "this script."
	exit 1;
fi
if [ "$#" -eq 0 ]; then
	pass=1
	DIR=$(cd `dirname $0` && pwd)
	for file in "${files[@]}"; do
		if ! test -f "$DIR/$file"; then
			pass=0
		fi
	done
	#if tests are located in script dir use those
	if [[ $pass -eq 1 ]]; then
		TEST_DIR=$DIR
	fi
	if [[ $pass -eq 0 ]]; then
		DIR=$PWD
		pass=1
		for file in "${files[@]}"; do
			if ! test -f "$DIR/$file"; then
				pass=0
			fi
		done
		if [[ $pass -eq 1 ]]; then
			TEST_DIR=$DIR
		fi
	fi
	if [[ $pass -eq 0 ]]; then
		echo "Not all healch check files found in the working"\
			"directory please specify where they can be found."
		exit 1;
	fi
else
	pass=1
	for file in "${files[@]}"; do
		if ! test -f "$1/$file"; then
			echo "Directory $1 is missing $file"
			pass=0
		fi
	done
	if [ $pass -eq 1 ]; then
		TEST_DIR=$1
	else
		echo "Directory $1 is missing health check files."
		exit 1;
	fi

fi

check_hardware=$($TEST_DIR/check-hardware.sh)
detect=$?
#detect=$(echo "$check_hardware" | grep "Fail:" | wc -l)
echo "------------------------------------------------------------------------"
echo "**************************Begin Health Checks***************************"
echo "------------------------------------------------------------------------"
line="------------------------------------------------------------------------"
if [ $detect -ne 0 ]; then
	echo "Failed to detect GPUs and NICs with error code $detect"\
		", run check-hardware.sh"
else
	pass=1
        #run 'dcgmi diag -r 1' and check for failures
	$TEST_DIR/dcgmi-check.sh
	out=$?
	if [ $out -ne 0 ]; then
		pass=0
	fi
        echo "$line"

        #run 'nvidia-smi -q -d ROW_REMAPPER' and check for problems 
	$TEST_DIR/ecc-errors.sh
	out=$?
	if [ $out -ne 0 ]; then
		pass=0
	fi
        echo "$line"

        #run ibstatus and check all devices are set up as expected
	$TEST_DIR/test-ib.sh
	out=$?
	if [ $out -ne 0 ]; then
		pass=0
	fi
        echo "$line"

        #test that host to device/device to host bandwidth meet expectations.
	$TEST_DIR/test-bandwidth.sh $TEST_DIR
	out=$?
	if [ $out -ne 0 ]; then
		pass=0
	fi
        echo "$line"

        #test nccl using nvlink and ib
	$TEST_DIR/test-nccl.sh
	out=$?
	if [ $out -ne 0 ]; then
		pass=0
	fi
        echo "$line"

	$TEST_DIR/test-MaxPayLoad.sh
	out=$?
	if [ $out -ne 0 ]; then
		pass=0
	fi
        echo "$line"

	if [ $pass -ne 1 ]; then
                message="******************At least one health check failed."
                message+="*********************"
                echo "$message"
	else
                message="********************All health checks have passed."
                message+="**********************"
                echo "$message"
	fi
        echo "$line"
fi
