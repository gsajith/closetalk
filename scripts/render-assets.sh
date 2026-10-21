#!/bin/bash
# Renders assets/src/*.html to assets/*.png with headless Chrome (1280x640, 2x for sharp text on GitHub).
set -euo pipefail
cd "$(dirname "$0")/.."
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
for src in assets/src/*.html; do
  name=$(basename "$src" .html)
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=2 \
    --window-size=1280,640 --screenshot="$PWD/assets/$name.png" "file://$PWD/$src" 2>/dev/null
  echo "assets/$name.png"
done
