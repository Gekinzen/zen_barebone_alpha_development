#!/usr/bin/env python3
"""
Hyprland Start Menu - v4.1 ULTRA-OPTIMIZED DAEMON
Windows 11-style launcher

v4.1 Changes:
- Text colors now use grey2 from theme for Paper/Yousai compatibility
- Added @grey2_color CSS variable
- All text elements (labels, titles, names) use grey2

v4.0 Changes:
- Ready file for bash script coordination
- Deferred app loading (load AFTER window shown)
- Lazy CSS parsing
- Optimized icon cache
- atexit cleanup
"""
import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
gi.require_version('Gdk', '4.0')
from gi.repository import Gtk, Adw, GLib, Gio, GdkPixbuf, Gdk
import json, subprocess, os, sys, re, hashlib, signal, atexit
from pathlib import Path
from datetime import datetime
import threading

try:
    gi.require_version('Gtk4LayerShell', '1.0')
    from gi.repository import Gtk4LayerShell
    HAS_LAYER_SHELL = True
except:
    HAS_LAYER_SHELL = False

# ═══════════════════════════════════════════════════════════════════════════════
# CONSTANTS
# ═══════════════════════════════════════════════════════════════════════════════
PID_FILE = Path("/tmp/hypr-startmenu.pid")
READY_FILE = Path("/tmp/hypr-startmenu.ready")

class NerdIcons:
    USER = "\uf007"
    FOLDER = "\U000f024b"
    SETTINGS = "\uf013"
    POWER = "\u23fb"
    LOCK = "\uf023"
    LOGOUT = "\U000f0343"
    RESTART = "\uf021"
    SHUTDOWN = "\uf28d"
    SEARCH = "\uf002"
    PIN = "\U000f0403"
    UNPIN = "\U000f0404"
    APP = "\uf009"

# ═══════════════════════════════════════════════════════════════════════════════
# CLEANUP
# ═══════════════════════════════════════════════════════════════════════════════
def cleanup():
    """Clean up PID and ready files on exit"""
    for f in [PID_FILE, READY_FILE]:
        try:
            f.unlink(missing_ok=True)
        except:
            pass

atexit.register(cleanup)

# ═══════════════════════════════════════════════════════════════════════════════
# FUZZY SEARCH (unchanged but optimized)
# ═══════════════════════════════════════════════════════════════════════════════
def fuzzy_match(query, text):
    if not query or not text: return 0.0
    query, text = query.lower(), text.lower()
    if query == text: return 1.0
    if text.startswith(query): return 0.95 + (len(query)/len(text))*0.05
    if query in text:
        for word in text.split():
            if word.startswith(query): return 0.85 + (len(query)/len(word))*0.1
        return 0.7 + (len(query)/len(text))*0.1
    qi, matches, consec, max_consec, last = 0, 0, 0, 0, -2
    for i, c in enumerate(text):
        if qi < len(query) and c == query[qi]:
            matches += 1
            consec = consec+1 if i == last+1 else 1
            max_consec = max(max_consec, consec)
            last, qi = i, qi+1
    if matches < len(query): return 0.0
    return min(0.65, matches/len(text) + max_consec/len(query)*0.3 - (len(text)-len(query))/len(text)*0.1)

def fuzzy_search(apps, query, threshold=0.3):
    if not query: return [(a, 1.0) for a in apps]
    results = []
    for app in apps:
        ns = fuzzy_match(query, app['name'])
        ks = max((fuzzy_match(query, k)*0.8 for k in app.get('keywords', [])), default=0)
        score = max(ns, ks)
        if score >= threshold: results.append((app, score))
    return sorted(results, key=lambda x: (-x[1], x[0]['name'].lower()))

# ═══════════════════════════════════════════════════════════════════════════════
# USER PROFILE
# ═══════════════════════════════════════════════════════════════════════════════
class UserProfile:
    _cache = {}
    
    @staticmethod
    def get_username():
        if 'username' not in UserProfile._cache:
            UserProfile._cache['username'] = os.getenv("USER", "User")
        return UserProfile._cache['username']
    
    @staticmethod
    def get_display_name():
        if 'display_name' not in UserProfile._cache:
            u = UserProfile.get_username()
            try:
                import pwd
                g = pwd.getpwnam(u).pw_gecos.split(',')[0]
                if g and g.strip():
                    UserProfile._cache['display_name'] = g.strip()
                else:
                    UserProfile._cache['display_name'] = u.capitalize()
            except:
                UserProfile._cache['display_name'] = u.capitalize()
        return UserProfile._cache['display_name']
    
    @staticmethod
    def get_avatar_path():
        if 'avatar' not in UserProfile._cache:
            u = UserProfile.get_username()
            paths = [Path(f"/var/lib/AccountsService/icons/{u}"), Path.home()/".face", Path.home()/".face.icon"]
            UserProfile._cache['avatar'] = None
            for p in paths:
                if p.exists() and p.is_file():
                    try:
                        with open(p, 'rb') as f:
                            h = f.read(8)
                            if h[:4]==b'\x89PNG' or h[:2]==b'\xff\xd8' or h[:6] in (b'GIF87a',b'GIF89a'):
                                UserProfile._cache['avatar'] = str(p)
                                break
                    except: pass
        return UserProfile._cache['avatar']
    
    @staticmethod
    def create_circular_avatar(path, size=32):
        da = Gtk.DrawingArea()
        da.set_size_request(size, size)
        da.set_halign(Gtk.Align.CENTER)
        da.set_valign(Gtk.Align.CENTER)
        pb = None
        if path and os.path.exists(path):
            try:
                orig = GdkPixbuf.Pixbuf.new_from_file(path)
                ow, oh = orig.get_width(), orig.get_height()
                sc = max(size/ow, size/oh)
                nw, nh = int(ow*sc), int(oh*sc)
                scaled = orig.scale_simple(nw, nh, GdkPixbuf.InterpType.BILINEAR)
                xo, yo = (nw-size)//2, (nh-size)//2
                pb = GdkPixbuf.Pixbuf.new(GdkPixbuf.Colorspace.RGB, True, 8, size, size)
                pb.fill(0)
                scaled.copy_area(xo, yo, size, size, pb, 0, 0)
            except: pb = None
        def draw(a, cr, w, h):
            import math
            cr.arc(w/2, h/2, min(w,h)/2, 0, 2*math.pi)
            cr.clip()
            if pb: Gdk.cairo_set_source_pixbuf(cr, pb, 0, 0); cr.paint()
            else: cr.set_source_rgba(0.38, 0.68, 0.93, 0.3); cr.paint()
        da.set_draw_func(draw)
        frame = Gtk.Frame()
        frame.set_child(da)
        frame.add_css_class("avatar-frame")
        return frame

