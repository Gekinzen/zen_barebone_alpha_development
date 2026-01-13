#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Panel Click Handler for Waybar
# Handles left/middle/right click on taskbar items
# Location: ~/.config/hypr-control-center/scripts/panel-click.sh
# ═══════════════════════════════════════════════════════════════

PANEL_DIR="$HOME/.config/hypr-control-center"

# Get click position from environment (set by Waybar)
# WAYBAR_BUTTON: 1=left, 2=middle, 3=right
BUTTON="${WAYBAR_BUTTON:-1}"

cd "$PANEL_DIR"
python3 -c "
import sys
sys.path.insert(0, '.')
from src.panel.waybar_output import handle_click
handle_click('$BUTTON')
" 2>/dev/null