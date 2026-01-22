#!/usr/bin/env zsh
set -euo pipefail

# Config
SCHEME="Prompteur"
PROJECT="Prompteur.xcodeproj"
DEVICE_NAME="iPhone 15 Pro"
DERIVED_DATA=".derived-data"
OUT_DIR="Screenshots"
BUNDLE_ID="com.prompteur.app"

mkdir -p "$OUT_DIR"

# Build for simulator (pretty output if xcpretty is available)
if command -v xcpretty >/dev/null 2>&1; then
  xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -sdk iphonesimulator \
    -derivedDataPath "$DERIVED_DATA" \
    -destination 'generic/platform=iOS Simulator' \
    build | xcpretty
else
  echo "ℹ️  xcpretty non trouvé, sortie xcodebuild non formatée."
  xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -sdk iphonesimulator \
    -derivedDataPath "$DERIVED_DATA" \
    -destination 'generic/platform=iOS Simulator' \
    build
fi

APP_PATH=$(ls -d "$DERIVED_DATA"/Build/Products/Debug-iphonesimulator/Prompteur.app 2>/dev/null || true)
if [[ -z "$APP_PATH" ]]; then
  echo "❌ App non trouvée dans $DERIVED_DATA/Build/Products/Debug-iphonesimulator" >&2
  exit 1
fi

# Boot simulator
xcrun simctl boot "$DEVICE_NAME" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE_NAME" -b

# Install and launch
xcrun simctl uninstall booted "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl install booted "$APP_PATH"
xcrun simctl launch booted "$BUNDLE_ID" || true

# Small delay to render UI
sleep 1.5

# Screenshot
FILENAME="$OUT_DIR/prompteur-$(echo $DEVICE_NAME | tr ' ' '_' | tr -d '()').png"
xcrun simctl io booted screenshot "$FILENAME"
echo "✅ Capture enregistrée: $FILENAME"