# ═══════════════════════════════════════════════════════════════════════════════
# APP LOADER - OPTIMIZED
# ═══════════════════════════════════════════════════════════════════════════════
class SmartAppLoader:
    DESKTOP_DIRS = [Path("/usr/share/applications"), Path("/usr/local/share/applications"),
                    Path.home()/".local/share/applications", Path.home()/".local/share/flatpak/exports/share/applications",
                    Path("/var/lib/flatpak/exports/share/applications"), Path("/var/lib/snapd/desktop/applications")]
    ICON_DIRS = [Path("/usr/share/icons"), Path("/usr/share/pixmaps"), Path.home()/".local/share/icons",
                 Path.home()/".local/share/flatpak/exports/share/icons", Path("/var/lib/flatpak/exports/share/icons")]
    CACHE_FILE = Path.home()/".cache/hypr-startmenu/apps.json"
    CACHE_MAX_AGE = 300
    _icon_cache = {}
    _apps_cache = None

    @classmethod
    def get_cache_hash(cls):
        h = ""
        for d in cls.DESKTOP_DIRS:
            if d.exists():
                try: h += f"{d}:{d.stat().st_mtime};"
                except: pass
        return hashlib.md5(h.encode()).hexdigest()[:16]

    @classmethod
    def load_from_cache(cls):
        try:
            if not cls.CACHE_FILE.exists(): return None
            if datetime.now().timestamp() - cls.CACHE_FILE.stat().st_mtime > cls.CACHE_MAX_AGE: return None
            with open(cls.CACHE_FILE) as f: data = json.load(f)
            if data.get('hash') != cls.get_cache_hash(): return None
            return data.get('apps', [])
        except: return None

    @classmethod
    def save_to_cache(cls, apps):
        def _save():
            try:
                cls.CACHE_FILE.parent.mkdir(parents=True, exist_ok=True)
                with open(cls.CACHE_FILE, 'w') as f:
                    json.dump({'hash': cls.get_cache_hash(), 'timestamp': datetime.now().isoformat(), 'apps': apps}, f)
            except: pass
        threading.Thread(target=_save, daemon=True).start()

    @classmethod
    def detect_package_source(cls, p):
        s = str(p).lower()
        if 'flatpak' in s: return 'flatpak'
        if 'snapd' in s or 'snap' in s: return 'snap'
        if '.local/share/applications' in s: return 'aur/local'
        if '/usr/share/applications' in s: return 'pacman'
        return 'system'

    @classmethod
    def load_all_apps(cls, use_cache=True, callback=None):
        """Load apps - returns cached immediately if available, refreshes in background"""
        if cls._apps_cache:
            return cls._apps_cache
        
        if use_cache:
            c = cls.load_from_cache()
            if c:
                cls._apps_cache = c
                # Refresh in background
                threading.Thread(target=cls._refresh_cache, daemon=True).start()
                return c
        
        # No cache - load synchronously but fast
        apps = cls._load_fresh()
        cls._apps_cache = apps
        return apps

    @classmethod
    def load_all_apps_async(cls, callback):
        """Load apps asynchronously - for deferred loading"""
        def _load():
            apps = cls.load_all_apps(use_cache=True)
            if callback:
                GLib.idle_add(callback, apps)
        threading.Thread(target=_load, daemon=True).start()

    @classmethod
    def _refresh_cache(cls):
        apps = cls._load_fresh()
        cls._apps_cache = apps
        cls.save_to_cache(apps)

    @classmethod
    def _load_fresh(cls):
        apps, seen = [], set()
        for d in cls.DESKTOP_DIRS:
            if not d.exists(): continue
            for f in d.glob("*.desktop"):
                try:
                    a = cls.parse_desktop_file(f)
                    if a and a['name'] not in seen:
                        a['source'] = cls.detect_package_source(f)
                        apps.append(a); seen.add(a['name'])
                except: continue
        apps.sort(key=lambda x: x['name'].lower())
        return apps

    @classmethod
    def parse_desktop_file(cls, f):
        try:
            with open(f, 'r', encoding='utf-8', errors='ignore') as fp: c = fp.read()
        except: return None
        if 'NoDisplay=true' in c or 'Hidden=true' in c or '[Desktop Entry]' not in c: return None
        name = icon = exc = comment = None
        cats, kws = [], []
        inde = False
        for line in c.split('\n'):
            line = line.strip()
            if line == '[Desktop Entry]': inde = True; continue
            if line.startswith('[') and line.endswith(']'): inde = False; continue
            if not inde or '=' not in line: continue
            k, _, v = line.partition('=')
            k, v = k.strip(), v.strip()
            if k == 'Name' and not name: name = v
            elif k == 'Icon': icon = v
            elif k == 'Exec': exc = re.sub(r'%[a-zA-Z]', '', v).strip()
            elif k == 'Comment' and not comment: comment = v
            elif k == 'Categories': cats = [x.strip() for x in v.split(';') if x.strip()]
            elif k == 'Keywords': kws = [x.strip() for x in v.split(';') if x.strip()]
        if not name: return None
        return {'name': name, 'icon': icon, 'exec': exc, 'comment': comment, 'categories': cats, 'keywords': kws+cats, 'desktop_file': str(f)}

    @classmethod
    def find_icon_path(cls, name, size=48):
        if not name: return None
        ck = f"{name}:{size}"
        if ck in cls._icon_cache: return cls._icon_cache[ck]
        r = cls._find_icon_uncached(name, size)
        cls._icon_cache[ck] = r
        return r

    @classmethod
    def _find_icon_uncached(cls, name, size=48):
        if name.startswith('/') and os.path.exists(name): return name
        exts = ['.png', '.svg', '.xpm', '']
        sizes = [f'{size}x{size}', 'scalable', '256x256', '128x128', '64x64', '48x48', '32x32']
        themes = ['hicolor', 'Adwaita', 'breeze', 'Papirus', '']
        cats = ['apps', 'applications', 'mimetypes', 'places']
        for d in cls.ICON_DIRS:
            if not d.exists(): continue
            for e in exts:
                p = d/f"{name}{e}"
                if p.exists(): return str(p)
            for t in themes:
                for s in sizes:
                    for c in cats:
                        for e in exts:
                            p = d/t/s/c/f"{name}{e}" if t else d/s/c/f"{name}{e}"
                            if p.exists(): return str(p)
        return None

