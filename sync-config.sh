#!/usr/bin/env bash
#
# sync-config.sh — Zen Shell clean config sync
#
# The recurring "Cannot assign to non-existent property" load errors were
# caused by a STALE file left in the running config dir
# (~/.config/quickshell/zen-shell/) when only some .qml files got copied
# from a new build. Quickshell loads from the config dir, NOT the tarball
# folder — so if even one file (e.g. Workspaces.qml) is old, a new
# property reference crashes the load.
#
# This script does a CLEAN sync: it removes the old zen-shell config dir
# and copies the full, current zen-shell-v5/ tree from THIS build into it.
# Run it from inside the extracted build folder (the one containing
# zen-shell-v5/).
#
# Usage:
#   cd zen-shell-v7.0.0-beta.1-hfXX
#   bash sync-config.sh
#   quickshell -p ~/.config/quickshell/zen-shell/shell.qml
#
# Wala tayong babawasan — this only refreshes the config dir; your
# panel-state.json (settings) lives there too, so it's PRESERVED by
# default (see KEEP_STATE below).
#
# CHANGELOG
#   v7.0.0-beta.1-hf95.1 — self-verify fixed + generalized. It grepped
#     the OLD `vertical` property name (renamed to `zenVertical` in
#     hf91.1) so it false-warned on every healthy sync; now greps the
#     correct name and checks ALL vertical-bar modules, not just
#     Workspaces. Copy logic unchanged (already clean-wipe + cache-clear).

set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)/zen-shell-v5"
DEST="$HOME/.config/quickshell/zen-shell"

# Preserve user settings (panel-state.json etc.) across the clean sync.
KEEP_STATE=1

if [[ ! -d "$SRC" ]]; then
    echo "ERROR: $SRC not found. Run this from the extracted build folder"
    echo "       (the one that contains a zen-shell-v5/ directory)."
    exit 1
fi

echo "Source : $SRC"
echo "Dest   : $DEST"

# Back up panel-state.json (and any *.json state) if present.
TMPSTATE="$(mktemp -d)"
if [[ "$KEEP_STATE" == "1" && -d "$DEST" ]]; then
    shopt -s nullglob
    for f in "$DEST"/*.json; do
        echo "  preserving $(basename "$f")"
        cp -a "$f" "$TMPSTATE/"
    done
    shopt -u nullglob
fi

# Clean wipe of the config dir so NO stale .qml can survive.
# Handle the case where DEST is a SYMLINK (remove the link itself, then
# make a real directory — so a stale symlinked source can't shadow us).
if [[ -L "$DEST" ]]; then
    echo "Dest is a SYMLINK → $(readlink -f "$DEST"); removing the link…"
    rm -f "$DEST"
elif [[ -d "$DEST" ]]; then
    echo "Removing old config dir (clean wipe)…"
    rm -rf "$DEST"
fi
mkdir -p "$DEST"

# Copy the full current tree.
echo "Copying fresh build…"
cp -a "$SRC"/. "$DEST"/

# Restore preserved state.
if [[ "$KEEP_STATE" == "1" ]]; then
    shopt -s nullglob
    for f in "$TMPSTATE"/*.json; do
        echo "  restoring $(basename "$f")"
        cp -a "$f" "$DEST"/
    done
    shopt -u nullglob
fi
rm -rf "$TMPSTATE"

# ── CRITICAL: clear Qt/Quickshell's COMPILED QML cache ──
# Qt caches compiled QML as .qmlc files. If the cache holds an OLD
# compiled module (e.g. a Workspaces without the `vertical` property),
# Qt loads the STALE compiled type instead of recompiling the fresh
# source — producing the paradox "the .qml clearly has the property, but
# the loaded type doesn't" → "Cannot assign to non-existent property".
# Wiping the cache forces a clean recompile of every module.
echo "Clearing Qt/Quickshell QML compiled cache…"
CLEARED=0
for d in \
    "$HOME/.cache/quickshell/qmlcache" \
    "$HOME/.cache/quickshell" \
    "$HOME/.cache/org.quickshell" \
    "${XDG_CACHE_HOME:-$HOME/.cache}/qmlcache" ; do
    if [[ -d "$d" ]]; then
        # Only remove compiled-cache artifacts, not crash logs.
        find "$d" -type f \( -name "*.qmlc" -o -name "*.jsc" \) -delete 2>/dev/null && CLEARED=1
    fi
done
# Stray per-file .qmlc next to sources (rare, but be thorough).
find "$DEST" -type f \( -name "*.qmlc" -o -name "*.jsc" \) -delete 2>/dev/null || true
if [[ "$CLEARED" == "1" ]]; then
    echo "  QML cache cleared."
else
    echo "  (no QML cache dir found — that's fine)"
fi

# Show the version that's now installed so you can confirm the sync.
VER="$(grep 'property string version:' "$DEST/ZenVersion.qml" | sed -E 's/.*"([^"]+)".*/\1/' | head -1 || true)"
echo ""
echo "Done. Installed version: ${VER:-<unknown>}"

# Self-verify: the recurring crash class was a stale vertical-bar module
# in the config dir lacking its `zenVertical` property. BarVertical.qml
# assigns `zenVertical: true` to every module listed below, so a stale
# copy of ANY of them (not just Workspaces) reproduces "Cannot assign to
# non-existent property zenVertical" and aborts the whole shell load.
#
# v7.0.0-beta.1-hf95.1: corrected the grep — it searched for the OLD
# `vertical` property name, which was renamed to `zenVertical` in
# hf91.1, so this check ALWAYS false-warned even on a healthy sync. Also
# widened from Workspaces-only to the full vertical-module set. Wala
# tayong babawasan — the original Workspaces verify is preserved, just
# corrected and generalized into the loop below.
VERTICAL_MODULES=(Clock MusicWidget SysRow SystemTray Taskbar WindowTitle Workspaces)
VERIFY_FAIL=0
for m in "${VERTICAL_MODULES[@]}"; do
    f="$DEST/$m.qml"
    if [[ ! -f "$f" ]]; then
        echo "Verify: WARNING — $m.qml is MISSING from the config dir!"
        VERIFY_FAIL=1
    elif grep -q 'property bool zenVertical' "$f" 2>/dev/null; then
        echo "Verify: $m.qml has the 'zenVertical' property ✓"
    else
        echo "Verify: WARNING — $m.qml is STILL missing 'zenVertical' (stale file?)."
        VERIFY_FAIL=1
    fi
done
if [[ "$VERIFY_FAIL" == "1" ]]; then
    echo "        One or more vertical modules are stale/missing AFTER the sync."
    echo "        Something is copying an old file over the config dir AFTER this sync,"
    echo "        or ~/.config/quickshell/zen-shell was re-created as a symlink to a"
    echo "        stale source. Re-run this script from the freshly extracted build."
else
    echo "Verify: all vertical-bar modules carry 'zenVertical' ✓ (stale-file bug cannot occur)"
fi
echo ""
echo "Launch with:"
echo "  quickshell -p ~/.config/quickshell/zen-shell/shell.qml"
