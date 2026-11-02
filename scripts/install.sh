#!/usr/bin/env bash
# Build Hub Widget signed with your Apple team, install it in /Applications and open it.
# Usage: DEVELOPMENT_TEAM=ABCDE12345 ./scripts/install.sh   (or put the team in Config/Local.xcconfig)
set -euo pipefail
cd "$(dirname "$0")/.."

command -v xcodebuild >/dev/null || { echo "Xcode is required (App Store → Xcode, then open it once)."; exit 1; }
command -v xcodegen >/dev/null || { echo "Installing XcodeGen…"; brew install xcodegen; }

if [[ -n "${DEVELOPMENT_TEAM:-}" ]]; then
  echo "DEVELOPMENT_TEAM = ${DEVELOPMENT_TEAM}" > Config/Local.xcconfig
fi
if ! grep -qs "DEVELOPMENT_TEAM" Config/Local.xcconfig; then
  echo "Set your team first: DEVELOPMENT_TEAM=ABCDE12345 ./scripts/install.sh"
  echo "Find it in Xcode → Settings → Accounts → (your Apple ID) → Team ID, or developer.apple.com → Membership."
  exit 1
fi

xcodegen generate
xcodebuild -project HubWidget.xcodeproj -scheme HubWidget -configuration Release \
  -destination 'platform=macOS' -derivedDataPath build -allowProvisioningUpdates build

APP="build/Build/Products/Release/Hub Widget.app"
[[ -d "$APP" ]] || { echo "Build output not found at $APP"; exit 1; }

pkill -x "Hub Widget" 2>/dev/null || true
rm -rf "/Applications/Hub Widget.app"
cp -R "$APP" /Applications/
open "/Applications/Hub Widget.app"
echo "Installed. Paste your kai_ key in the window that opened, then add the widget from the desktop (right-click → Edit Widgets)."
