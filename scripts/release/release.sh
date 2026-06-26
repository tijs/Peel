#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERSION="${VERSION:-${GITHUB_REF_NAME:-}}"
VERSION="${VERSION#v}"

APP_PATH="$("$ROOT_DIR/scripts/release/archive.sh" | tail -n 1)"
DMG_PATH="$("$ROOT_DIR/scripts/release/package-dmg.sh" "$APP_PATH" "$VERSION" | tail -n 1)"

if [[ "${SKIP_NOTARIZATION:-0}" != "1" ]]; then
  "$ROOT_DIR/scripts/release/notarize.sh" "$DMG_PATH"
fi

echo "$DMG_PATH"
