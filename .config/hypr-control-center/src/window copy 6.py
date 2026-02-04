"""
Main Control Center Window - OPTIMIZED VERSION
Memory optimizations applied without removing any features or logic
"""

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
gi.require_version('Gdk', '4.0')
from gi.repository import Gtk, Adw, Gdk
from typing import Callable, Optional, Dict, Any
from functools import lru_cache
import weakref

from .config_manager import HyprlandConfigManager
from .styles import get_css

# ════════════════════════════════════════════════════════════════════════════
# LAZY PAGE IMPORTS - Load only when needed
# ════════════════════════════════════════════════════════════════════════════
_page_builders: Dict[str, Any] = {}


def _get_page_builder(name: str):
    """Lazy load page builders to reduce initial memory footprint"""
    if name not in _page_builders:
        if name == "appearance":
            from .pages.appearance import build_appearance_page
            _page_builders[name] = build_appearance_page
        elif name == "panel":
            from .pages.panel import build_panel_page
            _page_builders[name] = build_panel_page
        elif name == "themes":
            from .pages.themes import build_themes_page
            _page_builders[name] = build_themes_page
        elif name == "displays":
            from .pages.displays import build_displays_page
            _page_builders[name] = build_displays_page
        elif name == "power":
            from .pages.power import build_power_page
            _page_builders[name] = build_power_page
        elif name == "notifications":
            from .pages.notifications import build_notifications_page
            _page_builders[name] = build_notifications_page
        elif name == "wallpaper":
            from .pages.wallpaper import build_wallpaper_page
            _page_builders[name] = build_wallpaper_page
        elif name == "animations":
            from .pages.animations import build_animations_page
            _page_builders[name] = build_animations_page
        elif name == "theming":
            from .pages.theming import build_theming_page
            _page_builders[name] = build_theming_page
        elif name == "input":
            from .pages.input import build_input_page
            _page_builders[name] = build_input_page
        elif name == "plugins":
            from .pages.plugins import build_plugins_page
            _page_builders[name] = build_plugins_page
        elif name == "time_language":
            from .pages.time_language import build_time_language_page
            _page_builders[name] = build_time_language_page
        elif name == "updates":
            from .pages.updates import build_updates_page
            _page_builders[name] = build_updates_page
        elif name == "keybinds":
            from .pages.keybinds import build_keybinds_page
            _page_builders[name] = build_keybinds_page
    return _page_builders.get(name)


# ════════════════════════════════════════════════════════════════════════════
# MODULE DETECTION - Cache results
# ════════════════════════════════════════════════════════════════════════════
@lru_cache(maxsize=1)
def _check_workspace_module() -> bool:
    """Check if workspace module is available (cached)"""
    try:
        from theming_modules.workspace_section import build_workspace_section
        return True
    except ImportError:
        return False


@lru_cache(maxsize=1)
def _check_theming_module() -> bool:
    """Check if theming module is available (cached)"""
    try:
        from .pages.theming import initialize_saved_theme
        return True
    except ImportError:
        try:
            from modules.theming import initialize_saved_theme
            return True
        except ImportError:
            return False


def _get_theming_functions():
    """Get theming module functions"""
    try:
        from .pages.theming import initialize_saved_theme, get_saved_theme_data
        return initialize_saved_theme, get_saved_theme_data
    except ImportError:
        try:
            from modules.theming import initialize_saved_theme, get_saved_theme_data
            return initialize_saved_theme, get_saved_theme_data
        except ImportError:
            return None, None


# ════════════════════════════════════════════════════════════════════════════
# NERD FONT ICON MAP - Immutable tuple for memory efficiency
# ════════════════════════════════════════════════════════════════════════════
ICON_MAP = {
    "wallpaper": "󰸉", "appearance": "󰇞", "panel": "󰙀",
    "notifications": "󰎟", "themes": "󰍣", "theming": "󰍣",
    "workspaces": "󰙀", "animations": "󰔎", "input": "󰌌",
    "displays": "󰍹", "power": "󰐥", "keybinds": "󰌌",
    "plugins": "󱁤", "time_language": "󰥔", "updates": "󰚰",
}

