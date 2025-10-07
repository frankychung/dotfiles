#!/bin/bash

# Get weather data from wttr.in for Tokyo
WEATHER_DATA=$(curl -s "wttr.in/Tokyo?format=j1" 2>/dev/null)

# Extract temperature in Fahrenheit and weather condition
if [ -n "$WEATHER_DATA" ]; then
  TEMP_F=$(echo "$WEATHER_DATA" | jq -r '.current_condition[0].temp_F' 2>/dev/null)
  WEATHER_DESC=$(echo "$WEATHER_DATA" | jq -r '.current_condition[0].weatherDesc[0].value' 2>/dev/null)

  # Check if it's day or night in Tokyo (JST = UTC+9)
  CURRENT_HOUR_UTC=$(date -u +%H)
  # Remove leading zero to avoid octal interpretation
  CURRENT_HOUR_UTC=$((10#$CURRENT_HOUR_UTC))
  TOKYO_HOUR=$(((CURRENT_HOUR_UTC + 9) % 24))

  # Consider day time as 6 AM to 6 PM (18:00) in Tokyo
  if [ $TOKYO_HOUR -ge 6 ] && [ $TOKYO_HOUR -lt 18 ]; then
    IS_DAY=true
  else
    IS_DAY=false
  fi

  # Convert weather description to our condition categories with day/night variants
  case $(echo "$WEATHER_DESC" | tr '[:upper:]' '[:lower:]') in
  *"sunny"* | *"clear"*)
    if [ "$IS_DAY" = true ]; then
      WEATHER_CONDITION="clear_day"
    else
      WEATHER_CONDITION="clear_night"
    fi
    ;;
  *"partly cloudy"* | *"partly"*)
    if [ "$IS_DAY" = true ]; then
      WEATHER_CONDITION="partly_cloudy_day"
    else
      WEATHER_CONDITION="partly_cloudy_night"
    fi
    ;;
  *"cloudy"* | *"overcast"*)
    WEATHER_CONDITION="cloudy"
    ;;
  *"light rain"* | *"drizzle"* | *"light shower"*)
    WEATHER_CONDITION="light_rain"
    ;;
  *"rain"* | *"shower"* | *"thundery"*)
    WEATHER_CONDITION="rain"
    ;;
  *"heavy rain"* | *"thunderstorm"*)
    WEATHER_CONDITION="heavy_rain"
    ;;
  *"light snow"* | *"snow shower"*)
    WEATHER_CONDITION="light_snow"
    ;;
  *"snow"* | *"blizzard"*)
    WEATHER_CONDITION="snow"
    ;;
  *"fog"* | *"mist"*)
    WEATHER_CONDITION="fog"
    ;;
  *"wind"*)
    WEATHER_CONDITION="wind"
    ;;
  *)
    WEATHER_CONDITION="default"
    ;;
  esac

  TEMP="${TEMP_F}°F"
else
  # Fallback if API fails
  WEATHER_CONDITION="default"
  TEMP="--°F"
fi

# Weather state to icon mapping - you'll manually add these icons
case $WEATHER_CONDITION in
"clear_day")
  ICON="󰖙" # You'll replace this with your sunny/day icon (sun)
  ;;
"clear_night")
  ICON="󰖔" # You'll replace this with your clear night icon (moon)
  ;;
"partly_cloudy_day")
  ICON="󰖕" # You'll replace this with your partly cloudy day icon (sun behind cloud)
  ;;
"partly_cloudy_night")
  ICON="󰼱" # You'll replace this with your partly cloudy night icon (moon behind cloud)
  ;;
"cloudy")
  ICON="󰖐" # You'll replace this with your cloudy icon
  ;;
"light_rain")
  ICON="󰖗" # You'll replace this with your light rain icon
  ;;
"rain")
  ICON="󰖗" # You'll replace this with your rain icon
  ;;
"heavy_rain")
  ICON="󰖖" # You'll replace this with your heavy rain icon
  ;;
"light_snow")
  ICON="󰖘" # You'll replace this with your light snow icon
  ;;
"snow")
  ICON="󰼶" # You'll replace this with your snow icon
  ;;
"fog")
  ICON="󰖑" # You'll replace this with your fog icon
  ;;
"wind")
  ICON="󰖝" # You'll replace this with your wind icon
  ;;
*)
  ICON="" # Default/unknown weather icon
  ;;
esac

sketchybar --set "$NAME" icon="$ICON" label="$TEMP"
