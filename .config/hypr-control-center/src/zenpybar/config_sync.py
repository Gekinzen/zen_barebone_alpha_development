#!/usr/bin/env python3
"""
ZenPyBar Config Sync v2.0
=========================

Enhanced version that properly handles hyprland/taskbar module.

Usage:
    python3 config_sync.py          # One-time sync
    python3 config_sync.py --watch  # Watch for changes
"""

import json
import re
import os
import sys
import subprocess
from pathlib import Path
from typing import Dict, Any, Optional
from dataclasses import dataclass, asdict
import hashlib


# ═══════════════════════════════════════════════════════════════════════════════
# PATHS
# ═══════════════════════════════════════════════════════════════════════════════

WAYBAR_DIR = Path.home() / ".config/waybar"
COLORSCHEME_DIR = Path.home() / ".config/colorscheme"
ZENPYBAR_PREFS = Path.home() / ".config/hypr-control-center/preferences/zenpybar.json"


# ═══════════════════════════════════════════════════════════════════════════════
# PARSERS
# ═══════════════════════════════════════════════════════════════════════════════

def parse_jsonc(content: str) -> dict:
    """Parse JSONC (JSON with comments) to dict"""
    # Remove // comments
    content = re.sub(r'//.*?$', '', content, flags=re.MULTILINE)
    # Remove /* */ comments
    content = re.sub(r'/\*.*?\*/', '', content, flags=re.DOTALL)
    # Remove trailing commas
    content = re.sub(r',\s*([}\]])', r'\1', content)
    
    try:
        return json.loads(content)
    except json.JSONDecodeError as e:
        print(f"[ConfigSync] ❌ JSON parse error: {e}")
        return {}


def parse_css_colors(css_content: str) -> Dict[str, str]:
    """Extract @define-color from CSS and convert to hex"""
    colors = {}
    
    # Find all @define-color statements
    pattern = r"@define-color\s+(\w+)\s+([^;]+);"
    for match in re.finditer(pattern, css_content):
        name = match.group(1)
        value = match.group(2).strip()
        
        # Convert to hex if needed
        hex_color = css_color_to_hex(value)
        if hex_color:
            colors[name] = hex_color
    
    return colors


def css_color_to_hex(value: str) -> Optional[str]:
    """Convert CSS color to hex"""
    value = value.strip()
    
    # Already hex
    if value.startswith('#'):
        return value
    
    # rgb(r, g, b) or rgba(r, g, b, a)
    rgb_match = re.match(r'rgba?\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)', value)
    if rgb_match:
        r, g, b = int(rgb_match.group(1)), int(rgb_match.group(2)), int(rgb_match.group(3))
        return f"#{r:02x}{g:02x}{b:02x}"
    
    # CSS color names (basic)
    css_colors = {
        'white': '#ffffff',
        'black': '#000000',
        'red': '#ff0000',
        'green': '#00ff00',
        'blue': '#0000ff',
        'transparent': '#00000000',
    }
    if value.lower() in css_colors:
        return css_colors[value.lower()]
    
    return value


def resolve_css_imports(css_path: Path) -> str:
    """Read CSS file and resolve @import statements"""
    if not css_path.exists():
        return ""
    
    content = css_path.read_text()
    resolved = ""
    
    # Find and resolve @import statements
    import_pattern = r"@import\s+['\"]([^'\"]+)['\"];"
    for match in re.finditer(import_pattern, content):
        import_path = match.group(1)
        
        # Resolve relative path
        if import_path.startswith('../colorscheme/'):
            full_path = COLORSCHEME_DIR / import_path.replace('../colorscheme/', '')
        elif import_path.startswith('colors/'):
            full_path = WAYBAR_DIR / import_path
        else:
            full_path = css_path.parent / import_path
        
        if full_path.exists():
            resolved += full_path.read_text() + "\n"
            print(f"[ConfigSync] Imported: {full_path.name}")
    
    return resolved + content