# Navigation structure - defined once, reused
NAV_SECTIONS = (
    ("DESKTOP", (
        ("Wallpaper", "wallpaper", "preferences-desktop-wallpaper-symbolic"),
        ("Appearance", "appearance", "preferences-desktop-appearance-symbolic"),
        ("Panel", "panel", "view-paged-symbolic"),
        ("Notifications", "notifications", "preferences-system-notifications-symbolic"),
        ("Theming", "theming", "preferences-desktop-theme-symbolic"),
        ("Workspaces", "workspaces", "view-grid-symbolic"),
        ("Plugins", "plugins", "application-x-addon-symbolic"),
    )),
    ("SYSTEM", (
        ("Animations", "animations", "preferences-desktop-effects-symbolic"),
        ("Input Devices", "input", "input-keyboard-symbolic"),
        ("Displays", "displays", "video-display-symbolic"),
        ("Power & Battery", "power", "battery-symbolic"),
        ("Time & Language", "time_language", "preferences-system-time-symbolic"),
        ("Keybinds", "keybinds", "preferences-desktop-keyboard-shortcuts-symbolic"),
        ("Updates", "updates", "software-update-available-symbolic"),
    )),
)


# ════════════════════════════════════════════════════════════════════════════
# WORKSPACE PAGE BUILDERS
# ════════════════════════════════════════════════════════════════════════════
def build_workspaces_page_wrapper(window) -> Gtk.Widget:
    """Build Workspaces page - uses full module if available"""
    if _check_workspace_module():
        return _build_full_workspaces_page(window)
    return _build_placeholder_workspaces_page(window)


def _build_full_workspaces_page(window) -> Gtk.Widget:
    """Build full workspaces page with all features"""
    page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
    page.set_margin_start(24)
    page.set_margin_end(24)
    page.set_margin_top(24)
    page.set_margin_bottom(24)
    
    # Header
    header = _create_page_header_static("Workspaces", 
        "Configure workspace orientation, multi-monitor behavior, and layout settings")
    page.append(header)
    
    try:
        from theming_modules.workspace_section import build_workspace_section
        workspace_content = build_workspace_section(window)
        workspace_content.set_margin_start(0)
        workspace_content.set_margin_end(0)
        page.append(workspace_content)
    except Exception as e:
        print(f"[Window] Error building workspace section: {e}")
        error_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        error_label = Gtk.Label()
        error_label.set_markup(f"<span color='#e06c75'>⚠️ Error loading workspace settings: {e}</span>")
        error_label.set_wrap(True)
        error_box.append(error_label)
        page.append(error_box)
    
    return page


def _build_placeholder_workspaces_page(window) -> Gtk.Widget:
    """Build placeholder workspaces page"""
    page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
    page.set_margin_start(24)
    page.set_margin_end(24)
    page.set_margin_top(24)
    page.set_margin_bottom(24)
    
    header = _create_page_header_static("Workspaces", "Workspace configuration")
    page.append(header)
    
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


def _create_page_header_static(title: str, subtitle: str) -> Gtk.Box:
    """Create page header - static helper to avoid instance method overhead"""
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


# ════════════════════════════════════════════════════════════════════════════
# CSS PROVIDER CACHE - Reuse providers
# ════════════════════════════════════════════════════════════════════════════
class CSSProviderCache:
    """Cache CSS providers to avoid recreating them"""
    _main_provider: Optional[Gtk.CssProvider] = None
    _icon_provider: Optional[Gtk.CssProvider] = None
    
    @classmethod
    def get_or_create_main(cls, css: str) -> Gtk.CssProvider:
        if cls._main_provider is None:
            cls._main_provider = Gtk.CssProvider()
        cls._main_provider.load_from_data(css.encode())
        return cls._main_provider
    
    @classmethod
    def get_or_create_icon(cls) -> Gtk.CssProvider:
        if cls._icon_provider is None:
            cls._icon_provider = Gtk.CssProvider()
            nuclear_css = """
.sidebar image, .sidebar listboxrow image, .sidebar-item image {
    -gtk-icon-palette: error #ffffff;
}
.sidebar listboxrow:selected image, .sidebar-item:selected image {
    -gtk-icon-palette: error #000000;
}"""
            cls._icon_provider.load_from_data(nuclear_css.encode())
        return cls._icon_provider


