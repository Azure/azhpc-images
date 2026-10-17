#!/bin/bash

function exit_on_error {
    if ! [[ -n "$HPC_DEBUG" && "$HPC_DEBUG" == "-d" ]]; then exit -1; fi
}

# check if the file is present
function check_exists {
    ls $1
    if [ $? -eq 0 ]
    then
        echo "$1 [OK]"
    else
        echo "*** ${FUNCNAME[1]} Error - $1 not found!" >&2
        exit_on_error
    fi
}

# check exit code
function check_exit_code {
    exit_code=$?
    if [ $exit_code -eq 0 ]
    then
        echo "[OK] : $1"
    else
        echo "*** ${FUNCNAME[1]}: Error - $2!" >&2
        echo "*** Failed with exit code - $exit_code" >&2
        exit_on_error
    fi
}

function ver { 
    printf "10#%03d%03d%03d" $(echo "$1" | tr '.' ' '); 
}

# Private helper that matches NCv6.
function _is_ncv6_sku {
    local ncv6_sizes="standard_nc.*_rtxpro6000bse_v6"
    [[ "${VMSIZE}" =~ ^($ncv6_sizes)$ ]]
}

# Whether the current SKU has NVLink.
function has_nvlink {
    ! _is_ncv6_sku
}

# Private helper that matches current MRC scope.
# MRC currently applies to baremetal_1p regardless of SKU.
function _is_mrc_network {
    [[ "${TARGET_NODE_TYPE:-azure_vm_regular}" == "baremetal_1p" ]]
}

# Return current network mode for this build target.
# Values:
#   - no_rdma: no RDMA-capable fabric (e.g. NCv6)
#   - mrc : MRC network mode (currently baremetal_1p)
#   - ib  : regular InfiniBand-capable path
function sku_network_mode {
    if _is_ncv6_sku; then
        echo "no_rdma"
    elif _is_mrc_network; then
        echo "mrc"
    else
        echo "standard_ib"
    fi
}

# Whether this SKU uses UCX as its MPI transport layer.
# Backward-compatible: only "no_rdma" (NCv6) disables UCX.
function sku_uses_ucx {
    ! [[ "$(sku_network_mode)" == "no_rdma" ]]
}

function sku_uses_ipoib {
    [[ "${TARGET_NODE_TYPE:-azure_vm_regular}" != "baremetal_3p" && "$(sku_network_mode)" == "standard_ib" ]]
}

# Whether the current SKU is NVSwitch-based (NDv4 A100 and NDv5 H100/H200).
# Used to gate Fabric Manager checks and bring-up, since cuInit() returns
# CUDA_ERROR_SYSTEM_NOT_READY on these SKUs until FM finishes NVLink fabric
# setup. GB200/GB300 use NVLink5 / a separate IMEX flow and are not included.
function sku_has_nvswitch {
    local nvswitch_sizes="standard_nd96.*v4|standard_nd96is.*_h[12]00_v5"
    [[ "${VMSIZE}" =~ ^($nvswitch_sizes)$ ]]
}

# verify OFED installation
function verify_ofed_installation {
    # verify OFED installation
    ofed_info | grep ${VERSION_OFED}
    check_exit_code "OFED installed" "OFED not installed"
}

# verify IB device status
function verify_ib_device_status {
    # verify IB device is listed
    lspci | grep "Infiniband controller\|Network controller"
    check_exit_code "IB device is listed" "IB device not found"

    ibstatus | grep "LinkUp"
    check_exit_code "IB devices are active and LinkUp" "IB Link is DOWN"

    if ! sku_uses_ipoib; then
        # Baremetal GB200/GB300: Verify IB devices are active and LinkUp
        ! ifconfig | grep "ib[[:digit:]]:\|ibP"
        check_exit_code "IB Links are Down" "IB Links are Brought Up unexpectedly"
    else
        ifconfig | grep "ib[[:digit:]]:\|ibP"
        check_exit_code "IB device is configured" "IB device not configured"
    fi

    #verify hostname -i returns IP address only
    hostname -i | grep -E "^([[:digit:]]{1,3}[\.]){3}[[:digit:]]{1,3}$"
    check_exit_code "Hostname -i returns IP address" "Hostname -i does not return IP address"
}

function verify_hpcx_installation {
    # verify mpi installations and their modulefiles
    module avail

    check_exists "${MODULE_FILES_ROOT}/mpi/hpcx"

    # UCX SKUs: use UCX RC transport. Non-UCX SKUs: no args needed (built with libfabric, auto-selects OFI).
    local mpi_args=""
    if sku_uses_ucx; then
        mpi_args="-x UCX_TLS=rc"
    fi
    
    module load mpi/hpcx
    if [[ "$DISTRIBUTION" == "ubuntu26.04" ]]; then
        ompi_info --version | grep -qE '^Open MPI v5\.'
        check_exit_code "HPC-X uses Open MPI 5" "HPC-X did not report Open MPI 5"

        pkg-config --atleast-version=5 pmix
        check_exit_code "HPC-X uses PMIx 5" "HPC-X did not provide PMIx 5"
    fi
    mpirun -np 2 --map-by ppr:2:node ${mpi_args} ${HPCX_OSU_DIR}/osu_latency
    check_exit_code "HPC-X" "Failed to run HPC-X"
    module unload mpi/hpcx

    check_exists "${MODULE_FILES_ROOT}/mpi/hpcx-pmix"

    module load mpi/hpcx-pmix
    mpirun -np 2 --map-by ppr:2:node ${mpi_args} ${HPCX_OSU_DIR}/osu_latency
    check_exit_code "HPC-X with PMIx" "Failed to run HPC-X with PMIx"
    module unload mpi/hpcx-pmix
    module purge
}

