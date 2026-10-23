#!/bin/bash
# Cuts a release from main: builds with the Developer ID, notarizes the app and DMG, creates a draft
# GitHub release to review before publishing, then adds the update to updates/appcast.xml.
#   scripts/release.sh 1.1
# Bump CFBundleShortVersionString and CFBundleVersion in Resources/Info.plist through a PR first.
# SIGN_IDENTITY overrides the signing certificate. ALLOW_BRANCH=1 skips the main-branch check, for
# testing this script on a branch.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?Usage: scripts/release.sh <version>}"
export SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Application: Gautham Sajith (843324F58U)}"
PLIST=Resources/Info.plist
APPCAST=updates/appcast.xml

fail() { echo "$1" >&2; exit 1; }

# Checked first: otherwise a gh login problem would only show up after the build and notarization.
gh auth status >/dev/null 2>&1 || fail "gh isn't logged in. Run gh auth login first."

# The release has to match a commit on GitHub, so build only a clean, pushed checkout.
if [ "${ALLOW_BRANCH:-}" != 1 ] && [ "$(git branch --show-current)" != main ]; then
  fail "Releases come from main. Switch to main first."
fi
[ -z "$(git status --porcelain)" ] || fail "The working tree has uncommitted changes."
git fetch --quiet origin
UPSTREAM=$(git rev-parse '@{upstream}' 2>/dev/null) || fail "This branch isn't pushed. Push it first."
[ "$(git rev-parse HEAD)" = "$UPSTREAM" ] || fail "This branch doesn't match its upstream. Push or pull first."

SHORT_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST")
BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST")
[ "$SHORT_VERSION" = "$VERSION" ] ||
  fail "$PLIST says version $SHORT_VERSION, not $VERSION. Bump it through a PR first."
if gh release view "v$VERSION" >/dev/null 2>&1; then
  fail "Release v$VERSION already exists. If it's a draft left by a failed run, delete it with
gh release delete v$VERSION and run this again."
fi
# Sparkle only offers an update with a higher build number than the installed one. A plain integer
# keeps that comparison simple.
[[ "$BUILD" =~ ^[0-9]+$ ]] || fail "CFBundleVersion is $BUILD. Use a whole number, like 2."
if [ -f "$APPCAST" ]; then
  LATEST=$(sed -n 's|.*<sparkle:version>\([0-9]*\)</sparkle:version>.*|\1|p' "$APPCAST" | sort -n | tail -1)
  if [ -n "$LATEST" ] && [ "$BUILD" -le "$LATEST" ]; then
    fail "Build $BUILD isn't higher than build $LATEST in $APPCAST. Bump CFBundleVersion through a PR first."
  fi
fi

echo "Releasing Closetalk $VERSION (build $BUILD) from $(git rev-parse --short HEAD)"
scripts/build-app.sh
scripts/notarize.sh
scripts/package.sh
scripts/notarize.sh build/Closetalk.dmg
spctl -a -t open --context context:primary-signature build/Closetalk.dmg

# The draft comes before the feed: if the feed step fails, deleting the draft is enough to retry.
# The other way round, a failed upload would leave a feed entry that blocks the next run.
gh release create "v$VERSION" build/Closetalk.dmg build/Closetalk.zip --draft \
  --target "$(git rev-parse HEAD)" --title "Closetalk $VERSION" --generate-notes

mkdir -p updates
cp build/Closetalk.zip "updates/Closetalk-$VERSION.zip"
.build/artifacts/sparkle/Sparkle/bin/generate_appcast updates

cat <<EOF

Draft release v$VERSION is ready. Review its notes on GitHub, then publish it.
Then upload these from updates/ to the root of closetalk.dev:
$(cd updates && ls -1 | grep -v '^old_updates$' | sed 's/^/  /')
EOF
