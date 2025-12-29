"""
Appearance page - Look & Feel configuration
"""

import gi
gi.require_version('Gtk', '4.0')
from gi.repository import Gtk

from ..widgets import (
    SettingsGroup, IntegerRow, ColorPickerRow, ToggleRow,
    DropdownRow, FloatRow, SectionHeader
)

def build_appearance_page(window) -> Gtk.ScrolledWindow:
    """Build Appearance settings page"""
    scrolled = Gtk.ScrolledWindow()
    scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
    
    content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
    content.add_css_class('content-area')
    
    # Header
    header = window._create_page_header(
        "Appearance",
        "Customize window borders, gaps, rounding, and effects"
    )
    content.append(header)
    
    # General Section
    general_group = SettingsGroup("General")
    
    # Gaps In
    w = IntegerRow("Gaps In", window.config.general.gaps_in, 0, 1000,
                   lambda v: setattr(window.config.general, 'gaps_in', v),
                   "Space between windows")
    window.widgets['gaps_in'] = w
    general_group.append(w)
    
    # Gaps Out
    w = IntegerRow("Gaps Out", window.config.general.gaps_out, 0, 1000,
                   lambda v: setattr(window.config.general, 'gaps_out', v),
                   "Space between windows and screen edge")
    window.widgets['gaps_out'] = w
    general_group.append(w)
    
    # Border Size
    w = IntegerRow("Border Size", window.config.general.border_size, 0, 100,
                   lambda v: setattr(window.config.general, 'border_size', v),
                   "Window border thickness in pixels")
    window.widgets['border_size'] = w
    general_group.append(w)
    
    # Active Border Color
    w = ColorPickerRow("Active Border Color", window.config.general.col_active_border,
                       lambda v: setattr(window.config.general, 'col_active_border', v),
                       "Color of focused window border")
    window.widgets['col_active_border'] = w
    general_group.append(w)
    
    # Inactive Border Color
    w = ColorPickerRow("Inactive Border Color", window.config.general.col_inactive_border,
                       lambda v: setattr(window.config.general, 'col_inactive_border', v),
                       "Color of unfocused window borders")
    window.widgets['col_inactive_border'] = w
    general_group.append(w)
    
    # Resize on Border
    w = ToggleRow("Resize on Border", window.config.general.resize_on_border,
                  lambda v: setattr(window.config.general, 'resize_on_border', v),
                  "Enable resizing by dragging borders")
    window.widgets['resize_on_border'] = w
    general_group.append(w)
    
    # Allow Tearing
    w = ToggleRow("Allow Tearing", window.config.general.allow_tearing,
                  lambda v: setattr(window.config.general, 'allow_tearing', v),
                  "Allow screen tearing for games")
    window.widgets['allow_tearing'] = w
    general_group.append(w)
    
    # Layout
    w = DropdownRow("Layout", ["dwindle", "master"], window.config.general.layout,
                    lambda v: setattr(window.config.general, 'layout', v),
                    "Window tiling layout algorithm")
    window.widgets['layout'] = w
    general_group.append(w)
    
    content.append(general_group)
    
    # Decoration Section
    decoration_group = SettingsGroup("Decoration")
    
    # Rounding
    w = IntegerRow("Rounding", window.config.decoration.rounding, 0, 100,
                   lambda v: setattr(window.config.decoration, 'rounding', v),
                   "Corner rounding radius in pixels")
    window.widgets['rounding'] = w
    decoration_group.append(w)
    
    # Rounding Power
    w = IntegerRow("Rounding Power", window.config.decoration.rounding_power, 1, 10,
                   lambda v: setattr(window.config.decoration, 'rounding_power', v),
                   "Smoothness of corner curves")
    window.widgets['rounding_power'] = w
    decoration_group.append(w)
    
    # Active Opacity
    w = FloatRow("Active Opacity", window.config.decoration.active_opacity, 0.0, 1.0,
                 lambda v: setattr(window.config.decoration, 'active_opacity', v),
                 "Transparency of focused windows")
    window.widgets['active_opacity'] = w
    decoration_group.append(w)
    
    # Inactive Opacity
    w = FloatRow("Inactive Opacity", window.config.decoration.inactive_opacity, 0.0, 1.0,
                 lambda v: setattr(window.config.decoration, 'inactive_opacity', v),
                 "Transparency of unfocused windows")
    window.widgets['inactive_opacity'] = w
    decoration_group.append(w)
    
    # Shadow header
    decoration_group.append(SectionHeader("Shadow"))
    
    # Shadow Enabled
    w = ToggleRow("Shadow Enabled", window.config.decoration.shadow_enabled,
                  lambda v: setattr(window.config.decoration, 'shadow_enabled', v))
    window.widgets['shadow_enabled'] = w
    decoration_group.append(w)
    
    # Shadow Range
    w = IntegerRow("Shadow Range", window.config.decoration.shadow_range, 0, 100,
                   lambda v: setattr(window.config.decoration, 'shadow_range', v),
                   "Shadow blur radius")
    window.widgets['shadow_range'] = w
    decoration_group.append(w)
    
    # Shadow Color
    w = ColorPickerRow("Shadow Color", window.config.decoration.shadow_color,
                       lambda v: setattr(window.config.decoration, 'shadow_color', v))
    window.widgets['shadow_color'] = w
    decoration_group.append(w)
    
    # Blur header
    decoration_group.append(SectionHeader("Blur"))
    
    # Blur Enabled
    w = ToggleRow("Blur Enabled", window.config.decoration.blur_enabled,
                  lambda v: setattr(window.config.decoration, 'blur_enabled', v))
    window.widgets['blur_enabled'] = w
    decoration_group.append(w)
    
    # Blur Size
    w = IntegerRow("Blur Size", window.config.decoration.blur_size, 1, 50,
                   lambda v: setattr(window.config.decoration, 'blur_size', v),
                   "Blur kernel size")
    window.widgets['blur_size'] = w
    decoration_group.append(w)
    
    # Blur Passes
    w = IntegerRow("Blur Passes", window.config.decoration.blur_passes, 1, 10,
                   lambda v: setattr(window.config.decoration, 'blur_passes', v),
                   "Number of blur iterations")
    window.widgets['blur_passes'] = w
    decoration_group.append(w)
    
    content.append(decoration_group)
    
    # Action buttons
    content.append(window._create_action_buttons(
        on_reset=window._on_appearance_reset,
        on_apply=window._on_appearance_apply
    ))
    
    scrolled.set_child(content)
    return scrolled