function verify_mvapich2_installation {
    check_exists "${MODULE_FILES_ROOT}/mpi/mvapich"

    module load mpi/mvapich
    local mvapich_omb_path=${MPI_HOME}/libexec/osu-micro-benchmarks/mpi/pt2pt
    if sku_uses_ucx; then
        # UCX transport: MV2_FORCE_HCA_TYPE=22 explicitly selects EDR
        mpiexec -np 2 -ppn 2 -env MV2_USE_SHARED_MEM=0 -env MV2_FORCE_HCA_TYPE=22 ${mvapich_omb_path}/osu_latency
    else
        mpiexec -np 2 -ppn 2 ${mvapich_omb_path}/osu_latency
    fi
    check_exit_code "MVAPICH ${VERSION_MVAPICH}" "Failed to run MVAPICH"
    module unload mpi/mvapich
}

function verify_impi_2021_installation {
    check_exists "${MODULE_FILES_ROOT}/mpi/impi-2021"

    module load mpi/impi-2021
    mpiexec -np 2 -ppn 2 -env I_MPI_SHM=0 ${MPI_BIN}/IMB-MPI1 pingpong
    check_exit_code "Intel MPI 2021 ${VERSION_IMPI}" "Failed to run Intel MPI 2021"
    module unload mpi/impi-2021
}

function verify_ompi_installation {
    check_exists "${MODULE_FILES_ROOT}/mpi/openmpi"
    check_exists "/opt/openmpi-${VERSION_OMPI}"
    check_exit_code "Open MPI ${VERSION_OMPI}" "Failed to run Open MPI"
}

function verify_nvidia_driver_installation {
    # Verify NVIDIA Driver installation
    nvidia_driver_cuda_version=$(nvidia-smi --version | tail -n 1 | awk -F':' '{print $2}' | tr -d "[:space:]")
    check_exit_code "NVIDIA Driver ${VERSION_NVIDIA}" "Failed to run NVIDIA SMI"
    
    # Verify if NVIDIA peer memory module is inserted on SKUs with IB
    # Any of the MRC bring up doesn't require nvidia_peermem
    if [[ "$(sku_network_mode)" == "standard_ib" ]]; then
        lsmod | grep nvidia_peermem
        check_exit_code "NVIDIA Peer memory module is inserted" "NVIDIA Peer memory module is not inserted!"
    fi

    if [[ "${SKU_FAMILY:-}" == "gb-family" ]]; then
        # Verify if NVIDIA driver CDMM mode is enabled
        cat /proc/driver/nvidia/params | grep -q  "CoherentGPUMemoryMode: \"driver\""
        check_exit_code "NVIDIA CDMM mode is enabled" "NVIDIA CDMM mode is not enabled!"
    fi
}

function verify_cuda_installation {
    nvidia_driver_cuda_version=$(nvidia-smi --version | tail -n 1 | awk -F':' '{print $2}' | tr -d "[:space:]")
    # Verify if CUDA is installed
    # re-enable this after testing
    # nvcc --version
    # check_exit_code "CUDA Driver ${VERSION_CUDA}" "CUDA not installed"
    check_exists "/usr/local/cuda/"
    cuda_runtime=$(echo ${VERSION_CUDA} | cut -d'.' -f1,2) 
    # Check that the CUDA runtime version isn't newer than the driver CUDA version.
    # Having a newer CUDA runtime breaks programs compiled to PTX with the cuda toolkit, such as gpu-burn
    if [[ $(ver ${cuda_runtime}) -le $(ver ${nvidia_driver_cuda_version})  ]]; then
        echo "[OK] : CUDA runtime version ${VERSION_CUDA} is compatible with the driver CUDA version ${nvidia_driver_cuda_version}"
    else
        echo "*** Error - CUDA runtime version ${VERSION_CUDA} is newer than the driver CUDA version ${nvidia_driver_cuda_version}"
        exit -1
    fi

    # Verify the compilation of CUDA samples
    if [[ -x /usr/local/cuda/samples/mergeSort ]]; then
        /usr/local/cuda/samples/mergeSort
    else
        /usr/local/cuda/samples/0_Introduction/mergeSort/mergeSort
    fi
    check_exit_code "CUDA Samples ${VERSION_CUDA}" "Failed to perform merge sort using CUDA Samples"
}

