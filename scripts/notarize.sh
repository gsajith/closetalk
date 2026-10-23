#!/bin/bash
# Notarizes the app or the DMG with Apple and staples the ticket, so it opens without "Open Anyway".
#   scripts/notarize.sh                       # build/Closetalk.app
#   scripts/notarize.sh build/Closetalk.dmg   # after scripts/package.sh
# Build with the Developer ID identity first (see scripts/build-app.sh).
# Needs the "notary" keychain profile, created once with:
#   xcrun notarytool store-credentials notary --apple-id <Apple ID> --team-id <Team ID>
set -euo pipefail
cd "$(dirname "$0")/.."

TARGET="${1:-build/Closetalk.app}"

# Apple rejects anything else, so fail before uploading. Captured first: piping codesign into
# grep -q under pipefail fails when grep exits early.
SIGNATURE=$(codesign -dvv "$TARGET" 2>&1 || true)
if ! grep -q "^Authority=Developer ID Application" <<<"$SIGNATURE"; then
  echo "$TARGET isn't signed with a Developer ID certificate. Build it with SIGN_IDENTITY set." >&2
  exit 1
fi

# notarytool takes a DMG as is, but an app has to be zipped first.
case "$TARGET" in
  *.dmg) UPLOAD="$TARGET" ;;
  *.app)
    UPLOAD=build/Closetalk-notarize.zip
    rm -f "$UPLOAD"
    ditto -c -k --keepParent "$TARGET" "$UPLOAD"
    trap 'rm -f "$UPLOAD"' EXIT
    ;;
  *)
    echo "Expected a .app or .dmg, got $TARGET" >&2
    exit 1
    ;;
esac

# --wait blocks until Apple finishes, usually a few minutes.
echo "Submitting $TARGET to Apple..."
# notarytool can exit non-zero on a rejection, so keep going and read the result either way.
RESULT=$(xcrun notarytool submit "$UPLOAD" --keychain-profile notary --wait --output-format json) || true
ID=$(plutil -extract id raw -o - - <<<"$RESULT" 2>/dev/null) || true
STATUS=$(plutil -extract status raw -o - - <<<"$RESULT" 2>/dev/null) || true

# No submission id means the upload itself failed, like a bad login or no network.
if [ -z "$ID" ]; then
  echo "Submission failed before Apple returned a submission id." >&2
  [ -n "$RESULT" ] && echo "$RESULT" >&2
  exit 1
fi
echo "Notarization $STATUS ($ID)"

if [ "$STATUS" != "Accepted" ]; then
  xcrun notarytool log "$ID" --keychain-profile notary >&2
  exit 1
fi

xcrun stapler staple "$TARGET"
