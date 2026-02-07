<p align="center">
  <img src="assets/preview.png" alt="Zen Barebone Desktop Preview" width="900"/>
</p>

<h1 align="center">Zen Barebone Alpha</h1>

<p align="center">
  <b>A performance-focused, fully themed Hyprland desktop ecosystem for Arch Linux</b><br/>
  <i>Control everything. Theme everything. Break nothing.</i>
</p>

<p align="center">
  <a href="#overview">Overview</a> •
  <a href="#features">Features</a> •
  <a href="#installation">Installation</a> •
  <a href="#architecture">Architecture</a> •
  <a href="#theming">Theming</a> •
  <a href="#roadmap">Roadmap</a> •
  <a href="#contributing">Contributing</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Arch-Linux-1793D1?logo=arch-linux&logoColor=white"/>
  <img src="https://img.shields.io/badge/Hyprland-Wayland-58E1FF?logo=wayland&logoColor=white"/>
  <img src="https://img.shields.io/badge/GTK4-Libadwaita-4A86CF?logo=gtk&logoColor=white"/>
  <img src="https://img.shields.io/badge/Status-Alpha-orange"/>
  <img src="https://img.shields.io/badge/License-MIT-green"/>
</p>

---

# 🚀 Overview

Zen Barebone Alpha is not just a Hyprland configuration.

It is a structured, modular desktop ecosystem built around three principles:

- ⚡ Performance-first configuration  
- 🎨 Unified cross-application theming  
- 🧩 GUI-driven customization without sacrificing power  

What started as a personal workflow optimization evolved into a complete GTK4-powered Control Center, dynamic theme engine, desktop widget system, custom dock module, and plugin manager — all tightly integrated with Hyprland.

No config chaos.  
No theme mismatch.  
No unnecessary complexity.

Switch once. Everything updates.

---

# 🖥 Target Audience

Ideal for:

- Arch Linux users running Hyprland  
- Developers who want a clean but powerful setup  
- Users who prefer GUI control without losing config-level flexibility  
- Anyone who wants synchronized theming across their entire desktop  

---

# ✨ Features

## 🎛 Hyprland Control Center

GTK4 / Libadwaita application providing centralized desktop management.

Includes:

- Appearance controls (gaps, borders, rounding, shadows)
- Waybar module manager
- Unified Theme Engine
- Wallpaper manager (SWWW integration)
- Workspace configuration
- Plugin manager (Hyprpm integration)
- Animation editor (Bezier curves)
- Input device configuration
- Display management
- Keybind editor
- Desktop Widgets manager
- Custom Dock configuration

---

## 🚀 Custom Dock Module

Fully integrated dock built specifically for Zen Barebone.

- Dynamic app launching
- Pinned applications
- Active window indicators
- Smooth hover animations
- Theme engine integration
- Layout and position customization
- Lightweight and optimized for Hyprland

Designed to complement Waybar — not replace it.

---

## 🎨 Unified Theming System (13+ Themes)

One-click synchronization across:

- Waybar  
- Rofi  
- Kitty  
- Start Menu  
- Hyprbars  
- SwayNC  
- Desktop Widgets  
- Dock  
- Control Center  

Included themes:

One Dark • Gruvbox • Nord • Tokyo Night • Catppuccin • Everforest • Dracula • Solarized • Cyberpunk • Arc • Adapta • Paper • Yousai

All components update automatically on theme switch.

---

## 🖥 Desktop Widgets

GTK4 Layer Shell widgets positioned behind windows:

- Clock (dual timezone support)
- Weather (7-day forecast)
- System Monitor (CPU, GPU, RAM, Network)

Features:

- Drag-and-drop positioning
- Automatic position saving
- Fully synchronized theming

---

## 🎮 Start Menu

Modern launcher with:

- Fast open time
- Grid and compact modes
- Real-time search
- Integrated power controls
- Theme synchronization

---

## 🔌 Plugin Management

Native Hyprpm integration:

- Hyprbars
- Hyprspace
- One-click enable/disable
- GUI plugin control

---

# ⚡ Installation

Zen Barebone provides an automated installer.

---

## 🔹 1. Clone Repository

```bash
git clone https://github.com/Gekinzen/zen_barebone_alpha_development.git ~/Dotfiles
cd ~/Dotfiles/zen_barebone_alpha_development
```

---

## 🔹 2. Make Installer Executable

```bash
chmod +x install.sh
```

---

## 🔹 3. Run Installer

```bash
./install.sh
```

The installer will:

- Copy configuration files into `~/.config`
- Install Control Center
- Configure widgets
- Install Dock module
- Configure theme engine
- Apply required permissions

---

## 🛑 Important

Recommended for fresh Hyprland setups.

If you have existing configs, back them up:

```bash
mv ~/.config/hypr ~/.config/hypr.backup
mv ~/.config/waybar ~/.config/waybar.backup
mv ~/.config/rofi ~/.config/rofi.backup
```

After installation:

Log out and log back into Hyprland.

---

# 🧰 Manual Installation (Advanced)

```bash
cp -r hypr ~/.config/
cp -r waybar ~/.config/
cp -r rofi ~/.config/
cp -r kitty ~/.config/
cp -r dock ~/.config/
cp -r hyprland-control-center ~/.config/
```

Launch Control Center:

```bash
python3 ~/.config/hyprland-control-center/main.py
```

---

# 🖥 First Launch

Start widgets:

```bash
~/.config/hypr/scripts/start-widgets.sh
```

Open Control Center:

```bash
python3 ~/.config/hyprland-control-center/main.py
```

Switch themes and enjoy full synchronization.

---

# 🏗 Architecture

Zen Barebone follows a modular design:

- Hyprland sources separated modules
- Theme engine generates synchronized config files
- Applications listen for reload signals
- Widgets use GTK4 Layer Shell
- Preferences stored in structured JSON
- Dock dynamically adapts to theme engine

Theme flow:

```
User selects theme
↓
Theme engine generates configs
↓
Waybar / Rofi / Kitty / Dock / Widgets reload
↓
Entire desktop updates instantly
```

---

# 🎨 Theming

Custom themes stored at:

```
~/.config/hypr-control-center/themes/custom/
```

Themes are portable JSON files.

Import via Control Center → Theme Switcher → Import.

---

# 🛣 Roadmap

Planned:

- Per-workspace theming
- Additional widget types
- Dock enhancements
- Expanded plugin integrations

---

# 🤝 Contributing

You can help by:

- Reporting bugs
- Suggesting features
- Submitting pull requests
- Sharing custom themes
- Improving documentation

---

# ⭐ If You Like This Project

Consider starring the repository to support development and help others discover it.

---

# ☕ Support

If Zen Barebone improved your workflow:

https://buymeacoffee.com/zenpy

---

# 📜 License

MIT License

---

<p align="center">
Made with ❤️ by <a href="https://github.com/Gekinzen">Zenpy</a>
</p>
