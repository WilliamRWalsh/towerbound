#!/usr/bin/env bash
set -euo pipefail

# Builds, signs, installs, and launches Towerbound on a connected, paired iPhone.
# Override DEVICE_ID, TEAM_ID, or BUNDLE_ID through the environment if needed.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IOS_BUILD="$ROOT/build/ios-device"
TEAM_ID="${TEAM_ID:-JZ82P2C5W7}"
BUNDLE_ID="${BUNDLE_ID:-com.woodale.towerbound}"
DEVICE_ID="${DEVICE_ID:-$(xcrun devicectl list devices --hide-default-columns --columns Identifier --columns State 2>/dev/null | awk '/connected|available \(paired\)/ && !id {id = $1} END {print id}')}"

if [[ -z "$DEVICE_ID" ]]; then
  echo "Connect and pair an iPhone first (xcrun devicectl manage pair --device <id>)." >&2
  exit 1
fi

if [[ -z "$TEAM_ID" ]]; then
  echo "Set TEAM_ID to your Apple development team (sign in under Xcode > Settings > Accounts to get one)." >&2
  exit 1
fi

# xcodebuild needs the hardware UDID so automatic signing can register the phone.
DEVICE_UDID="$(xcrun devicectl device info details --device "$DEVICE_ID" 2>/dev/null | awk '/• udid:/ && !id {id = $3} END {print id}')"

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
  -destination "platform=iOS,id=$DEVICE_UDID" \
  ARCHS=arm64 \
  CODE_SIGN_STYLE=Automatic \
  CODE_SIGN_IDENTITY="Apple Development" \
  PROVISIONING_PROFILE_SPECIFIER= \
  "DEVELOPMENT_TEAM=$TEAM_ID" \
  "PRODUCT_BUNDLE_IDENTIFIER=$BUNDLE_ID" \
  -allowProvisioningUpdates \
  -derivedDataPath "$IOS_BUILD/DerivedData" \
  build

APP="$IOS_BUILD/DerivedData/Build/Products/Debug-iphoneos/Towerbound.app"
xcrun devicectl device install app --device "$DEVICE_ID" "$APP"
xcrun devicectl device process launch --device "$DEVICE_ID" "$BUNDLE_ID"
