#!/bin/bash
d=0;
#ECC errors are handled by row remapping on A100. First count the number of 
#row remappings due to ECC errors (correctable and otherwise). If any GPU has
#512 or  more, the test fails. 

pass=1

ngpus=$(sudo nvidia-smi --query-gpu=name --format=csv,noheader | wc -l)

row_remaps=$(nvidia-smi -q -d ROW_REMAPPER)

#Query the nvidia-smi output to identify any pending row remaps.
pending=$(echo "$row_remaps" | grep "Pending" | cut -d: -f2)
gpui=0

#Check if any GPU has a pending remap.
for pend in $pending; do
	if [ "$pend" != "No" ]; then
		echo "$gpui has a pending remap."
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
for i in $(eval echo {0..$((ngpus-1))}); do
	val=$((correctable_v[i] + uncorrectable_v[i]))
	if [ $val -gt 511 ]; then
		pass=0
		echo "GPU $i has $val row remaps due to ECC errors."
	fi
done


if [ $pass -ne 1 ]; then
	echo "Fail: According to nvidia-smi at least one GPU had a row"\
		"remapping issue. Execute 'nvidia-smi -q -d ROW_REMAPPER' to"\
		"see the output."
else
	echo "ECC error check passes"
fi
		
