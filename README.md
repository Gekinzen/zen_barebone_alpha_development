<p align="center">
  <img src="assets/preview.png" alt="Zen Barebone Desktop Preview" width="800"/>
</p>

<h1 align="center">Zen Barebone Alpha</h1>

<p align="center">
  <b>A clean, performant Hyprland desktop environment with unified theming and custom GUI tools</b>
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#installation">Installation</a> •
  <a href="#components">Components</a> •
  <a href="#theming">Theming</a> •
  <a href="#presets">Presets</a> •
  <a href="#contributing">Contributing</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Arch-Linux-1793D1?logo=arch-linux&logoColor=white" alt="Arch Linux"/>
  <img src="https://img.shields.io/badge/Hyprland-Wayland-58E1FF?logo=wayland&logoColor=white" alt="Hyprland"/>
  <img src="https://img.shields.io/badge/GTK4-Libadwaita-4A86CF?logo=gtk&logoColor=white" alt="GTK4"/>
  <img src="https://img.shields.io/badge/License-MIT-green.svg" alt="License"/>
</p>

---

## Overview

This is my personal Hyprland/Arch Linux dotfiles setup that I've been developing since December 2024. What started as a way to streamline my daily workflow for work and gaming has evolved into a comprehensive desktop environment with custom-built GUI tools, unified theming, and sane defaults.

The focus is on **clean UI**, **performance**, and **making things work out of the box**. No bloat, no unnecessary complexity—just what I need for productive work and comfortable gaming.

---

## Features

### 🎛️ Hyprland Control Center
A custom GTK4/Libadwaita settings application for managing your Hyprland desktop.

| Module | Description |
|--------|-------------|
| **Appearance** | General look and feel, gaps, borders, rounding |
| **Panel** | Waybar configuration with module management |
| **Theme Switcher** | Global theming for Waybar, Rofi, Kitty, and widgets |
| **Workspaces** | Workspace behavior, persistent workspaces, icons |
| **Animations** | Bezier curves, window animations, workspace transitions |
| **Input Devices** | Keyboard, mouse, touchpad settings |
| **Displays** | Monitor configuration, scaling, rotation |
| **Keybinds** | Keyboard shortcuts management |

### 🎨 Unified Theming System
One-click theme switching across all applications:
- **Waybar** - Custom color variables and styling
- **Rofi** - Matching launcher theme
- **Kitty** - Terminal colors
- **Desktop Widgets** - Clock, weather, system monitor
- **Control Center** - GTK4 app styling

### 🖥️ Desktop Widgets
GTK4 Layer Shell widgets that live on your desktop (behind all windows):
- **Clock Widget** - Customizable time/date with timezone support (dual clock capable)
- **Weather Widget** - Current conditions and 7-day forecast with auto-location detection
- **System Monitor** - CPU, GPU, RAM, and network stats with live graphs

### 📊 ZenPyBar (Optional)
Custom Python-based status bar/taskbar system:
- Embedded taskbar with window tracking
- Multi-monitor support
- Pin/unpin applications
- Shared window tracker (no duplicates)

### 🚀 Performance Focused
- Lazy loading for faster startup
- Efficient memory management
- Optimized animations
- Minimal resource footprint

---

## Installation

### Prerequisites

```bash
# Base packages
sudo pacman -S hyprland waybar rofi kitty swaync

# GTK4/Libadwaita development
sudo pacman -S gtk4 libadwaita python-gobject gtk4-layer-shell

# Utilities
sudo pacman -S jq playerctl pamixer brightnessctl

# Fonts (pick your preferred Nerd Font)
yay -S ttf-jetbrains-mono-nerd
```

### Quick Install

```bash
# Clone the repository
git clone https://github.com/Gekinzen/zen_barebone_alpha_development.git ~/Dotfiles

# Run the installer
cd ~/Dotfiles/zen_barebone_alpha_development
./install.sh
```

### Manual Installation

```bash
# Copy configurations
cp -r hypr ~/.config/
cp -r waybar ~/.config/
cp -r rofi ~/.config/
cp -r kitty ~/.config/

# Install Control Center
cp -r hyprland-control-center ~/.config/hypr-control-center

# Set up widgets
mkdir -p ~/.config/hypr-control-center/widgets
cp widgets/* ~/.config/hypr-control-center/widgets/
```

---

## Components

### Directory Structure

```
zen_barebone_alpha_development/
├── hypr/
│   ├── hyprland.conf           # Main config (sources modules)
│   ├── modules/
│   │   ├── animations.conf     # Animation settings
│   │   ├── keybinds.conf       # Keyboard shortcuts
│   │   ├── windowrules.conf    # Window rules
│   │   └── look_and_feel.conf  # Appearance settings
│   ├── scripts/
│   │   ├── start-widgets.sh    # Desktop widget launcher
│   │   └── ...
│   └── colorscheme/            # Generated theme files
├── waybar/
│   ├── config.jsonc            # Waybar configuration
│   ├── style.css               # Main stylesheet
│   └── colors/                 # Theme color files
├── rofi/
│   ├── config.rasi
│   └── shared/colors.rasi      # Theme colors
├── kitty/
│   ├── kitty.conf
│   └── theme.conf              # Theme colors
├── hyprland-control-center/
│   ├── main.py                 # Entry point
│   ├── src/
│   │   ├── pages/              # Settings pages
│   │   ├── theme_manager.py    # Theming engine
│   │   └── ...
│   └── widgets/                # Desktop widgets
└── assets/
    └── icons/                  # Custom icons
```

