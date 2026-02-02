"""
═══════════════════════════════════════════════════════════════════════════════
PREVIEW WIDGETS - Live preview GTK widgets for Waybar, Rofi, Kitty
═══════════════════════════════════════════════════════════════════════════════
"""

import gi
gi.require_version('Gtk', '4.0')
from gi.repository import Gtk
import math
import cairo
from typing import Dict

from .constants import DEFAULT_WAYBAR_CONFIG, DEFAULT_WAYBAR_STYLE


def _hex_to_rgba(hex_color: str, alpha: float = 1.0):
    """Convert hex color to RGBA tuple"""
    h = hex_color.lstrip('#')[:6]
    if len(h) >= 6:
        r, g, b = tuple(int(h[i:i+2], 16) / 255.0 for i in (0, 2, 4))
        return (r, g, b, alpha)
    return (0.5, 0.5, 0.5, alpha)


def _draw_rounded_rect(cr, x, y, w, h, r):
    """Draw a rounded rectangle path"""
    cr.new_sub_path()
    cr.arc(x + w - r, y + r, r, -math.pi/2, 0)
    cr.arc(x + w - r, y + h - r, r, 0, math.pi/2)
    cr.arc(x + r, y + h - r, r, math.pi/2, math.pi)
    cr.arc(x + r, y + r, r, math.pi, 3*math.pi/2)
    cr.close_path()


