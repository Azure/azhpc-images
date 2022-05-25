#!/bin/bash
set -ex

# Place the topology file in /opt/microsoft
sudo mkdir -p /opt/microsoft
sudo bash -c "cat > /opt/microsoft/ndv4-topo.xml" <<'EOF'
<system version="1">
  <cpu numaid="0" affinity="0000ffff,0000ffff" arch="x86_64" vendor="AuthenticAMD" familyid="23" modelid="49">
    <pci busid="ffff:ff:01.0" class="0x060400" link_speed="16 GT/s" link_width="16">
      <pci busid="0001:00:00.0" class="0x030200" link_speed="16 GT/s" link_width="16"/>
      <pci busid="0101:00:00.0" class="0x020700" link_speed="16 GT/s" link_width="16"/>
      <pci busid="0002:00:00.0" class="0x030200" link_speed="16 GT/s" link_width="16"/>
      <pci busid="0102:00:00.0" class="0x020700" link_speed="16 GT/s" link_width="16"/>
    </pci>
  </cpu>
  <cpu numaid="1" affinity="0000ffff,0000ffff" arch="x86_64" vendor="AuthenticAMD" familyid="23" modelid="49">
    <pci busid="ffff:ff:02.0" class="0x060400" link_speed="16 GT/s" link_width="16">
      <pci busid="0003:00:00.0" class="0x030200" link_speed="16 GT/s" link_width="16"/>
      <pci busid="0103:00:00.0" class="0x020700" link_speed="16 GT/s" link_width="16"/>
      <pci busid="0004:00:00.0" class="0x030200" link_speed="16 GT/s" link_width="16"/>
      <pci busid="0104:00:00.0" class="0x020700" link_speed="16 GT/s" link_width="16"/>
    </pci>
  </cpu>
  <cpu numaid="2" affinity="0000ffff,0000ffff" arch="x86_64" vendor="AuthenticAMD" familyid="23" modelid="49">
      <pci busid="ffff:ff:03.0" class="0x060400" link_speed="16 GT/s" link_width="16">
      <pci busid="000b:00:00.0" class="0x030200" link_speed="16 GT/s" link_width="16"/>
      <pci busid="0105:00:00.0" class="0x020700" link_speed="16 GT/s" link_width="16"/>
      <pci busid="000c:00:00.0" class="0x030200" link_speed="16 GT/s" link_width="16"/>
      <pci busid="0106:00:00.0" class="0x020700" link_speed="16 GT/s" link_width="16"/>
    </pci>
  </cpu>
  <cpu numaid="3" affinity="0000ffff,0000ffff" arch="x86_64" vendor="AuthenticAMD" familyid="23" modelid="49">
    <pci busid="ffff:ff:04.0" class="0x060400" link_speed="16 GT/s" link_width="16">
      <pci busid="000d:00:00.0" class="0x030200" link_speed="16 GT/s" link_width="16"/>
      <pci busid="0107:00:00.0" class="0x020700" link_speed="16 GT/s" link_width="16"/>
      <pci busid="000e:00:00.0" class="0x030200" link_speed="16 GT/s" link_width="16"/>
      <pci busid="0108:00:00.0" class="0x020700" link_speed="16 GT/s" link_width="16"/>
    </pci>
  </cpu>
</system>
EOF

# Link the NDv4 topology file into /opt/microsoft/ndv4/
# Topology file in /opt/microsoft/ndv4-topo.xml will eventually be deleted
sudo mkdir -p /opt/microsoft/ndv4
ln -s /opt/microsoft/ndv4-topo.xml /opt/microsoft/ndv4/topo.xml


