"""
Main Control Center Window - COMPLETE WITH WHITE ICONS FIX + THEMING MODULE
Added: Plugins page, Time & Language page, Workspace page (with orientation & multi-monitor)
Fixed: Theme persistence on restart using initialize_saved_theme()
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
from .pages.animations import build_animations_page 
from .pages.theming import build_theming_page

# ════════════════════════════════════════════════════════════════════════════
# NEW PAGE IMPORTS
# ════════════════════════════════════════════════════════════════════════════
from .pages.input import build_input_page
from .pages.plugins import build_plugins_page
from .pages.time_language import build_time_language_page
from .pages.updates import build_updates_page
from .pages.keybinds import build_keybinds_page

# ════════════════════════════════════════════════════════════════════════════
# WORKSPACE SECTION - Full workspace configuration module
# ════════════════════════════════════════════════════════════════════════════
try:
    from theming_modules.workspace_section import build_workspace_section_for_expander, build_workspace_section
    HAS_WORKSPACE_MODULE = True
    print("[Window] 󰙀 Workspace module loaded")
except ImportError:
    try:
        # Alternative import path
        from .pages.placeholders import build_workspaces_page
        HAS_WORKSPACE_MODULE = False
        print("[Window] ⚠️ Workspace module not found - using placeholder")
    except ImportError:
        HAS_WORKSPACE_MODULE = False
        print("[Window] ⚠️ No workspace module available")


# ════════════════════════════════════════════════════════════════════════════
# IMPORT THEMING MODULE - This is the fix!
# ════════════════════════════════════════════════════════════════════════════
try:
    from .pages.theming import initialize_saved_theme, get_saved_theme_data
    HAS_THEMING_MODULE = True
    print("[Window] 󰍣 Theming module loaded")
except ImportError:
    try:
        # Alternative import path
        from modules.theming import initialize_saved_theme, get_saved_theme_data
        HAS_THEMING_MODULE = True
        print("[Window] 󰍣 Theming module loaded (modules path)")
    except ImportError:
        HAS_THEMING_MODULE = False
        print("[Window] ⚠️ Theming module not found - using fallback")


# ════════════════════════════════════════════════════════════════════════════
# NERD FONT ICON MAP
# ════════════════════════════════════════════════════════════════════════════
ICON_MAP = {
    "wallpaper": "󰸉",
    "appearance": "󰇞",
    "panel": "",
    "notifications": "󰎟",
    "themes": "󰍣",
    "theming": "󰍣",
    "workspaces": "󰙀",
    "animations": "󰔎",
    "input": "",
    "displays": "󰍹",
    "power": "󰐥",
    "keybinds": "󰌌",
    "plugins": "󱁤",
    "time_language": "󰥔",
    "updates": "󰚰",
}


def build_workspaces_page_wrapper(window) -> Gtk.Widget:
    """
    Build Workspaces page - uses full module if available, otherwise placeholder
    """
    if HAS_WORKSPACE_MODULE:
        # Use the full workspace section module
        return _build_full_workspaces_page(window)
    else:
        # Fallback to placeholder
        return _build_placeholder_workspaces_page(window)


def _build_full_workspaces_page(window) -> Gtk.Widget:
    """Build full workspaces page with all features"""
    page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
    page.set_margin_start(24)
    page.set_margin_end(24)
    page.set_margin_top(24)
    page.set_margin_bottom(24)
    
    # Header
    header = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
    header.set_margin_bottom(24)
    
    title = Gtk.Label(label="Workspaces")
    title.add_css_class('page-title')
    title.set_halign(Gtk.Align.START)
    header.append(title)
    
    subtitle = Gtk.Label(label="Configure workspace orientation, multi-monitor behavior, and layout settings")
    subtitle.add_css_class('page-subtitle')
    subtitle.set_halign(Gtk.Align.START)
    header.append(subtitle)
    
    page.append(header)
    
    # Main content from workspace_section module
    try:
        workspace_content = build_workspace_section(window)
        workspace_content.set_margin_start(0)
        workspace_content.set_margin_end(0)
        page.append(workspace_content)
    except Exception as e:
        print(f"[Window] Error building workspace section: {e}")
        import traceback
        traceback.print_exc()
        
        # Show error message
        error_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        error_label = Gtk.Label()
        error_label.set_markup(f"<span color='#e06c75'>⚠️ Error loading workspace settings: {str(e)}</span>")
        error_label.set_wrap(True)
        error_box.append(error_label)
        page.append(error_box)
    
    return page


def _build_placeholder_workspaces_page(window) -> Gtk.Widget:
    """Build placeholder workspaces page when module not available"""
    page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
    page.set_margin_start(24)
    page.set_margin_end(24)
    page.set_margin_top(24)
    page.set_margin_bottom(24)
    
    # Header
    header = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
    header.set_margin_bottom(24)
    
    title = Gtk.Label(label="Workspaces")
    title.add_css_class('page-title')
    title.set_halign(Gtk.Align.START)
    header.append(title)
    
    subtitle = Gtk.Label(label="Workspace configuration")
    subtitle.add_css_class('page-subtitle')
    subtitle.set_halign(Gtk.Align.START)
    header.append(subtitle)
    
    page.append(header)
    
    # Placeholder content
    placeholder = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16)
    placeholder.set_valign(Gtk.Align.CENTER)
    placeholder.set_vexpand(True)
    
    icon = Gtk.Label(label="󰙀")
    icon.add_css_class("page-title")
    icon.set_opacity(0.5)
    placeholder.append(icon)
    
    msg = Gtk.Label(label="Workspace module not installed")
    msg.add_css_class("dim-label")
    placeholder.append(msg)
    
    hint = Gtk.Label()
    hint.set_markup("<small>Copy <tt>workspace_section.py</tt> to <tt>theming_modules/</tt> to enable</small>")
    hint.add_css_class("dim-label")
    placeholder.append(hint)
    
    page.append(placeholder)
    
    return page


class ControlCenterWindow(Adw.ApplicationWindow):
    """Main Control Center Window"""
    
    def __init__(self, app):
        super().__init__(application=app)
        
        self.set_title("Zenpy - Hypr Center Alpha")
        self._set_optimal_window_size()
        self.set_resizable(True)
        
        # Store current theme data
        self.current_theme_data = None
        
        from .theme_manager import ThemeManager
        theme_mgr = ThemeManager()
        theme_source = theme_mgr.get_theme_source_mode()
        
        style_manager = Adw.StyleManager.get_default()
        if theme_source == "gtk":
            style_manager.set_color_scheme(Adw.ColorScheme.DEFAULT)
        else:
            style_manager.set_color_scheme(Adw.ColorScheme.FORCE_DARK)
        
        self.config = HyprlandConfigManager()
        self.config.parse_look_and_feel()
        self.widgets = {}
        
        # ════════════════════════════════════════════════════════════════════
        # CRITICAL FIX: Initialize saved theme BEFORE applying CSS
        # This ensures the correct theme is loaded on startup
        # ════════════════════════════════════════════════════════════════════
        self._initialize_theme()
        
        self._apply_css()
        self._build_ui()
    
    def _initialize_theme(self):
        """
        Initialize theme from saved preferences.
        This is the key function that ensures theme persistence!
        """
        if HAS_THEMING_MODULE:
            print("[Window] ════════════════════════════════════════════════")
            print("[Window] 🎨 Initializing saved theme...")
            print("[Window] ════════════════════════════════════════════════")
            
            try:
                # This reads preferences/theme.json and applies the saved theme
                self.current_theme_data = initialize_saved_theme(self)
                
                if self.current_theme_data:
                    theme_name = self.current_theme_data.get('name', 'Unknown')
                    theme_id = self.current_theme_data.get('id', 'unknown')
                    print(f"[Window] 󰍣 Theme initialized: {theme_name} (id={theme_id})")
                else:
                    print("[Window] ⚠️ No theme data returned, using defaults")
                    
            except Exception as e:
                print(f"[Window] ❌ Theme initialization error: {e}")
                import traceback
                traceback.print_exc()
        else:
            print("[Window] ⚠️ Theming module not available, skipping theme init")
    
    def _set_optimal_window_size(self):
        """Set window size based on monitor dimensions"""
        try:
            import subprocess
            import json
            
            result = subprocess.run(
                ['hyprctl', 'monitors', '-j'],
                capture_output=True,
                text=True,
                timeout=2
            )
            
            if result.returncode == 0:
                monitors = json.loads(result.stdout)
                if monitors:
                    active = monitors[0]
                    width = active.get('width', 1920)
                    height = active.get('height', 1080)
                    
                    window_width = int(width * 0.7)
                    window_height = int(height * 0.7)
                    
                    window_width = max(900, min(window_width, 1400))
                    window_height = max(650, min(window_height, 900))
                    
                    self.set_default_size(window_width, window_height)
                    return
        except:
            pass
        
        self.set_default_size(1100, 750)
        
    def _apply_css(self):
        """
        Apply themed CSS with white icon override.
        
        UPDATED: Now uses the theme initialized by _initialize_theme()
        instead of calling ThemeManager separately.
        """
        from .theme_manager import ThemeManager
        
        theme_mgr = ThemeManager()
        theme_source = theme_mgr.get_theme_source_mode()
        
        # ════════════════════════════════════════════════════════════════════
        # UPDATED: Check if we have theme data from initialize_saved_theme()
        # ════════════════════════════════════════════════════════════════════
        if HAS_THEMING_MODULE and self.current_theme_data:
            # Theme was already loaded and CSS was generated by initialize_saved_theme()
            # The CSS provider was already added, so we just need the icon override
            print(f"[Window] 📄 Using theme from theming module: {self.current_theme_data.get('name')}")
            
            # Still apply the theme colors for any additional CSS needs
            colors = self.current_theme_data.get('colors', {})
            if colors:
                css = self._generate_themed_css(colors)
                provider = Gtk.CssProvider()
                provider.load_from_data(css.encode())
                Gtk.StyleContext.add_provider_for_display(
                    Gdk.Display.get_default(),
                    provider,
                    Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
                )
        else:
            # Fallback to old ThemeManager behavior
            if theme_source == "gtk":
                from .styles import get_css
                css = get_css()
            else:
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
        
        # WHITE ICON OVERRIDE - NO PLACEHOLDERS!
        nuclear_css = """
