#!/bin/bash
# ~/.local/bin/openrgb-autoload.sh
sleep 5
LAST_PROFILE=$(cat ~/.config/openrgb/last-profile 2>/dev/null)
if [[ -n "$LAST_PROFILE" ]]; then
    openrgb --profile "$LAST_PROFILE"
fi
