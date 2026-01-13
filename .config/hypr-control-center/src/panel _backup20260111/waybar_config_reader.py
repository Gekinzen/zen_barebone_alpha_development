"""
WaybarConfigReader - Dynamic Position Detection for Panel Overlay
=================================================================

Reads Waybar config and calculates exact pixel position for the 
Python panel overlay based on where custom/panel is placed.

Supports:
- modules-left, modules-center, modules-right detection
- Dynamic margin calculation
- Theme extraction from style.css
"""

import json
import re
import subprocess
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass


@dataclass
class PanelPosition:
    """Calculated position for panel overlay"""
    location: str  # "left", "center", "right"
    waybar_position: str  # "top" or "bottom"
    waybar_height: int
    waybar_margin_top: int
    waybar_margin_bottom: int
    waybar_margin_left: int
    waybar_margin_right: int
    
    # Calculated margins for overlay
    margin_left: int = 0
    margin_right: int = 0
    
    # Index position in modules list
    module_index: int = 0
    modules_before: List[str] = None
    
    def __post_init__(self):
        if self.modules_before is None:
            self.modules_before = []


@dataclass 
class WaybarTheme:
    """Theme colors extracted from Waybar CSS"""
    bg0: str = "#1a1b26"
    bg1: str = "#16161e"
    bg2: str = "#24283b"
    bg3: str = "#414868"
    fg: str = "#c0caf5"
    fg_dim: str = "#565f89"
    blue: str = "#7aa2f7"
    purple: str = "#bb9af7"
    red: str = "#f7768e"
    green: str = "#9ece6a"
    yellow: str = "#e0af68"
    orange: str = "#ff9e64"
    cyan: str = "#7dcfff"
    border_radius: int = 12
    font_family: str = "JetBrainsMono Nerd Font"
    font_size: int = 12


