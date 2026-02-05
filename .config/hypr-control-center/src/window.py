"""
Main Control Center Window - MODERN FLOATING DESIGN with AUTO-SIZING
- Auto-detects screen resolution and scales appropriately
- Supports: 4K, 1440p, 1080p, 1024x768, and smaller screens
- Modern: Left panel solid, Right panel floating with gap
  - NO traffic lights (uses Hyprbar on left panel only)
  - Right panel is floating card with transparent bg
  - Wallpaper visible in gap between panels
- Classic: Solid background, traditional layout
- No resize

REQUIRES for transparency:
- gtk4-layer-shell (optional, for true transparency)
- Hyprland windowrules for opacity
"""

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
gi.require_version('Gdk', '4.0')
from gi.repository import Gtk, Adw, Gdk, Gio, GLib
from typing import Callable, Optional, Dict, Any, Tuple
from functools import lru_cache
from dataclasses import dataclass
import json
from pathlib import Path

from .config_manager import HyprlandConfigManager
from .styles import get_css

# Try to import gtk4-layer-shell for true transparency
try:
    gi.require_version('Gtk4LayerShell', '1.0')
    from gi.repository import Gtk4LayerShell
    HAS_LAYER_SHELL = True
except (ValueError, ImportError):
    HAS_LAYER_SHELL = False
    print("[Window] gtk4-layer-shell not available - using standard window")


# ════════════════════════════════════════════════════════════════════════════
# SCREEN SIZE DETECTION & SCALING
# ════════════════════════════════════════════════════════════════════════════
@dataclass
class WindowDimensions:
    """Window dimensions with scaling factors"""
    width: int
    height: int
    sidebar_width: int
    font_scale: float
    padding_scale: float
    icon_scale: float
    
    @property
    def content_width(self) -> int:
        return self.width - self.sidebar_width


