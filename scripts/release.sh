#!/bin/bash
# Cuts a release from main: builds with the Developer ID, notarizes the app and DMG, adds the update
# to updates/appcast.xml and creates a draft GitHub release to review before publishing.
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
  fail "Release v$VERSION already exists."
fi
# Sparkle compares the build number, so a release that reuses one would never be offered.
if [ -f "$APPCAST" ] && grep -q "<sparkle:version>$BUILD</sparkle:version>" "$APPCAST"; then
  fail "Build $BUILD is already in $APPCAST. Bump CFBundleVersion through a PR first."
fi

echo "Releasing Closetalk $VERSION (build $BUILD) from $(git rev-parse --short HEAD)"
scripts/build-app.sh
scripts/notarize.sh
scripts/package.sh
scripts/notarize.sh build/Closetalk.dmg
spctl -a -t open --context context:primary-signature build/Closetalk.dmg

mkdir -p updates
cp build/Closetalk.zip "updates/Closetalk-$VERSION.zip"
.build/artifacts/sparkle/Sparkle/bin/generate_appcast updates

gh release create "v$VERSION" build/Closetalk.dmg build/Closetalk.zip --draft \
  --target "$(git rev-parse HEAD)" --title "Closetalk $VERSION" --generate-notes

cat <<EOF

Draft release v$VERSION is ready. Review its notes on GitHub, then publish it.
Then upload these from updates/ to the root of closetalk.dev:
$(cd updates && ls -1 | grep -v '^old_updates$' | sed 's/^/  /')
EOF
