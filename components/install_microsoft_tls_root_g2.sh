#!/bin/bash
set -ex

# Bootstrap the "Microsoft TLS RSA Root G2" trust anchor on Ubuntu.
#
# Microsoft has rotated public-facing endpoints (e.g. download.microsoft.com)
# to a chain rooted at "Microsoft TLS RSA Root G2" (self-signed root issued
# 2025-04-10, valid until 2040). Mozilla's NSS bundle includes this root,
# but Ubuntu Noble/Jammy's `ca-certificates` package (still 20240203 as of
# this writing) has not yet been refreshed, so the new root is absent from
# /etc/ssl/certs/ca-certificates.crt. TLS verification against affected
# endpoints fails with "unable to get local issuer certificate".
#
# This script fetches the root over plain HTTP from Microsoft's PKI
# repository, pins its SHA-256 fingerprint, and installs it as a local
# trust anchor via update-ca-certificates. Once Ubuntu ships a refreshed
# ca-certificates package containing the G2 root, this anchor becomes
# redundant but harmless.

ROOT_URL="http://www.microsoft.com/pkiops/certs/Microsoft%20TLS%20RSA%20Root%20G2.crt"
ROOT_SHA256="6a170583db584151e1c454eeca2a64cc5d8e484a5bd1156e720b4458654ee9e5"
ANCHOR_PATH="/usr/local/share/ca-certificates/Microsoft_TLS_RSA_Root_G2.crt"

# Idempotency: if a previous image bake already installed the anchor, exit.
if [[ -f "${ANCHOR_PATH}" ]]; then
    echo "Microsoft TLS RSA Root G2 anchor already present at ${ANCHOR_PATH}; skipping."
    exit 0
fi

# Ensure tooling is present (ca-certificates and curl are normally pre-installed,
# but harden against minimal base images).
apt-get install -y --no-install-recommends ca-certificates curl openssl

TMP_DER="$(mktemp --suffix=.cer)"
TMP_PEM="$(mktemp --suffix=.pem)"
trap 'rm -f "${TMP_DER}" "${TMP_PEM}"' EXIT

curl -fsSL --connect-timeout 15 --retry 3 --retry-delay 5 \
    -o "${TMP_DER}" "${ROOT_URL}"

# Pin by SHA-256 of the DER encoding (== canonical X.509 fingerprint).
echo "${ROOT_SHA256}  ${TMP_DER}" | sha256sum -c -

# /usr/local/share/ca-certificates/ requires PEM-encoded *.crt files.
openssl x509 -inform DER -in "${TMP_DER}" -out "${TMP_PEM}"

install -m 0644 "${TMP_PEM}" "${ANCHOR_PATH}"
update-ca-certificates

# Sanity check: the new root must appear in the consolidated trust bundle.
grep -q "Microsoft TLS RSA Root G2" /etc/ssl/certs/ca-certificates.crt