function verify_nccl_installation {
    # Print nccl.conf if it exists
    if test -f /etc/nccl.conf; then
        cat /etc/nccl.conf
    fi

    module load mpi/hpcx

    # Determine if this is a gb-family node by SKU_FAMILY (forward-compatible)
    # or by VMSIZE pattern (backward-compatible for existing Azure SKUs).
    local _is_gb_family=0
    [[ "${SKU_FAMILY:-}" == "gb-family" ]] && _is_gb_family=1

    case ${VMSIZE} in
        standard_nc24rs_v3) mpirun -np 4 \
            -x LD_LIBRARY_PATH \
            --allow-run-as-root \
            --map-by ppr:4:node \
            -mca coll_hcoll_enable 0 \
            -x UCX_TLS=tcp \
            -x CUDA_DEVICE_ORDER=PCI_BUS_ID \
            -x NCCL_SOCKET_IFNAME=eth0 \
            -x NCCL_DEBUG=WARN \
            /opt/nccl-tests/build/all_reduce_perf -b1K -f2 -g1 -e 4G
            check_exit_code "NCCL ${VERSION_NCCL}" "Failed to run NCCL all reduce perf"
            ;;
        standard_nd40rs_v2 | standard_nd96*v4 | standard_nc*ads_a100_v4) mpirun -np 8 \
            --allow-run-as-root \
            --map-by ppr:8:node \
            -x LD_LIBRARY_PATH \
            -mca coll_hcoll_enable 0 \
            -x UCX_TLS=tcp \
            -x CUDA_DEVICE_ORDER=PCI_BUS_ID \
            -x NCCL_SOCKET_IFNAME=eth0 \
            -x NCCL_DEBUG=WARN \
            -x NCCL_NET_GDR_LEVEL=5 \
            /opt/nccl-tests/build/all_reduce_perf -b1K -f2 -g1 -e 4G
            check_exit_code "NCCL ${VERSION_NCCL}" "Failed to run NCCL all reduce perf"
            ;;
        standard_nc80adis_h100_v5) mpirun -np 2 \
                --allow-run-as-root \
                --map-by ppr:2:node \
                -x LD_LIBRARY_PATH \
                -mca coll_hcoll_enable 0 \
                -x UCX_TLS=tcp \
                -x CUDA_DEVICE_ORDER=PCI_BUS_ID \
                -x NCCL_SOCKET_IFNAME=eth0 \
                -x NCCL_DEBUG=WARN \
                -x NCCL_NET_GDR_LEVEL=5 \
                /opt/nccl-tests/build/all_reduce_perf -b1K -f2 -g1 -e 4G
                check_exit_code "NCCL ${VERSION_NCCL}" "Failed to run NCCL all reduce perf"
                ;;
        standard_nd128isr_ndr_gb200_v6|standard_nd128isr_gb300_v6) _is_gb_family=1;;
        *) ;;
    esac

    if [[ "$_is_gb_family" == "1" ]]; then
        mpirun -np 4 \
            --allow-run-as-root \
            --map-by ppr:4:node \
            -x LD_LIBRARY_PATH \
            -mca coll_hcoll_enable 0 \
            -x UCX_TLS=rc \
            -x UCX_IB_GID_INDEX=0 \
            -x CUDA_DEVICE_ORDER=PCI_BUS_ID \
            -x NCCL_SOCKET_IFNAME=eth0 \
            -x NCCL_DEBUG=WARN \
            -x NCCL_NET_GDR_LEVEL=5 \
            /opt/nccl-tests/build/all_reduce_perf -b1K -f2 -g1 -e 4G
            check_exit_code "NCCL ${VERSION_NCCL}" "Failed to run NCCL all reduce perf"
    fi

    case ${VMSIZE} in
        standard_nc*_rtxpro6000bse_v6)
            local ncv6_gpu_count
            ncv6_gpu_count=$(nvidia-smi -L | grep -c "^GPU")
            mpirun -np ${ncv6_gpu_count} \
            --allow-run-as-root \
            --map-by ppr:${ncv6_gpu_count}:node \
            -x LD_LIBRARY_PATH \
            -x CUDA_DEVICE_ORDER=PCI_BUS_ID \
            -x NCCL_SOCKET_IFNAME=eth0 \
            -x NCCL_DEBUG=WARN \
            /opt/nccl-tests/build/all_reduce_perf -b1K -f2 -g1 -e 4G
            check_exit_code "NCCL ${VERSION_NCCL}" "Failed to run NCCL all reduce perf"
            ;;
        *) ;;
    esac
    
    module unload mpi/hpcx
}

function verify_rocm_installation {
    # Verify AMD GPU Driver installation
    # Verify if ROCM is installed
    check_exists "/opt/rocm/"

    local rocm_prefix=/opt/rocm
    if [[ "$DISTRIBUTION" == "ubuntu26.04" ]]; then
        rocm_prefix=/opt/rocm/core
    fi
    amd_rocm_version=$(cat "$rocm_prefix/.info/version")
    check_exit_code "AMD ROCM version ${amd_rocm_version} found" "AMD ROCM not found"

    # Verify if AMD GPU driver exists
    amd_driver_version=$(modinfo amdgpu | grep "^version" | cut -d ":" -f 2 | tr -d '[:blank:]')
    check_exit_code "AMD GPU driver ${amd_driver_version} found" "AMD GPU driver not found"
}

