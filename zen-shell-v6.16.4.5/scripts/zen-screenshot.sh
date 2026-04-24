#!/usr/bin/env bash
# zen-screenshot.sh v6.12 — screenshot tool for Hyprland
#
# Supports both grim+slurp AND flameshot with proper Wayland env.
# Captures specific active monitor or all screens.
#
# Usage:
#   zen-screenshot.sh              # region select (active monitor)
#   zen-screenshot.sh region       # region select (active monitor)
#   zen-screenshot.sh full         # full active monitor → save
#   zen-screenshot.sh clipboard    # full active monitor → clipboard
#   zen-screenshot.sh allscreens   # all monitors combined → save
#   zen-screenshot.sh flameshot    # force flameshot GUI
#
# v6.12 changes:
#   - Flameshot GUI now opens on focused monitor (--region targeting)
#   - Fixed: gui no longer spawns on wrong monitor in multi-display
# v6.11 changes:
#   - Flameshot specific display support via --region flag
#   - Active monitor geometry detection for flameshot region
#   - "allscreens" mode for multi-monitor combined capture
#   - Better notification with thumbnail preview
#   - Print Screen keybind support preserved

MODE="${1:-region}"
SCREENSHOTS_DIR="$HOME/Pictures/Screenshots"
mkdir -p "$SCREENSHOTS_DIR"

# ═══════════════════════════════════════════════════════════════
# Active monitor detection
# ═══════════════════════════════════════════════════════════════
get_active_monitor_name() {
    hyprctl monitors -j 2>/dev/null | \
        python3 -c "import sys,json;[print(m['name']) for m in json.load(sys.stdin) if m.get('focused')]" 2>/dev/null
}

# Get active monitor geometry as WxH+X+Y (for flameshot --region)
get_active_monitor_geometry() {
    hyprctl monitors -j 2>/dev/null | \
        python3 -c "
import sys, json, math
monitors = json.load(sys.stdin)
for m in monitors:
    if m.get('focused'):
        # Account for scale
        scale = m.get('scale', 1.0)
        w = int(m['width'] / scale)
        h = int(m['height'] / scale)
        x = m['x']
        y = m['y']
        print(f'{m[\"width\"]}x{m[\"height\"]}+{x}+{y}')
        break
" 2>/dev/null
}

# Get active monitor position and size for slurp constraint
get_active_monitor_slurp() {
    hyprctl monitors -j 2>/dev/null | \
        python3 -c "
import sys, json
monitors = json.load(sys.stdin)
for m in monitors:
    if m.get('focused'):
        scale = m.get('scale', 1.0)
        w = int(m['width'] / scale)
        h = int(m['height'] / scale)
        print(f'{m[\"x\"]},{m[\"y\"]} {w}x{h}')
        break
" 2>/dev/null
}

FILENAME="$SCREENSHOTS_DIR/screenshot-$(date +%Y%m%d-%H%M%S).png"

# ═══════════════════════════════════════════════════════════════
# Method 1: grim + slurp (most reliable on Hyprland)
# ═══════════════════════════════════════════════════════════════
screenshot_grim() {
    local MONITOR
    MONITOR=$(get_active_monitor_name)

    case "$MODE" in
        full)
            if [ -n "$MONITOR" ]; then
                grim -o "$MONITOR" "$FILENAME"
            else
                grim "$FILENAME"
            fi
            [ -f "$FILENAME" ] && \
                notify-send -i "$FILENAME" "Screenshot saved" "$(basename "$FILENAME")" 2>/dev/null
            ;;
        region)
            local GEOM
            GEOM=$(slurp 2>/dev/null)
            [ -z "$GEOM" ] && exit 0  # cancelled
            grim -g "$GEOM" "$FILENAME"
            [ -f "$FILENAME" ] && \
                notify-send -i "$FILENAME" "Screenshot saved" "$(basename "$FILENAME")" 2>/dev/null
            ;;
        clipboard)
            if [ -n "$MONITOR" ]; then
                grim -o "$MONITOR" - | wl-copy
            else
                grim - | wl-copy
            fi
            notify-send "Screenshot" "Copied to clipboard" 2>/dev/null
            ;;
        allscreens)
            # Capture all monitors combined
            grim "$FILENAME"
            [ -f "$FILENAME" ] && \
                notify-send -i "$FILENAME" "Screenshot saved (all screens)" "$(basename "$FILENAME")" 2>/dev/null
            ;;
    esac
}

# ═══════════════════════════════════════════════════════════════
# Method 2: flameshot (with proper Wayland env + display targeting)
# ═══════════════════════════════════════════════════════════════
screenshot_flameshot() {
    # v6.12: Ensure flameshot config exists with Wayland-friendly settings
    local FLAME_CONF="$HOME/.config/flameshot/flameshot.ini"
    if [ ! -f "$FLAME_CONF" ]; then
        mkdir -p "$HOME/.config/flameshot"
        cat > "$FLAME_CONF" << 'EOF'
[General]
showStartupLaunchMessage=false
saveAfterCopy=true
savePath=/home/paul/Pictures/Screenshots
showDesktopNotification=true
disabledTrayIcon=true
EOF
        # Fix the savePath to use actual $HOME
        sed -i "s|/home/paul|$HOME|g" "$FLAME_CONF"
    fi

    # Ensure flameshot daemon is running with correct Wayland vars
    if ! pgrep -x flameshot >/dev/null 2>&1; then
        env XDG_CURRENT_DESKTOP=Hyprland \
            XDG_SESSION_TYPE=wayland \
            QT_QPA_PLATFORM=wayland \
            WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}" \
            flameshot &
        sleep 1.5
    fi

    case "$MODE" in
        full)
            # Capture specific active monitor using --region
            local GEOM
            GEOM=$(get_active_monitor_geometry)
            if [ -n "$GEOM" ]; then
                flameshot full --region "$GEOM" -p "$SCREENSHOTS_DIR"
            else
                flameshot full -p "$SCREENSHOTS_DIR"
            fi
            ;;
        region|flameshot)
            # v6.12 fix: Target flameshot GUI to the focused monitor.
            # Without --region, flameshot opens on whatever monitor it
            # defaults to (usually the first), not where your cursor is.
            local GUI_GEOM
            GUI_GEOM=$(get_active_monitor_geometry)
            if [ -n "$GUI_GEOM" ]; then
                flameshot gui --region "$GUI_GEOM"
            else
                flameshot gui
            fi
            ;;
        clipboard)
            local GEOM
            GEOM=$(get_active_monitor_geometry)
            if [ -n "$GEOM" ]; then
                flameshot full --region "$GEOM" --clipboard
            else
                flameshot full --clipboard
            fi
            ;;
        allscreens)
            flameshot full -p "$SCREENSHOTS_DIR"
            ;;
    esac
}

# ═══════════════════════════════════════════════════════════════
# Decide which method to use
# grim+slurp is primary, flameshot is fallback
# "flameshot" mode forces flameshot regardless
# ═══════════════════════════════════════════════════════════════
if [ "$MODE" = "flameshot" ]; then
    # Force flameshot mode
    if command -v flameshot >/dev/null 2>&1; then
        screenshot_flameshot
    else
        notify-send "Screenshot failed" "Flameshot not installed" 2>/dev/null
        exit 1
    fi
elif command -v grim >/dev/null 2>&1 && command -v slurp >/dev/null 2>&1; then
    screenshot_grim
elif command -v flameshot >/dev/null 2>&1; then
    screenshot_flameshot
else
    notify-send "Screenshot failed" "Install grim+slurp or flameshot" 2>/dev/null
    exit 1
fi
