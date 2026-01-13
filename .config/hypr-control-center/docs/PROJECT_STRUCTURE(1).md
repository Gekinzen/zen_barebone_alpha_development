# Hyprland Control Center - Updated Project Structure

## 📁 Complete Directory Tree

```
hyprland-control-center/
│
├── main.py                          # Application entry point
│
├── src/                            # Source code package
│   ├── __init__.py
│   ├── app.py                      # Main Adw.Application
│   ├── window.py                   # Main window & UI layout
│   ├── constants.py                # Paths & color constants
│   ├── models.py                   # Data classes (configs)
│   ├── config_manager.py           # Hyprland config parser/writer
│   ├── waybar_manager.py           # Waybar config manager (NEW)
│   ├── utils.py                    # Utility functions
│   ├── styles.py                   # CSS generator
│   ├── widgets.py                  # Custom GTK widgets
│   │
│   └── pages/                      # Page modules
│       ├── __init__.py
│       ├── appearance.py           # Appearance (Look & Feel)
│       ├── panel.py                # Panel (Waybar) - NEW
│       ├── panel_helpers.py        # Panel helper functions - NEW
│       └── placeholders.py         # Coming soon pages
│
├── assets/                         # Static assets
│   ├── style.css                   # Standalone app CSS
│   │
│   └── waybar/                     # Waybar assets - NEW
│       ├── colors/
│       │   └── one-dark.css        # Waybar color palette
│       └── default-style.css       # Default Waybar theme
│
├── docs/                           # Documentation - NEW
│   └── PANEL_GUIDE.md              # Panel feature guide
│
├── README.md                       # Main documentation
└── QUICK_REFERENCE.md              # Quick navigation guide

```

## 🆕 New Components

### Waybar Manager (`src/waybar_manager.py`)
Comprehensive Waybar configuration manager:
- Load/save config.json files
- Manage modules (add, remove, move, reorder)
- Monitor detection via `hyprctl`
- Default configuration generator
- Support for main panel + dock

### Panel Page (`src/pages/panel.py`)
Full-featured panel configuration:
- Tab view for Main Panel & Dock
- Panel behavior settings
- Appearance customization
- Module layout management
- Drag & drop support (prepared)

### Panel Helpers (`src/pages/panel_helpers.py`)
UI helper functions:
- Module chip creation
- Drop zone creation
- Size selector widget
- Monitor list getter
- Drag & drop handlers

### Waybar Assets (`assets/waybar/`)
Default configurations:
- One Dark color palette
- Default style.css template
- Ready for theme management

## 📊 Statistics

### Code Distribution

**Python Files:**
- main.py: 18 lines
- src/app.py: 20 lines
- src/window.py: ~250 lines
- src/constants.py: 40 lines
- src/models.py: 80 lines
- src/config_manager.py: 150 lines
- **src/waybar_manager.py: 280 lines** ⭐ NEW
- src/utils.py: 30 lines
- src/styles.py: ~300 lines (updated)
- src/widgets.py: 230 lines
- src/pages/appearance.py: 160 lines
- **src/pages/panel.py: 380 lines** ⭐ NEW
- **src/pages/panel_helpers.py: 150 lines** ⭐ NEW
- src/pages/placeholders.py: 40 lines

**Total Python:** ~2,180 lines

**CSS Files:**
- assets/style.css: ~450 lines (updated)
- assets/waybar/default-style.css: ~120 lines ⭐ NEW
- assets/waybar/colors/one-dark.css: ~20 lines ⭐ NEW

**Documentation:**
- README.md: Existing
- QUICK_REFERENCE.md: Existing
- **docs/PANEL_GUIDE.md: ~300 lines** ⭐ NEW

## 🎯 Feature Status

### ✅ Implemented
- [x] Appearance (Look & Feel)
  - General settings
  - Decoration settings
  - Shadow & blur configuration
  - Reset & apply functionality

