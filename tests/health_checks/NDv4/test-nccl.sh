#!/bin/bash

#Load the mpi module.
module load mpi/hpcx

#Lock graphics clocks to 1400.
sudo nvidia-smi -lgc 1400 > /dev/null

mpi_text="mpirun -np 8 --bind-to numa --map-by ppr:8:node -x LD_LIBRARY_PATH="
mpi_text+="/usr/local/nccl-rdma-sharp-plugins/lib:\$LD_LIBRARY_PATH"
mpi_text+=" -mca coll_hcoll_enable 0 -x NCCL_IB_PCI_RELAXED_ORDERING=1"

exec_text="/opt/nccl-tests/build/all_reduce_perf -b4G -f2 -g1 -e 4G"

#Run a single node nccl test using nvlink.
nccl_nvlink=$($mpi_text -x UCX_TLS=tcp -x UCX_NET_DEVICES=eth0 \
	-x CUDA_DEVICE_ORDER=PCI_BUS_ID -x NCCL_SOCKET_IFNAME=eth0 \
	-x NCCL_DEBUG=WARN -x NCCL_TOPO_FILE=/opt/microsoft/ndv4-topo.xml \
	$exec_text)
err_nccl=$?
if [ $err_nccl -ne 0 ]; then
	echo "Fail: The nccl nvlink test failed to execute. It exited with"\
	       "error code $err_nccl"
	exit $err_nccl
fi


#select the average bandwidth from the nccl output.
bw=$(echo "$nccl_nvlink" | grep "Avg bus bandwidth" | awk '{print $6}')
#the average bandwidth should be above 235 GB/s.
less=$(echo "scale=4; 220.0 > $bw" | bc)
if [ $less -eq 1 ]; then
       echo "Fail: observed bandwidth in nvlink nccl test is $bw."
else
       echo "nvlink nccl test passed."
fi

#Run a single node nccl test using infiniBand.
nccl_ib=$($mpi_text -H localhost:8 -x UCX_IB_PCI_RELAXED_ORDERING=on -x \
	UCX_TLS=tcp -x UCX_NET_DEVICES=eth0 -x CUDA_DEVICE_ORDER=PCI_BUS_ID \
       -x NCCL_SOCKET_IFNAME=eth0 -x NCCL_NET_GDR_LEVEL=5 \
       -x NCCL_TOPO_FILE=/opt/microsoft/ndv4-topo.xml -x NCCL_SHM_DISABLE=1 \
       -x NCCL_P2P_DISABLE=1 $exec_text)
err_nccl=$?
if [ $err_nccl -ne 0 ]; then
	echo "Fail: The nccl ib test failed to execute. It exited with"\
	       "error code $err_nccl"
	exit $err_nccl
fi

#select the average bandwidth from the nccl output.
bw=$(echo "$nccl_ib" | grep "Avg bus bandwidth" | awk '{print $6}')

#the average bandwidth should be above 20 GB/s.
less=$(echo "scale=4; 20.0 > $bw" | bc)
if [ $less -eq 1 ]; then
       echo "Fail: observed bandwidth in ib nccl test is $bw."
else
       echo "ib nccl test passed."
fi

#Unlock the graphics clock.
sudo nvidia-smi -rgc > /dev/null
