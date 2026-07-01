#!/usr/bin/env bash
# zen-plugin-cache-rebuild.sh — Build plugin .so cache for fast loading
#
# v7.0.0-beta.1-hf82w
#
# Discovers loaded plugin .so paths and writes them to
# ~/.local/share/zen-shell/plugin-cache.json so the systemd-based
# zen-plugin-loader can do direct hyprctl plugin load on next boot,
# skipping the slow `hyprpm reload` path.
#
# Called by:
#   1. install.sh (during plugin setup phase)
#   2. zen-plugin-bootstrap.sh (after a successful hyprpm rebuild)
#   3. Settings → Plugins → "Rebuild plugin cache" button (future)
#
# Strategy: query Hyprland for currently-loaded plugins, then for each
# look up the .so on disk in known locations. If a plugin is enabled in
# hyprpm but not currently loaded, we still try to record its .so path
# from disk so the next boot can load it.

set -u
CACHE_DIR="$HOME/.local/share/zen-shell"
CACHE="$CACHE_DIR/plugin-cache.json"
LOG=/tmp/zen-plugin-cache-rebuild.log

mkdir -p "$CACHE_DIR"
: > "$LOG"
echo "[$(date)] Cache rebuild starting" >> "$LOG"

# ── Get Hyprland version ──
HYPR_VER=$(hyprctl version 2>/dev/null | grep -oE 'Tag: v?[0-9.]+' | head -1 | sed 's/Tag: v\?//')
HYPR_COMMIT=$(hyprctl version 2>/dev/null | grep -oE 'commit [a-f0-9]+' | head -1 | sed 's/commit //')
if [ -z "$HYPR_VER" ]; then
    echo "[$(date)] FATAL: could not determine Hyprland version" >> "$LOG"
    exit 1
fi
echo "[$(date)] Hyprland version: $HYPR_VER ($HYPR_COMMIT)" >> "$LOG"

# ── Discover plugin .so files ──
# Search known hyprpm plugin output dirs in priority order:
#   1. $XDG_RUNTIME_DIR/hyprpm/$USER/  (modern hyprpm builds here)
#   2. ~/.local/share/hyprpm/          (older hyprpm location)
#   3. /run/user/$UID/hyprpm/          (alias for #1)
search_dirs=()
[ -n "${XDG_RUNTIME_DIR:-}" ] && search_dirs+=("$XDG_RUNTIME_DIR/hyprpm/$USER")
search_dirs+=("$HOME/.local/share/hyprpm")
[ -n "${UID:-}" ] && search_dirs+=("/run/user/$UID/hyprpm/$USER")

# Build the plugins JSON array
plugins_json=""
count=0
for sd in "${search_dirs[@]}"; do
    [ -d "$sd" ] || continue
    echo "[$(date)] Scanning $sd" >> "$LOG"
    # Each plugin lives in its own subdir; .so name matches subdir name
    while IFS= read -r so; do
        [ -z "$so" ] && continue
        name=$(basename "$(dirname "$so")")
        echo "[$(date)] Found: $name → $so" >> "$LOG"
        if [ -n "$plugins_json" ]; then
            plugins_json="$plugins_json,"
        fi
        plugins_json="$plugins_json"$'\n'"    { \"name\": \"$name\", \"path\": \"$so\" }"
        count=$((count + 1))
    done < <(find "$sd" -maxdepth 2 -name "*.so" -type f 2>/dev/null)
done

# Write the cache JSON
created_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
cat > "$CACHE" << EOF
{
  "hyprland_version": "$HYPR_VER",
  "hyprland_commit": "$HYPR_COMMIT",
  "created_at": "$created_at",
  "plugins": [${plugins_json}
  ]
}
EOF

echo "[$(date)] Wrote cache with $count plugins to $CACHE" >> "$LOG"
echo "Cache rebuilt: $count plugins for Hyprland $HYPR_VER"
exit 0
