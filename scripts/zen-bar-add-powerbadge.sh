#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
# zen-bar-add-powerbadge.sh v6.16.3.4
# ────────────────────────────────────────────────────────────────
# Idempotent helper for existing users to add the new powerbadge
# bar module to their saved bar-layout.json.
#
# Why this exists:
#   - Theme.barLayout in Theme.qml gives the DEFAULT for fresh installs
#   - Existing users have ~/.config/quickshell/bar-layout.json which
#     OVERRIDES that default (preserves their customizations across
#     upgrades — additive policy)
#   - So adding "powerbadge" to Theme.qml's default doesn't reach
#     existing users automatically. This script bridges that gap.
#
# What it does:
#   1. Reads ~/.config/quickshell/bar-layout.json (or finds via
#      Quickshell.dataPath equivalent on the user's system)
#   2. If "powerbadge" is already anywhere in the layout → exit 0
#   3. Otherwise, inserts "powerbadge" into the right row, just before
#      the existing "notifications" entry. Falls back to appending if
#      "notifications" isn't present.
#   4. Writes the file back. Backs up the original to .bak.<TS> first.
#
# This script is OPT-IN. It's NOT called from install.sh by default.
# Users run it manually when they want the badge on their existing
# customized bar.
#
# Usage:
#   ~/.local/bin/zen-bar-add-powerbadge.sh           # apply
#   ~/.local/bin/zen-bar-add-powerbadge.sh --dry-run # preview only
#   ~/.local/bin/zen-bar-add-powerbadge.sh --remove  # take it back out
# ════════════════════════════════════════════════════════════════

set -u

DRY_RUN=0
REMOVE=0
for arg in "$@"; do
    case "$arg" in
        --dry-run|-n) DRY_RUN=1 ;;
        --remove)     REMOVE=1 ;;
        -h|--help)
            sed -n '2,40p' "$0" | sed 's/^# \?//'
            exit 0
            ;;
    esac
done

# Find bar-layout.json. Quickshell.dataPath() resolves to one of:
#   $XDG_DATA_HOME/quickshell/zen-shell/bar-layout.json
#   $HOME/.local/share/quickshell/zen-shell/bar-layout.json
LAYOUT=""
for cand in \
    "${XDG_DATA_HOME:-$HOME/.local/share}/quickshell/zen-shell/bar-layout.json" \
    "$HOME/.local/share/quickshell/zen-shell/bar-layout.json" \
    "$HOME/.config/quickshell/bar-layout.json" \
    "$HOME/.config/quickshell/zen-shell/bar-layout.json"
do
    if [ -f "$cand" ]; then
        LAYOUT="$cand"
        break
    fi
done

if [ -z "$LAYOUT" ]; then
    echo "No saved bar-layout.json found in any expected path."
    echo "  Either you're on a fresh install (Theme.qml's default already"
    echo "  includes 'powerbadge'), or your bar layout has never been"
    echo "  customized. Either way, no action needed."
    exit 0
fi

echo "Found layout: $LAYOUT"

if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq is required for this script." >&2
    echo "       sudo pacman -S jq" >&2
    exit 1
fi

# Validate JSON before touching it
if ! jq empty "$LAYOUT" 2>/dev/null; then
    echo "ERROR: $LAYOUT is not valid JSON. Refusing to modify." >&2
    exit 1
fi

# Check current state
HAS_BADGE=$(jq -r '
    [.layout.left, .layout.center, .layout.right]
    | flatten
    | map(select(. == "powerbadge"))
    | length
' "$LAYOUT")

if [ "$REMOVE" = "1" ]; then
    if [ "$HAS_BADGE" = "0" ]; then
        echo "powerbadge not present — nothing to remove."
        exit 0
    fi
    NEW=$(jq '
        .layout.left   = (.layout.left   | map(select(. != "powerbadge"))) |
        .layout.center = (.layout.center | map(select(. != "powerbadge"))) |
        .layout.right  = (.layout.right  | map(select(. != "powerbadge")))
    ' "$LAYOUT")
    OP="removed"
else
    if [ "$HAS_BADGE" != "0" ]; then
        echo "powerbadge already present in layout — nothing to do."
        exit 0
    fi
    # Insert before "notifications" in right row, or append
    NEW=$(jq '
        .layout.right as $r |
        .layout.right = (
            if ($r | index("notifications")) then
                $r[0:($r | index("notifications"))]
                + ["powerbadge"]
                + $r[($r | index("notifications")):]
            else
                $r + ["powerbadge"]
            end
        )
    ' "$LAYOUT")
    OP="added"
fi

if [ "$DRY_RUN" = "1" ]; then
    echo "── DRY RUN — would write ──"
    echo "$NEW"
    exit 0
fi

# Backup + write
TS=$(date +%s)
cp "$LAYOUT" "$LAYOUT.bak.$TS" && echo "  backup: $LAYOUT.bak.$TS"
echo "$NEW" >"$LAYOUT" && echo "  $OP powerbadge → $LAYOUT"

echo ""
echo "Reload Zen Shell so the change takes effect:"
echo "  ~/.local/bin/zs-restart.sh"
