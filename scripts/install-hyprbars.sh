#!/usr/bin/env bash
# install-hyprbars.sh
# Manual hyprbars installer for systems where hyprpm's pinned release
# fails to build (e.g. Hyprland 0.54.3 missing GLTexture.hpp headers).
#
# Strategy: install AUR per-plugin package which builds against
# system /usr/include/hyprland headers, then symlink the .so into
# hyprpm's data dir so Zen Shell's PluginsPage detects it.

set -e
BOLD=$(tput bold 2>/dev/null||echo)
G=$(tput setaf 2 2>/dev/null||echo)
Y=$(tput setaf 3 2>/dev/null||echo)
R=$(tput setaf 1 2>/dev/null||echo)
N=$(tput sgr0 2>/dev/null||echo)
ok(){ echo "${G}✓${N} $*";}
warn(){ echo "${Y}⚠${N} $*";}
fail(){ echo "${R}✗${N} $*";}

echo "${BOLD}Hyprbars manual install (AUR fallback for stuck pinned releases)${N}"
echo

HELPER=""
command -v paru >/dev/null && HELPER=paru
[ -z "$HELPER" ] && command -v yay >/dev/null && HELPER=yay
if [ -z "$HELPER" ]; then
    fail "No AUR helper (need paru or yay)"
    echo "  Install paru first:"
    echo "    sudo pacman -S --needed base-devel git"
    echo "    git clone https://aur.archlinux.org/paru.git"
    echo "    cd paru && makepkg -si"
    exit 1
fi
ok "AUR helper: $HELPER"

# Try -git variant first (matches hyprland-git better), then non-git
PKG=""
for c in hyprland-plugin-hyprbars-git hyprland-plugin-hyprbars; do
    if $HELPER -Si "$c" >/dev/null 2>&1; then
        PKG="$c"
        break
    fi
done
if [ -z "$PKG" ]; then
    fail "No hyprbars AUR package found"
    echo "  Search: $HELPER -Ss hyprbars"
    exit 1
fi
ok "AUR package found: $PKG"

echo
echo "Installing $PKG (will prompt for sudo)..."
$HELPER -S --needed "$PKG"

# Find the built .so file
SO=""
for candidate in \
    /usr/lib/libhyprbars.so \
    /usr/lib/hyprland-plugins/hyprbars.so \
    /usr/lib/hyprland/hyprbars.so; do
    [ -f "$candidate" ] && SO="$candidate" && break
done
if [ -z "$SO" ]; then
    warn "Couldn't auto-find hyprbars.so. Checking package contents:"
    pacman -Ql "$PKG" | grep -E '\.so$'
    echo
    fail "Manually find the .so and run:"
    echo "  ln -sf <path-to-hyprbars.so> ~/.local/share/hyprpm/hyprland-plugins/hyprbars/hyprbars.so"
    exit 1
fi
ok "Found: $SO"

# Symlink into hyprpm data dir
HYPRPM_DIR="$HOME/.local/share/hyprpm/hyprland-plugins/hyprbars"
mkdir -p "$HYPRPM_DIR"
ln -sf "$SO" "$HYPRPM_DIR/hyprbars.so"
ok "Symlinked: $HYPRPM_DIR/hyprbars.so → $SO"

# Reload
hyprctl reload 2>&1 | sed 's/^/    /' || true

# Try direct hyprctl plugin load (since hyprpm may still mark as failed)
echo
echo "Loading via hyprctl plugin load..."
hyprctl plugin load "$SO" 2>&1 | sed 's/^/    /' || \
    warn "hyprctl plugin load returned an error (check above)"

echo
echo "${BOLD}${G}Done!${N}"
echo
echo "Test: open a floating window — should have a title bar now."
echo
echo "If Zen Shell PluginsPage still shows yellow 'build failed':"
echo "  • Wait 3 seconds (auto-refresh) — should flip to green"
echo "  • Or manually restart shell: zs-restart.sh"
echo
echo "To make hyprbars auto-load on Hyprland start, add to plugins.conf:"
echo "  plugin = $SO"
echo "  (or toggle ON sa Settings → Plugins → Hyprbars)"
