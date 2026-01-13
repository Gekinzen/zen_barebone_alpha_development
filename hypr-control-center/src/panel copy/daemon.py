#!/usr/bin/env python3
"""
Hyprland Panel Daemon
Main entry point that orchestrates all panel components

Location: ~/.config/hypr-control-center/src/panel/daemon.py

Features:
- Starts window tracker in background
- Loads pinned apps configuration
- Launches GTK4 taskbar widget
- Integrates pinned + running apps
- Handles signals for restart/quit
"""

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
gi.require_version('Gdk', '4.0')

try:
    gi.require_version('Gtk4LayerShell', '1.0')
    from gi.repository import Gtk4LayerShell as LayerShell
    HAS_LAYER_SHELL = True
except:
    HAS_LAYER_SHELL = False

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
except ImportError:
    sys.path.insert(0, str(Path(__file__).parent))
    from window_tracker import WindowTracker, AppGroup
    from pinned_manager import PinnedManager, PinnedApp, get_pinned_manager
    from icon_resolver import get_resolver, get_nerd_icon


class TaskbarItem(Gtk.Button):
    """
    Unified taskbar item for both pinned and running apps
    """
    
    def __init__(self, panel: 'HyprPanel', app_id: str, pinned_app: Optional[PinnedApp] = None, 
                 app_group: Optional[AppGroup] = None):
        super().__init__()
        
        self.panel = panel
        self.app_id = app_id
        self.pinned_app = pinned_app
        self.app_group = app_group
        
        self.add_css_class("taskbar-item")
        
        # Determine state
        self.is_pinned = pinned_app is not None
        self.is_running = app_group is not None and app_group.window_count > 0
        self.is_focused = app_group.has_focus if app_group else False
        
        self._build_ui()
        self._update_state()
        self._setup_gestures()
    
    def _build_ui(self):
        """Build item UI"""
        self.box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        
        # Icon container (for overlay effects)
        icon_container = Gtk.Box()
        icon_container.set_halign(Gtk.Align.CENTER)
        
        # Get icon
        resolver = get_resolver()
        wm_class = self._get_wm_class()
        self.icon_widget = resolver.create_icon_image(wm_class, size=28, use_nerd_fallback=True)
        self.icon_widget.add_css_class("taskbar-item-icon")
        icon_container.append(self.icon_widget)
        
        self.box.append(icon_container)
        
        # Running indicator dot
        self.indicator = Gtk.Box()
        self.indicator.add_css_class("running-indicator")
        self.indicator.set_size_request(6, 6)
        self.indicator.set_halign(Gtk.Align.CENTER)
        self.box.append(self.indicator)
        
        self.set_child(self.box)
        
        # Tooltip
        self._update_tooltip()
    
    def _get_wm_class(self) -> str:
        """Get WM class for icon lookup"""
        if self.app_group:
            return self.app_group.wm_class
        if self.pinned_app:
            return self.pinned_app.wm_class or self.pinned_app.app_id
        return self.app_id
    
    def _update_state(self):
        """Update visual state"""
        # Running indicator
        if self.is_running:
            self.indicator.remove_css_class("hidden")
            self.indicator.add_css_class("visible")
        else:
            self.indicator.remove_css_class("visible")
            self.indicator.add_css_class("hidden")
        
        # Focus state
        if self.is_focused:
            self.add_css_class("focused")
        else:
            self.remove_css_class("focused")
        
        # Pinned but not running (dimmed)
        if self.is_pinned and not self.is_running:
            self.add_css_class("not-running")
        else:
            self.remove_css_class("not-running")
    
    def _update_tooltip(self):
        """Update tooltip text"""
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
    
    def _on_left_click(self, button):
        """Handle left click"""
        if self.is_running:
            if self.app_group and self.app_group.window_count == 1:
                # Single window - focus it
                window = self.app_group.most_recent_window
                if window:
                    self.panel.focus_window(window.address)
            elif self.app_group and self.app_group.window_count > 1:
                # Multiple windows - show list
                self._show_window_list()
        elif self.is_pinned:
            # Not running - launch it
            self.panel.launch_app(self.app_id)
    
    def _on_middle_click(self, gesture, n_press, x, y):
        """Handle middle click - close"""
        if self.is_running and self.app_group:
            self.panel.close_app(self.app_group.wm_class)
    
    def _on_right_click(self, gesture, n_press, x, y):
        """Handle right click - context menu"""
        self._show_context_menu()
    
    def _show_window_list(self):
        """Show popup with windows"""
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
            title.set_ellipsize(3)  # PANGO_ELLIPSIZE_END
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
        
        # Close (if running)
        if self.is_running:
            close_btn = Gtk.Button(label=f"Close all windows")
            close_btn.add_css_class("flat")
            close_btn.connect("clicked", lambda b: self._close_all(popover))
            box.append(close_btn)
        
        # Launch new instance
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
        """Update item state"""
        self.app_group = app_group
        self.is_running = app_group is not None and app_group.window_count > 0
        self.is_focused = app_group.has_focus if app_group else False
        
        self._update_state()
        self._update_tooltip()