def clean_module_config(name: str, config: dict) -> dict:
    """Clean module config for Python use"""
    clean = {}
    
    for key, value in config.items():
        # Convert format strings
        if key == 'format':
            clean['format'] = str(value)
        elif key == 'format-icons':
            if isinstance(value, dict):
                clean['format_icons'] = {k: str(v) for k, v in value.items()}
            elif isinstance(value, list):
                clean['format_icons'] = [str(v) for v in value]
        elif key == 'tooltip-format':
            clean['tooltip_format'] = str(value)
        elif key == 'persistent-workspaces':
            clean['persistent_workspaces'] = value
        else:
            # Convert kebab-case to snake_case
            snake_key = key.replace('-', '_')
            clean[snake_key] = value
    
    return clean


# ═══════════════════════════════════════════════════════════════════════════════
# MAIN SYNC
# ═══════════════════════════════════════════════════════════════════════════════

@dataclass
class ZenPyBarConfig:
    """Clean ZenPyBar configuration"""
    # Version
    version: str = "2.0"
    source_hash: str = ""
    
    # Bar settings
    height: int = 40
    position: str = "bottom"
    layer: str = "top"
    margin_top: int = 4
    margin_bottom: int = 3
    margin_left: int = 0
    margin_right: int = 0
    
    # Modules
    modules_left: list = None
    modules_center: list = None
    modules_right: list = None
    
    # Module configs
    module_configs: dict = None
    
    # Theme colors (all hex)
    theme: dict = None
    
    def __post_init__(self):
        if self.modules_left is None:
            self.modules_left = []
        if self.modules_center is None:
            self.modules_center = []
        if self.modules_right is None:
            self.modules_right = []
        if self.module_configs is None:
            self.module_configs = {}
        if self.theme is None:
            self.theme = {}


def map_module_name(module_name: str) -> str:
    """Map Waybar module names to ZenPyBar equivalents"""
    # Mappings for compatibility
    mappings = {
        'custom/panel': 'hyprland/taskbar',  # Our custom taskbar
        # Add more mappings if needed
    }
    
    return mappings.get(module_name, module_name)


def expand_group_modules(modules: list, raw_config: dict) -> list:
    """Expand group/* modules to their child modules"""
    expanded = []
    
    for mod in modules:
        if mod.startswith('group/'):
            # This is a group - get its children
            if mod in raw_config:
                group_config = raw_config[mod]
                
                # Get modules from the group
                if 'modules' in group_config:
                    children = group_config['modules']
                    print(f"[ConfigSync] Expanding group '{mod}' → {children}")
                    # Map child module names too
                    mapped_children = [map_module_name(c) for c in children]
                    expanded.extend(mapped_children)
                else:
                    print(f"[ConfigSync] ⚠️ Group '{mod}' has no modules list")
                    expanded.append(map_module_name(mod))
            else:
                print(f"[ConfigSync] ⚠️ No config found for group '{mod}'")
                expanded.append(map_module_name(mod))
        else:
            # Map individual module names
            expanded.append(map_module_name(mod))
    
    return expanded


