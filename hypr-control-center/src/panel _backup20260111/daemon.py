#!/usr/bin/env python3
"""
Hyprland Panel Daemon - Auto-detects Waybar config
Main entry point that orchestrates all panel components

Location: ~/.config/hypr-control-center/src/panel/daemon.py

Features:
- Auto-detects position from Waybar config
- Inherits theme colors from Waybar style.css
- Real PNG/theme icons with Nerd Font fallback
- GTK4 Layer Shell for proper dock behavior
"""

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
gi.require_version('Gdk', '4.0')

try:
    gi.require_version('Gtk4LayerShell', '1.0')
    from gi.repository import Gtk4LayerShell as LayerShell
    HAS_LAYER_SHELL = True
    print("[HyprPanel] ✅ GTK4 Layer Shell loaded!")
except Exception as e:
    HAS_LAYER_SHELL = False
    print(f"[HyprPanel] ❌ GTK4 Layer Shell not found: {e}")

from gi.repository import Gtk, Adw, Gdk, GLib, Gio, GdkPixbuf
import asyncio
import threading
import signal
import sys
import os
from pathlib import Path
from typing import Optional, Dict, List

# Local imports
try:
    from .window_tracker import WindowTracker, AppGroup
    from .pinned_manager import PinnedManager, PinnedApp, get_pinned_manager
    from .icon_resolver import get_resolver, get_nerd_icon
    from .waybar_config_reader import WaybarConfigReader, get_waybar_reader
except ImportError:
    sys.path.insert(0, str(Path(__file__).parent))
    from window_tracker import WindowTracker, AppGroup
    from pinned_manager import PinnedManager, PinnedApp, get_pinned_manager
    from icon_resolver import get_resolver, get_nerd_icon
    from waybar_config_reader import WaybarConfigReader, get_waybar_reader


