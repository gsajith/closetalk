#!/bin/bash
# Builds build/Closetalk.app and signs it with the "Closetalk Dev" identity and hardened runtime.
set -euo pipefail
cd "$(dirname "$0")/.."

# Creates the signing identity on first run; does nothing after that.
scripts/make-cert.sh

swift build -c release
BIN=$(swift build -c release --show-bin-path)

APP=build/Closetalk.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/Closetalk" "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"

# Hardened runtime is required for notarization. It blocks the mic unless the entitlement is declared.
codesign --force --deep --options runtime --entitlements Resources/Closetalk.entitlements \
  --sign "Closetalk Dev" "$APP"
echo "Built $APP"
