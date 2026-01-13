#!/usr/bin/env python3
"""
ZenPyBar v2.0 - Complete Waybar Replacement
============================================

IMPORTANT: Must be run with LD_PRELOAD for Layer Shell to work!
Usage: LD_PRELOAD=/usr/lib/libgtk4-layer-shell.so python3 bar.py
OR: ./run.sh (recommended)

Full GTK4 bar with integrated taskbar using WindowTracker.
Reads from synced zenpybar.json (run config_sync.py first).

Features:
- Real-time window tracking
- Fast config loading
- Proper icons with fallbacks
- Click handlers for taskbar items
- Context menus
- Multi-monitor support
"""
import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Gtk4LayerShell', '1.0')
from gi.repository import Gtk, Gdk, Gtk4LayerShell, GLib

import subprocess
import json
import datetime
import asyncio
import threading
from pathlib import Path
from typing import Dict, List, Optional

# ═══════════════════════════════════════════════════════════════════════════════
# IMPORTS - Panel Modules
# ═══════════════════════════════════════════════════════════════════════════════

import sys
_panel_dir = Path.home() / ".config/hypr-control-center/src/panel"
if _panel_dir.exists() and str(_panel_dir) not in sys.path:
    sys.path.insert(0, str(_panel_dir))

HAS_PANEL_MODULES = False
try:
    from window_tracker import WindowTracker, AppGroup
    from pinned_manager import PinnedManager, PinnedApp, get_pinned_manager
    from icon_resolver import get_resolver, get_nerd_icon
    HAS_PANEL_MODULES = True
    print("[ZenPyBar] ✅ Panel modules loaded")
except ImportError as e:
    print(f"[ZenPyBar] ⚠️ Panel modules not available: {e}")


# ═══════════════════════════════════════════════════════════════════════════════
# CONFIG
# ═══════════════════════════════════════════════════════════════════════════════

ZENPYBAR_PREFS = Path.home() / ".config/hypr-control-center/preferences/zenpybar.json"


def load_config() -> dict:
    """Load cached ZenPyBar config"""
    if ZENPYBAR_PREFS.exists():
        try:
            with open(ZENPYBAR_PREFS, 'r') as f:
                return json.load(f)
        except Exception as e:
            print(f"[ZenPyBar] ⚠️ Config load error: {e}")
    
    return {
        "height": 40,
        "position": "bottom",
        "margin_top": 4,
        "margin_bottom": 3,
        "margin_left": 0,
        "margin_right": 0,
        "modules_left": ["custom/music", "hyprland/taskbar"],
        "modules_center": ["hyprland/workspaces", "hyprland/window"],
        "modules_right": ["custom/notification", "clock"],
        "module_configs": {},
        "theme": {
            "bg0": "#1a1b26",
            "bg1": "#16161e",
            "bg2": "#24283b",
            "bg3": "#414868",
            "fg": "#c0caf5",
            "blue": "#7aa2f7",
            "purple": "#bb9af7",
            "green": "#9ece6a",
            "red": "#f7768e",
        }
    }


def hex_to_rgba(hex_color: str, alpha: float) -> str:
    """Convert hex to rgba() string"""
    hex_color = hex_color.lstrip('#')
    r = int(hex_color[0:2], 16)
    g = int(hex_color[2:4], 16)
    b = int(hex_color[4:6], 16)
    return f"rgba({r}, {g}, {b}, {alpha})"


# ═══════════════════════════════════════════════════════════════════════════════
# TASKBAR ITEM - Full Featured
# ═══════════════════════════════════════════════════════════════════════════════

