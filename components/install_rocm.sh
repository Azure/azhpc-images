#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

#move to rocm package
rocm_metadata=$(get_component_config "rocm")
rocm_version=$(jq -r '.version' <<< $rocm_metadata)

if [[ $DISTRIBUTION == "ubuntu26.04" ]]; then
    driver_metadata=$(get_component_config "amdgpu")
    driver_version=$(jq -er '.version' <<< "$driver_metadata")
    driver_url="https://repo.radeon.com/amdgpu/${driver_version}/ubuntu"
    rocm_package="amdrocm-core-sdk${rocm_version}"

    apt install -y ca-certificates wget gnupg dkms "linux-headers-$(uname -r)"
    install -d -m 0755 /etc/apt/keyrings
    wget -O /tmp/amdrocm-packages.key https://stable.repo.amd.com/rocm/gpg/packages.gpg
    gpg --batch --yes --dearmor -o /etc/apt/keyrings/amdrocm.gpg /tmp/amdrocm-packages.key
    wget -O /tmp/amdgpu-packages.key https://repo.radeon.com/rocm/rocm.gpg.key
    gpg --batch --yes --dearmor -o /etc/apt/keyrings/amdgpu.gpg /tmp/amdgpu-packages.key
    chmod 0644 /etc/apt/keyrings/amdrocm.gpg /etc/apt/keyrings/amdgpu.gpg
    rm -f /tmp/amdrocm-packages.key /tmp/amdgpu-packages.key

    cat > /etc/apt/sources.list.d/amdrocm-stable.sources <<EOF
Types: deb
URIs: https://stable.repo.amd.com/rocm/core/packages/ubuntu2604/
Suites: stable
Components: main
Architectures: amd64
Signed-By: /etc/apt/keyrings/amdrocm.gpg
EOF
    cat > /etc/apt/sources.list.d/amdgpu.list <<EOF
deb [arch=amd64 signed-by=/etc/apt/keyrings/amdgpu.gpg] ${driver_url} resolute main
EOF
    cat > /etc/apt/sources.list.d/rvs.list <<EOF
deb [arch=amd64 signed-by=/etc/apt/keyrings/amdrocm.gpg] https://stable.repo.amd.com/rocm/extras/rvs/packages/ubuntu2604/ stable main
EOF
    apt update
    apt install -y amdgpu-dkms amdgpu-dkms-firmware
    check_dkms_status amdgpu
    apt install -y "$rocm_package" amdrocm10-rvs
    rocm_version=$(cat /opt/rocm/core/.info/version)
    write_component_version "AMDGPU" "$(dpkg-query -W -f='${Version}' amdgpu-dkms)"
    rvs_version=$(dpkg-query -W -f='${Version}' amdrocm10-rvs)
    write_component_version "RVS" "$rvs_version"

    # amdrocm-core-sdk ships no ld.so.conf entry, so libamdhip64 is unresolvable
    # for anything linking ROCm (e.g. Open MPI's accelerator component) without it.
    echo /opt/rocm/lib > /etc/ld.so.conf.d/rocm.conf
    ldconfig
elif [[ $DISTRIBUTION == *"ubuntu"* ]]; then
    rocm_url=$(jq -r '.url' <<< $rocm_metadata)
    rocm_sha256=$(jq -r '.sha256' <<< $rocm_metadata)
    DEBPACKAGE=$(basename ${rocm_url})
    download_and_verify ${rocm_url} ${rocm_sha256}
    apt install -y ./${DEBPACKAGE}
    if [[ $DISTRIBUTION == "ubuntu24.04" ]]; then
        # TODO: go back to bundled userspace once we move back to ROCm 7.0
        # apt update
        # apt install -y python3-setuptools python3-wheel
        # apt install -y amdgpu-dkms rocm
        # # ROCm bundles RCCL
        # write_component_version "RCCL" $(dpkg-query -W -f='${Version}' rccl)
        amdgpu-install -y --usecase=graphics
        # TODO: Revisit this explicit package list when upgrading back to ROCm 7.0.
        # Exclude MIVisionX, which pulls FFmpeg, Qt, cJSON, and mbedTLS packages
        # with publishing-blocking CVEs whose Ubuntu fixes require Pro/ESM.
        # Restore the full rocm install only after verifying its dependencies
        # pass security scanning without Ubuntu Pro; the version bump alone is not enough.
        apt-get install -y \
            rocm-utils \
            rocm-developer-tools \
            rocm-openmp-sdk \
            rocm-opencl-sdk \
            rocm-ml-sdk \
            migraphx migraphx-dev \
            rpp rpp-dev
    else
        amdgpu-install -y --usecase=graphics,rocm
    fi
    apt install -y rocm-bandwidth-test
    rm -f ./${DEBPACKAGE}
elif [[ $DISTRIBUTION == "azurelinux3.0" ]]; then
    dnf install -y azurelinux-repos-amd
    dnf -y install kernel-drivers-gpu-$(uname -r)
    dnf -y install amdgpu amdgpu-firmware amdgpu-headers

    # Add Azure Linux 3 ROCM repo file
    cat <<EOF >> /etc/yum.repos.d/amd_rocm.repo
[amd_rocm]
name="AMD ROCM packages repo for Azure Linux 3.0"
baseurl=https://repo.radeon.com/rocm/azurelinux3/${rocm_version}/main/
enabled=1
repo_gpgcheck=0
gpgcheck=0
sslverify=0
EOF

    dnf repolist --refresh
    dnf install -y rocm-dev rocm-validation-suite rocm-bandwidth-test
    dnf install -y rocm-smi-lib rocm-core rocm-device-libs rocm-llvm rocm-validation-suite
    dnf install -y rocm-bandwidth-test
fi

#Grant access to GPUs to all users via udev rules
cat <<'EOF' > /etc/udev/rules.d/99-amdgpu-permissive.rules
KERNEL=="kfd", MODE="0666"
SUBSYSTEM=="drm", KERNEL=="renderD*", MODE="0666"
EOF
udevadm control --reload-rules && sudo udevadm trigger

write_component_version "ROCM" ${rocm_version}

if [[ $DISTRIBUTION == *"ubuntu"* ]]; then
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
