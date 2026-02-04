"""
═══════════════════════════════════════════════════════════════════════════════
THEMING PAGE - Classic/Modern Toggle Design
Hyprland Control Center
═══════════════════════════════════════════════════════════════════════════════
Features:
  - Toggle between Classic (detailed controls) and Modern (palette cards)
  - Modern: Color palette cards with selection + hue slider
  - Classic: Full theming controls (profiles, individual colors, etc.)
  - Window size remains unchanged
═══════════════════════════════════════════════════════════════════════════════
"""

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
from gi.repository import Gtk, Adw, Gdk, GLib, Gio
import json
import os
import colorsys
from pathlib import Path
from typing import Optional, Dict, List, Callable

# ═══════════════════════════════════════════════════════════════════════════════
# CONSTANTS & PATHS
# ═══════════════════════════════════════════════════════════════════════════════

CONFIG_DIR = Path.home() / ".config" / "hypr-control-center"
THEMING_CONFIG = CONFIG_DIR / "theming_style.json"

# Built-in color palettes for Modern mode
MODERN_PALETTES = {
    "mocha": {
        "name": "Mocha",
        "colors": ["#1e1e2e", "#45475a", "#f38ba8", "#a6e3a1", "#f5e0dc", "#f9e2af", "#cdd6f4"],
        "accent": "#f38ba8"
    },
    "nord": {
        "name": "Nord",
        "colors": ["#2e3440", "#4c566a", "#bf616a", "#a3be8c", "#d8dee9", "#ebcb8b", "#eceff4"],
        "accent": "#88c0d0"
    },
    "gruvbox": {
        "name": "Gruvbox",
        "colors": ["#282828", "#504945", "#fb4934", "#b8bb26", "#d5c4a1", "#fabd2f", "#ebdbb2"],
        "accent": "#fe8019"
    },
    "onedark": {
        "name": "One Dark",
        "colors": ["#282c34", "#3e4451", "#e06c75", "#98c379", "#abb2bf", "#e5c07b", "#dcdfe4"],
        "accent": "#61afef"
    },
    "tokyo": {
        "name": "Tokyo Night",
        "colors": ["#1a1b26", "#414868", "#f7768e", "#9ece6a", "#a9b1d6", "#e0af68", "#c0caf5"],
        "accent": "#7aa2f7"
    },
    "dracula": {
        "name": "Dracula",
        "colors": ["#282a36", "#44475a", "#ff5555", "#50fa7b", "#f8f8f2", "#f1fa8c", "#ffffff"],
        "accent": "#bd93f9"
    },
    "rose": {
        "name": "Rosé Pine",
        "colors": ["#191724", "#26233a", "#eb6f92", "#9ccfd8", "#e0def4", "#f6c177", "#faf4ed"],
        "accent": "#c4a7e7"
    },
}

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION MANAGEMENT
# ═══════════════════════════════════════════════════════════════════════════════

def load_theming_config() -> Dict:
    """Load theming style configuration"""
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    
    default = {
        "style_mode": "classic",  # "classic" or "modern"
        "modern_palette": "mocha",
        "modern_hue_shift": 0.0,
        "modern_saturation": 1.0,
    }
    
    if THEMING_CONFIG.exists():
        try:
            with open(THEMING_CONFIG) as f:
                saved = json.load(f)
                default.update(saved)
        except Exception as e:
            print(f"[Theming] Error loading config: {e}")
    
    return default


def save_theming_config(config: Dict):
    """Save theming style configuration"""
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    try:
        with open(THEMING_CONFIG, 'w') as f:
            json.dump(config, f, indent=2)
    except Exception as e:
        print(f"[Theming] Error saving config: {e}")


# ═══════════════════════════════════════════════════════════════════════════════
# COLOR UTILITIES
# ═══════════════════════════════════════════════════════════════════════════════

