#!/usr/bin/env bash
# Create a STABLE self-signed code-signing identity in the login keychain, once.
#
# Why: an ad-hoc signature (`codesign -s -`) gets a fresh code hash on every build, so macOS
# invalidates the Accessibility (TCC) grant each rebuild — the toggle looks ON in System
# Settings but AXIsProcessTrusted() returns false. Signing with a stable identity means TCC
# keys the grant on the certificate (the "designated requirement"), so it survives rebuilds.
#
# This certificate is self-signed and NOT notarized — it does not help Gatekeeper; it only
# stabilizes the code-signing identity so the permission sticks. Run once.
set -euo pipefail

IDENTITY="Monitor Glue Self-Signed"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-identity 2>/dev/null | grep -q "$IDENTITY"; then
    echo "==> Identity '$IDENTITY' already exists. Nothing to do."
    exit 0
fi

P12PASS="mgtemp"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "==> Generating self-signed code-signing certificate…"
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -keyout "$TMP/key.pem" -out "$TMP/cert.pem" \
    -subj "/CN=$IDENTITY" \
    -addext "basicConstraints=critical,CA:FALSE" \
    -addext "keyUsage=critical,digitalSignature" \
    -addext "extendedKeyUsage=critical,codeSigning" >/dev/null 2>&1

# -legacy + -macalg sha1 + a non-empty password: required for macOS `security import` to
# accept an OpenSSL 3 PKCS#12 bundle.
openssl pkcs12 -export -legacy -macalg sha1 -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
    -out "$TMP/id.p12" -passout "pass:$P12PASS" -name "$IDENTITY" >/dev/null 2>&1

echo "==> Importing into login keychain (allow codesign to use the key)…"
security import "$TMP/id.p12" -k "$KEYCHAIN" -P "$P12PASS" \
    -T /usr/bin/codesign -T /usr/bin/security >/dev/null 2>&1

# Let codesign access the private key without an interactive prompt on each build.
# (codesign does not require the cert to be *trusted* to sign — only present with the
#  codeSigning EKU — so no admin/trust prompt is needed.)
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "" "$KEYCHAIN" >/dev/null 2>&1 || true

if security find-identity 2>/dev/null | grep -q "$IDENTITY"; then
    echo "==> Success. '$IDENTITY' is ready. Rebuild with Scripts/bundle.sh."
else
    echo "==> Warning: identity not found; bundle.sh will fall back to ad-hoc." >&2
    exit 1
fi
