#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"
APP_NAME="CursorRingMagnifier"
VERSION="${APP_VERSION:-0.2.0}"
BUILD_NUMBER="${APP_BUILD_NUMBER:-2}"
APP_DIR="$ROOT_DIR/dist/${APP_NAME}.app"
ICNS_PATH="$ROOT_DIR/Resources/AppIcon.icns"
export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-${TMPDIR:-/tmp}/mouse-circle-clang}"
export SWIFTPM_MODULECACHE_OVERRIDE="${SWIFTPM_MODULECACHE_OVERRIDE:-${TMPDIR:-/tmp}/mouse-circle-swift}"

# Keep the approved icon; generate it only when the source asset is absent.
if [[ ! -f "$ICNS_PATH" ]]; then
    mkdir -p "$ROOT_DIR/build" "$ROOT_DIR/Resources"
    swift "$ROOT_DIR/scripts/generate_icon.swift" "$ROOT_DIR/build/AppIcon.iconset"
    iconutil -c icns "$ROOT_DIR/build/AppIcon.iconset" -o "$ICNS_PATH"
fi
swift build -c release --build-system native --disable-sandbox --manifest-cache local
BIN_DIR="$(swift build -c release --build-system native --disable-sandbox --manifest-cache local --show-bin-path)"

mkdir -p "$ROOT_DIR/dist"
STAGING="$(mktemp -d "$ROOT_DIR/dist/.package.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
STAGED_APP="$STAGING/${APP_NAME}.app"
mkdir -p "$STAGED_APP/Contents/MacOS" "$STAGED_APP/Contents/Resources"
cp "$BIN_DIR/MouseCircleApp" "$STAGED_APP/Contents/MacOS/${APP_NAME}"
chmod +x "$STAGED_APP/Contents/MacOS/${APP_NAME}"
cp "$ICNS_PATH" "$STAGED_APP/Contents/Resources/AppIcon.icns"

cat > "$STAGED_APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>ja</string>
  <key>CFBundleExecutable</key><string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key><string>com.example.cursorringmagnifier</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleName</key><string>${APP_NAME}</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${BUILD_NUMBER}</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSScreenCaptureUsageDescription</key>
  <string>カーソル周辺を拡大表示するために使用します。画面の保存・送信は行いません。</string>
</dict>
</plist>
PLIST

plutil -lint "$STAGED_APP/Contents/Info.plist"
codesign --force --sign "${CODE_SIGN_IDENTITY:--}" --timestamp=none "$STAGED_APP"
codesign --verify --deep --strict "$STAGED_APP"
ditto -c -k --sequesterRsrc --keepParent "$STAGED_APP" "$STAGING/${APP_NAME}-macOS.zip"

if [[ -e "$APP_DIR" || -e "$ROOT_DIR/dist/${APP_NAME}-macOS.zip" ]]; then
    BACKUP="$ROOT_DIR/dist/previous/$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP"
    [[ ! -e "$APP_DIR" ]] || mv "$APP_DIR" "$BACKUP/"
    [[ ! -e "$ROOT_DIR/dist/${APP_NAME}-macOS.zip" ]] || mv "$ROOT_DIR/dist/${APP_NAME}-macOS.zip" "$BACKUP/"
fi
mv "$STAGED_APP" "$APP_DIR"
mv "$STAGING/${APP_NAME}-macOS.zip" "$ROOT_DIR/dist/"
(cd "$ROOT_DIR/dist" && shasum -a 256 "${APP_NAME}-macOS.zip" > "${APP_NAME}-macOS.zip.sha256")
echo "Packaged: $APP_DIR (v$VERSION)"
echo "ZIP: $ROOT_DIR/dist/${APP_NAME}-macOS.zip"
echo "Local/ad-hoc signing is not Apple notarization. Distribution requires separate signing/notarization."
