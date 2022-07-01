#!/bin/bash

##This script examines the output of ibstatus, looking for any problems.

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
echo "check ibstatus:"

#Store output from calls passed to catch_error
output=""

ib=200;
num_r=0
num_s=0
num_ps=0


#Check ibstatus Rates and make sure they are all 200.
exec_ibstat="timeout 3m ibstatus"
error_ibstat="**Fail** ibstatus exited with error code"
catch_error "$exec_ibstat" "$error_ibstat"
ibstat_out=$(echo "$output")

#make sure we are only checking rates for InfiniBand
types=$(echo "$ibstat_out" | grep "link_layer:" | awk '{print $2}')
types_v=( ${types} )

for i in $(echo "$ibstat_out" | grep "rate:" | awk '{print $2}'); do 
	num_r=$((num_r+1));
	if [ $i -lt $ib ]; then
		ir=$((num_r-1))
		if [ "${types_v[ir]}" = "InfiniBand" ]; then
			ib=$i;
		fi
	fi;
done

#Check ibstatus to make sure States are set to Active.
for i in $(echo "$ibstat_out" | grep "state:" | grep -v "phys" | awk '{print $3}'); do
	if [ "$i" = "ACTIVE" ]; then
		num_s=$((num_s+1));
	fi
done

#Check ibstatus to make sure Physical states are set to LinkUp
for i in $(echo "$ibstat_out" | grep "phys state:" | awk '{print $4}'); do
	if [ "$i" = "LinkUp" ]; then
		num_ps=$((num_ps+1));
	fi
done

pass=1


if [ $ib -lt 200 ]; then
	echo "The minimum ib rate observed is $ib, but it should be 200."
	pass=0
fi

if [ $num_s -lt $num_r ]; then
	echo "The ib 'State' is not set to 'ACTIVE' for all devices."
	pass=0
fi

if [ $num_ps -lt $num_r ]; then
	echo "The ib 'Physical state' is not set to LinkUp for all devices."
	pass=0
fi

if [ $pass -eq 1 ]; then
	echo -e "\t **Pass** All ibstatus settings are ok."
else
	echo -e "\t **Fail** The settings returned by ibstatus indicate a problem."
	exit 1;
fi
	
