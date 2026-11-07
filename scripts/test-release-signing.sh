#!/bin/bash
# Exercise the actual signing path on the same clean macOS runner as release jobs.
set -euo pipefail
umask 077

work=$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/clipper-sign-test.XXXXXX")
keychain_listing=$(/usr/bin/security list-keychains -d user)
cleanup() {
    local status=$?
    if [[ "$(/usr/bin/security list-keychains -d user)" != "$keychain_listing" ]]; then
        echo "Signing changed the original keychain search list." >&2
        status=1
    fi
    rm -rf "$work"
    return "$status"
}
trap cleanup EXIT

bash scripts/create-signing-identity.sh "$work/identity"
export RELEASE_CERTIFICATE_BASE64 RELEASE_CERTIFICATE_PASSWORD RELEASE_CERTIFICATE_SHA1 APP_PATH
RELEASE_CERTIFICATE_BASE64=$(cat "$work/identity/certificate-base64.txt")
RELEASE_CERTIFICATE_PASSWORD=$(cat "$work/identity/password.txt")
RELEASE_CERTIFICATE_SHA1=$(cat "$work/identity/certificate-sha1.txt")

for version in 1 2; do
    APP_PATH="$work/v$version/Clipper.app"
    mkdir -p "$APP_PATH/Contents/MacOS"
    cat > "$APP_PATH/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>io.github.ahmedamoniem.clipper</string>
<key>CFBundleExecutable</key><string>Clipper</string>
<key>CFBundleVersion</key><string>$version</string>
<key>CFBundlePackageType</key><string>APPL</string>
</dict></plist>
EOF
    printf 'int main(void) { return %s; }\n' "$version" > "$work/version.c"
    /usr/bin/xcrun clang -arch arm64 -arch x86_64 "$work/version.c" \
        -o "$APP_PATH/Contents/MacOS/Clipper"
    bash scripts/sign-release.sh
done

/usr/bin/codesign --display -r "$work/old.requirements" "$work/v1/Clipper.app"
sed 's/^designated => //' "$work/old.requirements" > "$work/identity.requirement"
/usr/bin/codesign --verify --deep --strict --all-architectures \
    -R "$work/identity.requirement" "$APP_PATH"

if RELEASE_CERTIFICATE_SHA1=0000000000000000000000000000000000000000 \
    bash scripts/sign-release.sh > "$work/wrong-identity.log" 2>&1; then
    echo "Signing unexpectedly accepted a different certificate fingerprint." >&2
    exit 1
fi
if RELEASE_CERTIFICATE_BASE64= bash scripts/sign-release.sh > "$work/missing-identity.log" 2>&1; then
    echo "Signing unexpectedly accepted missing certificate data." >&2
    exit 1
fi
/usr/bin/codesign --verify --deep --strict --all-architectures \
    -R "$work/identity.requirement" "$APP_PATH"
echo "Release signing passed: stable identity across builds and rejection of invalid configuration."
