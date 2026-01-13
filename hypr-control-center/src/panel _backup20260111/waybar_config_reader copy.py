#!/usr/bin/env python3
"""
Waybar Config Reader
Parses Waybar config.jsonc and style.css to:
1. Detect panel position and neighbors
2. Extract theme colors for GTK4 panel

Location: ~/.config/hypr-control-center/src/panel/waybar_config_reader.py
"""

import json
import re
import os
import subprocess
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass, field


@dataclass
class WaybarTheme:
    """Extracted theme colors from Waybar CSS"""
    # Base colors
    bg0: str = "#282c34"
    bg1: str = "#21252b"
    bg2: str = "#2c313a"
    bg3: str = "#3e4451"
    bg4: str = "#4b5263"
    fg: str = "#abb2bf"
    
    # Accent colors
    red: str = "#e06c75"
    orange: str = "#d19a66"
    yellow: str = "#e5c07b"
    green: str = "#98c379"
    aqua: str = "#56b6c2"
    blue: str = "#61afef"
    purple: str = "#c678dd"
    
    # Grey shades
    grey0: str = "#5c6370"
    grey1: str = "#828997"
    grey2: str = "#abb2bf"
    
    # Styling
    border_radius: int = 45
    font_family: str = "JetBrainsMono Nerd Font Propo"
    font_size: int = 16
    padding: str = "0 15px"
    margin: str = "0 0 0 12px"
    border_width: int = 1
    background_alpha: float = 0.9


@dataclass
class PanelPosition:
    """Panel position info from Waybar config"""
    location: str = "center"  # left, center, right
    index: int = 0  # Position in modules array
    
    # Neighbors
    modules_before: List[str] = field(default_factory=list)
    modules_after: List[str] = field(default_factory=list)
    
    # Waybar settings
    waybar_position: str = "bottom"  # top, bottom
    waybar_height: int = 40
    waybar_margin_top: int = 4
    waybar_margin_bottom: int = 3
    waybar_margin_left: int = 0
    waybar_margin_right: int = 0
    
    # Calculated margins for GTK panel
    margin_left: int = 0
    margin_right: int = 0
    margin_top: int = 0
    margin_bottom: int = 0


# ==========================================
# MODULE WIDTH ESTIMATES (in pixels)
# ==========================================

MODULE_WIDTHS = {
    # Workspaces (5 buttons)
    "hyprland/workspaces": 200,
    
    # Window title
    "hyprland/window": 250,
    
    # Custom modules
    "custom/taskbar": 300,
    "custom/pinned": 200,
    "custom/music": 180,
    "custom/notification": 50,
    "custom/pacman": 60,
    "custom/expand": 30,
    "custom/endpoint": 20,
    
    # System modules
    "clock": 140,
    "battery": 50,
    "pulseaudio": 50,
    "cpu": 50,
    "memory": 50,
    "temperature": 50,
    "network": 50,
    "bluetooth": 50,
    "tray": 100,
    
    # Groups
    "group/expand": 60,  # Collapsed state
    
    # Taskbar
    "wlr/taskbar": 200,
    "taskbar": 200,
    
    # Default
    "default": 80,
}


def get_waybar_geometry() -> Optional[Dict]:
    """Get Waybar window geometry using hyprctl"""
    try:
        result = subprocess.run(
            ['hyprctl', '-j', 'clients'],
            capture_output=True, text=True, timeout=2
        )
        if result.returncode == 0:
            clients = json.loads(result.stdout)
            for client in clients:
                # Find Waybar window
                if client.get('class', '').lower() == 'waybar':
                    return {
                        'x': client.get('at', [0, 0])[0],
                        'y': client.get('at', [0, 0])[1],
                        'width': client.get('size', [0, 0])[0],
                        'height': client.get('size', [0, 0])[1],
                    }
    except Exception as e:
        print(f"[WaybarConfigReader] Error getting Waybar geometry: {e}")
    return None


def get_monitor_width() -> int:
    """Get primary monitor width using hyprctl"""
    try:
        result = subprocess.run(
            ['hyprctl', '-j', 'monitors'],
            capture_output=True, text=True, timeout=2
        )
        if result.returncode == 0:
            monitors = json.loads(result.stdout)
            for monitor in monitors:
                if monitor.get('focused', False):
                    return monitor.get('width', 1920)
            # Return first monitor if no focused
            if monitors:
                return monitors[0].get('width', 1920)
    except:
        pass
    return 1920