class WaybarConfigReader:
    """
    Reads Waybar configuration and calculates overlay position.
    
    Usage:
        reader = get_waybar_reader()
        position = reader.get_panel_position("custom/panel")
        theme = reader.get_theme()
    """
    
    WAYBAR_CONFIG = Path.home() / ".config/waybar"
    
    # Estimated module widths (pixels) - for position calculation
    MODULE_WIDTHS = {
        'clock': 140,
        'custom/clock': 140,
        'hyprland/workspaces': 200,
        'wlr/workspaces': 200,
        'custom/music': 200,
        'mpris': 200,
        'custom/notification': 40,
        'custom/power': 40,
        'tray': 100,
        'pulseaudio': 40,
        'network': 40,
        'battery': 60,
        'cpu': 60,
        'memory': 60,
        'temperature': 50,
        'backlight': 40,
        'custom/weather': 80,
        'hyprland/window': 200,
        'wlr/taskbar': 300,
        'default': 80,  # Default width for unknown modules
    }
    
    _instance = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._initialized = False
        return cls._instance
    
    def __init__(self):
        if self._initialized:
            return
        
        self._config: Dict = {}
        self._theme: Optional[WaybarTheme] = None
        self._screen_width: int = 1920
        
        self._load_config()
        self._load_theme()
        self._detect_screen_width()
        
        self._initialized = True
        print(f"[WaybarReader] ✅ Initialized (screen: {self._screen_width}px)")
    
    def _load_config(self) -> None:
        """Load Waybar config.jsonc"""
        config_path = self.WAYBAR_CONFIG / "config.jsonc"
        if not config_path.exists():
            config_path = self.WAYBAR_CONFIG / "config.json"
        
        if not config_path.exists():
            print("[WaybarReader] ⚠️ No Waybar config found")
            return
        
        try:
            content = config_path.read_text()
            # Remove JSONC comments
            content = re.sub(r'//.*$', '', content, flags=re.MULTILINE)
            content = re.sub(r'/\*[\s\S]*?\*/', '', content)
            content = re.sub(r',(\s*[}\]])', r'\1', content)
            
            data = json.loads(content)
            
            # Handle array config (multiple bars)
            if isinstance(data, list):
                data = data[0] if data else {}
            
            self._config = data
            print(f"[WaybarReader] Loaded config: {config_path}")
            
        except Exception as e:
            print(f"[WaybarReader] ❌ Config error: {e}")
    
    def _load_theme(self) -> None:
        """Load theme from style.css"""
        self._theme = WaybarTheme()
        
        style_path = self.WAYBAR_CONFIG / "style.css"
        if not style_path.exists():
            return
        
        try:
            content = style_path.read_text()
            
            # Check for @import
            import_match = re.search(r'@import\s+["\']([^"\']+)["\']', content)
            if import_match:
                import_path = import_match.group(1)
                if import_path.startswith('../'):
                    full_path = (self.WAYBAR_CONFIG / import_path).resolve()
                else:
                    full_path = Path(import_path.replace('~', str(Path.home())))
                
                if full_path.exists():
                    content = full_path.read_text() + "\n" + content
            
            # Parse @define-color
            color_map = {
                'bg0': 'bg0', 'bg': 'bg0', 'background': 'bg0',
                'bg1': 'bg1', 'bg2': 'bg2', 'bg3': 'bg3',
                'fg': 'fg', 'foreground': 'fg',
                'fg-dim': 'fg_dim', 'comment': 'fg_dim',
                'blue': 'blue', 'accent': 'blue',
                'purple': 'purple', 'magenta': 'purple',
                'red': 'red', 'green': 'green',
                'yellow': 'yellow', 'orange': 'orange',
                'cyan': 'cyan',
            }
            
            for match in re.finditer(r'@define-color\s+(\w+)\s+([^;]+);', content):
                var_name = match.group(1).strip()
                color_value = match.group(2).strip()
                
                if var_name in color_map:
                    setattr(self._theme, color_map[var_name], color_value)
            
            # Parse border-radius
            radius_match = re.search(r'border-radius:\s*(\d+)', content)
            if radius_match:
                self._theme.border_radius = int(radius_match.group(1))
            
            # Parse font
            font_match = re.search(r'font-family:\s*([^;]+);', content)
            if font_match:
                self._theme.font_family = font_match.group(1).strip().strip('"\'')
            
            size_match = re.search(r'font-size:\s*(\d+)', content)
            if size_match:
                self._theme.font_size = int(size_match.group(1))
                
        except Exception as e:
            print(f"[WaybarReader] ⚠️ Theme error: {e}")
    
    def _detect_screen_width(self) -> None:
        """Detect screen width from Hyprland"""
        try:
            result = subprocess.run(
                ['hyprctl', '-j', 'monitors'],
                capture_output=True, text=True, timeout=2
            )
            if result.returncode == 0:
                monitors = json.loads(result.stdout)
                if monitors:
                    # Use primary/first monitor
                    self._screen_width = monitors[0].get('width', 1920)
        except Exception:
            pass
    
    def get_panel_position(self, module_name: str = "custom/panel") -> PanelPosition:
        """
        Calculate exact position for panel overlay.
        
        Detects if module is in left/center/right and calculates margins.
        """
        # Get Waybar settings
        waybar_height = self._config.get('height', 40)
        waybar_position = self._config.get('position', 'bottom')
        margin_top = self._config.get('margin-top', 4)
        margin_bottom = self._config.get('margin-bottom', 3)
        margin_left = self._config.get('margin-left', 4)
        margin_right = self._config.get('margin-right', 4)
        
        modules_left = self._config.get('modules-left', [])
        modules_center = self._config.get('modules-center', [])
        modules_right = self._config.get('modules-right', [])
        
        # Find which section contains our module
        location = "left"
        module_index = 0
        modules_before = []
        
        if module_name in modules_left:
            location = "left"
            module_index = modules_left.index(module_name)
            modules_before = modules_left[:module_index]
        elif module_name in modules_center:
            location = "center"
            module_index = modules_center.index(module_name)
            modules_before = modules_center[:module_index]
        elif module_name in modules_right:
            location = "right"
            module_index = modules_right.index(module_name)
            modules_before = modules_right[:module_index]
        else:
            print(f"[WaybarReader] ⚠️ Module '{module_name}' not found in config")
        
        # Calculate margins based on position
        calc_margin_left = margin_left
        calc_margin_right = margin_right
        
        if location == "left":
            # Calculate width of modules before this one
            width_before = self._calculate_modules_width(modules_before)
            calc_margin_left = margin_left + width_before + 8  # 8px spacing
            calc_margin_right = 0  # Don't anchor right
            
        elif location == "center":
            # Center section - need to calculate offset from center
            width_before = self._calculate_modules_width(modules_before)
            modules_after = modules_center[module_index + 1:] if module_index + 1 < len(modules_center) else []
            width_after = self._calculate_modules_width(modules_after)
            
            # Calculate left section total width
            left_total = self._calculate_modules_width(modules_left) + margin_left
            right_total = self._calculate_modules_width(modules_right) + margin_right
            
            # Center area starts after left section
            calc_margin_left = left_total + width_before + 16
            calc_margin_right = right_total + width_after + 16
            
        elif location == "right":
            # Calculate from right side
            modules_after = modules_right[module_index + 1:] if module_index + 1 < len(modules_right) else []
            width_after = self._calculate_modules_width(modules_after)
            calc_margin_left = 0  # Don't anchor left
            calc_margin_right = margin_right + width_after + 8
        
        position = PanelPosition(
            location=location,
            waybar_position=waybar_position,
            waybar_height=waybar_height,
            waybar_margin_top=margin_top,
            waybar_margin_bottom=margin_bottom,
            waybar_margin_left=margin_left,
            waybar_margin_right=margin_right,
            margin_left=calc_margin_left,
            margin_right=calc_margin_right,
            module_index=module_index,
            modules_before=modules_before,
        )
        
        print(f"[WaybarReader] 📍 Panel position: {location}")
        print(f"[WaybarReader]    Modules before: {modules_before}")
        print(f"[WaybarReader]    Margins: L={calc_margin_left}, R={calc_margin_right}")
        
        return position
    
    def _calculate_modules_width(self, modules: List[str]) -> int:
        """Calculate estimated total width of modules"""
        total = 0
        for mod in modules:
            width = self.MODULE_WIDTHS.get(mod, self.MODULE_WIDTHS['default'])
            total += width
        return total
    
    def get_theme(self) -> WaybarTheme:
        """Get parsed theme"""
        return self._theme or WaybarTheme()
    
    def get_config(self) -> Dict:
        """Get raw Waybar config"""
        return self._config
    
    def get_modules(self, section: str = "all") -> List[str]:
        """Get modules list"""
        if section == "left":
            return self._config.get('modules-left', [])
        elif section == "center":
            return self._config.get('modules-center', [])
        elif section == "right":
            return self._config.get('modules-right', [])
        else:
            return (
                self._config.get('modules-left', []) +
                self._config.get('modules-center', []) +
                self._config.get('modules-right', [])
            )
    
    def has_module(self, module_name: str) -> bool:
        """Check if module exists in config"""
        return module_name in self.get_modules()
    
    def reload(self) -> None:
        """Reload configuration"""
        self._initialized = False
        self.__init__()


