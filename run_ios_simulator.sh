#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IOS_BUILD="$ROOT/build/ios"
BUNDLE_ID="com.example.towerbound"
SIMULATOR_ID="${SIMULATOR_UDID:-$(xcrun simctl list devices booted --json | python3 -c 'import json,sys; d=json.load(sys.stdin); print(next((x["udid"] for ds in d["devices"].values() for x in ds if x["state"] == "Booted"), ""))')}"

if [[ -z "$SIMULATOR_ID" ]]; then
  echo "Boot an iPhone simulator first, then run this script again." >&2
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

ARCH="$(uname -m)"
xcodebuild \
  -project "$IOS_BUILD/Towerbound.xcodeproj" \
  -scheme Towerbound \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination "generic/platform=iOS Simulator" \
  "ARCHS=$ARCH" \
  CODE_SIGNING_ALLOWED=NO \
  -derivedDataPath "$IOS_BUILD/DerivedData" \
  build

APP="$IOS_BUILD/DerivedData/Build/Products/Debug-iphonesimulator/Towerbound.app"
open -a Simulator
xcrun simctl install "$SIMULATOR_ID" "$APP"
xcrun simctl launch "$SIMULATOR_ID" "$BUNDLE_ID"
