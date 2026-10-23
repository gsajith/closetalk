#!/bin/bash
# Builds build/Closetalk.app and signs it with hardened runtime.
# SIGN_IDENTITY picks the certificate. Release builds pass the Developer ID one:
#   SIGN_IDENTITY="Developer ID Application: Gautham Sajith (843324F58U)" scripts/build-app.sh
# Without it, the build uses the self-signed "Closetalk Dev" identity, which anyone can create.
set -euo pipefail
cd "$(dirname "$0")/.."

IDENTITY="${SIGN_IDENTITY:-Closetalk Dev}"
SPARKLE_IDENTITY="$IDENTITY"
TIMESTAMP=""
ENTITLEMENTS=Resources/Closetalk.entitlements
if [ "$IDENTITY" = "Closetalk Dev" ]; then
  # Creates the signing identity on first run; does nothing after that.
  scripts/make-cert.sh
  # A self-signed certificate has no Apple Team ID, which two checks rely on. Sparkle's installer
  # only launches helpers that are ad-hoc signed or share the app's Team ID, so dev builds sign
  # Sparkle ad-hoc. Hardened runtime only loads frameworks from the app's Team ID, so dev builds
  # turn that check off. Release builds keep both.
  SPARKLE_IDENTITY="-"
  ENTITLEMENTS=$(mktemp)
  trap 'rm -f "$ENTITLEMENTS"' EXIT
  cp Resources/Closetalk.entitlements "$ENTITLEMENTS"
  /usr/libexec/PlistBuddy -c "Add :com.apple.security.cs.disable-library-validation bool true" "$ENTITLEMENTS"
elif [[ "$IDENTITY" == "Developer ID Application"* ]]; then
  # Notarization requires a secure timestamp from Apple.
  TIMESTAMP="--timestamp"
fi

swift build -c release
BIN=$(swift build -c release --show-bin-path)

APP=build/Closetalk.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp "$BIN/Closetalk" "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"

# App icon: assets/icon.png (rendered from assets/src/icon.html) at every size macOS asks for.
ICONSET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
  sips -z "$s" "$s" assets/icon.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s * 2)) $((s * 2)) assets/icon.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

# Sparkle ships as a framework. SwiftPM links it with an rpath next to the binary, so add the
# bundle's Frameworks folder too.
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework"
ditto "$BIN/Sparkle.framework" "$SPARKLE"
# Its XPC services are only used by sandboxed apps, and Closetalk isn't sandboxed.
rm -rf "$SPARKLE/Versions/B/XPCServices" "$SPARKLE/XPCServices"
install_name_tool -add_rpath @executable_path/../Frameworks "$APP/Contents/MacOS/Closetalk"

# Hardened runtime is required for notarization. It blocks the mic unless the entitlement is declared.
# No --deep, so nested code is signed inside-out: Sparkle's helpers, the framework, then the app.
sign() { codesign --force --options runtime $TIMESTAMP "$@"; }
sign --sign "$SPARKLE_IDENTITY" "$SPARKLE/Versions/B/Autoupdate"
sign --sign "$SPARKLE_IDENTITY" "$SPARKLE/Versions/B/Updater.app"
sign --sign "$SPARKLE_IDENTITY" "$SPARKLE"
sign --sign "$IDENTITY" --entitlements "$ENTITLEMENTS" "$APP"
echo "Built $APP, signed by $IDENTITY"
