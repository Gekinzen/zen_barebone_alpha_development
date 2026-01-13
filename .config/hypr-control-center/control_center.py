#!/usr/bin/env python3
"""
Hyprland Control Center
A Cosmic-inspired control panel for Hyprland configuration
Location: ~/.config/hypr-control-center/
"""

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
gi.require_version('Gdk', '4.0')
from gi.repository import Gtk, Adw, Gdk, GLib, Gio, Pango
import os
import re
import shutil
import subprocess
from pathlib import Path
from dataclasses import dataclass, field
from typing import Optional, Dict, Any, List, Callable

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION PATHS
# ═══════════════════════════════════════════════════════════════════════════════

HOME = Path.home()
CONFIG_DIR = HOME / ".config" / "hypr"
MODULES_DIR = CONFIG_DIR / "modules"
DEFAULT_DIR = MODULES_DIR / "default"
WAYBAR_DIR = HOME / ".config" / "waybar"

# Config files
LOOK_AND_FEEL_CONF = MODULES_DIR / "look_and_feel.conf"
ANIMATIONS_CONF = CONFIG_DIR / "hyprland.conf"  # animations are in main conf
MONITORS_CONF = MODULES_DIR / "monitors.conf"
BINDS_CONF = MODULES_DIR / "binds.conf"
AUTOSTART_CONF = MODULES_DIR / "autostart.conf"

# One Dark color palette
ONE_DARK = {
    'bg0': '#282c34',
    'bg1': '#21252b',
    'bg2': '#2c313a',
    'bg3': '#3e4451',
    'bg4': '#4b5263',
    'red': '#e06c75',
    'orange': '#d19a66',
    'yellow': '#e5c07b',
    'green': '#98c379',
    'aqua': '#56b6c2',
    'blue': '#61afef',
    'purple': '#c678dd',
    'fg': '#abb2bf',
    'grey0': '#5c6370',
    'grey1': '#828997',
    'grey2': '#abb2bf',
}

# ═══════════════════════════════════════════════════════════════════════════════
# DATA CLASSES
# ═══════════════════════════════════════════════════════════════════════════════

@dataclass
class GeneralConfig:
    gaps_in: int = 8
    gaps_out: int = 18
    border_size: int = 1
    col_active_border: str = "rgba(83a598aa)"
    col_active_border_angle: int = 45
    col_inactive_border: str = "rgba(595959aa)"
    resize_on_border: bool = False
    allow_tearing: bool = False
    layout: str = "dwindle"

@dataclass
class DecorationConfig:
    rounding: int = 14
    rounding_power: int = 3
    active_opacity: float = 1.0
    inactive_opacity: float = 1.0
    shadow_enabled: bool = True
    shadow_range: int = 15
    shadow_render_power: int = 3
    shadow_color: str = "rgba(121212ee)"
    blur_enabled: bool = True
    blur_size: int = 7
    blur_passes: int = 3
    blur_vibrancy: float = 0.1696

@dataclass
class AnimationConfig:
    enabled: bool = True
    # Bezier curves
    bezier_easeOutQuint: str = "0.23, 1, 0.32, 1"
    bezier_easeInOutCubic: str = "0.65, 0.05, 0.36, 1"
    # Animation settings
    global_speed: int = 10
    border_speed: float = 5.39
    windows_speed: float = 4.79
    windowsIn_speed: float = 4.1
    windowsOut_speed: float = 1.49
    fade_speed: float = 1.73
    workspaces_speed: float = 2.39

@dataclass
class InputConfig:
    kb_layout: str = "us"
    follow_mouse: int = 1
    sensitivity: float = 0.0
    accel_profile: str = "flat"
    touchpad_natural_scroll: bool = True
    touchpad_disable_while_typing: bool = True
    touchpad_tap_to_click: bool = True

@dataclass
class MonitorConfig:
    name: str = ""
    resolution: str = "preferred"
    position: str = "auto"
    scale: float = 1.0
    transform: int = 0
    enabled: bool = True

@dataclass 
class WaybarConfig:
    position: str = "top"
    height: int = 34
    margin_top: int = 0
    margin_bottom: int = 0
    margin_left: int = 0
    margin_right: int = 0
    spacing: int = 4

@dataclass
class WorkspaceRule:
    workspace: int = 1
    monitor: str = ""
    default: bool = False
    persistent: bool = False

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIG MANAGER
# ═══════════════════════════════════════════════════════════════════════════════

