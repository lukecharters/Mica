#!/bin/bash
#
# Build a signed, notarized .pkg installer and .dmg disk image for Mica.
#
# The two are not equivalent, and the difference is the CLI. The .pkg runs
# pkg-scripts/postinstall, which symlinks mica-cli into /usr/local/bin; a .dmg
# is a drag-install and can run nothing, so it delivers the app alone. Anyone
# wanting mica-cli on their PATH from the .dmg has to symlink it themselves.
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
#   INSTALLER_IDENTITY  Developer ID Installer cert, signs the .pkg
#                       (default: auto-detected from keychain)
#   APP_IDENTITY        Developer ID Application cert, signs the .dmg
#                       (default: auto-detected from keychain)
#   NOTARY_PROFILE      notarytool keychain profile name (default: mica-notary)
#   SKIP_NOTARIZE       Set to 1 to build both artefacts but skip notarize+staple
#   SKIP_DMG            Set to 1 to build the .pkg only
#   BUILD_NUMBER        CFBundleVersion (default: git commit count)
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
DMG_PATH="${BUILD_DIR}/Mica.dmg"
DMG_STAGING="${BUILD_DIR}/dmg-staging"
EXPORT_OPTIONS="${PROJECT_DIR}/scripts/build-pkg/ExportOptions.plist"
PKG_SCRIPTS_DIR="${PROJECT_DIR}/scripts/build-pkg/pkg-scripts"
NOTARY_PROFILE="${NOTARY_PROFILE:-mica-notary}"

# CFBundleVersion is the commit count: monotonic, reproducible from any checkout,
# and nothing in the repo has to be edited to bump it. project.pbxproj keeps
# CURRENT_PROJECT_VERSION = 1 for local builds; only packaged builds get a real
# number, which is the only place it is user-visible (the About panel).
BUILD_NUMBER="${BUILD_NUMBER:-$(git rev-list --count HEAD 2>/dev/null || true)}"
if [[ -z "$BUILD_NUMBER" ]]; then
  echo "error: could not derive a build number from git (not a repository?)" >&2
  echo "       pass one explicitly: BUILD_NUMBER=123 $0" >&2
  exit 1
fi

# A commit count cannot describe uncommitted work, and CFBundleVersion has no
# room to say so — it must be period-separated integers. Warn rather than encode.
if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
  echo "warning: working tree is dirty; build $BUILD_NUMBER will not match its commit" >&2
fi

INSTALLER_IDENTITY="${INSTALLER_IDENTITY:-$(security find-identity -v 2>/dev/null \
  | awk -F'"' '/Developer ID Installer:.*'"$TEAM_ID"'/ {print $2; exit}')}"

if [[ -z "$INSTALLER_IDENTITY" ]]; then
  echo "error: no 'Developer ID Installer' cert for team $TEAM_ID in keychain" >&2
  echo "       install it from https://developer.apple.com/account/resources/certificates" >&2
  exit 1
fi

# A disk image is signed with Developer ID *Application*, not Installer — the
# Installer cert signs flat packages and nothing else.
if [[ "${SKIP_DMG:-0}" != "1" ]]; then
  APP_IDENTITY="${APP_IDENTITY:-$(security find-identity -v 2>/dev/null \
    | awk -F'"' '/Developer ID Application:.*'"$TEAM_ID"'/ {print $2; exit}')}"

  if [[ -z "$APP_IDENTITY" ]]; then
    echo "error: no 'Developer ID Application' cert for team $TEAM_ID in keychain" >&2
    echo "       install it from https://developer.apple.com/account/resources/certificates" >&2
    exit 1
  fi
fi

echo "==> Cleaning build directory"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "==> Archiving ($SCHEME / $CONFIGURATION, build $BUILD_NUMBER)"
xcodebuild archive \
  -project Mica.xcodeproj \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "generic/platform=macOS" \
  -archivePath "$ARCHIVE_PATH" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  -quiet

echo "==> Exporting archive (Developer ID)"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  -quiet

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
BUILT_NUMBER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_PATH/Contents/Info.plist")"

# An ignored build setting is invisible in the artefact, so check rather than assume.
if [[ "$BUILT_NUMBER" != "$BUILD_NUMBER" ]]; then
  echo "error: exported CFBundleVersion is $BUILT_NUMBER, expected $BUILD_NUMBER" >&2
  exit 1
fi

echo "==> Exported Mica $VERSION ($BUILD_NUMBER) at $APP_PATH"

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

ARTEFACTS=("$PKG_PATH")

if [[ "${SKIP_DMG:-0}" == "1" ]]; then
  echo "==> SKIP_DMG=1, skipping disk image"
else
  echo "==> Building disk image"
  rm -rf "$DMG_STAGING"
  mkdir -p "$DMG_STAGING"

  # ditto, not cp -R: it carries the extended attributes the code signature
  # lives in, so the app in the image verifies as the one that was signed.
  ditto "$APP_PATH" "$DMG_STAGING/Mica.app"
  ln -s /Applications "$DMG_STAGING/Applications"

  hdiutil create \
    -volname "Mica $VERSION" \
    -srcfolder "$DMG_STAGING" \
    -fs HFS+ \
    -format UDZO \
    -ov \
    -quiet \
    "$DMG_PATH"

  rm -rf "$DMG_STAGING"

  # The image is signed with the Application cert; the app inside keeps its own
  # signature, so this is a second, outer one rather than a replacement.
  echo "==> Signing disk image"
  codesign --sign "$APP_IDENTITY" --timestamp "$DMG_PATH"
  codesign --verify --strict --verbose=2 "$DMG_PATH"

  ARTEFACTS+=("$DMG_PATH")
fi

if [[ "${SKIP_NOTARIZE:-0}" == "1" ]]; then
  echo "==> SKIP_NOTARIZE=1, skipping notarization"
  for artefact in "${ARTEFACTS[@]}"; do
    echo "==> Done: $artefact (NOT notarized)"
  done
  exit 0
fi

# Each artefact is submitted on its own. A ticket is issued per-artefact, so
# notarizing the pkg says nothing about the dmg even though the app inside both
# is byte-identical.
for artefact in "${ARTEFACTS[@]}"; do
  echo "==> Submitting $(basename "$artefact") for notarization (profile: $NOTARY_PROFILE)"
  xcrun notarytool submit "$artefact" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait

  echo "==> Stapling notarization ticket to $(basename "$artefact")"
  xcrun stapler staple "$artefact"
  xcrun stapler validate "$artefact"
done

# Gatekeeper's own answer, which is the one a user's Mac will give. The pkg is
# judged as an installer and the dmg by the app it opens, hence two contexts.
echo "==> Verifying Gatekeeper acceptance"
spctl --assess --type install --verbose=2 "$PKG_PATH"
if [[ "${SKIP_DMG:-0}" != "1" ]]; then
  spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG_PATH"
fi

for artefact in "${ARTEFACTS[@]}"; do
  echo "==> Done: $artefact"
done
