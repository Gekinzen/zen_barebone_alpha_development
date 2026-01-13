#!/usr/bin/env python3
"""
ZenPyBar v1.1 - Fully Integrated with Embedded Taskbar
======================================================

Single bar per monitor, shared taskbar data (NO DUPLICATES!).
Detects custom/taskbar position from Waybar config.

Run: LD_PRELOAD=/usr/lib/libgtk4-layer-shell.so python3 bar.py
Or: ./run.sh
"""

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Gtk4LayerShell', '1.0')
from gi.repository import Gtk, Gdk, Gtk4LayerShell, GLib

import sys
import subprocess
import json
import re
import datetime
import asyncio
import threading
from pathlib import Path
from typing import Dict, List, Optional
from dataclasses import dataclass

SRC_DIR = Path(__file__).resolve().parent.parent
if str(SRC_DIR) not in sys.path:
    sys.path.insert(0, str(SRC_DIR))


# ═══════════════════════════════════════════════════════════════════════════════
# PANEL MODULES (Optional - for taskbar)
# ═══════════════════════════════════════════════════════════════════════════════

_panel_dir = Path.home() / ".config/hypr-control-center/src/panel"
if _panel_dir.exists() and str(_panel_dir) not in sys.path:
    sys.path.insert(0, str(_panel_dir))

HAS_PANEL = False
try:
    from window_tracker import WindowTracker, AppGroup
    from pinned_manager import PinnedManager, get_pinned_manager
    from icon_resolver import get_resolver
    HAS_PANEL = True
    print("[ZenPyBar] ✅ Panel modules loaded")
except ImportError as e:
    print(f"[ZenPyBar] ⚠️ No panel modules: {e}")
    print("[ZenPyBar] Taskbar will be disabled")


# ═══════════════════════════════════════════════════════════════════════════════
# CONFIG
# ═══════════════════════════════════════════════════════════════════════════════

@dataclass
class ThemeColors:
    bg0: str = "#1a1b26"
    bg1: str = "#16161e"
    bg2: str = "#24283b"
    fg: str = "#c0caf5"
    blue: str = "#7aa2f7"
    purple: str = "#bb9af7"
    red: str = "#f7768e"


def load_waybar_config() -> dict:
    """Load Waybar config.jsonc"""
    config_path = Path.home() / ".config/waybar/config.jsonc"
    if not config_path.exists():
        config_path = Path.home() / ".config/waybar/config.json"
    
    if not config_path.exists():
        return {}
    
    try:
        content = config_path.read_text()
        # Remove JSONC comments
        content = re.sub(r'//.*?$', '', content, flags=re.MULTILINE)
        content = re.sub(r'/\*.*?\*/', '', content, flags=re.DOTALL)
        content = re.sub(r',\s*([}\]])', r'\1', content)
        return json.loads(content)
    except Exception as e:
        print(f"[Config] Error loading Waybar config: {e}")
        return {}


def load_theme() -> ThemeColors:
    """Load theme colors from Waybar CSS"""
    theme = ThemeColors()
    colorscheme_dir = Path.home() / ".config/colorscheme"
    style_path = Path.home() / ".config/waybar/style.css"
    
    css_content = ""
    
    # Read style.css to find imported theme
    if style_path.exists():
        css_content = style_path.read_text()
        
        # Find @import line
        import_match = re.search(r"@import\s+['\"]\.\.\/colorscheme\/([^'\"]+)\.css['\"]", css_content)
        if import_match:
            theme_name = import_match.group(1)
            theme_file = colorscheme_dir / f"{theme_name}.css"
            if theme_file.exists():
                css_content = theme_file.read_text() + "\n" + css_content
    
    # Parse @define-color statements
    for match in re.finditer(r"@define-color\s+(\w+)\s+([^;]+);", css_content):
        name, value = match.group(1), match.group(2).strip()
        if hasattr(theme, name):
            setattr(theme, name, value)
    
    return theme


def hex_to_rgba(hex_color: str, alpha: float) -> str:
    """Convert hex to rgba() string"""
    hex_color = hex_color.lstrip('#')
    r = int(hex_color[0:2], 16)
    g = int(hex_color[2:4], 16)
    b = int(hex_color[4:6], 16)
    return f"rgba({r}, {g}, {b}, {alpha})"


# ═══════════════════════════════════════════════════════════════════════════════
# TASKBAR ITEM (Embedded)
# ═══════════════════════════════════════════════════════════════════════════════