class TaskbarItem(Gtk.Button):
    """Unified taskbar item for both pinned and running apps"""
    
    def __init__(self, panel: 'HyprPanel', app_id: str, pinned_app: Optional[PinnedApp] = None, 
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
        self._setup_gestures()
    
    def _build_ui(self):
        """Build item UI - HORIZONTAL layout for alignment"""
        # Single horizontal box - no vertical stacking
        self.box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        self.box.set_valign(Gtk.Align.CENTER)
        
        resolver = get_resolver()
        wm_class = self._get_wm_class()
        self.icon_widget = resolver.create_icon_image(wm_class, size=24, use_nerd_fallback=True)
        self.icon_widget.add_css_class("taskbar-item-icon")
        self.box.append(self.icon_widget)
        
        # Running indicator - small dot BESIDE icon, not below
        self.indicator = Gtk.Box()
        self.indicator.add_css_class("running-indicator")
        self.indicator.set_size_request(4, 4)
        self.indicator.set_valign(Gtk.Align.END)
        self.indicator.set_margin_start(2)
        self.box.append(self.indicator)
        
        self.set_child(self.box)
        self._update_tooltip()
    
    def _get_wm_class(self) -> str:
        if self.app_group:
            return self.app_group.wm_class
        if self.pinned_app:
            return self.pinned_app.wm_class or self.pinned_app.app_id
        return self.app_id
    
    def _update_state(self):
        if self.is_running:
            self.indicator.remove_css_class("hidden")
            self.indicator.add_css_class("visible")
        else:
            self.indicator.remove_css_class("visible")
            self.indicator.add_css_class("hidden")
        
        if self.is_focused:
            self.add_css_class("focused")
        else:
            self.remove_css_class("focused")
        
        if self.is_pinned and not self.is_running:
            self.add_css_class("not-running")
        else:
            self.remove_css_class("not-running")
    
    def _update_tooltip(self):
        name = ""
        if self.pinned_app:
            name = self.pinned_app.name
        elif self.app_group:
            name = self.app_group.wm_class
        
        tooltip = name
        
        if self.app_group and self.app_group.window_count > 1:
            tooltip += f" ({self.app_group.window_count} windows)"
        
        if self.app_group and self.app_group.display_title:
            tooltip += f"\n{self.app_group.display_title[:50]}"
        
        self.set_tooltip_text(tooltip)
    
    def _setup_gestures(self):
        self.connect("clicked", self._on_left_click)
        
        middle = Gtk.GestureClick.new()
        middle.set_button(2)
        middle.connect("pressed", self._on_middle_click)
        self.add_controller(middle)
        
        right = Gtk.GestureClick.new()
        right.set_button(3)
        right.connect("pressed", self._on_right_click)
        self.add_controller(right)
    
    def _on_left_click(self, button):
        if self.is_running:
            if self.app_group and self.app_group.window_count == 1:
                window = self.app_group.most_recent_window
                if window:
                    self.panel.focus_window(window.address)
            elif self.app_group and self.app_group.window_count > 1:
                self._show_window_list()
        elif self.is_pinned:
            self.panel.launch_app(self.app_id)
    
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
                indicator = Gtk.Label(label="→")
                indicator.add_css_class("focus-indicator")
                row_box.append(indicator)
            
            title = Gtk.Label(label=window.title[:45] if window.title else "Untitled")
            title.set_xalign(0)
            title.set_hexpand(True)
            title.set_ellipsize(3)
            row_box.append(title)
            
            close_btn = Gtk.Button()
            close_btn.set_icon_name("window-close-symbolic")
            close_btn.add_css_class("flat")
            close_btn.add_css_class("window-close-btn")
            close_btn.connect("clicked", lambda b, addr=window.address: self._close_window(addr, popover))
            row_box.append(close_btn)
            
            row.set_child(row_box)
            row.connect("clicked", lambda b, addr=window.address: self._focus_window(addr, popover))
            box.append(row)
        
        popover.set_child(box)
        popover.popup()
    
    def _show_context_menu(self):
        popover = Gtk.Popover()
        popover.set_parent(self)
        popover.add_css_class("context-menu")
        
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        box.set_margin_top(4)
        box.set_margin_bottom(4)
        box.set_margin_start(4)
        box.set_margin_end(4)
        
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
        
        if self.is_running:
            close_btn = Gtk.Button(label="Close all windows")
            close_btn.add_css_class("flat")
            close_btn.connect("clicked", lambda b: self._close_all(popover))
            box.append(close_btn)
        
        launch_btn = Gtk.Button(label="New window")
        launch_btn.add_css_class("flat")
        launch_btn.connect("clicked", lambda b: self._launch_new(popover))
        box.append(launch_btn)
        
        popover.set_child(box)
        popover.popup()
    
    def _focus_window(self, address: str, popover: Gtk.Popover):
        popover.popdown()
        self.panel.focus_window(address)
    
    def _close_window(self, address: str, popover: Gtk.Popover):
        self.panel.close_window(address)
    
    def _close_all(self, popover: Gtk.Popover):
        popover.popdown()
        if self.app_group:
            self.panel.close_app(self.app_group.wm_class)
    
    def _pin(self, popover: Gtk.Popover):
        popover.popdown()
        self.panel.pin_app(self.app_id)
    
    def _unpin(self, popover: Gtk.Popover):
        popover.popdown()
        self.panel.unpin_app(self.app_id)
    
    def _launch_new(self, popover: Gtk.Popover):
        popover.popdown()
        self.panel.launch_app(self.app_id)
    
    def update(self, app_group: Optional[AppGroup] = None):
        self.app_group = app_group
        self.is_running = app_group is not None and app_group.window_count > 0
        self.is_focused = app_group.has_focus if app_group else False
        self._update_state()
        self._update_tooltip()


class HyprPanel(Gtk.ApplicationWindow):
    """Main Hyprland Panel - Auto-detects Waybar config"""
    
    def __init__(self, app: Gtk.Application):
        super().__init__(application=app)
        
        # NO TITLE - truly borderless
        self.set_title("")
        self.set_decorated(False)
        self.set_resizable(False)
        
        # CRITICAL: Initialize Layer Shell IMMEDIATELY after window creation
        # MUST be done before the window is realized/mapped
        if HAS_LAYER_SHELL:
            print("[HyprPanel] Initializing Layer Shell...")
            LayerShell.init_for_window(self)
            print("[HyprPanel] ✅ Layer Shell initialized for window")
        
        self.tracker: Optional[WindowTracker] = None
        self.pinned_manager: Optional[PinnedManager] = None
        self._async_loop: Optional[asyncio.AbstractEventLoop] = None
        self._tracker_thread: Optional[threading.Thread] = None
        
        self.items: Dict[str, TaskbarItem] = {}
        
        # Paths
        self.config_dir = Path.home() / ".config/hypr-control-center"
        
        # Load Waybar config
        self.waybar_reader = get_waybar_reader()
        self.position = self.waybar_reader.get_panel_position("custom/panel")
        self.theme = self.waybar_reader.get_theme()
        
        print(f"[HyprPanel] Position: {self.position.location}")
        print(f"[HyprPanel] Margins: L={self.position.margin_left}, R={self.position.margin_right}")
        
        # Setup layer shell properties (after init_for_window)
        self._setup_layer_shell()
        self._load_css()
        self._build_ui()
        self._init_components()
    
    def _setup_layer_shell(self):
        """Setup layer shell properties"""
        if not HAS_LAYER_SHELL:
            self.set_default_size(600, self.position.waybar_height)
            print("[HyprPanel] ⚠️ Running WITHOUT Layer Shell")
            return
        
        # Set layer to OVERLAY (always on top)
        LayerShell.set_layer(self, LayerShell.Layer.OVERLAY)
        LayerShell.set_namespace(self, "hypr-panel")
        print(f"[HyprPanel] Layer: OVERLAY, namespace: hypr-panel")
        
        # Position based on Waybar config
        if self.position.waybar_position == "bottom":
            LayerShell.set_anchor(self, LayerShell.Edge.BOTTOM, True)
            LayerShell.set_margin(self, LayerShell.Edge.BOTTOM, self.position.waybar_margin_bottom)
            print(f"[HyprPanel] Anchored: BOTTOM, margin={self.position.waybar_margin_bottom}")
        else:
            LayerShell.set_anchor(self, LayerShell.Edge.TOP, True)
            LayerShell.set_margin(self, LayerShell.Edge.TOP, self.position.waybar_margin_top)
            print(f"[HyprPanel] Anchored: TOP, margin={self.position.waybar_margin_top}")
        
        # Horizontal positioning
        if self.position.location == "left":
            LayerShell.set_anchor(self, LayerShell.Edge.LEFT, True)
            LayerShell.set_margin(self, LayerShell.Edge.LEFT, self.position.margin_left)
            print(f"[HyprPanel] Position: LEFT, margin={self.position.margin_left}")
        elif self.position.location == "right":
            LayerShell.set_anchor(self, LayerShell.Edge.RIGHT, True)
            LayerShell.set_margin(self, LayerShell.Edge.RIGHT, self.position.margin_right)
            print(f"[HyprPanel] Position: RIGHT, margin={self.position.margin_right}")
        else:  # center
            LayerShell.set_anchor(self, LayerShell.Edge.LEFT, True)
            LayerShell.set_anchor(self, LayerShell.Edge.RIGHT, True)
            LayerShell.set_margin(self, LayerShell.Edge.LEFT, self.position.margin_left)
            LayerShell.set_margin(self, LayerShell.Edge.RIGHT, self.position.margin_right)
            print(f"[HyprPanel] Position: CENTER, L={self.position.margin_left}, R={self.position.margin_right}")
        
        # Don't grab keyboard, don't push windows
        LayerShell.set_keyboard_mode(self, LayerShell.KeyboardMode.NONE)
        LayerShell.set_exclusive_zone(self, 0)
        
        print("[HyprPanel] ✅ Layer Shell configured!")
    
    def _load_css(self):
        """Load CSS - generate from Waybar theme"""
        css_provider = Gtk.CssProvider()
        
        # Generate CSS from Waybar theme
        generated_css_path = self.waybar_reader.save_generated_css()
        
        # Try to load generated CSS
        if generated_css_path.exists():
            try:
                css_provider.load_from_path(str(generated_css_path))
                print(f"[HyprPanel] Loaded generated CSS: {generated_css_path}")
            except Exception as e:
                print(f"[HyprPanel] CSS error: {e}, using fallback")
                css_provider.load_from_string(self._get_fallback_css())
        else:
            css_provider.load_from_string(self._get_fallback_css())
        
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            css_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )
    
    def _get_fallback_css(self) -> str:
        """Fallback CSS if generation fails"""
        return f'''
        .panel-container {{
            background: alpha({self.theme.bg0}, 0.9);
            border-radius: {self.theme.border_radius}px;
            border: 1px solid {self.theme.bg1};
            padding: 5px 14px;
        }}
        
        .taskbar-item {{
            background: transparent;
            border-radius: 15px;
            padding: 4px 8px;
            margin: 2px;
            min-width: 40px;
            min-height: 40px;
        }}
        
        .taskbar-item:hover {{
            background: alpha({self.theme.fg}, 0.1);
        }}
        
        .taskbar-item.focused {{
            background: {self.theme.blue};
        }}
        
        .taskbar-item.not-running {{
            opacity: 0.5;
        }}
        
        .nerd-icon {{
            font-family: "{self.theme.font_family}", monospace;
            font-size: 20px;
            color: {self.theme.fg};
        }}
        
        .taskbar-item.focused .nerd-icon {{
            color: {self.theme.bg0};
        }}
        
        .running-indicator {{
            background: {self.theme.blue};
            border-radius: 50%;
            min-width: 6px;
            min-height: 6px;
        }}
        
        .running-indicator.hidden {{
            opacity: 0;
        }}
        
        .separator {{
            background: alpha({self.theme.fg}, 0.15);
            min-width: 1px;
            margin: 8px 6px;
        }}
        '''
    
    def _build_ui(self):
        """Build panel UI"""
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
                print(f"[HyprPanel] Tracker error: {e}")
        
        self._tracker_thread = threading.Thread(target=run_tracker, daemon=True)
        self._tracker_thread.start()
        
        print("[HyprPanel] Components initialized")
    
    def _on_tracker_change(self):
        GLib.idle_add(self._update_ui)
    
    def _on_pinned_change(self):
        GLib.idle_add(self._rebuild_ui)
    
    def _rebuild_ui(self):
        """Rebuild entire UI"""
        self.items.clear()
        
        while True:
            child = self.pinned_box.get_first_child()
            if not child:
                break
            self.pinned_box.remove(child)
        
        while True:
            child = self.running_box.get_first_child()
            if not child:
                break
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
        """Update UI state"""
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
            app_group = running_groups.get(app_id.lower()) or running_groups.get(item._get_wm_class().lower())
            item.update(app_group)
        
        current_running_ids = set(self.items.keys()) - pinned_classes
        new_running = set(running_groups.keys()) - pinned_classes - current_running_ids
        
        for wm_class in new_running:
            group = running_groups[wm_class]
            if group.wm_class.lower() not in pinned_classes:
                item = TaskbarItem(self, wm_class, app_group=group)
                self.items[wm_class] = item
                self.running_box.append(item)
        
        for app_id in list(self.items.keys()):
            if app_id.lower() not in pinned_classes:
                if app_id.lower() not in running_groups:
                    item = self.items.pop(app_id)
                    self.running_box.remove(item)
        
        has_pinned = self.pinned_box.get_first_child() is not None
        has_running = self.running_box.get_first_child() is not None
        self.separator.set_visible(has_pinned and has_running)
        
        return False
    
    # ==========================================
    # ACTIONS
    # ==========================================
    
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
    
    def cleanup(self):
        if self.tracker:
            self.tracker.stop()
        if self._async_loop:
            self._async_loop.call_soon_threadsafe(self._async_loop.stop)


