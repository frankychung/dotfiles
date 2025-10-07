#!/usr/bin/env bash

# Check if this workspace has windows
HAS_WINDOWS=$(aerospace list-windows --workspace "$1" --format '%{window-id}' 2>/dev/null)

# Only show workspace if it has windows or is focused
if [ -n "$HAS_WINDOWS" ] || [ "$1" = "$FOCUSED_WORKSPACE" ]; then
    if [ "$1" = "$FOCUSED_WORKSPACE" ]; then
        sketchybar --set "$NAME" drawing=on background.drawing=on icon.color=0xff000000
    else
        sketchybar --set "$NAME" drawing=on background.drawing=off icon.color=0xffffffff
    fi
    sketchybar --set windows."$1" drawing=on
else
    sketchybar --set "$NAME" drawing=off
    sketchybar --set windows."$1" drawing=off
fi

