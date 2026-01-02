#!/usr/bin/env bash

# Check if pavucontrol is running
if pgrep -f "pavucontrol" >/dev/null; then
    # Kill all pavucontrol processes
    pkill -f "pavucontrol"
else
    # Launch pavucontrol normally
    pavucontrol &
fi