class HyprlandConfigManager:
    """Manages reading and writing of Hyprland configuration files"""
    
    def __init__(self):
        self.general = GeneralConfig()
        self.decoration = DecorationConfig()
        self.animation = AnimationConfig()
        self.input = InputConfig()
        self.monitors: List[MonitorConfig] = []
        self.waybar = WaybarConfig()
        self.waybar2 = WaybarConfig()  # For dock mode
        self.workspace_rules: List[WorkspaceRule] = []
        
    def parse_look_and_feel(self) -> bool:
        """Parse look_and_feel.conf"""
        if not LOOK_AND_FEEL_CONF.exists():
            return False
            
        content = LOOK_AND_FEEL_CONF.read_text()
        
        # Parse general section
        general_match = re.search(r'general\s*\{([^}]+)\}', content, re.DOTALL)
        if general_match:
            self._parse_general(general_match.group(1))
            
        # Parse decoration section
        decoration_match = re.search(r'decoration\s*\{(.+?)^\}', content, re.DOTALL | re.MULTILINE)
        if decoration_match:
            self._parse_decoration(decoration_match.group(1))
            
        return True
    
    def _parse_general(self, content: str):
        """Parse general section values"""
        patterns = {
            'gaps_in': (r'gaps_in\s*=\s*(\d+)', int),
            'gaps_out': (r'gaps_out\s*=\s*(\d+)', int),
            'border_size': (r'border_size\s*=\s*(\d+)', int),
            'resize_on_border': (r'resize_on_border\s*=\s*(true|false)', lambda x: x.lower() == 'true'),
            'allow_tearing': (r'allow_tearing\s*=\s*(true|false)', lambda x: x.lower() == 'true'),
            'layout': (r'layout\s*=\s*(\w+)', str),
        }
        
        for attr, (pattern, converter) in patterns.items():
            match = re.search(pattern, content, re.IGNORECASE)
            if match:
                setattr(self.general, attr, converter(match.group(1)))
        
        # Parse colors
        active_match = re.search(r'col\.active_border\s*=\s*(rgba\([^)]+\))\s*(\d+deg)?', content)
        if active_match:
            self.general.col_active_border = active_match.group(1)
            if active_match.group(2):
                self.general.col_active_border_angle = int(active_match.group(2).replace('deg', ''))
                
        inactive_match = re.search(r'col\.inactive_border\s*=\s*(rgba\([^)]+\))', content)
        if inactive_match:
            self.general.col_inactive_border = inactive_match.group(1)
    
    def _parse_decoration(self, content: str):
        """Parse decoration section"""
        patterns = {
            'rounding': (r'^\s*rounding\s*=\s*(\d+)', int),
            'rounding_power': (r'rounding_power\s*=\s*(\d+)', int),
            'active_opacity': (r'active_opacity\s*=\s*([\d.]+)', float),
            'inactive_opacity': (r'inactive_opacity\s*=\s*([\d.]+)', float),
        }
        
        for attr, (pattern, converter) in patterns.items():
            match = re.search(pattern, content, re.MULTILINE)
            if match:
                setattr(self.decoration, attr, converter(match.group(1)))
        
        # Parse shadow
        shadow_match = re.search(r'shadow\s*\{([^}]+)\}', content, re.DOTALL)
        if shadow_match:
            shadow = shadow_match.group(1)
            if m := re.search(r'enabled\s*=\s*(true|false)', shadow, re.I):
                self.decoration.shadow_enabled = m.group(1).lower() == 'true'
            if m := re.search(r'range\s*=\s*(\d+)', shadow):
                self.decoration.shadow_range = int(m.group(1))
            if m := re.search(r'color\s*=\s*(rgba\([^)]+\))', shadow):
                self.decoration.shadow_color = m.group(1)
        
        # Parse blur
        blur_match = re.search(r'blur\s*\{([^}]+)\}', content, re.DOTALL)
        if blur_match:
            blur = blur_match.group(1)
            if m := re.search(r'enabled\s*=\s*(true|false)', blur, re.I):
                self.decoration.blur_enabled = m.group(1).lower() == 'true'
            if m := re.search(r'size\s*=\s*(\d+)', blur):
                self.decoration.blur_size = int(m.group(1))
            if m := re.search(r'passes\s*=\s*(\d+)', blur):
                self.decoration.blur_passes = int(m.group(1))
            if m := re.search(r'vibrancy\s*=\s*([\d.]+)', blur):
                self.decoration.blur_vibrancy = float(m.group(1))

    def generate_look_and_feel(self) -> str:
        """Generate look_and_feel.conf content"""
        return f'''#####################
### LOOK AND FEEL ###
#####################

# Refer to https://wiki.hypr.land/Configuring/Variables/

# https://wiki.hypr.land/Configuring/Variables/#general
general {{
    gaps_in = {self.general.gaps_in}
    gaps_out = {self.general.gaps_out}
    border_size = {self.general.border_size}

    # https://wiki.hypr.land/Configuring/Variables/#variable-types for info about colors
    col.active_border = {self.general.col_active_border} {self.general.col_active_border_angle}deg
    col.inactive_border = {self.general.col_inactive_border}

    # Set to true enable resizing windows by clicking and dragging on borders and gaps
    resize_on_border = {str(self.general.resize_on_border).lower()}

    # Please see https://wiki.hypr.land/Configuring/Tearing/ before you turn this on
    allow_tearing = {str(self.general.allow_tearing).lower()}

    layout = {self.general.layout}
}}

# https://wiki.hypr.land/Configuring/Variables/#decoration
decoration {{
    rounding = {self.decoration.rounding}
    rounding_power = {self.decoration.rounding_power}

    # Change transparency of focused and unfocused windows
    active_opacity = {self.decoration.active_opacity}
    inactive_opacity = {self.decoration.inactive_opacity}

    shadow {{
        enabled = {str(self.decoration.shadow_enabled).lower()}
        range = {self.decoration.shadow_range}
        render_power = {self.decoration.shadow_render_power}
        color = {self.decoration.shadow_color}
    }}

    # https://wiki.hypr.land/Configuring/Variables/#blur
    blur {{
        enabled = {str(self.decoration.blur_enabled).lower()}
        size = {self.decoration.blur_size}
        passes = {self.decoration.blur_passes}
        vibrancy = {self.decoration.blur_vibrancy}
    }}
}}
'''
    
    def save_look_and_feel(self):
        """Save look_and_feel.conf"""
        MODULES_DIR.mkdir(parents=True, exist_ok=True)
        LOOK_AND_FEEL_CONF.write_text(self.generate_look_and_feel())
        self._reload_hyprland()
    
    def reset_look_and_feel(self) -> bool:
        """Reset from default"""
        default = DEFAULT_DIR / "look_and_feel.conf"
        if default.exists():
            shutil.copy(default, LOOK_AND_FEEL_CONF)
            self.parse_look_and_feel()
            self._reload_hyprland()
            return True
        return False
    
    def _reload_hyprland(self):
        """Reload Hyprland config"""
        try:
            subprocess.run(['hyprctl', 'reload'], check=False, capture_output=True)
        except Exception:
            pass

# ═══════════════════════════════════════════════════════════════════════════════
# COLOR UTILITIES
# ═══════════════════════════════════════════════════════════════════════════════

def rgba_to_gdk(rgba_str: str) -> Gdk.RGBA:
    """Convert hyprland rgba to Gdk.RGBA"""
    match = re.match(r'rgba\(([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2})\)', rgba_str)
    if match:
        r, g, b, a = match.groups()
        color = Gdk.RGBA()
        color.red = int(r, 16) / 255.0
        color.green = int(g, 16) / 255.0
        color.blue = int(b, 16) / 255.0
        color.alpha = int(a, 16) / 255.0
        return color
    color = Gdk.RGBA()
    color.parse("#83a598")
    return color

def gdk_to_rgba(color: Gdk.RGBA) -> str:
    """Convert Gdk.RGBA to hyprland rgba"""
    r = int(color.red * 255)
    g = int(color.green * 255)
    b = int(color.blue * 255)
    a = int(color.alpha * 255)
    return f"rgba({r:02x}{g:02x}{b:02x}{a:02x})"

# ═══════════════════════════════════════════════════════════════════════════════
# CUSTOM WIDGETS
# ═══════════════════════════════════════════════════════════════════════════════

