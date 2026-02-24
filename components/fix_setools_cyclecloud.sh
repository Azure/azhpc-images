#!/bin/bash
set -ex

# Fix python3-setools pkg_resources compatibility issue for CycleCloud
#
# Issue: Rocky Linux 8.x has a bug where /usr/lib64/python3.6/site-packages/setools/__init__.py
# uses deprecated pkg_resources.get_distribution() which fails during CycleCloud initialization
# when semanage is called to configure SELinux contexts for /shared/home
#
# This prevents CycleCloud compute nodes from booting successfully because jetpack-initialize fails
#
# Solution: Patch setools/__init__.py to use a hardcoded version string instead of dynamic lookup
# This is safe because:
# 1. The version string is only used for informational purposes
# 2. Rocky 8.x ships with python3-setools 4.3.0 which is stable
# 3. CycleCloud requires semanage to work for proper home directory management

SETOOLS_INIT="/usr/lib64/python3.6/site-packages/setools/__init__.py"

if [ -f "$SETOOLS_INIT" ]; then
    echo "Patching setools to fix pkg_resources compatibility..."

    # Check if the file contains the problematic line
    if grep -q "__version__ = pkg_resources.get_distribution" "$SETOOLS_INIT"; then
        # Get the actual installed version
        SETOOLS_VERSION=$(rpm -q --queryformat '%{VERSION}' python3-setools 2>/dev/null || echo "4.3.0")

        # Patch the file to use hardcoded version
        sed -i "s/__version__ = pkg_resources.get_distribution(\"setools\").version/__version__ = \"${SETOOLS_VERSION}\"/" "$SETOOLS_INIT"

        echo "Successfully patched setools/__init__.py to use version ${SETOOLS_VERSION}"

        # Verify the patch worked
        if python3 -c "import setools; print(setools.__version__)" > /dev/null 2>&1; then
            echo "Verified: setools can be imported successfully"
        else
            echo "WARNING: setools import still fails after patching"
            exit 1
        fi
    else
        echo "setools/__init__.py does not contain problematic code, skipping patch"
    fi
else
    echo "setools not found at $SETOOLS_INIT, skipping patch (may be Rocky 9.x which doesn't have this issue)"
fi
