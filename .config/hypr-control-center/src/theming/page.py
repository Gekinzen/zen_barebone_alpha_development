"""
THEMING PAGE - Complete theme + panel appearance management
Theme applies to: Control Center, Waybar, Rofi, Kitty
Panel Appearance: Opacity, Radius, Font, Height, Margins, Monitor
"""

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
from gi.repository import Gtk, Adw
from pathlib import Path
import re
import subprocess
import json

from .themes import THEMES, get_theme_list, get_theme_colors
from .theme_applier import ThemeApplier


COLOR_OPTIONS = ["bg0", "bg1", "bg2", "bg3", "bg4", "fg", "grey0", "grey1", "grey2",
                 "red", "orange", "yellow", "green", "aqua", "blue", "purple"]


# ═══════════════════════════════════════════════════════════════════════════════
# MONITOR DETECTION
# ═══════════════════════════════════════════════════════════════════════════════

def get_monitor_list() -> list:
    """Parse monitors from hyprland monitors.conf"""
    monitors = ["All Monitors"]
    
    # Try monitors.conf first
    for path in [Path.home() / ".config/hypr/monitors.conf",
                 Path.home() / ".config/hypr/hyprland.conf"]:
        if path.exists():
            try:
                for line in path.read_text().split('\n'):
                    line = line.strip()
                    if line.startswith('monitor=') and not line.startswith('#'):
                        parts = line[8:].split(',')
                        if parts:
                            name = parts[0].strip()
                            if name and name not in monitors and name != "":
                                monitors.append(name)
            except:
                pass
    
    # Fallback to hyprctl
    if len(monitors) == 1:
        try:
            result = subprocess.run(['hyprctl', 'monitors', '-j'], capture_output=True, text=True, timeout=2)
            if result.returncode == 0:
                for mon in json.loads(result.stdout):
                    name = mon.get('name', '')
                    if name and name not in monitors:
                        monitors.append(name)
        except:
            pass
    
    return monitors


# ═══════════════════════════════════════════════════════════════════════════════
# WAYBAR CSS MANAGER - Matches YOUR style.css format
# ═══════════════════════════════════════════════════════════════════════════════

