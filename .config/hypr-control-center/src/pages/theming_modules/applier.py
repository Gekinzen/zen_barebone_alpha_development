"""THEME APPLIER - Apply themes to all applications"""
import gi
gi.require_version('Gtk', '4.0')
from gi.repository import Gtk, Gdk
import subprocess, json, re
from .constants import (WAYBAR_DIR, WAYBAR_COLORSCHEME_DIR, ROFI_SHARED_DIR, ROFI_COLORS_RASI,
                        KITTY_CONF, ASSETS_DIR, CONTROL_CENTER_CSS, START_MENU_CSS, PANEL_WIDGET_CSS,
                        CURRENT_THEME_FILE, PREFERENCES_THEME_FILE, PROFILES_FILE, PREFERENCES_DIR, THEMES_DIR)

_CSS_PROVIDER = None

class ThemeApplier:
    @staticmethod
    def apply_waybar_colorscheme(data):
        colors, tid = data.get("colors", {}), data.get("id", "custom")
        css = f"/* {data.get('name', 'Custom')} */\n" + "".join(f"@define-color {k} {v};\n" for k, v in colors.items())
        WAYBAR_COLORSCHEME_DIR.mkdir(parents=True, exist_ok=True)
        (WAYBAR_COLORSCHEME_DIR / f"{tid}.css").write_text(css)
        (WAYBAR_COLORSCHEME_DIR / "current.css").write_text(css)
        sf = WAYBAR_DIR / "style.css"
        if sf.exists():
            c = sf.read_text()
            if "@import" in c:
                lines = c.split('\n')
                for i, l in enumerate(lines):
                    if "@import" in l and "colorscheme" in l:
                        lines[i] = f"@import '../hypr/colorscheme/{tid}.css';"; break
                sf.write_text('\n'.join(lines))
        return True
    
    @staticmethod
    def apply_rofi_colors(data):
        rofi, colors = data.get("rofi", {}), data.get("colors", {})
        gc = lambda c: f"#{c.lstrip('#').upper()}FF" if len(c.lstrip('#')) == 6 else f"#{c.lstrip('#').upper()}"
        ROFI_SHARED_DIR.mkdir(parents=True, exist_ok=True)
        try:
            ROFI_COLORS_RASI.write_text(f'''* {{
    background:     {gc(rofi.get("background", colors.get("bg0", "#282c34")))};
    background-alt: {gc(rofi.get("background-alt", colors.get("bg1", "#21252b")))};
    foreground:     {gc(rofi.get("foreground", colors.get("fg", "#abb2bf")))};
    selected:       {gc(rofi.get("selected", colors.get("blue", "#61afef")))};
    active:         {gc(rofi.get("active", colors.get("green", "#98c379")))};
    urgent:         {gc(rofi.get("urgent", colors.get("red", "#e06c75")))};
}}''')
            return True
        except: return False
    
    @staticmethod
    def apply_kitty_colors(data):
        kitty, colors = data.get("kitty", {}), data.get("colors", {})
        if not KITTY_CONF.exists(): return False
        try:
            c = KITTY_CONF.read_text()
            for k, d in [("background", "bg0"), ("foreground", "fg"), ("cursor", "blue")]:
                v = kitty.get(k, colors.get(d, "#abb2bf"))
                if re.search(rf'^{k}\s+', c, re.MULTILINE):
                    c = re.sub(rf'^({k}\s+)#?[a-fA-F0-9]+.*$', rf'\g<1>{v}', c, flags=re.MULTILINE)
            KITTY_CONF.write_text(c)
            return True
        except: return False
    
    @staticmethod
    def apply_control_center_theme(data, window=None):
        from .css_generators import generate_control_center_css, generate_start_menu_css, generate_panel_widget_css
        colors = data.get("colors", {})
        for d in [ASSETS_DIR, PREFERENCES_DIR, THEMES_DIR]: d.mkdir(parents=True, exist_ok=True)
        CONTROL_CENTER_CSS.write_text(generate_control_center_css(colors))
        START_MENU_CSS.write_text(generate_start_menu_css(colors))
        PANEL_WIDGET_CSS.write_text(generate_panel_widget_css(colors))
        save = {"id": data.get("id"), "name": data.get("name"), "colors": colors, "is_builtin": data.get("is_builtin", True),
                "active_profile": data.get("id"), "active_profile_type": "builtin" if data.get("is_builtin", True) else "custom"}
        for p in [CURRENT_THEME_FILE, PREFERENCES_THEME_FILE]:
            try: p.write_text(json.dumps(save, indent=2))
            except: pass
        try:
            prof = json.loads(PROFILES_FILE.read_text()) if PROFILES_FILE.exists() else {}
            prof.update({"active_profile": data.get("id", "one-dark"), "active_profile_type": "builtin" if data.get("is_builtin", True) else "custom"})
            PROFILES_FILE.write_text(json.dumps(prof, indent=2))
        except: pass
        if window: ThemeApplier._reload_css(window)
        return True
    
    @staticmethod
    def _reload_css(window):
        global _CSS_PROVIDER
        display = Gdk.Display.get_default()
        if not display: return
        if _CSS_PROVIDER:
            try: Gtk.StyleContext.remove_provider_for_display(display, _CSS_PROVIDER)
            except: pass
        _CSS_PROVIDER = Gtk.CssProvider()
        if CONTROL_CENTER_CSS.exists():
            try: _CSS_PROVIDER.load_from_path(str(CONTROL_CENTER_CSS))
            except: return
        try: Gtk.StyleContext.add_provider_for_display(display, _CSS_PROVIDER, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION + 100)
        except: pass
        if window: window.queue_resize()
    
    @staticmethod
    def reload_waybar(): subprocess.run(["pkill", "-SIGUSR2", "waybar"], capture_output=True)
    @staticmethod
    def reload_kitty(): subprocess.run(["pkill", "-USR1", "kitty"], capture_output=True)
    @staticmethod
    def notify(title, msg): subprocess.run(["notify-send", "-a", "Hyprland Control Center", title, msg], capture_output=True)