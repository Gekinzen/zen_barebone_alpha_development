"""
Waybar CSS Manager
Handles style.css modifications for opacity, size, and border-radius
"""

import re
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
        
        # Find window#waybar block and replace background
        pattern = r'(window#waybar\s*\{[^}]*?)background:[^;]+;'
        
        if re.search(pattern, self.current_style):
            self.current_style = re.sub(pattern, f'\\1{new_bg}', self.current_style)
        else:
            # If window#waybar doesn't exist, add it
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
        
        # Find window#waybar block and update/add border-radius
        pattern = r'(window#waybar\s*\{[^}]*?)border-radius:[^;]+;'
        
        if re.search(pattern, self.current_style):
            self.current_style = re.sub(pattern, f'\\1{new_radius}', self.current_style)
        else:
            # Add border-radius to window#waybar
            pattern = r'(window#waybar\s*\{)'
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
            pattern = r'(window#waybar\s*\{)'
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
        if 'background:transparent' in self.current_style:
            return 1.0  # Fully transparent
        
        return None
    
    def get_current_font_size(self) -> Optional[int]:
        """Get current font-size from style.css"""
        match = re.search(r'\*\s*\{[^}]*?font-size:\s*(\d+)px', self.current_style, re.DOTALL)
        if match:
            return int(match.group(1))
        return None
    
    def is_transparent(self) -> bool:
        """Check if background is set to transparent"""
        return 'background:transparent' in self.current_style
    
    def create_default_style(self) -> str:
        """Create default Waybar style.css matching user's structure"""
        return '''@import 'colors/one-dark.css';

*{
    border:none;
    border-radius:0px;
    font-family: "Adwaita Sans", "JetBrainsMono Nerd Font Propo", sans-serif;
    font-size: 16px;
    font-weight:bold;
    min-height: 0;
    padding:0;
    margin:0;
}

window#waybar{
    background:transparent;
}

tooltip{
    background: @bg0;
    border: 1px solid @bg3;
    border-radius:12px;
}

tooltip label{
    color: @fg;
    padding:6px
}

#workspaces{
    background-color: @bg0;
    padding:5px 3px;
    margin: 0 0 0 12px;
    border-radius: 18px;
    border:1px solid @bg1;
    color: @fg;
}

#workspaces button {
    padding: 0px 6px;
    margin: 0px 3px;
    color: transparent;
    border-radius:16px;
    background-color: @bg1;
    transition:all 0.3s ease-in-out;
}

#workspaces button.active {
    background-color: @blue;
    color: @bg0;
    min-width:50px;
    border-radius:16px;
    transition:all 0.3s ease-in-out;
    font-size: 13px;
}

#workspaces button:hover{
    background-color: @purple;
    color: @bg0;
    border-radius:16px;
    min-width: 50px;
    background-size:400% 400%;
}

#workspaces button.urgent{
    background-color: @red;
    color: @bg0;
    border-radius:16px;
    min-width:50px;
    background-size: 400% 400%;
    transition:all 0.3s ease-in-out;
}

#battery,
#pulseaudio,
#network,
#clock,
#custom-notification {
    background-color: @bg0;
    padding: 0 15px 0 15px;
    margin: 0 0 0 12px;
    border-radius:45px;
    border:1px solid @bg1;
}

#clock {
    color: @blue;
}

#custom-notification {
    color: @fg;
    margin: 0 12px 0 12px;
}

#pulseaudio{
    color: @yellow;
}

#network{
    color:@purple;
}

#battery{
    color:@green;
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
'''