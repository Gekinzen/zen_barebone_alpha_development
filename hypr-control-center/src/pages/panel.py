"""
Panel (Waybar) Configuration Page
Main Panel only - Dock (Waybar2) coming soon!
Includes: Module Layout + Group/Expand Drawer Configuration

FIXED v2.0:
- Drawer selections now PERSIST across restarts
- Preferences saved to ~/.config/hypr-control-center/preferences/drawer-config.json
- Apply Drawer Config updates waybar config.jsonc AND reloads waybar
- Dynamic paths for any user
"""

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
from gi.repository import Gtk, Adw, GLib
from typing import Callable
import json
import os
from pathlib import Path
from datetime import datetime

from ..widgets import (
    SettingsGroup, IntegerRow, ToggleRow, DropdownRow, FloatRow
)
from ..waybar_manager import WaybarManager
from ..waybar_style_manager import WaybarStyleManager
from .panel_helpers import (
    create_module_drop_zone, get_monitor_list, create_size_selector
)


# ═══════════════════════════════════════════════════════════════════════════════
# DYNAMIC PATHS - Works for any user!
# ═══════════════════════════════════════════════════════════════════════════════

HOME = Path.home()
PREFERENCES_DIR = HOME / ".config/hypr-control-center/preferences"
DRAWER_PREFS_FILE = PREFERENCES_DIR / "drawer-config.json"


# ═══════════════════════════════════════════════════════════════════════════════
# DRAWER MODULE DEFINITIONS
# ═══════════════════════════════════════════════════════════════════════════════

# Modules that can be placed in the group/expand drawer
DRAWER_AVAILABLE_MODULES = [
    ("pulseaudio", "󰕾 Audio", "audio-volume-high-symbolic"),
    ("cpu", "󰻠 CPU Usage", "utilities-system-monitor-symbolic"),
    ("memory", "󰍛 Memory Usage", "drive-harddisk-symbolic"),
    ("temperature", "󰔏 Temperature", "temperature-symbolic"),
    ("network", "󰖩 Network", "network-wireless-symbolic"),
    ("bluetooth", "󰂯 Bluetooth", "bluetooth-symbolic"),
    ("battery", "󰁹 Battery", "battery-symbolic"),
    ("backlight", "󰃟 Brightness", "display-brightness-symbolic"),
    ("custom/pacman", "󰀼 System Updates", "system-software-update-symbolic"),
    ("disk", "󰋊 Disk Usage", "drive-harddisk-symbolic"),
]

# Expand icon options - Nerd Fonts
EXPAND_ICON_OPTIONS = [
    ("chevron_left", "", "Chevron <"),
    ("arrow_left", "", "Arrow <"),
    ("menu", "󰍜", "Menu"),
    ("chevron_alt", "󰁌", "Chevron Alt"),
    ("dots_h", "󰘕", "Dots H"),
    ("dots_v", "⋮", "Dots V"),
]

# Default drawer config
DEFAULT_DRAWER_CONFIG = {
    "enabled_modules": ["pulseaudio", "cpu", "memory", "temperature", "network", "bluetooth", "custom/pacman"],
    "animation_duration": 600,
    "expand_direction": "left",
    "expand_icon": "chevron_left",
    "click_to_reveal": True
}


# ═══════════════════════════════════════════════════════════════════════════════
# DRAWER PREFERENCES MANAGEMENT
# ═══════════════════════════════════════════════════════════════════════════════

def load_drawer_preferences() -> dict:
    """Load drawer preferences from file, returns defaults if not found"""
    try:
        if DRAWER_PREFS_FILE.exists():
            data = json.loads(DRAWER_PREFS_FILE.read_text())
            # Merge with defaults to handle new fields
            config = DEFAULT_DRAWER_CONFIG.copy()
            config.update(data)
            print(f"[Panel] Loaded drawer preferences: {len(config.get('enabled_modules', []))} modules")
            return config
    except Exception as e:
        print(f"[Panel] Error loading drawer preferences: {e}")
    
    return DEFAULT_DRAWER_CONFIG.copy()


