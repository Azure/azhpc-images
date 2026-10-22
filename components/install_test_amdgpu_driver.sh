#!/bin/bash
#
# Temporary-branch fix-up script (run through packer's extra_provision_script on
# an Azure Linux 3 MI300X in-place refresh build) that swaps in a pre-release
# Azure Linux amdgpu out-of-tree driver drop, plus the exact kernel and kernel
# module packages it was built against, so ROCm can be smoke-tested before
# Azure Linux publishes the driver to PMC.
#
# The driver drop (e.g. the "drop_amd64" artifact of the LSG-linux
# oot-driver-build pipeline) is staged under <repo>/prebuilt by the
# "(Azure Linux AMD) download pre-release driver drop" packer step.
#
# The post-reboot check (check_amdgpu_driver_update in tests/) reads the
# expectations written to ${EXPECTED_FILE}.
set -euo pipefail

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
RPM_ROOT=${AMDGPU_TEST_RPM_ROOT:-${REPO_DIR}/prebuilt}
EXPECTED_FILE=/opt/azurehpc/amdgpu_driver_test.env

log() { echo "##[section]$*"; }
die() { echo "##[error]$*" >&2; exit 1; }

# Print the single RPM under RPM_ROOT matching a filename glob (source RPMs and
# debuginfo packages are ignored).
find_rpm() {
    local pattern=$1 matches
    mapfile -t matches < <(find "${RPM_ROOT}" -type f -name "${pattern}" \
        ! -name '*.src.rpm' ! -name '*-debuginfo-*' | sort)
    if [[ ${#matches[@]} -ne 1 ]]; then
        echo "expected exactly one RPM matching '${pattern}' under ${RPM_ROOT}, found ${#matches[@]}: ${matches[*]:-}" >&2
        return 1
    fi
    echo "${matches[0]}"
}

rpm_nevra() { rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}' "$1"; }

[[ -d "${RPM_ROOT}" ]] || die "Driver drop not found at ${RPM_ROOT}. Set internal_bits_container_name/internal_bits_blob_name to the uploaded drop."

log "Pre-release driver drop contents (${RPM_ROOT})"
find "${RPM_ROOT}" -type f -name '*.rpm' ! -name '*.src.rpm' | sort

amdgpu_rpm=$(find_rpm 'amdgpu-[0-9]*.x86_64.rpm')
amdgpu_fw_rpm=$(find_rpm 'amdgpu-firmware-*.noarch.rpm')
amdgpu_hdr_rpm=$(find_rpm 'amdgpu-headers-*.noarch.rpm')

# The amdgpu kmod pins the exact kernel it was built for.
target_kernel=$(rpm -qp --requires "${amdgpu_rpm}" | awk '$1 == "kernel" && $2 == "=" {print $3}')
[[ -n "${target_kernel}" ]] || die "Could not determine the target kernel from ${amdgpu_rpm} requirements"
running_kernel=$(uname -r)
# Azure Linux kmod releases embed the kernel as e.g. "_6.6.159.1.1.azl3".
target_kmod_tag=${target_kernel//-/.}
running_kmod_tag=${running_kernel//-/.}

log "Before: kernel ${running_kernel}"
rpm -qa 'kernel*' 'amdgpu*' 'mlnx-ofa_kernel*' | sort
modinfo -F version amdgpu 2>/dev/null || true
echo "Target kernel: ${target_kernel}"

specs=("${amdgpu_rpm}" "${amdgpu_fw_rpm}" "${amdgpu_hdr_rpm}")
expected_nevras=("$(rpm_nevra "${amdgpu_rpm}")" "$(rpm_nevra "${amdgpu_fw_rpm}")" "$(rpm_nevra "${amdgpu_hdr_rpm}")")
handled_names=(amdgpu amdgpu-firmware amdgpu-headers)

# Prefer the published (PMC) build of a dependency; fall back to the copy in the drop.
add_dependency() {
    local name=$1 vr=$2 local_rpm
    handled_names+=("${name}")
    if [[ -n "$(dnf -q repoquery "${name}-${vr}" 2>/dev/null)" ]]; then
        specs+=("${name}-${vr}")
        expected_nevras+=("${name}-${vr}")
    elif local_rpm=$(find_rpm "${name}-${vr}.*.rpm" 2>/dev/null); then
        specs+=("${local_rpm}")
        expected_nevras+=("$(rpm_nevra "${local_rpm}")")
    else
        die "${name}-${vr} is neither in the enabled repos nor in the driver drop"
    fi
}

# Exact-version dependencies of the driver (kernel, kernel-drivers-gpu,
# mlnx-ofa_kernel, mlnx-ofa_kernel-modules, ...).
while read -r name op vr; do
    [[ "${op}" == "=" && "${name}" != amdgpu* ]] || continue
    add_dependency "${name}" "${vr}"
done < <(rpm -qp --requires "${amdgpu_rpm}")

for name in kernel-devel kernel-headers; do
    add_dependency "${name}" "${target_kernel}"
done

# Keep the drop's mlnx-ofa_kernel sub-packages consistent with the required version.
mlnx_vr=$(rpm -qp --requires "${amdgpu_rpm}" | awk '$1 == "mlnx-ofa_kernel" && $2 == "=" {print $3}')
if [[ -n "${mlnx_vr}" ]]; then
    for name in mlnx-ofa_kernel-devel mlnx-ofa_kernel-source; do
        if rpm -q "${name}" &>/dev/null; then
            add_dependency "${name}" "${mlnx_vr}"
        fi
    done
fi

# Move every other installed kmod built for the running kernel (iser, srp,
# xpmem-modules, ...) to its build for the target kernel, if one is published.
if [[ "${running_kmod_tag}" != "${target_kmod_tag}" ]]; then
    while read -r name; do
        [[ " ${handled_names[*]} " == *" ${name} "* ]] && continue
        candidate=$(dnf -q repoquery --qf '%{name}-%{version}-%{release}.%{arch}' "${name}" 2>/dev/null \
            | grep -F "_${target_kmod_tag}." | sort -V | tail -n1 || true)
        if [[ -n "${candidate}" ]]; then
            specs+=("${candidate}")
            expected_nevras+=("${candidate}")
        else
            echo "##[warning]No ${name} build for kernel ${target_kernel} in the enabled repos; it may be removed or stay on ${running_kernel}"
        fi
    done < <(rpm -qa --qf '%{NAME} %{RELEASE}\n' | awk -v tag="_${running_kmod_tag}" 'index($2, tag) {print $1}' | sort -u)
fi

if rpm -q kernel-drivers-intree-amdgpu &>/dev/null; then
    echo "##[warning]kernel-drivers-intree-amdgpu is installed and owns the same module paths as the amdgpu kmod"
fi

log "Installing pre-release amdgpu driver and kernel ${target_kernel}"
printf '  %s\n' "${specs[@]}"
dnf -y --allowerasing install "${specs[@]}"

for nevra in "${expected_nevras[@]}"; do
    rpm -q "${nevra}" >/dev/null || die "${nevra} is not installed after the transaction"
done

amdgpu_pkg=$(rpm_nevra "${amdgpu_rpm}")
amdgpu_ko=$(rpm -ql "${amdgpu_pkg}" | grep -E "/modules/${target_kernel}/.*/amdgpu\.ko(\.xz|\.zst)?$" | head -n1 || true)
[[ -n "${amdgpu_ko}" ]] || die "amdgpu.ko for ${target_kernel} not found in ${amdgpu_pkg}"
amdgpu_srcversion=$(modinfo -F srcversion "${amdgpu_ko}")
depmod -a "${target_kernel}"
resolved_ko=$(modinfo -k "${target_kernel}" -n amdgpu)
[[ "$(realpath "${resolved_ko}")" == "$(realpath "${amdgpu_ko}")" ]] \
    || die "amdgpu resolves to ${resolved_ko} instead of ${amdgpu_ko} for kernel ${target_kernel}"

# Boot the target kernel: drop any newer non-running kernel so it sorts first,
# then rebuild the initramfs and grub config.
while true; do
    newest=$(rpm -q kernel --qf '%{VERSION}-%{RELEASE}\n' | sort -V | tail -n1)
    [[ "${newest}" == "${target_kernel}" ]] && break
    [[ "${newest}" == "${running_kernel}" ]] \
        && die "Running kernel ${running_kernel} is newer than ${target_kernel}; rerun with skip_prerequisites=true"
    log "Removing newer kernel ${newest} so ${target_kernel} boots by default"
    dnf -y remove "kernel-${newest}"
done

dracut -f --kver "${target_kernel}"
# Unsigned (dev) driver builds cannot load under lockdown=integrity; relax it for this test VM only.
if [[ -z "$(modinfo -F sig_id "${amdgpu_ko}")" ]] && grep -q 'lockdown=integrity' /etc/default/grub; then
    echo "##[warning]${amdgpu_pkg} modules are unsigned; removing lockdown=integrity from the kernel command line for this test"
    sed -i 's/lockdown=integrity *//' /etc/default/grub
fi
grub2-mkconfig -o /boot/grub2/grub.cfg
if grep -q '^GRUB_DEFAULT=saved' /etc/default/grub 2>/dev/null; then
    grub2-set-default 0
fi
first_linux=$(grep -m1 -E '^\s*linux(efi)?\s' /boot/grub2/grub.cfg || true)
if [[ -z "${first_linux}" ]]; then
    echo "##[warning]No linux entries in /boot/grub2/grub.cfg to verify; the post-reboot test checks the booted kernel"
elif [[ "${first_linux}" != *"vmlinuz-${target_kernel}"* ]]; then
    die "Default grub entry does not boot ${target_kernel}: ${first_linux}"
fi

mkdir -p "$(dirname "${EXPECTED_FILE}")"
# RVS needs librocrand via hiprand, but AMD's Azure Linux 3 hiprand package does not declare the dependency.
if rpm -q rocm-validation-suite &>/dev/null && ! rpm -q rocrand &>/dev/null; then
    dnf -y install rocrand
fi

cat > "${EXPECTED_FILE}" <<EOF
AMDGPU_TEST_KERNEL=${target_kernel}
AMDGPU_TEST_PKG=${amdgpu_pkg}
AMDGPU_TEST_FIRMWARE_PKG=$(rpm_nevra "${amdgpu_fw_rpm}")
AMDGPU_TEST_KO=${amdgpu_ko}
AMDGPU_TEST_SRCVERSION=${amdgpu_srcversion}
EOF
chmod 644 "${EXPECTED_FILE}"

log "After: kernel packages and drivers staged for next boot"
rpm -qa 'kernel*' 'amdgpu*' 'mlnx-ofa_kernel*' | sort
cat "${EXPECTED_FILE}"
