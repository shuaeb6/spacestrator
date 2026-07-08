#!/usr/bin/env bash
#
# Build Spacestrator.app from the Swift package.
# Produces: build/Spacestrator.app
#
# Usage: scripts/build.sh [version]
#
set -euo pipefail

VERSION="${1:-0.1.0}"
APP_NAME="Spacestrator"
BUNDLE_ID="com.example.spacestrator"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BUILD_DIR="$ROOT/build"
APP="$BUILD_DIR/$APP_NAME.app"

echo "==> Compiling (release, arm64 + x86_64 universal)…"
swift build -c release --arch arm64 --arch x86_64

BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/$APP_NAME"
if [[ ! -f "$BIN" ]]; then
  echo "error: built binary not found at $BIN" >&2
  exit 1
fi

echo "==> Assembling app bundle…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"

sed -e "s/__VERSION__/$VERSION/g" \
    "$ROOT/Resources/Info.plist.template" > "$APP/Contents/Info.plist"

# Optional icon: drop Resources/AppIcon.icns to include it.
if [[ -f "$ROOT/Resources/AppIcon.icns" ]]; then
  cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
  /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" \
    "$APP/Contents/Info.plist" 2>/dev/null || true
fi

echo "==> Built: $APP"
echo "    Run locally (dev, unsigned):  open \"$APP\""
echo "    To distribute, run:           scripts/sign_notarize.sh $VERSION"
