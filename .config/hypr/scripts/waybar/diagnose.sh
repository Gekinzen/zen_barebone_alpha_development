#!/usr/bin/env bash
# Diagnostic script to check taskbar icon issues (JSONC support)

echo "╔════════════════════════════════════════════════╗"
echo "║  Taskbar Icon Diagnostic Tool                 ║"
echo "╚════════════════════════════════════════════════╝"
echo ""

# Check current panel style
PANEL_STYLE_FILE="$HOME/.config/hypr-control-center/preferences/waybar-menu.json"

if [ -f "$PANEL_STYLE_FILE" ]; then
    CURRENT_STYLE=$(jq -r '.style_mode' "$PANEL_STYLE_FILE" 2>/dev/null)
    echo "✅ Panel Style File: $PANEL_STYLE_FILE"
    echo "   Current Style: $CURRENT_STYLE"
else
    echo "❌ Panel Style File NOT FOUND: $PANEL_STYLE_FILE"
    CURRENT_STYLE="minimal"
fi
echo ""

# Check get-app-icon.py
ICON_SCRIPT="$HOME/.config/hypr/scripts/waybar/get-app-icon.py"

if [ -f "$ICON_SCRIPT" ]; then
    echo "✅ Icon Script: $ICON_SCRIPT"
    
    # Test with common apps
    echo ""
    echo "Testing icon resolution:"
    for app in firefox code thunar kitty; do
        result=$("$ICON_SCRIPT" "$app" 2>&1)
        
        if [[ "$result" == file://* ]]; then
            icon_path="${result#file://}"
            
            # Check if file exists and is PNG
            if [ -f "$icon_path" ]; then
                ext="${icon_path##*.}"
                size=$(stat -f%z "$icon_path" 2>/dev/null || stat -c%s "$icon_path" 2>/dev/null)
                
                if [ "$ext" = "png" ]; then
                    echo "  ✅ $app → PNG (${size} bytes)"
                elif [ "$ext" = "svg" ]; then
                    echo "  ⚠️  $app → SVG (may cause GTK errors)"
                else
                    echo "  ⚠️  $app → .$ext"
                fi
            else
                echo "  ❌ $app → File not found: $icon_path"
            fi
        else
            echo "  ✅ $app → $result (Nerd Font fallback)"
        fi
    done
else
    echo "❌ Icon Script NOT FOUND: $ICON_SCRIPT"
fi
echo ""

# Check running apps
echo "Currently running applications:"
hyprctl clients -j 2>/dev/null | jq -r '.[].class' | sort -u | head -5 | while read app; do
    echo "  • $app"
done
echo ""

# Test taskbar render
echo "Testing taskbar render output:"
RENDER_SCRIPT="$HOME/.config/hypr/scripts/waybar/taskbar-render.sh"

if [ -f "$RENDER_SCRIPT" ]; then
    OUTPUT=$("$RENDER_SCRIPT" 2>&1)
    
    # Check for errors
    if echo "$OUTPUT" | grep -qi "error"; then
        echo "  ❌ Errors detected in render output"
        echo "$OUTPUT" | grep -i "error" | head -3
    else
        # Parse JSON
        TEXT=$(echo "$OUTPUT" | jq -r '.text' 2>/dev/null)
        
        if [ -n "$TEXT" ]; then
            echo "  ✅ Render successful"
            echo "  Style: $CURRENT_STYLE"
            
            # Check if contains HTML img tags (modern mode)
            if echo "$TEXT" | grep -q "<img"; then
                IMG_COUNT=$(echo "$TEXT" | grep -o "<img" | wc -l)
                echo "  Mode: Modern (HTML markup)"
                echo "  Icons: $IMG_COUNT image tags"
                
                # Check for SVG
                if echo "$TEXT" | grep -qi "\.svg"; then
                    echo "  ⚠️  WARNING: SVG detected in markup (may cause GTK errors)"
                fi
            else
                echo "  Mode: Minimal (Nerd Fonts)"
                echo "  Output: ${TEXT:0:50}..."
            fi
        else
            echo "  ❌ Failed to parse output"
        fi
    fi
else
    echo "  ❌ Render script NOT FOUND: $RENDER_SCRIPT"
fi
echo ""

# Check Waybar config (JSONC support)
WAYBAR_CONFIG_JSONC="$HOME/.config/waybar/config.jsonc"
WAYBAR_CONFIG_JSON="$HOME/.config/waybar/config.json"

if [ -f "$WAYBAR_CONFIG_JSONC" ]; then
    WAYBAR_CONFIG="$WAYBAR_CONFIG_JSONC"
    echo "✅ Waybar Config: $WAYBAR_CONFIG (JSONC)"
elif [ -f "$WAYBAR_CONFIG_JSON" ]; then
    WAYBAR_CONFIG="$WAYBAR_CONFIG_JSON"
    echo "✅ Waybar Config: $WAYBAR_CONFIG (JSON)"
else
    WAYBAR_CONFIG=""
    echo "❌ Waybar Config NOT FOUND"
fi

if [ -n "$WAYBAR_CONFIG" ]; then
    # Check for taskbar module
    if grep -q "custom/taskbar" "$WAYBAR_CONFIG"; then
        echo "  ✅ custom/taskbar module present"
        
        # Check exec path (strip comments for JSONC)
        EXEC_LINE=$(grep "\"exec\"" "$WAYBAR_CONFIG" | grep -v "^[[:space:]]*//")
        if [ -n "$EXEC_LINE" ]; then
            echo "  Exec: $(echo $EXEC_LINE | sed 's/.*"exec"[[:space:]]*:[[:space:]]*"\(.*\)".*/\1/' | head -1)"
        fi
    else
        echo "  ⚠️  custom/taskbar module not found"
    fi
fi
echo ""

# Recommendations
echo "╔════════════════════════════════════════════════╗"
echo "║  Recommendations                               ║"
echo "╚════════════════════════════════════════════════╝"
echo ""

if [ "$CURRENT_STYLE" = "modern" ]; then
    echo "🎨 Modern mode active"
    echo ""
    echo "If you see GTK warnings about parsing errors:"
    echo "  1. Replace get-app-icon.py with PNG-only version:"
    echo "     cp get-app-icon-fixed.py ~/.config/hypr/scripts/waybar/get-app-icon.py"
    echo ""
    echo "  2. Restart Waybar:"
    echo "     pkill waybar && waybar &"
    echo ""
    echo "To switch to Minimal mode (no GTK warnings):"
    echo "  1. Open Control Center (Super+F1)"
    echo "  2. Panel Appearance → Panel Style → Minimal"
else
    echo "󰣆 Minimal mode active (Nerd Fonts)"
    echo "  No GTK warnings expected"
    echo ""
    echo "To enable colored system icons:"
    echo "  1. Open Control Center (Super+F1)"
    echo "  2. Panel Appearance → Panel Style → Modern"
fi