#!/usr/bin/env bash
set -e

# ===============================
# Hyprland Control Center Installer
# With Smart Config Backup
# ===============================

# ---------- Colors ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# ---------- Flags ----------
HEADLESS=false
for arg in "$@"; do
    case "$arg" in
        --headless) HEADLESS=true ;;
        -h|--help)
            echo "Usage: ./install.sh [--headless]"
            exit 0
            ;;
    esac
done

echo -e "${CYAN}🚀 Hyprland Control Center Installer${NC}"
echo "======================================"
echo ""

# ===============================
# Detect OS
# ===============================
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
else
    echo -e "${RED}❌ Cannot detect OS${NC}"
    exit 1
fi

case "$ID" in
    arch|endeavouros|cachyos)
        DISTRO="arch"
        PKG_INSTALL="sudo pacman -S --needed --noconfirm"
        ;;
    nobara|fedora)
        DISTRO="fedora"
        PKG_INSTALL="sudo dnf install -y"
        ;;
    *)
        echo -e "${RED}❌ Unsupported distro: $ID${NC}"
        exit 1
        ;;
esac

echo -e "${GREEN}✅ Detected distro: $NAME${NC}"
echo ""

# ===============================
# SMART CONFIG BACKUP
# ===============================
BACKUP_ROOT="$HOME/.config/zen-backups"
TIMESTAMP="$(date +'%Y-%m-%d_%H-%M-%S')"
BACKUP_DIR="$BACKUP_ROOT/backup_$TIMESTAMP"

CONFIG_TARGETS=(
    "hypr"
    "waybar"
    "kitty"
    "swaync"
    "rofi"
    "zen"
)

echo -e "${CYAN}🧠 Checking existing user configuration...${NC}"

FOUND_EXISTING=false
for cfg in "${CONFIG_TARGETS[@]}"; do
    [[ -d "$HOME/.config/$cfg" ]] && FOUND_EXISTING=true
done

if [[ "$FOUND_EXISTING" == true ]]; then
    echo -e "${YELLOW}⚠️ Existing config detected — creating backup${NC}"
    mkdir -p "$BACKUP_DIR"

    for cfg in "${CONFIG_TARGETS[@]}"; do
        if [[ -d "$HOME/.config/$cfg" ]]; then
            echo -e "  ${GREEN}✓${NC} Backing up $cfg"
            cp -a "$HOME/.config/$cfg" "$BACKUP_DIR/"
        fi
    done

    # Backup Waybar cache
    if [[ -d "$HOME/.cache/waybar" ]]; then
        mkdir -p "$BACKUP_DIR/.cache"
        cp -a "$HOME/.cache/waybar" "$BACKUP_DIR/.cache/"
    fi

    echo -e "${GREEN}✅ Backup saved to:${NC} $BACKUP_DIR"
    echo ""
else
    echo -e "${GREEN}✓ Fresh install detected (no backup needed)${NC}"
fi

# ===============================
# Base Dependencies
# ===============================
echo -e "${BLUE}📦 Installing base dependencies...${NC}"
if [[ "$DISTRO" == "arch" ]]; then
    $PKG_INSTALL git base-devel
else
    $PKG_INSTALL git curl
fi

# ===============================
# yay (Arch)
# ===============================
if [[ "$DISTRO" == "arch" ]] && ! command -v yay &>/dev/null; then
    echo -e "${BLUE}📦 Installing yay...${NC}"
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    (cd /tmp/yay && makepkg -si --noconfirm)
    rm -rf /tmp/yay
fi

# ===============================
# Hyprland
# ===============================
if ! command -v Hyprland &>/dev/null; then
    echo -e "${BLUE}📦 Installing Hyprland...${NC}"
    [[ "$DISTRO" == "arch" ]] && yay -S --needed --noconfirm hyprland xdg-desktop-portal-hyprland \
                             || $PKG_INSTALL hyprland xdg-desktop-portal-hyprland
else
    echo -e "${GREEN}✓ Hyprland already installed${NC}"
fi

# ===============================
# Desktop Packages
# ===============================
if [[ "$HEADLESS" == false ]]; then
    echo -e "${PURPLE}📦 Desktop packages${NC}"
    if [[ "$DISTRO" == "arch" ]]; then
        yay -S --needed --noconfirm \
            swww waybar swaync rofi wofi kitty \
            grim slurp wl-clipboard cliphist \
            nwg-look adw-gtk-theme \
            ttf-jetbrains-mono-nerd \
            ttf-geist-mono-nerd \
            noto-fonts-emoji
    else
        $PKG_INSTALL swww waybar swaync rofi kitty grim slurp wl-clipboard adw-gtk3-theme
    fi
else
    echo -e "${YELLOW}⚠️ Headless mode enabled — skipping UI packages${NC}"
fi

# ===============================
# Python / GTK / Control Center deps
# ===============================
echo -e "${PURPLE}📦 Control Center dependencies${NC}"
if [[ "$DISTRO" == "arch" ]]; then
    $PKG_INSTALL python python-pip python-gobject gtk4 libadwaita python-pytz
    pip install --break-system-packages pillow psutil
else
    $PKG_INSTALL python3 python3-pip python3-gobject gtk4 libadwaita
    pip3 install pillow psutil
fi

# ===============================
# User directories
# ===============================
echo -e "${BLUE}📁 Creating directories...${NC}"
mkdir -p \
    "$HOME/wallpapers" \
    "$HOME/.local/bin" \
    "$HOME/.config/hypr/scripts" \
    "$HOME/.config/systemd/user"

# ===============================
# Ownership fix
# ===============================
if [[ "$(stat -c '%U' "$HOME/.config")" != "$USER" ]]; then
    sudo chown -R "$USER:$USER" "$HOME/.config"
fi

# ===============================
# Wallpaper Slideshow Service
# ===============================
SERVICE="$HOME/.config/systemd/user/hypr-wallpaper-slideshow.service"

cat > "$SERVICE" <<EOF
[Unit]
Description=Hyprland Wallpaper Slideshow
After=graphical-session.target

[Service]
ExecStart=%h/.config/hypr/scripts/wallpaper-slideshow.sh
Restart=always

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable hypr-wallpaper-slideshow.service

# ===============================
# Summary
# ===============================
echo ""
echo -e "${PURPLE}════════════════════════════════════${NC}"
echo -e "${PURPLE} INSTALLATION COMPLETE${NC}"
echo -e "${PURPLE}════════════════════════════════════${NC}"
echo ""
[[ "$FOUND_EXISTING" == true ]] && echo -e "${CYAN}📦 Backup created:${NC} $BACKUP_DIR"
[[ "$HEADLESS" == true ]] && echo -e "${YELLOW}⚠️ Headless mode used${NC}"
echo ""
echo -e "${GREEN}🎉 Done.${NC}"
echo "Next:"
echo "  • Reboot"
echo "  • Login to Hyprland"
echo "  • Run your control center"
echo ""
