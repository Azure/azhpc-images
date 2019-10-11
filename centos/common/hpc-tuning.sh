# Disable some unneeded services by default (administrators can re-enable if desired)
systemctl disable wpa_supplicant
systemctl disable abrtd
systemctl disable firewalld

# Update memory limits
cat << EOF >> /etc/security/limits.conf
*               hard    memlock         unlimited
*               soft    memlock         unlimited
*               soft    nofile          65535
*               hard    nofile          65535
EOF

# Enable reclaim mode
echo "vm.zone_reclaim_mode = 1" >> /etc/sysctl.conf
sysctl -p

# Configure WALinuxAgent
sed -i -e 's/# OS.EnableRDMA=y/OS.EnableRDMA=y/g' /etc/waagent.conf
sed -i -e 's/CGroups.EnforceLimits=n/CGroups.EnforceLimits=y/g' /etc/waagent.conf
systemctl enable waagent

