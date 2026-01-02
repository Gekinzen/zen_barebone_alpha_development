"""
Animations Configuration Page
Manages Hyprland animation presets with state persistence
"""

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
from gi.repository import Gtk, Adw
import subprocess
import os
import json
from pathlib import Path
from datetime import datetime

# State file for persistence
STATE_FILE = Path.home() / ".config/hypr-control-center/animations.json"


def build_animations_page(window) -> Gtk.ScrolledWindow:
    """Build Animations settings page with preset selector"""
    scrolled = Gtk.ScrolledWindow()
    scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
    
    content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
    content.add_css_class('content-area')
    
    # Header
    page_header = window._create_page_header(
        "Animations",
        "Choose animation preset for Hyprland window manager"
    )
    content.append(page_header)
    
    # Main content
    main_content = _build_animations_content(window)
    content.append(main_content)
    
    scrolled.set_child(content)
    return scrolled


def _build_animations_content(window) -> Gtk.Box:
    """Build main animations content"""
    content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16)
    content.set_margin_start(32)
    content.set_margin_end(32)
    content.set_margin_top(16)
    content.set_margin_bottom(16)
    
    # Animation presets dictionary
    animation_presets = _get_animation_presets()
    
    # Store in window for later use
    if not hasattr(window, 'animation_presets'):
        window.animation_presets = animation_presets
        
        # Detect current preset from config or state file
        window.current_animation_preset = _detect_current_preset(animation_presets)
    
    from ..widgets import SettingsGroup, DropdownRow
    
    selection_group = SettingsGroup("Animation Preset")
    
    # Get preset names
    preset_names = list(animation_presets.keys())
    
    # Dropdown for preset selection
    preset_row = DropdownRow(
        "Select Preset",
        preset_names,
        window.current_animation_preset,
        lambda v: _on_preset_changed(window, v),
        "Choose from community-curated animation styles"
    )
    window.widgets['animation_preset'] = preset_row
    selection_group.append(preset_row)
    
    content.append(selection_group)
    
    preview_group = SettingsGroup("Configuration Preview")
    
    info = Gtk.Label(label="Preview of the selected animation configuration")
    info.add_css_class('setting-description')
    info.set_halign(Gtk.Align.START)
    info.set_margin_bottom(8)
    preview_group.append(info)
    
    # Text view for preview
    textview = Gtk.TextView()
    textview.set_editable(False)
    textview.set_monospace(True)
    textview.set_wrap_mode(Gtk.WrapMode.NONE)
    textview.set_margin_top(10)
    textview.set_margin_bottom(10)
    textview.set_margin_start(10)
    textview.set_margin_end(10)
    
    # Set initial preview
    buffer = textview.get_buffer()
    buffer.set_text(animation_presets[window.current_animation_preset])
    
    # Store textview reference
    window.animation_preview_textview = textview
    
    # Scrolled window for text view
    preview_scroll = Gtk.ScrolledWindow()
    preview_scroll.set_child(textview)
    preview_scroll.set_min_content_height(300)
    preview_scroll.set_vexpand(True)
    
    # Frame for preview
    preview_frame = Gtk.Frame()
    preview_frame.set_child(preview_scroll)
    
    preview_group.append(preview_frame)
    content.append(preview_group)
    
    content.append(window._create_action_buttons(
        on_reset=lambda b: _on_animations_reset(window),
        on_apply=lambda b: _on_animations_apply(window)
    ))
    
    return content


def _load_animation_state() -> str:
    """Load current animation preset from state file"""
    try:
        if STATE_FILE.exists():
            with open(STATE_FILE, 'r') as f:
                data = json.load(f)
                return data.get('current_preset', 'Default (Current)')
    except Exception as e:
        print(f"Failed to load animation state: {e}")
    
    return 'Default (Current)'


