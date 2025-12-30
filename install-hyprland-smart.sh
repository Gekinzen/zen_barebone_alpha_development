#!/usr/bin/env bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}🚀 Hyprland Control Center - Complete Installer${NC}"
echo "=========================================="
echo ""

# ---------- 1. Detect Arch ----------
if ! command -v pacman &>/dev/null; then
    echo -e "${RED}❌ Not an Arch-based system. Exiting.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Arch-based system detected${NC}"
echo ""

# ---------- 2. Base deps ----------
echo -e "${BLUE}📦 Installing base dependencies...${NC}"
sudo pacman -S --needed --noconfirm git base-devel

# ---------- 3. yay ----------
if ! command -v yay &>/dev/null; then
    echo -e "${BLUE}📦 Installing yay AUR helper...${NC}"
    cd ~
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
    cd ~
    rm -rf yay
else
    echo -e "${GREEN}✅ yay already installed${NC}"
fi

# ---------- 4. Detect Hyprland ----------
if command -v Hyprland &>/dev/null; then
    echo -e "${GREEN}✅ Hyprland already installed${NC}"
    HYPRLAND_INSTALLED=true
else
    echo -e "${YELLOW}⚠️ Hyprland NOT detected${NC}"
    HYPRLAND_INSTALLED=false
fi

# ---------- 5. Install Hyprland if missing ----------
if [[ "$HYPRLAND_INSTALLED" == false ]]; then
    echo ""
    echo -e "${BLUE}📦 Installing Hyprland compositor + XDG desktop stack...${NC}"
    yay -S --needed --noconfirm \
        hyprland \
        xdg-desktop-portal-hyprland \
        xdg-desktop-portal \
        polkit-kde-agent \
        qt5-wayland \
        qt6-wayland
fi

# ---------- 6. Core Desktop Packages ----------
echo ""
echo -e "${PURPLE}═══════════════════════════════════${NC}"
echo -e "${PURPLE}  CORE DESKTOP PACKAGES${NC}"
echo -e "${PURPLE}═══════════════════════════════════${NC}"

echo -e "${BLUE}📦 Installing wallpaper & theming...${NC}"
yay -S --needed --noconfirm \
    swww \
    hyprpaper \
    adw-gtk-theme \
    nwg-look

echo -e "${BLUE}📦 Installing panel & notifications...${NC}"
yay -S --needed --noconfirm \
    waybar \
    swaync

echo -e "${BLUE}📦 Installing launchers & menus...${NC}"
yay -S --needed --noconfirm \
    rofi \
    wofi

echo -e "${BLUE}📦 Installing terminal & shell...${NC}"
yay -S --needed --noconfirm \
    kitty \
    zsh \
    exa \
    bat \
    fzf

echo -e "${BLUE}📦 Installing fonts...${NC}"
yay -S --needed --noconfirm \
    ttf-jetbrains-mono-nerd \
    ttf-geist-mono-nerd \
    ttf-firacode-nerd \
    noto-fonts-emoji

echo -e "${BLUE}📦 Installing utilities...${NC}"
yay -S --needed --noconfirm \
    xdg-user-dirs \
    ristretto \
    file-roller \
    grim \
    slurp \
    wl-clipboard \
    cliphist

# ---------- 7. Control Center Dependencies ----------
echo ""
echo -e "${PURPLE}═══════════════════════════════════${NC}"
echo -e "${PURPLE}  CONTROL CENTER DEPENDENCIES${NC}"
echo -e "${PURPLE}═══════════════════════════════════${NC}"

echo -e "${BLUE}📦 Installing Python & GTK...${NC}"
sudo pacman -S --needed --noconfirm \
    python \
    python-pip \
    python-gobject \
    gtk4 \
    libadwaita

echo -e "${BLUE}📦 Installing Python packages...${NC}"
pip install --break-system-packages \
    pillow

echo -e "${BLUE}📦 Installing display management...${NC}"
yay -S --needed --noconfirm \
    nwg-displays \
    wlr-randr

echo -e "${BLUE}📦 Installing power management...${NC}"
yay -S --needed --noconfirm \
    power-profiles-daemon \
    brightnessctl

# ---------- 8. Optional Enhancements ----------
echo ""
echo -e "${PURPLE}═══════════════════════════════════${NC}"
echo -e "${PURPLE}  OPTIONAL ENHANCEMENTS${NC}"
echo -e "${PURPLE}═══════════════════════════════════${NC}"

read -rp "$(echo -e ${YELLOW}Install audio control? [Recommended] \(y/n\): ${NC})" INSTALL_AUDIO
if [[ "$INSTALL_AUDIO" =~ ^[Yy]$ ]]; then
    yay -S --needed --noconfirm \
        pipewire \
        wireplumber \
        pipewire-pulse \
        pipewire-alsa \
        pavucontrol
    echo -e "${GREEN}✅ Audio packages installed${NC}"