# Singleton getter
_reader_instance: Optional[WaybarConfigReader] = None

def get_waybar_reader() -> WaybarConfigReader:
    """Get singleton WaybarConfigReader instance"""
    global _reader_instance
    if _reader_instance is None:
        _reader_instance = WaybarConfigReader()
    return _reader_instance


# ═══════════════════════════════════════════════════════════════════════════════
# TESTING
# ═══════════════════════════════════════════════════════════════════════════════

if __name__ == "__main__":
    reader = get_waybar_reader()
    
    print("\n📋 Waybar Config:")
    print(f"   Position: {reader._config.get('position', 'bottom')}")
    print(f"   Height: {reader._config.get('height', 40)}")
    
    print(f"\n📦 Modules:")
    print(f"   Left: {reader.get_modules('left')}")
    print(f"   Center: {reader.get_modules('center')}")
    print(f"   Right: {reader.get_modules('right')}")
    
    print("\n📍 Panel Position Test:")
    for mod in ['custom/panel', 'custom/taskbar', 'wlr/taskbar']:
        if reader.has_module(mod):
            pos = reader.get_panel_position(mod)
            print(f"   {mod}: {pos.location}, L={pos.margin_left}, R={pos.margin_right}")
    
    print("\n🎨 Theme:")
    theme = reader.get_theme()
    print(f"   BG: {theme.bg0}")
    print(f"   FG: {theme.fg}")
    print(f"   Blue: {theme.blue}")
    print(f"   Font: {theme.font_family} {theme.font_size}px")