### Key Configuration Files

| File | Purpose |
|------|---------|
| `hypr/hyprland.conf` | Main Hyprland configuration |
| `waybar/config.jsonc` | Status bar modules and layout |
| `~/.config/hypr-control-center/preferences/` | Control Center settings (JSON) |
| `~/.config/hypr-control-center/theme.json` | Active theme configuration |

---

## Theming

### Built-in Themes

| Theme | Description | Accent |
|-------|-------------|--------|
| **One Dark** | Atom's iconic dark theme | Blue |
| **Gruvbox Dark** | Retro groove colors | Yellow |
| **Nord** | Arctic, north-bluish palette | Frost Blue |
| **Tokyo Night Storm** | Futuristic Tokyo aesthetic | Purple |
| **Catppuccin Mocha** | Pastel dark theme | Mauve |
| **Everforest Dark** | Nature-inspired greens | Green |
| **macOS Dark Blue** | Apple-inspired design | Blue |

### Creating Custom Themes

1. Open Control Center → **Theme Switcher**
2. Select a base theme
3. Customize colors, fonts, and styling
4. Click **Save As Custom**
5. Give your theme a name

### Export & Share Presets

Your custom themes can be exported as JSON files and shared with others:

```bash
# Themes are stored in:
~/.config/hypr-control-center/themes/custom/

# Export format: my-theme.json
{
  "schema_version": "1.0",
  "theme": {
    "id": "my-custom-theme",
    "name": "My Custom Theme",
    "colors": { ... },
    "waybar": { ... },
    "rofi": { ... },
    "kitty": { ... }
  }
}
```

### Importing Themes

1. Download a `.json` theme file
2. Open Control Center → **Theme Switcher**
3. Click **Import**
4. Select the file
5. Theme is now available in your profile list

---

## Presets

The theming system supports **dynamic preset sharing**. All components (Waybar, Rofi, Kitty, widgets) sync automatically when you switch themes.

### How It Works

```
User selects theme
    ↓
Control Center applies colors to:
    ├── ~/.config/hypr/colorscheme/{theme}.css     (Waybar)
    ├── ~/.config/rofi/shared/colors.rasi          (Rofi)
    ├── ~/.config/kitty/theme.conf                 (Terminal)
    └── Widget CSS variables                       (Desktop Widgets)
    ↓
Applications reload automatically
    ↓
Everything themed! ✨
```

### Signal-Based Sync

Components listen for theme change signals:
- **Waybar**: `pkill -SIGUSR2 waybar` or auto-restart
- **Kitty**: `pkill -USR1 kitty`
- **Widgets**: SIGUSR1/SIGUSR2 handlers for live updates

---

## Usage

### Starting the Control Center

```bash
# Run from anywhere
python3 ~/.config/hypr-control-center/main.py

# Or add to your keybinds (hypr/modules/keybinds.conf)
bind = $mainMod, I, exec, python3 ~/.config/hypr-control-center/main.py
```

### Starting Desktop Widgets

```bash
# Start all enabled widgets
~/.config/hypr/scripts/start-widgets.sh

# Individual widgets
~/.config/hypr/scripts/start-widgets.sh clock
~/.config/hypr/scripts/start-widgets.sh weather
~/.config/hypr/scripts/start-widgets.sh sysmon

# Restart widgets
~/.config/hypr/scripts/start-widgets.sh restart
```

### Widget Positioning

Widgets are draggable! Just click and drag to reposition. Positions are saved to:
```
~/.config/hypr-control-center/preferences/widgets.json
```

---

## Screenshots

<details>
<summary>Click to expand screenshots</summary>

### Control Center
![Control Center](assets/screenshots/control-center.png)

### Theme Switcher
![Theme Switcher](assets/screenshots/themes.png)

### Desktop Widgets
![Widgets](assets/screenshots/widgets.png)

### Waybar Styles
![Waybar](assets/screenshots/waybar.png)

</details>

---

## Roadmap

- [x] Core Control Center with settings pages
- [x] Unified theming system
- [x] Desktop widgets (clock, weather, system monitor)
- [x] Theme export/import
- [ ] More built-in themes
- [ ] Plugin system for custom modules
- [ ] Wallpaper manager integration
- [ ] Per-workspace theming

---

## Contributing

Contributions are welcome! Feel free to:
- Report bugs
- Suggest features
- Submit pull requests
- Share your custom themes

---

## Support

If this project helped your setup, workflow, or saved you a few hours of debugging, you can support its continued development:

<p align="center">
  <a href="https://buymeacoffee.com/zenpy">
    <img src="https://img.buymeacoffee.com/button-api/?text=Buy me a coffee&emoji=☕&slug=zenpy&button_colour=BD5FFF&font_colour=ffffff&font_family=Poppins&outline_colour=000000&coffee_colour=FFDD00" alt="Buy Me A Coffee"/>
  </a>
</p>

---

## Credits

- **[Hyprland](https://hyprland.org/)** - The amazing Wayland compositor
- **[GTK4](https://gtk.org/)** / **[Libadwaita](https://gnome.pages.gitlab.gnome.org/libadwaita/)** - UI toolkit
- **[Waybar](https://github.com/Alexays/Waybar)** - Status bar
- **[Rofi](https://github.com/davatorium/rofi)** - Application launcher
- The Linux ricing community for inspiration

---

## License

MIT License - Feel free to use, modify, and share.

---

<p align="center">
  Made with ❤️ by <a href="https://github.com/Gekinzen">Zenpy</a>
</p>
