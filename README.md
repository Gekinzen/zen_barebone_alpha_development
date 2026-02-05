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

## 📺 Video Showcase

<p align="center">
  <a href="https://www.youtube.com/watch?v=QR6xMcTzfYA">
    <img src="https://img.shields.io/badge/YouTube-Watch_Full_Demo-FF0000?logo=youtube&logoColor=white&style=for-the-badge" alt="YouTube Demo"/>
  </a>
</p>

<p align="center">
  <i>Watch the complete walkthrough, installation guide, and feature showcase!</i>
</p>

---

## ⚠️ Important Notice

> **🚧 CURRENTLY IN ALPHA DEVELOPMENT**
> 
> This project is actively being developed and refined. While the core functionality is stable and usable, you may encounter occasional bugs, breaking changes between updates, or features that are still being polished. Your feedback and patience are greatly appreciated!

### 💬 Community & Support

Found an issue? Have questions? Want to share your setup?

<p align="center">
  <a href="https://github.com/Gekinzen/zen_barebone_alpha_development/issues">
    <img src="https://img.shields.io/badge/GitHub-Report_Issue-181717?logo=github&style=for-the-badge" alt="GitHub Issues"/>
  </a>
  <a href="https://discord.gg/7v7zfyr2">
    <img src="https://img.shields.io/badge/Discord-Join_Community-5865F2?logo=discord&logoColor=white&style=for-the-badge" alt="Discord"/>
  </a>
</p>

