"""
PANEL STYLE PRESETS - Exact specs from user's niri CSS files
Each preset auto-fills ALL settings when selected
"""

PANEL_STYLE_PRESETS = {
    # ═══════════════════════════════════════════════════════════════════════════
    # CLASSIC - User's original style
    # ═══════════════════════════════════════════════════════════════════════════
    "classic": {
        "name": "Classic",
        "description": "Semi-opaque pill modules with per-module glow hover",
        "base": {
            "bar_background": "alpha(@bg0, {opacity})",
            "bar_radius": 16,
            "module_background": "alpha(@bg0, 0.9)",
            "module_radius": 45,  # Pill
            "border": "1px solid @bg1",
            "font_family": '"Adwaita Sans", "JetBrainsMono Nerd Font Propo", sans-serif',
            "font_size": 20,
            "padding": "0 15px",
            "margin": "0 0 0 12px",
            "opacity": 0.50
        },
        "workspaces": {
            "container_bg": "alpha(@bg0, 0.21)",
            "container_padding": "5px 3px",
            "container_radius": 26,
            "container_border": "1px solid @bg1",
            "button_bg": "@bg1",
            "button_radius": 16,
            "button_width": 22,
            "active_bg": "@blue",
            "active_width": 50,
            "hover_bg": "@purple",
            "urgent_bg": "@red"
        },
        "hover": {
            "type": "glow",  # Per-module color glow
            "bg_template": "alpha(MODULE_COLOR, 0.12)",
            "text_shadow": "0px 0px 2px alpha(MODULE_COLOR, 0.6)",
            "radius": None
        },
        "colors": {
            "cpu": "@blue",
            "memory": "@green",
            "temperature": "@orange",
            "pulseaudio": "@yellow",
            "battery": "@green",
            "bluetooth": "@blue",
            "clock": "@blue",
            "network": "@purple",
            "music": "#f5c2e7"
        }
    },
    
    # ═══════════════════════════════════════════════════════════════════════════
    # MODERN DARK - Based on niriCold (Catppuccin)
    # ═══════════════════════════════════════════════════════════════════════════
    "modern_dark": {
        "name": "Modern Dark (Catppuccin)",
        "description": "Glass modules with Catppuccin pastel colors - niriCold style",
        "base": {
            "bar_background": "transparent",
            "bar_radius": 0,
            "module_background": "rgba(255, 255, 255, 0.1)",
            "module_radius": 8,  # 0.5rem
            "border": "none",
            "font_family": '"JetBrainsMono Nerd Font"',
            "font_size": 15,
            "padding": "9px",
            "margin": "1.3px",
            "opacity": 0
        },
        "workspaces": {
            "container_bg": "rgba(255, 255, 255, 0.1)",
            "container_padding": "10px",
            "container_radius": 32,  # 2rem
            "container_border": "none",
            "button_bg": "rgba(255, 255, 255, 0.5)",
            "button_radius": 32,
            "button_width": 22,
            "active_bg": "rgba(255, 255, 255, 0.7)",
            "active_width": 50,
            "hover_bg": "rgba(255, 255, 255, 0.7)",
            "urgent_bg": "#f38ba8"
        },
        "hover": {
            "type": "unified",
            "background": "rgba(69, 71, 90, 0.55)",
            "text_color": "#f38ba8",
            "radius": 16  # 1rem
        },
        "colors": {
            "bluetooth": "#f38ba8",
            "battery": "#f9e2af",
            "battery_charging": "#a6e3a1",
            "battery_warning": "#f38ba8",
            "music": "#f5c2e7",
            "menuApp": "#f38ba8",
            "pulseaudio": "#f9e2af",
            "network": "#f9e2af",
            "cpu": "#a6e3a1",
            "memory": "#8bd5ca",
            "temperature": "#f38ba8",
            "clock": "#89b4fa"
        }
    },
    
    # ═══════════════════════════════════════════════════════════════════════════
    # MODERN LIGHT - Based on niriLight (Monochrome)
    # ═══════════════════════════════════════════════════════════════════════════
    "modern_light": {
        "name": "Modern Light (Monochrome)",
        "description": "Glass modules with monochrome gray - niriLight style",
        "base": {
            "bar_background": "transparent",
            "bar_radius": 0,
            "module_background": "rgba(255, 255, 255, 0.1)",
            "module_radius": 8,
            "border": "none",
            "font_family": '"JetBrainsMono Nerd Font"',
            "font_size": 15,
            "padding": "9px",
            "margin": "0px",
            "opacity": 0
        },
        "workspaces": {
            "container_bg": "rgba(255, 255, 255, 0.1)",
            "container_padding": "10px",
            "container_radius": 32,
            "container_border": "none",
            "button_bg": "rgba(255, 255, 255, 0.6)",
            "button_radius": 32,
            "button_width": 22,
            "active_bg": "rgba(255, 255, 255, 0.6)",
            "active_width": 50,
            "hover_bg": "#e6e6e6",
            "urgent_bg": "#4c4c4c"
        },
        "hover": {
            "type": "unified",
            "background": "#e6e6e6",
            "text_color": "#4c4c4c",
            "radius": 16
        },
        "colors": {
            "bluetooth": "#000000",
            "battery": "#4c4c4c",
            "battery_charging": "#4c4c4c",
            "battery_warning": "#4c4c4c",
            "music": "#4c4c4c",
            "menuApp": "#4c4c4c",
            "pulseaudio": "#4c4c4c",
            "network": "#4c4c4c",
            "cpu": "#4c4c4c",
            "memory": "#4c4c4c",
            "temperature": "#4c4c4c",
            "clock": "#4c4c4c"
        }
    },
    
    # ═══════════════════════════════════════════════════════════════════════════
    # WARM - Based on niriWarm (Gruvbox)
    # ═══════════════════════════════════════════════════════════════════════════
    "warm": {
        "name": "Warm (Gruvbox)",
        "description": "Glass modules with warm earth tones - niriWarm style",
        "base": {
            "bar_background": "transparent",
            "bar_radius": 0,
            "module_background": "rgba(255, 255, 255, 0.1)",
            "module_radius": 8,
            "border": "none",
            "font_family": '"JetBrainsMono Nerd Font"',
            "font_size": 15,
            "padding": "6px",
            "margin": "2px",
            "opacity": 0
        },
        "workspaces": {
            "container_bg": "rgba(255, 255, 255, 0.1)",
            "container_padding": "10px",
            "container_radius": 32,
            "container_border": "none",
            "button_bg": "rgba(255, 255, 255, 0.6)",
            "button_radius": 32,
            "button_width": 22,
            "active_bg": "rgba(255, 255, 255, 0.6)",
            "active_width": 50,
            "hover_bg": "#e6e6e6",
            "urgent_bg": "#fb4934"
        },
        "hover": {
            "type": "unified",
            "background": "#4a403d",
            "text_color": "#fc433c",
            "radius": 13  # 0.8rem
        },
        "colors": {
            "menuApp": "#d65d0e",
            "music": "#d65d0e",
            "pulseaudio": "#fabd2f",
            "bluetooth": "#fb4934",
            "network": "#fabd2f",
            "cpu": "#b8bb26",
            "memory": "#8ec07c",
            "temperature": "#fb4934",
            "battery": "#fabd2f",
            "battery_charging": "#b8bb26",
            "battery_warning": "#fb4934",
            "clock": "#83a598"
        }
    },
    
    # ═══════════════════════════════════════════════════════════════════════════
    # ZEN - Minimal centered bar with dots
    # ═══════════════════════════════════════════════════════════════════════════
    "zen": {
        "name": "Zen (Minimal)",
        "description": "Minimal centered bar with dot workspaces",
        "base": {
            "bar_background": "transparent",
            "bar_radius": 0,
            "module_background": "rgba(255, 255, 255, 0.08)",
            "module_radius": 24,
            "border": "none",
            "font_family": '"JetBrainsMono Nerd Font Propo"',
            "font_size": 14,
            "padding": "8px 14px",
            "margin": "2px",
            "opacity": 0
        },
        "workspaces": {
            "container_bg": "rgba(255, 255, 255, 0.08)",
            "container_padding": "8px 12px",
            "container_radius": 24,
            "container_border": "none",
            "button_bg": "rgba(255, 255, 255, 0.3)",
            "button_radius": 50,  # Circle
            "button_width": 10,   # Dot
            "active_bg": "rgba(255, 255, 255, 0.8)",
            "active_width": 20,
            "hover_bg": "rgba(255, 255, 255, 0.5)",
            "urgent_bg": "rgba(255, 100, 100, 0.7)"
        },
        "hover": {
            "type": "unified",
            "background": "rgba(255, 255, 255, 0.12)",
            "text_color": "#ffffff",
            "radius": 24
        },
        "colors": {
            "cpu": "@blue",
            "memory": "@green",
            "temperature": "@orange",
            "pulseaudio": "@yellow",
            "battery": "@green",
            "bluetooth": "@blue",
            "clock": "@fg",
            "network": "@purple",
            "music": "@purple"
        }
    }
}