class WaybarCSSManager:
    """Direct editing of Waybar style.css"""
    
    def __init__(self):
        self.style_file = Path.home() / ".config/waybar/style.css"
        self.css = ""
        self.load()
    
    def load(self):
        if self.style_file.exists():
            self.css = self.style_file.read_text()
    
    def save(self):
        self.style_file.write_text(self.css)
    
    def reload_waybar(self):
        subprocess.run(['pkill', '-SIGUSR2', 'waybar'], check=False)
    
    # ═══════════════════════════════════════════════════════════════════════════
    # WINDOW#WAYBAR
    # Format: window#waybar { background: alpha(@bg0, 0.6); border-radius: 0px; }
    # ═══════════════════════════════════════════════════════════════════════════
    
    def get_window_opacity(self) -> float:
        # Match: background: alpha(@bg0, 0.57);
        m = re.search(r'window#waybar\s*\{[^}]*background:\s*alpha\s*\(\s*@bg0\s*,\s*([0-9.]+)\s*\)', 
                      self.css, re.DOTALL | re.IGNORECASE)
        return float(m.group(1)) if m else 0.57
    
    def set_window_opacity(self, val: float):
        pattern = r'(window#waybar\s*\{[^}]*background:\s*alpha\s*\(\s*@bg0\s*,\s*)[0-9.]+(\s*\))'
        if re.search(pattern, self.css, re.DOTALL | re.IGNORECASE):
            self.css = re.sub(pattern, f'\\g<1>{val:.2f}\\2', self.css, flags=re.DOTALL | re.IGNORECASE)
    
    def get_window_border_radius(self) -> int:
        m = re.search(r'window#waybar\s*\{[^}]*border-radius:\s*(\d+)px', self.css, re.DOTALL)
        return int(m.group(1)) if m else 0
    
    def set_window_border_radius(self, val: int):
        pattern = r'(window#waybar\s*\{[^}]*border-radius:\s*)\d+px'
        if re.search(pattern, self.css, re.DOTALL):
            self.css = re.sub(pattern, f'\\g<1>{val}px', self.css, flags=re.DOTALL)
    
    # ═══════════════════════════════════════════════════════════════════════════
    # #WORKSPACES
    # Format: #workspaces { background-color: alpha(@bg0, 0.21); border-radius: 26px; }
    # ═══════════════════════════════════════════════════════════════════════════
    
    def get_workspaces_opacity(self) -> float:
        m = re.search(r'#workspaces\s*\{[^}]*background-color:\s*alpha\s*\(\s*@bg0\s*,\s*([0-9.]+)\s*\)',
                      self.css, re.DOTALL)
        return float(m.group(1)) if m else 0.21
    
    def set_workspaces_opacity(self, val: float):
        pattern = r'(#workspaces\s*\{[^}]*background-color:\s*alpha\s*\(\s*@bg0\s*,\s*)[0-9.]+(\s*\))'
        if re.search(pattern, self.css, re.DOTALL):
            self.css = re.sub(pattern, f'\\g<1>{val:.2f}\\2', self.css, flags=re.DOTALL)
    
    def get_workspaces_border_radius(self) -> int:
        m = re.search(r'#workspaces\s*\{[^}]*border-radius:\s*(\d+)px', self.css, re.DOTALL)
        return int(m.group(1)) if m else 26
    
    def set_workspaces_border_radius(self, val: int):
        pattern = r'(#workspaces\s*\{[^}]*border-radius:\s*)\d+px'
        if re.search(pattern, self.css, re.DOTALL):
            self.css = re.sub(pattern, f'\\g<1>{val}px', self.css, flags=re.DOTALL)
    
    # ═══════════════════════════════════════════════════════════════════════════
    # #workspaces button
    # ═══════════════════════════════════════════════════════════════════════════
    
    def get_ws_button_radius(self) -> int:
        m = re.search(r'#workspaces\s+button\s*\{[^}]*border-radius:\s*(\d+)px', self.css, re.DOTALL)
        return int(m.group(1)) if m else 16
    
    def set_ws_button_radius(self, val: int):
        for pat in [r'(#workspaces\s+button\s*\{[^}]*border-radius:\s*)\d+px',
                    r'(#workspaces\s+button\.active\s*\{[^}]*border-radius:\s*)\d+px',
                    r'(#workspaces\s+button:hover\s*\{[^}]*border-radius:\s*)\d+px',
                    r'(#workspaces\s+button\.urgent\s*\{[^}]*border-radius:\s*)\d+px']:
            if re.search(pat, self.css, re.DOTALL):
                self.css = re.sub(pat, f'\\g<1>{val}px', self.css, flags=re.DOTALL)
    
    def get_ws_button_active_width(self) -> int:
        m = re.search(r'#workspaces\s+button\.active\s*\{[^}]*min-width:\s*(\d+)px', self.css, re.DOTALL)
        return int(m.group(1)) if m else 50
    
    def set_ws_button_active_width(self, val: int):
        for pat in [r'(#workspaces\s+button\.active\s*\{[^}]*min-width:\s*)\d+px',
                    r'(#workspaces\s+button:hover\s*\{[^}]*min-width:\s*)\d+px',
                    r'(#workspaces\s+button\.urgent\s*\{[^}]*min-width:\s*)\d+px']:
            if re.search(pat, self.css, re.DOTALL):
                self.css = re.sub(pat, f'\\g<1>{val}px', self.css, flags=re.DOTALL)
    
    def get_ws_button_color(self, state: str) -> str:
        """state: normal, active, hover, urgent"""
        if state == "normal":
            m = re.search(r'#workspaces\s+button\s*\{[^}]*background-color:\s*@(\w+)', self.css, re.DOTALL)
        elif state == "hover":
            m = re.search(r'#workspaces\s+button:hover\s*\{[^}]*background-color:\s*@(\w+)', self.css, re.DOTALL)
        else:
            m = re.search(rf'#workspaces\s+button\.{state}\s*\{{[^}}]*background-color:\s*@(\w+)', self.css, re.DOTALL)
        
        defaults = {"normal": "bg1", "active": "blue", "hover": "purple", "urgent": "red"}
        return m.group(1) if m else defaults.get(state, "bg1")
    
    def set_ws_button_color(self, state: str, color: str):
        if state == "normal":
            pat = r'(#workspaces\s+button\s*\{[^}]*background-color:\s*)@\w+'
        elif state == "hover":
            pat = r'(#workspaces\s+button:hover\s*\{[^}]*background-color:\s*)@\w+'
        else:
            pat = rf'(#workspaces\s+button\.{state}\s*\{{[^}}]*background-color:\s*)@\w+'
        
        if re.search(pat, self.css, re.DOTALL):
            self.css = re.sub(pat, f'\\g<1>@{color}', self.css, flags=re.DOTALL)
    
    # ═══════════════════════════════════════════════════════════════════════════
    # Module Colors (#cpu, #memory, etc)
    # ═══════════════════════════════════════════════════════════════════════════
    
    def get_module_color(self, mod: str) -> str:
        m = re.search(rf'#{mod}\s*\{{[^}}]*\n\s*color:\s*@(\w+)', self.css, re.DOTALL)
        defaults = {"cpu": "blue", "memory": "green", "temperature": "orange",
                    "pulseaudio": "yellow", "battery": "green", "bluetooth": "blue",
                    "clock": "blue", "network": "purple"}
        return m.group(1) if m else defaults.get(mod, "fg")
    
    def set_module_color(self, mod: str, color: str):
        # Match: #cpu {\n    color: @blue;
        pat = rf'(#{mod}\s*\{{[^}}]*\n\s*color:\s*)@\w+'
        if re.search(pat, self.css, re.DOTALL):
            self.css = re.sub(pat, f'\\g<1>@{color}', self.css, flags=re.DOTALL)
    
    def get_modules_border_radius(self) -> int:
        # Match combined selector: #battery, #pulseaudio, ... { border-radius: 45px; }
        m = re.search(r'#battery[^{]*\{[^}]*border-radius:\s*(\d+)px', self.css, re.DOTALL)
        return int(m.group(1)) if m else 45
    
    def set_modules_border_radius(self, val: int):
        pat = r'(#battery[^{]*\{[^}]*border-radius:\s*)\d+px'
        if re.search(pat, self.css, re.DOTALL):
            self.css = re.sub(pat, f'\\g<1>{val}px', self.css, flags=re.DOTALL)
    
    # ═══════════════════════════════════════════════════════════════════════════
    # Font Size
    # Format: * { font-family: ...; font-size: 16px; }
    # ═══════════════════════════════════════════════════════════════════════════
    
    def get_font_size(self) -> int:
        m = re.search(r'\*\s*\{[^}]*font-size:\s*(\d+)px', self.css, re.DOTALL)
        return int(m.group(1)) if m else 16
    
    def set_font_size(self, val: int):
        pat = r'(\*\s*\{[^}]*font-size:\s*)\d+px'
        if re.search(pat, self.css, re.DOTALL):
            self.css = re.sub(pat, f'\\g<1>{val}px', self.css, flags=re.DOTALL)


