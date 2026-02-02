#!/usr/bin/env python3
"""
═══════════════════════════════════════════════════════════════════════════════
Hyprland Panel Widget - v2.1 INSTANT Edition
═══════════════════════════════════════════════════════════════════════════════
Waybar Overlay Taskbar with TRUE TRANSPARENT background

Changes in v2.1:
- ✅ TRUE TRANSPARENT WINDOW (like clock widget approach)
- ✅ INSTANT launch (optimized initialization)
- ✅ Smart position detection from Waybar config
- ✅ Auto-detect Flatpak, Pacman, AUR, Snap apps
- ✅ Auto-close when mouse leaves

Run: LD_PRELOAD=/usr/lib/libgtk4-layer-shell.so python3 panel_widget.py
═══════════════════════════════════════════════════════════════════════════════
"""

import gi
gi.require_version('Gtk', '4.0')
from gi.repository import Gtk, Gdk, GLib, GdkPixbuf

import json
import subprocess
import asyncio
import threading
import os
import re
from pathlib import Path
from typing import Optional, Dict, List, Tuple
from dataclasses import dataclass, field
from enum import Enum, auto
import sys

# Check GTK4 Layer Shell
try:
    gi.require_version('Gtk4LayerShell', '1.0')
    from gi.repository import Gtk4LayerShell
    HAS_LAYER_SHELL = True
except:
    HAS_LAYER_SHELL = False
    print("[Panel] ⚠️ GTK4 Layer Shell not found!")

# Add panel directory to path
_panel_dir = Path(__file__).parent
if str(_panel_dir) not in sys.path:
    sys.path.insert(0, str(_panel_dir))

# Import local modules
try:
    from hypr_ipc import HyprlandIPC, HyprEvent, HyprEventType, HyprWindow, hyprctl_json
    from window_tracker import WindowTracker, AppGroup
    from pinned_manager import PinnedManager, PinnedApp, get_pinned_manager
    from icon_resolver import get_resolver, get_nerd_icon
    HAS_MODULES = True
except ImportError as e:
    print(f"[Panel] ❌ Import error: {e}")
    HAS_MODULES = False


# ═══════════════════════════════════════════════════════════════════════════════
# PATHS & THEME
# ═══════════════════════════════════════════════════════════════════════════════

CONFIG_DIR = Path.home() / ".config/hypr-control-center"
PREFERENCES_DIR = CONFIG_DIR / "preferences"

DEFAULT_COLORS = {
    "bg0": "#1e2127", "bg1": "#282b31", "bg2": "#2c313a", "bg3": "#3e4451", "bg4": "#4b5263",
    "fg": "#abb2bf", "grey0": "#5c6370", "grey1": "#828997", "grey2": "#abb2bf",
    "red": "#e06c75", "orange": "#d19a66", "yellow": "#e5c07b", "green": "#98c379",
    "aqua": "#56b6c2", "blue": "#61afef", "purple": "#c678dd"
}


def get_current_theme_colors() -> dict:
    theme_files = [
        PREFERENCES_DIR / "theme.json",
        CONFIG_DIR / "current-theme.json",
    ]
    
    for theme_file in theme_files:
        if theme_file.exists():
            try:
                with open(theme_file, 'r') as f:
                    return json.load(f).get('colors', DEFAULT_COLORS)
            except:
                pass
    
    return DEFAULT_COLORS


def is_light_theme(colors: dict) -> bool:
    bg = colors.get('bg0', '#1e2127')
    if bg.startswith('#'):
        try:
            r = int(bg[1:3], 16)
            g = int(bg[3:5], 16)
            b = int(bg[5:7], 16)
            return (0.299 * r + 0.587 * g + 0.114 * b) / 255 > 0.5
        except:
            pass
    return False


# ═══════════════════════════════════════════════════════════════════════════════
# POSITION DETECTION
# ═══════════════════════════════════════════════════════════════════════════════

@dataclass
class PanelPosition:
    location: str = "center"
    waybar_position: str = "top"
    margin_left: int = 8
    margin_right: int = 8
    margin_top: int = 48
    margin_bottom: int = 8
    waybar_height: int = 40


