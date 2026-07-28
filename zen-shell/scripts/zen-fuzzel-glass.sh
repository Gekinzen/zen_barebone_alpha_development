#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# zen-fuzzel-glass.sh — make the fuzzel launcher match the Glass+ shell frost.
#
# fuzzel is its own app; its colours live in ~/.config/fuzzel/fuzzel.ini, which
# regen-terminal-themes.sh rewrites from the current theme — always with an
# OPAQUE background. On the clear shell look the launcher was therefore a solid
# slab (dark on a dark theme, cream on a light one), matching nothing.
#
# The shell's panels use a NEUTRAL WHITE frost on Glass+, regardless of theme.
# So does fuzzel now: this rewrites the [colors] background to ffffff + a
# translucent alpha, so the launcher reads as the same frosted glass. fuzzel gets
# real blur when the compositor blurs its layer (namespace `fuzzel`).
#
#   zen-fuzzel-glass.sh <alpha_hex>   # e.g. 3b — white @ ~23%. Glass+ active.
#   zen-fuzzel-glass.sh --opaque      # restore the theme's own opaque background
#
# For --opaque it re-reads the theme background from current-theme.json (so it
# puts back exactly what regen would have), falling back to leaving the line
# alone if that's unavailable. For the glass case it only ever writes ffffffAA.
#
# Idempotent, and it touches ONLY the [colors] background line.
# ─────────────────────────────────────────────────────────────────────────────
set -u
INI="${FUZZEL_INI:-$HOME/.config/fuzzel/fuzzel.ini}"
[ -f "$INI" ] || exit 0

MODE="${1:-}"
if [ "$MODE" = "--opaque" ]; then
    NEWBG=""      # empty = restore from theme / leave alone (handled below)
else
    ALPHA="${MODE:-3b}"
    case "$ALPHA" in
        [0-9a-fA-F][0-9a-fA-F]) : ;;
        *) echo "zen-fuzzel-glass: alpha must be 2 hex digits, got '$ALPHA'" >&2; exit 2 ;;
    esac
    NEWBG="ffffff${ALPHA}"
fi

# Glass defaults: the sheet we write is always white-dominant, so the ink that reads
# on it is always dark. --opaque overrides all three from the theme below.
INK="1a1b20ff"          # near-black, reads on the white sheet
INK_MATCH="0f62feff"    # the matched substring — an accent that still passes on white
SEL="00000014"          # selection wash: a faint dark tint, not another white

# For --opaque, recover the theme's own colours so we restore exactly.
#
# v8.0.0-alpha-hf178 — this used to recover only the background. That was fine while the
# script never touched the text, but now it does: leaving Glass+ would restore a dark
# theme background under the dark ink the glass run wrote, i.e. dark-on-dark. So --opaque
# now pulls the theme's fg/blue/bg2 back as well, and the two paths stay symmetrical.
_theme_hex() {   # $1 = colour key; echoes rrggbb, empty if not found
    v=""
    if command -v jq >/dev/null 2>&1; then
        v="$(jq -r ".colors.$1 // empty" "$THEME_JSON" 2>/dev/null | tr -d '#')"
    fi
    if [ -z "$v" ]; then
        v="$(grep -o "\"$1\"[[:space:]]*:[[:space:]]*\"#\?[0-9a-fA-F]\{6\}\"" "$THEME_JSON" 2>/dev/null \
             | grep -o '[0-9a-fA-F]\{6\}' | head -1)"
    fi
    [ "${#v}" -eq 6 ] && printf '%s' "$v"
}

if [ "$MODE" = "--opaque" ]; then
    THEME_JSON="${ZEN_THEME_JSON:-$HOME/.config/hypr-control-center/current-theme.json}"
    if [ -f "$THEME_JSON" ]; then
        bg="$(_theme_hex bg0)"
        [ -n "$bg" ] && NEWBG="${bg}ff"
        fg="$(_theme_hex fg)";    [ -n "$fg" ]    && INK="${fg}ff"
        bl="$(_theme_hex blue)";  [ -n "$bl" ]    && INK_MATCH="${bl}ff"
        s2="$(_theme_hex bg2)";   [ -n "$s2" ]    && SEL="${s2}ff"
    fi
    # if we couldn't resolve the background, leave the file alone entirely (no-op)
    [ -z "$NEWBG" ] && exit 0
fi

tmp="$(mktemp)"
# v8.0.0-alpha-hf178 — also rewrite the TEXT colours, not just the background.
#
# Before, this touched only `background`, so on the clear look fuzzel became a white
# sheet while its text stayed whatever the theme set — which on a dark theme is light
# text. White on white. That's why Super+D was unreadable on Glass+.
#
# The sheet we write is always white-dominant, so the ink that reads on it is always
# dark. No luminance test needed: we control both sides. On --opaque we restore the
# theme's own background and leave the text lines alone, because there the theme's own
# fg/bg pair is already designed to contrast.
awk -v bg="$NEWBG" -v ink="$INK" -v inkm="$INK_MATCH" -v sel="$SEL" -v mode="$MODE" '
    /^\[/ { section = $0 }
    section == "[colors]" && /^[[:space:]]*background[[:space:]]*=[[:space:]]*[0-9a-fA-F]{8}[[:space:]]*$/ {
        sub(/=[[:space:]]*[0-9a-fA-F]{8}[[:space:]]*$/, "=" bg)
        print; next
    }
    # Only retint the text when we are putting fuzzel ON the white sheet.
    section == "[colors]" && /^[[:space:]]*text[[:space:]]*=[[:space:]]*[0-9a-fA-F]{8}[[:space:]]*$/ {
        sub(/=[[:space:]]*[0-9a-fA-F]{8}[[:space:]]*$/, "=" ink); print; next
    }
    section == "[colors]" && /^[[:space:]]*selection-text[[:space:]]*=[[:space:]]*[0-9a-fA-F]{8}[[:space:]]*$/ {
        sub(/=[[:space:]]*[0-9a-fA-F]{8}[[:space:]]*$/, "=" ink); print; next
    }
    section == "[colors]" && /^[[:space:]]*selection-match[[:space:]]*=[[:space:]]*[0-9a-fA-F]{8}[[:space:]]*$/ {
        sub(/=[[:space:]]*[0-9a-fA-F]{8}[[:space:]]*$/, "=" inkm); print; next
    }
    section == "[colors]" && /^[[:space:]]*match[[:space:]]*=[[:space:]]*[0-9a-fA-F]{8}[[:space:]]*$/ {
        sub(/=[[:space:]]*[0-9a-fA-F]{8}[[:space:]]*$/, "=" inkm); print; next
    }
    section == "[colors]" && /^[[:space:]]*selection[[:space:]]*=[[:space:]]*[0-9a-fA-F]{8}[[:space:]]*$/ {
        sub(/=[[:space:]]*[0-9a-fA-F]{8}[[:space:]]*$/, "=" sel); print; next
    }
    { print }
' "$INI" > "$tmp" && cat "$tmp" > "$INI"
rm -f "$tmp"
