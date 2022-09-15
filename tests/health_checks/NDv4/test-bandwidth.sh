#!/bin/bash

##This script tests host to device bandwidth and device to host bandwidth using
##a script recorded within the test that tests host to device and device to 
##host copy bandwidths between every combination of gpus and numa domains. The
##test confirms that each GPU is hitting the expected bandwidths to at least
##one of the numa domains.
##
##When this test is first run it will compile the gpu-copy benchmark if it is
##not detected.


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

create_benchmark() {
        file_dir="$1"

        compile_bench="nvcc -lnuma $file_dir/gpu-copy.cu -o $file_dir/gpu-copy"
        compile_error="Error when attempting to compile benchmark"
        catch_error "$compile_bench" "$compile_error"
}

locate_file() {
        file="$1"
        exitOnFail=$2
        pass=1
	#File name we want to locate.
        local file="$1"
	#What should  happen if the file isn't located?
        local exitOnFail=$2
	#Write the directory containing the file here, if found.
        local return_dir=$3
        local pass=1

	#Start by testing directory where the script is located
        local DIR=$(cd `dirname $0` && pwd)
        DIR=$(cd `dirname $0` && pwd)
        if ! test -f "$DIR/$file"; then
                pass=0
        fi
        #If file is located in script dir use that directory.
        if [[ $pass -eq 1 ]]; then
                CHECK_LOC=$DIR
        fi
	#Otherwise check the PWD (in case that is different).
        if [[ $pass -eq 0 ]]; then
                DIR=$PWD
                pass=1
                if test -f "$DIR/$file"; then
                        CHECK_LOC=$DIR
                else
                        pass=0
                fi
        fi

	#If we found the file pass that to return_dir. 
	#Otherwise either just exit or also fail.
        if [[ $exitOnFail -eq 0 ]]; then
                if [[ $pass -eq 0 ]]; then
                         DIR=$(cd `dirname $0` && pwd)
                         CHECK_LOC=$DIR
                fi
        else
                if [[ $pass -eq 0 ]]; then
                        echo "Cannot find file $file."
                        exit 1;
                fi
        fi
	eval $return_dir="'$CHECK_LOC'"
}


echo "htod and dtoh bandwidth check:"

#If no arguments are passed to the script assume the gpu-copy test is located
#in the default location. Otherwise check if it the gpu-copy test is in the 
#location indicated by the argument. 
if [ "$#" -eq 0 ]; then
	locate_file "gpu-copy" 0 CHECK_DIR
	locate_file "gpu-copy.cu" 1 CHECK_DIR
        create_benchmark "$CHECK_DIR"
else
	pass=1
	if test -f "$1/gpu-copy"; then
		CHECK_DIR=$1
	else
                create_benchmark $1
                CHECK_DIR=$1
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
gpu_list="timeout 3m nvidia-smi --query-gpu=name --format=csv,noheader"
catch_error "$gpu_list" "$error_smi"
ngpus=$(echo "$output" | wc -l)




#Run the superbench device to host bandwidth test.
exec_htod="timeout 3m $CHECK_DIR/gpu-copy --size 134217728 --htod"

error_htod="**Fail** The htod gpu_copy test failed to execute."
error_htod+="It exited with error code"

catch_error "$exec_htod" "$error_htod"
x_htod=$(echo "$output")

#Run the superbench host to device bandwidth test.
exec_dtoh="timeout 3m $CHECK_DIR/gpu-copy --size 134217728 --dtoh"

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
	if [ $min_bw -lt 24 ]; then
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
