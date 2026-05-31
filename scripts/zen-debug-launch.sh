#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────
# zen-debug-launch.sh — v7.0.0-beta.1-hf25
#
# Launches quickshell with full crash capture so user can see
# crash output AFTER the shell goes down (without it auto-restarting
# and erasing the screen output).
#
# Usage: ./zen-debug-launch.sh
#        Run from your normal terminal; on crash, the shell will
#        DIE and STAY DEAD, leaving the full crash output visible.
#        Plus a copy is saved to ~/.cache/zen-shell-crashes/
# ──────────────────────────────────────────────────────────────────

CRASH_DIR="$HOME/.cache/zen-shell-crashes"
mkdir -p "$CRASH_DIR"

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
CRASH_LOG="$CRASH_DIR/crash-$TIMESTAMP.log"

echo "╭─────────────────────────────────────────────────────────╮"
echo "│ Zen Shell Debug Launcher                                │"
echo "│ Log: $CRASH_LOG"
echo "│ Press Ctrl+C to stop normally                           │"
echo "│ On crash: output saved + shell stays dead for analysis │"
echo "╰─────────────────────────────────────────────────────────╯"

# Disable Quickshell's auto-restart so we see the crash dump
export QS_NO_RESTART=1
export QT_LOGGING_RULES="*.debug=true;qt.qpa.*=false"

# Kill any existing quickshell to avoid the "second instance" problem
pkill -f "quickshell.*zen-shell" 2>/dev/null
sleep 0.3

# Run with tee so output appears live AND saved
qs -c zen-shell 2>&1 | tee "$CRASH_LOG"

EXIT_CODE=${PIPESTATUS[0]}

echo ""
echo "─────────────────────────────────────────────────────────"
echo "Quickshell exited with code: $EXIT_CODE"
echo "Last 60 lines saved to: $CRASH_LOG"
echo ""

# Find latest Quickshell-side crash dump
LATEST_CRASH=$(ls -t "$HOME/.cache/quickshell/crashes" 2>/dev/null | head -1)
if [ -n "$LATEST_CRASH" ]; then
    echo "Quickshell crash dump dir: ~/.cache/quickshell/crashes/$LATEST_CRASH"
    echo "Contents:"
    ls -la "$HOME/.cache/quickshell/crashes/$LATEST_CRASH" 2>/dev/null
fi

echo ""
echo "To analyze a coredump (if produced):"
echo "  coredumpctl info $(pgrep -x quickshell 2>/dev/null || echo "<pid>")"
echo "  coredumpctl gdb <pid>"
echo ""
echo "Press Enter to exit..."
read -r