def hex_to_rgb(hex_color: str) -> tuple:
    """Convert hex to RGB tuple (0-1 range)"""
    hex_color = hex_color.lstrip('#')
    r = int(hex_color[0:2], 16) / 255
    g = int(hex_color[2:4], 16) / 255
    b = int(hex_color[4:6], 16) / 255
    return (r, g, b)


def rgb_to_hex(r: float, g: float, b: float) -> str:
    """Convert RGB (0-1) to hex"""
    return f"#{int(r*255):02x}{int(g*255):02x}{int(b*255):02x}"


def shift_hue(hex_color: str, hue_shift: float, saturation_mult: float = 1.0) -> str:
    """Shift hue of a color by given amount (0-1)"""
    r, g, b = hex_to_rgb(hex_color)
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    
    # Shift hue (wrapping around)
    h = (h + hue_shift) % 1.0
    # Adjust saturation
    s = min(1.0, s * saturation_mult)
    
    r, g, b = colorsys.hsv_to_rgb(h, s, v)
    return rgb_to_hex(r, g, b)


# ═══════════════════════════════════════════════════════════════════════════════
# MODERN STYLE WIDGETS
# ═══════════════════════════════════════════════════════════════════════════════

class ColorPaletteCard(Gtk.Button):
    """Single color card in the palette row"""
    
    def __init__(self, color: str, is_selected: bool = False, on_click: Callable = None):
        super().__init__()
        self.color = color
        self._is_selected = is_selected
        self._on_click = on_click
        
        self.set_size_request(48, 48)
        self.add_css_class("palette-card")
        if is_selected:
            self.add_css_class("palette-card-selected")
        
        # Apply color as background
        self._apply_color()
        
        if on_click:
            self.connect("clicked", lambda b: on_click(self.color))
    
    def _apply_color(self):
        """Apply the color to this card via inline CSS"""
        css = f"""
            .palette-card {{
                background-color: {self.color};
                border-radius: 8px;
                border: 2px solid transparent;
                min-width: 48px;
                min-height: 48px;
                transition: all 150ms ease;
            }}
            .palette-card:hover {{
                transform: scale(1.05);
                border-color: rgba(255,255,255,0.3);
            }}
            .palette-card-selected {{
                border: 2px solid #ffffff;
                box-shadow: 0 0 0 1px rgba(0,0,0,0.3);
            }}
        """
        provider = Gtk.CssProvider()
        provider.load_from_data(css.encode())
        self.get_style_context().add_provider(provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION + 100)
    
    def set_selected(self, selected: bool):
        self._is_selected = selected
        if selected:
            self.add_css_class("palette-card-selected")
        else:
            self.remove_css_class("palette-card-selected")
    
    def update_color(self, new_color: str):
        self.color = new_color
        self._apply_color()


