#!/usr/bin/env bash
# zen-screenshot.sh v6.14 — screenshot tool for Hyprland
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
# v6.14 (Zen Shell v7.0.0-beta.1-hf82g) changes:
#   - FIX: flameshot --region on scaled monitors (1.25x, 1.5x, etc)
#     was cropping the capture/selection area regardless of whether
#     we passed native OR logical dimensions. Different scale values
#     gave different crop amounts; no constant transform made it
#     work right.
#   - Root cause: flameshot on Wayland-Hyprland with --region has
#     known buggy coordinate handling that interacts poorly with
#     fractional scaling. Upstream flameshot's Wayland support
#     relies on wlr-screencopy or xdg-desktop-portal, and the
#     --region geometry isn't consistently interpreted across
#     either path on scaled displays.
#   - Decision: drop --region from `flameshot gui` and `flameshot
#     full` calls entirely. Without --region, flameshot uses its
#     own focused-monitor detection (good enough on Hyprland's
#     Wayland) and captures the full visible workspace, which is
#     what the user wanted anyway.
#   - Trade-off: in very rare multi-monitor edge cases where
#     flameshot's auto-detection picks the wrong screen, the
#     workaround is to move the mouse cursor to the desired screen
#     before triggering the keybind. The hf82e attempt to enforce
#     focused-monitor targeting via --region caused more problems
#     than it solved on scaled displays.
#   - get_active_monitor_geometry() preserved (used elsewhere
#     potentially in future) but not called for flameshot anymore.
#
# v6.13 (hf82e) changes:
#   - get_active_monitor_geometry() printed logical dimensions
#     instead of native. Was a partial fix; v6.14 supersedes.
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
#
# v7.0.0-beta.1-hf82e FIX: this used to print m['width']x m['height']
# (native pixels) which was WRONG for flameshot — flameshot's region
# picker on Hyprland Wayland operates in LOGICAL coordinate space.
# A 3440x1440 monitor at 1.5x scale has a logical workspace of
# 2293x960; passing the native 3440x1440 caused the region to
# overshoot bounds.
#
# Now divides w + h by scale, matching the slurp helper below.
get_active_monitor_geometry() {
    hyprctl monitors -j 2>/dev/null | \
        python3 -c "
import sys, json, math
monitors = json.load(sys.stdin)
for m in monitors:
    if m.get('focused'):
        # Use LOGICAL dimensions for flameshot --region.
        # Native = m['width'] / m['height'] (physical pixels)
        # Logical = native / scale (CSS-pixel equivalents)
        scale = m.get('scale', 1.0)
        if scale <= 0:
            scale = 1.0
        w = int(round(m['width'] / scale))
        h = int(round(m['height'] / scale))
        x = m['x']
        y = m['y']
        print(f'{w}x{h}+{x}+{y}')
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
            # v7.0.0-beta.1-hf82g: dropped --region — caused cropping
            # on scaled displays no matter what dimensions were passed.
            # flameshot's auto-detection of focused monitor is good
            # enough on Hyprland Wayland.
            flameshot full -p "$SCREENSHOTS_DIR"
            ;;
        region|flameshot)
            # v7.0.0-beta.1-hf82g: dropped --region. See header.
            #
            # flameshot gui without --region shows the entire visible
            # workspace of the focused monitor for selection — which
            # is the actual behavior the user wanted on a 1.5x scaled
            # 3440x1440 monitor.
            flameshot gui
            ;;
        clipboard)
            # v7.0.0-beta.1-hf82g: same fix applies to --clipboard mode.
            flameshot full --clipboard
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
