#!/usr/bin/env python3
"""
Waybar Config Diagnostic Tool
Check what modules are actually in your Waybar config
"""

import json
import re
from pathlib import Path

WAYBAR_DIR = Path.home() / ".config/waybar"

def parse_jsonc(content: str) -> dict:
    """Parse JSONC (JSON with comments)"""
    # Remove // comments
    content = re.sub(r'//.*?$', '', content, flags=re.MULTILINE)
    # Remove /* */ comments
    content = re.sub(r'/\*.*?\*/', '', content, flags=re.DOTALL)
    # Remove trailing commas
    content = re.sub(r',\s*([}\]])', r'\1', content)
    
    try:
        return json.loads(content)
    except json.JSONDecodeError as e:
        print(f"❌ JSON parse error: {e}")
        return {}


def main():
    print("=== Waybar Config Diagnostic ===\n")
    
    # Find config file
    config_path = WAYBAR_DIR / "config.jsonc"
    if not config_path.exists():
        config_path = WAYBAR_DIR / "config.json"
    
    if not config_path.exists():
        print("❌ No Waybar config found!")
        print(f"   Checked: {WAYBAR_DIR / 'config.jsonc'}")
        print(f"   Checked: {WAYBAR_DIR / 'config.json'}")
        return
    
    print(f"✅ Found config: {config_path.name}\n")
    
    # Parse config
    raw_config = parse_jsonc(config_path.read_text())
    
    if not raw_config:
        print("❌ Failed to parse config!")
        return
    
    # Show basic settings
    print("📊 Bar Settings:")
    print(f"   Height: {raw_config.get('height', 'NOT SET')}")
    print(f"   Position: {raw_config.get('position', 'NOT SET')}")
    print(f"   Layer: {raw_config.get('layer', 'NOT SET')}")
    print()
    
    # Show modules
    print("📦 Modules Configuration:")
    
    modules_left = raw_config.get('modules-left', [])
    modules_center = raw_config.get('modules-center', [])
    modules_right = raw_config.get('modules-right', [])
    
    print(f"\n   LEFT ({len(modules_left)} modules):")
    for mod in modules_left:
        has_config = mod in raw_config
        print(f"      {'✅' if has_config else '⚠️ '} {mod}")
        if not has_config:
            print(f"         (No config block found)")
    
    print(f"\n   CENTER ({len(modules_center)} modules):")
    for mod in modules_center:
        has_config = mod in raw_config
        print(f"      {'✅' if has_config else '⚠️ '} {mod}")
        if not has_config:
            print(f"         (No config block found)")
    
    print(f"\n   RIGHT ({len(modules_right)} modules):")
    for mod in modules_right:
        has_config = mod in raw_config
        print(f"      {'✅' if has_config else '⚠️ '} {mod}")
        if not has_config:
            print(f"         (No config block found)")
    
    # Show module configs
    print("\n\n📋 Module Configs Found:")
    all_modules = set(modules_left + modules_center + modules_right)
    
    for mod in sorted(all_modules):
        if mod in raw_config:
            config = raw_config[mod]
            print(f"\n   {mod}:")
            
            # Show important keys
            if isinstance(config, dict):
                for key in ['format', 'exec', 'on-click', 'interval']:
                    if key in config:
                        value = str(config[key])
                        if len(value) > 60:
                            value = value[:57] + "..."
                        print(f"      {key}: {value}")
    
    # Show what ZenPyBar would see
    print("\n\n🎯 What ZenPyBar Will Get:")
    print(f"   modules_left: {modules_left}")
    print(f"   modules_center: {modules_center}")
    print(f"   modules_right: {modules_right}")
    
    # Check for common issues
    print("\n\n⚠️  Common Issues:")
    
    issues = []
    
    # Check for group modules
    for mod in all_modules:
        if mod.startswith('group/'):
            issues.append(f"   • '{mod}' is a group module - ZenPyBar doesn't support drawer groups yet")
    
    # Check for missing configs
    missing = [m for m in all_modules if m not in raw_config]
    if missing:
        issues.append(f"   • Missing config blocks: {', '.join(missing)}")
    
    # Check for taskbar
    if 'hyprland/taskbar' not in all_modules and 'custom/panel' not in all_modules:
        issues.append(f"   • No taskbar module found! Add 'hyprland/taskbar' or 'custom/panel'")
    
    if issues:
        for issue in issues:
            print(issue)
    else:
        print("   ✅ No issues found!")
    
    print("\n" + "="*50)


if __name__ == "__main__":
    main()