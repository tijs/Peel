#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $0 /path/to/Peel.app [version]" >&2
  exit 64
fi

APP_PATH="$1"
VERSION="${2:-${VERSION:-}}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DIST_DIR="${DIST_DIR:-"$ROOT_DIR/dist"}"
STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/peel-dmg.XXXXXX")"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-Developer ID Application}"
SIGNING_TIMESTAMP="${SIGNING_TIMESTAMP:---timestamp}"

cleanup() {
  rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

if [[ ! -d "$APP_PATH" ]]; then
  echo "App not found: $APP_PATH" >&2
  exit 66
fi

if [[ -z "$VERSION" ]]; then
  VERSION="$(/usr/libexec/PlistBuddy -c 'Print :ApplicationProperties:CFBundleShortVersionString' "$ROOT_DIR/build/release/Peel.xcarchive/Info.plist" 2>/dev/null || true)"
fi
if [[ -z "$VERSION" ]]; then
  VERSION="dev"
fi

mkdir -p "$DIST_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/Peel.app"
ln -s /Applications "$STAGING_DIR/Applications"

DMG_PATH="$DIST_DIR/Peel-$VERSION.dmg"
rm -f "$DMG_PATH"

hdiutil create \
  -volname "Peel" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

timestamp_args=()
if [[ "$SIGNING_TIMESTAMP" == "none" ]]; then
  timestamp_args+=(--timestamp=none)
else
  timestamp_args+=("$SIGNING_TIMESTAMP")
fi

codesign --force \
  "${timestamp_args[@]}" \
  --sign "$SIGNING_IDENTITY" \
  "$DMG_PATH"

shasum -a 256 "$DMG_PATH" > "$DMG_PATH.sha256"
echo "$DMG_PATH"
