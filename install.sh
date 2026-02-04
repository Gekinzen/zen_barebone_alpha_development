#!/usr/bin/env bash
set -e

# ===============================
# Zen Barebone Installer
# ===============================

# ---------- Colors ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}🚀 Zen Barebone Installer${NC}"
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

echo -e "${CYAN}🧠 Checking existing ~/.config...${NC}"

FOUND_EXISTING=false
for cfg in "${CONFIG_TARGETS[@]}"; do
    [[ -d "$HOME/.config/$cfg" ]] && FOUND_EXISTING=true
done

if [[ "$FOUND_EXISTING" == true ]]; then
    echo -e "${YELLOW}⚠️ Existing configs detected — backing up${NC}"
    mkdir -p "$BACKUP_DIR"

    for cfg in "${CONFIG_TARGETS[@]}"; do
        if [[ -d "$HOME/.config/$cfg" ]]; then
            echo -e "  ${GREEN}✓${NC} Backing up $cfg"
            cp -a "$HOME/.config/$cfg" "$BACKUP_DIR/"
        fi
    done

    # Waybar cache
    if [[ -d "$HOME/.cache/waybar" ]]; then
        mkdir -p "$BACKUP_DIR/.cache"
        cp -a "$HOME/.cache/waybar" "$BACKUP_DIR/.cache/"
    fi

    echo -e "${GREEN}✅ Backup stored at:${NC} $BACKUP_DIR"
    echo ""
else
    echo -e "${GREEN}✓ Fresh install detected${NC}"
fi

# ===============================
# Base Dependencies
# ===============================
echo -e "${BLUE}📦 Installing base packages...${NC}"
$PKG_INSTALL git base-devel curl rsync

# ===============================
# yay
# ===============================
if ! command -v yay &>/dev/null; then
    echo -e "${BLUE}📦 Installing yay...${NC}"
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    (cd /tmp/yay && makepkg -si --noconfirm)
    rm -rf /tmp/yay
fi

# ===============================
# Desktop Packages (FIXED: Thunar added)
# ===============================
echo -e "${PURPLE}📦 Installing desktop packages...${NC}"
yay -S --needed --noconfirm \
    hyprland xdg-desktop-portal-hyprland \
    swww waybar swaync rofi wofi kitty thunar \
    grim slurp wl-clipboard cliphist \
    nwg-look adw-gtk-theme \
    ttf-jetbrains-mono-nerd \
    ttf-geist-mono-nerd \
    noto-fonts-emoji

# ===============================
# Python / GTK deps
# ===============================
echo -e "${PURPLE}📦 Installing Python + GTK deps...${NC}"
$PKG_INSTALL python python-pip python-gobject gtk4 libadwaita python-pytz
pip install --break-system-packages pillow psutil

# ===============================
# DEPLOY CONFIGS FROM REPO
# ===============================
echo -e "${CYAN}📂 Deploying .config from repo...${NC}"

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
CONFIG_SOURCE="$REPO_ROOT/.config"

if [[ ! -d "$CONFIG_SOURCE" ]]; then
    echo -e "${RED}❌ Repo .config folder not found${NC}"
    exit 1
fi

mkdir -p "$HOME/.config"

for dir in "$CONFIG_SOURCE"/*; do
    name="$(basename "$dir")"

    echo -e "${BLUE}→ Installing config:${NC} $name"

    rsync -av \
        --ignore-existing \
        "$dir/" "$HOME/.config/$name/"
done

echo -e "${GREEN}✅ Config deployment done${NC}"
echo ""

# ===============================
# Directories
# ===============================
mkdir -p \
    "$HOME/wallpapers" \
    "$HOME/.local/bin" \
    "$HOME/.config/hypr/scripts" \
    "$HOME/.config/systemd/user"

# ===============================
# Ownership Fix
# ===============================
if [[ "$(stat -c '%U' "$HOME/.config")" != "$USER" ]]; then
    sudo chown -R "$USER:$USER" "$HOME/.config"
fi

# ===============================
# Done
# ===============================
echo ""
echo -e "${PURPLE}════════════════════════════════════${NC}"
echo -e "${PURPLE} INSTALL COMPLETE${NC}"
echo -e "${PURPLE}════════════════════════════════════${NC}"
echo ""

[[ "$FOUND_EXISTING" == true ]] && echo -e "${CYAN}📦 Backup:${NC} $BACKUP_DIR"

echo -e "${GREEN}🎉 Zen Barebone ready.${NC}"
echo "Next:"
echo "  • Reboot"
echo "  • Login to Hyprland"
echo ""
