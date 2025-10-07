#!/bin/bash

# Get volume level and mute status
VOLUME=$(osascript -e "output volume of (get volume settings)")
MUTED=$(osascript -e "output muted of (get volume settings)")

# Get current audio output device (similar to macOS menu bar)
OUTPUT_DEVICE=$(SwitchAudioSource -c 2>/dev/null || echo "")

# If SwitchAudioSource isn't available, fall back to system_profiler (slower)
if [ -z "$OUTPUT_DEVICE" ]; then
  # Find the device name that has "Default Output Device: Yes"
  OUTPUT_DEVICE=$(system_profiler SPAudioDataType 2>/dev/null | grep -B 20 "Default Output Device: Yes" | grep "^        [A-Z]" | tail -1 | sed 's/^        //' | sed 's/:$//')
fi

# Fallback if still empty
if [ -z "$OUTPUT_DEVICE" ]; then
  OUTPUT_DEVICE="Audio Output"
fi

# Determine icon based on mute status or zero volume
if [ "$MUTED" = "true" ] || [ "$VOLUME" -eq 0 ]; then
  VOLUME_ICON="󰖁" # You'll replace with muted icon
  LABEL="${OUTPUT_DEVICE}"
else
  VOLUME_ICON="󰕾" # You'll replace with volume icon
  LABEL="${VOLUME}% ${OUTPUT_DEVICE}"
fi

sketchybar --set "$NAME" icon="$VOLUME_ICON" label="$LABEL"
