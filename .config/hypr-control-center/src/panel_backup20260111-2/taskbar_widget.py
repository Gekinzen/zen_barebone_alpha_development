#!/usr/bin/env python3
"""
Taskbar Widget Module
GTK4 Layer Shell taskbar for Hyprland

Location: ~/.config/hypr-control-center/src/panel/taskbar_widget.py

Features:
- Layer shell integration (sits on desktop like Waybar)
- Real-time window tracking
- App icons with window count badges
- Click to focus, middle-click to close
- Right-click context menu
- Focus indicator styling
"""

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
gi.require_version('Gdk', '4.0')

# Try to load GTK4 Layer Shell
try:
    gi.require_version('Gtk4LayerShell', '1.0')
    from gi.repository import Gtk4LayerShell as LayerShell
    HAS_LAYER_SHELL = True
except:
    HAS_LAYER_SHELL = False
    print("[TaskbarWidget] WARNING: GTK4 Layer Shell not found!")
    print("                Install with: yay -S gtk4-layer-shell")

from gi.repository import Gtk, Adw, Gdk, GLib, Gio, GdkPixbuf
import asyncio
import threading
from pathlib import Path
from typing import Optional, Dict, List

# Local imports - handle both module and direct run
try:
    from .window_tracker import WindowTracker, AppGroup, TrackedWindow
    from .icon_resolver import get_resolver, get_icon_for_class
except ImportError:
    import sys
    sys.path.insert(0, str(Path(__file__).parent))
    from window_tracker import WindowTracker, AppGroup, TrackedWindow
    from icon_resolver import get_resolver, get_icon_for_class


class TaskbarButton(Gtk.Button):
    """Individual app button in taskbar"""
    
    def __init__(self, app_group: AppGroup, taskbar: 'TaskbarWidget'):
        super().__init__()
        self.app_group = app_group
        self.taskbar = taskbar
        self.wm_class = app_group.wm_class
        
        self.add_css_class("taskbar-button")
        
        # Build button content
        self._build_ui()
        
        # Update focus state
        self._update_focus_state()
        
        # Click handlers
        self.connect("clicked", self._on_click)
        
        # Middle click to close
        middle_click = Gtk.GestureClick.new()
        middle_click.set_button(2)
        middle_click.connect("pressed", self._on_middle_click)
        self.add_controller(middle_click)
        
        # Right click for context menu
        right_click = Gtk.GestureClick.new()
        right_click.set_button(3)
        right_click.connect("pressed", self._on_right_click)
        self.add_controller(right_click)
    
    def _build_ui(self):
        """Build button UI"""
        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        
        # Icon - use create_icon_image which handles Nerd Font fallback
        resolver = get_resolver()
        self.icon = resolver.create_icon_image(self.wm_class, size=24, use_nerd_fallback=True)
        self.icon.add_css_class("taskbar-icon")
        box.append(self.icon)
        
        # Window count badge (if more than 1)
        if self.app_group.window_count > 1:
            self.badge = Gtk.Label(label=str(self.app_group.window_count))
            self.badge.add_css_class("taskbar-badge")
            box.append(self.badge)
        else:
            self.badge = None
        
        self.set_child(box)
        
        # Tooltip with app name and title
        tooltip = f"{self.wm_class}"
        if self.app_group.display_title:
            tooltip += f"\n{self.app_group.display_title[:50]}"
        self.set_tooltip_text(tooltip)
    
    def _update_focus_state(self):
        """Update visual focus state"""
        if self.app_group.has_focus:
            self.add_css_class("focused")
        else:
            self.remove_css_class("focused")
    
    def update(self, app_group: AppGroup):
        """Update button with new app group data"""
        self.app_group = app_group
        
        # Update badge
        if self.badge:
            if app_group.window_count > 1:
                self.badge.set_label(str(app_group.window_count))
                self.badge.set_visible(True)
            else:
                self.badge.set_visible(False)
        elif app_group.window_count > 1:
            # Need to add badge
            self._build_ui()
        
        # Update tooltip
        tooltip = f"{self.wm_class}"
        if self.app_group.display_title:
            tooltip += f"\n{self.app_group.display_title[:50]}"
        self.set_tooltip_text(tooltip)
        
        # Update focus state
        self._update_focus_state()
    
    def _on_click(self, button):
        """Handle left click - focus app"""
        if self.app_group.window_count == 1:
            # Single window - focus it
            window = self.app_group.most_recent_window
            if window:
                self.taskbar.focus_window(window.address)
        else:
            # Multiple windows - show window list popup
            self._show_window_list()
    
    def _on_middle_click(self, gesture, n_press, x, y):
        """Handle middle click - close app"""
        self.taskbar.close_app(self.wm_class)
    
    def _on_right_click(self, gesture, n_press, x, y):
        """Handle right click - context menu"""
        self._show_context_menu()
    
    def _show_window_list(self):
        """Show popup with all windows for this app"""
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
                indicator = Gtk.Label(label="→")
                indicator.add_css_class("focus-indicator")
                row_box.append(indicator)
            
            # Title
            title = Gtk.Label(label=window.title[:40])
            title.set_xalign(0)
            title.set_hexpand(True)
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
        """Show right-click context menu"""
        popover = Gtk.Popover()
        popover.set_parent(self)
        popover.add_css_class("context-menu")
        
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        box.set_margin_top(4)
        box.set_margin_bottom(4)
        
        # Close all windows
        close_btn = Gtk.Button(label=f"Close all ({self.app_group.window_count})")
        close_btn.add_css_class("flat")
        close_btn.connect("clicked", lambda b: self._close_all(popover))
        box.append(close_btn)
        
        popover.set_child(box)
        popover.popup()
    
    def _focus_window(self, address: str, popover: Gtk.Popover):
        """Focus specific window"""
        popover.popdown()
        self.taskbar.focus_window(address)
    
    def _close_window(self, address: str, popover: Gtk.Popover):
        """Close specific window"""
        self.taskbar.close_window(address)
        # Don't close popover - let it update
    
    def _close_all(self, popover: Gtk.Popover):
        """Close all windows of this app"""
        popover.popdown()
        self.taskbar.close_app(self.wm_class)