# ═══════════════════════════════════════════════════════════════════════════════
# THEME/CONFIG - LAZY LOADING
# ═══════════════════════════════════════════════════════════════════════════════
class ThemeManager:
    _cache = {}
    
    @classmethod
    def clear_cache(cls):
        cls._cache.clear()
    
    @classmethod
    def get_waybar_config(cls):
        if 'waybar_config' in cls._cache:
            return cls._cache['waybar_config']
        
        cfg = {}
        for cp in [Path.home()/".config/waybar/config.jsonc", Path.home()/".config/waybar/config.json", Path.home()/".config/waybar/config"]:
            if not cp.exists(): continue
            try:
                c = cp.read_text()
                c = re.sub(r'//.*$', '', c, flags=re.MULTILINE)
                c = re.sub(r'/\*.*?\*/', '', c, flags=re.DOTALL)
                c = re.sub(r',\s*([}\]])', r'\1', c)
                raw = json.loads(c)
                if isinstance(raw, list):
                    for x in raw:
                        if isinstance(x, dict):
                            o = x.get("output", "")
                            if not o or o == "*" or "DP" in str(o): cfg = x; break
                    if not cfg and raw: cfg = raw[0] if isinstance(raw[0], dict) else {}
                elif isinstance(raw, dict): cfg = raw
                break
            except: pass
        cls._cache['waybar_config'] = cfg
        return cfg
    
    @classmethod
    def get_waybar_colors(cls):
        if 'waybar_colors' in cls._cache:
            return cls._cache['waybar_colors']
        
        colors = {"bg": None, "fg": None, "accent": None, "red": "#e06c75", "green": "#98c379",
                  "yellow": "#e5c07b", "blue": "#61afef", "purple": "#c678dd", "aqua": "#56b6c2",
                  "orange": "#d19a66", "grey0": "#5c6370", "grey1": "#828997", "grey2": "#a0a0a0",
                  "waybar_opacity": None, "waybar_radius": None}
        
        for cp in [Path.home()/".config/waybar/style.css", Path.home()/".config/waybar/themes/current.css"]:
            if not cp.exists(): continue
            try:
                content = cls._resolve_css_imports(cp, cp.read_text())
                sel, depth = "", 0
                for line in content.splitlines():
                    line = line.strip()
                    if "{" in line:
                        if depth == 0: sel = line.split("{")[0].strip()
                        depth += line.count("{")
                    if "}" in line:
                        depth -= line.count("}")
                        if depth <= 0: sel, depth = "", 0
                    if line.startswith("@define-color"):
                        raw = line.replace("@define-color", "").strip().rstrip(";")
                        parts = raw.split(None, 1)
                        if len(parts) >= 2:
                            n, c = parts[0].lower(), parts[1].strip()
                            if any(k in n for k in ["bg0", "bg", "background", "base"]) and not colors["bg"]: colors["bg"] = c
                            elif any(k in n for k in ["fg", "foreground", "text"]) and not colors["fg"]: colors["fg"] = c
                            elif any(k in n for k in ["accent", "primary"]) and not colors["accent"]: colors["accent"] = c
                            elif "grey2" in n: colors["grey2"] = c
                            for cn in ["blue", "red", "green", "yellow", "purple", "aqua", "orange"]:
                                if cn in n: colors[cn] = c
                    if "#waybar" in sel:
                        if "background" in line:
                            m = re.search(r'alpha\(@?\w+,\s*([\d.]+)\)', line)
                            if m and colors["waybar_opacity"] is None: colors["waybar_opacity"] = float(m.group(1))
                        if "border-radius" in line:
                            m = re.search(r'(\d+)', line)
                            if m and colors["waybar_radius"] is None: colors["waybar_radius"] = int(m.group(1))
            except: pass
        cls._cache['waybar_colors'] = colors
        return colors
    
    @classmethod
    def get_hyprland_config(cls):
        if 'hypr_config' in cls._cache:
            return cls._cache['hypr_config']
        
        config = {"active_opacity": 1.0, "inactive_opacity": 1.0, "active_border_color": "#61afef",
                  "inactive_border_color": "#5c6370", "rounding": 8}
        
        for cf in [Path.home()/".config/hypr/hyprland.conf"] + [Path.home()/".config/hypr"/x for x in ["colors.conf", "theme.conf", "decoration.conf"] if (Path.home()/".config/hypr"/x).exists()]:
            if not cf.exists(): continue
            try:
                for line in cf.read_text().splitlines():
                    line = line.strip()
                    if line.startswith("#") or not line: continue
                    if "active_opacity" in line:
                        try: config["active_opacity"] = float(line.split("=")[1].split("#")[0].strip())
                        except: pass
                    elif "inactive_opacity" in line:
                        try: config["inactive_opacity"] = float(line.split("=")[1].split("#")[0].strip())
                        except: pass
                    elif "rounding" in line and "border" not in line.lower():
                        try: config["rounding"] = int(line.split("=")[1].split("#")[0].strip())
                        except: pass
            except: pass
        cls._cache['hypr_config'] = config
        return config
    
    @classmethod
    def get_theme_colors(cls):
        waybar_colors = cls.get_waybar_colors()
        hypr_config = cls.get_hyprland_config()
        
        colors = {"bg0": "#1e2127", "bg1": "#282b31", "fg": "#abb2bf", "grey0": "#5c6370", "grey1": "#828997",
                  "grey2": "#a0a0a0", "red": "#e06c75", "orange": "#d19a66", "yellow": "#e5c07b", "green": "#98c379",
                  "aqua": "#56b6c2", "blue": "#61afef", "purple": "#c678dd"}
        
        for tf in [Path.home()/".config/hypr-control-center/preferences/theme.json"]:
            if tf.exists():
                try:
                    with open(tf) as f: 
                        theme_data = json.load(f)
                        theme_colors = theme_data.get('colors', {})
                        colors.update(theme_colors)
                        # Ensure grey2 is loaded
                        if 'grey2' in theme_colors:
                            colors['grey2'] = theme_colors['grey2']
                    break
                except: pass
        
        if hypr_config.get("active_border_color"): colors["accent"] = hypr_config["active_border_color"]
        if waybar_colors.get("bg"): colors["bg0"] = waybar_colors["bg"]
        if waybar_colors.get("fg"): colors["fg"] = waybar_colors["fg"]
        if waybar_colors.get("accent"): colors["accent"] = waybar_colors["accent"]
        if waybar_colors.get("grey2"): colors["grey2"] = waybar_colors["grey2"]
        for c in ["blue", "red", "green", "yellow", "purple", "aqua", "orange"]:
            if waybar_colors.get(c): colors[c] = waybar_colors[c]
        if not colors.get("accent"): colors["accent"] = colors["blue"]
        return colors
    
    @classmethod
    def _resolve_css_imports(cls, css_path, content, visited=None):
        if visited is None: visited = set()
        rp = str(css_path.resolve())
        if rp in visited: return content
        visited.add(rp)
        lines, resolved = content.splitlines(), []
        for line in lines:
            s = line.strip()
            m = re.match(r"""@import\s+['"](.+?)['"]\s*;?""", s)
            if m:
                ip = (css_path.parent/m.group(1)).resolve()
                if ip.exists():
                    try:
                        ic = ip.read_text()
                        ic = cls._resolve_css_imports(ip, ic, visited)
                        resolved.append(f"/* @import: {m.group(1)} */")
                        resolved.append(ic)
                        continue
                    except: pass
            resolved.append(line)
        return "\n".join(resolved)

