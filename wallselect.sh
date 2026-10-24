#!/bin/bash

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"

if [ ! -d "$WALLPAPER_DIR" ]; then
    notify-send -a "Android" "Error" "Folder not found: $WALLPAPER_DIR"
    exit 1
fi

SELECTED_WALLPAPER=$(find "$WALLPAPER_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.gif" \) | while read -r img; do
    filename=$(basename "$img")
    echo -en "$filename\x00icon\x1f$img\n"
done | rofi -dmenu -i -show-icons -p "Wallpapers" \
     -theme-str 'entry { placeholder: "Search wallpapers..."; }')
if [ -n "$SELECTED_WALLPAPER" ]; then
    awww img "$WALLPAPER_DIR/$SELECTED_WALLPAPER" --transition-type grow --transition-duration 2
    matugen image "$WALLPAPER_DIR/$SELECTED_WALLPAPER" -m dark --prefer darkness
fi
