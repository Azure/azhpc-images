#!/bin/bash
set -ex

## Systemd service for setting up nvme devices
cat <<EOF >/usr/sbin/nvme_raid_start.sh
#!/bin/bash

nvme_disks_name=\`ls /dev/nvme*n1\`
nvme_disks=\`ls -latr /dev/nvme*n1 | wc -l\`

if [ "\$nvme_disks" == "0" ]
then
    exit 1
fi

# Stop any existing RAID array
if [ -e /dev/md128 ]; then
    mdadm --stop /dev/md128
    for dev in \$nvme_disks_name; do
        # Zeroing block for the NVMe device
        mdadm --zero-superblock \$dev
    done
fi

# Create the RAID array
mdadm --create /dev/md128 --level=0 --raid-devices=\$nvme_disks \$nvme_disks_name

# Create the filesystem if it doesn't exist
if [ -z "\$(blkid -o value -s UUID /dev/md128)" ]; then
    echo "Creating filesystem on /dev/md128..."

    # Create a file system
    mkfs.xfs /dev/md128

    # Assign a unique ID for the generated file system
    xfs_admin -U generate /dev/md128
fi

uuid_md128=\$(mdadm --detail /dev/md128 | grep UUID | awk '{print \$3}')

# Check if mdadm config already has /dev/md128 UUID info
# replace if it does and append if not
[ ! -f /etc/mdadm/mdadm.conf ] && touch /etc/mdadm/mdadm.conf
if grep -q '^UUID=' /etc/mdadm/mdadm.conf
then
    sed -i '/^UUID=[0-9a-f:]* \/dev\/md128/s/.*/UUID='"\$uuid_md128"' \/dev\/md128/' /etc/mdadm/mdadm.conf
else
    echo "UUID=\$uuid_md128 /dev/md128" | tee -a /etc/mdadm/mdadm.conf
fi

update-initramfs -u

mkdir -p /mnt/resource_nvme

# Add the entry to /etc/fstab if it doesn't exist
if ! grep -q "/dev/md128 /mnt/resource_nvme xfs" /etc/fstab; then
    echo "/dev/md128 /mnt/resource_nvme xfs" >> /etc/fstab
fi

# Mount the file system
mount /dev/md128 /mnt/resource_nvme
chmod 777 /mnt/resource_nvme

EOF
chmod 755 /usr/sbin/nvme_raid_start.sh

cat <<EOF >/usr/sbin/nvme_raid_stop.sh
#!/bin/bash

# Unmount the file system
if mountpoint -q /mnt/resource_nvme; then
    umount /mnt/resource_nvme
fi

# Stop the RAID array
if [ -e /dev/md128 ]; then
    mdadm --stop /dev/md128
    nvme_disks_name=\`ls /dev/nvme*n1\`
    for dev in \$nvme_disks_name; do
        mdadm --zero-superblock \$dev
    done
fi

# Clear the UUID from /etc/mdadm/mdadm.conf
sed -i '/^UUID=/d' /etc/mdadm/mdadm.conf

EOF
chmod 755 /usr/sbin/nvme_raid_stop.sh

cat <<EOF >/etc/systemd/system/nvme-raid.service
[Unit]
Description=Setup NVMe RAID array
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/sbin/nvme_raid_start.sh
ExecStop=/usr/sbin/nvme_raid_stop.sh
RemainAfterExit=yes
StandardOutput=journal

[Install]
WantedBy=multi-user.target
EOF
