#!/bin/bash
# Cuts a release from main: builds with the Developer ID, notarizes the app and DMG, creates a draft
# GitHub release to review before publishing, then adds the update to the site's appcast. Sparkle
# downloads the update from the GitHub release. Publish the release, then merge the appcast change
# through a PR to put the update live on closetalk.dev.
#   scripts/release.sh 1.1
# Bump CFBundleShortVersionString and CFBundleVersion in Resources/Info.plist through a PR first.
# SIGN_IDENTITY overrides the signing certificate. ALLOW_BRANCH=1 skips the main-branch check, for
# testing this script on a branch.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?Usage: scripts/release.sh <version>}"
export SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Application: Gautham Sajith (843324F58U)}"
PLIST=Resources/Info.plist
# The Sparkle feed lives with the site, so closetalk.dev serves it from its root.
APPCAST=site/public/appcast.xml
DOWNLOADS=https://github.com/gsajith/closetalk/releases/download

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
LATEST=$(sed -n 's|.*<sparkle:version>\([0-9]*\)</sparkle:version>.*|\1|p' "$APPCAST" | sort -n | tail -1)
if [ -n "$LATEST" ] && [ "$BUILD" -le "$LATEST" ]; then
  fail "Build $BUILD isn't higher than build $LATEST in $APPCAST. Bump CFBundleVersion through a PR first."
fi

echo "Releasing Closetalk $VERSION (build $BUILD) from $(git rev-parse --short HEAD)"
scripts/build-app.sh
scripts/notarize.sh
scripts/package.sh
scripts/notarize.sh build/Closetalk.dmg
spctl -a -t open --context context:primary-signature build/Closetalk.dmg

# The draft comes before the feed: if the feed step fails, deleting the draft is enough to retry.
# The other way round, a leftover feed entry would block the next run.
gh release create "v$VERSION" build/Closetalk.dmg build/Closetalk.zip --draft \
  --target "$(git rev-parse HEAD)" --title "Closetalk $VERSION" --generate-notes

# generate_appcast signs the zip and adds only this build to the feed. Earlier entries keep the
# download URL of their own release.
UPDATES=$(mktemp -d)
trap 'rm -rf "$UPDATES"' EXIT
cp build/Closetalk.zip "$APPCAST" "$UPDATES/"
.build/artifacts/sparkle/Sparkle/bin/generate_appcast "$UPDATES" --versions "$BUILD" \
  --download-url-prefix "$DOWNLOADS/v$VERSION/"
cp "$UPDATES/appcast.xml" "$APPCAST"

cat <<EOF

Draft release v$VERSION is ready. Review its notes on GitHub, then publish it.
Then merge the $APPCAST change through a PR, which deploys it to closetalk.dev.
Publish first: the feed links to the release's Closetalk.zip, which isn't public while it's a draft.
EOF
