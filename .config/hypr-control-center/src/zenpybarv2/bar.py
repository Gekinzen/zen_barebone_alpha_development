#!/usr/bin/env python3
"""
ZenPyBar v2.0 - Main Bar Entry Point
====================================

Complete Waybar replacement with:
- Automatic Waybar config sync
- Embedded taskbar with pin/unpin
- Theme icon integration
- Multi-monitor support
- Real-time Hyprland IPC updates

Run: ./run.sh
Or:  LD_PRELOAD=/usr/lib/libgtk4-layer-shell.so python3 bar.py
"""

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Gtk4LayerShell', '1.0')
from gi.repository import Gtk, Gdk, Gtk4LayerShell, GLib, GdkPixbuf

import sys
import subprocess
import json
import asyncio
import threading
from pathlib import Path
from typing import Dict, List, Optional, Any
from dataclasses import dataclass
from datetime import datetime

# ═══════════════════════════════════════════════════════════════════════════════
# CORE MODULE IMPORTS
# ═══════════════════════════════════════════════════════════════════════════════

ZENPYBAR_DIR = Path(__file__).resolve().parent
CORE_DIR = ZENPYBAR_DIR / "core"

if str(CORE_DIR) not in sys.path:
    sys.path.insert(0, str(CORE_DIR))
if str(ZENPYBAR_DIR) not in sys.path:
    sys.path.insert(0, str(ZENPYBAR_DIR))

# Import core modules
try:
    from core.config_manager import ConfigManager, get_config_manager
    from core.waybar_sync import WaybarSync, get_waybar_sync, WaybarTheme
    from core.icon_resolver import IconResolver, get_resolver, get_nerd_icon
    from core.window_tracker import WindowTracker, get_window_tracker, AppGroup
    from core.pinned_manager import PinnedManager, get_pinned_manager, PinnedApp
    HAS_CORE = True
    print("[ZenPyBar] ✅ Core modules loaded")
except ImportError as e:
    print(f"[ZenPyBar] ❌ Core import error: {e}")
    import traceback
    traceback.print_exc()
    HAS_CORE = False
    sys.exit(1)


# ═══════════════════════════════════════════════════════════════════════════════
# TASKBAR ITEM WIDGET
# ═══════════════════════════════════════════════════════════════════════════════

