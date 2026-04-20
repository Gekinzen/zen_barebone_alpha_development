#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# Zen Shell v6.15.13 — Bootstrap
# ═══════════════════════════════════════════════════════════════
# Installs Hyprland + Quickshell + all Zen Shell dependencies on a
# fresh Arch-based system (Arch, CachyOS, EndeavourOS, Manjaro).
#
# Designed to be safe on laptops that already run KDE / GNOME / COSMIC:
#   - Does NOT install or touch the display manager (SDDM / GDM / etc.)
#   - Does NOT change the default session or autologin
#   - Does NOT enable/disable any systemd services besides optional
#     user-facing ones the user explicitly opts into later
#   - Creates /usr/share/wayland-sessions/hyprland.desktop (if missing)
#     so Hyprland becomes selectable from the EXISTING login screen
#
# After bootstrap: logout, pick "Hyprland" at the login screen, then
# run install.sh normally to apply Zen Shell configs.
# ═══════════════════════════════════════════════════════════════
set -o pipefail 2>/dev/null || true

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# ── Colors (plain if no tty) ──
if [ -t 1 ]; then
    C_RED=$'\033[0;31m'
    C_YEL=$'\033[1;33m'
    C_GRN=$'\033[0;32m'
    C_CYN=$'\033[0;36m'
    C_DIM=$'\033[2m'
    C_END=$'\033[0m'
else
    C_RED=""; C_YEL=""; C_GRN=""; C_CYN=""; C_DIM=""; C_END=""
fi

echo ""
echo "    Zen Shell v6.15.13 — Bootstrap"
echo "    ─────────────────────────────────────────────────────"
echo ""
echo "    Installs Hyprland + Quickshell + all Zen Shell deps"
echo "    on a fresh Arch-based system."
echo ""
echo "    ⚠ This script is SAFE with existing desktop environments."
echo "      It will NOT:"
echo "        - Replace your display manager"
echo "        - Change your default session"
echo "        - Remove KDE / GNOME / COSMIC"
echo ""
echo "      It WILL:"
echo "        - Install Hyprland + Quickshell + ~35 support packages"
echo "        - Create a Hyprland wayland-session entry (selectable"
echo "          from your existing login screen)"
echo "        - Leave your current DE fully intact"
echo ""
echo "    ─────────────────────────────────────────────────────"
echo ""

# ═══════════════════════════════════════════════════════════════
# [1/6] Distro detection
# ═══════════════════════════════════════════════════════════════
echo "${C_CYN}[1/6]${C_END} Distro detection..."

if ! command -v pacman >/dev/null 2>&1; then
    echo "${C_RED}  ✗ pacman not found${C_END}"
    echo ""
    echo "    Bootstrap mode supports Arch-based distros only:"
    echo "      - Arch Linux"
    echo "      - CachyOS"
    echo "      - EndeavourOS"
    echo "      - Manjaro"
    echo ""
    echo "    For other distros you'll need to install Hyprland +"
    echo "    Quickshell manually, then re-run install.sh (without"
    echo "    --bootstrap)."
    exit 1
fi

DISTRO_NAME="Arch Linux"
if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    DISTRO_NAME="${PRETTY_NAME:-Arch Linux}"
fi
echo "    ${C_GRN}✓${C_END} $DISTRO_NAME (pacman detected)"

# ═══════════════════════════════════════════════════════════════
# [2/6] AUR helper detection
# ═══════════════════════════════════════════════════════════════
echo ""
echo "${C_CYN}[2/6]${C_END} AUR helper detection..."

AUR_HELPER=""
if command -v paru >/dev/null 2>&1; then
    AUR_HELPER="paru"
elif command -v yay >/dev/null 2>&1; then
    AUR_HELPER="yay"
fi

