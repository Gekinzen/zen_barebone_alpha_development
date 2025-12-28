#!/usr/bin/env bash
set -e

echo "🚀 Hyprland Smart Installer (Consent-Based)"
echo "=========================================="

# ---------- 1. Detect Arch ----------
if ! command -v pacman &>/dev/null; then
  echo "❌ Not an Arch-based system. Exiting."
  exit 1
fi
echo "✅ Arch-based system detected"

# ---------- 2. Base deps ----------
sudo pacman -S --needed --noconfirm git base-devel

# ---------- 3. yay ----------
if ! command -v yay &>/dev/null; then
  echo "📦 Installing yay..."
  cd ~
  git clone https://aur.archlinux.org/yay.git
  cd yay
  makepkg -si --noconfirm
  cd ~
else
  echo "✅ yay already installed"
fi

# ---------- 4. Detect Hyprland ----------
if command -v Hyprland &>/dev/null; then
  echo "✅ Hyprland already installed"
  HYPRLAND_INSTALLED=true
else
  echo "⚠️ Hyprland NOT detected"
  HYPRLAND_INSTALLED=false
fi

# ---------- 5. Install Hyprland if missing ----------
if [[ "$HYPRLAND_INSTALLED" == false ]]; then
  echo "📦 Installing Hyprland compositor + xdg desktop stack..."
  yay -S --needed --noconfirm \
    hyprland \
    xdg-desktop-portal-hyprland \
    xdg-desktop-portal \
    polkit-kde-agent \
    qt5-wayland \
    qt6-wayland
fi

# ---------- 6. Install YOUR packages ----------
echo "📦 Installing user packages..."
yay -S --needed --noconfirm \
  swww \
  hyprpaper \
  waybar \
  rofi \
  swaync \
  kitty \
  nwg-look \
  ristretto \
  xdg-user-dirs \
  exa \
  zsh \
  ttf-jetbrains-mono-nerd \
  ttf-geist-mono-nerd \
  adw-gtk-theme

# ---------- 7. STOP & WARNING ----------
echo ""
echo "⚠️  WARNING: CONFIG OVERWRITE"
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
echo "❗ Existing files WILL BE OVERWRITTEN"
echo ""

read -rp "Proceed with copying barebone_core? (yes/no): " CONFIRM

# ---------- 8. Copy barebone_core ----------
if [[ "$CONFIRM" == "yes" ]]; then
  if [[ ! -d "$HOME/barebone_core" ]]; then
    echo "📦 Cloning barebone_core..."
    git clone https://github.com/Gekinzen/barebone_core.git
  fi

  echo "📂 Copying files to HOME..."
  cp -rf barebone_core/. "$HOME/"

  echo "✅ barebone_core applied"
else
  echo "⏭️ Skipped barebone_core"
fi

echo ""
echo "🎉 Done."
echo "➡️ Reboot, login to Hyprland, then run:"
echo "   hyprctl monitors"
