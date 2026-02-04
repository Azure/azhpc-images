#!/usr/bin/env python3
"""
Validation reboot script.
Triggers reboot between pre-reboot and post-reboot validation phases.
"""

import argparse
import os
import sys

# Add script directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from utils import header, info


def main():
    parser = argparse.ArgumentParser(
        description="Trigger reboot for post-installation validation"
    )
    parser.add_argument(
        "--skip",
        action="store_true",
        help="Skip validation reboot"
    )
    args = parser.parse_args()

    if args.skip:
        info("Validation reboot: SKIPPED (validation disabled)")
        return 0

    header("Rebooting for post-installation validation...")
    
    # Trigger reboot and exit immediately
    # The script exits before the reboot actually happens
    os.system("(sleep 5 && sudo reboot) &")
    
    return 0


if __name__ == "__main__":
    sys.exit(main())
