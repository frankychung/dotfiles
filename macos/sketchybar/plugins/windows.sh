#!/bin/bash

# Extract space number from item name (e.g., windows.1 -> 1)
SPACE_ID=$(echo "$NAME" | cut -d'.' -f2)

# Get windows info for this specific space (app names and count)
WINDOWS_JSON=$(aerospace list-windows --workspace "$SPACE_ID" --format '%{app-name}' --json 2>/dev/null || echo "[]")
WINDOW_COUNT=$(echo "$WINDOWS_JSON" | jq '. | length' 2>/dev/null || echo "0")

# Function to get app icon
# To add more apps:
# 1. Find the exact app name by running: aerospace list-windows --all | awk '{print $3}' | sort | uniq
# 2. Add a new case entry with the exact app name (case sensitive)
# 3. Add your chosen nerd font icon
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
    echo ""
    ;;
  # Add more apps here following this pattern:
  # "App Name")
  #     echo "󰊯"  # Your chosen icon
  #     ;;
  *)
    echo "" # Default square icon for unknown apps
    ;;
  esac
}

# Create icons for each window based on app names
ICONS=""
if [ "$WINDOW_COUNT" -gt 0 ]; then
  # Get app names and create corresponding icons with spacing
  first_icon=true
  while IFS= read -r app_name; do
    if [ -n "$app_name" ]; then
      icon=$(get_app_icon "$app_name")
      if [ "$first_icon" = true ]; then
        ICONS="${icon}"
        first_icon=false
      else
        ICONS="${ICONS} ${icon}" # Add space between icons
      fi
    fi
  done < <(echo "$WINDOWS_JSON" | jq -r '.[]."app-name"' 2>/dev/null)
fi

# Set the label to show app icons, or empty if no windows
if [ "$WINDOW_COUNT" -eq 0 ]; then
  sketchybar --set "$NAME" label=""
else
  sketchybar --set "$NAME" label="$ICONS"
fi
