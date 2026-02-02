"""
═══════════════════════════════════════════════════════════════════════════════
WAYBAR STYLING - Detailed Waybar CSS Editor
Integrates with existing WaybarStyleManager from panel.py approach
═══════════════════════════════════════════════════════════════════════════════
"""

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
from gi.repository import Gtk, Adw
from typing import Dict, Callable
from pathlib import Path
import re

from .constants import COLOR_OPTIONS, FONT_FAMILIES
from .ui_components import (
    ColorVariableDropdown, NumericInputRow, PaddingEditor, 
    OpacitySlider, FontSelector
)
from .preview_widgets import WaybarPreviewWidget


class WaybarThemingManager:
    """
    Manages Waybar theming - works alongside existing WaybarStyleManager
    Focuses on module colors and detailed styling that WaybarStyleManager doesn't cover
    """
    
    def __init__(self, waybar_dir: Path = None):
        self.waybar_dir = waybar_dir or Path.home() / ".config/waybar"
        self.style_file = self.waybar_dir / "style.css"
        self.current_style = ""
        self._load_style()
    
    def _load_style(self):
        """Load current style.css"""
        if self.style_file.exists():
            self.current_style = self.style_file.read_text(encoding='utf-8')
    
    def save_style(self):
        """Save style.css"""
        self.style_file.write_text(self.current_style, encoding='utf-8')
    
    # ═══════════════════════════════════════════════════════════════════════════
    # WINDOW STYLING
    # ═══════════════════════════════════════════════════════════════════════════
    
    def get_window_opacity(self) -> float:
        """Get window#waybar background opacity"""
        match = re.search(r'window#waybar\s*\{[^}]*background:\s*alpha\(@bg0,\s*([0-9.]+)\)', 
                         self.current_style, re.DOTALL)
        if match:
            return float(match.group(1))
        return 0.5
    
    def set_window_opacity(self, opacity: float):
        """Set window#waybar background opacity"""
        new_bg = f"background: alpha(@bg0,{opacity:.2f});"
        
        # Find and replace in window#waybar block
        pattern = r'(window#waybar\s*\{[^}]*?)background:[^;]+;'
        if re.search(pattern, self.current_style, re.DOTALL):
            self.current_style = re.sub(pattern, f'\\1{new_bg}', self.current_style, flags=re.DOTALL)
    
    def get_window_border_radius(self) -> int:
        """Get window#waybar border-radius"""
        match = re.search(r'window#waybar\s*\{[^}]*border-radius:\s*(\d+)', 
                         self.current_style, re.DOTALL)
        if match:
            return int(match.group(1))
        return 0
    
    def set_window_border_radius(self, radius: int):
        """Set window#waybar border-radius"""
        new_radius = f"border-radius:{radius}px;"
        
        pattern = r'(window#waybar\s*\{[^}]*?)border-radius:[^;]+;'
        if re.search(pattern, self.current_style, re.DOTALL):
            self.current_style = re.sub(pattern, f'\\1{new_radius}', self.current_style, flags=re.DOTALL)
    
    # ═══════════════════════════════════════════════════════════════════════════
    # WORKSPACES STYLING
    # ═══════════════════════════════════════════════════════════════════════════
    
    def get_workspaces_opacity(self) -> float:
        """Get #workspaces background opacity"""
        match = re.search(r'#workspaces\s*\{[^}]*background-color:\s*alpha\(@bg0,\s*([0-9.]+)\)', 
                         self.current_style, re.DOTALL)
        if match:
            return float(match.group(1))
        return 0.21
    
    def set_workspaces_opacity(self, opacity: float):
        """Set #workspaces background opacity"""
        new_bg = f"background-color: alpha(@bg0,{opacity:.2f});"
        
        pattern = r'(#workspaces\s*\{[^}]*?)background-color:\s*alpha\([^)]+\);'
        if re.search(pattern, self.current_style, re.DOTALL):
            self.current_style = re.sub(pattern, f'\\1{new_bg}', self.current_style, flags=re.DOTALL)
    
    def get_workspaces_border_radius(self) -> int:
        """Get #workspaces border-radius"""
        match = re.search(r'#workspaces\s*\{[^}]*border-radius:\s*(\d+)', 
                         self.current_style, re.DOTALL)
        if match:
            return int(match.group(1))
        return 26
    
    def set_workspaces_border_radius(self, radius: int):
        """Set #workspaces border-radius"""
        pattern = r'(#workspaces\s*\{[^}]*?)border-radius:\s*\d+px;'
        if re.search(pattern, self.current_style, re.DOTALL):
            self.current_style = re.sub(pattern, f'\\1border-radius: {radius}px;', 
                                       self.current_style, flags=re.DOTALL)
    
    def get_workspaces_min_width(self) -> int:
        """Get #workspaces min-width"""
        match = re.search(r'#workspaces\s*\{[^}]*min-width:\s*(\d+)', 
                         self.current_style, re.DOTALL)
        if match:
            return int(match.group(1))
        return 176
    
    def set_workspaces_min_width(self, width: int):
        """Set #workspaces min-width"""
        pattern = r'(#workspaces\s*\{[^}]*?)min-width:\s*\d+px;'
        if re.search(pattern, self.current_style, re.DOTALL):
            self.current_style = re.sub(pattern, f'\\1min-width: {width}px;', 
                                       self.current_style, flags=re.DOTALL)
    
    def get_workspaces_padding(self) -> str:
        """Get #workspaces padding"""
        match = re.search(r'#workspaces\s*\{[^}]*padding:\s*([^;]+);', 
                         self.current_style, re.DOTALL)
        if match:
            return match.group(1).strip()
        return "5px 3px 5px 3px"
    
    def set_workspaces_padding(self, padding: str):
        """Set #workspaces padding"""
        pattern = r'(#workspaces\s*\{[^}]*?)padding:\s*[^;]+;'
        if re.search(pattern, self.current_style, re.DOTALL):
            self.current_style = re.sub(pattern, f'\\1padding: {padding};', 
                                       self.current_style, flags=re.DOTALL)
    
    # ═══════════════════════════════════════════════════════════════════════════
    # WORKSPACE BUTTON STYLING
    # ═══════════════════════════════════════════════════════════════════════════
    
    def get_ws_button_radius(self) -> int:
        """Get workspace button border-radius"""
        match = re.search(r'#workspaces\s+button\s*\{[^}]*border-radius:\s*(\d+)', 
                         self.current_style, re.DOTALL)
        if match:
            return int(match.group(1))
        return 16
    
    def set_ws_button_radius(self, radius: int):
        """Set workspace button border-radius"""
        # Update all workspace button states
        for selector in ['#workspaces button', '#workspaces button.active', 
                        '#workspaces button:hover', '#workspaces button.urgent']:
            pattern = rf'({re.escape(selector)}\s*\{{[^}}]*?)border-radius:\s*\d+px;'
            if re.search(pattern, self.current_style, re.DOTALL):
                self.current_style = re.sub(pattern, f'\\1border-radius: {radius}px;', 
                                           self.current_style, flags=re.DOTALL)
    
    def get_ws_button_active_min_width(self) -> int:
        """Get workspace button.active min-width"""
        match = re.search(r'#workspaces\s+button\.active\s*\{[^}]*min-width:\s*(\d+)', 
                         self.current_style, re.DOTALL)
        if match:
            return int(match.group(1))
        return 50
    
    def set_ws_button_active_min_width(self, width: int):
        """Set workspace button.active min-width"""
        for selector in ['#workspaces button.active', '#workspaces button:hover', 
                        '#workspaces button.urgent']:
            pattern = rf'({re.escape(selector)}\s*\{{[^}}]*?)min-width:\s*\d+px;'
            if re.search(pattern, self.current_style, re.DOTALL):
                self.current_style = re.sub(pattern, f'\\1min-width: {width}px;', 
                                           self.current_style, flags=re.DOTALL)
    
    def get_ws_button_color(self, state: str) -> str:
        """Get workspace button background color variable for state (normal, active, hover, urgent)"""
        if state == "normal":
            match = re.search(r'#workspaces\s+button\s*\{[^}]*background-color:\s*@(\w+)', 
                             self.current_style, re.DOTALL)
        elif state == "hover":
            match = re.search(r'#workspaces\s+button:hover\s*\{[^}]*background-color:\s*@(\w+)', 
                             self.current_style, re.DOTALL)
        else:
            match = re.search(rf'#workspaces\s+button\.{state}\s*\{{[^}}]*background-color:\s*@(\w+)', 
                             self.current_style, re.DOTALL)
        if match:
            return match.group(1)
        
        defaults = {"normal": "bg1", "active": "blue", "hover": "purple", "urgent": "red"}
        return defaults.get(state, "bg1")
    
    def set_ws_button_color(self, state: str, color_var: str):
        """Set workspace button background color variable"""
        if state == "normal":
            pattern = r'(#workspaces\s+button\s*\{[^}]*?)background-color:\s*@\w+;'
        elif state == "hover":
            pattern = r'(#workspaces\s+button:hover\s*\{[^}]*?)background-color:\s*@\w+;'
        else:
            pattern = rf'(#workspaces\s+button\.{state}\s*\{{[^}}]*?)background-color:\s*@\w+;'
        
        if re.search(pattern, self.current_style, re.DOTALL):
            self.current_style = re.sub(pattern, f'\\1background-color: @{color_var};', 
                                       self.current_style, flags=re.DOTALL)
    
    # ═══════════════════════════════════════════════════════════════════════════
    # MODULE COLORS
    # ═══════════════════════════════════════════════════════════════════════════
    
    def get_module_color(self, module: str) -> str:
        """Get module color variable (cpu, memory, clock, etc.)"""
        match = re.search(rf'#{module}\s*\{{[^}}]*color:\s*@(\w+)', 
                         self.current_style, re.DOTALL)
        if match:
            return match.group(1)
        
        defaults = {
            "cpu": "blue", "memory": "green", "temperature": "orange",
            "pulseaudio": "yellow", "battery": "green", "bluetooth": "blue",
            "clock": "blue", "network": "purple"
        }
        return defaults.get(module, "fg")
    
    def set_module_color(self, module: str, color_var: str):
        """Set module color variable"""
        pattern = rf'(#{module}\s*\{{[^}}]*?)color:\s*@\w+;'
        if re.search(pattern, self.current_style, re.DOTALL):
            self.current_style = re.sub(pattern, f'\\1color: @{color_var};', 
                                       self.current_style, flags=re.DOTALL)
    
    def get_modules_border_radius(self) -> int:
        """Get system modules border-radius"""
        # Look in the grouped selector
        match = re.search(r'#battery,[^{]*#clock[^{]*\{[^}]*border-radius:\s*(\d+)', 
                         self.current_style, re.DOTALL)
        if match:
            return int(match.group(1))
        return 45
    
    def set_modules_border_radius(self, radius: int):
        """Set system modules border-radius"""
        pattern = r'(#battery,[^{]*#clock[^{]*\{[^}]*?)border-radius:\s*\d+px;'
        if re.search(pattern, self.current_style, re.DOTALL):
            self.current_style = re.sub(pattern, f'\\1border-radius: {radius}px;', 
                                       self.current_style, flags=re.DOTALL)
    
    # ═══════════════════════════════════════════════════════════════════════════
    # FONT STYLING  
    # ═══════════════════════════════════════════════════════════════════════════
    
    def get_font_family(self) -> str:
        """Get global font-family"""
        match = re.search(r'\*\s*\{[^}]*font-family:\s*"([^"]+)"', 
                         self.current_style, re.DOTALL)
        if match:
            return match.group(1)
        return "JetBrainsMono Nerd Font Propo"
    
    def set_font_family(self, family: str):
        """Set global font-family"""
        pattern = r'(\*\s*\{[^}]*?)font-family:\s*"[^"]+"[^;]*;'
        if re.search(pattern, self.current_style, re.DOTALL):
            self.current_style = re.sub(
                pattern, 
                f'\\1font-family: "{family}", sans-serif;', 
                self.current_style, 
                flags=re.DOTALL
            )
    
    def get_font_size(self) -> int:
        """Get global font-size"""
        match = re.search(r'\*\s*\{[^}]*font-size:\s*(\d+)px', 
                         self.current_style, re.DOTALL)
        if match:
            return int(match.group(1))
        return 14
    
    def set_font_size(self, size: int):
        """Set global font-size"""
        pattern = r'(\*\s*\{[^}]*?)font-size:\s*\d+px;'
        if re.search(pattern, self.current_style, re.DOTALL):
            self.current_style = re.sub(pattern, f'\\1font-size: {size}px;', 
                                       self.current_style, flags=re.DOTALL)
    
    # ═══════════════════════════════════════════════════════════════════════════
    # TASKBAR STYLING
    # ═══════════════════════════════════════════════════════════════════════════
    
    def get_taskbar_border_radius(self) -> int:
        """Get #taskbar border-radius"""
        match = re.search(r'#taskbar\s*\{[^}]*border-radius:\s*(\d+)', 
                         self.current_style, re.DOTALL)
        if match:
            return int(match.group(1))
        return 18
    
    def set_taskbar_border_radius(self, radius: int):
        """Set #taskbar border-radius"""
        pattern = r'(#taskbar\s*\{[^}]*?)border-radius:\s*\d+px;'
        if re.search(pattern, self.current_style, re.DOTALL):
            self.current_style = re.sub(pattern, f'\\1border-radius: {radius}px;', 
                                       self.current_style, flags=re.DOTALL)
    
    def get_taskbar_button_radius(self) -> int:
        """Get #taskbar button border-radius"""
        match = re.search(r'#taskbar\s+button\s*\{[^}]*border-radius:\s*(\d+)', 
                         self.current_style, re.DOTALL)
        if match:
            return int(match.group(1))
        return 14
    
    def set_taskbar_button_radius(self, radius: int):
        """Set #taskbar button border-radius"""
        pattern = r'(#taskbar\s+button\s*\{[^}]*?)border-radius:\s*\d+px;'
        if re.search(pattern, self.current_style, re.DOTALL):
            self.current_style = re.sub(pattern, f'\\1border-radius: {radius}px;', 
                                       self.current_style, flags=re.DOTALL)


