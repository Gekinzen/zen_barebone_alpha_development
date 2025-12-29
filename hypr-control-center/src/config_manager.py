"""
Hyprland configuration file manager
Handles reading and writing of Hyprland config files
"""

import re
import shutil
import subprocess
from typing import List
from pathlib import Path

from .models import (
    GeneralConfig, DecorationConfig, AnimationConfig,
    InputConfig, MonitorConfig, WaybarConfig, WorkspaceRule
)
from .constants import (
    LOOK_AND_FEEL_CONF, MODULES_DIR, DEFAULT_DIR
)

class HyprlandConfigManager:
    """Manages reading and writing of Hyprland configuration files"""
    
    def __init__(self):
        self.general = GeneralConfig()
        self.decoration = DecorationConfig()
        self.animation = AnimationConfig()
        self.input = InputConfig()
        self.monitors: List[MonitorConfig] = []
        self.waybar = WaybarConfig()
        self.waybar2 = WaybarConfig()  # For dock mode
        self.workspace_rules: List[WorkspaceRule] = []
        
    def parse_look_and_feel(self) -> bool:
        """Parse look_and_feel.conf"""
        if not LOOK_AND_FEEL_CONF.exists():
            return False
            
        content = LOOK_AND_FEEL_CONF.read_text()
        
        # Parse general section
        general_match = re.search(r'general\s*\{([^}]+)\}', content, re.DOTALL)
        if general_match:
            self._parse_general(general_match.group(1))
            
        # Parse decoration section
        decoration_match = re.search(r'decoration\s*\{(.+?)^\}', content, re.DOTALL | re.MULTILINE)
        if decoration_match:
            self._parse_decoration(decoration_match.group(1))
            
        return True
    
    def _parse_general(self, content: str):
        """Parse general section values"""
        patterns = {
            'gaps_in': (r'gaps_in\s*=\s*(\d+)', int),
            'gaps_out': (r'gaps_out\s*=\s*(\d+)', int),
            'border_size': (r'border_size\s*=\s*(\d+)', int),
            'resize_on_border': (r'resize_on_border\s*=\s*(true|false)', lambda x: x.lower() == 'true'),
            'allow_tearing': (r'allow_tearing\s*=\s*(true|false)', lambda x: x.lower() == 'true'),
            'layout': (r'layout\s*=\s*(\w+)', str),
        }
        
        for attr, (pattern, converter) in patterns.items():
            match = re.search(pattern, content, re.IGNORECASE)
            if match:
                setattr(self.general, attr, converter(match.group(1)))
        
        # Parse colors
        active_match = re.search(r'col\.active_border\s*=\s*(rgba\([^)]+\))\s*(\d+deg)?', content)
        if active_match:
            self.general.col_active_border = active_match.group(1)
            if active_match.group(2):
                self.general.col_active_border_angle = int(active_match.group(2).replace('deg', ''))
                
        inactive_match = re.search(r'col\.inactive_border\s*=\s*(rgba\([^)]+\))', content)
        if inactive_match:
            self.general.col_inactive_border = inactive_match.group(1)
    
    def _parse_decoration(self, content: str):
        """Parse decoration section"""
        patterns = {
            'rounding': (r'^\s*rounding\s*=\s*(\d+)', int),
            'rounding_power': (r'rounding_power\s*=\s*(\d+)', int),
            'active_opacity': (r'active_opacity\s*=\s*([\d.]+)', float),
            'inactive_opacity': (r'inactive_opacity\s*=\s*([\d.]+)', float),
        }
        
        for attr, (pattern, converter) in patterns.items():
            match = re.search(pattern, content, re.MULTILINE)
            if match:
                setattr(self.decoration, attr, converter(match.group(1)))
        
        # Parse shadow
        shadow_match = re.search(r'shadow\s*\{([^}]+)\}', content, re.DOTALL)
        if shadow_match:
            shadow = shadow_match.group(1)
            if m := re.search(r'enabled\s*=\s*(true|false)', shadow, re.I):
                self.decoration.shadow_enabled = m.group(1).lower() == 'true'
            if m := re.search(r'range\s*=\s*(\d+)', shadow):
                self.decoration.shadow_range = int(m.group(1))
            if m := re.search(r'color\s*=\s*(rgba\([^)]+\))', shadow):
                self.decoration.shadow_color = m.group(1)
        
        # Parse blur
        blur_match = re.search(r'blur\s*\{([^}]+)\}', content, re.DOTALL)
        if blur_match:
            blur = blur_match.group(1)
            if m := re.search(r'enabled\s*=\s*(true|false)', blur, re.I):
                self.decoration.blur_enabled = m.group(1).lower() == 'true'
            if m := re.search(r'size\s*=\s*(\d+)', blur):
                self.decoration.blur_size = int(m.group(1))
            if m := re.search(r'passes\s*=\s*(\d+)', blur):
                self.decoration.blur_passes = int(m.group(1))
            if m := re.search(r'vibrancy\s*=\s*([\d.]+)', blur):
                self.decoration.blur_vibrancy = float(m.group(1))

    def generate_look_and_feel(self) -> str:
        """Generate look_and_feel.conf content"""
        return f'''#####################
### LOOK AND FEEL ###
#####################

# Refer to https://wiki.hypr.land/Configuring/Variables/

# https://wiki.hypr.land/Configuring/Variables/#general
general {{
    gaps_in = {self.general.gaps_in}
    gaps_out = {self.general.gaps_out}
    border_size = {self.general.border_size}

    # https://wiki.hypr.land/Configuring/Variables/#variable-types for info about colors
    col.active_border = {self.general.col_active_border} {self.general.col_active_border_angle}deg
    col.inactive_border = {self.general.col_inactive_border}

    # Set to true enable resizing windows by clicking and dragging on borders and gaps
    resize_on_border = {str(self.general.resize_on_border).lower()}

    # Please see https://wiki.hypr.land/Configuring/Tearing/ before you turn this on
    allow_tearing = {str(self.general.allow_tearing).lower()}

    layout = {self.general.layout}
}}

# https://wiki.hypr.land/Configuring/Variables/#decoration
decoration {{
    rounding = {self.decoration.rounding}
    rounding_power = {self.decoration.rounding_power}

    # Change transparency of focused and unfocused windows
    active_opacity = {self.decoration.active_opacity}
    inactive_opacity = {self.decoration.inactive_opacity}

    shadow {{
        enabled = {str(self.decoration.shadow_enabled).lower()}
        range = {self.decoration.shadow_range}
        render_power = {self.decoration.shadow_render_power}
        color = {self.decoration.shadow_color}
    }}

    # https://wiki.hypr.land/Configuring/Variables/#blur
    blur {{
        enabled = {str(self.decoration.blur_enabled).lower()}
        size = {self.decoration.blur_size}
        passes = {self.decoration.blur_passes}
        vibrancy = {self.decoration.blur_vibrancy}
    }}
}}
'''
    
    def save_look_and_feel(self):
        """Save look_and_feel.conf"""
        MODULES_DIR.mkdir(parents=True, exist_ok=True)
        LOOK_AND_FEEL_CONF.write_text(self.generate_look_and_feel())
        self._reload_hyprland()
    
    def reset_look_and_feel(self) -> bool:
        """Reset from default"""
        default = DEFAULT_DIR / "look_and_feel.conf"
        if default.exists():
            shutil.copy(default, LOOK_AND_FEEL_CONF)
            self.parse_look_and_feel()
            self._reload_hyprland()
            return True
        return False
    
    def _reload_hyprland(self):
        """Reload Hyprland config"""
        try:
            subprocess.run(['hyprctl', 'reload'], check=False, capture_output=True)
        except Exception:
            pass
