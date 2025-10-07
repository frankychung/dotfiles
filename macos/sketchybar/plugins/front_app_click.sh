#!/bin/bash

# Check if Apple Music is running and playing/paused
MUSIC_STATE=$(osascript -e 'if application "Music" is running then
    tell application "Music"
        if player state is playing or player state is paused then
            return "active"
        end if
    end tell
end if' 2>/dev/null)

if [ "$MUSIC_STATE" = "active" ]; then
  # Toggle Apple Music play/pause
  osascript -e 'tell application "Music" to playpause' 2>/dev/null
else
  # Toggle VLC play/pause
  echo "pause" | nc -w 1 localhost 4212 >/dev/null 2>&1
fi

# Trigger front_app update to refresh the display immediately
sketchybar --trigger front_app_switched