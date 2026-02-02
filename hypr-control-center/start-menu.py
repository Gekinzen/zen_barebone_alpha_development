#!/usr/bin/env python3
"""
═══════════════════════════════════════════════════════════════════════════════
Hyprland Start Menu - v2.5 DAEMON Edition (ENHANCED)
═══════════════════════════════════════════════════════════════════════════════
Windows 11-style launcher with TRUE INSTANT toggle

Changes in v2.5:
- ✅ FIXED: Folder and Settings icons now visible
- ✅ FIXED: Pin/Unpin now works correctly
- ✅ DAEMON MODE - Menu stays resident, show/hide is INSTANT
- ✅ CIRCULAR AVATAR with proper image fitting
- ✅ TRUE TRANSPARENT WINDOW
- ✅ App caching for fast startup
- ✅ ENHANCED: GLib.unix_signal_add for reliable SIGUSR1 toggle
- ✅ ENHANCED: ESC closes from search entry too
- ✅ ENHANCED: Better focus handling (won't close during popover)
- ✅ ENHANCED: Click outside detection improved

Location: ~/.config/hypr-control-center/start-menu.py
Run: LD_PRELOAD=/usr/lib/libgtk4-layer-shell.so python3 start-menu.py [--daemon]
═══════════════════════════════════════════════════════════════════════════════
"""

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
gi.require_version('Gdk', '4.0')
from gi.repository import Gtk, Adw, GLib, Gio, GdkPixbuf, Gdk
import json
import subprocess
import os
import sys
import re
import hashlib
import signal
from pathlib import Path
from datetime import datetime
import threading

# Check for GTK4 Layer Shell
try:
    gi.require_version('Gtk4LayerShell', '1.0')
    from gi.repository import Gtk4LayerShell
    HAS_LAYER_SHELL = True
except:
    HAS_LAYER_SHELL = False
    print("[StartMenu] ⚠️ GTK4 Layer Shell not found")


# ═══════════════════════════════════════════════════════════════════════════════
# NERD FONT ICONS - FIXED!
# ═══════════════════════════════════════════════════════════════════════════════

class NerdIcons:
    USER = ""          # nf-fa-user
    FOLDER = "󰉋"       # nf-md-folder
    SETTINGS = ""      # nf-fa-cog
    POWER = "⏻"         # power symbol
    LOCK = ""          # nf-fa-lock
    LOGOUT = "󰍃"       # nf-md-logout
    RESTART = ""       # nf-fa-refresh
    SHUTDOWN = ""      # nf-oct-stop
    SEARCH = ""        # nf-fa-search
    PIN = "󰐃"          # nf-md-pin
    UNPIN = "󰐄"        # nf-md-pin_off
    APP = ""           # nf-fa-th_large


# ═══════════════════════════════════════════════════════════════════════════════
# FUZZY SEARCH
# ═══════════════════════════════════════════════════════════════════════════════

def fuzzy_match(query: str, text: str) -> float:
    if not query or not text:
        return 0.0
    
    query = query.lower()
    text = text.lower()
    
    if query == text:
        return 1.0
    if text.startswith(query):
        return 0.95 + (len(query) / len(text)) * 0.05
    if query in text:
        words = text.split()
        for word in words:
            if word.startswith(query):
                return 0.85 + (len(query) / len(word)) * 0.1
        return 0.7 + (len(query) / len(text)) * 0.1
    
    query_idx = 0
    matches = 0
    consecutive = 0
    max_consecutive = 0
    last_match_idx = -2
    
    for i, char in enumerate(text):
        if query_idx < len(query) and char == query[query_idx]:
            matches += 1
            if i == last_match_idx + 1:
                consecutive += 1
                max_consecutive = max(max_consecutive, consecutive)
            else:
                consecutive = 1
            last_match_idx = i
            query_idx += 1
    
    if matches < len(query):
        return 0.0
    
    base_score = matches / len(text)
    consecutive_bonus = max_consecutive / len(query) * 0.3
    length_penalty = (len(text) - len(query)) / len(text) * 0.1
    
    return min(0.65, base_score + consecutive_bonus - length_penalty)


def fuzzy_search(apps: list, query: str, threshold: float = 0.3) -> list:
    if not query:
        return [(app, 1.0) for app in apps]
    
    results = []
    for app in apps:
        name_score = fuzzy_match(query, app['name'])
        keyword_score = 0.0
        if app.get('keywords'):
            for keyword in app['keywords']:
                keyword_score = max(keyword_score, fuzzy_match(query, keyword) * 0.8)
        
        score = max(name_score, keyword_score)
        if score >= threshold:
            results.append((app, score))
    
    results.sort(key=lambda x: (-x[1], x[0]['name'].lower()))
    return results


# ═══════════════════════════════════════════════════════════════════════════════
# USER PROFILE - With CIRCULAR avatar support
# ═══════════════════════════════════════════════════════════════════════════════

