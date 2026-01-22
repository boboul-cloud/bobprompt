#!/usr/bin/env zsh
set -euo pipefail

# Generate iOS app icon PNGs from a single square source image
# Usage:
#   ./Scripts/generate_app_icons.zsh /path/to/source.png
# The script writes files into Prompteur/Assets.xcassets/AppIcon.appiconset

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 /path/to/source_square.png" >&2
  exit 1
fi

SRC="$1"
if [[ ! -f "$SRC" ]]; then
  echo "Error: source file not found: $SRC" >&2
  exit 1
fi

APPICONSET_DIR="$(cd "$(dirname "$0")/.." && pwd)/Prompteur/Assets.xcassets/AppIcon.appiconset"
mkdir -p "$APPICONSET_DIR"

echo "Generating icons in $APPICONSET_DIR from $SRC"

function gen() {
  local size=$1
  local name=$2
  local out="$APPICONSET_DIR/$name"
  sips -z $size $size "$SRC" --out "$out" >/dev/null
  echo " - $name ($size x $size)"
}

# Targets (px)
# iPhone
gen 120 AppIcon-120.png   # 60x60 @2x
gen 180 AppIcon-180.png   # 60x60 @3x
# iPad
gen 76  AppIcon-76.png    # 76x76 @1x
gen 152 AppIcon-152.png   # 76x76 @2x
gen 167 AppIcon-167.png   # 83.5x83.5 @2x
# Marketing
gen 1024 AppIcon-1024.png # App Store

echo "Done. Open Xcode → Assets.xcassets → AppIcon to verify."
