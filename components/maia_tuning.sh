#!/bin/bash
#
# MAIA200 VM configuration.
#
# Extracted verbatim from distros/ubuntu24.04/install.sh, where this ran as a
# 350-line inline "if [[ $GPU == MAIA ]]" branch.  The branch ended in exit 0,
# so every step below that point in install.sh was skipped for MAIA.  That is
# how disable_auto_upgrade.sh was missed and image 2608.04.19 shipped with
# automatic upgrades still armed.  Splitting the platform work into a component
# follows the pattern already used by baremetal/distros/ubuntu24.04/install.sh,
# which is a thin orchestrator over baremetal/components/*.sh.
#
# Behaviour is unchanged by the extraction.  set -ex matches the caller, since
# -e is not inherited across an exec'd script, and a non-zero exit here aborts
# install.sh in turn.
#
# Ordering note: the guest stack is installed later, by install_dependencies.sh
# in hpc-image-val, not here.

set -ex

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Inherited from install.sh; the fallback keeps the script runnable standalone.
export COMPONENT_DIR="${COMPONENT_DIR:-$SCRIPT_DIR}"
echo "##[section]Applying MAIA200 VM configurations"

sudo DEBIAN_FRONTEND=noninteractive apt-get install -y unzip zip

# 1. GRUB: DMA memory reservation for MAIA accelerator
echo "##[section]Configuring GRUB memmap for MAIA200"
sudo mkdir -p /etc/default/grub.d
# Three layers of escaping are required:
# 1. Single quotes here → file gets: memmap=256G\\\$90G  (literal backslashes + dollar)
# 2. bash sources the file → \\\$90G in double-quotes → \$90G  (backslash + literal $)
# 3. GRUB shell parses grub.cfg  → \$90G → $90G  (literal $ passed to kernel)
# Without this, GRUB expands $90G as an empty variable → kernel sees 256GG (wrong).
echo 'GRUB_CMDLINE_LINUX="$GRUB_CMDLINE_LINUX memmap=256G\\\$90G"' | sudo tee /etc/default/grub.d/90-maia.cfg
sudo update-grub

# 2. Disable automatic upgrades (drivers are kernel-version-specific)
#
# The generic distros/ubuntu24.04/disable_auto_upgrade.sh never runs for
# MAIA: the MAIA branch exits 0 further down, before that call.  Do the work
# here instead.
#
# Disabling unattended-upgrades.service alone is NOT enough, which is how
# image 2608.04.19 shipped with automatic upgrades still armed.  The daily
# work is driven by apt-daily.timer and apt-daily-upgrade.timer, which call
# /usr/lib/apt/apt.systemd.daily, and that runs the unattended-upgrade
# BINARY directly.  It never consults the service unit, so the service can
# be disabled while upgrades still happen.  Mask the timers as well.
echo "##[section]Disabling unattended upgrades for MAIA"

# Units that MUST be off.  These can install or upgrade packages.
MAIA_CRITICAL_UNITS="apt-daily.timer apt-daily-upgrade.timer \
apt-daily.service apt-daily-upgrade.service unattended-upgrades.service"

# Best-effort.  These fetch package or firmware metadata, refresh snaps, run
# Ubuntu Pro background jobs, or can apply remote changes.  None is required
# by a MAIA node: no build script in this repo installs or uses a snap, and
# the GB200 Fairwater tuning script already masks the fwupd units for the
# same reason.  Missing units are skipped, since the set varies by base image.
MAIA_OPTIONAL_UNITS="update-notifier-download.timer update-notifier-download.service \
update-notifier-motd.timer update-notifier-motd.service \
ua-timer.timer ua-timer.service apt-news.service esm-cache.service \
snapd.snap-repair.timer snapd.snap-repair.service \
snapd.service snapd.socket snapd.seeded.service \
fwupd-refresh.timer fwupd-refresh.service fwupd.service \
motd-news.timer motd-news.service packagekit.service"

for unit in $MAIA_CRITICAL_UNITS $MAIA_OPTIONAL_UNITS; do
    sudo systemctl mask --now "$unit" 2>/dev/null || true
