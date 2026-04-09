#!/bin/bash

PANERU="$HOME/Developer/paneru/target/release/paneru"
STATE_FILE="/tmp/paneru-state.json"

# Map bundle_id to nerd font icon
get_icon_for_bundle() {
  case "$1" in
  com.apple.MobileSMS) echo "󱋊" ;;
  jp.naver.line.mac) echo "󱋊" ;;
  com.google.Chrome) echo "" ;;
  com.github.wez.wezterm) echo "󰢹" ;;
  com.tinyspeck.slackmacgap) echo "" ;;
  com.apple.Music) echo "󰝚" ;;
  com.apple.Safari) echo "󰀹" ;;
  com.valvesoftware.steam) echo "󰺷" ;;
  com.openai.chat) echo "󱌽" ;;
  com.apple.iCal) echo "󰃭" ;;
  com.flexibits.fantastical2) echo "󰃭" ;;
  com.apple.finder) echo "󰉖" ;;
  io.github.nickvision.Zen) echo "󰺕" ;;
  com.1password.1password) echo "" ;;
  com.apple.Photos) echo "" ;;
  com.apple.Maps) echo "󰍏" ;;
  com.apple.ActivityMonitor) echo "󰍛" ;;
  dev.kdrag0n.MacVirt) echo "󰟀" ;;
  *) echo "" ;;
  esac
}

if [ ! -f "$STATE_FILE" ]; then
  sketchybar --set "$NAME" label="no state"
  exit 0
fi

# Get focused app bundle ID
FOCUSED_PID=$(lsappinfo info -only pid $(lsappinfo front) 2>/dev/null | grep -o '[0-9]*')
FOCUSED_BUNDLE=$(lsappinfo info -only bundleid $(lsappinfo front) 2>/dev/null | cut -d'"' -f4)

# Parse paneru state
NUM_STRIPS=$(jq '.workspaces[0].strips | length' "$STATE_FILE" 2>/dev/null)
if [ -z "$NUM_STRIPS" ] || [ "$NUM_STRIPS" = "null" ]; then
  sketchybar --set "$NAME" label="no ws"
  exit 0
fi

OUTPUT=""

for ((s = 0; s < NUM_STRIPS; s++)); do
  # Add workspace separator if multiple strips
  if [ "$NUM_STRIPS" -gt 1 ]; then
    VI=$(jq -r ".workspaces[0].strips[$s].virtual_index" "$STATE_FILE")
    if [ -n "$OUTPUT" ]; then
      OUTPUT="${OUTPUT}    "
    fi
    OUTPUT="${OUTPUT}$((VI + 1)): "
  fi

  # Get bundle IDs for this strip's columns, in order
  BUNDLES=$(jq -r ".workspaces[0].strips[$s].columns[].Single.bundle_id" "$STATE_FILE" 2>/dev/null)

  first=true
  while IFS= read -r bundle; do
    [ -z "$bundle" ] && continue

    icon=$(get_icon_for_bundle "$bundle")

    if [ "$bundle" = "$FOCUSED_BUNDLE" ]; then
      icon="${icon} ◀"
    fi

    if [ "$first" = true ]; then
      OUTPUT="${OUTPUT}${icon}"
      first=false
    else
      OUTPUT="${OUTPUT}  ${icon}"
    fi
  done <<<"$BUNDLES"
done

sketchybar --set "$NAME" label="$OUTPUT"
