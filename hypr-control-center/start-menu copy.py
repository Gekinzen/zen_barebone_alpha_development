#!/usr/bin/env python3
"""
Hyprland Start Menu
Windows 11-style launcher with pinned apps, search, and power controls
Location: ~/.config/hypr-control-center/start-menu.py
"""

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
gi.require_version('Gdk', '4.0')
from gi.repository import Gtk, Adw, GLib, Gio, GdkPixbuf, Gdk
import json
import subprocess
import os
import sys
import re
from pathlib import Path

print("Starting Start Menu...")  # Debug

class StartMenu(Gtk.ApplicationWindow):
    def __init__(self, app):
        print("Initializing StartMenu window...")  # Debug
        super().__init__(application=app, title="Start Menu")
        
        # Paths
        self.config_dir = Path.home() / ".config/hypr-control-center"
        self.assets_dir = self.config_dir / "assets"
        self.pinned_file = self.config_dir / "preferences/start-menu-pinned.json"
        
        # Ensure directories exist
        self.pinned_file.parent.mkdir(parents=True, exist_ok=True)
        print(f"Config dir: {self.config_dir}")  # Debug
        
        # Load data
        print("Loading pinned apps...")  # Debug
        self.pinned_apps = self.load_pinned_apps()
        print(f"Pinned apps: {self.pinned_apps}")  # Debug
        
        print("Loading all apps...")  # Debug
        self.all_apps = self.load_all_apps()
        print(f"Found {len(self.all_apps)} apps")  # Debug
        
        # Window setup
        self.set_default_size(800, 600)
        self.set_resizable(False)
        
        # Remove hyprbars decorations
        self.set_decorated(False)
        
        # Track if we should monitor for close
        self.last_active_window = None
        self.click_outside_enabled = False
        
        # Load CSS
        print("Loading CSS...")  # Debug
        self.load_css()
        
        # Build UI
        print("Building UI...")  # Debug
        self.build_ui()
        
        # Setup click outside to close (disabled by default)
        # We'll enable it only after detecting an actual click
        # self.setup_click_outside_close()
        
        print("StartMenu initialized!")  # Debug
        print("Note: Click-outside-to-close is DISABLED due to focus-follows-mouse")
        print("Use ESC key or launch an app to close")
        
    def load_css(self):
        """Load CSS from assets/style.css"""
        css_file = self.assets_dir / "style.css"
        if css_file.exists():
            try:
                css_provider = Gtk.CssProvider()
                css_provider.load_from_path(str(css_file))
                Gtk.StyleContext.add_provider_for_display(
                    self.get_display(),
                    css_provider,
                    Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
                )
                print(f"CSS loaded from {css_file}")  # Debug
            except Exception as e:
                print(f"CSS load error: {e}")  # Debug
        else:
            print(f"CSS file not found: {css_file}")  # Debug
    
    def load_pinned_apps(self):
        """Load pinned apps from JSON"""
        try:
            if self.pinned_file.exists():
                with open(self.pinned_file, 'r') as f:
                    data = json.load(f)
                    return data.get('pinned', [])
            else:
                # Default pinned apps
                default = ["firefox", "code", "thunar", "kitty"]
                self.save_pinned_apps(default)
                return default
        except Exception as e:
            print(f"Error loading pinned apps: {e}")
            return []
    
    def save_pinned_apps(self, apps):
        """Save pinned apps to JSON"""
        try:
            with open(self.pinned_file, 'w') as f:
                json.dump({'pinned': apps}, f, indent=2)
            print(f"Saved pinned apps: {apps}")  # Debug
        except Exception as e:
            print(f"Error saving pinned apps: {e}")
    
    def pin_app(self, app_id):
        """Pin an app"""
        if app_id not in self.pinned_apps:
            self.pinned_apps.append(app_id)
            self.save_pinned_apps(self.pinned_apps)
            self.refresh_pinned_section()
    
    def unpin_app(self, app_id):
        """Unpin an app"""
        if app_id in self.pinned_apps:
            self.pinned_apps.remove(app_id)
            self.save_pinned_apps(self.pinned_apps)
            self.refresh_pinned_section()
    
    def get_app_id(self, app_info):
        """Get simplified app ID from app info - use full name for better matching"""
        # Use the full app name as ID for better accuracy
        name = app_info['name'].lower()
        
        # Clean up but keep distinctiveness
        # Keep alphanumeric and spaces
        name = re.sub(r'[^\w\s]', '', name)
        # Replace spaces with hyphens
        name = name.replace(' ', '-')
        # Remove consecutive hyphens
        name = re.sub(r'-+', '-', name)
        
        return name.strip('-')[:50]  # Use longer ID for uniqueness
    
    def is_pinned(self, app_info):
        """Check if app is pinned"""
        app_id = self.get_app_id(app_info)
        return app_id in self.pinned_apps
    
    def load_all_apps(self):
        """Load all installed applications from .desktop files"""
        apps = []
        desktop_dirs = [
            Path("/usr/share/applications"),
            Path("/usr/local/share/applications"),
            Path.home() / ".local/share/applications"
        ]
        
        for desktop_dir in desktop_dirs:
            if not desktop_dir.exists():
                continue
            
            try:
                for desktop_file in desktop_dir.glob("*.desktop"):
                    try:
                        app_info = self.parse_desktop_file(desktop_file)
                        if app_info:
                            apps.append(app_info)
                    except Exception as e:
                        # Silently skip problematic .desktop files
                        pass
            except Exception as e:
                print(f"Error scanning {desktop_dir}: {e}")
        
        # Sort by name
        apps.sort(key=lambda x: x['name'].lower())
        return apps
    
    def parse_desktop_file(self, desktop_file):
        """Parse .desktop file for app info"""
        try:
            with open(desktop_file, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
        except:
            return None
        
        # Extract Name
        name = None
        for line in content.split('\n'):
            if line.startswith('Name='):
                name = line.split('=', 1)[1].strip()
                break
        
        if not name or 'NoDisplay=true' in content:
            return None
        
        # Extract Icon
        icon = None
        for line in content.split('\n'):
            if line.startswith('Icon='):
                icon = line.split('=', 1)[1].strip()
                break
        
        # Extract Exec
        exec_cmd = None
        for line in content.split('\n'):
            if line.startswith('Exec='):
                exec_cmd = line.split('=', 1)[1].strip()
                # Remove field codes
                exec_cmd = exec_cmd.replace('%U', '').replace('%F', '').replace('%u', '').replace('%f', '').strip()
                break
        
        return {
            'name': name,
            'icon': icon,
            'exec': exec_cmd,
            'desktop_file': str(desktop_file)
        }
    
    def build_ui(self):
        """Build the main UI"""
        main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        main_box.add_css_class("start-menu")
        
        # Content area (split left/right)
        content = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        content.set_vexpand(True)
        
        # LEFT SIDE - Pinned Apps
        self.left_side = self.create_left_side()
        content.append(self.left_side)
        
        # RIGHT SIDE - All Apps
        right_side = self.create_right_side()
        content.append(right_side)
        
        main_box.append(content)
        
        # BOTTOM BAR - User info and controls
        bottom_bar = self.create_bottom_bar()
        main_box.append(bottom_bar)
        
        self.set_child(main_box)
        print("UI built successfully!")  # Debug
    
    def create_left_side(self):
        """Create left side with pinned apps"""
        left_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16)
        left_box.add_css_class("start-left")
        left_box.set_size_request(400, -1)
        
        # Pinned section
        pinned_label = Gtk.Label(label="Pinned")
        pinned_label.add_css_class("section-title")
        pinned_label.set_xalign(0)
        left_box.append(pinned_label)
        
        # Pinned apps grid
        self.pinned_grid = Gtk.FlowBox()
        self.pinned_grid.set_valign(Gtk.Align.START)
        self.pinned_grid.set_max_children_per_line(5)
        self.pinned_grid.set_column_spacing(8)
        self.pinned_grid.set_row_spacing(8)
        self.pinned_grid.set_selection_mode(Gtk.SelectionMode.NONE)
        
        self.refresh_pinned_section()
        
        left_box.append(self.pinned_grid)
        
        # Wrap in scrolled window
        scroll = Gtk.ScrolledWindow()
        scroll.set_child(left_box)
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroll.set_margin_start(20)
        scroll.set_margin_end(20)
        scroll.set_margin_top(20)
        scroll.set_margin_bottom(20)
        
        return scroll
    
    def refresh_pinned_section(self):
        """Refresh pinned apps grid"""
        # Clear existing
        while True:
            child = self.pinned_grid.get_first_child()
            if child is None:
                break
            self.pinned_grid.remove(child)
        
        # Add pinned apps
        for app_id in self.pinned_apps:
            app_info = self.find_app_by_id(app_id)
            if app_info:
                app_button = self.create_app_tile(app_info)
                self.pinned_grid.append(app_button)
    
    def create_right_side(self):
        """Create right side with all apps and search"""
        right_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        right_box.add_css_class("start-right")
        right_box.set_size_request(400, -1)
        
        # Header
        header = Gtk.Label(label="All Apps")
        header.add_css_class("section-title")
        header.set_xalign(0)
        right_box.append(header)
        
        # Search bar
        search_entry = Gtk.SearchEntry()
        search_entry.set_placeholder_text("Type here to search")
        search_entry.add_css_class("search-entry")
        search_entry.connect("search-changed", self.on_search_changed)
        right_box.append(search_entry)
        
        # Apps list
        self.apps_list_box = Gtk.ListBox()
        self.apps_list_box.add_css_class("apps-list")
        self.apps_list_box.set_selection_mode(Gtk.SelectionMode.NONE)
        self.apps_list_box.connect("row-activated", self.on_app_activated)
        
        # Populate apps (grouped by letter)
        self.populate_apps_list()
        
        # Scrolled window for apps
        scroll = Gtk.ScrolledWindow()
        scroll.set_child(self.apps_list_box)
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroll.set_vexpand(True)
        right_box.append(scroll)
        
        # Wrap in box with margins
        wrapper = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        wrapper.append(right_box)
        wrapper.set_margin_start(20)
        wrapper.set_margin_end(20)
        wrapper.set_margin_top(20)
        wrapper.set_margin_bottom(20)
        
        return wrapper
    
    def populate_apps_list(self, filter_text=""):
        """Populate apps list with optional filtering"""
        # Clear existing
        while True:
            row = self.apps_list_box.get_row_at_index(0)
            if row is None:
                break
            self.apps_list_box.remove(row)
        
        # Filter apps
        filtered_apps = [app for app in self.all_apps 
                        if filter_text.lower() in app['name'].lower()]
        
        # Group by first letter
        groups = {}
        for app in filtered_apps:
            first_letter = app['name'][0].upper()
            if first_letter not in groups:
                groups[first_letter] = []
            groups[first_letter].append(app)
        
        # Add to list
        for letter in sorted(groups.keys()):
            # Letter header
            if not filter_text:  # Only show letter headers when not searching
                header_label = Gtk.Label(label=letter)
                header_label.add_css_class("letter-header")
                header_label.set_xalign(0)
                header_row = Gtk.ListBoxRow()
                header_row.set_selectable(False)
                header_row.set_activatable(False)
                header_row.set_child(header_label)
                self.apps_list_box.append(header_row)
            
            # Apps
            for app in groups[letter]:
                app_row = self.create_app_row(app)
                self.apps_list_box.append(app_row)
    
    def create_app_tile(self, app_info):
        """Create pinned app tile with right-click context menu"""
        button = Gtk.Button()
        button.add_css_class("app-tile")
        button.connect("clicked", lambda b: self.launch_app(app_info))
        
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        
        # Icon
        icon = self.create_app_icon(app_info['icon'], 48)
        box.append(icon)
        
        # Name
        label = Gtk.Label(label=app_info['name'])
        label.add_css_class("app-tile-label")
        label.set_max_width_chars(10)
        label.set_ellipsize(3)  # ELLIPSIZE_END
        label.set_justify(Gtk.Justification.CENTER)
        box.append(label)
        
        button.set_child(box)
        
        # Right-click context menu for pinned apps
        gesture = Gtk.GestureClick.new()
        gesture.set_button(3)  # Right click
        gesture.connect("pressed", lambda g, n, x, y: self.show_pinned_context_menu(button, app_info))
        button.add_controller(gesture)
        
        return button
    
    def create_app_row(self, app_info):
        """Create app list row with right-click context menu"""
        row = Gtk.ListBoxRow()
        row.add_css_class("app-row")
        row.set_activatable(True)
        row.app_info = app_info  # Store app info
        
        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        box.set_margin_start(12)
        box.set_margin_end(12)
        box.set_margin_top(8)
        box.set_margin_bottom(8)
        
        # Icon
        icon = self.create_app_icon(app_info['icon'], 32)
        box.append(icon)
        
        # Name
        label = Gtk.Label(label=app_info['name'])
        label.set_xalign(0)
        label.set_hexpand(True)
        box.append(label)
        
        # Pin status indicator
        if self.is_pinned(app_info):
            pin_icon = Gtk.Image.new_from_icon_name("emblem-favorite")
            pin_icon.set_pixel_size(16)
            pin_icon.add_css_class("pin-indicator")
            box.append(pin_icon)
        
        row.set_child(box)
        
        # Right-click context menu
        gesture = Gtk.GestureClick.new()
        gesture.set_button(3)  # Right click
        gesture.connect("pressed", lambda g, n, x, y: self.show_app_context_menu(row, app_info))
        row.add_controller(gesture)
        
        return row
    
    def show_pinned_context_menu(self, widget, app_info):
        """Show context menu for pinned app"""
        menu = Gio.Menu()
        menu.append("Unpin", "app.unpin")
        menu.append("Close All Windows", "app.close-app")
        
        popover = Gtk.PopoverMenu()
        popover.set_menu_model(menu)
        popover.set_parent(widget)
        
        # Store app info for actions
        widget.app_info = app_info
        popover.app_info = app_info
        
        # Store reference to current app_info in window for action handlers
        win = widget.get_root()
        if win:
            win.current_context_app = app_info
        
        popover.popup()
    
    def show_app_context_menu(self, widget, app_info):
        """Show context menu for all apps list"""
        menu = Gio.Menu()
        
        if self.is_pinned(app_info):
            menu.append("Unpin from Start", "app.unpin")
        else:
            menu.append("Pin to Start", "app.pin")
        
        menu.append("Close All Windows", "app.close-app")
        
        popover = Gtk.PopoverMenu()
        popover.set_menu_model(menu)
        popover.set_parent(widget)
        
        # Store app info for actions - store on both widget and popover
        widget.app_info = app_info
        popover.app_info = app_info
        
        # Store reference to current app_info in window for action handlers
        win = widget.get_root()
        if win:
            win.current_context_app = app_info
        
        popover.popup()
    
    def create_app_icon(self, icon_name, size):
        """Create app icon widget"""
        if icon_name and icon_name.startswith('/') and os.path.exists(icon_name):
            # Absolute path icon - load directly as paintable
            try:
                # Use GdkPixbuf to load and scale
                pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(
                    icon_name, size, size, True
                )
                # Create Image from pixbuf (no deprecation warning)
                icon = Gtk.Image.new_from_pixbuf(pixbuf)
                icon.set_pixel_size(size)
                return icon
            except Exception as e:
                # Silently fall through to icon name
                pass
        
        # Try icon name from theme
        icon = Gtk.Image.new_from_icon_name(icon_name or "application-x-executable")
        icon.set_pixel_size(size)
        return icon
    
    def create_bottom_bar(self):
        """Create bottom bar with user info and power buttons"""
        bar = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        bar.add_css_class("bottom-bar")
        bar.set_margin_start(20)
        bar.set_margin_end(20)
        bar.set_margin_top(12)
        bar.set_margin_bottom(20)
        
        # User info
        user_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        
        # Avatar
        avatar = Gtk.Image.new_from_icon_name("avatar-default")
        avatar.set_pixel_size(40)
        avatar.add_css_class("user-avatar")
        user_box.append(avatar)
        
        # Name
        username = os.getenv("USER", "User")
        user_label = Gtk.Label(label=username.capitalize())
        user_label.add_css_class("user-name")
        user_box.append(user_label)
        
        bar.append(user_box)
        
        # Spacer
        spacer = Gtk.Box()
        spacer.set_hexpand(True)
        bar.append(spacer)
        
        # Folder button
        folder_btn = Gtk.Button()
        folder_btn.set_icon_name("folder")
        folder_btn.add_css_class("icon-button")
        folder_btn.set_tooltip_text("Files")
        folder_btn.connect("clicked", lambda b: self.launch_thunar())
        bar.append(folder_btn)
        
        # Settings button
        settings_btn = Gtk.Button()
        settings_btn.set_icon_name("emblem-system")
        settings_btn.add_css_class("icon-button")
        settings_btn.set_tooltip_text("Settings")
        settings_btn.connect("clicked", lambda b: self.launch_control_center())
        bar.append(settings_btn)
        
        # Power menu button
        power_btn = Gtk.MenuButton()
        power_btn.set_icon_name("system-shutdown")
        power_btn.add_css_class("icon-button")
        power_btn.set_tooltip_text("Power")
        
        # Power menu
        power_menu = Gio.Menu()
        power_menu.append("🔒 Lock", "app.lock")
        power_menu.append("🚪 Logout", "app.logout")
        power_menu.append("🔄 Restart", "app.restart")
        power_menu.append("⏻ Shutdown", "app.shutdown")
        power_btn.set_menu_model(power_menu)
        
        bar.append(power_btn)
        
        return bar
    
    def find_app_by_id(self, app_id):
        """Find app info by ID (exact match first, then partial)"""
        # Try exact match first
        for app in self.all_apps:
            if self.get_app_id(app) == app_id:
                return app
        
        # Fallback to partial match for backward compatibility
        app_id_lower = app_id.lower()
        for app in self.all_apps:
            if app_id_lower in app['name'].lower():
                return app
        
        return None
    
    def launch_app(self, app_info):
        """Launch an application"""
        if app_info and app_info['exec']:
            try:
                subprocess.Popen(app_info['exec'], shell=True)
                self.close()
            except Exception as e:
                print(f"Failed to launch {app_info['name']}: {e}")
    
    def launch_thunar(self):
        """Launch file manager"""
        subprocess.Popen(['thunar'])
        self.close()
    
    def launch_control_center(self):
        """Launch Hyprland Control Center"""
        subprocess.Popen(['python3', str(self.config_dir / 'main.py')])
        self.close()
    
    def on_app_activated(self, list_box, row):
        """Handle app row activation"""
        if hasattr(row, 'app_info'):
            self.launch_app(row.app_info)
    
    def on_search_changed(self, search_entry):
        """Handle search text change"""
        search_text = search_entry.get_text()
        self.populate_apps_list(search_text)