fi

read -rp "$(echo -e ${YELLOW}Install network management? [Recommended] \(y/n\): ${NC})" INSTALL_NETWORK
if [[ "$INSTALL_NETWORK" =~ ^[Yy]$ ]]; then
    yay -S --needed --noconfirm \
        networkmanager \
        nm-connection-editor \
        network-manager-applet
    sudo systemctl enable NetworkManager
    echo -e "${GREEN}✅ Network packages installed${NC}"
fi

read -rp "$(echo -e ${YELLOW}Install Bluetooth? \(y/n\): ${NC})" INSTALL_BLUETOOTH
if [[ "$INSTALL_BLUETOOTH" =~ ^[Yy]$ ]]; then
    yay -S --needed --noconfirm \
        bluez \
        bluez-utils \
        blueman
    sudo systemctl enable bluetooth
    echo -e "${GREEN}✅ Bluetooth packages installed${NC}"
fi

# ---------- 9. Barebone Core (Optional) ----------
echo ""
echo -e "${PURPLE}═══════════════════════════════════${NC}"
echo -e "${PURPLE}  BAREBONE CORE CONFIG${NC}"
echo -e "${PURPLE}═══════════════════════════════════${NC}"

echo -e "${YELLOW}⚠️  WARNING: CONFIG OVERWRITE${NC}"
echo "------------------------------------------"
echo "This will COPY ALL contents from:"
echo "  barebone_core/"
echo ""
echo "Including:"
echo "  ~/.config"
echo "  ~/.local"
echo "  ~/.oh-my-zsh"
echo "  ~/.p10k.zsh"
echo "  ~/.zshrc"
echo ""
echo -e "${RED}❗ Existing files WILL BE OVERWRITTEN${NC}"
echo ""

read -rp "$(echo -e ${YELLOW}Proceed with copying barebone_core? \(yes/no\): ${NC})" CONFIRM

if [[ "$CONFIRM" == "yes" ]]; then
    if [[ ! -d "$HOME/barebone_core" ]]; then
        echo -e "${BLUE}📦 Cloning barebone_core...${NC}"
        cd ~
        git clone https://github.com/Gekinzen/barebone_core.git
    fi
    
    echo -e "${BLUE}📂 Copying files to HOME...${NC}"
    cp -rf "$HOME/barebone_core/." "$HOME/"
    
    echo -e "${GREEN}✅ barebone_core applied${NC}"
else
    echo -e "${YELLOW}⏭️ Skipped barebone_core${NC}"
fi

# ---------- 10. Setup directories ----------
echo ""
echo -e "${BLUE}📁 Creating user directories...${NC}"
xdg-user-dirs-update
mkdir -p "$HOME/wallpapers"
mkdir -p "$HOME/Pictures/Screenshots"
mkdir -p "$HOME/.config/colorscheme"

# ---------- 11. Enable Services ----------
echo ""
echo -e "${BLUE}🔧 Configuring services...${NC}"

if command -v powerprofilesctl &>/dev/null; then
    sudo systemctl enable power-profiles-daemon
    echo -e "${GREEN}✅ Power profiles enabled${NC}"
fi

# ---------- 12. Summary ----------
echo ""
echo -e "${PURPLE}═══════════════════════════════════${NC}"
echo -e "${PURPLE}  INSTALLATION SUMMARY${NC}"
echo -e "${PURPLE}═══════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}✅ Core Hyprland system${NC}"
echo -e "${GREEN}✅ Desktop environment packages${NC}"
echo -e "${GREEN}✅ Control Center dependencies${NC}"
[[ "$INSTALL_AUDIO" =~ ^[Yy]$ ]] && echo -e "${GREEN}✅ Audio system${NC}"
[[ "$INSTALL_NETWORK" =~ ^[Yy]$ ]] && echo -e "${GREEN}✅ Network management${NC}"
[[ "$INSTALL_BLUETOOTH" =~ ^[Yy]$ ]] && echo -e "${GREEN}✅ Bluetooth${NC}"
[[ "$CONFIRM" == "yes" ]] && echo -e "${GREEN}✅ Barebone core configs${NC}"

echo ""
echo -e "${PURPLE}═══════════════════════════════════${NC}"
echo -e "${PURPLE}  NEXT STEPS${NC}"
echo -e "${PURPLE}═══════════════════════════════════${NC}"
echo ""
echo -e "${CYAN}1. Reboot your system${NC}"
echo -e "${CYAN}2. Select 'Hyprland' at login${NC}"
echo -e "${CYAN}3. Test monitors:${NC}"
echo "   hyprctl monitors"
echo ""
echo -e "${GREEN}🎉 Installation complete!${NC}"
echo ""
echo -e "${CYAN}Happy Hyprland-ing! 🚀${NC}"