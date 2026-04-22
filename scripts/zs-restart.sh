#!/usr/bin/env bash
# zs-restart.sh — Zen Shell nuclear respawn helper
#
# Installed by install.sh to ~/.local/bin/zs-restart.sh. Invoked by
# shell.qml's nuclear restart mechanism (v6.15.12+) when the bug-
# triggering Float/FW → Island panel-mode transition happens. Kills
# the running Quickshell instance and relaunches it cleanly so island
# mode starts from a fresh QML state (no feedback-loop intermediate
# positions).
#
# This script is fully dynamic — uses $HOME and $USER throughout,
# works for any Linux user on any system. No hardcoded paths.
#
# ───────────────────────────────────────────────────────────────────
# WHY THE SCRIPT IS NAMED "zs-restart.sh" NOT "zen-shell-*"
# ───────────────────────────────────────────────────────────────────
#
# The v6.15.11 version of this helper was named
# zen-shell-nuclear-restart.sh. That turned out to be buggy: the
# script ran `pkill -f zen-shell` internally, which matches ANY
# process whose cmdline contains "zen-shell" — including the bash
# process running THIS script itself (whose cmdline is e.g.
# "/bin/bash /home/$USER/.local/bin/zen-shell-nuclear-restart.sh").
# Script killed itself mid-execution before reaching the relaunch
# step → Quickshell stayed dead.
#
# v6.15.12+ fixes this by:
#   1. Renaming the script to zs-restart.sh (no "zen-shell"
#      substring in the path).
#   2. Tightening the pkill pattern to 'quickshell.*zen-shell'
#      which matches ONLY the quickshell process, not arbitrary
#      scripts with "zen-shell" anywhere in their cmdline.
#
# DO NOT RENAME this file to anything containing "zen-shell"
# or the self-suicide bug will come back.
# ───────────────────────────────────────────────────────────────────
#
# Manual test: just run it.
#   ~/.local/bin/zs-restart.sh
# Should kill + respawn your Zen Shell in ~1 second. Check
# /tmp/zs-restart.log for full execution trace.

LOG=/tmp/zs-restart.log
exec >> "$LOG" 2>&1

echo "=================================================================="
echo "[$(date -Iseconds)] zs-restart: starting"
echo "[$(date -Iseconds)] zs-restart:   pid    = $$"
echo "[$(date -Iseconds)] zs-restart:   user   = ${USER:-unknown}"
echo "[$(date -Iseconds)] zs-restart:   home   = ${HOME:-unknown}"
echo "[$(date -Iseconds)] zs-restart:   script = $0"
echo "[$(date -Iseconds)] zs-restart:   cmdline= $(tr '\0' ' ' < /proc/$$/cmdline 2>/dev/null)"

# ── Pre-flight: verify Quickshell binary exists ──────────────────
if ! command -v quickshell >/dev/null 2>&1; then
    echo "[$(date -Iseconds)] zs-restart: FATAL — 'quickshell' binary not"
    echo "                                 found in PATH. Aborting respawn."
    echo "                                 PATH=$PATH"
    exit 1
fi
QUICKSHELL_BIN=$(command -v quickshell)
echo "[$(date -Iseconds)] zs-restart:   qs bin = $QUICKSHELL_BIN"

# ── Pre-flight: verify Zen Shell config dir exists ───────────────
ZEN_SHELL_DIR="$HOME/.config/quickshell/zen-shell"
if [ ! -d "$ZEN_SHELL_DIR" ]; then
    echo "[$(date -Iseconds)] zs-restart: FATAL — Zen Shell config dir not"
    echo "                                 found: $ZEN_SHELL_DIR"
    echo "                                 Did you run install.sh?"
    exit 1
fi
echo "[$(date -Iseconds)] zs-restart:   config = $ZEN_SHELL_DIR"

# ── Grace period for PanelState.saveState() to commit to disk ────
sleep 0.3

# ── Show what's currently running (for diagnostics) ──────────────
echo "[$(date -Iseconds)] zs-restart: matching quickshell processes BEFORE kill:"
if pgrep -af 'quickshell.*zen-shell' >/dev/null 2>&1; then
    pgrep -af 'quickshell.*zen-shell' | sed 's/^/                                 /'
else
    echo "                                 (none found — was Zen Shell running?)"
fi

# ── Kill running Quickshell instance ─────────────────────────────
# Pattern 'quickshell.*zen-shell' is specific enough to:
#   ✓ Match:     quickshell -p ~/.config/quickshell/zen-shell
#   ✓ Match:     /usr/bin/quickshell -p /home/$USER/.config/quickshell/zen-shell
#   ✗ Not match: /bin/bash /home/$USER/.local/bin/zs-restart.sh
#   ✗ Not match: journalctl --user -f --grep=zen-shell
pkill -f 'quickshell.*zen-shell' 2>/dev/null
KILL_RC=$?
echo "[$(date -Iseconds)] zs-restart: pkill returned $KILL_RC"
if [ $KILL_RC -eq 0 ]; then
    echo "                                 (0 = processes killed)"
elif [ $KILL_RC -eq 1 ]; then
    echo "                                 (1 = no matching processes)"
else
    echo "                                 (unexpected — see man pkill)"
fi

# ── Give Hyprland time to clean up dead layer-shell surfaces ─────
# Otherwise the new shell can race with surface reclamation
sleep 0.3

# ── Launch fresh Quickshell, fully detached ──────────────────────
echo "[$(date -Iseconds)] zs-restart: launching: $QUICKSHELL_BIN -p $ZEN_SHELL_DIR"
"$QUICKSHELL_BIN" -p "$ZEN_SHELL_DIR" </dev/null >/dev/null 2>&1 &
LAUNCH_PID=$!
disown 2>/dev/null || true

echo "[$(date -Iseconds)] zs-restart: respawn dispatched (pid=$LAUNCH_PID)"
echo "[$(date -Iseconds)] zs-restart: done"
exit 0
