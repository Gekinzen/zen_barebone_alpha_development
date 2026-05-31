#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
# zen-sddm-sync.sh v7.0.0-beta.1-hf95.10 — SDDM greeter live sync
# ────────────────────────────────────────────────────────────────
# Makes the Zen Tokyo SDDM greeter track your live desktop, the same
# way zen-lock.sh keeps hyprlock in sync — but into a world-readable
# system theme dir, because the greeter runs as the `sddm` user and
# cannot read your $HOME.
#
# What it does:
#   1. Reads .currentWallpaper from wallpaper-v5.json and COPIES it
#      into  <theme>/backgrounds/current  (copy, not symlink — sddm
#      can't follow a symlink into your $HOME).
#   2. Maps your bar fontFamilyId → clock/text fonts (identical
#      mapping to zen-lock.sh) and rewrites them in theme.conf.
#   3. Optionally exports the current mood/care line (from
#      zen-lock-message.sh) into <theme>/mood-care.txt.
#
# Run it:
#   - at logout / shutdown (so the greeter shows your last wallpaper)
#   - whenever you change wallpaper (WallpaperServiceV5 can call it)
#
# Root: writing under /usr/share needs root. Either run via the
# pkexec/sudoers rule installed by zen-sddm-install.sh, or invoke as
# root directly. The user whose wallpaper to read is resolved from
# SUDO_USER / PKEXEC_UID / the --user arg, falling back to $USER.
#
# Idempotent + safe: only writes the theme dir, never touches your
# $HOME. Wala tayong babawasan.
# ════════════════════════════════════════════════════════════════
set -u

THEME_DIR="${ZEN_SDDM_THEME_DIR:-/usr/share/sddm/themes/zen-tokyo}"
LOG="/var/log/zen-sddm-sync.log"

# ── Resolve the human user whose desktop we mirror ──
SRC_USER=""
for cand in "${1:-}" "${ZEN_SDDM_USER:-}" "${SUDO_USER:-}"; do
    case "$cand" in --user=*) cand="${cand#--user=}";; esac
    [ -n "$cand" ] && { SRC_USER="$cand"; break; }
done
if [ -z "$SRC_USER" ] && [ -n "${PKEXEC_UID:-}" ]; then
    SRC_USER="$(getent passwd "$PKEXEC_UID" | cut -d: -f1)"
fi
[ -z "$SRC_USER" ] && SRC_USER="${USER:-}"
SRC_HOME="$(getent passwd "$SRC_USER" | cut -d: -f6)"
[ -z "$SRC_HOME" ] && SRC_HOME="/home/$SRC_USER"

log() { echo "[$(date '+%F %T')] $*" >>"$LOG" 2>/dev/null || true; }

if [ ! -d "$THEME_DIR" ]; then
    echo "Theme dir not found: $THEME_DIR (run zen-sddm-install.sh first)" >&2
    exit 1
fi
mkdir -p "$THEME_DIR/backgrounds" 2>/dev/null

WP_STATE="$SRC_HOME/.config/quickshell/zen-shell/wallpaper-v5.json"
PANEL_STATE="$SRC_HOME/.local/share/quickshell/zen-shell/panel-state.json"
SETTINGS_STATE="$SRC_HOME/.config/quickshell/zen-shell/settings-state.json"
CONF="$THEME_DIR/theme.conf"

# v7.0.0-beta.1-hf95.12: respect the Settings → Login Screen toggles.
#   sddm.loginEnabled  → if false, do nothing (user hasn't opted in).
#   sddm.backgroundMode → "wallpaper" (blurred image) | "matugen" (solid
#                         colour from the active scheme).
LOGIN_ENABLED="true"
BG_MODE="wallpaper"
if [ -f "$SETTINGS_STATE" ] && command -v jq >/dev/null 2>&1; then
    le="$(jq -r '.sddm.loginEnabled // empty' "$SETTINGS_STATE" 2>/dev/null)"
    bm="$(jq -r '.sddm.backgroundMode // empty' "$SETTINGS_STATE" 2>/dev/null)"
    [ -n "$le" ] && LOGIN_ENABLED="$le"
    [ -n "$bm" ] && BG_MODE="$bm"
fi
# Allow callers (installer first-run) to force a sync even pre-toggle.
[ "${ZEN_SDDM_FORCE:-}" = "1" ] && LOGIN_ENABLED="true"
if [ "$LOGIN_ENABLED" != "true" ]; then
    log "SDDM login theme disabled in settings for $SRC_USER — skipping sync"
    exit 0
fi