function verify_rccl_installation {

    module load mpi/hpcx

    amdgpumod=$(lsmod | grep "^amdgpu")
    check_exit_code "amdgpu driver is loaded" "No amdgpu driver"

    case ${VMSIZE} in
        standard_nd96isr_mi300x_v5) timeout 600 mpirun -np 8 \
            --allow-run-as-root \
            --map-by ppr:8:node \
            -x LD_LIBRARY_PATH=/opt/rccl/lib:$LD_LIBRARY_PATH \
            -x CUDA_DEVICE_ORDER=PCI_BUS_ID \
            -x NCCL_SOCKET_IFNAME=eth0 \
            -x NCCL_DEBUG=WARN \
            /opt/rccl-tests/all_reduce_perf -b1K -f2 -g1 -e 4G;;
        *) ;;
    esac
    check_exit_code "RCCL ${VERSION_RCCL}" "Failed to run RCCL all reduce perf"

    module unload mpi/hpcx
}

# Validate /etc/dnf/dnf.conf is well-formed. Build-time only (call sites
# should gate on validation_mode).
#
# Motivation: the legacy `sed -i "$ s/$/ PKG/" /etc/dnf/dnf.conf` pattern
# appended package globs onto the last line of dnf.conf (e.g.
# `skip_if_unavailable=False`), which dnf
# treats as an `Invalid configuration value` *warning* and silently
# disables the pin -- letting `dnf update` upgrade nvidia-fabricmanager
# out of sync with the driver. This check fails the build if dnf can't
# parse its own config.
function verify_dnf_conf {
    # Only RHEL-family + azurelinux use /etc/dnf/dnf.conf; Ubuntu uses apt.
    case "${ID}" in
        almalinux|rocky|rhel|azurelinux) ;;
        *) return 0 ;;
    esac

    local conf=/etc/dnf/dnf.conf
    check_exists "${conf}"

    # dnf must accept the config without `Invalid configuration value`
    # warnings. Use `-C` so we don't refresh metadata; we only care
    # whether dnf can parse the config file.
    local dnf_out
    dnf_out=$(sudo dnf -C --quiet repolist 2>&1 || true)
    if grep -qi 'invalid configuration value' <<< "${dnf_out}"; then
        echo "*** verify_dnf_conf: Error - dnf rejects ${conf}:" >&2
        grep -i 'invalid configuration' <<< "${dnf_out}" >&2
        echo "--- ${conf} ---" >&2
        cat "${conf}" >&2
        exit_on_error
        return 0
    fi

    echo "[OK] : ${conf} parses cleanly"
}

function verify_package_updates {
    case ${ID} in
        ubuntu)
            # TODO: re-enable upgrade count check after pinning
            # num_upgradable=$(sudo apt -s upgrade 2>/dev/null | grep -oP '^\K[0-9]+(?= upgraded,)')
            # [[ "$num_upgradable" -eq 0 ]]
            if [[ "${VERSION_ID}" != "22.04" ]]; then
                sudo apt -s upgrade 2> /dev/null
            fi
            true
            ;;   
        azurelinux) true;;
        *)
            sudo dnf -y makecache 
            sudo dnf check-update -y --refresh;;
    esac
    check_exit_code "No stale packages" "Stale packages found!"
}

function verify_azcopy_installation {
    sudo azcopy --version
    check_exit_code "azcopy ${VERSION_AZCOPY}" "Failed to install azcopy"
}

function verify_mkl_installation {
    check_exists "/opt/intel/oneapi/mkl/${VERSION_INTEL_ONE_MKL:0:6}/"
    check_exit_code "Intel Oneapi MKL ${VERSION_INTEL_ONE_MKL}" "Intel Oneapi MKL installation not found!"
}

function verify_hpcdiag_installation {
    local hpcdiag_path="${HPC_ENV}/diagnostics/gather_azhpc_vm_diagnostics.sh"
    check_exists $hpcdiag_path
}

# Internal/ external installation of GCC
function verify_gcc_installation {
    gcc --version
    check_exit_code "GCC is installed" "GCC doesn't exist!"
}

function verify_aocl_installation {
    # verify AMD modulefiles
    check_exists "${MODULE_FILES_ROOT}/amd/aocl"
    check_exists "/opt/amd/MT/lib/"
    check_exists "/opt/amd/MT/include/"
    check_exists "/opt/amd/ST/lib/"
    check_exists "/opt/amd/ST/include/"
    check_exists "/opt/amd/lib/"
    check_exists "/opt/amd/include/"

    readlink -f /opt/amd/lib | grep -q "^/opt/amd/MT/lib"
    check_exit_code "AOCL default library path uses MT" "AOCL default library path does not use MT"
    readlink -f /opt/amd/include | grep -q "^/opt/amd/MT/include"
    check_exit_code "AOCL default include path uses MT" "AOCL default include path does not use MT"
}

function verify_aocc_installation {
    # verify AMD compiler installation
    check_exists "/opt/amd/aocc-compiler-${VERSION_AOCC}/"
}

