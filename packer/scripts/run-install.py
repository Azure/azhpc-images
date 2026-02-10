#!/usr/bin/env python3
"""
Run azhpc-images install.sh (monolithic build)
This script runs the distro-specific install.sh from azhpc-images.

Usage: python3 run-install.py --os ubuntu --version 22.04 --gpu nvidia --model a100 [--aks]
"""
import argparse
import json
import os
import subprocess
import sys

# Add script directory to path for imports
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, SCRIPT_DIR)

from utils import (
    header, info, success, error, warn, C,
    get_distro_name, get_gpu_platform, get_sku
)


def update_component_versions(image_version: str) -> None:
    """Add image version to component_versions.txt if provided."""
    if not image_version:
        return
    
    component_versions_path = '/opt/azurehpc/component_versions.txt'
    if not os.path.isfile(component_versions_path):
        warn(f"component_versions.txt not found at {component_versions_path}")
        return
    
    try:
        with open(component_versions_path, 'r') as f:
            versions = json.load(f)
        versions['ImageVersion'] = image_version
        with open(component_versions_path, 'w') as f:
            json.dump(versions, f, indent=2)
        success(f"Added ImageVersion '{image_version}' to component_versions.txt")
    except Exception as e:
        warn(f"Failed to update component_versions.txt: {e}")


def main():
    parser = argparse.ArgumentParser(description='Run azhpc-images install.sh')
    parser.add_argument('--os', required=True, choices=['ubuntu', 'alma', 'azurelinux'],
                        help='OS family')
    parser.add_argument('--version', required=True,
                        help='OS version (e.g., 22.04, 24.04, 8.10)')
    parser.add_argument('--gpu', required=True, choices=['NVIDIA', 'AMD'],
                        help='GPU vendor (required)')
    parser.add_argument('--model', required=True,
                        help='GPU model (e.g., a100, h100, gb200, mi300x)')
    parser.add_argument('--aks', action='store_true',
                        help='Build AKS host image (uses install_aks.sh if available)')
    parser.add_argument('--image-version', default='',
                        help='Image version to embed in component_versions.txt')
    args = parser.parse_args()
    
    header("Running azhpc-images install")
    info("OS:", f"{args.os} {args.version}")
    info("GPU:", f"{args.gpu} {args.model}")
    info("AKS Host:", str(args.aks))
    if args.image_version:
        info("Image Version:", args.image_version)
    
    distro = get_distro_name(args.os, args.version)
    if not distro:
        error(f"Unknown OS family: {args.os}")
        sys.exit(1)
    
    gpu_platform = get_gpu_platform(args.gpu)
    sku = get_sku(args.model)
    
    install_dir = f'/opt/azhpc-images/distros/{distro}'
    
    # Determine which install script to use
    if args.aks:
        aks_script = f'{install_dir}/install_aks.sh'
        if os.path.isfile(aks_script):
            install_script = aks_script
            info("Install Script:", f"{C.GREEN}install_aks.sh{C.RESET}")
        else:
            install_script = f'{install_dir}/install.sh'
            warn("install_aks.sh not found, falling back to install.sh")
    else:
        install_script = f'{install_dir}/install.sh'
    
    if not os.path.isdir(install_dir):
        error(f"Distribution directory not found: {install_dir}")
        sys.exit(1)
    
    if not os.path.isfile(install_script):
        error(f"Install script not found: {install_script}")
        sys.exit(1)
    
    script_name = os.path.basename(install_script)
    print(f"\n{C.CYAN}Running: ./{script_name} {gpu_platform} {sku}{C.RESET}\n")
    
    # Change to install directory and run install script
    os.chdir(install_dir)
    os.chmod(install_script, 0o755)
    
    result = subprocess.run([install_script, gpu_platform, sku], check=False)
    
    if result.returncode != 0:
        error(f"{script_name} failed with exit code {result.returncode}")
        sys.exit(result.returncode)
    
    update_component_versions(args.image_version)
    
    header("Install Complete", color=C.GREEN)


if __name__ == '__main__':
    main()