class ModernPaletteView(Gtk.Box):
    """Modern palette view with color cards and hue slider"""
    
    def __init__(self, window, on_theme_change: Callable = None):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=16)
        self.window = window
        self.on_theme_change = on_theme_change
        self.config = load_theming_config()
        self.color_cards: List[ColorPaletteCard] = []
        self.selected_index = 0
        
        self.set_margin_start(24)
        self.set_margin_end(24)
        self.set_margin_top(16)
        self.set_margin_bottom(16)
        
        self._build_ui()
        self._apply_css()
    
    def _apply_css(self):
        """Apply Modern view CSS"""
        css = """
            .modern-palette-container {
                background-color: alpha(@card_bg_color, 0.6);
                border-radius: 16px;
                padding: 20px;
                border: 1px solid alpha(white, 0.1);
            }
            
            .palette-row {
                margin-bottom: 16px;
            }
            
            .hue-slider-container {
                margin-top: 8px;
            }
            
            .hue-slider trough {
                background: linear-gradient(to right, 
                    #ff0000, #ffff00, #00ff00, #00ffff, #0000ff, #ff00ff, #ff0000);
                border-radius: 8px;
                min-height: 8px;
            }
            
            .hue-slider highlight {
                background: transparent;
            }
            
            .hue-slider slider {
                background-color: #ffffff;
                border-radius: 50%;
                min-width: 20px;
                min-height: 20px;
                margin: -6px;
                box-shadow: 0 2px 6px rgba(0,0,0,0.4);
                border: 2px solid rgba(255,255,255,0.9);
            }
            
            .palette-preset-dropdown {
                background-color: alpha(white, 0.1);
                border-radius: 8px;
                padding: 8px 12px;
                min-width: 120px;
            }
        """
        provider = Gtk.CssProvider()
        provider.load_from_data(css.encode())
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )
    
    def _build_ui(self):
        """Build the Modern palette UI"""
        # Container with glass effect
        container = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        container.add_css_class("modern-palette-container")
        
        # Header row with title and preset dropdown
        header_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        header_row.set_margin_bottom(8)
        
        title = Gtk.Label(label="Theming")
        title.add_css_class("title-1")
        title.set_halign(Gtk.Align.START)
        title.set_hexpand(True)
        header_row.append(title)
        
        # Preset dropdown
        preset_model = Gtk.StringList()
        for pid, pdata in MODERN_PALETTES.items():
            preset_model.append(pdata["name"])
        
        self.preset_dropdown = Gtk.DropDown(model=preset_model)
        self.preset_dropdown.add_css_class("palette-preset-dropdown")
        
        # Set current selection
        palette_ids = list(MODERN_PALETTES.keys())
        current_palette = self.config.get("modern_palette", "mocha")
        if current_palette in palette_ids:
            self.preset_dropdown.set_selected(palette_ids.index(current_palette))
        
        self.preset_dropdown.connect("notify::selected", self._on_preset_changed)
        header_row.append(self.preset_dropdown)
        
        container.append(header_row)
        
        # Color palette row
        palette_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        palette_row.add_css_class("palette-row")
        palette_row.set_halign(Gtk.Align.CENTER)
        
        current_colors = self._get_current_colors()
        for i, color in enumerate(current_colors):
            card = ColorPaletteCard(
                color=color,
                is_selected=(i == self.selected_index),
                on_click=lambda c, idx=i: self._on_color_selected(idx)
            )
            self.color_cards.append(card)
            palette_row.append(card)
        
        container.append(palette_row)
        
        # Hue slider
        slider_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        slider_box.add_css_class("hue-slider-container")
        
        self.hue_slider = Gtk.Scale(orientation=Gtk.Orientation.HORIZONTAL)
        self.hue_slider.set_range(0, 1)
        self.hue_slider.set_value(self.config.get("modern_hue_shift", 0))
        self.hue_slider.set_draw_value(False)
        self.hue_slider.set_hexpand(True)
        self.hue_slider.add_css_class("hue-slider")
        self.hue_slider.connect("value-changed", self._on_hue_changed)
        
        slider_box.append(self.hue_slider)
        container.append(slider_box)
        
        self.append(container)
    
    def _get_current_colors(self) -> List[str]:
        """Get current palette colors with hue shift applied"""
        palette_id = self.config.get("modern_palette", "mocha")
        base_colors = MODERN_PALETTES.get(palette_id, MODERN_PALETTES["mocha"])["colors"]
        
        hue_shift = self.config.get("modern_hue_shift", 0)
        saturation = self.config.get("modern_saturation", 1.0)
        
        if hue_shift == 0 and saturation == 1.0:
            return base_colors
        
        return [shift_hue(c, hue_shift, saturation) for c in base_colors]
    
    def _on_color_selected(self, index: int):
        """Handle color card selection"""
        self.selected_index = index
        for i, card in enumerate(self.color_cards):
            card.set_selected(i == index)
        
        # Trigger theme change callback
        if self.on_theme_change:
            colors = self._get_current_colors()
            self.on_theme_change(colors, index)
    
    def _on_preset_changed(self, dropdown, param):
        """Handle preset dropdown change"""
        palette_ids = list(MODERN_PALETTES.keys())
        selected_idx = dropdown.get_selected()
        
        if 0 <= selected_idx < len(palette_ids):
            new_palette = palette_ids[selected_idx]
            self.config["modern_palette"] = new_palette
            save_theming_config(self.config)
            
            # Update color cards
            self._update_color_cards()
            
            if self.on_theme_change:
                colors = self._get_current_colors()
                self.on_theme_change(colors, self.selected_index)
    
    def _on_hue_changed(self, slider):
        """Handle hue slider change"""
        self.config["modern_hue_shift"] = slider.get_value()
        save_theming_config(self.config)
        
        # Update color cards with new hue
        self._update_color_cards()
        
        if self.on_theme_change:
            colors = self._get_current_colors()
            self.on_theme_change(colors, self.selected_index)
    
    def _update_color_cards(self):
        """Update all color cards with current colors"""
        colors = self._get_current_colors()
        for i, card in enumerate(self.color_cards):
            if i < len(colors):
                card.update_color(colors[i])


