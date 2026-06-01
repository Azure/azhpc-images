#!/bin/bash
set -ex
set -o pipefail

# Bootstrap the "Microsoft TLS RSA Root G2" trust anchor on any supported distro.
#
# Microsoft has rotated public-facing endpoints (e.g. download.microsoft.com)
# to a chain issued by a new intermediate, "Microsoft TLS G2 RSA CA OCSP NN",
# whose issuer is "Microsoft TLS RSA Root G2". That root exists in two
# forms with the same Subject and the same public key but different issuers:
#   * self-signed root  (anchor; issued by itself, valid until 2040)
#   * cross-signed cert (intermediate; issued by DigiCert Global Root G2)
#
# The acute problem is a server-side chain-configuration inconsistency at
# Microsoft, not a missing trust anchor in the distro:
#
#   * Some Microsoft front-ends serve the FULL chain --
#       leaf
#         -> "Microsoft TLS G2 RSA CA OCSP NN" (intermediate)
#         -> "Microsoft TLS RSA Root G2"       (cross-signed by
#                                              DigiCert Global Root G2)
#     The client then anchors at DigiCert Global Root G2, which is already
#     in every supported distro's trust store, and TLS verification
#     succeeds out of the box.
#
#   * Other front-ends serve ONLY the first two certs --
#       leaf
#         -> "Microsoft TLS G2 RSA CA OCSP NN" (intermediate)
#     The cross-signed bridge to DigiCert is omitted. The client must then
#     resolve the issuer of that intermediate locally, and unless the
#     self-signed "Microsoft TLS RSA Root G2" is present in the trust
#     store, path-building dead-ends and openssl/curl/etc. report:
#       "unable to get local issuer certificate" (verify error 20).
#
# Installing the self-signed "Microsoft TLS RSA Root G2" as a local trust
# anchor closes that gap: it terminates the chain locally when the server
# omits the cross-signed bridge, and is a no-op when the server does
# return the full chain (the existing DigiCert path is preferred).
#
# This script fetches the root over plain HTTP from Microsoft's PKI
# repository, pins its SHA-256 fingerprint, and installs it using the
# distro-appropriate layout:
#   Ubuntu       :  /usr/local/share/ca-certificates/  +  update-ca-certificates
#   RHEL family  :  /etc/pki/ca-trust/source/anchors/  +  update-ca-trust
#   Azure Linux  :  /etc/pki/ca-trust/source/anchors/  +  update-ca-trust
#
# Once Microsoft fixes the partial-chain endpoints (or otherwise stops
# relying on the new G2 CA), this anchor becomes redundant but harmless.

source ${UTILS_DIR}/utilities.sh

ROOT_URL="http://www.microsoft.com/pkiops/certs/Microsoft%20TLS%20RSA%20Root%20G2.crt"
ROOT_SHA256="6a170583db584151e1c454eeca2a64cc5d8e484a5bd1156e720b4458654ee9e5"
ANCHOR_NAME="Microsoft_TLS_RSA_Root_G2"

# Select trust-store layout per distro family (matches the convention used
# in install_aznfs.sh and other components).
if [[ $DISTRIBUTION == *"ubuntu"* ]]; then
    ANCHOR_DIR="/usr/local/share/ca-certificates"
    ANCHOR_FILE="${ANCHOR_DIR}/${ANCHOR_NAME}.crt"
    TRUST_BUNDLE="/etc/ssl/certs/ca-certificates.crt"
    update_trust() { update-ca-certificates; }
elif [[ $DISTRIBUTION == *"almalinux"* || $DISTRIBUTION == *"rocky"* || $DISTRIBUTION == *"rhel"* || $DISTRIBUTION == *"azurelinux"* ]]; then
    ANCHOR_DIR="/etc/pki/ca-trust/source/anchors"
    ANCHOR_FILE="${ANCHOR_DIR}/${ANCHOR_NAME}.pem"
    TRUST_BUNDLE="/etc/pki/tls/certs/ca-bundle.crt"
    update_trust() { update-ca-trust extract; }
else
    echo "Unsupported DISTRIBUTION='${DISTRIBUTION:-unset}'; refusing to install Microsoft TLS RSA Root G2 anchor."
    exit 1
fi

# Idempotency: if the base image already has the anchor, exit.
if [[ -f "${ANCHOR_FILE}" ]]; then
    echo "Microsoft TLS RSA Root G2 anchor already present at ${ANCHOR_FILE}; skipping."
    exit 0
fi

mkdir -p "${ANCHOR_DIR}"

TMP_DER="$(mktemp --suffix=.cer)"
TMP_PEM="$(mktemp --suffix=.pem)"
trap 'rm -f "${TMP_DER}" "${TMP_PEM}"' EXIT

curl -fsSL --connect-timeout 15 --retry 3 --retry-delay 5 \
    -o "${TMP_DER}" "${ROOT_URL}"

# Pin by SHA-256 of the DER encoding (== canonical X.509 fingerprint).
echo "${ROOT_SHA256}  ${TMP_DER}" | sha256sum -c -

# Normalize to PEM; both anchor layouts accept PEM-encoded certificates.
openssl x509 -inform DER -in "${TMP_DER}" -out "${TMP_PEM}"

install -m 0644 "${TMP_PEM}" "${ANCHOR_FILE}"
update_trust

# Sanity check: the new root must appear in the consolidated trust bundle.
#
# The consolidated bundle is *not* human-readable text on every distro:
#   * Ubuntu /etc/ssl/certs/ca-certificates.crt is bare concatenated PEM
#     blocks with no per-cert header lines, so a plain `grep` for the
#     Subject name never matches (the name only lives base64-encoded
#     inside the certificate body).
#   * RHEL-family /etc/pki/tls/certs/ca-bundle.crt does emit per-cert
#     comment headers, where `grep` would match -- but relying on that
#     would silently regress on Ubuntu.
#
# Walk the bundle through openssl so the check is identical on every
# supported distro: crl2pkcs7 wraps the PEM blocks into a single PKCS#7
# envelope, then `pkcs7 -print_certs -noout` renders one stable
# "subject=... issuer=..." line per certificate that we can grep.
if ! openssl crl2pkcs7 -nocrl -certfile "${TRUST_BUNDLE}" \
        | openssl pkcs7 -print_certs -noout \
        | grep -q "Microsoft TLS RSA Root G2"; then
    echo "ERROR: 'Microsoft TLS RSA Root G2' not found in consolidated trust bundle ${TRUST_BUNDLE} after installing anchor ${ANCHOR_FILE} and running update_trust." >&2
    exit 1
fi
