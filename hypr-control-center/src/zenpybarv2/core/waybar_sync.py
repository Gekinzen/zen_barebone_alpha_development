"""
WaybarSync - Automatic Waybar Configuration Synchronization
============================================================

Watches and syncs Waybar config.jsonc and style.css to ZenPyBar.
Maintains two-way compatibility while allowing ZenPyBar-specific overrides.

Key Features:
- Parses JSONC (JSON with comments)
- Extracts CSS color variables
- Tracks config changes via hash
- Provides merged config for ZenPyBar
"""

import json
import re
import os
from pathlib import Path
from typing import Dict, List, Optional, Any, Tuple
from dataclasses import dataclass, field
from datetime import datetime
import threading
import hashlib


@dataclass
class WaybarModuleConfig:
    """Parsed Waybar module configuration"""
    name: str
    config: Dict[str, Any] = field(default_factory=dict)
    

@dataclass
class WaybarTheme:
    """Extracted theme from Waybar CSS"""
    # Background colors
    bg0: str = "#1a1b26"
    bg1: str = "#16161e"
    bg2: str = "#24283b"
    bg3: str = "#414868"
    
    # Foreground colors
    fg: str = "#c0caf5"
    fg_dim: str = "#565f89"
    
    # Accent colors
    blue: str = "#7aa2f7"
    purple: str = "#bb9af7"
    red: str = "#f7768e"
    green: str = "#9ece6a"
    yellow: str = "#e0af68"
    orange: str = "#ff9e64"
    cyan: str = "#7dcfff"
    
    # UI colors
    border: str = "#414868"
    focused: str = "#7aa2f7"
    urgent: str = "#f7768e"
    
    # Font
    font_family: str = "JetBrainsMono Nerd Font"
    font_size: str = "12px"
    
    # Import path (if using @import)
    import_path: Optional[str] = None


@dataclass
class WaybarConfig:
    """Complete parsed Waybar configuration"""
    # Bar settings
    height: int = 40
    position: str = "bottom"
    spacing: int = 4
    margin_top: int = 4
    margin_bottom: int = 3
    margin_left: int = 4
    margin_right: int = 4
    
    # Modules
    modules_left: List[str] = field(default_factory=list)
    modules_center: List[str] = field(default_factory=list)
    modules_right: List[str] = field(default_factory=list)
    
    # Module configurations
    modules: Dict[str, WaybarModuleConfig] = field(default_factory=dict)
    
    # Theme
    theme: WaybarTheme = field(default_factory=WaybarTheme)
    
    # Raw data
    raw_config: Dict[str, Any] = field(default_factory=dict)
    raw_css: str = ""