# ═══════════════════════════════════════════════════════════════════════════════
# STYLE MODE TOGGLE
# ═══════════════════════════════════════════════════════════════════════════════

class StyleModeToggle(Gtk.Box):
    """Toggle button group for Classic/Modern style selection"""
    
    def __init__(self, current_mode: str, on_mode_change: Callable):
        super().__init__(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        self.on_mode_change = on_mode_change
        self.current_mode = current_mode
        
        self.add_css_class("linked")
        self.set_halign(Gtk.Align.CENTER)
        self.set_margin_bottom(16)
        
        # Classic button
        self.classic_btn = Gtk.ToggleButton(label="Classic")
        self.classic_btn.set_size_request(100, -1)
        self.classic_btn.set_active(current_mode == "classic")
        self.classic_btn.connect("toggled", self._on_classic_toggled)
        self.append(self.classic_btn)
        
        # Modern button
        self.modern_btn = Gtk.ToggleButton(label="Modern")
        self.modern_btn.set_size_request(100, -1)
        self.modern_btn.set_active(current_mode == "modern")
        self.modern_btn.connect("toggled", self._on_modern_toggled)
        self.append(self.modern_btn)
        
        self._apply_css()
    
    def _apply_css(self):
        css = """
            .style-toggle button {
                font-weight: 600;
                padding: 8px 16px;
            }
            .style-toggle button:checked {
                background-color: @accent_color;
                color: white;
            }
        """
        provider = Gtk.CssProvider()
        provider.load_from_data(css.encode())
        self.get_style_context().add_provider(provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
    
    def _on_classic_toggled(self, btn):
        if btn.get_active():
            self.modern_btn.set_active(False)
            self.current_mode = "classic"
            self.on_mode_change("classic")
    
    def _on_modern_toggled(self, btn):
        if btn.get_active():
            self.classic_btn.set_active(False)
            self.current_mode = "modern"
            self.on_mode_change("modern")


# ═══════════════════════════════════════════════════════════════════════════════
# MAIN PAGE BUILDER
# ═══════════════════════════════════════════════════════════════════════════════

def build_theming_page(window) -> Gtk.Widget:
    """
    Build the Theming page with Classic/Modern toggle
    
    Args:
        window: Parent ControlCenterWindow instance
    
    Returns:
        Gtk.Widget: The theming page container
    """
    config = load_theming_config()
    current_mode = config.get("style_mode", "classic")
    
    # Main container
    page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
    page.set_margin_start(24)
    page.set_margin_end(24)
    page.set_margin_top(24)
    page.set_margin_bottom(24)
    
    # Page header
    header = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
    header.set_margin_bottom(16)
    
    title = Gtk.Label(label="Theming")
    title.add_css_class("page-title")
    title.set_halign(Gtk.Align.START)
    header.append(title)
    
    subtitle = Gtk.Label(label="Choose your preferred theming interface style")
    subtitle.add_css_class("page-subtitle")
    subtitle.set_halign(Gtk.Align.START)
    header.append(subtitle)
    
    page.append(header)
    
    # Style mode toggle
    def on_mode_change(new_mode: str):
        config["style_mode"] = new_mode
        save_theming_config(config)
        _switch_content_view(new_mode)
    
    toggle = StyleModeToggle(current_mode, on_mode_change)
    page.append(toggle)
    
    # Content stack for Classic/Modern views
    content_stack = Gtk.Stack()
    content_stack.set_transition_type(Gtk.StackTransitionType.CROSSFADE)
    content_stack.set_transition_duration(200)
    content_stack.set_vexpand(True)
    
    # Modern view
    def on_theme_change(colors: List[str], selected_index: int):
        """Handle theme change from Modern view"""
        print(f"[Theming] Modern theme updated: {len(colors)} colors, selected: {selected_index}")
        # Here you would apply the colors to your system
        # This integrates with your existing ThemeApplier
        try:
            from .appliers import ThemeApplier
            applier = ThemeApplier()
            # Create a custom theme from the modern palette
            custom_colors = {
                "bg0": colors[0] if len(colors) > 0 else "#282c34",
                "bg1": colors[1] if len(colors) > 1 else "#3e4451",
                "red": colors[2] if len(colors) > 2 else "#e06c75",
                "green": colors[3] if len(colors) > 3 else "#98c379",
                "fg": colors[4] if len(colors) > 4 else "#abb2bf",
                "yellow": colors[5] if len(colors) > 5 else "#e5c07b",
                "white": colors[6] if len(colors) > 6 else "#ffffff",
                "blue": colors[selected_index] if selected_index < len(colors) else "#61afef",
            }
            applier.apply_colors(custom_colors)
        except ImportError:
            print("[Theming] ThemeApplier not available")
        except Exception as e:
            print(f"[Theming] Error applying theme: {e}")
    
    modern_view = ModernPaletteView(window, on_theme_change=on_theme_change)
    content_stack.add_named(modern_view, "modern")
    
    # Classic view - import your existing detailed theming
    classic_view = _build_classic_view(window)
    content_stack.add_named(classic_view, "classic")
    
    # Set initial view
    content_stack.set_visible_child_name(current_mode)
    
    def _switch_content_view(mode: str):
        content_stack.set_visible_child_name(mode)
    
    page.append(content_stack)
    
    return page


def _build_classic_view(window) -> Gtk.Widget:
    """
    Build the Classic theming view with all detailed controls
    This wraps your existing theming UI
    """
    # Try to import existing theming components
    try:
        # Import your existing detailed theming UI components
        from .profile_manager import ThemeProfileManager
        from .themes import BUILTIN_THEMES
        from .appliers import ThemeApplier
        from .preview_widgets import WaybarPreview
        
        return _build_full_classic_view(window)
    except ImportError as e:
        print(f"[Theming] Classic modules not found: {e}")
        return _build_classic_placeholder(window)


def _build_full_classic_view(window) -> Gtk.Widget:
    """Build the full classic theming interface"""
    scrolled = Gtk.ScrolledWindow()
    scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
    
    content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16)
    content.set_margin_start(8)
    content.set_margin_end(8)
    
    # ═══════════════════════════════════════════════════════════════════════════
    # PROFILE SELECTION GROUP
    # ═══════════════════════════════════════════════════════════════════════════
    profile_group = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
    profile_group.add_css_class("settings-group")
    
    profile_title = Gtk.Label(label="THEME PROFILE")
    profile_title.add_css_class("group-title")
    profile_title.set_halign(Gtk.Align.START)
    profile_group.append(profile_title)
    
    # Profile dropdown row
    profile_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
    profile_row.add_css_class("setting-row")
    
    profile_label_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
    profile_label_box.set_hexpand(True)
    
    profile_label = Gtk.Label(label="Active Profile")
    profile_label.add_css_class("setting-label")
    profile_label.set_halign(Gtk.Align.START)
    profile_label_box.append(profile_label)
    
    profile_desc = Gtk.Label(label="Select a built-in or custom theme profile")
    profile_desc.add_css_class("setting-description")
    profile_desc.set_halign(Gtk.Align.START)
    profile_label_box.append(profile_desc)
    
    profile_row.append(profile_label_box)
    
    # Profile dropdown
    try:
        from .profile_manager import ThemeProfileManager
        from .themes import BUILTIN_THEMES
        
        manager = ThemeProfileManager()
        profiles = list(BUILTIN_THEMES.keys()) + manager.list_custom_profiles()
        
        profile_model = Gtk.StringList()
        for p in profiles:
            profile_model.append(p.replace("_", " ").title())
        
        profile_dropdown = Gtk.DropDown(model=profile_model)
        profile_dropdown.set_size_request(180, -1)
        
        # Find current profile
        current = manager.get_active_profile()
        if current in profiles:
            profile_dropdown.set_selected(profiles.index(current))
        
        def on_profile_changed(dd, param):
            idx = dd.get_selected()
            if idx < len(profiles):
                selected = profiles[idx]
                manager.set_active_profile(selected)
                print(f"[Theming] Switched to profile: {selected}")
                # Refresh preview if exists
                if hasattr(window, 'current_theme_data'):
                    window.refresh_theme()
        
        profile_dropdown.connect("notify::selected", on_profile_changed)
        profile_row.append(profile_dropdown)
    except ImportError:
        placeholder = Gtk.Label(label="Not available")
        placeholder.add_css_class("dim-label")
        profile_row.append(placeholder)
    
    profile_group.append(profile_row)
    content.append(profile_group)
    
    # ═══════════════════════════════════════════════════════════════════════════
    # COLOR CUSTOMIZATION GROUP
    # ═══════════════════════════════════════════════════════════════════════════
    colors_group = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
    colors_group.add_css_class("settings-group")
    
    colors_title = Gtk.Label(label="COLOR CUSTOMIZATION")
    colors_title.add_css_class("group-title")
    colors_title.set_halign(Gtk.Align.START)
    colors_group.append(colors_title)
    
    # Color swatches grid
    color_keys = [
        ("bg0", "Background", "Primary background color"),
        ("bg1", "Surface", "Card and surface color"),
        ("fg", "Foreground", "Main text color"),
        ("blue", "Accent", "Primary accent color"),
        ("green", "Success", "Success/positive color"),
        ("red", "Error", "Error/destructive color"),
        ("yellow", "Warning", "Warning color"),
        ("purple", "Purple", "Secondary accent"),
    ]
    
    for key, label, desc in color_keys:
        row = _create_color_row(key, label, desc, window)
        colors_group.append(row)
    
    content.append(colors_group)
    
    # ═══════════════════════════════════════════════════════════════════════════
    # APPLY TARGETS GROUP
    # ═══════════════════════════════════════════════════════════════════════════
    targets_group = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
    targets_group.add_css_class("settings-group")
    
    targets_title = Gtk.Label(label="APPLY TO")
    targets_title.add_css_class("group-title")
    targets_title.set_halign(Gtk.Align.START)
    targets_group.append(targets_title)
    
    targets = [
        ("waybar", "Waybar", "Apply colors to status bar"),
        ("rofi", "Rofi", "Apply colors to app launcher"),
        ("kitty", "Kitty Terminal", "Apply colors to terminal"),
        ("control_center", "Control Center", "Apply colors to this app"),
    ]
    
    for target_id, label, desc in targets:
        row = _create_toggle_row(target_id, label, desc)
        targets_group.append(row)
    
    content.append(targets_group)
    
    # ═══════════════════════════════════════════════════════════════════════════
    # ACTION BUTTONS
    # ═══════════════════════════════════════════════════════════════════════════
    actions = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
    actions.set_halign(Gtk.Align.END)
    actions.set_margin_top(16)
    
    reset_btn = Gtk.Button(label="Reset")
    reset_btn.add_css_class("destructive-action")
    actions.append(reset_btn)
    
    apply_btn = Gtk.Button(label="Apply Theme")
    apply_btn.add_css_class("suggested-action")
    
    def on_apply(btn):
        try:
            from .appliers import ThemeApplier
            applier = ThemeApplier()
            applier.apply_all()
            if hasattr(window, '_show_toast'):
                window._show_toast("Theme applied successfully!")
        except Exception as e:
            print(f"[Theming] Apply error: {e}")
    
    apply_btn.connect("clicked", on_apply)
    actions.append(apply_btn)
    
    content.append(actions)
    
    scrolled.set_child(content)
    return scrolled


def _build_classic_placeholder(window) -> Gtk.Widget:
    """Build placeholder when classic modules aren't available"""
    box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16)
    box.set_valign(Gtk.Align.CENTER)
    box.set_vexpand(True)
    
    icon = Gtk.Label(label="󰍣")
    icon.set_css_classes(["page-title"])
    icon.set_opacity(0.5)
    box.append(icon)
    
    msg = Gtk.Label(label="Classic theming modules not found")
    msg.add_css_class("dim-label")
    box.append(msg)
    
    hint = Gtk.Label()
    hint.set_markup("<small>Install theming modules to enable detailed customization</small>")
    hint.add_css_class("dim-label")
    box.append(hint)
    
    return box


