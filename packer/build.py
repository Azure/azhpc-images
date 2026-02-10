#!/usr/bin/env python3
"""
HPC Image Builder - Cross-Platform Entry Point
Build Azure HPC images using the official azhpc-images scripts.
Works on Windows, Linux, and macOS with Python 3.6+.

Usage: python build.py [options]
"""

import argparse
import json
import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent.resolve()
AZHPC_ROOT = SCRIPT_DIR.parent
sys.path.insert(0, str(SCRIPT_DIR / 'scripts'))
from utils import run, header, info, success, error, warn, step, C

def git_info(repo_path):
    """Get git information from a repository."""
    def git(cmd):
        return run(f'git -C "{repo_path}" {cmd}', check=False, capture=True) or "unknown"
    return {
        'commit': git('rev-parse HEAD'),
        'commit_short': git('rev-parse --short HEAD'),
        'url': git('config --get remote.origin.url'),
        'branch': git('rev-parse --abbrev-ref HEAD'),
    }

def find_mdatp():
    """Find mdatp onboarding package."""
    locations = ['/tmp/mdatp', os.environ.get('TEMP', '') + '/mdatp', str(SCRIPT_DIR / 'mdatp')]
    for loc in locations:
        if loc and Path(loc, 'MicrosoftDefenderATPOnboardingLinuxServer.py').exists():
            return loc
    return ""

def build_image(args, git):
    """Build a complete HPC image."""
    header("Building HPC Image", color=C.YELLOW)
    
    # Generate build ID for temp resource group naming
    build_id = datetime.now().strftime("%Y%m%d%H%M%S")
    temp_rg_name = f"pkr-hpc-{build_id}"
    
    packer_args = [
        'packer', 'build',
        '-on-error=abort' if args.hold_on_error else '-on-error=cleanup',
        f'-var=build_id={build_id}',
        f'-var=os_family={args.os}',
        f'-var=os_version={args.version}',
        f'-var=gpu_vendor={args.gpu}',
        f'-var=gpu_model={args.model}',
        f'-var=vhd_resource_group_name={args.resource_group}',
        f'-var=azure_location={args.location}',
        f'-var=skip_validation={str(args.skip_validation).lower()}',
        f'-var=azhpc_commit={git["commit"]}',
        f'-var=azhpc_repo_url={git["url"]}',
        f'-var=azhpc_branch={git["branch"]}',
        f'-var=azhpc_path={AZHPC_ROOT}',
        f'-var=owner_alias={args.owner}',
        f'-var=aks_host_image={str(args.aks_host).lower()}',
        f'-var=gb200_partuuid={args.gb200_partuuid}',
    ]
    
    if args.mdatp_path:
        packer_args.append(f'-var=mdatp_path={args.mdatp_path}')
    if args.create_vhd:
        packer_args.append('-var=create_vhd=true')
        packer_args.append(f'-var=vhd_storage_account={args.storage_account}')
    if args.publish_to_sig:
        packer_args.append('-var=publish_to_sig=true')
        packer_args.append(f'-var=sig_resource_group={args.sig_resource_group}')
        packer_args.append(f'-var=sig_gallery_name={args.sig_gallery_name}')
        if args.sig_image_name:
            packer_args.append(f'-var=sig_image_name={args.sig_image_name}')
        if args.sig_image_version:
            packer_args.append(f'-var=sig_image_version={args.sig_image_version}')
        # Convert comma-separated regions to HCL list format
        regions = [r.strip() for r in args.sig_replication_regions.split(',')]
        regions_hcl = json.dumps(regions)
        packer_args.append(f'-var=sig_replication_regions={regions_hcl}')
    packer_args.append('.')
    
    print(f"{C.DIM}Running: {' '.join(packer_args)}{C.RESET}\n")
    
    # Run Packer and handle Ctrl+C gracefully
    try:
        process = subprocess.Popen(packer_args, cwd=SCRIPT_DIR)
        returncode = process.wait()
    except KeyboardInterrupt:
        # User pressed Ctrl+C - let Packer finish its cleanup
        print(f"\n{C.YELLOW}[WARN] Cancelled. Waiting for Packer to exit...{C.RESET}")
        returncode = process.wait()
        
        # Clean up resource group if Packer didn't
        print(f"{C.YELLOW}[WARN] Cleaning up resource group: {temp_rg_name}{C.RESET}")
        rg_exists = run(f'az group exists --name "{temp_rg_name}"', check=False, capture=True, silent=True)
        if rg_exists == 'true':
            print(f"{C.YELLOW}[WARN] Deleting resource group: {temp_rg_name}{C.RESET}")
            run(f'az group delete --name "{temp_rg_name}" --yes --no-wait', check=False, silent=True)
            print(f"{C.YELLOW}[WARN] Cleanup initiated. Resource group will be deleted in background.{C.RESET}")
        else:
            print(f"{C.GREEN}[OK] Resource group already cleaned up by Packer.{C.RESET}")
        sys.exit(130)
    
    if returncode != 0:
        error("Build failed")
        sys.exit(1)
    
    # Get image name from manifest
    manifests = sorted(SCRIPT_DIR.glob('build-manifest-*.json'), key=os.path.getmtime, reverse=True)
    if manifests:
        manifest = json.loads(manifests[0].read_text())
        return manifest['builds'][0]['custom_data']['image_name']
    raise RuntimeError("Build manifest not found")