class SettingRow(Gtk.Box):
    """Base class for setting rows"""
    
    def __init__(self, label: str, description: str = ""):
        super().__init__(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        self.add_css_class('setting-row')
        self.set_margin_top(8)
        self.set_margin_bottom(8)
        
        # Label container
        label_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        label_box.set_hexpand(True)
        label_box.set_valign(Gtk.Align.CENTER)
        
        lbl = Gtk.Label(label=label)
        lbl.set_halign(Gtk.Align.START)
        lbl.add_css_class('setting-label')
        label_box.append(lbl)
        
        if description:
            desc = Gtk.Label(label=description)
            desc.set_halign(Gtk.Align.START)
            desc.add_css_class('setting-description')
            label_box.append(desc)
        
        self.append(label_box)

class ColorPickerRow(SettingRow):
    """Color picker with value display"""
    
    def __init__(self, label: str, rgba_value: str, callback: Callable, description: str = ""):
        super().__init__(label, description)
        self.callback = callback
        
        # Value label
        self.value_label = Gtk.Label(label=rgba_value)
        self.value_label.add_css_class('value-mono')
        self.value_label.set_selectable(True)
        self.append(self.value_label)
        
        # Color button
        self.color_btn = Gtk.ColorButton()
        self.color_btn.set_use_alpha(True)
        self.color_btn.set_rgba(rgba_to_gdk(rgba_value))
        self.color_btn.connect('color-set', self._on_color_set)
        self.color_btn.add_css_class('color-button')
        self.append(self.color_btn)
        
    def _on_color_set(self, button):
        rgba_str = gdk_to_rgba(button.get_rgba())
        self.value_label.set_label(rgba_str)
        if self.callback:
            self.callback(rgba_str)
    
    def set_value(self, rgba_value: str):
        self.color_btn.set_rgba(rgba_to_gdk(rgba_value))
        self.value_label.set_label(rgba_value)

class IntegerRow(SettingRow):
    """Integer input with spin button"""
    
    def __init__(self, label: str, value: int, min_val: int, max_val: int, 
                 callback: Callable, description: str = ""):
        super().__init__(label, description)
        self.callback = callback
        
        adjustment = Gtk.Adjustment(value=value, lower=min_val, upper=max_val, step_increment=1)
        self.spin = Gtk.SpinButton(adjustment=adjustment)
        self.spin.set_numeric(True)
        self.spin.set_width_chars(6)
        self.spin.connect('value-changed', self._on_changed)
        self.spin.add_css_class('spin-input')
        self.append(self.spin)
        
    def _on_changed(self, spin):
        if self.callback:
            self.callback(int(spin.get_value()))
    
    def set_value(self, value: int):
        self.spin.set_value(value)
    
    def get_value(self) -> int:
        return int(self.spin.get_value())

class FloatRow(SettingRow):
    """Float input with slider and value display"""
    
    def __init__(self, label: str, value: float, min_val: float, max_val: float,
                 callback: Callable, description: str = "", step: float = 0.01):
        super().__init__(label, description)
        self.callback = callback
        
        # Value display
        self.value_label = Gtk.Label(label=f"{value:.2f}")
        self.value_label.add_css_class('value-mono')
        self.value_label.set_width_chars(5)
        self.append(self.value_label)
        
        # Scale
        self.scale = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, min_val, max_val, step)
        self.scale.set_value(value)
        self.scale.set_draw_value(False)
        self.scale.set_size_request(180, -1)
        self.scale.connect('value-changed', self._on_changed)
        self.scale.add_css_class('opacity-scale')
        self.append(self.scale)
        
    def _on_changed(self, scale):
        value = round(scale.get_value(), 2)
        self.value_label.set_label(f"{value:.2f}")
        if self.callback:
            self.callback(value)
    
    def set_value(self, value: float):
        self.scale.set_value(value)
        self.value_label.set_label(f"{value:.2f}")
    
    def get_value(self) -> float:
        return round(self.scale.get_value(), 2)

class ToggleRow(SettingRow):
    """Toggle switch row"""
    
    def __init__(self, label: str, value: bool, callback: Callable, description: str = ""):
        super().__init__(label, description)
        self.callback = callback
        
        self.switch = Gtk.Switch()
        self.switch.set_active(value)
        self.switch.set_valign(Gtk.Align.CENTER)
        self.switch.connect('state-set', self._on_state_set)
        self.append(self.switch)
        
    def _on_state_set(self, switch, state):
        if self.callback:
            self.callback(state)
        return False
    
    def set_value(self, value: bool):
        self.switch.set_active(value)
    
    def get_value(self) -> bool:
        return self.switch.get_active()

class DropdownRow(SettingRow):
    """Dropdown selection row"""
    
    def __init__(self, label: str, options: list, current: str, 
                 callback: Callable, description: str = ""):
        super().__init__(label, description)
        self.callback = callback
        self.options = options
        
        string_list = Gtk.StringList.new(options)
        self.dropdown = Gtk.DropDown(model=string_list)
        
        try:
            self.dropdown.set_selected(options.index(current))
        except ValueError:
            self.dropdown.set_selected(0)
            
        self.dropdown.connect('notify::selected', self._on_selected)
        self.dropdown.add_css_class('setting-dropdown')
        self.append(self.dropdown)
        
    def _on_selected(self, dropdown, param):
        idx = dropdown.get_selected()
        if idx < len(self.options) and self.callback:
            self.callback(self.options[idx])
    
    def set_value(self, value: str):
        try:
            self.dropdown.set_selected(self.options.index(value))
        except ValueError:
            pass
    
    def get_value(self) -> str:
        idx = self.dropdown.get_selected()
        return self.options[idx] if idx < len(self.options) else self.options[0]

class SectionHeader(Gtk.Box):
    """Section header with title"""
    
    def __init__(self, title: str):
        super().__init__(orientation=Gtk.Orientation.HORIZONTAL)
        self.set_margin_top(16)
        self.set_margin_bottom(8)
        
        label = Gtk.Label(label=title)
        label.add_css_class('section-header')
        label.set_halign(Gtk.Align.START)
        self.append(label)

class SettingsGroup(Gtk.Box):
    """Container for a group of settings"""
    
    def __init__(self, title: str = ""):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.add_css_class('settings-group')
        
        if title:
            header = Gtk.Label(label=title.upper())
            header.add_css_class('group-title')
            header.set_halign(Gtk.Align.START)
            header.set_margin_bottom(8)
            self.append(header)

