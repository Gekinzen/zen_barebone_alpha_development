#!/usr/bin/env bash

# Folder containing wallpapers
WALL_DIR="$HOME/walls"

# Temporary folder for small preview icons
PREVIEW_DIR="$HOME/.config/rofi/wallpaper_previews"
mkdir -p "$PREVIEW_DIR"

# Check if Rofi is already open
if pgrep -x "rofi" > /dev/null; then
    pkill -x rofi
    exit 0
fi

# Get first 5 wallpapers (.jpg or .png)
PICS=($(ls "$WALL_DIR" | grep -E "\.(jpg|png)$" | head -n 5))

# Generate Rofi input with icon previews
ROFI_INPUT=""
for w in "${PICS[@]}"; do
    SRC="$WALL_DIR/$w"
    PREVIEW="$PREVIEW_DIR/$w"

    # Generate small 80x80 preview using ImageMagick
    convert "$SRC" -resize 80x80 "$PREVIEW"

    # Add to Rofi input
    ROFI_INPUT+="$w icon $PREVIEW\n"
done

# Add a random option
ROFI_INPUT+="Random icon /usr/share/icons/Adwaita/32x32/actions/view-refresh.png\n"

# Path to Rofi theme
THEME="$HOME/.config/rofi/wallpapers.rasi"

# Launch Rofi and get selection
SELECTED=$(echo -e "$ROFI_INPUT" | rofi -show run -theme "$THEME" -i -p "Select Wallpaper:")

# Apply the selected wallpaper
if [[ -n "$SELECTED" ]]; then
    if [[ "$SELECTED" == "Random" ]]; then
        RANDOM_PIC=${PICS[ $RANDOM % ${#PICS[@]} ]}
        swaybg -i "$WALL_DIR/$RANDOM_PIC" -m fill &
    else
        swaybg -i "$WALL_DIR/$SELECTED" -m fill &
    fi
fi

