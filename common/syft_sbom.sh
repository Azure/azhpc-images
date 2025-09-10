#!/usr/bin/env bash
set -euxo pipefail

curl -sSfL https://get.anchore.io/syft | sh -s -- -b /usr/local/bin

/usr/local/bin/syft scan / -o syft-json=/opt/azurehpc/syft-sbom-syft.json
/usr/local/bin/syft scan / -o cyclonedx-json=/opt/azurehpc/syft-sbom-cyclonedx.json