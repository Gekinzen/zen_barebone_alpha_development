#!/usr/bin/env bash

# Check if blueman-manager is running
if pgrep -x blueman-manager >/dev/null; then
    # Kill blueman-manager
    pkill -x blueman-manager
else
    # Launch blueman-manager normally
    blueman-manager &
fi

