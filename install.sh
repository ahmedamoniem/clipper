#!/bin/bash
set -e

echo "🚀 Starting Clipper Remote Installer..."

# 1. Fetch latest release info from GitHub API
echo "🔍 Fetching latest release information..."
LATEST_RELEASE_JSON=$(curl -s https://api.github.com/repos/ahmedamoniem/clipper/releases/latest)
LATEST_VERSION=$(echo "$LATEST_RELEASE_JSON" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

if [ -z "$LATEST_VERSION" ]; then
    echo "❌ Could not determine latest version. Falling back to v1.0.40 (or your requested version)..."
    LATEST_VERSION="v1.0.40"
fi

echo "📦 Latest version detected: $LATEST_VERSION"

# Construct the download URL for the ZIP asset
# Note: The release.yml names it Clipper-v1.0.X-macOS.zip
ZIP_NAME="Clipper-${LATEST_VERSION}-macOS.zip"
ZIP_URL="https://github.com/ahmedamoniem/clipper/releases/download/${LATEST_VERSION}/${ZIP_NAME}"

TEMP_DIR=$(mktemp -d)

echo "📥 Downloading Clipper from $ZIP_URL..."
if ! curl -L "$ZIP_URL" -o "$TEMP_DIR/Clipper_macOS.zip"; then
    echo "❌ Download failed. Please check if version $LATEST_VERSION is released."
    exit 1
fi

# 2. Extract
echo "📦 Extracting..."
unzip -q "$TEMP_DIR/Clipper_macOS.zip" -d "$TEMP_DIR"

# 3. Move to Applications
echo "📂 Moving Clipper to /Applications (may ask for password)..."
# The zip contains Clipper.app directly (using ditto --keepParent)
sudo cp -R "$TEMP_DIR/Clipper.app" /Applications/

# 4. Bypass Gatekeeper
echo "🔓 Removing quarantine flags..."
sudo xattr -cr /Applications/Clipper.app

echo "✅ Installation Complete!"
echo "------------------------------------------------"
echo "👉 1. Clipper is now in your Applications folder."
echo "👉 2. Open it and grant Accessibility permissions in System Settings."
echo "------------------------------------------------"

# 5. Cleanup
rm -rf "$TEMP_DIR"

# 6. Open the app
open /Applications/Clipper.app
