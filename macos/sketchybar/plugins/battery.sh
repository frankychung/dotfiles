#!/bin/bash

# Get battery information
BATTERY_INFO=$(pmset -g batt)
PERCENTAGE=$(echo "$BATTERY_INFO" | grep -o '[0-9]*%' | cut -d'%' -f1)
CHARGING=$(echo "$BATTERY_INFO" | grep -c "AC Power")

# Convert percentage to number for comparison
PERCENTAGE_NUM=$((10#$PERCENTAGE))

# Determine battery icon based on charge level
if [ $PERCENTAGE_NUM -ge 85 ]; then
  BATTERY_ICON="" # You'll replace with 100-85% icon
elif [ $PERCENTAGE_NUM -ge 60 ]; then
  BATTERY_ICON="" # You'll replace with 85-60% icon
elif [ $PERCENTAGE_NUM -ge 35 ]; then
  BATTERY_ICON="" # You'll replace with 60-35% icon
elif [ $PERCENTAGE_NUM -ge 10 ]; then
  BATTERY_ICON="" # You'll replace with 35-10% icon
else
  BATTERY_ICON="" # You'll replace with 10-0% icon
fi

# Add charging icon if plugged in
if [ $CHARGING -gt 0 ]; then
  CHARGING_ICON="󱐋" # You'll replace with charging icon
  ICON="${BATTERY_ICON}${CHARGING_ICON}"
  LABEL="${PERCENTAGE}%"
else
  ICON="$BATTERY_ICON"
  LABEL="${PERCENTAGE}%"
fi

sketchybar --set "$NAME" icon="$ICON" label="$LABEL"