.sidebar image,
.sidebar listboxrow image,
.sidebar-item image {
    -gtk-icon-palette: error #ffffff;
}

.sidebar listboxrow:selected image,
.sidebar-item:selected image {
    -gtk-icon-palette: error #000000;
}
"""
        
        nuclear_provider = Gtk.CssProvider()
        nuclear_provider.load_from_data(nuclear_css.encode())
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            nuclear_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION + 1
        )
    
    def _generate_themed_css(self, colors: dict) -> str:
        """Generate CSS with theme colors"""
        from .styles import get_css_template
        css = get_css_template().format(**colors)
        return css
    
    def _build_ui(self):
        """Build the main UI"""
        self.toast_overlay = Adw.ToastOverlay()
        self.set_content(self.toast_overlay)
        
        main_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        self.toast_overlay.set_child(main_box)
        
        sidebar = self._build_sidebar()
        main_box.append(sidebar)
        
        scrolled = Gtk.ScrolledWindow()
        scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scrolled.set_hexpand(True)
        scrolled.set_vexpand(True)
        scrolled.add_css_class('content-area')
        
        self.stack = Gtk.Stack()
        self.stack.set_transition_type(Gtk.StackTransitionType.CROSSFADE)
        self.stack.set_transition_duration(200)
        self.stack.set_hexpand(True)
        self.stack.set_vexpand(True)
        
        # ═══ ADD PAGES TO STACK ═══
        self.stack.add_named(build_wallpaper_page(self), "wallpaper")
        self.stack.add_named(build_appearance_page(self), "appearance")
        self.stack.add_named(build_panel_page(self), "panel")
        self.stack.add_named(build_notifications_page(self), "notifications")
        self.stack.add_named(build_themes_page(self), "themes")
        self.stack.add_named(build_theming_page(self), "theming")
        
        # ═══ WORKSPACES PAGE - Uses full module or placeholder ═══
        self.stack.add_named(build_workspaces_page_wrapper(self), "workspaces")
        
        self.stack.add_named(build_plugins_page(self), "plugins")
        self.stack.add_named(build_animations_page(self), "animations")
        self.stack.add_named(build_input_page(self), "input")
        self.stack.add_named(build_displays_page(self), "displays")
        self.stack.add_named(build_power_page(self), "power")
        self.stack.add_named(build_time_language_page(self), "time_language")
        self.stack.add_named(build_keybinds_page(self), "keybinds")
        self.stack.add_named(build_updates_page(self), "updates")
        
        scrolled.set_child(self.stack)
        main_box.append(scrolled)
    
    def _build_sidebar(self) -> Gtk.Box:
        """Build sidebar navigation"""
        sidebar = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        sidebar.add_css_class('sidebar')
        sidebar.set_size_request(240, -1)
        
        title = Gtk.Label(label="⚙ Settings")
        title.add_css_class('sidebar-title')
        title.set_halign(Gtk.Align.START)
        sidebar.append(title)
        
        # ═══ NAVIGATION SECTIONS - UPDATED WITH PLUGINS & TIME/LANGUAGE ═══
        nav_sections = [
            ("DESKTOP", [
                ("Wallpaper", "wallpaper", "preferences-desktop-wallpaper-symbolic"),
                ("Appearance", "appearance", "preferences-desktop-appearance-symbolic"),
                ("Panel", "panel", "view-paged-symbolic"),
                ("Notifications", "notifications", "preferences-system-notifications-symbolic"),
                ("Theming", "theming", "preferences-desktop-theme-symbolic"),
                ("Workspaces", "workspaces", "view-grid-symbolic"),
                ("Plugins", "plugins", "application-x-addon-symbolic"),
            ]),
            ("SYSTEM", [
                ("Animations", "animations", "preferences-desktop-effects-symbolic"),
                ("Input Devices", "input", "input-keyboard-symbolic"),
                ("Displays", "displays", "video-display-symbolic"),
                ("Power & Battery", "power", "battery-symbolic"),
                ("Time & Language", "time_language", "preferences-system-time-symbolic"),
                ("Keybinds", "keybinds", "preferences-desktop-keyboard-shortcuts-symbolic"),
                ("Updates", "updates", "software-update-available-symbolic"),
            ]),
        ]
        
        list_box = Gtk.ListBox()
        list_box.set_selection_mode(Gtk.SelectionMode.SINGLE)
        list_box.connect('row-activated', self._on_nav_activated)
        
        for section_name, items in nav_sections:
            section_row = Gtk.ListBoxRow()
            section_row.set_selectable(False)
            section_row.set_activatable(False)
            section_label = Gtk.Label(label=section_name)
            section_label.add_css_class('sidebar-section')
            section_label.set_halign(Gtk.Align.START)
            section_row.set_child(section_label)
            list_box.append(section_row)
            
            for label, page_name, icon_name in items:
                row = Gtk.ListBoxRow()
                row.set_name(page_name)
                
                box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
                box.add_css_class('sidebar-item')
                
                icon_label = Gtk.Label(label=ICON_MAP.get(page_name, "•"))
                icon_label.add_css_class("sidebar-icon")
                icon_label.set_xalign(0.5)
                icon_label.set_yalign(0.5)
                box.append(icon_label)
                                
                lbl = Gtk.Label(label=label)
                lbl.set_halign(Gtk.Align.START)
                box.append(lbl)
                
                row.set_child(box)
                list_box.append(row)
        
        list_box.select_row(list_box.get_row_at_index(1))
        sidebar.append(list_box)
        
        spacer = Gtk.Box()
        spacer.set_vexpand(True)
        sidebar.append(spacer)
        
        version = Gtk.Label(label="v2.0.0")
        version.add_css_class('setting-description')
        version.set_margin_bottom(4)
        sidebar.append(version)
        
        credits = Gtk.Label(label="Created by Gekinzen")
        credits.add_css_class('dim-label')
        credits.set_margin_bottom(12)
        sidebar.append(credits)
        
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
        """Refresh appearance widgets"""
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
    
    def _create_page_header(self, title: str, subtitle: str) -> Gtk.Box:
        """Create page header"""
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
        """Create action buttons"""
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
        """Show About dialog"""
        import platform
        import subprocess
        
        try:
            kernel = platform.release()
        except:
            kernel = "Unknown"
        
        try:
            hostname = platform.node()
        except:
            hostname = "Unknown"
        
        try:
            result = subprocess.run(['hyprctl', 'version'], 
                                  capture_output=True, text=True, timeout=2)
            hypr_version = result.stdout.split('\n')[0] if result.returncode == 0 else "Unknown"
        except:
            hypr_version = "Unknown"
        
        dialog = Adw.AboutWindow(
            transient_for=self,
            application_name="Zenpy - Hypr Center",
            application_icon="preferences-system",
            developer_name="Gekinzen",
            version="2.0.0",
            comments="A GUI settings panel for Hyprland",
            website="https://github.com/gekinzen/hyprland-control-center",
            issue_url="https://github.com/gekinzen/hyprland-control-center/issues",
            license_type=Gtk.License.MIT_X11,
        )
        
        # Add current theme info
        theme_info = ""
        if self.current_theme_data:
            theme_info = f"\n<b>Current Theme:</b> {self.current_theme_data.get('name', 'Unknown')}"
        
        # Add workspace module info
        workspace_info = "Enabled" if HAS_WORKSPACE_MODULE else "Placeholder"
        
        system_info = f"""<b>System:</b>