class WaybarSync:
    """
    Syncs Waybar configuration to ZenPyBar format.
    
    Usage:
        sync = WaybarSync()
        config = sync.get_config()
        theme = sync.get_theme()
    """
    
    WAYBAR_CONFIG_PATH = Path.home() / ".config/waybar"
    COLORSCHEME_PATH = Path.home() / ".config/colorscheme"
    
    _instance = None
    _lock = threading.Lock()
    
    def __new__(cls, *args, **kwargs):
        """Singleton pattern"""
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = super().__new__(cls)
                    cls._instance._initialized = False
        return cls._instance
    
    def __init__(self, waybar_path: Optional[Path] = None):
        if self._initialized:
            return
            
        self.waybar_path = waybar_path or self.WAYBAR_CONFIG_PATH
        self._config: Optional[WaybarConfig] = None
        self._config_hash: str = ""
        self._style_hash: str = ""
        
        # Initial parse
        self._parse_all()
        
        self._initialized = True
        print(f"[WaybarSync] ✅ Initialized from {self.waybar_path}")
    
    # ═══════════════════════════════════════════════════════════════════════
    # PUBLIC API
    # ═══════════════════════════════════════════════════════════════════════
    
    def get_config(self, force_reload: bool = False) -> WaybarConfig:
        """Get current Waybar configuration"""
        if force_reload or self._has_changes():
            self._parse_all()
        return self._config
    
    def get_theme(self) -> WaybarTheme:
        """Get current theme"""
        return self._config.theme if self._config else WaybarTheme()
    
    def has_changes(self) -> bool:
        """Check if Waybar config has changed"""
        return self._has_changes()
    
    def get_module_config(self, module_name: str) -> Dict[str, Any]:
        """Get configuration for a specific module"""
        if self._config and module_name in self._config.modules:
            return self._config.modules[module_name].config
        return {}
    
    # ═══════════════════════════════════════════════════════════════════════
    # JSONC PARSING
    # ═══════════════════════════════════════════════════════════════════════
    
    def _strip_jsonc_comments(self, content: str) -> str:
        """Remove JSONC-style comments from JSON content"""
        # Remove single-line comments
        content = re.sub(r'//.*$', '', content, flags=re.MULTILINE)
        
        # Remove multi-line comments
        content = re.sub(r'/\*[\s\S]*?\*/', '', content)
        
        # Remove trailing commas before } or ]
        content = re.sub(r',(\s*[}\]])', r'\1', content)
        
        return content
    
    def _parse_config_file(self) -> Dict[str, Any]:
        """Parse Waybar config.jsonc file"""
        config_path = self.waybar_path / "config.jsonc"
        if not config_path.exists():
            config_path = self.waybar_path / "config.json"
        
        if not config_path.exists():
            print(f"[WaybarSync] ⚠️ No config file found at {self.waybar_path}")
            return {}
        
        try:
            content = config_path.read_text()
            self._config_hash = hashlib.md5(content.encode()).hexdigest()
            
            # Strip comments
            clean_json = self._strip_jsonc_comments(content)
            
            # Handle potential array config (Waybar supports multiple bars)
            data = json.loads(clean_json)
            
            # If array, use first config
            if isinstance(data, list):
                data = data[0] if data else {}
            
            return data
            
        except json.JSONDecodeError as e:
            print(f"[WaybarSync] ❌ JSON parse error: {e}")
            return {}
        except Exception as e:
            print(f"[WaybarSync] ❌ Config read error: {e}")
            return {}
    
    # ═══════════════════════════════════════════════════════════════════════
    # CSS THEME PARSING
    # ═══════════════════════════════════════════════════════════════════════
    
    def _parse_style_file(self) -> Tuple[str, WaybarTheme]:
        """Parse Waybar style.css and extract theme colors"""
        style_path = self.waybar_path / "style.css"
        if not style_path.exists():
            return "", WaybarTheme()
        
        try:
            content = style_path.read_text()
            self._style_hash = hashlib.md5(content.encode()).hexdigest()
            
            theme = WaybarTheme()
            
            # Check for @import
            import_match = re.search(r'@import\s+["\']([^"\']+)["\']', content)
            if import_match:
                import_path = import_match.group(1)
                theme.import_path = import_path
                
                # Resolve import path
                if import_path.startswith('../'):
                    # Relative path (e.g., ../colorscheme/one-dark.css)
                    full_import_path = (self.waybar_path / import_path).resolve()
                elif import_path.startswith('~'):
                    full_import_path = Path(import_path.replace('~', str(Path.home())))
                else:
                    full_import_path = Path(import_path)
                
                if full_import_path.exists():
                    print(f"[WaybarSync] 🎨 Loading colorscheme: {full_import_path}")
                    content = full_import_path.read_text() + "\n" + content
            
            # Parse @define-color directives
            color_pattern = r'@define-color\s+(\w+)\s+([^;]+);'
            for match in re.finditer(color_pattern, content):
                var_name = match.group(1).strip()
                color_value = match.group(2).strip()
                
                # Map to theme attributes
                color_mapping = {
                    'bg0': 'bg0', 'bg': 'bg0', 'background': 'bg0',
                    'bg1': 'bg1', 'bg-dark': 'bg1',
                    'bg2': 'bg2', 'bg-light': 'bg2',
                    'bg3': 'bg3',
                    'fg': 'fg', 'foreground': 'fg', 'text': 'fg',
                    'fg-dim': 'fg_dim', 'comment': 'fg_dim',
                    'blue': 'blue', 'accent': 'blue',
                    'purple': 'purple', 'magenta': 'purple',
                    'red': 'red', 'error': 'red',
                    'green': 'green', 'success': 'green',
                    'yellow': 'yellow', 'warning': 'yellow',
                    'orange': 'orange',
                    'cyan': 'cyan', 'aqua': 'cyan',
                    'border': 'border',
                    'focused': 'focused', 'active': 'focused',
                    'urgent': 'urgent',
                }
                
                if var_name in color_mapping:
                    attr_name = color_mapping[var_name]
                    setattr(theme, attr_name, color_value)
            
            # Parse font-family
            font_match = re.search(r'font-family:\s*([^;]+);', content)
            if font_match:
                theme.font_family = font_match.group(1).strip().strip('"\'')
            
            # Parse font-size
            size_match = re.search(r'font-size:\s*([^;]+);', content)
            if size_match:
                theme.font_size = size_match.group(1).strip()
            
            return content, theme
            
        except Exception as e:
            print(f"[WaybarSync] ❌ Style parse error: {e}")
            return "", WaybarTheme()
    
    # ═══════════════════════════════════════════════════════════════════════
    # FULL PARSE
    # ═══════════════════════════════════════════════════════════════════════
    
    def _parse_all(self) -> None:
        """Parse all Waybar configuration"""
        raw_config = self._parse_config_file()
        raw_css, theme = self._parse_style_file()
        
        # Build WaybarConfig
        config = WaybarConfig(
            height=raw_config.get('height', 40),
            position=raw_config.get('position', 'bottom'),
            spacing=raw_config.get('spacing', 4),
            margin_top=raw_config.get('margin-top', 4),
            margin_bottom=raw_config.get('margin-bottom', 3),
            margin_left=raw_config.get('margin-left', 4),
            margin_right=raw_config.get('margin-right', 4),
            modules_left=raw_config.get('modules-left', []),
            modules_center=raw_config.get('modules-center', []),
            modules_right=raw_config.get('modules-right', []),
            theme=theme,
            raw_config=raw_config,
            raw_css=raw_css,
        )
        
        # Parse individual module configs
        for key, value in raw_config.items():
            if isinstance(value, dict) and key not in [
                'modules-left', 'modules-center', 'modules-right'
            ]:
                config.modules[key] = WaybarModuleConfig(
                    name=key,
                    config=value
                )
        
        self._config = config
        
        print(f"[WaybarSync] 📋 Parsed config:")
        print(f"   Height: {config.height}, Position: {config.position}")
        print(f"   Left: {config.modules_left}")
        print(f"   Center: {config.modules_center}")
        print(f"   Right: {config.modules_right}")
        print(f"   Theme: {theme.import_path or 'inline'}")
    
    def _has_changes(self) -> bool:
        """Check if config or style files have changed"""
        # Check config hash
        config_path = self.waybar_path / "config.jsonc"
        if not config_path.exists():
            config_path = self.waybar_path / "config.json"
        
        if config_path.exists():
            try:
                content = config_path.read_text()
                new_hash = hashlib.md5(content.encode()).hexdigest()
                if new_hash != self._config_hash:
                    return True
            except Exception:
                pass
        
        # Check style hash
        style_path = self.waybar_path / "style.css"
        if style_path.exists():
            try:
                content = style_path.read_text()
                new_hash = hashlib.md5(content.encode()).hexdigest()
                if new_hash != self._style_hash:
                    return True
            except Exception:
                pass
        
        return False
    
    # ═══════════════════════════════════════════════════════════════════════
    # EXPORT FOR ZENPYBAR
    # ═══════════════════════════════════════════════════════════════════════
    
    def export_zenpybar_config(self, output_path: Path) -> bool:
        """Export parsed config to ZenPyBar JSON format"""
        if not self._config:
            return False
        
        try:
            data = {
                'synced_from': 'waybar',
                'synced_at': datetime.now().isoformat(),
                'config_hash': self._config_hash,
                'style_hash': self._style_hash,
                'bar': {
                    'height': self._config.height,
                    'position': self._config.position,
                    'spacing': self._config.spacing,
                    'margin_top': self._config.margin_top,
                    'margin_bottom': self._config.margin_bottom,
                    'margin_left': self._config.margin_left,
                    'margin_right': self._config.margin_right,
                    'modules_left': self._config.modules_left,
                    'modules_center': self._config.modules_center,
                    'modules_right': self._config.modules_right,
                },
                'theme': {
                    'bg0': self._config.theme.bg0,
                    'bg1': self._config.theme.bg1,
                    'bg2': self._config.theme.bg2,
                    'bg3': self._config.theme.bg3,
                    'fg': self._config.theme.fg,
                    'fg_dim': self._config.theme.fg_dim,
                    'blue': self._config.theme.blue,
                    'purple': self._config.theme.purple,
                    'red': self._config.theme.red,
                    'green': self._config.theme.green,
                    'yellow': self._config.theme.yellow,
                    'orange': self._config.theme.orange,
                    'cyan': self._config.theme.cyan,
                    'border': self._config.theme.border,
                    'focused': self._config.theme.focused,
                    'urgent': self._config.theme.urgent,
                    'font_family': self._config.theme.font_family,
                    'font_size': self._config.theme.font_size,
                    'import_path': self._config.theme.import_path,
                },
                'modules': {
                    name: mod.config 
                    for name, mod in self._config.modules.items()
                },
            }
            
            output_path.parent.mkdir(parents=True, exist_ok=True)
            with open(output_path, 'w') as f:
                json.dump(data, f, indent=2)
            
            print(f"[WaybarSync] 💾 Exported to {output_path}")
            return True
            
        except Exception as e:
            print(f"[WaybarSync] ❌ Export error: {e}")
            return False
    
    def generate_css(self) -> str:
        """Generate CSS string from theme"""
        if not self._config:
            return ""
        
        t = self._config.theme
        
        css = f"""
/* ZenPyBar - Auto-generated from Waybar theme */
/* Generated: {datetime.now().isoformat()} */

* {{
    font-family: "{t.font_family}";
    font-size: {t.font_size};
}}

window {{
    background-color: transparent;
}}

.bar-container {{
    background-color: {t.bg0};
    border-radius: 12px;
    padding: 4px 8px;
}}

.module {{
    padding: 4px 8px;
    margin: 2px 4px;
    border-radius: 8px;
    color: {t.fg};
}}

.workspace-btn {{
    min-width: 28px;
    min-height: 28px;
    padding: 4px;
    margin: 2px;
    border-radius: 8px;
    background-color: {t.bg2};
    color: {t.fg};
    border: 1px solid transparent;
}}

.workspace-btn:hover {{
    background-color: {t.bg3};
}}

.workspace-btn.active {{
    background-color: {t.blue};
    color: {t.bg0};
}}

.workspace-btn.occupied {{
    border-color: {t.fg_dim};
}}

.taskbar-item {{
    min-width: 36px;
    min-height: 36px;
    padding: 4px;
    margin: 2px;
    border-radius: 8px;
    background-color: transparent;
    border: none;
}}

.taskbar-item:hover {{
    background-color: {t.bg2};
}}

.taskbar-item.running {{
    border-bottom: 2px solid {t.fg_dim};
}}

.taskbar-item.focused {{
    background-color: {t.bg2};
    border-bottom: 2px solid {t.blue};
}}

.taskbar-item.pinned {{
    opacity: 0.7;
}}

.taskbar-item.pinned:hover {{
    opacity: 1.0;
}}

.clock {{
    color: {t.fg};
    font-weight: 500;
}}

.music-label {{
    color: {t.purple};
}}

.notification-btn {{
    color: {t.yellow};
}}
"""
        return css


def get_waybar_sync() -> WaybarSync:
    """Get singleton WaybarSync instance"""
    return WaybarSync()


# ═══════════════════════════════════════════════════════════════════════════════
# TESTING
# ═══════════════════════════════════════════════════════════════════════════════

if __name__ == "__main__":
    sync = get_waybar_sync()
    
    config = sync.get_config()
    
    print(f"\n📋 Waybar Configuration:")
    print(f"   Height: {config.height}")
    print(f"   Position: {config.position}")
    print(f"   Modules Left: {config.modules_left}")
    print(f"   Modules Center: {config.modules_center}")
    print(f"   Modules Right: {config.modules_right}")
    
    print(f"\n🎨 Theme:")
    print(f"   Background: {config.theme.bg0}")
    print(f"   Foreground: {config.theme.fg}")
    print(f"   Accent: {config.theme.blue}")
    print(f"   Font: {config.theme.font_family}")
    print(f"   Import: {config.theme.import_path}")
    
    # Test export
    export_path = Path("/tmp/zenpybar_test.json")
    sync.export_zenpybar_config(export_path)
    
    # Print generated CSS
    print("\n📄 Generated CSS Preview:")
    print(sync.generate_css()[:500] + "...")