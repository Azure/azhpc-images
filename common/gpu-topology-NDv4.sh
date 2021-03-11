#!/bin/bash
set -e

### Place the NDv4 GPU topology file in /opt/msft/gpu-topology-NDv4.xml
sudo mkdir -p /opt/msft
sudo bash -c "cat > /opt/msft/gpu-topology-NDv4.xml" <<'EOF'
<system version="1">
  <cpu numaid="0" affinity="0000ffff,0000ffff" arch="x86_64" vendor="AuthenticAMD" familyid="143" modelid="49">
    <pci busid="ffff:ff:01.0" class="0x060400" link_speed="16 GT/s" link_width="16">
      <pci busid="0001:00:00.0" class="0x030200" link_speed="16 GT/s" link_width="16"/>
      <pci busid="0101:00:00.0" class="0x020700" link_speed="16 GT/s" link_width="16"/>
      <pci busid="0002:00:00.0" class="0x030200" link_speed="16 GT/s" link_width="16"/>
      <pci busid="0102:00:00.0" class="0x020700" link_speed="16 GT/s" link_width="16"/>
    </pci>
    <pci busid="ffff:ff:02.0" class="0x060400" link_speed="16 GT/s" link_width="16">
      <pci busid="0003:00:00.0" class="0x030200" link_speed="16 GT/s" link_width="16"/>
      <pci busid="0103:00:00.0" class="0x020700" link_speed="16 GT/s" link_width="16"/>
      <pci busid="0004:00:00.0" class="0x030200" link_speed="16 GT/s" link_width="16"/>
      <pci busid="0104:00:00.0" class="0x020700" link_speed="16 GT/s" link_width="16"/>
    </pci>
      <pci busid="ffff:ff:03.0" class="0x060400" link_speed="16 GT/s" link_width="16">
      <pci busid="000b:00:00.0" class="0x030200" link_speed="16 GT/s" link_width="16"/>
      <pci busid="0105:00:00.0" class="0x020700" link_speed="16 GT/s" link_width="16"/>
      <pci busid="000c:00:00.0" class="0x030200" link_speed="16 GT/s" link_width="16"/>
      <pci busid="0106:00:00.0" class="0x020700" link_speed="16 GT/s" link_width="16"/>
    </pci>
    <pci busid="ffff:ff:04.0" class="0x060400" link_speed="16 GT/s" link_width="16">
      <pci busid="000d:00:00.0" class="0x030200" link_speed="16 GT/s" link_width="16"/>
      <pci busid="0107:00:00.0" class="0x020700" link_speed="16 GT/s" link_width="16"/>
      <pci busid="000e:00:00.0" class="0x030200" link_speed="16 GT/s" link_width="16"/>
      <pci busid="0108:00:00.0" class="0x020700" link_speed="16 GT/s" link_width="16"/>
    </pci>
  </cpu>
</system>
EOF

exit 0