function verify_docker_installation {
    sudo docker pull hello-world
    sudo docker run hello-world
    check_exit_code "Docker ${VERSION_DOCKER}" "Problem with Docker!"
    sudo docker rm $(sudo docker ps -aq)
    sudo docker rmi hello-world
}

function verify_ib_modules_and_devices {
    if ! systemctl is-active openibd > /dev/null 2>&1; then
        echo "*** openibd service is not active!" >&2
        systemctl status --no-pager openibd >&2
        exit_on_error
    else
        echo "[OK] : openibd service is active"
    fi

    # Check if all key IB modules are inserted.
    # ib_ipoib is not loaded on baremetal nodes (IPoIB is not used).
    local ib_modules
    if ! sku_uses_ipoib; then
        ib_modules=("ib_uverbs" "ib_umad" "ib_cm" "ib_core")
    else
        ib_modules=("ib_uverbs" "ib_umad" "ib_ipoib" "ib_cm" "ib_core")
    fi
    for module in "${ib_modules[@]}"; do
        lsmod | grep "^${module}"
        check_exit_code "${module} module is inserted" "${module} module not inserted!"
    done

    # Check if ib devices are listed
    if ! sku_uses_ipoib; then
        ! (ip addr | grep ib)
        check_exit_code "IPoIB not present as expected" "IPoIB unexpectedly present!"
    else
        ip addr | grep ib
        check_exit_code "IPoIB is working" "IPoIB is not working!"
    fi
}

function verify_lustre_installation {
    # Verify both halves of a usable Lustre client: the userspace utilities and
    # the kernel module for the running kernel (modinfo catches a silently-failed
    # DKMS build, where the package installs but no module is built).
    command -v lctl > /dev/null 2>&1
    check_exit_code "Lustre userspace client (lctl) is present" "Lustre userspace client (lctl) not found!"

    if modinfo lustre > /dev/null 2>&1; then
        echo "[OK] : Lustre client kernel module (lustre.ko) is present"
    else
        echo "*** verify_lustre_installation: Error - no loadable Lustre client kernel module (lustre.ko) for running kernel $(uname -r); DKMS build likely failed (dkms status shows it 'added', not 'installed' for this kernel)" >&2
        exit_on_error
    fi
}

function verify_gdrcopy_installation {
    # Verify GDRCopy package installation
    gdrcopy_sanity
    check_exit_code "GDRCopy Installed" "GDRCopy not installed!"
}

function verify_pssh_installation {
    # Verify PSSH package installation
    case ${ID} in
        ubuntu) dpkg -l | grep pssh;;
        almalinux|rocky|rhel) dnf list installed | grep pssh;;
        azurelinux) sudo dnf list installed | grep pssh;;
        * ) ;;
    esac
    check_exit_code "PSSH Installed" "PSSH not installed!"
}

function verify_aznfs_installation {
    # verify AZNFS Mount Helper installation
    check_exists "/opt/microsoft/aznfs/"
}

function verify_dcgm_installation {
    # Verify DCGM package installation
    case ${ID} in
        ubuntu) dpkg -l | grep datacenter-gpu-manager;;
        almalinux|rocky|rhel) dnf list installed | grep datacenter-gpu-manager;;
        azurelinux) sudo dnf list installed | grep datacenter-gpu-manager;;
        * ) ;;
    esac
    check_exit_code "DCGM Installed" "DCGM not installed!"

    # Check if the NVIDIA DCGM service is active
    systemctl is-active --quiet nvidia-dcgm
    check_exit_code "NVIDIA DCGM service is active" "NVIDIA DCGM service is inactive/dead!"

    if [[ -n "$(_dcgm_multinode_packages)" ]]; then
        verify_dcgm_multinode_installation
    fi
}

# Print the installed DCGM multinode packages, one per line.
function _dcgm_multinode_packages {
    if command -v dpkg-query &>/dev/null; then
        dpkg-query -W -f='${Package} ${db:Status-Status}\n' 'datacenter-gpu-manager-4-multinode*' 2>/dev/null \
            | awk '$2 == "installed" {print $1}'
    else
        rpm -qa --qf '%{NAME}\n' 'datacenter-gpu-manager-4-multinode*' 2>/dev/null
    fi
}

function _package_files {
    if command -v dpkg-query &>/dev/null; then dpkg-query -L "$1"; else rpm -ql "$1"; fi
}

function _package_verify {
    if command -v dpkg-query &>/dev/null; then dpkg -V "$@" 2>&1; else rpm -V "$@" 2>&1; fi
}

