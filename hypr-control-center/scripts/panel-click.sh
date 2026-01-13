#!/bin/bash
# Panel Click Handler
cd ~/.config/hypr-control-center
python3 src/panel/waybar_output.py click "${WAYBAR_BUTTON:-1}"