done

# Write this file rather than sed it.  The previous approach used
# sed -i 's/APT::Periodic::Unattended-Upgrade ".*/...0";/', which silently
# changes nothing when the pattern is absent and reports success either way.
sudo tee /etc/apt/apt.conf.d/20auto-upgrades >/dev/null <<'APTEOF'
APT::Periodic::Update-Package-Lists "0";
APT::Periodic::Download-Upgradeable-Packages "0";
APT::Periodic::Unattended-Upgrade "0";
APT::Periodic::AutocleanInterval "0";
APTEOF

sudo apt-mark hold linux-image-generic linux-headers-generic linux-generic 2>/dev/null || true

# Verify, rather than assume.  This is the check that would have caught the
# 2608.04.19 regression at build time instead of on a running node.
maia_auto_upgrade_state_ok=1
for key in Update-Package-Lists Unattended-Upgrade; do
    if ! grep -q "APT::Periodic::${key} \"0\";" /etc/apt/apt.conf.d/20auto-upgrades; then
        echo "##[error]APT::Periodic::${key} is not 0 in /etc/apt/apt.conf.d/20auto-upgrades"
        maia_auto_upgrade_state_ok=0
    fi
done
for unit in $MAIA_CRITICAL_UNITS; do
    if [ "$(systemctl is-enabled "$unit" 2>&1)" != "masked" ]; then
        echo "##[error]$unit is $(systemctl is-enabled "$unit" 2>&1), expected masked"
        maia_auto_upgrade_state_ok=0
    fi
done
if [ "$maia_auto_upgrade_state_ok" -ne 1 ]; then
    echo "##[error]Automatic upgrades are still armed; a node built from this image could upgrade packages under a pinned kernel"
    exit 1
fi

# Warn only.  A unit absent from the base image is fine, one present and
# still active is worth seeing in the build log.
for unit in $MAIA_OPTIONAL_UNITS; do
    state=$(systemctl is-enabled "$unit" 2>/dev/null || true)
    if [ -n "$state" ] && [ "$state" != "masked" ]; then
        echo "##[warning]$unit is $state, expected masked"
    fi
done
echo "Automatic upgrades disabled: units masked, APT::Periodic keys set to 0"

# 2b. Align kernel headers with the running kernel.
#
# Image 2608.04.19 shipped linux-headers-azure and
# linux-headers-6.17.0-1021-azure while running 6.11.0-1018-azure, with only
# /boot/vmlinuz-6.11.0-1018-azure present.  Headers from a kernel series that
# is not installed serve no purpose here and give any out-of-tree build a
# chance to pick the wrong /usr/src tree.  The metapackage is unversioned and
# tracks the newest series, so it is held to stop it pulling the mismatch
# back in during later stages.
echo "##[section]Aligning kernel headers with the running kernel"
MAIA_KERNEL="$(uname -r)"
echo "Running kernel: $MAIA_KERNEL"

if ! dpkg-query -W -f='${Status}' "linux-headers-$MAIA_KERNEL" 2>/dev/null | grep -qE ' installed$'; then
    echo "##[section]Installing linux-headers-$MAIA_KERNEL"
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "linux-headers-$MAIA_KERNEL"
fi

# dpkg-query -W lists every package name it knows, whatever its state, so the
# output includes packages already removed but still holding config files and
# packages registered only by an apt-mark hold.  Build 36498 warned that
# linux-headers-6.17.0-1022-azure was still present seconds after apt had
# reported removing it, for that reason alone.  Filter on install status so
# both the removal list and the check below see only installed packages.
#
# dpkg Status is "<desired> <error> <current>" and only the current field says
# whether the files are on disk.  Match on that field alone: a held package
# reads "hold ok installed", so testing the desired field as well would hide
# every package this script itself holds a few lines further down.
maia_installed_headers() {
    dpkg-query -W -f='${Status} ${Package}\n' 'linux-headers-*azure' 2>/dev/null \
        | awk '$3 == "installed" { print $4 }'
}