class HyprPanel(Gtk.ApplicationWindow):
    """
    Main Hyprland Panel with pinned + running apps
    """
    
    def __init__(self, app: Gtk.Application):
        super().__init__(application=app, title="Hypr Panel")
        
        # Components
        self.tracker: Optional[WindowTracker] = None
        self.pinned_manager: Optional[PinnedManager] = None
        self._async_loop: Optional[asyncio.AbstractEventLoop] = None
        self._tracker_thread: Optional[threading.Thread] = None
        
        # UI state
        self.items: Dict[str, TaskbarItem] = {}
        
        # Config
        self.config = {
            'position': 'bottom',
            'height': 48,
            'margin_left': 300,
            'margin_right': 300,
            'margin_bottom': 6,
            'margin_top': 0,
        }
        
        # Paths
        self.config_dir = Path.home() / ".config/hypr-control-center"
        self.css_file = self.config_dir / "assets/panel.css"
        
        # Setup
        self._setup_window()
        self._load_css()
        self._build_ui()
        self._init_components()
    
    def _setup_window(self):
        """Setup window with layer shell"""
        self.set_decorated(False)
        self.set_resizable(False)
        
        if HAS_LAYER_SHELL:
            LayerShell.init_for_window(self)
            LayerShell.set_layer(self, LayerShell.Layer.TOP)
            LayerShell.set_namespace(self, "hypr-panel")
            
            # Anchors
            if self.config['position'] == 'bottom':
                LayerShell.set_anchor(self, LayerShell.Edge.BOTTOM, True)
                LayerShell.set_anchor(self, LayerShell.Edge.LEFT, True)
                LayerShell.set_anchor(self, LayerShell.Edge.RIGHT, True)
                LayerShell.set_margin(self, LayerShell.Edge.BOTTOM, self.config['margin_bottom'])
            else:
                LayerShell.set_anchor(self, LayerShell.Edge.TOP, True)
                LayerShell.set_anchor(self, LayerShell.Edge.LEFT, True)
                LayerShell.set_anchor(self, LayerShell.Edge.RIGHT, True)
                LayerShell.set_margin(self, LayerShell.Edge.TOP, self.config['margin_top'])
            
            LayerShell.set_margin(self, LayerShell.Edge.LEFT, self.config['margin_left'])
            LayerShell.set_margin(self, LayerShell.Edge.RIGHT, self.config['margin_right'])
            LayerShell.set_keyboard_mode(self, LayerShell.KeyboardMode.NONE)
            LayerShell.set_exclusive_zone(self, 0)
            
            print("[HyprPanel] Layer shell configured")
        else:
            self.set_default_size(600, self.config['height'])
            print("[HyprPanel] Running without layer shell")
    
    def _load_css(self):
        """Load CSS styling"""
        css_provider = Gtk.CssProvider()
        
        default_css = """
        .panel-container {
            background: alpha(#1e1e2e, 0.85);
            border-radius: 12px;
            padding: 4px 12px;
            margin: 4px;
        }
        
        .taskbar-item {
            background: transparent;
            border: none;
            border-radius: 8px;
            padding: 6px 10px;
            margin: 2px;
            min-width: 44px;
            min-height: 44px;
            transition: all 150ms ease;
        }
        
        .taskbar-item:hover {
            background: alpha(#cdd6f4, 0.15);
        }
        
        .taskbar-item.focused {
            background: alpha(#89b4fa, 0.25);
        }
        
        .taskbar-item.not-running {
            opacity: 0.5;
        }
        
        .taskbar-item.not-running:hover {
            opacity: 1;
        }
        
        .taskbar-item-icon {
            color: #cdd6f4;
        }
        
        .running-indicator {
            background: #89b4fa;
            border-radius: 50%;
            min-width: 6px;
            min-height: 6px;
            margin-top: 2px;
        }
        
        .running-indicator.hidden {
            opacity: 0;
        }
        
        .running-indicator.visible {
            opacity: 1;
        }
        
        .nerd-icon {
            font-family: "JetBrainsMono Nerd Font", "Symbols Nerd Font", monospace;
            font-size: 24px;
            color: #cdd6f4;
        }
        
        .separator {
            background: alpha(#cdd6f4, 0.2);
            min-width: 1px;
            margin: 8px 6px;
        }
        
        .window-list-popover {
            background: #1e1e2e;
            border: 1px solid #313244;
            border-radius: 12px;
        }
        
        .window-list-item {
            background: transparent;
            padding: 8px 12px;
            border-radius: 8px;
            min-width: 200px;
        }
        
        .window-list-item:hover {
            background: alpha(#cdd6f4, 0.1);
        }
        
        .window-close-btn {
            opacity: 0.5;
            min-width: 24px;
            min-height: 24px;
        }
        
        .window-close-btn:hover {
            opacity: 1;
            color: #f38ba8;
        }
        
        .focus-indicator {
            color: #89b4fa;
            font-weight: bold;
        }
        
        .context-menu {
            background: #1e1e2e;
            border: 1px solid #313244;
            border-radius: 12px;
        }
        
        .context-menu button {
            padding: 8px 16px;
            border-radius: 6px;
        }
        """
        
        if self.css_file.exists():
            try:
                css_provider.load_from_path(str(self.css_file))
                print(f"[HyprPanel] Loaded CSS: {self.css_file}")
            except Exception as e:
                print(f"[HyprPanel] CSS error: {e}, using defaults")
                css_provider.load_from_string(default_css)
        else:
            css_provider.load_from_string(default_css)
        
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
        
        # Pinned apps section
        self.pinned_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=2)
        self.container.append(self.pinned_box)
        
        # Separator
        self.separator = Gtk.Separator(orientation=Gtk.Orientation.VERTICAL)
        self.separator.add_css_class("separator")
        self.container.append(self.separator)
        
        # Running apps section (non-pinned)
        self.running_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=2)
        self.container.append(self.running_box)
        
        self.set_child(self.container)
    
    def _init_components(self):
        """Initialize tracker and pinned manager"""
        # Pinned manager
        self.pinned_manager = get_pinned_manager(self.config_dir)
        self.pinned_manager.on_change(self._on_pinned_change)
        
        # Window tracker
        self.tracker = WindowTracker()
        self.tracker.on_change(self._on_tracker_change)
        
        # Initial UI update
        GLib.idle_add(self._rebuild_ui)
        
        # Start tracker thread
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
        """Handle tracker state change"""
        GLib.idle_add(self._update_ui)
    
    def _on_pinned_change(self):
        """Handle pinned apps change"""
        GLib.idle_add(self._rebuild_ui)
    
    def _rebuild_ui(self):
        """Rebuild entire UI (when pinned apps change)"""
        # Clear existing items
        self.items.clear()
        
        # Clear pinned box
        while True:
            child = self.pinned_box.get_first_child()
            if not child:
                break
            self.pinned_box.remove(child)
        
        # Clear running box
        while True:
            child = self.running_box.get_first_child()
            if not child:
                break
            self.running_box.remove(child)
        
        # Get data
        pinned_apps = self.pinned_manager.get_pinned_apps() if self.pinned_manager else []
        running_groups = {g.wm_class.lower(): g for g in (self.tracker.get_app_groups() if self.tracker else [])}
        
        # Build pinned section
        for pinned in pinned_apps:
            app_group = None
            # Match with running
            if pinned.wm_class and pinned.wm_class.lower() in running_groups:
                app_group = running_groups[pinned.wm_class.lower()]
            elif pinned.app_id.lower() in running_groups:
                app_group = running_groups[pinned.app_id.lower()]
            
            item = TaskbarItem(self, pinned.app_id, pinned_app=pinned, app_group=app_group)
            self.items[pinned.app_id] = item
            self.pinned_box.append(item)
        
        # Build running section (non-pinned only)
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
        """Update UI state (without rebuilding)"""
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
        
        # Check for new running apps (not pinned)
        current_running_ids = set(self.items.keys()) - pinned_classes
        new_running = set(running_groups.keys()) - pinned_classes - current_running_ids
        
        for wm_class in new_running:
            group = running_groups[wm_class]
            if group.wm_class.lower() not in pinned_classes:
                item = TaskbarItem(self, wm_class, app_group=group)
                self.items[wm_class] = item
                self.running_box.append(item)
        
        # Remove closed apps (non-pinned)
        for app_id in list(self.items.keys()):
            if app_id.lower() not in pinned_classes:
                if app_id.lower() not in running_groups:
                    item = self.items.pop(app_id)
                    self.running_box.remove(item)
        
        # Update separator visibility
        has_pinned = self.pinned_box.get_first_child() is not None
        has_running = self.running_box.get_first_child() is not None
        self.separator.set_visible(has_pinned and has_running)
        
        return False
    
    # ==========================================
    # ACTIONS
    # ==========================================
    
    def focus_window(self, address: str):
        """Focus window by address"""
        if self._async_loop and self.tracker:
            asyncio.run_coroutine_threadsafe(
                self.tracker.focus_window(address),
                self._async_loop
            )
    
    def close_window(self, address: str):
        """Close window by address"""
        if self._async_loop and self.tracker:
            asyncio.run_coroutine_threadsafe(
                self.tracker.close_window(address),
                self._async_loop
            )
    
    def close_app(self, wm_class: str):
        """Close all windows of app"""
        if self._async_loop and self.tracker:
            asyncio.run_coroutine_threadsafe(
                self.tracker.close_app(wm_class),
                self._async_loop
            )
    
    def launch_app(self, app_id: str):
        """Launch app"""
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
        """Cleanup on exit"""
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
        
        # Handle signals
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
        """Handle interrupt signal"""
        print("\n[HyprPanelApp] Shutting down...")
        if self.panel:
            self.panel.cleanup()
        self.quit()
        return False


def main():
    """Main entry point"""
    print("""
╔══════════════════════════════════════════════════════════╗
║              HYPRLAND PANEL DAEMON                       ║
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