class PlaceholderPage(Gtk.Box):
    """Placeholder for upcoming features"""
    
    def __init__(self, title: str, icon_name: str, description: str):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=16)
        self.set_valign(Gtk.Align.CENTER)
        self.set_halign(Gtk.Align.CENTER)
        self.add_css_class('placeholder-page')
        
        icon = Gtk.Image.new_from_icon_name(icon_name)
        icon.set_pixel_size(64)
        icon.add_css_class('placeholder-icon')
        self.append(icon)
        
        title_label = Gtk.Label(label=title)
        title_label.add_css_class('placeholder-title')
        self.append(title_label)
        
        desc_label = Gtk.Label(label=description)
        desc_label.add_css_class('placeholder-description')
        desc_label.set_wrap(True)
        desc_label.set_max_width_chars(40)
        desc_label.set_justify(Gtk.Justification.CENTER)
        self.append(desc_label)
        
        badge = Gtk.Label(label="Coming Soon")
        badge.add_css_class('coming-soon-badge')
        self.append(badge)

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN WINDOW
# ═══════════════════════════════════════════════════════════════════════════════

class ControlCenterWindow(Adw.ApplicationWindow):
    """Main Control Center Window"""
    
    def __init__(self, app):
        super().__init__(application=app)
        
        self.set_title("Hyprland Control Center")
        self.set_default_size(1100, 750)
        
        # Config manager
        self.config = HyprlandConfigManager()
        self.config.parse_look_and_feel()
        
        # Widget references
        self.widgets = {}
        
        # Apply CSS
        self._apply_css()
        
        # Build UI
        self._build_ui()
        
    def _apply_css(self):
        """Apply One Dark themed CSS"""
        css = f'''
        /* ═══════════════════════════════════════════════════════════════ */
        /* WINDOW & CONTAINERS                                              */
        /* ═══════════════════════════════════════════════════════════════ */
        
        window {{
            background-color: {ONE_DARK["bg1"]};
        }}
        
        .sidebar {{
            background-color: {ONE_DARK["bg0"]};
            border-right: 1px solid {ONE_DARK["bg3"]};
        }}
        
        .content-area {{
            background-color: {ONE_DARK["bg1"]};
            padding: 24px 32px;
        }}
        
        /* ═══════════════════════════════════════════════════════════════ */
        /* SIDEBAR                                                          */
        /* ═══════════════════════════════════════════════════════════════ */
        
        .sidebar-title {{
            font-size: 18px;
            font-weight: 700;
            color: {ONE_DARK["fg"]};
            padding: 16px;
        }}
        
        .sidebar-section {{
            font-size: 11px;
            font-weight: 600;
            color: {ONE_DARK["grey0"]};
            letter-spacing: 1.2px;
            text-transform: uppercase;
            padding: 16px 16px 8px 16px;
        }}
        
        .sidebar-item {{
            padding: 10px 16px;
            margin: 2px 8px;
            border-radius: 8px;
            color: {ONE_DARK["fg"]};
            font-size: 13px;
        }}
        
        .sidebar-item:hover {{
            background-color: {ONE_DARK["bg2"]};
        }}
        
        .sidebar-item:selected,
        .sidebar-item:checked {{
            background-color: {ONE_DARK["blue"]};
            color: {ONE_DARK["bg1"]};
        }}
        
        /* ═══════════════════════════════════════════════════════════════ */
        /* PAGE HEADERS                                                     */
        /* ═══════════════════════════════════════════════════════════════ */
        
        .page-title {{
            font-size: 28px;
            font-weight: 700;
            color: {ONE_DARK["fg"]};
        }}
        
        .page-subtitle {{
            font-size: 14px;
            color: {ONE_DARK["grey1"]};
            margin-top: 4px;
        }}
        
        /* ═══════════════════════════════════════════════════════════════ */
        /* SETTINGS GROUPS                                                  */
        /* ═══════════════════════════════════════════════════════════════ */
        
        .settings-group {{
            background-color: {ONE_DARK["bg0"]};
            border-radius: 12px;
            padding: 16px 20px;
            margin-bottom: 16px;
        }}
        
        .group-title {{
            font-size: 11px;
            font-weight: 600;
            color: {ONE_DARK["blue"]};
            letter-spacing: 1px;
        }}
        
        .section-header {{
            font-size: 12px;
            font-weight: 600;
            color: {ONE_DARK["purple"]};
            letter-spacing: 0.5px;
        }}
        
        /* ═══════════════════════════════════════════════════════════════ */
        /* SETTING ROWS                                                     */
        /* ═══════════════════════════════════════════════════════════════ */
        
        .setting-row {{
            padding: 6px 0;
            border-bottom: 1px solid {ONE_DARK["bg2"]};
        }}
        
        .setting-row:last-child {{
            border-bottom: none;
        }}
        
        .setting-label {{
            font-size: 14px;
            font-weight: 500;
            color: {ONE_DARK["fg"]};
        }}
        
        .setting-description {{
            font-size: 12px;
            color: {ONE_DARK["grey0"]};
        }}
        
        .value-mono {{
            font-family: "JetBrains Mono", "Fira Code", monospace;
            font-size: 12px;
            color: {ONE_DARK["aqua"]};
            background-color: {ONE_DARK["bg2"]};
            padding: 4px 10px;
            border-radius: 6px;
        }}
        
        /* ═══════════════════════════════════════════════════════════════ */
        /* INPUT WIDGETS                                                    */
        /* ═══════════════════════════════════════════════════════════════ */
        
        .color-button {{
            min-width: 44px;
            min-height: 32px;
            border-radius: 8px;
            border: 2px solid {ONE_DARK["bg3"]};
        }}
        
        .spin-input {{
            background-color: {ONE_DARK["bg2"]};
            color: {ONE_DARK["fg"]};
            border-radius: 8px;
            border: 1px solid {ONE_DARK["bg3"]};
            padding: 4px 8px;
            min-width: 80px;
        }}
        
        .spin-input:focus {{
            border-color: {ONE_DARK["blue"]};
        }}
        
        .opacity-scale {{
            min-width: 150px;
        }}
        
        .opacity-scale trough {{
            background-color: {ONE_DARK["bg3"]};
            border-radius: 4px;
            min-height: 6px;
        }}
        
        .opacity-scale highlight {{
            background-color: {ONE_DARK["blue"]};
            border-radius: 4px;
        }}
        
        .opacity-scale slider {{
            background-color: {ONE_DARK["fg"]};
            border-radius: 50%;
            min-width: 18px;
            min-height: 18px;
            margin: -6px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.3);
        }}
        
        switch {{
            background-color: {ONE_DARK["bg3"]};
            border-radius: 14px;
            min-width: 50px;
            min-height: 26px;
        }}
        
        switch:checked {{
            background-color: {ONE_DARK["green"]};
        }}
        
        switch slider {{
            background-color: {ONE_DARK["fg"]};
            border-radius: 13px;
            min-width: 22px;
            min-height: 22px;
            margin: 2px;
        }}
        
        .setting-dropdown {{
            background-color: {ONE_DARK["bg2"]};
            color: {ONE_DARK["fg"]};
            border-radius: 8px;
            padding: 6px 12px;
            border: 1px solid {ONE_DARK["bg3"]};
            min-width: 120px;
        }}
        
        /* ═══════════════════════════════════════════════════════════════ */
        /* BUTTONS                                                          */
        /* ═══════════════════════════════════════════════════════════════ */
        
        .action-button {{
            padding: 10px 24px;
            border-radius: 8px;
            font-weight: 600;
            font-size: 13px;
            margin: 4px;
            border: none;
        }}
        
        .reset-button {{
            background-color: {ONE_DARK["red"]};
            color: white;
        }}
        
        .reset-button:hover {{
            background-color: #c75f68;
        }}
        
        .apply-button {{
            background-color: {ONE_DARK["green"]};
            color: {ONE_DARK["bg1"]};
        }}
        
        .apply-button:hover {{
            background-color: #88b369;
        }}
        
        /* ═══════════════════════════════════════════════════════════════ */
        /* PLACEHOLDER PAGES                                                */
        /* ═══════════════════════════════════════════════════════════════ */
        
        .placeholder-page {{
            padding: 48px;
        }}
        
        .placeholder-icon {{
            color: {ONE_DARK["grey0"]};
            opacity: 0.5;
            margin-bottom: 8px;
        }}
        
        .placeholder-title {{
            font-size: 24px;
            font-weight: 700;
            color: {ONE_DARK["fg"]};
        }}
        
        .placeholder-description {{
            font-size: 14px;
            color: {ONE_DARK["grey1"]};
            margin-top: 8px;
        }}
        
        .coming-soon-badge {{
            background-color: {ONE_DARK["purple"]};
            color: white;
            font-size: 11px;
            font-weight: 600;
            padding: 6px 16px;
            border-radius: 16px;
            margin-top: 16px;
        }}
        
        /* ═══════════════════════════════════════════════════════════════ */
        /* SCROLLBARS                                                       */
        /* ═══════════════════════════════════════════════════════════════ */
        
        scrollbar {{
            background-color: transparent;
        }}
        
        scrollbar slider {{
            background-color: {ONE_DARK["bg3"]};
            border-radius: 8px;
            min-width: 8px;
        }}
        
        scrollbar slider:hover {{
            background-color: {ONE_DARK["bg4"]};
        }}
        '''
        
        provider = Gtk.CssProvider()
        provider.load_from_data(css.encode())
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )
    
    def _build_ui(self):
        """Build the main UI"""
        # Toast overlay wrapper
        self.toast_overlay = Adw.ToastOverlay()
        self.set_content(self.toast_overlay)
        
        # Main horizontal box
        main_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        self.toast_overlay.set_child(main_box)
        
        # Sidebar
        sidebar = self._build_sidebar()
        main_box.append(sidebar)
        
        # Content stack
        self.stack = Gtk.Stack()
        self.stack.set_transition_type(Gtk.StackTransitionType.CROSSFADE)
        self.stack.set_transition_duration(200)
        self.stack.set_hexpand(True)
        self.stack.set_vexpand(True)
        
        # Add pages
        self.stack.add_named(self._build_appearance_page(), "appearance")
        self.stack.add_named(self._build_panel_page(), "panel")
        self.stack.add_named(self._build_workspaces_page(), "workspaces")
        self.stack.add_named(self._build_animations_page(), "animations")
        self.stack.add_named(self._build_input_page(), "input")
        self.stack.add_named(self._build_monitors_page(), "monitors")
        self.stack.add_named(self._build_keybinds_page(), "keybinds")
        
        main_box.append(self.stack)
    
    def _build_sidebar(self) -> Gtk.Box:
        """Build sidebar navigation"""
        sidebar = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        sidebar.add_css_class('sidebar')
        sidebar.set_size_request(240, -1)
        
        # App title
        title = Gtk.Label(label="⚙ Settings")
        title.add_css_class('sidebar-title')
        title.set_halign(Gtk.Align.START)
        sidebar.append(title)
        
        # Navigation sections
        nav_sections = [
            ("DESKTOP", [
                ("Appearance", "appearance", "preferences-desktop-appearance-symbolic"),
                ("Panel", "panel", "view-paged-symbolic"),
                ("Workspaces", "workspaces", "view-grid-symbolic"),
            ]),
            ("SYSTEM", [
                ("Animations", "animations", "preferences-desktop-effects-symbolic"),
                ("Input Devices", "input", "input-keyboard-symbolic"),
                ("Monitors", "monitors", "video-display-symbolic"),
                ("Keybinds", "keybinds", "preferences-desktop-keyboard-shortcuts-symbolic"),
            ]),
        ]
        
        list_box = Gtk.ListBox()
        list_box.set_selection_mode(Gtk.SelectionMode.SINGLE)
        list_box.connect('row-activated', self._on_nav_activated)
        
        for section_name, items in nav_sections:
            # Section header (as a non-selectable row)
            section_row = Gtk.ListBoxRow()
            section_row.set_selectable(False)
            section_row.set_activatable(False)
            section_label = Gtk.Label(label=section_name)
            section_label.add_css_class('sidebar-section')
            section_label.set_halign(Gtk.Align.START)
            section_row.set_child(section_label)
            list_box.append(section_row)
            
            # Items
            for label, page_name, icon_name in items:
                row = Gtk.ListBoxRow()
                row.set_name(page_name)
                
                box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
                box.add_css_class('sidebar-item')
                
                icon = Gtk.Image.new_from_icon_name(icon_name)
                icon.set_pixel_size(18)
                box.append(icon)
                
                lbl = Gtk.Label(label=label)
                lbl.set_halign(Gtk.Align.START)
                box.append(lbl)
                
                row.set_child(box)
                list_box.append(row)
        
        # Select first actual item (skip section header)
        list_box.select_row(list_box.get_row_at_index(1))
        
        sidebar.append(list_box)
        
        # Spacer
        spacer = Gtk.Box()
        spacer.set_vexpand(True)
        sidebar.append(spacer)
        
        # Version info
        version = Gtk.Label(label="v1.0.0")
        version.add_css_class('setting-description')
        version.set_margin_bottom(16)
        sidebar.append(version)
        
        return sidebar
    
    def _on_nav_activated(self, list_box, row):
        """Handle navigation selection"""
        if row and row.get_selectable():
            page_name = row.get_name()
            if page_name:
                self.stack.set_visible_child_name(page_name)
    
    # ═══════════════════════════════════════════════════════════════════════════
    # APPEARANCE PAGE (Look & Feel)
    # ═══════════════════════════════════════════════════════════════════════════
    
    def _build_appearance_page(self) -> Gtk.ScrolledWindow:
        """Build Appearance settings page"""
        scrolled = Gtk.ScrolledWindow()
        scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        
        content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        content.add_css_class('content-area')
        
        # Header
        header = self._create_page_header(
            "Appearance",
            "Customize window borders, gaps, rounding, and effects"
        )
        content.append(header)
        
        # General Section
        general_group = SettingsGroup("General")
        
        # Gaps In
        w = IntegerRow("Gaps In", self.config.general.gaps_in, 0, 1000,
                       lambda v: setattr(self.config.general, 'gaps_in', v),
                       "Space between windows")
        self.widgets['gaps_in'] = w
        general_group.append(w)
        
        # Gaps Out
        w = IntegerRow("Gaps Out", self.config.general.gaps_out, 0, 1000,
                       lambda v: setattr(self.config.general, 'gaps_out', v),
                       "Space between windows and screen edge")
        self.widgets['gaps_out'] = w
        general_group.append(w)
        
        # Border Size
        w = IntegerRow("Border Size", self.config.general.border_size, 0, 100,
                       lambda v: setattr(self.config.general, 'border_size', v),
                       "Window border thickness in pixels")
        self.widgets['border_size'] = w
        general_group.append(w)
        
        # Active Border Color
        w = ColorPickerRow("Active Border Color", self.config.general.col_active_border,
                           lambda v: setattr(self.config.general, 'col_active_border', v),
                           "Color of focused window border")
        self.widgets['col_active_border'] = w
        general_group.append(w)
        
        # Inactive Border Color
        w = ColorPickerRow("Inactive Border Color", self.config.general.col_inactive_border,
                           lambda v: setattr(self.config.general, 'col_inactive_border', v),
                           "Color of unfocused window borders")
        self.widgets['col_inactive_border'] = w
        general_group.append(w)
        
        # Resize on Border
        w = ToggleRow("Resize on Border", self.config.general.resize_on_border,
                      lambda v: setattr(self.config.general, 'resize_on_border', v),
                      "Enable resizing by dragging borders")
        self.widgets['resize_on_border'] = w
        general_group.append(w)
        
        # Allow Tearing
        w = ToggleRow("Allow Tearing", self.config.general.allow_tearing,
                      lambda v: setattr(self.config.general, 'allow_tearing', v),
                      "Allow screen tearing for games")
        self.widgets['allow_tearing'] = w
        general_group.append(w)
        
        # Layout
        w = DropdownRow("Layout", ["dwindle", "master"], self.config.general.layout,
                        lambda v: setattr(self.config.general, 'layout', v),
                        "Window tiling layout algorithm")
        self.widgets['layout'] = w
        general_group.append(w)
        
        content.append(general_group)
        
        # Decoration Section
        decoration_group = SettingsGroup("Decoration")
        
        # Rounding
        w = IntegerRow("Rounding", self.config.decoration.rounding, 0, 100,
                       lambda v: setattr(self.config.decoration, 'rounding', v),
                       "Corner rounding radius in pixels")
        self.widgets['rounding'] = w
        decoration_group.append(w)
        
        # Rounding Power
        w = IntegerRow("Rounding Power", self.config.decoration.rounding_power, 1, 10,
                       lambda v: setattr(self.config.decoration, 'rounding_power', v),
                       "Smoothness of corner curves")
        self.widgets['rounding_power'] = w
        decoration_group.append(w)
        
        # Active Opacity
        w = FloatRow("Active Opacity", self.config.decoration.active_opacity, 0.0, 1.0,
                     lambda v: setattr(self.config.decoration, 'active_opacity', v),
                     "Transparency of focused windows")
        self.widgets['active_opacity'] = w
        decoration_group.append(w)
        
        # Inactive Opacity
        w = FloatRow("Inactive Opacity", self.config.decoration.inactive_opacity, 0.0, 1.0,
                     lambda v: setattr(self.config.decoration, 'inactive_opacity', v),
                     "Transparency of unfocused windows")
        self.widgets['inactive_opacity'] = w
        decoration_group.append(w)
        
        # Shadow header
        decoration_group.append(SectionHeader("Shadow"))
        
        # Shadow Enabled
        w = ToggleRow("Shadow Enabled", self.config.decoration.shadow_enabled,
                      lambda v: setattr(self.config.decoration, 'shadow_enabled', v))
        self.widgets['shadow_enabled'] = w
        decoration_group.append(w)
        
        # Shadow Range
        w = IntegerRow("Shadow Range", self.config.decoration.shadow_range, 0, 100,
                       lambda v: setattr(self.config.decoration, 'shadow_range', v),
                       "Shadow blur radius")
        self.widgets['shadow_range'] = w
        decoration_group.append(w)
        
        # Shadow Color
        w = ColorPickerRow("Shadow Color", self.config.decoration.shadow_color,
                           lambda v: setattr(self.config.decoration, 'shadow_color', v))
        self.widgets['shadow_color'] = w
        decoration_group.append(w)
        
        # Blur header
        decoration_group.append(SectionHeader("Blur"))
        
        # Blur Enabled
        w = ToggleRow("Blur Enabled", self.config.decoration.blur_enabled,
                      lambda v: setattr(self.config.decoration, 'blur_enabled', v))
        self.widgets['blur_enabled'] = w
        decoration_group.append(w)
        
        # Blur Size
        w = IntegerRow("Blur Size", self.config.decoration.blur_size, 1, 50,
                       lambda v: setattr(self.config.decoration, 'blur_size', v),
                       "Blur kernel size")
        self.widgets['blur_size'] = w
        decoration_group.append(w)
        
        # Blur Passes
        w = IntegerRow("Blur Passes", self.config.decoration.blur_passes, 1, 10,
                       lambda v: setattr(self.config.decoration, 'blur_passes', v),
                       "Number of blur iterations")
        self.widgets['blur_passes'] = w
        decoration_group.append(w)
        
        content.append(decoration_group)
        
        # Action buttons
        content.append(self._create_action_buttons(
            on_reset=self._on_appearance_reset,
            on_apply=self._on_appearance_apply
        ))
        
        scrolled.set_child(content)
        return scrolled
    
    def _on_appearance_reset(self, btn):
        """Reset appearance to default"""
        dialog = Adw.MessageDialog(
            transient_for=self,
            heading="Reset to Default?",
            body="This will restore appearance settings from the default configuration."
        )
        dialog.add_response("cancel", "Cancel")
        dialog.add_response("reset", "Reset")
        dialog.set_response_appearance("reset", Adw.ResponseAppearance.DESTRUCTIVE)
        dialog.connect('response', self._on_appearance_reset_response)
        dialog.present()
    
    def _on_appearance_reset_response(self, dialog, response):
        if response == "reset":
            if self.config.reset_look_and_feel():
                self._refresh_appearance_widgets()
                self._show_toast("Settings reset to default")
            else:
                self._show_toast("Default configuration not found")
    
    def _on_appearance_apply(self, btn):
        """Apply appearance changes"""
        self.config.save_look_and_feel()
        self._show_toast("Appearance settings applied")
    
    def _refresh_appearance_widgets(self):
        """Refresh appearance widgets with current values"""
        widget_map = {
            'gaps_in': self.config.general.gaps_in,
            'gaps_out': self.config.general.gaps_out,
            'border_size': self.config.general.border_size,
            'col_active_border': self.config.general.col_active_border,
            'col_inactive_border': self.config.general.col_inactive_border,
            'resize_on_border': self.config.general.resize_on_border,
            'allow_tearing': self.config.general.allow_tearing,
            'layout': self.config.general.layout,
            'rounding': self.config.decoration.rounding,
            'rounding_power': self.config.decoration.rounding_power,
            'active_opacity': self.config.decoration.active_opacity,
            'inactive_opacity': self.config.decoration.inactive_opacity,
            'shadow_enabled': self.config.decoration.shadow_enabled,
            'shadow_range': self.config.decoration.shadow_range,
            'shadow_color': self.config.decoration.shadow_color,
            'blur_enabled': self.config.decoration.blur_enabled,
            'blur_size': self.config.decoration.blur_size,
            'blur_passes': self.config.decoration.blur_passes,
        }
        
        for key, value in widget_map.items():
            if key in self.widgets:
                if hasattr(self.widgets[key], 'set_value'):
                    self.widgets[key].set_value(value)
                elif hasattr(self.widgets[key], 'set_color'):
                    self.widgets[key].set_color(value)
    
    # ═══════════════════════════════════════════════════════════════════════════
    # PANEL PAGE (Waybar)
    # ═══════════════════════════════════════════════════════════════════════════
    
    def _build_panel_page(self) -> Gtk.ScrolledWindow:
        """Build Panel (Waybar) settings page"""
        scrolled = Gtk.ScrolledWindow()
        scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        
        content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        content.add_css_class('content-area')
        
        # Header
        header = self._create_page_header(
            "Panel",
            "Configure Waybar position, size, and dock mode"
        )
        content.append(header)
        
        # Main Waybar Section
        waybar_group = SettingsGroup("Waybar (Main)")
        
        # Position
        w = DropdownRow("Position", ["top", "bottom", "left", "right"], "top",
                        lambda v: setattr(self.config.waybar, 'position', v),
                        "Bar position on screen")
        self.widgets['waybar_position'] = w
        waybar_group.append(w)
        
        # Height
        w = IntegerRow("Height", 34, 20, 100,
                       lambda v: setattr(self.config.waybar, 'height', v),
                       "Bar height in pixels")
        self.widgets['waybar_height'] = w
        waybar_group.append(w)
        
        # Margins
        waybar_group.append(SectionHeader("Margins"))
        
        w = IntegerRow("Margin Top", 0, 0, 100,
                       lambda v: setattr(self.config.waybar, 'margin_top', v))
        self.widgets['waybar_margin_top'] = w
        waybar_group.append(w)
        
        w = IntegerRow("Margin Bottom", 0, 0, 100,
                       lambda v: setattr(self.config.waybar, 'margin_bottom', v))
        self.widgets['waybar_margin_bottom'] = w
        waybar_group.append(w)
        
        w = IntegerRow("Margin Left", 0, 0, 100,
                       lambda v: setattr(self.config.waybar, 'margin_left', v))
        self.widgets['waybar_margin_left'] = w
        waybar_group.append(w)
        
        w = IntegerRow("Margin Right", 0, 0, 100,
                       lambda v: setattr(self.config.waybar, 'margin_right', v))
        self.widgets['waybar_margin_right'] = w
        waybar_group.append(w)
        
        w = IntegerRow("Spacing", 4, 0, 50,
                       lambda v: setattr(self.config.waybar, 'spacing', v),
                       "Space between modules")
        self.widgets['waybar_spacing'] = w
        waybar_group.append(w)
        
        content.append(waybar_group)
        
        # Dock Mode Section
        dock_group = SettingsGroup("Waybar 2 (Dock)")
        
        # Position
        w = DropdownRow("Position", ["top", "bottom", "left", "right"], "bottom",
                        lambda v: setattr(self.config.waybar2, 'position', v),
                        "Dock position on screen")
        self.widgets['waybar2_position'] = w
        dock_group.append(w)
        
        # Height
        w = IntegerRow("Height", 60, 40, 150,
                       lambda v: setattr(self.config.waybar2, 'height', v),
                       "Dock height in pixels")
        self.widgets['waybar2_height'] = w
        dock_group.append(w)
        
        # Margins
        dock_group.append(SectionHeader("Margins"))
        
        w = IntegerRow("Margin Top", 0, 0, 100,
                       lambda v: setattr(self.config.waybar2, 'margin_top', v))
        self.widgets['waybar2_margin_top'] = w
        dock_group.append(w)
        
        w = IntegerRow("Margin Bottom", 8, 0, 100,
                       lambda v: setattr(self.config.waybar2, 'margin_bottom', v))
        self.widgets['waybar2_margin_bottom'] = w
        dock_group.append(w)
        
        w = IntegerRow("Margin Left", 0, 0, 500,
                       lambda v: setattr(self.config.waybar2, 'margin_left', v))
        self.widgets['waybar2_margin_left'] = w
        dock_group.append(w)
        
        w = IntegerRow("Margin Right", 0, 0, 500,
                       lambda v: setattr(self.config.waybar2, 'margin_right', v))
        self.widgets['waybar2_margin_right'] = w
        dock_group.append(w)
        
        content.append(dock_group)
        
        # Action buttons
        content.append(self._create_action_buttons(
            on_reset=lambda b: self._show_toast("Coming soon"),
            on_apply=lambda b: self._show_toast("Coming soon")
        ))
        
        scrolled.set_child(content)
        return scrolled
    
    # ═══════════════════════════════════════════════════════════════════════════
    # WORKSPACES PAGE
    # ═══════════════════════════════════════════════════════════════════════════
    
    def _build_workspaces_page(self) -> Gtk.ScrolledWindow:
        """Build Workspaces settings page"""
        scrolled = Gtk.ScrolledWindow()
        scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        
        content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        content.add_css_class('content-area')
        
        # Header
        header = self._create_page_header(
            "Workspaces",
            "Configure workspace rules and behavior"
        )
        content.append(header)
        
        # Workspace rules section
        rules_group = SettingsGroup("Workspace Rules")
        
        # Placeholder info
        info_label = Gtk.Label(label="Configure which workspaces appear on which monitors,\nset persistent workspaces, and default workspace assignments.")
        info_label.add_css_class('setting-description')
        info_label.set_halign(Gtk.Align.START)
        info_label.set_margin_top(8)
        info_label.set_margin_bottom(16)
        rules_group.append(info_label)
        
        # Workspace entries (1-10)
        for i in range(1, 11):
            ws_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=16)
            ws_row.add_css_class('setting-row')
            ws_row.set_margin_top(8)
            ws_row.set_margin_bottom(8)
            
            # Workspace number
            num_label = Gtk.Label(label=f"Workspace {i}")
            num_label.add_css_class('setting-label')
            num_label.set_width_chars(12)
            num_label.set_halign(Gtk.Align.START)
            ws_row.append(num_label)
            
            # Monitor dropdown
            monitor_dropdown = Gtk.DropDown(model=Gtk.StringList.new(["Auto", "DP-1", "DP-2", "HDMI-A-1"]))
            monitor_dropdown.add_css_class('setting-dropdown')
            ws_row.append(monitor_dropdown)
            
            # Persistent toggle
            persist_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
            persist_label = Gtk.Label(label="Persistent")
            persist_label.add_css_class('setting-description')
            persist_box.append(persist_label)
            persist_switch = Gtk.Switch()
            persist_switch.set_valign(Gtk.Align.CENTER)
            persist_box.append(persist_switch)
            ws_row.append(persist_box)
            
            rules_group.append(ws_row)
        
        content.append(rules_group)
        
        # Action buttons
        content.append(self._create_action_buttons(
            on_reset=lambda b: self._show_toast("Coming soon"),
            on_apply=lambda b: self._show_toast("Coming soon")
        ))
        
        scrolled.set_child(content)
        return scrolled
    
    # ═══════════════════════════════════════════════════════════════════════════
    # ANIMATIONS PAGE (Placeholder)
    # ═══════════════════════════════════════════════════════════════════════════
    
    def _build_animations_page(self) -> Gtk.Box:
        """Build Animations placeholder page"""
        return PlaceholderPage(
            "Animations",
            "preferences-desktop-effects-symbolic",
            "Configure window animations, bezier curves, and transition effects for a smooth desktop experience."
        )
    
    # ═══════════════════════════════════════════════════════════════════════════
    # INPUT PAGE (Placeholder)
    # ═══════════════════════════════════════════════════════════════════════════
    
    def _build_input_page(self) -> Gtk.Box:
        """Build Input Devices placeholder page"""
        return PlaceholderPage(
            "Input Devices",
            "input-keyboard-symbolic",
            "Configure keyboard layouts, mouse sensitivity, touchpad gestures, and other input device settings."
        )
    
    # ═══════════════════════════════════════════════════════════════════════════
    # MONITORS PAGE (Placeholder)
    # ═══════════════════════════════════════════════════════════════════════════
    
    def _build_monitors_page(self) -> Gtk.Box:
        """Build Monitors placeholder page"""
        return PlaceholderPage(
            "Monitors",
            "video-display-symbolic",
            "Configure monitor resolution, position, scale, and rotation for multi-display setups."
        )
    
    # ═══════════════════════════════════════════════════════════════════════════
    # KEYBINDS PAGE (Placeholder)
    # ═══════════════════════════════════════════════════════════════════════════
    
    def _build_keybinds_page(self) -> Gtk.Box:
        """Build Keybinds placeholder page"""
        return PlaceholderPage(
            "Keybinds",
            "preferences-desktop-keyboard-shortcuts-symbolic",
            "Customize keyboard shortcuts for window management, workspace navigation, and launching applications."
        )
    
    # ═══════════════════════════════════════════════════════════════════════════
    # HELPER METHODS
    # ═══════════════════════════════════════════════════════════════════════════
    
    def _create_page_header(self, title: str, subtitle: str) -> Gtk.Box:
        """Create page header with title and subtitle"""
        header = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        header.set_margin_bottom(24)
        
        title_label = Gtk.Label(label=title)
        title_label.add_css_class('page-title')
        title_label.set_halign(Gtk.Align.START)
        header.append(title_label)
        
        subtitle_label = Gtk.Label(label=subtitle)
        subtitle_label.add_css_class('page-subtitle')
        subtitle_label.set_halign(Gtk.Align.START)
        header.append(subtitle_label)
        
        return header
    
    def _create_action_buttons(self, on_reset: Callable, on_apply: Callable) -> Gtk.Box:
        """Create action button bar"""
        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        box.set_margin_top(24)
        box.set_halign(Gtk.Align.END)
        
        reset_btn = Gtk.Button(label="Reset to Default")
        reset_btn.add_css_class('action-button')
        reset_btn.add_css_class('reset-button')
        reset_btn.connect('clicked', on_reset)
        box.append(reset_btn)
        
        apply_btn = Gtk.Button(label="Apply Changes")
        apply_btn.add_css_class('action-button')
        apply_btn.add_css_class('apply-button')
        apply_btn.connect('clicked', on_apply)
        box.append(apply_btn)
        
        return box
    
    def _show_toast(self, message: str):
        """Show toast notification"""
        toast = Adw.Toast(title=message)
        toast.set_timeout(3)
        self.toast_overlay.add_toast(toast)

# ═══════════════════════════════════════════════════════════════════════════════
# APPLICATION
# ═══════════════════════════════════════════════════════════════════════════════

class ControlCenterApp(Adw.Application):
    """Main application"""
    
    def __init__(self):
        super().__init__(
            application_id='com.hyprland.controlcenter',
            flags=Gio.ApplicationFlags.FLAGS_NONE
        )
        
    def do_activate(self):
        win = ControlCenterWindow(self)
        win.present()

def main():
    app = ControlCenterApp()
    return app.run(None)

if __name__ == "__main__":
    main()
