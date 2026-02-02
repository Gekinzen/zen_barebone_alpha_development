"""UI COMPONENTS - All Reusable UI Elements including v2.1 features"""
import gi
gi.require_version('Gtk', '4.0')
from gi.repository import Gtk, Gdk
import math

COLOR_OPTIONS = ["bg0", "bg1", "bg2", "bg3", "bg4", "fg", "grey0", "grey1", "grey2",
                 "red", "orange", "yellow", "green", "aqua", "blue", "purple"]

def _hex_to_rgba(hex_color, alpha=1.0):
    h = hex_color.lstrip('#')[:6]
    if len(h) >= 6: return tuple(int(h[i:i+2], 16) / 255.0 for i in (0, 2, 4)) + (alpha,)
    return (0.5, 0.5, 0.5, alpha)

def _draw_rounded_rect(cr, x, y, w, h, r):
    cr.new_sub_path()
    cr.arc(x + w - r, y + r, r, -math.pi/2, 0)
    cr.arc(x + w - r, y + h - r, r, 0, math.pi/2)
    cr.arc(x + r, y + h - r, r, math.pi/2, math.pi)
    cr.arc(x + r, y + r, r, math.pi, 3*math.pi/2)
    cr.close_path()


class ClickableColorSwatch(Gtk.Box):
    """Clickable color swatch that opens a color picker dialog - v2.1 feature"""
    
    def __init__(self, key: str, label: str, hex_color: str, on_change):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        self.key = key
        self.hex_color = hex_color
        self.on_change = on_change
        self.set_halign(Gtk.Align.CENTER)
        
        self.swatch = Gtk.DrawingArea()
        self.swatch.set_content_width(40)
        self.swatch.set_content_height(40)
        self.swatch.set_draw_func(self._draw)
        
        click = Gtk.GestureClick()
        click.connect("pressed", self._on_click)
        self.swatch.add_controller(click)
        self.swatch.set_cursor(Gdk.Cursor.new_from_name("pointer", None))
        
        self.append(self.swatch)
        
        lbl = Gtk.Label(label=label)
        lbl.add_css_class("caption")
        lbl.add_css_class("dim-label")
        self.append(lbl)
    
    def _draw(self, area, cr, w, h):
        cr.set_source_rgba(*_hex_to_rgba(self.hex_color))
        _draw_rounded_rect(cr, 0, 0, w, h, 6)
        cr.fill()
        cr.set_source_rgba(1, 1, 1, 0.2)
        cr.set_line_width(1)
        _draw_rounded_rect(cr, 0.5, 0.5, w - 1, h - 1, 6)
        cr.stroke()
    
    def _on_click(self, gesture, n_press, x, y):
        window = self.get_root()
        dialog = Gtk.ColorChooserDialog(title=f"Choose {self.key} Color", transient_for=window, use_alpha=False)
        rgba = Gdk.RGBA()
        rgba.parse(self.hex_color)
        dialog.set_rgba(rgba)
        dialog.connect("response", self._on_color_response)
        dialog.present()
    
    def _on_color_response(self, dialog, response):
        if response == Gtk.ResponseType.OK:
            rgba = dialog.get_rgba()
            self.hex_color = "#{:02x}{:02x}{:02x}".format(int(rgba.red * 255), int(rgba.green * 255), int(rgba.blue * 255))
            self.swatch.queue_draw()
            self.on_change(self.key, self.hex_color)
        dialog.destroy()
    
    def set_color(self, hex_color: str):
        self.hex_color = hex_color
        self.swatch.queue_draw()


