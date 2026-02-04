#!/bin/bash
# ═══════════════════════════════════════════════════════════
# Theme Reload - Send SIGUSR2 to all desktop daemons
# ═══════════════════════════════════════════════════════════
# Called by: theming applier after applying colorscheme
# Signals:  waybar (SIGUSR2), start-menu (SIGUSR2), panel (SIGUSR2)

echo "[ThemeReload] 🎨 Broadcasting theme reload..."

# 1. Waybar (built-in SIGUSR2 reload)
pkill -SIGUSR2 waybar 2>/dev/null && echo "[ThemeReload] ✅ Waybar reloaded" || echo "[ThemeReload] ⚠️  Waybar not running"

# 2. Start Menu daemon
STARTMENU_PID="/tmp/hypr-startmenu.pid"
if [ -f "$STARTMENU_PID" ]; then
    pid=$(cat "$STARTMENU_PID" 2>/dev/null)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        kill -USR2 "$pid" 2>/dev/null
        echo "[ThemeReload] ✅ Start Menu reloaded (PID: $pid)"
    else
        echo "[ThemeReload] ⚠️  Start Menu PID stale"
    fi
else
    echo "[ThemeReload] ⚠️  Start Menu not running"
fi

# 3. Panel Widget daemon
PANEL_PID="/tmp/hypr-panel.pid"
if [ -f "$PANEL_PID" ]; then
    pid=$(cat "$PANEL_PID" 2>/dev/null)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        kill -USR2 "$pid" 2>/dev/null
        echo "[ThemeReload] ✅ Panel reloaded (PID: $pid)"
    else
        echo "[ThemeReload] ⚠️  Panel PID stale"
    fi
else
    echo "[ThemeReload] ⚠️  Panel not running"
fi

echo "[ThemeReload] 🎨 Done!"