mismatched_headers=$(maia_installed_headers | grep -v "^linux-headers-$MAIA_KERNEL$" || true)
if [ -n "$mismatched_headers" ]; then
    echo "Removing headers that do not match $MAIA_KERNEL:"
    echo "$mismatched_headers"
    # shellcheck disable=SC2086
    sudo DEBIAN_FRONTEND=noninteractive apt-get remove -y $mismatched_headers || \
        echo "##[warning]Could not remove one or more mismatched header packages"
fi

# Hold the unversioned metapackages so a later apt run cannot reintroduce a
# newer series.  apt-mark hold applies to packages that are not installed.
sudo apt-mark hold linux-headers-azure linux-image-azure "linux-headers-$MAIA_KERNEL" 2>/dev/null || true

remaining=$(maia_installed_headers | grep -v "^linux-headers-$MAIA_KERNEL$" || true)
if [ -n "$remaining" ]; then
    echo "##[warning]Header packages still installed for another kernel series: $remaining"
else
    echo "Kernel headers aligned with $MAIA_KERNEL"
fi

# 3. Environment variables
echo "##[section]Setting MAIA environment variables"
cat <<'ENVEOF' | sudo tee /etc/profile.d/maiaenv.sh
# MAIA200 environment
ulimit -S -n 2048
export PATH="/opt/maia/bin:$PATH"
ENVEOF
sudo chmod 644 /etc/profile.d/maiaenv.sh

# 4. Crash dump configuration
sudo sysctl -w kernel.core_pattern="/var/crash/%e_%p_%t.dmp"
echo 'kernel.core_pattern=/var/crash/%e_%p_%t.dmp' | sudo tee -a /etc/sysctl.d/90-maia-coredump.conf
sudo mkdir -p /var/crash

# 5. Device node creation service (Issue 1 fix: skip dummy nodes when real driver devices exist)
echo "##[section]Installing MAIA device node service"
cat <<'DEVEOF' | sudo tee /usr/local/bin/create_maia_devices.sh
#!/bin/bash
# Creates placeholder /dev/apu* and /dev/maianexus* device nodes only for slots
# not already occupied by real driver-created devices (major != 1).
# This prevents dummy nodes (major 1 = /dev/null) from shadowing hardware devices,
# which causes libapu IOCTL -ENOTTY failures on every maia-smi invocation.
NUM_DEVICES="${NUM_APU_DEVICES:-8}"
for i in $(seq 0 $((NUM_DEVICES - 1))); do
    for prefix in apu maianexus; do
        DEV="/dev/${prefix}${i}"
        if [ ! -e "$DEV" ]; then
            # Only create a dummy if no real (non-null) devices exist for this prefix
            REAL_COUNT=$(ls -la /dev/${prefix}[0-9]* 2>/dev/null | awk '$5 != "1," {count++} END {print count+0}')
            if [ "$REAL_COUNT" -eq 0 ]; then
                mknod -m 0666 "$DEV" c 1 3
            fi
        fi
    done
done
DEVEOF
sudo chmod +x /usr/local/bin/create_maia_devices.sh

cat <<'SVCEOF' | sudo tee /etc/systemd/system/maia-devices.service
[Unit]
Description=Create MAIA APU and MaiaNexus Device Nodes
After=maia-driver-dma.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/create_maia_devices.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
SVCEOF

