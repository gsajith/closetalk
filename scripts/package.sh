#!/bin/bash
# Packages build/Closetalk.app into build/Closetalk.dmg (drag-to-install) and build/Closetalk.zip.
# For a release, notarize the app first so both packages carry the stapled ticket.
# The DMG is signed with the same identity as the app.
set -euo pipefail
cd "$(dirname "$0")/.."

APP=build/Closetalk.app
DMG=build/Closetalk.dmg
ZIP=build/Closetalk.zip

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

STAGING=$(mktemp -d)
trap 'rm -rf "$STAGING"' EXIT
ditto "$APP" "$STAGING/Closetalk.app"
ln -s /Applications "$STAGING/Applications"

hdiutil create -volname Closetalk -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null
codesign --force --sign "$IDENTITY" $TIMESTAMP "$DMG"

rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "Packaged $DMG and $ZIP, signed by $IDENTITY"
