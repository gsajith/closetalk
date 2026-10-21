#!/bin/bash
# Builds build/LocalWhisper.app and signs it with the "LocalWhisper Dev" identity (see make-cert.sh).
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
BIN=$(swift build -c release --show-bin-path)

APP=build/LocalWhisper.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/LocalWhisper" "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"
# SwiftPM resource bundles from dependencies, if any.
find "$BIN" -maxdepth 1 -name '*.bundle' -exec cp -R {} "$APP/Contents/Resources/" \;

codesign --force --deep --sign "LocalWhisper Dev" "$APP"
echo "Built $APP"
