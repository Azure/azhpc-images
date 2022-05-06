#!/bin/bash

ib=200;
num_r=0
num_s=0
num_ps=0

#Check ibstat Rates and make sure they are all 200.
for i in $(ibstat | grep "Rate:" | cut -d: -f2 | xargs); do 
	num_r=$((num_r+1));
	if [ $i -lt $ib ];
        	then ib=$i;
	fi;
done

#Check ibstat to make sure States are set to Active.
for i in $(ibstat | grep "State:" | cut -d: -f2); do
	if [ "$i" = "Active" ]; then
		num_s=$((num_s+1));
	fi
done

#Check ibstat to make sure Physical states are set to LinkUp
for i in $(ibstat | grep "Physical state:" | cut -d: -f2); do
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
	echo "The ib 'State' is not set to 'Active' for all"\
		"devices."
	pass=0
fi

if [ $num_ps -lt $num_r ]; then
	echo "The ib 'Physical state' is not set to LinkUp for"\
		"all devices."
	pass=0
fi
if [ $pass -eq 1 ]; then
	echo "All ibstat settings are ok."
else
	echo "Fail: The settings returned by ibstat indicate a problem."
fi
	
