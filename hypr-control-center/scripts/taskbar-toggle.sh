#!/bin/bash
# Toggle panel_widget.py

PANEL_PID=$(pgrep -f "panel_widget.py")

if [ -n "$PANEL_PID" ]; then
    # Panel is running - kill it
    kill $PANEL_PID
else
    # Panel not running - start it
    LD_PRELOAD=/usr/lib/libgtk4-layer-shell.so python3 ~/.config/hypr-control-center/src/panel/panel_widget.py &
fi