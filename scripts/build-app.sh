#!/bin/bash
# Builds build/Closetalk.app and signs it with hardened runtime.
# SIGN_IDENTITY picks the certificate. Release builds pass the Developer ID one:
#   SIGN_IDENTITY="Developer ID Application: Gautham Sajith (843324F58U)" scripts/build-app.sh
# Without it, the build uses the self-signed "Closetalk Dev" identity, which anyone can create.
set -euo pipefail
cd "$(dirname "$0")/.."

IDENTITY="${SIGN_IDENTITY:-Closetalk Dev}"
TIMESTAMP=""
if [ "$IDENTITY" = "Closetalk Dev" ]; then
  # Creates the signing identity on first run; does nothing after that.
  scripts/make-cert.sh
elif [[ "$IDENTITY" == "Developer ID Application"* ]]; then
  # Notarization requires a secure timestamp from Apple.
  TIMESTAMP="--timestamp"
fi

swift build -c release
BIN=$(swift build -c release --show-bin-path)

APP=build/Closetalk.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/Closetalk" "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"

# Hardened runtime is required for notarization. It blocks the mic unless the entitlement is declared.
# No --deep: the bundle has a single executable and no nested code.
codesign --force --options runtime --entitlements Resources/Closetalk.entitlements $TIMESTAMP \
  --sign "$IDENTITY" "$APP"
echo "Built $APP, signed by $IDENTITY"
