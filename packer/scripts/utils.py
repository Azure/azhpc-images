#!/usr/bin/env python3
"""Shared utilities for HPC image build scripts."""

import os
import subprocess
import sys

# Enable ANSI colors on Windows
if sys.platform == 'win32':
    os.system('')  # Enables ANSI escape sequences in Windows Terminal

# ANSI color codes
class Colors:
    RESET = '\033[0m'
    BOLD = '\033[1m'
    DIM = '\033[2m'
    
    RED = '\033[91m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    MAGENTA = '\033[95m'
    CYAN = '\033[96m'
    WHITE = '\033[97m'
    
    # Backgrounds
    BG_RED = '\033[41m'
    BG_GREEN = '\033[42m'
    BG_BLUE = '\033[44m'

C = Colors  # Short alias

def header(text, char='=', color=C.CYAN):
    """Print a colored header."""
    line = char * 50
    print(f"{color}{C.BOLD}{line}{C.RESET}")
    print(f"{color}{C.BOLD}{text}{C.RESET}")
    print(f"{color}{C.BOLD}{line}{C.RESET}")

def info(label, value='', color=C.WHITE):
    """Print a labeled info line."""
    if value:
        print(f"{C.CYAN}{label:<20}{C.RESET} {color}{value}{C.RESET}")
    else:
        print(f"{color}{label}{C.RESET}")

def success(msg):
    """Print success message."""
    print(f"{C.GREEN}{C.BOLD}[OK] {msg}{C.RESET}")

def error(msg):
    """Print error message."""
    print(f"{C.RED}{C.BOLD}[ERROR] {msg}{C.RESET}", file=sys.stderr)

def warn(msg):
    """Print warning message."""
    print(f"{C.YELLOW}[WARN] {msg}{C.RESET}")

def step(num, total, msg):
    """Print a step indicator."""
    print(f"\n{C.MAGENTA}{C.BOLD}[{num}/{total}]{C.RESET} {C.WHITE}{msg}{C.RESET}")

def run(cmd, check=True, capture=False, silent=False):
    """Run a command and return output.
    
    Args:
        cmd: Command string to execute
        check: If True, exit on non-zero return code
        capture: If True, return stdout; otherwise return exit code
        silent: If True, suppress error output
    
    Returns:
        stdout string if capture=True, else return code
    """
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if check and result.returncode != 0:
        if not silent:
            error(result.stderr.strip() or f"Command failed: {cmd}")
        sys.exit(result.returncode)
    return result.stdout.strip() if capture else result.returncode


# OS family to distro directory prefix
DISTRO_PREFIX_MAP = {
    'ubuntu': 'ubuntu',
    'alma': 'almalinux',
    'azurelinux': 'azurelinux',
}

# GPU vendor to platform name (uppercase for azhpc-images scripts)
GPU_PLATFORM_MAP = {
    'nvidia': 'NVIDIA',
    'amd': 'AMD',
}


def get_distro_name(os_family: str, distro_version: str) -> str:
    """Map os_family + distro_version to distribution directory name.
    
    Example: get_distro_name('ubuntu', '22.04') -> 'ubuntu22.04'
    """
    prefix = DISTRO_PREFIX_MAP.get(os_family)
    return f"{prefix}{distro_version}" if prefix else None


def get_gpu_platform(gpu_vendor: str) -> str:
    """Map gpu vendor to platform name (uppercase for azhpc-images).
    
    Example: get_gpu_platform('nvidia') -> 'NVIDIA'
    """
    return GPU_PLATFORM_MAP.get(gpu_vendor, '')


def get_sku(gpu_model: str) -> str:
    """Map gpu_model to SKU (uppercase).
    
    Example: get_sku('a100') -> 'A100'
    """
    return gpu_model.upper()
