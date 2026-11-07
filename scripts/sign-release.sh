#!/bin/bash
# Import a persistent certificate into an isolated keychain and sign the finished app.
set -euo pipefail
umask 077

: "${APP_PATH:?Set APP_PATH to the built Clipper.app}"
: "${RELEASE_CERTIFICATE_BASE64:?Set the RELEASE_CERTIFICATE_BASE64 secret}"
: "${RELEASE_CERTIFICATE_PASSWORD:?Set the RELEASE_CERTIFICATE_PASSWORD secret}"
: "${RELEASE_CERTIFICATE_SHA1:?Set the RELEASE_CERTIFICATE_SHA1 repository variable}"
[[ "$RELEASE_CERTIFICATE_SHA1" =~ ^[[:xdigit:]]{40}$ ]] || {
    echo "RELEASE_CERTIFICATE_SHA1 must be the certificate's 40-character SHA-1 fingerprint." >&2
    exit 1
}
[[ -d "$APP_PATH" ]] || { echo "App bundle not found: $APP_PATH" >&2; exit 1; }
bundle_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Contents/Info.plist")
[[ "$bundle_id" = io.github.ahmedamoniem.clipper ]] || {
    echo "Refusing to sign an unexpected bundle identifier: $bundle_id" >&2
    exit 1
}

work=$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/clipper-sign.XXXXXX")
keychain="$work/signing.keychain-db"
cleanup() {
    /usr/bin/security delete-keychain "$keychain" >/dev/null 2>&1 || true
    rm -rf "$work"
}
trap cleanup EXIT
keychain_password=$(/usr/bin/openssl rand -base64 48)
printf '%s' "$RELEASE_CERTIFICATE_BASE64" | /usr/bin/base64 --decode > "$work/certificate.p12"
/usr/bin/security create-keychain -p "$keychain_password" "$keychain"
/usr/bin/security set-keychain-settings -lut 3600 "$keychain"
/usr/bin/security unlock-keychain -p "$keychain_password" "$keychain"
/usr/bin/security import "$work/certificate.p12" -k "$keychain" \
    -P "$RELEASE_CERTIFICATE_PASSWORD" -T /usr/bin/codesign >/dev/null
/usr/bin/security set-key-partition-list -S apple-tool:,apple:,codesign: \
    -s -k "$keychain_password" "$keychain" >/dev/null

# The certificate anchors the default designated requirement across different builds.
# No custom identifier-only requirement or system trust changes are needed.
/usr/bin/codesign --force --sign "$RELEASE_CERTIFICATE_SHA1" --keychain "$keychain" \
    --options runtime --timestamp=none "$APP_PATH"
/usr/bin/codesign --verify --deep --strict --all-architectures \
    -R="identifier \"$bundle_id\" and certificate leaf = H\"$RELEASE_CERTIFICATE_SHA1\"" "$APP_PATH"
/usr/bin/codesign --display -r- "$APP_PATH"