- [x] Panel (Waybar) - **NEW**
  - Main Panel configuration
  - Dock (Waybar2) configuration
  - Position & monitor selection
  - Size presets (4 levels each)
  - Margin controls
  - Module layout zones
  - Reset & apply functionality

### 🚧 In Progress
- [ ] Panel (Waybar)
  - Drag & drop module reordering
  - Add module dialog
  - Live preview
  - CSS/opacity manipulation
  - Module-specific settings

### 📋 Planned
- [ ] Workspaces
  - Workspace rules
  - Monitor assignments
  - Persistent workspaces

- [ ] Animations
  - Bezier curves
  - Animation speeds
  - Enable/disable toggles

- [ ] Input Devices
  - Keyboard layouts
  - Mouse/touchpad settings
  - Sensitivity controls

- [ ] Monitors
  - Resolution & scale
  - Position & rotation
  - Multi-monitor setup

- [ ] Keybinds
  - Keyboard shortcuts
  - Custom bindings
  - Categories

## 🔧 Technical Details

### Module System

**WaybarManager API:**
```python
# Initialize
wm = WaybarManager()
wm.load_config(is_dock=False)

# Basic operations
wm.get_position(is_dock=False)  # → "top"
wm.set_height(34, is_dock=False)
wm.get_modules("left", is_dock=False)  # → ["clock", "workspaces"]

# Module management
wm.add_module("left", "cpu", is_dock=False)
wm.remove_module("right", "battery", is_dock=False)
wm.move_module("left", "center", "clock", is_dock=False)
wm.reorder_modules("left", ["workspaces", "clock"], is_dock=False)

# Monitor detection
monitors = wm.get_monitors()  # Uses hyprctl monitors -j

# Save & reload
wm.save_config(wm.main_config, is_dock=False)
wm.reload_waybar()  # pkill waybar && waybar
```

### Configuration Paths

**Hyprland:**
- `~/.config/hypr/hyprland.conf` - Main config
- `~/.config/hypr/modules/look_and_feel.conf` - Appearance
- `~/.config/hypr/modules/default/` - Defaults

**Waybar:**
- `~/.config/waybar/config.json` - Main panel config
- `~/.config/waybar/style.css` - Main panel style
- `~/.config/waybar/waybar2/config.json` - Dock config
- `~/.config/waybar/waybar2/style.css` - Dock style

### CSS Architecture

**Application CSS** (`assets/style.css`):
- Window & containers
- Sidebar navigation
- Settings groups & rows
- Input widgets
- Module management UI
- Tab interface
- One Dark theme

**Waybar CSS** (`assets/waybar/default-style.css`):
- Waybar-specific styling
- Module appearance
- Workspace indicators
- Tooltip styling
- Icon colors

## 🎨 Design Principles

1. **Modular Architecture** - Each feature in its own module
2. **Separation of Concerns** - UI, logic, data separated
3. **Consistent Theming** - One Dark palette throughout
4. **Reusable Components** - Shared widgets across pages
5. **Clear File Structure** - Easy navigation & maintenance
6. **Helper Functions** - Complex logic extracted to helpers
7. **CSS Independence** - Styles separate from code

## 🚀 Usage

### Development
```bash
cd ~/.config/hypr-control-center
python main.py
```

### Production
```bash
./main.py  # If chmod +x
```

Or via desktop entry:
```desktop
Exec=python3 ~/.config/hypr-control-center/main.py
```

## 📚 Documentation

- **README.md** - Project overview & installation
- **QUICK_REFERENCE.md** - File map & navigation
- **docs/PANEL_GUIDE.md** - Panel feature guide
- **Code comments** - Inline documentation
- **Function docstrings** - API documentation

## 🔮 Future Enhancements

### Panel Page
- Real-time drag & drop
- Module configuration dialogs
- Live Waybar preview
- Theme presets
- Import/export configs
- Auto-hide settings
- Per-workspace visibility

### General
- Settings export/import
- Theme marketplace
- Plugin system
- Cloud sync
- Backup/restore
- Configuration profiles
- Keyboard shortcuts
