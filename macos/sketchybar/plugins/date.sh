#!/bin/bash

# Get current date in format "Thursday, July 2"
DATE=$(date '+%A, %B %-d')

sketchybar --set "$NAME" label="$DATE"