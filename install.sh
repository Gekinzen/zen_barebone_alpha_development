#!/usr/bin/env bash
set -e

# ==================================================
# Zen Barebone Installer (REPLACE MODE + ZSH FIX)
# ==================================================

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

# ==================================================
# Detect OS (Arch-based only)
# ==================================================
if [[ -f /etc/os-release ]]; then
  . /etc/os-release
else
  echo -e "${RED}❌ Cannot detect OS${NC}"
  exit 1
fi

case "$ID" in
  arch|endeavouros|cachyos) ;;
  *)
    echo -e "${RED}❌ Unsupported distro: $ID${NC}"
    exit 1
    ;;
esac

echo -e "${GREEN}✅ Detected distro: $NAME${NC}"
echo ""

# ==================================================
# SMART BACKUP (~/.config + waybar cache)
# ==================================================
BACKUP_ROOT="$HOME/.config/zen-backups"
TIMESTAMP="$(date +'%Y-%m-%d_%H-%M-%S')"
BACKUP_DIR="$BACKUP_ROOT/backup_$TIMESTAMP"

CONFIG_TARGETS=(hypr waybar kitty swaync rofi zen)

echo -e "${CYAN}🧠 Checking existing configs...${NC}"

FOUND=false
for cfg in "${CONFIG_TARGETS[@]}"; do
  [[ -d "$HOME/.config/$cfg" ]] && FOUND=true
done

if [[ "$FOUND" == true ]]; then
  echo -e "${YELLOW}⚠️ Existing configs found — backing up${NC}"
  mkdir -p "$BACKUP_DIR"

  for cfg in "${CONFIG_TARGETS[@]}"; do
    if [[ -d "$HOME/.config/$cfg" ]]; then
      echo -e "  ${GREEN}✓${NC} Backing up $cfg"
      cp -a "$HOME/.config/$cfg" "$BACKUP_DIR/"
    fi
  done

  if [[ -d "$HOME/.cache/waybar" ]]; then
    mkdir -p "$BACKUP_DIR/.cache"
    cp -a "$HOME/.cache/waybar" "$BACKUP_DIR/.cache/"
  fi

  echo -e "${GREEN}✅ Backup saved to:${NC} $BACKUP_DIR"
  echo ""
else
  echo -e "${GREEN}✓ No existing configs detected${NC}"
fi

# ==================================================
# Base Dependencies
# ==================================================
echo -e "${BLUE}📦 Installing base dependencies...${NC}"
sudo pacman -S --needed --noconfirm git base-devel curl rsync

# ==================================================
# yay
# ==================================================
if ! command -v yay &>/dev/null; then
  echo -e "${BLUE}📦 Installing yay...${NC}"
  git clone https://aur.archlinux.org/yay.git /tmp/yay
  (cd /tmp/yay && makepkg -si --noconfirm)
  rm -rf /tmp/yay
fi

# ==================================================
# ZSH SETUP (FIX: Failed to launch child: zsh)
# ==================================================
echo -e "${PURPLE}🐚 Setting up Zsh...${NC}"

if ! command -v zsh &>/dev/null; then
  sudo pacman -S --needed --noconfirm zsh
fi

if [[ ! -x /bin/zsh ]]; then
  echo -e "${RED}❌ /bin/zsh not found${NC}"
  exit 1
fi

if ! grep -q "^/bin/zsh$" /etc/shells; then
  echo "/bin/zsh" | sudo tee -a /etc/shells >/dev/null
fi

if [[ "$SHELL" != "/bin/zsh" ]]; then
  chsh -s /bin/zsh "$USER" || true
fi

echo -e "${GREEN}✅ Zsh ready${NC}"
echo ""

# ==================================================
# Desktop Packages (includes Thunar)
# ==================================================
echo -e "${PURPLE}📦 Installing desktop packages...${NC}"
yay -S --needed --noconfirm \
  hyprland xdg-desktop-portal-hyprland \
  swww waybar swaync rofi wofi kitty thunar \
  grim slurp wl-clipboard cliphist \
  nwg-look adw-gtk-theme \
  ttf-jetbrains-mono-nerd \
  ttf-geist-mono-nerd \
  noto-fonts-emoji

# ==================================================
# Python / GTK deps
# ==================================================
echo -e "${PURPLE}📦 Installing Python + GTK deps...${NC}"
sudo pacman -S --needed --noconfirm \
  python python-pip python-gobject gtk4 libadwaita python-pytz

pip install --break-system-packages pillow psutil

# ==================================================
# DEPLOY CONFIGS (REPLACE MODE)
# ==================================================
echo -e "${CYAN}📂 Applying configs from repo...${NC}"

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
CONFIG_SOURCE="$REPO_ROOT/.config"

if [[ ! -d "$CONFIG_SOURCE" ]]; then
  echo -e "${RED}❌ Repo .config folder not found${NC}"
  exit 1
fi

mkdir -p "$HOME/.config"

for dir in "$CONFIG_SOURCE"/*; do
  name="$(basename "$dir")"
  echo -e "${BLUE}→ Installing:${NC} $name"
  rsync -av --delete "$dir/" "$HOME/.config/$name/"
done

echo -e "${GREEN}✅ Configs applied successfully${NC}"
echo ""

# ==================================================
# Directories
# ==================================================
mkdir -p \
  "$HOME/wallpapers" \
  "$HOME/.local/bin" \
  "$HOME/.config/hypr/scripts" \
  "$HOME/.config/systemd/user"

# ==================================================
# Ownership Fix
# ==================================================
if [[ "$(stat -c '%U' "$HOME/.config")" != "$USER" ]]; then
  sudo chown -R "$USER:$USER" "$HOME/.config"
fi

# ==================================================
# DONE
# ==================================================
echo ""
echo -e "${PURPLE}════════════════════════════════════${NC}"
echo -e "${PURPLE} INSTALL COMPLETE${NC}"
echo -e "${PURPLE}════════════════════════════════════${NC}"
echo ""

[[ "$FOUND" == true ]] && echo -e "${CYAN}📦 Backup created at:${NC} $BACKUP_DIR"

echo -e "${GREEN}🎉 Zen Barebone successfully installed.${NC}"
echo ""
echo "Next steps:"
echo "  • Reboot (important for shell change)"
echo "  • Login to Hyprland"
echo ""
