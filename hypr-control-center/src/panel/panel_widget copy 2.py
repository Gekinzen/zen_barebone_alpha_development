#!/usr/bin/env python3
"""
Hyprland Panel Widget - Waybar Overlay Taskbar
==============================================

A GTK4 Layer Shell overlay that positions itself exactly where
custom/panel is placed in Waybar config (left, center, or right).

Features:
- Dynamic position sync with Waybar config
- Pin/Unpin apps (Windows-style)
- Window list popover
- Context menu
- Theme sync from Waybar style.css
- Smart close: closes when mouse leaves panel and clicks outside

Run: LD_PRELOAD=/usr/lib/libgtk4-layer-shell.so python3 panel_widget.py
"""

import gi
gi.require_version('Gtk', '4.0')
from gi.repository import Gtk, Gdk, GLib, GdkPixbuf

import json
import subprocess
import asyncio
import threading
import os
from pathlib import Path
from typing import Optional, Dict, List
import sys

# Check GTK4 Layer Shell
try:
    gi.require_version('Gtk4LayerShell', '1.0')
    from gi.repository import Gtk4LayerShell
    HAS_LAYER_SHELL = True
    print("[Panel] ✅ GTK4 Layer Shell available")
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
    from waybar_config_reader import WaybarConfigReader, get_waybar_reader, PanelPosition, WaybarTheme
    HAS_MODULES = True
    print("[Panel] ✅ All modules loaded")
except ImportError as e:
    print(f"[Panel] ❌ Import error: {e}")
    HAS_MODULES = False


class TaskbarItem(Gtk.Button):
    """Single taskbar item with icon, click handlers, and context menu"""
    
    def __init__(self, panel: 'PanelWidget', app_id: str, 
                 pinned_app: Optional[PinnedApp] = None,
                 app_group: Optional[AppGroup] = None):
        super().__init__()
        
        self.panel = panel
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
        """Build icon widget"""
        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        box.set_valign(Gtk.Align.CENTER)
        
        resolver = get_resolver()
        wm_class = self._get_wm_class()
        
        # Try to create icon
        self.icon_widget = resolver.create_icon_image(wm_class, size=24, use_nerd_fallback=True)
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
        """Update CSS classes based on state"""
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
        if self.pinned_app:
            name = self.pinned_app.name or self.pinned_app.app_id
        elif self.app_group:
            name = self.app_group.wm_class
        else:
            name = self.app_id
        
        tooltip = name
        if self.app_group and self.app_group.window_count > 1:
            tooltip += f" ({self.app_group.window_count} windows)"
        
        self.set_tooltip_text(tooltip)
    
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
        """Left click - focus or launch"""
        print(f"[TaskbarItem] Click: {self.app_id}")
        
        if self.is_running and self.app_group:
            if self.app_group.window_count == 1:
                window = self.app_group.most_recent_window
                if window:
                    self.panel.focus_window(window.address)
                    # Close panel after focusing
                    GLib.timeout_add(100, self.panel.close)
            else:
                self._show_window_list()
        elif self.is_pinned:
            self.panel.launch_app(self.app_id)
            # Close panel after launching
            GLib.timeout_add(100, self.panel.close)
    
    def _on_middle_click(self, gesture, n_press, x, y):
        """Middle click - close all"""
        if self.is_running and self.app_group:
            self.panel.close_app(self.app_group.wm_class)
    
    def _on_right_click(self, gesture, n_press, x, y):
        """Right click - context menu"""
        self._show_context_menu()
    
    def _show_window_list(self):
        """Show window list popover"""
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
            btn = Gtk.Button(label="📍 Unpin from taskbar")
            btn.add_css_class("flat")
            btn.connect("clicked", lambda b: self._do_action_and_close(popover, lambda: self.panel.unpin_app(self.app_id)))
            box.append(btn)
        else:
            btn = Gtk.Button(label="📌 Pin to taskbar")
            btn.add_css_class("flat")
            btn.connect("clicked", lambda b: self._do_action_and_close(popover, lambda: self.panel.pin_app(self._get_wm_class())))
            box.append(btn)
        
        # New window
        new_btn = Gtk.Button(label="🆕 New window")
        new_btn.add_css_class("flat")
        new_btn.connect("clicked", lambda b: self._do_action_and_close(popover, lambda: self.panel.launch_app(self._get_wm_class())))
        box.append(new_btn)
        
        # Close all
        if self.is_running:
            close_btn = Gtk.Button(label="❌ Close all windows")
            close_btn.add_css_class("flat")
            close_btn.connect("clicked", lambda b: self._do_action_and_close(popover, lambda: self.panel.close_app(self.app_group.wm_class)))
            box.append(close_btn)
        
        popover.set_child(box)
        popover.popup()
    
    def _do_action_and_close(self, popover: Gtk.Popover, action):
        """Execute action, close popover, then close panel"""
        popover.popdown()
        action()
        # Close the panel after a brief delay
        GLib.timeout_add(100, self.panel.close)
    
    def _focus_single(self, address: str, popover: Gtk.Popover):
        """Focus window and close panel"""
        popover.popdown()
        self.panel.focus_window(address)
        # Close panel after focusing
        GLib.timeout_add(100, self.panel.close)
    
    def _close_single(self, address: str, popover: Gtk.Popover):
        """Close a single window"""
        self.panel.close_window(address)
        # Don't close panel - user might want to close more windows
    
    def update(self, app_group: Optional[AppGroup] = None):
        """Update state"""
        self.app_group = app_group
        self.is_running = app_group is not None and app_group.window_count > 0
        self.is_focused = app_group.has_focus if app_group else False
        self._update_state()
        self._update_tooltip()


