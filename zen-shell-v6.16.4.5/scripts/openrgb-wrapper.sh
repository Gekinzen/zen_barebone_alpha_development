#!/bin/bash
# ~/.local/bin/openrgb-wrapper.sh

# If a profile is being set, save it as the last used
if [[ "$*" == *"--profile"* ]]; then
    for i in "$@"; do
        if [[ "$prev" == "--profile" ]]; then
            echo "$i" > ~/.config/openrgb/last-profile
        fi
        prev="$i"
    done
fi

/usr/bin/openrgb "$@"
