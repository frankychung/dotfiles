#!/bin/bash

# Get current WiFi interface
WIFI_INTERFACE=$(networksetup -listallhardwareports | awk '/Wi-Fi|AirPort/{getline; print $NF}')

# Check if WiFi is connected by checking if interface has an IP address
IP_ADDRESS=$(ipconfig getifaddr "$WIFI_INTERFACE" 2>/dev/null)

# Check if connected to WiFi
if [ -n "$IP_ADDRESS" ]; then
  # Connected to WiFi
  WIFI_ICON="󰖩"
else
  # Not connected to WiFi
  WIFI_ICON="󰖪"
fi

sketchybar --set "$NAME" icon="$WIFI_ICON" label=""