def _save_animation_state(preset_name: str):
    """Save current animation preset to state file"""
    try:
        STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
        
        state = {
            'current_preset': preset_name,
            'last_applied': datetime.now().isoformat()
        }
        
        with open(STATE_FILE, 'w') as f:
            json.dump(state, f, indent=2)
            
    except Exception as e:
        print(f"Failed to save animation state: {e}")


def _detect_current_preset(animation_presets: dict) -> str:
    """
    Detect current animation preset by reading animations.conf
    Returns best matching preset name or state file value
    """
    animations_conf = Path.home() / ".config/hypr/modules/animations.conf"
    
    if not animations_conf.exists():
        return _load_animation_state()
    
    try:
        with open(animations_conf, 'r') as f:
            current_config = f.read()
        
        # Extract just the animations block (ignore comments/headers)
        for preset_name, preset_config in animation_presets.items():
            if _configs_match(current_config, preset_config):
                return preset_name
        
        # If no match, check state file
        return _load_animation_state()
        
    except Exception as e:
        print(f"Failed to detect preset: {e}")
        return _load_animation_state()


def _configs_match(config1: str, config2: str) -> bool:
    """Compare two animation configs (normalized)"""
    def normalize(config):
        # Remove comments, extra whitespace, empty lines
        lines = []
        for line in config.split('\n'):
            # Strip comments
            if '#' in line:
                line = line[:line.index('#')]
            line = line.strip()
            if line and not line.startswith('#'):
                lines.append(line)
        return '\n'.join(sorted(lines))
    
    norm1 = normalize(config1)
    norm2 = normalize(config2)
    
    # Match if >80% of lines are identical
    lines1 = set(norm1.split('\n'))
    lines2 = set(norm2.split('\n'))
    
    if not lines1 or not lines2:
        return False
    
    common = lines1 & lines2
    similarity = len(common) / max(len(lines1), len(lines2))
    
    return similarity > 0.8


def _send_swaync_notification(title: str, body: str, urgency: str = "normal"):
    """Send notification via notify-send (works with swaync)"""
    try:
        subprocess.run([
            'notify-send',
            '-u', urgency,
            '-a', 'Hyprland Control Center',
            '-i', 'preferences-desktop-effects',  # Icon name
            title,
            body
        ], timeout=2)
    except Exception as e:
        print(f"Failed to send notification: {e}")


def _on_preset_changed(window, preset_name: str):
    """Handle preset selection change"""
    window.current_animation_preset = preset_name
    
    # Update preview
    if hasattr(window, 'animation_preview_textview'):
        buffer = window.animation_preview_textview.get_buffer()
        config_text = window.animation_presets[preset_name]
        buffer.set_text(config_text)


def _on_animations_reset(window):
    """Reset to default animation preset"""
    dialog = Adw.MessageDialog(
        transient_for=window,
        heading="Reset Animations?",
        body="This will restore animations to your default configuration."
    )
    dialog.add_response("cancel", "Cancel")
    dialog.add_response("reset", "Reset")
    dialog.set_response_appearance("reset", Adw.ResponseAppearance.DESTRUCTIVE)
    
    def on_response(dlg, response):
        if response == "reset":
            window.current_animation_preset = "Default (Current)"
            
            # Save state
            _save_animation_state("Default (Current)")
            
            # Update preview
            if hasattr(window, 'animation_preview_textview'):
                buffer = window.animation_preview_textview.get_buffer()
                buffer.set_text(window.animation_presets["Default (Current)"])
            
            # Apply changes
            _on_animations_apply(window)
            
            # Toast notification
            window._show_toast("Animations reset to default")
            
            # Swaync notification
            _send_swaync_notification(
                "Animations Reset",
                "Animation settings restored to default configuration",
                "normal"
            )
    
    dialog.connect('response', on_response)
    dialog.present()