def detect_panel_position(module_name: str = "custom/taskbar") -> PanelPosition:
    position = PanelPosition()
    
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
            position.waybar_position = waybar_pos
            waybar_height = config.get("height", 40)
            position.waybar_height = waybar_height
            
            waybar_margin_top = config.get("margin-top", 0)
            waybar_margin_bottom = config.get("margin-bottom", 0)
            
            if waybar_pos == "bottom":
                position.margin_bottom = waybar_height + waybar_margin_bottom + 8
                position.margin_top = 8
            else:
                position.margin_top = waybar_height + waybar_margin_top + 8
                position.margin_bottom = 8
            
            modules_left = config.get("modules-left", [])
            modules_center = config.get("modules-center", [])
            modules_right = config.get("modules-right", [])
            
            if module_name in modules_left:
                position.location = "left"
                idx = modules_left.index(module_name)
                position.margin_left = config.get("margin-left", 0) + idx * 50 + 8
            elif module_name in modules_center:
                position.location = "center"
            elif module_name in modules_right:
                position.location = "right"
                idx = modules_right.index(module_name)
                modules_after = len(modules_right) - 1 - idx
                position.margin_right = config.get("margin-right", 0) + modules_after * 50 + 8
            
            break
        except:
            continue
    
    return position


# ═══════════════════════════════════════════════════════════════════════════════
# APP DETECTION
# ═══════════════════════════════════════════════════════════════════════════════

class AppType(Enum):
    NATIVE = auto()
    FLATPAK = auto()
    SNAP = auto()
    APPIMAGE = auto()
    UNKNOWN = auto()


@dataclass
class AppInfo:
    app_id: str
    name: str
    exec_cmd: str
    app_type: AppType
    desktop_file: Optional[Path] = None
    icon_name: Optional[str] = None
    wm_class: Optional[str] = None
    flatpak_id: Optional[str] = None
    categories: List[str] = field(default_factory=list)
    keywords: List[str] = field(default_factory=list)
    terminal: bool = False
    score: int = 0


