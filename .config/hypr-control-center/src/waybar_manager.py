"""
Waybar Configuration Manager
Handles Waybar config.json and style.css files
INCLUDES: Hexdump utility for Nerd Font icon extraction and preservation
"""

import json
import subprocess
import re
from pathlib import Path
from typing import Dict, List, Any, Optional

from .constants import WAYBAR_DIR


class WaybarManager:
    """Manages Waybar configuration files"""
    
    def __init__(self):
        self.waybar_dir = WAYBAR_DIR
        self.config_file = self.waybar_dir / "config.jsonc"
        self.style_file = self.waybar_dir / "style.css"
        self.waybar2_dir = WAYBAR_DIR / "waybar2"
        self.waybar2_config = self.waybar2_dir / "config.jsonc"
        self.waybar2_style = self.waybar2_dir / "style.css"
        
        # Current configs
        self.main_config: Dict[str, Any] = {}
        self.dock_config: Dict[str, Any] = {}
        
    # ====================================================================
    # HEXDUMP & ICON EXTRACTION UTILITIES
    # ====================================================================
    
    def hexdump_module_icons(self, module_name: str, config_path: Path = None) -> dict:
        """
        Extract Nerd Font icons from a specific module using hexdump analysis
        Returns dict with Unicode codepoints and raw characters
        """
        if config_path is None:
            config_path = self.config_file
            
        if not config_path.exists():
            return {}
        
        try:
            # Read config as bytes for accurate hex analysis
            with open(config_path, 'rb') as f:
                content = f.read()
            
            # Decode to string
            config_text = content.decode('utf-8')
            
            # Find the module's format string
            pattern = rf'"{module_name}":\s*\{{[^}}]*"format":\s*"([^"]*)"'
            match = re.search(pattern, config_text, re.DOTALL)
            
            if not match:
                return {}
            
            format_string = match.group(1)
            
            # Extract all non-ASCII characters (Nerd Font icons)
            icons = []
            for char in format_string:
                if ord(char) > 127:  # Non-ASCII = Nerd Font icon
                    icons.append({
                        'char': char,
                        'codepoint': f"U+{ord(char):04X}",
                        'unicode_escape': f"\\u{ord(char):04x}",
                        'hex_bytes': char.encode('utf-8').hex(),
                        'decimal': ord(char)
                    })
            
            return {
                'module': module_name,
                'format': format_string,
                'icons': icons,
                'icon_count': len(icons)
            }
            
        except Exception as e:
            print(f"Error extracting icons from {module_name}: {e}")
            return {}
    
    def extract_all_module_icons(self, config_path: Path = None) -> dict:
        """Extract Nerd Font icons from all modules"""
        modules = [
            'cpu', 'memory', 'temperature', 'pulseaudio',
            'network', 'bluetooth', 'battery', 'clock',
            'custom/notification', 'custom/expand', 'custom/pacman',
            'custom/music'
        ]
        
        all_icons = {}
        for module in modules:
            result = self.hexdump_module_icons(module, config_path)
            if result and result.get('icon_count', 0) > 0:
                all_icons[module] = result
        
        return all_icons
    
    def print_icon_analysis(self):
        """Print detailed analysis of all Nerd Font icons"""
        print("\n" + "="*70)
        print("WAYBAR NERD FONT ICON ANALYSIS")
        print("="*70)
        
        all_icons = self.extract_all_module_icons()
        
        if not all_icons:
            print("No Nerd Font icons found in config")
            return
        
        for module, data in all_icons.items():
            print(f"\n📦 Module: {module}")
            print(f"   Format: {data['format']}")
            print(f"   Icons found: {data['icon_count']}")
            
            for i, icon_info in enumerate(data['icons'], 1):
                print(f"\n   Icon #{i}:")
                print(f"      Character: {icon_info['char']}")
                print(f"      Codepoint: {icon_info['codepoint']}")
                print(f"      Unicode Escape: {icon_info['unicode_escape']}")
                print(f"      Hex Bytes: {icon_info['hex_bytes']}")
                print(f"      Decimal: {icon_info['decimal']}")
        
        print("\n" + "="*70)
    
    def get_module_icon_literal(self, module_name: str) -> str:
        """
        Get the raw icon character for a module
        Returns empty string if no icon found
        """
        data = self.hexdump_module_icons(module_name)
        if data and data.get('icons'):
            # Return first icon (usually the one before {icon})
            return data['icons'][0]['char']
        return ""
    
    def verify_nerd_fonts_installed(self) -> dict:
        """
        Verify Nerd Fonts are installed on system
        """
        try:
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
                'fonts': nerd_fonts[:10],
                'count': len(nerd_fonts)
            }
        except Exception as e:
            return {
                'installed': False,
                'error': str(e)
            }
    
    # ====================================================================
    # ORIGINAL WAYBAR MANAGER METHODS
    # ====================================================================
    
    def load_config(self, is_dock: bool = False) -> bool:
        """Load waybar config.jsonc (JSON with comments)"""
        config_path = self.waybar2_config if is_dock else self.config_file
        
        if not config_path.exists():
            # If config doesn't exist, create from default
            default = self.create_default_config(is_dock=is_dock)
            self.save_config(default, is_dock=is_dock)
            return True
            
        try:
            with open(config_path, 'r', encoding='utf-8') as f:
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
        """Save waybar config.jsonc - preserves all module definitions INCLUDING Nerd Font icons"""
        config_path = self.waybar2_config if is_dock else self.config_file
        config_dir = config_path.parent
        
        config_dir.mkdir(parents=True, exist_ok=True)
        
        # Read existing config to preserve module definitions
        existing_config = {}
        if config_path.exists():
            try:
                with open(config_path, 'r', encoding='utf-8') as f:
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
            'height', 'position', 'layer',
            'margin-top', 'margin-bottom', 'margin-left', 'margin-right',
            'modules-left', 'modules-center', 'modules-right'
        ]
        
        # Start with existing config to preserve module definitions
        final_config = existing_config.copy()
        
        # Update layout keys (position, margins, modules-*)
        for key in editable_keys:
            if key in config:
                final_config[key] = config[key]

        # Merge ALL missing module definitions from new config
        for key, value in config.items():
            if key not in final_config:
                final_config[key] = value
        
        # Convert surrogate pairs to actual characters before saving
        final_config = self._fix_surrogate_pairs(final_config)
                
        # Save with UTF-8 encoding
        with open(config_path, 'w', encoding='utf-8') as f:
            json.dump(final_config, f, indent=4, ensure_ascii=False)
        
        self.reload_waybar()


    def _fix_surrogate_pairs(self, obj):
        """Recursively fix surrogate pairs in dict/list structures"""
        if isinstance(obj, dict):
            return {k: self._fix_surrogate_pairs(v) for k, v in obj.items()}
        elif isinstance(obj, list):
            return [self._fix_surrogate_pairs(item) for item in obj]
        elif isinstance(obj, str):
            # Convert surrogate pairs to actual Unicode characters
            try:
                # Encode with surrogatepass, then decode normally
                return obj.encode('utf-16', 'surrogatepass').decode('utf-16')
            except:
                return obj
        else:
            return obj

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
        return config.get('height', 20)
    
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
    
    def load_default_config_from_file(self, is_dock: bool = False) -> Dict[str, Any]:
        """Load default config from JSON file in preferences"""
        prefs_dir = Path.home() / ".config/hypr-control-center/preferences/waybar"
        default_file = prefs_dir / "default-config.jsonc"
        
        # If file doesn't exist, return hardcoded fallback
        if not default_file.exists():
            return self._get_hardcoded_default(is_dock)
        
        # Load from file
        try:
            with open(default_file, 'r', encoding='utf-8') as f:
                content = f.read()
                # Remove comments
                lines = []
                for line in content.split('\n'):
                    if '//' in line:
                        line = line[:line.index('//')]
                    lines.append(line)
                config = json.loads('\n'.join(lines))
                return config
        except Exception as e:
            print(f"Error loading default config from file: {e}")
            # Fallback to hardcoded
            return self._get_hardcoded_default(is_dock)

    def _get_hardcoded_default(self, is_dock: bool = False) -> Dict[str, Any]:
        """Hardcoded fallback default config"""
        if is_dock:
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
            home_dir = Path.home()
            return {
                "height": 40,
                "position": "bottom",
                "layer": "top",
                "margin-top": 4,
                "margin-right": 0,
                "margin-bottom": 3,
                "margin-left": 0,
                "modules-left": [
                    "custom/start-menu",
                    "custom/taskbar",
                    "custom/music"
                ],
                "modules-center": [
                    "hyprland/workspaces",
                    "hyprland/window"
                ],
                "modules-right": [
                    "group/expand",
                    "custom/notification",
                    "clock"
                ],
                "hyprland/workspaces": {
                    "disable-scroll": True,
                    "sort-by-name": True,
                    "format": " {icon} ",
                    "persistent-workspaces": {
                        "*": 5
                    },
                    "format-icons": {
                        "1": "1",
                        "2": "2",
                        "3": "3",
                        "4": "4",
                        "5": "5",
                        "active": "",
                        "default": ""
                    },
                    "on-scroll-up": "hyprctl dispatch workspace e+1",
                    "on-scroll-down": "hyprctl dispatch workspace e-1",
                    "on-click": "activate"
                },
                "tray": {
                    "icon-size": 21,
                    "spacing": 10
                },
                "custom/notification": {
                    "tooltip": True,
                    "format": "<span size='16pt'>{icon}</span>",
                    "format-icons": {
                        "notification": "\udb84\udd6b",
                        "none": "\udb80\udc9c",
                        "dnd-notification": "\udb80\udca0",
                        "dnd-none": "\udb82\ude93",
                        "inhibited-notification": "\udb80\udc9b",
                        "inhibited-none": "\udb82\ude91",
                        "dnd-inhibited-notification": "\udb80\udc9b",
                        "dnd-inhibited-none": "\udb82\ude91"
                    },
                    "return-type": "json",
                    "exec-if": "which swaync-client",
                    "exec": "swaync-client -swb",
                    "on-click": "swaync-client -t -sw",
                    "on-click-right": "swaync-client -d -sw",
                    "escape": True
                },
                "custom/taskbar": {
                    "return-type": "json",
                    "exec": f"{home_dir}/.config/hypr/scripts/waybar/taskbar-render.sh",
                    "interval": 1,
                    "format": "{}",
                    "escape": False,
                    "on-click": f"{home_dir}/.config/hypr/scripts/waybar/taskbar-click.sh",
                    "on-click-middle": f"{home_dir}/.config/hypr/scripts/waybar/taskbar-smart-click.sh",
                    "on-click-right": f"{home_dir}/.config/hypr/scripts/waybar/taskbar-menu-global.sh"
                },
                "custom/pinned": {
                    "return-type": "json",
                    "exec": f"{home_dir}/.config/hypr/scripts/waybar/pinned-apps-render.sh",
                    "interval": 2,
                    "format": "{}",
                    "escape": False,
                    "on-click": f"{home_dir}/.config/hypr/scripts/waybar/pinned-apps-click.sh"
                },
                "wlr/taskbar": {
                    "format": "{icon} {count}",
                    "all-outputs": True,
                    "on-click": "activate",
                    "on-click-middle": f"exec {home_dir}/.config/hypr/scripts/waybar/taskbar-smart-click.sh",
                    "on-click-right": f"exec {home_dir}/.config/hypr/scripts/waybar/taskbar-wlr-menu.sh"
                },
                "hyprland/window": {
                    "format": "{title}",
                    "max-length": 50,
                    "separate-outputs": True,
                    "rewrite": {
                        "(.*) — Mozilla Firefox": "  $1",
                        "(.*) - Mozilla Firefox": "  $1",
                        "(.*) - Visual Studio Code": "  $1",
                        "(.*) - Code": "  $1",
                        "(.*) - kitty": "  $1",
                        "(.*)": "  $1"
                    }
                },
                "cpu": {
                    "interval": 1,
                    "format": "\uf2db {icon}",
                    "format-icons": ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"],
                    "tooltip": True,
                    "tooltip-format": "CPU Status:\n{usage}% Used\n{avg_frequency}GHz",
                    "on-click": f"{home_dir}/.config/alacritty/btmrun.sh"
                },
                "memory": {
                    "interval": 1,
                    "format": "\uf538 {icon}",
                    "format-icons": ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"],
                    "tooltip": True,
                    "tooltip-format": "Memory:\n{used:0.1f}G / {total:0.1f}G\n{percentage}% Used\n\nSwap:\n{swapUsed:0.1f}G / {swapTotal:0.1f}G",
                    "on-click": f"{home_dir}/.config/alacritty/btmrun.sh"
                },
                "temperature": {
                    "format": "\uf2c9 {icon}",
                    "format-icons": ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"],
                    "tooltip-format": "Temperature:  {temperatureC}°C"
                },
                "pulseaudio": {
                    "scroll-step": 10,
                    "format": "\uf028 {icon}",
                    "format-muted": "",
                    "format-icons": {
                        "default": ["▁", "▂", "▃", "▄", "▅", "▆", "▇"]
                    },
                    "tooltip": True,
                    "tooltip-format": "Audio:\nVolume: {volume}%\nDevice: {desc}",
                    "on-click": f"{home_dir}/.config/kitty/modules/audiotop.sh",
                    "on-click-right": "pavucontrol"
                },
                "network": {
                    "interval": 1,
                    "format-wifi": " {icon} ",
                    "format-ethernet": " {icon} ",
                    "format-disconnected": "󰤮",
                    "format-icons": {
                        "wifi": ["󰤯", "󰤟", "󰤢", "󰤥", "󰤨"],
                        "ethernet": "󰈀"
                    },
                    "tooltip": True,
                    "tooltip-format-wifi": "WiFi Connected:\n{essid}\nSignal: {signalStrength}%\nIP: {ipaddr}\nSpeed: {bandwidthDownBits} ↓ {bandwidthUpBits} ↑",
                    "tooltip-format-ethernet": "Ethernet Connected:\nIP: {ipaddr}\nSpeed: {bandwidthDownBits} ↓ {bandwidthUpBits} ↑",
                    "tooltip-format-disconnected": "Network Disconnected\n\nClick to select WiFi",
                    "on-click": f"{home_dir}/.config/hypr-control-center/scripts/wifi_selector.py"
                },
                "bluetooth": {
                    "format": "\uf293 ",
                    "format-disabled": "\uf293 ",
                    "format-connected": "\uf293 {num_connections} ",
                    "format-connected-battery": "\uf293 {num_connections} {device_battery_percentage}% ",
                    "tooltip": True,
                    "tooltip-format": "Bluetooth: {status}\n{num_connections} device(s) connected",
                    "tooltip-format-connected": "Bluetooth Connected:\n{device_enumerate}",
                    "tooltip-format-enumerate-connected": "{device_alias}\t{device_battery_percentage}%",
                    "tooltip-format-enumerate-connected-battery": "{device_alias}\t{device_battery_percentage}%",
                    "on-click": f"{home_dir}/.config/alacritty/bluetoothrun.sh",
                    "on-click-right": "blueman-manager"
                },
                "battery": {
                    "interval": 5,
                    "states": {
                        "warning": 30,
                        "critical": 15
                    },
                    "format": "\uf0e7 {icon} ",
                    "format-charging": "\uf1e6 {icon} ",
                    "format-plugged": "\uf1e6 {icon} ",
                    "format-icons": [
                        "\uf244",
                        "\uf243",
                        "\uf242",
                        "\uf241",
                        "\uf240"
                    ],
                    "tooltip": True,
                    "tooltip-format": "Battery:\n{capacity}% {timeTo}\nPower: {power}W\n\nStatus: {status}",
                    "tooltip-format-charging": "Battery Charging:\n{capacity}% - {timeTo}\nPower: {power}W",
                    "tooltip-format-full": "Battery Full:\n100% Charged"
                },
                "custom/pacman": {
                    "format": "\U000f003c {}",
                    "interval": 3600,
                    "exec": "checkupdates 2>/dev/null | wc -l || echo 0",
                    "exec-if": "exit 0",
                    "on-click": f"kitty sh -c 'yay -Qu; echo; echo Press enter to upgrade or Ctrl+C to cancel; read; yay -Syu; echo Done; read'; pkill -SIGRTMIN+8 waybar",
                    "signal": 8,
                    "tooltip": True,
                    "tooltip-format": "{} updates available"
                },
                "group/expand": {
                    "orientation": "horizontal",
                    "drawer": {
                        "transition-duration": 600,
                        "transition-to-left": True,
                        "click-to-reveal": True
                    },
                    "modules": [
                        "custom/expand",
                        "pulseaudio",
                        "cpu",
                        "memory",
                        "temperature",
                        "network",
                        "bluetooth",
                        "custom/pacman",
                        "custom/endpoint"
                    ]
                },
                "custom/expand": {
                    "format": "\uf104",
                    "tooltip": False
                },
                "custom/endpoint": {
                    "format": "|",
                    "tooltip": False
                },
                "clock": {
                    "format": "\uf017 {:%Y-%m-%d \n %I:%M:%S %p}",
                    "interval": 1,
                    "tooltip-format": "<tt>{calendar}</tt>",
                    "calendar": {
                        "format": {
                            "today": "<span color='#fAfBfC'><b>{}</b></span>"
                        }
                    },
                    "actions": {
                        "on-click-right": "shift_down",
                        "on-click": "shift_up"
                    }
                },
                "custom/music": {
                    "format": "{}",
                    "return-type": "json",
                    "exec": f"{home_dir}/.config/hypr-control-center/scripts/music.sh",
                    "interval": 2,
                    "max-length": 40,
                    "on-click": "playerctl play-pause",
                    "on-click-right": "playerctl next",
                    "on-click-middle": "playerctl previous",
                    "on-scroll-up": "playerctl position 5+",
                    "on-scroll-down": "playerctl position 5-",
                    "escape": True,
                    "tooltip": True
                },
                "custom/panel": {
                    "format": "",
                    "tooltip": False
                },
                "custom/start-menu": {
                    "format": "  ",
                    "tooltip": True,
                    "on-click": f"{home_dir}/.config/hypr-control-center/scripts/start-menu-toggle.sh",
                    "on-click-right": f"{home_dir}/.config/hypr-control-center/scripts/start-menu-toggle.sh close"
                }
            }

    def create_default_config(self, is_dock: bool = False) -> Dict[str, Any]:
        """Create default config - tries to load from file, falls back to hardcoded"""
        return self.load_default_config_from_file(is_dock)
    
    def get_available_modules(self) -> List[str]:
        """Get list of available waybar modules"""
        return [
            "clock",
            "hyprland/workspaces",
            "hyprland/window",
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
            "custom/taskbar",
            "custom/pinned",
            "custom/music",
            "custom/pacman",
            "custom/expand",
            "custom/endpoint",
            "idle_inhibitor",
            "mpd",
            "custom/weather",
            "wlr/taskbar",
            "custom/start-menu",
        ]

    def apply_style_config(self, mode: str, is_dock: bool = False):
        """Apply module configuration based on style mode"""
        # This method can be extended to change modules based on style
        # For now, it just reloads to apply CSS changes
        pass


# Utility to run icon analysis from command line
if __name__ == "__main__":
    import sys
    
    manager = WaybarManager()
    
    if len(sys.argv) > 1 and sys.argv[1] == "analyze":
        manager.print_icon_analysis()
    elif len(sys.argv) > 1 and sys.argv[1] == "verify":
        result = manager.verify_nerd_fonts_installed()
        print("\n" + "="*70)
        print("NERD FONT VERIFICATION")
        print("="*70)
        if result['installed']:
            print(f"✓ Nerd Fonts installed: {result['count']} fonts found")
            print("\nSample fonts:")
            for font in result['fonts']:
                print(f"  • {font}")
        else:
            print("✗ Nerd Fonts not found")
            if 'error' in result:
                print(f"Error: {result['error']}")
        print("="*70)
    else:
        print("Usage:")
        print("  python waybar_manager.py analyze  - Analyze Nerd Font icons")
        print("  python waybar_manager.py verify   - Verify Nerd Font installation")