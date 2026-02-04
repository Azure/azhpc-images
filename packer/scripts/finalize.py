#!/usr/bin/env python3
"""
Finalize: Verify build completion and report status.

This script runs AFTER the install.sh completes.

NOTE: The distro-specific install.sh scripts already handle:
  - Trivy security scanning (trivy_scan.sh)
  - Disabling auto kernel updates (disable_auto_upgrade.sh)
  - Disabling predictive network naming (disable_predictive_interface_renaming.sh)
  - SKU customizations (setup_sku_customizations.sh)
  - Cleanup of downloaded tarballs

This script just verifies the build artifacts exist and reports status.
"""

import argparse
import os
import sys
import shutil

# Add script directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from utils import header, info, success, warn, C


def check_file(path: str, description: str) -> bool:
    """Check if a file exists and report status."""
    if os.path.isfile(path):
        success(f"{description} exists")
        return True
    else:
        warn(f"{description} not found")
        return False


def check_dir(path: str, description: str) -> bool:
    """Check if a directory exists and report status."""
    if os.path.isdir(path):
        success(f"{description} exists")
        return True
    else:
        warn(f"{description} not found")
        return False


def get_disk_usage() -> str:
    """Get disk usage for root partition."""
    try:
        usage = shutil.disk_usage('/')
        used_gb = usage.used / (1024 ** 3)
        total_gb = usage.total / (1024 ** 3)
        return f"{used_gb:.1f}GB / {total_gb:.1f}GB"
    except Exception:
        return "unknown"


def main():
    parser = argparse.ArgumentParser(
        description="Verify build artifacts and report status"
    )
    parser.add_argument(
        "--skip",
        action="store_true",
        help="Skip finalization checks"
    )
    args = parser.parse_args()

    # Check if finalization should be skipped
    if args.skip:
        header("Finalization SKIPPED")
        return 0

    header("Finalization: Verify Build Artifacts")

    # Source azhpc environment if available
    azhpc_env = "/etc/profile.d/azhpc-env.sh"
    if os.path.isfile(azhpc_env):
        # Read and parse key environment variables
        pass  # Environment sourcing handled by shell wrapper

    print("Checking build artifacts...")
    print()

    # Check expected build artifacts
    artifacts = [
        ("/opt/azurehpc/component_versions.txt", "Component versions file"),
        ("/opt/azurehpc/trivy-report-rootfs.json", "Trivy report"),
        ("/opt/azurehpc/trivy-cyclonedx-rootfs.json", "Trivy CycloneDX SBOM"),
    ]

    for path, desc in artifacts:
        check_file(path, desc)

    # Check test directory
    check_dir("/opt/azurehpc/test", "Test directory")

    print()
    header("Finalization Complete")
    info("Final disk usage:", get_disk_usage())

    # Print component versions if available
    versions_file = "/opt/azurehpc/component_versions.txt"
    if os.path.isfile(versions_file):
        print()
        print(f"{C.CYAN}{C.BOLD}Final Component Versions:{C.RESET}")
        with open(versions_file, 'r') as f:
            print(f.read())

    return 0


if __name__ == "__main__":
    sys.exit(main())