def main():
    parser = argparse.ArgumentParser(description='Build Azure HPC Images')
    parser.add_argument('-o', '--os', choices=['ubuntu', 'alma', 'azurelinux'], default='ubuntu',
                        help='OS family')
    parser.add_argument('-v', '--version', default='22.04',
                        help='OS version (e.g., 22.04, 24.04, 8.10, 9.7, 3.0)')
    parser.add_argument('-g', '--gpu', required=True, choices=['nvidia', 'amd'],
                        help='GPU vendor (required)')
    parser.add_argument('-m', '--model', required=True,
                        help='GPU model (e.g., a100, h100, v100, gb200, mi300x)')
    parser.add_argument('--aks-host', action='store_true',
                        help='Build AKS host image (uses install_aks.sh)')
    parser.add_argument('--gb200-partuuid', default='None',
                        help='Disk PARTUUID for GB200 builds (required for GB200 non-AKS)')
    parser.add_argument('--rg', '--resource-group', dest='resource_group', default='hpc-images-rg',
                        help='Azure resource group')
    parser.add_argument('--location', default='westus2',
                        help='Azure location')
    parser.add_argument('--skip-validation', action='store_true',
                        help='Skip tests and health checks')
    parser.add_argument('--hold-on-error', action='store_true',
                        help='Keep VM on error for debugging')
    parser.add_argument('--create-vhd', action='store_true',
                        help='Also create VHD in storage account')
    parser.add_argument('--storage-account', default='',
                        help='Storage account for VHD output')
    # Shared Image Gallery options
    parser.add_argument('--publish-to-sig', action='store_true',
                        help='Publish image to Shared Image Gallery')
    parser.add_argument('--sig-resource-group', default='hpc-images-rg',
                        help='Resource group containing the SIG')
    parser.add_argument('--sig-gallery-name', default='AzHPCImageReleaseCandidates',
                        help='Name of the Shared Image Gallery')
    parser.add_argument('--sig-image-name', default='',
                        help='Image definition name (auto-generated if empty)')
    parser.add_argument('--sig-image-version', default='',
                        help='Image version (auto-generated if empty)')
    parser.add_argument('--sig-replication-regions', default='westus2',
                        help='Comma-separated list of replication regions')
    parser.add_argument('--owner', default=os.environ.get('USER', os.environ.get('USERNAME', 'packer')),
                        help='Owner alias for tagging')
    args = parser.parse_args()

    # Validations
    if args.create_vhd and not args.storage_account:
        error("--storage-account is required with --create-vhd")
        sys.exit(1)

    # Check prerequisites
    if run('az account show', check=False, capture=True, silent=True) == '':
        error("Not logged in to Azure. Run: az login")
        sys.exit(1)
    if run('packer version', check=False, capture=True, silent=True) == '':
        error("Packer not installed")
        sys.exit(1)
    
    git = git_info(AZHPC_ROOT)
    args.mdatp_path = find_mdatp()
    
    header("HPC Image Builder")
    info("OS:", f"{args.os} {args.version}")
    info("GPU:", f"{C.MAGENTA}{args.gpu} {args.model}{C.RESET}")
    info("Resource Group:", args.resource_group)
    info("azhpc-images:", f"{git['branch']} @ {C.YELLOW}{git['commit_short']}{C.RESET}")
    if args.mdatp_path:
        info("MDATP:", f"{C.GREEN}Found{C.RESET}")
    else:
        info("MDATP:", f"{C.DIM}Not found (skipping){C.RESET}")
    if args.create_vhd:
        info("VHD Output:", f"{C.GREEN}{args.storage_account}{C.RESET}")
    if args.publish_to_sig:
        info("SIG:", f"{C.GREEN}{args.sig_gallery_name}{C.RESET}")
    
    os.chdir(SCRIPT_DIR)
    run('packer init .', check=False)
    
    start = datetime.now()
    image_name = build_image(args, git)
    duration = datetime.now() - start
    
    header("Build Complete!", color=C.GREEN)
    info("Image:", image_name)
    info("Duration:", str(duration))

if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        print(f"\n{C.YELLOW}[WARN] Build cancelled by user.{C.RESET}")
        sys.exit(130)
