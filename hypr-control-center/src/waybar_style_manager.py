"""
Waybar CSS Manager
Handles style.css modifications for opacity, size, and border-radius
"""

import re
import json
from pathlib import Path
from typing import Optional


class WaybarStyleManager:
    """Manages Waybar style.css file"""
    
    def __init__(self, waybar_dir: Path):
        self.waybar_dir = waybar_dir
        self.style_file = self.waybar_dir / "style.css"
        self.current_style = ""
        
    def load_style(self) -> bool:
        """Load current style.css"""
        if not self.style_file.exists():
            return False
        
        try:
            self.current_style = self.style_file.read_text()
            return True
        except Exception as e:
            print(f"Error loading style.css: {e}")
            return False
    
    def save_style(self):
        """Save style.css"""
        self.style_file.parent.mkdir(parents=True, exist_ok=True)
        self.style_file.write_text(self.current_style)
    
    def set_opacity(self, opacity: float, transparent: bool = False):
        """
        Set waybar background opacity
        transparent=True: background:transparent
        transparent=False: background: alpha(@bg0, opacity)
        """
        if transparent:
            new_bg = "background:transparent;"
        else:
            new_bg = f"background: alpha(@bg0,{opacity:.1f});"
        
        # Find window#waybar or #waybar block and replace background
        pattern = r'((?:window)?#waybar\s*\{[^}]*?)background[^;]+;'
        
        if re.search(pattern, self.current_style):
            self.current_style = re.sub(pattern, f'\\1{new_bg}', self.current_style)
        else:
            # If waybar block doesn't exist, add it
            waybar_block = f'''window#waybar{{
    {new_bg}
}}
'''
            # Add after @import if exists, otherwise at start
            if '@import' in self.current_style:
                lines = self.current_style.split('\n')
                insert_pos = 0
                for i, line in enumerate(lines):
                    if '@import' in line:
                        insert_pos = i + 1
                lines.insert(insert_pos, waybar_block)
                self.current_style = '\n'.join(lines)
            else:
                self.current_style = waybar_block + self.current_style
    
    def set_border_radius(self, radius: int, enabled: bool = True):
        """
        Set waybar border-radius
        enabled=True: border-radius: {radius}px
        enabled=False: border-radius: 0px (for extend to edges)
        """
        if not enabled:
            radius = 0
        
        new_radius = f"border-radius:{radius}px;"
        
        # Find window#waybar or #waybar block and update/add border-radius
        pattern = r'((?:window)?#waybar\s*\{[^}]*?)border-radius:[^;]+;'
        
        if re.search(pattern, self.current_style):
            self.current_style = re.sub(pattern, f'\\1{new_radius}', self.current_style)
        else:
            # Add border-radius to waybar
            pattern = r'((?:window)?#waybar\s*\{)'
            self.current_style = re.sub(pattern, f'\\1\n    {new_radius}', self.current_style)
    
    def set_box_shadow(self, enabled: bool = True):
        """
        Set waybar box-shadow
        enabled=True: box-shadow: 0px 0px 2px rgba(0, 0, 0, .6);
        enabled=False: removes box-shadow
        """
        if enabled:
            new_shadow = "box-shadow: 0px 0px 2px rgba(0, 0, 0, .6);"
        else:
            new_shadow = ""
        
        # Remove existing box-shadow
        pattern = r'box-shadow:[^;]+;\s*'
        self.current_style = re.sub(pattern, '', self.current_style)
        
        # Add new one if enabled
        if enabled:
            pattern = r'((?:window)?#waybar\s*\{)'
            self.current_style = re.sub(pattern, f'\\1\n    {new_shadow}', self.current_style)
    
    def set_font_size(self, size: int):
        """
        Set global font size
        Size presets:
        - Small: 10px
        - Medium: 16px
        - Large: 20px
        - X-Large: 26px
        """
        new_size = f"font-size: {size}px;"
        
        # Find * {...} block and replace font-size
        pattern = r'(\*\s*\{[^}]*?)font-size:[^;]+;'
        
        if re.search(pattern, self.current_style):
            self.current_style = re.sub(pattern, f'\\1{new_size}', self.current_style)
        else:
            # If * block doesn't exist, create it
            global_block = f'''*{{
    border:none;
    border-radius:0px;
    font-family: "Adwaita Sans", "JetBrainsMono Nerd Font Propo", sans-serif;
    {new_size}
    font-weight:bold;
    min-height: 0;
    padding:0;
    margin:0;
}}
'''
            # Add after @import
            if '@import' in self.current_style:
                lines = self.current_style.split('\n')
                insert_pos = 0
                for i, line in enumerate(lines):
                    if '@import' in line:
                        insert_pos = i + 1
                lines.insert(insert_pos, global_block)
                self.current_style = '\n'.join(lines)
            else:
                self.current_style = global_block + self.current_style
    
    def get_current_opacity(self) -> Optional[float]:
        """Get current opacity value from style.css"""
        match = re.search(r'background:\s*alpha\(@bg0?,\s*([0-9.]+)\)', self.current_style)
        if match:
            return float(match.group(1))
        
        # Check if transparent
        if 'background:transparent' in self.current_style or 'background-color: rgba' in self.current_style:
            return 1.0
        
        return None
    
    def get_current_font_size(self) -> Optional[int]:
        """Get current font-size from style.css"""
        match = re.search(r'\*\s*\{[^}]*?font-size:\s*(\d+)px', self.current_style, re.DOTALL)
        if match:
            return int(match.group(1))
        return None
    
    def get_border_radius(self) -> Optional[int]:
        """Get current border-radius from waybar"""
        match = re.search(r'(?:window)?#waybar\s*\{[^}]*?border-radius:\s*(\d+(?:\.\d+)?)(px|rem)', self.current_style, re.DOTALL)
        if match:
            value = float(match.group(1))
            unit = match.group(2)
            # Convert rem to px (assuming 1rem = 16px)
            if unit == 'rem':
                return int(value * 16)
            return int(value)
        return None
    
    def is_transparent(self) -> bool:
        """Check if background is set to transparent"""
        return 'background:transparent' in self.current_style or 'background-color: rgba(49,50,68,0)' in self.current_style
    
    def get_current_style_mode(self) -> str:
        """Detect current style mode: 'minimal' or 'modern'"""
        # First check saved state
        saved_mode = self.load_style_state()
        
        # Verify it matches CSS
        if 'rgba(49,50,68' in self.current_style:
            return 'modern'
        
        return saved_mode

    def apply_style_mode(self, mode: str):
        """Apply style mode: 'minimal' or 'modern'"""
        if mode == 'modern':
            self.current_style = self.create_modern_style()
        else:
            self.current_style = self.create_default_style()
        
        self.save_style()
        self.save_style_state(mode)

    def save_style_state(self, mode: str):
        """Save current style mode to preferences"""
        prefs_dir = Path.home() / ".config/hypr-control-center/preferences"
        prefs_dir.mkdir(parents=True, exist_ok=True)
        
        state_file = prefs_dir / "waybar-menu.json"
        
        import datetime
        state = {
            "style_mode": mode,
            "last_updated": datetime.datetime.now().isoformat()
        }
        
        with open(state_file, 'w') as f:
            json.dump(state, f, indent=2)

    def load_style_state(self) -> str:
        """Load saved style mode from preferences"""
        state_file = Path.home() / ".config/hypr-control-center/preferences/waybar-menu.json"
        
        if not state_file.exists():
            return 'minimal'  # Default
        
        try:
            with open(state_file, 'r') as f:
                state = json.load(f)
                return state.get('style_mode', 'minimal')
        except:
            return 'minimal'

    def create_modern_style(self) -> str:
        """Create modern Waybar style (rounded, semi-transparent)"""
        return '''@import '../colorscheme/everforest-dark.css';

* {
    border: none;
    border-radius: 0px;
    font-family: "JetBrainsMono Nerd Font Propo", sans-serif;
    font-size: 15px;
    font-weight: bold;
    min-height: 0;
    padding: 0;
    margin: 0;
}

#waybar {
    background-color: rgba(49,50,68,0.4);
    color: #cdd6f4;
    margin: 5px 5px;
    border-radius: 2rem;
}

tooltip {
    background: @bg0;
    border: 1px solid @bg3;
    border-radius: 12px;
}

tooltip label {
    color: @fg;
    padding: 6px;
}

#bluetooth,
#temperature,
#custom-music,
#clock,
#battery,
#pulseaudio,
#network,
#cpu,
#memory,
#custom-menuApp,
#custom-power,
#custom-switcher,
#custom-notification,
#custom-taskbar,
#tray,
#workspaces {
    background-color: rgba(49,50,68,0);
    padding: 9px;
    margin: 0px;
    margin-top: 3px;
    transition: all 0.4s ease;
}

#bluetooth {
    margin-left: 0.1px;
    margin-right: 0px;
    border-radius: 0.5rem;
    color: #f38ba8;
    padding-left: 17px;
    padding-right: 17px;
}

#bluetooth.off { color: #8bd5ca; }
#bluetooth.on { color: #a6e3a1; }
#bluetooth.disabled { color: #8bd5ca; }

#battery {
    margin-left: 0.1px;
    margin-right: 0px;
    border-radius: 0.5rem;
    color: #f9e2af;
    padding-left: 0px;
    padding-right: 15px;
}

#battery.charging { color: #a6e3a1; }
#battery.warning:not(.charging) { color: #f38ba8; }

#backlight { color: #f9e2af; }

#custom-music {
    margin-left: 0.1px;
    margin-right: 5px;
    border-radius: 0.5rem 2rem 2rem 0.5rem;
    color: #f5c2e7;
    padding-left: 17px;
    padding-right: 17px;
    font-size: 14px;
}

#custom-music:hover {
    border-radius: 1rem;
    background-color: rgba(69,71,90,0.55);
}

#custom-menuApp {
    margin-left: 5px;
    margin-right: 0px;
    border-radius: 2rem 0.5rem 0.5rem 2rem;
    color: #f38ba8;
    transition: all 0.4s ease;
    padding-right: 14px;
}

#custom-menuApp:hover {
    border-radius: 1rem;
    background-color: rgba(69,71,90,0.55);
}

#custom-switcher {
    margin-left: 0.1px;
    margin-right: 0px;
    border-radius: 0.5rem;
    color: #d65d0e;
    padding-left: 10px;
    padding-right: 7px;
}

#custom-switcher:hover {
    border-radius: 1rem;
    background-color: rgba(69,71,90,0.55);
}

#custom-power {
    margin-left: 0.1px;
    margin-right: 0px;
    border-radius: 0.5rem 2rem 2rem 0.5rem;
    color: #f38ba8;
    padding-left: 20px;
    padding-right: 23px;
}

#custom-power:hover {
    border-radius: 1rem;
    background-color: rgba(69,71,90,0.55);
}

#pulseaudio {
    margin-left: 0.1px;
    margin-right: 0px;
    border-radius: 2rem 0.5rem 0.5rem 2rem;
    color: #f9e2af;
    padding-left: 10px;
    padding-right: 17px;
}

#network, #cpu, #memory, #temperature, #clock {
    margin-left: 0.1px;
    margin-right: 0px;
    border-radius: 0.5rem;
    padding-left: 17px;
    padding-right: 17px;
}

#network { color: #f9e2af; }
#cpu { color: #a6e3a1; }
#memory { color: #8bd5ca; }
#temperature { color: #f38ba8; }
#clock { color: #89b4fa; }

#custom-notification {
    color: #f9e2af;
    margin-left: 0.1px;
    margin-right: 0px;
    border-radius: 0.5rem;
    padding-left: 17px;
    padding-right: 17px;
}

#custom-taskbar {
    background-color: rgba(49,50,68,0);
    padding: 8px;
    margin: 0px;
    margin-top: 3px;
    border-radius: 0.5rem;
    color: #cdd6f4;
    font-family: "JetBrainsMono Nerd Font Propo", sans-serif;
}

#custom-taskbar button {
    background-color: rgba(41,42,58,0.55);
    margin-left: 0.1px;
    border-radius: 0.5rem;
    transition: all 0.4s ease;
    padding: 8px;
}

#custom-taskbar button.active {
    background-color: rgba(224,227,230,0.55);
    border-radius: 0.5rem;
}

#custom-taskbar button:hover {
    border-radius: 1rem;
    background-color: rgba(224,227,230,0.55);
}

#tray {
    background-color: rgba(49,50,68,0);
    padding: 9px 10px;
    margin: 0px;
    margin-top: 3px;
    border-radius: 0.5rem;
}

#tray > .passive {
    -gtk-icon-effect: dim;
}

#tray > .needs-attention {
    -gtk-icon-effect: highlight;
    background-color: #f38ba8;
}

#memory:hover, #network:hover, #cpu:hover, #bluetooth:hover,
#pulseaudio:hover, #clock:hover, #temperature:hover, #battery:hover,
#custom-notification:hover, #tray:hover {
    color: #f38ba8;
    border-radius: 1rem;
}

#workspaces {
    background-color: rgba(49,50,68,0);
    border-radius: 2rem;
    padding: 10px;
    margin-left: 5px;
    transition: all 0.5s ease-in-out;
}

#workspaces button {
    background-color: rgba(255,255,255,0.5);
    border-radius: 2rem;
    padding: 0px;
    margin-right: 5px;
    transition: all 0.5s ease-out;
    min-width: 22px;
}

#workspaces button.active {
    min-width: 50px;
    background-color: rgba(255,255,255,0.7);
}

#workspaces button:hover {
    background-color: rgba(255,255,255,0.7);
}
'''
    
    def create_default_style(self) -> str:
        """Create default Waybar style.css matching user's structure"""
        return '''@import '../colorscheme/everforest-dark.css';

* {
    border: none;
    border-radius: 0px;
    font-family: "Adwaita Sans", "JetBrainsMono Nerd Font Propo", sans-serif;
    font-size: 16px;
    font-weight: bold;
    min-height: 0;
    padding: 0;
    margin: 0;
}

window#waybar {
    border-radius: 46px;
    background: alpha(@bg0,1.0);
    box-shadow: 0px 0px 2px rgba(0, 0, 0, .6);
}

tooltip {
    background: @bg0;
    border: 1px solid @bg3;
    border-radius: 12px;
}

tooltip label {
    color: @fg;
    padding: 6px;
}

#workspaces {
    background-color: @bg0;
    padding: 5px 3px;
    margin: 0 0 0 12px;
    border-radius: 18px;
    border: 1px solid @bg1;
    color: @fg;
}

#workspaces button {
    padding: 0px 6px;
    margin: 0px 3px;
    color: transparent;
    border-radius: 16px;
    background-color: @bg1;
    transition: all 0.3s ease-in-out;
}

#workspaces button.active {
    background-color: @blue;
    color: @bg0;
    min-width: 50px;
    border-radius: 16px;
    transition: all 0.3s ease-in-out;
    font-size: 13px;
}

#workspaces button:hover {
    background-color: @purple;
    color: @bg0;
    border-radius: 16px;
    min-width: 50px;
    background-size: 400% 400%;
}

#workspaces button.urgent {
    background-color: @red;
    color: @bg0;
    border-radius: 16px;
    min-width: 50px;
    background-size: 400% 400%;
    transition: all 0.3s ease-in-out;
}

#battery,
#pulseaudio,
#network,
#clock,
#custom-notification {
    background-color: @bg0;
    padding: 0 15px 0 15px;
    margin: 0 0 0 12px;
    border-radius: 45px;
    border: 1px solid @bg1;
}

#clock {
    color: @blue;
}

#custom-notification {
    color: @fg;
    margin: 0 12px 0 12px;
}

#pulseaudio {
    color: @yellow;
}

#network {
    color: @purple;
}

#battery {
    color: @green;
}

#tray {
    background-color: @bg0;
    padding: 0 10px;
    margin: 0 0 0 12px;
    border-radius: 45px;
    border: 1px solid @bg1;
}

#tray > .passive {
    -gtk-icon-effect: dim;
}

#tray > .needs-attention {
    -gtk-icon-effect: highlight;
    background-color: @red;
}

#custom-taskbar {
    background-color: @bg0;
    padding: 0 15px;
    margin: 0 0 0 12px;
    border-radius: 45px;
    border: 1px solid @bg1;
    font-family: "JetBrainsMono Nerd Font Propo", "JetBrainsMono NFM";
    font-size: 16px;
    font-weight: bold;
    color: @fg;
    min-height: 0;
}

#taskbar {
    background-color: @bg0;
    padding: 5px 6px;
    margin: 0 0 0 12px;
    border-radius: 18px;
    border: 1px solid @bg1;
}

#taskbar button {
    padding: 0.4em 0.8em;
    margin: 0 4px;
    border-radius: 14px;
    background-color: @bg1;
    color: @fg;
    transition: all 0.25s ease-in-out;
}

#taskbar button.running {
    background-color: @bg2;
    color: @fg;
    border-bottom: 2px solid @blue;
}

#taskbar button.active {
    background-color: @blue;
    color: @bg0;
    box-shadow: 0 2px 8px alpha(@blue, 0.4);
}

#taskbar button:hover {
    background-color: @bg3;
    color: @fg;
    box-shadow: 0 2px 6px alpha(@bg0, 0.3);
}

#taskbar button.urgent {
    background-color: @red;
    color: @bg0;
    -gtk-icon-effect: highlight;
}

#taskbar button.pinned {
    background-color: transparent;
    border: 1px dashed @bg3;
    color: @grey1;
    opacity: 0.6;
}

#taskbar button.pinned.running {
    background-color: @bg2;
    border: 1px solid @bg3;
    color: @fg;
    opacity: 1;
}

#taskbar button.pinned.active {
    background-color: @blue;
    border: 1px solid @blue;
    color: @bg0;
    opacity: 1;
    box-shadow: 0 2px 10px alpha(@blue, 0.5);
}

#window:hover {
    background-color: @bg1;
}

#taskbar button image,
#taskbar button label {
    transition: opacity 0.2s ease-in-out;
}
'''
    
    def add_vertical_bar_css(self):
        """Add CSS for vertical bars (left/right position)"""
        # Check if already has vertical bar CSS
        if '.modules-left' in self.current_style or '.modules-right' in self.current_style:
            return
        
        # Add vertical bar styling
        vertical_css = '''
/* Vertical bar styling for left/right positions */
.modules-left {
    transition-property: background-color;
    transition-duration: 0.5s;
    margin: 6px 6px 6px 6px;
    border-radius: 4px;
    background: alpha(@bg0, 0.4);
    color: @fg;
}

.modules-right {
    margin: 0px 6px 6px 6px;
    border-radius: 4px;
    background: alpha(@bg0, 0.4);
    color: @fg;
}
'''
        self.current_style += vertical_css
    
    def remove_vertical_bar_css(self):
        """Remove vertical bar CSS (when switching back to top/bottom)"""
        # Remove .modules-left block
        pattern = r'/\* Vertical bar styling.*?\*/\s*.modules-left\s*\{[^}]+\}\s*'
        self.current_style = re.sub(pattern, '', self.current_style, flags=re.DOTALL)
        
        # Remove .modules-right block
        pattern = r'.modules-right\s*\{[^}]+\}\s*'
        self.current_style = re.sub(pattern, '', self.current_style, flags=re.DOTALL)