# ── 1. Background ──
if [ "$BG_MODE" = "matugen" ]; then
    # Solid colour from the scheme: tell the greeter to skip the image and
    # use the flat background colour (set in step 3 from current-theme.json).
    sed -i -E "s|^backgroundMode=.*|backgroundMode=matugen|" "$CONF" 2>/dev/null \
        || echo "backgroundMode=matugen" >> "$CONF"
    rm -f "$THEME_DIR/backgrounds/current" "$THEME_DIR/backgrounds/current".* 2>/dev/null
    log "background mode = matugen (solid scheme colour, no wallpaper)"
else
    sed -i -E "s|^backgroundMode=.*|backgroundMode=wallpaper|" "$CONF" 2>/dev/null \
        || echo "backgroundMode=wallpaper" >> "$CONF"
    CURRENT_WP=""
if command -v jq >/dev/null 2>&1 && [ -f "$WP_STATE" ]; then
    CURRENT_WP="$(jq -r '.currentWallpaper // empty' "$WP_STATE" 2>/dev/null)"
fi
if [ -n "$CURRENT_WP" ] && [ -f "$CURRENT_WP" ]; then
    # Keep the original extension so the QML Image decoder is happy.
    ext="${CURRENT_WP##*.}"
    case "$ext" in jpg|jpeg|png|webp|bmp) : ;; *) ext="png" ;; esac
    rm -f "$THEME_DIR/backgrounds/current" "$THEME_DIR/backgrounds/current".* 2>/dev/null
    cp -f "$CURRENT_WP" "$THEME_DIR/backgrounds/current.$ext"
    # theme.conf references `backgrounds/current` (no ext); provide a
    # stable copy at that exact name too so the Image source resolves.
    cp -f "$CURRENT_WP" "$THEME_DIR/backgrounds/current"
    chmod 0644 "$THEME_DIR/backgrounds/current" "$THEME_DIR/backgrounds/current.$ext" 2>/dev/null
    log "wallpaper copied: $CURRENT_WP -> $THEME_DIR/backgrounds/current.$ext"
else
    log "no current wallpaper for $SRC_USER (greeter keeps previous / flat colour)"
fi
fi   # end BG_MODE wallpaper/matugen branch

# ── 2. Map fonts (identical to zen-lock.sh) ──
if [ -f "$PANEL_STATE" ] && command -v jq >/dev/null 2>&1; then
    FONT_ID="$(jq -r '.fontFamilyId // "adwaita"' "$PANEL_STATE" 2>/dev/null)"
    case "$FONT_ID" in
        adwaita)   CLOCK_FONT="Adwaita Sans Black";            TEXT_FONT="Adwaita Sans" ;;
        jetbrains) CLOCK_FONT="JetBrainsMono Nerd Font Bold";  TEXT_FONT="JetBrainsMono Nerd Font Propo" ;;
        geist)     CLOCK_FONT="GeistMono Nerd Font Mono Bold"; TEXT_FONT="GeistMono Nerd Font Mono" ;;
        firacode)  CLOCK_FONT="FiraCode Nerd Font Bold";       TEXT_FONT="FiraCode Nerd Font" ;;
        caskaydia) CLOCK_FONT="CaskaydiaCove Nerd Font Bold";  TEXT_FONT="CaskaydiaCove Nerd Font" ;;
        iosevka)   CLOCK_FONT="Iosevka Nerd Font Heavy";       TEXT_FONT="Iosevka Nerd Font" ;;
        hack)      CLOCK_FONT="Hack Nerd Font Bold";           TEXT_FONT="Hack Nerd Font" ;;
        ubuntu)    CLOCK_FONT="UbuntuMono Nerd Font Bold";     TEXT_FONT="UbuntuMono Nerd Font" ;;
        sfpro)     CLOCK_FONT="SF Pro Display Black";          TEXT_FONT="SF Pro Text" ;;
        inter)     CLOCK_FONT="Inter Black";                   TEXT_FONT="Inter" ;;
        *)         CLOCK_FONT="Adwaita Sans Black";            TEXT_FONT="Adwaita Sans" ;;
    esac
    if [ -f "$CONF" ]; then
        sed -i -E "s|^clockFont=.*|clockFont=${CLOCK_FONT}|" "$CONF"
        sed -i -E "s|^textFont=.*|textFont=${TEXT_FONT}|"   "$CONF"
        log "fonts synced: clock=${CLOCK_FONT} text=${TEXT_FONT} (id=${FONT_ID})"
    fi
fi