class PanelWidget(Gtk.Window):
    """
    Panel overlay widget that syncs position with Waybar.
    
    Positions itself exactly where custom/panel module is in Waybar config.
    
    Smart Close Behavior:
    - Once mouse enters the panel, it becomes "armed"
    - When mouse leaves the panel (after entering), monitor for clicks outside
    - Any click outside the panel will close it
    """
    
    def __init__(self, module_name: str = "custom/panel"):
        super().__init__()
        
        self.module_name = module_name
        self.set_title("hypr-panel")
        self.set_decorated(False)
        self.set_resizable(False)
        
        # Config directory
        self.config_dir = Path.home() / ".config/hypr-control-center"
        
        # Load Waybar config
        self.waybar_reader = get_waybar_reader()
        self.position = self.waybar_reader.get_panel_position(module_name)
        self.theme = self.waybar_reader.get_theme()
        
        print(f"[Panel] 📍 Position: {self.position.location}")
        print(f"[Panel] 📏 Margins: L={self.position.margin_left}, R={self.position.margin_right}")
        
        # Setup layer shell
        if HAS_LAYER_SHELL:
            self._setup_layer_shell()
        
        # Apply CSS
        self._apply_css()
        
        # Build UI
        self._build_ui()
        
        # Components
        self.items: Dict[str, TaskbarItem] = {}
        self.tracker: Optional[WindowTracker] = None
        self.pinned_manager: Optional[PinnedManager] = None
        self._async_loop = None
        self._tracker_thread = None
        
        # Smart close state
        self._mouse_has_entered = False  # True once mouse enters panel
        self._mouse_inside = False       # True while mouse is inside panel
        self._close_timer_id = None      # Timer ID for delayed close
        
        # Initialize
        self._init_components()
        
        # Track mouse enter/leave for smart close behavior
        motion_controller = Gtk.EventControllerMotion()
        motion_controller.connect("enter", self._on_mouse_enter)
        motion_controller.connect("leave", self._on_mouse_leave)
        self.add_controller(motion_controller)
    
    def _on_mouse_enter(self, controller, x, y):
        """Mouse entered the panel - cancel any pending close"""
        self._mouse_has_entered = True
        self._mouse_inside = True
        
        # Cancel pending close timer if any
        if hasattr(self, '_close_timer_id') and self._close_timer_id:
            GLib.source_remove(self._close_timer_id)
            self._close_timer_id = None
        
        print("[Panel] 🖱️ Mouse entered panel")
    
    def _on_mouse_leave(self, controller):
        """Mouse left the panel - close after short delay"""
        self._mouse_inside = False
        
        if self._mouse_has_entered:
            print("[Panel] 🖱️ Mouse left panel - closing in 400ms")
            
            # Close after 400ms delay (gives time to re-enter if accidental)
            def delayed_close():
                self._close_timer_id = None
                if not self._mouse_inside:
                    print("[Panel] ⏱️ Timer expired - closing")
                    self._close_panel()
                return False  # Don't repeat
            
            self._close_timer_id = GLib.timeout_add(400, delayed_close)
    
    def _close_panel(self):
        """Close the panel"""
        print("[Panel] 🚪 Closing panel")
        self._mouse_has_entered = False
        self.close()
        return False
    
    def _setup_layer_shell(self):
        """Setup GTK4 Layer Shell with dynamic positioning"""
        Gtk4LayerShell.init_for_window(self)
        Gtk4LayerShell.set_layer(self, Gtk4LayerShell.Layer.TOP)
        Gtk4LayerShell.set_namespace(self, "hypr-panel")
        Gtk4LayerShell.set_keyboard_mode(self, Gtk4LayerShell.KeyboardMode.NONE)
        Gtk4LayerShell.set_exclusive_zone(self, 0)
        
        # Vertical position (top/bottom)
        if self.position.waybar_position == "bottom":
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.BOTTOM, True)
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.TOP, False)
            Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.BOTTOM, 
                                      self.position.waybar_margin_bottom + 6)
        else:
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.TOP, True)
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.BOTTOM, False)
            Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.TOP,
                                      self.position.waybar_margin_top + 6)
        
        # Horizontal position based on module location
        if self.position.location == "left":
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.LEFT, True)
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.RIGHT, False)
            Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.LEFT, self.position.margin_left)
            print(f"[Panel] ⬅️ Anchored LEFT, margin={self.position.margin_left}")
            
        elif self.position.location == "center":
            # Center - anchor both sides with equal margins for centering
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.LEFT, True)
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.RIGHT, True)
            Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.LEFT, self.position.margin_left)
            Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.RIGHT, self.position.margin_right)
            print(f"[Panel] ⬛ Anchored CENTER, L={self.position.margin_left}, R={self.position.margin_right}")
            
        else:  # right
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.RIGHT, True)
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.LEFT, False)
            Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.RIGHT, self.position.margin_right)
            print(f"[Panel] ➡️ Anchored RIGHT, margin={self.position.margin_right}")
        
        print("[Panel] ✅ Layer Shell configured")
    
    def _apply_css(self):
        """Apply theme CSS"""
        t = self.theme
        
        css = f'''
        window {{
            background: transparent;
        }}
        
        .panel-container {{
            background: alpha({t.bg0}, 0.95);
            border-radius: {t.border_radius}px;
            border: 1px solid alpha({t.fg}, 0.1);
            padding: 4px 8px;
        }}
        
        .taskbar-item {{
            background: transparent;
            border: none;
            border-radius: 8px;
            padding: 4px 6px;
            margin: 2px;
            min-width: 36px;
            min-height: 36px;
        }}
        
        .taskbar-item:hover {{
            background: alpha({t.fg}, 0.1);
        }}
        
        .taskbar-item.focused {{
            background: {t.blue};
        }}
        
        .taskbar-item.running {{
            border-bottom: 2px solid {t.blue};
        }}
        
        .taskbar-item.not-running {{
            opacity: 0.5;
        }}
        
        .taskbar-item.not-running:hover {{
            opacity: 1;
        }}
        
        .taskbar-icon {{
            color: {t.fg};
            font-size: 18px;
        }}
        
        .taskbar-item.focused .taskbar-icon {{
            color: {t.bg0};
        }}
        
        .separator {{
            background: alpha({t.fg}, 0.2);
            min-width: 1px;
            margin: 8px 6px;
        }}
        
        /* Popovers */
        .window-list-popover, .context-menu {{
            background: {t.bg0};
            border: 1px solid {t.bg3};
            border-radius: 12px;
        }}
        
        .window-list-popover > contents,
        .context-menu > contents {{
            background: transparent;
            padding: 4px;
        }}
        
        .window-list-item, .context-menu button {{
            background: transparent;
            border: none;
            border-radius: 8px;
            padding: 8px 12px;
            margin: 2px;
            color: {t.fg};
        }}
        
        .window-list-item:hover, .context-menu button:hover {{
            background: alpha({t.fg}, 0.1);
        }}
        
        .focus-indicator {{
            color: {t.blue};
            margin-right: 8px;
        }}
        
        .window-close-btn {{
            opacity: 0.5;
            min-width: 24px;
            min-height: 24px;
        }}
        
        .window-close-btn:hover {{
            opacity: 1;
            color: {t.red};
        }}
        
        tooltip {{
            background: {t.bg0};
            border: 1px solid {t.bg3};
            border-radius: 8px;
        }}
        
        tooltip label {{
            color: {t.fg};
            padding: 6px 10px;
        }}
        '''
        
        provider = Gtk.CssProvider()
        provider.load_from_string(css)
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )
    
    def _build_ui(self):
        """Build panel UI"""
        self.container = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=2)
        self.container.add_css_class("panel-container")
        self.container.set_halign(Gtk.Align.CENTER)
        self.container.set_valign(Gtk.Align.CENTER)
        
        # Pinned apps section
        self.pinned_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=2)
        self.container.append(self.pinned_box)
        
        # Separator
        self.separator = Gtk.Separator(orientation=Gtk.Orientation.VERTICAL)
        self.separator.add_css_class("separator")
        self.container.append(self.separator)
        
        # Running apps section
        self.running_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=2)
        self.container.append(self.running_box)
        
        self.set_child(self.container)
    
    def _init_components(self):
        """Initialize tracker and pinned manager"""
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
            except Exception as e:
                print(f"[Panel] Tracker error: {e}")
        
        self._tracker_thread = threading.Thread(target=run_tracker, daemon=True)
        self._tracker_thread.start()
        
        print("[Panel] ✅ Components initialized")
    
    def _on_tracker_change(self):
        GLib.idle_add(self._update_ui)
    
    def _on_pinned_change(self):
        GLib.idle_add(self._rebuild_ui)
    
    def _rebuild_ui(self):
        """Rebuild entire taskbar"""
        self.items.clear()
        
        # Clear boxes
        while (child := self.pinned_box.get_first_child()):
            self.pinned_box.remove(child)
        while (child := self.running_box.get_first_child()):
            self.running_box.remove(child)
        
        pinned_apps = self.pinned_manager.get_pinned_apps() if self.pinned_manager else []
        running_groups = {g.wm_class.lower(): g for g in (self.tracker.get_app_groups() if self.tracker else [])}
        
        # Add pinned apps
        for pinned in pinned_apps:
            app_group = None
            if pinned.wm_class and pinned.wm_class.lower() in running_groups:
                app_group = running_groups[pinned.wm_class.lower()]
            elif pinned.app_id.lower() in running_groups:
                app_group = running_groups[pinned.app_id.lower()]
            
            item = TaskbarItem(self, pinned.app_id, pinned_app=pinned, app_group=app_group)
            self.items[pinned.app_id] = item
            self.pinned_box.append(item)
        
        # Add non-pinned running apps
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
        
        # Show/hide separator
        has_pinned = self.pinned_box.get_first_child() is not None
        has_running = self.running_box.get_first_child() is not None
        self.separator.set_visible(has_pinned and has_running)
        
        print(f"[Panel] 🔄 Rebuilt: {len(self.items)} items")
        return False
    
    def _update_ui(self):
        """Update existing items"""
        if not self.tracker:
            return False
        
        running_groups = {g.wm_class.lower(): g for g in self.tracker.get_app_groups()}
        pinned_classes = set()
        
        if self.pinned_manager:
            for p in self.pinned_manager.get_pinned_apps():
                if p.wm_class:
                    pinned_classes.add(p.wm_class.lower())
                pinned_classes.add(p.app_id.lower())
        
        # Update existing
        for app_id, item in list(self.items.items()):
            wm_class = item._get_wm_class().lower()
            app_group = running_groups.get(app_id.lower()) or running_groups.get(wm_class)
            item.update(app_group)
        
        # Add new running apps
        current_ids = set(self.items.keys())
        for wm_class in running_groups:
            if wm_class not in current_ids and wm_class not in pinned_classes:
                group = running_groups[wm_class]
                if group.wm_class.lower() not in pinned_classes:
                    item = TaskbarItem(self, wm_class, app_group=group)
                    self.items[wm_class] = item
                    self.running_box.append(item)
        
        # Remove closed apps
        for app_id in list(self.items.keys()):
            if app_id.lower() not in pinned_classes and app_id.lower() not in running_groups:
                item = self.items.pop(app_id)
                self.running_box.remove(item)
        
        # Update separator
        has_pinned = self.pinned_box.get_first_child() is not None
        has_running = self.running_box.get_first_child() is not None
        self.separator.set_visible(has_pinned and has_running)
        
        return False
    
    # ═══════════════════════════════════════════════════════════════════════
    # ACTIONS
    # ═══════════════════════════════════════════════════════════════════════
    
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
        """Launch an app with smart detection (flatpak, native, snap, etc.)"""
        print(f"[Panel] 🔍 Looking for app: {app_id}")
        
        # Try to find the best way to launch this app
        launch_info = self._find_app_launch_info(app_id)
        
        if launch_info:
            return self._execute_launch(launch_info)
        
        # Last resort: just try to run the app_id as command
        print(f"[Panel] ⚠️ No .desktop found, trying direct: {app_id}")
        try:
            subprocess.Popen(
                ["hyprctl", "dispatch", "exec", app_id],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
            return True
        except Exception as e:
            print(f"[Panel] ❌ Direct launch failed: {e}")
        
        return False
    
    def _find_app_launch_info(self, app_id: str) -> Optional[dict]:
        """
        Find the best .desktop file and determine launch method.
        Returns dict with: exec_cmd, app_type (native/flatpak/snap), desktop_file
        """
        # Normalize app_id for matching
        app_id_lower = app_id.lower().replace(" ", "-").replace("_", "-")
        app_id_simple = app_id_lower.split(".")[-1]  # For flatpak IDs like org.mozilla.firefox
        
        # Desktop file directories in priority order
        desktop_dirs = [
            # User local (highest priority)
            (Path.home() / ".local/share/applications", "native"),
            # Flatpak user
            (Path.home() / ".local/share/flatpak/exports/share/applications", "flatpak"),
            # System
            (Path("/usr/share/applications"), "native"),
            (Path("/usr/local/share/applications"), "native"),
            # Flatpak system
            (Path("/var/lib/flatpak/exports/share/applications"), "flatpak"),
            # Snap
            (Path("/var/lib/snapd/desktop/applications"), "snap"),
            (Path.home() / "snap" / "applications", "snap"),
        ]
        
        candidates = []
        
        for desktop_dir, app_type in desktop_dirs:
            if not desktop_dir.exists():
                continue
            
            for desktop_file in desktop_dir.glob("*.desktop"):
                score = self._match_desktop_file(desktop_file, app_id_lower, app_id_simple)
                if score > 0:
                    candidates.append({
                        "file": desktop_file,
                        "type": app_type,
                        "score": score
                    })
        
        if not candidates:
            return None
        
        # Sort by score (highest first)
        candidates.sort(key=lambda x: x["score"], reverse=True)
        best = candidates[0]
        
        print(f"[Panel] ✅ Found: {best['file'].name} (type={best['type']}, score={best['score']})")
        
        # Parse the desktop file
        return self._parse_desktop_file(best["file"], best["type"])
    
    def _match_desktop_file(self, desktop_file: Path, app_id_lower: str, app_id_simple: str) -> int:
        """
        Score how well a .desktop file matches the app_id.
        Higher score = better match.
        Returns 0 if no match.
        """
        score = 0
        filename = desktop_file.stem.lower().replace("_", "-")
        
        # Exact filename match
        if filename == app_id_lower or filename == app_id_simple:
            score += 100
        # Filename contains app_id
        elif app_id_lower in filename or app_id_simple in filename:
            score += 50
        # app_id contains filename
        elif filename in app_id_lower:
            score += 40
        
        # Check inside the file
        try:
            content = desktop_file.read_text(errors='ignore')
            
            for line in content.splitlines():
                line_lower = line.lower()
                
                # StartupWMClass match (best indicator)
                if line.startswith("StartupWMClass="):
                    wm_class = line.split("=", 1)[1].strip().lower()
                    if wm_class == app_id_lower or wm_class == app_id_simple:
                        score += 80
                    elif app_id_lower in wm_class or app_id_simple in wm_class:
                        score += 60
                
                # Name match
                elif line.startswith("Name="):
                    name = line.split("=", 1)[1].strip().lower()
                    if name == app_id_lower or name == app_id_simple:
                        score += 70
                    elif app_id_lower in name or app_id_simple in name:
                        score += 30
                
                # Check for flatpak ID in filename (org.mozilla.firefox -> firefox)
                elif line.startswith("X-Flatpak="):
                    flatpak_id = line.split("=", 1)[1].strip().lower()
                    flatpak_simple = flatpak_id.split(".")[-1]
                    if flatpak_simple == app_id_lower or flatpak_simple == app_id_simple:
                        score += 75
                    elif app_id_lower in flatpak_id:
                        score += 45
        except:
            pass
        
        return score
    
    def _parse_desktop_file(self, desktop_file: Path, app_type: str) -> Optional[dict]:
        """Parse .desktop file and return launch info"""
        try:
            content = desktop_file.read_text(errors='ignore')
            
            exec_cmd = None
            name = None
            terminal = False
            flatpak_id = None
            
            in_desktop_entry = False
            
            for line in content.splitlines():
                line = line.strip()
                
                if line == "[Desktop Entry]":
                    in_desktop_entry = True
                    continue
                elif line.startswith("[") and line.endswith("]"):
                    in_desktop_entry = False
                    continue
                
                if not in_desktop_entry:
                    continue
                
                if line.startswith("Exec="):
                    exec_cmd = line.split("=", 1)[1].strip()
                elif line.startswith("Name=") and not name:
                    name = line.split("=", 1)[1].strip()
                elif line.startswith("Terminal="):
                    terminal = line.split("=", 1)[1].strip().lower() == "true"
                elif line.startswith("X-Flatpak="):
                    flatpak_id = line.split("=", 1)[1].strip()
            
            if not exec_cmd:
                return None
            
            # Clean up Exec command - remove field codes
            exec_parts = []
            for part in exec_cmd.split():
                # Skip field codes like %u %U %f %F %c %k etc
                if part.startswith("%") and len(part) == 2:
                    continue
                # Skip env vars that might cause issues
                if part.startswith("env ") or "=" in part and part.index("=") < part.index(" ") if " " in part else "=" in part:
                    if not exec_parts:  # Only skip leading env assignments
                        continue
                exec_parts.append(part)
            
            exec_cmd = " ".join(exec_parts)
            
            # Determine actual app type based on exec command
            if "flatpak run" in exec_cmd or flatpak_id:
                app_type = "flatpak"
                # Extract flatpak ID if not already found
                if not flatpak_id and "flatpak run" in exec_cmd:
                    parts = exec_cmd.split("flatpak run")
                    if len(parts) > 1:
                        flatpak_id = parts[1].strip().split()[0]
            elif "/snap/" in exec_cmd:
                app_type = "snap"
            
            return {
                "exec_cmd": exec_cmd,
                "app_type": app_type,
                "terminal": terminal,
                "name": name,
                "flatpak_id": flatpak_id,
                "desktop_file": desktop_file
            }
            
        except Exception as e:
            print(f"[Panel] ❌ Failed to parse {desktop_file}: {e}")
            return None
    
    def _execute_launch(self, launch_info: dict) -> bool:
        """Execute the app with the appropriate method"""
        app_type = launch_info["app_type"]
        exec_cmd = launch_info["exec_cmd"]
        terminal = launch_info.get("terminal", False)
        flatpak_id = launch_info.get("flatpak_id")
        name = launch_info.get("name", "App")
        
        print(f"[Panel] 🚀 Launching {name} ({app_type})")
        
        try:
            if app_type == "flatpak" and flatpak_id:
                # Use flatpak run directly for reliability
                cmd = f"flatpak run {flatpak_id}"
                print(f"[Panel] 📦 Flatpak: {cmd}")
            elif app_type == "snap":
                # Snap apps - use the exec command as-is
                cmd = exec_cmd
                print(f"[Panel] 📦 Snap: {cmd}")
            else:
                # Native app
                cmd = exec_cmd
                print(f"[Panel] 💻 Native: {cmd}")
            
            # Wrap in terminal if needed
            if terminal:
                term = os.environ.get("TERMINAL", "kitty")
                cmd = f"{term} -e {cmd}"
                print(f"[Panel] 🖥️ Terminal wrapped: {cmd}")
            
            # Launch via hyprctl for proper Wayland handling
            subprocess.Popen(
                ["hyprctl", "dispatch", "exec", cmd],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
            
            return True
            
        except Exception as e:
            print(f"[Panel] ❌ Launch failed: {e}")
            
            # Fallback: try gtk-launch
            try:
                desktop_name = launch_info["desktop_file"].stem
                print(f"[Panel] 🔄 Fallback: gtk-launch {desktop_name}")
                subprocess.Popen(
                    ["gtk-launch", desktop_name],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL
                )
                return True
            except:
                pass
        
        return False
    
    def pin_app(self, app_id: str):
        if self.pinned_manager:
            self.pinned_manager.pin_app(app_id)
    
    def unpin_app(self, app_id: str):
        if self.pinned_manager:
            self.pinned_manager.unpin_app(app_id)

    def cleanup(self):
        # Cancel any pending close timer
        if hasattr(self, '_close_timer_id') and self._close_timer_id:
            GLib.source_remove(self._close_timer_id)
        if self.tracker:
            self.tracker.stop()
        if self._async_loop:
            self._async_loop.call_soon_threadsafe(self._async_loop.stop)


def main():
    print("""
╔══════════════════════════════════════════════════════════════╗
║       HYPRLAND PANEL - Waybar Overlay Taskbar                ║
║       Position synced with custom/panel in Waybar            ║
║       Auto-close when mouse leaves panel                     ║
╚══════════════════════════════════════════════════════════════╝
""")
    
    if not HAS_MODULES:
        print("[Panel] ❌ Missing required modules!")
        return
    
    # Check which module name to use
    reader = get_waybar_reader()
    module_name = "custom/panel"
    
    # Try different module names
    for name in ["custom/panel", "custom/taskbar", "wlr/taskbar"]:
        if reader.has_module(name):
            module_name = name
            break
    
    print(f"[Panel] Using module: {module_name}")
    
    panel = PanelWidget(module_name)
    panel.present()
    
    print("[Panel] ✅ Panel started!")
    
    loop = GLib.MainLoop()
    
    def on_destroy(win):
        panel.cleanup()
        loop.quit()
    
    panel.connect("destroy", on_destroy)
    
    try:
        loop.run()
    except KeyboardInterrupt:
        print("\n[Panel] Shutting down...")
        panel.cleanup()
        loop.quit()


if __name__ == "__main__":
    main()