def save_drawer_preferences(config: dict) -> bool:
    """Save drawer preferences to file for persistence"""
    try:
        PREFERENCES_DIR.mkdir(parents=True, exist_ok=True)
        
        config["updated"] = datetime.now().isoformat()
        DRAWER_PREFS_FILE.write_text(json.dumps(config, indent=2, ensure_ascii=False))
        
        print(f"[Panel] Saved drawer preferences: {config.get('enabled_modules', [])}")
        return True
    except Exception as e:
        print(f"[Panel] Error saving drawer preferences: {e}")
        return False


# ═══════════════════════════════════════════════════════════════════════════════
# MAIN PAGE BUILDER
# ═══════════════════════════════════════════════════════════════════════════════

def build_panel_page(window) -> Gtk.ScrolledWindow:
    """Build Panel (Waybar) settings page - Module Layout + Drawer Config"""
    scrolled = Gtk.ScrolledWindow()
    scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
    
    # PREVENT AUTO-SCROLL DURING DRAG
    scrolled.set_kinetic_scrolling(False)
    
    content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
    content.add_css_class('content-area')
    
    # Initialize waybar manager
    if not hasattr(window, 'waybar_manager'):
        window.waybar_manager = WaybarManager()
        window.waybar_manager.load_config(is_dock=False)
    
    # Initialize style manager
    if not hasattr(window, 'waybar_style_manager'):
        from ..constants import WAYBAR_DIR
        window.waybar_style_manager = WaybarStyleManager(WAYBAR_DIR)
        window.waybar_style_manager.load_style()
    
    # ═══════════════════════════════════════════════════════════════
    # VALIDATE GROUP/EXPAND CONFIG ON PAGE LOAD
    # ═══════════════════════════════════════════════════════════════
    _validate_group_expand_config(window.waybar_manager)
    
    # Header
    page_header = window._create_page_header(
        "Panel (Waybar)",
        "Configure your Waybar panel modules and drawer"
    )
    content.append(page_header)
    
    # Info banner about Theming
    info_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
    info_box.add_css_class('info-banner')
    info_box.set_margin_bottom(16)
    
    info_icon = Gtk.Image.new_from_icon_name('dialog-information-symbolic')
    info_icon.set_pixel_size(16)
    info_box.append(info_icon)
    
    info_label = Gtk.Label(label="💡 Panel appearance (colors, opacity, style) is controlled in the Theming page")
    info_label.add_css_class('setting-description')
    info_label.set_halign(Gtk.Align.START)
    info_box.append(info_label)
    
    content.append(info_box)
    
    # Main Panel content
    main_content = _build_main_panel_content(window)
    content.append(main_content)
    
    scrolled.set_child(content)
    return scrolled


def _validate_group_expand_config(wm):
    """Validate and fix group/expand configuration if needed"""
    config = wm.main_config
    needs_save = False
    
    # Check if group/expand is used anywhere
    all_modules = []
    for pos in ['left', 'center', 'right']:
        all_modules.extend(config.get(f'modules-{pos}', []))
    
    has_group_expand = 'group/expand' in all_modules
    
    if has_group_expand:
        # Validate custom/expand - MUST have visible format!
        if "custom/expand" not in config:
            config["custom/expand"] = {"format": "", "tooltip": False}
            needs_save = True
        elif not config["custom/expand"].get("format"):
            config["custom/expand"]["format"] = ""
            needs_save = True
        
        # Validate custom/endpoint
        if "custom/endpoint" not in config:
            config["custom/endpoint"] = {"format": "|", "tooltip": False}
            needs_save = True
        
        # Validate group/expand has drawer config
        if "group/expand" not in config:
            config["group/expand"] = {
                "orientation": "horizontal",
                "drawer": {"transition-duration": 600, "transition-to-left": True, "click-to-reveal": True},
                "modules": ["custom/expand", "pulseaudio", "cpu", "memory", "temperature", "network", "bluetooth", "custom/pacman", "custom/endpoint"]
            }
            needs_save = True
        else:
            if "drawer" not in config["group/expand"]:
                config["group/expand"]["drawer"] = {"transition-duration": 600, "transition-to-left": True, "click-to-reveal": True}
                needs_save = True
            
            modules = config["group/expand"].get("modules", [])
            if not modules:
                modules = ["custom/expand", "pulseaudio", "cpu", "memory", "custom/endpoint"]
                config["group/expand"]["modules"] = modules
                needs_save = True
            else:
                if "custom/expand" not in modules:
                    modules.insert(0, "custom/expand")
                    needs_save = True
                if "custom/endpoint" not in modules:
                    modules.append("custom/endpoint")
                    needs_save = True
                if needs_save:
                    config["group/expand"]["modules"] = modules
    
    if needs_save:
        print("[Panel] Saving fixed group/expand configuration...")
        wm.save_config(config, is_dock=False)


