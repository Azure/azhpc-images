#!/bin/bash

##This script runs dcgmi diag -r 1 tests and evaluates if any fail.

#Catch error codes that may be thrown by the executable passed as the first
#input, and if an error code is tripped throw the second input as a message. 
catch_error() {
	output=$($1)
	err_code=$?
	if [ $err_code -ne 0 ]; then
		echo -e "\t $2 $err_code" >&2
		exit $err_code;
	fi
}

output=""
error_smi="**Fail** nvidia-smi failed with error code"

echo "dcgmi diag tests:"


#get the number of GPUs
exec_names="timeout 3m sudo nvidia-smi --query-gpu=name --format=csv,noheader"
catch_error "$exec_names" "$error_smi"
ngpus=$(echo "$output" | wc -l)

#array to hold status of persistence mode for each gpu
declare -a pmvals=()

#Find which GPUs have persistence mode off, record that information in pmvals.
#Enable persistence mode on GPUs that have it disabled. 
for i in $(seq 0 $((ngpus-1))); do
	exec_query="timeout 3m nvidia-smi -i $i -q"
	catch_error "$exec_query" "$error_smi"
	pmvals[$i]=$(echo "$output" | grep "Persistence Mode" \
		| awk '{print $4}')
	if [ ${pmvals[$i]} == "Disabled" ]; then
		exec_pm="timeout 3m sudo nvidia-smi -i $i -pm 1"
                catch_error "$exec_pm" "$error_smi"
	fi	       
done

#Turn on persistence mode.

#Run the basic (r=1) dcgmi diag tests.
exec_dcgmi="timeout 3m dcgmi diag -r 1"
error_dcgmi="**Fail** dcgmi diag failed with error code"
catch_error "$exec_dcgmi" "$error_dcgmi"
fails=$(echo "$output" | grep "Fail" | wc -l)

#Disable persistence mode on GPUs that started with it disabled.
for i in $(seq 0 $((ngpus-1))); do
	if [ ${pmvals[$i]} == "Disabled" ]; then
	       #sudo nvidia-smi -i $i -pm 0 > /dev/null
		exec_pm="timeout 3m sudo nvidia-smi -i $i -pm 0"
                catch_error "$exec_pm" "$error_smi"
	fi	       
done

#Disable persistence mode on GPUs that started with it disabled.
for i in $(seq 0 $((ngpus-1))); do
	if [ ${pmvals[$i]} == "Disabled" ]; then
	       #sudo nvidia-smi -i $i -pm 0 > /dev/null
		exec_pm="timeout 3m sudo nvidia-smi -i $i -pm 0"
                catch_error "$exec_pm" "$error_smi"
	fi	       
done

if [ $fails -gt 0 ]; then
	echo -e " \t **Fail** dcgmi tests have hit errors. Execute the"\
		"command 'dcgmi diag -r 1' to see specific failures"
	exit 1
else
	echo -e " \t **Pass** All level 1 dcgmi diag tests passed."
fi
