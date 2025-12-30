"""
Main window for Hyprland Control Center
COMPLETE VERSION with white icons fix
"""

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
from gi.repository import Gtk, Adw, Gdk

from .config_manager import HyprlandConfigManager
from .styles import get_css
from .pages.appearance import build_appearance_page
from .pages.panel import build_panel_page
from .pages.themes import build_themes_page
from .pages.displays import build_displays_page
from .pages.power import build_power_page
from .pages.notifications import build_notifications_page
from .pages.wallpaper import build_wallpaper_page
from .pages.placeholders import (
    build_workspaces_page, build_animations_page,
    build_input_page, build_keybinds_page
)


class ControlCenterWindow(Adw.ApplicationWindow):
    """Main application window"""
    
    def __init__(self, app):
        super().__init__(application=app)
        
        # Window properties
        self.set_title("Hyprland Control Center")
        
        # Initialize managers
        self.config_manager = HyprlandConfigManager()
        self.waybar_manager = None  # Will be imported when needed
        
        # Initialize theme manager
        from .theme_manager import ThemeManager
        self.theme_manager = ThemeManager()
        
        # Detect monitor size and set window size
        self._set_window_size()
        
        # Apply CSS
        self._apply_css()
        
        # Build UI
        self._build_ui()
    
    def _set_window_size(self):
        """Set window size based on monitor resolution"""
        try:
            # Get display and monitor info
            display = Gdk.Display.get_default()
            if display:
                monitors = display.get_monitors()
                if monitors and monitors.get_n_items() > 0:
                    monitor = monitors.get_item(0)
                    geometry = monitor.get_geometry()
                    width = geometry.width
                    height = geometry.height
                    
                    # Set to 70% of monitor size
                    window_width = int(width * 0.7)
                    window_height = int(height * 0.7)
                    
                    # Clamp to reasonable limits
                    window_width = max(900, min(window_width, 1400))
                    window_height = max(650, min(window_height, 900))
                    
                    self.set_default_size(window_width, window_height)
                    return
        except:
            pass
        
        # Fallback to reasonable default
        self.set_default_size(1100, 750)
        
    def _apply_css(self):
        """Apply themed CSS"""
        css = get_css()
        
        provider = Gtk.CssProvider()
        provider.load_from_data(css.encode())
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )
    
    def _generate_themed_css(self, colors: dict) -> str:
        """Generate CSS with theme colors for dynamic theme switching"""
        from .styles import get_css
        return get_css()
    
    def _build_ui(self):
        """Build the main UI"""
        # Toast overlay wrapper
        self.toast_overlay = Adw.ToastOverlay()
        self.set_content(self.toast_overlay)
        
        # Main horizontal box
        main_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        self.toast_overlay.set_child(main_box)
        
        # Sidebar
        sidebar = self._build_sidebar()
        main_box.append(sidebar)
        
        # Content area with stack
        self.stack = Gtk.Stack()
        self.stack.set_transition_type(Gtk.StackTransitionType.SLIDE_LEFT_RIGHT)
        self.stack.set_transition_duration(200)
        self.stack.add_css_class('content-area')
        
        # Add pages
        self.stack.add_named(build_wallpaper_page(self), "wallpaper")
        self.stack.add_named(build_appearance_page(self), "appearance")
        self.stack.add_named(build_panel_page(self), "panel")
        self.stack.add_named(build_notifications_page(self), "notifications")
        self.stack.add_named(build_themes_page(self), "themes")
        self.stack.add_named(build_workspaces_page(self), "workspaces")
        self.stack.add_named(build_animations_page(self), "animations")
        self.stack.add_named(build_input_page(self), "input")
        self.stack.add_named(build_displays_page(self), "displays")
        self.stack.add_named(build_power_page(self), "power")
        self.stack.add_named(build_keybinds_page(self), "keybinds")
        
        main_box.append(self.stack)
        
        # Show wallpaper page by default
        self.stack.set_visible_child_name("wallpaper")
    
    def _build_sidebar(self) -> Gtk.Box:
        """Build navigation sidebar"""
        sidebar = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        sidebar.set_size_request(240, -1)
        sidebar.add_css_class('sidebar')
        
        # Title
        title = Gtk.Label(label="Settings")
        title.add_css_class('sidebar-title')
        title.set_halign(Gtk.Align.START)
        title.set_margin_top(16)
        title.set_margin_bottom(16)
        title.set_margin_start(16)
        title.set_margin_end(16)
        sidebar.append(title)
        
        # List box for navigation
        list_box = Gtk.ListBox()
        list_box.set_selection_mode(Gtk.SelectionMode.SINGLE)
        list_box.connect('row-selected', self._on_nav_changed)
        list_box.add_css_class('sidebar-list')
        
        # Navigation sections
        nav_sections = [
            ("DESKTOP", [
                ("Wallpaper", "wallpaper", "preferences-desktop-wallpaper-symbolic"),
                ("Appearance", "appearance", "preferences-desktop-appearance-symbolic"),
                ("Panel", "panel", "view-paged-symbolic"),
                ("Notifications", "notifications", "preferences-system-notifications-symbolic"),
                ("Theme Switcher", "themes", "applications-graphics-symbolic"),
                ("Workspaces", "workspaces", "view-grid-symbolic"),
            ]),
            ("SYSTEM", [
                ("Animations", "animations", "preferences-desktop-animation-symbolic"),
                ("Input Devices", "input", "input-keyboard-symbolic"),
                ("Displays", "displays", "video-display-symbolic"),
                ("Power & Battery", "power", "battery-symbolic"),
                ("Keybinds", "keybinds", "preferences-desktop-keyboard-shortcuts-symbolic"),
            ]),
        ]
        
        for section_title, items in nav_sections:
            # Section header
            header = Gtk.Label(label=section_title)
            header.add_css_class('sidebar-section')
            header.set_halign(Gtk.Align.START)
            sidebar.append(header)
            
            # Items
            for label, page_name, icon_name in items:
                row = Gtk.ListBoxRow()
                row.set_name(page_name)
                
                box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
                box.add_css_class('sidebar-item')
                
                # FORCE WHITE ICONS!
                icon = Gtk.Image.new_from_icon_name(icon_name)
                icon.set_pixel_size(18)
                icon.add_css_class('sidebar-icon')
                icon.add_css_class('force-white')
                box.append(icon)
                
                lbl = Gtk.Label(label=label)
                lbl.set_halign(Gtk.Align.START)
                box.append(lbl)
                
                row.set_child(box)
                list_box.append(row)
        
        # Select first actual item (skip section header)
        list_box.select_row(list_box.get_row_at_index(1))
        
        sidebar.append(list_box)
        
        # Spacer
        spacer = Gtk.Box()
        spacer.set_vexpand(True)
        sidebar.append(spacer)
        
        # Version info
        version_label = Gtk.Label(label="v1.0.0")
        version_label.add_css_class('dim-label')
        version_label.set_margin_bottom(16)
        sidebar.append(version_label)
        
        return sidebar
    
    def _on_nav_changed(self, list_box, row):
        """Handle navigation selection"""
        if row:
            page_name = row.get_name()
            self.stack.set_visible_child_name(page_name)
    
    def _show_toast(self, message: str):
        """Show toast notification"""
        toast = Adw.Toast(title=message)
        toast.set_timeout(3)
        self.toast_overlay.add_toast(toast)
    
    def _apply_theme_to_ui(self, theme_id: str):
        """Apply theme colors to Control Center UI immediately"""
        from .theme_manager import ThemeManager
        
        theme_mgr = ThemeManager()
        colors = theme_mgr.get_theme_colors(theme_id)
        
        if colors:
            # Regenerate CSS with new theme
            css = self._generate_themed_css(colors)
            
            # Re-apply CSS
            css_provider = Gtk.CssProvider()
            css_provider.load_from_string(css)
            
            Gtk.StyleContext.add_provider_for_display(
                Gdk.Display.get_default(),
                css_provider,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            )