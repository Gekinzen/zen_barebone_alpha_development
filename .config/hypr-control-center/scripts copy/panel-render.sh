#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Panel Render Script for Waybar
# Outputs JSON format for Waybar custom module
# Location: ~/.config/hypr-control-center/scripts/panel-render.sh
# ═══════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PANEL_DIR="$HOME/.config/hypr-control-center"

# Call Python renderer
cd "$PANEL_DIR"
python3 -c "
import sys
sys.path.insert(0, '.')
from src.panel.waybar_output import render_taskbar
print(render_taskbar())
" 2>/dev/null || echo '{"text": "", "tooltip": "Panel loading..."}'