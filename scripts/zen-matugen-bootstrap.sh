#!/usr/bin/env bash
# zen-matugen-bootstrap.sh — v6.16.4.12.6.3 (Hikari)
#
# Idempotent matugen config bootstrap. Safe to run on every install.
#
# What this script does:
#   1. Verifies matugen is installed (warns + exits 0 if not — toggle in
#      Themes page already hides itself when binary is missing, so the
#      shell still boots cleanly without matugen).
#   2. Creates ~/.config/matugen/ (config dir).
#   3. Drops a minimal config.toml IF MISSING. matugen 2.x requires a
#      [templates] section even when no templates are configured —
#      omitting it caused the "missing field `templates`" failure
#      reported by Paul against v6.16.4.12.6.{0,1,2}.
#   4. v6.16.4.12.6.3 NEW: HEALS existing configs that lack [templates].
#      Anyone who installed v6.16.4.12.6 → v6.16.4.12.6.2 has a broken
#      config; we detect that and append [templates] in place. The
#      original config is backed up to config.toml.bak-zenheal-<date>.
#
# Note: zen-shell's own matugen call now ALWAYS uses --config <tempfile>
# with a known-good minimal config, so this script is no longer required
# for the in-shell Matugen toggle to work. It's still useful for users
# who want to use matugen MANUALLY for other apps (kitty, gtk, discord,
# etc.) — those workflows do read ~/.config/matugen/config.toml.
#
# Wala tayo babawasan — only writes when missing or healing.
set -euo pipefail

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/matugen"
CONFIG_FILE="$CONFIG_DIR/config.toml"

if ! command -v matugen >/dev/null 2>&1; then
    echo "[zen-matugen-bootstrap] matugen not installed — skipping"
    echo "[zen-matugen-bootstrap] To enable wallpaper-driven theming:"
    echo "[zen-matugen-bootstrap]   paru -S matugen-bin     # AUR"
    echo "[zen-matugen-bootstrap]   yay  -S matugen         # alt"
    exit 0
fi

mkdir -p "$CONFIG_DIR"

# The minimal known-good config we write on fresh install.
# matugen 2.x REQUIRES [templates] (even empty) — see commit message.
write_fresh_config() {
    cat > "$CONFIG_FILE" <<'TOML'
# matugen config — installed by zen-shell v6.16.4.12.6.3 (Hikari)
#
# zen-shell uses matugen as a palette extractor only. The shell calls
# matugen with --config <tempfile> (a self-contained minimal config),
# so this file does NOT affect the in-shell Matugen toggle. Edit it
# only if you want matugen to ALSO theme other apps (kitty, gtk,
# discord, etc.) when you run matugen MANUALLY from the terminal.
#
# matugen 2.x requires [templates] even when empty — DO NOT remove
# the section header below or matugen errors with:
#   "missing field `templates`"

[config]
reload_apps = false
set_wallpaper = false   # zen-shell already handles the wallpaper itself

# Add your own [templates.kitty], [templates.gtk] etc. here if you want
# matugen to theme other apps too. Examples in matugen's docs:
#   https://github.com/InioX/matugen
[templates]
TOML
    echo "[zen-matugen-bootstrap] Wrote $CONFIG_FILE"
}

if [ ! -f "$CONFIG_FILE" ]; then
    write_fresh_config
    echo "[zen-matugen-bootstrap] Done. Toggle in Settings → Themes → Matugen."
    exit 0
fi

# ────────────────────────────────────────────────────────────────────
# v6.16.4.12.6.3: heal existing broken configs (missing [templates])
# ────────────────────────────────────────────────────────────────────
if ! grep -qE '^\[templates(\.|$|\])' "$CONFIG_FILE"; then
    BACKUP="${CONFIG_FILE}.bak-zenheal-$(date +%Y%m%d-%H%M%S)"
    cp "$CONFIG_FILE" "$BACKUP"
    {
        echo ""
        echo "# v6.16.4.12.6.3 healed: matugen 2.x requires [templates] even empty"
        echo "[templates]"
    } >> "$CONFIG_FILE"
    echo "[zen-matugen-bootstrap] Healed $CONFIG_FILE — appended [templates] section"
    echo "[zen-matugen-bootstrap] Original backed up to $BACKUP"
else
    echo "[zen-matugen-bootstrap] $CONFIG_FILE already has [templates] — leaving alone"
fi
