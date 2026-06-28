#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 3 ]]; then
	echo "usage: $0 /path/to/homebrew-tap version dmg-sha256" >&2
	exit 64
fi

TAP_DIR="$1"
VERSION="${2#v}"
SHA256="$3"

if [[ ! -d "$TAP_DIR/.git" ]]; then
	echo "Tap repo not found: $TAP_DIR" >&2
	exit 66
fi

mkdir -p "$TAP_DIR/Casks"
cat >"$TAP_DIR/Casks/peel.rb" <<EOF
cask "peel" do
  version "$VERSION"
  sha256 "$SHA256"

  url "https://github.com/tijs/Peel/releases/download/v#{version}/Peel-#{version}.dmg"
  name "Peel"
  desc "Native macOS app for removing image backgrounds"
  homepage "https://github.com/tijs/Peel"

  app "Peel.app"

  zap trash: [
    "~/Library/Preferences/org.tijs.Peel.plist",
    "~/Library/Saved Application State/org.tijs.Peel.savedState",
  ]
end
EOF
