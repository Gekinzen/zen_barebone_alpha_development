#!/usr/bin/env python3
"""
Hyprland Panel - Using same pattern as working widgets
Location: ~/.config/hypr-control-center/src/panel/panel_widget.py
"""

import gi
gi.require_version('Gtk', '4.0')
from gi.repository import Gtk, Gdk, GLib, GdkPixbuf

import json
import subprocess
import asyncio
import threading
from pathlib import Path
from typing import Optional, Dict, List

# Check if gtk4-layer-shell is available
try:
    gi.require_version('Gtk4LayerShell', '1.0')
    from gi.repository import Gtk4LayerShell
    HAS_LAYER_SHELL = True
    print("[HyprPanel] ✅ GTK4 Layer Shell available")
except:
    HAS_LAYER_SHELL = False
    print("[HyprPanel] ⚠️ gtk4-layer-shell not found")

# Import local modules
import sys
from pathlib import Path

# Add parent directory to path for direct execution
_panel_dir = Path(__file__).parent
if str(_panel_dir) not in sys.path:
    sys.path.insert(0, str(_panel_dir))

# Now import - these will work both as module and direct script
from hypr_ipc import HyprlandIPC, HyprEvent, HyprEventType, HyprWindow, hyprctl_json
from window_tracker import WindowTracker, AppGroup
from pinned_manager import PinnedManager, PinnedApp, get_pinned_manager
from icon_resolver import get_resolver, get_nerd_icon
from waybar_config_reader import WaybarConfigReader, get_waybar_reader


class TaskbarItem(Gtk.Button):
    """Single taskbar item with full functionality"""
    
    def __init__(self, panel, app_id: str, pinned_app=None, app_group=None):
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
        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        box.set_valign(Gtk.Align.CENTER)
        
        resolver = get_resolver()
        wm_class = self._get_wm_class()
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
        self.remove_css_class("focused")
        self.remove_css_class("running")
        self.remove_css_class("not-running")
        
        if self.is_focused:
            self.add_css_class("focused")
        elif self.is_running:
            self.add_css_class("running")
        elif self.is_pinned:
            self.add_css_class("not-running")
    
    def _update_tooltip(self):
        name = ""
        if self.pinned_app:
            name = self.pinned_app.name
        elif self.app_group:
            name = self.app_group.wm_class
        
        tooltip = name
        if self.app_group and self.app_group.window_count > 1:
            tooltip += f" ({self.app_group.window_count} windows)"
        
        self.set_tooltip_text(tooltip)
    
    def _setup_clicks(self):
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
        """Left click - focus window or show window list"""
        if self.is_running and self.app_group:
            if self.app_group.window_count == 1:
                # Single window - focus it
                window = self.app_group.most_recent_window
                if window:
                    self.panel.focus_window(window.address)
            else:
                # Multiple windows - show list
                self._show_window_list()
        elif self.is_pinned:
            # Not running - launch app
            self.panel.launch_app(self.app_id)
    
    def _on_middle_click(self, gesture, n_press, x, y):
        """Middle click - close all windows"""
        if self.is_running and self.app_group:
            self.panel.close_app(self.app_group.wm_class)
    
    def _on_right_click(self, gesture, n_press, x, y):
        """Right click - show context menu"""
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
            title.set_ellipsize(3)  # PANGO_ELLIPSIZE_END
            row_box.append(title)
            
            # Close button
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
    
    def _focus_window(self, address: str, popover: Gtk.Popover):
        """Focus specific window"""
        popover.popdown()
        self.panel.focus_window(address)
    
    def _close_window(self, address: str, popover: Gtk.Popover):
        """Close specific window"""
        self.panel.close_window(address)
    
    def _close_all(self, popover: Gtk.Popover):
        """Close all windows of this app"""
        popover.popdown()
        if self.app_group:
            self.panel.close_app(self.app_group.wm_class)
    
    def _pin(self, popover: Gtk.Popover):
        """Pin app to taskbar"""
        popover.popdown()
        self.panel.pin_app(self._get_wm_class())
    
    def _unpin(self, popover: Gtk.Popover):
        """Unpin app from taskbar"""
        popover.popdown()
        self.panel.unpin_app(self.app_id)
    
    def _launch_new(self, popover: Gtk.Popover):
        """Launch new instance"""
        popover.popdown()
        self.panel.launch_app(self._get_wm_class())
    
    def update(self, app_group=None):
        self.app_group = app_group
        self.is_running = app_group is not None and app_group.window_count > 0
        self.is_focused = app_group.has_focus if app_group else False
        self._update_state()
        self._update_tooltip()


