#!/bin/bash
# ZenPyBar Launcher
# Location: ~/.config/hypr-control-center/src/zenpybar/run.sh
#
# This script launches bar.py which automatically spawns panel_widget.py
# if taskbar modules (hyprland/taskbar, custom/panel, hyprland/window) are detected

# CRITICAL: LD_PRELOAD is required for GTK4 Layer Shell to work properly
export LD_PRELOAD=/usr/lib/libgtk4-layer-shell.so

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Run ZenPyBar - it will auto-launch panel if needed
exec python3 "$SCRIPT_DIR/bar.py" "$@"