class StartMenuApp(Gtk.Application):
    def __init__(self):
        print("Initializing StartMenuApp...")  # Debug
        super().__init__(application_id="com.hyprland.startmenu",
                        flags=Gio.ApplicationFlags.FLAGS_NONE)
        
    def do_activate(self):
        print("do_activate() called")  # Debug
        # Check if already running
        windows = self.get_windows()
        if windows:
            # Already open, just present it
            print("Window already exists, presenting...")  # Debug
            windows[0].present()
            return
        
        print("Creating new window...")  # Debug
        # Create new window
        win = StartMenu(self)
        
        # Add pin/unpin actions
        pin_action = Gio.SimpleAction.new("pin", None)
        pin_action.connect("activate", self.on_pin)
        self.add_action(pin_action)
        
        unpin_action = Gio.SimpleAction.new("unpin", None)
        unpin_action.connect("activate", self.on_unpin)
        self.add_action(unpin_action)
        
        close_app_action = Gio.SimpleAction.new("close-app", None)
        close_app_action.connect("activate", self.on_close_app)
        self.add_action(close_app_action)
        
        # Add power actions
        lock_action = Gio.SimpleAction.new("lock", None)
        lock_action.connect("activate", self.on_lock)
        self.add_action(lock_action)
        
        logout_action = Gio.SimpleAction.new("logout", None)
        logout_action.connect("activate", self.on_logout)
        self.add_action(logout_action)
        
        restart_action = Gio.SimpleAction.new("restart", None)
        restart_action.connect("activate", self.on_restart)
        self.add_action(restart_action)
        
        shutdown_action = Gio.SimpleAction.new("shutdown", None)
        shutdown_action.connect("activate", self.on_shutdown)
        self.add_action(shutdown_action)
        
        print("Presenting window...")  # Debug
        win.present()
        print("Window presented!")  # Debug
    
    def get_active_window_app_info(self):
        """Get app info from the current context"""
        win = self.get_active_window()
        if win and hasattr(win, 'current_context_app'):
            return win.current_context_app
        return None
    
    def on_pin(self, action, param):
        """Pin app to start"""
        app_info = self.get_active_window_app_info()
        if app_info:
            win = self.get_active_window()
            app_id = win.get_app_id(app_info)
            print(f"Pinning: {app_info['name']} (ID: {app_id})")  # Debug
            win.pin_app(app_id)
            # Refresh all apps list to show pin indicator
            win.populate_apps_list()
    
    def on_unpin(self, action, param):
        """Unpin app from start"""
        app_info = self.get_active_window_app_info()
        if app_info:
            win = self.get_active_window()
            app_id = win.get_app_id(app_info)
            print(f"Unpinning: {app_info['name']} (ID: {app_id})")  # Debug
            win.unpin_app(app_id)
            # Refresh all apps list to remove pin indicator
            win.populate_apps_list()
    
    def on_close_app(self, action, param):
        """Close all windows of app"""
        app_info = self.get_active_window_app_info()
        if app_info:
            # Get app class/name for hyprctl
            app_class = app_info['name'].split()[0].lower()
            subprocess.Popen(['hyprctl', 'dispatch', 'closewindow', f'class:{app_class}'])
    
    def on_lock(self, action, param):
        """Lock screen"""
        subprocess.Popen(['hyprlock'])
        self.quit()
    
    def on_logout(self, action, param):
        """Logout"""
        subprocess.Popen(['hyprctl', 'dispatch', 'exit'])
        self.quit()
    
    def on_restart(self, action, param):
        """Restart"""
        subprocess.Popen(['systemctl', 'reboot'])
        self.quit()
    
    def on_shutdown(self, action, param):
        """Shutdown"""
        subprocess.Popen(['systemctl', 'poweroff'])
        self.quit()

if __name__ == "__main__":
    print("__main__ executed")  # Debug
    app = StartMenuApp()
    print("Running app...")  # Debug
    sys.exit(app.run(None))