def sync_config() -> ZenPyBarConfig:
    """Sync Waybar config to ZenPyBar preferences"""
    print("[ConfigSync] Starting sync...")
    
    config = ZenPyBarConfig()
    
    # 1. Load Waybar config.jsonc
    config_path = WAYBAR_DIR / "config.jsonc"
    if not config_path.exists():
        config_path = WAYBAR_DIR / "config.json"
    
    if config_path.exists():
        raw_config = parse_jsonc(config_path.read_text())
        print(f"[ConfigSync] ✅ Loaded: {config_path.name}")
        
        # Bar settings
        config.height = raw_config.get('height', 40)
        config.position = raw_config.get('position', 'bottom')
        config.layer = raw_config.get('layer', 'top')
        config.margin_top = raw_config.get('margin-top', 4)
        config.margin_bottom = raw_config.get('margin-bottom', 3)
        config.margin_left = raw_config.get('margin-left', 0)
        config.margin_right = raw_config.get('margin-right', 0)
        
        # Get raw modules
        raw_left = raw_config.get('modules-left', [])
        raw_center = raw_config.get('modules-center', [])
        raw_right = raw_config.get('modules-right', [])
        
        print(f"\n[ConfigSync] Raw modules:")
        print(f"   Left:   {raw_left}")
        print(f"   Center: {raw_center}")
        print(f"   Right:  {raw_right}")
        
        # Expand group modules
        config.modules_left = expand_group_modules(raw_left, raw_config)
        config.modules_center = expand_group_modules(raw_center, raw_config)
        config.modules_right = expand_group_modules(raw_right, raw_config)
        
        print(f"\n[ConfigSync] Expanded modules:")
        print(f"   Left:   {config.modules_left}")
        print(f"   Center: {config.modules_center}")
        print(f"   Right:  {config.modules_right}")
        
        # Module configs - get ALL possible modules including from groups
        all_modules = config.modules_left + config.modules_center + config.modules_right
        
        # Also check for any group configs
        for mod in raw_left + raw_center + raw_right:
            if mod.startswith('group/') and mod in raw_config:
                # Store group config too (for reference)
                config.module_configs[mod] = clean_module_config(mod, raw_config[mod])
        
        # Get individual module configs
        for module_name in all_modules:
            if module_name in raw_config:
                config.module_configs[module_name] = clean_module_config(
                    module_name, raw_config[module_name]
                )
            else:
                print(f"[ConfigSync] ⚠️ No config found for '{module_name}'")
        
        print(f"\n[ConfigSync] Total modules: {len(all_modules)}")
        print(f"[ConfigSync] Module configs: {len(config.module_configs)}")
        
        # Check for duplicate taskbar modules
        taskbar_modules = [m for m in all_modules if 'taskbar' in m.lower()]
        if len(taskbar_modules) > 1:
            print(f"\n[ConfigSync] ⚠️ WARNING: Multiple taskbar modules found!")
            print(f"   Found: {taskbar_modules}")
            print(f"   ZenPyBar only uses 'hyprland/taskbar'")
            print(f"   Consider removing: {[m for m in taskbar_modules if m != 'hyprland/taskbar']}")
        
        # Check for unsupported modules
        unsupported = []
        for mod in all_modules:
            if mod.startswith('custom/') and mod not in ['custom/music', 'custom/notification']:
                if mod != 'hyprland/taskbar':  # This was mapped from custom/panel
                    unsupported.append(mod)
            elif mod in ['pulseaudio', 'cpu', 'memory', 'temperature', 'network', 'bluetooth', 'wlr/taskbar']:
                unsupported.append(mod)
        
        if unsupported:
            print(f"\n[ConfigSync] ⚠️ WARNING: Unsupported modules (will be skipped):")
            for mod in unsupported:
                print(f"   - {mod}")
            print(f"   These modules need implementation in bar.py")
    
    # 2. Load theme colors from CSS
    style_path = WAYBAR_DIR / "style.css"
    if style_path.exists():
        css_content = resolve_css_imports(style_path)
        config.theme = parse_css_colors(css_content)
        print(f"[ConfigSync] ✅ Loaded {len(config.theme)} colors")
    
    # 3. Generate source hash for change detection
    source_content = ""
    if config_path.exists():
        source_content += config_path.read_text()
    if style_path.exists():
        source_content += style_path.read_text()
    
    config.source_hash = hashlib.md5(source_content.encode()).hexdigest()[:16]
    
    return config


def save_config(config: ZenPyBarConfig):
    """Save config to ZenPyBar preferences"""
    ZENPYBAR_PREFS.parent.mkdir(parents=True, exist_ok=True)
    
    data = asdict(config)
    
    with open(ZENPYBAR_PREFS, 'w') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    
    print(f"[ConfigSync] ✅ Saved: {ZENPYBAR_PREFS}")