# Per-node checks that DCGM multinode diagnostics (dcgmi mndiag) can launch their MPI workload.
# Running mndiag itself needs multiple GB200/GB300 nodes and is left to the validation pipeline.
# Package contents are discovered from the package file lists rather than hardcoded, because
# NVIDIA has moved and added files between DCGM releases (e.g. libdcgmmodulemndiag in 4.7).
function verify_dcgm_multinode_installation {
    local dropin=/etc/systemd/system/nvidia-dcgm.service.d/99-mndiag-hpcx.conf
    local packages pkg cuda_major verify_output service_env generator key expected effective file
    local mpirun_path mpi_ld_library_path opal_prefix main_pid mpi_prefix mpi_libs shadowed driver_cuda_elf_count=0
    packages=$(_dcgm_multinode_packages)

    # --hostList was introduced with mndiag in DCGM 4.3
    dcgmi mndiag --help | grep -q -- '--hostList'
    check_exit_code "dcgmi mndiag is available" "dcgmi mndiag does not list --hostList"

    cuda_major=$(nvidia-smi | grep -oP 'CUDA Version:\s*\K[0-9]+')
    grep -qx "datacenter-gpu-manager-4-multinode-cuda${cuda_major}" <<< "${packages}"
    check_exit_code "DCGM multinode package for CUDA ${cuda_major} is installed" "datacenter-gpu-manager-4-multinode-cuda${cuda_major} is not installed"

    # Doc/man paths may be excluded from installation by the package manager configuration
    verify_output=$(_package_verify ${packages} | grep -v ' /usr/share/\(doc\|man\)/')
    echo "${verify_output}"
    [[ -z "${verify_output}" ]]
    check_exit_code "DCGM multinode package files are intact" "DCGM multinode package files are missing or modified"

    # Every variable the package's systemd generator sets must be overridden by the image drop-in,
    # and the drop-in must win. A newer generator adding a variable or sorting later fails here.
    check_exists "${dropin}"
    service_env=$(systemctl show nvidia-dcgm.service -p Environment --value | tr ' ' '\n')
    generator=$(for pkg in ${packages}; do _package_files "${pkg}"; done | grep -m1 '/system-generators/')
    for key in $( { [[ -n "${generator}" ]] && grep -oP 'Environment="?\K[A-Za-z_][A-Za-z0-9_]*(?==)' "${generator}"
                    grep -oP '^Environment="?\K[A-Za-z_][A-Za-z0-9_]*(?==)' "${dropin}"; } | sort -u); do
        expected=$(sed -n "s/^Environment=\"\{0,1\}${key}=\([^\"]*\)\"\{0,1\}$/\1/p" "${dropin}" | tail -n1)
        effective=$(sed -n "s/^${key}=//p" <<< "${service_env}" | tail -n1)
        grep -q "^Environment=\"\{0,1\}${key}=" "${dropin}" && [[ "${effective}" == "${expected}" ]]
        check_exit_code "nvidia-dcgm ${key} is set by ${dropin}" "nvidia-dcgm ${key}='${effective}' is not the value from ${dropin}${generator:+ (also set by ${generator})}"
    done

    mpirun_path=$(sed -n 's/^DCGM_MNDIAG_MPIRUN_PATH=//p' <<< "${service_env}" | tail -n1)
    mpi_ld_library_path=$(sed -n 's/^LD_LIBRARY_PATH=//p' <<< "${service_env}" | tail -n1)
    opal_prefix=$(sed -n 's/^OPAL_PREFIX=//p' <<< "${service_env}" | tail -n1)

    [[ -n "${mpirun_path}" && -x "${mpirun_path}" ]]
    check_exit_code "DCGM mndiag mpirun ${mpirun_path} is executable" "DCGM mndiag mpirun '${mpirun_path}' is not executable"

    env LD_LIBRARY_PATH="${mpi_ld_library_path}" ${opal_prefix:+OPAL_PREFIX="${opal_prefix}"} "${mpirun_path}" --version
    check_exit_code "DCGM mndiag mpirun runs" "DCGM mndiag mpirun '${mpirun_path}' --version failed"

    # mpirun and its local ranks inherit nv-hostengine's limits; UCX needs unlimited locked memory.
    # Check the running process rather than the unit so a missed restart is also caught.
    main_pid=$(systemctl show nvidia-dcgm.service -p MainPID --value)
    grep -E '^Max locked memory +unlimited +unlimited' "/proc/${main_pid}/limits"
    check_exit_code "nv-hostengine max locked memory is unlimited" "nv-hostengine (pid ${main_pid}) max locked memory is not unlimited; mndiag ranks it launches cannot register UCX memory"

    # Every ELF file the multinode packages ship (mndiag module, mnubergemm, ...) must resolve
    # its libraries, including libmpi, in the environment nv-hostengine runs them with.
    mpi_prefix=${opal_prefix:-$(dirname "$(dirname "${mpirun_path}")")}
    mpi_libs=$(_mpi_runtime_libraries "${mpi_prefix}" "${mpi_ld_library_path}")
    for pkg in ${packages}; do
        while IFS= read -r file; do
            [[ -f "${file}" && ! -L "${file}" ]] || continue
            [[ "$(head -c 4 "${file}" | od -An -tx1 | tr -d ' \n')" == "7f454c46" ]] || continue
            [[ "${pkg}" == "datacenter-gpu-manager-4-multinode-cuda${cuda_major}" ]] && driver_cuda_elf_count=$((driver_cuda_elf_count + 1))
            ! LD_LIBRARY_PATH="${mpi_ld_library_path}" ldd "${file}" | grep 'not found'
            check_exit_code "${file} libraries resolve" "${file} has unresolved libraries"

            # Only executables become MPI ranks; shared objects here are loaded by nv-hostengine.
            readelf -l "${file}" | grep -q 'program interpreter' || continue
            shadowed=$(_rpath_shadowed_libraries "${file}" "${mpi_libs}")
            echo "${shadowed}"
            [[ -z "${shadowed}" ]]
            check_exit_code "${file} RPATH does not shadow MPI libraries" "${file} DT_RPATH loads a different copy of MPI runtime libraries into mndiag ranks"
        done < <(_package_files "${pkg}")
    done
    (( driver_cuda_elf_count > 0 ))
    check_exit_code "DCGM multinode CUDA ${cuda_major} package ships binaries" "datacenter-gpu-manager-4-multinode-cuda${cuda_major} ships no ELF binaries"
}