class TaskbarItem(Gtk.Button):
    """Single taskbar button (embedded in main bar)"""
    
    def __init__(self, bar, app_id: str, pinned_app=None, app_group=None):
        super().__init__()
        self.bar = bar
        self.app_id = app_id
        self.pinned_app = pinned_app
        self.app_group = app_group
        
        self.add_css_class("taskbar-item")
        
        self.is_pinned = pinned_app is not None
        self.is_running = app_group is not None and app_group.window_count > 0
        self.is_focused = app_group.has_focus if app_group else False
        
        self._build_ui()
        self._update_state()
        self._setup_clicks()
    
    def _build_ui(self):
        """Build taskbar item UI"""
        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        box.set_valign(Gtk.Align.CENTER)
        
        if HAS_PANEL:
            resolver = get_resolver()
            wm_class = self._get_wm_class()
            self.icon_widget = resolver.create_icon_image(wm_class, size=22, use_nerd_fallback=True)
        else:
            # Fallback to generic icon
            self.icon_widget = Gtk.Label(label="󰣆")
            self.icon_widget.add_css_class("nerd-icon")
        
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
        """Update CSS state classes"""
        self.remove_css_class("focused")
        self.remove_css_class("running")
        self.remove_css_class("pinned")
        
        if self.is_focused:
            self.add_css_class("focused")
        elif self.is_running:
            self.add_css_class("running")
        elif self.is_pinned:
            self.add_css_class("pinned")
    
    def _update_tooltip(self):
        """Update tooltip text"""
        name = self.pinned_app.name if self.pinned_app else self._get_wm_class()
        if self.app_group and self.app_group.window_count > 1:
            name += f" ({self.app_group.window_count})"
        self.set_tooltip_text(name)
    
    def _setup_clicks(self):
        """Setup click handlers"""
        self.connect("clicked", self._on_click)
        
        # Middle click - close all
        middle = Gtk.GestureClick.new()
        middle.set_button(2)
        middle.connect("pressed", self._on_middle_click)
        self.add_controller(middle)
        
        # Right click - context menu
        right = Gtk.GestureClick.new()
        right.set_button(3)
        right.connect("pressed", self._on_right_click)
        self.add_controller(right)
    
    def _on_click(self, btn):
        """Left click - focus or launch"""
        print(f"[TaskbarItem] Clicked: {self.app_id}")
        if self.is_running and self.app_group:
            if self.app_group.window_count == 1:
                window = self.app_group.most_recent_window
                if window:
                    print(f"[TaskbarItem] Focusing window: {window.address}")
                    self.bar.focus_window(window.address)
            else:
                # Multiple windows - show list
                self._show_window_list()
        elif self.is_pinned:
            print(f"[TaskbarItem] Launching: {self.app_id}")
            self.bar.launch_app(self.app_id)
    
    def _on_middle_click(self, gesture, n, x, y):
        """Middle click - close all windows"""
        if self.is_running and self.app_group:
            print(f"[TaskbarItem] Closing all: {self.app_group.wm_class}")
            self.bar.close_app(self.app_group.wm_class)
    
    def _on_right_click(self, gesture, n, x, y):
        """Right click - context menu"""
        self._show_context_menu()
    
    def _show_window_list(self):
        """Show popover with list of windows"""
        if not self.app_group:
            return
        
        popover = Gtk.Popover()
        popover.set_parent(self)
        popover.add_css_class("window-list-popover")
        
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        box.set_margin_top(8)
        box.set_margin_bottom(8)
        box.set_margin_start(8)
        box.set_margin_end(8)
        
        for window in self.app_group.windows.values():
            row = Gtk.Button()
            row.add_css_class("window-list-item")
            
            row_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
            
            # Focus indicator
            if window.is_focused:
                indicator = Gtk.Label(label="●")
                indicator.add_css_class("focus-indicator")
                row_box.append(indicator)
            
            # Window title
            title_text = window.title[:40] if window.title else "Untitled"
            title = Gtk.Label(label=title_text)
            title.set_xalign(0)
            title.set_hexpand(True)
            row_box.append(title)
            
            row.set_child(row_box)
            row.connect("clicked", lambda b, addr=window.address: self._focus_and_close(addr, popover))
            box.append(row)
        
        popover.set_child(box)
        popover.popup()
    
    def _focus_and_close(self, address: str, popover: Gtk.Popover):
        """Focus window and close popover"""
        popover.popdown()
        self.bar.focus_window(address)
    
    def _show_context_menu(self):
        """Show context menu"""
        popover = Gtk.Popover()
        popover.set_parent(self)
        popover.add_css_class("context-menu")
        
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        box.set_margin_top(4)
        box.set_margin_bottom(4)
        box.set_margin_start(4)
        box.set_margin_end(4)
        
        # Pin/Unpin
        if self.is_pinned:
            unpin_btn = Gtk.Button(label="Unpin from taskbar")
            unpin_btn.add_css_class("flat")
            unpin_btn.connect("clicked", lambda b: self._unpin(popover))
            box.append(unpin_btn)
        else:
            pin_btn = Gtk.Button(label="Pin to taskbar")
            pin_btn.add_css_class("flat")
            pin_btn.connect("clicked", lambda b: self._pin(popover))
            box.append(pin_btn)
        
        # Close all (if running)
        if self.is_running:
            close_btn = Gtk.Button(label="Close all windows")
            close_btn.add_css_class("flat")
            close_btn.connect("clicked", lambda b: self._close_all(popover))
            box.append(close_btn)
        
        # New window
        launch_btn = Gtk.Button(label="New window")
        launch_btn.add_css_class("flat")
        launch_btn.connect("clicked", lambda b: self._launch_new(popover))
        box.append(launch_btn)
        
        popover.set_child(box)
        popover.popup()
    
    def _pin(self, popover: Gtk.Popover):
        popover.popdown()
        self.bar.pin_app(self._get_wm_class())
    
    def _unpin(self, popover: Gtk.Popover):
        popover.popdown()
        self.bar.unpin_app(self.app_id)
    
    def _close_all(self, popover: Gtk.Popover):
        popover.popdown()
        if self.app_group:
            self.bar.close_app(self.app_group.wm_class)
    
    def _launch_new(self, popover: Gtk.Popover):
        popover.popdown()
        self.bar.launch_app(self._get_wm_class())
    
    def update(self, app_group=None):
        """Update item state"""
        self.app_group = app_group
        self.is_running = app_group is not None and app_group.window_count > 0
        self.is_focused = app_group.has_focus if app_group else False
        self._update_state()
        self._update_tooltip()


