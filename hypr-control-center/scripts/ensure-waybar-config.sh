#!/bin/bash
# ensure-waybar-config.sh
# Run this on startup to ensure start-menu config exists
# Add to hyprland.conf: exec-once = ~/.config/hypr-control-center/scripts/ensure-waybar-config.sh

WAYBAR_CONFIG="$HOME/.config/waybar/config.jsonc"
SCRIPTS_DIR="$HOME/.config/hypr-control-center/scripts"

# Start menu default config
START_MENU_CONFIG='"custom/start-menu": {
    "format": "  ",
    "tooltip": true,
    "on-click": "'$SCRIPTS_DIR'/start-menu-toggle.sh",
    "on-click-right": "'$SCRIPTS_DIR'/start-menu-toggle.sh close"
}'

# Check if waybar config exists
if [[ ! -f "$WAYBAR_CONFIG" ]]; then
    echo "Waybar config not found: $WAYBAR_CONFIG"
    exit 1
fi

# Check if custom/start-menu already exists
if grep -q '"custom/start-menu"' "$WAYBAR_CONFIG"; then
    echo "start-menu config already exists"
    exit 0
fi

# Backup original config
cp "$WAYBAR_CONFIG" "$WAYBAR_CONFIG.bak"

# Find the last closing brace and insert before it
# Using python for safer JSON handling
python3 << 'PYTHON_SCRIPT'
import json
import re
import sys
from pathlib import Path

config_path = Path.home() / ".config/waybar/config.jsonc"
scripts_dir = Path.home() / ".config/hypr-control-center/scripts"

try:
    content = config_path.read_text()
    
    # Remove comments for parsing
    clean = re.sub(r'//.*$', '', content, flags=re.MULTILINE)
    clean = re.sub(r'/\*.*?\*/', '', clean, flags=re.DOTALL)
    clean = re.sub(r',(\s*[}\]])', r'\1', clean)  # Remove trailing commas
    
    config = json.loads(clean)
    
    # Check if start-menu exists
    if "custom/start-menu" in config:
        print("start-menu already configured")
        sys.exit(0)
    
    # Add start-menu config
    config["custom/start-menu"] = {
        "format": "  ",
        "tooltip": True,
        "on-click": str(scripts_dir / "start-menu-toggle.sh"),
        "on-click-right": str(scripts_dir / "start-menu-toggle.sh") + " close"
    }
    
    # Find position to insert in original content (preserve comments)
    # Insert before the last }
    insert_pos = content.rfind('}')
    if insert_pos > 0:
        # Check if we need a comma
        before = content[:insert_pos].rstrip()
        needs_comma = not before.endswith(',') and not before.endswith('{')
        
        start_menu_json = '''
    "custom/start-menu": {
        "format": "  ",
        "tooltip": true,
        "on-click": "''' + str(scripts_dir / "start-menu-toggle.sh") + '''",
        "on-click-right": "''' + str(scripts_dir / "start-menu-toggle.sh") + ''' close"
    }'''
        
        new_content = content[:insert_pos]
        if needs_comma:
            new_content = new_content.rstrip() + ','
        new_content += start_menu_json + '\n' + content[insert_pos:]
        
        config_path.write_text(new_content)
        print("Added start-menu config")
    else:
        print("Could not find insertion point")
        sys.exit(1)
        
except Exception as e:
    print(f"Error: {e}")
    sys.exit(1)
PYTHON_SCRIPT

# Reload waybar if running
if pgrep -x waybar > /dev/null; then
    pkill -SIGUSR2 waybar
fi

echo "Waybar config updated"