# ═══════════════════════════════════════════════════════════════════════════════
# WAYBAR CONFIG MANAGER (config.jsonc)
# ═══════════════════════════════════════════════════════════════════════════════

class WaybarConfigManager:
    def __init__(self):
        self.config_file = Path.home() / ".config/waybar/config.jsonc"
        self.config = {}
        self.load()
    
    def load(self):
        if self.config_file.exists():
            try:
                content = self.config_file.read_text()
                # Strip comments
                content = re.sub(r'//.*?\n', '\n', content)
                content = re.sub(r'/\*.*?\*/', '', content, flags=re.DOTALL)
                self.config = json.loads(content)
            except:
                self.config = {}
    
    def save(self):
        self.config_file.write_text(json.dumps(self.config, indent=2))
    
    def get(self, key, default=None):
        return self.config.get(key, default)
    
    def set(self, key, val):
        if val is None or (isinstance(val, str) and val == ""):
            self.config.pop(key, None)
        else:
            self.config[key] = val


# ═══════════════════════════════════════════════════════════════════════════════
# UI WIDGETS
# ═══════════════════════════════════════════════════════════════════════════════

class SettingRow(Gtk.Box):
    def __init__(self, label: str, desc: str = ""):
        super().__init__(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        self.set_margin_start(16); self.set_margin_end(16)
        self.set_margin_top(8); self.set_margin_bottom(8)
        
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        box.set_hexpand(True)
        
        lbl = Gtk.Label(label=label)
        lbl.set_xalign(0)
        lbl.add_css_class('heading')
        box.append(lbl)
        
        if desc:
            d = Gtk.Label(label=desc)
            d.set_xalign(0)
            d.add_css_class('dim-label')
            box.append(d)
        
        self.append(box)


class OpacityRow(SettingRow):
    def __init__(self, label, value, on_change, desc=""):
        super().__init__(label, desc)
        self.lbl = Gtk.Label(label=f"{int(value*100)}%")
        self.lbl.set_width_chars(5)
        self.append(self.lbl)
        
        self.scale = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 1, 0.01)
        self.scale.set_value(value)
        self.scale.set_draw_value(False)
        self.scale.set_size_request(150, -1)
        self.scale.connect("value-changed", lambda s: (
            self.lbl.set_label(f"{int(s.get_value()*100)}%"),
            on_change(s.get_value())
        ))
        self.append(self.scale)