class WaybarConfigReader:
    """
    Reads and parses Waybar configuration
    
    Usage:
        reader = WaybarConfigReader()
        position = reader.get_panel_position()
        theme = reader.get_theme()
    
    Manual Override:
        Create ~/.config/hypr-control-center/panel-config.json:
        {
            "margin_left": 500,
            "margin_right": 300,
            "module_widths": {
                "hyprland/workspaces": 250,
                "clock": 150
            }
        }
    """
    
    def __init__(self, config_dir: Optional[Path] = None):
        self.config_dir = config_dir or Path.home() / ".config/waybar"
        self.panel_config_dir = Path.home() / ".config/hypr-control-center"
        self.config_file = self._find_config_file()
        self.style_file = self.config_dir / "style.css"
        self.override_file = self.panel_config_dir / "panel-config.json"
        
        self._config: Dict = {}
        self._override: Dict = {}
        self._theme: Optional[WaybarTheme] = None
        self._position: Optional[PanelPosition] = None
        
        # Load configs
        self._load_config()
        self._load_override()
        
        print(f"[WaybarConfigReader] Config: {self.config_file}")
        print(f"[WaybarConfigReader] Style: {self.style_file}")
        if self._override:
            print(f"[WaybarConfigReader] Override: {self.override_file}")
    
    def _find_config_file(self) -> Path:
        """Find Waybar config file (supports multiple formats)"""
        candidates = [
            self.config_dir / "config.jsonc",
            self.config_dir / "config.json",
            self.config_dir / "config",
        ]
        
        for candidate in candidates:
            if candidate.exists():
                return candidate
        
        return self.config_dir / "config.jsonc"
    
    def _load_config(self):
        """Load and parse Waybar config"""
        if not self.config_file.exists():
            print(f"[WaybarConfigReader] Config not found: {self.config_file}")
            return
        
        try:
            with open(self.config_file, 'r') as f:
                content = f.read()
            
            # Remove comments (// and /* */)
            content = re.sub(r'//.*?$', '', content, flags=re.MULTILINE)
            content = re.sub(r'/\*.*?\*/', '', content, flags=re.DOTALL)
            
            # Remove trailing commas (invalid JSON but valid JSONC)
            content = re.sub(r',\s*([}\]])', r'\1', content)
            
            self._config = json.loads(content)
            print(f"[WaybarConfigReader] Loaded config successfully")
        
        except Exception as e:
            print(f"[WaybarConfigReader] Error loading config: {e}")
            self._config = {}
    
    def _load_override(self):
        """Load manual override config if exists"""
        if not self.override_file.exists():
            return
        
        try:
            with open(self.override_file, 'r') as f:
                self._override = json.load(f)
            
            # Apply module width overrides
            if 'module_widths' in self._override:
                MODULE_WIDTHS.update(self._override['module_widths'])
            
            print(f"[WaybarConfigReader] Loaded override config")
        except Exception as e:
            print(f"[WaybarConfigReader] Error loading override: {e}")
    
    # ==========================================
    # PANEL POSITION
    # ==========================================
    
    def get_panel_position(self, panel_module: str = "custom/panel") -> PanelPosition:
        """Get panel position from Waybar config"""
        if self._position:
            return self._position
        
        position = PanelPosition()
        
        # Get Waybar settings
        position.waybar_position = self._config.get("position", "bottom")
        position.waybar_height = self._config.get("height", 40)
        position.waybar_margin_top = self._config.get("margin-top", 0)
        position.waybar_margin_bottom = self._config.get("margin-bottom", 0)
        position.waybar_margin_left = self._config.get("margin-left", 0)
        position.waybar_margin_right = self._config.get("margin-right", 0)
        
        # Find panel in modules
        modules_left = self._config.get("modules-left", [])
        modules_center = self._config.get("modules-center", [])
        modules_right = self._config.get("modules-right", [])
        
        # Check each location
        if panel_module in modules_left:
            position.location = "left"
            idx = modules_left.index(panel_module)
            position.index = idx
            position.modules_before = modules_left[:idx]
            position.modules_after = modules_left[idx+1:]
        
        elif panel_module in modules_center:
            position.location = "center"
            idx = modules_center.index(panel_module)
            position.index = idx
            position.modules_before = modules_center[:idx]
            position.modules_after = modules_center[idx+1:]
        
        elif panel_module in modules_right:
            position.location = "right"
            idx = modules_right.index(panel_module)
            position.index = idx
            position.modules_before = modules_right[:idx]
            position.modules_after = modules_right[idx+1:]
        
        else:
            # Default to center if not found
            print(f"[WaybarConfigReader] {panel_module} not found, defaulting to center")
            position.location = "center"
        
        # Calculate margins
        self._calculate_margins(position, modules_left, modules_center, modules_right)
        
        # Apply manual overrides if present
        if 'margin_left' in self._override:
            position.margin_left = self._override['margin_left']
            print(f"[WaybarConfigReader] Override margin_left: {position.margin_left}")
        if 'margin_right' in self._override:
            position.margin_right = self._override['margin_right']
            print(f"[WaybarConfigReader] Override margin_right: {position.margin_right}")
        if 'margin_top' in self._override:
            position.margin_top = self._override['margin_top']
        if 'margin_bottom' in self._override:
            position.margin_bottom = self._override['margin_bottom']
        
        self._position = position
        return position
    
    def _calculate_margins(self, position: PanelPosition, 
                          modules_left: List[str], 
                          modules_center: List[str],
                          modules_right: List[str]):
        """Calculate GTK panel margins based on module positions"""
        
        # Get actual monitor width
        monitor_width = get_monitor_width()
        
        # Get Waybar geometry if available
        waybar_geo = get_waybar_geometry()
        if waybar_geo:
            print(f"[WaybarConfigReader] Waybar geometry: {waybar_geo}")
        
        # Base margin from Waybar styling
        base_margin = 12  # Standard Waybar module margin
        
        # Estimate widths
        left_total = self._estimate_modules_width(modules_left)
        center_before = self._estimate_modules_width(position.modules_before)
        center_after = self._estimate_modules_width(position.modules_after)
        right_total = self._estimate_modules_width(modules_right)
        
        print(f"[WaybarConfigReader] Estimated widths: L={left_total}, CB={center_before}, CA={center_after}, R={right_total}")
        
        if position.location == "left":
            position.margin_left = self._estimate_modules_width(position.modules_before) + base_margin
            position.margin_right = monitor_width - position.margin_left - 400  # Leave space for panel
        
        elif position.location == "center":
            # For center, we need to calculate based on what's on each side
            # Left side: modules-left + modules before panel in center
            # Right side: modules after panel in center + modules-right
            
            # Calculate center offset
            # Waybar centers the center modules, so we need to account for that
            left_side_width = left_total + center_before + base_margin * 2
            right_side_width = center_after + right_total + base_margin * 2
            
            # Add extra padding for Waybar's internal spacing
            position.margin_left = left_side_width + 24
            position.margin_right = right_side_width + 24
        
        elif position.location == "right":
            position.margin_right = self._estimate_modules_width(position.modules_after) + base_margin
            position.margin_left = monitor_width - position.margin_right - 400
        
        # Vertical margins - align with Waybar
        if position.waybar_position == "bottom":
            position.margin_bottom = position.waybar_margin_bottom
            position.margin_top = 0
        else:
            position.margin_top = position.waybar_margin_top
            position.margin_bottom = 0
        
        print(f"[WaybarConfigReader] Final margins: L={position.margin_left}, R={position.margin_right}")
    
    def _estimate_modules_width(self, modules: List[str]) -> int:
        """Estimate total width of modules"""
        total = 0
        for module in modules:
            # Get width from estimates or use default
            width = MODULE_WIDTHS.get(module, MODULE_WIDTHS["default"])
            total += width
        return total
    
    # ==========================================
    # THEME COLORS
    # ==========================================
    
    def get_theme(self) -> WaybarTheme:
        """Extract theme colors from Waybar CSS"""
        if self._theme:
            return self._theme
        
        theme = WaybarTheme()
        
        if not self.style_file.exists():
            print(f"[WaybarConfigReader] Style not found, using defaults")
            return theme
        
        try:
            with open(self.style_file, 'r') as f:
                css_content = f.read()
            
            # Also check for imported colorscheme
            css_content = self._resolve_imports(css_content)
            
            # Parse @define-color directives
            color_pattern = r'@define-color\s+(\w+)\s+([^;]+);'
            for match in re.finditer(color_pattern, css_content):
                name = match.group(1)
                value = match.group(2).strip()
                
                # Map to theme attributes
                if hasattr(theme, name):
                    setattr(theme, name, value)
            
            # Parse styling from #custom-taskbar
            taskbar_style = self._extract_selector_style(css_content, "#custom-taskbar")
            
            if taskbar_style:
                # Border radius
                if 'border-radius' in taskbar_style:
                    radius = re.search(r'(\d+)', taskbar_style['border-radius'])
                    if radius:
                        theme.border_radius = int(radius.group(1))
                
                # Font family
                if 'font-family' in taskbar_style:
                    theme.font_family = taskbar_style['font-family'].strip('"\'')
                
                # Font size
                if 'font-size' in taskbar_style:
                    size = re.search(r'(\d+)', taskbar_style['font-size'])
                    if size:
                        theme.font_size = int(size.group(1))
                
                # Padding
                if 'padding' in taskbar_style:
                    theme.padding = taskbar_style['padding']
                
                # Margin
                if 'margin' in taskbar_style:
                    theme.margin = taskbar_style['margin']
            
            print(f"[WaybarConfigReader] Theme loaded: bg0={theme.bg0}, blue={theme.blue}")
        
        except Exception as e:
            print(f"[WaybarConfigReader] Error loading theme: {e}")
        
        self._theme = theme
        return theme
    
    def _resolve_imports(self, css_content: str) -> str:
        """Resolve @import statements in CSS"""
        import_pattern = r"@import\s+['\"]?([^'\";\s]+)['\"]?\s*;"
        
        for match in re.finditer(import_pattern, css_content):
            import_path = match.group(1)
            
            # Handle relative paths
            if import_path.startswith('../') or import_path.startswith('./'):
                full_path = (self.style_file.parent / import_path).resolve()
            else:
                full_path = self.config_dir / import_path
            
            if full_path.exists():
                try:
                    with open(full_path, 'r') as f:
                        imported_content = f.read()
                    css_content = imported_content + "\n" + css_content
                    print(f"[WaybarConfigReader] Imported: {full_path}")
                except:
                    pass
        
        return css_content
    
    def _extract_selector_style(self, css_content: str, selector: str) -> Optional[Dict[str, str]]:
        """Extract styles for a specific CSS selector"""
        # Match selector and its block
        pattern = rf'{re.escape(selector)}\s*\{{([^}}]+)\}}'
        match = re.search(pattern, css_content)
        
        if not match:
            return None
        
        block = match.group(1)
        styles = {}
        
        # Parse property: value pairs
        prop_pattern = r'([\w-]+)\s*:\s*([^;]+);'
        for prop_match in re.finditer(prop_pattern, block):
            prop = prop_match.group(1).strip()
            value = prop_match.group(2).strip()
            styles[prop] = value
        
        return styles
    
    # ==========================================
    # GENERATE GTK CSS
    # ==========================================
    
    def generate_panel_css(self) -> str:
        """Generate GTK CSS that matches Waybar theme - ATTACHED style"""
        theme = self.get_theme()
        position = self.get_panel_position()
        
        # Panel height should match Waybar
        panel_height = position.waybar_height - 8  # Account for padding
        
        css = f'''/* Auto-generated from Waybar theme - ATTACHED STYLE */
/* Location: ~/.config/hypr-control-center/assets/panel-generated.css */

/* Theme Colors */
@define-color panel_bg {theme.bg0};
@define-color panel_bg1 {theme.bg1};
@define-color panel_bg2 {theme.bg2};
@define-color panel_bg3 {theme.bg3};
@define-color panel_fg {theme.fg};
@define-color panel_blue {theme.blue};
@define-color panel_red {theme.red};
@define-color panel_green {theme.green};
@define-color panel_yellow {theme.yellow};
@define-color panel_purple {theme.purple};
@define-color panel_aqua {theme.aqua};
@define-color panel_orange {theme.orange};
@define-color panel_grey {theme.grey0};

/* Main Window - Transparent to blend with Waybar */
window {{
    background: transparent;
}}

/* Panel Container - Matches Waybar module style EXACTLY */
.panel-container {{
    background: alpha(@panel_bg, {theme.background_alpha});
    border-radius: {theme.border_radius}px;
    border: 1px solid @panel_bg1;
    padding: 5px 14px;
    margin: 0px;
    min-height: {panel_height}px;
}}

/* Taskbar Items - Fit inside Waybar height */
.taskbar-item {{
    background: transparent;
    border: none;
    border-radius: {theme.border_radius // 3}px;
    padding: 2px 6px;
    margin: 1px;
    min-width: 32px;
    min-height: 32px;
    transition: all 150ms ease;
}}

.taskbar-item:hover {{
    background: alpha(@panel_fg, 0.1);
}}

.taskbar-item.focused {{
    background: @panel_blue;
}}

.taskbar-item.not-running {{
    opacity: 0.5;
}}

.taskbar-item.not-running:hover {{
    opacity: 0.9;
}}

/* Icons - Sized for Waybar */
.taskbar-item-icon {{
    color: @panel_fg;
}}

.taskbar-item.focused .taskbar-item-icon {{
    color: @panel_bg;
}}

.nerd-icon {{
    font-family: "{theme.font_family}", "Symbols Nerd Font", monospace;
    font-size: {theme.font_size + 2}px;
    color: @panel_fg;
}}

.taskbar-item.focused .nerd-icon {{
    color: @panel_bg;
}}

/* Running Indicator - Small dot */
.running-indicator {{
    background: @panel_blue;
    border-radius: 50%;
    min-width: 4px;
    min-height: 4px;
    margin-top: 1px;
}}

.running-indicator.hidden {{
    opacity: 0;
}}

.taskbar-item.focused .running-indicator {{
    background: @panel_aqua;
}}

/* Separator - Subtle */
.separator {{
    background: alpha(@panel_fg, 0.15);
    min-width: 1px;
    margin: 6px 4px;
}}

/* Window List Popover */
.window-list-popover {{
    background: @panel_bg;
    border: 1px solid @panel_bg3;
    border-radius: 12px;
}}

.window-list-popover contents {{
    background: transparent;
}}

.window-list-item {{
    background: transparent;
    padding: 8px 12px;
    border-radius: 8px;
}}

.window-list-item:hover {{
    background: alpha(@panel_fg, 0.1);
}}

.window-list-item label {{
    color: @panel_fg;
}}

.window-close-btn {{
    opacity: 0.5;
}}

.window-close-btn:hover {{
    opacity: 1;
    color: @panel_red;
}}

/* Context Menu */
.context-menu {{
    background: @panel_bg;
    border: 1px solid @panel_bg3;
    border-radius: 12px;
}}

.context-menu contents {{
    background: transparent;
}}

.context-menu button {{
    background: transparent;
    color: @panel_fg;
    padding: 8px 16px;
    border-radius: 8px;
    border: none;
}}

.context-menu button:hover {{
    background: alpha(@panel_fg, 0.1);
}}

/* Tooltip */
tooltip {{
    background: @panel_bg;
    border: 1px solid @panel_bg3;
    border-radius: 12px;
}}

tooltip label {{
    color: @panel_fg;
    padding: 6px;
}}
'''
        return css
    
    def save_generated_css(self, output_path: Optional[Path] = None) -> Path:
        """Generate and save CSS file"""
        if output_path is None:
            output_path = Path.home() / ".config/hypr-control-center/assets/panel-generated.css"
        
        output_path.parent.mkdir(parents=True, exist_ok=True)
        
        css = self.generate_panel_css()
        
        with open(output_path, 'w') as f:
            f.write(css)
        
        print(f"[WaybarConfigReader] Generated CSS: {output_path}")
        return output_path


