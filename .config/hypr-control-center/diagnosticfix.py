#!/usr/bin/env python3
"""
Diagnostic and Fix Script for Hyprland Control Center
Checks and fixes:
1. White icon CSS classes in window.py
2. Theme persistence manager
3. JSON config auto-generation
"""

import os
import sys
from pathlib import Path

CONFIG_DIR = Path.home() / ".config" / "hypr-control-center"
SRC_DIR = CONFIG_DIR / "src"
WINDOW_PY = SRC_DIR / "window.py"
STYLES_PY = SRC_DIR / "styles.py"
PREFS_DIR = CONFIG_DIR / "preferences"

def check_window_py():
    """Check if window.py has white icon CSS classes"""
    print("\n🔍 Checking window.py for icon classes...")
    
    if not WINDOW_PY.exists():
        print(f"❌ File not found: {WINDOW_PY}")
        return False
    
    content = WINDOW_PY.read_text()
    
    # Check for icon.add_css_class('sidebar-icon')
    if "icon.add_css_class('sidebar-icon')" in content:
        print("✅ Found: icon.add_css_class('sidebar-icon')")
    else:
        print("❌ Missing: icon.add_css_class('sidebar-icon')")
        return False
    
    # Check for icon.add_css_class('force-white')
    if "icon.add_css_class('force-white')" in content:
        print("✅ Found: icon.add_css_class('force-white')")
    else:
        print("❌ Missing: icon.add_css_class('force-white')")
        return False
    
    return True

def fix_window_py():
    """Add missing CSS classes to window.py"""
    print("\n🔧 Fixing window.py...")
    
    content = WINDOW_PY.read_text()
    lines = content.split('\n')
    
    fixed_lines = []
    for i, line in enumerate(lines):
        fixed_lines.append(line)
        
        # If we find set_pixel_size and next lines don't have css classes
        if 'icon.set_pixel_size(18)' in line:
            # Check next 3 lines
            next_lines = lines[i+1:i+4]
            next_text = '\n'.join(next_lines)
            
            if "icon.add_css_class('sidebar-icon')" not in next_text:
                # Add the classes
                indent = ' ' * (len(line) - len(line.lstrip()))
                fixed_lines.append(f"{indent}icon.add_css_class('sidebar-icon')")
                fixed_lines.append(f"{indent}icon.add_css_class('force-white')")
                print("✅ Added CSS classes after set_pixel_size(18)")
    
    # Write back
    WINDOW_PY.write_text('\n'.join(fixed_lines))
    print("✅ window.py fixed!")

def check_styles_py():
    """Check if styles.py has force-white CSS"""
    print("\n🔍 Checking styles.py for white icon CSS...")
    
    if not STYLES_PY.exists():
        print(f"❌ File not found: {STYLES_PY}")
        return False
    
    content = STYLES_PY.read_text()
    
    if '.force-white' in content:
        print("✅ Found: .force-white CSS class")
        return True
    else:
        print("❌ Missing: .force-white CSS class")
        return False

def check_prefs_dir():
    """Check if preferences directory exists"""
    print("\n🔍 Checking preferences directory...")
    
    if not PREFS_DIR.exists():
        print(f"❌ Directory not found: {PREFS_DIR}")
        print("🔧 Creating directory...")
        PREFS_DIR.mkdir(parents=True, exist_ok=True)
        print(f"✅ Created: {PREFS_DIR}")
        return False
    else:
        print(f"✅ Directory exists: {PREFS_DIR}")
        return True

def create_default_configs():
    """Create default JSON configs"""
    print("\n🔧 Creating default JSON configs...")
    
    # Wallpaper config
    wallpaper_json = PREFS_DIR / "wallpaper.json"
    if not wallpaper_json.exists():
        import json
        default_config = {
            "wallpaper_folder": str(Path.home() / "wallpapers"),
            "current_wallpaper": "",
            "transition_type": "fade",
            "slideshow_enabled": False,
            "slideshow_interval": 60,
            "random_transition": False
        }
        wallpaper_json.write_text(json.dumps(default_config, indent=2))
        print(f"✅ Created: {wallpaper_json}")
    else:
        print(f"✅ Already exists: {wallpaper_json}")
    
    # Theme config
    theme_json = PREFS_DIR / "theme.json"
    if not theme_json.exists():
        import json
        default_config = {
            "current_theme": "One Dark",
            "gtk_theme_enabled": False
        }
        theme_json.write_text(json.dumps(default_config, indent=2))
        print(f"✅ Created: {theme_json}")
    else:
        print(f"✅ Already exists: {theme_json}")

def main():
    print("=" * 60)
    print("🔧 HYPRLAND CONTROL CENTER - DIAGNOSTIC & FIX TOOL")
    print("=" * 60)
    
    # Check preferences directory
    check_prefs_dir()
    
    # Create default configs
    create_default_configs()
    
    # Check window.py
    if not check_window_py():
        response = input("\n⚠️  window.py needs fixing. Fix it? (y/n): ")
        if response.lower() == 'y':
            fix_window_py()
            print("\n✅ Fixed! Now clear cache and restart app:")
            print(f"   rm -rf {CONFIG_DIR}/src/__pycache__")
            print(f"   rm -rf {CONFIG_DIR}/src/pages/__pycache__")
            print(f"   cd {CONFIG_DIR} && python3 main.py")
    
    # Check styles.py
    if not check_styles_py():
        print("\n❌ styles.py is missing white icon CSS!")
        print("📥 Please download and install styles_FINAL.py:")
        print(f"   cp ~/Downloads/styles_FINAL.py {STYLES_PY}")
    
    print("\n" + "=" * 60)
    print("✅ DIAGNOSTIC COMPLETE")
    print("=" * 60)

if __name__ == "__main__":
    main()