def get_preset_defaults(preset_id: str) -> dict:
    """Get all default values for a preset - used to populate UI controls"""
    preset = PANEL_STYLE_PRESETS.get(preset_id, PANEL_STYLE_PRESETS["classic"])
    base = preset.get("base", {})
    ws = preset.get("workspaces", {})
    hover = preset.get("hover", {})
    colors = preset.get("colors", {})
    
    # Determine module opacity based on style
    # Classic uses solid modules, others use glass
    module_opacity = 0.9 if preset_id == "classic" else 0.1
    
    return {
        # Base settings
        "opacity": base.get("opacity", 0.5),
        "bar_radius": base.get("bar_radius", 16),
        "module_radius": base.get("module_radius", 45),
        "module_opacity": module_opacity,
        "font_size": base.get("font_size", 15),
        "module_bg": base.get("module_background", "rgba(255,255,255,0.1)"),
        "border": base.get("border", "none"),
        
        # Workspace settings
        "ws_radius": ws.get("button_radius", 32),
        "ws_active_width": ws.get("active_width", 50),
        "ws_active_bg": ws.get("active_bg", "@blue"),
        "ws_hover_bg": ws.get("hover_bg", "@purple"),
        "ws_urgent_bg": ws.get("urgent_bg", "@red"),
        
        # Hover settings
        "hover_type": hover.get("type", "unified"),
        "hover_bg": hover.get("background", "rgba(69,71,90,0.55)"),
        "hover_text": hover.get("text_color", "#f38ba8"),
        "hover_radius": hover.get("radius", 16),
        
        # Module colors
        "colors": colors
    }