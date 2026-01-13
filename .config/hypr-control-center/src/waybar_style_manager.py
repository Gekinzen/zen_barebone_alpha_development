"""
Waybar CSS Manager
Handles style.css modifications for opacity, size, and border-radius
INCLUDES: Hexdump utility for preserving Nerd Font icons
"""

import re
import json
import subprocess
from pathlib import Path
from typing import Optional


class WaybarStyleManager:
    """Manages Waybar style.css file"""
    
    def __init__(self, waybar_dir: Path):
        self.waybar_dir = waybar_dir
        self.style_file = self.waybar_dir / "style.css"
        self.config_file = self.waybar_dir / "config.jsonc"
        self.current_style = ""
        
    def load_style(self) -> bool:
        """Load current style.css"""
        if not self.style_file.exists():
            return False
        
        try:
            self.current_style = self.style_file.read_text(encoding='utf-8')
            return True
        except Exception as e:
            print(f"Error loading style.css: {e}")
            return False
    
    def save_style(self):
        """Save style.css"""
        self.style_file.parent.mkdir(parents=True, exist_ok=True)
        self.style_file.write_text(self.current_style, encoding='utf-8')
    
    def hexdump_nerd_fonts(self, module_name: str) -> dict:
        """
        Extract Nerd Font icons from config.jsonc using hexdump
        Returns dict with Unicode codepoints and raw characters
        """
        if not self.config_file.exists():
            return {}
        
        try:
            # Read the config file as bytes
            with open(self.config_file, 'rb') as f:
                content = f.read()
            
            # Convert to string for parsing
            config_text = content.decode('utf-8')
            
            # Find the module section
            pattern = rf'"{module_name}":\s*\{{[^}}]*"format":\s*"([^"]*)"'
            match = re.search(pattern, config_text, re.DOTALL)
            
            if not match:
                return {}
            
            format_string = match.group(1)
            
            # Extract all non-ASCII characters (Nerd Font icons)
            icons = {}
            for i, char in enumerate(format_string):
                if ord(char) > 127:  # Non-ASCII
                    codepoint = f"U+{ord(char):04X}"
                    icons[f"icon_{i}"] = {
                        'char': char,
                        'codepoint': codepoint,
                        'unicode_escape': f"\\u{ord(char):04x}",
                        'bytes': char.encode('utf-8').hex()
                    }
            
            return {
                'module': module_name,
                'format': format_string,
                'icons': icons,
                'full_unicode': ''.join([char for char in format_string if ord(char) > 127])
            }
            
        except Exception as e:
            print(f"Error extracting icons from {module_name}: {e}")
            return {}
    
    def extract_all_nerd_fonts(self) -> dict:
        """Extract Nerd Font icons from all modules in config.jsonc"""
        modules = [
            'cpu', 'memory', 'temperature', 'pulseaudio',
            'network', 'bluetooth', 'battery', 'clock',
            'custom/notification', 'custom/expand', 'custom/pacman'
        ]
        
        all_icons = {}
        for module in modules:
            icons = self.hexdump_nerd_fonts(module)
            if icons:
                all_icons[module] = icons
        
        return all_icons
    
    def print_icon_report(self):
        """Print a detailed report of all Nerd Font icons found"""
        print("\n" + "="*60)
        print("NERD FONT ICONS ANALYSIS")
        print("="*60)
        
        all_icons = self.extract_all_nerd_fonts()
        
        for module, data in all_icons.items():
            print(f"\n📦 Module: {module}")
            print(f"   Format: {data['format']}")
            
            if data['icons']:
                print(f"   Icons found: {len(data['icons'])}")
                for icon_key, icon_info in data['icons'].items():
                    print(f"   • {icon_info['char']} → {icon_info['codepoint']} → {icon_info['unicode_escape']}")
            else:
                print("   No Nerd Font icons found")
        
        print("\n" + "="*60)
    
    def get_module_icon_unicode(self, module_name: str) -> str:
        """
        Get the Unicode escape sequence for a module's icon
        Returns empty string if no icon found
        """
        data = self.hexdump_nerd_fonts(module_name)
        if data and data.get('icons'):
            # Return the first icon found (usually the one before {icon})
            first_icon = list(data['icons'].values())[0]
            return first_icon['unicode_escape']
        return ""
    
    def verify_nerd_fonts(self) -> dict:
        """
        Verify that Nerd Fonts are properly installed and rendering
        Returns dict with verification results
        """
        try:
            # Check if fc-list can find Nerd Fonts
            result = subprocess.run(
                ['fc-list', ':', 'family'],
                capture_output=True,
                text=True,
                check=True
            )
            
            nerd_fonts = [
                line for line in result.stdout.split('\n')
                if 'Nerd Font' in line or 'JetBrainsMono' in line
            ]
            
            return {
                'installed': len(nerd_fonts) > 0,
                'fonts': nerd_fonts[:5],  # First 5 matches
                'count': len(nerd_fonts)
            }
        except Exception as e:
            return {
                'installed': False,
                'error': str(e)
            }
    
    def set_opacity(self, opacity: float, transparent: bool = False):
        """
        Set waybar background opacity
        transparent=True: background:transparent
        transparent=False: background: alpha(@bg0, opacity)
        """
        if transparent:
            new_bg = "background:transparent;"
        else:
            new_bg = f"background: alpha(@bg0,{opacity:.2f});"
        
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
        """Apply style mode: 'minimal' or 'modern' - CSS ONLY"""
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
#taskbar,
#tray,
#workspaces {
background-color: rgba(255, 255, 255, 0);
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
#clock { 
    color: #89b4fa; 
    transition: all .3s ease;
}