class UserProfile:
    @staticmethod
    def get_username() -> str:
        return os.getenv("USER", "User")
    
    @staticmethod
    def get_display_name() -> str:
        username = UserProfile.get_username()
        try:
            import pwd
            pw_entry = pwd.getpwnam(username)
            gecos = pw_entry.pw_gecos.split(',')[0]
            if gecos and gecos.strip():
                return gecos.strip()
        except:
            pass
        return username.capitalize()
    
    @staticmethod
    def get_avatar_path() -> str:
        """Find user avatar - checks AccountsService and common locations"""
        username = UserProfile.get_username()
        
        # Priority order for avatar locations
        avatar_paths = [
            # AccountsService icon file (most reliable)
            Path(f"/var/lib/AccountsService/icons/{username}"),
            # User-set locations
            Path.home() / ".face",
            Path.home() / ".face.icon",
            Path.home() / ".config/ostree/ostree-user-avatar",
            # GNOME
            Path.home() / ".local/share/gnome-photos/profile-picture.png",
        ]
        
        for path in avatar_paths:
            if path.exists() and path.is_file():
                # Verify it's actually an image
                try:
                    with open(path, 'rb') as f:
                        header = f.read(8)
                        # Check for PNG, JPEG, or other image magic bytes
                        if (header[:4] == b'\x89PNG' or 
                            header[:2] == b'\xff\xd8' or  # JPEG
                            header[:6] in (b'GIF87a', b'GIF89a')):
                            return str(path)
                except:
                    pass
        
        # Check AccountsService config file for Icon= path
        as_config = Path(f"/var/lib/AccountsService/users/{username}")
        if as_config.exists():
            try:
                content = as_config.read_text()
                for line in content.split('\n'):
                    if line.startswith('Icon='):
                        icon_path = line.split('=', 1)[1].strip()
                        if Path(icon_path).exists():
                            return icon_path
            except:
                pass
        
        return None
    
    @staticmethod
    def create_circular_avatar(path: str, size: int = 32) -> Gtk.Widget:
        """Create a circular avatar widget with proper image fitting"""
        
        # Create drawing area for circular clip
        drawing_area = Gtk.DrawingArea()
        drawing_area.set_size_request(size, size)
        drawing_area.set_halign(Gtk.Align.CENTER)
        drawing_area.set_valign(Gtk.Align.CENTER)
        
        # Store pixbuf for drawing
        pixbuf = None
        if path and os.path.exists(path):
            try:
                # Load and scale image to cover the circle
                original = GdkPixbuf.Pixbuf.new_from_file(path)
                
                # Calculate scaling to COVER (not fit) - ensures no empty space
                orig_w = original.get_width()
                orig_h = original.get_height()
                
                # Scale to cover
                scale = max(size / orig_w, size / orig_h)
                new_w = int(orig_w * scale)
                new_h = int(orig_h * scale)
                
                scaled = original.scale_simple(new_w, new_h, GdkPixbuf.InterpType.BILINEAR)
                
                # Center crop
                x_offset = (new_w - size) // 2
                y_offset = (new_h - size) // 2
                
                pixbuf = GdkPixbuf.Pixbuf.new(GdkPixbuf.Colorspace.RGB, True, 8, size, size)
                pixbuf.fill(0x00000000)  # Transparent
                
                scaled.copy_area(
                    x_offset, y_offset,
                    size, size,
                    pixbuf,
                    0, 0
                )
            except Exception as e:
                print(f"[StartMenu] ⚠️ Avatar load error: {e}")
                pixbuf = None
        
        def draw_func(area, cr, width, height):
            # Draw circular clip path
            cr.arc(width / 2, height / 2, min(width, height) / 2, 0, 2 * 3.14159)
            cr.clip()
            
            if pixbuf:
                # Draw the image
                Gdk.cairo_set_source_pixbuf(cr, pixbuf, 0, 0)
                cr.paint()
            else:
                # Draw fallback circle with user icon
                cr.set_source_rgba(0.38, 0.68, 0.93, 0.3)  # Blue tint
                cr.paint()
        
        drawing_area.set_draw_func(draw_func)
        
        # Wrap in a frame for the border
        frame = Gtk.Frame()
        frame.set_child(drawing_area)
        frame.add_css_class("avatar-frame")
        
        return frame


# ═══════════════════════════════════════════════════════════════════════════════
# SMART APP LOADER with CACHING
# ═══════════════════════════════════════════════════════════════════════════════