class PanelWidget(Gtk.Window):
    """Panel widget using same pattern as clock/weather widgets"""
    
    def __init__(self):
        super().__init__()
        
        self.set_title("hypr-panel")
        self.set_decorated(False)
        self.set_resizable(False)
        
        # Config
        self.config_dir = Path.home() / ".config/hypr-control-center"
        
        # Load Waybar config
        self.waybar_reader = get_waybar_reader()
        self.position = self.waybar_reader.get_panel_position("custom/panel")
        self.theme = self.waybar_reader.get_theme()
        
        print(f"[HyprPanel] Position: {self.position.location}")
        print(f"[HyprPanel] Margins: L={self.position.margin_left}, R={self.position.margin_right}")
        print(f"[HyprPanel] Waybar: {self.position.waybar_position}, height={self.position.waybar_height}")
        
        # Setup layer shell FIRST (like widgets do)
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
        
        # Initialize
        self._init_components()
    
    def _setup_layer_shell(self):
        """Setup GTK4 Layer Shell - same pattern as widgets"""
        Gtk4LayerShell.init_for_window(self)
        
        # TOP layer - SAME as Waybar so they align properly
        Gtk4LayerShell.set_layer(self, Gtk4LayerShell.Layer.TOP)
        Gtk4LayerShell.set_namespace(self, "hypr-panel")
        
        print(f"[HyprPanel] Layer: TOP, namespace: hypr-panel")
        
        # Keyboard mode - none (don't grab focus)
        Gtk4LayerShell.set_keyboard_mode(self, Gtk4LayerShell.KeyboardMode.NONE)
        
        # No exclusive zone
        Gtk4LayerShell.set_exclusive_zone(self, 0)
        
        # Anchor based on Waybar position
        if self.position.waybar_position == "bottom":
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.BOTTOM, True)
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.TOP, False)
            Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.BOTTOM, self.position.waybar_margin_bottom)
            print(f"[HyprPanel] Anchor: BOTTOM, margin={self.position.waybar_margin_bottom}")
        else:
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.TOP, True)
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.BOTTOM, False)
            Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.TOP, self.position.waybar_margin_top)
            print(f"[HyprPanel] Anchor: TOP, margin={self.position.waybar_margin_top}")
        
        # Horizontal positioning
        if self.position.location == "center":
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.LEFT, True)
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.RIGHT, True)
            Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.LEFT, self.position.margin_left)
            Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.RIGHT, self.position.margin_right)
            print(f"[HyprPanel] Center: L={self.position.margin_left}, R={self.position.margin_right}")
        elif self.position.location == "left":
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.LEFT, True)
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.RIGHT, False)
            Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.LEFT, self.position.margin_left)
        else:
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.RIGHT, True)
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.LEFT, False)
            Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.RIGHT, self.position.margin_right)
        
        print("[HyprPanel] ✅ Layer Shell configured!")
    
    def _apply_css(self):
        """Apply CSS styling"""
        css_provider = Gtk.CssProvider()
        
        css = f'''
        window {{
            background: transparent;
        }}
        
        .panel-container {{
            background: alpha({self.theme.bg0}, 0.9);
            border-radius: {self.theme.border_radius}px;
            border: 1px solid {self.theme.bg1};
            padding: 4px 12px;
        }}
        
        .taskbar-item {{
            background: transparent;
            border: none;
            border-radius: 8px;
            padding: 4px 6px;
            margin: 2px;
            min-width: 32px;
            min-height: 32px;
        }}
        
        .taskbar-item:hover {{
            background: alpha({self.theme.fg}, 0.1);
        }}
        
        .taskbar-item.focused {{
            background: {self.theme.blue};
        }}
        
        .taskbar-item.running {{
            border-bottom: 2px solid {self.theme.blue};
        }}
        
        .taskbar-item.not-running {{
            opacity: 0.5;
        }}
        
        .taskbar-icon {{
            color: {self.theme.fg};
        }}
        
        .taskbar-item.focused .taskbar-icon {{
            color: {self.theme.bg0};
        }}
        
        .separator {{
            background: alpha({self.theme.fg}, 0.2);
            min-width: 1px;
            margin: 6px 4px;
        }}
        
        /* Window List Popover */
        .window-list-popover {{
            background: {self.theme.bg0};
            border: 1px solid {self.theme.bg3};
            border-radius: 12px;
        }}
        
        .window-list-popover > contents {{
            background: transparent;
            padding: 4px;
        }}
        
        .window-list-item {{
            background: transparent;
            border: none;
            border-radius: 8px;
            padding: 8px 12px;
            margin: 2px;
        }}
        
        .window-list-item:hover {{
            background: alpha({self.theme.fg}, 0.1);
        }}
        
        .window-list-item label {{
            color: {self.theme.fg};
        }}
        
        .focus-indicator {{
            color: {self.theme.blue};
            margin-right: 8px;
        }}
        
        .window-close-btn {{
            opacity: 0.5;
            min-width: 24px;
            min-height: 24px;
        }}
        
        .window-close-btn:hover {{
            opacity: 1;
            color: {self.theme.red};
        }}
        
        /* Context Menu */
        .context-menu {{
            background: {self.theme.bg0};
            border: 1px solid {self.theme.bg3};
            border-radius: 12px;
        }}
        
        .context-menu > contents {{
            background: transparent;
            padding: 4px;
        }}
        
        .context-menu button {{
            background: transparent;
            border: none;
            border-radius: 8px;
            padding: 8px 16px;
            margin: 2px;
            color: {self.theme.fg};
        }}
        
        .context-menu button:hover {{
            background: alpha({self.theme.fg}, 0.1);
        }}
        
        /* Tooltip */
        tooltip {{
            background: {self.theme.bg0};
            border: 1px solid {self.theme.bg3};
            border-radius: 8px;
        }}
        
        tooltip > * {{
            background: transparent;
        }}
        
        tooltip label {{
            color: {self.theme.fg};
            padding: 6px 10px;
        }}
        '''
        
        css_provider.load_from_string(css)
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            css_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )
    
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
        
        print("[HyprPanel] ✅ Components initialized")
    
    def _on_tracker_change(self):
        GLib.idle_add(self._update_ui)
    
    def _on_pinned_change(self):
        GLib.idle_add(self._rebuild_ui)
    
    def _rebuild_ui(self):
        """Rebuild UI"""
        self.items.clear()
        
        # Clear boxes
        while (child := self.pinned_box.get_first_child()):
            self.pinned_box.remove(child)
        while (child := self.running_box.get_first_child()):
            self.running_box.remove(child)
        
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
            self.items[pinned.app_id] = item
            self.pinned_box.append(item)
        
        # Non-pinned running
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
        
        # Update existing items
        for app_id, item in list(self.items.items()):
            app_group = running_groups.get(app_id.lower()) or running_groups.get(item._get_wm_class().lower())
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
    
    # Actions
    def focus_window(self, address: str):
        if self._async_loop and self.tracker:
            asyncio.run_coroutine_threadsafe(
                self.tracker.focus_window(address),
                self._async_loop
            )
    
    def close_window(self, address: str):
        """Close specific window"""
        if self._async_loop and self.tracker:
            asyncio.run_coroutine_threadsafe(
                self.tracker.close_window(address),
                self._async_loop
            )
    
    def close_app(self, wm_class: str):
        """Close all windows of an app"""
        if self._async_loop and self.tracker:
            asyncio.run_coroutine_threadsafe(
                self.tracker.close_app(wm_class),
                self._async_loop
            )
    
    def launch_app(self, app_id: str):
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
    
    def cleanup(self):
        if self.tracker:
            self.tracker.stop()
        if self._async_loop:
            self._async_loop.call_soon_threadsafe(self._async_loop.stop)


def main():
    print("""
╔══════════════════════════════════════════════════════════╗
║         HYPRLAND PANEL (Widget Style)                    ║
╚══════════════════════════════════════════════════════════╝
""")
    
    panel = PanelWidget()
    panel.present()
    
    print("[HyprPanel] ✅ Panel started!")
    print("[HyprPanel] Check: hyprctl layers | grep -A2 overlay")
    
    # Run GLib main loop (GTK4 style)
    loop = GLib.MainLoop()
    
    def on_destroy(win):
        panel.cleanup()
        loop.quit()
    
    panel.connect("destroy", on_destroy)
    
    try:
        loop.run()
    except KeyboardInterrupt:
        print("\n[HyprPanel] Shutting down...")
        panel.cleanup()
        loop.quit()


if __name__ == "__main__":
    main()