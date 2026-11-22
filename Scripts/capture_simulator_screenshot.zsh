#!/usr/bin/env zsh
# Construit l'app, la lance dans le simulateur sur un écran donné et enregistre
# une capture dans Screenshots/.
#
#   ./Scripts/capture_simulator_screenshot.zsh lecteur-tambour -demoScreen reader -demoStyle drum -demoWord 30
#
# Arguments de démonstration (compilation Debug uniquement) : voir DemoConfig
# dans Prompteur/App/BobpromptApp.swift.
set -euo pipefail

NAME=${1:-capture}; shift || true
DEVICE_NAME=${DEVICE_NAME:-"iPhone 17"}
DERIVED_DATA=".derived-data"
OUT_DIR="Screenshots"
BUNDLE_ID="com.bobprompt.app"

mkdir -p "$OUT_DIR"
xcodegen generate >/dev/null
xcodebuild -project Prompteur.xcodeproj -scheme Prompteur -configuration Debug \
  -destination "platform=iOS Simulator,name=$DEVICE_NAME" \
  -derivedDataPath "$DERIVED_DATA" build -quiet

APP="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/Prompteur.app"
xcrun simctl boot "$DEVICE_NAME" 2>/dev/null || true
xcrun simctl status_bar "$DEVICE_NAME" override --time 9:41 --batteryState charged --batteryLevel 100 || true
xcrun simctl install "$DEVICE_NAME" "$APP"
xcrun simctl terminate "$DEVICE_NAME" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl launch "$DEVICE_NAME" "$BUNDLE_ID" -AppleLanguages "(fr)" -AppleLocale fr_FR "$@" >/dev/null
sleep 4
xcrun simctl io "$DEVICE_NAME" screenshot "$OUT_DIR/$NAME.png"
echo "✅ $OUT_DIR/$NAME.png"