# ==========================================
# SINGLETON
# ==========================================

_reader_instance: Optional[WaybarConfigReader] = None

def get_waybar_reader() -> WaybarConfigReader:
    """Get singleton WaybarConfigReader instance"""
    global _reader_instance
    if _reader_instance is None:
        _reader_instance = WaybarConfigReader()
    return _reader_instance


# ==========================================
# TEST
# ==========================================

def demo():
    """Demo the waybar config reader"""
    print("""
╔══════════════════════════════════════════════════════════╗
║           WAYBAR CONFIG READER DEMO                      ║
╚══════════════════════════════════════════════════════════╝
""")
    
    reader = WaybarConfigReader()
    
    # Get position
    print("\n=== PANEL POSITION ===")
    position = reader.get_panel_position()
    print(f"  Location: {position.location}")
    print(f"  Index: {position.index}")
    print(f"  Modules before: {position.modules_before}")
    print(f"  Modules after: {position.modules_after}")
    print(f"  Waybar position: {position.waybar_position}")
    print(f"  Waybar height: {position.waybar_height}px")
    print(f"\n  Calculated margins:")
    print(f"    Left: {position.margin_left}px")
    print(f"    Right: {position.margin_right}px")
    print(f"    Top: {position.margin_top}px")
    print(f"    Bottom: {position.margin_bottom}px")
    
    # Get theme
    print("\n=== THEME COLORS ===")
    theme = reader.get_theme()
    print(f"  bg0: {theme.bg0}")
    print(f"  bg1: {theme.bg1}")
    print(f"  fg: {theme.fg}")
    print(f"  blue: {theme.blue}")
    print(f"  red: {theme.red}")
    print(f"  green: {theme.green}")
    print(f"  Border radius: {theme.border_radius}px")
    print(f"  Font: {theme.font_family}")
    print(f"  Font size: {theme.font_size}px")
    
    # Generate CSS
    print("\n=== GENERATING CSS ===")
    css_path = reader.save_generated_css()
    print(f"  Saved to: {css_path}")
    
    print()


if __name__ == "__main__":
    demo()