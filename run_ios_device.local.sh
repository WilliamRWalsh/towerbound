#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IOS_BUILD="$ROOT/build/ios-device"
BUNDLE_ID="${BUNDLE_ID:-com.woodale.towerbound}"
TEAM_ID="${TEAM_ID:-JZ82P2C5W7}"
DEVICE_ID="${DEVICE_ID:-$(xcrun devicectl list devices 2>/dev/null | awk '/connected/ && /iPhone/ {print $3; exit}')}"

if [[ -z "$DEVICE_ID" ]]; then
  echo "Connect and unlock an iPhone first, then run this script again." >&2
  exit 1
fi

rm -rf "$IOS_BUILD"
mkdir -p "$IOS_BUILD"
godot --headless --path "$ROOT" --export-debug "iOS Simulator" "$IOS_BUILD/Towerbound.zip"

# Godot 4.7.2 leaves empty extension placeholders in the Xcode template.
PROJECT_FILE="$IOS_BUILD/Towerbound.xcodeproj/project.pbxproj"
sed -i '' \
  -e '/\$pbx_embeded_frameworks/d' \
  -e '/\$additional_pbx_files/d' \
  -e '/\$additional_pbx_frameworks_build/d' \
  -e '/\$additional_pbx_frameworks_refs/d' \
  -e '/\$additional_pbx_resources_build/d' \
  -e '/\$additional_pbx_resources_refs/d' \
  -e '/D07CD44E1C5D589C00B7FB28 \/\* Images.xcassets in Resources \*\//d' \
  -e '/D07CD44D1C5D589C00B7FB28 \/\* Images.xcassets \*\//d' \
  "$PROJECT_FILE"

xcodebuild \
  -project "$IOS_BUILD/Towerbound.xcodeproj" \
  -scheme Towerbound \
  -configuration Debug \
  -sdk iphoneos \
  -destination "generic/platform=iOS" \
  -allowProvisioningUpdates \
  ARCHS=arm64 \
  CODE_SIGN_STYLE=Automatic \
  CODE_SIGN_IDENTITY="Apple Development" \
  PROVISIONING_PROFILE_SPECIFIER= \
  "DEVELOPMENT_TEAM=$TEAM_ID" \
  "PRODUCT_BUNDLE_IDENTIFIER=$BUNDLE_ID" \
  -derivedDataPath "$IOS_BUILD/DerivedData" \
  build

APP="$IOS_BUILD/DerivedData/Build/Products/Debug-iphoneos/Towerbound.app"
xcrun devicectl device install app --device "$DEVICE_ID" "$APP"
xcrun devicectl device process launch --device "$DEVICE_ID" "$BUNDLE_ID"
