#!/usr/bin/env zsh
# Captures App Store, reproductibles : iPhone 6,9" (1320 × 2868) et iPad 13" (2064 × 2752).
#
#   ./Scripts/capture_app_store.zsh            # les deux séries
#   ./Scripts/capture_app_store.zsh iphone     # seulement l'iPhone
#
# Chaque écran est ouvert par les arguments de démonstration (compilation Debug,
# voir DemoConfig dans Prompteur/App/BobpromptApp.swift) : mêmes textes, mêmes
# étoiles, même instant de lecture à chaque fois. L'app est réinstallée avant
# chaque série pour repartir de réglages neufs.
set -euo pipefail
cd "$(dirname "$0")/.."

WHICH=${1:-all}
DD=".derived-data"
BUNDLE_ID="com.bobprompt.app"
APP="$DD/Build/Products/Debug-iphonesimulator/Prompteur.app"
LANG_ARGS=(-AppleLanguages "(fr)" -AppleLocale fr_FR)

xcodegen generate >/dev/null
xcodebuild -project Prompteur.xcodeproj -scheme Prompteur -configuration Debug \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath "$DD" build -quiet

# nom | attente (s) | arguments
SHOTS=(
  "01-accueil|5|-demoSeed YES"
  "02-pluie-de-mots|5|-demoSeed YES -demoProfile kids -demoScreen reader -demoStyle sky -demoWord 6.09 -demoClean YES"
  "03-coin-lecture|5|-demoSeed YES -demoScreen kids"
  "04-badges|5|-demoSeed YES -demoScreen rewards"
  "05-tambour-3d|5|-demoSeed YES -demoScreen reader -demoStyle drum -demoSample 2 -demoWord 30.5 -demoClean YES"
  "06-vieille-ecole|6|-demoSeed YES -demoScreen reader -demoStyle crtGreen -demoSample 1 -demoWord 31.5 -demoClean YES"
)

series() {
  local device=$1 folder=$2
  local out="soumission/captures/$folder"
  mkdir -p "$out"
  xcrun simctl boot "$device" 2>/dev/null || true
  xcrun simctl bootstatus "$device" -b >/dev/null
  xcrun simctl ui "$device" appearance light
  xcrun simctl status_bar "$device" override --time 9:41 --batteryState charged --batteryLevel 100 \
    --wifiBars 3 --cellularBars 4 2>/dev/null || \
  xcrun simctl status_bar "$device" override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3
  xcrun simctl uninstall "$device" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl install "$device" "$APP"
  # Premier lancement « à vide » : l'animation d'ouverture ne doit pas être photographiée.
  xcrun simctl launch "$device" "$BUNDLE_ID" "${LANG_ARGS[@]}" >/dev/null
  sleep 4
  for entry in "${SHOTS[@]}"; do
    local name=${entry%%|*}; local rest=${entry#*|}
    local wait=${rest%%|*}; local args=${rest#*|}
    xcrun simctl terminate "$device" "$BUNDLE_ID" 2>/dev/null || true
    sleep 1
    xcrun simctl launch "$device" "$BUNDLE_ID" "${LANG_ARGS[@]}" ${=args} >/dev/null
    sleep "$wait"
    xcrun simctl io "$device" screenshot --type=png "$out/$name.png" >/dev/null 2>&1
    echo "  $out/$name.png"
  done
  xcrun simctl terminate "$device" "$BUNDLE_ID" 2>/dev/null || true
}

if [[ $WHICH == all || $WHICH == iphone ]]; then
  echo "iPhone 6,9 pouces"
  series "iPhone 17 Pro Max" "iphone-6.9"
fi
if [[ $WHICH == all || $WHICH == ipad ]]; then
  echo "iPad 13 pouces"
  series "iPad Pro 13-inch (M5)" "ipad-13"
fi

echo "Dimensions :"
sips -g pixelWidth -g pixelHeight soumission/captures/*/*.png | grep -E "png|pixel" | paste - - - | awk '{print $1, $3 "×" $5}'