def load_cached_config() -> Optional[ZenPyBarConfig]:
    """Load cached config from preferences"""
    if not ZENPYBAR_PREFS.exists():
        return None
    
    try:
        with open(ZENPYBAR_PREFS, 'r') as f:
            data = json.load(f)
        
        return ZenPyBarConfig(**data)
    except Exception as e:
        print(f"[ConfigSync] ⚠️ Cache load error: {e}")
        return None


def needs_sync() -> bool:
    """Check if sync is needed by comparing hashes"""
    cached = load_cached_config()
    if not cached:
        return True
    
    # Compute current hash
    source_content = ""
    
    config_path = WAYBAR_DIR / "config.jsonc"
    if not config_path.exists():
        config_path = WAYBAR_DIR / "config.json"
    
    style_path = WAYBAR_DIR / "style.css"
    
    if config_path.exists():
        source_content += config_path.read_text()
    if style_path.exists():
        source_content += style_path.read_text()
    
    current_hash = hashlib.md5(source_content.encode()).hexdigest()[:16]
    
    return current_hash != cached.source_hash


def restart_zenpybar():
    """Restart ZenPyBar"""
    print("[ConfigSync] Restarting ZenPyBar...")
    subprocess.run(['pkill', '-f', 'zenpybar'], capture_output=True)


# ═══════════════════════════════════════════════════════════════════════════════
# CLI
# ═══════════════════════════════════════════════════════════════════════════════

def main():
    import argparse
    
    parser = argparse.ArgumentParser(description='Sync Waybar config to ZenPyBar v2')
    parser.add_argument('--watch', action='store_true', help='Watch for changes')
    parser.add_argument('--force', action='store_true', help='Force sync even if unchanged')
    parser.add_argument('--restart', action='store_true', help='Restart ZenPyBar after sync')
    
    args = parser.parse_args()
    
    print("""
╔══════════════════════════════════════════════════════════╗
║              ZenPyBar Config Sync v2.0                   ║
╚══════════════════════════════════════════════════════════╝
""")
    
    if args.watch:
        # Watch mode - requires inotify
        try:
            import inotify.adapters
        except ImportError:
            print("[ConfigSync] ❌ Watch mode requires: pip install inotify")
            print("[ConfigSync] Running one-time sync instead...")
            args.watch = False
    
    if args.watch:
        print("[ConfigSync] Watching for changes... (Ctrl+C to stop)")
        import inotify.adapters
        
        i = inotify.adapters.Inotify()
        i.add_watch(str(WAYBAR_DIR))
        if COLORSCHEME_DIR.exists():
            i.add_watch(str(COLORSCHEME_DIR))
        
        for event in i.event_gen(yield_nones=False):
            (_, type_names, path, filename) = event
            
            if 'IN_CLOSE_WRITE' in type_names or 'IN_MODIFY' in type_names:
                if filename.endswith(('.json', '.jsonc', '.css')):
                    print(f"\n[ConfigSync] Change detected: {filename}")
                    
                    config = sync_config()
                    save_config(config)
                    
                    if args.restart:
                        restart_zenpybar()
    else:
        # One-time sync
        if args.force:
            if ZENPYBAR_PREFS.exists():
                ZENPYBAR_PREFS.unlink()
                print("[ConfigSync] 🗑️ Deleted old cache")
        
        if not args.force and not needs_sync():
            print("[ConfigSync] No changes detected, skipping sync")
            print("[ConfigSync] Use --force to sync anyway")
            return
        
        config = sync_config()
        save_config(config)
        
        # Print summary
        print(f"\n[ConfigSync] Summary:")
        print(f"  Version: {config.version}")
        print(f"  Height: {config.height}px")
        print(f"  Position: {config.position}")
        print(f"  Modules Left: {config.modules_left}")
        print(f"  Modules Center: {config.modules_center}")
        print(f"  Modules Right: {config.modules_right}")
        print(f"  Theme colors: {len(config.theme)}")
        
        if args.restart:
            restart_zenpybar()


if __name__ == "__main__":
    main()