- **🐛 Bug Reports**: [Open an issue on GitHub](https://github.com/Gekinzen/zen_barebone_alpha_development/issues)
- **💡 Feature Requests**: Share your ideas in Issues or Discord
- **🤝 General Help**: Join our Discord server for real-time support
- **📸 Showcase**: Post your customized setups in the Discord community!

### 🎨 Share Your Creativity!

One of the best features of Zen Barebone is the ability to create and share custom themes:

✨ **Create unique themes** using the built-in Theme Switcher  
📤 **Export your designs** as portable JSON files (one click!)  
🤝 **Share with friends** or the wider community  
🎭 **Show off your style** by posting screenshots on Discord  
🔄 **Contribute back** by submitting your themes via pull requests  

> 💡 **Pro Tip**: Custom theme presets are fully portable and easy to distribute. They're the perfect way to showcase your personal aesthetic or help others discover eye-catching configurations. Every export includes all color schemes, fonts, and styling—ready to import and use instantly!

---

## Overview

Zen Barebone Alpha is my personal Hyprland/Arch Linux desktop environment that I've been crafting since December 2024. What began as a simple workflow optimization for work and gaming has evolved into a comprehensive desktop ecosystem featuring custom-built GUI applications, unified theming architecture, and carefully tuned defaults.

The philosophy centers on three core principles: **clean aesthetics**, **optimal performance**, and **plug-and-play functionality**. No unnecessary bloat, no overwhelming complexity—just a polished, efficient environment for productive work and immersive gaming.

---

## Features

### 🎛️ Hyprland Control Center
A sophisticated GTK4/Libadwaita settings application providing centralized management of your Hyprland desktop environment.

| Module | Description |
|--------|-------------|
| **Appearance** | Visual customization: gaps, borders, rounding, shadows |
| **Panel** | Waybar module manager with intuitive drag-and-drop configuration |
| **Theming** | Unified theme engine for Waybar, Rofi, Kitty, SwayNC, Hyprbars |
| **Wallpaper** | SWWW integration with slideshow automation, pagination, folder browser |
| **Workspaces** | Workspace behavior settings, persistent workspace configuration, custom icons |
| **Widgets** | Desktop widget management (clock, weather, system monitor) |
| **Plugins** | Hyprpm plugin manager (Hyprbars, Hyprspace, and more) |
| **Animations** | Bezier curve editor, window animation controls, workspace transitions |
| **Input Devices** | Keyboard, mouse, and touchpad configuration |
| **Displays** | Monitor setup, scaling, rotation, positioning |
| **Keybinds** | Comprehensive keyboard shortcut management |

### 🎨 Unified Theming System (13+ Themes)
Seamless one-click theme switching across your entire desktop environment:
- **Waybar** - Statusbar with custom color variables and detailed styling
- **Rofi** - Application launcher with matching color definitions
- **Kitty** - Terminal emulator with complete 16-color palettes
- **Start Menu** - Windows 11-inspired launcher with full theme integration
- **Hyprbars** - Window titlebar decoration colors
- **SwayNC** - Notification center styling
- **Desktop Widgets** - Clock, weather, and system monitor theming
- **Control Center** - Self-theming GTK4 application interface

### 🖥️ Desktop Widgets
Beautiful GTK4 Layer Shell widgets that integrate seamlessly with your desktop (positioned behind all windows):
- **Clock Widget** - Customizable time/date display with dual timezone support
- **Weather Widget** - Real-time conditions and 7-day forecast with automatic location detection
- **System Monitor** - Live CPU, GPU, RAM, and network statistics with animated graphs
- **Draggable Interface** - Click and drag to reposition anywhere, positions automatically saved

### 🎮 Start Menu
Modern Windows 11-style application launcher with performance optimization:
- **Daemon-based Preload** - Instant response times under 100ms
- **Dual View Modes** - Toggle between grid tiles and compact list layouts
- **Fast Search** - Real-time application filtering and search
- **Theme Synchronized** - Automatically matches your global color scheme
- **Integrated Power Menu** - Quick access to shutdown, restart, and logout

### 🔌 Plugin Management
Native Hyprpm integration for enhanced Hyprland functionality:
- **Hyprbars** - Customizable window titlebars with theme support
- **Hyprspace** - Workspace overview (accessible via MOD+TAB)
- **One-Click Control** - Enable/disable plugins directly from Control Center

---

## Installation

### Prerequisites
```bash
# Core desktop environment packages
sudo pacman -S hyprland waybar rofi kitty swaync

# GTK4/Libadwaita development libraries
sudo pacman -S gtk4 libadwaita python-gobject gtk4-layer-shell

# Essential utilities
sudo pacman -S jq playerctl pamixer brightnessctl

# Fonts (choose your preferred Nerd Font variant)
yay -S ttf-jetbrains-mono-nerd
```

### Quick Install (Recommended)
```bash
# Clone the repository to your home directory
git clone https://github.com/Gekinzen/zen_barebone_alpha_development.git ~/Dotfiles

# Navigate to the project directory
cd ~/Dotfiles/zen_barebone_alpha_development

# Run the automated installer
./install.sh
```

### Manual Installation
```bash
# Copy configuration files to their respective locations
cp -r hypr ~/.config/
cp -r waybar ~/.config/
cp -r rofi ~/.config/
cp -r kitty ~/.config/

# Install the Hyprland Control Center
cp -r hyprland-control-center ~/.config/hypr-control-center

# Set up desktop widgets
mkdir -p ~/.config/hypr-control-center/widgets
cp widgets/* ~/.config/hypr-control-center/widgets/
```

---

## Components

### Directory Structure
```
zen_barebone_alpha_development/
├── hypr/
│   ├── hyprland.conf           # Main configuration file (sources modules)
│   ├── modules/
│   │   ├── animations.conf     # Animation settings and bezier curves
│   │   ├── keybinds.conf       # Keyboard shortcuts and bindings
│   │   ├── windowrules.conf    # Window-specific rules and behaviors
│   │   └── look_and_feel.conf  # Visual appearance settings
│   ├── scripts/
│   │   ├── start-widgets.sh    # Desktop widget launcher script
│   │   └── ...
│   └── colorscheme/            # Generated theme color files
├── waybar/
│   ├── config.jsonc            # Waybar module configuration
│   ├── style.css               # Main stylesheet
│   └── colors/                 # Theme-specific color definitions
├── rofi/
│   ├── config.rasi
│   └── shared/colors.rasi      # Theme color variables
├── kitty/
│   ├── kitty.conf
│   └── theme.conf              # Terminal color scheme
├── hyprland-control-center/
│   ├── main.py                 # Application entry point
│   ├── src/
│   │   ├── pages/              # Settings page modules
│   │   ├── theme_manager.py    # Theme engine and synchronization
│   │   └── ...
│   └── widgets/                # Desktop widget implementations
└── assets/
    └── icons/                  # Custom iconography
```

### Key Configuration Files

| File | Purpose |
|------|---------|
| `hypr/hyprland.conf` | Main Hyprland compositor configuration |
| `waybar/config.jsonc` | Status bar module layout and settings |
| `~/.config/hypr-control-center/preferences/` | Control Center user preferences (JSON format) |
| `~/.config/hypr-control-center/theme.json` | Active theme configuration and colors |

---

## Theming

### Built-in Themes

| Theme | Description | Accent Color |
|-------|-------------|--------------|
| **One Dark** | Atom's iconic dark color scheme | Blue |
| **Gruvbox Dark** | Retro-inspired warm palette | Yellow |
| **Nord** | Arctic, north-bluish aesthetic | Frost Blue |
| **Tokyo Night Storm** | Futuristic Tokyo-inspired dark theme | Purple |
| **Catppuccin Mocha** | Soothing pastel color palette | Mauve |
| **Everforest Dark** | Nature-inspired green tones | Green |
| **Dracula** | Popular vibrant dark theme | Purple |
| **Solarized Dark** | Ethan Schoonover's precision colors | Blue |
| **Cyberpunk** | Neon-infused futuristic aesthetic | Pink/Cyan |
| **Arc** | Modern flat design language | Blue |
| **Adapta** | Material Design influenced | Teal |
| **Paper** | Light, minimalist aesthetic | Blue |
| **Yousai** | Elegant light theme variant | Purple |

### Creating Custom Themes

1. Launch Control Center → Navigate to **Theme Switcher**
2. Select a base theme as your starting point
3. Customize colors, typography, and visual elements
4. Click **Save As Custom** to preserve your creation
5. Assign a memorable name to your theme

### Export & Share Custom Presets

Your personalized themes are stored as portable JSON files, perfect for sharing:
```bash
# Custom themes are automatically saved to:
~/.config/hypr-control-center/themes/custom/

# Standard export format: my-theme.json
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

### Importing Themes from Others

1. Download a `.json` theme file from a friend or the community
2. Open Control Center → **Theme Switcher**
3. Click the **Import** button
4. Select the downloaded theme file
5. Your new theme is now available in the theme selector!

---

## Presets

The theming architecture supports **dynamic preset synchronization** across all desktop components. When you switch themes, every application updates automatically—no manual configuration required.

### How the System Works
```
User selects theme in Control Center
    ↓
Theme engine generates color definitions:
    ├── ~/.config/hypr/colorscheme/{theme}.css     (Waybar styling)
    ├── ~/.config/rofi/shared/colors.rasi          (Rofi launcher)
    ├── ~/.config/kitty/theme.conf                 (Terminal colors)
    └── Widget CSS variables                       (Desktop widgets)
    ↓
Applications receive reload signals
    ↓
Complete desktop transformation! ✨
```

### Signal-Based Synchronization

Components utilize POSIX signals for instant theme updates without restarts:
- **Waybar**: Receives `SIGUSR2` signal or performs automatic restart
- **Kitty**: Listens for `USR1` signal for live color updates
- **Widgets**: Handle `SIGUSR1`/`SIGUSR2` for real-time theme switching

---

## Usage

### Launching the Control Center
```bash
# Execute from any directory
python3 ~/.config/hypr-control-center/main.py

# Or bind to a keyboard shortcut (edit hypr/modules/keybinds.conf)
bind = $mainMod, I, exec, python3 ~/.config/hypr-control-center/main.py
```

### Managing Desktop Widgets
```bash
# Launch all enabled widgets at once
~/.config/hypr/scripts/start-widgets.sh

# Start individual widget components
~/.config/hypr/scripts/start-widgets.sh clock
~/.config/hypr/scripts/start-widgets.sh weather
~/.config/hypr/scripts/start-widgets.sh sysmon

# Restart all active widgets
~/.config/hypr/scripts/start-widgets.sh restart
```

### Widget Positioning & Persistence

Widgets feature intuitive drag-and-drop repositioning. Simply click any widget and drag it to your preferred location. All positions are automatically saved to:
```
~/.config/hypr-control-center/preferences/widgets.json
```

---

## Screenshots

<details>
<summary>Click to expand screenshot gallery</summary>

### Hyprland Control Center
![Control Center](assets/screenshots/control-center.png)

### Theme Switcher Interface
![Theme Switcher](assets/screenshots/themes.png)

### Desktop Widgets in Action
![Widgets](assets/screenshots/widgets.png)

### Waybar Style Variations
![Waybar](assets/screenshots/waybar.png)

</details>

---

## Roadmap

### ✅ Completed Features

| Feature | Status | Implementation Notes |
|---------|--------|---------------------|
| Core Control Center | ✅ Complete | Full GTK4/Libadwaita settings application |
| Unified Theming System | ✅ Complete | 13+ themes with instant synchronization |
| Desktop Widgets | ✅ Complete | Clock, Weather, System Monitor with drag support |
| Theme Export/Import | ✅ Complete | JSON format with full portability |
| Extended Theme Library | ✅ Complete | One Dark, Gruvbox, Nord, Tokyo Night, Catppuccin, Everforest, Dracula, Solarized, Cyberpunk, Arc, Adapta, Paper, Yousai |
| Plugin Management | ✅ Complete | Hyprpm integration with GUI controls |
| Wallpaper Manager | ✅ Complete | SWWW with slideshow, pagination, folder browser |
| UI Design System | ✅ Complete | Floating cards with transparency support |

### 🚧 Planned Features

| Feature | Status | Description |
|---------|--------|-------------|
| Per-Workspace Theming | 🚧 Roadmap | Different theme per virtual workspace |
| Additional Widget Types | 🚧 Roadmap | Calendar, media player, quick settings panel |

### Automatic Theme Synchronization

When you switch themes, these components update automatically:

| Component | Integration Method |
|-----------|-------------------|
| **Waybar** | CSS color variables + complete stylesheet |
| **Rofi** | Direct color definitions in colors.rasi |
| **Kitty Terminal** | Full 16-color palette in theme.conf |
| **Start Menu** | Complete CSS with typography support |
| **Hyprbars** | Titlebar colors and decoration styling |
| **SwayNC** | Notification center theme integration |
| **Desktop Widgets** | Clock, weather, and system monitor styling |
| **Control Center** | Self-theming with live interface updates |

---

## Contributing

Community contributions are welcomed and encouraged! Here's how you can help:

- 🐛 **Report Bugs**: Document issues with reproduction steps
- 💡 **Suggest Features**: Share your ideas for improvements
- 🔧 **Submit Pull Requests**: Code contributions are always appreciated
- 🎨 **Share Custom Themes**: Contribute your unique designs to the project
- 📖 **Improve Documentation**: Help make the guides clearer

---

## Support the Project

If Zen Barebone has enhanced your desktop experience, streamlined your workflow, or saved you valuable development time, consider supporting its continued growth:

<p align="center">
  <a href="https://buymeacoffee.com/zenpy">
    <img src="https://img.buymeacoffee.com/button-api/?text=Buy me a coffee&emoji=☕&slug=zenpy&button_colour=BD5FFF&font_colour=ffffff&font_family=Poppins&outline_colour=000000&coffee_colour=FFDD00" alt="Buy Me A Coffee"/>
  </a>
</p>

Your support helps maintain and expand this project. Every contribution, no matter the size, is genuinely appreciated! ☕

---

## Credits & Acknowledgments

- **[Hyprland](https://hyprland.org/)** - The powerful and flexible Wayland compositor
- **[GTK4](https://gtk.org/)** / **[Libadwaita](https://gnome.pages.gitlab.gnome.org/libadwaita/)** - Modern UI toolkit and design system
- **[Waybar](https://github.com/Alexays/Waybar)** - Highly customizable Wayland status bar
- **[Rofi](https://github.com/davatorium/rofi)** - Window switcher and application launcher
- **The Linux Ricing Community** - For endless inspiration and knowledge sharing

---

## License

This project is released under the **MIT License**.

You're free to use, modify, distribute, and build upon this work. See the LICENSE file for complete terms.

---

<p align="center">
  Made with ❤️ by <a href="https://github.com/Gekinzen">Zenpy</a>
</p>
