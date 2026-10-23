#!/bin/bash
# Creates a self-signed code signing certificate named "Closetalk Dev" in the login keychain.
# Signing every build with the same identity lets macOS remember the Accessibility grant across rebuilds.
# Safe to run more than once.
set -euo pipefail

NAME="Closetalk Dev"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

# No -v: the certificate is untrusted, which codesign accepts.
if security find-identity -p codesigning | grep -q "\"$NAME\""; then
  echo "Signing identity \"$NAME\" already exists."
  exit 0
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/cert.cnf" <<CNF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
CNF

# /usr/bin/openssl is LibreSSL, whose PKCS#12 output the macOS keychain can import.
/usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -config "$TMP/cert.cnf" -keyout "$TMP/key.pem" -out "$TMP/cert.pem"
/usr/bin/openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
  -name "$NAME" -passout pass:closetalk -out "$TMP/cert.p12"

# -T lets codesign use the key without a keychain prompt.
security import "$TMP/cert.p12" -k "$KEYCHAIN" -P closetalk -T /usr/bin/codesign

echo "Created signing identity \"$NAME\"."
