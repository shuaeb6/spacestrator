#!/usr/bin/env bash
#
# Convert Resources/icon-1024.png into Resources/AppIcon.icns (macOS only).
# Regenerate the source PNG first with:  python3 scripts/make_icon.py
#
# Usage: scripts/make_icon.sh [path-to-1024px-png]
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${1:-$ROOT/Resources/icon-1024.png}"
OUT="$ROOT/Resources/AppIcon.icns"
ICONSET="$(mktemp -d)/AppIcon.iconset"

command -v sips >/dev/null     || { echo "sips not found (macOS only)" >&2; exit 1; }
command -v iconutil >/dev/null || { echo "iconutil not found (macOS only)" >&2; exit 1; }
[[ -f "$SRC" ]] || { echo "source image not found: $SRC" >&2; exit 1; }

mkdir -p "$ICONSET"

# Apple's required iconset sizes (1x and 2x).
gen() { sips -z "$2" "$2" "$SRC" --out "$ICONSET/icon_$1.png" >/dev/null; }
gen 16x16        16
gen 16x16@2x     32
gen 32x32        32
gen 32x32@2x     64
gen 128x128     128
gen 128x128@2x  256
gen 256x256     256
gen 256x256@2x  512
gen 512x512     512
gen 512x512@2x 1024

iconutil -c icns "$ICONSET" -o "$OUT"
echo "Wrote $OUT"
echo "scripts/build.sh will now embed it automatically."