# ═══════════════════════════════════════════════════════════════════════════════
# MAIN BAR (One per monitor)
# ═══════════════════════════════════════════════════════════════════════════════

class ZenPyBar(Gtk.Window):
    """Main bar window - one per monitor"""
    
    # Class variables for shared tracker (prevents duplicates!)
    _shared_tracker = None
    _shared_async_loop = None
    _tracker_initialized = False
    
    def __init__(self, monitor_name: str = None, config: dict = None, theme: ThemeColors = None):
        super().__init__()
        
        self.monitor_name = monitor_name
        self.config = config or {}
        self.theme = theme or ThemeColors()
        
        # Config parsing
        self.height = self.config.get('height', 40)
        self.position = self.config.get('position', 'bottom')
        self.margin_top = self.config.get('margin-top', 4)
        self.margin_bottom = self.config.get('margin-bottom', 3)
        
        self.modules_left = self.config.get('modules-left', [])
        self.modules_center = self.config.get('modules-center', [])
        self.modules_right = self.config.get('modules-right', [])
        
        # Workspace config
        ws_config = self.config.get('hyprland/workspaces', {})
        self.persistent_ws = ws_config.get('persistent-workspaces', {}).get('*', 5)
        
        self.set_title(f"zenpybar-{monitor_name}" if monitor_name else "zenpybar")
        self.set_decorated(False)
        
        # Taskbar state (per-bar UI, shared data)
        self.taskbar_items: Dict[str, TaskbarItem] = {}
        self.taskbar_container: Optional[Gtk.Box] = None
        self.pinned_manager: Optional[PinnedManager] = None
        
        # Detect where custom/taskbar is in config
        self._detect_taskbar_position()
        
        # Setup
        self._setup_layer_shell()
        self._apply_css()
        self._build_ui()
        
        # Start update timers
        GLib.timeout_add(100, self._update_workspaces)
        GLib.timeout_add(1000, self._update_clock)
        GLib.timeout_add(2000, self._update_music)
        
        # Initialize embedded taskbar
        if self.taskbar_position and HAS_PANEL:
            self._init_embedded_taskbar()
    
    def _detect_taskbar_position(self):
        """Detect where custom/taskbar is in the config"""
        taskbar_modules = ['custom/taskbar', 'wlr/taskbar', 'hyprland/taskbar']
        
        self.taskbar_position = None
        
        for mod in taskbar_modules:
            if mod in self.modules_left:
                self.taskbar_position = 'left'
                print(f"[ZenPyBar] 📍 Taskbar detected in modules-left: {mod}")
                break
            elif mod in self.modules_center:
                self.taskbar_position = 'center'
                print(f"[ZenPyBar] 📍 Taskbar detected in modules-center: {mod}")
                break
            elif mod in self.modules_right:
                self.taskbar_position = 'right'
                print(f"[ZenPyBar] 📍 Taskbar detected in modules-right: {mod}")
                break
        
        if not self.taskbar_position:
            print("[ZenPyBar] ⚠️ No taskbar module found in config")
    
    def _setup_layer_shell(self):
        """Setup GTK4 Layer Shell"""
        Gtk4LayerShell.init_for_window(self)
        Gtk4LayerShell.set_layer(self, Gtk4LayerShell.Layer.TOP)
        Gtk4LayerShell.set_namespace(self, f"zenpybar-{self.monitor_name}" if self.monitor_name else "zenpybar")
        Gtk4LayerShell.set_keyboard_mode(self, Gtk4LayerShell.KeyboardMode.ON_DEMAND)
        
        # Set monitor
        if self.monitor_name:
            display = self.get_display()
            monitors = display.get_monitors()
            for i in range(monitors.get_n_items()):
                mon = monitors.get_item(i)
                if mon.get_connector() == self.monitor_name:
                    Gtk4LayerShell.set_monitor(self, mon)
                    print(f"[ZenPyBar] Assigned to monitor: {self.monitor_name}")
                    break
        
        # Anchors
        Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.LEFT, True)
        Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.RIGHT, True)
        
        if self.position == "bottom":
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.BOTTOM, True)
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.TOP, False)
        else:
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.TOP, True)
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.BOTTOM, False)
        
        # Margins
        Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.TOP, self.margin_top)
        Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.BOTTOM, self.margin_bottom)
        
        # Exclusive zone
        Gtk4LayerShell.set_exclusive_zone(self, self.height + self.margin_top + self.margin_bottom)
        
        print(f"[ZenPyBar] Layer Shell configured: {self.position}, height={self.height}px")
    
    def _apply_css(self):
        """Apply theme CSS"""
        t = self.theme
        bg0_92 = hex_to_rgba(t.bg0, 0.92)
        bg0_90 = hex_to_rgba(t.bg0, 0.90)
        bg0_40 = hex_to_rgba(t.bg0, 0.40)
        
        css = Gtk.CssProvider()
        css.load_from_string(f'''
/* ZenPyBar Theme */
window {{ background-color: {bg0_92}; }}
label {{ 
    color: {t.fg}; 
    font-family: "JetBrainsMono Nerd Font Propo", sans-serif; 
    font-size: 14px; 
    font-weight: bold; 
}}

.zenpy-bar {{ 
    background-color: {bg0_92}; 
    min-height: {self.height}px; 
}}

/* Workspaces */
.workspaces {{ 
    background-color: {bg0_40}; 
    padding: 5px 3px; 
    margin: 0 0 0 12px; 
    border-radius: 26px; 
    border: 1px solid {t.bg1}; 
}}

.workspace-btn {{ 
    min-width: 30px; 
    min-height: 30px; 
    padding: 0 6px; 
    margin: 0 3px; 
    border-radius: 16px; 
    background-color: {t.bg1}; 
    border: none; 
}}

.workspace-btn label {{ color: transparent; }}
.workspace-btn.active {{ background-color: {t.blue}; min-width: 50px; }}
.workspace-btn.active label {{ color: {t.bg0}; }}
.workspace-btn.occupied {{ background-color: {t.bg2}; }}
.workspace-btn:hover {{ background-color: {t.purple}; }}

/* Embedded Taskbar */
.taskbar {{ 
    background-color: {bg0_90}; 
    padding: 4px 8px; 
    margin: 0 0 0 12px; 
    border-radius: 45px; 
    border: 1px solid {t.bg1}; 
    min-height: 36px;
}}

.taskbar-item {{ 
    min-width: 32px; 
    min-height: 32px; 
    padding: 4px; 
    margin: 0 2px; 
    border-radius: 10px; 
    background-color: transparent; 
    border: none; 
}}

.taskbar-item.pinned {{ opacity: 0.5; }}
.taskbar-item.running {{ background-color: {t.bg2}; opacity: 1; }}
.taskbar-item.focused {{ background-color: {t.blue}; opacity: 1; }}
.taskbar-item:hover {{ background-color: {t.purple}; }}

.taskbar-icon {{ min-width: 22px; min-height: 22px; }}
.nerd-icon {{ font-size: 18px; color: {t.fg}; }}
.taskbar-item.focused .nerd-icon {{ color: {t.bg0}; }}

/* Clock */
.clock {{ 
    background-color: {bg0_90}; 
    padding: 0 15px; 
    margin: 0 12px; 
    border-radius: 45px; 
    border: 1px solid {t.bg1}; 
}}
.clock label {{ color: {t.blue}; }}

/* Music */
.music {{ 
    background-color: {bg0_90}; 
    padding: 0 15px; 
    margin: 0 0 0 12px; 
    border-radius: 45px; 
    border: 1px solid {t.bg1}; 
}}
.music label {{ color: {t.purple}; }}

/* Notification */
.notification {{ 
    background-color: {bg0_90}; 
    padding: 0 15px; 
    margin: 0 12px; 
    border-radius: 45px; 
    border: 1px solid {t.bg1}; 
}}

/* Window List Popover */
.window-list-popover {{
    background: {t.bg0};
    border: 1px solid {t.bg2};
    border-radius: 12px;
}}

.window-list-popover > contents {{
    background: transparent;
}}

.window-list-item {{
    background: transparent;
    border: none;
    border-radius: 8px;
    padding: 8px 12px;
}}

.window-list-item:hover {{
    background: {t.bg2};
}}

.focus-indicator {{
    color: {t.blue};
    margin-right: 8px;
}}

/* Context Menu */
.context-menu {{
    background: {t.bg0};
    border: 1px solid {t.bg2};
    border-radius: 12px;
}}

.context-menu > contents {{
    background: transparent;
}}

.context-menu button {{
    background: transparent;
    border: none;
    border-radius: 8px;
    padding: 8px 16px;
    color: {t.fg};
}}

.context-menu button:hover {{
    background: {t.bg2};
}}
        ''')
        
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(), css,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION + 100
        )
    
    def _build_ui(self):
        """Build bar UI from config"""
        main = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        main.add_css_class("zenpy-bar")
        main.set_hexpand(True)
        
        # Left section
        self.left_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        self.left_box.set_halign(Gtk.Align.START)
        self.left_box.set_hexpand(True)
        
        # Center section
        self.center_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        self.center_box.set_halign(Gtk.Align.CENTER)
        
        # Right section
        self.right_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        self.right_box.set_halign(Gtk.Align.END)
        self.right_box.set_hexpand(True)
        
        # Build modules for each section
        for mod in self.modules_left:
            w = self._create_module(mod)
            if w:
                self.left_box.append(w)
        
        for mod in self.modules_center:
            w = self._create_module(mod)
            if w:
                self.center_box.append(w)
        
        for mod in self.modules_right:
            w = self._create_module(mod)
            if w:
                self.right_box.append(w)
        
        main.append(self.left_box)
        main.append(self.center_box)
        main.append(self.right_box)
        
        self.set_child(main)
    
    def _create_module(self, name: str) -> Optional[Gtk.Widget]:
        """Create a module widget by name"""
        
        # Taskbar modules - create container
        if name in ["custom/taskbar", "wlr/taskbar", "hyprland/taskbar"]:
            return self._mod_taskbar()
        
        # Custom modules
        if name == "custom/music":
            return self._mod_music()
        
        if name == "custom/notification":
            return self._mod_notification()
        
        # Hyprland modules
        if name == "hyprland/workspaces":
            return self._mod_workspaces()
        
        if name == "hyprland/window":
            return self._mod_window_title()
        
        # Clock module
        if name == "clock":
            return self._mod_clock()
        
        # Skip known Waybar modules we don't implement yet
        skip_modules = [
            "pulseaudio", "cpu", "memory", "temperature", 
            "network", "bluetooth", "custom/pacman", 
            "custom/endpoint", "custom/expand"
        ]
        if name in skip_modules:
            return None
        
        # Fallback - create empty placeholder with CSS class
        # box = Gtk.Box()
        # box.add_css_class(name.replace("/", "-"))
        # return box
        return None
    
    def _mod_taskbar(self) -> Gtk.Widget:
        """
        Create embedded taskbar container.
        Uses built-in TaskbarItem class with shared WindowTracker.
        """
        self.taskbar_container = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=2)
        self.taskbar_container.add_css_class("taskbar")
        self.taskbar_container.set_valign(Gtk.Align.CENTER)
        
        print(f"[ZenPyBar] ✅ Embedded taskbar created (position: {self.taskbar_position})")
        return self.taskbar_container
    
    def _mod_workspaces(self) -> Gtk.Widget:
        """Create workspaces module"""
        self.ws_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        self.ws_box.add_css_class("workspaces")
        self.ws_btns = {}
        
        for i in range(1, self.persistent_ws + 1):
            btn = Gtk.Button()
            btn.add_css_class("workspace-btn")
            btn.set_child(Gtk.Label(label=str(i)))
            btn.connect("clicked", lambda b, n=i: subprocess.Popen(
                ['hyprctl', 'dispatch', 'workspace', str(n)],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL))
            self.ws_btns[i] = btn
            self.ws_box.append(btn)
        
        return self.ws_box
    
    def _mod_clock(self) -> Gtk.Widget:
        """Create clock module"""
        box = Gtk.Box()
        box.add_css_class("clock")
        self.clock_label = Gtk.Label()
        box.append(self.clock_label)
        return box
    
    def _mod_music(self) -> Gtk.Widget:
        """Create music module"""
        box = Gtk.Box()
        box.add_css_class("music")
        self.music_label = Gtk.Label(label="󰎈 Music")
        box.append(self.music_label)
        return box
    
    def _mod_notification(self) -> Gtk.Widget:
        """Create notification module"""
        box = Gtk.Box()
        box.add_css_class("notification")
        box.append(Gtk.Label(label="󰂜"))
        return box
    
    def _mod_window_title(self) -> Gtk.Widget:
        """Create window title module"""
        box = Gtk.Box()
        box.add_css_class("window-title")
        self.window_title_label = Gtk.Label(label="")
        box.append(self.window_title_label)
        return box
    
    # ═══════════════════════════════════════════════════════════════════════════
    # EMBEDDED TASKBAR - SHARED TRACKER (NO DUPLICATES!)
    # ═══════════════════════════════════════════════════════════════════════════
    
    def _init_embedded_taskbar(self):
        """Initialize embedded taskbar with SHARED tracker"""
        config_dir = Path.home() / ".config/hypr-control-center"
        
        # Pinned manager (shared via singleton)
        self.pinned_manager = get_pinned_manager(config_dir)
        self.pinned_manager.on_change(lambda: GLib.idle_add(self._rebuild_taskbar))
        
        # CRITICAL: Use class-level shared tracker to prevent duplicates!
        if not ZenPyBar._tracker_initialized:
            print("[ZenPyBar] Initializing SHARED window tracker...")
            
            ZenPyBar._shared_tracker = WindowTracker()
            
            # Start tracker thread ONCE for all bars
            def run_tracker():
                loop = asyncio.new_event_loop()
                asyncio.set_event_loop(loop)
                ZenPyBar._shared_async_loop = loop
                try:
                    loop.run_until_complete(ZenPyBar._shared_tracker.start())
                except Exception as e:
                    print(f"[ZenPyBar] Tracker error: {e}")
            
            thread = threading.Thread(target=run_tracker, daemon=True)
            thread.start()
            
            ZenPyBar._tracker_initialized = True
            print("[ZenPyBar] ✅ Shared window tracker started")
        
        # Each bar references the SAME shared tracker
        ZenPyBar._shared_tracker.on_change(lambda: GLib.idle_add(self._update_taskbar))
        
        # Build initial taskbar
        GLib.idle_add(self._rebuild_taskbar)
        GLib.timeout_add(800, self._rebuild_taskbar)  # Rebuild after tracker loads
        
        print(f"[ZenPyBar] ✅ Embedded taskbar initialized for {self.monitor_name}")
    
    def _rebuild_taskbar(self) -> bool:
        """Rebuild entire taskbar"""
        if not self.taskbar_container:
            print("[ZenPyBar] ⚠️ No taskbar container!")
            return False
        
        # Clear existing items
        self.taskbar_items.clear()
        while (child := self.taskbar_container.get_first_child()):
            self.taskbar_container.remove(child)
        
        if not ZenPyBar._shared_tracker:
            print("[ZenPyBar] ⚠️ No shared tracker!")
            return False
        
        # Get pinned apps and running windows
        pinned_apps = self.pinned_manager.get_pinned_apps() if self.pinned_manager else []
        running_groups = {g.wm_class.lower(): g for g in ZenPyBar._shared_tracker.get_app_groups()}
        
        print(f"[ZenPyBar] Rebuilding taskbar: {len(pinned_apps)} pinned, {len(running_groups)} running")
        
        # Add pinned apps first
        for pinned in pinned_apps:
            app_group = None
            # Match by wm_class or app_id
            if pinned.wm_class and pinned.wm_class.lower() in running_groups:
                app_group = running_groups[pinned.wm_class.lower()]
            elif pinned.app_id.lower() in running_groups:
                app_group = running_groups[pinned.app_id.lower()]
            
            item = TaskbarItem(self, pinned.app_id, pinned_app=pinned, app_group=app_group)
            self.taskbar_items[pinned.app_id] = item
            self.taskbar_container.append(item)
        
        # Build set of pinned classes for exclusion
        pinned_classes = set()
        for p in pinned_apps:
            if p.wm_class:
                pinned_classes.add(p.wm_class.lower())
            pinned_classes.add(p.app_id.lower())
        
        # Add non-pinned running apps
        for wm_class, group in running_groups.items():
            if wm_class not in pinned_classes and group.wm_class.lower() not in pinned_classes:
                item = TaskbarItem(self, wm_class, app_group=group)
                self.taskbar_items[wm_class] = item
                self.taskbar_container.append(item)
        
        print(f"[ZenPyBar] Taskbar rebuilt: {len(self.taskbar_items)} items")
        return False
    
    def _update_taskbar(self) -> bool:
        """Update taskbar state (focus changes, window counts)"""
        if not ZenPyBar._shared_tracker:
            return False
        
        running_groups = {g.wm_class.lower(): g for g in ZenPyBar._shared_tracker.get_app_groups()}
        
        for app_id, item in list(self.taskbar_items.items()):
            wm_class = item._get_wm_class().lower()
            app_group = running_groups.get(app_id.lower()) or running_groups.get(wm_class)
            item.update(app_group)
        
        return False
    
    # ═══════════════════════════════════════════════════════════════════════════
    # TASKBAR ACTIONS
    # ═══════════════════════════════════════════════════════════════════════════
    
    def focus_window(self, address: str):
        """Focus a window by address"""
        if ZenPyBar._shared_async_loop and ZenPyBar._shared_tracker:
            asyncio.run_coroutine_threadsafe(
                ZenPyBar._shared_tracker.focus_window(address),
                ZenPyBar._shared_async_loop
            )
    
    def close_app(self, wm_class: str):
        """Close all windows of an app"""
        if ZenPyBar._shared_async_loop and ZenPyBar._shared_tracker:
            asyncio.run_coroutine_threadsafe(
                ZenPyBar._shared_tracker.close_app(wm_class),
                ZenPyBar._shared_async_loop
            )
    
    def launch_app(self, app_id: str):
        """Launch an app by app_id"""
        if self.pinned_manager:
            self.pinned_manager.launch_app(app_id)
    
    def pin_app(self, app_id: str):
        """Pin app to taskbar"""
        if self.pinned_manager:
            self.pinned_manager.pin_app(app_id)
    
    def unpin_app(self, app_id: str):
        """Unpin app from taskbar"""
        if self.pinned_manager:
            self.pinned_manager.unpin_app(app_id)
    
    # ═══════════════════════════════════════════════════════════════════════════
    # UPDATE TIMERS
    # ═══════════════════════════════════════════════════════════════════════════
    
    def _update_workspaces(self) -> bool:
        """Update workspace buttons"""
        if not hasattr(self, 'ws_btns'):
            return True
        
        try:
            result = subprocess.run(['hyprctl', '-j', 'activeworkspace'],
                                    capture_output=True, text=True, timeout=1)
            active = 1
            if result.returncode == 0:
                active = json.loads(result.stdout).get('id', 1)
            
            result = subprocess.run(['hyprctl', '-j', 'workspaces'],
                                    capture_output=True, text=True, timeout=1)
            occupied = set()
            if result.returncode == 0:
                for ws in json.loads(result.stdout):
                    if ws.get('windows', 0) > 0:
                        occupied.add(ws.get('id', 0))
            
            for ws_id, btn in self.ws_btns.items():
                btn.remove_css_class("active")
                btn.remove_css_class("occupied")
                if ws_id == active:
                    btn.add_css_class("active")
                elif ws_id in occupied:
                    btn.add_css_class("occupied")
        except Exception as e:
            pass
        
        return True
    
    def _update_clock(self) -> bool:
        """Update clock label"""
        if hasattr(self, 'clock_label'):
            now = datetime.datetime.now()
            self.clock_label.set_label(f" {now.strftime('%I:%M:%S %p')}")
        return True
    
    def _update_music(self) -> bool:
        """Update music status"""
        if hasattr(self, 'music_label'):
            try:
                result = subprocess.run(['playerctl', 'metadata', '--format', '{{artist}} - {{title}}'],
                                        capture_output=True, text=True, timeout=1)
                if result.returncode == 0 and result.stdout.strip():
                    text = result.stdout.strip()
                    if len(text) > 35:
                        text = text[:32] + "..."
                    self.music_label.set_label(f"󰎈 {text}")
                else:
                    self.music_label.set_label("󰎈 No music")
            except Exception:
                self.music_label.set_label("󰎈 No music")
        return True
    
    def cleanup(self):
        """Cleanup on shutdown"""
        if ZenPyBar._shared_tracker:
            ZenPyBar._shared_tracker.stop()
        if ZenPyBar._shared_async_loop:
            ZenPyBar._shared_async_loop.call_soon_threadsafe(ZenPyBar._shared_async_loop.stop)