#custom-notification {
    color: #f9e2af;
    margin-left: 0.1px;
    margin-right: 0px;
    border-radius: 0.5rem;
    padding-left: 17px;
    padding-right: 17px;
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

################workspaces##############
#workspaces {
    background-color: rgba(49,50,68,0); /* semi-transparent */
    border-radius: 2rem;
    padding: 10px;
    margin-left: 5px;
    transition: all 0.5s ease-in-out;
}

#workspaces button {
    background-color: rgba(255,255,255,0.5); /* semi-transparent */
    border-radius: 2rem;
    padding: 0px;
    margin-right: 5px;
    transition: all 0.5s ease-out;
    min-width: 22px;
}

#workspaces button.active {
    min-width: 50px;
    background-color: rgba(255,255,255,0.7); /* semi-transparent */
}

#workspaces button:hover {
    background-color: rgba(255,255,255,0.7); /* semi-transparent */
}


/* Modern WLR Taskbar (system icons with colors!) */
#taskbar {
    background-color: rgba(49,50,68,0);
    padding: 8px;
    margin: 0px;
    margin-top: 3px;
    border-radius: 0.5rem;
}

#taskbar button {
    background-color: rgba(41,42,58,0.55);
    margin-left: 0.1px;
    margin-right: 3px;
    border-radius: 0.5rem;
    transition: all 0.4s ease;
    padding: 8px;
}

#taskbar button.active {
    background-color: rgba(224,227,230,0.55);
    border-radius: 0.5rem;
}

#taskbar button:hover {
    border-radius: 1rem;
    background-color: rgba(224,227,230,0.55);
}

/* Custom taskbar (nerd fonts) */
#custom-taskbar {
    background-color: rgba(49,50,68,0);
    padding: 8px;
    margin: 0px;
    margin-top: 3px;
    border-radius: 0.5rem;
    font-family: "JetBrainsMono Nerd Font Propo", sans-serif;
}
#custom-taskbar image {
   -gtk-icon-effect: none;
    opacity: 1;
}

#custom-taskbar * {
    -gtk-icon-effect: none;
    color: unset;
}
'''

    
    def create_default_style(self) -> str:
        """Create default Waybar style.css - YOUR ACTUAL DEFAULT"""
        return '''@import '../colorscheme/tokyo-night-storm.css';

* {
    border: none;
    border-radius: 0px;
    font-family: "Adwaita Sans", "JetBrainsMono Nerd Font Propo", sans-serif;
    font-size: 20px;
    font-weight: bold;
    min-height: 0;
    padding: 0;
    margin: 0;
}
window#waybar {
    border-radius:0px;
    background: alpha(@bg0,0.57);
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
    background-color: alpha(@bg0,0.21);
    /*padding: 18px 20px;*/
    padding: 5px 3px 5px 3px;
    min-width: 176px;
    margin: 0 0 0 12px;
    border-radius: 26px;
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

/* ================================================
   SYSTEM MODULES - Base Styling + Hover Effects
   ================================================ */