def _on_animations_apply(window):
    """Apply selected animation preset to Hyprland"""
    animations_conf_path = Path.home() / ".config/hypr/modules/animations.conf"
    
    preset_name = window.current_animation_preset
    config_content = window.animation_presets[preset_name]
    
    # Add header comment
    header = f"""# ----------------------------------------------------- 
# ▄▀█ █▄░█ █ █▀▄▀█ ▄▀█ ▀█▀ █ █▀█ █▄░█
# █▀█ █░▀█ █ █░▀░█ █▀█ ░█░ █ █▄█ █░▀█
#
# Animation Preset: {preset_name}
# Applied by Hyprland Control Center
# https://wiki.hypr.land/Configuring/Animations/
# ----------------------------------------------------- 

"""
    
    full_content = header + config_content + "\n"
    
    try:
        # Ensure modules directory exists
        animations_conf_path.parent.mkdir(parents=True, exist_ok=True)
        
        # Write to animations.conf
        with open(animations_conf_path, 'w') as f:
            f.write(full_content)
        
        # Save state to JSON
        _save_animation_state(preset_name)
        
        # Reload Hyprland config
        subprocess.run(['hyprctl', 'reload'], check=True, timeout=5)
        
        # Toast notification (in-app)
        window._show_toast(f"Applied '{preset_name}' animation preset")
        
        # Swaync notification (system-wide)
        _send_swaync_notification(
            "Animations Applied",
            f"Animation preset '{preset_name}' has been applied successfully",
            "normal"
        )
        
    except subprocess.TimeoutExpired:
        window._show_toast("Warning: Hyprland reload timed out")
        _send_swaync_notification(
            "Animation Warning",
            "Animation applied but Hyprland reload timed out",
            "normal"
        )
    except Exception as e:
        error_msg = f"Failed to apply animation: {str(e)}"
        window._show_toast(error_msg)
        _send_swaync_notification(
            "Animation Error",
            error_msg,
            "critical"
        )


