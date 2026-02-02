"""
═══════════════════════════════════════════════════════════════════════════════
UI COMPONENTS - Reusable widgets for theming page
═══════════════════════════════════════════════════════════════════════════════
"""

import gi
gi.require_version('Gtk', '4.0')
from gi.repository import Gtk, Gdk
import math
from typing import Dict, Callable

from .constants import COLOR_OPTIONS, FONT_FAMILIES


def _draw_rounded_rect(cr, x, y, w, h, r):
    cr.new_sub_path()
    cr.arc(x + w - r, y + r, r, -math.pi/2, 0)
    cr.arc(x + w - r, y + h - r, r, 0, math.pi/2)
    cr.arc(x + r, y + h - r, r, math.pi/2, math.pi)
    cr.arc(x + r, y + r, r, math.pi, 3*math.pi/2)
    cr.close_path()


class ColorPickerRow(Gtk.Box):
    def __init__(self, label: str, color_key: str, hex_value: str, on_change: Callable):
        super().__init__(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        self.color_key = color_key
        self.on_change = on_change
        self.hex_value = hex_value
        self.set_margin_start(8)
        self.set_margin_end(8)
        self.set_margin_top(4)
        self.set_margin_bottom(4)
        
        self.swatch = Gtk.DrawingArea()
        self.swatch.set_content_width(26)
        self.swatch.set_content_height(26)
        self.swatch.set_draw_func(self._draw_swatch)
        click = Gtk.GestureClick()
        click.connect("pressed", self._on_click)
        self.swatch.add_controller(click)
        self.append(self.swatch)
        
        lbl = Gtk.Label(label=label)
        lbl.set_xalign(0)
        lbl.set_size_request(100, -1)
        self.append(lbl)
        
        self.entry = Gtk.Entry()
        self.entry.set_text(hex_value)
        self.entry.set_max_length(7)
        self.entry.set_width_chars(9)
        self.entry.connect("changed", self._on_entry_changed)
        self.append(self.entry)
    
    def _draw_swatch(self, area, cr, w, h):
        hc = self.hex_value.lstrip('#')
        r, g, b = tuple(int(hc[i:i+2], 16) / 255.0 for i in (0, 2, 4)) if len(hc) >= 6 else (0.5, 0.5, 0.5)
        cr.set_source_rgb(r, g, b)
        _draw_rounded_rect(cr, 0, 0, w, h, 5)
        cr.fill()
    
    def _on_click(self, gesture, n, x, y):
        dialog = Gtk.ColorChooserDialog(title=f"Choose {self.color_key}", transient_for=self.get_root(), use_alpha=False)
        rgba = Gdk.RGBA()
        rgba.parse(self.hex_value)
        dialog.set_rgba(rgba)
        dialog.connect("response", self._on_color_chosen)
        dialog.present()
    
    def _on_color_chosen(self, dialog, response):
        if response == Gtk.ResponseType.OK:
            rgba = dialog.get_rgba()
            self.hex_value = "#{:02x}{:02x}{:02x}".format(int(rgba.red * 255), int(rgba.green * 255), int(rgba.blue * 255))
            self.entry.set_text(self.hex_value)
            self.swatch.queue_draw()
            self.on_change(self.color_key, self.hex_value)
        dialog.destroy()
    
    def _on_entry_changed(self, entry):
        text = entry.get_text()
        if len(text) == 7 and text.startswith('#'):
            try:
                int(text[1:], 16)
                self.hex_value = text
                self.swatch.queue_draw()
                self.on_change(self.color_key, text)
            except:
                pass


class ColorVariableDropdown(Gtk.Box):
    def __init__(self, label: str, current_value: str, colors: Dict, on_change: Callable):
        super().__init__(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        self.colors = colors
        self.on_change = on_change
        self.config_key = label.lower().replace(" ", "_")
        self.current_value = current_value
        self.set_margin_start(8)
        self.set_margin_end(8)
        self.set_margin_top(4)
        self.set_margin_bottom(4)
        
        lbl = Gtk.Label(label=label)
        lbl.set_xalign(0)
        lbl.set_size_request(120, -1)
        self.append(lbl)
        
        self.swatch = Gtk.DrawingArea()
        self.swatch.set_content_width(20)
        self.swatch.set_content_height(20)
        self.swatch.set_draw_func(self._draw_swatch)
        self.append(self.swatch)
        
        self.dropdown = Gtk.DropDown()
        model = Gtk.StringList()
        for opt in COLOR_OPTIONS:
            model.append(opt)
        self.dropdown.set_model(model)
        try:
            self.dropdown.set_selected(COLOR_OPTIONS.index(current_value))
        except:
            self.dropdown.set_selected(0)
        self.dropdown.connect("notify::selected", self._on_changed)
        self.append(self.dropdown)
    
    def _draw_swatch(self, area, cr, w, h):
        color = self.colors.get(self.current_value, "#888888")
        hc = color.lstrip('#')
        r, g, b = tuple(int(hc[i:i+2], 16) / 255.0 for i in (0, 2, 4)) if len(hc) >= 6 else (0.5, 0.5, 0.5)
        cr.set_source_rgb(r, g, b)
        cr.arc(w/2, h/2, min(w, h)/2 - 1, 0, 2 * math.pi)
        cr.fill()
    
    def _on_changed(self, dropdown, pspec):
        idx = dropdown.get_selected()
        if idx != Gtk.INVALID_LIST_POSITION:
            self.current_value = COLOR_OPTIONS[idx]
            self.swatch.queue_draw()
            self.on_change(self.config_key, self.current_value)
    
    def update_colors(self, colors: Dict):
        self.colors = colors
        self.swatch.queue_draw()


class FontSelector(Gtk.Box):
    def __init__(self, label: str, current_family: str, current_size: int, on_change: Callable):
        super().__init__(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        self.on_change = on_change
        self.current_family = current_family
        self.current_size = current_size
        self.set_margin_start(8)
        self.set_margin_end(8)
        self.set_margin_top(8)
        self.set_margin_bottom(8)
        
        self.append(Gtk.Label(label=label))
        
        self.family_dropdown = Gtk.DropDown()
        model = Gtk.StringList()
        for font in FONT_FAMILIES:
            model.append(font)
        self.family_dropdown.set_model(model)
        try:
            self.family_dropdown.set_selected(FONT_FAMILIES.index(current_family))
        except:
            self.family_dropdown.set_selected(0)
        self.family_dropdown.connect("notify::selected", self._on_family_changed)
        self.append(self.family_dropdown)
        
        adj = Gtk.Adjustment(value=current_size, lower=8, upper=32, step_increment=1)
        self.size_spin = Gtk.SpinButton(adjustment=adj)
        self.size_spin.connect("value-changed", self._on_size_changed)
        self.append(self.size_spin)
        self.append(Gtk.Label(label="px"))
    
    def _on_family_changed(self, dropdown, pspec):
        idx = dropdown.get_selected()
        if idx != Gtk.INVALID_LIST_POSITION:
            self.current_family = FONT_FAMILIES[idx]
            self.on_change(self.current_family, self.current_size)
    
    def _on_size_changed(self, spin):
        self.current_size = int(spin.get_value())
        self.on_change(self.current_family, self.current_size)


class NumericInputRow(Gtk.Box):
    def __init__(self, label: str, value: float, min_val: float, max_val: float, on_change: Callable, description: str = ""):
        super().__init__(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        self.on_change = on_change
        self.key = label.lower().replace(" ", "_")
        self.set_margin_start(8)
        self.set_margin_end(8)
        self.set_margin_top(6)
        self.set_margin_bottom(6)
        
        lbl = Gtk.Label(label=label)
        lbl.set_xalign(0)
        lbl.set_hexpand(True)
        self.append(lbl)
        
        adj = Gtk.Adjustment(value=value, lower=min_val, upper=max_val, step_increment=1)
        self.spin = Gtk.SpinButton(adjustment=adj, digits=0)
        self.spin.set_value(value)
        self.spin.connect("value-changed", self._on_changed)
        self.append(self.spin)
    
    def _on_changed(self, spin):
        self.on_change(self.key, spin.get_value())


class PaddingEditor(Gtk.Box):
    def __init__(self, label: str, padding_str: str, on_change: Callable):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        self.on_change = on_change
        self.key = label.lower().replace(" ", "_")
        self.set_margin_start(8)
        self.set_margin_end(8)
        self.set_margin_top(4)
        self.set_margin_bottom(4)
        
        self.append(Gtk.Label(label=label, xalign=0))
        self.values = self._parse_padding(padding_str)
        
        grid = Gtk.Grid()
        grid.set_column_spacing(4)
        self.spins = {}
        for i, (s, v) in enumerate([("T", self.values[0]), ("R", self.values[1]), ("B", self.values[2]), ("L", self.values[3])]):
            grid.attach(Gtk.Label(label=s), i*2, 0, 1, 1)
            adj = Gtk.Adjustment(value=v, lower=0, upper=50, step_increment=1)
            spin = Gtk.SpinButton(adjustment=adj, digits=0)
            spin.set_width_chars(3)
            spin.connect("value-changed", lambda x: self._emit())
            self.spins[s.lower()] = spin
            grid.attach(spin, i*2+1, 0, 1, 1)
        self.append(grid)
    
    def _parse_padding(self, s: str) -> list:
        parts = s.replace("px", "").replace("em", "").split()
        nums = [int(float(p)) for p in parts if p.replace("-", "").replace(".", "").isdigit()]
        if len(nums) == 1: return [nums[0]]*4
        if len(nums) == 2: return [nums[0], nums[1], nums[0], nums[1]]
        if len(nums) >= 4: return nums[:4]
        return [5, 5, 5, 5]
    
    def _emit(self):
        v = [int(self.spins[k].get_value()) for k in ["t", "r", "b", "l"]]
        self.on_change(self.key, f"{v[0]}px {v[1]}px {v[2]}px {v[3]}px")


class OpacitySlider(Gtk.Box):
    def __init__(self, label: str, value: float, on_change: Callable, description: str = ""):
        super().__init__(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        self.on_change = on_change
        self.key = label.lower().replace(" ", "_")
        self.set_margin_start(8)
        self.set_margin_end(8)
        self.set_margin_top(6)
        self.set_margin_bottom(6)
        
        lbl = Gtk.Label(label=label)
        lbl.set_xalign(0)
        lbl.set_hexpand(True)
        self.append(lbl)
        
        self.value_label = Gtk.Label(label=f"{int(value * 100)}%")
        self.value_label.set_width_chars(5)
        self.append(self.value_label)
        
        self.scale = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0.0, 1.0, 0.05)
        self.scale.set_value(value)
        self.scale.set_draw_value(False)
        self.scale.set_size_request(150, -1)
        self.scale.connect("value-changed", self._on_changed)
        self.append(self.scale)
    
    def _on_changed(self, scale):
        v = scale.get_value()
        self.value_label.set_label(f"{int(v * 100)}%")
        self.on_change(self.key, v)
