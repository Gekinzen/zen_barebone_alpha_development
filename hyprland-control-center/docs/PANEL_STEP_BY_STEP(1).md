# Step-by-Step Guide: Panel Module Implementation

## 📚 Table of Contents
1. [Overview](#overview)
2. [File Structure](#file-structure)
3. [Step-by-Step Implementation](#step-by-step-implementation)
4. [Testing Guide](#testing-guide)
5. [Future: Adding Dock Support](#future-adding-dock-support)

---

## Overview

Ang Panel module ay nag-manage ng Waybar configuration with:
- ✅ Main Panel (Waybar) - Fully implemented
- 🔜 Dock (Waybar2) - Coming soon (structure ready)

**Key Components:**
- `waybar_manager.py` - Backend config manager
- `panel.py` - Main UI page
- `panel_helpers.py` - UI helper functions
- Default configs in `assets/waybar/`

---

## File Structure

```
hyprland-control-center/
│
├── src/
│   ├── waybar_manager.py          # Core Waybar config manager
│   │   └── WaybarManager class     # 20 functions for config manipulation
│   │
│   └── pages/
│       ├── panel.py                # Main Panel UI (287 lines)
│       │   ├── build_panel_page()           # Entry point
│       │   ├── _build_main_panel_content()  # Main panel UI
│       │   └── Helper functions (9)         # Event handlers
│       │
│       └── panel_helpers.py        # UI components (150 lines)
│           ├── create_module_chip()         # Module visual
│           ├── create_module_drop_zone()    # Drag & drop zone
│           ├── create_size_selector()       # Size buttons
│           └── get_monitor_list()           # hyprctl integration
│
├── assets/waybar/
│   ├── colors/one-dark.css         # Color variables
│   └── default-style.css           # Default Waybar CSS
│
└── docs/
    └── PANEL_STEP_BY_STEP.md       # This file!
```

---

## Step-by-Step Implementation

### STEP 1: Understanding WaybarManager

**File:** `src/waybar_manager.py`

**Purpose:** Manages all Waybar config.json operations

**Key Methods:**
```python
# Load config from file
wm = WaybarManager()
wm.load_config(is_dock=False)  # Load main panel config

# Position & Size
wm.get_position(is_dock=False)    # → "top"
wm.set_position("bottom", is_dock=False)
wm.get_height(is_dock=False)      # → 34
wm.set_height(42, is_dock=False)

# Margins
wm.get_margin('left', is_dock=False)    # → 0
wm.set_margin('top', 15, is_dock=False)

# Modules
modules = wm.get_modules('left', is_dock=False)  # → ["clock", "workspaces"]
wm.add_module('left', 'cpu', is_dock=False)
wm.remove_module('right', 'battery', is_dock=False)
wm.move_module('left', 'center', 'clock', is_dock=False)

# Monitor
monitors = wm.get_monitors()  # Uses: hyprctl monitors -j
wm.set_output('DP-1', is_dock=False)  # Show on specific monitor
wm.set_output(None, is_dock=False)    # Show on all monitors

# Save & Reload
wm.save_config(wm.main_config, is_dock=False)
wm.reload_waybar()  # pkill waybar && waybar &
```

**How it works:**
1. Loads `~/.config/waybar/config.json` into `main_config` dict
2. You modify the dict using setter methods
3. Call `save_config()` to write back to file
4. `reload_waybar()` restarts Waybar to apply changes

---

### STEP 2: Building the UI (panel.py)

**File:** `src/pages/panel.py`

#### 2.1 Entry Point: `build_panel_page()`

```python
def build_panel_page(window) -> Gtk.ScrolledWindow:
    """Main entry point called by window.py"""
    
    # 1. Create scrolled window
    scrolled = Gtk.ScrolledWindow()
    content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
    
    # 2. Initialize WaybarManager
    if not hasattr(window, 'waybar_manager'):
        window.waybar_manager = WaybarManager()
        window.waybar_manager.load_config(is_dock=False)
    
    # 3. Add header
    page_header = window._create_page_header(
        "Panel (Waybar)",
        "Configure your main Waybar panel"
    )
    content.append(page_header)
    
    # 4. Add info banner
    info_box = Gtk.Box(...)
    info_label = Gtk.Label(label="Dock coming soon!")
    content.append(info_box)
    
    # 5. Build main content
    main_content = _build_main_panel_content(window)
    content.append(main_content)
    
    return scrolled
```

**Flow:**
1. User clicks "Panel" in sidebar
2. `window.py` calls `build_panel_page(window)`
3. Returns Gtk.ScrolledWindow with all UI
4. Displayed in main content area

---

#### 2.2 Main Content: `_build_main_panel_content()`

**Sections:**

**A. Panel Behavior**
```python
behavior_group = SettingsGroup("Panel Behavior")

# Position dropdown
DropdownRow(
    "Position on Screen",
    ["top", "bottom", "left", "right"],
    current_position,
    lambda v: wm.set_position(v, is_dock=False)
)

# Monitor selection
DropdownRow(
    "Show on Display",
    ["All Monitors", "Primary", "DP-1", "HDMI-A-1"],
    current_monitor,
    lambda v: _on_monitor_change(window, v, is_dock=False)
)

# Extend toggle
ToggleRow(
    "Extend to Screen Edges",
    is_extended,
    lambda v: _on_extend_toggle(window, v, is_dock=False)
)
```

**B. Panel Appearance**
```python
appearance_group = SettingsGroup("Panel Appearance")

# Size selector (4 buttons)
create_size_selector(
    current_height,
    lambda h: wm.set_height(h, is_dock=False)
)

# Opacity slider
FloatRow("Background Opacity", 1.0, 0.0, 1.0, callback)

# Margins (4 spinners)
for side in ['top', 'bottom', 'left', 'right']:
    IntegerRow(
        f"Margin {side.title()}",
        current_value,
        0, 100,
        lambda v, s=side: wm.set_margin(s, v, is_dock=False)
    )
```

**C. Module Layout**
```python
modules_group = SettingsGroup("Module Layout")

# 3 drop zones: left, center, right
for pos in ['left', 'center', 'right']:
    modules = wm.get_modules(pos, is_dock=False)
    zone = create_module_drop_zone(
        pos,
        modules,
        on_add=lambda p: _on_add_module(window, p),
        on_remove=lambda p, m: _on_remove_module(window, p, m),
        on_reorder=lambda p, data: _on_reorder_modules(window, p, data)
    )
```

---

### STEP 3: Helper Functions (panel_helpers.py)

**File:** `src/pages/panel_helpers.py`

#### 3.1 Module Chip
```python
def create_module_chip(module_name: str, on_remove: Callable):
    """Creates visual module chip with icon and remove button"""
    
    chip = Gtk.Box(horizontal, spacing=8)
    chip.add_css_class('module-chip')
    
    # Icon (based on module type)
    icon = Gtk.Image(icon_name_from_module(module_name))
    chip.append(icon)
    
    # Label
    label = Gtk.Label(label=display_name(module_name))
    chip.append(label)
    
    # Remove button (×)
    remove_btn = Gtk.Button(icon='window-close-symbolic')
    remove_btn.connect('clicked', lambda: on_remove(module_name))
    chip.append(remove_btn)
    
    return chip
```

**Result:** `[🕐 Clock ×]`

---

#### 3.2 Drop Zone
```python
def create_module_drop_zone(position, modules, on_add, on_remove, on_reorder):
    """Creates drop zone with header and module chips"""
    
    zone = Gtk.Box(vertical)
    
    # Header with + button
    header = Gtk.Box(horizontal)
    title = Gtk.Label(label=position.upper())
    add_btn = Gtk.Button(icon='list-add-symbolic')
    add_btn.connect('clicked', lambda: on_add(position))
    header.append(title)
    header.append(add_btn)
    
    # Modules container
    modules_box = Gtk.Box(vertical)
    for module in modules:
        chip = create_module_chip(module, lambda m: on_remove(position, m))
        modules_box.append(chip)
    
    zone.append(header)
    zone.append(modules_box)
    
    return zone
```

**Result:**
```
┌─────────────────┐
│ LEFT        [+] │
├─────────────────┤
│ [🕐 Clock ×]    │
│ [📊 Work.. ×]   │
└─────────────────┘
```

---

#### 3.3 Monitor Detection
```python
def get_monitor_list() -> List[str]:
    """Get monitors using hyprctl"""
    
    result = subprocess.run(
        ['hyprctl', 'monitors', '-j'],
        capture_output=True,
        text=True
    )
    
    monitors = json.loads(result.stdout)
    names = [m['name'] for m in monitors]
    
    return ['All Monitors', 'Primary'] + names
```

**Result:** `['All Monitors', 'Primary', 'DP-1', 'HDMI-A-1']`

---

### STEP 4: Event Handlers (panel.py)

#### 4.1 Monitor Change
```python
def _on_monitor_change(window, monitor_name: str, is_dock: bool):
    """Handle monitor selection"""
    if monitor_name in ["All Monitors", "Primary"]:
        # Remove output key → show on all
        window.waybar_manager.set_output(None, is_dock=is_dock)
    else:
        # Set specific monitor
        window.waybar_manager.set_output(monitor_name, is_dock=is_dock)
```

---

#### 4.2 Extend Toggle
```python
def _on_extend_toggle(window, extend: bool, is_dock: bool):
    """Handle extend to edges"""
    wm = window.waybar_manager
    if extend:
        # Full width
        wm.set_margin('left', 0, is_dock=is_dock)
        wm.set_margin('right', 0, is_dock=is_dock)
    else:
        # Floating panel
        wm.set_margin('left', 12, is_dock=is_dock)
        wm.set_margin('right', 12, is_dock=is_dock)
```

---

#### 4.3 Module Operations
```python
def _on_add_module(window, position: str, is_dock: bool):
    """Add module - shows toast for now"""
    window._show_toast(f"Add module to {position} - Coming soon")

def _on_remove_module(window, position: str, module: str, is_dock: bool):
    """Remove module"""
    window.waybar_manager.remove_module(position, module, is_dock=is_dock)
    window._show_toast(f"Removed {module}")
    # TODO: Refresh UI

def _on_reorder_modules(window, position: str, data: str, is_dock: bool):
    """Handle drag & drop"""
    # Parse "from_pos:module"
    from_pos, module = data.split(':')
    if from_pos != position:
        window.waybar_manager.move_module(from_pos, position, module, is_dock=is_dock)
```

---

#### 4.4 Reset & Apply
```python
def _on_panel_reset(window, is_dock: bool):
    """Reset to default config"""
    dialog = Adw.MessageDialog(
        heading="Reset Main Panel?",
        body="This will restore default configuration."
    )
    dialog.add_response("reset", "Reset")
    dialog.connect('response', lambda d, r: handle_reset(r))
    dialog.present()

def _on_panel_apply(window, is_dock: bool):
    """Save and reload"""
    wm = window.waybar_manager
    wm.save_config(wm.main_config, is_dock=False)
    window._show_toast("Panel configuration saved")
```

---

## Testing Guide

### Test 1: Load Panel Page
```bash
cd ~/.config/hypr-control-center
python main.py
```
1. Click "Panel" in sidebar
2. Should see: Header, info banner, settings groups
3. Check: No errors in terminal

### Test 2: Position Change
1. Click "Position on Screen" dropdown
2. Select "bottom"
3. Click "Apply Changes"
4. **Expected:** Waybar moves to bottom

### Test 3: Monitor Detection
1. Check "Show on Display" dropdown
2. **Expected:** See your actual monitors
3. Verify with: `hyprctl monitors -j`

### Test 4: Size Presets
1. Click size buttons (Small, Medium, Large, X-Large)
2. Click "Apply Changes"
3. **Expected:** Panel height changes (28, 34, 42, 52)

### Test 5: Extend Toggle
1. Toggle "Extend to Screen Edges" ON
2. Click "Apply"
3. **Expected:** Panel touches screen edges
4. Toggle OFF
5. **Expected:** 12px margins on sides

### Test 6: Module Removal
1. Click × on any module chip
2. Click "Apply"
3. **Expected:** Module disappears from Waybar

### Test 7: Reset
1. Make several changes
2. Click "Reset to Default"
3. Confirm dialog
4. **Expected:** Your default config restored

---

## Future: Adding Dock Support

When ready to implement Waybar2 (Dock), follow these steps:

### Step 1: Uncomment Dock Function
In `panel.py`, uncomment the `_build_dock_panel_content()` function and implement it similar to main panel.

### Step 2: Add Tab View
Replace single content with TabView:

```python
def build_panel_page(window):
    # ... init code ...
    
    # Create tab view
    tab_view = Adw.TabView()
    
    # Main Panel tab
    main_page = _build_main_panel_content(window)
    tab_view.append(main_page).set_title("Main Panel")
    
    # Dock tab
    dock_page = _build_dock_panel_content(window)
    tab_view.append(dock_page).set_title("Dock (Waybar2)")
    
    # Tab bar
    tab_bar = Adw.TabBar()
    tab_bar.set_view(tab_view)
    
    content.append(tab_bar)
    content.append(tab_view)
```

### Step 3: Enable Dock Config Loading
```python
if not hasattr(window, 'waybar_manager'):
    window.waybar_manager = WaybarManager()
    window.waybar_manager.load_config(is_dock=False)
    window.waybar_manager.load_config(is_dock=True)  # Enable this!
```

### Step 4: Create Waybar2 Directory
```bash
mkdir -p ~/.config/waybar/waybar2
```

### Step 5: Copy Default Config
WaybarManager will create default config automatically, or manually:
```bash
cp assets/waybar/default-config.json ~/.config/waybar/waybar2/config.json
cp assets/waybar/default-style.css ~/.config/waybar/waybar2/style.css
```

### Step 6: Launch Waybar2
```bash
waybar -c ~/.config/waybar/waybar2/config.json \
       -s ~/.config/waybar/waybar2/style.css &
```

### Step 7: Test Dock Config
Same tests as main panel, but with `is_dock=True` flag.

---

## Troubleshooting

### Panel doesn't reload?
```bash
pkill waybar
waybar &
```

### Config file not found?
```bash
ls ~/.config/waybar/
# Should see: config.json, style.css
```

### Monitors not detected?
```bash
hyprctl monitors -j
# Should return JSON array
```

### Module not appearing?
1. Check module is in modules list: `wm.get_modules('left')`
2. Check module config exists in main_config dict
3. Check Waybar supports that module

---

## Quick Reference

**Common Tasks:**

```python
# Get WaybarManager instance
wm = window.waybar_manager

# Change position
wm.set_position("bottom", is_dock=False)

# Change size
wm.set_height(42, is_dock=False)

# Add module
wm.add_module("left", "cpu", is_dock=False)

# Save changes
wm.save_config(wm.main_config, is_dock=False)
wm.reload_waybar()
```

**File Locations:**
- Main config: `~/.config/waybar/config.json`
- Main style: `~/.config/waybar/style.css`
- Dock config: `~/.config/waybar/waybar2/config.json`
- Dock style: `~/.config/waybar/waybar2/style.css`

**Key Files:**
- Backend: `src/waybar_manager.py` (280 lines)
- UI: `src/pages/panel.py` (287 lines)
- Helpers: `src/pages/panel_helpers.py` (150 lines)
- CSS: `assets/waybar/default-style.css` (120 lines)

---

Tapos na! Complete step-by-step guide from backend to frontend! 🚀
