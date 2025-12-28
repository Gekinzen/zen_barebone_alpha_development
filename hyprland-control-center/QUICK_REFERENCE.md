# Hyprland Control Center - Quick Reference

## File Map (Galing sa Monolithic → Modular)

### Entry Point
- **main.py** (18 lines)
  - Application entry point
  - Imports ControlCenterApp and runs it

### Core Application
- **src/app.py** (20 lines)
  - `ControlCenterApp` class
  - Adwaita.Application setup

- **src/window.py** (~250 lines)
  - `ControlCenterWindow` class
  - UI layout (sidebar + stack)
  - Navigation handlers
  - Helper methods (page header, action buttons, toast)
  - Appearance page handlers (reset, apply, refresh)

### Data & Configuration
- **src/constants.py** (40 lines)
  - Path definitions (HOME, CONFIG_DIR, etc.)
  - One Dark color palette

- **src/models.py** (80 lines)
  - All dataclasses:
    - GeneralConfig
    - DecorationConfig  
    - AnimationConfig
    - InputConfig
    - MonitorConfig
    - WaybarConfig
    - WorkspaceRule

- **src/config_manager.py** (~150 lines)
  - `HyprlandConfigManager` class
  - parse_look_and_feel()
  - generate_look_and_feel()
  - save/reset functionality
  - Regex-based parsing

### UI Components
- **src/widgets.py** (~230 lines)
  - SettingRow (base class)
  - ColorPickerRow
  - IntegerRow
  - FloatRow
  - ToggleRow
  - DropdownRow
  - SectionHeader
  - SettingsGroup
  - PlaceholderPage

- **src/utils.py** (30 lines)
  - rgba_to_gdk() - Hyprland → GTK color
  - gdk_to_rgba() - GTK → Hyprland color

- **src/styles.py** (~240 lines)
  - get_css() function
  - One Dark CSS theme
  - All widget styles

### Pages
- **src/pages/appearance.py** (~160 lines)
  - build_appearance_page() function
  - General settings section
  - Decoration settings section
  - Creates all widgets with callbacks

- **src/pages/placeholders.py** (~50 lines)
  - build_panel_page()
  - build_workspaces_page()
  - build_animations_page()
  - build_input_page()
  - build_monitors_page()
  - build_keybinds_page()

### Assets
- **assets/style.css** (~340 lines)
  - Standalone CSS file
  - CSS variables version
  - Same as styles.py output

## Line Count Breakdown

Original monolithic: ~1300 lines

New modular:
- main.py: 18
- src/app.py: 20
- src/window.py: 250
- src/constants.py: 40
- src/models.py: 80
- src/config_manager.py: 150
- src/widgets.py: 230
- src/utils.py: 30
- src/styles.py: 240
- src/pages/appearance.py: 160
- src/pages/placeholders.py: 50
- **Total Python: ~1270 lines**
- assets/style.css: 340 (optional)

## Import Chain

```
main.py
  └─> src.app.ControlCenterApp
        └─> src.window.ControlCenterWindow
              ├─> src.config_manager.HyprlandConfigManager
              │     └─> src.models.*
              │     └─> src.constants.*
              ├─> src.styles.get_css()
              │     └─> src.constants.ONE_DARK
              ├─> src.pages.appearance.build_appearance_page()
              │     └─> src.widgets.*
              │           └─> src.utils.rgba_to_gdk/gdk_to_rgba
              └─> src.pages.placeholders.build_*_page()
                    └─> src.widgets.PlaceholderPage
```

## Key Benefits

1. **Maintainability**: Each file has single responsibility
2. **Testability**: Easy to test individual modules
3. **Extensibility**: Add new pages by creating new files
4. **Reusability**: Widgets can be used across pages
5. **Organization**: Clear structure, easy to navigate

## Quick Navigation

Need to...
- Change colors? → `src/constants.py` (ONE_DARK dict)
- Add widget? → `src/widgets.py`
- Modify CSS? → `src/styles.py` or `assets/style.css`
- Add page? → `src/pages/your_page.py`
- Change config parsing? → `src/config_manager.py`
- Add config type? → `src/models.py`
- Modify layout? → `src/window.py`

## Installation

Same installation process:
```bash
mkdir -p ~/.config/hypr-control-center
cp -r * ~/.config/hypr-control-center/
chmod +x ~/.config/hypr-control-center/main.py
```

Desktop entry still points to:
```
Exec=python3 ~/.config/hypr-control-center/main.py
```
