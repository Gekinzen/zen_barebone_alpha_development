#!/bin/bash
# Launch Hyprland Control Center
# This script properly loads custom CSS without theme overrides

cd ~/.config/hypr-control-center

# Don't override GTK theme - let app use its own CSS!
unset GTK_THEME
unset GTK2_RC_FILES

# Use Wayland backend
export GDK_BACKEND=wayland

# Launch app
python3 main.py