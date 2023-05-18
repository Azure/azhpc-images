#!/bin/bash
set -ex

# Place NDv5 customizations under /opt/microsoft/ndv5
mkdir -p /opt/microsoft/ndv5

# Place the topology file in /opt/microsoft
bash -c "cat > /opt/microsoft/ndv5-topo.xml" <<'EOF'
<system version="1">
  <cpu numaid="0" affinity="ffffffff,ffff0000,00000000" arch="x86_64" vendor="GenuineIntel" familyid="6" modelid="143">
    <pci busid="ffff:ff:01.0" class="0x060400" link_speed="32.0 GT/s PCIe" link_width="16" vendor="0x0000" device="0x0000" subsystem_vendor="0x0000" subsystem_device="0x0000">
      <pci busid="0001:00:00.0" class="0x030200" link_speed="32.0 GT/s PCIe" link_width="16"/>
      <pci busid="0101:00:00.0" class="0x020700" link_speed="32.0 GT/s PCIe" link_width="16"/>
    </pci>
    <pci busid="ffff:ff:02.0" class="0x060400" link_speed="32.0 GT/s PCIe" link_width="16" vendor="0x0000" device="0x0000" subsystem_vendor="0x0000" subsystem_device="0x0000">
      <pci busid="0002:00:00.0" class="0x030200" link_speed="32.0 GT/s PCIe" link_width="16"/>
      <pci busid="0102:00:00.0" class="0x020700" link_speed="32.0 GT/s PCIe" link_width="16"/>
    </pci>
    <pci busid="ffff:ff:03.0" class="0x060400" link_speed="32.0 GT/s PCIe" link_width="16" vendor="0x0000" device="0x0000" subsystem_vendor="0x0000" subsystem_device="0x0000">
      <pci busid="0003:00:00.0" class="0x030200" link_speed="32.0 GT/s PCIe" link_width="16"/>
      <pci busid="0103:00:00.0" class="0x020700" link_speed="32.0 GT/s PCIe" link_width="16"/>
    </pci>
    <pci busid="ffff:ff:04.0" class="0x060400" link_speed="32.0 GT/s PCIe" link_width="16" vendor="0x0000" device="0x0000" subsystem_vendor="0x0000" subsystem_device="0x0000">
      <pci busid="0008:00:00.0" class="0x030200" link_speed="32.0 GT/s PCIe" link_width="16"/>
      <pci busid="0104:00:00.0" class="0x020700" link_speed="32.0 GT/s PCIe" link_width="16"/>
    </pci>
  </cpu>
  <cpu numaid="1" affinity="00000000,0000ffff,ffffffff" arch="x86_64" vendor="GenuineIntel" familyid="6" modelid="143">
    <pci busid="ffff:ff:05.0" class="0x060400" link_speed="32.0 GT/s PCIe" link_width="16" vendor="0x0000" device="0x0000" subsystem_vendor="0x0000" subsystem_device="0x0000">
      <pci busid="0009:00:00.0" class="0x030200" link_speed="32.0 GT/s PCIe" link_width="16"/>
      <pci busid="0105:00:00.0" class="0x020700" link_speed="32.0 GT/s PCIe" link_width="16"/>
    </pci>
    <pci busid="ffff:ff:06.0" class="0x060400" link_speed="32.0 GT/s PCIe" link_width="16" vendor="0x0000" device="0x0000" subsystem_vendor="0x0000" subsystem_device="0x0000">
      <pci busid="000a:00:00.0" class="0x030200" link_speed="32.0 GT/s PCIe" link_width="16"/>
      <pci busid="0106:00:00.0" class="0x020700" link_speed="32.0 GT/s PCIe" link_width="16"/>
    </pci>
    <pci busid="ffff:ff:07.0" class="0x060400" link_speed="32.0 GT/s PCIe" link_width="16" vendor="0x0000" device="0x0000" subsystem_vendor="0x0000" subsystem_device="0x0000">
      <pci busid="000b:00:00.0" class="0x030200" link_speed="32.0 GT/s PCIe" link_width="16"/>
      <pci busid="0107:00:00.0" class="0x020700" link_speed="32.0 GT/s PCIe" link_width="16"/>
    </pci>
    <pci busid="ffff:ff:08.0" class="0x060400" link_speed="32.0 GT/s PCIe" link_width="16" vendor="0x0000" device="0x0000" subsystem_vendor="0x0000" subsystem_device="0x0000">
      <pci busid="000c:00:00.0" class="0x030200" link_speed="32.0 GT/s PCIe" link_width="16"/>
      <pci busid="0108:00:00.0" class="0x020700" link_speed="32.0 GT/s PCIe" link_width="16"/>
    </pci>
  </cpu>
</system>
EOF

# Link the NDv5 topology file into /opt/microsoft/ndv5/
# Topology file in /opt/microsoft/ndv5-topo.xml will eventually be deleted
ln -sf /opt/microsoft/ndv5-topo.xml /opt/microsoft/ndv5/topo.xml

## Set NCCL configuration file for NDv5
bash -c "cat > /etc/nccl.conf" <<'EOF'
NCCL_IB_PCI_RELAXED_ORDERING=1
NCCL_TOPO_FILE=/opt/microsoft/ndv5/topo.xml
EOF

## NVIDIA Fabric manager
systemctl enable nvidia-fabricmanager
systemctl start nvidia-fabricmanager
systemctl is-active --quiet nvidia-fabricmanager

error_code=$?
if [ ${error_code} -ne 0 ]
then
    echo "NVIDIA Fabic Manager Inactive!"
    exit ${error_code}
fi

## load nvidia-peermem module
modprobe nvidia-peermem