class SmartAppLoader:
    DESKTOP_DIRS = [
        Path("/usr/share/applications"),
        Path("/usr/local/share/applications"),
        Path.home() / ".local/share/applications",
        Path.home() / ".local/share/flatpak/exports/share/applications",
        Path("/var/lib/flatpak/exports/share/applications"),
        Path("/var/lib/snapd/desktop/applications"),
    ]
    
    ICON_DIRS = [
        Path("/usr/share/icons"),
        Path("/usr/share/pixmaps"),
        Path.home() / ".local/share/icons",
        Path.home() / ".local/share/flatpak/exports/share/icons",
        Path("/var/lib/flatpak/exports/share/icons"),
    ]
    
    CACHE_FILE = Path.home() / ".cache/hypr-startmenu/apps.json"
    CACHE_MAX_AGE = 300
    
    @classmethod
    def get_cache_hash(cls) -> str:
        hash_input = ""
        for desktop_dir in cls.DESKTOP_DIRS:
            if desktop_dir.exists():
                try:
                    mtime = desktop_dir.stat().st_mtime
                    hash_input += f"{desktop_dir}:{mtime};"
                except:
                    pass
        return hashlib.md5(hash_input.encode()).hexdigest()[:16]
    
    @classmethod
    def load_from_cache(cls) -> list:
        try:
            if not cls.CACHE_FILE.exists():
                return None
            
            cache_age = datetime.now().timestamp() - cls.CACHE_FILE.stat().st_mtime
            if cache_age > cls.CACHE_MAX_AGE:
                return None
            
            with open(cls.CACHE_FILE, 'r') as f:
                data = json.load(f)
            
            if data.get('hash') != cls.get_cache_hash():
                return None
            
            return data.get('apps', [])
        except:
            return None
    
    @classmethod
    def save_to_cache(cls, apps: list):
        def _save():
            try:
                cls.CACHE_FILE.parent.mkdir(parents=True, exist_ok=True)
                data = {
                    'hash': cls.get_cache_hash(),
                    'timestamp': datetime.now().isoformat(),
                    'apps': apps
                }
                with open(cls.CACHE_FILE, 'w') as f:
                    json.dump(data, f)
            except:
                pass
        
        thread = threading.Thread(target=_save, daemon=True)
        thread.start()
    
    @classmethod
    def detect_package_source(cls, desktop_path: Path) -> str:
        path_str = str(desktop_path).lower()
        if 'flatpak' in path_str:
            return 'flatpak'
        elif 'snapd' in path_str or 'snap' in path_str:
            return 'snap'
        elif '.local/share/applications' in path_str:
            return 'aur/local'
        elif '/usr/share/applications' in path_str:
            return 'pacman'
        return 'system'
    
    @classmethod
    def load_all_apps(cls, use_cache=True) -> list:
        if use_cache:
            cached = cls.load_from_cache()
            if cached:
                print(f"[StartMenu] ⚡ Loaded {len(cached)} apps from cache")
                threading.Thread(target=lambda: cls._refresh_cache(), daemon=True).start()
                return cached
        
        return cls._load_fresh()
    
    @classmethod
    def _refresh_cache(cls):
        apps = cls._load_fresh()
        cls.save_to_cache(apps)
    
    @classmethod
    def _load_fresh(cls) -> list:
        apps = []
        seen = set()
        
        for desktop_dir in cls.DESKTOP_DIRS:
            if not desktop_dir.exists():
                continue
            
            for desktop_file in desktop_dir.glob("*.desktop"):
                try:
                    app_info = cls.parse_desktop_file(desktop_file)
                    if app_info and app_info['name'] not in seen:
                        app_info['source'] = cls.detect_package_source(desktop_file)
                        apps.append(app_info)
                        seen.add(app_info['name'])
                except:
                    continue
        
        apps.sort(key=lambda x: x['name'].lower())
        print(f"[StartMenu] 📦 Loaded {len(apps)} apps from disk")
        cls.save_to_cache(apps)
        return apps
    
    @classmethod
    def parse_desktop_file(cls, desktop_file: Path) -> dict:
        try:
            with open(desktop_file, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
        except:
            return None
        
        if 'NoDisplay=true' in content or 'Hidden=true' in content:
            return None
        if '[Desktop Entry]' not in content:
            return None
        
        name = icon = exec_cmd = comment = None
        categories = []
        keywords = []
        
        in_desktop_entry = False
        for line in content.split('\n'):
            line = line.strip()
            
            if line == '[Desktop Entry]':
                in_desktop_entry = True
                continue
            elif line.startswith('[') and line.endswith(']'):
                in_desktop_entry = False
                continue
            
            if not in_desktop_entry or '=' not in line:
                continue
            
            key, _, value = line.partition('=')
            key = key.strip()
            value = value.strip()
            
            if key == 'Name' and not name:
                name = value
            elif key == 'Icon':
                icon = value
            elif key == 'Exec':
                exec_cmd = re.sub(r'%[a-zA-Z]', '', value).strip()
            elif key == 'Comment' and not comment:
                comment = value
            elif key == 'Categories':
                categories = [c.strip() for c in value.split(';') if c.strip()]
            elif key == 'Keywords':
                keywords = [k.strip() for k in value.split(';') if k.strip()]
        
        if not name:
            return None
        
        return {
            'name': name,
            'icon': icon,
            'exec': exec_cmd,
            'comment': comment,
            'categories': categories,
            'keywords': keywords + categories,
            'desktop_file': str(desktop_file)
        }
    
    @classmethod
    def find_icon_path(cls, icon_name: str, size: int = 48) -> str:
        if not icon_name:
            return None
        
        if icon_name.startswith('/') and os.path.exists(icon_name):
            return icon_name
        
        extensions = ['.png', '.svg', '.xpm', '']
        sizes = [f'{size}x{size}', 'scalable', '256x256', '128x128', '64x64', '48x48', '32x32']
        themes = ['hicolor', 'Adwaita', 'breeze', 'Papirus', '']
        categories = ['apps', 'applications', 'mimetypes', 'places']
        
        for icon_dir in cls.ICON_DIRS:
            if not icon_dir.exists():
                continue
            
            for ext in extensions:
                path = icon_dir / f"{icon_name}{ext}"
                if path.exists():
                    return str(path)
            
            for theme in themes:
                for size_dir in sizes:
                    for category in categories:
                        for ext in extensions:
                            if theme:
                                path = icon_dir / theme / size_dir / category / f"{icon_name}{ext}"
                            else:
                                path = icon_dir / size_dir / category / f"{icon_name}{ext}"
                            if path.exists():
                                return str(path)
        
        return None


# ═══════════════════════════════════════════════════════════════════════════════
# THEME HELPER
# ═══════════════════════════════════════════════════════════════════════════════

def get_current_theme_colors() -> dict:
    theme_files = [
        Path.home() / ".config/hypr-control-center/preferences/theme.json",
        Path.home() / ".config/hypr-control-center/current-theme.json",
    ]
    
    colors = {
        "bg0": "#1e2127", "bg1": "#282b31", "bg2": "#2c313a",
        "bg3": "#3e4451", "bg4": "#4b5263", "fg": "#abb2bf",
        "grey0": "#5c6370", "grey1": "#828997", "grey2": "#abb2bf",
        "red": "#e06c75", "orange": "#d19a66", "yellow": "#e5c07b",
        "green": "#98c379", "aqua": "#56b6c2", "blue": "#61afef",
        "purple": "#c678dd",
    }
    
    for theme_file in theme_files:
        try:
            if theme_file.exists():
                with open(theme_file, 'r') as f:
                    data = json.load(f)
                    colors.update(data.get('colors', {}))
                    return colors
        except:
            continue
    
    return colors


def is_light_theme(colors: dict) -> bool:
    bg = colors.get("bg0", "#282c34")
    try:
        hex_color = bg.lstrip('#')
        r, g, b = tuple(int(hex_color[i:i+2], 16) for i in (0, 2, 4))
        luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255
        return luminance > 0.5
    except:
        return False


# ═══════════════════════════════════════════════════════════════════════════════
# MAIN APPLICATION - DAEMON MODE
# ═══════════════════════════════════════════════════════════════════════════════

class StartMenu(Gtk.ApplicationWindow):
    def __init__(self, app, daemon_mode=False):
        super().__init__(application=app, title="Start Menu")
        
        self.daemon_mode = daemon_mode
        self.config_dir = Path.home() / ".config/hypr-control-center"
        self.pinned_file = self.config_dir / "preferences/start-menu-pinned.json"
        self.pinned_file.parent.mkdir(parents=True, exist_ok=True)
        
        # Load theme
        self.theme_colors = get_current_theme_colors()
        self.is_light = is_light_theme(self.theme_colors)
        
        # Load data
        self.pinned_apps = self.load_pinned_apps()
        self.all_apps = SmartAppLoader.load_all_apps(use_cache=True)
        
        # Window setup
        self.set_default_size(720, 580)
        self.set_resizable(False)
        self.set_decorated(False)
        
        # State
        self._mouse_inside = False
        self._mouse_entered = False
        self._close_timer_id = None
        self._active_popover = None
        self._search_query = ""
        self._is_visible = False
        self._ignore_focus_loss = False  # ENHANCED: Prevent focus loss during popover
        
        # Get position
        self.waybar_position = self._get_waybar_position()
        
        # Setup Layer Shell
        if HAS_LAYER_SHELL:
            self._setup_layer_shell()
        
        # Apply CSS
        self.load_css()
        
        # Build UI
        self.build_ui()
        
        # Mouse tracking
        self._setup_mouse_tracking()
        
        # Key handling - ESC to close
        key_controller = Gtk.EventControllerKey()
        key_controller.connect("key-pressed", self._on_key_pressed)
        self.add_controller(key_controller)
        
        # Focus out handling for daemon mode
        focus_controller = Gtk.EventControllerFocus()
        focus_controller.connect("leave", self._on_focus_leave)
        self.add_controller(focus_controller)
    
    def _on_focus_leave(self, controller):
        """Hide when focus is lost (daemon mode) - ENHANCED"""
        if self.daemon_mode and self._is_visible:
            # Don't close if popover is active
            if self._active_popover and self._active_popover.is_visible():
                return
            # Don't close if we're ignoring focus loss
            if self._ignore_focus_loss:
                return
            # Small delay to check if we should really close
            GLib.timeout_add(150, self._check_and_hide)
    
    def _check_and_hide(self):
        """Check if we should hide - ENHANCED"""
        # Don't hide if popover is active
        if self._active_popover and self._active_popover.is_visible():
            return False
        # Don't hide if mouse is inside
        if self._mouse_inside:
            return False
        # Don't hide if window is active
        if self.is_active():
            return False
        # Don't hide if ignoring focus loss
        if self._ignore_focus_loss:
            return False
        
        self.hide_menu()
        return False
    
    def show_menu(self):
        """Show the menu (for daemon mode)"""
        print("[StartMenu] show_menu() called")
        self._is_visible = True
        self._ignore_focus_loss = False
        
        # Force window to show
        self.set_visible(True)
        self.present()
        
        # Ensure window is on top and focused
        # Focus search entry after small delay
        GLib.timeout_add(50, lambda: self.search_entry.grab_focus() if self._is_visible else False)
        print("[StartMenu] 👁️ Menu shown")
    
    def hide_menu(self):
        """Hide the menu (for daemon mode)"""
        if not self._is_visible:
            return
            
        self._is_visible = False
        if self.daemon_mode:
            self.set_visible(False)
            # Clear search when hiding
            self.search_entry.set_text("")
            self.populate_apps_list("")
        else:
            self.close()
        print("[StartMenu] 🙈 Menu hidden")
    
    def toggle_menu(self):
        """Toggle visibility (for daemon mode)"""
        if self._is_visible:
            self.hide_menu()
        else:
            self.show_menu()
    
    def _get_waybar_position(self) -> dict:
        position = {
            "location": "center",
            "waybar_position": "top",
            "margin_left": 8, "margin_right": 8,
            "margin_bottom": 48, "margin_top": 48,
        }
        
        waybar_configs = [
            Path.home() / ".config/waybar/config.jsonc",
            Path.home() / ".config/waybar/config.json",
        ]
        
        for config_path in waybar_configs:
            if not config_path.exists():
                continue
            
            try:
                content = config_path.read_text()
                content = re.sub(r'//.*$', '', content, flags=re.MULTILINE)
                content = re.sub(r'/\*.*?\*/', '', content, flags=re.DOTALL)
                config = json.loads(content)
                
                waybar_pos = config.get("position", "top")
                position["waybar_position"] = waybar_pos
                
                waybar_height = config.get("height", 40)
                waybar_margin_top = config.get("margin-top", 0)
                waybar_margin_bottom = config.get("margin-bottom", 0)
                
                if waybar_pos == "bottom":
                    position["margin_bottom"] = waybar_height + waybar_margin_bottom + 8
                    position["margin_top"] = 8
                else:
                    position["margin_top"] = waybar_height + waybar_margin_top + 8
                    position["margin_bottom"] = 8
                
                module_name = "custom/start-menu"
                modules_left = config.get("modules-left", [])
                modules_center = config.get("modules-center", [])
                modules_right = config.get("modules-right", [])
                
                if module_name in modules_left:
                    position["location"] = "left"
                    idx = modules_left.index(module_name)
                    position["margin_left"] = config.get("margin-left", 0) + idx * 50 + 8
                elif module_name in modules_center:
                    position["location"] = "center"
                elif module_name in modules_right:
                    position["location"] = "right"
                    idx = modules_right.index(module_name)
                    modules_after = len(modules_right) - 1 - idx
                    position["margin_right"] = config.get("margin-right", 0) + modules_after * 50 + 8
                
                break
            except:
                continue
        
        return position
    
    def _setup_layer_shell(self):
        Gtk4LayerShell.init_for_window(self)
        Gtk4LayerShell.set_layer(self, Gtk4LayerShell.Layer.TOP)
        Gtk4LayerShell.set_namespace(self, "start-menu")
        Gtk4LayerShell.set_keyboard_mode(self, Gtk4LayerShell.KeyboardMode.ON_DEMAND)
        Gtk4LayerShell.set_exclusive_zone(self, -1)
        
        pos = self.waybar_position
        
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
        motion = Gtk.EventControllerMotion()
        motion.connect("enter", self._on_mouse_enter)
        motion.connect("leave", self._on_mouse_leave)
        self.add_controller(motion)
    
    def _on_mouse_enter(self, controller, x, y):
        self._mouse_inside = True
        self._mouse_entered = True
        if self._close_timer_id:
            GLib.source_remove(self._close_timer_id)
            self._close_timer_id = None
    
    def _on_mouse_leave(self, controller):
        self._mouse_inside = False
    
    def register_popover(self, popover):
        """Register popover to prevent close during context menu - ENHANCED"""
        self._active_popover = popover
        self._ignore_focus_loss = True
        
        def on_closed(p):
            self._active_popover = None
            # Delay re-enabling focus loss handling
            GLib.timeout_add(200, self._reenable_focus_loss)
        
        popover.connect("closed", on_closed)
    
    def _reenable_focus_loss(self):
        """Re-enable focus loss handling after popover closes"""
        self._ignore_focus_loss = False
        return False
    
    def _on_key_pressed(self, controller, keyval, keycode, state):
        """Handle ESC key press - closes menu"""
        if keyval == Gdk.KEY_Escape:
            self.hide_menu()
            return True
        return False
    
    def load_css(self):
        colors = self.theme_colors
        text_color = colors['fg']
        
        css = f'''
/* Start Menu v2.5 - Daemon Edition with Fixed Icons */

window, window *, window.background, window.background *,
.background, .background * {{
    background-color: rgba(0, 0, 0, 0) !important;
    background-image: none !important;
    box-shadow: none !important;
}}

.start-menu {{
    background: alpha({colors['bg0']}, 0.92);
    border-radius: 16px;
    border: 1px solid alpha({colors['fg']}, 0.12);
    box-shadow: 0 8px 32px rgba(0, 0, 0, 0.4);
}}

.start-left {{
    padding: 20px;
    border-right: 1px solid alpha({colors['fg']}, 0.08);
    background: transparent;
}}

.start-right {{
    padding: 20px;
    background: transparent;
}}

.section-title {{
    font-size: 13px;
    font-weight: 600;
    color: alpha({text_color}, 0.7);
    margin-bottom: 12px;
    background: transparent;
}}

.app-tile {{
    background: transparent;
    border: none;
    border-radius: 8px;
    padding: 12px 8px;
    min-width: 72px;
    transition: all 150ms ease;
}}

.app-tile:hover {{
    background: alpha({colors['fg']}, 0.08);
}}

.app-tile:active {{
    background: alpha({colors['fg']}, 0.12);
}}

.app-tile-label {{
    font-size: 11px;
    color: {text_color};
    background: transparent;
}}

.app-row {{
    border-radius: 8px;
    margin: 2px 0;
    padding: 8px 12px;
    transition: all 150ms ease;
    background: transparent;
}}

.app-row:hover {{
    background: alpha({colors['fg']}, 0.06);
}}

.app-row-name {{
    font-size: 13px;
    font-weight: 500;
    color: {text_color};
    background: transparent;
}}

.app-row-source {{
    font-size: 10px;
    color: {colors['grey1']};
    margin-left: 8px;
    background: transparent;
}}

.search-entry {{
    background: alpha({colors['fg']}, 0.08);
    border: 1px solid alpha({colors['fg']}, 0.12);
    border-radius: 8px;
    padding: 10px 14px;
    color: {text_color};
    margin-bottom: 12px;
}}

.search-entry:focus {{
    background: alpha({colors['fg']}, 0.1);
    border-color: {colors['blue']};
}}

.search-hint {{
    font-size: 11px;
    color: {colors['grey1']};
    margin-bottom: 8px;
    background: transparent;
}}

.bottom-bar {{
    background: alpha({colors['bg1']}, 0.6);
    border-top: 1px solid alpha({colors['fg']}, 0.08);
    padding: 14px 20px;
    border-radius: 0 0 16px 16px;
}}

.user-name {{
    font-size: 14px;
    font-weight: 600;
    color: {text_color};
    background: transparent;
}}

.nerd-icon {{
    font-family: "JetBrainsMono Nerd Font", "JetBrainsMono Nerd Font Propo", "Symbols Nerd Font Mono", "Symbols Nerd Font", monospace;
    font-size: 18px;
    color: {text_color};
    background: transparent;
    min-width: 24px;
    min-height: 24px;
}}

.icon-button {{
    background: transparent;
    border: none;
    border-radius: 8px;
    padding: 8px;
    min-width: 40px;
    min-height: 40px;
    transition: all 150ms ease;
}}

.icon-button:hover {{
    background: alpha({colors['fg']}, 0.08);
}}

.icon-button label, .icon-button .nerd-icon {{
    font-family: "JetBrainsMono Nerd Font", "JetBrainsMono Nerd Font Propo", "Symbols Nerd Font Mono", "Symbols Nerd Font", monospace;
    font-size: 18px;
    color: {text_color};
    background: transparent;
}}

/* ══════════════════════════════════════════════════════════════════════════ */
/* CIRCULAR AVATAR STYLING                                                     */
/* ══════════════════════════════════════════════════════════════════════════ */

.avatar-frame {{
    border-radius: 50%;
    border: 2px solid alpha({colors['blue']}, 0.4);
    background: transparent;
    min-width: 36px;
    min-height: 36px;
    padding: 0;
    margin: 0;
}}

.avatar-frame > * {{
    border-radius: 50%;
}}

.user-avatar-fallback {{
    background: alpha({colors['blue']}, 0.2);
    border-radius: 50%;
    min-width: 32px;
    min-height: 32px;
    padding: 4px;
}}

.user-avatar-fallback label {{
    font-family: "JetBrainsMono Nerd Font", "Symbols Nerd Font Mono", monospace;
    font-size: 16px;
    color: {colors['blue']};
}}

.letter-header {{
    font-size: 14px;
    font-weight: 600;
    color: {colors['blue']};
    padding: 8px 12px 4px;
    background: transparent;
}}

scrollbar {{ background: transparent; }}
scrollbar slider {{
    background: alpha({colors['fg']}, 0.2);
    border-radius: 4px;
    min-width: 8px;
}}
scrollbar slider:hover {{ background: alpha({colors['fg']}, 0.3); }}
scrolledwindow {{ background: transparent; }}
scrolledwindow > viewport {{ background: transparent; }}

popover, popover.menu {{
    background: alpha({colors['bg0']}, 0.95);
    border: 1px solid alpha({colors['blue']}, 0.3);
    border-radius: 12px;
    padding: 6px;
}}

popover contents {{ background: transparent; }}

popover button, popover.menu button {{
    background: transparent;
    border: none;
    border-radius: 8px;
    padding: 8px 12px;
    color: {text_color};
}}

popover button:hover, popover.menu button:hover {{
    background: alpha({colors['blue']}, 0.15);
}}

popover modelbutton {{
    padding: 8px 12px;
    border-radius: 6px;
    color: {text_color};
    background: transparent;
}}

popover modelbutton:hover {{
    background: alpha({colors['blue']}, 0.15);
}}

.apps-list {{ background: transparent; }}
.apps-list row {{ padding: 0; background: transparent; }}
.apps-list row:hover {{ background: alpha({colors['fg']}, 0.05); }}

listbox {{ background: transparent; }}
listbox row {{ background: transparent; }}
flowbox {{ background: transparent; }}
flowboxchild {{ background: transparent; }}
box {{ background: transparent; }}
label {{ background: transparent; }}
image {{ background: transparent; }}

.source-badge {{
    font-size: 9px;
    padding: 2px 6px;
    border-radius: 4px;
    font-weight: 600;
}}

.source-flatpak {{
    background: alpha({colors['blue']}, 0.2);
    color: {colors['blue']};
}}

.source-snap {{
    background: alpha({colors['orange']}, 0.2);
    color: {colors['orange']};
}}

.source-aur {{
    background: alpha({colors['aqua']}, 0.2);
    color: {colors['aqua']};
}}

.source-pacman {{
    background: alpha({colors['green']}, 0.2);
    color: {colors['green']};
}}
'''
        
        try:
            provider = Gtk.CssProvider()
            provider.load_from_string(css)
            Gtk.StyleContext.add_provider_for_display(
                self.get_display(),
                provider,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION + 100
            )
        except Exception as e:
            print(f"[StartMenu] ❌ CSS error: {e}")
    
    def load_pinned_apps(self):
        """Load pinned apps - stores desktop file paths for reliable matching"""
        try:
            if self.pinned_file.exists():
                with open(self.pinned_file, 'r') as f:
                    data = json.load(f)
                    return data.get('pinned', [])
            else:
                # Default pinned apps - use desktop file names
                default = ["firefox", "code", "thunar", "kitty"]
                self.save_pinned_apps(default)
                return default
        except:
            return []
    
    def save_pinned_apps(self, apps):
        try:
            with open(self.pinned_file, 'w') as f:
                json.dump({'pinned': apps}, f, indent=2)
            print(f"[StartMenu] 💾 Saved pinned apps: {apps}")
        except Exception as e:
            print(f"[StartMenu] ❌ Save error: {e}")
    
    def get_app_id(self, app_info):
        """Generate a unique ID for an app - use desktop file basename for reliability"""
        # Use desktop file path as the primary identifier
        desktop_file = app_info.get('desktop_file', '')
        if desktop_file:
            # Get basename without .desktop extension
            basename = Path(desktop_file).stem
            return basename.lower()
        
        # Fallback to name-based ID
        name = app_info['name'].lower()
        name = re.sub(r'[^\w\s]', '', name)
        name = name.replace(' ', '-')
        return re.sub(r'-+', '-', name).strip('-')[:50]
    
    def pin_app(self, app_id):
        """Pin an app"""
        if app_id not in self.pinned_apps:
            self.pinned_apps.append(app_id)
            self.save_pinned_apps(self.pinned_apps)
            self.refresh_pinned_section()
            print(f"[StartMenu] 📌 Pinned: {app_id}")
    
    def unpin_app(self, app_id):
        """Unpin an app"""
        print(f"[StartMenu] 🔍 Trying to unpin: {app_id}")
        print(f"[StartMenu] 📋 Current pinned: {self.pinned_apps}")
        
        if app_id in self.pinned_apps:
            self.pinned_apps.remove(app_id)
            self.save_pinned_apps(self.pinned_apps)
            self.refresh_pinned_section()
            print(f"[StartMenu] 📍 Unpinned: {app_id}")
        else:
            # Try fuzzy match - maybe the stored ID format is different
            for pinned_id in self.pinned_apps[:]:  # Copy list to allow modification
                if app_id in pinned_id or pinned_id in app_id:
                    self.pinned_apps.remove(pinned_id)
                    self.save_pinned_apps(self.pinned_apps)
                    self.refresh_pinned_section()
                    print(f"[StartMenu] 📍 Unpinned (fuzzy): {pinned_id}")
                    return
            print(f"[StartMenu] ⚠️ App not found in pinned list")
    
    def is_pinned(self, app_info):
        """Check if an app is pinned"""
        app_id = self.get_app_id(app_info)
        
        # Direct match
        if app_id in self.pinned_apps:
            return True
        
        # Fuzzy match for legacy IDs
        for pinned_id in self.pinned_apps:
            if app_id in pinned_id or pinned_id in app_id:
                return True
            # Also check app name
            if pinned_id.lower() in app_info['name'].lower():
                return True
        
        return False
    
    def find_app_by_id(self, app_id):
        """Find an app by its ID - with improved matching"""
        app_id_lower = app_id.lower()
        
        # First: exact desktop file match
        for app in self.all_apps:
            if self.get_app_id(app) == app_id_lower:
                return app
        
        # Second: desktop file contains the ID
        for app in self.all_apps:
            desktop_file = app.get('desktop_file', '').lower()
            if app_id_lower in Path(desktop_file).stem:
                return app
        
        # Third: app name contains the ID
        for app in self.all_apps:
            if app_id_lower in app['name'].lower():
                return app
        
        # Fourth: ID contains app name
        for app in self.all_apps:
            app_name_clean = re.sub(r'[^\w]', '', app['name'].lower())
            if app_name_clean in app_id_lower or app_id_lower in app_name_clean:
                return app
        
        print(f"[StartMenu] ⚠️ Could not find app: {app_id}")
        return None
    
    def build_ui(self):
        main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        main_box.add_css_class("start-menu")
        
        content = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        content.set_vexpand(True)
        
        self.left_side = self.create_left_side()
        content.append(self.left_side)
        
        right_side = self.create_right_side()
        content.append(right_side)
        
        main_box.append(content)
        
        bottom_bar = self.create_bottom_bar()
        main_box.append(bottom_bar)
        
        self.set_child(main_box)
    
    def create_left_side(self):
        left_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16)
        left_box.add_css_class("start-left")
        left_box.set_size_request(360, -1)
        
        pinned_label = Gtk.Label(label="Pinned")
        pinned_label.add_css_class("section-title")
        pinned_label.set_xalign(0)
        left_box.append(pinned_label)
        
        self.pinned_grid = Gtk.FlowBox()
        self.pinned_grid.set_valign(Gtk.Align.START)
        self.pinned_grid.set_max_children_per_line(5)
        self.pinned_grid.set_column_spacing(8)
        self.pinned_grid.set_row_spacing(8)
        self.pinned_grid.set_selection_mode(Gtk.SelectionMode.NONE)
        
        self.refresh_pinned_section()
        left_box.append(self.pinned_grid)
        
        scroll = Gtk.ScrolledWindow()
        scroll.set_child(left_box)
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroll.set_margin_start(20)
        scroll.set_margin_end(20)
        scroll.set_margin_top(20)
        scroll.set_margin_bottom(20)
        
        return scroll
    
    def refresh_pinned_section(self):
        """Refresh the pinned apps grid"""
        while (child := self.pinned_grid.get_first_child()):
            self.pinned_grid.remove(child)
        
        for app_id in self.pinned_apps:
            app_info = self.find_app_by_id(app_id)
            if app_info:
                tile = self.create_app_tile(app_info)
                self.pinned_grid.append(tile)
    
    def create_right_side(self):
        right_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        right_box.add_css_class("start-right")
        right_box.set_size_request(360, -1)
        
        header = Gtk.Label(label="All Apps")
        header.add_css_class("section-title")
        header.set_xalign(0)
        right_box.append(header)
        
        self.search_entry = Gtk.SearchEntry()
        self.search_entry.set_placeholder_text(f"{NerdIcons.SEARCH}  Type to search (fuzzy match)...")
        self.search_entry.add_css_class("search-entry")
        self.search_entry.connect("search-changed", self.on_search_changed)
        # ENHANCED: ESC in search entry also closes menu
        self.search_entry.connect("stop-search", lambda w: self.hide_menu())
        right_box.append(self.search_entry)
        
        self.search_hint = Gtk.Label(label="")
        self.search_hint.add_css_class("search-hint")
        self.search_hint.set_xalign(0)
        self.search_hint.set_visible(False)
        right_box.append(self.search_hint)
        
        self.apps_list_box = Gtk.ListBox()
        self.apps_list_box.add_css_class("apps-list")
        self.apps_list_box.set_selection_mode(Gtk.SelectionMode.NONE)
        self.apps_list_box.connect("row-activated", self.on_app_activated)
        
        self.populate_apps_list()
        
        scroll = Gtk.ScrolledWindow()
        scroll.set_child(self.apps_list_box)
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroll.set_vexpand(True)
        right_box.append(scroll)
        
        wrapper = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        wrapper.append(right_box)
        wrapper.set_margin_start(20)
        wrapper.set_margin_end(20)
        wrapper.set_margin_top(20)
        wrapper.set_margin_bottom(20)
        
        return wrapper
    
    def populate_apps_list(self, filter_text=""):
        while (row := self.apps_list_box.get_row_at_index(0)):
            self.apps_list_box.remove(row)
        
        if filter_text:
            results = fuzzy_search(self.all_apps, filter_text, threshold=0.25)
            filtered = [app for app, score in results]
            
            if filtered:
                self.search_hint.set_text(f"Found {len(filtered)} matches for '{filter_text}'")
                self.search_hint.set_visible(True)
            else:
                self.search_hint.set_text(f"No matches for '{filter_text}'")
                self.search_hint.set_visible(True)
        else:
            filtered = self.all_apps
            self.search_hint.set_visible(False)
        
        if not filter_text:
            groups = {}
            for app in filtered:
                letter = app['name'][0].upper()
                if letter not in groups:
                    groups[letter] = []
                groups[letter].append(app)
            
            for letter in sorted(groups.keys()):
                header = Gtk.Label(label=letter)
                header.add_css_class("letter-header")
                header.set_xalign(0)
                row = Gtk.ListBoxRow()
                row.set_selectable(False)
                row.set_activatable(False)
                row.set_child(header)
                self.apps_list_box.append(row)
                
                for app in groups[letter]:
                    self.apps_list_box.append(self.create_app_row(app))
        else:
            for app in filtered:
                self.apps_list_box.append(self.create_app_row(app, show_source=True))
    
    def create_app_tile(self, app_info):
        """Create a pinned app tile"""
        button = Gtk.Button()
        button.add_css_class("app-tile")
        button.connect("clicked", lambda b: self.launch_app(app_info))
        
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        box.append(self.create_app_icon(app_info['icon'], 48))
        
        label = Gtk.Label(label=app_info['name'])
        label.add_css_class("app-tile-label")
        label.set_max_width_chars(10)
        label.set_ellipsize(3)
        box.append(label)
        
        button.set_child(box)
        
        # Store app_id directly on the button for reliable unpin
        button.app_id = self.get_app_id(app_info)
        button.app_info = app_info
        
        gesture = Gtk.GestureClick.new()
        gesture.set_button(3)
        gesture.connect("pressed", lambda g, n, x, y: self.show_pinned_context_menu(button, app_info))
        button.add_controller(gesture)
        
        return button
    
    def create_app_row(self, app_info, show_source=False):
        row = Gtk.ListBoxRow()
        row.add_css_class("app-row")
        row.set_activatable(True)
        row.app_info = app_info
        row.app_id = self.get_app_id(app_info)
        
        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        box.set_margin_start(12)
        box.set_margin_end(12)
        box.set_margin_top(8)
        box.set_margin_bottom(8)
        
        box.append(self.create_app_icon(app_info['icon'], 32))
        
        info_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        info_box.set_hexpand(True)
        
        name_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        label = Gtk.Label(label=app_info['name'])
        label.add_css_class("app-row-name")
        label.set_xalign(0)
        name_box.append(label)
        
        if show_source and app_info.get('source'):
            source = app_info['source']
            source_label = Gtk.Label(label=source.upper())
            source_label.add_css_class("source-badge")
            source_label.add_css_class(f"source-{source.split('/')[0]}")
            name_box.append(source_label)
        
        info_box.append(name_box)
        
        if app_info.get('comment'):
            comment = Gtk.Label(label=app_info['comment'][:50])
            comment.add_css_class("app-row-source")
            comment.set_xalign(0)
            comment.set_ellipsize(3)
            info_box.append(comment)
        
        box.append(info_box)
        
        if self.is_pinned(app_info):
            pin = Gtk.Label(label=NerdIcons.PIN)
            pin.add_css_class("nerd-icon")
            pin.set_opacity(0.6)
            box.append(pin)
        
        row.set_child(box)
        
        gesture = Gtk.GestureClick.new()
        gesture.set_button(3)
        gesture.connect("pressed", lambda g, n, x, y: self.show_app_context_menu(row, app_info))
        row.add_controller(gesture)
        
        return row
    
    def show_pinned_context_menu(self, widget, app_info):
        """Show context menu for pinned app tile"""
        menu = Gio.Menu()
        menu.append(f"{NerdIcons.UNPIN}  Unpin from Start", "app.unpin")
        
        popover = Gtk.PopoverMenu()
        popover.set_menu_model(menu)
        popover.set_parent(widget)
        
        # Store the app_id for the action handler
        self.current_context_app = app_info
        self.current_context_app_id = self.get_app_id(app_info)
        
        self.register_popover(popover)
        popover.popup()
    
    def show_app_context_menu(self, widget, app_info):
        """Show context menu for app in list"""
        menu = Gio.Menu()
        if self.is_pinned(app_info):
            menu.append(f"{NerdIcons.UNPIN}  Unpin from Start", "app.unpin")
        else:
            menu.append(f"{NerdIcons.PIN}  Pin to Start", "app.pin")
        
        popover = Gtk.PopoverMenu()
        popover.set_menu_model(menu)
        popover.set_parent(widget)
        
        # Store the app_id for the action handler
        self.current_context_app = app_info
        self.current_context_app_id = self.get_app_id(app_info)
        
        self.register_popover(popover)
        popover.popup()
    
    def create_app_icon(self, icon_name, size):
        icon_path = SmartAppLoader.find_icon_path(icon_name, size)
        
        if icon_path and os.path.exists(icon_path):
            try:
                pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(icon_path, size, size, True)
                icon = Gtk.Image.new_from_pixbuf(pixbuf)
                icon.set_pixel_size(size)
                return icon
            except:
                pass
        
        icon = Gtk.Image.new_from_icon_name(icon_name or "application-x-executable")
        icon.set_pixel_size(size)
        return icon
    
    def create_bottom_bar(self):
        bar = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        bar.add_css_class("bottom-bar")
        bar.set_margin_start(20)
        bar.set_margin_end(20)
        bar.set_margin_top(12)
        bar.set_margin_bottom(20)
        
        # ══════════════════════════════════════════════════════════════════════
        # USER SECTION - With CIRCULAR profile photo
        # ══════════════════════════════════════════════════════════════════════
        user_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        user_box.set_valign(Gtk.Align.CENTER)
        
        # Get avatar
        avatar_path = UserProfile.get_avatar_path()
        
        if avatar_path:
            # Create circular avatar
            avatar_widget = UserProfile.create_circular_avatar(avatar_path, 32)
            user_box.append(avatar_widget)
        else:
            # Fallback: circular container with user icon
            fallback_box = Gtk.Box()
            fallback_box.add_css_class("user-avatar-fallback")
            fallback_box.set_halign(Gtk.Align.CENTER)
            fallback_box.set_valign(Gtk.Align.CENTER)
            
            user_icon = Gtk.Label(label=NerdIcons.USER)
            user_icon.add_css_class("nerd-icon")
            fallback_box.append(user_icon)
            
            frame = Gtk.Frame()
            frame.set_child(fallback_box)
            frame.add_css_class("avatar-frame")
            user_box.append(frame)
        
        # Display name
        display_name = UserProfile.get_display_name()
        user_label = Gtk.Label(label=display_name)
        user_label.add_css_class("user-name")
        user_box.append(user_label)
        
        bar.append(user_box)
        
        spacer = Gtk.Box()
        spacer.set_hexpand(True)
        bar.append(spacer)
        
        # ══════════════════════════════════════════════════════════════════════
        # BOTTOM BUTTONS - FIXED ICONS!
        # ══════════════════════════════════════════════════════════════════════
        
        # Folder button
        folder_btn = Gtk.Button()
        folder_btn.add_css_class("icon-button")
        folder_icon = Gtk.Label(label=NerdIcons.FOLDER)
        folder_icon.add_css_class("nerd-icon")
        folder_btn.set_child(folder_icon)
        folder_btn.set_tooltip_text("Open File Manager")
        folder_btn.connect("clicked", lambda b: self.launch_thunar())
        bar.append(folder_btn)
        
        # Settings button
        settings_btn = Gtk.Button()
        settings_btn.add_css_class("icon-button")
        settings_icon = Gtk.Label(label=NerdIcons.SETTINGS)
        settings_icon.add_css_class("nerd-icon")
        settings_btn.set_child(settings_icon)
        settings_btn.set_tooltip_text("Settings")
        settings_btn.connect("clicked", lambda b: self.launch_control_center())
        bar.append(settings_btn)
        
        # Power button
        power_btn = Gtk.MenuButton()
        power_btn.add_css_class("icon-button")
        power_icon = Gtk.Label(label=NerdIcons.POWER)
        power_icon.add_css_class("nerd-icon")
        power_btn.set_child(power_icon)
        power_btn.set_tooltip_text("Power Options")
        
        power_menu = Gio.Menu()
        power_menu.append(f"{NerdIcons.LOCK}  Lock", "app.lock")
        power_menu.append(f"{NerdIcons.LOGOUT}  Logout", "app.logout")
        power_menu.append(f"{NerdIcons.RESTART}  Restart", "app.restart")
        power_menu.append(f"{NerdIcons.SHUTDOWN}  Shutdown", "app.shutdown")
        power_btn.set_menu_model(power_menu)
        
        # ENHANCED: Register power menu popover to prevent unwanted close
        def on_power_toggled(btn):
            popover = btn.get_popover()
            if popover:
                self.register_popover(popover)
        # power_btn.connect("toggled", on_power_toggled)  # REMOVED - not needed
        
        bar.append(power_btn)
        
        return bar
    
    def launch_app(self, app_info):
        if not app_info or not app_info.get('exec'):
            return
        
        exec_cmd = app_info['exec']
        source = app_info.get('source', 'system')
        
        print(f"[StartMenu] 🚀 Launching: {app_info['name']} ({source})")
        
        try:
            subprocess.Popen(
                ['hyprctl', 'dispatch', 'exec', exec_cmd],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
            self.hide_menu()
        except Exception as e:
            print(f"[StartMenu] ❌ Launch error: {e}")
            try:
                subprocess.Popen(exec_cmd, shell=True, 
                               start_new_session=True,
                               stdout=subprocess.DEVNULL,
                               stderr=subprocess.DEVNULL)
                self.hide_menu()
            except:
                pass
    
    def launch_thunar(self):
        subprocess.Popen(['hyprctl', 'dispatch', 'exec', 'thunar'],
                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.hide_menu()
    
    def launch_control_center(self):
        cmd = f'python3 {self.config_dir}/main.py'
        subprocess.Popen(['hyprctl', 'dispatch', 'exec', cmd],
                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.hide_menu()
    
    def on_app_activated(self, list_box, row):
        if hasattr(row, 'app_info'):
            self.launch_app(row.app_info)
    
    def on_search_changed(self, entry):
        self._search_query = entry.get_text()
        self.populate_apps_list(self._search_query)


class StartMenuApp(Gtk.Application):
    def __init__(self, daemon_mode=False):
        super().__init__(application_id="com.hyprland.startmenu",
                        flags=Gio.ApplicationFlags.NON_UNIQUE)
        self.daemon_mode = daemon_mode
        self.window = None
        
    def do_activate(self):
        if self.window:
            self.window.toggle_menu()
            return
        
        # CRITICAL: Keep app alive in daemon mode (no visible windows)
        if self.daemon_mode:
            self.hold()
        
        self.window = StartMenu(self, daemon_mode=self.daemon_mode)
        
        for name, handler in [
            ("pin", self.on_pin),
            ("unpin", self.on_unpin),
            ("lock", lambda a, p: subprocess.Popen(['hyprlock'])),
            ("logout", lambda a, p: subprocess.Popen(['hyprctl', 'dispatch', 'exit'])),
            ("restart", lambda a, p: subprocess.Popen(['systemctl', 'reboot'])),
            ("shutdown", lambda a, p: subprocess.Popen(['systemctl', 'poweroff'])),
        ]:
            action = Gio.SimpleAction.new(name, None)
            action.connect("activate", handler)
            self.add_action(action)
        
        if self.daemon_mode:
            self.window._is_visible = False
            print("[StartMenu] 🔄 Daemon mode active - send SIGUSR1 to toggle")
        else:
            self.window._is_visible = True
        
        self.window.present()
        
        if self.daemon_mode:
            GLib.idle_add(lambda: self.window.set_visible(False))
    
    def on_pin(self, action, param):
        """Handle pin action"""
        if self.window and hasattr(self.window, 'current_context_app_id'):
            app_id = self.window.current_context_app_id
            self.window.pin_app(app_id)
            self.window.populate_apps_list(self.window._search_query)
    
    def on_unpin(self, action, param):
        """Handle unpin action"""
        if self.window and hasattr(self.window, 'current_context_app_id'):
            app_id = self.window.current_context_app_id
            print(f"[StartMenu] 🎯 Unpin action for: {app_id}")
            self.window.unpin_app(app_id)
            self.window.populate_apps_list(self.window._search_query)


def main():
    import argparse
    parser = argparse.ArgumentParser(description='Hyprland Start Menu')
    parser.add_argument('--daemon', '-d', action='store_true', help='Run in daemon mode')
    parser.add_argument('--toggle', '-t', action='store_true', help='Toggle existing instance')
    args = parser.parse_args()
    
    app = StartMenuApp(daemon_mode=args.daemon)
    
    # Write PID file FIRST before GTK starts
    pid_file = Path("/tmp/hypr-startmenu.pid")
    pid_file.write_text(str(os.getpid()))
    print(f"[StartMenu] 📝 PID file written: {os.getpid()}")
    
    # Setup SIGUSR1 handler using GLib (safer for GTK)
    def on_sigusr1():
        """Handle SIGUSR1 signal for toggle"""
        print("[StartMenu] 📨 Received SIGUSR1 - toggling...")
        if app.window:
            app.window.toggle_menu()
        return True  # Keep the handler active
    
    # Use GLib signal handler (thread-safe with GTK)
    GLib.unix_signal_add(GLib.PRIORITY_HIGH, signal.SIGUSR1, on_sigusr1)
    
    try:
        sys.exit(app.run(None))
    finally:
        pid_file.unlink(missing_ok=True)
        print("[StartMenu] 🧹 Cleanup complete")


if __name__ == "__main__":
    main()