# Print the real paths of the libraries an MPI installation loads at runtime: its own libraries
# and MCA plugins, plus everything they resolve to with the given LD_LIBRARY_PATH.
function _mpi_runtime_libraries {
    local mpi_prefix=$1 mpi_ld_library_path=$2
    find "${mpi_prefix}/lib" -maxdepth 2 -name '*.so*' -type f \
        | while IFS= read -r lib; do
            echo "${lib}"
            LD_LIBRARY_PATH="${mpi_ld_library_path}" ldd "${lib}" 2>/dev/null | awk '$2 == "=>" && $3 ~ /^\// {print $3}'
        done | xargs -r realpath | sort -u
}

# An executable with DT_RPATH and no DT_RUNPATH searches its RPATH directories before
# LD_LIBRARY_PATH for every library loaded into the process, including dependencies of
# MPI plugins dlopen'd during MPI_Init. Print "<rpath copy> (MPI uses <path>)" for each
# MPI runtime library that such a directory holds a different copy of, e.g. the distro
# libpmix in /usr/lib64 shadowing HPC-X's under DCGM 4.6 RPMs' mnubergemm.
function _rpath_shadowed_libraries {
    local file=$1 mpi_libs=$2 dynamic rpath dir lib candidate
    dynamic=$(readelf -d "${file}")
    grep -q '(RUNPATH)' <<< "${dynamic}" && return
    rpath=$(sed -n 's/.*(RPATH).*\[\(.*\)\]$/\1/p' <<< "${dynamic}")
    for dir in ${rpath//:/ }; do
        dir=${dir//\$\{ORIGIN\}/$(dirname "${file}")}
        dir=${dir//\$ORIGIN/$(dirname "${file}")}
        while IFS= read -r lib; do
            candidate="${dir}/$(basename "${lib}")"
            if [[ -e "${candidate}" && "$(realpath "${candidate}")" != "${lib}" ]]; then
                echo "${candidate} (MPI uses ${lib})"
            fi
        done <<< "${mpi_libs}"
    done
}

function verify_sku_customization_service {
    # Check if the SKU customization service is active
    # Note: bash =~ is ERE, so use regex instead of glob patterns for matching
    local valid_sizes="standard_nc.*ads_a100_v4|standard_nd96.*v4|standard_nd40rs_v2|standard_hb176.*v4|standard_nd96is.*_h[12]00_v5|standard_nd128is.*_gb[2-3]00_v6|standard_nc.*_rtxpro6000bse_v6"
    if [[ "${VMSIZE}" =~ ^($valid_sizes)$ ]]
    then
        systemctl is-active --quiet sku-customizations
        check_exit_code "SKU Customization is active" "SKU Customization is inactive/dead!"
    fi
}

function verify_nvidia_fabricmanager_service {
    # Check if the NVIDIA Fabricmanager service is active
    if sku_has_nvswitch
    then
        systemctl is-active --quiet nvidia-fabricmanager
        check_exit_code "NVIDIA Fabricmanager is active" "NVIDIA Fabricmanager is inactive/dead!"
    fi
}

function verify_sunrpc_tcp_settings_service {
    # Check if the sunrpc TCP settings service is active
    systemctl is-active --quiet sunrpc_tcp_settings
    check_exit_code "sunrpc TCP settings service is active" "sunrpc TCP settings service is inactive/dead!"
}

function verify_azure_persistent_rdma_naming_service {
    systemctl is-enabled --quiet azure_persistent_rdma_naming.service
    check_exit_code "Azure persistent RDMA naming service is enabled" "Azure persistent RDMA naming service is not enabled!"

    systemctl is-active --quiet azure_persistent_rdma_naming.timer
    check_exit_code "Azure persistent RDMA naming timer is active" "Azure persistent RDMA naming timer is inactive/dead!"
}

function verify_nvbandwidth_setup {
    # Verify nvbandwidth setup
    # Nvbandwith is compiled in mulitple node, so we need to load mpi/hpcx module to run it
    # See https://github.com/NVIDIA/nvbandwidth#multinode-benchmarks
    module load mpi/hpcx
    /opt/nvidia/nvbandwidth/nvbandwidth
    check_exit_code "NV Bandwidth Installed!" "Issue with NV Bandwidth installation!"
    module unload mpi/hpcx
}

function verify_nvloom_setup {
    # Verify nvloom setup
    module load mpi/hpcx
    gpu_num=$(nvidia-smi -L | wc -l) 
    mpirun -np $gpu_num /opt/nvidia/nvloom/nvloom_cli -s gpu-to-rack
    check_exit_code "NV Loom Installed!" "Issue with NV Loom installation!"
    module unload mpi/hpcx
}

function verify_nvlink_setup {
    # Skip NVLink checks on SKUs without NVLink
    if ! has_nvlink; then return; fi

    # Verify nvlink setup
    nvidia-smi nvlink --status
    check_exit_code "NVLINK Reports Healthy" "Unhealthy NVLINK setup!"

    if [[ "${SKU_FAMILY:-}" == "gb-family" ]]; then
        nvidia_smi_output=$(nvidia-smi -q | grep 'Fabric' -A 4)
        echo "$nvidia_smi_output"

        # Validate each GPU's Fabric block: State=Completed, Status=Success,
        # non-zero CliqueId, and valid (non-zero) ClusterUUID.
        # Previously only checked for literal "N/A", which missed failure modes
        # like "Status : Insufficient Resources" with CliqueId 0.
        if [[ -z "$nvidia_smi_output" ]]; then
            echo "*** Error - Failed to retrieve Fabric information or no Fabric data found"
            exit -1
        fi

        local fabric_errors=0
        local gpu_idx=0

        while IFS= read -r -d '' block; do
            local state status clique_id cluster_uuid
            state=$(echo "$block" | grep 'State' | awk -F: '{gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}')
            status=$(echo "$block" | grep 'Status' | awk -F: '{gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}')
            clique_id=$(echo "$block" | grep 'CliqueId' | awk -F: '{gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}')
            cluster_uuid=$(echo "$block" | grep 'ClusterUUID' | awk -F: '{gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}')

            if [[ "$state" != "Completed" ]]; then
                echo "*** Error - GPU $gpu_idx: Fabric State='$state' (expected 'Completed')"
                ((fabric_errors++)) || true
            fi
            if [[ "$status" != "Success" ]]; then
                echo "*** Error - GPU $gpu_idx: Fabric Status='$status' (expected 'Success')"
                ((fabric_errors++)) || true
            fi
            if [[ "$clique_id" == "0" ]] || [[ -z "$clique_id" ]]; then
                echo "*** Error - GPU $gpu_idx: Fabric CliqueId='$clique_id' (expected non-zero)"
                ((fabric_errors++)) || true
            fi
            if [[ -z "$cluster_uuid" ]] || [[ "$cluster_uuid" == "00000000-0000-0000-0000-000000000000" ]]; then
                echo "*** Error - GPU $gpu_idx: Fabric ClusterUUID='$cluster_uuid' (expected valid non-zero UUID)"
                ((fabric_errors++)) || true
            fi
            ((gpu_idx++)) || true
        done < <(echo "$nvidia_smi_output" | awk '/^[[:space:]]*Fabric[[:space:]]*$/{found=1; block=""; next} found{block=block $0 "\n"; if(/ClusterUUID/){printf "%s\0", block; found=0; block=""}}')

        if [[ "$gpu_idx" -eq 0 ]]; then
            echo "*** Error - No Fabric blocks parsed from nvidia-smi output"
            exit -1
        fi

        if [[ "$fabric_errors" -gt 0 ]]; then
            echo "*** Error - Unhealthy NVLINK Fabric setup!! ($fabric_errors issues found)"
            exit -1
        else
            echo "[OK] : NVLINK Fabric setup is healthy (all GPUs: State=Completed, Status=Success)"
        fi
    fi
}

function verify_nvidia_imex_service {
    check_exists /usr/lib/systemd/system/nvidia-imex.service
    # Check if nvidia caps imex channel exists
    ls -al /dev/nvidia-caps-imex-channels/channel0
    check_exit_code "NVIDIA Caps Imex channel exists" "NVIDIA Caps Imex channel does not exist!"
}

function verify_nvidia_persistenced_service {
    # nvidia-persistenced attaches to /dev/nvidia* at startup; only meaningful
    # to verify on a VM that actually has an NVIDIA GPU attached.
    if ! command -v nvidia-smi >/dev/null 2>&1 || ! nvidia-smi -L >/dev/null 2>&1; then
        echo "[SKIP] : no NVIDIA GPU detected; skipping nvidia-persistenced service check"
        return
    fi
    systemctl is-active --quiet nvidia-persistenced.service
    check_exit_code "NVIDIA persistence daemon is active" "NVIDIA persistence daemon is inactive/dead!"
}

function verify_mpifileutils_installation {
    # Verify mpifileutils binaries exist
    check_exists "/opt/mpifileutils/bin/dbcast"
    check_exists "/opt/mpifileutils/bin/dcp"
    check_exists "/opt/mpifileutils/bin/dsync"
    # Verify it runs (requires MPI libraries)
    module load mpi/hpcx
    /opt/mpifileutils/bin/dbcast --help > /dev/null 2>&1
    check_exit_code "mpifileutils ${VERSION_MPIFILEUTILS}" "mpifileutils not working!"
    module unload mpi/hpcx
}