class WaybarPreviewWidget(Gtk.DrawingArea):
    """Live preview widget for Waybar appearance"""
    
    def __init__(self, colors: Dict, waybar_config: Dict, waybar_style: Dict = None):
        super().__init__()
        self.colors = colors.copy()
        self.config = waybar_config.copy()
        self.style = waybar_style.copy() if waybar_style else DEFAULT_WAYBAR_STYLE.copy()
        self.hover = "normal"
        
        self.set_content_width(540)
        self.set_content_height(52)
        self.set_draw_func(self._draw)
        
        # Hover detection
        motion = Gtk.EventControllerMotion()
        motion.connect("motion", self._on_motion)
        motion.connect("leave", self._on_leave)
        self.add_controller(motion)
    
    def _get_color(self, name: str) -> str:
        return self.colors.get(name, "#888888")
    
    def _draw(self, area, cr, w, h):
        window_style = self.style.get("window", {})
        ws_style = self.style.get("workspaces", {})
        ws_cfg = self.config.get("workspaces", {})
        modules_cfg = self.config.get("modules", {})
        
        # Main bar background
        opacity = window_style.get("background_opacity", 0.5)
        radius = window_style.get("border_radius", 0)
        cr.set_source_rgba(*_hex_to_rgba(self._get_color("bg0"), opacity))
        _draw_rounded_rect(cr, 2, 2, w - 4, h - 4, min(radius, 20))
        cr.fill()
        
        # Workspaces container
        ws_opacity = ws_style.get("background_opacity", 0.21)
        ws_radius = ws_style.get("border_radius", 26)
        cr.set_source_rgba(*_hex_to_rgba(self._get_color("bg0"), ws_opacity))
        _draw_rounded_rect(cr, 14, 8, 130, h - 16, min(ws_radius, 14))
        cr.fill()
        
        # Workspace buttons
        states = ["normal", "hover", "active", "urgent"] if self.hover == "hover" else ["normal", "normal", "active", "normal"]
        btn_x = 20
        for i, state in enumerate(states):
            btn_w = 30 if state != "normal" else 22
            
            # Get color from config
            color_map = {
                "active": ws_cfg.get("button_active_bg", "blue"),
                "hover": ws_cfg.get("button_hover_bg", "purple"),
                "urgent": ws_cfg.get("button_urgent_bg", "red"),
                "normal": ws_cfg.get("button_normal_bg", "bg1"),
            }
            bg_color = self._get_color(color_map.get(state, "bg1"))
            
            cr.set_source_rgba(*_hex_to_rgba(bg_color))
            _draw_rounded_rect(cr, btn_x, 12, btn_w, h - 24, 8)
            cr.fill()
            
            # Label for non-normal
            if state != "normal":
                text_color_key = ws_cfg.get(f"button_{state}_text", "bg0")
                cr.set_source_rgba(*_hex_to_rgba(self._get_color(text_color_key)))
                cr.select_font_face("Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
                cr.set_font_size(9)
                cr.move_to(btn_x + btn_w/2 - 3, h/2 + 3)
                cr.show_text(str(i + 1))
            
            btn_x += btn_w + 4
        
        # Clock module
        clock_color = self._get_color(modules_cfg.get("clock", {}).get("color", "blue"))
        cr.set_source_rgba(*_hex_to_rgba(self._get_color("bg0"), 0.9))
        _draw_rounded_rect(cr, w/2 - 30, 8, 60, h - 16, 12)
        cr.fill()
        
        cr.set_source_rgba(*_hex_to_rgba(clock_color))
        cr.select_font_face("Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
        cr.set_font_size(10)
        cr.move_to(w/2 - 15, h/2 + 3)
        cr.show_text("12:45")
        
        # System modules
        mod_x = w - 180
        for icon, color_key in [
            ("C", modules_cfg.get("cpu", {}).get("color", "blue")),
            ("M", modules_cfg.get("memory", {}).get("color", "green")),
            ("V", modules_cfg.get("pulseaudio", {}).get("color", "yellow")),
            ("N", modules_cfg.get("network", {}).get("wifi", "purple")),
            ("B", modules_cfg.get("battery", {}).get("color", "green")),
        ]:
            cr.set_source_rgba(*_hex_to_rgba(self._get_color("bg0"), 0.9))
            _draw_rounded_rect(cr, mod_x, 8, 28, h - 16, 10)
            cr.fill()
            
            cr.set_source_rgba(*_hex_to_rgba(self._get_color(color_key)))
            cr.set_font_size(9)
            cr.move_to(mod_x + 10, h/2 + 3)
            cr.show_text(icon)
            
            mod_x += 32
    
    def _on_motion(self, ctrl, x, y):
        self.hover = "hover" if 14 <= x <= 144 else "normal"
        self.queue_draw()
    
    def _on_leave(self, ctrl):
        self.hover = "normal"
        self.queue_draw()
    
    def update_colors(self, colors: Dict):
        self.colors = colors.copy()
        self.queue_draw()
    
    def update_config(self, config: Dict):
        self.config = config.copy()
        self.queue_draw()
    
    def update_style(self, style: Dict):
        self.style = style.copy()
        self.queue_draw()


class RofiPreviewWidget(Gtk.DrawingArea):
    """Live preview widget for Rofi appearance"""
    
    def __init__(self, colors: Dict, rofi_config: Dict):
        super().__init__()
        self.colors = colors.copy()
        self.rofi = rofi_config.copy()
        
        self.set_content_width(240)
        self.set_content_height(140)
        self.set_draw_func(self._draw)
    
    def _get_color(self, name: str) -> str:
        if name in self.rofi:
            c = self.rofi[name]
            return c[:7] if len(c) == 9 else c
        return self.colors.get(name, "#888888")
    
    def _draw(self, area, cr, w, h):
        bg = self._get_color("background")
        bg_alt = self._get_color("background-alt")
        fg = self._get_color("foreground")
        selected = self._get_color("selected")
        
        # Window background
        cr.set_source_rgba(*_hex_to_rgba(bg))
        _draw_rounded_rect(cr, 0, 0, w, h, 10)
        cr.fill()
        
        # Border
        cr.set_source_rgba(*_hex_to_rgba(selected))
        _draw_rounded_rect(cr, 0, 0, w, h, 10)
        cr.set_line_width(2)
        cr.stroke()
        
        # Search bar
        cr.set_source_rgba(*_hex_to_rgba(bg_alt))
        _draw_rounded_rect(cr, 10, 10, w - 20, 26, 6)
        cr.fill()
        
        cr.set_source_rgba(*_hex_to_rgba(fg))
        cr.select_font_face("Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_NORMAL)
        cr.set_font_size(10)
        cr.move_to(16, 28)
        cr.show_text("Search...")
        
        # Items
        items = ["Firefox", "VS Code", "Kitty"]
        item_y = 46
        for i, name in enumerate(items):
            if i == 1:  # Selected
                cr.set_source_rgba(*_hex_to_rgba(selected))
                _draw_rounded_rect(cr, 10, item_y, w - 20, 24, 5)
                cr.fill()
                cr.set_source_rgba(*_hex_to_rgba(bg))
            else:
                cr.set_source_rgba(*_hex_to_rgba(fg))
            
            cr.set_font_size(10)
            cr.move_to(16, item_y + 17)
            cr.show_text(name)
            item_y += 30
    
    def update_rofi(self, rofi: Dict):
        self.rofi = rofi.copy()
        self.queue_draw()
    
    def update_colors(self, colors: Dict):
        self.colors = colors.copy()
        self.queue_draw()


class KittyPreviewWidget(Gtk.DrawingArea):
    """Live preview widget for Kitty terminal appearance"""
    
    def __init__(self, colors: Dict, kitty_config: Dict):
        super().__init__()
        self.colors = colors.copy()
        self.kitty = kitty_config.copy()
        
        self.set_content_width(240)
        self.set_content_height(110)
        self.set_draw_func(self._draw)
    
    def _get_color(self, name: str) -> str:
        return self.kitty.get(name, self.colors.get(name, "#888888"))
    
    def _draw(self, area, cr, w, h):
        bg = self._get_color("background")
        fg = self._get_color("foreground")
        cursor = self._get_color("cursor")
        green = self._get_color("color2")
        blue = self._get_color("color4")
        
        # Terminal window
        cr.set_source_rgba(*_hex_to_rgba(bg, 0.95))
        _draw_rounded_rect(cr, 0, 0, w, h, 8)
        cr.fill()
        
        # Border
        cr.set_source_rgba(*_hex_to_rgba(self.colors.get("bg3", "#444")))
        _draw_rounded_rect(cr, 0, 0, w, h, 8)
        cr.set_line_width(1)
        cr.stroke()
        
        # Terminal content
        cr.select_font_face("Monospace", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_NORMAL)
        cr.set_font_size(9)
        
        y = 16
        # Prompt + command
        cr.set_source_rgba(*_hex_to_rgba(green))
        cr.move_to(8, y)
        cr.show_text("user@arch")
        cr.set_source_rgba(*_hex_to_rgba(fg))
        cr.show_text(" ~ $ neofetch")
        
        # Neofetch output
        y += 14
        cr.set_source_rgba(*_hex_to_rgba(blue))
        cr.move_to(8, y)
        cr.show_text("    ████")
        cr.set_source_rgba(*_hex_to_rgba(fg))
        cr.show_text("  OS: Arch Linux")
        
        y += 14
        cr.set_source_rgba(*_hex_to_rgba(blue))
        cr.move_to(8, y)
        cr.show_text("    ████")
        cr.set_source_rgba(*_hex_to_rgba(fg))
        cr.show_text("  WM: Hyprland")
        
        # New prompt with cursor
        y += 18
        cr.set_source_rgba(*_hex_to_rgba(green))
        cr.move_to(8, y)
        cr.show_text("user@arch")
        cr.set_source_rgba(*_hex_to_rgba(fg))
        cr.show_text(" ~ $ ")
        
        # Cursor
        ext = cr.text_extents("user@arch ~ $ ")
        cr.set_source_rgba(*_hex_to_rgba(cursor))
        cr.rectangle(8 + ext.width, y - 9, 6, 11)
        cr.fill()
    
    def update_kitty(self, kitty: Dict):
        self.kitty = kitty.copy()
        self.queue_draw()
    
    def update_colors(self, colors: Dict):
        self.colors = colors.copy()
        self.queue_draw()