if [ -z "$AUR_HELPER" ]; then
    echo "${C_YEL}  ○ No AUR helper found (paru / yay)${C_END}"
    echo ""
    echo "    Some packages (quickshell, nwg-displays, etc.) come from"
    echo "    the AUR and need an AUR helper."
    echo ""
    read -rp "    Install paru now? [Y/n] " ans
    if [ "${ans,,}" != "n" ]; then
        echo ""
        echo "    Installing build tools..."
        sudo pacman -S --needed --noconfirm base-devel git
        TMPDIR=$(mktemp -d)
        git clone https://aur.archlinux.org/paru-bin.git "$TMPDIR/paru-bin"
        (cd "$TMPDIR/paru-bin" && makepkg -si --noconfirm)
        rm -rf "$TMPDIR"
        AUR_HELPER="paru"
        echo "    ${C_GRN}✓${C_END} paru installed"
    else
        echo ""
        echo "    Cannot proceed without an AUR helper. Install paru"
        echo "    or yay manually then re-run this script."
        exit 1
    fi
else
    echo "    ${C_GRN}✓${C_END} $AUR_HELPER ($(command -v "$AUR_HELPER"))"
fi

# ═══════════════════════════════════════════════════════════════
# [3/6] Existing DE / compositor detection
# ═══════════════════════════════════════════════════════════════
echo ""
echo "${C_CYN}[3/6]${C_END} Desktop environment check..."

CURRENT_DE="${XDG_CURRENT_DESKTOP:-unknown}"
SESSION_TYPE="${XDG_SESSION_TYPE:-unknown}"
DM_RUNNING=""

for dm in sddm gdm lightdm lxdm ly greetd; do
    if systemctl is-active --quiet "$dm" 2>/dev/null; then
        DM_RUNNING="$dm"; break
    fi
done

echo "    Current desktop : $CURRENT_DE"
echo "    Session type    : $SESSION_TYPE"
echo "    Display manager : ${DM_RUNNING:-(none detected)}"

CONFLICTING=0
case "${CURRENT_DE,,}" in
    *plasma*|*kde*)      CONFLICTING=1; CONFLICT_NAME="KDE Plasma" ;;
    *gnome*)             CONFLICTING=1; CONFLICT_NAME="GNOME" ;;
    *cosmic*)            CONFLICTING=1; CONFLICT_NAME="COSMIC" ;;
    *sway*)              CONFLICTING=1; CONFLICT_NAME="Sway" ;;
    *hyprland*)          CONFLICTING=0 ;;
    *)                   CONFLICTING=0 ;;
esac

if [ "$CONFLICTING" = "1" ]; then
    echo ""
    echo "${C_YEL}    ⚠  You are currently running $CONFLICT_NAME.${C_END}"
    echo ""
    echo "    Bootstrap will proceed, but take note:"
    echo "      - Hyprland cannot run alongside $CONFLICT_NAME in the"
    echo "        same session. You must logout and pick 'Hyprland'"
    echo "        from the login screen after bootstrap completes."
    echo "      - Your $CONFLICT_NAME setup will remain intact and"
    echo "        selectable at the login screen."
    echo ""
    read -rp "    Continue with bootstrap? [Y/n] " ans
    [ "${ans,,}" = "n" ] && echo "    Cancelled." && exit 0
fi

# ═══════════════════════════════════════════════════════════════
# [4/6] Package installation
# ═══════════════════════════════════════════════════════════════
echo ""
echo "${C_CYN}[4/6]${C_END} Install packages..."

# Tier 1 — Core (Hyprland + Quickshell + hard deps)
TIER_CORE=(
    hyprland
    quickshell-git
    jq
    xdg-desktop-portal-hyprland
    polkit-gnome
    qt6-declarative
    qt6-wayland
    qt6-5compat
    qt6-svg
)

# Tier 2 — DE/compositor essentials (audio, gfx, network, bluetooth)
# These are typically already on a KDE/GNOME system but pacman -S --needed
# skips anything already installed, so safe to include.
TIER_SYSTEM=(
    pipewire
    pipewire-pulse
    pipewire-alsa
    wireplumber
    networkmanager
    bluez
    bluez-utils
)

# Tier 3 — Zen Shell specific (strings, wallpaper, launcher, notifications)
TIER_ZEN=(
    swww
    swaync
    fuzzel
    cava
    playerctl
    grim
    slurp
    wl-clipboard
    imagemagick
    alacritty
    thunar
    pavucontrol
    blueman
    zenity
    bottom
    libnotify
    nwg-displays
    nwg-look
)