def _create_color_row(key: str, label: str, desc: str, window) -> Gtk.Box:
    """Create a color picker row"""
    row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
    row.add_css_class("setting-row")
    
    label_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
    label_box.set_hexpand(True)
    
    lbl = Gtk.Label(label=label)
    lbl.add_css_class("setting-label")
    lbl.set_halign(Gtk.Align.START)
    label_box.append(lbl)
    
    desc_lbl = Gtk.Label(label=desc)
    desc_lbl.add_css_class("setting-description")
    desc_lbl.set_halign(Gtk.Align.START)
    label_box.append(desc_lbl)
    
    row.append(label_box)
    
    # Color button
    color_btn = Gtk.ColorButton()
    color_btn.set_size_request(80, 32)
    
    # Try to get current color from theme
    try:
        if hasattr(window, 'current_theme_data') and window.current_theme_data:
            colors = window.current_theme_data.get('colors', {})
            if key in colors:
                rgba = Gdk.RGBA()
                rgba.parse(colors[key])
                color_btn.set_rgba(rgba)
    except Exception:
        pass
    
    row.append(color_btn)
    
    return row


def _create_toggle_row(key: str, label: str, desc: str) -> Gtk.Box:
    """Create a toggle switch row"""
    row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
    row.add_css_class("setting-row")
    
    label_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
    label_box.set_hexpand(True)
    
    lbl = Gtk.Label(label=label)
    lbl.add_css_class("setting-label")
    lbl.set_halign(Gtk.Align.START)
    label_box.append(lbl)
    
    desc_lbl = Gtk.Label(label=desc)
    desc_lbl.add_css_class("setting-description")
    desc_lbl.set_halign(Gtk.Align.START)
    label_box.append(desc_lbl)
    
    row.append(label_box)
    
    switch = Gtk.Switch()
    switch.set_active(True)
    switch.set_valign(Gtk.Align.CENTER)
    row.append(switch)
    
    return row


# ═══════════════════════════════════════════════════════════════════════════════
# EXPORTS
# ═══════════════════════════════════════════════════════════════════════════════

__all__ = [
    'build_theming_page',
    'ModernPaletteView',
    'StyleModeToggle',
    'ColorPaletteCard',
    'load_theming_config',
    'save_theming_config',
    'MODERN_PALETTES',
]