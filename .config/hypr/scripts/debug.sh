#!/usr/bin/env bash
# Debug Alt+Tab Issue

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🔍 Alt+Tab Debug Check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check 1: Script exists?
echo "1️⃣  Checking if script exists..."
if [ -f "$HOME/.config/hypr/scripts/alt-tab-rofi.sh" ]; then
    echo "✅ Script found: ~/.config/hypr/scripts/alt-tab-rofi.sh"
    ls -lh "$HOME/.config/hypr/scripts/alt-tab-rofi.sh"
else
    echo "❌ Script NOT found!"
    echo "   Looking for: ~/.config/hypr/scripts/alt-tab-rofi.sh"
fi

echo ""

# Check 2: Executable?
echo "2️⃣  Checking if script is executable..."
if [ -x "$HOME/.config/hypr/scripts/alt-tab-rofi.sh" ]; then
    echo "✅ Script is executable"
else
    echo "❌ Script is NOT executable!"
    echo "   Fix: chmod +x ~/.config/hypr/scripts/alt-tab-rofi.sh"
fi

echo ""

# Check 3: Rofi installed?
echo "3️⃣  Checking if rofi is installed..."
if command -v rofi &>/dev/null; then
    echo "✅ rofi is installed"
    rofi -version | head -1
else
    echo "❌ rofi is NOT installed!"
    echo "   Install: sudo pacman -S rofi"
fi

echo ""

# Check 4: Test rofi directly
echo "4️⃣  Testing rofi window mode..."
echo "   Running: rofi -show window"
echo "   (This should open rofi - press ESC to close)"
sleep 2
rofi -show window 2>&1 | head -5 || echo "❌ Rofi failed to launch!"

echo ""

# Check 5: Alt+Tab keybind
echo "5️⃣  Checking Alt+Tab keybind in config..."
HYPR_CONF="$HOME/.config/hypr/hyprland.conf"
KEYBINDS_CONF="$HOME/.config/hypr/keybinds.conf"

if [ -f "$KEYBINDS_CONF" ]; then
    echo "📄 Checking keybinds.conf:"
    grep -n "bind.*ALT.*TAB" "$KEYBINDS_CONF" 2>/dev/null || echo "   ❌ No Alt+Tab bind found"
fi

echo ""
echo "📄 Checking hyprland.conf:"
grep -n "bind.*ALT.*TAB" "$HYPR_CONF" 2>/dev/null || echo "   ❌ No Alt+Tab bind found"

echo ""

# Check 6: Conflicting binds
echo "6️⃣  Checking for conflicting Alt+Tab binds..."
ALL_BINDS=$(grep "bind.*ALT.*TAB" "$HYPR_CONF" "$KEYBINDS_CONF" 2>/dev/null)

if [ -n "$ALL_BINDS" ]; then
    echo "Found binds:"
    echo "$ALL_BINDS"
    
    COUNT=$(echo "$ALL_BINDS" | grep -c "bind.*ALT, TAB")
    if [ "$COUNT" -gt 1 ]; then
        echo ""
        echo "⚠️  WARNING: Multiple Alt+Tab binds found!"
        echo "   Only the LAST one will work"
    fi
else
    echo "❌ NO Alt+Tab bind found in config!"
fi

echo ""

# Check 7: Test script manually
echo "7️⃣  Testing script manually..."
echo "   Running: ~/.config/hypr/scripts/alt-tab-rofi.sh"
echo "   (Rofi should open - press ESC to close)"
sleep 2

if [ -f "$HOME/.config/hypr/scripts/alt-tab-rofi.sh" ]; then
    "$HOME/.config/hypr/scripts/alt-tab-rofi.sh" &
    SCRIPT_PID=$!
    sleep 3
    
    if kill -0 $SCRIPT_PID 2>/dev/null; then
        echo "✅ Script is running"
        kill $SCRIPT_PID 2>/dev/null
    else
        echo "⚠️  Script finished or crashed"
    fi
else
    echo "❌ Cannot test - script not found"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  📋 DIAGNOSIS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Provide diagnosis
if ! [ -f "$HOME/.config/hypr/scripts/alt-tab-rofi.sh" ]; then
    echo "❌ PROBLEM: Script not installed"
    echo ""
    echo "🔧 FIX:"
    echo "   cp alt-tab-rofi-final.sh ~/.config/hypr/scripts/alt-tab-rofi.sh"
    echo "   chmod +x ~/.config/hypr/scripts/alt-tab-rofi.sh"
elif ! grep -q "bind.*ALT, TAB.*alt-tab-rofi.sh" "$HYPR_CONF" "$KEYBINDS_CONF" 2>/dev/null; then
    echo "❌ PROBLEM: Alt+Tab keybind not configured"
    echo ""
    echo "🔧 FIX:"
    echo "   echo 'bind = ALT, TAB, exec, ~/.config/hypr/scripts/alt-tab-rofi.sh' >> ~/.config/hypr/hyprland.conf"
    echo "   hyprctl reload"
else
    echo "✅ Everything looks good!"
    echo ""
    echo "💡 If Alt+Tab still doesn't work:"
    echo "   1. Try: hyprctl reload"
    echo "   2. Check if another program is catching Alt+Tab"
    echo "   3. Test with different key: bind = SUPER, TAB, exec, ..."
fi

echo ""