def build_waybar_styling_section(window, colors: Dict, on_update: Callable) -> Gtk.Box:
    """Build the detailed Waybar styling section using WaybarThemingManager"""
    
    section = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
    
    # Initialize theming manager
    wtm = WaybarThemingManager()
    window.waybar_theming_manager = wtm
    
    # ═══════════════════════════════════════════════════════════════════════
    # LIVE PREVIEW
    # ═══════════════════════════════════════════════════════════════════════
    
    preview_frame = Gtk.Frame()
    preview_frame.set_margin_bottom(12)
    
    # Build config dict from current CSS values
    waybar_config = {
        "workspaces": {
            "button_normal_bg": wtm.get_ws_button_color("normal"),
            "button_active_bg": wtm.get_ws_button_color("active"),
            "button_hover_bg": wtm.get_ws_button_color("hover"),
            "button_urgent_bg": wtm.get_ws_button_color("urgent"),
            "button_active_text": "bg0",
            "button_hover_text": "bg0",
            "button_urgent_text": "bg0",
        },
        "modules": {
            "cpu": {"color": wtm.get_module_color("cpu")},
            "memory": {"color": wtm.get_module_color("memory")},
            "clock": {"color": wtm.get_module_color("clock")},
            "network": {"color": wtm.get_module_color("network")},
            "battery": {"color": wtm.get_module_color("battery")},
        }
    }
    
    waybar_style = {
        "window": {
            "background_opacity": wtm.get_window_opacity(),
            "border_radius": wtm.get_window_border_radius(),
        },
        "workspaces": {
            "background_opacity": wtm.get_workspaces_opacity(),
            "border_radius": wtm.get_workspaces_border_radius(),
            "min_width": wtm.get_workspaces_min_width(),
            "padding": wtm.get_workspaces_padding(),
        },
        "workspaces_button": {
            "border_radius": wtm.get_ws_button_radius(),
        },
        "workspaces_button_active": {
            "min_width": wtm.get_ws_button_active_min_width(),
        },
        "modules": {
            "border_radius": wtm.get_modules_border_radius(),
        },
        "font": {
            "family": wtm.get_font_family(),
            "size": wtm.get_font_size(),
        }
    }
    
    preview = WaybarPreviewWidget(colors, waybar_config, waybar_style)
    window.waybar_theming_preview = preview
    preview_frame.set_child(preview)
    section.append(preview_frame)
    
    hint = Gtk.Label(label="Hover over workspaces to preview hover state")
    hint.add_css_class("dim-label")
    hint.set_margin_bottom(8)
    section.append(hint)
    
    # ═══════════════════════════════════════════════════════════════════════
    # FONT SETTINGS
    # ═══════════════════════════════════════════════════════════════════════
    
    font_exp = Gtk.Expander(label="󰛖 Font Settings")
    font_content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
    font_content.set_margin_start(12)
    font_content.set_margin_top(8)
    font_content.set_margin_bottom(8)
    
    def on_font_change(family, size):
        wtm.set_font_family(family)
        wtm.set_font_size(size)
        _apply_and_reload(window, wtm, on_update)
    
    font_selector = FontSelector(
        "Waybar Font",
        wtm.get_font_family(),
        wtm.get_font_size(),
        on_font_change
    )
    font_content.append(font_selector)
    font_exp.set_child(font_content)
    section.append(font_exp)
    
    # ═══════════════════════════════════════════════════════════════════════
    # WINDOW STYLING
    # ═══════════════════════════════════════════════════════════════════════
    
    window_exp = Gtk.Expander(label="󰍹 Window (Main Bar)")
    window_content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
    window_content.set_margin_start(12)
    window_content.set_margin_top(8)
    window_content.set_margin_bottom(8)
    
    def on_window_opacity(key, val):
        wtm.set_window_opacity(val)
        _apply_and_reload(window, wtm, on_update)
    
    window_content.append(OpacitySlider(
        "Background Opacity",
        wtm.get_window_opacity(),
        on_window_opacity,
        "0% = transparent, 100% = solid"
    ))
    
    def on_window_radius(key, val):
        wtm.set_window_border_radius(int(val))
        _apply_and_reload(window, wtm, on_update)
    
    window_content.append(NumericInputRow(
        "Border Radius",
        wtm.get_window_border_radius(),
        0, 50,
        on_window_radius
    ))
    
    window_exp.set_child(window_content)
    section.append(window_exp)
    
    # ═══════════════════════════════════════════════════════════════════════
    # WORKSPACES STYLING
    # ═══════════════════════════════════════════════════════════════════════
    
    ws_exp = Gtk.Expander(label="󰙀 Workspaces")
    ws_content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
    ws_content.set_margin_start(12)
    ws_content.set_margin_top(8)
    ws_content.set_margin_bottom(8)
    
    # Container settings
    header1 = Gtk.Label(label="CONTAINER", xalign=0)
    header1.add_css_class("caption")
    ws_content.append(header1)
    
    def on_ws_opacity(key, val):
        wtm.set_workspaces_opacity(val)
        _apply_and_reload(window, wtm, on_update)
    
    ws_content.append(OpacitySlider("Container Opacity", wtm.get_workspaces_opacity(), on_ws_opacity))
    
    def on_ws_radius(key, val):
        wtm.set_workspaces_border_radius(int(val))
        _apply_and_reload(window, wtm, on_update)
    
    ws_content.append(NumericInputRow("Border Radius", wtm.get_workspaces_border_radius(), 0, 50, on_ws_radius))
    
    def on_ws_width(key, val):
        wtm.set_workspaces_min_width(int(val))
        _apply_and_reload(window, wtm, on_update)
    
    ws_content.append(NumericInputRow("Min Width", wtm.get_workspaces_min_width(), 50, 300, on_ws_width))
    
    def on_ws_padding(key, val):
        wtm.set_workspaces_padding(val)
        _apply_and_reload(window, wtm, on_update)
    
    ws_content.append(PaddingEditor("Padding", wtm.get_workspaces_padding(), on_ws_padding))
    
    # Button colors
    header2 = Gtk.Label(label="BUTTON COLORS", xalign=0)
    header2.add_css_class("caption")
    header2.set_margin_top(12)
    ws_content.append(header2)
    
    for label, state in [
        ("Normal Background", "normal"),
        ("Active Background", "active"),
        ("Hover Background", "hover"),
        ("Urgent Background", "urgent"),
    ]:
        current = wtm.get_ws_button_color(state)
        
        def make_callback(s):
            def cb(key, val):
                wtm.set_ws_button_color(s, val)
                _apply_and_reload(window, wtm, on_update)
            return cb
        
        ws_content.append(ColorVariableDropdown(label, current, colors, make_callback(state)))
    
    # Button dimensions
    header3 = Gtk.Label(label="BUTTON DIMENSIONS", xalign=0)
    header3.add_css_class("caption")
    header3.set_margin_top(12)
    ws_content.append(header3)
    
    def on_btn_radius(key, val):
        wtm.set_ws_button_radius(int(val))
        _apply_and_reload(window, wtm, on_update)
    
    ws_content.append(NumericInputRow("Button Radius", wtm.get_ws_button_radius(), 0, 30, on_btn_radius))
    
    def on_active_width(key, val):
        wtm.set_ws_button_active_min_width(int(val))
        _apply_and_reload(window, wtm, on_update)
    
    ws_content.append(NumericInputRow("Active Min Width", wtm.get_ws_button_active_min_width(), 20, 100, on_active_width))
    
    ws_exp.set_child(ws_content)
    section.append(ws_exp)
    
    # ═══════════════════════════════════════════════════════════════════════
    # MODULES STYLING
    # ═══════════════════════════════════════════════════════════════════════
    
    mod_exp = Gtk.Expander(label="󰍛 System Modules")
    mod_content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
    mod_content.set_margin_start(12)
    mod_content.set_margin_top(8)
    mod_content.set_margin_bottom(8)
    
    # Module container
    header4 = Gtk.Label(label="CONTAINER", xalign=0)
    header4.add_css_class("caption")
    mod_content.append(header4)
    
    def on_mod_radius(key, val):
        wtm.set_modules_border_radius(int(val))
        _apply_and_reload(window, wtm, on_update)
    
    mod_content.append(NumericInputRow("Border Radius", wtm.get_modules_border_radius(), 0, 50, on_mod_radius))
    
    # Module colors
    header5 = Gtk.Label(label="MODULE COLORS", xalign=0)
    header5.add_css_class("caption")
    header5.set_margin_top(12)
    mod_content.append(header5)
    
    for mod_name, default in [
        ("cpu", "blue"), ("memory", "green"), ("temperature", "orange"),
        ("clock", "blue"), ("network", "purple"), ("battery", "green"),
        ("pulseaudio", "yellow"), ("bluetooth", "blue"),
    ]:
        current = wtm.get_module_color(mod_name)
        
        def make_mod_callback(m):
            def cb(key, val):
                wtm.set_module_color(m, val)
                _apply_and_reload(window, wtm, on_update)
            return cb
        
        mod_content.append(ColorVariableDropdown(
            mod_name.title() + " Color", 
            current, 
            colors, 
            make_mod_callback(mod_name)
        ))
    
    mod_exp.set_child(mod_content)
    section.append(mod_exp)
    
    # ═══════════════════════════════════════════════════════════════════════
    # TASKBAR STYLING
    # ═══════════════════════════════════════════════════════════════════════
    
    tb_exp = Gtk.Expander(label="󰖯 Taskbar")
    tb_content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
    tb_content.set_margin_start(12)
    tb_content.set_margin_top(8)
    tb_content.set_margin_bottom(8)
    
    def on_tb_radius(key, val):
        wtm.set_taskbar_border_radius(int(val))
        _apply_and_reload(window, wtm, on_update)
    
    tb_content.append(NumericInputRow("Container Radius", wtm.get_taskbar_border_radius(), 0, 50, on_tb_radius))
    
    def on_tb_btn_radius(key, val):
        wtm.set_taskbar_button_radius(int(val))
        _apply_and_reload(window, wtm, on_update)
    
    tb_content.append(NumericInputRow("Button Radius", wtm.get_taskbar_button_radius(), 0, 30, on_tb_btn_radius))
    
    tb_exp.set_child(tb_content)
    section.append(tb_exp)
    
    return section


