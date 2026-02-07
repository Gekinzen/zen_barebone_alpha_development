#!/usr/bin/env python3
"""
═══════════════════════════════════════════════════════════════════════════════
Hyprland Dock Widget - Independent Desktop Dock
═══════════════════════════════════════════════════════════════════════════════
Version: 1.0.0
Author: Paul Zenpy (Gekinzen)

INDEPENDENT from panel_widget.py - this is a PERSISTENT dock bar:
- Sticks to screen edge like Waybar (exclusive zone = no window overlap)
- Supports top/bottom/left/right positioning
- Smart Waybar collision: if same edge as Waybar → stacks inside (closer to center)
- Visibility modes: always-show / autohide / hidden
- Customizable rounding, size, opacity, icon size
- Pinned apps + running app indicators
- Full theme sync from theming.py
- Daemon mode with SIGUSR1 toggle

Config: ~/.config/hypr-control-center/dock-config.json

Run:
  LD_PRELOAD=/usr/lib/libgtk4-layer-shell.so python3 dock_widget.py
  LD_PRELOAD=/usr/lib/libgtk4-layer-shell.so python3 dock_widget.py --daemon

Toggle (daemon):
  kill -USR1 $(cat /tmp/hypr-dock.pid)
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
import signal
import argparse
from pathlib import Path
from typing import Optional, Dict, List, Tuple
from dataclasses import dataclass, field
from enum import Enum, auto
import sys
import time

# ═══════════════════════════════════════════════════════════════════════════════
# GTK4 LAYER SHELL
# ═══════════════════════════════════════════════════════════════════════════════

try:
    gi.require_version('Gtk4LayerShell', '1.0')
    from gi.repository import Gtk4LayerShell
    HAS_LAYER_SHELL = True
    print("[Dock] ✅ GTK4 Layer Shell available")
except Exception:
    HAS_LAYER_SHELL = False
    print("[Dock] ⚠️ GTK4 Layer Shell not found!")

# Add shared module directories to path
# Modules live in: ~/.config/hypr-control-center/src/panel/
_dock_dir = Path(__file__).parent
_config_dir = Path.home() / ".config/hypr-control-center"
_panel_module_dir = _config_dir / "src" / "panel"

for p in [str(_dock_dir), str(_panel_module_dir), str(_config_dir / "src")]:
    if p not in sys.path:
        sys.path.insert(0, p)

print(f"[Dock] 📁 Module search: {_panel_module_dir}")

# Import shared modules from src/panel/
try:
    from hypr_ipc import HyprlandIPC, HyprEvent, HyprEventType, HyprWindow, hyprctl_json
    from window_tracker import WindowTracker, AppGroup
    from pinned_manager import PinnedManager, PinnedApp, get_pinned_manager
    from icon_resolver import get_resolver, get_nerd_icon
    HAS_MODULES = True
    print("[Dock] ✅ Shared modules loaded from src/panel/")
except ImportError as e:
    print(f"[Dock] ❌ Import error: {e}")
    print(f"[Dock] 💡 Expected modules at: {_panel_module_dir}")
    HAS_MODULES = False

# ═══════════════════════════════════════════════════════════════════════════════
# CONSTANTS & CONFIG
# ═══════════════════════════════════════════════════════════════════════════════

PID_FILE = Path("/tmp/hypr-dock.pid")
CONFIG_DIR = Path.home() / ".config/hypr-control-center"
DOCK_CONFIG_FILE = CONFIG_DIR / "dock-config.json"
DOCK_CSS_FILE = CONFIG_DIR / "assets" / "dock-widget.css"
ASSETS_DIR = CONFIG_DIR / "assets"


class DockPosition(Enum):
    BOTTOM = "bottom"
    TOP = "top"
    LEFT = "left"
    RIGHT = "right"


class DockVisibility(Enum):
    ALWAYS = "always"       # Always visible, exclusive zone (like Waybar)
    AUTOHIDE = "autohide"   # Hide when no hover, show on mouse edge
    HIDDEN = "hidden"       # Manually toggled via SIGUSR1 only


# Default dock configuration
DEFAULT_DOCK_CONFIG = {
    "position": "bottom",
    "visibility": "always",
    "icon_size": 48,
    "dock_padding": 8,
    "dock_margin": 8,
    "border_radius": 16,
    "opacity": 0.85,
    "autohide_delay_ms": 600,
    "autohide_show_delay_ms": 200,
    "edge_trigger_size": 2,       # px from screen edge to trigger autohide show
    "dock_thickness": 64,         # Height (horizontal) or width (vertical)
    "separator_enabled": True,
    "pinned_apps": [],            # Managed by PinnedManager
    "show_running_indicators": True,
    "centered": True,             # Center dock on its edge
    "stretch": False,             # Stretch full edge width
    "theme_sync": True,           # Auto-sync from theming.py
    # Spacing
    "item_spacing": 4,
    "item_padding": 6,
    # Waybar collision
    "waybar_collision": "stack",  # "stack" = position next to waybar, "ignore" = overlap
}


def load_dock_config() -> dict:
    """Load dock config from JSON, merge with defaults"""
    config = DEFAULT_DOCK_CONFIG.copy()
    if DOCK_CONFIG_FILE.exists():
        try:
            saved = json.loads(DOCK_CONFIG_FILE.read_text())
            config.update(saved)
            print(f"[Dock] 📄 Config loaded: {DOCK_CONFIG_FILE}")
        except Exception as e:
            print(f"[Dock] ⚠️ Config parse error: {e}")
    return config


def save_dock_config(config: dict):
    """Save dock config to JSON"""
    try:
        CONFIG_DIR.mkdir(parents=True, exist_ok=True)
        DOCK_CONFIG_FILE.write_text(json.dumps(config, indent=2))
        print(f"[Dock] 💾 Config saved: {DOCK_CONFIG_FILE}")
    except Exception as e:
        print(f"[Dock] ⚠️ Config save error: {e}")


# ═══════════════════════════════════════════════════════════════════════════════
# WAYBAR COLLISION DETECTOR
# ═══════════════════════════════════════════════════════════════════════════════

class WaybarDetector:
    """
    Detect Waybar position & dimensions to avoid collision.
    
    Rules:
    - If dock is on SAME edge as Waybar → dock stacks INSIDE (towards center)
      e.g., both bottom → dock sits above Waybar
      e.g., both top → dock sits below Waybar
    - If different edges → no adjustment needed
    """
    
    @staticmethod
    def get_waybar_info() -> dict:
        """Read Waybar config to determine position and dimensions"""
        info = {
            "position": "bottom",
            "height": 40,
            "margin_top": 0,
            "margin_bottom": 0,
            "margin_left": 0,
            "margin_right": 0,
            "found": False,
        }
        
        config_paths = [
            Path.home() / ".config/waybar/config.jsonc",
            Path.home() / ".config/waybar/config.json",
            Path.home() / ".config/waybar/config",
        ]
        
        for config_path in config_paths:
            if not config_path.exists():
                continue
            try:
                content = config_path.read_text()
                # Strip JSONC comments
                content = re.sub(r'//.*$', '', content, flags=re.MULTILINE)
                content = re.sub(r'/\*.*?\*/', '', content, flags=re.DOTALL)
                content = re.sub(r',\s*([}\]])', r'\1', content)
                raw = json.loads(content)
                
                # Handle array configs
                data = None
                if isinstance(raw, list):
                    for cfg in raw:
                        if isinstance(cfg, dict):
                            out = cfg.get("output", "")
                            if not out or out == "*" or "DP" in str(out):
                                data = cfg
                                break
                    if data is None and raw and isinstance(raw[0], dict):
                        data = raw[0]
                elif isinstance(raw, dict):
                    data = raw
                
                if not data:
                    continue
                
                info["position"] = data.get("position", "bottom")
                info["height"] = data.get("height", 40)
                info["margin_top"] = data.get("margin-top", 0)
                info["margin_bottom"] = data.get("margin-bottom", 0)
                info["margin_left"] = data.get("margin-left", 0)
                info["margin_right"] = data.get("margin-right", 0)
                info["found"] = True
                
                print(f"[Dock] 📊 Waybar: pos={info['position']}, h={info['height']}, "
                      f"mt={info['margin_top']}, mb={info['margin_bottom']}")
                break
            except Exception as e:
                print(f"[Dock] ⚠️ Waybar config parse error: {e}")
        
        return info
    
    @staticmethod
    def calculate_offset(dock_position: str, waybar_info: dict, dock_config: dict) -> int:
        """
        Calculate the margin offset needed to stack dock next to Waybar.
        
        Returns extra margin in px to add on the dock's edge.
        """
        if not waybar_info["found"]:
            return dock_config.get("dock_margin", 8)
        
        if dock_config.get("waybar_collision") == "ignore":
            return dock_config.get("dock_margin", 8)
        
        wb_pos = waybar_info["position"]
        gap = 4  # Gap between dock and Waybar
        base_margin = dock_config.get("dock_margin", 8)
        
        # Same edge → stack
        if dock_position == wb_pos:
            wb_height = waybar_info["height"]
            
            if dock_position == "bottom":
                wb_margin = waybar_info["margin_bottom"]
            elif dock_position == "top":
                wb_margin = waybar_info["margin_top"]
            elif dock_position == "left":
                wb_margin = waybar_info["margin_left"]
            elif dock_position == "right":
                wb_margin = waybar_info["margin_right"]
            else:
                wb_margin = 0
            
            offset = wb_height + wb_margin + gap
            print(f"[Dock] 📐 Same edge ({dock_position}): offset={offset}px "
                  f"(wb_h={wb_height} + wb_m={wb_margin} + gap={gap})")
            return offset
        
        # Different edge → just use base margin
        return base_margin


# ═══════════════════════════════════════════════════════════════════════════════
# DOCK ITEM
# ═══════════════════════════════════════════════════════════════════════════════

class DockItem(Gtk.Button):
    """Single dock item with icon, click handlers, and running indicator"""
    
    def __init__(self, dock: 'DockWidget', app_id: str,
                 pinned_app: Optional[PinnedApp] = None,
                 app_group: Optional[AppGroup] = None,
                 icon_size: int = 48):
        super().__init__()
        
        self.dock = dock
        self.app_id = app_id
        self.pinned_app = pinned_app
        self.app_group = app_group
        self.icon_size = icon_size
        
        self.add_css_class("dock-item")
        
        self.is_pinned = pinned_app is not None
        self.is_running = app_group is not None and app_group.window_count > 0
        self.is_focused = app_group.has_focus if app_group else False
        self.window_count = app_group.window_count if app_group else 0
        
        self._build_ui()
        self._update_state()
        self._setup_clicks()
    
    def _build_ui(self):
        """Build icon + running indicator"""
        overlay = Gtk.Overlay()
        
        # Icon
        resolver = get_resolver()
        wm_class = self._get_wm_class()
        
        icon_name = None
        if self.pinned_app and self.pinned_app.icon:
            icon_name = self.pinned_app.icon
        
        self.icon_widget = resolver.create_icon_image(
            icon_name or wm_class,
            size=self.icon_size,
            use_nerd_fallback=True
        )
        self.icon_widget.add_css_class("dock-icon")
        overlay.set_child(self.icon_widget)
        
        # Running indicator dot
        self.indicator = Gtk.Box()
        self.indicator.add_css_class("dock-indicator")
        self.indicator.set_halign(Gtk.Align.CENTER)
        self.indicator.set_valign(Gtk.Align.END)
        overlay.add_overlay(self.indicator)
        
        self.set_child(overlay)
        self._update_tooltip()
    
    def _get_wm_class(self) -> str:
        if self.app_group:
            return self.app_group.wm_class
        if self.pinned_app:
            return self.pinned_app.wm_class or self.pinned_app.app_id
        return self.app_id
    
    def _update_state(self):
        """Update CSS classes"""
        for cls in ["focused", "running", "not-running", "multi-window"]:
            self.remove_css_class(cls)
        
        if self.is_focused:
            self.add_css_class("focused")
        elif self.is_running:
            self.add_css_class("running")
        elif self.is_pinned:
            self.add_css_class("not-running")
        
        if self.window_count > 1:
            self.add_css_class("multi-window")
        
        # Indicator visibility
        self.indicator.set_visible(self.is_running)
    
    def _update_tooltip(self):
        name = ""
        if self.pinned_app:
            name = self.pinned_app.name or self.pinned_app.app_id
        elif self.app_group:
            name = self.app_group.wm_class
        else:
            name = self.app_id
        
        if self.window_count > 1:
            name += f" ({self.window_count} windows)"
        
        self.set_tooltip_text(name)
    
    def _setup_clicks(self):
        # Left click
        self.connect("clicked", self._on_left_click)
        
        # Middle click
        middle = Gtk.GestureClick.new()
        middle.set_button(2)
        middle.connect("pressed", self._on_middle_click)
        self.add_controller(middle)
        
        # Right click
        right = Gtk.GestureClick.new()
        right.set_button(3)
        right.connect("pressed", self._on_right_click)
        self.add_controller(right)
    
    def _on_left_click(self, btn):
        if self.is_running and self.app_group:
            if self.app_group.window_count == 1:
                window = self.app_group.most_recent_window
                if window:
                    self.dock.focus_window(window.address)
            else:
                self._show_window_list()
        elif self.is_pinned:
            self.dock.launch_app(self.app_id)
    
    def _on_middle_click(self, gesture, n_press, x, y):
        if self.is_running and self.app_group:
            self.dock.close_app(self.app_group.wm_class)
    
    def _on_right_click(self, gesture, n_press, x, y):
        self._show_context_menu()
    
    def _show_window_list(self):
        """Show window list popover"""
        if not self.app_group:
            return
        
        popover = Gtk.Popover()
        popover.set_parent(self)
        popover.add_css_class("dock-popover")
        
        if hasattr(self.dock, 'register_popover'):
            self.dock.register_popover(popover)
        
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        box.set_margin_top(8)
        box.set_margin_bottom(8)
        box.set_margin_start(8)
        box.set_margin_end(8)
        
        for window in self.app_group.windows.values():
            row = Gtk.Button()
            row.add_css_class("dock-window-item")
            
            row_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
            
            if window.is_focused:
                dot = Gtk.Label(label="●")
                dot.add_css_class("focus-dot")
                row_box.append(dot)
            
            title = Gtk.Label(label=(window.title[:35] if window.title else "Untitled"))
            title.set_xalign(0)
            title.set_hexpand(True)
            title.set_ellipsize(3)
            row_box.append(title)
            
            close_btn = Gtk.Button()
            close_btn.set_icon_name("window-close-symbolic")
            close_btn.add_css_class("flat")
            close_btn.add_css_class("close-btn")
            close_btn.connect("clicked", lambda b, addr=window.address: (
                self.dock.close_window(addr)
            ))
            row_box.append(close_btn)
            
            row.set_child(row_box)
            row.connect("clicked", lambda b, addr=window.address: (
                popover.popdown(),
                self.dock.focus_window(addr),
            ))
            box.append(row)
        
        popover.set_child(box)
        popover.popup()
    
    def _show_context_menu(self):
        """Show context menu"""
        popover = Gtk.Popover()
        popover.set_parent(self)
        popover.add_css_class("dock-popover")
        
        if hasattr(self.dock, 'register_popover'):
            self.dock.register_popover(popover)
        
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        box.set_margin_top(4)
        box.set_margin_bottom(4)
        box.set_margin_start(4)
        box.set_margin_end(4)
        
        # Pin/Unpin
        if self.is_pinned:
            btn = Gtk.Button(label="📍 Unpin")
            btn.add_css_class("flat")
            btn.connect("clicked", lambda b: (popover.popdown(), self.dock.unpin_app(self.app_id)))
            box.append(btn)
        else:
            btn = Gtk.Button(label="📌 Pin to Dock")
            btn.add_css_class("flat")
            btn.connect("clicked", lambda b: (popover.popdown(), self.dock.pin_app(self._get_wm_class())))
            box.append(btn)
        
        # New window
        new_btn = Gtk.Button(label="🆕 New Window")
        new_btn.add_css_class("flat")
        new_btn.connect("clicked", lambda b: (popover.popdown(), self.dock.launch_app(self._get_wm_class())))
        box.append(new_btn)
        
        # Close all
        if self.is_running:
            close_btn = Gtk.Button(label="❌ Close All")
            close_btn.add_css_class("flat")
            close_btn.connect("clicked", lambda b: (popover.popdown(), self.dock.close_app(self.app_group.wm_class)))
            box.append(close_btn)
        
        popover.set_child(box)
        popover.popup()
    
    def update(self, app_group: Optional[AppGroup] = None):
        """Update state from tracker"""
        self.app_group = app_group
        self.is_running = app_group is not None and app_group.window_count > 0
        self.is_focused = app_group.has_focus if app_group else False
        self.window_count = app_group.window_count if app_group else 0
        self._update_state()
        self._update_tooltip()


# ═══════════════════════════════════════════════════════════════════════════════
# DOCK WIDGET - MAIN CLASS
# ═══════════════════════════════════════════════════════════════════════════════

class DockWidget(Gtk.Window):
    """
    Independent Desktop Dock
    
    Key differences from panel_widget.py:
    1. Uses EXCLUSIVE ZONE → windows don't overlap (like Waybar)
    2. Persistent — always present on desktop (not popup)
    3. Supports autohide with edge trigger
    4. Stacks with Waybar if on same edge
    5. Independent config file (dock-config.json)
    """
    
    def __init__(self, daemon_mode: bool = False):
        super().__init__()
        
        self.daemon_mode = daemon_mode
        self.config = load_dock_config()
        self.set_title("hypr-dock")
        self.set_decorated(False)
        self.set_resizable(False)
        
        # Parse position
        self.position = DockPosition(self.config.get("position", "bottom"))
        self.visibility = DockVisibility(self.config.get("visibility", "always"))
        self.is_horizontal = self.position in (DockPosition.BOTTOM, DockPosition.TOP)
        
        # Waybar detection
        self.waybar_info = WaybarDetector.get_waybar_info()
        self.edge_offset = WaybarDetector.calculate_offset(
            self.position.value, self.waybar_info, self.config
        )
        
        print(f"[Dock] 📍 Position: {self.position.value}")
        print(f"[Dock] 👁️ Visibility: {self.visibility.value}")
        print(f"[Dock] 📐 Edge offset: {self.edge_offset}px")
        
        # Layer shell
        if HAS_LAYER_SHELL:
            self._setup_layer_shell()
        
        # Theme
        self._apply_css()
        
        # Build UI
        self._build_ui()
        
        # State
        self.items: Dict[str, DockItem] = {}
        self.tracker: Optional[WindowTracker] = None
        self.pinned_manager: Optional[PinnedManager] = None
        self._async_loop = None
        self._tracker_thread = None
        
        # Autohide state
        self._autohide_visible = True
        self._autohide_timer_id = None
        self._mouse_inside = False
        self._active_popover = None
        
        # Initialize
        self._init_components()
        
        # Mouse tracking for autohide
        motion = Gtk.EventControllerMotion()
        motion.connect("enter", self._on_mouse_enter)
        motion.connect("leave", self._on_mouse_leave)
        self.add_controller(motion)
        
        # Daemon mode
        if daemon_mode:
            self.connect("close-request", self._on_close_request)
            self._write_pid()
            self._setup_signals()
        
        # Config file watcher (reload on external changes from theming.py)
        self._config_mtime = self._get_config_mtime()
        GLib.timeout_add(2000, self._check_config_changes)
    
    # ═══════════════════════════════════════════════════════════════════════
    # LAYER SHELL SETUP
    # ═══════════════════════════════════════════════════════════════════════
    
    def _setup_layer_shell(self):
        """
        Setup GTK4 Layer Shell positioning.
        
        KEY INSIGHT:
        - EXCLUSIVE ZONE (always mode): Wayland compositor auto-stacks
          exclusive surfaces. If Waybar has exclusive zone on bottom,
          our dock's exclusive zone stacks ABOVE it automatically.
          We only need dock_margin for spacing, NOT waybar offset.
        
        - NON-EXCLUSIVE (autohide/hidden): We use exclusive_zone(-1)
          and manually calculate offset from waybar so we don't overlap.
        """
        Gtk4LayerShell.init_for_window(self)
        Gtk4LayerShell.set_namespace(self, "hypr-dock")
        Gtk4LayerShell.set_keyboard_mode(self, Gtk4LayerShell.KeyboardMode.NONE)
        
        edge = self.position
        cfg = self.config
        dock_margin = cfg.get("dock_margin", 8)
        is_centered = cfg.get("centered", True) and not cfg.get("stretch", False)
        is_stretch = cfg.get("stretch", False)
        
        # ─── Determine layer & exclusive zone ───────────────────────────
        if self.visibility == DockVisibility.ALWAYS:
            Gtk4LayerShell.set_layer(self, Gtk4LayerShell.Layer.TOP)
            Gtk4LayerShell.auto_exclusive_zone_enable(self)
            # Exclusive zone = compositor auto-stacks, just use dock_margin
            edge_margin = dock_margin
            print(f"[Dock] 🔒 Exclusive zone ON → edge_margin={edge_margin}px (auto-stacks with Waybar)")
        else:
            Gtk4LayerShell.set_layer(self, Gtk4LayerShell.Layer.TOP)
            Gtk4LayerShell.set_exclusive_zone(self, -1)
            # Non-exclusive = we must manually avoid waybar
            edge_margin = self.edge_offset
            print(f"[Dock] 🔓 Non-exclusive → edge_margin={edge_margin}px (manual waybar offset)")
        
        # ─── Reset all anchors to known state ───────────────────────────
        for e in [Gtk4LayerShell.Edge.TOP, Gtk4LayerShell.Edge.BOTTOM,
                  Gtk4LayerShell.Edge.LEFT, Gtk4LayerShell.Edge.RIGHT]:
            Gtk4LayerShell.set_anchor(self, e, False)
            Gtk4LayerShell.set_margin(self, e, 0)
        
        # ─── Apply position ─────────────────────────────────────────────
        if edge == DockPosition.BOTTOM:
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.BOTTOM, True)
            Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.BOTTOM, edge_margin)
            
            if is_stretch:
                Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.LEFT, True)
                Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.RIGHT, True)
                Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.LEFT, dock_margin)
                Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.RIGHT, dock_margin)
            # else: centered = no left/right anchor → GTK centers it
            
            print(f"[Dock] ⬇️ BOTTOM: margin-bottom={edge_margin}px, "
                  f"{'stretch' if is_stretch else 'centered' if is_centered else 'default'}")
            
        elif edge == DockPosition.TOP:
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.TOP, True)
            Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.TOP, edge_margin)
            
            if is_stretch:
                Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.LEFT, True)
                Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.RIGHT, True)
                Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.LEFT, dock_margin)
                Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.RIGHT, dock_margin)
            
            print(f"[Dock] ⬆️ TOP: margin-top={edge_margin}px")
            
        elif edge == DockPosition.LEFT:
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.LEFT, True)
            Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.LEFT, edge_margin)
            
            if is_stretch:
                Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.TOP, True)
                Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.BOTTOM, True)
                Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.TOP, dock_margin)
                Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.BOTTOM, dock_margin)
            
            print(f"[Dock] ⬅️ LEFT: margin-left={edge_margin}px")
            
        elif edge == DockPosition.RIGHT:
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.RIGHT, True)
            Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.RIGHT, edge_margin)
            
            if is_stretch:
                Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.TOP, True)
                Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.BOTTOM, True)
                Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.TOP, dock_margin)
                Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.BOTTOM, dock_margin)
            
            print(f"[Dock] ➡️ RIGHT: margin-right={edge_margin}px")
        
        print(f"[Dock] ✅ Layer Shell configured ({edge.value})")
    
    # ═══════════════════════════════════════════════════════════════════════
    # CSS / THEMING
    # ═══════════════════════════════════════════════════════════════════════
    
    def _load_theme_colors(self) -> dict:
        """Load current theme colors from theming system"""
        colors = {
            "bg0": "#282c34", "bg1": "#353b45", "bg2": "#2c313a",
            "bg3": "#3e4451", "bg4": "#4b5263",
            "fg": "#abb2bf", "grey1": "#5c6370",
            "blue": "#61afef", "red": "#e06c75",
            "green": "#98c379", "yellow": "#e5c07b",
        }
        
        # Try to load from saved theme
        theme_file = CONFIG_DIR / "current-theme.json"
        if theme_file.exists():
            try:
                data = json.loads(theme_file.read_text())
                if "colors" in data:
                    colors.update(data["colors"])
            except Exception:
                pass
        
        return colors
    
    def _apply_css(self):
        """Apply dock CSS"""
        colors = self._load_theme_colors()
        cfg = self.config
        
        opacity = cfg.get("opacity", 0.85)
        radius = cfg.get("border_radius", 16)
        padding = cfg.get("dock_padding", 8)
        icon_size = cfg.get("icon_size", 48)
        item_spacing = cfg.get("item_spacing", 4)
        item_padding = cfg.get("item_padding", 6)
        thickness = cfg.get("dock_thickness", 64)
        
        css = self._generate_css(colors, opacity, radius, padding, icon_size,
                                  item_spacing, item_padding, thickness)
        
        # Save CSS file
        try:
            ASSETS_DIR.mkdir(parents=True, exist_ok=True)
            DOCK_CSS_FILE.write_text(css)
        except Exception:
            pass
        
        # Apply
        provider = Gtk.CssProvider()
        provider.load_from_string(css)
        display = Gdk.Display.get_default()
        if display:
            Gtk.StyleContext.add_provider_for_display(
                display, provider,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION + 50
            )
        
        print(f"[Dock] 🎨 CSS applied: opacity={opacity}, radius={radius}, icon={icon_size}")
    
    def _generate_css(self, colors: dict, opacity: float, radius: int,
                       padding: int, icon_size: int, item_spacing: int,
                       item_padding: int, thickness: int) -> str:
        """Generate dock CSS"""
        bg = colors.get("bg0", "#282c34")
        fg = colors.get("fg", "#abb2bf")
        accent = colors.get("blue", "#61afef")
        bg3 = colors.get("bg3", "#3e4451")
        bg4 = colors.get("bg4", "#4b5263")
        red = colors.get("red", "#e06c75")
        green = colors.get("green", "#98c379")
        grey1 = colors.get("grey1", "#5c6370")
        
        # Orientation-specific sizing
        if self.is_horizontal:
            size_css = f"min-height: {thickness}px;"
        else:
            size_css = f"min-width: {thickness}px;"
        
        return f'''
/* ═══════════════════════════════════════════════════════════════════
   Hyprland Dock Widget - Auto-generated CSS
   ═══════════════════════════════════════════════════════════════════ */

#hypr-dock {{
    background: transparent;
}}

.dock-container {{
    background: alpha({bg}, {opacity});
    border-radius: {radius}px;
    border: 1px solid alpha({fg}, 0.08);
    padding: {padding}px;
    {size_css}
}}

.dock-item {{
    background: transparent;
    border: none;
    border-radius: {max(4, radius - 4)}px;
    padding: {item_padding}px;
    margin: {item_spacing // 2}px;
    min-width: {icon_size + item_padding * 2}px;
    min-height: {icon_size + item_padding * 2}px;
    transition: all 150ms ease;
}}

.dock-item:hover {{
    background: alpha({fg}, 0.08);
    transform: scale(1.1);
}}

.dock-item.focused {{
    background: alpha({accent}, 0.12);
}}

.dock-item.not-running {{
    opacity: 0.5;
}}

.dock-item.not-running:hover {{
    opacity: 1;
}}

.dock-icon {{
    color: {fg};
}}

/* Running indicator dot */
.dock-indicator {{
    background: {accent};
    border-radius: 50%;
    min-width: 6px;
    min-height: 6px;
    margin-bottom: 2px;
}}

.dock-item.focused .dock-indicator {{
    background: {accent};
    min-width: 8px;
}}

.dock-item.multi-window .dock-indicator {{
    min-width: 12px;
    border-radius: 3px;
}}

.dock-separator {{
    background: alpha({fg}, 0.12);
    margin: 4px;
}}

/* Popovers */
.dock-popover,
.dock-popover > contents {{
    background: alpha({bg}, {min(opacity + 0.1, 1.0)});
    border: 1px solid alpha({accent}, 0.2);
    border-radius: {radius}px;
}}

.dock-window-item {{
    background: transparent;
    border: none;
    border-radius: {max(4, radius - 4)}px;
    padding: 8px 12px;
    margin: 2px;
    color: {fg};
}}

.dock-window-item:hover {{
    background: alpha({accent}, 0.12);
}}

.focus-dot {{
    color: {accent};
    margin-right: 6px;
}}

.close-btn {{
    opacity: 0.5;
    min-width: 20px;
    min-height: 20px;
}}

.close-btn:hover {{
    opacity: 1;
    color: {red};
}}

.dock-popover button.flat {{
    color: {fg};
    border-radius: {max(4, radius - 4)}px;
    padding: 8px 12px;
}}

.dock-popover button.flat:hover {{
    background: alpha({accent}, 0.12);
}}

tooltip {{
    background: alpha({bg}, {min(opacity + 0.1, 1.0)});
    border: 1px solid alpha({accent}, 0.15);
    border-radius: {min(radius, 8)}px;
}}

tooltip label {{
    color: {fg};
    padding: 6px 10px;
}}
'''
    
    # ═══════════════════════════════════════════════════════════════════════
    # UI
    # ═══════════════════════════════════════════════════════════════════════
    
    def _build_ui(self):
        """Build dock UI"""
        self.set_name("hypr-dock")
        
        orientation = (Gtk.Orientation.HORIZONTAL if self.is_horizontal
                       else Gtk.Orientation.VERTICAL)
        
        self.container = Gtk.Box(orientation=orientation, spacing=0)
        self.container.add_css_class("dock-container")
        self.container.set_halign(Gtk.Align.CENTER)
        self.container.set_valign(Gtk.Align.CENTER)
        
        # Pinned section
        self.pinned_box = Gtk.Box(orientation=orientation,
                                   spacing=self.config.get("item_spacing", 4))
        self.container.append(self.pinned_box)
        
        # Separator
        sep_orient = (Gtk.Orientation.VERTICAL if self.is_horizontal
                      else Gtk.Orientation.HORIZONTAL)
        self.separator = Gtk.Separator(orientation=sep_orient)
        self.separator.add_css_class("dock-separator")
        self.container.append(self.separator)
        
        # Running (unpinned) section
        self.running_box = Gtk.Box(orientation=orientation,
                                    spacing=self.config.get("item_spacing", 4))
        self.container.append(self.running_box)
        
        self.set_child(self.container)
    
    def _init_components(self):
        """Start tracker and pinned manager"""
        self.pinned_manager = get_pinned_manager(CONFIG_DIR)
        self.pinned_manager.on_change(self._on_pinned_change)
        
        self.tracker = WindowTracker()
        self.tracker.on_change(self._on_tracker_change)
        
        GLib.idle_add(self._rebuild_ui)
        
        def run_tracker():
            self._async_loop = asyncio.new_event_loop()
            asyncio.set_event_loop(self._async_loop)
            try:
                self._async_loop.run_until_complete(self.tracker.start())
            except Exception as e:
                print(f"[Dock] Tracker error: {e}")
        
        self._tracker_thread = threading.Thread(target=run_tracker, daemon=True)
        self._tracker_thread.start()
        print("[Dock] ✅ Components initialized")
    
    def _on_tracker_change(self):
        GLib.idle_add(self._update_ui)
    
    def _on_pinned_change(self):
        GLib.idle_add(self._rebuild_ui)
    
    def _rebuild_ui(self):
        """Full rebuild"""
        self.items.clear()
        
        while (child := self.pinned_box.get_first_child()):
            self.pinned_box.remove(child)
        while (child := self.running_box.get_first_child()):
            self.running_box.remove(child)
        
        pinned_apps = self.pinned_manager.get_pinned_apps() if self.pinned_manager else []
        running_groups = {g.wm_class.lower(): g
                          for g in (self.tracker.get_app_groups() if self.tracker else [])}
        
        icon_size = self.config.get("icon_size", 48)
        
        for pinned in pinned_apps:
            app_group = None
            if pinned.wm_class and pinned.wm_class.lower() in running_groups:
                app_group = running_groups[pinned.wm_class.lower()]
            elif pinned.app_id.lower() in running_groups:
                app_group = running_groups[pinned.app_id.lower()]
            
            item = DockItem(self, pinned.app_id, pinned_app=pinned,
                            app_group=app_group, icon_size=icon_size)
            self.items[pinned.app_id] = item
            self.pinned_box.append(item)
        
        pinned_classes = set()
        for p in pinned_apps:
            if p.wm_class:
                pinned_classes.add(p.wm_class.lower())
            pinned_classes.add(p.app_id.lower())
        
        for wm_class, group in running_groups.items():
            if wm_class not in pinned_classes and group.wm_class.lower() not in pinned_classes:
                item = DockItem(self, wm_class, app_group=group, icon_size=icon_size)
                self.items[wm_class] = item
                self.running_box.append(item)
        
        has_pinned = self.pinned_box.get_first_child() is not None
        has_running = self.running_box.get_first_child() is not None
        self.separator.set_visible(
            has_pinned and has_running and self.config.get("separator_enabled", True)
        )
        
        return False
    
    def _update_ui(self):
        """Incremental update"""
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
            wm = item._get_wm_class().lower()
            ag = running_groups.get(app_id.lower()) or running_groups.get(wm)
            item.update(ag)
        
        current_ids = set(self.items.keys())
        icon_size = self.config.get("icon_size", 48)
        
        for wm_class in running_groups:
            if wm_class not in current_ids and wm_class not in pinned_classes:
                group = running_groups[wm_class]
                if group.wm_class.lower() not in pinned_classes:
                    item = DockItem(self, wm_class, app_group=group, icon_size=icon_size)
                    self.items[wm_class] = item
                    self.running_box.append(item)
        
        for app_id in list(self.items.keys()):
            if app_id.lower() not in pinned_classes and app_id.lower() not in running_groups:
                item = self.items.pop(app_id)
                self.running_box.remove(item)
        
        has_pinned = self.pinned_box.get_first_child() is not None
        has_running = self.running_box.get_first_child() is not None
        self.separator.set_visible(has_pinned and has_running
                                    and self.config.get("separator_enabled", True))
        
        return False
    
    # ═══════════════════════════════════════════════════════════════════════
    # AUTOHIDE
    # ═══════════════════════════════════════════════════════════════════════
    
    def _on_mouse_enter(self, controller, x, y):
        self._mouse_inside = True
        if self._autohide_timer_id:
            GLib.source_remove(self._autohide_timer_id)
            self._autohide_timer_id = None
        
        if self.visibility == DockVisibility.AUTOHIDE and not self._autohide_visible:
            self._autohide_show()
    
    def _on_mouse_leave(self, controller):
        self._mouse_inside = False
        
        if self.visibility == DockVisibility.AUTOHIDE:
            delay = self.config.get("autohide_delay_ms", 600)
            self._autohide_timer_id = GLib.timeout_add(delay, self._autohide_check)
    
    def _autohide_check(self) -> bool:
        self._autohide_timer_id = None
        if not self._mouse_inside and not self._has_open_popover():
            self._autohide_hide()
        return False
    
    def _autohide_show(self):
        """Show dock (autohide mode)"""
        self._autohide_visible = True
        self.set_visible(True)
        # Could add slide animation here
        print("[Dock] 👁️ Autohide: show")
    
    def _autohide_hide(self):
        """Hide dock (autohide mode)"""
        self._autohide_visible = False
        self.set_visible(False)
        print("[Dock] 🙈 Autohide: hide")
    
    def _has_open_popover(self) -> bool:
        return self._active_popover is not None and self._active_popover.is_visible()
    
    def register_popover(self, popover: Gtk.Popover):
        self._active_popover = popover
        
        def on_closed(p):
            self._active_popover = None
            if self.visibility == DockVisibility.AUTOHIDE and not self._mouse_inside:
                delay = self.config.get("autohide_delay_ms", 600)
                GLib.timeout_add(delay, self._autohide_check)
        
        popover.connect("closed", on_closed)
    
    # ═══════════════════════════════════════════════════════════════════════
    # DAEMON MODE
    # ═══════════════════════════════════════════════════════════════════════
    
    def _write_pid(self):
        try:
            PID_FILE.write_text(str(os.getpid()))
            print(f"[Dock] 📝 PID: {PID_FILE} (pid={os.getpid()})")
        except Exception as e:
            print(f"[Dock] ⚠️ PID write error: {e}")
    
    def _cleanup_pid(self):
        try:
            if PID_FILE.exists():
                PID_FILE.unlink()
        except Exception:
            pass
    
    def _setup_signals(self):
        GLib.unix_signal_add(GLib.PRIORITY_HIGH, signal.SIGUSR1, self._on_toggle)
        GLib.unix_signal_add(GLib.PRIORITY_HIGH, signal.SIGUSR2, self._on_reload_config)
        GLib.unix_signal_add(GLib.PRIORITY_HIGH, signal.SIGTERM, self._on_quit)
        print("[Dock] 📡 Signals: USR1=toggle, USR2=reload, TERM=quit")
    
    def _on_toggle(self) -> bool:
        if self.get_visible():
            self.set_visible(False)
        else:
            self.set_visible(True)
            self._rebuild_ui()
        return True
    
    def _on_reload_config(self) -> bool:
        """SIGUSR2 - reload config from disk (sent by theming.py)"""
        print("[Dock] 📡 SIGUSR2 → Reload config")
        self._reload_config()
        return True
    
    def _on_quit(self) -> bool:
        self._cleanup_pid()
        self.destroy()
        return False
    
    def _on_close_request(self, window) -> bool:
        if self.daemon_mode:
            self.set_visible(False)
            return True
        return False
    
    # ═══════════════════════════════════════════════════════════════════════
    # CONFIG HOT-RELOAD
    # ═══════════════════════════════════════════════════════════════════════
    
    def _get_config_mtime(self) -> float:
        try:
            return DOCK_CONFIG_FILE.stat().st_mtime if DOCK_CONFIG_FILE.exists() else 0
        except Exception:
            return 0
    
    def _check_config_changes(self) -> bool:
        """Periodic check for config file changes (from theming.py)"""
        mtime = self._get_config_mtime()
        if mtime > self._config_mtime:
            self._config_mtime = mtime
            print("[Dock] 🔄 Config changed externally → reload")
            self._reload_config()
        return True  # Keep timer alive
    
    def _reload_config(self):
        """Reload config and re-apply CSS"""
        self.config = load_dock_config()
        self._apply_css()
        self._rebuild_ui()
        print("[Dock] ✅ Config reloaded")
    
    # ═══════════════════════════════════════════════════════════════════════
    # ACTIONS
    # ═══════════════════════════════════════════════════════════════════════
    
    def focus_window(self, address: str):
        if self._async_loop and self.tracker:
            asyncio.run_coroutine_threadsafe(
                self.tracker.focus_window(address), self._async_loop
            )
    
    def close_window(self, address: str):
        if self._async_loop and self.tracker:
            asyncio.run_coroutine_threadsafe(
                self.tracker.close_window(address), self._async_loop
            )
    
    def close_app(self, wm_class: str):
        if self._async_loop and self.tracker:
            asyncio.run_coroutine_threadsafe(
                self.tracker.close_app(wm_class), self._async_loop
            )
    
    def launch_app(self, app_id: str):
        """Launch app using hyprctl"""
        print(f"[Dock] 🚀 Launch: {app_id}")
        try:
            subprocess.Popen(
                ["hyprctl", "dispatch", "exec", app_id],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
            )
        except Exception as e:
            print(f"[Dock] ❌ Launch error: {e}")
    
    def pin_app(self, app_id: str):
        if self.pinned_manager:
            self.pinned_manager.pin_app(app_id)
    
    def unpin_app(self, app_id: str):
        if self.pinned_manager:
            self.pinned_manager.unpin_app(app_id)
    
    def cleanup(self):
        if self._autohide_timer_id:
            GLib.source_remove(self._autohide_timer_id)
        if self.tracker:
            self.tracker.stop()
        if self._async_loop:
            self._async_loop.call_soon_threadsafe(self._async_loop.stop)
        if self.daemon_mode:
            self._cleanup_pid()


# ═══════════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════════

def main():
    parser = argparse.ArgumentParser(description="Hyprland Dock Widget")
    parser.add_argument("--daemon", action="store_true", help="Daemon mode")
    args, _ = parser.parse_known_args()
    
    mode = "DAEMON" if args.daemon else "STANDALONE"
    
    print(f"""
