#!/usr/bin/env python3
"""Add ipTags to Azure public IP for first-party access."""

import os
import sys
from utils import run, info, success, error, C

def main():
    rg = os.environ.get('RG_NAME', '').strip()
    pip = os.environ.get('PIP_NAME', '').strip()
    
    if not rg or not pip:
        error("RG_NAME and PIP_NAME environment variables required")
        sys.exit(1)
    
    print(f"{C.CYAN}Adding ipTags to temporary public IP...{C.RESET}")
    info("Resource Group:", rg)
    info("Public IP Name:", pip)
    
    print(f"{C.DIM}Verifying Azure CLI access...{C.RESET}")
    print(run('az account show --query name -o tsv', capture=True))
    
    print(f"{C.YELLOW}Updating public IP with ipTags...{C.RESET}")
    run(f'az network public-ip update --resource-group "{rg}" --name "{pip}" --ip-tags FirstPartyUsage=/Unprivileged')
    
    print(f"{C.DIM}Verifying ipTags...{C.RESET}")
    print(run(f'az network public-ip show --resource-group "{rg}" --name "{pip}" --query ipTags -o json', capture=True))
    
    success("ipTags added successfully!")

if __name__ == '__main__':
    main()