class TaskbarItem(Gtk.Button):
    """Taskbar button with full functionality"""
    
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
        """Build item UI"""
        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        box.set_valign(Gtk.Align.CENTER)
        
        # Get icon
        if HAS_PANEL_MODULES:
            resolver = get_resolver()
            wm_class = self._get_wm_class()
            self.icon_widget = resolver.create_icon_image(wm_class, size=22, use_nerd_fallback=True)
        else:
            # Fallback: use Nerd Font label
            icon = self._get_nerd_icon(self._get_wm_class())
            self.icon_widget = Gtk.Label(label=icon)
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
    
    def _get_nerd_icon(self, wm_class: str) -> str:
        """Fallback Nerd Font icons"""
        icons = {
            'firefox': '󰈹', 'chrome': '󰊯', 'brave': '󰖟',
            'kitty': '󰆍', 'alacritty': '󰆍',
            'code': '󰨞', 'vscode': '󰨞',
            'thunar': '󰝰', 'nautilus': '󰝰',
            'spotify': '󰓇', 'discord': '󰙯',
            'steam': '󰓓', 'obsidian': '󰎚',
        }
        return icons.get(wm_class.lower(), '󰣆')
    
    def _update_state(self):
        """Update CSS classes"""
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
        """Set tooltip"""
        name = self.pinned_app.name if self.pinned_app else self._get_wm_class()
        if self.app_group and self.app_group.window_count > 1:
            name += f" ({self.app_group.window_count})"
        self.set_tooltip_text(name)
    
    def _setup_clicks(self):
        """Setup click handlers"""
        # Left click
        self.connect("clicked", self._on_left_click)
        
        # Middle click - close
        middle = Gtk.GestureClick.new()
        middle.set_button(2)
        middle.connect("pressed", self._on_middle_click)
        self.add_controller(middle)
        
        # Right click - context menu
        right = Gtk.GestureClick.new()
        right.set_button(3)
        right.connect("pressed", self._on_right_click)
        self.add_controller(right)
    
    def _on_left_click(self, btn):
        """Focus or launch"""
        if self.is_running and self.app_group:
            if self.app_group.window_count == 1:
                window = self.app_group.most_recent_window
                if window:
                    self.bar.focus_window(window.address)
            else:
                self._show_window_list()
        elif self.is_pinned:
            self.bar.launch_app(self.app_id)
    
    def _on_middle_click(self, gesture, n, x, y):
        """Close all windows"""
        if self.is_running and self.app_group:
            self.bar.close_app(self.app_group.wm_class)
    
    def _on_right_click(self, gesture, n, x, y):
        """Show context menu"""
        self._show_context_menu()
    
    def _show_window_list(self):
        """Show window list popover"""
        if not self.app_group:
            return
        
        popover = Gtk.Popover()
        popover.set_parent(self)
        
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        box.set_margin_top(8)
        box.set_margin_bottom(8)
        box.set_margin_start(8)
        box.set_margin_end(8)
        
        for window in self.app_group.windows.values():
            row = Gtk.Button()
            
            row_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
            
            if window.is_focused:
                indicator = Gtk.Label(label="●")
                indicator.add_css_class("focus-indicator")
                row_box.append(indicator)
            
            title = Gtk.Label(label=window.title[:40] if window.title else "Untitled")
            title.set_xalign(0)
            title.set_hexpand(True)
            row_box.append(title)
            
            close_btn = Gtk.Button(label="󰅖")
            close_btn.add_css_class("flat")
            close_btn.connect("clicked", lambda b, a=window.address: self._close_window(a, popover))
            row_box.append(close_btn)
            
            row.set_child(row_box)
            row.connect("clicked", lambda b, a=window.address: self._focus_window(a, popover))
            box.append(row)
        
        popover.set_child(box)
        popover.popup()
    
    def _show_context_menu(self):
        """Show context menu"""
        popover = Gtk.Popover()
        popover.set_parent(self)
        
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        box.set_margin_top(6)
        box.set_margin_bottom(6)
        box.set_margin_start(6)
        box.set_margin_end(6)
        
        if self.is_pinned:
            btn = Gtk.Button(label="󰤃  Unpin")
            btn.connect("clicked", lambda b: self._unpin(popover))
        else:
            btn = Gtk.Button(label="󰤱  Pin")
            btn.connect("clicked", lambda b: self._pin(popover))
        box.append(btn)
        
        if self.is_running:
            close = Gtk.Button(label="󰅖  Close all")
            close.connect("clicked", lambda b: self._close_all(popover))
            box.append(close)
        
        new = Gtk.Button(label="󰐕  New window")
        new.connect("clicked", lambda b: self._launch(popover))
        box.append(new)
        
        popover.set_child(box)
        popover.popup()
    
    def _focus_window(self, address: str, popover):
        popover.popdown()
        self.bar.focus_window(address)
    
    def _close_window(self, address: str, popover):
        self.bar.close_window(address)
    
    def _close_all(self, popover):
        popover.popdown()
        self.bar.close_app(self.app_group.wm_class)
    
    def _pin(self, popover):
        popover.popdown()
        self.bar.pin_app(self._get_wm_class())
    
    def _unpin(self, popover):
        popover.popdown()
        self.bar.unpin_app(self.app_id)
    
    def _launch(self, popover):
        popover.popdown()
        self.bar.launch_app(self._get_wm_class())
    
    def update(self, app_group=None):
        """Update state"""
        self.app_group = app_group
        self.is_running = app_group is not None and app_group.window_count > 0
        self.is_focused = app_group.has_focus if app_group else False
        self._update_state()
        self._update_tooltip()


