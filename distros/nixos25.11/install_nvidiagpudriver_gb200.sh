#!/bin/bash
# NixOS NVIDIA GPU Driver Installation for GB200/GB300
#
# NixOS handles NVIDIA drivers declaratively via configuration.nix,
# not via apt/dpkg. This script:
#   1. Enables nvidia drivers in NixOS config
#   2. Rebuilds the system with nvidia support
#   3. Installs CUDA toolkit via nix-env for user-space tools
#   4. Verifies the installation
#
# The kernel module is loaded by NixOS's hardware.nvidia module.
set -ex

source ${UTILS_DIR}/utilities.sh

echo "##[section]Installing NVIDIA GPU driver for NixOS (GB200/GB300)"

cuda_metadata=$(get_component_config "cuda" 2>/dev/null || echo '{}')
nvidia_metadata=$(get_component_config "nvidia" 2>/dev/null || echo '{}')

# Extract versions (fallback to defaults if metadata unavailable)
CUDA_VERSION=$(jq -r '.driver.version // "12.8"' <<< "$cuda_metadata")
NVIDIA_DRIVER_VERSION=$(jq -r '.driver.version // "570"' <<< "$nvidia_metadata")

echo "##[debug]CUDA version: ${CUDA_VERSION}"
echo "##[debug]NVIDIA driver version: ${NVIDIA_DRIVER_VERSION}"

# ── Step 1: Enable NVIDIA in NixOS configuration ────────────────────
# Append NVIDIA hardware configuration to the system
cat >> /etc/nixos/nvidia-hpc.nix << 'NIXEOF'
{ config, pkgs, lib, ... }:

{
  # Enable NVIDIA proprietary drivers
  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.production;
    modesetting.enable = true;
    open = true;
    nvidiaSettings = false;
  };

  # Enable OpenGL/GPU support
  hardware.graphics.enable = true;

  # Load nvidia kernel modules at boot
  boot.kernelModules = [ "nvidia" "nvidia_uvm" "nvidia_modeset" ];

  # NVIDIA modprobe options (GB300-specific)
  # NVreg_CreateImexChannel0=1        — required for IMEX
  # NVreg_CoherentGPUMemoryMode=driver — CDMM mode
  # NVreg_RestrictProfilingToAdminUsers=0 — allow non-root profiling
  # NVreg_EnableNonblockingOpen=0     — serialized GSP init (avoid deadlocks)
  # No fabricmanager — GB300 NVSwitch is hypervisor-managed
  boot.extraModprobeConfig = ''
    options nvidia NVreg_RestrictProfilingToAdminUsers=0
    options nvidia NVreg_CoherentGPUMemoryMode=driver
    options nvidia NVreg_CreateImexChannel0=1
    options nvidia NVreg_EnableNonblockingOpen=0
  '';

  # NVIDIA persistence daemon
  systemd.services.nvidia-persistenced = {
    description = "NVIDIA Persistence Daemon";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "forking";
      ExecStart = "${config.hardware.nvidia.package}/bin/nvidia-persistenced --persistence-mode";
      ExecStopPost = "${config.hardware.nvidia.package}/bin/nvidia-persistenced --persistence-mode --no-persistence-mode";
    };
  };

  # CUDA environment
  environment.systemPackages = with pkgs; [
    cudaPackages.cudatoolkit
    cudaPackages.cudnn
    config.hardware.nvidia.package
  ];

  environment.variables = {
    CUDA_HOME = "${pkgs.cudaPackages.cudatoolkit}";
    CUDA_PATH = "${pkgs.cudaPackages.cudatoolkit}";
  };
}
NIXEOF

echo "##[debug]NVIDIA NixOS configuration written to /etc/nixos/nvidia-hpc.nix"

# ── Step 2: Include nvidia-hpc.nix in main configuration ────────────
# Add the import if not already present
if ! grep -q "nvidia-hpc.nix" /etc/nixos/configuration.nix; then
    sed -i '/imports = \[/a\    ./nvidia-hpc.nix' /etc/nixos/configuration.nix
    echo "##[debug]Added nvidia-hpc.nix import to configuration.nix"
fi

# ── Step 3: Rebuild NixOS with NVIDIA support ───────────────────────
echo "##[section]Rebuilding NixOS with NVIDIA drivers"
nixos-rebuild switch --no-build-nix 2>&1 || {
    echo "##[warning]nixos-rebuild switch failed, trying boot target"
    nixos-rebuild boot --no-build-nix 2>&1
    echo "##[warning]Reboot required for NVIDIA driver activation"
}

# ── Step 4: Post-rebuild cleanup ────────────────────────────────────
# Remove unused KMS config created by NVIDIA driver
rm -f /etc/modprobe.d/nvidia-graphics-drivers-kms.conf

# ── Step 5: Verify installation ─────────────────────────────────────
if command -v nvidia-smi &>/dev/null; then
    echo "##[section]NVIDIA driver verification"
    nvidia-smi
    nvidia_driver_version=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -n 1 || echo "pending-reboot")
    write_component_version "NVIDIA" "${nvidia_driver_version}"
else
    echo "##[warning]nvidia-smi not yet available (may need reboot)"
    write_component_version "NVIDIA" "pending-reboot"
fi

# Record CUDA version from nix
cuda_version=$(nix-store -qR $(which nvcc 2>/dev/null || echo "/dev/null") 2>/dev/null | grep cuda | head -1 | grep -oP 'cuda-\K[0-9.]+' || echo "${CUDA_VERSION}")
write_component_version "CUDA" "${cuda_version}"

echo "##[section]NVIDIA GPU driver installation complete for NixOS"