#battery,
#pulseaudio,
#cpu,
#memory,
#temperature,
#network,
#bluetooth,
#clock,
#custom-notification {
    background-color: alpha(@bg0, 0.9);
    padding: 0 15px 0 15px;
    margin: 0 0 0 12px;
    border-radius: 45px;
    border: 1px solid @bg1;
    transition: all 0.25s ease-in-out;
}

/* CPU Module */
#cpu {
    color: @blue;
}

#cpu:hover {
    background: alpha(@blue, 0.12);
    color: @blue;
    text-shadow: 0px 0px 2px alpha(@blue, 0.6);
}

/* Memory Module */
#memory {
    color: @green;
}

#memory:hover {
    background: alpha(@green, 0.12);
    color: @green;
    text-shadow: 0px 0px 2px alpha(@green, 0.6);
}

/* Temperature Module */
#temperature {
    color: @orange;
}

#temperature:hover {
    background: alpha(@orange, 0.12);
    color: @orange;
    text-shadow: 0px 0px 2px alpha(@orange, 0.6);
}

/* PulseAudio Module */
#pulseaudio {
    color: @yellow;
}

#pulseaudio:hover {
    background: alpha(@yellow, 0.12);
    text-shadow: 0px 0px 2px alpha(@yellow, 0.6);
}

#pulseaudio.muted {
    color: @red;
    opacity: 0.6;
}

/* Battery Module - No Blinking */
#battery {
    color: @green;
}

#battery:hover {
    background: alpha(@green, 0.12);
    text-shadow: 0px 0px 2px alpha(@green, 0.6);
}

#battery.warning {
    color: @orange;
}

#battery.critical {
    color: @red;
}

/* Bluetooth Module */
#bluetooth {
    color: @blue;
}

#bluetooth:hover {
    background: alpha(@blue, 0.12);
    color: @blue;
    text-shadow: 0px 0px 2px alpha(@blue, 0.6);
}

#bluetooth.connected {
    color: @green;
}

#bluetooth.disconnected {
    color: @red;
    opacity: 0.6;
}

/* Clock Module */
#clock {
    color: @blue;
}

#clock:hover {
    background: alpha(@blue, 0.12);
    text-shadow: 0px 0px 2px alpha(@blue, 0.6);
}

#custom-notification {
    color: @fg;
    margin: 0 12px 0 12px;
}

/* Network Module - Enhanced */
#network {
    color: @purple;
    text-shadow: 0px 0px 1.5px @fg;
}

#network.wifi:hover {
    background: alpha(@blue, 0.12);
    color: @blue;
    text-shadow: 0px 0px 2px alpha(@blue, 0.6);
}

#network.ethernet {
    color: @green;
}

#network.ethernet:hover {
    background: alpha(@green, 0.12);
    color: @green;
    text-shadow: 0px 0px 2px alpha(@green, 0.6);
}

#network.disconnected {
    color: @red;
    text-shadow: 0px 0px 2px alpha(@red, 0.6);
}

#network.disconnected:hover {
    background: alpha(@red, 0.12);
}

#network:active {
    }

/* Tray */
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

#tray {
    padding: 0px 5px;
    transition: all .3s ease; 
}

#tray menu * {
    padding: 0px 5px;
    transition: all .3s ease; 
}

#tray menu separator {
    padding: 0px 5px;
    transition: all .3s ease; 
}

/* Taskbar */
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
    }

#taskbar button:hover {
    background-color: @bg3;
    color: @fg;
    }

#taskbar button.urgent {
    background-color: @red;
    color: @bg0;
    -gtk-icon-effect: highlight;
}

#taskbar button.pinned {
    /*background-color: transparent;*/
    background: alpha(@bg0, 0.6);
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
    }

#window:hover {
    background-color: @bg1;
}

#taskbar button image,
#taskbar button label {
    transition: opacity 0.2s ease-in-out;
}

/*
#custom-taskbar,
#custom-pinned {
    font-size: 20px;
    padding: 5px 14px;
}
*/


/* Taskbar Module */
#custom-taskbar {
    font-family: "JetBrainsMono Nerd Font";
    font-size: 16px;
    padding: 0 10px;
}

#custom-taskbar .focused {
    color: #7aa2f7;
}

