set -ex

ARCH=$(uname -m)


# install libnvshmem RPMS
if [ "$ARCHITECTURE" = "aarch64" ]; then

az artifacts universal download \
    --organization "https://dev.azure.com/mariner-org/" \
    --project "36d030d6-1d99-4ebd-878b-09af1f4f722f" \
    --scope project \
    --feed "azlinux-ai-ml-artifacts" \
    --name "azlinux-hpc-image-prebuilt-aarch64-test-packages" \
    --version "0.0.9" \
    --path /tmp

tdnf install -y /tmp/azlinux-hpc-image-prebuilt-aarch64-test-packages/libnvshmem-*.rpm
fi