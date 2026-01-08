#!/bin/bash
# Complete debug for clock widget

echo "════════════════════════════════════════════════════════"
echo "  CLOCK WIDGET DEBUG"
echo "════════════════════════════════════════════════════════"
echo ""

# 1. Check files
echo "1️⃣  FILE CHECK"
echo "---"
if [ -f "$HOME/.config/hypr-control-center/widgets/clock_widget.py" ]; then
    echo "✅ clock_widget.py exists"
    echo "   Size: $(stat -f%z "$HOME/.config/hypr-control-center/widgets/clock_widget.py" 2>/dev/null || stat -c%s "$HOME/.config/hypr-control-center/widgets/clock_widget.py")"
else
    echo "❌ clock_widget.py NOT FOUND"
fi

if [ -f "$HOME/.config/hypr/scripts/start-widgets.sh" ]; then
    echo "✅ start-widgets.sh exists"
    if [ -x "$HOME/.config/hypr/scripts/start-widgets.sh" ]; then
        echo "   ✅ Executable"
    else
        echo "   ❌ NOT executable - run: chmod +x ~/.config/hypr/scripts/start-widgets.sh"
    fi
else
    echo "❌ start-widgets.sh NOT FOUND"
fi

# 2. Check running processes
echo ""
echo "2️⃣  PROCESS CHECK"
echo "---"
CLOCK_PID=$(pgrep -f "clock_widget.py")
if [ -n "$CLOCK_PID" ]; then
    echo "✅ Clock widget running (PID: $CLOCK_PID)"
    ps aux | grep -v grep | grep clock_widget.py
else
    echo "❌ Clock widget NOT running"
fi

# 3. Check Hyprland windows
echo ""
echo "3️⃣  HYPRLAND WINDOW CHECK"
echo "---"
if command -v hyprctl &> /dev/null; then
    CLOCK_WINDOW=$(hyprctl clients -j | jq -r '.[] | select(.title | contains("hypr-widget-clock")) | .title' 2>/dev/null)
    if [ -n "$CLOCK_WINDOW" ]; then
        echo "✅ Clock window found in Hyprland"
        hyprctl clients -j | jq '.[] | select(.title | contains("hypr-widget-clock"))'
    else
        echo "❌ No clock window in Hyprland"
    fi
else
    echo "⚠️  hyprctl not available"
fi

# 4. Check layer shell
echo ""
echo "4️⃣  LAYER SHELL CHECK"
echo "---"
if [ -f "/usr/lib/libgtk4-layer-shell.so" ]; then
    echo "✅ gtk4-layer-shell library exists"
    ls -lh /usr/lib/libgtk4-layer-shell.so
else
    echo "❌ gtk4-layer-shell library NOT FOUND"
    echo "   Install: yay -S gtk4-layer-shell"
fi

# 5. Test Python imports
echo ""
echo "5️⃣  PYTHON DEPENDENCY CHECK"
echo "---"
python3 << 'PYEOF'
import sys
try:
    import gi
    gi.require_version('Gtk', '4.0')
    from gi.repository import Gtk
    print("✅ GTK4 available")
except Exception as e:
    print(f"❌ GTK4 error: {e}")
    sys.exit(1)

try:
    gi.require_version('Gtk4LayerShell', '1.0')
    from gi.repository import Gtk4LayerShell
    print("✅ gtk4-layer-shell Python bindings available")
except Exception as e:
    print(f"❌ gtk4-layer-shell bindings error: {e}")
PYEOF

# 6. Manual test with LD_PRELOAD
echo ""
echo "6️⃣  MANUAL TEST (5 seconds)"
echo "---"
if [ -f "$HOME/.config/hypr-control-center/widgets/clock_widget.py" ]; then
    cd "$HOME/.config/hypr-control-center/widgets"
    echo "Running: LD_PRELOAD=/usr/lib/libgtk4-layer-shell.so python3 clock_widget.py"
    timeout 5 LD_PRELOAD=/usr/lib/libgtk4-layer-shell.so python3 clock_widget.py 2>&1 &
    TEST_PID=$!
    sleep 2
    
    if ps -p $TEST_PID > /dev/null 2>&1; then
        echo "✅ Manual start successful"
        
        # Check if window appeared
        if command -v hyprctl &> /dev/null; then
            sleep 1
            if hyprctl clients -j | jq -e '.[] | select(.title | contains("hypr-widget-clock"))' > /dev/null 2>&1; then
                echo "✅ Window appeared in Hyprland"
            else
                echo "⚠️  Process running but window not visible"
            fi
        fi
    else
        echo "❌ Manual start failed"
    fi
    
    wait $TEST_PID 2>/dev/null
fi

# 7. Check logs
echo ""
echo "7️⃣  LOG CHECK"
echo "---"
if [ -d "$HOME/.local/share/hypr-widgets/logs" ]; then
    if [ -f "$HOME/.local/share/hypr-widgets/logs/clock.log" ]; then
        echo "📋 Clock log (last 10 lines):"
        tail -10 "$HOME/.local/share/hypr-widgets/logs/clock.log"
    else
        echo "⚠️  No clock log yet"
    fi
else
    echo "⚠️  Log directory doesn't exist"
fi

# 8. Check Hyprland window rules
echo ""
echo "8️⃣  HYPRLAND WINDOW RULES"
echo "---"
if [ -f "$HOME/.config/hypr/hyprland.conf" ]; then
    echo "Widget-related rules:"
    grep -n "hypr-widget" "$HOME/.config/hypr/hyprland.conf" | head -20
else
    echo "⚠️  hyprland.conf not found"
fi

echo ""
echo "════════════════════════════════════════════════════════"
echo "  SUMMARY"
echo "════════════════════════════════════════════════════════"

# Final verdict
ALL_GOOD=true

[ ! -f "$HOME/.config/hypr-control-center/widgets/clock_widget.py" ] && ALL_GOOD=false
[ ! -f "/usr/lib/libgtk4-layer-shell.so" ] && ALL_GOOD=false

if [ "$ALL_GOOD" = true ]; then
    echo "✅ All dependencies present"
    echo ""
    echo "🔧 TRY THIS:"
    echo "   1. Kill existing: pkill -9 -f clock_widget"
    echo "   2. Run manually: cd ~/.config/hypr-control-center/widgets && LD_PRELOAD=/usr/lib/libgtk4-layer-shell.so python3 clock_widget.py"
    echo "   3. Check if visible on desktop"
    echo "   4. If visible, restart script: ~/.config/hypr/scripts/start-widgets.sh restart"
else
    echo "❌ Missing dependencies - check errors above"
fi

echo ""
