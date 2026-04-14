#!/bin/bash

# Function to get app icon
get_app_icon() {
  local app_name="$1"
  case "$app_name" in
  "LINE")
    echo "󱋊"
    ;;
  "Messages")
    echo "󱋊"
    ;;
  "Google Chrome")
    echo ""
    ;;
  "WezTerm")
    echo ""
    ;;
  "wezterm-gui")
    echo "󰢹"
    ;;
  "Slack")
    echo ""
    ;;
  "Music")
    echo "󰝚"
    ;;
  "Safari")
    echo "󰀹"
    ;;
  "Steam Helper")
    echo "󰺷"
    ;;
  "ChatGPT")
    echo "󱌽"
    ;;
  "Calendar")
    echo "󰃭"
    ;;
  "Fantastical")
    echo "󰃭"
    ;;
  "Finder")
    echo "󰉖"
    ;;
  "Zen")
    echo "󰺕"
    ;;
  "1Password")
    echo ""
    ;;
  "Photos")
    echo ""
    ;;
  "Maps")
    echo "󰍏"
    ;;
  *)
    echo "" # Default square icon for unknown apps
    ;;
  esac
}

# Get currently focused app
FOCUSED_APP=$(lsappinfo info -only name $(lsappinfo front) | cut -d'"' -f4)

# Get apps with their window x positions, sorted left to right
ICONS=""
first_icon=true

while IFS='|' read -r x_pos app_name; do
  # Skip apps without visible windows
  if [ -n "$app_name" ] && [ "$x_pos" != "99999" ]; then
    icon=$(get_app_icon "$app_name")
    # Add arrow if this is the focused app
    if [ "$app_name" = "$FOCUSED_APP" ]; then
      icon="${icon} ◀"
    fi
    if [ "$first_icon" = true ]; then
      ICONS="${icon}"
      first_icon=false
    else
      ICONS="${ICONS}  ${icon}"
    fi
  fi
done < <(
  while IFS= read -r app_name; do
    if [ -n "$app_name" ]; then
      x_pos=$(osascript -e "tell application \"System Events\" to tell process \"$app_name\" to get position of window 1" 2>/dev/null | cut -d',' -f1)
      [ -z "$x_pos" ] && x_pos="99999"
      echo "${x_pos}|${app_name}"
    fi
  done < <(lsappinfo list | grep -B5 'type="Foreground"' | grep '".*" ASN' | awk -F'"' '{print $2}') | sort -t'|' -k1 -n
)

# Set the label to show app icons
sketchybar --set "$NAME" label="$ICONS"