class TaskbarWidget(Gtk.ApplicationWindow):
    """
    Main taskbar widget using GTK4 Layer Shell
    """
    
    def __init__(self, app: Gtk.Application):
        super().__init__(application=app, title="Hypr Taskbar")
        
        self.tracker: Optional[WindowTracker] = None
        self.buttons: Dict[str, TaskbarButton] = {}
        self._async_loop: Optional[asyncio.AbstractEventLoop] = None
        self._tracker_thread: Optional[threading.Thread] = None
        
        # Config
        self.config = {
            'position': 'bottom',  # top, bottom
            'height': 40,
            'margin_left': 400,    # Space for Waybar left modules
            'margin_right': 400,   # Space for Waybar right modules
            'margin_bottom': 0,
            'margin_top': 0,
            'monitor': -1,         # -1 = all monitors
        }
        
        # Paths
        self.config_dir = Path.home() / ".config/hypr-control-center"
        self.css_file = self.config_dir / "assets/panel.css"
        
        # Setup window
        self._setup_window()
        
        # Load CSS
        self._load_css()
        
        # Build UI
        self._build_ui()
        
        # Start tracker
        self._start_tracker()
    
    def _setup_window(self):
        """Setup window properties and layer shell"""
        self.set_decorated(False)
        self.set_resizable(False)
        
        if HAS_LAYER_SHELL:
            # Initialize layer shell
            LayerShell.init_for_window(self)
            
            # Set layer (overlay to be above other windows but below popups)
            LayerShell.set_layer(self, LayerShell.Layer.TOP)
            
            # Set anchors based on position
            if self.config['position'] == 'bottom':
                LayerShell.set_anchor(self, LayerShell.Edge.BOTTOM, True)
                LayerShell.set_anchor(self, LayerShell.Edge.LEFT, True)
                LayerShell.set_anchor(self, LayerShell.Edge.RIGHT, True)
                LayerShell.set_margin(self, LayerShell.Edge.BOTTOM, self.config['margin_bottom'])
            else:  # top
                LayerShell.set_anchor(self, LayerShell.Edge.TOP, True)
                LayerShell.set_anchor(self, LayerShell.Edge.LEFT, True)
                LayerShell.set_anchor(self, LayerShell.Edge.RIGHT, True)
                LayerShell.set_margin(self, LayerShell.Edge.TOP, self.config['margin_top'])
            
            # Set margins for left/right (leave space for Waybar modules)
            LayerShell.set_margin(self, LayerShell.Edge.LEFT, self.config['margin_left'])
            LayerShell.set_margin(self, LayerShell.Edge.RIGHT, self.config['margin_right'])
            
            # Set namespace for window rules
            LayerShell.set_namespace(self, "hypr-taskbar")
            
            # Don't take keyboard focus
            LayerShell.set_keyboard_mode(self, LayerShell.KeyboardMode.NONE)
            
            # Exclusive zone = 0 (don't push other windows)
            LayerShell.set_exclusive_zone(self, 0)
            
            print("[TaskbarWidget] Layer shell configured")
        else:
            # Fallback: regular window
            self.set_default_size(800, self.config['height'])
            print("[TaskbarWidget] Running without layer shell (regular window)")
    
    def _load_css(self):
        """Load CSS styling"""
        css_provider = Gtk.CssProvider()
        
        # Default CSS
        default_css = """
        .taskbar-container {
            background: alpha(#1e1e2e, 0.9);
            padding: 4px 8px;
            border-radius: 0;
        }
        
        .taskbar-button {
            background: transparent;
            border: none;
            border-radius: 8px;
            padding: 4px 8px;
            margin: 2px;
            min-width: 40px;
            min-height: 32px;
            transition: all 200ms ease;
        }
        
        .taskbar-button:hover {
            background: alpha(#cdd6f4, 0.1);
        }
        
        .taskbar-button.focused {
            background: alpha(#89b4fa, 0.2);
            border-bottom: 2px solid #89b4fa;
        }
        
        .taskbar-icon {
            color: #cdd6f4;
        }
        
        .taskbar-badge {
            background: #f38ba8;
            color: #1e1e2e;
            font-size: 10px;
            font-weight: bold;
            padding: 1px 5px;
            border-radius: 10px;
            min-width: 16px;
        }
        
        .window-list-popover {
            background: #1e1e2e;
            border: 1px solid #313244;
            border-radius: 8px;
        }
        
        .window-list-item {
            background: transparent;
            padding: 8px 12px;
            border-radius: 6px;
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
        
        .nerd-icon {
            font-family: "JetBrainsMono Nerd Font", "Symbols Nerd Font", monospace;
            font-size: 20px;
            color: #cdd6f4;
        }
        
        .context-menu {
            background: #1e1e2e;
            border: 1px solid #313244;
            border-radius: 8px;
            padding: 4px;
        }
        """
        
        # Try to load custom CSS
        if self.css_file.exists():
            try:
                css_provider.load_from_path(str(self.css_file))
                print(f"[TaskbarWidget] Loaded CSS from {self.css_file}")
            except Exception as e:
                print(f"[TaskbarWidget] CSS load error: {e}, using defaults")
                css_provider.load_from_string(default_css)
        else:
            css_provider.load_from_string(default_css)
            print("[TaskbarWidget] Using default CSS")
        
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            css_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )
    
    def _build_ui(self):
        """Build taskbar UI"""
        # Main container
        self.container = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
        self.container.add_css_class("taskbar-container")
        self.container.set_halign(Gtk.Align.CENTER)
        self.container.set_valign(Gtk.Align.CENTER)
        
        # Placeholder
        placeholder = Gtk.Label(label="Loading...")
        placeholder.set_opacity(0.5)
        self.container.append(placeholder)
        
        self.set_child(self.container)
    
    def _start_tracker(self):
        """Start window tracker in background thread"""
        self.tracker = WindowTracker()
        self.tracker.on_change(self._on_tracker_change)
        
        # Run tracker in separate thread with its own event loop
        def run_tracker():
            self._async_loop = asyncio.new_event_loop()
            asyncio.set_event_loop(self._async_loop)
            
            try:
                self._async_loop.run_until_complete(self.tracker.start())
            except Exception as e:
                print(f"[TaskbarWidget] Tracker error: {e}")
        
        self._tracker_thread = threading.Thread(target=run_tracker, daemon=True)
        self._tracker_thread.start()
        
        print("[TaskbarWidget] Tracker started in background thread")
    
    def _on_tracker_change(self):
        """Handle tracker state change - update UI"""
        # Schedule UI update on main thread
        GLib.idle_add(self._update_buttons)
    
    def _update_buttons(self):
        """Update taskbar buttons based on tracker state"""
        if not self.tracker:
            return
        
        app_groups = self.tracker.get_app_groups()
        current_classes = {g.wm_class for g in app_groups}
        existing_classes = set(self.buttons.keys())
        
        # Remove buttons for closed apps
        for wm_class in existing_classes - current_classes:
            button = self.buttons.pop(wm_class)
            self.container.remove(button)
        
        # Clear placeholder if we have apps
        if app_groups and self.container.get_first_child():
            first = self.container.get_first_child()
            if isinstance(first, Gtk.Label):
                self.container.remove(first)
        
        # Add/update buttons
        for group in app_groups:
            if group.wm_class in self.buttons:
                # Update existing
                self.buttons[group.wm_class].update(group)
            else:
                # Add new
                button = TaskbarButton(group, self)
                self.buttons[group.wm_class] = button
                self.container.append(button)
        
        # Show placeholder if no apps
        if not app_groups:
            if not self.container.get_first_child():
                placeholder = Gtk.Label(label="No windows")
                placeholder.set_opacity(0.5)
                self.container.append(placeholder)
        
        return False  # Don't repeat
    
    # ==========================================
    # ACTIONS
    # ==========================================
    
    def focus_window(self, address: str):
        """Focus a specific window"""
        if self._async_loop and self.tracker:
            asyncio.run_coroutine_threadsafe(
                self.tracker.focus_window(address),
                self._async_loop
            )
    
    def close_window(self, address: str):
        """Close a specific window"""
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
    
    def cleanup(self):
        """Cleanup on close"""
        if self.tracker:
            self.tracker.stop()
        if self._async_loop:
            self._async_loop.call_soon_threadsafe(self._async_loop.stop)


class TaskbarApp(Adw.Application):
    """Taskbar application"""
    
    def __init__(self):
        super().__init__(
            application_id="com.hyprland.taskbar",
            flags=Gio.ApplicationFlags.FLAGS_NONE
        )
        self.window = None
    
    def do_activate(self):
        if self.window:
            self.window.present()
            return
        
        self.window = TaskbarWidget(self)
        self.window.present()
        
        print("[TaskbarApp] Window presented")


def main():
    """Main entry point"""
    print("""
╔══════════════════════════════════════════════════════════╗
║            HYPRLAND TASKBAR WIDGET                       ║
╚══════════════════════════════════════════════════════════╝
""")
    
    if not HAS_LAYER_SHELL:
        print("WARNING: Running without GTK4 Layer Shell")
        print("         Taskbar will appear as regular window\n")
    
    app = TaskbarApp()
    
    try:
        app.run(None)
    except KeyboardInterrupt:
        print("\nShutting down...")
        if app.window:
            app.window.cleanup()


if __name__ == "__main__":
    main()