<b>Hostname:</b> {hostname}
<b>Kernel:</b> {kernel}
<b>Hyprland:</b> {hypr_version}
<b>Desktop:</b> Wayland{theme_info}
<b>Workspace Module:</b> {workspace_info}"""
        
        dialog.set_debug_info(system_info)
        dialog.present()
    
    def _show_toast(self, message: str):
        """Show toast"""
        toast = Adw.Toast(title=message)
        toast.set_timeout(3)
        self.toast_overlay.add_toast(toast)
    
    def _apply_theme_to_ui(self, theme_id: str):
        """Apply theme to UI"""
        from .theme_manager import ThemeManager
        
        theme_mgr = ThemeManager()
        colors = theme_mgr.get_theme_colors(theme_id)
        
        if colors:
            css = self._generate_themed_css(colors)
            css_provider = Gtk.CssProvider()
            css_provider.load_from_string(css)
            
            Gtk.StyleContext.add_provider_for_display(
                Gdk.Display.get_default(),
                css_provider,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            )
    
    def refresh_theme(self):
        """
        Refresh the current theme.
        Call this after theme changes in the Theming page.
        """
        if HAS_THEMING_MODULE:
            self.current_theme_data = initialize_saved_theme(self)
            self._apply_css()
            self._show_toast(f"Theme refreshed: {self.current_theme_data.get('name', 'Unknown')}")
    
    def refresh_workspaces(self):
        """
        Refresh workspace settings.
        Call this after workspace configuration changes.
        """
        if HAS_WORKSPACE_MODULE:
            # Reload the workspace page if needed
            try:
                # Get current page
                current = self.stack.get_visible_child_name()
                
                # If on workspaces page, refresh it
                if current == "workspaces":
                    self._show_toast("Workspace settings updated")
            except Exception as e:
                print(f"[Window] Error refreshing workspaces: {e}")