class ControlCenterWindow(Adw.ApplicationWindow):
    """Main Control Center Window - Optimized"""
    
    __slots__ = ('config', 'widgets', 'toast_overlay', 'stack', 
                 'current_theme_data', '_loaded_pages')
    
    def __init__(self, app):
        super().__init__(application=app)
        
        self.set_title("Zenpy - Hypr Center Alpha")
        self._set_optimal_window_size()
        self.set_resizable(True)
        
        # Use slots for memory efficiency
        self.current_theme_data: Optional[Dict] = None
        self._loaded_pages: set = set()  # Track which pages are loaded
        
        # Theme setup
        from .theme_manager import ThemeManager
        theme_mgr = ThemeManager()
        theme_source = theme_mgr.get_theme_source_mode()
        
        style_manager = Adw.StyleManager.get_default()
        style_manager.set_color_scheme(
            Adw.ColorScheme.DEFAULT if theme_source == "gtk" else Adw.ColorScheme.FORCE_DARK
        )
        
        self.config = HyprlandConfigManager()
        self.config.parse_look_and_feel()
        self.widgets = {}
        
        self._initialize_theme()
        self._apply_css()
        self._build_ui()
    
    def _initialize_theme(self):
        """Initialize theme from saved preferences"""
        if not _check_theming_module():
            print("[Window] ⚠️ Theming module not available, skipping theme init")
            return
            
        print("[Window] ════════════════════════════════════════════════")
        print("[Window] 🎨 Initializing saved theme...")
        
        try:
            initialize_saved_theme, _ = _get_theming_functions()
            if initialize_saved_theme:
                self.current_theme_data = initialize_saved_theme(self)
                if self.current_theme_data:
                    print(f"[Window] 󰍣 Theme initialized: {self.current_theme_data.get('name', 'Unknown')}")
                else:
                    print("[Window] ⚠️ No theme data returned, using defaults")
        except Exception as e:
            print(f"[Window] ❌ Theme initialization error: {e}")
    
    def _set_optimal_window_size(self):
        """Set window size based on monitor dimensions"""
        try:
            import subprocess
            import json
            
            result = subprocess.run(
                ['hyprctl', 'monitors', '-j'],
                capture_output=True, text=True, timeout=2
            )
            
            if result.returncode == 0:
                monitors = json.loads(result.stdout)
                if monitors:
                    active = monitors[0]
                    w = int(active.get('width', 1920) * 0.7)
                    h = int(active.get('height', 1080) * 0.7)
                    self.set_default_size(
                        max(900, min(w, 1400)),
                        max(650, min(h, 900))
                    )
                    return
        except Exception:
            pass
        self.set_default_size(1100, 750)
        
    def _apply_css(self):
        """Apply themed CSS with white icon override"""
        from .theme_manager import ThemeManager
        
        theme_mgr = ThemeManager()
        theme_source = theme_mgr.get_theme_source_mode()
        display = Gdk.Display.get_default()
        
        if _check_theming_module() and self.current_theme_data:
            colors = self.current_theme_data.get('colors', {})
            if colors:
                css = self._generate_themed_css(colors)
                provider = CSSProviderCache.get_or_create_main(css)
                Gtk.StyleContext.add_provider_for_display(
                    display, provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
                )
        else:
            if theme_source == "gtk":
                css = get_css()
            else:
                colors = theme_mgr.get_theme_colors(theme_mgr.get_current_theme())
                css = self._generate_themed_css(colors)
            
            provider = CSSProviderCache.get_or_create_main(css)
            Gtk.StyleContext.add_provider_for_display(
                display, provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            )
        
        # Icon override
        icon_provider = CSSProviderCache.get_or_create_icon()
        Gtk.StyleContext.add_provider_for_display(
            display, icon_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION + 1
        )
    
    def _generate_themed_css(self, colors: dict) -> str:
        """Generate CSS with theme colors"""
        from .styles import get_css_template
        return get_css_template().format(**colors)
    
    def _build_ui(self):
        """Build the main UI with lazy page loading"""
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
        
        # Load initial page only - others load on demand
        self._load_page("wallpaper")
        
        scrolled.set_child(self.stack)
        main_box.append(scrolled)
    
    def _load_page(self, page_name: str):
        """Lazy load a page only when needed"""
        if page_name in self._loaded_pages:
            return
        
        self._loaded_pages.add(page_name)
        
        if page_name == "workspaces":
            self.stack.add_named(build_workspaces_page_wrapper(self), page_name)
        else:
            builder = _get_page_builder(page_name)
            if builder:
                self.stack.add_named(builder(self), page_name)
    
    def _build_sidebar(self) -> Gtk.Box:
        """Build sidebar navigation"""
        sidebar = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        sidebar.add_css_class('sidebar')
        sidebar.set_size_request(240, -1)
        
        title = Gtk.Label(label="⚙ Settings")
        title.add_css_class('sidebar-title')
        title.set_halign(Gtk.Align.START)
        sidebar.append(title)
        
        list_box = Gtk.ListBox()
        list_box.set_selection_mode(Gtk.SelectionMode.SINGLE)
        list_box.connect('row-activated', self._on_nav_activated)
        
        for section_name, items in NAV_SECTIONS:
            # Section header
            section_row = Gtk.ListBoxRow()
            section_row.set_selectable(False)
            section_row.set_activatable(False)
            section_label = Gtk.Label(label=section_name)
            section_label.add_css_class('sidebar-section')
            section_label.set_halign(Gtk.Align.START)
            section_row.set_child(section_label)
            list_box.append(section_row)
            
            # Nav items
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
        
        # Spacer
        spacer = Gtk.Box()
        spacer.set_vexpand(True)
        sidebar.append(spacer)
        
        # Footer
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
        """Handle navigation selection with lazy loading"""
        if row and row.get_selectable():
            page_name = row.get_name()
            if page_name:
                # Lazy load the page if not already loaded
                self._load_page(page_name)
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
            widget = self.widgets.get(key)
            if widget:
                if hasattr(widget, 'set_value'):
                    widget.set_value(value)
                elif hasattr(widget, 'set_color'):
                    widget.set_color(value)
    
    def _create_page_header(self, title: str, subtitle: str) -> Gtk.Box:
        """Create page header - instance method for compatibility"""
        return _create_page_header_static(title, subtitle)
    
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
        
        kernel = platform.release() if hasattr(platform, 'release') else "Unknown"
        hostname = platform.node() if hasattr(platform, 'node') else "Unknown"
        
        try:
            result = subprocess.run(['hyprctl', 'version'], 
                                  capture_output=True, text=True, timeout=2)
            hypr_version = result.stdout.split('\n')[0] if result.returncode == 0 else "Unknown"
        except Exception:
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
        
        theme_info = f"\n<b>Current Theme:</b> {self.current_theme_data.get('name', 'Unknown')}" if self.current_theme_data else ""
        workspace_info = "Enabled" if _check_workspace_module() else "Placeholder"
        
        system_info = f"""<b>System:</b>
<b>Hostname:</b> {hostname}
<b>Kernel:</b> {kernel}
<b>Hyprland:</b> {hypr_version}
<b>Desktop:</b> Wayland{theme_info}
<b>Workspace Module:</b> {workspace_info}"""
        
        dialog.set_debug_info(system_info)
        dialog.present()
    
    def _show_toast(self, message: str):
        """Show toast notification"""
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
            provider = CSSProviderCache.get_or_create_main(css)
            Gtk.StyleContext.add_provider_for_display(
                Gdk.Display.get_default(),
                provider,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            )
    
    def refresh_theme(self):
        """Refresh the current theme"""
        if _check_theming_module():
            initialize_saved_theme, _ = _get_theming_functions()
            if initialize_saved_theme:
                self.current_theme_data = initialize_saved_theme(self)
                self._apply_css()
                self._show_toast(f"Theme refreshed: {self.current_theme_data.get('name', 'Unknown')}")
    
    def refresh_workspaces(self):
        """Refresh workspace settings"""
        if _check_workspace_module() and self.stack.get_visible_child_name() == "workspaces":
            self._show_toast("Workspace settings updated")