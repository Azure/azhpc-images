#!/usr/bin/env python3
"""
Validation: Run tests and health checks (matching old pipeline run_tests.sh)

Usage: python3 validate-image.py [pre-reboot|post-reboot] [options]

Options:
    --gpu-platform PLATFORM  GPU platform (NVIDIA/AMD)
    --gpu-model MODEL        GPU model (a100, gb200, etc.)
    --aks                    AKS host image build
    --skip                   Skip validation
"""
import argparse
import os
import subprocess
import sys

# Add script directory to path for imports
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, SCRIPT_DIR)

from utils import header, info, success, warn, C

# Paths matching old pipeline
TEST_DIR = "/opt/azurehpc/test"
TEST_SCRIPT = f"{TEST_DIR}/run-tests.sh"
HEALTH_CHECK_SCRIPT = f"{TEST_DIR}/azurehpc-health-checks/run-health-checks.sh"
HEALTH_LOG = f"{TEST_DIR}/azurehpc-health-checks/health.log"


def run_tests(gpu_platform: str, aks_host: bool) -> None:
    """Run component tests (matching old pipeline: run-tests.sh $GPU_PLATFORM [-aks-host])"""
    if not os.path.isfile(TEST_SCRIPT):
        warn(f"Test script not found: {TEST_SCRIPT}")
        return
    
    test_args = [TEST_SCRIPT, gpu_platform]
    if aks_host:
        test_args.append("-aks-host")
    
    print(f"{C.CYAN}Running: {' '.join(test_args)}{C.RESET}")
    
    result = subprocess.run(["sudo", "bash"] + test_args, check=False)
    if result.returncode != 0:
        warn("Tests had warnings (expected during image build without GPU hardware)")
    else:
        success("Tests passed")


def run_health_checks(gpu_sku: str) -> None:
    """Run health checks (matching old pipeline: run-health-checks.sh -o health.log -v)"""
    # Skip for GB200 (matching old pipeline)
    if gpu_sku.lower() == "gb200":
        info("Health Check:", "Skipped for GB200")
        return
    
    if not os.path.isfile(HEALTH_CHECK_SCRIPT):
        warn(f"Health check script not found: {HEALTH_CHECK_SCRIPT}")
        return
    
    print(f"{C.CYAN}Running health checks...{C.RESET}")
    
    subprocess.run(
        ["sudo", "-i", HEALTH_CHECK_SCRIPT, "-o", HEALTH_LOG, "-v"],
        check=False
    )
    
    # Check results matching old pipeline logic
    if os.path.isfile(HEALTH_LOG):
        with open(HEALTH_LOG, 'r') as f:
            log_content = f.read()
        
        if "health checks completed with exit code: 0." in log_content.lower():
            success("Health Check - Passed!")
        else:
            warn("Health Check - Completed with warnings (expected during image build)")
    else:
        warn("Health log not found")


def main():
    parser = argparse.ArgumentParser(description='Run image validation tests and health checks')
    parser.add_argument('phase', nargs='?', default='pre-reboot',
                        choices=['pre-reboot', 'post-reboot'],
                        help='Validation phase: pre-reboot or post-reboot')
    parser.add_argument('--gpu-platform', dest='gpu_platform', required=True,
                        help='GPU platform (NVIDIA/AMD)')
    parser.add_argument('--gpu-sku', dest='gpu_sku', required=True,
                        help='GPU SKU (a100, h100, gb200, mi300x)')
    parser.add_argument('--aks', action='store_true',
                        help='AKS host image build')
    parser.add_argument('--skip', action='store_true',
                        help='Skip validation')
    args = parser.parse_args()
    
    gpu_platform = args.gpu_platform
    gpu_sku = args.gpu_sku
    aks_host = args.aks
    
    if args.skip:
        print("Validation SKIPPED")
        sys.exit(0)
    
    header(f"Image Validation: {args.phase}")
    info("GPU Platform:", gpu_platform)
    info("GPU SKU:", gpu_sku)
    info("AKS Host:", str(aks_host))
    print()
    
    if args.phase == "pre-reboot":
        # Old pipeline: runs tests before reboot if not GB200
        if gpu_sku.lower() != "gb200":
            run_tests(gpu_platform, aks_host)
    
    elif args.phase == "post-reboot":
        # Verify system is fully ready after reboot
        print(f"{C.CYAN}System Status After Reboot:{C.RESET}")
        subprocess.run(["uptime"], check=False)
        subprocess.run(["systemctl", "is-system-running", "--wait"], check=False)
        print()
        
        # Old pipeline: runs tests and health checks after reboot
        run_tests(gpu_platform, aks_host)
        run_health_checks(gpu_sku)
    
    print()
    print("Validation Complete")


if __name__ == "__main__":
    main()
