#!/usr/bin/env python3
import os
import subprocess
import json

def get_os_version():
    result = subprocess.run(['uname', '-r'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    result.check_returncode()
    return result.stdout.strip()

def get_component_versions():
    if not os.path.exists('/opt/azurehpc/component_versions.txt'):
        return {}
    with open('/opt/azurehpc/component_versions.txt') as f:
        return json.load(f)

print(f"Kernel={get_os_version()}", end=" ")
for component, version in get_component_versions().items():
    print(f"{component}={version}", end=" ")