class HyprPanelApp(Adw.Application):
    """Main application"""
    
    def __init__(self):
        super().__init__(
            application_id="com.hyprland.panel",
            flags=Gio.ApplicationFlags.FLAGS_NONE
        )
        self.panel = None
        
        GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGINT, self._on_sigint)
        GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGTERM, self._on_sigint)
    
    def do_activate(self):
        if self.panel:
            self.panel.present()
            return
        
        self.panel = HyprPanel(self)
        self.panel.present()
        
        print("[HyprPanelApp] Panel started")
    
    def _on_sigint(self):
        print("\n[HyprPanelApp] Shutting down...")
        if self.panel:
            self.panel.cleanup()
        self.quit()
        return False


def main():
    print("""
╔══════════════════════════════════════════════════════════╗
║         HYPRLAND PANEL DAEMON (Auto-detect)              ║
╚══════════════════════════════════════════════════════════╝
""")
    
    if not HAS_LAYER_SHELL:
        print("⚠  GTK4 Layer Shell not found!")
        print("   Install with: yay -S gtk4-layer-shell")
        print("   Running in windowed mode...\n")
    
    app = HyprPanelApp()
    
    try:
        app.run(None)
    except KeyboardInterrupt:
        print("\nShutting down...")
        if app.panel:
            app.panel.cleanup()


if __name__ == "__main__":
    main()