#!/bin/bash
# Renders assets/src/*.html to assets/ images with headless Chrome.
# A page sets its size with <meta name="render" content="WIDTHxHEIGHT@SCALE">; the default is
# 1280x640@2, the README cover at 2x for sharp text on GitHub. Transparent pages stay transparent.
# <meta name="render-format" content="jpg"> saves a JPEG instead, for opaque art that PNG can't compress.
set -euo pipefail
cd "$(dirname "$0")/.."
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
for src in assets/src/*.html; do
  name=$(basename "$src" .html)
  spec=$(grep -o 'name="render" content="[^"]*"' "$src" | sed 's/.*content="\(.*\)"/\1/' || true)
  spec=${spec:-1280x640@2}
  size=${spec%@*}
  # The time budget lets web fonts and images load before the screenshot.
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --default-background-color=00000000 \
    --force-device-scale-factor="${spec#*@}" --window-size="${size/x/,}" --virtual-time-budget=5000 \
    --screenshot="$PWD/assets/$name.png" "file://$PWD/$src" 2>/dev/null
  if grep -q 'name="render-format" content="jpg"' "$src"; then
    sips -s format jpeg -s formatOptions 85 "assets/$name.png" --out "assets/$name.jpg" >/dev/null
    rm "assets/$name.png"
    echo "assets/$name.jpg"
  else
    echo "assets/$name.png"
  fi
done
