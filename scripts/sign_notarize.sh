#!/usr/bin/env bash
#
# Sign (Developer ID), notarize, staple, and package Spacestrator.app
# into a distributable DMG.
#
# Prerequisites (one-time):
#   1. Apple Developer Program membership ($99/yr).
#   2. A "Developer ID Application" certificate in your login keychain.
#         security find-identity -v -p codesigning
#   3. A notarytool keychain profile storing your App Store Connect API key
#      or app-specific password:
#         xcrun notarytool store-credentials "WO_NOTARY" \
#            --apple-id "you@example.com" --team-id "TEAMID" --password "app-specific-pw"
#
# Usage: scripts/sign_notarize.sh <version>
#   SIGN_IDENTITY   defaults to "Developer ID Application"
#   NOTARY_PROFILE  defaults to "WO_NOTARY"
#
set -euo pipefail

VERSION="${1:?usage: sign_notarize.sh <version>}"
APP_NAME="Spacestrator"
SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Application}"
NOTARY_PROFILE="${NOTARY_PROFILE:-WO_NOTARY}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT/build"
APP="$BUILD_DIR/$APP_NAME.app"
DMG="$BUILD_DIR/$APP_NAME-$VERSION.dmg"
ENTITLEMENTS="$ROOT/Resources/Spacestrator.entitlements"

[[ -d "$APP" ]] || { echo "error: $APP not found — run scripts/build.sh $VERSION first" >&2; exit 1; }

echo "==> Codesigning with Hardened Runtime…"
codesign --force --options runtime --timestamp \
  --entitlements "$ENTITLEMENTS" \
  --sign "$SIGN_IDENTITY" \
  "$APP/Contents/MacOS/$APP_NAME"

codesign --force --options runtime --timestamp \
  --entitlements "$ENTITLEMENTS" \
  --sign "$SIGN_IDENTITY" \
  "$APP"

echo "==> Verifying signature…"
codesign --verify --deep --strict --verbose=2 "$APP"

echo "==> Building DMG…"
rm -f "$DMG"
hdiutil create -volname "$APP_NAME" -srcfolder "$APP" -ov -format UDZO "$DMG"

echo "==> Signing DMG…"
codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG"

echo "==> Submitting to Apple notary service (this can take a few minutes)…"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait

echo "==> Stapling ticket…"
xcrun stapler staple "$DMG"
xcrun stapler staple "$APP"

echo "==> Done."
SHA="$(shasum -a 256 "$DMG" | awk '{print $1}')"
echo "    DMG:    $DMG"
echo "    SHA256: $SHA"
echo
echo "Update packaging/homebrew/spacestrator.rb with:"
echo "    version \"$VERSION\""
echo "    sha256 \"$SHA\""