def _build_main_panel_content(window) -> Gtk.Box:
    """Build main panel configuration content"""
    content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16)
    content.set_margin_start(32)
    content.set_margin_end(32)
    content.set_margin_top(16)
    content.set_margin_bottom(16)
    
    wm = window.waybar_manager
    
    # MODULE LAYOUT SECTION
    modules_group = SettingsGroup("Module Layout")
    
    info = Gtk.Label(label="Drag and drop modules to rearrange. Click + to add new modules.")
    info.add_css_class('setting-description')
    info.set_wrap(True)
    info.set_halign(Gtk.Align.START)
    info.set_margin_bottom(12)
    modules_group.append(info)
    
    zones_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
    zones_box.set_homogeneous(True)
    
    for pos in ['left', 'center', 'right']:
        modules = wm.get_modules(pos, is_dock=False)
        zone = create_module_drop_zone(
            pos, modules,
            lambda p: _on_add_module(window, p, is_dock=False),
            lambda p, m: _on_remove_module(window, p, m, is_dock=False),
            lambda p, data: _on_reorder_modules(window, p, data, is_dock=False)
        )
        zones_box.append(zone)
    
    modules_group.append(zones_box)
    content.append(modules_group)
    
    # ═══════════════════════════════════════════════════════════════
    # GROUP/EXPAND DRAWER CONFIGURATION - WITH PERSISTENCE!
    # ═══════════════════════════════════════════════════════════════
    
    drawer_group = SettingsGroup("Expandable Drawer (group/expand)")
    
    drawer_info = Gtk.Label()
    drawer_info.set_markup("<small>Configure which modules appear in the expandable drawer.\nClick the 󰁌 icon on your panel to expand/collapse.</small>")
    drawer_info.add_css_class('setting-description')
    drawer_info.set_wrap(True)
    drawer_info.set_halign(Gtk.Align.START)
    drawer_info.set_margin_bottom(12)
    drawer_group.append(drawer_info)
    
    # ═══════════════════════════════════════════════════════════════
    # LOAD SAVED PREFERENCES - Key fix for persistence!
    # ═══════════════════════════════════════════════════════════════
    saved_prefs = load_drawer_preferences()
    current_drawer_modules = saved_prefs.get("enabled_modules", DEFAULT_DRAWER_CONFIG["enabled_modules"])
    
    window._drawer_checkboxes = {}
    
    modules_flow = Gtk.FlowBox()
    modules_flow.set_selection_mode(Gtk.SelectionMode.NONE)
    modules_flow.set_max_children_per_line(3)
    modules_flow.set_min_children_per_line(2)
    modules_flow.set_column_spacing(12)
    modules_flow.set_row_spacing(8)
    modules_flow.set_homogeneous(True)
    
    for module_id, module_name, icon_name in DRAWER_AVAILABLE_MODULES:
        item_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        item_box.set_margin_start(8)
        item_box.set_margin_end(8)
        item_box.set_margin_top(4)
        item_box.set_margin_bottom(4)
        
        check = Gtk.CheckButton()
        # USE SAVED PREFERENCES for initial state!
        check.set_active(module_id in current_drawer_modules)
        window._drawer_checkboxes[module_id] = check
        item_box.append(check)
        
        icon = Gtk.Image.new_from_icon_name(icon_name)
        icon.set_pixel_size(16)
        item_box.append(icon)
        
        label = Gtk.Label(label=module_name)
        label.set_halign(Gtk.Align.START)
        item_box.append(label)
        
        modules_flow.append(item_box)
    
    drawer_group.append(modules_flow)
    
    # Drawer settings row
    drawer_settings_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=16)
    drawer_settings_box.set_margin_top(12)
    
    # Animation duration - USE SAVED VALUE
    duration_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
    duration_label = Gtk.Label(label="Animation Duration:")
    duration_label.add_css_class('setting-description')
    duration_box.append(duration_label)
    
    duration_spin = Gtk.SpinButton.new_with_range(100, 2000, 50)
    duration_spin.set_value(saved_prefs.get("animation_duration", 600))
    duration_spin.set_tooltip_text("Drawer animation duration in milliseconds")
    window._drawer_duration_spin = duration_spin
    duration_box.append(duration_spin)
    
    ms_label = Gtk.Label(label="ms")
    ms_label.add_css_class('dim-label')
    duration_box.append(ms_label)
    drawer_settings_box.append(duration_box)
    
    # Direction - USE SAVED VALUE
    direction_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
    direction_label = Gtk.Label(label="Expand Direction:")
    direction_label.add_css_class('setting-description')
    direction_box.append(direction_label)
    
    direction_dd = Gtk.DropDown()
    direction_dd.set_model(Gtk.StringList.new(["← Left", "→ Right"]))
    saved_direction = saved_prefs.get("expand_direction", "left")
    direction_dd.set_selected(0 if saved_direction == "left" else 1)
    direction_dd.set_tooltip_text("Direction the drawer expands")
    window._drawer_direction_dd = direction_dd
    direction_box.append(direction_dd)
    drawer_settings_box.append(direction_box)
    
    drawer_group.append(drawer_settings_box)
    
    # Expand icon selector - USE SAVED VALUE
    icon_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
    icon_box.set_margin_top(8)
    
    icon_label = Gtk.Label(label="Expand Icon:")
    icon_label.add_css_class('setting-description')
    icon_box.append(icon_label)
    
    icon_display_names = [f"{data[1]} {data[2]}" for data in EXPAND_ICON_OPTIONS]
    icon_keys = [data[0] for data in EXPAND_ICON_OPTIONS]
    icon_values = [data[1] for data in EXPAND_ICON_OPTIONS]
    
    icon_dd = Gtk.DropDown()
    icon_dd.set_model(Gtk.StringList.new(icon_display_names))
    
    saved_icon_key = saved_prefs.get("expand_icon", "chevron_left")
    current_idx = 0
    for i, key in enumerate(icon_keys):
        if key == saved_icon_key:
            current_idx = i
            break
    icon_dd.set_selected(current_idx)
    
    window._drawer_icon_dd = icon_dd
    window._drawer_icon_keys = icon_keys
    window._drawer_icon_values = icon_values
    icon_box.append(icon_dd)
    drawer_group.append(icon_box)
    
    # Apply drawer button
    drawer_btn_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
    drawer_btn_box.set_margin_top(12)
    drawer_btn_box.set_halign(Gtk.Align.END)
    
    apply_drawer_btn = Gtk.Button(label="Apply Drawer Config")
    apply_drawer_btn.add_css_class('suggested-action')
    apply_drawer_btn.connect('clicked', lambda b: _apply_drawer_config(window))
    drawer_btn_box.append(apply_drawer_btn)
    drawer_group.append(drawer_btn_box)
    
    content.append(drawer_group)
    
    # ACTION BUTTONS
    content.append(window._create_action_buttons(
        on_reset=lambda b: _on_panel_reset(window, is_dock=False),
        on_apply=lambda b: _on_panel_apply(window, is_dock=False)
    ))
    
    return content


