#!/bin/bash
# Notarizes build/Closetalk.app with Apple and staples the ticket, so it opens without "Open Anyway".
# Build it with the Developer ID identity first (see scripts/build-app.sh).
# Needs the "notary" keychain profile, created once with:
#   xcrun notarytool store-credentials notary --apple-id <Apple ID> --team-id <Team ID>
set -euo pipefail
cd "$(dirname "$0")/.."

APP=build/Closetalk.app
ZIP=build/Closetalk-notarize.zip

# Apple rejects anything else, so fail before uploading. Captured first: piping codesign into
# grep -q under pipefail fails when grep exits early.
SIGNATURE=$(codesign -dvv "$APP" 2>&1 || true)
if ! grep -q "^Authority=Developer ID Application" <<<"$SIGNATURE"; then
  echo "$APP isn't signed with a Developer ID certificate. Build it with SIGN_IDENTITY set." >&2
  exit 1
fi

rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
trap 'rm -f "$ZIP"' EXIT

# --wait blocks until Apple finishes, usually a few minutes.
echo "Submitting to Apple..."
RESULT=$(xcrun notarytool submit "$ZIP" --keychain-profile notary --wait --output-format json)
ID=$(plutil -extract id raw -o - - <<<"$RESULT")
STATUS=$(plutil -extract status raw -o - - <<<"$RESULT")
echo "Notarization $STATUS ($ID)"

if [ "$STATUS" != "Accepted" ]; then
  xcrun notarytool log "$ID" --keychain-profile notary >&2
  exit 1
fi

xcrun stapler staple "$APP"
