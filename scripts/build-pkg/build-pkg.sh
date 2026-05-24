#!/bin/bash
#
# Build a signed, notarized .pkg installer for Mica.
#
# Prerequisites (one-time):
#   1. Install "Developer ID Application" and "Developer ID Installer" certs for
#      team SFUTCBA5VH in your login keychain (Apple Developer portal).
#   2. Store notarization credentials once:
#        xcrun notarytool store-credentials mica-notary \
#          --apple-id <your-apple-id> \
#          --team-id SFUTCBA5VH \
#          --password <app-specific-password>
#
# Usage:
#   ./scripts/build-pkg.sh
#
# Env overrides:
#   INSTALLER_IDENTITY  Full cert name (default: auto-detected from keychain)
#   NOTARY_PROFILE      notarytool keychain profile name (default: mica-notary)
#   SKIP_NOTARIZE       Set to 1 to build the .pkg but skip notarize+staple
#

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_DIR"

SCHEME="Mica"
CONFIGURATION="Release"
TEAM_ID="SFUTCBA5VH"
BUNDLE_ID_PKG="com.lukecharters.mica.pkg"
BUILD_DIR="${PROJECT_DIR}/build"
ARCHIVE_PATH="${BUILD_DIR}/Mica.xcarchive"
EXPORT_PATH="${BUILD_DIR}/export"
APP_PATH="${EXPORT_PATH}/Mica.app"
PKG_PATH="${BUILD_DIR}/Mica.pkg"
EXPORT_OPTIONS="${PROJECT_DIR}/scripts/build-pkg/ExportOptions.plist"
PKG_SCRIPTS_DIR="${PROJECT_DIR}/scripts/build-pkg/pkg-scripts"
NOTARY_PROFILE="${NOTARY_PROFILE:-mica-notary}"

INSTALLER_IDENTITY="${INSTALLER_IDENTITY:-$(security find-identity -v 2>/dev/null \
  | awk -F'"' '/Developer ID Installer:.*'"$TEAM_ID"'/ {print $2; exit}')}"

if [[ -z "$INSTALLER_IDENTITY" ]]; then
  echo "error: no 'Developer ID Installer' cert for team $TEAM_ID in keychain" >&2
  echo "       install it from https://developer.apple.com/account/resources/certificates" >&2
  exit 1
fi

echo "==> Cleaning build directory"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "==> Archiving ($SCHEME / $CONFIGURATION)"
xcodebuild archive \
  -project Mica.xcodeproj \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "generic/platform=macOS" \
  -archivePath "$ARCHIVE_PATH" \
  -quiet

echo "==> Exporting archive (Developer ID)"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  -quiet

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
echo "==> Exported Mica $VERSION at $APP_PATH"

echo "==> Verifying app signature"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
codesign --display --verbose=2 "$APP_PATH/Contents/MacOS/mica-cli" 2>&1 \
  | grep -E "Authority=Developer ID Application" > /dev/null \
  || { echo "error: mica-cli is not signed with Developer ID Application" >&2; exit 1; }

echo "==> Building installer pkg"
pkgbuild \
  --component "$APP_PATH" \
  --install-location "/Applications" \
  --scripts "$PKG_SCRIPTS_DIR" \
  --identifier "$BUNDLE_ID_PKG" \
  --version "$VERSION" \
  --sign "$INSTALLER_IDENTITY" \
  "$PKG_PATH"

echo "==> Verifying pkg signature"
pkgutil --check-signature "$PKG_PATH"

if [[ "${SKIP_NOTARIZE:-0}" == "1" ]]; then
  echo "==> SKIP_NOTARIZE=1, skipping notarization"
  echo "==> Done: $PKG_PATH (NOT notarized)"
  exit 0
fi

echo "==> Submitting for notarization (profile: $NOTARY_PROFILE)"
xcrun notarytool submit "$PKG_PATH" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait

echo "==> Stapling notarization ticket"
xcrun stapler staple "$PKG_PATH"
xcrun stapler validate "$PKG_PATH"

echo "==> Done: $PKG_PATH"