# Tier 4 — Fonts + icons (Zen Shell design tokens)
TIER_FONTS=(
    ttf-jetbrains-mono-nerd
    ttf-font-awesome
    noto-fonts
    noto-fonts-emoji
    papirus-icon-theme
)

ALL_PKGS=("${TIER_CORE[@]}" "${TIER_SYSTEM[@]}" "${TIER_ZEN[@]}" "${TIER_FONTS[@]}")
TOTAL_COUNT=${#ALL_PKGS[@]}

echo "    ${TOTAL_COUNT} packages total across 4 tiers."
echo ""
echo "${C_DIM}    Tier 1 — Core        : ${#TIER_CORE[@]}   (hyprland, quickshell, qt6)${C_END}"
echo "${C_DIM}    Tier 2 — System      : ${#TIER_SYSTEM[@]}   (pipewire, NM, bluetooth)${C_END}"
echo "${C_DIM}    Tier 3 — Zen Shell   : ${#TIER_ZEN[@]}  (swww, swaync, cava, …)${C_END}"
echo "${C_DIM}    Tier 4 — Fonts/icons : ${#TIER_FONTS[@]}   (JetBrains Mono, Nerd, Papirus)${C_END}"
echo ""
echo "    ${C_DIM}Already-installed packages will be skipped (--needed).${C_END}"
echo ""
read -rp "    Proceed with installation? [Y/n] " ans
[ "${ans,,}" = "n" ] && echo "    Cancelled." && exit 0
echo ""

# Install all tiers in one shot — faster than multiple pacman runs.
# --needed : skip already installed
# --noconfirm : no prompts (user already confirmed above)
echo "${C_DIM}    Running: $AUR_HELPER -S --needed --noconfirm …${C_END}"
echo ""

if "$AUR_HELPER" -S --needed --noconfirm "${ALL_PKGS[@]}"; then
    echo ""
    echo "    ${C_GRN}✓${C_END} All packages installed / already present"
else
    echo ""
    echo "${C_YEL}    ⚠  Some packages failed.${C_END}"
    echo "    Common causes:"
    echo "      - quickshell-git : AUR build failure → try 'quickshell' instead"
    echo "      - nwg-displays   : requires gtk4 layer-shell (auto deps usually fix)"
    echo ""
    read -rp "    Continue anyway? [Y/n] " ans
    [ "${ans,,}" = "n" ] && echo "    Aborted." && exit 1
fi

# ═══════════════════════════════════════════════════════════════
# [5/6] Hyprland wayland-session entry
# ═══════════════════════════════════════════════════════════════
echo ""
echo "${C_CYN}[5/6]${C_END} Hyprland session entry..."

SESSION_FILE="/usr/share/wayland-sessions/hyprland.desktop"
if [ -f "$SESSION_FILE" ]; then
    echo "    ${C_GRN}✓${C_END} $SESSION_FILE already exists"
else
    echo "    Creating $SESSION_FILE ..."
    sudo tee "$SESSION_FILE" >/dev/null <<'EOF'
[Desktop Entry]
Name=Hyprland
Comment=An intelligent dynamic tiling Wayland compositor
Exec=Hyprland
Type=Application
EOF
    echo "    ${C_GRN}✓${C_END} Created. Hyprland will now appear at the login screen."
fi

# ═══════════════════════════════════════════════════════════════
# [6/6] Minimal Hyprland config bootstrap (only if none exists)
# ═══════════════════════════════════════════════════════════════
echo ""
echo "${C_CYN}[6/6]${C_END} Hyprland base config..."

HYPR_DIR="$HOME/.config/hypr"
HYPR_CONF="$HYPR_DIR/hyprland.conf"

if [ -f "$HYPR_CONF" ]; then
    echo "    ${C_GRN}✓${C_END} $HYPR_CONF already exists — leaving alone"
else
    echo "    No existing Hyprland config. Writing minimal default..."
    mkdir -p "$HYPR_DIR/modules"
    cat > "$HYPR_CONF" <<'EOF'
# ═══════════════════════════════════════════════════════════════
# Minimal Hyprland config — bootstrapped by Zen Shell
# Run install.sh (without --bootstrap) to layer Zen Shell on top.
# ═══════════════════════════════════════════════════════════════

monitor = , preferred, auto, 1

env = XDG_CURRENT_DESKTOP,Hyprland
env = XDG_SESSION_TYPE,wayland
env = XDG_SESSION_DESKTOP,Hyprland
env = QT_QPA_PLATFORM,wayland
env = QT_WAYLAND_DISABLE_WINDOWDECORATION,1

exec-once = /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
exec-once = swww-daemon &
exec-once = swaync &
exec-once = nm-applet --indicator &
exec-once = blueman-applet &

input {
    kb_layout = us
    follow_mouse = 1
    touchpad {
        natural_scroll = true
    }
}

general {
    gaps_in = 4
    gaps_out = 8
    border_size = 2
    col.active_border = rgba(5A4F42ff) rgba(928572ff) 45deg
    col.inactive_border = rgba(595959aa)
    layout = dwindle
}

decoration {
    rounding = 8
    blur {
        enabled = true
        size = 6
        passes = 2
    }
}

animations {
    enabled = true
}

dwindle {
    pseudotile = true
    preserve_split = true
}

# Minimal binds — Zen Shell installer will add more
bind = SUPER, Return, exec, alacritty
bind = SUPER, Q, killactive
bind = SUPER, M, exit
bind = SUPER, E, exec, thunar
bind = SUPER, V, togglefloating
bind = SUPER, R, exec, fuzzel
bind = SUPER, F, fullscreen

bind = SUPER, left,  movefocus, l
bind = SUPER, right, movefocus, r
bind = SUPER, up,    movefocus, u
bind = SUPER, down,  movefocus, d

bind = SUPER, 1, workspace, 1
bind = SUPER, 2, workspace, 2
bind = SUPER, 3, workspace, 3
bind = SUPER, 4, workspace, 4
bind = SUPER, 5, workspace, 5

bind = SUPER SHIFT, 1, movetoworkspace, 1
bind = SUPER SHIFT, 2, movetoworkspace, 2
bind = SUPER SHIFT, 3, movetoworkspace, 3
bind = SUPER SHIFT, 4, movetoworkspace, 4
bind = SUPER SHIFT, 5, movetoworkspace, 5

bindm = SUPER, mouse:272, movewindow
bindm = SUPER, mouse:273, resizewindow

# Start Zen Shell on login (after install.sh has been run)
exec-once = qs -c zen-shell
EOF
    echo "    ${C_GRN}✓${C_END} $HYPR_CONF written"
fi

# ═══════════════════════════════════════════════════════════════
# DONE
# ═══════════════════════════════════════════════════════════════
echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                                                               ║"
echo "║         🎉  ZEN SHELL BOOTSTRAP COMPLETE  🎉                  ║"
echo "║                                                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "  Hyprland and all dependencies are installed."
echo ""
echo "  ── What happens next ──"
echo ""
echo "  1. Logout of your current session ($CURRENT_DE)"
echo ""
echo "  2. At the login screen (${DM_RUNNING:-your DM}), click the"
echo "     session selector (usually a dropdown or gear icon) and"
echo "     choose 'Hyprland'"
echo ""
echo "  3. Log back in. You'll have a minimal Hyprland session."
echo ""
echo "  4. Open a terminal (Super + Return) and run:"
echo ""
echo "       cd $SCRIPT_DIR"
echo "       ./install.sh"
echo ""
echo "     This applies all Zen Shell configs on top of the base"
echo "     Hyprland install you just bootstrapped."
echo ""
echo "  ── Your existing setup is safe ──"
if [ -n "$DM_RUNNING" ]; then
    echo "    $DM_RUNNING was NOT modified. $CURRENT_DE is still"
    echo "    selectable from the same login screen."
else
    echo "    No display manager was touched. Existing sessions are"
    echo "    still available."
fi
echo ""
echo "  ✅  Done. Logout + pick Hyprland at login, pre."
echo ""
exit 0
