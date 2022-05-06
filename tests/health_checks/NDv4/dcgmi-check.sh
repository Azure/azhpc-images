#!/bin/bash

#Turn on persistence mode.
sudo nvidia-smi -pm 1 > /dev/null

#Run the basic (r=1) dcgmi diag tests.
fails=$(dcgmi diag -r 1 | grep "Fail" | wc -l)

if [ $fails -gt 0 ]; then
	echo "Fail: dcgmi tests have hit errors. Execute the command"\
		"'dcgmi diag -r 1' to see specific failures"
else
	echo "dcgmi test passes"
fi
