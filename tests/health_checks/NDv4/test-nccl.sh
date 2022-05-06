#!/bin/bash

#Load the mpi module.
module load mpi/hpcx

#Lock graphics clocks to 1400.
sudo nvidia-smi -lgc 1400 > /dev/null


#Run a single node nccl test using nvlink.
nccl_nvlink=$(mpirun -np 8 --bind-to numa --map-by ppr:8:node -x \
       LD_LIBRARY_PATH=/usr/local/nccl-rdma-sharp-plugins/lib:$LD_LIBRARY_PATH \
       -mca coll_hcoll_enable 0 -x NCCL_IB_PCI_RELAXED_ORDERING=1 \
       -x UCX_TLS=tcp -x UCX_NET_DEVICES=eth0 -x CUDA_DEVICE_ORDER=PCI_BUS_ID \
       -x NCCL_SOCKET_IFNAME=eth0 -x NCCL_DEBUG=WARN \
       -x NCCL_TOPO_FILE=/opt/microsoft/ndv4-topo.xml \
       /opt/nccl-tests/build/all_reduce_perf -b4G -f2 -g1 -e 4G)

#select the average bandwidth from the nccl output.
bw=$(echo "$nccl_nvlink" | grep "Avg bus bandwidth" | \
	cut -d: -f2 | cut -d ' ' -f 2 | cut -d. -f1)

#the average bandwidth should be above 235 GB/s.
if [ $bw -lt 220 ]; then
       echo "Fail: observed bandwidth in nvlink nccl test is $bw."
else
       echo "nvlink nccl test passed."
fi

#Run a single node nccl test using infiniBand.
nccl_ib=$(mpirun -np 8 --map-by ppr:8:node -bind-to numa -H localhost:8 -x \
       LD_LIBRARY_PATH=/usr/local/nccl-rdma-sharp-plugins/lib:$LD_LIBRARY_PATH \
       -mca coll_hcoll_enable 0 -x NCCL_IB_PCI_RELAXED_ORDERING=1 \
       -x UCX_IB_PCI_RELAXED_ORDERING=on -x UCX_TLS=tcp \
       -x UCX_NET_DEVICES=eth0 -x CUDA_DEVICE_ORDER=PCI_BUS_ID \
       -x NCCL_SOCKET_IFNAME=eth0 -x NCCL_NET_GDR_LEVEL=5 -x \
       NCCL_TOPO_FILE=/opt/microsoft/ndv4-topo.xml -x NCCL_SHM_DISABLE=1 \
       -x NCCL_P2P_DISABLE=1 /opt/nccl-tests/build/all_reduce_perf -b 4G \
       -f 2 -g 1 -e 4G)

#select the average bandwidth from the nccl output.
bw=$(echo "$nccl_ib" | grep "Avg bus bandwidth" | cut -d: -f2 | \
	cut -d ' ' -f 2 | cut -d. -f1)

#the average bandwidth should be above 20 GB/s.
if [ $bw -lt 20 ]; then
       echo "Fail: observed bandwidth in ib nccl test is $bw."
else
       echo "ib nccl test passed."
fi

#Unlock the graphics clock.
sudo nvidia-smi -rgc > /dev/null
