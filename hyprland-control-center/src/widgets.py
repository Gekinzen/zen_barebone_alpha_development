"""
Custom GTK widgets for Hyprland Control Center
"""

import gi
gi.require_version('Gtk', '4.0')
from gi.repository import Gtk
from typing import Callable

from .utils import rgba_to_gdk, gdk_to_rgba

# ═══════════════════════════════════════════════════════════════════════════════
# BASE WIDGETS
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