# 5b. apupci driver DMA service (Issue 3 fix: load driver with dma_mem when memmap= is in cmdline)
# The default boot loads apupci.ko via modprobe without dma_mem, so /dev/apu-dma-mem is never created
# even though GRUB reserves 256GB DMA memory (memmap=256G$90G).
# This service re-loads the driver using loaddriver.sh dma_mem which checks /proc/cmdline internally.
#
# The service also loads maianexus.ko (no systemd unit ships with the MAIA package),
# and pre-cleans any stale /dev/apu* / /dev/maianexus* dummy stubs left behind by
# earlier boot stages — otherwise the dummies (created with major 1,3 = /dev/null)
# would shadow the real char devices the driver tries to register, leaving every
# /dev/apuN as /dev/null and breaking libapu IOCTLs.
#
# Hardware gate: the helper script /usr/local/bin/maia-load-drivers.sh first
# checks for a MAIA200 PCI device (1414:00bd) and exits 0 without doing
# anything on hosts that don't have one (e.g. the Standard_D16s_v5 build
# VM used to bake this image).  Without the gate, loaddriver.sh hangs the
# kernel during boot on non-MAIA hosts, sshd never starts, and the build
# pipeline's post-reboot SSH probe times out.
echo "##[section]Installing MAIA driver loader helper"
cat <<'LOADEROF' | sudo tee /usr/local/bin/maia-load-drivers.sh
#!/bin/bash
# Load the MAIA apupci (with DMA reserved memory) and maianexus kernel
# drivers, but only on hosts that actually have MAIA200 hardware.
# On non-MAIA hosts (e.g. the build VM), exit 0 immediately without touching
# the kernel — running loaddriver.sh there can hang/panic the kernel.

set -u