#custom-taskbar .running {
    color: #c0caf5;
}

#custom-taskbar .pinned-only {
    color: #565f89;
}



#custom-endpoint {
    color: transparent;
    text-shadow: 0px 0px 1.5px @fg;
}

#group-expand {
    background: alpha(@bg0, 0.6);
    padding: 0px 5px;
    transition: all .3s ease; 
}

#custom-expand {
    padding: 0px 5px;
    color: @fg;
    text-shadow: 0px 0px 2px rgba(0, 0, 0, .7);
    transition: all .3s ease; 
}

#custom-expand:hover {
    color: rgba(255,255,255,.2);
    text-shadow: 0px 0px 2px rgba(255, 255, 255, .5);
}

/* ================================================
   MUSIC PLAYER MODULE - Waybar Compatible
   ================================================ */

#custom-music {
    color: #f5c2e7;
    padding: 0px 15px;
    margin: 0px 0px 0px 12px;
    border-radius: 45px;
    background-color: alpha(@bg0, 0.9);
    border: 1px solid @bg1;
    transition: all 0.25s ease-in-out;
}

#custom-music:hover {
    border-radius: 1rem;
    background-color: rgba(69, 71, 90, 0.55);
}

#custom-music.playing {
    color: #98c379;
}

#custom-music.paused {
    color: #e5c07b;
    opacity: 0.8;
}

#custom-music.idle {
    color: #5c6370;
    opacity: 0.6;
}



/* PACMAN UPDATE MODULE */

#custom-pacman {
    color: #00fff7;
    padding: 0px 15px;
    margin: 0px 0px 0px 12px;
    border-radius: 45px;
    background-color: alpha(@bg0, 0.9);
    border: 1px solid @bg1;
    transition: all 0.25s ease-in-out;
}

#custom-pacman:hover {
    background: alpha(#00fff7, 0.12);
    color: #00fff7;
    text-shadow: 0px 0px 2px alpha(#00fff7, 0.6);
}


/* ~/.config/waybar/style.css */
#group-taskbar {
    padding: 0 5px;
}

#group-taskbar image {
    padding: 0 2px;
}



/* ═══════════════════════════════════════════════════════════════════════════
   START MENU BUTTON - Default Style
   ═══════════════════════════════════════════════════════════════════════════ */

/*#custom-start-menu {
    font-family: "JetBrainsMono Nerd Font";
    font-size: 18px;
    color: #61afef;
    padding: 0 14px;
    margin: 4px 2px;
    border-radius: 8px;
    background: transparent;
    transition: all 200ms ease;
}*/
/*
#custom-start-menu:hover {
    background: rgba(97, 175, 239, 0.15);
    color: #61afef;
}
*/

#custom-start-menu:active {
    background: rgba(97, 175, 239, 0.25);
}

#custom-start-menu {
    background-image: url("~/.config/hypr-control-center/assets/start-icons/arch.svg");
    background-size: 42px 42px;
    background-repeat: no-repeat;
    background-position: center;
    min-width: 36px;
    min-height: 36px;
    padding: 8 8px;
    margin: 4px;
    border-radius: 8px;
}

#custom-start-menu:hover {
    /*background-color: rgba(255, 255, 255, 0.1);*/
    background-color: alpha(@bg0, 0.6);
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


# Utility function to run icon analysis from command line
if __name__ == "__main__":
    import sys
    
    waybar_dir = Path.home() / ".config/waybar"
    manager = WaybarStyleManager(waybar_dir)
    
    if len(sys.argv) > 1 and sys.argv[1] == "analyze":
        manager.print_icon_report()
    elif len(sys.argv) > 1 and sys.argv[1] == "verify":
        result = manager.verify_nerd_fonts()
        print("\n" + "="*60)
        print("NERD FONT VERIFICATION")
        print("="*60)
        if result['installed']:
            print(f"✓ Nerd Fonts installed: {result['count']} fonts found")
            print("\nSample fonts:")
            for font in result['fonts']:
                print(f"  • {font}")
        else:
            print("✗ Nerd Fonts not found")
            if 'error' in result:
                print(f"Error: {result['error']}")
        print("="*60)
    else:
        print("Usage:")
        print("  python waybar_style_manager.py analyze  - Analyze Nerd Font icons")
        print("  python waybar_style_manager.py verify   - Verify Nerd Font installation")