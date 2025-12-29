# Panel (Waybar) Configuration

## Overview

The Panel page provides comprehensive control over your Waybar configurations with support for:
- **Main Panel** - Primary status bar
- **Dock (Waybar2)** - Secondary dock-style panel

## Features

### ✨ Panel Behavior

- **Position on Screen** - Top, Bottom, Left, Right
- **Show on Display** - All Monitors, Primary, or specific monitor
- **Extend to Screen Edges** - Toggle for full-width/height panels
- **Monitor Detection** - Uses `hyprctl monitors` for auto-detection

### 🎨 Panel Appearance

- **Size Presets**:
  - Main Panel: Small (28px), Medium (34px), Large (42px), X-Large (52px)
  - Dock: Small (48px), Medium (60px), Large (72px), X-Large (84px)
- **Background Opacity** - Adjustable transparency
- **Margins** - Fine-grained control (top, bottom, left, right)

### 🧩 Module Management

- **Drag & Drop** - Rearrange modules between left/center/right zones
- **Add Modules** - Button to add new applets
- **Remove Modules** - Click × to remove
- **Available Modules**:
  - clock
  - hyprland/workspaces
  - tray
  - pulseaudio
  - network
  - battery
  - cpu
  - memory
  - disk
  - temperature
  - backlight
  - bluetooth
  - custom/notification
  - idle_inhibitor
  - mpd
  - custom/weather

## File Structure

```
src/
├── waybar_manager.py          # Waybar config manager
├── pages/
│   ├── panel.py              # Main panel page
│   └── panel_helpers.py      # Helper functions for module UI

assets/waybar/
├── colors/
│   └── one-dark.css          # Color palette
└── default-style.css         # Default Waybar styling
```

## Configuration Files

### Main Panel
- Config: `~/.config/waybar/config.json`
- Style: `~/.config/waybar/style.css`

### Dock (Waybar2)
- Config: `~/.config/waybar/waybar2/config.json`
- Style: `~/.config/waybar/waybar2/style.css`

## Default Configurations

### Main Panel Default
```json
{
    "position": "top",
    "height": 34,
    "modules-left": ["clock", "hyprland/workspaces"],
    "modules-center": ["tray"],
    "modules-right": ["pulseaudio", "network", "battery", "custom/notification"]
}
```

### Dock Default
```json
{
    "position": "bottom",
    "height": 60,
    "margin-bottom": 8,
    "modules-left": ["hyprland/workspaces"],
    "modules-right": ["tray"]
}
```

## Usage

### Basic Configuration
1. Open Hyprland Control Center
2. Navigate to "Panel" section
3. Choose "Main Panel" or "Dock (Waybar2)" tab
4. Adjust settings as needed
5. Click "Apply Changes"

### Module Management
1. **Add Module**: Click + button in zone
2. **Remove Module**: Click × on module chip
3. **Rearrange**: Drag and drop between zones
4. **Reorder**: Drag within same zone (Coming soon)

### Monitor Setup
1. Select "Show on Display" dropdown
2. Options auto-populated from `hyprctl monitors`
3. Choose:
   - "All Monitors" - Show on every display
   - "Primary" - Show on primary monitor
   - Specific monitor name (e.g., "DP-1")

## Advanced Features

### Extend to Screen Edges
When enabled:
- Left/Right margins set to 0
- Panel spans full width/height

When disabled:
- Default 12px margins applied
- Creates floating panel effect

### Size Presets
Each size level affects:
- Panel height
- Module spacing
- Icon sizes (via CSS)

## Styling

### One Dark Theme
Default theme uses One Dark color palette:
- Background: `#282c34` (bg0)
- Active modules: `#61afef` (blue)
- Text: `#abb2bf` (fg)

### Custom Styling
Modify: `~/.config/waybar/style.css`
- Module-specific styles
- Workspace indicators
- Icon colors
- Hover effects

## Implementation Details

### WaybarManager Class
```python
from waybar_manager import WaybarManager

wm = WaybarManager()
wm.load_config(is_dock=False)  # Load main panel
wm.set_position("top")
wm.add_module("left", "clock")
wm.save_config(wm.main_config)
```

### Module Operations
```python
# Add module
wm.add_module("left", "clock", is_dock=False)

# Remove module
wm.remove_module("right", "battery", is_dock=False)

# Move module
wm.move_module("left", "center", "clock", is_dock=False)

# Reorder modules
wm.reorder_modules("left", ["clock", "workspaces"], is_dock=False)
```

### Monitor Detection
```python
monitors = wm.get_monitors()
# Returns: [{'name': 'DP-1', 'width': 1920, ...}, ...]
```

## Upcoming Features

- [ ] Module configuration dialogs
- [ ] Live preview
- [ ] Custom module creator
- [ ] Theme presets
- [ ] Export/Import configurations
- [ ] Auto-hide/reveal animations
- [ ] Per-workspace visibility

## Troubleshooting

### Waybar not reloading?
```bash
pkill waybar && waybar &
```

### Config not found?
```bash
mkdir -p ~/.config/waybar/waybar2
```

### Monitor not detected?
```bash
hyprctl monitors -j
```

## See Also

- [Waybar Wiki](https://github.com/Alexays/Waybar/wiki)
- [Hyprland Wiki](https://wiki.hyprland.org/)
- Appearance page - For theme consistency
- Workspaces page - For workspace configuration