class ScreenSizeDetector:
    """Auto-detect screen size and calculate optimal window dimensions"""
    
    # Breakpoints for different screen categories
    BREAKPOINTS = {
        '4k': (2560, 1440),      # 4K and above
        '1440p': (2560, 1440),   # 2K/1440p
        '1080p': (1920, 1080),   # Full HD
        '900p': (1600, 900),     # HD+
        '768p': (1366, 768),     # HD
        '720p': (1280, 720),     # 720p
        'small': (1024, 768),    # Small screens
    }
    
    # Window size ratios (percentage of screen)
    SIZE_CONFIGS = {
        '4k': {
            'width_ratio': 0.45,
            'height_ratio': 0.65,
            'min_width': 1200,
            'max_width': 1400,
            'min_height': 800,
            'max_height': 1000,
            'sidebar_width': 260,
            'font_scale': 1.1,
            'padding_scale': 1.2,
            'icon_scale': 1.15,
        },
        '1440p': {
            'width_ratio': 0.50,
            'height_ratio': 0.70,
            'min_width': 1100,
            'max_width': 1300,
            'min_height': 750,
            'max_height': 950,
            'sidebar_width': 240,
            'font_scale': 1.0,
            'padding_scale': 1.0,
            'icon_scale': 1.0,
        },
        '1080p': {
            'width_ratio': 0.58,
            'height_ratio': 0.75,
            'min_width': 1000,
            'max_width': 1150,
            'min_height': 680,
            'max_height': 820,
            'sidebar_width': 220,
            'font_scale': 1.0,
            'padding_scale': 1.0,
            'icon_scale': 1.0,
        },
        '900p': {
            'width_ratio': 0.65,
            'height_ratio': 0.80,
            'min_width': 900,
            'max_width': 1050,
            'min_height': 600,
            'max_height': 720,
            'sidebar_width': 200,
            'font_scale': 0.95,
            'padding_scale': 0.9,
            'icon_scale': 0.95,
        },
        '768p': {
            'width_ratio': 0.72,
            'height_ratio': 0.85,
            'min_width': 850,
            'max_width': 1000,
            'min_height': 550,
            'max_height': 650,
            'sidebar_width': 190,
            'font_scale': 0.9,
            'padding_scale': 0.85,
            'icon_scale': 0.9,
        },
        '720p': {
            'width_ratio': 0.78,
            'height_ratio': 0.88,
            'min_width': 800,
            'max_width': 980,
            'min_height': 520,
            'max_height': 630,
            'sidebar_width': 180,
            'font_scale': 0.88,
            'padding_scale': 0.8,
            'icon_scale': 0.88,
        },
        'small': {
            'width_ratio': 0.92,
            'height_ratio': 0.92,
            'min_width': 700,
            'max_width': 950,
            'min_height': 480,
            'max_height': 700,
            'sidebar_width': 160,
            'font_scale': 0.82,
            'padding_scale': 0.7,
            'icon_scale': 0.82,
        },
    }
    
    @classmethod
    def get_screen_size(cls) -> Tuple[int, int]:
        """Get the primary monitor's resolution"""
        display = Gdk.Display.get_default()
        if not display:
            print("[ScreenSize] No display found, using fallback 1920x1080")
            return (1920, 1080)
        
        # Try to get monitors
        monitors = display.get_monitors()
        if monitors and monitors.get_n_items() > 0:
            # Get primary monitor (first one)
            monitor = monitors.get_item(0)
            if monitor:
                geometry = monitor.get_geometry()
                width = geometry.width
                height = geometry.height
                
                # Account for scaling factor
                scale = monitor.get_scale_factor()
                if scale > 1:
                    # For HiDPI, we work with logical pixels
                    print(f"[ScreenSize] Detected HiDPI scale: {scale}")
                
                print(f"[ScreenSize] Detected: {width}x{height} (scale: {scale})")
                return (width, height)
        
        print("[ScreenSize] Could not detect monitor, using fallback 1920x1080")
        return (1920, 1080)
    
    @classmethod
    def get_screen_category(cls, width: int, height: int) -> str:
        """Determine screen category based on resolution"""
        # Check from largest to smallest
        if width >= 2560 or height >= 1440:
            if width >= 3840:
                return '4k'
            return '1440p'
        elif width >= 1920 or height >= 1080:
            return '1080p'
        elif width >= 1600 or height >= 900:
            return '900p'
        elif width >= 1366 or height >= 768:
            return '768p'
        elif width >= 1280 or height >= 720:
            return '720p'
        else:
            return 'small'
    
    @classmethod
    def calculate_dimensions(cls, screen_width: int, screen_height: int) -> WindowDimensions:
        """Calculate optimal window dimensions for given screen size"""
        category = cls.get_screen_category(screen_width, screen_height)
        config = cls.SIZE_CONFIGS[category]
        
        # Calculate base dimensions from ratios
        base_width = int(screen_width * config['width_ratio'])
        base_height = int(screen_height * config['height_ratio'])
        
        # Clamp to min/max
        final_width = max(config['min_width'], min(base_width, config['max_width']))
        final_height = max(config['min_height'], min(base_height, config['max_height']))
        
        # Ensure window fits on screen with some margin
        margin = 50
        if final_width > screen_width - margin:
            final_width = screen_width - margin
        if final_height > screen_height - margin:
            final_height = screen_height - margin
        
        print(f"[ScreenSize] Category: {category}")
        print(f"[ScreenSize] Screen: {screen_width}x{screen_height}")
        print(f"[ScreenSize] Window: {final_width}x{final_height}")
        print(f"[ScreenSize] Sidebar: {config['sidebar_width']}px")
        print(f"[ScreenSize] Font scale: {config['font_scale']}")
        
        return WindowDimensions(
            width=final_width,
            height=final_height,
            sidebar_width=config['sidebar_width'],
            font_scale=config['font_scale'],
            padding_scale=config['padding_scale'],
            icon_scale=config['icon_scale'],
        )
    
    @classmethod
    def get_optimal_dimensions(cls) -> WindowDimensions:
        """Get optimal window dimensions for current screen"""
        screen_width, screen_height = cls.get_screen_size()
        return cls.calculate_dimensions(screen_width, screen_height)


# ════════════════════════════════════════════════════════════════════════════
# STYLE CONFIG
# ════════════════════════════════════════════════════════════════════════════
STYLE_CONFIG_PATH = Path.home() / ".config" / "hypr-control-center" / "ui_style.json"

def load_ui_style() -> str:
    try:
        if STYLE_CONFIG_PATH.exists():
            with open(STYLE_CONFIG_PATH) as f:
                data = json.load(f)
                return data.get("style", "classic")
    except Exception as e:
        print(f"[Window] Error loading UI style: {e}")
    return "classic"

def save_ui_style(style: str):
    try:
        STYLE_CONFIG_PATH.parent.mkdir(parents=True, exist_ok=True)
        with open(STYLE_CONFIG_PATH, 'w') as f:
            json.dump({"style": style}, f)
    except Exception as e:
        print(f"[Window] Error saving UI style: {e}")


# ════════════════════════════════════════════════════════════════════════════
# LAZY PAGE IMPORTS
# ════════════════════════════════════════════════════════════════════════════
_page_builders: Dict[str, Any] = {}

def _get_page_builder(name: str):
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
        elif name == "widgets":
            from .pages.widgets_page import WidgetsPage
            _page_builders[name] = lambda window: WidgetsPage(window)
    return _page_builders.get(name)


# ════════════════════════════════════════════════════════════════════════════
# MODULE DETECTION
# ════════════════════════════════════════════════════════════════════════════
@lru_cache(maxsize=1)
def _check_workspace_module() -> bool:
    try:
        from theming_modules.workspace_section import build_workspace_section
        return True
    except ImportError:
        return False