class AppDetector:
    DESKTOP_DIRS = [
        (Path.home() / ".local/share/applications", AppType.NATIVE, 100),
        (Path.home() / ".local/share/flatpak/exports/share/applications", AppType.FLATPAK, 95),
        (Path("/usr/share/applications"), AppType.NATIVE, 90),
        (Path("/var/lib/flatpak/exports/share/applications"), AppType.FLATPAK, 80),
        (Path("/var/lib/snapd/desktop/applications"), AppType.SNAP, 75),
    ]
    
    _cache: Dict[str, AppInfo] = {}
    _desktop_files: Optional[Dict[str, List[Tuple[Path, AppType, int]]]] = None
    
    @classmethod
    def _index_desktop_files(cls):
        if cls._desktop_files is not None:
            return cls._desktop_files
        
        cls._desktop_files = {}
        
        for desktop_dir, app_type, priority in cls.DESKTOP_DIRS:
            if not desktop_dir.exists():
                continue
            
            try:
                for desktop_file in desktop_dir.glob("*.desktop"):
                    key = desktop_file.stem.lower()
                    if key not in cls._desktop_files:
                        cls._desktop_files[key] = []
                    cls._desktop_files[key].append((desktop_file, app_type, priority))
                    
                    if "." in key:
                        simple_key = key.split(".")[-1]
                        if simple_key not in cls._desktop_files:
                            cls._desktop_files[simple_key] = []
                        cls._desktop_files[simple_key].append((desktop_file, app_type, priority - 5))
            except:
                continue
        
        return cls._desktop_files
    
    @classmethod
    def find_app(cls, app_id: str, wm_class: Optional[str] = None) -> Optional[AppInfo]:
        app_id_lower = app_id.lower().replace(" ", "-").replace("_", "-")
        wm_class_lower = wm_class.lower() if wm_class else app_id_lower
        
        cache_key = f"{app_id_lower}:{wm_class_lower}"
        if cache_key in cls._cache:
            return cls._cache[cache_key]
        
        desktop_index = cls._index_desktop_files()
        candidates = []
        checked = set()
        
        for key in [app_id_lower, wm_class_lower, app_id_lower.split(".")[-1]]:
            if key in desktop_index:
                for desktop_file, app_type, priority in desktop_index[key]:
                    if desktop_file in checked:
                        continue
                    checked.add(desktop_file)
                    
                    app_info = cls._parse_and_score(desktop_file, app_type, priority, app_id_lower, wm_class_lower)
                    if app_info and app_info.score > 0:
                        candidates.append(app_info)
        
        if not candidates:
            return None
        
        candidates.sort(key=lambda x: x.score, reverse=True)
        best = candidates[0]
        cls._cache[cache_key] = best
        return best
    
    @classmethod
    def _parse_and_score(cls, desktop_file, default_type, base_priority, app_id, wm_class):
        try:
            content = desktop_file.read_text(errors='ignore')
        except:
            return None
        
        entry = {}
        in_entry = False
        for line in content.splitlines():
            line = line.strip()
            if line == "[Desktop Entry]":
                in_entry = True
                continue
            elif line.startswith("["):
                if in_entry:
                    break
                continue
            if in_entry and "=" in line:
                k, _, v = line.partition("=")
                entry[k.strip()] = v.strip()
        
        if not entry:
            return None
        
        exec_cmd = entry.get("Exec", "")
        name = entry.get("Name", desktop_file.stem)
        icon = entry.get("Icon", "")
        startup_wm_class = entry.get("StartupWMClass", "").lower()
        flatpak_id = entry.get("X-Flatpak", "")
        
        app_type = default_type
        if flatpak_id or "flatpak run" in exec_cmd:
            app_type = AppType.FLATPAK
            if not flatpak_id and "flatpak run" in exec_cmd:
                match = re.search(r'flatpak run\s+([^\s]+)', exec_cmd)
                if match:
                    flatpak_id = match.group(1)
        elif "/snap/" in exec_cmd:
            app_type = AppType.SNAP
        
        score = base_priority
        filename = desktop_file.stem.lower()
        name_lower = name.lower()
        
        if startup_wm_class == wm_class:
            score += 100
        elif startup_wm_class == app_id:
            score += 95
        
        if filename == wm_class or filename == app_id:
            score += 90
        elif filename.endswith(wm_class) or filename.endswith(app_id):
            score += 70
        
        if name_lower == wm_class or name_lower == app_id:
            score += 85
        
        if wm_class in filename or app_id in filename:
            score += 50
        if wm_class in name_lower or app_id in name_lower:
            score += 45
        
        if flatpak_id:
            flatpak_simple = flatpak_id.lower().split(".")[-1]
            if flatpak_simple == wm_class or flatpak_simple == app_id:
                score += 80
        
        if score <= base_priority:
            return None
        
        return AppInfo(
            app_id=desktop_file.stem,
            name=name,
            exec_cmd=exec_cmd,
            app_type=app_type,
            desktop_file=desktop_file,
            icon_name=icon,
            wm_class=startup_wm_class or filename,
            flatpak_id=flatpak_id,
            score=score
        )
    
    @classmethod
    def get_launch_command(cls, app_info: AppInfo) -> str:
        exec_cmd = re.sub(r'\s+%[a-zA-Z]', '', app_info.exec_cmd)
        
        if app_info.app_type == AppType.FLATPAK and app_info.flatpak_id:
            return f"flatpak run {app_info.flatpak_id}"
        
        parts = exec_cmd.split()
        clean_parts = []
        skip_env = True
        
        for part in parts:
            if skip_env and ("=" in part or part == "env"):
                continue
            skip_env = False
            clean_parts.append(part)
        
        return " ".join(clean_parts) if clean_parts else exec_cmd


# ═══════════════════════════════════════════════════════════════════════════════
# TASKBAR ITEM
# ═══════════════════════════════════════════════════════════════════════════════

