#!/usr/bin/env bash
# Waybar Custom Music Module
# Shows currently playing media with marquee effect

# Get all available players
players=$(playerctl -l 2>/dev/null)

# No players detected
if [ -z "$players" ]; then
    echo '{"text":"󰝛","class":"idle","tooltip":"No media detected"}'
    exit 0
fi

active=""
state=""

# Priority 1: Find any Playing media
for player in $players; do
    status=$(playerctl -p "$player" status 2>/dev/null)
    if [ "$status" = "Playing" ]; then
        active="$player"
        state="playing"
        break
    fi
done

# Priority 2: Fallback to Paused media
if [ -z "$active" ]; then
    for player in $players; do
        status=$(playerctl -p "$player" status 2>/dev/null)
        if [ "$status" = "Paused" ]; then
            active="$player"
            state="paused"
            break
        fi
    done
fi

# Priority 3: Just grab first available player
if [ -z "$active" ]; then
    active=$(echo "$players" | head -1)
    state="idle"
fi

# Nothing usable found
if [ -z "$active" ]; then
    echo '{"text":"󰝛","class":"idle","tooltip":"No media playing"}'
    exit 0
fi

# Get metadata
title=$(playerctl -p "$active" metadata title 2>/dev/null)
artist=$(playerctl -p "$active" metadata artist 2>/dev/null)
album=$(playerctl -p "$active" metadata album 2>/dev/null)
player_name=$(playerctl -p "$active" metadata playerName 2>/dev/null)

# Fallbacks for missing metadata
title=${title:-Unknown Title}
artist=${artist:-Unknown Artist}
album=${album:-}
player_name=${player_name:-Media Player}

# Icon based on state
case "$state" in
    playing)
        icon="󰎈"  # Nerd Font play icon
        ;;
    paused)
        icon="󰏤"  # Nerd Font pause icon
        ;;
    *)
        icon="󰝛"  # Nerd Font stop icon
        ;;
esac

# Build display text
if [ "$artist" != "Unknown Artist" ]; then
    text="$artist - $title"
else
    text="$title"
fi

# Build tooltip
tooltip="$icon $player_name\n"
tooltip+="Title: $title\n"
tooltip+="Artist: $artist"
[ -n "$album" ] && tooltip+="\nAlbum: $album"

# Output JSON for Waybar
echo "{\"text\":\"$text\",\"class\":\"$state\",\"tooltip\":\"$tooltip\"}"