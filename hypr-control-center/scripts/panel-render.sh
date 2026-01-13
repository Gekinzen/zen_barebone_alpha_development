#!/bin/bash
# Panel Render for Waybar
cd ~/.config/hypr-control-center
python3 src/panel/waybar_output.py 2>/dev/null || echo '{"text": "", "tooltip": "Loading..."}'