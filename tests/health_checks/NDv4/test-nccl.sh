#!/bin/bash

##This script executes two nccl tests, one using ib and one using nvlink.
##It also checks that the performance on these benchmarks is satisfactory.

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
echo "NCCL tests:"

#Store output from calls passed to catch_error
output=""

pass=1

#Count the number of gpu-name nvidia-smi outputs.
error_smi="**Fail** nvidia-smi failed with error code"
#Load the mpi module.
module load mpi/hpcx > /dev/null

#Lock graphics clocks to 1400.
lock_clocks="sudo nvidia-smi -lgc 1400"
catch_error "$lock_clocks" "$error_smi"

mpi_text="mpirun -np 8 --bind-to numa --map-by ppr:8:node -x LD_LIBRARY_PATH="
mpi_text+="/usr/local/nccl-rdma-sharp-plugins/lib:\$LD_LIBRARY_PATH"
mpi_text+=" -mca coll_hcoll_enable 0 -x NCCL_IB_PCI_RELAXED_ORDERING=1"

exec_text="/opt/nccl-tests/build/all_reduce_perf -c 1 -b4G -f2 -g1 -e 4G"

exec_nvlink="timeout 3m $mpi_text -x UCX_TLS=tcp -x UCX_NET_DEVICES=eth0"
exec_nvlink+=" -x CUDA_DEVICE_ORDER=PCI_BUS_ID -x NCCL_SOCKET_IFNAME=eth0 -x"
exec_nvlink+=" NCCL_DEBUG=WARN -x NCCL_TOPO_FILE=/opt/microsoft/ndv4-topo.xml"
exec_nvlink+=" $exec_text"

error_nvlink="**Fail** nccl test using nvlink failed with error code"

#Run a single node nccl test using nvlink.
catch_error "$exec_nvlink" "$error_nvlink"
nccl_nvlink=$(echo "$output")


#select the average bandwidth from the nccl output.
bw=$(echo "$nccl_nvlink" | grep "Avg bus bandwidth" | awk '{print $6}')
#the average bandwidth should be above 235 GB/s.
less=$(echo "scale=4; 230.0 > $bw" | bc)
if [ $less -eq 1 ]; then
       echo -e "\t **Fail** observed bandwidth in nvlink nccl test is $bw."
       pass=0
fi

#Run a single node nccl test using infiniBand.
exec_ib="timeout 3m $mpi_text -H localhost:8 -x UCX_IB_PCI_RELAXED_ORDERING=on"
exec_ib+=" -x UCX_TLS=tcp -x UCX_NET_DEVICES=eth0 -x"
exec_ib+=" CUDA_DEVICE_ORDER=PCI_BUS_ID -x NCCL_SOCKET_IFNAME=eth0 -x"
exec_ib+=" NCCL_NET_GDR_LEVEL=5 -x NCCL_TOPO_FILE=/opt/microsoft/ndv4-topo.xml"
exec_ib+=" -x NCCL_SHM_DISABLE=1 -x NCCL_P2P_DISABLE=1 $exec_text"

error_ib="**Fail** the nccl ib test exited with error code"

catch_error "$exec_ib" "$error_ib"
nccl_ib=$(echo "$output")

#select the average bandwidth from the nccl output.
bw=$(echo "$nccl_ib" | grep "Avg bus bandwidth" | awk '{print $6}')

#the average bandwidth should be above 20 GB/s.
less=$(echo "scale=4; 20.0 > $bw" | bc)
if [ $less -eq 1 ]; then
       echo -e "\t **Fail** observed bandwidth in ib nccl test is $bw."
       pass=0
fi

#Unlock the graphics clock.
unlock_clocks="sudo timeout 3m nvidia-smi -rgc"
catch_error "$unlock_clocks" "$error_smi"

if [ $pass -eq 1 ]; then
	echo -e "\t **Pass** Both nccl tests pass."
else
	exit 1;
fi

