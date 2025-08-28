#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

#move to rocm package
rocm_metadata=$(get_component_config "rocm")
rocm_version=$(jq -r '.version' <<< $rocm_metadata)
rocm_url=$(jq -r '.url' <<< $rocm_metadata)
rocm_sha256=$(jq -r '.sha256' <<< $rocm_metadata)
DEBPACKAGE=$(basename ${rocm_url})

if [[ $DISTRIBUTION == ubuntu* ]]; then
   if [[ $DISTRIBUTION == "ubuntu24.04" ]]; then
      # ROCm 6.4 depends on mivisionx-dev which depends on libopencv-dev which depends on libopenmpi3t64 which depends on libucx0, which is a Ubuntu upstream UCX that
      # is older than and conflicts with the ucx package installed by doca-ofed and has unknown IB support status.
      # We install this marker package to indicate to the package manager that ucx provides libucx0 so that ROCm can be installed.
      # TODO: make sure a UCX that actually has proper IB, GDR and ROCm support is being used
      # See https://askubuntu.com/a/218294/595565
      apt install -y equivs
      ucx_version=$(dpkg -s ucx | grep Version | awk '{print $2}')
      cat <<EOF > /tmp/ucx-provides-libucx0
Section: misc
Priority: optional
Homepage: https://github.com/Azure/azhpc-images
Standards-Version: 3.9.2

Package: ucx-provides-libucx0
Depends: ucx
Provides: libucx0 (= ${ucx_version})
Version: ${ucx_version}
Maintainer: Azure HPC Platform team <hpcplat@microsoft.com>
Description: marker package in Azure HPC Image to work around ROCm dependency issue
EOF
      equivs-build /tmp/ucx-provides-libucx0
      dpkg -i ucx-provides-libucx0_${ucx_version}_all.deb
      rm -f ucx-provides-libucx0_${ucx_version}_all.deb
      rm -f /tmp/ucx-provides-libucx0
   fi
   download_and_verify ${rocm_url} ${rocm_sha256}
   apt install -y ./${DEBPACKAGE}
   amdgpu-install -y --usecase=graphics,rocm
   apt install -y rocm-bandwidth-test
   rm -f ./${DEBPACKAGE}
elif [[ $DISTRIBUTION == "azurelinux3.0" ]]; then
   tdnf install -y azurelinux-repos-amd
   tdnf -y install kernel-drivers-gpu-$(uname -r)
   tdnf -y install \
   https://packages.microsoft.com/azurelinux/3.0/prod/amd/x86_64/Packages/a/amdgpu-${AMDGPU_VERSION}_$(uname -r | sed 's/-/./').x86_64.rpm \
   https://packages.microsoft.com/azurelinux/3.0/prod/amd/x86_64/Packages/a/amdgpu-firmware-${AMDGPU_VERSION}.azl3.noarch.rpm \
   https://packages.microsoft.com/azurelinux/3.0/prod/amd/x86_64/Packages/a/amdgpu-headers-${AMDGPU_VERSION}.azl3.noarch.rpm

   # Add Azure Linux 3 ROCM repo file
   cat <<EOF >> /etc/yum.repos.d/amd_rocm.repo
[amd_rocm]
name="AMD ROCM packages repo for Azure Linux 3.0"
baseurl=https://repo.radeon.com/.hidden/c5c79c1ea1d0aa6008ddbd29c3ea1523/rocm/azurelinux3/${rocm_version}/main/
enabled=1
repo_gpgcheck=0
gpgcheck=0
sslverify=0
EOF

   tdnf repolist --refresh
   tdnf install -y rocm-dev rocm-validation-suite rocm-bandwidth-test
   tdnf install -y rocm-smi-lib rocm-core rocm-device-libs rocm-llvm rocm-validation-suite

   #Add self to render and video groups so they can access gpus.
   usermod -a -G render $(logname)
   usermod -a -G video $(logname)

   tdnf install -y rocm-bandwidth-test
fi
write_component_version "ROCM" ${rocm_version}

#Grant access to GPUs to all users via udev rules
cat <<'EOF' > /etc/udev/rules.d/99-amdgpu-permissive.rules
KERNEL=="kfd", MODE="0666"
SUBSYSTEM=="drm", KERNEL=="renderD*", MODE="0666"
EOF

udevadm control --reload-rules && sudo udevadm trigger

if [[ $DISTRIBUTION == ubuntu* ]]; then
   echo blacklist amdgpu | tee -a /etc/modprobe.d/blacklist.conf
   update-initramfs -c -k $(uname -r)
fi

#1002:740c is Mi200
#1002:74b5 is Mi300x
#1002:74bd is Mi300HF
echo "Writing gpu mode probe in init.d"
cat <<'EOF' > /tmp/tempinit.sh
#!/bin/sh
at_count=0
while [ $at_count -le 90 ]
do
    if [ $(lspci -d 1002:74b5 | wc -l) -eq 8 -o $(lspci -d 1002:74bd | wc -l) -eq 8 -o $(lspci -d 1002:740c | wc -l) -eq 16 ]; then
       echo Required number of GPUs found
       at_count=91
       sleep 120s
       echo doing Modprobe for amdgpu
       if [ $(lspci -d 1002:740c | wc -l) -eq 16 ]; then
          sudo modprobe amdgpu
       else
          sudo modprobe -r hyperv_drm
          sudo modprobe amdgpu ip_block_mask=0x7f
       fi
    else
       sleep 10
       at_count=$(($at_count + 1))
    fi
done

exit 0
EOF
cp /tmp/tempinit.sh /etc/init.d/initamdgpu.sh
chmod +x /etc/init.d/initamdgpu.sh
rm /tmp/tempinit.sh

echo "Completed gpu mode probe in init.d"

echo -e '[Unit]\n\nDescription=Runs /etc/init.d/initamdgpu.sh\n\n' \
               | tee rocmstartup.service
echo -e '[Service]\n\nExecStart=/etc/init.d/initamdgpu.sh\n\n' \
               | tee -a rocmstartup.service
echo -e '[Install]\n\nWantedBy=multi-user.target' \
               | tee -a rocmstartup.service

mv rocmstartup.service /etc/systemd/system/rocmstartup.service
systemctl start rocmstartup
systemctl enable rocmstartup