class TaskbarItem(Gtk.Button):
    def __init__(self, panel, app_id, pinned_app=None, app_group=None):
        super().__init__()
        
        self.panel = panel
        self.app_id = app_id
        self.pinned_app = pinned_app
        self.app_group = app_group
        
        wm_class = self._get_wm_class()
        self.app_info = AppDetector.find_app(app_id, wm_class)
        
        self.add_css_class("taskbar-item")
        
        self.is_pinned = pinned_app is not None
        self.is_running = app_group is not None and app_group.window_count > 0
        self.is_focused = app_group.has_focus if app_group else False
        
        self._build_ui()
        self._update_state()
        self._setup_clicks()
    
    def _build_ui(self):
        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        box.set_valign(Gtk.Align.CENTER)
        
        resolver = get_resolver()
        wm_class = self._get_wm_class()
        
        icon_name = None
        if self.app_info and self.app_info.icon_name:
            icon_name = self.app_info.icon_name
        
        self.icon_widget = resolver.create_icon_image(
            icon_name or wm_class, 
            size=24, 
            use_nerd_fallback=True
        )
        self.icon_widget.add_css_class("taskbar-icon")
        box.append(self.icon_widget)
        
        self.set_child(box)
        self._update_tooltip()
    
    def _get_wm_class(self) -> str:
        if self.app_group:
            return self.app_group.wm_class
        if self.pinned_app:
            return self.pinned_app.wm_class or self.pinned_app.app_id
        return self.app_id
    
    def _update_state(self):
        for cls in ["focused", "running", "not-running"]:
            self.remove_css_class(cls)
        
        if self.is_focused:
            self.add_css_class("focused")
        elif self.is_running:
            self.add_css_class("running")
        elif self.is_pinned:
            self.add_css_class("not-running")
    
    def _update_tooltip(self):
        name = ""
        if self.app_info:
            name = self.app_info.name
        elif self.pinned_app:
            name = self.pinned_app.name or self.pinned_app.app_id
        elif self.app_group:
            name = self.app_group.wm_class
        else:
            name = self.app_id
        
        tooltip = name
        
        if self.app_info:
            type_icons = {
                AppType.FLATPAK: "📦",
                AppType.SNAP: "🔷",
                AppType.APPIMAGE: "📀",
            }
            type_icon = type_icons.get(self.app_info.app_type, "")
            if type_icon:
                tooltip = f"{type_icon} {tooltip}"
        
        if self.app_group and self.app_group.window_count > 1:
            tooltip += f" ({self.app_group.window_count} windows)"
        
        self.set_tooltip_text(tooltip)
    
    def _setup_clicks(self):
        self.connect("clicked", self._on_left_click)
        
        middle = Gtk.GestureClick.new()
        middle.set_button(2)
        middle.connect("pressed", self._on_middle_click)
        self.add_controller(middle)
        
        right = Gtk.GestureClick.new()
        right.set_button(3)
        right.connect("pressed", self._on_right_click)
        self.add_controller(right)
    
    def _on_left_click(self, btn):
        if self.is_running and self.app_group:
            if self.app_group.window_count == 1:
                window = self.app_group.most_recent_window
                if window:
                    self.panel.focus_window(window.address)
                    GLib.timeout_add(100, self.panel.close)
            else:
                self._show_window_list()
        elif self.is_pinned:
            self.panel.launch_app(self.app_id, self.app_info)
            GLib.timeout_add(100, self.panel.close)
    
    def _on_middle_click(self, gesture, n_press, x, y):
        if self.is_running and self.app_group:
            self.panel.close_app(self.app_group.wm_class)
    
    def _on_right_click(self, gesture, n_press, x, y):
        self._show_context_menu()
    
    def _show_window_list(self):
        if not self.app_group:
            return
        
        popover = Gtk.Popover()
        popover.set_parent(self)
        popover.add_css_class("window-list-popover")
        
        self.panel.register_popover(popover)
        
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        box.set_margin_top(8)
        box.set_margin_bottom(8)
        box.set_margin_start(8)
        box.set_margin_end(8)
        
        for window in self.app_group.windows.values():
            row = Gtk.Button()
            row.add_css_class("window-list-item")
            
            row_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
            
            if window.is_focused:
                indicator = Gtk.Label(label="●")
                indicator.add_css_class("focus-indicator")
                row_box.append(indicator)
            
            title_text = window.title[:40] if window.title else "Untitled"
            title = Gtk.Label(label=title_text)
            title.set_xalign(0)
            title.set_hexpand(True)
            title.set_ellipsize(3)
            row_box.append(title)
            
            close_btn = Gtk.Button()
            close_btn.set_icon_name("window-close-symbolic")
            close_btn.add_css_class("flat")
            close_btn.add_css_class("window-close-btn")
            close_btn.connect("clicked", lambda b, addr=window.address: self._close_single(addr, popover))
            row_box.append(close_btn)
            
            row.set_child(row_box)
            row.connect("clicked", lambda b, addr=window.address: self._focus_single(addr, popover))
            box.append(row)
        
        popover.set_child(box)
        popover.popup()
    
    def _show_context_menu(self):
        popover = Gtk.Popover()
        popover.set_parent(self)
        popover.add_css_class("context-menu")
        
        self.panel.register_popover(popover)
        
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        box.set_margin_top(4)
        box.set_margin_bottom(4)
        box.set_margin_start(4)
        box.set_margin_end(4)
        
        if self.app_info:
            type_labels = {
                AppType.FLATPAK: "📦 Flatpak",
                AppType.SNAP: "🔷 Snap",
                AppType.NATIVE: "💻 Native",
            }
            type_label = type_labels.get(self.app_info.app_type, "")
            if type_label:
                header = Gtk.Label(label=type_label)
                header.add_css_class("dim-label")
                header.set_xalign(0)
                header.set_margin_start(8)
                header.set_margin_bottom(4)
                box.append(header)
        
        if self.is_pinned:
            btn = Gtk.Button(label="📍 Unpin from taskbar")
            btn.add_css_class("flat")
            btn.connect("clicked", lambda b: self._do_action_close(popover, lambda: self.panel.unpin_app(self.app_id)))
            box.append(btn)
        else:
            btn = Gtk.Button(label="📌 Pin to taskbar")
            btn.add_css_class("flat")
            btn.connect("clicked", lambda b: self._do_action_close(popover, lambda: self.panel.pin_app(self._get_wm_class())))
            box.append(btn)
        
        new_btn = Gtk.Button(label="🆕 New window")
        new_btn.add_css_class("flat")
        new_btn.connect("clicked", lambda b: self._do_action_close(popover, lambda: self.panel.launch_app(self._get_wm_class(), self.app_info)))
        box.append(new_btn)
        
        if self.is_running:
            close_btn = Gtk.Button(label="❌ Close all windows")
            close_btn.add_css_class("flat")
            close_btn.connect("clicked", lambda b: self._do_action_close(popover, lambda: self.panel.close_app(self.app_group.wm_class)))
            box.append(close_btn)
        
        popover.set_child(box)
        popover.popup()
    
    def _do_action_close(self, popover, action):
        popover.popdown()
        action()
        GLib.timeout_add(100, self.panel.close)
    
    def _focus_single(self, address, popover):
        popover.popdown()
        self.panel.focus_window(address)
        GLib.timeout_add(100, self.panel.close)
    
    def _close_single(self, address, popover):
        self.panel.close_window(address)
    
    def update(self, app_group=None):
        self.app_group = app_group
        self.is_running = app_group is not None and app_group.window_count > 0
        self.is_focused = app_group.has_focus if app_group else False
        self._update_state()
        self._update_tooltip()


