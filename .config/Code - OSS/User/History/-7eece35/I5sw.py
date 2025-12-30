"""
Main Control Center Window
"""

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
gi.require_version('Gdk', '4.0')
from gi.repository import Gtk, Adw, Gdk
from typing import Callable

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
    """Main Control Center Window"""
    
    def __init__(self, app):
        super().__init__(application=app)
        
        self.set_title("Hyprland Control Center")
        
        # Auto-detect monitor size and set appropriate window size
        self._set_optimal_window_size()
        
        # Allow window resizing
        self.set_resizable(True)
        
        # Check theme source mode
        from .theme_manager import ThemeManager
        theme_mgr = ThemeManager()
        theme_source = theme_mgr.get_theme_source_mode()
        
        # Apply color scheme based on mode
        style_manager = Adw.StyleManager.get_default()
        if theme_source == "gtk":
            # Follow system GTK theme
            style_manager.set_color_scheme(Adw.ColorScheme.DEFAULT)
        else:
            # Force dark for custom themes
            style_manager.set_color_scheme(Adw.ColorScheme.FORCE_DARK)
        
        # Config manager
        self.config = HyprlandConfigManager()
        self.config.parse_look_and_feel()
        
        # Widget references
        self.widgets = {}
        
        # Apply CSS
        self._apply_css()
        
        # Build UI
        self._build_ui()
    
    def _set_optimal_window_size(self):
        """Set window size based on monitor dimensions"""
        try:
            import subprocess
            import json
            
            # Get monitor info from hyprctl
            result = subprocess.run(
                ['hyprctl', 'monitors', '-j'],
                capture_output=True,
                text=True,
                timeout=2
            )
            
            if result.returncode == 0:
                monitors = json.loads(result.stdout)
                if monitors:
                    # Get active monitor dimensions
                    active = monitors[0]
                    width = active.get('width', 1920)
                    height = active.get('height', 1080)
                    
                    # Set window to 70% of monitor size (responsive)
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
        """Apply themed CSS - respects theme source mode"""
        from .theme_manager import ThemeManager
        
        # Get theme source mode
        theme_mgr = ThemeManager()
        theme_source = theme_mgr.get_theme_source_mode()
        
        if theme_source == "gtk":
            # Use GTK system theme - just load base CSS
            from .styles import get_css
            css = get_css()
        else:
            # Use custom color scheme
            current_theme = theme_mgr.get_current_theme()
            colors = theme_mgr.get_theme_colors(current_theme)
            css = self._generate_themed_css(colors)
        
        provider = Gtk.CssProvider()
        provider.load_from_data(css.encode())
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )
    
    def _generate_themed_css(self, colors: dict) -> str:
        """Generate CSS with theme colors"""
        # Get base CSS template
        from .styles import get_css_template
        
        # Format template with new theme colors
        css = get_css_template().format(**colors)
        
        return css
    
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
        
        # Scrolled window for content
        scrolled = Gtk.ScrolledWindow()
        scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scrolled.set_hexpand(True)
        scrolled.set_vexpand(True)
        scrolled.add_css_class('content-area')
        
        # Content stack
        self.stack = Gtk.Stack()
        self.stack.set_transition_type(Gtk.StackTransitionType.CROSSFADE)
        self.stack.set_transition_duration(200)
        self.stack.set_hexpand(True)
        self.stack.set_vexpand(True)
        
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
        
        scrolled.set_child(self.stack)
        main_box.append(scrolled)
    
    def _build_sidebar(self) -> Gtk.Box:
        """Build sidebar navigation"""
        sidebar = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        sidebar.add_css_class('sidebar')
        sidebar.set_size_request(240, -1)
        
        # App title
        title = Gtk.Label(label="⚙ Settings")
        title.add_css_class('sidebar-title')
        title.set_halign(Gtk.Align.START)
        sidebar.append(title)
        
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
                ("Animations", "animations", "preferences-desktop-effects-symbolic"),
                ("Input Devices", "input", "input-keyboard-symbolic"),
                ("Displays", "displays", "video-display-symbolic"),
                ("Power & Battery", "power", "battery-symbolic"),
                ("Keybinds", "keybinds", "preferences-desktop-keyboard-shortcuts-symbolic"),
            ]),
        ]
        
        list_box = Gtk.ListBox()
        list_box.set_selection_mode(Gtk.SelectionMode.SINGLE)
        list_box.connect('row-activated', self._on_nav_activated)
        
        for section_name, items in nav_sections:
            # Section header (as a non-selectable row)
            section_row = Gtk.ListBoxRow()
            section_row.set_selectable(False)
            section_row.set_activatable(False)
            section_label = Gtk.Label(label=section_name)
            section_label.add_css_class('sidebar-section')
            section_label.set_halign(Gtk.Align.START)
            section_row.set_child(section_label)
            list_box.append(section_row)
            
            # Items
            for label, page_name, icon_name in items:
                row = Gtk.ListBoxRow()
                row.set_name(page_name)
                
                box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
                box.add_css_class('sidebar-item')
                
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
        version = Gtk.Label(label="v1.0.0")
        version.add_css_class('setting-description')
        version.set_margin_bottom(4)
        sidebar.append(version)
        
        # Credits
        credits = Gtk.Label(label="Created by Gekinzen")
        credits.add_css_class('dim-label')
        credits.set_margin_bottom(12)
        sidebar.append(credits)
        
        # About button
        about_btn = Gtk.Button(label="About")
        about_btn.add_css_class('flat')
        about_btn.connect('clicked', self._show_about_dialog)
        about_btn.set_margin_bottom(16)
        sidebar.append(about_btn)
        
        return sidebar
    
    def _on_nav_activated(self, list_box, row):
        """Handle navigation selection"""
        if row and row.get_selectable():
            page_name = row.get_name()
            if page_name:
                self.stack.set_visible_child_name(page_name)
    
    # ═══════════════════════════════════════════════════════════════════════════
    # APPEARANCE PAGE HANDLERS
    # ═══════════════════════════════════════════════════════════════════════════
    
    def _on_appearance_reset(self, btn):
        """Reset appearance to default"""
        dialog = Adw.MessageDialog(
            transient_for=self,
            heading="Reset to Default?",
            body="This will restore appearance settings from the default configuration."
        )
        dialog.add_response("cancel", "Cancel")
        dialog.add_response("reset", "Reset")
        dialog.set_response_appearance("reset", Adw.ResponseAppearance.DESTRUCTIVE)
        dialog.connect('response', self._on_appearance_reset_response)
        dialog.present()
    
    def _on_appearance_reset_response(self, dialog, response):
        if response == "reset":
            if self.config.reset_look_and_feel():
                self._refresh_appearance_widgets()
                self._show_toast("Settings reset to default")
            else:
                self._show_toast("Default configuration not found")
    
    def _on_appearance_apply(self, btn):
        """Apply appearance changes"""
        self.config.save_look_and_feel()
        self._show_toast("Appearance settings applied")
    
    def _refresh_appearance_widgets(self):
        """Refresh appearance widgets with current values"""
        widget_map = {
            'gaps_in': self.config.general.gaps_in,
            'gaps_out': self.config.general.gaps_out,
            'border_size': self.config.general.border_size,
            'col_active_border': self.config.general.col_active_border,
            'col_inactive_border': self.config.general.col_inactive_border,
            'resize_on_border': self.config.general.resize_on_border,
            'allow_tearing': self.config.general.allow_tearing,
            'layout': self.config.general.layout,
            'rounding': self.config.decoration.rounding,
            'rounding_power': self.config.decoration.rounding_power,
            'active_opacity': self.config.decoration.active_opacity,
            'inactive_opacity': self.config.decoration.inactive_opacity,
            'shadow_enabled': self.config.decoration.shadow_enabled,
            'shadow_range': self.config.decoration.shadow_range,
            'shadow_color': self.config.decoration.shadow_color,
            'blur_enabled': self.config.decoration.blur_enabled,
            'blur_size': self.config.decoration.blur_size,
            'blur_passes': self.config.decoration.blur_passes,
        }
        
        for key, value in widget_map.items():
            if key in self.widgets:
                if hasattr(self.widgets[key], 'set_value'):
                    self.widgets[key].set_value(value)
                elif hasattr(self.widgets[key], 'set_color'):
                    self.widgets[key].set_color(value)
    
    # ═══════════════════════════════════════════════════════════════════════════
    # HELPER METHODS
    # ═══════════════════════════════════════════════════════════════════════════
    
    def _create_page_header(self, title: str, subtitle: str) -> Gtk.Box:
        """Create page header with title and subtitle"""
        header = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        header.set_margin_bottom(24)
        
        title_label = Gtk.Label(label=title)
        title_label.add_css_class('page-title')
        title_label.set_halign(Gtk.Align.START)
        header.append(title_label)
        
        subtitle_label = Gtk.Label(label=subtitle)
        subtitle_label.add_css_class('page-subtitle')
        subtitle_label.set_halign(Gtk.Align.START)
        header.append(subtitle_label)
        
        return header
    
    def _create_action_buttons(self, on_reset: Callable, on_apply: Callable) -> Gtk.Box:
        """Create action button bar"""
        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        box.set_margin_top(24)
        box.set_halign(Gtk.Align.END)
        
        reset_btn = Gtk.Button(label="Reset to Default")
        reset_btn.add_css_class('action-button')
        reset_btn.add_css_class('reset-button')
        reset_btn.connect('clicked', on_reset)
        box.append(reset_btn)
        
        apply_btn = Gtk.Button(label="Apply Changes")
        apply_btn.add_css_class('action-button')
        apply_btn.add_css_class('apply-button')
        apply_btn.connect('clicked', on_apply)
        box.append(apply_btn)
        
        return box
    
    def _show_about_dialog(self, button):
        """Show About dialog with system info"""
        import platform
        import subprocess
        
        # Get system info
        try:
            kernel = platform.release()
        except:
            kernel = "Unknown"
        
        try:
            hostname = platform.node()
        except:
            hostname = "Unknown"
        
        try:
            # Get Hyprland version
            result = subprocess.run(['hyprctl', 'version'], 
                                  capture_output=True, text=True, timeout=2)
            hypr_version = result.stdout.split('\n')[0] if result.returncode == 0 else "Unknown"
        except:
            hypr_version = "Unknown"
        
        # Create dialog
        dialog = Adw.AboutWindow(
            transient_for=self,
            application_name="Hyprland Control Center",
            application_icon="preferences-system",
            developer_name="Gekinzen",
            version="1.0.0",
            comments="A GUI settings panel for Hyprland window manager",
            website="https://github.com/gekinzen/hyprland-control-center",
            issue_url="https://github.com/gekinzen/hyprland-control-center/issues",
            license_type=Gtk.License.MIT_X11,
        )
        
        # Add system info
        system_info = f"""<b>System Information:</b>

<b>Hostname:</b> {hostname}
<b>Kernel:</b> {kernel}
<b>Hyprland:</b> {hypr_version}
<b>Desktop:</b> Wayland

<b>Developer:</b> Gekinzen
<b>Project:</b> Hyprland Control Center
<b>License:</b> MIT"""
        
        dialog.set_debug_info(system_info)
        dialog.present()
    
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

nuclear_css = '''
/* NUCLEAR WHITE ICON OVERRIDE - MAXIMUM PRIORITY */
window > box > box > listbox > row > box > image,
.sidebar listboxrow box image,
listboxrow.sidebar-item box image {
    color: #abb2bf !important;
    -gtk-icon-palette: #abb2bf !important;
    -gtk-icon-style: symbolic !important;
    filter: brightness(0) invert(1) !important;
}

/* When selected - black icons on blue */
window > box > box > listbox > row:selected > box > image,
.sidebar listboxrow:selected box image {
    color: #282c34 !important;
    -gtk-icon-palette: #282c34 !important;
    filter: none !important;
}

/* Force all images in sidebar white */
.sidebar image {
    color: #abb2bf !important;
    -gtk-icon-palette: #abb2bf !important;
    filter: brightness(0) invert(1) !important;
}
'''

nuclear_provider = Gtk.CssProvider()
nuclear_provider.load_from_string(nuclear_css)
Gtk.StyleContext.add_provider_for_display(
    Gdk.Display.get_default(),
    nuclear_provider,
    Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION + 1  # HIGHER than normal!
)
