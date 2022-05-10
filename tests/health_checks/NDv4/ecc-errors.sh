#!/bin/bash

#ECC errors are handled by row remapping on A100. This script first counts the
#row remappings due to ECC errors (correctable and otherwise). If any GPU has
#512 or  more, the test fails. 


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

#Store output from calls passed to catch_error
output=""

echo "ECC error check:"

pass=1

#query the number of gpus
exec_names="sudo timeout 3m nvidia-smi --query-gpu=name --format=csv,noheader"
error_smi="**Fail** nvidia-smi failed with error code"
catch_error "$exec_names" "$error_smi"
ngpus=$(echo "$output" | wc -l)

#query nvidia-smi to collect row remap information.
exec_rows="timeout 3m nvidia-smi -q -d ROW_REMAPPER"
catch_error "$exec_rows" "$error_smi"
row_remaps=$(echo "$output")
#Query the nvidia-smi output to identify any pending row remaps.
pending=$(echo "$row_remaps" | grep "Pending" | cut -d: -f2)
gpui=0

#Check if any GPU has a pending remap.
for pend in $pending; do
	if [ "$pend" != "No" ]; then
		echo "$gpui has a pending remap. Reset the GPU."
		exit
		pass=0
	fi
	gpui=$((gpui+1))
done

#Query the nvidia-smi output to identify any row remap failures.
fails=$(echo "$row_remaps" | grep "Remapping Failure Occurred" | cut -d: -f2)
gpui=0

#Check if any GPU has had a row remap failure.
for err in $fails; do
	if [ "$err" != "No" ]; then
		echo "GPU $gpui indicates it has experienced a remap"\
	       	"error."
		gpui=$((gpui+1))
		pass=0
	fi
done

#Query the nvidia-smi output to identify remap counts due to correctable 
#and uncorrectable ECC errors.

correctable=$(echo "$row_remaps" | grep "Correctable Error" | cut -d: -f2)
uncorrectable=$(echo "$row_remaps" | grep "Uncorrectable Error" | cut -d: -f2)

correctable_v=( ${correctable} )
uncorrectable_v=( ${uncorrectable} )


#Identify any GPUs that have experienced more row remaps than allowed.
for i in $(seq 0 $((ngpus-1))); do
	val=$((correctable_v[i] + uncorrectable_v[i]))
	if [ $val -gt 511 ]; then
		pass=0
		echo "GPU $i has $val row remaps due to ECC errors."
	fi
done


if [ $pass -ne 1 ]; then
	echo -e "\t **Fail** According to nvidia-smi at least one GPU had a"\
		"row remapping issue. Execute 'nvidia-smi -q -d ROW_REMAPPER'"\
		"to see the output."
	exit 1
else
	echo -e "\t **Pass** The ECC error check passed."
fi
		