# ═══════════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════════

def main():
    import os
    
    print("""
╔══════════════════════════════════════════════════════════╗
║       ZenPyBar v1.1 - Embedded Taskbar with Position     ║
║              NO DUPLICATES - Shared Tracker              ║
╚══════════════════════════════════════════════════════════╝
""")
    
    # Check LD_PRELOAD
    if 'LD_PRELOAD' not in os.environ or 'libgtk4-layer-shell.so' not in os.environ.get('LD_PRELOAD', ''):
        print("⚠️  WARNING: LD_PRELOAD not set!")
        print("   Run: ./run.sh")
        print()
    
    # Load config and theme ONCE
    config = load_waybar_config()
    theme = load_theme()
    
    print(f"[ZenPyBar] Theme: bg0={theme.bg0}, blue={theme.blue}")
    print(f"[ZenPyBar] Modules left: {config.get('modules-left', [])}")
    print(f"[ZenPyBar] Modules center: {config.get('modules-center', [])}")
    print(f"[ZenPyBar] Modules right: {config.get('modules-right', [])}")
    
    app = Gtk.Application(application_id="com.hyprland.zenpybar")
    bars = []
    
    def on_activate(app):
        # Get monitors from Hyprland
        try:
            result = subprocess.run(['hyprctl', '-j', 'monitors'],
                                    capture_output=True, text=True, timeout=1)
            monitors = json.loads(result.stdout) if result.returncode == 0 else []
        except Exception:
            monitors = []
        
        if not monitors:
            # No monitors detected, create single bar
            print("[ZenPyBar] No monitors detected, creating single bar")
            bar = ZenPyBar(config=config, theme=theme)
            bar.set_application(app)
            bar.present()
            bars.append(bar)
        else:
            # Create one bar per monitor
            for mon in monitors:
                name = mon.get('name')
                print(f"[ZenPyBar] Creating bar for monitor: {name}")
                bar = ZenPyBar(monitor_name=name, config=config, theme=theme)
                bar.set_application(app)
                bar.present()
                bars.append(bar)
        
        print()
        print("[ZenPyBar] ✅ Ready!")
        print("[ZenPyBar] All bars share ONE window tracker (no duplicates!)")
    
    def on_shutdown(app):
        print("[ZenPyBar] Shutting down...")
        for bar in bars:
            bar.cleanup()
    
    app.connect("activate", on_activate)
    app.connect("shutdown", on_shutdown)
    
    try:
        app.run(None)
    except KeyboardInterrupt:
        print("\n[ZenPyBar] Interrupted")
        for bar in bars:
            bar.cleanup()


if __name__ == "__main__":
    main()