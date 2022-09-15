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

DRAM_ECC_THRESHOLD=20000000
SRAM_ECC_THRESHOLD=10000


#query the number of gpus
exec_names="timeout 3m nvidia-smi --query-gpu=name --format=csv,noheader"
error_smi="**Fail** nvidia-smi failed with error code"
catch_error "$exec_names" "$error_smi"
ngpus=$(echo "$output" | wc -l)

#query nvidia-smi to collect row remap information.
exec_rows="timeout 3m nvidia-smi -q -d ROW_REMAPPER"
catch_error "$exec_rows" "$error_smi"
row_remaps=$(echo "$output")

#query nvidia-smi to collect row remap information.
exec_ecc="timeout 3m nvidia-smi -q -d ECC"
catch_error "$exec_ecc" "$error_smi"
ECC_errors=$(echo "$output")


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
	val=$((uncorrectable_v[i]))
	if [ $val -gt 512 ]; then
		pass=0
		echo "GPU $i has $val uncorrectable row remap errors."
	fi
done

#Check the number of uncorrectable volatile SRAM ECC errors. Fail if any are
#observed
uncorrectableVS=$(echo "$ECC_errors" | grep Volatile -A 4 \
	| grep "SRAM Uncorrectable" | cut -d: -f2)
uncorrectableVS_v=( ${uncorrectableVS} )
for i in $(seq 0 $((ngpus-1))); do
	val=$((uncorrectableVS_v[i]))
	if [ $val -gt 0 ]; then
		pass=0
		echo "GPU $i has $val uncorrectable volatile SRAM errors."
	fi
done

#Count the number of correctable volatile SRAM ECC errors. Warn if more than
#SRAM_ECC_THRESHOLD are observed, but don't fail. 
correctableVS=$(echo "$ECC_errors"  | grep Volatile -A 4 \
	| grep "SRAM Correctable" | cut -d: -f2)
CorrectableVS_v=( ${correctableVS} )
for i in $(seq 0 $((ngpus-1))); do
	val=$((correctableVS_v[i]))
	if [ $val -gt $SRAM_ECC_THRESHOLD ]; then
		echo "GPU $i has $val correctable volatile SRAM errors."
	fi
done

#Count the number of uncorrectable volatile DRAM ECC errors. Warn if more than
#DRAM_ECC_THRESHOLD are observed but don't fail.
uncorrectableVD=$(echo "$ECC_errors" | grep Volatile -A 4 \
	| grep "DRAM Uncorrectable" | cut -d: -f2)
uncorrectableVD_v=( ${uncorrectableVD} )
for i in $(seq 0 $((ngpus-1))); do
	val=$((uncorrectableVD_v[i]))
	if [ $val -gt $DRAM_ECC_THRESHOLD ]; then
		echo "GPU $i has $val uncorrectable volatile DRAM errors."
	fi
done

#Count the number of correctable volatile DRAM ECC errors. Warn if more than
#DRAM_ECC_THRESHOLD are observed but don't fail.
correctableVD=$(echo "$ECC_errors" | grep Volatile -A 4 \
	| grep "DRAM Correctable" | cut -d: -f2)
correctableVD_v=( ${correctableVD} )
for i in $(seq 0 $((ngpus-1))); do
	val=$((correctableVD_v[i]))
	if [ $val -gt $DRAM_ECC_THRESHOLD ]; then
		echo "GPU $i has $val correctable volatile DRAM errors."
	fi
done

#Check the number of uncorrectable aggregate SRAM ECC errors. Fail if any are
#detected.
uncorrectableAS=$(echo "$ECC_errors" | grep Aggregate -A 4 \
	| grep "SRAM Uncorrectable" | cut -d: -f2)
uncorrectableAS_v=( ${uncorrectableAS} )
for i in $(seq 0 $((ngpus-1))); do
	val=$((uncorrectableAS_v[i]))
	if [ $val -gt 0 ]; then
		pass=0
		echo "GPU $i has $val uncorrectable aggregate SRAM errors."
	fi
done

#Count the number of correctable aggregate SRAM ECC errors. Warn if more than
#SRAM_ECC_THRESHOLD are detected but don't fail.
correctableAS=$(echo "$ECC_errors" | grep Aggregate -A 4 \
	| grep "SRAM Correctable" | cut -d: -f2)
correctableAS_v=( ${correctableAS} )
for i in $(seq 0 $((ngpus-1))); do
	val=$((correctableAS_v[i]))
	if [ $val -gt $SRAM_ECC_THRESHOLD ]; then
		echo "GPU $i has $val correctable aggregate SRAM errors."
	fi
done

#Count the number of uncorrectable aggregate DRAM ECC errors. Warn if more than
#DRAM_ECC_THRESHOLD are detected but don't fail.
uncorrectableAD=$(echo "$ECC_errors" | grep Aggregate -A 4 \
	| grep "DRAM Uncorrectable" | cut -d: -f2)
uncorrectableAD_v=( ${uncorrectableAD} )
for i in $(seq 0 $((ngpus-1))); do
	val=$((uncorrectableAD_v[i]))
	if [ $val -gt $DRAM_ECC_THRESHOLD ]; then
		echo "GPU $i has $val uncorrectable aggregate DRAM errors."
	fi
done

#Count the number of correctable aggregate DRAM ECC errors. Warn if more than
#DRAM_ECC_THRESHOLD are detected but don't fail.
correctableAD=$(echo "$ECC_errors" | grep Aggregate -A 4 \
	| grep "DRAM Correctable" | cut -d: -f2)
correctableAD_v=( ${correctableAD} )
for i in $(seq 0 $((ngpus-1))); do
	val=$((correctableAD_v[i]))
	if [ $val -gt $DRAM_ECC_THRESHOLD ]; then
		echo "GPU $i has $val correctable aggregate DRAM errors."
	fi
done

if [ $pass -ne 1 ]; then
	echo -e "\t **Fail** According to nvidia-smi at least one GPU had an"\
		"ECC error status to investigate."
	exit 1
else
	echo -e "\t **Pass** The ECC error check passed."
fi
		
