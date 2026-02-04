#!/usr/bin/env bash
set -e

# ===============================
# Hyprland Control Center Installer
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

# ---------- Detect Distro ----------
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
else
    echo -e "${RED}❌ Cannot detect OS${NC}"
    exit 1
fi

DISTRO=""
PKG_INSTALL=""
AUR_INSTALL=""

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

# ---------- Base deps ----------
echo -e "${BLUE}📦 Installing base dependencies...${NC}"
if [[ "$DISTRO" == "arch" ]]; then
    $PKG_INSTALL git base-devel
else
    $PKG_INSTALL git curl
fi

# ---------- yay (Arch only) ----------
if [[ "$DISTRO" == "arch" ]]; then
    if ! command -v yay &>/dev/null; then
        echo -e "${BLUE}📦 Installing yay...${NC}"
        git clone https://aur.archlinux.org/yay.git /tmp/yay
        (cd /tmp/yay && makepkg -si --noconfirm)
        rm -rf /tmp/yay
    else
        echo -e "${GREEN}✅ yay already installed${NC}"
    fi
fi

# ---------- Hyprland ----------
if ! command -v Hyprland &>/dev/null; then
    echo -e "${BLUE}📦 Installing Hyprland...${NC}"
    if [[ "$DISTRO" == "arch" ]]; then
        yay -S --needed --noconfirm hyprland xdg-desktop-portal-hyprland
    else
        $PKG_INSTALL hyprland xdg-desktop-portal-hyprland
    fi
else
    echo -e "${GREEN}✅ Hyprland already installed${NC}"
fi

# ---------- Desktop packages (skip if headless) ----------
if [[ "$HEADLESS" == false ]]; then
    echo ""
    echo -e "${PURPLE}📦 Desktop packages${NC}"

    if [[ "$DISTRO" == "arch" ]]; then
        yay -S --needed --noconfirm \
            swww waybar swaync rofi wofi kitty \
            grim slurp wl-clipboard cliphist \
            nwg-look adw-gtk-theme \
            ttf-jetbrains-mono-nerd noto-fonts-emoji
    else
        $PKG_INSTALL \
            swww waybar swaync rofi kitty \
            grim slurp wl-clipboard \
            adw-gtk3-theme
    fi
else
    echo -e "${YELLOW}⚠️ Headless mode enabled — skipping UI packages${NC}"
fi

# ---------- Control Center deps ----------
echo ""
echo -e "${PURPLE}📦 Control Center dependencies${NC}"

if [[ "$DISTRO" == "arch" ]]; then
    $PKG_INSTALL python python-pip python-gobject gtk4 libadwaita
    pip install --break-system-packages pillow
else
    $PKG_INSTALL python3 python3-pip python3-gobject gtk4 libadwaita
    pip3 install pillow
fi

# ---------- User directories ----------
echo ""
echo -e "${BLUE}📁 Creating directories...${NC}"
mkdir -p "$HOME/wallpapers"
mkdir -p "$HOME/.config/hypr/scripts"
mkdir -p "$HOME/.config/systemd/user"

# ---------- Fix ~/.config ownership ----------
echo ""
echo -e "${BLUE}🛠️ Fixing ~/.config ownership...${NC}"
if [ "$(stat -c '%U' "$HOME/.config")" != "$USER" ]; then
    echo -e "${YELLOW}⚠️ ~/.config owned by $(stat -c '%U'), fixing...${NC}"
    sudo chown -R "$USER:$USER" "$HOME/.config"
else
    echo -e "${GREEN}✅ ~/.config ownership OK${NC}"
fi

ls -ld "$HOME/.config" \
       "$HOME/.config/systemd" \
       "$HOME/.config/systemd/user"

# ---------- Install wallpaper daemon ----------
echo ""
echo -e "${BLUE}🖼️ Installing wallpaper slideshow service...${NC}"

SERVICE_FILE="$HOME/.config/systemd/user/hypr-wallpaper-slideshow.service"

cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Hyprland Wallpaper Slideshow (swww)
After=graphical-session.target

[Service]
ExecStart=%h/.config/hypr/scripts/wallpaper-slideshow.sh
Restart=always
RestartSec=2

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable hypr-wallpaper-slideshow.service

echo -e "${GREEN}✅ User service installed${NC}"

# ---------- Summary ----------
echo ""
echo -e "${PURPLE}════════════════════════════════════${NC}"
echo -e "${PURPLE} INSTALLATION COMPLETE${NC}"
echo -e "${PURPLE}════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}✅ Distro supported: $NAME${NC}"
[[ "$HEADLESS" == true ]] && echo -e "${YELLOW}⚠️ Headless mode used${NC}"
echo -e "${CYAN}Next:${NC}"
echo "  • Reboot"
echo "  • Login to Hyprland"
echo "  • Run: hypr-control-center"
echo ""
echo -e "${GREEN}🎉 Done.${NC}"
