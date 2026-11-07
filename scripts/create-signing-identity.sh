#!/bin/bash
# Create once, then keep the same identity for every release.
set -euo pipefail
umask 077

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 /absolute/path/to/new-private-directory" >&2
    exit 1
fi

output=$1
[[ "$output" = /* ]] || { echo "Use an absolute output path." >&2; exit 1; }
mkdir -m 700 "$output" # Refuse to overwrite an existing identity.
work=$(mktemp -d "${TMPDIR:-/tmp}/clipper-certificate.XXXXXX")
trap 'rm -rf "$work"' EXIT

/usr/bin/openssl rand -base64 48 > "$output/password.txt"
cp "$output/password.txt" "$work/key-password.txt"
cat > "$work/certificate.conf" <<'EOF'
[req]
distinguished_name = subject
x509_extensions = extensions
prompt = no
[subject]
CN = Clipper Release Signing
[extensions]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
subjectKeyIdentifier = hash
EOF

/usr/bin/openssl genrsa -aes256 -passout "file:$work/key-password.txt" \
    -out "$work/private-key.pem" 3072
/usr/bin/openssl req -new -x509 -sha256 -days 3650 \
    -key "$work/private-key.pem" -passin "file:$work/key-password.txt" \
    -config "$work/certificate.conf" -out "$output/certificate.pem"
/usr/bin/openssl pkcs12 -export -name "Clipper Release Signing" \
    -inkey "$work/private-key.pem" -passin "file:$work/key-password.txt" \
    -in "$output/certificate.pem" -passout "file:$output/password.txt" \
    -out "$output/clipper-signing.p12"
/usr/bin/base64 -i "$output/clipper-signing.p12" > "$output/certificate-base64.txt"
/usr/bin/openssl x509 -in "$output/certificate.pem" -noout -fingerprint -sha1 \
    | sed 's/.*=//; s/://g' > "$output/certificate-sha1.txt"
echo "Created signing identity in $output. Back up this directory privately; never commit it."