class TaskbarItem(Gtk.Button):
    """
    Single taskbar item representing an app.
    Shows icon, handles click to focus/launch, right-click for context menu.
    """
    
    def __init__(self, app_id: str, bar: 'ZenPyBar', 
                 pinned_app: Optional[PinnedApp] = None,
                 app_group: Optional[AppGroup] = None):
        super().__init__()
        
        self.app_id = app_id
        self.bar = bar
        self.pinned_app = pinned_app
        self.app_group = app_group
        
        # Get managers
        self.icon_resolver = get_resolver()
        self.pinned_mgr = get_pinned_manager()
        
        # Setup UI
        self._build_ui()
        self._update_state()
        self._setup_events()
        
        # CSS classes
        self.add_css_class("taskbar-item")
    
    def _build_ui(self) -> None:
        """Build the icon widget"""
        icon_size = 24
        
        # Try to get PNG icon from theme
        icon_path = self.icon_resolver.get_icon_path(self.app_id, icon_size)
        
        if icon_path:
            try:
                pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(
                    icon_path, icon_size, icon_size, True
                )
                image = Gtk.Image.new_from_pixbuf(pixbuf)
                self.set_child(image)
                return
            except Exception as e:
                print(f"[TaskbarItem] ⚠️ Icon load failed: {e}")
        
        # Fallback to Nerd Font
        nerd_icon = self.icon_resolver.get_nerd_icon(self.app_id)
        label = Gtk.Label(label=nerd_icon)
        label.add_css_class("nerd-icon")
        self.set_child(label)
    
    def _update_state(self) -> None:
        """Update CSS classes based on state"""
        # Clear existing state classes
        for cls in ["focused", "running", "pinned-only"]:
            self.remove_css_class(cls)
        
        is_running = self.app_group and self.app_group.window_count > 0
        is_focused = self.app_group and self.app_group.is_focused
        is_pinned = self.pinned_mgr.is_pinned(self.app_id)
        
        if is_focused:
            self.add_css_class("focused")
        elif is_running:
            self.add_css_class("running")
        elif is_pinned:
            self.add_css_class("pinned-only")
        
        # Update tooltip
        tooltip = self.app_id
        if self.app_group:
            count = self.app_group.window_count
            if count > 0:
                tooltip += f" ({count} window{'s' if count > 1 else ''})"
        self.set_tooltip_text(tooltip)
    
    def _setup_events(self) -> None:
        """Setup click handlers"""
        # Left click
        self.connect("clicked", self._on_left_click)
        
        # Right click for context menu
        right_click = Gtk.GestureClick(button=3)
        right_click.connect("pressed", self._on_right_click)
        self.add_controller(right_click)
        
        # Middle click to close
        middle_click = Gtk.GestureClick(button=2)
        middle_click.connect("pressed", self._on_middle_click)
        self.add_controller(middle_click)
    
    def _on_left_click(self, btn) -> None:
        """Handle left click - focus or launch"""
        print(f"[TaskbarItem] 🖱️ Click: {self.app_id}")
        
        if self.app_group and self.app_group.window_count > 0:
            # Has windows - focus the first or cycle
            if self.app_group.window_count == 1:
                # Single window - focus it
                window = self.app_group.first_window
                if window:
                    self.bar.focus_window(window.address)
            else:
                # Multiple windows - show picker or cycle
                # For now, focus first non-focused window
                for w in self.app_group.windows:
                    if not w.focused:
                        self.bar.focus_window(w.address)
                        break
        else:
            # No windows - launch app
            self.pinned_mgr.launch_app(self.app_id)
    
    def _on_right_click(self, gesture, n_press, x, y) -> None:
        """Handle right click - context menu"""
        print(f"[TaskbarItem] 📋 Right click: {self.app_id}")
        self._show_context_menu()
    
    def _on_middle_click(self, gesture, n_press, x, y) -> None:
        """Handle middle click - close all windows"""
        print(f"[TaskbarItem] ✖️ Middle click: {self.app_id}")
        if self.app_group:
            tracker = get_window_tracker()
            tracker.close_all_windows(self.app_group.wm_class)
    
    def _show_context_menu(self) -> None:
        """Show right-click context menu"""
        popover = Gtk.Popover()
        popover.set_parent(self)
        
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        box.set_margin_top(8)
        box.set_margin_bottom(8)
        box.set_margin_start(8)
        box.set_margin_end(8)
        
        # Pin/Unpin button
        is_pinned = self.pinned_mgr.is_pinned(self.app_id)
        pin_label = "Unpin from taskbar" if is_pinned else "Pin to taskbar"
        pin_btn = Gtk.Button(label=pin_label)
        pin_btn.add_css_class("flat")
        
        def on_pin_click(btn):
            if is_pinned:
                self.pinned_mgr.unpin_app(self.app_id)
            else:
                wm_class = self.app_group.wm_class if self.app_group else self.app_id
                self.pinned_mgr.pin_app(self.app_id, wm_class=wm_class)
            popover.popdown()
        
        pin_btn.connect("clicked", on_pin_click)
        box.append(pin_btn)
        
        # New window button
        new_btn = Gtk.Button(label="New window")
        new_btn.add_css_class("flat")
        new_btn.connect("clicked", lambda b: (self.pinned_mgr.launch_app(self.app_id), popover.popdown()))
        box.append(new_btn)
        
        # Close all button (if running)
        if self.app_group and self.app_group.window_count > 0:
            close_btn = Gtk.Button(label=f"Close all ({self.app_group.window_count})")
            close_btn.add_css_class("flat")
            close_btn.add_css_class("destructive-action")
            
            def on_close_click(btn):
                tracker = get_window_tracker()
                tracker.close_all_windows(self.app_group.wm_class)
                popover.popdown()
            
            close_btn.connect("clicked", on_close_click)
            box.append(close_btn)
        
        popover.set_child(box)
        popover.popup()
    
    def update(self, app_group: Optional[AppGroup]) -> None:
        """Update with new app group data"""
        self.app_group = app_group
        self._update_state()


# ═══════════════════════════════════════════════════════════════════════════════
# MAIN BAR CLASS
# ═══════════════════════════════════════════════════════════════════════════════