def _apply_drawer_config(window):
    """Apply drawer configuration - SAVES PREFERENCES + UPDATES WAYBAR"""
    wm = window.waybar_manager
    
    # Collect selected modules
    selected_modules = []
    for module_id, checkbox in window._drawer_checkboxes.items():
        if checkbox.get_active():
            selected_modules.append(module_id)
    
    if not selected_modules:
        window._show_toast("Please select at least one module for the drawer")
        return
    
    # Get settings
    duration = int(window._drawer_duration_spin.get_value())
    to_left = window._drawer_direction_dd.get_selected() == 0
    direction = "left" if to_left else "right"
    
    icon_idx = window._drawer_icon_dd.get_selected()
    expand_icon_key = window._drawer_icon_keys[icon_idx] if icon_idx < len(window._drawer_icon_keys) else "chevron_left"
    expand_icon_value = window._drawer_icon_values[icon_idx] if icon_idx < len(window._drawer_icon_values) else ""
    
    # ═══════════════════════════════════════════════════════════════
    # SAVE PREFERENCES TO FILE (for persistence!)
    # ═══════════════════════════════════════════════════════════════
    prefs = {
        "enabled_modules": selected_modules,
        "animation_duration": duration,
        "expand_direction": direction,
        "expand_icon": expand_icon_key,
        "click_to_reveal": True
    }
    save_drawer_preferences(prefs)
    
    # ═══════════════════════════════════════════════════════════════
    # UPDATE WAYBAR CONFIG.JSONC
    # ═══════════════════════════════════════════════════════════════
    drawer_modules = ["custom/expand"] + selected_modules + ["custom/endpoint"]
    
    group_expand_config = {
        "orientation": "horizontal",
        "drawer": {
            "transition-duration": duration,
            "transition-to-left": to_left,
            "click-to-reveal": True
        },
        "modules": drawer_modules
    }
    
    # Update custom/expand with selected icon
    wm.main_config["custom/expand"] = {
        "format": expand_icon_value if expand_icon_value else "",
        "tooltip": False
    }
    
    if "custom/endpoint" not in wm.main_config:
        wm.main_config["custom/endpoint"] = {"format": "|", "tooltip": False}
    
    wm.main_config["group/expand"] = group_expand_config
    
    # Ensure group/expand is in modules-right
    modules_right = wm.main_config.get("modules-right", [])
    if "group/expand" not in modules_right:
        modules_right.insert(0, "group/expand")
        wm.main_config["modules-right"] = modules_right
    
    # Ensure all enabled modules have configs
    _ensure_module_configs(wm.main_config, selected_modules)
    
    # Save and reload
    wm.save_config(wm.main_config, is_dock=False)
    wm.reload_waybar()
    
    window._show_toast(f"✅ Drawer configured with {len(selected_modules)} modules")
    print(f"[Panel] Applied drawer config: {selected_modules}")