# ── 3. Sync theme colours from the user's active scheme ──
# v7.0.0-beta.1-hf95.11: the greeter now follows whatever theme the
# user has selected, instead of fixed Tokyo-Night. ThemeService writes
# the active scheme to ~/.config/hypr-control-center/current-theme.json
# (schema: .colors.{bg0,bg1,bg2,bg3,fg,grey1,blue,green,red,...}). We map
# those into theme.conf's colour keys with the same roles the QML uses:
#   background ← bg0   surface ← bg2   text ← fg      dim ← grey1
#   accent ← blue      accentText ← bg0 success ← green error ← red
#   border ← bg3
THEME_JSON="$SRC_HOME/.config/hypr-control-center/current-theme.json"
if [ -f "$THEME_JSON" ] && command -v jq >/dev/null 2>&1 && [ -f "$CONF" ]; then
    # Pull each colour with a fallback to the existing Tokyo-Night value
    # so a theme that omits a key doesn't blank it out.
    get() { jq -r ".colors.$1 // empty" "$THEME_JSON" 2>/dev/null; }
    C_BG0="$(get bg0)";  C_BG2="$(get bg2)";  C_BG3="$(get bg3)"
    C_FG="$(get fg)";    C_GREY1="$(get grey1)"
    C_BLUE="$(get blue)"; C_GREEN="$(get green)"; C_RED="$(get red)"

    setkey() {  # setkey <key> <value>  — only if value is a #hex
        local k="$1" v="$2"
        case "$v" in \#[0-9a-fA-F][0-9a-fA-F]*) sed -i -E "s|^${k}=.*|${k}=${v}|" "$CONF" ;; esac
    }
    setkey colorBackground "$C_BG0"
    setkey colorSurface    "$C_BG2"
    setkey colorText       "$C_FG"
    setkey colorTextDim    "$C_GREY1"
    setkey colorAccent     "$C_BLUE"
    setkey colorAccentText "$C_BG0"
    setkey colorSuccess    "$C_GREEN"
    setkey colorError      "$C_RED"
    setkey colorBorder     "$C_BG3"
    log "theme colours synced from $THEME_JSON (bg0=$C_BG0 accent=$C_BLUE)"
else
    log "no current-theme.json for $SRC_USER (greeter keeps existing colours)"
fi

# ── 4. Publish the user's avatar so the greeter matches the start menu ──
# v7.0.0-beta.1-hf95.12: the start menu resolves the avatar via
# UserProfileService (~/.face, AccountsService, /usr/share/sddm/faces,
# or the zen-shell override ~/.config/zen-shell/user-avatar.*). SDDM's
# greeter reads /var/lib/AccountsService/icons/<user> and
# /usr/share/sddm/faces/<user>.face.icon. To make them match, copy the
# best available source avatar into BOTH SDDM-readable locations.
AV_SRC=""
for cand in \
    "$SRC_HOME/.config/zen-shell/user-avatar.png" \
    "$SRC_HOME/.config/zen-shell/user-avatar.jpg" \
    "$SRC_HOME/.config/zen-shell/user-avatar.jpeg" \
    "$SRC_HOME/.face" "$SRC_HOME/.face.icon"; do
    [ -f "$cand" ] && { AV_SRC="$cand"; break; }
done
if [ -n "$AV_SRC" ]; then
    mkdir -p /var/lib/AccountsService/icons /usr/share/sddm/faces 2>/dev/null
    cp -f "$AV_SRC" "/var/lib/AccountsService/icons/$SRC_USER" 2>/dev/null \
        && chmod 0644 "/var/lib/AccountsService/icons/$SRC_USER" 2>/dev/null
    cp -f "$AV_SRC" "/usr/share/sddm/faces/$SRC_USER.face.icon" 2>/dev/null \
        && chmod 0644 "/usr/share/sddm/faces/$SRC_USER.face.icon" 2>/dev/null
    # Ensure AccountsService points at it (some greeters read the [User] Icon key).
    AS_USER_FILE="/var/lib/AccountsService/users/$SRC_USER"
    if [ ! -f "$AS_USER_FILE" ]; then
        mkdir -p /var/lib/AccountsService/users 2>/dev/null
        printf '[User]\nIcon=/var/lib/AccountsService/icons/%s\n' "$SRC_USER" > "$AS_USER_FILE" 2>/dev/null
    fi
    log "avatar published from $AV_SRC for $SRC_USER"
else
    log "no avatar source for $SRC_USER (greeter uses letter fallback)"
fi

# ── 5. Optional mood/care line ──
MSG_SCRIPT="$SRC_HOME/.local/bin/zen-lock-message.sh"
if [ -x "$MSG_SCRIPT" ]; then
    # Run as the source user so its $HOME/weather.json resolves.
    LINE="$(runuser -u "$SRC_USER" -- "$MSG_SCRIPT" weather 2>/dev/null || true)"
    printf '%s' "$LINE" > "$THEME_DIR/mood-care.txt" 2>/dev/null
    chmod 0644 "$THEME_DIR/mood-care.txt" 2>/dev/null
    log "mood line exported: $LINE"
fi

log "sync complete for user=$SRC_USER"
exit 0