class ZenPyBar(Gtk.Window):
    """
    Main bar window using GTK4 Layer Shell.
    
    Class Variables (SHARED across all instances):
    - _shared_tracker: WindowTracker (ONE for all bars)
    - _tracker_started: bool
    """
    
    # Shared across all bar instances
    _shared_tracker: Optional[WindowTracker] = None
    _tracker_started: bool = False
    
    def __init__(self, app: Gtk.Application, monitor_name: str = ""):
        super().__init__(application=app)
        
        self.monitor_name = monitor_name
        self.app = app
        
        # Get managers (singletons)
        self.waybar_sync = get_waybar_sync()
        self.config_mgr = get_config_manager()
        self.icon_resolver = get_resolver()
        self.pinned_mgr = get_pinned_manager()
        
        # Get Waybar config
        self.wb_config = self.waybar_sync.get_config()
        self.theme = self.wb_config.theme
        
        # Taskbar items
        self.taskbar_items: Dict[str, TaskbarItem] = {}
        self.taskbar_box: Optional[Gtk.Box] = None
        
        # Workspace buttons
        self.ws_buttons: Dict[int, Gtk.Button] = {}
        
        # Module widgets
        self.clock_label: Optional[Gtk.Label] = None
        self.music_label: Optional[Gtk.Label] = None
        
        # Setup
        self._setup_layer_shell()
        self._apply_css()
        self._build_ui()
        self._start_updates()
        self._init_taskbar()
        
        print(f"[ZenPyBar] ✅ Bar created for {monitor_name or 'default'}")
    
    # ═══════════════════════════════════════════════════════════════════════
    # LAYER SHELL SETUP
    # ═══════════════════════════════════════════════════════════════════════
    
    def _setup_layer_shell(self) -> None:
        """Configure GTK4 Layer Shell"""
        Gtk4LayerShell.init_for_window(self)
        Gtk4LayerShell.set_layer(self, Gtk4LayerShell.Layer.TOP)
        Gtk4LayerShell.set_namespace(self, "zenpybar")
        
        # Position
        position = self.wb_config.position
        if position == "top":
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.TOP, True)
        else:
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.BOTTOM, True)
        
        Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.LEFT, True)
        Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.RIGHT, True)
        
        # Margins
        Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.TOP, self.wb_config.margin_top)
        Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.BOTTOM, self.wb_config.margin_bottom)
        Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.LEFT, self.wb_config.margin_left)
        Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.RIGHT, self.wb_config.margin_right)
        
        # Exclusive zone
        height = self.wb_config.height
        exclusive = height + self.wb_config.margin_top + self.wb_config.margin_bottom
        Gtk4LayerShell.set_exclusive_zone(self, exclusive)
        
        # Monitor
        if self.monitor_name:
            display = Gdk.Display.get_default()
            if display:
                monitors = display.get_monitors()
                for i in range(monitors.get_n_items()):
                    mon = monitors.get_item(i)
                    if mon.get_connector() == self.monitor_name:
                        Gtk4LayerShell.set_monitor(self, mon)
                        break
    
    # ═══════════════════════════════════════════════════════════════════════
    # CSS STYLING
    # ═══════════════════════════════════════════════════════════════════════
    
    def _apply_css(self) -> None:
        """Apply CSS styling from theme"""
        t = self.theme
        
        css = f"""
        /* ZenPyBar v2 - Auto-generated CSS */
        
        * {{
            font-family: "{t.font_family}";
            font-size: {t.font_size};
        }}
        
        window {{
            background-color: transparent;
        }}
        
        .bar-container {{
            background-color: {t.bg0};
            border-radius: 12px;
            padding: 4px 12px;
            margin: 2px 4px;
        }}
        
        .module {{
            padding: 4px 8px;
            margin: 0 4px;
            border-radius: 8px;
            color: {t.fg};
        }}
        
        /* Workspaces */
        .workspace-btn {{
            min-width: 28px;
            min-height: 28px;
            padding: 4px 8px;
            margin: 2px;
            border-radius: 8px;
            background-color: {t.bg2};
            color: {t.fg};
            border: none;
        }}
        
        .workspace-btn:hover {{
            background-color: {t.bg3};
        }}
        
        .workspace-btn.active {{
            background-color: {t.blue};
            color: {t.bg0};
        }}
        
        .workspace-btn.occupied {{
            color: {t.fg};
        }}
        
        .workspace-btn.empty {{
            color: {t.fg_dim};
        }}
        
        /* Taskbar */
        .taskbar-box {{
            margin: 0 8px;
        }}
        
        .taskbar-item {{
            min-width: 36px;
            min-height: 36px;
            padding: 4px;
            margin: 2px;
            border-radius: 8px;
            background-color: transparent;
            border: none;
            border-bottom: 2px solid transparent;
        }}
        
        .taskbar-item:hover {{
            background-color: {t.bg2};
        }}
        
        .taskbar-item.running {{
            border-bottom-color: {t.fg_dim};
        }}
        
        .taskbar-item.focused {{
            background-color: {t.bg2};
            border-bottom-color: {t.blue};
        }}
        
        .taskbar-item.pinned-only {{
            opacity: 0.6;
        }}
        
        .taskbar-item.pinned-only:hover {{
            opacity: 1.0;
        }}
        
        .nerd-icon {{
            font-size: 18px;
        }}
        
        /* Clock */
        .clock {{
            color: {t.fg};
            font-weight: 500;
            padding: 4px 12px;
        }}
        
        /* Music */
        .music-label {{
            color: {t.purple};
            padding: 4px 8px;
        }}
        
        /* Notification */
        .notification-btn {{
            color: {t.yellow};
            padding: 4px 8px;
            background: transparent;
            border: none;
        }}
        """
        
        provider = Gtk.CssProvider()
        provider.load_from_data(css.encode())
        
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )
    
    # ═══════════════════════════════════════════════════════════════════════
    # UI BUILDING
    # ═══════════════════════════════════════════════════════════════════════
    
    def _build_ui(self) -> None:
        """Build the bar UI from Waybar config"""
        # Main container
        container = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        container.add_css_class("bar-container")
        container.set_hexpand(True)
        
        # Left box
        left_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
        left_box.set_halign(Gtk.Align.START)
        left_box.set_hexpand(True)
        
        # Center box
        center_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
        center_box.set_halign(Gtk.Align.CENTER)
        
        # Right box
        right_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
        right_box.set_halign(Gtk.Align.END)
        right_box.set_hexpand(True)
        
        # Build modules
        for mod_name in self.wb_config.modules_left:
            widget = self._create_module(mod_name)
            if widget:
                left_box.append(widget)
        
        for mod_name in self.wb_config.modules_center:
            widget = self._create_module(mod_name)
            if widget:
                center_box.append(widget)
        
        for mod_name in self.wb_config.modules_right:
            widget = self._create_module(mod_name)
            if widget:
                right_box.append(widget)
        
        # Assemble
        container.append(left_box)
        container.append(center_box)
        container.append(right_box)
        
        self.set_child(container)
    
    def _create_module(self, name: str) -> Optional[Gtk.Widget]:
        """Create widget for a module"""
        
        # Taskbar
        if name in ['custom/taskbar', 'wlr/taskbar', 'hyprland/taskbar']:
            self.taskbar_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=2)
            self.taskbar_box.add_css_class("taskbar-box")
            return self.taskbar_box
        
        # Workspaces
        if name in ['hyprland/workspaces', 'wlr/workspaces']:
            return self._create_workspaces()
        
        # Clock
        if name == 'clock':
            return self._create_clock()
        
        # Music
        if name in ['custom/music', 'mpris']:
            return self._create_music()
        
        # Notification
        if name == 'custom/notification':
            return self._create_notification()
        
        # Generic module placeholder
        label = Gtk.Label(label=name.split('/')[-1])
        label.add_css_class("module")
        return label
    
    def _create_workspaces(self) -> Gtk.Widget:
        """Create workspace buttons"""
        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=2)
        
        # Get persistent workspaces config
        ws_config = self.wb_config.modules.get('hyprland/workspaces', None)
        num_workspaces = 5
        
        if ws_config and ws_config.config:
            persistent = ws_config.config.get('persistent-workspaces', {})
            if '*' in persistent:
                num_workspaces = persistent['*']
        
        for i in range(1, num_workspaces + 1):
            btn = Gtk.Button(label=str(i))
            btn.add_css_class("workspace-btn")
            btn.connect("clicked", lambda b, ws=i: self._switch_workspace(ws))
            self.ws_buttons[i] = btn
            box.append(btn)
        
        return box
    
    def _create_clock(self) -> Gtk.Widget:
        """Create clock widget"""
        self.clock_label = Gtk.Label()
        self.clock_label.add_css_class("clock")
        self._update_clock()
        return self.clock_label
    
    def _create_music(self) -> Gtk.Widget:
        """Create music widget"""
        self.music_label = Gtk.Label(label="")
        self.music_label.add_css_class("music-label")
        self.music_label.set_max_width_chars(40)
        self.music_label.set_ellipsize(3)  # END
        return self.music_label
    
    def _create_notification(self) -> Gtk.Widget:
        """Create notification button"""
        btn = Gtk.Button(label="󰂚")
        btn.add_css_class("notification-btn")
        btn.connect("clicked", lambda b: subprocess.Popen(['swaync-client', '-t']))
        return btn
    
    # ═══════════════════════════════════════════════════════════════════════
    # UPDATE LOOPS
    # ═══════════════════════════════════════════════════════════════════════
    
    def _start_updates(self) -> None:
        """Start periodic update timers"""
        GLib.timeout_add(1000, self._update_clock)
        GLib.timeout_add(100, self._update_workspaces)
        GLib.timeout_add(2000, self._update_music)
    
    def _update_clock(self) -> bool:
        """Update clock label"""
        if self.clock_label:
            now = datetime.now()
            self.clock_label.set_label(now.strftime("%a %b %d  %H:%M"))
        return True
    
    def _update_workspaces(self) -> bool:
        """Update workspace buttons"""
        try:
            # Get active workspace
            result = subprocess.run(
                ['hyprctl', '-j', 'activeworkspace'],
                capture_output=True, text=True, timeout=1
            )
            active_ws = 1
            if result.returncode == 0:
                data = json.loads(result.stdout)
                active_ws = data.get('id', 1)
            
            # Get all workspaces
            result = subprocess.run(
                ['hyprctl', '-j', 'workspaces'],
                capture_output=True, text=True, timeout=1
            )
            occupied = set()
            if result.returncode == 0:
                for ws in json.loads(result.stdout):
                    occupied.add(ws.get('id', 0))
            
            # Update buttons
            for ws_id, btn in self.ws_buttons.items():
                btn.remove_css_class("active")
                btn.remove_css_class("occupied")
                btn.remove_css_class("empty")
                
                if ws_id == active_ws:
                    btn.add_css_class("active")
                elif ws_id in occupied:
                    btn.add_css_class("occupied")
                else:
                    btn.add_css_class("empty")
                    
        except Exception as e:
            pass
        
        return True
    
    def _update_music(self) -> bool:
        """Update music label"""
        if not self.music_label:
            return True
        
        try:
            result = subprocess.run(
                ['playerctl', 'metadata', '--format', '{{artist}} - {{title}}'],
                capture_output=True, text=True, timeout=1
            )
            if result.returncode == 0 and result.stdout.strip():
                self.music_label.set_label(f"󰎆 {result.stdout.strip()}")
            else:
                self.music_label.set_label("")
        except Exception:
            self.music_label.set_label("")
        
        return True
    
    def _switch_workspace(self, ws: int) -> None:
        """Switch to workspace"""
        subprocess.run(['hyprctl', 'dispatch', 'workspace', str(ws)])
    
    # ═══════════════════════════════════════════════════════════════════════
    # TASKBAR
    # ═══════════════════════════════════════════════════════════════════════
    
    def _init_taskbar(self) -> None:
        """Initialize taskbar with shared tracker"""
        if not self.taskbar_box:
            return
        
        # Initialize shared tracker (once for all bars)
        if not ZenPyBar._tracker_started:
            ZenPyBar._shared_tracker = get_window_tracker()
            ZenPyBar._shared_tracker.start()
            ZenPyBar._tracker_started = True
            print("[ZenPyBar] 🚀 Shared WindowTracker started")
        
        # Register callbacks
        ZenPyBar._shared_tracker.on_change(self._on_windows_changed)
        self.pinned_mgr.on_change(self._rebuild_taskbar)
        
        # Initial build
        self._rebuild_taskbar()
    
    def _rebuild_taskbar(self) -> None:
        """Rebuild entire taskbar"""
        if not self.taskbar_box:
            return
        
        # Clear existing
        while True:
            child = self.taskbar_box.get_first_child()
            if child:
                self.taskbar_box.remove(child)
            else:
                break
        
        self.taskbar_items.clear()
        
        # Get data
        pinned_apps = self.pinned_mgr.get_pinned_apps()
        app_groups = ZenPyBar._shared_tracker.get_app_groups() if ZenPyBar._shared_tracker else {}
        
        # Track which apps we've added
        added_apps = set()
        
        # Add pinned apps first (maintains order)
        for pinned in pinned_apps:
            app_id = pinned.app_id
            wm_class = pinned.wm_class
            
            # Find matching app group
            app_group = None
            for wc, group in app_groups.items():
                if wc.lower() == wm_class.lower() or wc.lower() == app_id.lower():
                    app_group = group
                    break
            
            item = TaskbarItem(app_id, self, pinned_app=pinned, app_group=app_group)
            self.taskbar_items[app_id] = item
            self.taskbar_box.append(item)
            added_apps.add(app_id)
            added_apps.add(wm_class.lower())
        
        # Add running apps that aren't pinned
        for wm_class, group in app_groups.items():
            app_id = wm_class.lower()
            if app_id not in added_apps and wm_class.lower() not in added_apps:
                item = TaskbarItem(app_id, self, app_group=group)
                self.taskbar_items[app_id] = item
                self.taskbar_box.append(item)
                added_apps.add(app_id)
        
        print(f"[ZenPyBar] 📋 Taskbar rebuilt: {len(self.taskbar_items)} items")
    
    def _on_windows_changed(self) -> None:
        """Handle window changes from tracker"""
        if not ZenPyBar._shared_tracker:
            return
        
        app_groups = ZenPyBar._shared_tracker.get_app_groups()
        
        # Check if we need full rebuild (new apps)
        current_wm_classes = set(wc.lower() for wc in app_groups.keys())
        known_apps = set(self.taskbar_items.keys())
        pinned_wm_classes = set(p.wm_class.lower() for p in self.pinned_mgr.get_pinned_apps())
        
        # New running app that's not pinned?
        new_apps = current_wm_classes - known_apps - pinned_wm_classes
        
        if new_apps:
            # Full rebuild needed
            self._rebuild_taskbar()
        else:
            # Just update existing items
            for app_id, item in self.taskbar_items.items():
                # Find matching group
                app_group = None
                for wm_class, group in app_groups.items():
                    if wm_class.lower() == app_id or wm_class.lower() == (item.pinned_app.wm_class.lower() if item.pinned_app else ""):
                        app_group = group
                        break
                
                item.update(app_group)
    
    # ═══════════════════════════════════════════════════════════════════════
    # WINDOW ACTIONS
    # ═══════════════════════════════════════════════════════════════════════
    
    def focus_window(self, address: str) -> None:
        """Focus a window"""
        if ZenPyBar._shared_tracker:
            ZenPyBar._shared_tracker.focus_window(address)


