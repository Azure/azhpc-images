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
# Wait until device exists 
udevadm settle

# Create the filesystem if it doesn't exist
if [ -z "\$(blkid -o value -s UUID /dev/md128)" ]; then
    echo "Creating filesystem on /dev/md128..."

    # Create a file system
    mkfs.xfs /dev/md128
fi

mdadm --detail --scan >> /etc/mdadm/mdadm.conf

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

# Clear the fstab entry
sed -i "/\/dev\/md128 \/mnt\/resource_nvme xfs/d" /etc/fstab


# Stop the RAID array
if [ -e /dev/md128 ]; then
    mdadm --stop /dev/md128
    
    nvme_disks_name=\`ls /dev/nvme*n1\`
    for dev in \$nvme_disks_name; do
        mdadm --zero-superblock \$dev
    done

    sed -i '/ARRAY \/dev\/md128/d' /etc/mdadm/mdadm.conf
fi

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