# ═══════════════════════════════════════════════════════════════════════════════
# MAIN BAR
# ═══════════════════════════════════════════════════════════════════════════════

class ZenPyBar(Gtk.Window):
    """ZenPyBar v2.0 - Full Waybar replacement"""
    
    def __init__(self, monitor_name: str = None, monitor_info: dict = None, config: dict = None):
        super().__init__()
        
        self.monitor_name = monitor_name
        self.monitor_info = monitor_info or {}
        self.config = config or load_config()
        self.theme = self.config.get('theme', {})
        
        # Bar settings
        self.height = self.config.get('height', 40)
        self.position = self.config.get('position', 'bottom')
        self.margin_top = self.config.get('margin_top', 4)
        self.margin_bottom = self.config.get('margin_bottom', 3)
        
        self.modules_left = self.config.get('modules_left', [])
        self.modules_center = self.config.get('modules_center', [])
        self.modules_right = self.config.get('modules_right', [])
        self.module_configs = self.config.get('module_configs', {})
        
        self.set_title(f"zenpybar-{monitor_name}" if monitor_name else "zenpybar")
        self.set_decorated(False)
        
        # Taskbar state
        self.taskbar_items: Dict[str, TaskbarItem] = {}
        self.tracker: Optional[WindowTracker] = None
        self.pinned_manager: Optional[PinnedManager] = None
        self._async_loop = None
        self._tracker_thread = None
        
        # Setup - ORDER MATTERS!
        self._setup_layer_shell()  # FIRST!
        self._apply_css()
        self._build_ui()
        
        # Start updates
        GLib.timeout_add(100, self._update_workspaces)
        GLib.timeout_add(1000, self._update_clock)
        GLib.timeout_add(2000, self._update_music)
        GLib.timeout_add(500, self._update_window_title)
        
        # Auto-launch panel_widget.py if taskbar modules detected
        self._panel_process = None
        taskbar_triggers = ['hyprland/taskbar', 'custom/panel', 'hyprland/window']
        has_taskbar = any(m in taskbar_triggers for m in self.modules_left + self.modules_center + self.modules_right)
        
        if has_taskbar:
            self._launch_panel_widget()
    
    def _get_color(self, name: str, default: str = "#ffffff") -> str:
        return self.theme.get(name, default)
    
    def _setup_layer_shell(self):
        """Setup GTK4 Layer Shell - CRITICAL: Must be called BEFORE window is realized!"""
        print(f"[ZenPyBar] Setting up Layer Shell for {self.monitor_name}...")
        
        # Initialize Layer Shell for this window
        Gtk4LayerShell.init_for_window(self)
        
        # Set layer to TOP (same as Waybar)
        Gtk4LayerShell.set_layer(self, Gtk4LayerShell.Layer.TOP)
        Gtk4LayerShell.set_namespace(self, f"zenpybar-{self.monitor_name}" if self.monitor_name else "zenpybar")
        
        # Keyboard mode - ON_DEMAND for popups/menus
        Gtk4LayerShell.set_keyboard_mode(self, Gtk4LayerShell.KeyboardMode.ON_DEMAND)
        
        # Set monitor if specified
        if self.monitor_name:
            display = self.get_display()
            monitors = display.get_monitors()
            for i in range(monitors.get_n_items()):
                mon = monitors.get_item(i)
                if mon.get_connector() == self.monitor_name:
                    Gtk4LayerShell.set_monitor(self, mon)
                    print(f"[ZenPyBar] Assigned to monitor: {self.monitor_name}")
                    break
        
        # Anchor left and right (full width)
        Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.LEFT, True)
        Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.RIGHT, True)
        
        # Anchor top or bottom based on config
        if self.position == "bottom":
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.BOTTOM, True)
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.TOP, False)
        else:
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.TOP, True)
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.BOTTOM, False)
        
        # Set margins
        Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.TOP, self.margin_top)
        Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.BOTTOM, self.margin_bottom)
        
        # Set exclusive zone (pushes windows away)
        Gtk4LayerShell.set_exclusive_zone(self, self.height + self.margin_top + self.margin_bottom)
        
        # Connect realize signal
        self.connect("realize", self._on_realize)
        
        print(f"[ZenPyBar] ✅ Layer Shell configured: {self.position}, height={self.height}")
    
    def _on_realize(self, widget):
        """Called when window is realized"""
        self.set_can_focus(True)
        self.set_focusable(True)
        print(f"[ZenPyBar] ✅ Window realized on {self.monitor_name}")
    
    def _apply_css(self):
        """Apply theme CSS"""
        bg0 = self._get_color('bg0', '#1a1b26')
        bg1 = self._get_color('bg1', '#16161e')
        bg2 = self._get_color('bg2', '#24283b')
        fg = self._get_color('fg', '#c0caf5')
        blue = self._get_color('blue', '#7aa2f7')
        purple = self._get_color('purple', '#bb9af7')
        red = self._get_color('red', '#f7768e')
        
        bg0_92 = hex_to_rgba(bg0, 0.92)
        bg0_90 = hex_to_rgba(bg0, 0.90)
        bg0_40 = hex_to_rgba(bg0, 0.40)
        
        css = Gtk.CssProvider()
        css.load_from_string(f'''
window, window.background, .background {{
    background-color: {bg0_92};
}}

label {{
    color: {fg};
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
    border: 1px solid {bg1};
}}

.workspace-btn {{
    min-width: 30px;
    min-height: 30px;
    padding: 0 6px;
    margin: 0 3px;
    border-radius: 16px;
    background-color: {bg1};
    border: none;
}}

.workspace-btn label {{ color: transparent; }}

.workspace-btn.active {{
    background-color: {blue};
    min-width: 50px;
}}

.workspace-btn.active label {{ color: {bg0}; }}

.workspace-btn.occupied {{
    background-color: {bg2};
}}

.workspace-btn:hover {{
    background-color: {purple};
}}

/* Taskbar */
.taskbar {{
    background-color: {bg0_90};
    padding: 4px 8px;
    margin: 0 0 0 12px;
    border-radius: 45px;
    border: 1px solid {bg1};
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
.taskbar-item.running {{ 
    background-color: {bg2};
    opacity: 1;
}}
.taskbar-item.focused {{ 
    background-color: {blue};
    opacity: 1;
}}

.taskbar-item:hover {{ background-color: {purple}; }}

.taskbar-icon {{
    min-width: 22px;
    min-height: 22px;
}}

.nerd-icon {{
    font-size: 18px;
    color: {fg};
}}

.taskbar-item.focused .nerd-icon {{ color: {bg0}; }}

/* Clock */
.clock {{
    background-color: {bg0_90};
    padding: 2px 15px;
    margin: 0 12px;
    border-radius: 45px;
    border: 1px solid {bg1};
}}

.clock label {{ color: {blue}; }}

.clock-date {{
    font-size: 11px;
    color: {fg};
}}

.clock-time {{
    font-size: 13px;
    color: {blue};
}}

/* Music */
.music {{
    background-color: {bg0_90};
    padding: 0 15px;
    margin: 0 0 0 12px;
    border-radius: 45px;
    border: 1px solid {bg1};
}}

.music label {{ color: {purple}; }}

.music-btn {{
    background: transparent;
    border: none;
    padding: 0;
}}

.music-btn:hover {{
    background-color: {bg2};
    border-radius: 20px;
}}

/* Window Title */
.window-title {{ padding: 0 10px; }}
.window-title label {{
    color: {fg};
    font-size: 13px;
}}

/* Notification */
.notification {{
    background-color: {bg0_90};
    padding: 0 5px;
    margin: 0 12px;
    border-radius: 45px;
    border: 1px solid {bg1};
}}

.notification-btn {{
    background: transparent;
    border: none;
    padding: 0 10px;
}}

.notification-btn:hover {{
    background-color: {bg2};
    border-radius: 20px;
}}

/* Popover */
popover {{
    background: {bg0};
    border: 1px solid {bg2};
    border-radius: 12px;
}}

popover button {{
    background: transparent;
    border: none;
    padding: 8px 12px;
    color: {fg};
}}

popover button:hover {{
    background: {bg2};
    border-radius: 8px;
}}

.focus-indicator {{ color: {blue}; }}

/* Tooltip */
tooltip {{
    background: {bg0};
    border: 1px solid {bg2};
    border-radius: 8px;
}}

tooltip label {{
    color: {fg};
    padding: 6px 10px;
}}
        ''')
        
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(), css,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION + 100
        )
    
    def _build_ui(self):
        """Build UI from config"""
        main = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        main.add_css_class("zenpy-bar")
        main.set_hexpand(True)
        
        left = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        left.set_halign(Gtk.Align.START)
        left.set_hexpand(True)
        
        center = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        center.set_halign(Gtk.Align.CENTER)
        
        right = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        right.set_halign(Gtk.Align.END)
        right.set_hexpand(True)
        
        for mod in self.modules_left:
            w = self._create_module(mod)
            if w: left.append(w)
        
        for mod in self.modules_center:
            w = self._create_module(mod)
            if w: center.append(w)
        
        for mod in self.modules_right:
            w = self._create_module(mod)
            if w: right.append(w)
        
        main.append(left)
        main.append(center)
        main.append(right)
        
        self.set_child(main)
    
    def _create_module(self, name: str) -> Optional[Gtk.Widget]:
        """Create module widget"""
        if name == 'hyprland/workspaces':
            return self._mod_workspaces()
        elif name == 'hyprland/window':
            # This triggers panel_widget.py - no widget needed here
            return None
        elif name in ['hyprland/taskbar', 'custom/panel']:
            # These trigger panel_widget.py - no widget needed here
            return None
        elif name == 'clock':
            return self._mod_clock()
        elif name == 'custom/music':
            return self._mod_music()
        elif name == 'custom/notification':
            return self._mod_notification()
        
        # Fallback for unsupported modules
        elif name in ['custom/taskbar', 'wlr/taskbar']:
            # These are Waybar's built-in taskbars, different from our system
            print(f"[ZenPyBar] ⚠️ Skipping Waybar taskbar: {name}")
            return None
        
        elif name.startswith('custom/'):
            # Skip custom modules that need exec scripts
            print(f"[ZenPyBar] ⚠️ Skipping custom module: {name} (not implemented)")
            return None
        
        elif name in ['pulseaudio', 'cpu', 'memory', 'temperature', 'network', 'bluetooth']:
            # Skip system modules (future implementation)
            print(f"[ZenPyBar] ⚠️ Skipping system module: {name} (not implemented)")
            return None
        
        elif name.startswith('group/'):
            # Groups should have been expanded already
            print(f"[ZenPyBar] ⚠️ Skipping group: {name} (should be expanded)")
            return None
        
        else:
            print(f"[ZenPyBar] ⚠️ Unknown module: {name}")
            return None
    
    def _mod_workspaces(self) -> Gtk.Widget:
        """Workspaces module"""
        self.ws_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        self.ws_box.add_css_class("workspaces")
        self.ws_btns = {}
        
        ws_config = self.module_configs.get('hyprland/workspaces', {})
        persistent_ws = ws_config.get('persistent_workspaces', {}).get('*', 5)
        
        for i in range(1, persistent_ws + 1):
            btn = Gtk.Button()
            btn.add_css_class("workspace-btn")
            btn.set_child(Gtk.Label(label=str(i)))
            btn.connect("clicked", lambda b, n=i: subprocess.Popen(
                ['hyprctl', 'dispatch', 'workspace', str(n)],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL))
            self.ws_btns[i] = btn
            self.ws_box.append(btn)
        
        return self.ws_box
    
    def _mod_window(self) -> Gtk.Widget:
        """Window title"""
        box = Gtk.Box()
        box.add_css_class("window-title")
        self.win_label = Gtk.Label(label="")
        box.append(self.win_label)
        return box
    
    def _mod_clock(self) -> Gtk.Widget:
        """Clock module"""
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        box.add_css_class("clock")
        box.set_valign(Gtk.Align.CENTER)
        
        clock_config = self.module_configs.get('clock', {})
        format_str = clock_config.get('format', ' {:%I:%M:%S %p}')
        
        if '\\n' in format_str or '\n' in format_str:
            self.clock_date_label = Gtk.Label()
            self.clock_date_label.add_css_class("clock-date")
            self.clock_time_label = Gtk.Label()
            self.clock_time_label.add_css_class("clock-time")
            box.append(self.clock_date_label)
            box.append(self.clock_time_label)
            self.clock_multiline = True
        else:
            self.clock_label = Gtk.Label()
            box.append(self.clock_label)
            self.clock_multiline = False
        
        self._update_clock()
        return box
    
    def _mod_music(self) -> Gtk.Widget:
        """Music module"""
        box = Gtk.Box()
        box.add_css_class("music")
        
        btn = Gtk.Button()
        btn.add_css_class("music-btn")
        self.music_label = Gtk.Label(label="󰎈 Music")
        btn.set_child(self.music_label)
        
        config = self.module_configs.get('custom/music', {})
        on_click = config.get('on_click', 'playerctl play-pause')
        btn.connect("clicked", lambda b: subprocess.Popen(
            on_click.split(), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL))
        
        box.append(btn)
        return box
    
    def _mod_notification(self) -> Gtk.Widget:
        """Notification module"""
        box = Gtk.Box()
        box.add_css_class("notification")
        
        btn = Gtk.Button()
        btn.add_css_class("notification-btn")
        
        config = self.module_configs.get('custom/notification', {})
        format_icons = config.get('format_icons', {})
        icon = format_icons.get('none', '󰂜')
        
        btn.set_child(Gtk.Label(label=icon))
        
        on_click = config.get('on_click', 'swaync-client -t -sw')
        btn.connect("clicked", lambda b: subprocess.Popen(
            on_click.split(), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL))
        
        # Right-click handler
        right = Gtk.GestureClick.new()
        right.set_button(3)
        on_click_right = config.get('on_click_right', 'swaync-client -d -sw')
        right.connect("pressed", lambda g, n, x, y: subprocess.Popen(
            on_click_right.split(), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL))
        btn.add_controller(right)
        
        box.append(btn)
        return box
    
    # ═══════════════════════════════════════════════════════════════════════════
    # TASKBAR INTEGRATION
    # ═══════════════════════════════════════════════════════════════════════════
    
    def _init_taskbar(self):
        """Initialize taskbar with WindowTracker"""
        if not HAS_PANEL_MODULES:
            print("[ZenPyBar] ⚠️ Panel modules not available, skipping taskbar")
            return
        
        config_dir = Path.home() / ".config/hypr-control-center"
        
        self.pinned_manager = get_pinned_manager(config_dir)
        self.pinned_manager.on_change(lambda: GLib.idle_add(self._rebuild_taskbar))
        
        self.tracker = WindowTracker()
        self.tracker.on_change(lambda: GLib.idle_add(self._update_taskbar))
        
        # Build initial UI
        GLib.idle_add(self._rebuild_taskbar)
        
        # Start tracker
        def run_tracker():
            self._async_loop = asyncio.new_event_loop()
            asyncio.set_event_loop(self._async_loop)
            try:
                self._async_loop.run_until_complete(self.tracker.start())
            except Exception as e:
                print(f"[ZenPyBar] Tracker error: {e}")
        
        self._tracker_thread = threading.Thread(target=run_tracker, daemon=True)
        self._tracker_thread.start()
        
        # Rebuild after tracker loads
        GLib.timeout_add(800, self._rebuild_taskbar)
        
        print("[ZenPyBar] ✅ Taskbar initialized")
    
    def _rebuild_taskbar(self) -> bool:
        """Full taskbar rebuild"""
        if not hasattr(self, 'taskbar_container'):
            return False
        
        self.taskbar_items.clear()
        while (child := self.taskbar_container.get_first_child()):
            self.taskbar_container.remove(child)
        
        pinned_apps = self.pinned_manager.get_pinned_apps() if self.pinned_manager else []
        running_groups = {g.wm_class.lower(): g for g in (self.tracker.get_app_groups() if self.tracker else [])}
        
        # Pinned apps
        for pinned in pinned_apps:
            app_group = None
            if pinned.wm_class and pinned.wm_class.lower() in running_groups:
                app_group = running_groups[pinned.wm_class.lower()]
            elif pinned.app_id.lower() in running_groups:
                app_group = running_groups[pinned.app_id.lower()]
            
            item = TaskbarItem(self, pinned.app_id, pinned_app=pinned, app_group=app_group)
            self.taskbar_items[pinned.app_id] = item
            self.taskbar_container.append(item)
        
        # Non-pinned running
        pinned_classes = set()
        for p in pinned_apps:
            if p.wm_class:
                pinned_classes.add(p.wm_class.lower())
            pinned_classes.add(p.app_id.lower())
        
        for wm_class, group in running_groups.items():
            if wm_class not in pinned_classes and group.wm_class.lower() not in pinned_classes:
                item = TaskbarItem(self, wm_class, app_group=group)
                self.taskbar_items[wm_class] = item
                self.taskbar_container.append(item)
        
        return False
    
    def _update_taskbar(self) -> bool:
        """Update taskbar state"""
        if not self.tracker:
            return False
        
        running_groups = {g.wm_class.lower(): g for g in self.tracker.get_app_groups()}
        
        # Update existing items
        for app_id, item in list(self.taskbar_items.items()):
            wm_class = item._get_wm_class().lower()
            app_group = running_groups.get(app_id.lower()) or running_groups.get(wm_class)
            item.update(app_group)
        
        return False
    
    # ═══════════════════════════════════════════════════════════════════════════
    # TASKBAR ACTIONS
    # ═══════════════════════════════════════════════════════════════════════════
    
    def focus_window(self, address: str):
        if self._async_loop and self.tracker:
            asyncio.run_coroutine_threadsafe(
                self.tracker.focus_window(address),
                self._async_loop
            )
    
    def close_window(self, address: str):
        if self._async_loop and self.tracker:
            asyncio.run_coroutine_threadsafe(
                self.tracker.close_window(address),
                self._async_loop
            )
    
    def close_app(self, wm_class: str):
        if self._async_loop and self.tracker:
            asyncio.run_coroutine_threadsafe(
                self.tracker.close_app(wm_class),
                self._async_loop
            )
    
    def launch_app(self, app_id: str):
        if self.pinned_manager:
            self.pinned_manager.launch_app(app_id)
    
    def pin_app(self, app_id: str):
        if self.pinned_manager:
            self.pinned_manager.pin_app(app_id)
    
    def unpin_app(self, app_id: str):
        if self.pinned_manager:
            self.pinned_manager.unpin_app(app_id)
    
    # ═══════════════════════════════════════════════════════════════════════════
    # UPDATES
    # ═══════════════════════════════════════════════════════════════════════════
    
    def _update_workspaces(self) -> bool:
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
        except:
            pass
        
        return True
    
    def _update_clock(self) -> bool:
        now = datetime.datetime.now()
        if hasattr(self, 'clock_multiline') and self.clock_multiline:
            if hasattr(self, 'clock_date_label'):
                self.clock_date_label.set_label(now.strftime(" %Y-%m-%d"))
            if hasattr(self, 'clock_time_label'):
                self.clock_time_label.set_label(now.strftime(" %I:%M:%S %p"))
        elif hasattr(self, 'clock_label'):
            self.clock_label.set_label(f" {now.strftime('%I:%M:%S %p')}")
        return True
    
    def _update_music(self) -> bool:
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
            except:
                self.music_label.set_label("󰎈 No music")
        return True
    
    def _update_window_title(self) -> bool:
        if hasattr(self, 'win_label'):
            try:
                result = subprocess.run(['hyprctl', '-j', 'activewindow'],
                                      capture_output=True, text=True, timeout=1)
                if result.returncode == 0:
                    data = json.loads(result.stdout)
                    title = data.get('title', '')
                    if len(title) > 50:
                        title = title[:47] + "..."
                    self.win_label.set_label(f"  {title}" if title else "")
            except:
                pass
        return True
    
    def cleanup(self):
        """Cleanup resources"""
        # Kill panel_widget.py if we spawned it
        if self._panel_process:
            print("[ZenPyBar] Stopping panel_widget.py...")
            try:
                self._panel_process.terminate()
                self._panel_process.wait(timeout=2)
            except:
                self._panel_process.kill()
        
        if self.tracker:
            self.tracker.stop()
        if self._async_loop:
            self._async_loop.call_soon_threadsafe(self._async_loop.stop)
    
    def _launch_panel_widget(self):
        """Auto-launch panel_widget.py for taskbar"""
        panel_script = Path.home() / ".config/hypr-control-center/src/panel/panel_widget.py"
        
        if not panel_script.exists():
            print(f"[ZenPyBar] ⚠️ panel_widget.py not found at {panel_script}")
            return
        
        print("[ZenPyBar] 🚀 Auto-launching panel_widget.py...")
        
        import os
        env = os.environ.copy()
        
        # Ensure LD_PRELOAD is set
        if 'LD_PRELOAD' in env:
            if 'libgtk4-layer-shell.so' not in env['LD_PRELOAD']:
                env['LD_PRELOAD'] += ':/usr/lib/libgtk4-layer-shell.so'
        else:
            env['LD_PRELOAD'] = '/usr/lib/libgtk4-layer-shell.so'
        
        try:
            self._panel_process = subprocess.Popen(
                ['python3', str(panel_script)],
                env=env,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
            print(f"[ZenPyBar] ✅ panel_widget.py started (PID: {self._panel_process.pid})")
        except Exception as e:
            print(f"[ZenPyBar] ❌ Failed to launch panel_widget.py: {e}")


# ═══════════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════════

def get_monitors() -> List[dict]:
    """Get monitors from hyprctl"""
    try:
        result = subprocess.run(['hyprctl', '-j', 'monitors'],
                              capture_output=True, text=True, timeout=1)
        if result.returncode == 0:
            return json.loads(result.stdout)
    except:
        pass
    return []


def main():
    print("""
╔══════════════════════════════════════════════════════════╗
║              ZenPyBar v2.0 - Full Featured               ║
║          REQUIRES: LD_PRELOAD for Layer Shell!           ║
╚══════════════════════════════════════════════════════════╝
""")
    
    # Check if LD_PRELOAD is set
    if 'LD_PRELOAD' not in os.environ or 'libgtk4-layer-shell.so' not in os.environ.get('LD_PRELOAD', ''):
        print("⚠️  WARNING: LD_PRELOAD not set!")
        print("   ZenPyBar requires: LD_PRELOAD=/usr/lib/libgtk4-layer-shell.so")
        print("   Run: ./run.sh (recommended)")
        print("   Or: LD_PRELOAD=/usr/lib/libgtk4-layer-shell.so python3 bar.py")
        print()
    
    if not ZENPYBAR_PREFS.exists():
        print("[ZenPyBar] ⚠️ No config found!")
        print("[ZenPyBar] Run: python3 config_sync.py --force")
        print("[ZenPyBar] Using defaults...")
    
    config = load_config()
    print(f"[ZenPyBar] Config loaded")
    print(f"[ZenPyBar] Position: {config.get('position')}, Height: {config.get('height')}px")
    print(f"[ZenPyBar] Modules Left: {config.get('modules_left', [])}")
    
    app = Gtk.Application(application_id="com.hyprland.zenpybar")
    bars = []
    
    def on_activate(app):
        monitors = get_monitors()
        
        if not monitors:
            bar = ZenPyBar(config=config)
            bar.set_application(app)
            bar.present()
            bars.append(bar)
        else:
            for mon in monitors:
                name = mon.get('name')
                print(f"[ZenPyBar] Creating bar for: {name}")
                bar = ZenPyBar(monitor_name=name, monitor_info=mon, config=config)
                bar.set_application(app)
                bar.present()
                bars.append(bar)
        
        print("[ZenPyBar] ✅ Ready!")
        print("[ZenPyBar] Check with: hyprctl layers | grep -A2 zenpybar")
    
    def on_shutdown(app):
        print("\n[ZenPyBar] Shutting down...")
        for bar in bars:
            bar.cleanup()
    
    app.connect("activate", on_activate)
    app.connect("shutdown", on_shutdown)
    
    try:
        app.run(None)
    except KeyboardInterrupt:
        print("\nShutting down...")
        for bar in bars:
            bar.cleanup()


if __name__ == "__main__":
    import os
    main()