# Hardware gate: any PCI device with vendor 0x1414 (Microsoft) AND device
# 0x00bd (MAIA200) qualifies as MAIA hardware.
have_maia=0
for dev in /sys/bus/pci/devices/*; do
    [ -r "$dev/vendor" ] && [ -r "$dev/device" ] || continue
    [ "$(cat "$dev/vendor")" = "0x1414" ] || continue
    [ "$(cat "$dev/device")" = "0x00bd" ] || continue
    have_maia=1
    break
done

if [ "$have_maia" -eq 0 ]; then
    echo "maia-drivers: no MAIA200 PCI device (1414:00bd) found, skipping driver load"
    exit 0
fi

# Clear stale /dev stubs so the drivers can register their real char devices.
rm -f /dev/apu[0-9]* /dev/apu-dma-mem /dev/maianexus[0-9]* || true

# Track load failures so the unit ends up in a failed state instead of
# reporting success with no drivers loaded.  A silently-skipped maianexus
# is not detectable until validation fails ~30 minutes later.
load_failed=0

# Load apupci with DMA reserved memory enabled.  loaddriver.sh uses a
# relative path for apupci.ko, so we must cd into its directory.
LOADDRIVER_DIR=/opt/maia/drivers/vfdriver/release/driver
LOADDRIVER_SH="$LOADDRIVER_DIR/loaddriver.sh"
# Self-heal: the aifx-maia-guest-stack tarball historically ships loaddriver.sh
# with mode 0664 (no +x).  Without +x the [ -x ] test below silently skips
# apupci on every boot, /dev/apu-dma-mem is never created, and downstream
# validation fails far later.  If the file exists but isn't executable, chmod
# it now and log the heal so the regression is detectable in the boot journal.
if [ -f "$LOADDRIVER_SH" ] && [ ! -x "$LOADDRIVER_SH" ]; then
    echo "maia-drivers: $LOADDRIVER_SH exists but is not executable — applying chmod +x"
    chmod +x "$LOADDRIVER_SH" || echo "maia-drivers: chmod +x failed on $LOADDRIVER_SH"
fi
if [ ! -x "$LOADDRIVER_SH" ]; then
    echo "maia-drivers: $LOADDRIVER_SH not found, skipping apupci"
    load_failed=1
else
    rmmod apupci 2>/dev/null || true
    if ! ( cd "$LOADDRIVER_DIR" && ./loaddriver.sh dma_mem ); then
        echo "maia-drivers: apupci load failed"
        load_failed=1
    fi
fi

# Load maianexus from the bundled per-kernel zip.
NEXUS_LOAD=/opt/maia/drivers/maianexus/utils/load_maianexus.sh
NEXUS_DIR=/opt/maia/drivers/maianexus
# The guest-stack tarball ships the master zip as maianexus_ubuntu_2404.zip
# when unsigned and maianexus_ubuntu_2404_signed.zip once it has been through
# the kernel-module signing pipeline.  Hardcoding the unsigned name meant the
# guard below failed on every signed image and maianexus was never loaded.
# Resolve either, preferring the signed one, matching the resolution already
# done in install_dependencies.sh (hpc-image-val).
NEXUS_ZIP=$(ls -1 "$NEXUS_DIR"/maianexus_ubuntu_2404*signed*.zip 2>/dev/null | sort -V | tail -1)
[ -z "$NEXUS_ZIP" ] && NEXUS_ZIP=$(ls -1 "$NEXUS_DIR"/maianexus_ubuntu_2404*.zip 2>/dev/null | sort -V | tail -1)
# Same self-heal as loaddriver.sh above — load_maianexus.sh is also shipped 0664.
if [ -f "$NEXUS_LOAD" ] && [ ! -x "$NEXUS_LOAD" ]; then
    echo "maia-drivers: $NEXUS_LOAD exists but is not executable — applying chmod +x"
    chmod +x "$NEXUS_LOAD" || echo "maia-drivers: chmod +x failed on $NEXUS_LOAD"
fi
if [ ! -x "$NEXUS_LOAD" ] || [ -z "$NEXUS_ZIP" ] || [ ! -f "$NEXUS_ZIP" ]; then
    echo "maia-drivers: maianexus loader or zip not found, skipping maianexus"
    echo "maia-drivers:   loader=$NEXUS_LOAD (executable: $( [ -x "$NEXUS_LOAD" ] && echo yes || echo no ))"
    echo "maia-drivers:   zip=${NEXUS_ZIP:-<none matched>}"
    ls -la "$NEXUS_DIR" 2>&1 || true
    load_failed=1
else
    echo "maia-drivers: loading maianexus from $NEXUS_ZIP"
    rmmod maianexus 2>/dev/null || true
    if ! "$NEXUS_LOAD" -z "$NEXUS_ZIP"; then
        echo "maia-drivers: maianexus load failed"
        load_failed=1
    fi
fi

udevadm settle --timeout=30 || true

if [ "$load_failed" -ne 0 ]; then
    echo "maia-drivers: one or more MAIA drivers failed to load, failing the unit"
    exit 1
fi
LOADEROF
sudo chmod +x /usr/local/bin/maia-load-drivers.sh

echo "##[section]Installing MAIA apupci DMA driver service"
cat <<'DMAEOF' | sudo tee /etc/systemd/system/maia-driver-dma.service
[Unit]
Description=Load MAIA apupci (with DMA reserved memory) and maianexus drivers
# Only depend on kernel auto-modload — do NOT pull in systemd-udev-settle.service,
# which can hang for hours on Azure VMs (continuous uevent stream from waagent)
# and would block multi-user.target → sshd never starts → unreachable VM.
After=systemd-modules-load.service
Before=maia-devices.service
# Skip the unit entirely if the helper script is missing (defensive — should
# never happen on an HPC image).
ConditionPathExists=/usr/local/bin/maia-load-drivers.sh

[Service]
Type=oneshot
RemainAfterExit=yes
# Cap the worst-case runtime: if anything hangs, fail the unit instead of
# blocking multi-user.target indefinitely.
TimeoutStartSec=300
ExecStart=/usr/local/bin/maia-load-drivers.sh

[Install]
WantedBy=multi-user.target
DMAEOF

sudo systemctl daemon-reload
sudo systemctl enable maia-driver-dma.service
sudo systemctl enable maia-devices.service

# NOTE: maia-guest-agent.service masking is intentionally NOT done here.
# The MAIA guest stack (setup.sh) is installed AFTER this script and tries
# to run `systemctl enable maia-guest-agent` during its post-install step.
# Masking here would cause that step to fail.  Masking is applied in
# install_dependencies.sh (hpc-image-val) immediately after setup.sh runs.

# 6. Create MCCL log directory
sudo mkdir -p /opt/maia/logs/mccl
sudo chmod 777 /opt/maia/logs/mccl

export ARCHITECTURE=$(uname -m)
export SKIP_FILES=()

$COMPONENT_DIR/trivy_scan.sh

echo "##[section]MAIA200 VM configurations complete"
echo "MAIA200 SKU: guest stack is installed separately via install_dependencies.sh"