def _ensure_module_configs(config: dict, enabled_modules: list):
    """Ensure all enabled modules have basic configs"""
    HOME = Path.home()
    HYPR_CONTROL_CENTER = HOME / ".config/hypr-control-center"
    ALACRITTY_DIR = HOME / ".config/alacritty"
    KITTY_MODULES = HOME / ".config/kitty/modules"
    
    module_defaults = {
        "battery": {
            "interval": 5, "states": {"warning": 30, "critical": 15},
            "format": " {icon} ", "format-charging": " {icon} ", "format-plugged": " {icon} ",
            "format-icons": ["", "", "", "", ""],
            "tooltip": True, "tooltip-format": "Battery: {capacity}%"
        },
        "backlight": {
            "format": " {icon} ", "format-icons": ["󰃞", "󰃟", "󰃠"],
            "tooltip": True, "tooltip-format": "Brightness: {percent}%",
            "on-scroll-up": "brightnessctl set +5%", "on-scroll-down": "brightnessctl set 5%-"
        },
        "disk": {
            "interval": 30, "format": " 󰋊 ", "path": "/",
            "tooltip": True, "tooltip-format": "Disk: {used} / {total} ({percentage_used}%)"
        },
        "pulseaudio": {
            "scroll-step": 10, "format": " {icon}", "format-muted": "",
            "format-icons": {"headphone": "", "default": ["", "", ""]},
            "tooltip": True, "tooltip-format": "Volume: {volume}%",
            "on-click": str(KITTY_MODULES / "audiotop.sh"), "on-click-right": "pavucontrol"
        },
        "cpu": {
            "interval": 1, "format": " {icon}",
            "format-icons": ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"],
            "tooltip": True, "tooltip-format": "CPU: {usage}%",
            "on-click": str(ALACRITTY_DIR / "btmrun.sh")
        },
        "memory": {
            "interval": 1, "format": " {icon}",
            "format-icons": ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"],
            "tooltip": True, "tooltip-format": "Memory: {used:0.1f}G / {total:0.1f}G",
            "on-click": str(ALACRITTY_DIR / "btmrun.sh")
        },
        "temperature": {
            "format": " {icon}", "format-icons": ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"],
            "tooltip": True, "tooltip-format": "Temperature: {temperatureC}°C"
        },
        "network": {
            "interval": 1, "format-wifi": " {icon} ", "format-ethernet": " {icon} ", "format-disconnected": "󰤮",
            "format-icons": {"wifi": ["󰤯", "󰤟", "󰤢", "󰤥", "󰤨"], "ethernet": "󰈀"},
            "tooltip": True, "on-click": str(HYPR_CONTROL_CENTER / "scripts/wifi_selector.py")
        },
        "bluetooth": {
            "format": " ", "format-disabled": " ", "format-connected": " {num_connections} ",
            "tooltip": True, "on-click": str(ALACRITTY_DIR / "bluetoothrun.sh"), "on-click-right": "blueman-manager"
        },
        "custom/pacman": {
            "exec": str(HYPR_CONTROL_CENTER / "scripts/pacman-updates.sh"),
            "return-type": "json", "interval": 3600, "format": "󰏔 {}", "tooltip": True,
            "on-click": str(HYPR_CONTROL_CENTER / "scripts/pacman-updates.sh --update"),
            "on-click-right": str(HYPR_CONTROL_CENTER / "scripts/pacman-updates.sh --refresh")
        }
    }
    
    for module_id in enabled_modules:
        if module_id not in config and module_id in module_defaults:
            config[module_id] = module_defaults[module_id]
            print(f"[Panel] Added missing module config: {module_id}")


