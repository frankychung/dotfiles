#!/bin/bash

PANERU="$HOME/Developer/paneru/target/release/paneru"

LABEL=$("$PANERU" query state --json 2>/dev/null | jq -r '
  def icon:
    {
      "com.apple.MobileSMS": "󱋊",
      "jp.naver.line.mac": "󱋊",
      "com.google.Chrome": "",
      "com.github.wez.wezterm": "󰢹",
      "com.tinyspeck.slackmacgap": "",
      "com.apple.Music": "󰝚",
      "com.apple.Safari": "󰀹",
      "com.apple.iCal": "󰃭",
      "com.flexibits.fantastical2": "󰃭",
      "com.apple.finder": "󰉖",
      "com.1password.1password": "",
      "com.apple.Photos": "",
      "com.apple.Maps": "󰍏",
      "com.apple.ActivityMonitor": "󰍛",
      "dev.kdrag0n.MacVirt": "󰟀"
    }[.] // "";

  if (.virtual_workspaces | length) == 0 then "no ws"
  else
    (.virtual_workspaces | length) as $n |
    [
      .virtual_workspaces[] |
      ((.windows | map((.bundle_id | icon) + (if .focused then " ◀" else "" end))) | join("  ")) as $apps |
      if $n > 1 then "\(.number): \($apps)" else $apps end
    ] | join("    ")
  end
')

if [ -z "$LABEL" ]; then
  sketchybar --set "$NAME" label="no state"
else
  sketchybar --set "$NAME" label="$LABEL"
fi