class SpinRow(SettingRow):
    def __init__(self, label, value, min_v, max_v, on_change, desc=""):
        super().__init__(label, desc)
        adj = Gtk.Adjustment(value=value, lower=min_v, upper=max_v, step_increment=1)
        self.spin = Gtk.SpinButton(adjustment=adj)
        self.spin.connect("value-changed", lambda s: on_change(int(s.get_value())))
        self.append(self.spin)


class DropdownRow(SettingRow):
    def __init__(self, label, options, current, on_change, desc=""):
        super().__init__(label, desc)
        self.options = options
        self.dd = Gtk.DropDown()
        model = Gtk.StringList()
        for o in options:
            model.append(str(o))
        self.dd.set_model(model)
        try:
            self.dd.set_selected(options.index(current))
        except:
            self.dd.set_selected(0)
        self.dd.connect("notify::selected", lambda d, p: on_change(options[d.get_selected()]))
        self.append(self.dd)


class ColorDropdownRow(SettingRow):
    def __init__(self, label, current, on_change, desc=""):
        super().__init__(label, desc)
        self.dd = Gtk.DropDown()
        model = Gtk.StringList()
        for o in COLOR_OPTIONS:
            model.append(o)
        self.dd.set_model(model)
        try:
            self.dd.set_selected(COLOR_OPTIONS.index(current))
        except:
            self.dd.set_selected(0)
        self.dd.connect("notify::selected", lambda d, p: on_change(COLOR_OPTIONS[d.get_selected()]))
        self.append(self.dd)


class ToggleRow(SettingRow):
    def __init__(self, label, value, on_change, desc=""):
        super().__init__(label, desc)
        self.sw = Gtk.Switch()
        self.sw.set_active(value)
        self.sw.set_valign(Gtk.Align.CENTER)
        self.sw.connect("notify::active", lambda s, p: on_change(s.get_active()))
        self.append(self.sw)


