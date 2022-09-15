#!/bin/bash

echo "MaxPayload test:"

pass=1
ids=$(lspci | grep "3D controller" | cut -d' ' -f1)
for i in $(echo "$ids"); do
	DevCap=$(sudo lspci -vv -s $i | grep DevCap: \
		| cut -d' ' -f2)
	DevCtl=$(sudo lspci -vv -s $i | grep DevCtl: -A 2 \
		| grep MaxPayload | cut -d' ' -f2)
	if [[ $DevCap -ne $DevCtl ]]; then
		echo "DevCap and DevCtl MaxPayload do not match for device $i"
		exit 1;
	fi
done
echo -e "\t **Pass** The MaxPayload size check passed."
