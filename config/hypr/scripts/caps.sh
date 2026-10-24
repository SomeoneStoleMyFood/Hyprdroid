#!/bin/bash
sleep 0.1
caps_state=$(hyprctl devices -j | jq -r '.keyboards[] | select(.main == true) | .capsLock')

if [ "$caps_state" = "true" ]; then
    notify-send -a "Android" "Keyboard" "CapsLock ON"
else
    notify-send -a "Android" "Keyboard" "CapsLock OFF"
fi