# ═══════════════════════════════════════════════════════════════════
# MODULE HELPER FUNCTIONS
# ═══════════════════════════════════════════════════════════════════

def _on_add_module(window, position: str, is_dock: bool):
    """Show dialog to add a module"""
    wm = window.waybar_manager
    all_modules = list(wm.get_available_modules())
    
    special_modules = ['group/expand', 'tray', 'custom/expand', 'custom/endpoint']
    for sm in special_modules:
        if sm not in all_modules:
            all_modules.append(sm)
    
    used_modules = []
    for pos in ['left', 'center', 'right']:
        used_modules.extend(wm.get_modules(pos, is_dock=is_dock))
    
    available_modules = [m for m in all_modules if m not in used_modules]
    
    if not available_modules:
        window._show_toast("All modules are already in use!")
        return
    
    dialog = Adw.MessageDialog(
        transient_for=window,
        heading=f"Add Module to {position.upper()}",
        body="Select a module to add:"
    )
    
    list_box = Gtk.ListBox()
    list_box.set_selection_mode(Gtk.SelectionMode.SINGLE)
    list_box.add_css_class('boxed-list')
    
    for module in sorted(available_modules):
        row = Gtk.ListBoxRow()
        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        box.set_margin_top(8)
        box.set_margin_bottom(8)
        box.set_margin_start(12)
        box.set_margin_end(12)
        
        icon = Gtk.Image.new_from_icon_name(_get_module_icon(module))
        icon.set_pixel_size(24)
        box.append(icon)
        
        display_name = _get_module_display_name(module)
        if module == 'group/expand':
            display_name += " (Collapsible Drawer)"
        
        label = Gtk.Label(label=display_name)
        label.set_halign(Gtk.Align.START)
        label.set_hexpand(True)
        box.append(label)
        
        row.set_child(box)
        row.module_name = module
        list_box.append(row)
    
    scrolled = Gtk.ScrolledWindow()
    scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
    scrolled.set_min_content_height(200)
    scrolled.set_max_content_height(400)
    scrolled.set_child(list_box)
    
    dialog.set_extra_child(scrolled)
    dialog.add_response("cancel", "Cancel")
    dialog.add_response("add", "Add")
    dialog.set_response_appearance("add", Adw.ResponseAppearance.SUGGESTED)
    dialog.set_default_response("add")
    
    def on_response(dialog, response):
        if response == "add":
            selected_row = list_box.get_selected_row()
            if selected_row:
                module = selected_row.module_name
                if module == 'group/expand':
                    _ensure_group_expand_config(wm)
                wm.add_module(position, module, is_dock=is_dock)
                _on_panel_apply(window, is_dock=is_dock)
                window._show_toast(f"Added {module} to {position}")
                _refresh_panel_page(window, is_dock=is_dock)
    
    dialog.connect('response', on_response)
    dialog.present()


