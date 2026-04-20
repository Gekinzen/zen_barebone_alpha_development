#!/usr/bin/env bash
# zen-screenshot-capture.sh v6.15
#
# Pipeline runner for ZenScreenshotOverlay. Called by the overlay QML
# when the user clicks Copy or Save. Handles:
#   1. grim region capture
#   2. ImageMagick composite (if annotations present)
#   3. wl-copy to clipboard, OR save to file
#
# Usage:
#   zen-screenshot-capture.sh copy  GEOM [SVG_FILE]
#   zen-screenshot-capture.sh save  GEOM OUTPUT_PATH [SVG_FILE]
#
# GEOM format: "X,Y WxH" (global screen coords for grim)
# SVG_FILE:    path to annotation SVG (optional)
#
# All output logged to /tmp/zen-screenshot.log for debugging.

LOG=/tmp/zen-screenshot.log
exec > "$LOG" 2>&1

echo "=== zen-screenshot-capture $(date -Iseconds) ==="
echo "args: $*"

MODE="$1"
GEOM="$2"
OUT="$3"
SVG="$4"
if [ "$MODE" = "copy" ]; then
    SVG="$3"
fi

TMPRAW=/tmp/zen-shot-raw.png
TMPFINAL=/tmp/zen-shot-final.jpg

echo "mode:  $MODE"
echo "geom:  $GEOM"
echo "svg:   $SVG"

# ── Step 1: grim ──
if ! grim -g "$GEOM" "$TMPRAW"; then
    echo "FAIL: grim"
    notify-send -u critical "Screenshot failed" "grim couldn't capture that region" 2>/dev/null
    exit 1
fi
echo "grim ok ($(stat -c%s "$TMPRAW") bytes)"

# ── Step 2: compose or encode ──
HAVE_SVG=0
if [ -n "$SVG" ] && [ -s "$SVG" ]; then
    HAVE_SVG=1
fi

MAGICK=""
if command -v magick >/dev/null 2>&1; then
    MAGICK="magick"
elif command -v convert >/dev/null 2>&1; then
    MAGICK="convert"
fi

if [ "$HAVE_SVG" = "1" ] && [ -n "$MAGICK" ]; then
    if $MAGICK "$TMPRAW" \( "$SVG" -background none \) \
              -compose over -composite -quality 92 "$TMPFINAL"; then
        echo "magick composite ok"
    else
        echo "magick composite FAILED, using raw"
        cp "$TMPRAW" "$TMPFINAL"
    fi
elif [ -n "$MAGICK" ]; then
    if $MAGICK "$TMPRAW" -quality 92 "$TMPFINAL"; then
        echo "magick encode ok"
    else
        cp "$TMPRAW" "$TMPFINAL"
    fi
else
    echo "no ImageMagick — copying raw PNG as .jpg"
    cp "$TMPRAW" "$TMPFINAL"
fi

if [ ! -s "$TMPFINAL" ]; then
    echo "FAIL: empty final file"
    notify-send -u critical "Screenshot failed" "encoded file is empty" 2>/dev/null
    exit 1
fi
echo "final: $(stat -c%s "$TMPFINAL") bytes"

# ── Step 3: copy or save ──
if [ "$MODE" = "copy" ]; then
    if ! command -v wl-copy >/dev/null 2>&1; then
        echo "FAIL: wl-copy not installed"
        notify-send -u critical "Copy failed" "wl-clipboard not installed" 2>/dev/null
        exit 1
    fi

    # CRITICAL: wl-copy needs to survive this script's exit.
    # Strategy: double-fork via setsid so it becomes a session leader
    # and reparents to init. This guarantees it stays alive even after
    # this shell and its parent (Quickshell Process) exit.
    #
    # We also redirect stdin from the JPG file path (not piped from
    # this shell), so the file descriptor stays valid inside wl-copy
    # after we exit.
    setsid bash -c "exec wl-copy --type image/jpeg < '$TMPFINAL'" \
        </dev/null >/dev/null 2>&1 &
    disown 2>/dev/null || true

    # Give wl-copy time to claim the clipboard
    sleep 0.4

    # Verify — check if the clipboard advertises image/jpeg now
    if command -v wl-paste >/dev/null 2>&1; then
        TYPES=$(wl-paste --list-types 2>/dev/null | tr '\n' ' ')
        echo "clipboard types: $TYPES"
        if echo "$TYPES" | grep -q "image/jpeg"; then
            echo "SUCCESS: clipboard has image/jpeg"
            notify-send -i "$TMPFINAL" "Screenshot copied" \
                "JPG in clipboard — paste with Ctrl+V" 2>/dev/null
        else
            echo "WARN: image/jpeg not yet advertised, retrying once"
            sleep 0.5
            TYPES=$(wl-paste --list-types 2>/dev/null | tr '\n' ' ')
            echo "clipboard types (retry): $TYPES"
            if echo "$TYPES" | grep -q "image/jpeg"; then
                echo "SUCCESS on retry"
                notify-send -i "$TMPFINAL" "Screenshot copied" \
                    "JPG in clipboard — paste with Ctrl+V" 2>/dev/null
            else
                echo "FAIL: clipboard never got image/jpeg"
                notify-send -u critical "Copy failed" \
                    "wl-copy didn't claim clipboard. Check /tmp/zen-screenshot.log" 2>/dev/null
            fi
        fi
    fi

elif [ "$MODE" = "save" ]; then
    if [ -z "$OUT" ]; then
        echo "FAIL: save mode needs output path"
        exit 1
    fi
    mkdir -p "$(dirname "$OUT")"
    if cp "$TMPFINAL" "$OUT"; then
        echo "saved: $OUT"
        notify-send -i "$OUT" "Screenshot saved" "$(basename "$OUT")" 2>/dev/null
    else
        echo "FAIL: save"
        notify-send -u critical "Save failed" "couldn't write $OUT" 2>/dev/null
        exit 1
    fi
else
    echo "FAIL: unknown mode $MODE"
    exit 1
fi

echo "done"
exit 0