# ═══════════════════════════════════════════════════════════════════════════════
# PANEL WIDGET
# ═══════════════════════════════════════════════════════════════════════════════

class PanelWidget(Gtk.Window):
    def __init__(self, module_name: str = "custom/taskbar"):
        super().__init__()
        
        self.module_name = module_name
        self.set_title("hypr-panel")
        self.set_decorated(False)
        self.set_resizable(False)
        
        self.config_dir = Path.home() / ".config/hypr-control-center"
        
        self.position = detect_panel_position(module_name)
        
        if HAS_LAYER_SHELL:
            self._setup_layer_shell()
        
        # Apply TRUE TRANSPARENT CSS
        self._apply_transparent_css()
        
        self._build_ui()
        
        self.items: Dict[str, TaskbarItem] = {}
        self.tracker = None
        self.pinned_manager = None
        self._async_loop = None
        self._tracker_thread = None
        
        self._mouse_has_entered = False
        self._mouse_inside = False
        self._close_timer_id = None
        self._active_popover = None
        
        self._init_components()
        
        motion_controller = Gtk.EventControllerMotion()
        motion_controller.connect("enter", self._on_mouse_enter)
        motion_controller.connect("leave", self._on_mouse_leave)
        self.add_controller(motion_controller)
    
    def _on_mouse_enter(self, controller, x, y):
        self._mouse_has_entered = True
        self._mouse_inside = True
        
        if self._close_timer_id:
            GLib.source_remove(self._close_timer_id)
            self._close_timer_id = None
    
    def _on_mouse_leave(self, controller):
        self._mouse_inside = False
        
        if self._mouse_has_entered:
            def delayed_close():
                self._close_timer_id = None
                if not self._mouse_inside and not self._has_open_popover():
                    self._close_panel()
                return False
            
            self._close_timer_id = GLib.timeout_add(400, delayed_close)
    
    def _has_open_popover(self) -> bool:
        return self._active_popover and self._active_popover.is_visible()
    
    def register_popover(self, popover):
        self._active_popover = popover
        
        def on_closed(p):
            self._active_popover = None
            if not self._mouse_inside and self._mouse_has_entered:
                GLib.timeout_add(300, lambda: self._close_panel() if not self._mouse_inside else None)
        
        popover.connect("closed", on_closed)
    
    def _close_panel(self):
        if self._has_open_popover():
            return False
        self._mouse_has_entered = False
        self.close()
        return False
    
    def _setup_layer_shell(self):
        Gtk4LayerShell.init_for_window(self)
        Gtk4LayerShell.set_layer(self, Gtk4LayerShell.Layer.TOP)
        Gtk4LayerShell.set_namespace(self, "hypr-panel")
        Gtk4LayerShell.set_keyboard_mode(self, Gtk4LayerShell.KeyboardMode.NONE)
        Gtk4LayerShell.set_exclusive_zone(self, 0)
        
        pos = self.position
        
        if pos.waybar_position == "bottom":
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.BOTTOM, True)
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.TOP, False)
            Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.BOTTOM, pos.margin_bottom)
        else:
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.TOP, True)
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.BOTTOM, False)
            Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.TOP, pos.margin_top)
        
        if pos.location == "left":
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.LEFT, True)
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.RIGHT, False)
            Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.LEFT, pos.margin_left)
        elif pos.location == "center":
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.LEFT, False)
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.RIGHT, False)
        else:
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.RIGHT, True)
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.LEFT, False)
            Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.RIGHT, pos.margin_right)
    
    def _apply_transparent_css(self):
        """Apply CSS with TRUE TRANSPARENT WINDOW (like clock widget)"""
        colors = get_current_theme_colors()
        light = is_light_theme(colors)
        
        css = f'''
/* ═══════════════════════════════════════════════════════════════════════════ */
/* PANEL WIDGET - TRUE TRANSPARENT WINDOW (Clock Widget Approach)              */
/* ═══════════════════════════════════════════════════════════════════════════ */

/* Force ALL window backgrounds transparent */
window,
window *,
window.background,
window.background *,
.background,
.background * {{
    background-color: rgba(0, 0, 0, 0) !important;
    background-image: none !important;
    box-shadow: none !important;
}}

/* The actual panel container - this has the styled background */
.panel-container {{
    background: alpha({colors['bg0']}, 0.92);
    border-radius: 12px;
    border: 1px solid alpha({colors['fg']}, 0.12);
    padding: 4px 8px;
    box-shadow: 0 4px 16px rgba(0, 0, 0, 0.3);
}}

.taskbar-item {{
    background: transparent;
    border: none;
    border-radius: 8px;
    padding: 6px 8px;
    margin: 2px;
    min-width: 36px;
    min-height: 36px;
    transition: all 150ms ease;
}}

.taskbar-item:hover {{
    background: alpha({colors['fg']}, 0.08);
}}

.taskbar-item.focused {{
    background: alpha({colors['blue']}, 0.15);
    border-bottom: 2px solid {colors['blue']};
}}

.taskbar-item.running {{
    border-bottom: 2px solid alpha({colors['blue']}, 0.5);
}}

.taskbar-item.not-running {{
    opacity: 0.6;
}}

.taskbar-item.not-running:hover {{
    opacity: 1;
}}

.taskbar-icon {{
    color: {colors['fg']};
    font-size: 20px;
    background: transparent;
}}

.separator {{
    background: alpha({colors['fg']}, 0.15);
    min-width: 1px;
    margin: 8px 4px;
}}

.window-list-popover,
.context-menu {{
    background: alpha({colors['bg0']}, 0.95);
    border: 1px solid alpha({colors['blue']}, 0.3);
    border-radius: 12px;
}}

.window-list-popover > contents,
.context-menu > contents {{
    background: transparent;
    padding: 4px;
}}

.window-list-item,
.context-menu button {{
    background: transparent;
    border: none;
    border-radius: 8px;
    padding: 8px 12px;
    margin: 2px;
    color: {colors['fg']};
}}

.window-list-item:hover,
.context-menu button:hover {{
    background: alpha({colors['blue']}, 0.15);
}}

.focus-indicator {{
    color: {colors['blue']};
    margin-right: 8px;
    background: transparent;
}}

.window-close-btn {{
    opacity: 0.5;
    min-width: 24px;
    min-height: 24px;
    background: transparent;
}}

.window-close-btn:hover {{
    opacity: 1;
    color: {colors['red']};
}}

.dim-label {{
    opacity: 0.7;
    font-size: 0.85em;
    color: {colors['grey1']};
    background: transparent;
}}

tooltip {{
    background: alpha({colors['bg0']}, 0.95);
    border: 1px solid alpha({colors['blue']}, 0.2);
    border-radius: 8px;
}}

tooltip label {{
    color: {colors['fg']};
    padding: 6px 10px;
    background: transparent;
}}

box {{
    background: transparent;
}}

label {{
    background: transparent;
}}

image {{
    background: transparent;
}}

popover {{
    background: transparent;
}}

popover contents {{
    background: transparent;
}}
'''
        
        provider = Gtk.CssProvider()
        provider.load_from_string(css)
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION + 100
        )
    
    def _build_ui(self):
        self.container = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=2)
        self.container.add_css_class("panel-container")
        self.container.set_halign(Gtk.Align.CENTER)
        self.container.set_valign(Gtk.Align.CENTER)
        
        self.pinned_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=2)
        self.container.append(self.pinned_box)
        
        self.separator = Gtk.Separator(orientation=Gtk.Orientation.VERTICAL)
        self.separator.add_css_class("separator")
        self.container.append(self.separator)
        
        self.running_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=2)
        self.container.append(self.running_box)
        
        self.set_child(self.container)
    
    def _init_components(self):
        self.pinned_manager = get_pinned_manager(self.config_dir)
        self.pinned_manager.on_change(self._on_pinned_change)
        
        self.tracker = WindowTracker()
        self.tracker.on_change(self._on_tracker_change)
        
        GLib.idle_add(self._rebuild_ui)
        
        def run_tracker():
            self._async_loop = asyncio.new_event_loop()
            asyncio.set_event_loop(self._async_loop)
            try:
                self._async_loop.run_until_complete(self.tracker.start())
            except:
                pass
        
        self._tracker_thread = threading.Thread(target=run_tracker, daemon=True)
        self._tracker_thread.start()
    
    def _on_tracker_change(self):
        GLib.idle_add(self._update_ui)
    
    def _on_pinned_change(self):
        GLib.idle_add(self._rebuild_ui)
    
    def _rebuild_ui(self):
        self.items.clear()
        
        while (child := self.pinned_box.get_first_child()):
            self.pinned_box.remove(child)
        while (child := self.running_box.get_first_child()):
            self.running_box.remove(child)
        
        pinned_apps = self.pinned_manager.get_pinned_apps() if self.pinned_manager else []
        running_groups = {g.wm_class.lower(): g for g in (self.tracker.get_app_groups() if self.tracker else [])}
        
        for pinned in pinned_apps:
            app_group = None
            if pinned.wm_class and pinned.wm_class.lower() in running_groups:
                app_group = running_groups[pinned.wm_class.lower()]
            elif pinned.app_id.lower() in running_groups:
                app_group = running_groups[pinned.app_id.lower()]
            
            item = TaskbarItem(self, pinned.app_id, pinned_app=pinned, app_group=app_group)
            self.items[pinned.app_id] = item
            self.pinned_box.append(item)
        
        pinned_classes = set()
        for p in pinned_apps:
            if p.wm_class:
                pinned_classes.add(p.wm_class.lower())
            pinned_classes.add(p.app_id.lower())
        
        for wm_class, group in running_groups.items():
            if wm_class not in pinned_classes and group.wm_class.lower() not in pinned_classes:
                item = TaskbarItem(self, wm_class, app_group=group)
                self.items[wm_class] = item
                self.running_box.append(item)
        
        has_pinned = self.pinned_box.get_first_child() is not None
        has_running = self.running_box.get_first_child() is not None
        self.separator.set_visible(has_pinned and has_running)
        
        return False
    
    def _update_ui(self):
        if not self.tracker:
            return False
        
        running_groups = {g.wm_class.lower(): g for g in self.tracker.get_app_groups()}
        pinned_classes = set()
        
        if self.pinned_manager:
            for p in self.pinned_manager.get_pinned_apps():
                if p.wm_class:
                    pinned_classes.add(p.wm_class.lower())
                pinned_classes.add(p.app_id.lower())
        
        for app_id, item in list(self.items.items()):
            wm_class = item._get_wm_class().lower()
            app_group = running_groups.get(app_id.lower()) or running_groups.get(wm_class)
            item.update(app_group)
        
        current_ids = set(self.items.keys())
        for wm_class in running_groups:
            if wm_class not in current_ids and wm_class not in pinned_classes:
                group = running_groups[wm_class]
                if group.wm_class.lower() not in pinned_classes:
                    item = TaskbarItem(self, wm_class, app_group=group)
                    self.items[wm_class] = item
                    self.running_box.append(item)
        
        for app_id in list(self.items.keys()):
            if app_id.lower() not in pinned_classes and app_id.lower() not in running_groups:
                item = self.items.pop(app_id)
                self.running_box.remove(item)
        
        has_pinned = self.pinned_box.get_first_child() is not None
        has_running = self.running_box.get_first_child() is not None
        self.separator.set_visible(has_pinned and has_running)
        
        return False
    
    def focus_window(self, address):
        if self._async_loop and self.tracker:
            asyncio.run_coroutine_threadsafe(self.tracker.focus_window(address), self._async_loop)
    
    def close_window(self, address):
        if self._async_loop and self.tracker:
            asyncio.run_coroutine_threadsafe(self.tracker.close_window(address), self._async_loop)
    
    def close_app(self, wm_class):
        if self._async_loop and self.tracker:
            asyncio.run_coroutine_threadsafe(self.tracker.close_app(wm_class), self._async_loop)
    
    def launch_app(self, app_id, app_info=None):
        if not app_info:
            app_info = AppDetector.find_app(app_id)
        
        if app_info:
            cmd = AppDetector.get_launch_command(app_info)
            print(f"[Panel] 🚀 Launching: {app_info.name} ({app_info.app_type.name})")
            self._exec_command(cmd)
        else:
            print(f"[Panel] 🚀 Direct launch: {app_id}")
            self._exec_command(app_id)
    
    def _exec_command(self, cmd):
        try:
            subprocess.Popen(
                ["hyprctl", "dispatch", "exec", cmd],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
        except:
            pass
    
    def pin_app(self, app_id):
        if self.pinned_manager:
            self.pinned_manager.pin_app(app_id)
    
    def unpin_app(self, app_id):
        if self.pinned_manager:
            self.pinned_manager.unpin_app(app_id)
    
    def cleanup(self):
        if self._close_timer_id:
            GLib.source_remove(self._close_timer_id)
        if self.tracker:
            self.tracker.stop()
        if self._async_loop:
            self._async_loop.call_soon_threadsafe(self._async_loop.stop)


def main():
    if not HAS_MODULES:
        print("[Panel] ❌ Missing required modules!")
        return
    
    panel = PanelWidget("custom/taskbar")
    panel.present()
    
    loop = GLib.MainLoop()
    
    def on_destroy(win):
        panel.cleanup()
        loop.quit()
    
    panel.connect("destroy", on_destroy)
    
    try:
        loop.run()
    except KeyboardInterrupt:
        panel.cleanup()
        loop.quit()


if __name__ == "__main__":
    main()