# Place NCv4 topology and graph files under /opt/microsoft/ncv4
sudo mkdir -p /opt/microsoft/ncv4
sudo bash -c "cat > /opt/microsoft/ncv4/topo.xml" <<'EOF'
<system version="1">
  <cpu numaid="0" affinity="00000000,00000000,00ffffff" arch="x86_64" vendor="AuthenticAMD" familyid="175" modelid="1">
    <pci busid="0001:00:00.0" class="0x030200" vendor="0x10de" device="0x20b5" subsystem_vendor="0x10de" subsystem_device="0x1533" link_speed="" link_width="0">
      <gpu dev="0" sm="80" rank="0" gdr="1">
        <nvlink target="0002:00:00.0" count="12" tclass="0x030200"/>
      </gpu>
    </pci>
    <nic>
      <net name="eth0" dev="0" speed="100000" port="0" latency="0.000000" guid="0x0" maxconn="65536" gdr="0"/>
    </nic>
  </cpu>
  <cpu numaid="1" affinity="00000000,0000ffff,ff000000" arch="x86_64" vendor="AuthenticAMD" familyid="175" modelid="1">
    <pci busid="0002:00:00.0" class="0x030200" vendor="0x10de" device="0x20b5" subsystem_vendor="0x10de" subsystem_device="0x1533" link_speed="" link_width="0">
      <gpu dev="1" sm="80" rank="1" gdr="1">
        <nvlink target="0001:00:00.0" count="12" tclass="0x030200"/>
      </gpu>
    </pci>
  </cpu>
  <cpu numaid="2" affinity="000000ff,ffff0000,00000000" arch="x86_64" vendor="AuthenticAMD" familyid="175" modelid="1">
    <pci busid="0003:00:00.0" class="0x030200" vendor="0x10de" device="0x20b5" subsystem_vendor="0x10de" subsystem_device="0x1533" link_speed="" link_width="0">
      <gpu dev="2" sm="80" rank="2" gdr="1">
        <nvlink target="0004:00:00.0" count="12" tclass="0x030200"/>
      </gpu>
    </pci>
  </cpu>
  <cpu numaid="3" affinity="ffffff00,00000000,00000000" arch="x86_64" vendor="AuthenticAMD" familyid="175" modelid="1">
    <pci busid="0004:00:00.0" class="0x030200" vendor="0x10de" device="0x20b5" subsystem_vendor="0x10de" subsystem_device="0x1533" link_speed="" link_width="0">
      <gpu dev="3" sm="80" rank="3" gdr="1">
        <nvlink target="0003:00:00.0" count="12" tclass="0x030200"/>
      </gpu>
    </pci>
  </cpu>
</system>
EOF


sudo bash -c "cat > /opt/microsoft/ncv4/graph.xml" <<'EOF'
<graphs version="1">
  <graph id="0" pattern="4" crossnic="0" nchannels="2" speedintra="12" speedinter="12" latencyinter="0" typeintra="SYS" typeinter="PIX" samechannels="0">
    <channel>
      <gpu dev="0"/>
      <gpu dev="1"/>
      <gpu dev="2"/>
      <gpu dev="3"/>
    </channel>
    <channel>
      <gpu dev="0"/>
      <gpu dev="3"/>
      <gpu dev="2"/>
      <gpu dev="1"/>
    </channel>
  </graph>
  <graph id="1" pattern="1" crossnic="0" nchannels="4" speedintra="12" speedinter="12" latencyinter="0" typeintra="SYS" typeinter="PIX" samechannels="0">
    <channel>
      <gpu dev="0"/>
      <gpu dev="1"/>
      <gpu dev="2"/>
      <gpu dev="3"/>
    </channel>
    <channel>
      <gpu dev="1"/>
      <gpu dev="0"/>
      <gpu dev="3"/>
      <gpu dev="2"/>
    </channel>
    <channel>
      <gpu dev="3"/>
      <gpu dev="2"/>
      <gpu dev="1"/>
      <gpu dev="0"/>
    </channel>
    <channel>
      <gpu dev="2"/>
      <gpu dev="3"/>
      <gpu dev="0"/>
      <gpu dev="1"/>
    </channel>
  </graph>
  <graph id="2" pattern="3" crossnic="0" nchannels="4" speedintra="12" speedinter="12" latencyinter="0" typeintra="SYS" typeinter="PIX" samechannels="0">
    <channel>
      <gpu dev="0"/>
      <gpu dev="1"/>
      <gpu dev="2"/>
      <gpu dev="3"/>
    </channel>
    <channel>
      <gpu dev="1"/>
      <gpu dev="0"/>
      <gpu dev="3"/>
      <gpu dev="2"/>
    </channel>
    <channel>
      <gpu dev="3"/>
      <gpu dev="2"/>
      <gpu dev="1"/>
      <gpu dev="0"/>
    </channel>
    <channel>
      <gpu dev="2"/>
      <gpu dev="3"/>
      <gpu dev="0"/>
      <gpu dev="1"/>
    </channel>
  </graph>
</graphs>
EOF
