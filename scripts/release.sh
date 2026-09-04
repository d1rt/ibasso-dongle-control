#!/bin/bash

set -euo pipefail

VERSION="${VERSION:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
APP_NAME="Dongle Control for iBasso"
ASSET_BASENAME="Dongle-Control-for-iBasso-v${VERSION}"
SCHEME="Dongle Control for iBasso"
PROJECT="IBassoDongleControl.xcodeproj"
BUNDLE_ID="app.donglecontrol.mac"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
DMG_PATH="$DIST_DIR/${ASSET_BASENAME}.dmg"
ZIP_PATH="$DIST_DIR/${ASSET_BASENAME}.zip"
CHECKSUM_PATH="$DIST_DIR/SHA256SUMS.txt"
WORK_DIR="$(mktemp -d /private/tmp/ibasso-dongle-release.XXXXXX)"
DERIVED_DATA="$WORK_DIR/DerivedData"
STAGING_DIR="$WORK_DIR/dmg-root"
mkdir -p "$STAGING_DIR"

cleanup() {
    case "$WORK_DIR" in
        /private/tmp/ibasso-dongle-release.*) rm -rf "$WORK_DIR" ;;
        *) echo "Refusing to remove unexpected work path: $WORK_DIR" >&2 ;;
    esac
}
trap cleanup EXIT

expect_equal() {
    local label="$1"
    local actual="$2"
    local expected="$3"
    if [[ "$actual" != "$expected" ]]; then
        echo "$label mismatch: expected '$expected', got '$actual'" >&2
        exit 1
    fi
}

echo "==> Cleaning release outputs"
mkdir -p "$DIST_DIR"
rm -f "$DMG_PATH" "$ZIP_PATH" "$CHECKSUM_PATH"

echo "==> Running tests"
(cd "$ROOT_DIR" && swift test)

echo "==> Checking signing identities"
security find-identity -v -p codesigning || true
if [[ -n "${SIGNING_IDENTITY:-}" ]]; then
    CODE_SIGN_IDENTITY_VALUE="$SIGNING_IDENTITY"
    SIGNING_STATUS="Developer ID/custom identity: $SIGNING_IDENTITY"
else
    CODE_SIGN_IDENTITY_VALUE="-"
    SIGNING_STATUS="ad-hoc"
fi

echo "==> Building Release application for arm64"
xcodebuild \
    -project "$ROOT_DIR/$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -derivedDataPath "$DERIVED_DATA" \
    clean build \
    ARCHS=arm64 \
    ONLY_ACTIVE_ARCH=NO \
    MARKETING_VERSION="$VERSION" \
    CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="$CODE_SIGN_IDENTITY_VALUE" \
    CODE_SIGNING_ALLOWED=NO

APP_PATH="$DERIVED_DATA/Build/Products/Release/${APP_NAME}.app"
INFO_PLIST="$APP_PATH/Contents/Info.plist"
if [[ ! -d "$APP_PATH" || ! -f "$INFO_PLIST" ]]; then
    echo "Release application was not created at: $APP_PATH" >&2
    exit 1
fi

# File Provider-backed workspaces can attach Finder metadata to build products.
# Remove it only from the disposable Release app before applying a fresh signature.
echo "==> Signing Release application ($SIGNING_STATUS)"
xattr -cr "$APP_PATH"
if [[ "$CODE_SIGN_IDENTITY_VALUE" == "-" ]]; then
    while IFS= read -r framework; do
        codesign --force --sign - --timestamp=none "$framework"
    done < <(find "$APP_PATH/Contents/Frameworks" -maxdepth 1 -type d -name '*.framework' -print)
    xattr -cr "$APP_PATH"
    codesign --force --sign - --timestamp=none "$APP_PATH"
else
    while IFS= read -r framework; do
        codesign --force --sign "$CODE_SIGN_IDENTITY_VALUE" --timestamp --options runtime "$framework"
    done < <(find "$APP_PATH/Contents/Frameworks" -maxdepth 1 -type d -name '*.framework' -print)
    xattr -cr "$APP_PATH"
    codesign --force --sign "$CODE_SIGN_IDENTITY_VALUE" --timestamp --options runtime "$APP_PATH"
fi

ACTUAL_BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$INFO_PLIST")"
ACTUAL_DISPLAY_NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "$INFO_PLIST")"
ACTUAL_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
ACTUAL_BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST")"
EXECUTABLE_NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$INFO_PLIST")"

expect_equal "Bundle identifier" "$ACTUAL_BUNDLE_ID" "$BUNDLE_ID"
expect_equal "Display name" "$ACTUAL_DISPLAY_NAME" "$APP_NAME"
expect_equal "Version" "$ACTUAL_VERSION" "$VERSION"
expect_equal "Build number" "$ACTUAL_BUILD" "$BUILD_NUMBER"
expect_equal "Architectures" "$(lipo -archs "$APP_PATH/Contents/MacOS/$EXECUTABLE_NAME")" "arm64"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

echo "==> Creating ZIP"
/usr/bin/ditto -c -k --norsrc --keepParent "$APP_PATH" "$ZIP_PATH"

echo "==> Creating DMG"
/usr/bin/ditto "$APP_PATH" "$STAGING_DIR/${APP_NAME}.app"
ln -s /Applications "$STAGING_DIR/Applications"
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"
hdiutil verify "$DMG_PATH"

DMG_SHA256="$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')"
ZIP_SHA256="$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"
{
    echo "$DMG_SHA256  $(basename "$DMG_PATH")"
    echo "$ZIP_SHA256  $(basename "$ZIP_PATH")"
} > "$CHECKSUM_PATH"

echo
echo "Release artifacts"
echo "  App:        ${APP_NAME}.app (inside DMG and ZIP)"
echo "  DMG:        $DMG_PATH"
echo "  ZIP:        $ZIP_PATH"
echo "  Checksums:  $CHECKSUM_PATH"
echo "  Signing:    $SIGNING_STATUS"
echo "  Notarized:  no"
echo "  DMG SHA-256: $DMG_SHA256"
echo "  ZIP SHA-256: $ZIP_SHA256"