╔══════════════════════════════════════════════════════════════════════╗
║       HYPRLAND DOCK - Independent Desktop Dock                       ║
║       Mode: {mode:<55s}║
║       ✅ Exclusive zone (windows don't overlap)                      ║
║       ✅ Smart Waybar collision detection                            ║
║       ✅ Always-show / Autohide / Hidden modes                       ║
║       ✅ Customizable position, rounding, opacity, icon size         ║
║       ✅ Theme sync from theming.py (auto-reload)                    ║
║       ✅ SIGUSR1=toggle, SIGUSR2=reload config                      ║
╚══════════════════════════════════════════════════════════════════════╝
""")
    
    if not HAS_MODULES:
        print("[Dock] ❌ Missing required modules!")
        print("[Dock] Need: hypr_ipc, window_tracker, pinned_manager, icon_resolver")
        return
    
    dock = DockWidget(daemon_mode=args.daemon)
    dock.present()
    
    # Autohide: start hidden, wait for mouse edge
    if dock.visibility == DockVisibility.AUTOHIDE:
        GLib.timeout_add(1000, lambda: dock._autohide_hide() or False)
    
    # Hidden mode: start invisible
    if dock.visibility == DockVisibility.HIDDEN:
        GLib.idle_add(lambda: dock.set_visible(False) or False)
    
    print("[Dock] ✅ Dock ready!")
    
    loop = GLib.MainLoop()
    
    def on_destroy(win):
        dock.cleanup()
        loop.quit()
    
    dock.connect("destroy", on_destroy)
    
    try:
        loop.run()
    except KeyboardInterrupt:
        print("\n[Dock] Shutting down...")
        dock.cleanup()
        loop.quit()


if __name__ == "__main__":
    main()