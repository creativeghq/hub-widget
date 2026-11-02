#!/usr/bin/env bash
# Install the latest Hub Widget release into /Applications — no Xcode needed.
# Needs the GitHub CLI signed in to an account that can read creativeghq/hub-widget:
#   brew install gh && gh auth login
# Usage: ./scripts/install.sh            (latest)
#        ./scripts/install.sh v1.0.0     (a specific release)
set -euo pipefail

REPO="creativeghq/hub-widget"
TAG="${1:-}"
APP="/Applications/Hub Widget.app"

command -v gh >/dev/null || { echo "Install the GitHub CLI first: brew install gh && gh auth login"; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Downloading ${TAG:-the latest release}…"
gh release download ${TAG:+"$TAG"} --repo "$REPO" --pattern 'HubWidget-*.zip' --dir "$TMP"
ZIP="$(ls "$TMP"/HubWidget-*.zip | head -1)"

pkill -x "Hub Widget" 2>/dev/null || true
rm -rf "$APP"
ditto -x -k "$ZIP" /Applications/
# Not signed by an Apple developer account: clear the download quarantine so macOS lets it open.
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true

open "$APP"
echo "Installed $(basename "$ZIP" .zip)."
echo "Next: right-click the desktop → Edit Widgets… → search Hub, then Edit the widget and paste your kai_ key."
