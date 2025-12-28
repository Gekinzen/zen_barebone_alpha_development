"""
Waybar Configuration Manager
Handles Waybar config.json and style.css files
"""

import json
import subprocess
from pathlib import Path
from typing import Dict, List, Any, Optional

from .constants import WAYBAR_DIR

class WaybarManager:
    """Manages Waybar configuration files"""
    
    def __init__(self):
        self.waybar_dir = WAYBAR_DIR
        self.config_file = self.waybar_dir / "config.jsonc"  # JSONC for comments
        self.style_file = self.waybar_dir / "style.css"
        self.waybar2_dir = WAYBAR_DIR / "waybar2"
        self.waybar2_config = self.waybar2_dir / "config.jsonc"  # JSONC for dock too
        self.waybar2_style = self.waybar2_dir / "style.css"
        
        # Current configs
        self.main_config: Dict[str, Any] = {}
        self.dock_config: Dict[str, Any] = {}
        
    def load_config(self, is_dock: bool = False) -> bool:
        """Load waybar config.jsonc (JSON with comments)"""
        config_path = self.waybar2_config if is_dock else self.config_file
        
        if not config_path.exists():
            # If config doesn't exist, create from default
            default = self.create_default_config(is_dock=is_dock)
            self.save_config(default, is_dock=is_dock)
            return True
            
        try:
            with open(config_path, 'r') as f:
                # Remove comments before parsing (Waybar allows // comments)
                content = f.read()
                # Simple comment removal (not perfect but works for most cases)
                lines = []
                for line in content.split('\n'):
                    # Remove // comments
                    if '//' in line:
                        line = line[:line.index('//')]
                    lines.append(line)
                clean_content = '\n'.join(lines)
                
                config = json.loads(clean_content)
                if is_dock:
                    self.dock_config = config
                else:
                    self.main_config = config
            return True
        except Exception as e:
            print(f"Error loading waybar config: {e}")
            return False
    
    def save_config(self, config: Dict[str, Any], is_dock: bool = False):
        """Save waybar config.jsonc - only saves top-level properties"""
        config_path = self.waybar2_config if is_dock else self.config_file
        config_dir = config_path.parent
        
        config_dir.mkdir(parents=True, exist_ok=True)
        
        # Read existing config to preserve module definitions
        existing_config = {}
        if config_path.exists():
            try:
                with open(config_path, 'r') as f:
                    content = f.read()
                    # Remove comments for parsing
                    lines = []
                    for line in content.split('\n'):
                        if '//' in line:
                            line = line[:line.index('//')]
                        lines.append(line)
                    existing_config = json.loads('\n'.join(lines))
            except:
                pass
        
        # Update only the editable properties
        editable_keys = [
            'height', 'position', 
            'margin-top', 'margin-bottom', 'margin-left', 'margin-right',
            'modules-left', 'modules-center', 'modules-right'
        ]
        
        # Start with existing config to preserve module definitions
        final_config = existing_config.copy()
        
        # Update only the editable keys
        for key in editable_keys:
            if key in config:
                final_config[key] = config[key]
        
        # Save with nice formatting
        with open(config_path, 'w') as f:
            json.dump(final_config, f, indent=4)
        
        self.reload_waybar()
    
    def get_position(self, is_dock: bool = False) -> str:
        """Get waybar position"""
        config = self.dock_config if is_dock else self.main_config
        return config.get('position', 'top')
    
    def set_position(self, position: str, is_dock: bool = False):
        """Set waybar position"""
        if is_dock:
            self.dock_config['position'] = position
        else:
            self.main_config['position'] = position
    
    def get_height(self, is_dock: bool = False) -> int:
        """Get waybar height"""
        config = self.dock_config if is_dock else self.main_config
        return config.get('height', 34)
    
    def set_height(self, height: int, is_dock: bool = False):
        """Set waybar height"""
        if is_dock:
            self.dock_config['height'] = height
        else:
            self.main_config['height'] = height
    
    def get_margin(self, side: str, is_dock: bool = False) -> int:
        """Get margin for a side (top, bottom, left, right)"""
        config = self.dock_config if is_dock else self.main_config
        return config.get(f'margin-{side}', 0)
    
    def set_margin(self, side: str, value: int, is_dock: bool = False):
        """Set margin for a side"""
        if is_dock:
            self.dock_config[f'margin-{side}'] = value
        else:
            self.main_config[f'margin-{side}'] = value
    
    def get_modules(self, position: str, is_dock: bool = False) -> List[str]:
        """Get modules for a position (left, center, right)"""
        config = self.dock_config if is_dock else self.main_config
        return config.get(f'modules-{position}', [])
    
    def set_modules(self, position: str, modules: List[str], is_dock: bool = False):
        """Set modules for a position"""
        if is_dock:
            self.dock_config[f'modules-{position}'] = modules
        else:
            self.main_config[f'modules-{position}'] = modules
    
    def add_module(self, position: str, module: str, is_dock: bool = False):
        """Add a module to a position"""
        modules = self.get_modules(position, is_dock)
        if module not in modules:
            modules.append(module)
            self.set_modules(position, modules, is_dock)
    
    def remove_module(self, position: str, module: str, is_dock: bool = False):
        """Remove a module from a position"""
        modules = self.get_modules(position, is_dock)
        if module in modules:
            modules.remove(module)
            self.set_modules(position, modules, is_dock)
    
    def move_module(self, from_pos: str, to_pos: str, module: str, is_dock: bool = False):
        """Move a module from one position to another"""
        self.remove_module(from_pos, module, is_dock)
        self.add_module(to_pos, module, is_dock)
    
    def reorder_modules(self, position: str, modules: List[str], is_dock: bool = False):
        """Reorder modules in a position"""
        self.set_modules(position, modules, is_dock)
    
    def get_layer(self, is_dock: bool = False) -> str:
        """Get waybar layer (top, bottom, overlay)"""
        config = self.dock_config if is_dock else self.main_config
        return config.get('layer', 'top')
    
    def set_layer(self, layer: str, is_dock: bool = False):
        """Set waybar layer"""
        if is_dock:
            self.dock_config['layer'] = layer
        else:
            self.main_config['layer'] = layer
    
    def get_output(self, is_dock: bool = False) -> Optional[str]:
        """Get waybar output (monitor)"""
        config = self.dock_config if is_dock else self.main_config
        return config.get('output')
    
    def set_output(self, output: Optional[str], is_dock: bool = False):
        """Set waybar output (monitor)"""
        if output:
            if is_dock:
                self.dock_config['output'] = output
            else:
                self.main_config['output'] = output
        else:
            # Remove output key to show on all monitors
            if is_dock:
                self.dock_config.pop('output', None)
            else:
                self.main_config.pop('output', None)
    
    def reload_waybar(self):
        """Reload waybar"""
        try:
            # Kill waybar
            subprocess.run(['pkill', 'waybar'], check=False, capture_output=True)
            # Start waybar
            subprocess.Popen(['waybar'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception as e:
            print(f"Error reloading waybar: {e}")
    
    def get_monitors(self) -> List[Dict[str, Any]]:
        """Get list of monitors using hyprctl"""
        try:
            result = subprocess.run(
                ['hyprctl', 'monitors', '-j'],
                capture_output=True,
                text=True,
                check=True
            )
            monitors = json.loads(result.stdout)
            return monitors
        except Exception as e:
            print(f"Error getting monitors: {e}")
            return []
    
    def create_default_config(self, is_dock: bool = False) -> Dict[str, Any]:
        """Create default waybar configuration matching user's structure"""
        if is_dock:
            # Dock configuration (Waybar2) - Coming soon
            return {
                "height": 60,
                "position": "bottom",
                "margin-top": 0,
                "margin-bottom": 8,
                "margin-left": 0,
                "margin-right": 0,
                "modules-left": ["hyprland/workspaces"],
                "modules-center": [],
                "modules-right": ["tray"],
                "hyprland/workspaces": {
                    "format": "{name}",
                    "format-icons": {
                        "1": "",
                        "2": "",
                        "3": "",
                        "4": "",
                        "5": "",
                        "active": "",
                        "default": ""
                    },
                    "persistent-workspaces": {
                        "*": 5
                    }
                },
                "tray": {
                    "icon-size": 21,
                    "spacing": 10
                }
            }
        else:
            # Main panel configuration - User's exact structure
            return {
                "height": 10,
                "position": "top",
                "margin-top": 15,
                "margin-bottom": 0,
                "margin-left": 0,
                "margin-right": 0,
                "modules-left": ["clock", "hyprland/workspaces"],
                "modules-center": ["tray"],
                "modules-right": [
                    "pulseaudio",
                    "network",
                    "battery",
                    "custom/notification"
                ],
                "clock": {
                    "interval": 60,
                    "format": "{:%H:%M}",
                    "max-length": 25
                },
                "hyprland/workspaces": {
                    "format": "{name}",
                    "format-icons": {
                        "1": "",
                        "2": "",
                        "3": "",
                        "4": "",
                        "5": "",
                        "active": "",
                        "default": ""
                    },
                    "persistent-workspaces": {
                        "*": 5,
                        "HDMI-A-1": 3
                    }
                },
                "tray": {
                    "icon-size": 21,
                    "spacing": 10
                },
                "pulseaudio": {
                    "format": "{volume}% {icon}",
                    "format-bluetooth": "{volume}% {icon}",
                    "format-muted": "",
                    "format-icons": {
                        "headphone": "",
                        "hands-free": "",
                        "headset": "",
                        "phone": "",
                        "phone-muted": "",
                        "portable": "",
                        "car": "",
                        "default": ["", ""]
                    },
                    "scroll-step": 1,
                    "on-click": "pavucontrol",
                    "ignored-sinks": ["Easy Effects Sink"]
                },
                "network": {
                    "interface": "wlp2s0",
                    "format": "{ifname}",
                    "format-wifi": "{essid} ({signalStrength}%) ",
                    "format-ethernet": "{ipaddr}/{cidr} 󰊗",
                    "format-disconnected": "",
                    "tooltip-format": "{ifname} via {gwaddr} 󰊗",
                    "tooltip-format-wifi": "{essid} ({signalStrength}%) ",
                    "tooltip-format-ethernet": "{ifname} ",
                    "tooltip-format-disconnected": "Disconnected",
                    "max-length": 50
                },
                "battery": {
                    "interval": 60,
                    "states": {
                        "warning": 30,
                        "critical": 15
                    },
                    "format": "{capacity}% {icon}",
                    "format-icons": ["", "", "", "", ""],
                    "max-length": 25
                },
                "custom/notification": {
                    "tooltip": True,
                    "format": "<span size='16pt'>{icon}</span>",
                    "format-icons": {
                        "notification": "󱅫",
                        "none": "󰂜",
                        "dnd-notification": "󰂠",
                        "dnd-none": "󰪓",
                        "inhibited-notification": "󰂛",
                        "inhibited-none": "󰪑",
                        "dnd-inhibited-notification": "󰂛",
                        "dnd-inhibited-none": "󰪑"
                    },
                    "return-type": "json",
                    "exec-if": "which swaync-client",
                    "exec": "swaync-client -swb",
                    "on-click": "swaync-client -t -sw",
                    "on-click-right": "swaync-client -d -sw",
                    "escape": True
                }
            }
    
    def get_available_modules(self) -> List[str]:
        """Get list of available waybar modules"""
        return [
            "clock",
            "hyprland/workspaces",
            "tray",
            "pulseaudio",
            "network",
            "battery",
            "cpu",
            "memory",
            "disk",
            "temperature",
            "backlight",
            "bluetooth",
            "custom/notification",
            "idle_inhibitor",
            "mpd",
            "custom/weather"
        ]