# ═══════════════════════════════════════════════════════════════════════════════
# MAIN APPLICATION
# ═══════════════════════════════════════════════════════════════════════════════

class ZenPyBarApp(Gtk.Application):
    """Main GTK Application"""
    
    def __init__(self):
        super().__init__(application_id="com.zenpybar.bar")
        self.bars: List[ZenPyBar] = []
    
    def do_activate(self) -> None:
        """Create bars for each monitor"""
        # Get monitors
        monitors = self._get_monitors()
        
        if not monitors:
            # Single bar on default monitor
            bar = ZenPyBar(self)
            bar.present()
            self.bars.append(bar)
        else:
            # Bar per monitor
            for mon_name in monitors:
                bar = ZenPyBar(self, monitor_name=mon_name)
                bar.present()
                self.bars.append(bar)
        
        print(f"[ZenPyBarApp] ✅ Created {len(self.bars)} bar(s)")
    
    def _get_monitors(self) -> List[str]:
        """Get list of monitor names from Hyprland"""
        try:
            result = subprocess.run(
                ['hyprctl', '-j', 'monitors'],
                capture_output=True, text=True, timeout=2
            )
            if result.returncode == 0:
                monitors = json.loads(result.stdout)
                return [m.get('name', '') for m in monitors if m.get('name')]
        except Exception as e:
            print(f"[ZenPyBarApp] ⚠️ Monitor detection failed: {e}")
        
        return []


# ═══════════════════════════════════════════════════════════════════════════════
# ENTRY POINT
# ═══════════════════════════════════════════════════════════════════════════════

def main():
    """Main entry point"""
    print("=" * 60)
    print("ZenPyBar v2.0 - Starting...")
    print("=" * 60)
    
    # Sync Waybar config
    sync = get_waybar_sync()
    config = sync.get_config()
    
    print(f"\n📋 Waybar Config Loaded:")
    print(f"   Position: {config.position}")
    print(f"   Height: {config.height}")
    print(f"   Modules Left: {config.modules_left}")
    print(f"   Modules Center: {config.modules_center}")
    print(f"   Modules Right: {config.modules_right}")
    print(f"   Theme: {config.theme.import_path or 'inline'}")
    
    # Run app
    app = ZenPyBarApp()
    app.run(None)


if __name__ == "__main__":
    main()