def _ensure_group_expand_config(wm):
    """Ensure group/expand and its dependencies are properly configured"""
    config = wm.main_config
    
    if "custom/expand" not in config:
        config["custom/expand"] = {"format": "", "tooltip": False}
    elif not config["custom/expand"].get("format"):
        config["custom/expand"]["format"] = ""
    
    if "custom/endpoint" not in config:
        config["custom/endpoint"] = {"format": "|", "tooltip": False}
    
    if "group/expand" not in config:
        saved_prefs = load_drawer_preferences()
        enabled = saved_prefs.get("enabled_modules", DEFAULT_DRAWER_CONFIG["enabled_modules"])
        
        config["group/expand"] = {
            "orientation": "horizontal",
            "drawer": {
                "transition-duration": saved_prefs.get("animation_duration", 600),
                "transition-to-left": saved_prefs.get("expand_direction", "left") == "left",
                "click-to-reveal": True
            },
            "modules": ["custom/expand"] + enabled + ["custom/endpoint"]
        }
    else:
        if "drawer" not in config["group/expand"]:
            config["group/expand"]["drawer"] = {"transition-duration": 600, "transition-to-left": True, "click-to-reveal": True}
        modules = config["group/expand"].get("modules", [])
        if "custom/expand" not in modules:
            modules.insert(0, "custom/expand")
        if "custom/endpoint" not in modules:
            modules.append("custom/endpoint")
        config["group/expand"]["modules"] = modules


def _refresh_panel_page(window, is_dock: bool = False):
    """Refresh panel page to show updated module layout"""
    page_name = "panel" if not is_dock else "dock"
    old_page = window.stack.get_child_by_name(page_name)

    vadj_value = 0
    if isinstance(old_page, Gtk.ScrolledWindow):
        vadj = old_page.get_vadjustment()
        vadj_value = vadj.get_value()

    new_page = build_panel_page(window)

    if old_page:
        window.stack.remove(old_page)

    window.stack.add_named(new_page, page_name)
    window.stack.set_visible_child_name(page_name)

    def restore_scroll():
        vadj = new_page.get_vadjustment()
        vadj.set_value(vadj_value)
        return False

    GLib.idle_add(restore_scroll)


def _get_module_icon(module: str) -> str:
    """Get icon name for module"""
    icons = {
        'clock': 'preferences-system-time-symbolic', 'hyprland/workspaces': 'view-grid-symbolic',
        'hyprland/window': 'window-symbolic', 'custom/taskbar': 'view-list-symbolic',
        'custom/pinned': 'pin-symbolic', 'custom/music': 'multimedia-player-symbolic',
        'custom/pacman': 'system-software-update-symbolic', 'custom/expand': 'go-previous-symbolic',
        'custom/endpoint': 'list-remove-symbolic', 'group/expand': 'view-more-symbolic',
        'tray': 'system-tray-symbolic', 'pulseaudio': 'audio-volume-high-symbolic',
        'network': 'network-wireless-symbolic', 'battery': 'battery-symbolic',
        'custom/notification': 'notification-symbolic', 'cpu': 'utilities-system-monitor-symbolic',
        'memory': 'drive-harddisk-symbolic', 'disk': 'drive-harddisk-symbolic',
        'temperature': 'sensors-temperature-symbolic', 'backlight': 'display-brightness-symbolic',
        'bluetooth': 'bluetooth-symbolic', 'wlr/taskbar': 'view-list-symbolic',
        'custom/start-menu': 'start-here-symbolic'
    }
    return icons.get(module, 'application-x-executable-symbolic')


def _get_module_display_name(module: str) -> str:
    """Get display name for module"""
    names = {
        'clock': 'Clock', 'hyprland/workspaces': 'Workspaces', 'hyprland/window': 'Active Window Title',
        'tray': 'System Tray', 'pulseaudio': 'Audio', 'network': 'Network', 'battery': 'Battery',
        'bluetooth': 'Bluetooth', 'cpu': 'CPU Usage', 'memory': 'Memory Usage', 'disk': 'Disk Usage',
        'temperature': 'Temperature', 'backlight': 'Brightness', 'custom/notification': 'Notifications',
        'custom/taskbar': 'Taskbar', 'custom/pinned': 'Pinned Apps', 'custom/music': 'Music Player',
        'custom/pacman': 'System Updates (Pacman)', 'custom/expand': 'Drawer Toggle',
        'custom/endpoint': 'Drawer End Marker', 'group/expand': 'Expandable Drawer',
        'wlr/taskbar': 'WLR Taskbar', 'custom/start-menu': 'Start Menu'
    }
    return names.get(module, module.replace('/', ' ').title())