@lru_cache(maxsize=1)
def _check_theming_module() -> bool:
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
# ICONS & NAVIGATION
# ════════════════════════════════════════════════════════════════════════════
ICON_MAP = {
    "wallpaper": "󰸉", "appearance": "󰇞", "panel": "󰙀",
    "notifications": "󰎟", "themes": "󰍣", "theming": "󰍣",
    "workspaces": "󰙀", "animations": "󰔎", "input": "󰌌",
    "displays": "󰍹", "power": "󰐥", "keybinds": "󰌌",
    "plugins": "󱁤", "time_language": "󰥔", "updates": "󰚰",
    "widgets": "󰍺",
}

NAV_SECTIONS = (
    ("DESKTOP", (
        ("Wallpaper", "wallpaper", "preferences-desktop-wallpaper-symbolic"),
        ("Appearance", "appearance", "preferences-desktop-appearance-symbolic"),
        ("Panel", "panel", "view-paged-symbolic"),
        ("Notifications", "notifications", "preferences-system-notifications-symbolic"),
        ("Theming", "theming", "preferences-desktop-theme-symbolic"),
        ("Workspaces", "workspaces", "view-grid-symbolic"),
        ("Plugins", "plugins", "application-x-addon-symbolic"),
        ("Widgets", "widgets", "preferences-desktop-apps-symbolic"),
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
    if _check_workspace_module():
        return _build_full_workspaces_page(window)
    return _build_placeholder_workspaces_page(window)

def _build_full_workspaces_page(window) -> Gtk.Widget:
    dims = getattr(window, 'dimensions', None)
    margin = int(24 * (dims.padding_scale if dims else 1.0))
    
    page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
    page.set_margin_start(margin)
    page.set_margin_end(margin)
    page.set_margin_top(margin)
    page.set_margin_bottom(margin)
    
    header = _create_page_header_static("Workspaces", 
        "Configure workspace orientation, multi-monitor behavior, and layout settings",
        dims)
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
    dims = getattr(window, 'dimensions', None)
    margin = int(24 * (dims.padding_scale if dims else 1.0))
    
    page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
    page.set_margin_start(margin)
    page.set_margin_end(margin)
    page.set_margin_top(margin)
    page.set_margin_bottom(margin)
    
    header = _create_page_header_static("Workspaces", "Workspace configuration", dims)
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

def _create_page_header_static(title: str, subtitle: str, dims: Optional[WindowDimensions] = None) -> Gtk.Box:
    header = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
    margin_bottom = int(24 * (dims.padding_scale if dims else 1.0))
    header.set_margin_bottom(margin_bottom)
    
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
# CSS PROVIDERS
# ════════════════════════════════════════════════════════════════════════════
class CSSProviderCache:
    _main_provider: Optional[Gtk.CssProvider] = None
    _icon_provider: Optional[Gtk.CssProvider] = None
    _style_provider: Optional[Gtk.CssProvider] = None
    _scale_provider: Optional[Gtk.CssProvider] = None
    
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
    
    @classmethod
    def load_style_css(cls, style: str, dims: Optional[WindowDimensions] = None) -> Gtk.CssProvider:
        if cls._style_provider is None:
            cls._style_provider = Gtk.CssProvider()
        
        if style == "modern":
            css = cls._get_modern_css(dims)
        else:
            css = cls._get_classic_css(dims)
        
        cls._style_provider.load_from_data(css.encode())
        return cls._style_provider
    
    @classmethod
    def apply_scaling_css(cls, dims: WindowDimensions) -> Gtk.CssProvider:
        """Generate CSS for dynamic scaling based on screen size"""
        if cls._scale_provider is None:
            cls._scale_provider = Gtk.CssProvider()
        
        # Calculate scaled values
        font_scale = dims.font_scale
        padding_scale = dims.padding_scale
        icon_scale = dims.icon_scale
        
        # Base sizes
        base_title_size = 26
        base_subtitle_size = 12
        base_label_size = 13
        base_section_size = 10
        base_icon_size = 15
        base_padding = 16
        base_margin = 24
        
        scaling_css = f"""
/* ═══════════════════════════════════════════════════════════════════════════
   DYNAMIC SCALING - Auto-generated for screen: {dims.width}x{dims.height}
═══════════════════════════════════════════════════════════════════════════ */

.page-title {{
    font-size: {int(base_title_size * font_scale)}px;
}}

.page-subtitle {{
    font-size: {int(base_subtitle_size * font_scale)}px;
}}

.sidebar-title {{
    font-size: {int(15 * font_scale)}px;
    padding: {int(base_padding * padding_scale)}px;
}}

.sidebar-section {{
    font-size: {int(base_section_size * font_scale)}px;
    padding: {int(base_padding * padding_scale)}px {int(base_padding * padding_scale)}px {int(6 * padding_scale)}px {int(base_padding * padding_scale)}px;
}}

.sidebar-item {{
    padding: {int(10 * padding_scale)}px {int(14 * padding_scale)}px;
    margin: {int(2 * padding_scale)}px {int(10 * padding_scale)}px;
    font-size: {int(base_label_size * font_scale)}px;
}}

.sidebar-icon {{
    font-size: {int(base_icon_size * icon_scale)}px;
    min-width: {int(22 * icon_scale)}px;
}}

.settings-group {{
    padding: {int(20 * padding_scale)}px {int(24 * padding_scale)}px;
    margin-bottom: {int(16 * padding_scale)}px;
    border-radius: {int(14 * padding_scale)}px;
}}

.group-title {{
    font-size: {int(11 * font_scale)}px;
    margin-bottom: {int(16 * padding_scale)}px;
}}

.setting-row {{
    padding: {int(12 * padding_scale)}px 0;
}}

.setting-label {{
    font-size: {int(13 * font_scale)}px;
}}

.setting-description {{
    font-size: {int(11 * font_scale)}px;
}}

button {{
    padding: {int(8 * padding_scale)}px {int(16 * padding_scale)}px;
    border-radius: {int(10 * padding_scale)}px;
}}

.style-toggle-btn {{
    font-size: {int(11 * font_scale)}px;
    padding: {int(6 * padding_scale)}px {int(14 * padding_scale)}px;
}}

.dim-label {{
    font-size: {int(11 * font_scale)}px;
}}

.value-mono {{
    font-size: {int(11 * font_scale)}px;
    padding: {int(5 * padding_scale)}px {int(12 * padding_scale)}px;
}}

/* Content panel margins - scale with padding */
.content-panel {{
    margin: {int(12 * padding_scale)}px;
    margin-left: {int(16 * padding_scale)}px;
    border-radius: {int(16 * padding_scale)}px;
}}
"""
        
        cls._scale_provider.load_from_data(scaling_css.encode())
        return cls._scale_provider
    
    @classmethod
    def _get_modern_css(cls, dims: Optional[WindowDimensions] = None) -> str:
        """Modern: Left panel solid (Hyprbar), Right panel floating with gap"""
        sidebar_width = dims.sidebar_width if dims else 220
        
        return f"""
/* ═══════════════════════════════════════════════════════════════════════════
   MODERN STYLE - Left solid + Right floating with wallpaper gap
   Sidebar width: {sidebar_width}px (auto-scaled)
═══════════════════════════════════════════════════════════════════════════ */

/* Window - FULLY TRANSPARENT for wallpaper visibility */
window, window.background, window.solid-csd, .background {{
    background-color: transparent;
    background: transparent;
}}

window.csd, window.solid-csd {{
    background-color: transparent;
    box-shadow: none;
}}

decoration {{
    background-color: transparent;
    box-shadow: none;
}}

toastoverlay, toastoverlay > *, window > box, window > * {{
    background-color: transparent;
    background: transparent;
}}

.main-container {{
    background-color: transparent;
    background: transparent;
    padding: 0;
}}

/* ─────────────────────────────────────────────────────────────────────────
   LEFT PANEL (Sidebar) - Scaled width
───────────────────────────────────────────────────────────────────────── */
.sidebar-panel {{
    background-color: #2a2d37;
    border: none;
    border-radius: 0;
    margin: 0;
    box-shadow: 2px 0 8px rgba(0, 0, 0, 0.3);
}}

.sidebar {{
    background: transparent;
    border: none;
    border-radius: 0;
    margin: 0;
    min-width: {sidebar_width}px;
}}

.sidebar-title {{
    font-weight: 600;
    color: rgba(255, 255, 255, 0.95);
}}

.sidebar-section {{
    font-weight: 600;
    color: rgba(255, 255, 255, 0.35);
    letter-spacing: 0.8px;
    text-transform: uppercase;
}}

.sidebar-item {{
    border-radius: 8px;
    color: rgba(255, 255, 255, 0.75);
    transition: all 0.15s ease;
}}

.sidebar-item:hover {{
    background-color: rgba(255, 255, 255, 0.08);
}}

listbox row:selected .sidebar-item {{
    background-color: rgba(82, 148, 226, 0.3);
    color: #ffffff;
    font-weight: 500;
}}

.sidebar-icon {{
    font-family: "JetBrainsMono Nerd Font", monospace;
    color: rgba(255, 255, 255, 0.85);
}}

.sidebar listbox, .sidebar listbox row {{
    background: transparent;
}}

/* ─────────────────────────────────────────────────────────────────────────
   RIGHT PANEL (Content)
───────────────────────────────────────────────────────────────────────── */
.content-panel {{
    background-color: rgba(45, 48, 58, 0.95);
    border: 1px solid rgba(255, 255, 255, 0.08);
    box-shadow: 0 12px 40px rgba(0, 0, 0, 0.4),
                0 4px 12px rgba(0, 0, 0, 0.25),
                inset 0 1px 0 rgba(255, 255, 255, 0.05);
}}

.content-area {{
    background: transparent;
    border: none;
    border-radius: 0;
    margin: 0;
}}

.content-area > stack, .content-area stack > * {{
    background: transparent;
}}

/* ─────────────────────────────────────────────────────────────────────────
   SHARED STYLES - Modern
───────────────────────────────────────────────────────────────────────── */
.dim-label {{
    color: rgba(255, 255, 255, 0.4);
}}

.page-title {{
    font-weight: 600;
    color: rgba(255, 255, 255, 0.95);
}}

.page-subtitle {{
    color: rgba(255, 255, 255, 0.5);
}}

.settings-group {{
    background-color: rgba(35, 38, 48, 0.7);
    border: 1px solid rgba(255, 255, 255, 0.05);
}}

.group-title {{
    font-weight: 700;
    color: #5294e2;
    letter-spacing: 0.8px;
    text-transform: uppercase;
}}

.setting-row {{
    border-bottom: 1px solid rgba(255, 255, 255, 0.04);
}}

.setting-row:last-child {{
    border-bottom: none;
}}

.setting-label {{
    font-weight: 500;
    color: rgba(255, 255, 255, 0.9);
}}

.setting-description {{
    color: rgba(255, 255, 255, 0.45);
}}

button {{
    background-color: rgba(255, 255, 255, 0.08);
    color: rgba(255, 255, 255, 0.9);
    border: 1px solid rgba(255, 255, 255, 0.1);
    transition: all 0.15s ease;
}}

button:hover {{
    background-color: rgba(255, 255, 255, 0.14);
    border-color: rgba(255, 255, 255, 0.15);
}}

button.suggested-action {{
    background-color: #5294e2;
    color: #ffffff;
    border-color: transparent;
}}

button.suggested-action:hover {{
    background-color: #6aa3e8;
}}

button.destructive-action {{
    background-color: rgba(224, 107, 116, 0.15);
    color: #e06b74;
    border-color: rgba(224, 107, 116, 0.3);
}}

button.destructive-action:hover {{
    background-color: rgba(224, 107, 116, 0.25);
}}

button.flat {{
    background: transparent;
    border: none;
}}

button.flat:hover {{
    background-color: rgba(255, 255, 255, 0.08);
}}

switch {{
    background-color: rgba(255, 255, 255, 0.15);
    border-radius: 14px;
    min-width: 48px;
    min-height: 26px;
}}

switch:checked {{
    background-color: #5294e2;
}}

switch slider {{
    background-color: #ffffff;
    border-radius: 13px;
    min-width: 22px;
    min-height: 22px;
    margin: 2px;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
}}

entry {{
    background-color: rgba(0, 0, 0, 0.25);
    color: rgba(255, 255, 255, 0.9);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 10px;
    padding: 8px 12px;
    transition: all 0.15s ease;
}}

entry:focus {{
    border-color: #5294e2;
    background-color: rgba(0, 0, 0, 0.3);
}}

dropdown {{
    background-color: rgba(0, 0, 0, 0.25);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 10px;
    padding: 6px 12px;
    color: rgba(255, 255, 255, 0.9);
}}

scale trough {{
    background-color: rgba(255, 255, 255, 0.12);
    border-radius: 6px;
    min-height: 6px;
}}

scale highlight {{
    background-color: #5294e2;
    border-radius: 6px;
}}

scale slider {{
    background-color: #ffffff;
    border-radius: 50%;
    min-width: 18px;
    min-height: 18px;
    margin: -6px;
    box-shadow: 0 2px 6px rgba(0, 0, 0, 0.3);
}}

scrollbar {{
    background: transparent;
}}

scrollbar slider {{
    background-color: rgba(255, 255, 255, 0.15);
    border-radius: 6px;
    min-width: 6px;
}}

scrollbar slider:hover {{
    background-color: rgba(255, 255, 255, 0.25);
}}

.card {{
    background-color: rgba(35, 38, 48, 0.7);
    border: 1px solid rgba(255, 255, 255, 0.05);
    border-radius: 12px;
}}

.value-mono {{
    font-family: "JetBrains Mono", monospace;
    color: #56b6c2;
    background-color: rgba(0, 0, 0, 0.25);
    border-radius: 8px;
}}

toast {{
    background-color: rgba(40, 42, 50, 0.95);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 12px;
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.4);
}}
"""
    
    @classmethod
    def _get_classic_css(cls, dims: Optional[WindowDimensions] = None) -> str:
        """Classic: Solid background - your default style"""
        sidebar_width = dims.sidebar_width if dims else 240
        
        return f"""
/* ═══════════════════════════════════════════════════════════════════════════
   CLASSIC STYLE - Solid background (auto-scaled sidebar: {sidebar_width}px)
═══════════════════════════════════════════════════════════════════════════ */

window.background, window {{
    background-color: #383c4a;
}}

.main-container {{
    padding: 0;
}}

.sidebar-panel {{
    background: transparent;
    border: none;
    border-radius: 0;
    margin: 0;
    box-shadow: none;
}}

.content-panel {{
    background: transparent;
    border: none;
    border-radius: 0;
    margin: 0;
    box-shadow: none;
}}

.sidebar {{
    background-color: #2f343f;
    border-right: 1px solid #4b5162;
    border-radius: 0;
    margin: 0;
    min-width: {sidebar_width}px;
}}

.content-area {{
    background-color: #383c4a;
    border-radius: 0;
    margin: 0;
}}

.sidebar-title {{
    font-weight: 700;
    color: #d3dae3;
}}

.sidebar-section {{
    font-weight: 700;
    color: #7c818c;
    letter-spacing: 1.2px;
    text-transform: uppercase;
}}

.sidebar-item {{
    border-radius: 8px;
    color: #d3dae3;
}}

.sidebar-item:hover {{
    background-color: #404552;
}}

listbox row:selected .sidebar-item {{
    background-color: #5294e2;
    color: #ffffff;
    font-weight: 600;
}}

.sidebar-icon {{
    font-family: "JetBrainsMono Nerd Font";
    color: #ffffff;
}}

.sidebar listbox, .sidebar listbox row {{
    background: transparent;
}}

.page-title {{
    font-weight: 700;
    color: #d3dae3;
    margin-bottom: 4px;
}}

.page-subtitle {{
    color: #9499a4;
    opacity: 0.8;
}}

.settings-group {{
    background-color: #2f343f;
    border: 1px solid #4b5162;
}}

.group-title {{
    font-weight: 700;
    color: #5294e2;
    letter-spacing: 0.8px;
    text-transform: uppercase;
}}

.setting-row {{
    border-bottom: 1px solid #404552;
}}

.setting-row:last-child {{
    border-bottom: none;
}}

.setting-label {{
    font-weight: 600;
    color: #d3dae3;
}}

.setting-description {{
    color: #9499a4;
    opacity: 0.75;
}}

button {{
    background-color: #404552;
    color: #d3dae3;
    border: 1px solid #4b5162;
    border-radius: 8px;
}}

button:hover {{
    background-color: #4b5162;
}}

button.suggested-action {{
    background-color: #5294e2;
    color: #ffffff;
    border-color: #5294e2;
}}

button.destructive-action {{
    background-color: #404552;
    color: #e06b74;
    border-color: #4b5162;
}}

button.flat {{
    background: transparent;
    border: none;
}}

button.flat:hover {{
    background-color: #404552;
}}

switch {{
    background-color: #4b5162;
    border-radius: 14px;
    min-width: 50px;
    min-height: 26px;
}}

switch:checked {{
    background-color: #5294e2;
}}

switch slider {{
    background-color: #ffffff;
    border-radius: 13px;
    min-width: 22px;
    min-height: 22px;
    margin: 2px;
}}

entry {{
    background-color: #404552;
    color: #d3dae3;
    border: 1px solid #4b5162;
    border-radius: 8px;
    padding: 8px 12px;
}}

entry:focus {{
    border-color: #5294e2;
    background-color: #383c4a;
}}

dropdown {{
    background-color: #404552;
    color: #d3dae3;
    border: 1px solid #4b5162;
    border-radius: 8px;
    padding: 6px 12px;
}}

scale trough {{
    background-color: #4b5162;
    border-radius: 4px;
    min-height: 6px;
}}

scale highlight {{
    background-color: #5294e2;
    border-radius: 4px;
}}

scale slider {{
    background-color: #ffffff;
    border-radius: 50%;
    min-width: 18px;
    min-height: 18px;
    margin: -6px;
}}

scrollbar slider {{
    background-color: #4b5162;
    border-radius: 8px;
    min-width: 8px;
}}

.card {{
    background-color: #2f343f;
    border-radius: 12px;
    padding: 16px;
    border: 1px solid #4b5162;
}}

.dim-label {{
    color: #9499a4;
    opacity: 0.8;
}}

.value-mono {{
    font-family: "JetBrains Mono";
    color: #56b6c2;
    background-color: #404552;
    border: 1px solid #4b5162;
}}
"""


class ControlCenterWindow(Adw.ApplicationWindow):
    """Main Control Center Window - Modern Floating Design with Auto-Sizing
    
    Features:
    - Auto-detects screen resolution
    - Scales UI appropriately for all screen sizes
    - Modern: Left panel solid (Hyprbar), Right panel floating
    - Classic: Traditional solid layout
    
    For transparent gap effect, add to Hyprland:
    windowrulev2 = float, class:^(com.hyprland.controlcenter)$
    """
    
    __slots__ = ('config', 'widgets', 'toast_overlay', 'stack', 
                 'current_theme_data', '_loaded_pages', 'ui_style', 
                 'style_toggle', 'dimensions')
    
    def __init__(self, app):
        super().__init__(application=app)
        
        # Auto-detect screen size and calculate optimal dimensions
        self.dimensions = ScreenSizeDetector.get_optimal_dimensions()
        
        self.set_title("Zenpy - Hypr Center Alpha")
        self.set_resizable(False)
        self._set_optimal_window_size()
        
        self.ui_style = load_ui_style()
        self.current_theme_data: Optional[Dict] = None
        self._loaded_pages: set = set()
        
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
        self._setup_transparency()
        self._apply_css()
        self._build_ui()
        
        # Log final configuration
        print(f"[Window] Final size: {self.dimensions.width}x{self.dimensions.height}")
        print(f"[Window] Sidebar: {self.dimensions.sidebar_width}px")
        print(f"[Window] Font scale: {self.dimensions.font_scale}")
    
    def _setup_transparency(self):
        """Setup window transparency for modern mode"""
        if self.ui_style == "modern":
            self.set_decorated(False)
    
    def _initialize_theme(self):
        if not _check_theming_module():
            return
        try:
            initialize_saved_theme, _ = _get_theming_functions()
            if initialize_saved_theme:
                self.current_theme_data = initialize_saved_theme(self)
        except Exception as e:
            print(f"[Window] Theme init error: {e}")
    
    def _set_optimal_window_size(self):
        """Set window size based on auto-detected dimensions"""
        width = self.dimensions.width
        height = self.dimensions.height
        
        self.set_default_size(width, height)
        self.set_size_request(width, height)
        
        print(f"[Window] Setting size to {width}x{height}")
    
    def _apply_css(self):
        display = Gdk.Display.get_default()
        
        # Apply style CSS with dimensions
        style_provider = CSSProviderCache.load_style_css(self.ui_style, self.dimensions)
        Gtk.StyleContext.add_provider_for_display(
            display, style_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION + 10
        )
        
        # Apply scaling CSS
        scale_provider = CSSProviderCache.apply_scaling_css(self.dimensions)
        Gtk.StyleContext.add_provider_for_display(
            display, scale_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION + 11
        )
        
        # Apply icon CSS
        icon_provider = CSSProviderCache.get_or_create_icon()
        Gtk.StyleContext.add_provider_for_display(
            display, icon_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION + 12
        )
    
    def _toggle_ui_style(self, button):
        if self.ui_style == "classic":
            self.ui_style = "modern"
            self.set_decorated(False)
        else:
            self.ui_style = "classic"
            self.set_decorated(True)
        
        button.set_label(self.ui_style.title())
        save_ui_style(self.ui_style)
        self._apply_css()
        self._show_toast(f"Style: {self.ui_style.title()} - Restart app for full effect")
    
    def _build_ui(self):
        self.toast_overlay = Adw.ToastOverlay()
        self.set_content(self.toast_overlay)
        
        # Main container - horizontal layout
        main_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        main_box.add_css_class('main-container')
        self.toast_overlay.set_child(main_box)
        
        # ═══════════════════════════════════════════════════════════════════
        # LEFT PANEL (Sidebar)
        # ═══════════════════════════════════════════════════════════════════
        sidebar_panel = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        sidebar_panel.add_css_class('sidebar-panel')
        
        sidebar = self._build_sidebar()
        sidebar_panel.append(sidebar)
        
        main_box.append(sidebar_panel)
        
        # ═══════════════════════════════════════════════════════════════════
        # RIGHT PANEL (Content)
        # ═══════════════════════════════════════════════════════════════════
        content_panel = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        content_panel.add_css_class('content-panel')
        content_panel.set_hexpand(True)
        content_panel.set_vexpand(True)
        
        content_area = Gtk.ScrolledWindow()
        content_area.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        content_area.set_hexpand(True)
        content_area.set_vexpand(True)
        content_area.add_css_class('content-area')
        
        self.stack = Gtk.Stack()
        self.stack.set_transition_type(Gtk.StackTransitionType.CROSSFADE)
        self.stack.set_transition_duration(200)
        self.stack.set_hexpand(True)
        self.stack.set_vexpand(True)
        
        self._load_page("wallpaper")
        
        content_area.set_child(self.stack)
        content_panel.append(content_area)
        
        main_box.append(content_panel)
    
    def _load_page(self, page_name: str):
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
        sidebar = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        sidebar.add_css_class('sidebar')
        sidebar.set_size_request(self.dimensions.sidebar_width, -1)
        
        # Calculate scaled padding
        padding = int(16 * self.dimensions.padding_scale)
        
        # Header with style toggle
        header_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        header_box.set_margin_start(padding)
        header_box.set_margin_end(padding)
        header_box.set_margin_top(padding)
        header_box.set_margin_bottom(int(8 * self.dimensions.padding_scale))
        
        title = Gtk.Label(label="Settings")
        title.add_css_class('sidebar-title')
        title.set_halign(Gtk.Align.START)
        title.set_hexpand(True)
        header_box.append(title)
        
        self.style_toggle = Gtk.Button(label=self.ui_style.title())
        self.style_toggle.add_css_class('style-toggle-btn')
        self.style_toggle.set_tooltip_text("Toggle Classic/Modern")
        self.style_toggle.connect('clicked', self._toggle_ui_style)
        header_box.append(self.style_toggle)
        
        sidebar.append(header_box)
        
        # Navigation
        list_box = Gtk.ListBox()
        list_box.set_selection_mode(Gtk.SelectionMode.SINGLE)
        list_box.connect('row-activated', self._on_nav_activated)
        
        for section_name, items in NAV_SECTIONS:
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
                
                box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=int(12 * self.dimensions.padding_scale))
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
        
        # Footer - version and credits with screen info
        screen_w, screen_h = ScreenSizeDetector.get_screen_size()
        category = ScreenSizeDetector.get_screen_category(screen_w, screen_h)
        
        screen_info = Gtk.Label(label=f"{screen_w}×{screen_h} ({category})")
        screen_info.add_css_class('dim-label')
        screen_info.set_margin_bottom(2)
        sidebar.append(screen_info)
        
        version = Gtk.Label(label="v2.1.0")
        version.add_css_class('dim-label')
        version.set_margin_bottom(4)
        sidebar.append(version)
        
        credits = Gtk.Label(label="Created by Gekinzen")
        credits.add_css_class('dim-label')
        credits.set_margin_bottom(padding)
        sidebar.append(credits)
        
        return sidebar
    
    def _on_nav_activated(self, list_box, row):
        if row and row.get_selectable():
            page_name = row.get_name()
            if page_name:
                self._load_page(page_name)
                self.stack.set_visible_child_name(page_name)
    
    def _on_appearance_reset(self, btn):
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
        self.config.save_look_and_feel()
        self._show_toast("Appearance settings applied")
    
    def _refresh_appearance_widgets(self):
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
        return _create_page_header_static(title, subtitle, self.dimensions)
    
    def _create_action_buttons(self, on_reset: Callable, on_apply: Callable) -> Gtk.Box:
        margin_top = int(24 * self.dimensions.padding_scale)
        
        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        box.set_margin_top(margin_top)
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
            version="2.1.0",
            comments="A GUI settings panel for Hyprland\nAuto-scaling UI for all screen sizes",
            website="https://github.com/gekinzen/hyprland-control-center",
            issue_url="https://github.com/gekinzen/hyprland-control-center/issues",
            license_type=Gtk.License.MIT_X11,
        )
        
        theme_info = f"\n<b>Current Theme:</b> {self.current_theme_data.get('name', 'Unknown')}" if self.current_theme_data else ""
        workspace_info = "Enabled" if _check_workspace_module() else "Placeholder"
        
        screen_w, screen_h = ScreenSizeDetector.get_screen_size()
        category = ScreenSizeDetector.get_screen_category(screen_w, screen_h)
        
        system_info = f"""<b>System:</b>
<b>Hostname:</b> {hostname}
<b>Kernel:</b> {kernel}
<b>Hyprland:</b> {hypr_version}
<b>Desktop:</b> Wayland{theme_info}
<b>Workspace Module:</b> {workspace_info}
<b>UI Style:</b> {self.ui_style.title()}

<b>Display:</b>
<b>Screen:</b> {screen_w}×{screen_h}
<b>Category:</b> {category}
<b>Window:</b> {self.dimensions.width}×{self.dimensions.height}
<b>Font Scale:</b> {self.dimensions.font_scale}
<b>Sidebar:</b> {self.dimensions.sidebar_width}px"""
        
        dialog.set_debug_info(system_info)
        dialog.present()
    
    def _show_toast(self, message: str):
        toast = Adw.Toast(title=message)
        toast.set_timeout(3)
        self.toast_overlay.add_toast(toast)
    
    def _apply_theme_to_ui(self, theme_id: str):
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
    
    def _generate_themed_css(self, colors: dict) -> str:
        from .styles import get_css_template
        return get_css_template().format(**colors)
    
    def refresh_theme(self):
        if _check_theming_module():
            initialize_saved_theme, _ = _get_theming_functions()
            if initialize_saved_theme:
                self.current_theme_data = initialize_saved_theme(self)
                self._apply_css()
                self._show_toast(f"Theme refreshed: {self.current_theme_data.get('name', 'Unknown')}")
    
    def refresh_workspaces(self):
        if _check_workspace_module() and self.stack.get_visible_child_name() == "workspaces":
            self._show_toast("Workspace settings updated")
    
    def get_scaled_value(self, base_value: int, scale_type: str = 'padding') -> int:
        """Helper method for pages to get scaled values"""
        if scale_type == 'padding':
            return int(base_value * self.dimensions.padding_scale)
        elif scale_type == 'font':
            return int(base_value * self.dimensions.font_scale)
        elif scale_type == 'icon':
            return int(base_value * self.dimensions.icon_scale)
        return base_value