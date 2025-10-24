#!/bin/bash

# Safety check: ensure NAME is set
if [ -z "$NAME" ]; then
  exit 0
fi

# Check if we're using built-in display only (not external monitor)
# If system_profiler shows only 1 display AND it's not an external brand, we're on laptop only
DISPLAY_INFO=$(system_profiler SPDisplaysDataType)
DISPLAY_COUNT=$(echo "$DISPLAY_INFO" | grep -c "Resolution:")
IS_EXTERNAL=$(echo "$DISPLAY_INFO" | grep -E "DELL|LG|Samsung|HP|BenQ|Acer|ASUS|ViewSonic|Philips|AOC|Studio Display|Pro Display XDR|Thunderbolt Display|Cinema Display" | wc -l | tr -d ' ')

if [ "$DISPLAY_COUNT" -eq 1 ] && [ "$IS_EXTERNAL" -gt 0 ]; then
  # External monitor only (clamshell mode), hide the item
  sketchybar --set "$NAME" drawing=off
  exit 0
fi

if [ "$DISPLAY_COUNT" -gt 1 ]; then
  # Multiple displays including external, hide the item
  sketchybar --set "$NAME" drawing=off
  exit 0
fi

# Only built-in display (laptop only), continue to show music if playing

# Check if Apple Music is running and playing
MUSIC_STATE=$(osascript -e 'if application "Music" is running then
    tell application "Music"
        if player state is playing then
            return "playing"
        else if player state is paused then
            return "paused"
        end if
    end tell
end if' 2>/dev/null)

if [ -n "$MUSIC_STATE" ]; then
  # Set play/pause icon based on state
  if [ "$MUSIC_STATE" = "playing" ]; then
    PLAY_ICON="󰏤" # pause icon (nerd font)
  else
    PLAY_ICON="󰐊" # play icon (nerd font)
  fi

  sketchybar --set "$NAME" label="♪ $PLAY_ICON"
else
  # Check if VLC is playing
  VLC_INFO=$(echo "info" | nc -w 2 localhost 4212 2>/dev/null)

  if [ $? -eq 0 ] && [ -n "$VLC_INFO" ]; then
    # Check if VLC is playing or paused
    VLC_STATUS=$(echo "status" | nc -w 1 localhost 4212 2>/dev/null)
    IS_PLAYING=$(echo "$VLC_STATUS" | grep -i "playing")

    # Set play/pause icon based on status
    if [ -n "$IS_PLAYING" ]; then
      PLAY_ICON="󰏤" # pause icon (nerd font)
    else
      PLAY_ICON="󰐊" # play icon (nerd font)
    fi

    sketchybar --set "$NAME" label="♪ $PLAY_ICON"
  else
    # Nothing playing, hide the item
    sketchybar --set "$NAME" drawing=off
  fi
fi
