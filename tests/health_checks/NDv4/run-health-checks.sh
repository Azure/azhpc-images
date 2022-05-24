#!/bin/bash

#Users may pass a directory where health checks are located to this script.
#If no directory is passed the script assumes health checks are in the opt
#directory.

#Verify if an argument was passed to the script. Test if the argument is
#a directory that contains all the expected health checks. If no arguments
#are passed use the default directory.
if [ "$#" -eq 0 ]; then
	TEST_DIR="/opt/azurehpc/test/health_checks/NDv4/"
else
	pass=1
	declare -a files=("check-hardware.sh" "dcgmi-check.sh" "ecc-errors.sh"\
	       	"test-bandwidth.sh" "test-ib.sh" "test-nccl.sh")
	for file in "${files[@]}"; do
		if test -f "$1/$file"; then
			true
		else
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

	if [ $pass -ne 1 ]; then
		echo "******************At least one health check failed."\
			"********************"
	else
		echo "*********All health checks have passed, everything "\
			"seems ok.***********"
	fi
        echo "$line"
fi