def _apply_and_reload(window, wtm: WaybarThemingManager, on_update: Callable):
    """Save CSS and reload Waybar"""
    import subprocess
    
    wtm.save_style()
    
    # Reload waybar
    try:
        subprocess.run(['pkill', '-SIGUSR2', 'waybar'], check=False)
    except:
        pass
    
    # Update preview
    if hasattr(window, 'waybar_theming_preview'):
        # Rebuild config from current CSS
        waybar_config = {
            "workspaces": {
                "button_normal_bg": wtm.get_ws_button_color("normal"),
                "button_active_bg": wtm.get_ws_button_color("active"),
                "button_hover_bg": wtm.get_ws_button_color("hover"),
                "button_urgent_bg": wtm.get_ws_button_color("urgent"),
            },
            "modules": {
                "cpu": {"color": wtm.get_module_color("cpu")},
                "memory": {"color": wtm.get_module_color("memory")},
                "clock": {"color": wtm.get_module_color("clock")},
            }
        }
        waybar_style = {
            "window": {
                "background_opacity": wtm.get_window_opacity(),
                "border_radius": wtm.get_window_border_radius(),
            },
            "workspaces": {
                "background_opacity": wtm.get_workspaces_opacity(),
                "border_radius": wtm.get_workspaces_border_radius(),
            },
        }
        window.waybar_theming_preview.update_config(waybar_config)
        window.waybar_theming_preview.update_style(waybar_style)
    
    if on_update:
        on_update()
