#!/usr/bin/env bash
# Builds MacVault.app into ./build (run on the Mac, from anywhere).
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"

APP="build/MacVault.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/MacVault" "$APP/Contents/MacOS/MacVault"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# Default is an ad-hoc signature (no Apple developer account needed). Set
# MACVAULT_SIGN_IDENTITY to a self-signed code-signing certificate's name to
# keep Keychain "Always Allow" working across rebuilds (see README).
codesign --force --sign "${MACVAULT_SIGN_IDENTITY:--}" --identifier local.macvault.app "$APP"

echo "Built $(pwd)/$APP"
echo "Install with:  cp -R \"$(pwd)/$APP\" /Applications/ && open /Applications/MacVault.app"
