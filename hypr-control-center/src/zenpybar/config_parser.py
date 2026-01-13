#!/usr/bin/env python3
"""
ZenPyBar Config Parser
======================

Parses Waybar config.jsonc and style.css to configure the bar.

Reads from:
- ~/.config/waybar/config.jsonc
- ~/.config/waybar/style.css
"""

import json
import re
from pathlib import Path
from typing import Dict, List, Any, Optional
from dataclasses import dataclass, field


@dataclass
class ModuleConfig:
    """Configuration for a single module"""
    name: str
    type: str  # 'builtin' or 'custom'
    config: Dict[str, Any] = field(default_factory=dict)


@dataclass
class BarConfig:
    """Full bar configuration"""
    # Bar settings
    height: int = 40
    position: str = "bottom"  # top, bottom
    layer: str = "top"
    
    # Margins
    margin_top: int = 0
    margin_bottom: int = 3
    margin_left: int = 0
    margin_right: int = 0
    
    # Modules
    modules_left: List[str] = field(default_factory=list)
    modules_center: List[str] = field(default_factory=list)
    modules_right: List[str] = field(default_factory=list)
    
    # Module configs
    module_configs: Dict[str, ModuleConfig] = field(default_factory=dict)


@dataclass
class ThemeColors:
    """Theme colors extracted from CSS"""
    # Base colors
    bg0: str = "#1a1b26"
    bg1: str = "#16161e"
    bg2: str = "#2f3549"
    bg3: str = "#444b6a"
    fg: str = "#c0caf5"
    
    # Accent colors
    red: str = "#f7768e"
    orange: str = "#ff9e64"
    yellow: str = "#e0af68"
    green: str = "#9ece6a"
    aqua: str = "#73daca"
    blue: str = "#7aa2f7"
    purple: str = "#bb9af7"
    
    # Greys
    grey0: str = "#565f89"
    grey1: str = "#6b7089"
    
    # Styling
    border_radius: int = 45
    font_family: str = "JetBrainsMono Nerd Font Propo"
    font_size: int = 14
    
    # Bar specific
    bar_background: str = "alpha(@bg0, 0.67)"
    bar_border: str = "1px solid @bg1"


