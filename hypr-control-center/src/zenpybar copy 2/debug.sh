#!/bin/bash
# Quick Debug & Fix Script
# Run this to diagnose and fix config issues

echo "╔══════════════════════════════════════════════════════════╗"
echo "║         ZenPyBar Config Debug & Fix                     ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo

# 1. Check Waybar config exists
echo "1️⃣  Checking Waybar config..."
if [ -f ~/.config/waybar/config.jsonc ]; then
    echo "   ✅ Found: config.jsonc"
    WAYBAR_CONFIG=~/.config/waybar/config.jsonc
elif [ -f ~/.config/waybar/config.json ]; then
    echo "   ✅ Found: config.json"
    WAYBAR_CONFIG=~/.config/waybar/config.json
else
    echo "   ❌ No Waybar config found!"
    exit 1
fi

# 2. Show what's in the config
echo
echo "2️⃣  Showing Waybar config content..."
python3 dump_waybar_config.py

# 3. Run diagnostic
echo
echo "3️⃣  Running diagnostic..."
python3 check_config.py

# 4. Force sync
echo
echo "4️⃣  Force syncing config..."
python3 config_sync.py --force

# 5. Check generated config
echo
echo "5️⃣  Generated ZenPyBar config:"
if [ -f ~/.config/hypr-control-center/preferences/zenpybar.json ]; then
    echo
    cat ~/.config/hypr-control-center/preferences/zenpybar.json | head -30
    echo
    echo "   ..."
    echo
else
    echo "   ❌ No zenpybar.json generated!"
fi

# 6. Offer to restart
echo
echo "6️⃣  Ready to test?"
echo "   Run: ./run.sh"
echo
echo "   Or check with: hyprctl layers | grep zenpybar"
echo