def _on_remove_module(window, position: str, module: str, is_dock: bool):
    """Remove a module from position"""
    window.waybar_manager.remove_module(position, module, is_dock=is_dock)
    _on_panel_apply(window, is_dock=is_dock)
    window._show_toast(f"Removed {module} from {position}")
    _refresh_panel_page(window, is_dock=is_dock)


def _on_reorder_modules(window, position: str, data: str, is_dock: bool):
    """Handle module reordering via drag and drop"""
    parts = data.split(':')
    wm = window.waybar_manager
    
    if len(parts) >= 4:
        from_pos, from_module, to_pos = parts[0], parts[1], parts[2]
        
        if len(parts) == 4 and parts[3] == 'append':
            if from_pos == to_pos:
                modules = wm.get_modules(to_pos, is_dock)
                if from_module in modules:
                    modules.remove(from_module)
                    modules.append(from_module)
                    wm.set_modules(to_pos, modules, is_dock)
            else:
                wm.move_module(from_pos, to_pos, from_module, is_dock)
            
            window._show_toast(f"Moved {from_module} to {to_pos}")
            _on_panel_apply(window, is_dock)
            _refresh_panel_page(window, is_dock)
            
        elif len(parts) == 5:
            target_module = parts[3]
            insert_before = parts[4] == 'before'
            
            if from_pos == to_pos:
                modules = wm.get_modules(to_pos, is_dock)
                if from_module in modules and target_module in modules:
                    modules.remove(from_module)
                    target_idx = modules.index(target_module)
                    modules.insert(target_idx if insert_before else target_idx + 1, from_module)
                    wm.set_modules(to_pos, modules, is_dock)
                    window._show_toast(f"Reordered {from_module} in {to_pos}")
            else:
                wm.remove_module(from_pos, from_module, is_dock)
                modules = wm.get_modules(to_pos, is_dock)
                if target_module in modules:
                    target_idx = modules.index(target_module)
                    modules.insert(target_idx if insert_before else target_idx + 1, from_module)
                else:
                    modules.append(from_module)
                wm.set_modules(to_pos, modules, is_dock)
                window._show_toast(f"Moved {from_module} from {from_pos} to {to_pos}")
            
            _on_panel_apply(window, is_dock)
            _refresh_panel_page(window, is_dock)
    
    elif len(parts) == 2:
        from_pos, module = parts
        if from_pos != position:
            wm.move_module(from_pos, position, module, is_dock=is_dock)
            window._show_toast(f"Moved {module} from {from_pos} to {position}")
            _on_panel_apply(window, is_dock)
            _refresh_panel_page(window, is_dock)


def _on_panel_reset(window, is_dock: bool):
    """Reset panel to default configuration"""
    panel_type = "Dock" if is_dock else "Main Panel"
    
    dialog = Adw.MessageDialog(
        transient_for=window,
        heading=f"Reset {panel_type}?",
        body=f"This will restore the {panel_type.lower()} to default configuration.\nDrawer preferences will also be reset."
    )
    dialog.add_response("cancel", "Cancel")
    dialog.add_response("reset", "Reset")
    dialog.set_response_appearance("reset", Adw.ResponseAppearance.DESTRUCTIVE)
    dialog.connect('response', lambda d, r: _on_panel_reset_response(window, d, r, is_dock))
    dialog.present()


def _on_panel_reset_response(window, dialog, response, is_dock: bool):
    """Handle panel reset confirmation"""
    if response == "reset":
        wm = window.waybar_manager
        default_config = wm.create_default_config(is_dock=is_dock)
        
        if is_dock:
            wm.dock_config = default_config
        else:
            wm.main_config = default_config
        
        # Reset drawer preferences too
        save_drawer_preferences(DEFAULT_DRAWER_CONFIG)
        
        wm.save_config(default_config, is_dock=is_dock)
        wm.reload_waybar()
        _refresh_panel_page(window, is_dock=is_dock)
        window._show_toast("Panel reset to default")


def _on_panel_apply(window, is_dock: bool):
    """Apply panel changes"""
    wm = window.waybar_manager
    
    if is_dock:
        wm.save_config(wm.dock_config, is_dock=True)
    else:
        wm.save_config(wm.main_config, is_dock=False)
    
    wm.reload_waybar()
    window._show_toast("Panel configuration applied!")