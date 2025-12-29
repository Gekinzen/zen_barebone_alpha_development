#!/bin/bash
# Launch Hyprland Control Center without warnings

cd ~/.config/hypr-control-center

# Suppress GTK/Vulkan warnings
export GDK_BACKEND=x11  # Force X11 backend (no Vulkan)
export GTK_THEME=Adwaita:dark  # Use system theme

# Run with stderr filtered
python3 main.py 2>&1 | grep -v "Gtk-WARNING\|Gdk-WARNING\|libEGL\|Vulkan"