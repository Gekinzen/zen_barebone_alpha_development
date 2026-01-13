#!/usr/bin/env bash
# Waybar Custom Music Module

players=$(playerctl -l 2>/dev/null)

if [ -z "$players" ]; then
    echo '{"text":"󰝛","class":"idle","tooltip":"No media detected"}'
    exit 0
fi

active=""
state=""

# Priority 1: Find Playing media
for player in $players; do
    status=$(playerctl -p "$player" status 2>/dev/null)
    if [ "$status" = "Playing" ]; then
        active="$player"
        state="playing"
        break
    fi
done

# Priority 2: Fallback to Paused
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

# Priority 3: First available
if [ -z "$active" ]; then
    active=$(echo "$players" | head -1)
    state="idle"
fi

if [ -z "$active" ]; then
    echo '{"text":"󰝛","class":"idle","tooltip":"No media playing"}'
    exit 0
fi

# Get metadata
title=$(playerctl -p "$active" metadata title 2>/dev/null)
artist=$(playerctl -p "$active" metadata artist 2>/dev/null)
album=$(playerctl -p "$active" metadata album 2>/dev/null)
player_name=$(playerctl -p "$active" metadata playerName 2>/dev/null)

# Fallbacks
title=${title:-Unknown Title}
artist=${artist:-Unknown Artist}
player_name=${player_name:-Media Player}

# Escape special characters for JSON
escape_json() {
    echo "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/g' | tr -d '\n' | sed 's/\\n$//'
}

title=$(escape_json "$title")
artist=$(escape_json "$artist")
album=$(escape_json "$album")
player_name=$(escape_json "$player_name")

# Icon based on state
case "$state" in
    playing) icon="󰎈" ;;
    paused) icon="󰏤" ;;
    *) icon="󰝛" ;;
esac

# Build display text
if [ "$artist" != "Unknown Artist" ]; then
    text="$artist - $title"
else
    text="$title"
fi

# Build tooltip (escape newlines properly)
tooltip="${icon} ${player_name}\\nTitle: ${title}\\nArtist: ${artist}"
[ -n "$album" ] && tooltip="${tooltip}\\nAlbum: ${album}"

# Output valid JSON
printf '{"text":"%s","class":"%s","tooltip":"%s"}\n' "$text" "$state" "$tooltip"