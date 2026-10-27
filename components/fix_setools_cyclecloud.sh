#!/bin/bash
set -ex

# EL8/EL9 SETools uses pkg_resources for its informational version. Missing
# Python distribution metadata can break imports and CycleCloud's semanage calls.
# Upstream replaced this lookup in SETools 4.5.0; leave that implementation alone.
if ! rpm -q python3-setools >/dev/null 2>&1; then
    echo "python3-setools is not installed, skipping patch"
    exit 0
fi

SETOOLS_INIT=$(rpm -ql python3-setools | grep '/setools/__init__\.py$')
if [[ ! -f "$SETOOLS_INIT" ]]; then
    echo "ERROR: unable to locate the installed setools/__init__.py" >&2
    exit 1
fi

if ! grep -Fq '__version__ = pkg_resources.get_distribution("setools").version' "$SETOOLS_INIT"; then
    echo "setools does not use the legacy version lookup, skipping patch"
    exit 0
fi

SETOOLS_VERSION=$(rpm -q --queryformat '%{VERSION}' python3-setools)
sed -i "s/__version__ = pkg_resources\.get_distribution(\"setools\")\.version/__version__ = \"${SETOOLS_VERSION}\"/" "$SETOOLS_INIT"

if ! /usr/sbin/semanage --help >/dev/null; then
    echo "ERROR: semanage still fails after patching setools" >&2
    exit 1
fi
echo "Verified: semanage works with setools ${SETOOLS_VERSION}"