def _group(title: str) -> Gtk.Box:
    g = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
    g.add_css_class('card')
    g.set_margin_bottom(16)
    lbl = Gtk.Label(label=title)
    lbl.add_css_class('caption')
    lbl.add_css_class('dim-label')
    lbl.set_xalign(0)
    lbl.set_margin_start(16)
    lbl.set_margin_top(12)
    lbl.set_margin_bottom(8)
    g.append(lbl)
    return g


def _swatch(color: str, name: str) -> Gtk.Box:
    box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
    area = Gtk.DrawingArea()
    area.set_size_request(36, 36)
    css = Gtk.CssProvider()
    css.load_from_data(f"* {{ background-color: {color}; border-radius: 6px; }}".encode())
    area.get_style_context().add_provider(css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
    box.append(area)
    lbl = Gtk.Label(label=name)
    lbl.add_css_class('caption')
    box.append(lbl)
    return box


# ═══════════════════════════════════════════════════════════════════════════════
# MAIN PAGE BUILDER
# ═══════════════════════════════════════════════════════════════════════════════

def build_theming_page(window) -> Gtk.ScrolledWindow:
    scrolled = Gtk.ScrolledWindow()
    scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
    
    content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
    content.add_css_class('content-area')
    
    # Init managers
    applier = ThemeApplier()
    wcm = WaybarCSSManager()
    wcfg = WaybarConfigManager()
    window._theme_applier = applier
    window._waybar_css = wcm
    window._waybar_cfg = wcfg
    
    # Header
    header = window._create_page_header("Theming", 
        "Apply themes and customize panel appearance")
    content.append(header)
    
    main = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16)
    main.set_margin_start(32)
    main.set_margin_end(32)
    main.set_margin_bottom(32)
    
    def apply_css():
        wcm.save()
        wcm.reload_waybar()
    
    def apply_cfg():
        wcfg.save()
        wcm.reload_waybar()
    
    # ═══════════════════════════════════════════════════════════════════════════
    # 1. GLOBAL THEME
    # ═══════════════════════════════════════════════════════════════════════════
    theme_grp = _group("GLOBAL THEME")
    
    current = applier.get_current_theme()
    themes = get_theme_list()
    names = [t["name"] for t in themes]
    ids = [t["id"] for t in themes]
    idx = ids.index(current) if current in ids else 0
    
    # Theme dropdown row
    row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
    row.set_margin_start(16); row.set_margin_end(16)
    row.set_margin_top(8); row.set_margin_bottom(8)
    
    lbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
    lbox.set_hexpand(True)
    lbl = Gtk.Label(label="Color Scheme")
    lbl.set_xalign(0)
    lbl.add_css_class('heading')
    lbox.append(lbl)
    desc = Gtk.Label(label="Applies to: Control Center, Waybar, Rofi, Kitty")
    desc.set_xalign(0)
    desc.add_css_class('dim-label')
    lbox.append(desc)
    row.append(lbox)
    
    dd = Gtk.DropDown()
    model = Gtk.StringList()
    for n in names:
        model.append(n)
    dd.set_model(model)
    dd.set_selected(idx)
    
    # Color preview
    preview_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
    preview_box.set_margin_start(16)
    preview_box.set_margin_bottom(12)
    
    def update_preview(theme_id):
        # Clear
        child = preview_box.get_first_child()
        while child:
            nxt = child.get_next_sibling()
            preview_box.remove(child)
            child = nxt
        # Add swatches
        colors = get_theme_colors(theme_id)
        for key, name in [("bg0", "BG"), ("fg", "FG"), ("blue", "Blue"), 
                          ("purple", "Purple"), ("green", "Green"), ("red", "Red")]:
            if key in colors:
                preview_box.append(_swatch(colors[key], name))
    
    update_preview(current)
    
    def on_theme(d, p):
        i = d.get_selected()
        if i != Gtk.INVALID_LIST_POSITION:
            tid = ids[i]
            if applier.apply_theme(tid):
                window._show_toast(f"Theme: {names[i]} applied!")
                update_preview(tid)
    
    dd.connect("notify::selected", on_theme)
    row.append(dd)
    theme_grp.append(row)
    theme_grp.append(preview_box)
    
    info = Gtk.Label(label="✓ Control Center  ✓ Waybar  ✓ Rofi  ✓ Kitty")
    info.add_css_class('dim-label')
    info.set_margin_start(16)
    info.set_margin_bottom(12)
    info.set_xalign(0)
    theme_grp.append(info)
    main.append(theme_grp)
    
    # ═══════════════════════════════════════════════════════════════════════════
    # 2. PANEL BEHAVIOR
    # ═══════════════════════════════════════════════════════════════════════════
    behavior_grp = _group("PANEL BEHAVIOR")
    
    # Position
    behavior_grp.append(DropdownRow("Position", ["top", "bottom"],
        wcfg.get("position", "bottom"),
        lambda v: (wcfg.set("position", v), apply_cfg()),
        "Panel location on screen"))
    
    # Monitor selection
    monitors = get_monitor_list()
    cur_mon = wcfg.get("output", "") or "All Monitors"
    if cur_mon not in monitors:
        cur_mon = "All Monitors"
    
    behavior_grp.append(DropdownRow("Show on Display", monitors, cur_mon,
        lambda v: (wcfg.set("output", None if v == "All Monitors" else v), apply_cfg()),
        "Which monitor to show panel"))
    
    # Extend to edges
    margins_zero = (wcfg.get("margin-left", 0) == 0 and 
                    wcfg.get("margin-right", 0) == 0 and
                    wcfg.get("margin-top", 0) == 0 and
                    wcfg.get("margin-bottom", 0) == 0)
    
    def on_extend(v):
        if v:
            wcfg.set("margin-left", 0)
            wcfg.set("margin-right", 0)
            wcfg.set("margin-top", 0)
            wcfg.set("margin-bottom", 0)
            wcm.set_window_border_radius(0)
        else:
            wcm.set_window_border_radius(46)
        wcfg.save()
        wcm.save()
        wcm.reload_waybar()
    
    behavior_grp.append(ToggleRow("Extend to Edges", margins_zero,
        on_extend, "Panel spans full width"))
    
    main.append(behavior_grp)
    
    # ═══════════════════════════════════════════════════════════════════════════
    # 3. PANEL APPEARANCE
    # ═══════════════════════════════════════════════════════════════════════════
    appear_grp = _group("PANEL APPEARANCE")
    
    appear_grp.append(OpacityRow("Background Opacity", wcm.get_window_opacity(),
        lambda v: (wcm.set_window_opacity(v), apply_css()),
        "0% = transparent, 100% = opaque"))
    
    appear_grp.append(SpinRow("Border Radius", wcm.get_window_border_radius(), 0, 50,
        lambda v: (wcm.set_window_border_radius(v), apply_css()),
        "Corner roundness (px)"))
    
    appear_grp.append(SpinRow("Font Size", wcm.get_font_size(), 8, 32,
        lambda v: (wcm.set_font_size(v), apply_css()),
        "Global panel font size"))
    
    appear_grp.append(SpinRow("Panel Height", wcfg.get("height", 40), 10, 80,
        lambda v: (wcfg.set("height", v), apply_cfg()),
        "Height in pixels"))
    
    # Margins sub-section
    mhdr = Gtk.Label(label="MARGINS")
    mhdr.add_css_class('caption')
    mhdr.add_css_class('dim-label')
    mhdr.set_xalign(0)
    mhdr.set_margin_start(16)
    mhdr.set_margin_top(16)
    appear_grp.append(mhdr)
    
    for side in ['top', 'bottom', 'left', 'right']:
        appear_grp.append(SpinRow(f"Margin {side.title()}", 
            wcfg.get(f"margin-{side}", 0), 0, 100,
            lambda v, s=side: (wcfg.set(f"margin-{s}", v), apply_cfg()),
            f"Space from screen {side}"))
    
    main.append(appear_grp)
    
    # ═══════════════════════════════════════════════════════════════════════════
    # 4. WAYBAR WORKSPACES
    # ═══════════════════════════════════════════════════════════════════════════
    ws_grp = _group("WAYBAR WORKSPACES")
    
    ws_grp.append(OpacityRow("Container Opacity", wcm.get_workspaces_opacity(),
        lambda v: (wcm.set_workspaces_opacity(v), apply_css())))
    
    ws_grp.append(SpinRow("Container Radius", wcm.get_workspaces_border_radius(), 0, 50,
        lambda v: (wcm.set_workspaces_border_radius(v), apply_css())))
    
    ws_grp.append(SpinRow("Button Radius", wcm.get_ws_button_radius(), 0, 30,
        lambda v: (wcm.set_ws_button_radius(v), apply_css())))
    
    ws_grp.append(SpinRow("Active Button Width", wcm.get_ws_button_active_width(), 20, 100,
        lambda v: (wcm.set_ws_button_active_width(v), apply_css())))
    
    # Button colors
    bhdr = Gtk.Label(label="BUTTON COLORS")
    bhdr.add_css_class('caption')
    bhdr.add_css_class('dim-label')
    bhdr.set_xalign(0)
    bhdr.set_margin_start(16)
    bhdr.set_margin_top(16)
    ws_grp.append(bhdr)
    
    for label, state in [("Normal", "normal"), ("Active", "active"), 
                         ("Hover", "hover"), ("Urgent", "urgent")]:
        ws_grp.append(ColorDropdownRow(f"{label} Background", 
            wcm.get_ws_button_color(state),
            lambda v, s=state: (wcm.set_ws_button_color(s, v), apply_css())))
    
    main.append(ws_grp)
    
    # ═══════════════════════════════════════════════════════════════════════════
    # 5. MODULE COLORS
    # ═══════════════════════════════════════════════════════════════════════════
    mod_grp = _group("MODULE COLORS")
    
    mod_grp.append(SpinRow("Module Border Radius", wcm.get_modules_border_radius(), 0, 50,
        lambda v: (wcm.set_modules_border_radius(v), apply_css())))
    
    for mod in ["cpu", "memory", "temperature", "clock", "network", 
                "battery", "pulseaudio", "bluetooth"]:
        mod_grp.append(ColorDropdownRow(f"{mod.title()} Color", 
            wcm.get_module_color(mod),
            lambda v, m=mod: (wcm.set_module_color(m, v), apply_css())))
    
    main.append(mod_grp)
    
    # ═══════════════════════════════════════════════════════════════════════════
    # ACTION BUTTONS
    # ═══════════════════════════════════════════════════════════════════════════
    def on_reload(b):
        wcm.load()
        wcfg.load()
        window._show_toast("Reloaded from disk")
        # Rebuild page
        _refresh_page(window)
    
    def on_apply(b):
        wcm.save()
        wcfg.save()
        wcm.reload_waybar()
        window._show_toast("All changes applied!")
    
    btn_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
    btn_box.set_halign(Gtk.Align.END)
    btn_box.set_margin_top(16)
    
    reload_btn = Gtk.Button(label="Reload")
    reload_btn.add_css_class('pill')
    reload_btn.connect('clicked', on_reload)
    btn_box.append(reload_btn)
    
    apply_btn = Gtk.Button(label="Apply")
    apply_btn.add_css_class('pill')
    apply_btn.add_css_class('suggested-action')
    apply_btn.connect('clicked', on_apply)
    btn_box.append(apply_btn)
    
    main.append(btn_box)
    
    content.append(main)
    scrolled.set_child(content)
    return scrolled


def _refresh_page(window):
    """Rebuild theming page"""
    old = window.stack.get_child_by_name("theming")
    if old:
        window.stack.remove(old)
    new_page = build_theming_page(window)
    window.stack.add_named(new_page, "theming")
    window.stack.set_visible_child_name("theming")