# ═══════════════════════════════════════════════════════════════════════════════
# START MENU WINDOW
# ═══════════════════════════════════════════════════════════════════════════════
class StartMenu(Gtk.ApplicationWindow):
    def __init__(self, app, daemon_mode=False):
        super().__init__(application=app, title="Start Menu")
        self.daemon_mode = daemon_mode
        self.config_dir = Path.home()/".config/hypr-control-center"
        self.pinned_file = self.config_dir/"preferences/start-menu-pinned.json"
        self.pinned_file.parent.mkdir(parents=True, exist_ok=True)
        
        # Lazy-loaded
        self._waybar_config = None
        self._waybar_colors = None
        self._hypr_config = None
        self._theme_colors = None
        
        # State
        self._mouse_inside = False
        self._mouse_entered = False
        self._close_timer_id = None
        self._active_popover = None
        self._search_query = ""
        self._is_visible = False
        self._ignore_focus_loss = False
        self._suppress_search = False
        self._apps_loaded = False
        
        # Load pinned apps (fast - just JSON read)
        self.pinned_apps = self.load_pinned_apps()
        
        # Defer app loading
        self.all_apps = []
        
        # Window setup
        self.set_default_size(720, 580)
        self.set_resizable(False)
        self.set_decorated(False)
        
        # Layer shell (before CSS)
        if HAS_LAYER_SHELL:
            self._setup_layer_shell()
        
        # Apply CSS
        self._apply_css()
        
        # Build UI with placeholder
        self.build_ui()
        
        # Setup controllers
        self._setup_mouse_tracking()
        kc = Gtk.EventControllerKey()
        kc.connect("key-pressed", self._on_key_pressed)
        self.add_controller(kc)
        fc = Gtk.EventControllerFocus()
        fc.connect("leave", self._on_focus_leave)
        self.add_controller(fc)
        
        # Load apps async AFTER window is ready
        GLib.idle_add(self._deferred_load)
    
    def _deferred_load(self):
        """Load apps after GTK is ready - this keeps first paint fast"""
        SmartAppLoader.load_all_apps_async(self._on_apps_loaded)
        return False
    
    def _on_apps_loaded(self, apps):
        """Called when apps are loaded"""
        self.all_apps = apps
        self._apps_loaded = True
        self.populate_apps_list()
        self.refresh_pinned_section()
    
    @property
    def waybar_config(self):
        if self._waybar_config is None:
            self._waybar_config = ThemeManager.get_waybar_config()
        return self._waybar_config
    
    @property
    def waybar_colors(self):
        if self._waybar_colors is None:
            self._waybar_colors = ThemeManager.get_waybar_colors()
        return self._waybar_colors
    
    @property
    def hypr_config(self):
        if self._hypr_config is None:
            self._hypr_config = ThemeManager.get_hyprland_config()
        return self._hypr_config
    
    @property
    def theme_colors(self):
        if self._theme_colors is None:
            self._theme_colors = ThemeManager.get_theme_colors()
        return self._theme_colors
    
    @property
    def bg_opacity(self):
        return self.waybar_colors.get("waybar_opacity") or self.hypr_config.get("active_opacity", 0.92)
    
    @property
    def border_radius(self):
        return self.waybar_colors.get("waybar_radius") or self.hypr_config.get("rounding", 16)

    def _on_focus_leave(self, c):
        if self.daemon_mode and self._is_visible:
            if self._active_popover and self._active_popover.is_visible(): return
            if self._ignore_focus_loss: return
            GLib.timeout_add(150, self._check_and_hide)

    def _check_and_hide(self):
        if self._active_popover and self._active_popover.is_visible(): return False
        if self._mouse_inside or self.is_active() or self._ignore_focus_loss: return False
        self.hide_menu()
        return False

    def show_menu(self):
        self._is_visible = True
        self._ignore_focus_loss = False
        self.set_visible(True)
        self.present()
        GLib.timeout_add(50, lambda: self.search_entry.grab_focus() if self._is_visible else False)

    def hide_menu(self):
        if not self._is_visible: return
        self._is_visible = False
        if self.daemon_mode:
            self.set_visible(False)
            self._suppress_search = True
            self.search_entry.set_text("")
            self._suppress_search = False
            if self._search_query:
                self._search_query = ""
                self.populate_apps_list("")
        else: self.close()

    def toggle_menu(self):
        if self._is_visible: self.hide_menu()
        else: self.show_menu()

    def _get_waybar_position(self):
        pos = {"location": "center", "waybar_position": "top", "margin_left": 8, "margin_right": 8, "margin_bottom": 48, "margin_top": 48}
        cfg = self.waybar_config
        if not cfg: return pos
        wp = cfg.get("position", "top")
        pos["waybar_position"] = wp
        wh = cfg.get("height", 40)
        wmt, wmb = cfg.get("margin-top", 0), cfg.get("margin-bottom", 0)
        if wp == "bottom":
            pos["margin_bottom"] = wh + wmb + 8
            pos["margin_top"] = 8
        else:
            pos["margin_top"] = wh + wmt + 8
            pos["margin_bottom"] = 8
        mn = "custom/start-menu"
        ml, mc, mr = cfg.get("modules-left", []), cfg.get("modules-center", []), cfg.get("modules-right", [])
        if mn in ml:
            pos["location"] = "left"
            pos["margin_left"] = cfg.get("margin-left", 0) + ml.index(mn)*50 + 8
        elif mn in mc: pos["location"] = "center"
        elif mn in mr:
            pos["location"] = "right"
            pos["margin_right"] = cfg.get("margin-right", 0) + (len(mr)-1-mr.index(mn))*50 + 8
        return pos

    def _setup_layer_shell(self):
        Gtk4LayerShell.init_for_window(self)
        Gtk4LayerShell.set_layer(self, Gtk4LayerShell.Layer.TOP)
        Gtk4LayerShell.set_namespace(self, "start-menu")
        Gtk4LayerShell.set_keyboard_mode(self, Gtk4LayerShell.KeyboardMode.ON_DEMAND)
        Gtk4LayerShell.set_exclusive_zone(self, -1)
        pos = self._get_waybar_position()
        if pos["waybar_position"] == "bottom":
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.BOTTOM, True)
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.TOP, False)
            Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.BOTTOM, pos["margin_bottom"])
        else:
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.TOP, True)
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.BOTTOM, False)
            Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.TOP, pos["margin_top"])
        if pos["location"] == "left":
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.LEFT, True)
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.RIGHT, False)
            Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.LEFT, pos["margin_left"])
        elif pos["location"] == "center":
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.LEFT, False)
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.RIGHT, False)
        else:
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.RIGHT, True)
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.LEFT, False)
            Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.RIGHT, pos["margin_right"])

    def _setup_mouse_tracking(self):
        m = Gtk.EventControllerMotion()
        m.connect("enter", lambda c, x, y: setattr(self, '_mouse_inside', True) or setattr(self, '_mouse_entered', True))
        m.connect("leave", lambda c: setattr(self, '_mouse_inside', False))
        self.add_controller(m)

    def register_popover(self, p):
        self._active_popover = p
        self._ignore_focus_loss = True
        def on_closed(x):
            self._active_popover = None
            GLib.timeout_add(200, lambda: setattr(self, '_ignore_focus_loss', False) or False)
        p.connect("closed", on_closed)

    def _on_key_pressed(self, c, kv, kc, s):
        if kv == Gdk.KEY_Escape: self.hide_menu(); return True
        return False

    def reload_theme(self):
        """Reload theme - called via SIGUSR2"""
        ThemeManager.clear_cache()
        self._waybar_colors = None
        self._hypr_config = None
        self._theme_colors = None
        self._apply_css()

    def _apply_css(self):
        colors = self.theme_colors
        opacity = self.bg_opacity
        menu_opacity = min(0.95, opacity + 0.10) if opacity < 0.90 else opacity
        rounding = self.border_radius
        rounding_lg = min(rounding + 4, int(rounding * 1.5))
        inactive_opacity = self.hypr_config.get("inactive_opacity", 0.8) * 0.6
        
        # v4.1: Added @grey2_color for text elements
        variables = {
            "@accent_color": colors.get("accent", colors["blue"]),
            "@bg_color": colors["bg0"], 
            "@bg1_color": colors.get("bg1", colors["bg0"]),
            "@fg_color": colors["fg"], 
            "@grey2_color": colors.get("grey2", colors.get("grey1", "#828997")),  # NEW: grey2 for text
            "@opacity": str(menu_opacity),
            "@inactive_opacity": str(inactive_opacity),
            "@rounding": f"{rounding}px", 
            "@rounding_lg": f"{rounding_lg}px",
            "@red_color": colors["red"], 
            "@green_color": colors["green"],
            "@yellow_color": colors["yellow"], 
            "@blue_color": colors["blue"],
            "@purple_color": colors["purple"], 
            "@aqua_color": colors["aqua"],
            "@orange_color": colors["orange"], 
            "@grey0_color": colors["grey0"],
            "@grey1_color": colors["grey1"],
        }
        
        css_file = self.config_dir/"assets/start-menu.css"
        css = None
        if css_file.exists():
            try: css = css_file.read_text()
            except: pass
        if not css:
            css = self._get_default_css()
            self._save_default_css(css_file, css)
        
        for var, val in variables.items():
            css = css.replace(var, val)
        
        provider = Gtk.CssProvider()
        provider.load_from_string(css)
        Gtk.StyleContext.add_provider_for_display(self.get_display(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION + 100)

    def _get_default_css(self):
        """v4.1: Updated CSS with grey2 for all text colors"""
        return '''
/* Start Menu v4.1 CSS - grey2 text colors for Paper/Yousai themes */
window, window *, window.background, window.background *, .background, .background * {
    background-color: rgba(0, 0, 0, 0) !important;
    background-image: none !important;
    box-shadow: none !important;
}
.start-menu {
    background: alpha(@bg_color, @opacity);
    border-radius: @rounding_lg;
    border: 1px solid alpha(@fg_color, 0.12);
    box-shadow: 0 8px 32px rgba(0, 0, 0, 0.4);
}
.start-left { padding: 20px; border-right: 1px solid alpha(@fg_color, 0.08); background: transparent; }
.start-right { padding: 20px; background: transparent; }

/* v4.1: Section titles use grey2 */
.section-title { font-size: 13px; font-weight: 600; color: @grey2_color; margin-bottom: 12px; background: transparent; }

.app-tile { background: transparent; border: none; border-radius: @rounding; padding: 12px 8px; min-width: 72px; transition: all 150ms ease; }
.app-tile:hover { background: alpha(@fg_color, 0.08); }
.app-tile:active { background: alpha(@fg_color, 0.12); }

/* v4.1: App tile labels use grey2 */
.app-tile-label { font-size: 11px; color: @grey2_color; background: transparent; }

.app-row { border-radius: @rounding; margin: 2px 0; padding: 8px 12px; transition: all 150ms ease; background: transparent; }
.app-row:hover { background: alpha(@fg_color, 0.06); }

/* v4.1: App row names use grey2 */
.app-row-name { font-size: 13px; font-weight: 500; color: @grey2_color; background: transparent; }
.app-row-source { font-size: 10px; color: @grey1_color; margin-left: 8px; background: transparent; }

.search-entry { background: alpha(@fg_color, 0.08); border: 1px solid alpha(@fg_color, 0.12); border-radius: @rounding; padding: 10px 14px; color: @grey2_color; margin-bottom: 12px; }
.search-entry:focus { background: alpha(@fg_color, 0.1); border-color: @accent_color; }
.search-hint { font-size: 11px; color: @grey1_color; margin-bottom: 8px; background: transparent; }

.bottom-bar { background: alpha(@bg1_color, 0.6); border-top: 1px solid alpha(@fg_color, 0.08); padding: 14px 20px; border-radius: 0 0 @rounding_lg @rounding_lg; }

/* v4.1: User name uses grey2 */
.user-name { font-size: 14px; font-weight: 600; color: @grey2_color; background: transparent; }

/* v4.1: Nerd icons use grey2 */
.nerd-icon { font-family: "JetBrainsMono Nerd Font", "Symbols Nerd Font Mono", monospace; font-size: 18px; color: @grey2_color; background: transparent; min-width: 24px; min-height: 24px; }

.icon-button { background: transparent; border: none; border-radius: @rounding; padding: 8px; min-width: 40px; min-height: 40px; transition: all 150ms ease; }
.icon-button:hover { background: alpha(@fg_color, 0.08); }

/* v4.1: Icon button labels use grey2 */
.icon-button label, .icon-button .nerd-icon { font-family: "JetBrainsMono Nerd Font", "Symbols Nerd Font Mono", monospace; font-size: 18px; color: @grey2_color; background: transparent; }

.avatar-frame { border-radius: 50%; border: 2px solid alpha(@accent_color, 0.4); background: transparent; min-width: 36px; min-height: 36px; padding: 0; margin: 0; }
.avatar-frame > * { border-radius: 50%; }
.user-avatar-fallback { background: alpha(@accent_color, 0.2); border-radius: 50%; min-width: 32px; min-height: 32px; padding: 4px; }
.user-avatar-fallback label { font-family: "JetBrainsMono Nerd Font", monospace; font-size: 16px; color: @accent_color; }

/* v4.1: Letter headers use accent color (kept as is for visual distinction) */
.letter-header { font-size: 14px; font-weight: 600; color: @accent_color; padding: 8px 12px 4px; background: transparent; }

.loading-label { font-size: 12px; color: @grey1_color; padding: 20px; }

scrollbar { background: transparent; }
scrollbar slider { background: alpha(@fg_color, 0.2); border-radius: 4px; min-width: 8px; }
scrollbar slider:hover { background: alpha(@fg_color, 0.3); }
scrolledwindow { background: transparent; }
scrolledwindow > viewport { background: transparent; }

popover, popover.menu { background: alpha(@bg_color, 0.95); border: 1px solid alpha(@accent_color, 0.3); border-radius: @rounding_lg; padding: 6px; }
popover contents { background: transparent; }

/* v4.1: Popover buttons use grey2 */
popover button, popover.menu button { background: transparent; border: none; border-radius: @rounding; padding: 8px 12px; color: @grey2_color; }
popover button:hover, popover.menu button:hover { background: alpha(@accent_color, 0.15); }
popover modelbutton { padding: 8px 12px; border-radius: 6px; color: @grey2_color; background: transparent; }
popover modelbutton:hover { background: alpha(@accent_color, 0.15); }

.apps-list { background: transparent; }
.apps-list row { padding: 0; background: transparent; }
.apps-list row:hover { background: alpha(@fg_color, 0.05); }

listbox, listbox row, flowbox, flowboxchild, box, label, image { background: transparent; }

/* v4.1: Labels inherit grey2 */
label { color: @grey2_color; }

.source-badge { font-size: 9px; padding: 2px 6px; border-radius: 4px; font-weight: 600; }
.source-flatpak { background: alpha(@blue_color, 0.2); color: @blue_color; }
.source-snap { background: alpha(@orange_color, 0.2); color: @orange_color; }
.source-aur { background: alpha(@aqua_color, 0.2); color: @aqua_color; }
.source-pacman { background: alpha(@green_color, 0.2); color: @green_color; }

tooltip { background: alpha(@bg_color, @opacity); border: 1px solid alpha(@accent_color, 0.2); border-radius: @rounding; }
tooltip label { color: @grey2_color; padding: 6px 10px; }
'''

    def _save_default_css(self, css_file, css):
        try:
            css_file.parent.mkdir(parents=True, exist_ok=True)
            css_file.write_text("/* Start Menu v4.1 CSS - @variable substitution - grey2 text */\n" + css)
        except: pass

    def load_pinned_apps(self):
        try:
            if self.pinned_file.exists():
                with open(self.pinned_file) as f: return json.load(f).get('pinned', [])
            default = ["firefox", "code", "thunar", "kitty"]
            self.save_pinned_apps(default)
            return default
        except: return []

    def save_pinned_apps(self, apps):
        try:
            with open(self.pinned_file, 'w') as f: json.dump({'pinned': apps}, f, indent=2)
        except: pass

    def get_app_id(self, app):
        df = app.get('desktop_file', '')
        if df: return Path(df).stem.lower()
        n = re.sub(r'[^\w\s]', '', app['name'].lower()).replace(' ', '-')
        return re.sub(r'-+', '-', n).strip('-')[:50]

    def pin_app(self, aid):
        if aid not in self.pinned_apps:
            self.pinned_apps.append(aid)
            self.save_pinned_apps(self.pinned_apps)
            self.refresh_pinned_section()

    def unpin_app(self, aid):
        if aid in self.pinned_apps:
            self.pinned_apps.remove(aid)
            self.save_pinned_apps(self.pinned_apps)
            self.refresh_pinned_section()
        else:
            for pid in self.pinned_apps[:]:
                if aid in pid or pid in aid:
                    self.pinned_apps.remove(pid)
                    self.save_pinned_apps(self.pinned_apps)
                    self.refresh_pinned_section()
                    return

    def is_pinned(self, app):
        aid = self.get_app_id(app)
        if aid in self.pinned_apps: return True
        for pid in self.pinned_apps:
            if aid in pid or pid in aid or pid.lower() in app['name'].lower(): return True
        return False

    def find_app_by_id(self, aid):
        al = aid.lower()
        for a in self.all_apps:
            if self.get_app_id(a) == al: return a
        for a in self.all_apps:
            if al in Path(a.get('desktop_file', '')).stem.lower(): return a
        for a in self.all_apps:
            if al in a['name'].lower(): return a
        return None

    def build_ui(self):
        main = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        main.add_css_class("start-menu")
        content = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        content.set_vexpand(True)
        self.left_side = self.create_left_side()
        content.append(self.left_side)
        content.append(self.create_right_side())
        main.append(content)
        main.append(self.create_bottom_bar())
        self.set_child(main)

    def create_left_side(self):
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16)
        box.add_css_class("start-left")
        box.set_size_request(360, -1)
        lbl = Gtk.Label(label="Pinned")
        lbl.add_css_class("section-title")
        lbl.set_xalign(0)
        box.append(lbl)
        self.pinned_grid = Gtk.FlowBox()
        self.pinned_grid.set_valign(Gtk.Align.START)
        self.pinned_grid.set_max_children_per_line(5)
        self.pinned_grid.set_column_spacing(8)
        self.pinned_grid.set_row_spacing(8)
        self.pinned_grid.set_selection_mode(Gtk.SelectionMode.NONE)
        # Show loading placeholder
        loading = Gtk.Label(label="Loading...")
        loading.add_css_class("loading-label")
        self.pinned_grid.append(loading)
        box.append(self.pinned_grid)
        scroll = Gtk.ScrolledWindow()
        scroll.set_child(box)
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroll.set_margin_start(20)
        scroll.set_margin_end(20)
        scroll.set_margin_top(20)
        scroll.set_margin_bottom(20)
        return scroll

    def refresh_pinned_section(self):
        while (c := self.pinned_grid.get_first_child()): self.pinned_grid.remove(c)
        if not self._apps_loaded:
            loading = Gtk.Label(label="Loading...")
            loading.add_css_class("loading-label")
            self.pinned_grid.append(loading)
            return
        for aid in self.pinned_apps:
            app = self.find_app_by_id(aid)
            if app: self.pinned_grid.append(self.create_app_tile(app))

    def create_right_side(self):
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        box.add_css_class("start-right")
        box.set_size_request(360, -1)
        lbl = Gtk.Label(label="All Apps")
        lbl.add_css_class("section-title")
        lbl.set_xalign(0)
        box.append(lbl)
        self.search_entry = Gtk.SearchEntry()
        self.search_entry.set_placeholder_text(f"{NerdIcons.SEARCH}  Type to search...")
        self.search_entry.add_css_class("search-entry")
        self.search_entry.connect("search-changed", self.on_search_changed)
        self.search_entry.connect("stop-search", lambda w: self.hide_menu())
        box.append(self.search_entry)
        self.search_hint = Gtk.Label(label="")
        self.search_hint.add_css_class("search-hint")
        self.search_hint.set_xalign(0)
        self.search_hint.set_visible(False)
        box.append(self.search_hint)
        self.apps_list_box = Gtk.ListBox()
        self.apps_list_box.add_css_class("apps-list")
        self.apps_list_box.set_selection_mode(Gtk.SelectionMode.NONE)
        self.apps_list_box.connect("row-activated", self.on_app_activated)
        # Show loading initially
        row = Gtk.ListBoxRow()
        row.set_selectable(False)
        row.set_activatable(False)
        loading = Gtk.Label(label="Loading apps...")
        loading.add_css_class("loading-label")
        row.set_child(loading)
        self.apps_list_box.append(row)
        scroll = Gtk.ScrolledWindow()
        scroll.set_child(self.apps_list_box)
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroll.set_vexpand(True)
        box.append(scroll)
        wrap = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        wrap.append(box)
        wrap.set_margin_start(20)
        wrap.set_margin_end(20)
        wrap.set_margin_top(20)
        wrap.set_margin_bottom(20)
        return wrap

    def populate_apps_list(self, ft=""):
        while (r := self.apps_list_box.get_row_at_index(0)): self.apps_list_box.remove(r)
        
        if not self._apps_loaded:
            row = Gtk.ListBoxRow()
            row.set_selectable(False)
            row.set_activatable(False)
            loading = Gtk.Label(label="Loading apps...")
            loading.add_css_class("loading-label")
            row.set_child(loading)
            self.apps_list_box.append(row)
            return
        
        if ft:
            results = fuzzy_search(self.all_apps, ft, threshold=0.25)
            filtered = [a for a, s in results]
            if filtered:
                self.search_hint.set_text(f"Found {len(filtered)} matches for '{ft}'")
                self.search_hint.set_visible(True)
            else:
                self.search_hint.set_text(f"No matches for '{ft}'")
                self.search_hint.set_visible(True)
        else:
            filtered = self.all_apps
            self.search_hint.set_visible(False)
        if not ft:
            groups = {}
            for a in filtered:
                l = a['name'][0].upper()
                if l not in groups: groups[l] = []
                groups[l].append(a)
            for l in sorted(groups.keys()):
                h = Gtk.Label(label=l)
                h.add_css_class("letter-header")
                h.set_xalign(0)
                row = Gtk.ListBoxRow()
                row.set_selectable(False)
                row.set_activatable(False)
                row.set_child(h)
                self.apps_list_box.append(row)
                for a in groups[l]: self.apps_list_box.append(self.create_app_row(a))
        else:
            for a in filtered: self.apps_list_box.append(self.create_app_row(a, show_source=True))

    def create_app_tile(self, app):
        btn = Gtk.Button()
        btn.add_css_class("app-tile")
        btn.connect("clicked", lambda b: self.launch_app(app))
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        box.append(self.create_app_icon(app['icon'], 48))
        lbl = Gtk.Label(label=app['name'])
        lbl.add_css_class("app-tile-label")
        lbl.set_max_width_chars(10)
        lbl.set_ellipsize(3)
        box.append(lbl)
        btn.set_child(box)
        btn.app_id = self.get_app_id(app)
        btn.app_info = app
        g = Gtk.GestureClick.new()
        g.set_button(3)
        g.connect("pressed", lambda g, n, x, y: self.show_pinned_context_menu(btn, app))
        btn.add_controller(g)
        return btn

    def create_app_row(self, app, show_source=False):
        row = Gtk.ListBoxRow()
        row.add_css_class("app-row")
        row.set_activatable(True)
        row.app_info = app
        row.app_id = self.get_app_id(app)
        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        box.set_margin_start(12)
        box.set_margin_end(12)
        box.set_margin_top(8)
        box.set_margin_bottom(8)
        box.append(self.create_app_icon(app['icon'], 32))
        ib = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        ib.set_hexpand(True)
        nb = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        lbl = Gtk.Label(label=app['name'])
        lbl.add_css_class("app-row-name")
        lbl.set_xalign(0)
        nb.append(lbl)
        if show_source and app.get('source'):
            sl = Gtk.Label(label=app['source'].upper())
            sl.add_css_class("source-badge")
            sl.add_css_class(f"source-{app['source'].split('/')[0]}")
            nb.append(sl)
        ib.append(nb)
        if app.get('comment'):
            cl = Gtk.Label(label=app['comment'][:50])
            cl.add_css_class("app-row-source")
            cl.set_xalign(0)
            cl.set_ellipsize(3)
            ib.append(cl)
        box.append(ib)
        if self.is_pinned(app):
            pin = Gtk.Label(label=NerdIcons.PIN)
            pin.add_css_class("nerd-icon")
            pin.set_opacity(0.6)
            box.append(pin)
        row.set_child(box)
        g = Gtk.GestureClick.new()
        g.set_button(3)
        g.connect("pressed", lambda g, n, x, y: self.show_app_context_menu(row, app))
        row.add_controller(g)
        return row

    def show_pinned_context_menu(self, w, app):
        m = Gio.Menu()
        m.append(f"{NerdIcons.UNPIN}  Unpin from Start", "app.unpin")
        p = Gtk.PopoverMenu()
        p.set_menu_model(m)
        p.set_parent(w)
        self.current_context_app = app
        self.current_context_app_id = self.get_app_id(app)
        self.register_popover(p)
        p.popup()

    def show_app_context_menu(self, w, app):
        m = Gio.Menu()
        if self.is_pinned(app): m.append(f"{NerdIcons.UNPIN}  Unpin from Start", "app.unpin")
        else: m.append(f"{NerdIcons.PIN}  Pin to Start", "app.pin")
        p = Gtk.PopoverMenu()
        p.set_menu_model(m)
        p.set_parent(w)
        self.current_context_app = app
        self.current_context_app_id = self.get_app_id(app)
        self.register_popover(p)
        p.popup()

    def create_app_icon(self, name, size):
        ip = SmartAppLoader.find_icon_path(name, size)
        if ip and os.path.exists(ip):
            try:
                pb = GdkPixbuf.Pixbuf.new_from_file_at_scale(ip, size, size, True)
                i = Gtk.Image.new_from_pixbuf(pb)
                i.set_pixel_size(size)
                return i
            except: pass
        i = Gtk.Image.new_from_icon_name(name or "application-x-executable")
        i.set_pixel_size(size)
        return i

    def create_bottom_bar(self):
        bar = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        bar.add_css_class("bottom-bar")
        bar.set_margin_start(20)
        bar.set_margin_end(20)
        bar.set_margin_top(12)
        bar.set_margin_bottom(20)
        ub = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        ub.set_valign(Gtk.Align.CENTER)
        ap = UserProfile.get_avatar_path()
        if ap: ub.append(UserProfile.create_circular_avatar(ap, 32))
        else:
            fb = Gtk.Box()
            fb.add_css_class("user-avatar-fallback")
            fb.set_halign(Gtk.Align.CENTER)
            fb.set_valign(Gtk.Align.CENTER)
            ui = Gtk.Label(label=NerdIcons.USER)
            ui.add_css_class("nerd-icon")
            fb.append(ui)
            fr = Gtk.Frame()
            fr.set_child(fb)
            fr.add_css_class("avatar-frame")
            ub.append(fr)
        ul = Gtk.Label(label=UserProfile.get_display_name())
        ul.add_css_class("user-name")
        ub.append(ul)
        bar.append(ub)
        sp = Gtk.Box()
        sp.set_hexpand(True)
        bar.append(sp)
        fb = Gtk.Button()
        fb.add_css_class("icon-button")
        fi = Gtk.Label(label=NerdIcons.FOLDER)
        fi.add_css_class("nerd-icon")
        fb.set_child(fi)
        fb.set_tooltip_text("Open File Manager")
        fb.connect("clicked", lambda b: self.launch_thunar())
        bar.append(fb)
        sb = Gtk.Button()
        sb.add_css_class("icon-button")
        si = Gtk.Label(label=NerdIcons.SETTINGS)
        si.add_css_class("nerd-icon")
        sb.set_child(si)
        sb.set_tooltip_text("Settings")
        sb.connect("clicked", lambda b: self.launch_control_center())
        bar.append(sb)
        pb = Gtk.MenuButton()
        pb.add_css_class("icon-button")
        pi = Gtk.Label(label=NerdIcons.POWER)
        pi.add_css_class("nerd-icon")
        pb.set_child(pi)
        pb.set_tooltip_text("Power Options")
        pm = Gio.Menu()
        pm.append(f"{NerdIcons.LOCK}  Lock", "app.lock")
        pm.append(f"{NerdIcons.LOGOUT}  Logout", "app.logout")
        pm.append(f"{NerdIcons.RESTART}  Restart", "app.restart")
        pm.append(f"{NerdIcons.SHUTDOWN}  Shutdown", "app.shutdown")
        pb.set_menu_model(pm)
        bar.append(pb)
        return bar

    def launch_app(self, app):
        if not app or not app.get('exec'): return
        try:
            subprocess.Popen(['hyprctl', 'dispatch', 'exec', app['exec']], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            self.hide_menu()
        except:
            try:
                subprocess.Popen(app['exec'], shell=True, start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                self.hide_menu()
            except: pass

    def launch_thunar(self):
        subprocess.Popen(['hyprctl', 'dispatch', 'exec', 'thunar'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.hide_menu()

    def launch_control_center(self):
        subprocess.Popen(['hyprctl', 'dispatch', 'exec', f'python3 {self.config_dir}/main.py'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.hide_menu()

    def on_app_activated(self, lb, row):
        if hasattr(row, 'app_info'): self.launch_app(row.app_info)

    def on_search_changed(self, e):
        if self._suppress_search: return
        self._search_query = e.get_text()
        self.populate_apps_list(self._search_query)


# ═══════════════════════════════════════════════════════════════════════════════
# APPLICATION
# ═══════════════════════════════════════════════════════════════════════════════
class StartMenuApp(Gtk.Application):
    def __init__(self, daemon_mode=False):
        super().__init__(application_id="com.hyprland.startmenu", flags=Gio.ApplicationFlags.NON_UNIQUE)
        self.daemon_mode = daemon_mode
        self.window = None

    def do_activate(self):
        if self.window:
            self.window.toggle_menu()
            return
        
        if self.daemon_mode:
            self.hold()
        
        self.window = StartMenu(self, daemon_mode=self.daemon_mode)
        
        for n, h in [("pin", self.on_pin), ("unpin", self.on_unpin),
                     ("lock", lambda a, p: subprocess.Popen(['hyprlock'])),
                     ("logout", lambda a, p: subprocess.Popen(['hyprctl', 'dispatch', 'exit'])),
                     ("restart", lambda a, p: subprocess.Popen(['systemctl', 'reboot'])),
                     ("shutdown", lambda a, p: subprocess.Popen(['systemctl', 'poweroff']))]:
            act = Gio.SimpleAction.new(n, None)
            act.connect("activate", h)
            self.add_action(act)
        
        if self.daemon_mode:
            self.window._is_visible = False
        else:
            self.window._is_visible = True
        
        self.window.present()
        
        if self.daemon_mode:
            GLib.idle_add(lambda: self.window.set_visible(False))
        
        # Mark ready AFTER window is presented
        GLib.idle_add(self._mark_ready)

    def _mark_ready(self):
        """Signal that GTK is fully initialized"""
        READY_FILE.touch()
        return False

    def on_pin(self, a, p):
        if self.window and hasattr(self.window, 'current_context_app_id'):
            self.window.pin_app(self.window.current_context_app_id)
            self.window.populate_apps_list(self.window._search_query)

    def on_unpin(self, a, p):
        if self.window and hasattr(self.window, 'current_context_app_id'):
            self.window.unpin_app(self.window.current_context_app_id)
            self.window.populate_apps_list(self.window._search_query)


# ═══════════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════════
def main():
    import argparse
    parser = argparse.ArgumentParser(description='Hyprland Start Menu v4.1')
    parser.add_argument('--daemon', '-d', action='store_true', help='Run in daemon mode')
    parser.add_argument('--toggle', '-t', action='store_true', help='Toggle existing instance')
    args, _ = parser.parse_known_args()
    
    # Write PID immediately
    PID_FILE.write_text(str(os.getpid()))
    
    app = StartMenuApp(daemon_mode=args.daemon)
    
    def on_sigusr1():
        if app.window:
            app.window.toggle_menu()
        return True
    GLib.unix_signal_add(GLib.PRIORITY_HIGH, signal.SIGUSR1, on_sigusr1)
    
    def on_sigusr2():
        if app.window:
            GLib.idle_add(app.window.reload_theme)
        return True
    GLib.unix_signal_add(GLib.PRIORITY_HIGH, signal.SIGUSR2, on_sigusr2)
    
    try:
        sys.exit(app.run(None))
    finally:
        cleanup()

if __name__ == "__main__":
    main()