class ConfigParser:
    """
    Parses Waybar configuration files
    
    Usage:
        parser = ConfigParser()
        bar_config = parser.get_bar_config()
        theme = parser.get_theme()
    """
    
    def __init__(self, waybar_dir: Optional[Path] = None):
        self.waybar_dir = waybar_dir or Path.home() / ".config/waybar"
        self.config_file = self._find_config_file()
        self.style_file = self.waybar_dir / "style.css"
        
        self._raw_config: Dict = {}
        self._bar_config: Optional[BarConfig] = None
        self._theme: Optional[ThemeColors] = None
        
        self._load_config()
        
        print(f"[ConfigParser] Config: {self.config_file}")
        print(f"[ConfigParser] Style: {self.style_file}")
    
    def _find_config_file(self) -> Path:
        """Find Waybar config file"""
        candidates = [
            self.waybar_dir / "config.jsonc",
            self.waybar_dir / "config.json",
            self.waybar_dir / "config",
        ]
        
        for candidate in candidates:
            if candidate.exists():
                return candidate
        
        return self.waybar_dir / "config.jsonc"
    
    def _load_config(self):
        """Load and parse config file"""
        if not self.config_file.exists():
            print(f"[ConfigParser] Config not found: {self.config_file}")
            return
        
        try:
            with open(self.config_file, 'r') as f:
                content = f.read()
            
            # Remove JSONC comments
            content = re.sub(r'//.*?$', '', content, flags=re.MULTILINE)
            content = re.sub(r'/\*.*?\*/', '', content, flags=re.DOTALL)
            
            # Remove trailing commas
            content = re.sub(r',\s*([}\]])', r'\1', content)
            
            self._raw_config = json.loads(content)
            print(f"[ConfigParser] ✅ Loaded config")
            
        except Exception as e:
            print(f"[ConfigParser] ❌ Error loading config: {e}")
            self._raw_config = {}
    
    def get_bar_config(self) -> BarConfig:
        """Get bar configuration"""
        if self._bar_config:
            return self._bar_config
        
        config = BarConfig()
        
        # Bar settings
        config.height = self._raw_config.get('height', 40)
        config.position = self._raw_config.get('position', 'bottom')
        config.layer = self._raw_config.get('layer', 'top')
        
        # Margins
        config.margin_top = self._raw_config.get('margin-top', 0)
        config.margin_bottom = self._raw_config.get('margin-bottom', 3)
        config.margin_left = self._raw_config.get('margin-left', 0)
        config.margin_right = self._raw_config.get('margin-right', 0)
        
        # Modules
        config.modules_left = self._raw_config.get('modules-left', [])
        config.modules_center = self._raw_config.get('modules-center', [])
        config.modules_right = self._raw_config.get('modules-right', [])
        
        # Parse module configs
        all_modules = config.modules_left + config.modules_center + config.modules_right
        for module_name in all_modules:
            module_config = self._parse_module_config(module_name)
            config.module_configs[module_name] = module_config
        
        self._bar_config = config
        return config
    
    def _parse_module_config(self, module_name: str) -> ModuleConfig:
        """Parse config for a specific module"""
        # Determine module type
        if module_name.startswith('custom/'):
            module_type = 'custom'
        elif module_name.startswith('group/'):
            module_type = 'group'
        elif '/' in module_name:
            module_type = 'builtin'
        else:
            module_type = 'builtin'
        
        # Get module-specific config
        config_dict = self._raw_config.get(module_name, {})
        
        return ModuleConfig(
            name=module_name,
            type=module_type,
            config=config_dict
        )
    
    def get_module_config(self, module_name: str) -> Dict[str, Any]:
        """Get config for specific module"""
        return self._raw_config.get(module_name, {})
    
    def get_theme(self) -> ThemeColors:
        """Extract theme colors from CSS"""
        if self._theme:
            return self._theme
        
        theme = ThemeColors()
        
        if not self.style_file.exists():
            print(f"[ConfigParser] Style not found, using defaults")
            return theme
        
        try:
            with open(self.style_file, 'r') as f:
                css_content = f.read()
            
            # Resolve imports
            css_content = self._resolve_imports(css_content)
            
            # Parse @define-color
            color_pattern = r'@define-color\s+(\w+)\s+([^;]+);'
            for match in re.finditer(color_pattern, css_content):
                name = match.group(1)
                value = match.group(2).strip()
                
                if hasattr(theme, name):
                    setattr(theme, name, value)
            
            # Parse window#waybar for bar background
            waybar_style = self._extract_selector_style(css_content, 'window#waybar')
            if waybar_style:
                if 'background' in waybar_style:
                    theme.bar_background = waybar_style['background']
                if 'border-radius' in waybar_style:
                    radius = re.search(r'(\d+)', waybar_style['border-radius'])
                    if radius:
                        theme.border_radius = int(radius.group(1))
            
            # Parse font from * selector
            star_style = self._extract_selector_style(css_content, '*')
            if star_style:
                if 'font-family' in star_style:
                    # Extract first font
                    fonts = star_style['font-family'].split(',')
                    theme.font_family = fonts[0].strip().strip('"\'')
                if 'font-size' in star_style:
                    size = re.search(r'(\d+)', star_style['font-size'])
                    if size:
                        theme.font_size = int(size.group(1))
            
            print(f"[ConfigParser] ✅ Theme loaded: bg0={theme.bg0}, blue={theme.blue}")
            
        except Exception as e:
            print(f"[ConfigParser] ❌ Error loading theme: {e}")
        
        self._theme = theme
        return theme
    
    def _resolve_imports(self, css_content: str) -> str:
        """Resolve @import statements and REMOVE them from output"""
        import_pattern = r"@import\s+['\"]?([^'\";\s]+)['\"]?\s*;"
        
        resolved_content = ""
        
        for match in re.finditer(import_pattern, css_content):
            import_path = match.group(1)
            
            if import_path.startswith('../') or import_path.startswith('./'):
                full_path = (self.style_file.parent / import_path).resolve()
            else:
                full_path = self.waybar_dir / import_path
            
            if full_path.exists():
                try:
                    with open(full_path, 'r') as f:
                        imported = f.read()
                    resolved_content = imported + "\n" + resolved_content
                    print(f"[ConfigParser] Imported: {full_path.name}")
                except:
                    pass
        
        # CRITICAL: Remove all @import lines from original CSS
        css_without_imports = re.sub(import_pattern, '', css_content)
        
        return resolved_content + css_without_imports
    
    def _extract_selector_style(self, css: str, selector: str) -> Optional[Dict[str, str]]:
        """Extract styles for a CSS selector"""
        pattern = rf'{re.escape(selector)}\s*\{{([^}}]+)\}}'
        match = re.search(pattern, css)
        
        if not match:
            return None
        
        block = match.group(1)
        styles = {}
        
        prop_pattern = r'([\w-]+)\s*:\s*([^;]+);'
        for prop_match in re.finditer(prop_pattern, block):
            prop = prop_match.group(1).strip()
            value = prop_match.group(2).strip()
            styles[prop] = value
        
        return styles
    
    def generate_gtk_css(self) -> str:
        """
        Generate GTK CSS by EXACT conversion of Waybar CSS
        
        Strategy: Read style.css, resolve imports, then do simple selector replacement
        Keep ALL properties exactly as-is
        """
        if not self.style_file.exists():
            print(f"[ConfigParser] Style not found, using fallback")
            return self._generate_fallback_css()
        
        try:
            with open(self.style_file, 'r') as f:
                css_content = f.read()
            
            # Resolve @import first (get colorscheme)
            css_content = self._resolve_imports(css_content)
            
            # Simple selector replacements - keep everything else EXACTLY as-is
            replacements = [
                # Window
                ('window#waybar', '.zenpy-bar'),
                
                # Workspaces - be careful with order (more specific first)
                ('#workspaces button.active', '.workspace-button.active'),
                ('#workspaces button.urgent', '.workspace-button.urgent'),
                ('#workspaces button:hover', '.workspace-button:hover'),
                ('#workspaces button', '.workspace-button'),
                ('#workspaces', '.workspaces'),
                
                # Taskbar - more specific first
                ('#taskbar button.pinned.active', '.taskbar-item.pinned.active'),
                ('#taskbar button.pinned.running', '.taskbar-item.pinned.running'),
                ('#taskbar button.pinned', '.taskbar-item.pinned'),
                ('#taskbar button.running', '.taskbar-item.running'),
                ('#taskbar button.active', '.taskbar-item.active'),
                ('#taskbar button.urgent', '.taskbar-item.urgent'),
                ('#taskbar button:hover', '.taskbar-item:hover'),
                ('#taskbar button image', '.taskbar-item image'),
                ('#taskbar button label', '.taskbar-item label'),
                ('#taskbar button', '.taskbar-item'),
                ('#taskbar', '.taskbar'),
                
                # Custom modules
                ('#custom-taskbar', '.custom-taskbar'),
                ('#custom-pinned', '.custom-pinned'),
                ('#custom-music', '.custom-music'),
                ('#custom-notification', '.custom-notification'),
                ('#custom-pacman', '.custom-pacman'),
                ('#custom-expand', '.custom-expand'),
                ('#custom-endpoint', '.custom-endpoint'),
                
                # Standard modules
                ('#clock', '.clock'),
                ('#battery', '.battery'),
                ('#pulseaudio', '.pulseaudio'),
                ('#cpu', '.cpu'),
                ('#memory', '.memory'),
                ('#temperature', '.temperature'),
                ('#network', '.network'),
                ('#bluetooth', '.bluetooth'),
                ('#tray', '.tray'),
                ('#window', '.window-title'),
                
                # Groups
                ('#group-expand', '.group-expand'),
            ]
            
            gtk_css = css_content
            for waybar_sel, gtk_sel in replacements:
                gtk_css = gtk_css.replace(waybar_sel, gtk_sel)
            
            # Add ZenPyBar-specific additions at the end
            gtk_css += self._get_zenpybar_additions()
            
            print(f"[ConfigParser] ✅ Converted Waybar CSS ({len(gtk_css)} chars)")
            return gtk_css
            
        except Exception as e:
            print(f"[ConfigParser] ❌ Error converting CSS: {e}")
            import traceback
            traceback.print_exc()
            return self._generate_fallback_css()
    
    def _get_zenpybar_additions(self) -> str:
        """Additional CSS rules specific to ZenPyBar/GTK4"""
        return '''

/* ================================================
   ZENPYBAR GTK4 ADDITIONS
   ================================================ */

/* CRITICAL: Window background - use solid color for testing */
window {
    background-color: #1a1b26;
}

/* Force bar to fill width */
.zenpy-bar {
    background-color: #1a1b26;
    min-width: 100%;
    min-height: 40px;
}

/* Make all labels visible */
label {
    color: #c0caf5;
}

/* Ensure proper box sizing */
.zenpy-bar * {
    -gtk-icon-style: symbolic;
}

/* Module containers alignment */
.modules-left {
    padding-left: 0;
}

.modules-center {
    padding: 0;
}

.modules-right {
    padding-right: 0;
}

/* Workspace button sizing */
.workspace-button {
    background-color: #16161e;
    min-width: 30px;
    min-height: 30px;
}

.workspace-button.active {
    background-color: #7aa2f7;
}

/* Taskbar item sizing for icons */
.taskbar-item {
    min-width: 40px;
    min-height: 40px;
}

.taskbar-item image {
    -gtk-icon-size: 24px;
}

/* Taskbar separator */
.taskbar > separator {
    background-color: #565f89;
    min-width: 1px;
    margin: 8px 6px;
}

/* Clock styling */
.clock {
    background-color: #1a1b26;
    color: #7aa2f7;
    padding: 0 15px;
    border-radius: 45px;
}

/* Popover theming - matches tooltip */
popover, popover > contents {
    background-color: #1a1b26;
    border: 1px solid #414868;
    border-radius: 12px;
}

popover arrow {
    background-color: #1a1b26;
    border-color: #414868;
}

popover button {
    background: transparent;
    border: none;
    border-radius: 8px;
    padding: 8px 16px;
    color: #c0caf5;
}

popover button:hover {
    background-color: #24283b;
}

/* Window list items */
.window-list-item {
    padding: 8px 12px;
    border-radius: 8px;
    background: transparent;
}

.window-list-item:hover {
    background-color: #24283b;
}

.window-list-item label {
    color: #c0caf5;
}

/* Context menu */
.context-menu button {
    padding: 8px 16px;
    border-radius: 8px;
}

.context-menu button:hover {
    background-color: #24283b;
}
'''
    
    def _generate_fallback_css(self) -> str:
        """Fallback CSS if Waybar style not found"""
        theme = self.get_theme()
        
        return f'''
/* ZenPyBar Fallback CSS */
@define-color bg0 {theme.bg0};
@define-color bg1 {theme.bg1};
@define-color bg2 {theme.bg2};
@define-color bg3 {theme.bg3};
@define-color fg {theme.fg};
@define-color blue {theme.blue};
@define-color red {theme.red};
@define-color green {theme.green};
@define-color yellow {theme.yellow};
@define-color purple {theme.purple};
@define-color orange {theme.orange};

* {{
    font-family: "{theme.font_family}", sans-serif;
    font-size: {theme.font_size}px;
}}

.zenpy-bar {{
    background: alpha(@bg0, 0.67);
    min-height: 40px;
}}

.workspaces {{
    background: alpha(@bg0, 0.21);
    padding: 5px 3px;
    margin: 0 0 0 12px;
    border-radius: 26px;
    border: 1px solid @bg1;
}}

.workspace-button {{
    padding: 0 6px;
    margin: 0 3px;
    border-radius: 16px;
    background: @bg1;
    color: transparent;
    min-width: 30px;
    min-height: 30px;
}}

.workspace-button.active {{
    background: @blue;
    color: @bg0;
    min-width: 50px;
}}

.taskbar {{
    background: alpha(@bg0, 0.9);
    padding: 5px 14px;
    margin: 0 0 0 12px;
    border-radius: 45px;
    border: 1px solid @bg1;
}}

.taskbar-item {{
    padding: 4px 8px;
    margin: 0 4px;
    border-radius: 14px;
    background: @bg1;
}}

.taskbar-item.active {{
    background: @blue;
    color: @bg0;
}}

.taskbar-item.running {{
    background: @bg2;
    border-bottom: 2px solid @blue;
}}

.clock {{
    background: alpha(@bg0, 0.9);
    padding: 0 15px;
    margin: 0 0 0 12px;
    border-radius: 45px;
    border: 1px solid @bg1;
    color: @blue;
}}

tooltip {{
    background: @bg0;
    border: 1px solid @bg3;
    border-radius: 12px;
}}

tooltip label {{
    color: @fg;
    padding: 6px;
}}
'''


# Singleton
_parser_instance: Optional[ConfigParser] = None

def get_config_parser() -> ConfigParser:
    """Get singleton ConfigParser"""
    global _parser_instance
    if _parser_instance is None:
        _parser_instance = ConfigParser()
    return _parser_instance


if __name__ == "__main__":
    # Test
    parser = ConfigParser()
    
    print("\n=== BAR CONFIG ===")
    config = parser.get_bar_config()
    print(f"  Position: {config.position}")
    print(f"  Height: {config.height}px")
    print(f"  Modules Left: {config.modules_left}")
    print(f"  Modules Center: {config.modules_center}")
    print(f"  Modules Right: {config.modules_right}")
    
    print("\n=== THEME ===")
    theme = parser.get_theme()
    print(f"  bg0: {theme.bg0}")
    print(f"  blue: {theme.blue}")
    print(f"  Font: {theme.font_family}")