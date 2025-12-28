# Hyprland Control Center - Project Structure

## Overview
Modular structure para sa Hyprland Control Center with separated concerns.

## Directory Structure

```
hyprland-control-center/
├── main.py                    # Entry point
├── src/
│   ├── __init__.py           # Package initialization
│   ├── app.py                # Main application class
│   ├── window.py             # Main window with UI logic
│   ├── constants.py          # Paths and color constants
│   ├── models.py             # Data classes for configs
│   ├── config_manager.py     # Config file parser/writer
│   ├── utils.py              # Utility functions (color conversion)
│   ├── styles.py             # CSS generation
│   ├── widgets.py            # Custom GTK widgets
│   └── pages/
│       ├── __init__.py
│       ├── appearance.py     # Appearance settings page
│       └── placeholders.py   # Placeholder pages
├── assets/
│   └── style.css            # Standalone CSS file (optional)
└── README.md                # This file
```

## Module Descriptions

### Core Modules

**main.py**
- Entry point ng application
- Calls `ControlCenterApp().run()`

**src/app.py**
- `ControlCenterApp` - Main Adwaita Application
- Handles application lifecycle

**src/window.py**
- `ControlCenterWindow` - Main application window
- Builds UI layout (sidebar + content stack)
- Contains page handlers (reset, apply, etc.)

### Configuration

**src/constants.py**
- File paths (CONFIG_DIR, LOOK_AND_FEEL_CONF, etc.)
- One Dark color palette dictionary

**src/models.py**
- Data classes for all config types:
  - `GeneralConfig`
  - `DecorationConfig`
  - `AnimationConfig`
  - `InputConfig`
  - `MonitorConfig`
  - `WaybarConfig`
  - `WorkspaceRule`

**src/config_manager.py**
- `HyprlandConfigManager` class
- Parses Hyprland config files (regex-based)
- Generates config file content
- Saves and reloads Hyprland

### UI Components

**src/widgets.py**
- Custom GTK4 widgets:
  - `SettingRow` - Base row widget
  - `ColorPickerRow` - Color picker with RGBA display
  - `IntegerRow` - Spin button for integers
  - `FloatRow` - Slider for floats
  - `ToggleRow` - Switch widget
  - `DropdownRow` - Dropdown menu
  - `SectionHeader` - Section separator
  - `SettingsGroup` - Container for settings
  - `PlaceholderPage` - "Coming Soon" page

**src/styles.py**
- `get_css()` function that returns complete CSS
- One Dark theme implementation
- Programmatically generates CSS from constants

**src/utils.py**
- `rgba_to_gdk()` - Convert Hyprland RGBA to GTK Gdk.RGBA
- `gdk_to_rgba()` - Convert GTK Gdk.RGBA to Hyprland RGBA

### Pages

**src/pages/appearance.py**
- `build_appearance_page()` - Complete Appearance section
- Look & Feel configuration UI
- All the working widgets for general + decoration

**src/pages/placeholders.py**
- Placeholder pages for upcoming features:
  - Panel (Waybar)
  - Workspaces
  - Animations
  - Input Devices
  - Monitors
  - Keybinds

## Running the Application

```bash
cd ~/.config/hypr-control-center
python main.py
```

or

```bash
python -m src.app
```

## Adding New Features

### To add a new settings page:

1. Create new file in `src/pages/your_page.py`
2. Define `build_your_page(window)` function
3. Import in `src/pages/__init__.py`
4. Add to window stack in `src/window.py`
5. Add sidebar item in `window._build_sidebar()`

### To add new config types:

1. Add dataclass to `src/models.py`
2. Add parser/generator in `src/config_manager.py`
3. Create widgets in corresponding page file

## CSS Customization

Two options:

1. **Programmatic** (current): Edit `src/styles.py` - `get_css()`
2. **Static file**: Edit `assets/style.css` and load from file

Para gawing file-based ang CSS:

```python
# In src/window.py _apply_css():
css_file = Path(__file__).parent.parent / "assets" / "style.css"
provider.load_from_path(str(css_file))
```

## Installation Structure

When installed sa `~/.config/hypr-control-center/`:

```
~/.config/hypr-control-center/
├── main.py
├── src/
│   └── (all modules)
├── assets/
│   └── style.css
└── README.md
```

## Design Principles

- **Separation of Concerns**: UI, logic, data separated
- **Modularity**: Easy to add new pages/features
- **Maintainability**: Clear structure, well-organized
- **Cosmic-inspired**: Matches Cosmic DE design patterns
- **One Dark themed**: Consistent with waybar theme