def _get_animation_presets() -> dict:
    """Get all animation presets"""
    return {
        "Default (Current)": """animations {
    enabled = yes, please :)
    bezier = easeOutQuint, 0.23, 1, 0.32, 1
    bezier = easeInOutCubic, 0.65, 0.05, 0.36, 1
    bezier = linear, 0, 0, 1, 1
    bezier = almostLinear, 0.5, 0.5, 0.75, 1
    bezier = quick, 0.15, 0, 0.1, 1
    animation = global, 1, 10, default
    animation = border, 1, 5.39, easeOutQuint
    animation = windows, 1, 4.79, easeOutQuint
    animation = windowsIn, 1, 4.1, easeOutQuint, popin 87%
    animation = windowsOut, 1, 1.49, linear, popin 87%
    animation = fadeIn, 1, 1.73, almostLinear
    animation = fadeOut, 1, 1.46, almostLinear
    animation = fade, 1, 3.03, quick
    animation = layers, 1, 3.81, easeOutQuint
    animation = layersIn, 1, 4, easeOutQuint, fade
    animation = layersOut, 1, 1.5, linear, fade
    animation = fadeLayersIn, 1, 1.79, almostLinear
    animation = fadeLayersOut, 1, 1.39, almostLinear
    animation = workspaces, 1, 1.94, almostLinear, fade
    animation = workspacesIn, 1, 1.21, almostLinear, fade
    animation = workspacesOut, 1, 1.94, almostLinear, fade
    animation = zoomFactor, 1, 7, quick
}""",
        "Classic": """animations {
    enabled = true
    bezier = myBezier, 0.05, 0.9, 0.1, 1.05
    animation = windows, 1, 7, myBezier
    animation = windowsOut, 1, 7, default, popin 80%
    animation = border, 1, 10, default
    animation = borderangle, 1, 8, default
    animation = fade, 1, 7, default
    animation = workspaces, 1, 6, default
}""",
        "HyDe Diablo-1": """animations {
    enabled = 1
    bezier = default, 0.05, 0.9, 0.1, 1.05
    bezier = wind, 0.05, 0.9, 0.1, 1.05
    bezier = overshot, 0.13, 0.99, 0.29, 1.08
    bezier = liner, 1, 1, 1, 1
    bezier = bounce, 0.4, 0.9, 0.6, 1.0
    bezier = snappyReturn, 0.4, 0.9, 0.6, 1.0
    bezier = slideInFromRight, 0.5, 0.0, 0.5, 1.0
    animation = windows, 1, 5, snappyReturn, slidevert
    animation = windowsIn, 1, 5, snappyReturn, slidevert right
    animation = windowsOut, 1, 5, snappyReturn, slide
    animation = windowsMove, 1, 6, bounce, slide
    animation = layersOut, 1, 5, bounce, slidevert right
    animation = fadeIn, 1, 10, default
    animation = fadeOut, 1, 10, default
    animation = fadeSwitch, 1, 10, default
    animation = fadeShadow, 1, 10, default
    animation = fadeDim, 1, 10, default
    animation = fadeLayers, 1, 10, default
    animation = workspaces, 1, 7, overshot, slidevert
    animation = border, 1, 1, liner
    animation = layers, 1, 4, bounce, slidevert right
    animation = borderangle, 1, 30, liner, loop
}""",
        "HyDe Diablo-2": """animations {
    enabled = 1
    bezier = default, 0.05, 0.9, 0.1, 1.05
    bezier = wind, 0.05, 0.9, 0.1, 1.05
    bezier = overshot, 0.13, 0.99, 0.29, 1.08
    bezier = liner, 1, 1, 1, 1
    animation = windows, 1, 7, wind, popin
    animation = windowsIn, 1, 7, overshot, popin
    animation = windowsOut, 1, 5, overshot, popin
    animation = windowsMove, 1, 6, overshot, slide
    animation = layers, 1, 5, default, popin
    animation = fadeIn, 1, 10, default
    animation = fadeOut, 1, 10, default
    animation = fadeSwitch, 1, 10, default
    animation = fadeShadow, 1, 10, default
    animation = fadeDim, 1, 10, default
    animation = fadeLayers, 1, 10, default
    animation = workspaces, 1, 7, overshot, slidevert
    animation = border, 1, 1, liner
    animation = borderangle, 1, 30, liner, loop
}""",
        "Disabled": """animations:enabled=false""",
        "HyDe Dynamic": """animations {
    enabled = true
    bezier = wind, 0.05, 0.9, 0.1, 1.05
    bezier = winIn, 0.1, 1.1, 0.1, 1.1
    bezier = winOut, 0.3, -0.3, 0, 1
    bezier = liner, 1, 1, 1, 1
    animation = windows, 1, 6, wind, slide
    animation = windowsIn, 1, 6, winIn, slide
    animation = windowsOut, 1, 5, winOut, slide
    animation = windowsMove, 1, 5, wind, slide
    animation = border, 1, 1, liner
    animation = borderangle, 1, 30, liner, loop
    animation = fade, 1, 10, default
    animation = workspaces, 1, 5, wind
}""",
        "End4 Animation": """animations {
    enabled = true
    bezier = linear, 0, 0, 1, 1
    bezier = md3_standard, 0.2, 0, 0, 1
    bezier = md3_decel, 0.05, 0.7, 0.1, 1
    bezier = md3_accel, 0.3, 0, 0.8, 0.15
    bezier = overshot, 0.05, 0.9, 0.1, 1.1
    bezier = crazyshot, 0.1, 1.5, 0.76, 0.92
    bezier = hyprnostretch, 0.05, 0.9, 0.1, 1.0
    bezier = menu_decel, 0.1, 1, 0, 1
    bezier = menu_accel, 0.38, 0.04, 1, 0.07
    bezier = easeInOutCirc, 0.85, 0, 0.15, 1
    bezier = easeOutCirc, 0, 0.55, 0.45, 1
    bezier = easeOutExpo, 0.16, 1, 0.3, 1
    bezier = softAcDecel, 0.26, 0.26, 0.15, 1
    bezier = md2, 0.4, 0, 0.2, 1
    animation = windows, 1, 3, md3_decel, popin 60%
    animation = windowsIn, 1, 3, md3_decel, popin 60%
    animation = windowsOut, 1, 3, md3_accel, popin 60%
    animation = border, 1, 10, default
    animation = fade, 1, 3, md3_decel
    animation = layersIn, 1, 3, menu_decel, slide
    animation = layersOut, 1, 1.6, menu_accel
    animation = fadeLayersIn, 1, 2, menu_decel
    animation = fadeLayersOut, 1, 4.5, menu_accel
    animation = workspaces, 1, 7, menu_decel, slide
    animation = specialWorkspace, 1, 3, md3_decel, slidevert
}""",
        "Fast": """animations {
    enabled = true
    bezier = md3_decel, 0.05, 0.7, 0.1, 1
    bezier = md3_accel, 0.3, 0, 0.8, 0.15
    bezier = easeOutExpo, 0.16, 1, 0.3, 1
    animation = windows, 1, 3, md3_decel, popin 60%
    animation = border, 1, 10, default
    animation = fade, 1, 2.5, md3_decel
    animation = workspaces, 1, 3.5, easeOutExpo, slide
    animation = specialWorkspace, 1, 3, md3_decel, slidevert
}""",
        "High": """animations {
    enabled = true
    bezier = wind, 0.05, 0.9, 0.1, 1.05
    bezier = winIn, 0.1, 1.1, 0.1, 1.1
    bezier = winOut, 0.3, -0.3, 0, 1
    bezier = liner, 1, 1, 1, 1
    animation = windows, 1, 6, wind, slide
    animation = windowsIn, 1, 6, winIn, slide
    animation = windowsOut, 1, 5, winOut, slide
    animation = windowsMove, 1, 5, wind, slide
    animation = border, 1, 1, liner
    animation = borderangle, 1, 30, liner, loop
    animation = fade, 1, 10, default
    animation = workspaces, 1, 5, wind
}""",
        "Ja (JaKooLit)": """animations {
    enabled = yes
    bezier = wind, 0.05, 0.9, 0.1, 1.05
    bezier = winIn, 0.1, 1.1, 0.1, 1.1
    bezier = winOut, 0.3, -0.3, 0, 1
    bezier = liner, 1, 1, 1, 1
    bezier = overshot, 0.05, 0.9, 0.1, 1.05
    bezier = smoothOut, 0.5, 0, 0.99, 0.99
    bezier = smoothIn, 0.5, -0.5, 0.68, 1.5
    animation = windows, 1, 6, wind, slide
    animation = windowsIn, 1, 5, winIn, slide
    animation = windowsOut, 1, 3, smoothOut, slide
    animation = windowsMove, 1, 5, wind, slide
    animation = border, 1, 1, liner
    animation = fade, 1, 3, smoothOut
    animation = workspaces, 1, 5, overshot
    animation = workspacesIn, 1, 5, winIn, slide
    animation = workspacesOut, 1, 5, winOut, slide
}""",
        "LimeFrenzy": """animations {
    enabled = 1
    bezier = default, 0.12, 0.92, 0.08, 1.0
    bezier = wind, 0.12, 0.92, 0.08, 1.0
    bezier = overshot, 0.18, 0.95, 0.22, 1.03
    bezier = liner, 1, 1, 1, 1
    animation = windows, 1, 5, wind, popin 60%
    animation = windowsIn, 1, 6, overshot, popin 60%
    animation = windowsOut, 1, 4, overshot, popin 60%
    animation = windowsMove, 1, 4, overshot, slide
    animation = layers, 1, 4, default, popin
    animation = fadeIn, 1, 7, default
    animation = fadeOut, 1, 7, default
    animation = workspaces, 1, 5, overshot, slidevert
    animation = border, 1, 1, liner
    animation = borderangle, 1, 24, liner, loop
}""",
        "Me-1": """animations {
    enabled = true
    bezier = wind, 0.05, 0.9, 0.1, 1.05
    bezier = winIn, 0.1, 1.1, 0.1, 1.1
    bezier = winOut, 0.3, -0.3, 0, 1
    bezier = liner, 1, 1, 1, 1
    bezier = md3_decel, 0.05, 0.7, 0.1, 1
    bezier = menu_decel, 0.1, 1, 0, 1
    bezier = menu_accel, 0.38, 0.04, 1, 0.07
    animation = border, 1, 1, liner
    animation = borderangle, 1, 30, liner, loop
    animation = windows, 1, 6, wind, slide
    animation = windowsIn, 1, 6, winIn, slide
    animation = windowsOut, 1, 5, winOut, slide
    animation = windowsMove, 1, 5, wind, slide
    animation = fade, 1, 3, md3_decel
    animation = layersIn, 1, 3, menu_decel, slide
    animation = layersOut, 1, 1.6, menu_accel
    animation = fadeLayersIn, 1, 2, menu_decel
    animation = fadeLayersOut, 1, 4.5, menu_accel
    animation = workspaces, 1, 7, menu_decel, slide
    animation = specialWorkspace, 1, 3, md3_decel, slidevert
}""",
        "Me-2": """animations {
    enabled = true
    bezier = wind, 0.05, 0.9, 0.1, 1.05
    bezier = winIn, 0.1, 1.1, 0.1, 1.1
    bezier = liner, 1, 1, 1, 1
    bezier = md3_decel, 0.05, 0.7, 0.1, 1
    bezier = menu_decel, 0.1, 1, 0, 1
    bezier = menu_accel, 0.38, 0.04, 1, 0.07
    bezier = OutBack, 0.34, 1.56, 0.64, 1
    bezier = easeInOutCirc, 0.85, 0, 0.15, 1
    animation = border, 1, 1, liner
    animation = borderangle, 1, 30, liner, loop
    animation = windowsIn, 1, 6, winIn, slide
    animation = windows, 1, 5, easeInOutCirc
    animation = windowsOut, 1, 5, OutBack
    animation = windowsMove, 1, 5, wind, slide
    animation = fade, 1, 3, md3_decel
    animation = layersIn, 1, 3, menu_decel, slide
    animation = layersOut, 1, 1.6, menu_accel
    animation = fadeLayersIn, 1, 2, menu_decel
    animation = fadeLayersOut, 1, 4.5, menu_accel
    animation = workspaces, 1, 7, menu_decel, slide
    animation = specialWorkspace, 1, 3, md3_decel, slidevert
}""",
        "Minimal-1": """animations {
    enabled = true
    bezier = wind, 0.05, 0.9, 0.1, 1.05
    bezier = winIn, 0.1, 1.1, 0.1, 1.1
    bezier = winOut, 0.3, -0.3, 0, 1
    bezier = liner, 1, 1, 1, 1
    animation = windows, 1, 6, wind, slide
    animation = windowsIn, 1, 6, winIn, slide
    animation = windowsOut, 1, 5, winOut, slide
    animation = windowsMove, 1, 5, wind, slide
    animation = border, 1, 1, liner
    animation = borderangle, 1, 30, liner, loop
    animation = fade, 1, 10, default
    animation = workspaces, 1, 5, wind
}""",
        "Minimal-2": """animations {
    enabled = yes
    bezier = quart, 0.25, 1, 0.5, 1
    animation = windows, 1, 6, quart, slide
    animation = border, 1, 6, quart
    animation = borderangle, 1, 6, quart
    animation = fade, 1, 6, quart
    animation = workspaces, 1, 6, quart
}""",
        "Moving": """animations {
    enabled = true
    bezier = overshot, 0.05, 0.9, 0.1, 1.05
    bezier = smoothOut, 0.5, 0, 0.99, 0.99
    bezier = smoothIn, 0.5, -0.5, 0.68, 1.5
    animation = windows, 1, 5, overshot, slide
    animation = windowsOut, 1, 3, smoothOut
    animation = windowsIn, 1, 3, smoothOut
    animation = windowsMove, 1, 4, smoothIn, slide
    animation = border, 1, 5, default
    animation = fade, 1, 5, smoothIn
    animation = fadeDim, 1, 5, smoothIn
    animation = workspaces, 1, 6, default
}""",
        "Optimized": """animations {
    enabled = true
    bezier = wind, 0.05, 0.85, 0.03, 0.97
    bezier = winIn, 0.07, 0.88, 0.04, 0.99
    bezier = liner, 1, 1, 1, 1
    bezier = md3_decel, 0.05, 0.80, 0.10, 0.97
    bezier = menu_decel, 0.05, 0.82, 0, 1
    bezier = menu_accel, 0.20, 0, 0.82, 0.10
    bezier = easeOutCirc, 0, 0.48, 0.38, 1
    animation = border, 1, 1.6, liner
    animation = borderangle, 1, 82, liner, loop
    animation = windowsIn, 1, 3.2, winIn, slide
    animation = windowsOut, 1, 2.8, easeOutCirc
    animation = windowsMove, 1, 3.0, wind, slide
    animation = fade, 1, 1.8, md3_decel
    animation = layersIn, 1, 1.8, menu_decel, slide
    animation = layersOut, 1, 1.5, menu_accel
    animation = fadeLayersIn, 1, 1.6, menu_decel
    animation = fadeLayersOut, 1, 1.8, menu_accel
    animation = workspaces, 1, 4.0, menu_decel, slide
    animation = specialWorkspace, 1, 2.3, md3_decel, slidefadevert 15%
}""",
        "Standard": """animations {
    enabled = true
    bezier = myBezier, 0.05, 0.9, 0.1, 1.05
    animation = windows, 1, 7, myBezier
    animation = windowsOut, 1, 7, default, popin 80%
    animation = border, 1, 10, default
    animation = borderangle, 1, 8, default
    animation = fade, 1, 7, default
    animation = workspaces, 1, 6, default
}""",
        "Vertical": """animations {
    bezier = fluent_decel, 0, 0.2, 0.4, 1
    bezier = easeOutCirc, 0, 0.55, 0.45, 1
    bezier = easeOutCubic, 0.33, 1, 0.68, 1
    bezier = easeinoutsine, 0.37, 0, 0.63, 1
    animation = windowsIn, 1, 1.5, easeinoutsine, popin 60%
    animation = windowsOut, 1, 1.5, easeOutCubic, popin 60%
    animation = windowsMove, 1, 1.5, easeinoutsine, slide
    animation = fade, 1, 2.5, fluent_decel
    animation = fadeLayersIn, 0
    animation = border, 0
    animation = layers, 1, 1.5, easeinoutsine, popin
    animation = workspaces, 1, 3, fluent_decel, slidefadevert 30%
    animation = specialWorkspace, 1, 2, fluent_decel, slidefade 10%
}""",
        "Elifouts": """animations {
    enabled = true
    bezier = fluid, 0.15, 0.85, 0.25, 1
    bezier = snappy, 0.3, 1, 0.4, 1
    animation = windows, 1, 3, fluid, popin 5%
    animation = windowsOut, 1, 2.5, snappy
    animation = fade, 1, 4, snappy
    animation = workspaces, 1, 1.7, snappy, slide
    animation = specialWorkspace, 1, 4, fluid, slidefadevert -35%
    animation = layers, 1, 2, snappy, popin 70%
}""",
        "Linuxfam": """animations {
    enabled = true
    bezier = myBezier, 0.05, 0.9, 0.1, 1.05
    animation = windows, 1, 7, myBezier
    animation = windowsIn, 1, 8, default, slide bottom
    animation = windowsOut, 1, 7, default, slide right
    animation = border, 1, 10, default
    animation = borderangle, 1, 8, default
    animation = fade, 1, 7, default
    animation = workspaces, 1, 6, default
}"""
    }
