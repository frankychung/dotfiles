#!/bin/bash

# Show current app name using lsappinfo
APP_NAME=$(lsappinfo info -only name $(lsappinfo front) | cut -d'"' -f4)

# Fallback if no app is focused
if [ -z "$APP_NAME" ]; then
  APP_NAME="Desktop"
fi

# Set the label to show the current app name
sketchybar --set "$NAME" label="$APP_NAME"
