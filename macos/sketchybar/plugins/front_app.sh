#!/bin/bash

# Check if we're using built-in display only (not external monitor)
# If system_profiler shows only 1 display AND it's not an external brand, we're on laptop only
DISPLAY_INFO=$(system_profiler SPDisplaysDataType)
DISPLAY_COUNT=$(echo "$DISPLAY_INFO" | grep -c "Resolution:")
IS_EXTERNAL=$(echo "$DISPLAY_INFO" | grep -E "DELL|LG|Samsung|HP|BenQ|Acer|ASUS|ViewSonic|Philips|AOC|Studio Display|Pro Display XDR|Thunderbolt Display|Cinema Display" | wc -l | tr -d ' ')

if [ "$DISPLAY_COUNT" -eq 1 ] && [ "$IS_EXTERNAL" -eq 0 ]; then
  # Only built-in display, hide the item
  sketchybar --set "$NAME" drawing=off
  exit 0
fi

# External monitor detected (or clamshell mode), ensure item is visible
sketchybar --set "$NAME" drawing=on

# Function to format seconds to MM:SS
format_time() {
  local seconds=$1
  # Strip whitespace and validate it's a number
  seconds=$(echo "$seconds" | sed 's/[^0-9]//g')
  if [ -z "$seconds" ] || [ "$seconds" -eq 0 ] 2>/dev/null; then
    echo "0:00"
    return
  fi

  local minutes=$((seconds / 60))
  local remaining_seconds=$((seconds % 60))
  printf "%d:%02d" $minutes $remaining_seconds
}

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
  # Get track info
  ARTIST=$(osascript -e 'tell application "Music" to get artist of current track' 2>/dev/null)
  TITLE=$(osascript -e 'tell application "Music" to get name of current track' 2>/dev/null)
  ALBUM=$(osascript -e 'tell application "Music" to get album of current track' 2>/dev/null)

  # Get time info (in seconds)
  CURRENT_TIME=$(osascript -e 'tell application "Music" to get player position' 2>/dev/null | awk '{print int($1)}')
  TOTAL_LENGTH=$(osascript -e 'tell application "Music" to get duration of current track' 2>/dev/null | awk '{print int($1)}')

  # Format times
  if [ -n "$CURRENT_TIME" ] && [ -n "$TOTAL_LENGTH" ] && [ "$CURRENT_TIME" != "0" ] && [ "$TOTAL_LENGTH" != "0" ]; then
    FORMATTED_CURRENT=$(format_time "$CURRENT_TIME")
    FORMATTED_TOTAL=$(format_time "$TOTAL_LENGTH")
    TIME_DISPLAY=" [$FORMATTED_CURRENT / $FORMATTED_TOTAL]"
  else
    TIME_DISPLAY=""
  fi

  # Set play/pause icon based on state
  if [ "$MUSIC_STATE" = "playing" ]; then
    PLAY_ICON="󰏤" # pause icon (nerd font)
  else
    PLAY_ICON="󰐊" # play icon (nerd font)
  fi

  # Display track info
  if [ -n "$ARTIST" ] && [ -n "$TITLE" ]; then
    if [ -n "$ALBUM" ]; then
      # Show artist - album - track format with time
      sketchybar --set "$NAME" label="♪ $PLAY_ICON $ARTIST - $ALBUM - $TITLE$TIME_DISPLAY"
    else
      # Show artist - track if no album with time
      sketchybar --set "$NAME" label="♪ $PLAY_ICON $ARTIST - $TITLE$TIME_DISPLAY"
    fi
  elif [ -n "$TITLE" ]; then
    # Just show title if no artist info with time
    sketchybar --set "$NAME" label="♪ $PLAY_ICON $TITLE$TIME_DISPLAY"
  else
    if [ "$MUSIC_STATE" = "playing" ]; then
      # Music is running but no song info available
      sketchybar --set "$NAME" label="♪ $PLAY_ICON Music playing$TIME_DISPLAY"
    else
      sketchybar --set "$NAME" label="♪ $PLAY_ICON Music paused"
    fi
  fi
else
  # Check if VLC RC interface is available and get current song info
  VLC_INFO=$(echo "info" | nc -w 2 localhost 4212 2>/dev/null)

  if [ $? -eq 0 ] && [ -n "$VLC_INFO" ]; then
    # Check if VLC is playing or paused
    VLC_STATUS=$(echo "status" | nc -w 1 localhost 4212 2>/dev/null)
    IS_PLAYING=$(echo "$VLC_STATUS" | grep -i "playing")

    # Get current time and length
    CURRENT_TIME=$(echo "get_time" | nc -w 1 localhost 4212 2>/dev/null | grep "^> [0-9]" | sed 's/^> //')
    TOTAL_LENGTH=$(echo "get_length" | nc -w 1 localhost 4212 2>/dev/null | grep "^> [0-9]" | sed 's/^> //')

    # Format times
    if [ -n "$CURRENT_TIME" ] && [ -n "$TOTAL_LENGTH" ] && [ "$CURRENT_TIME" != "0" ] && [ "$TOTAL_LENGTH" != "0" ]; then
      FORMATTED_CURRENT=$(format_time "$CURRENT_TIME")
      FORMATTED_TOTAL=$(format_time "$TOTAL_LENGTH")
      TIME_DISPLAY=" [$FORMATTED_CURRENT / $FORMATTED_TOTAL]"
    else
      TIME_DISPLAY=""
    fi

    # Set play/pause icon based on status
    if [ -n "$IS_PLAYING" ]; then
      PLAY_ICON="󰏤" # pause icon (nerd font)
    else
      PLAY_ICON="󰐊" # play icon (nerd font)
    fi

    # Parse artist, album, and title from the info output
    ARTIST=$(echo "$VLC_INFO" | grep "| artist:" | sed 's/| artist: //' | sed 's/^[ \t]*//' | sed 's/[ \t]*$//')
    ALBUM=$(echo "$VLC_INFO" | grep "| album:" | sed 's/| album: //' | sed 's/^[ \t]*//' | sed 's/[ \t]*$//')
    TITLE=$(echo "$VLC_INFO" | grep "| title:" | sed 's/| title: //' | sed 's/^[ \t]*//' | sed 's/[ \t]*$//')

    # Check if we got the basic info
    if [ -n "$ARTIST" ] && [ -n "$TITLE" ]; then
      if [ -n "$ALBUM" ]; then
        # Show artist - album - track format with time
        sketchybar --set "$NAME" label="♪ $PLAY_ICON $ARTIST - $ALBUM - $TITLE$TIME_DISPLAY"
      else
        # Show artist - track if no album with time
        sketchybar --set "$NAME" label="♪ $PLAY_ICON $ARTIST - $TITLE$TIME_DISPLAY"
      fi
    elif [ -n "$TITLE" ]; then
      # Just show title if no artist info with time
      sketchybar --set "$NAME" label="♪ $PLAY_ICON $TITLE$TIME_DISPLAY"
    else
      if [ -n "$IS_PLAYING" ]; then
        # VLC is running but no song info available
        sketchybar --set "$NAME" label="♪ $PLAY_ICON VLC playing$TIME_DISPLAY"
      else
        sketchybar --set "$NAME" label="♪ $PLAY_ICON VLC stopped"
      fi
    fi
  else
    # VLC RC not available, show current app name using aerospace
    APP_NAME=$(aerospace list-windows --focused --format '%{app-name}' 2>/dev/null || echo "Desktop")

    # Set the label to show the current app name
    sketchybar --set "$NAME" label="$APP_NAME"
  fi
fi
