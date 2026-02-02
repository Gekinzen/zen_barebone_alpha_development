"""PREVIEW WIDGETS - Waybar, Rofi, Kitty Previews"""
import gi
gi.require_version('Gtk', '4.0')
from gi.repository import Gtk
import math, cairo

def _hex_rgba(h, a=1.0):
    h = h.lstrip('#')[:6]
    return tuple(int(h[i:i+2], 16)/255.0 for i in (0,2,4)) + (a,) if len(h) >= 6 else (0.5,0.5,0.5,a)

def _rounded_rect(cr, x, y, w, h, r):
    cr.new_sub_path()
    cr.arc(x+w-r, y+r, r, -math.pi/2, 0); cr.arc(x+w-r, y+h-r, r, 0, math.pi/2)
    cr.arc(x+r, y+h-r, r, math.pi/2, math.pi); cr.arc(x+r, y+r, r, math.pi, 3*math.pi/2)
    cr.close_path()

class WaybarPreviewWidget(Gtk.DrawingArea):
    def __init__(self, colors, waybar_config):
        super().__init__()
        self.colors, self.waybar_config, self.hover = colors.copy(), waybar_config.copy(), "normal"
        self.set_content_width(540); self.set_content_height(48); self.set_draw_func(self._draw)
        m = Gtk.EventControllerMotion()
        m.connect("motion", lambda c,x,y: (setattr(self,'hover','hover' if 10<=x<=140 else 'normal'), self.queue_draw()))
        m.connect("leave", lambda c: (setattr(self,'hover','normal'), self.queue_draw()))
        self.add_controller(m)
    
    def _draw(self, a, cr, w, h):
        op = self.waybar_config.get("global", {}).get("window_opacity", 0.5)
        cr.set_source_rgba(*_hex_rgba(self.colors.get("bg0", "#282c34"), op))
        _rounded_rect(cr, 2, 2, w-4, h-4, 20); cr.fill()
        ws = self.waybar_config.get("workspaces", {})
        cr.set_source_rgba(*_hex_rgba(self.colors.get("bg0", "#282c34"), 0.21))
        _rounded_rect(cr, 10, 6, 120, h-12, 10); cr.fill()
        states = ["normal","hover","active","urgent"] if self.hover == "hover" else ["normal","normal","active","normal"]
        bx = 14
        for i, st in enumerate(states):
            bw = 30 if st != "normal" else 22
            bg = {"active":"blue","hover":"purple","urgent":"red","normal":"bg1"}
            cr.set_source_rgba(*_hex_rgba(self.colors.get(ws.get(f"button_{st}_bg", bg.get(st)), "#21252b")))
            _rounded_rect(cr, bx, 9, bw, h-18, 6); cr.fill()
            if st != "normal":
                cr.set_source_rgba(*_hex_rgba(self.colors.get("bg0","#282c34")))
                cr.select_font_face("Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
                cr.set_font_size(8); cr.move_to(bx+bw/2-3, h/2+3); cr.show_text(str(i+1))
            bx += bw + 4
        cr.set_source_rgba(*_hex_rgba(self.colors.get("bg0","#282c34"), 0.9))
        _rounded_rect(cr, w/2-25, 6, 50, h-12, 10); cr.fill()
        cr.set_source_rgba(*_hex_rgba(self.colors.get("blue","#61afef")))
        cr.set_font_size(9); cr.move_to(w/2-15, h/2+3); cr.show_text("12:45")
    
    def update_colors(self, c): self.colors = c.copy(); self.queue_draw()
    def update_waybar_config(self, c): self.waybar_config = c.copy(); self.queue_draw()

class RofiPreviewWidget(Gtk.DrawingArea):
    def __init__(self, colors, rofi):
        super().__init__()
        self.colors, self.rofi = colors.copy(), rofi.copy()
        self.set_content_width(240); self.set_content_height(140); self.set_draw_func(self._draw)
    
    def _draw(self, a, cr, w, h):
        bg, fg = self.rofi.get("background", self.colors.get("bg0","#282c34"))[:7], self.rofi.get("foreground", self.colors.get("fg","#abb2bf"))[:7]
        sel = self.rofi.get("selected", self.colors.get("blue","#61afef"))[:7]
        cr.set_source_rgba(*_hex_rgba(bg)); _rounded_rect(cr, 0, 0, w, h, 8); cr.fill()
        cr.set_source_rgba(*_hex_rgba(sel)); _rounded_rect(cr, 0, 0, w, h, 8); cr.set_line_width(2); cr.stroke()
        cr.set_source_rgba(*_hex_rgba(fg)); cr.select_font_face("Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_NORMAL)
        cr.set_font_size(9); cr.move_to(16, 27); cr.show_text("Search...")
        iy = 44
        for i, name in enumerate(["Firefox", "VS Code", "Kitty"]):
            if i == 1:
                cr.set_source_rgba(*_hex_rgba(sel)); _rounded_rect(cr, 10, iy, w-20, 24, 5); cr.fill()
                cr.set_source_rgba(*_hex_rgba(bg))
            else: cr.set_source_rgba(*_hex_rgba(fg))
            cr.set_font_size(9); cr.move_to(16, iy+16); cr.show_text(name); iy += 30
    
    def update_rofi(self, r): self.rofi = r.copy(); self.queue_draw()
    def update_colors(self, c): self.colors = c.copy(); self.queue_draw()

class KittyPreviewWidget(Gtk.DrawingArea):
    def __init__(self, colors, kitty):
        super().__init__()
        self.colors, self.kitty = colors.copy(), kitty.copy()
        self.set_content_width(240); self.set_content_height(110); self.set_draw_func(self._draw)
    
    def _draw(self, a, cr, w, h):
        bg, fg = self.kitty.get("background", self.colors.get("bg0","#282c34")), self.kitty.get("foreground", self.colors.get("fg","#abb2bf"))
        cr.set_source_rgba(*_hex_rgba(bg, 0.95)); _rounded_rect(cr, 0, 0, w, h, 6); cr.fill()
        cr.set_source_rgba(*_hex_rgba(self.colors.get("bg3","#444"))); _rounded_rect(cr, 0, 0, w, h, 6); cr.set_line_width(1); cr.stroke()
        cr.select_font_face("Monospace", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_NORMAL); cr.set_font_size(8)
        cr.set_source_rgba(*_hex_rgba(self.colors.get("green","#98c379"))); cr.move_to(6, 14); cr.show_text("user@arch")
        cr.set_source_rgba(*_hex_rgba(fg)); cr.show_text(" ~ $ neofetch")
    
    def update_kitty(self, k): self.kitty = k.copy(); self.queue_draw()
    def update_colors(self, c): self.colors = c.copy(); self.queue_draw()