class ModuleColorRow(Gtk.Box):
    """Row for customizing individual module colors - v2.1 feature"""
    
    def __init__(self, module_name: str, icon: str, current_color: str, on_change):
        super().__init__(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        self.module_name = module_name
        self.on_change = on_change
        self.hex_color = current_color
        
        self.set_margin_start(8)
        self.set_margin_end(8)
        self.set_margin_top(4)
        self.set_margin_bottom(4)
        
        icon_lbl = Gtk.Label(label=icon)
        icon_lbl.set_size_request(24, -1)
        icon_lbl.add_css_class("title-4")
        self.append(icon_lbl)
        
        name_lbl = Gtk.Label(label=module_name.replace("_", " ").title())
        name_lbl.set_xalign(0)
        name_lbl.set_hexpand(True)
        self.append(name_lbl)
        
        self.swatch = Gtk.DrawingArea()
        self.swatch.set_content_width(24)
        self.swatch.set_content_height(24)
        self.swatch.set_draw_func(self._draw)
        
        swatch_btn = Gtk.Button()
        swatch_btn.set_child(self.swatch)
        swatch_btn.connect("clicked", self._on_click)
        swatch_btn.set_tooltip_text("Change color")
        self.append(swatch_btn)
        
        self.entry = Gtk.Entry()
        self.entry.set_text(current_color)
        self.entry.set_max_length(7)
        self.entry.set_width_chars(8)
        self.entry.connect("changed", self._on_entry_changed)
        self.append(self.entry)
    
    def _draw(self, area, cr, w, h):
        cr.set_source_rgba(*_hex_to_rgba(self.hex_color))
        _draw_rounded_rect(cr, 2, 2, w - 4, h - 4, 4)
        cr.fill()
    
    def _on_click(self, btn):
        window = self.get_root()
        dialog = Gtk.ColorChooserDialog(title=f"Choose {self.module_name} Color", transient_for=window, use_alpha=False)
        rgba = Gdk.RGBA()
        rgba.parse(self.hex_color)
        dialog.set_rgba(rgba)
        dialog.connect("response", self._on_color_response)
        dialog.present()
    
    def _on_color_response(self, dialog, response):
        if response == Gtk.ResponseType.OK:
            rgba = dialog.get_rgba()
            self.hex_color = "#{:02x}{:02x}{:02x}".format(int(rgba.red * 255), int(rgba.green * 255), int(rgba.blue * 255))
            self.entry.set_text(self.hex_color)
            self.swatch.queue_draw()
            self.on_change(self.module_name, self.hex_color)
        dialog.destroy()
    
    def _on_entry_changed(self, entry):
        text = entry.get_text()
        if len(text) == 7 and text.startswith('#'):
            try:
                int(text[1:], 16)
                self.hex_color = text
                self.swatch.queue_draw()
                self.on_change(self.module_name, text)
            except: pass


class ColorPickerRow(Gtk.Box):
    """Standard color picker row with swatch + entry"""
    def __init__(self, label, key, hex_val, on_change):
        super().__init__(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        self.key, self.on_change, self.hex = key, on_change, hex_val
        self.set_margin_start(8); self.set_margin_end(8); self.set_margin_top(4); self.set_margin_bottom(4)
        
        self.swatch = Gtk.DrawingArea()
        self.swatch.set_content_width(24); self.swatch.set_content_height(24)
        self.swatch.set_draw_func(lambda a,cr,w,h: (cr.set_source_rgba(*_hex_to_rgba(self.hex)), _draw_rounded_rect(cr,0,0,w,h,5), cr.fill()))
        click = Gtk.GestureClick(); click.connect("pressed", self._on_click); self.swatch.add_controller(click)
        self.append(self.swatch)
        
        lbl = Gtk.Label(label=label); lbl.set_xalign(0); lbl.set_size_request(90, -1); self.append(lbl)
        
        self.entry = Gtk.Entry(); self.entry.set_text(hex_val); self.entry.set_max_length(7); self.entry.set_width_chars(9)
        self.entry.connect("changed", self._on_entry); self.append(self.entry)
    
    def _on_click(self, g, n, x, y):
        dialog = Gtk.ColorChooserDialog(title=f"Choose {self.key}", transient_for=self.get_root(), use_alpha=False)
        rgba = Gdk.RGBA(); rgba.parse(self.hex); dialog.set_rgba(rgba)
        dialog.connect("response", self._on_color); dialog.present()
    
    def _on_color(self, d, r):
        if r == Gtk.ResponseType.OK:
            rgba = d.get_rgba()
            self.hex = "#{:02x}{:02x}{:02x}".format(int(rgba.red * 255), int(rgba.green * 255), int(rgba.blue * 255))
            self.entry.set_text(self.hex); self.swatch.queue_draw(); self.on_change(self.key, self.hex)
        d.destroy()
    
    def _on_entry(self, e):
        t = e.get_text()
        if len(t) == 7 and t.startswith('#'):
            try: int(t[1:], 16); self.hex = t; self.swatch.queue_draw(); self.on_change(self.key, t)
            except: pass
    
    def set_color(self, color):
        """Set color programmatically - used for preset sync"""
        # Convert theme vars to hex
        if color.startswith("@"):
            color_map = {"@blue": "#61afef", "@green": "#98c379", "@yellow": "#e5c07b",
                        "@orange": "#d19a66", "@purple": "#c678dd", "@red": "#e06c75", 
                        "@fg": "#abb2bf", "@bg0": "#282c34", "@bg1": "#353b45"}
            color = color_map.get(color, "#61afef")
        # Handle rgba values - extract or use default
        if color.startswith("rgba") or color.startswith("alpha"):
            color = "#61afef"  # Default for complex values
        self.hex = color
        self.entry.set_text(color)
        self.swatch.queue_draw()


class ColorVariableDropdown(Gtk.Box):
    """Dropdown to select theme color variable"""
    def __init__(self, label, current, colors, on_change):
        super().__init__(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        self.colors, self.on_change, self.current = colors, on_change, current
        self.key = label.lower().replace(" ", "_")
        self.set_margin_start(8); self.set_margin_end(8); self.set_margin_top(4); self.set_margin_bottom(4)
        
        lbl = Gtk.Label(label=label); lbl.set_xalign(0); lbl.set_size_request(110, -1); self.append(lbl)
        
        self.swatch = Gtk.DrawingArea(); self.swatch.set_content_width(18); self.swatch.set_content_height(18)
        self.swatch.set_draw_func(self._draw); self.append(self.swatch)
        
        self.dropdown = Gtk.DropDown()
        model = Gtk.StringList()
        for opt in COLOR_OPTIONS: model.append(opt)
        self.dropdown.set_model(model)
        try: self.dropdown.set_selected(COLOR_OPTIONS.index(current))
        except: self.dropdown.set_selected(0)
        self.dropdown.connect("notify::selected", self._on_changed); self.append(self.dropdown)
    
    def _draw(self, area, cr, w, h):
        cr.set_source_rgba(*_hex_to_rgba(self.colors.get(self.current, "#888888")))
        cr.arc(w/2, h/2, min(w, h)/2 - 1, 0, 2 * math.pi); cr.fill()
    
    def _on_changed(self, dd, _):
        idx = dd.get_selected()
        if idx != Gtk.INVALID_LIST_POSITION:
            self.current = COLOR_OPTIONS[idx]; self.swatch.queue_draw(); self.on_change(self.key, self.current)
    
    def update_colors(self, c): self.colors = c; self.swatch.queue_draw()


# Helper functions
def create_group(title):
    group = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
    group.add_css_class("card"); group.set_margin_bottom(8)
    lbl = Gtk.Label(label=title); lbl.add_css_class("caption"); lbl.set_xalign(0)
    lbl.set_margin_start(16); lbl.set_margin_top(12); lbl.set_margin_bottom(4)
    group.append(lbl)
    return group

def create_section_header(title: str) -> Gtk.Label:
    header = Gtk.Label(label=title)
    header.add_css_class("heading")
    header.set_xalign(0)
    header.set_margin_top(20)
    header.set_margin_bottom(12)
    header.set_margin_start(4)
    return header

def create_setting_row(title: str, description: str = None) -> Gtk.Box:
    row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
    row.set_margin_top(8); row.set_margin_bottom(8)
    label_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
    label_box.set_hexpand(True)
    title_lbl = Gtk.Label(label=title); title_lbl.set_xalign(0)
    label_box.append(title_lbl)
    if description:
        desc_lbl = Gtk.Label(label=description); desc_lbl.set_xalign(0)
        desc_lbl.add_css_class("dim-label"); desc_lbl.add_css_class("caption")
        label_box.append(desc_lbl)
    row.append(label_box)
    return row

def create_swatch(key, label, hex_color):
    b = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4); b.set_halign(Gtk.Align.CENTER)
    s = Gtk.DrawingArea(); s.set_content_width(40); s.set_content_height(40); s.hex_color = hex_color
    s.set_draw_func(lambda a,cr,w,h: (cr.set_source_rgba(*_hex_to_rgba(a.hex_color)), _draw_rounded_rect(cr,0,0,w,h,6), cr.fill()))
    b.append(s)
    l = Gtk.Label(label=label); l.add_css_class("caption"); l.add_css_class("dim-label"); b.append(l)
    b.swatch = s
    return b

def create_size_buttons(sizes, current, on_change, window):
    box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0); box.add_css_class('linked')
    btns = []
    for name, val in sizes:
        btn = Gtk.ToggleButton(label=name)
        if val == current: btn.set_active(True)
        btns.append(btn); box.append(btn)
    def tog(b, v, grp):
        if b.get_active():
            for x in grp:
                if x != b and x.get_active(): x.set_active(False)
            on_change(v, window)
    for i, b in enumerate(btns): b.connect('toggled', lambda b, v=sizes[i][1], g=btns: tog(b, v, g))
    return box