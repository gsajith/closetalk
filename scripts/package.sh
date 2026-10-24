#!/bin/bash
# Packages build/Closetalk.app into build/Closetalk.dmg (drag-to-install) and build/Closetalk.zip.
# For a release, notarize the app first so both packages carry the stapled ticket.
# The DMG is signed with the same identity as the app. Its Finder window (background, icon spots,
# volume icon) comes from scripts/dmg-settings.py through dmgbuild, which runs with uv.
set -euo pipefail
cd "$(dirname "$0")/.."

APP=build/Closetalk.app
DMG=build/Closetalk.dmg
ZIP=build/Closetalk.zip

command -v uvx >/dev/null || { echo "Packaging needs uv for dmgbuild: brew install uv" >&2; exit 1; }
if [ ! -d "$APP" ]; then
  echo "$APP doesn't exist. Run scripts/build-app.sh first." >&2
  exit 1
fi

# The first Authority line is the signing certificate's name. Captured first: piping codesign
# into a reader that exits early fails under pipefail.
SIGNATURE=$(codesign -dvv "$APP" 2>&1 || true)
IDENTITY=$(sed -n '/^Authority=/{s///p;q;}' <<<"$SIGNATURE")
if [ -z "$IDENTITY" ]; then
  echo "$APP isn't signed. Run scripts/build-app.sh first." >&2
  exit 1
fi
TIMESTAMP=""
if [[ "$IDENTITY" == "Developer ID Application"* ]]; then
  TIMESTAMP="--timestamp"
  # Without the stapled ticket, the app in the DMG and zip only passes Gatekeeper online.
  if ! xcrun stapler validate -q "$APP"; then
    echo "$APP isn't notarized yet. Run scripts/notarize.sh first." >&2
    exit 1
  fi
fi

# The volume is named Closetalk.dmg so the mounted disk on the desktop doesn't read as the app itself.
# The background ships at 2x (assets/dmg-background.png). Finder wants a TIFF holding both sizes.
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
sips -z 420 660 assets/dmg-background.png --out "$TMP/background.png" >/dev/null
tiffutil -cathidpicheck "$TMP/background.png" assets/dmg-background.png -out "$TMP/background.tiff" 2>/dev/null

rm -f "$DMG"
uvx --quiet dmgbuild@1.6.7 -s scripts/dmg-settings.py -D app="$APP" -D background="$TMP/background.tiff" \
  -D icon="$APP/Contents/Resources/AppIcon.icns" Closetalk.dmg "$DMG" 2>&1 | grep -v "is deprecated" || true
[ -f "$DMG" ] || { echo "dmgbuild didn't create $DMG." >&2; exit 1; }
codesign --force --sign "$IDENTITY" $TIMESTAMP "$DMG"

rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "Packaged $DMG and $ZIP, signed by $IDENTITY"
