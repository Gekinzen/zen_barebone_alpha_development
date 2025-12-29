#!/usr/bin/env python3
"""
Verify if Panel files are up to date
"""

import sys
from pathlib import Path

print("=" * 60)
print("PANEL FILES VERIFICATION")
print("=" * 60)
print()

# Check if in correct directory
if not Path("src/pages/panel.py").exists():
    print("❌ Run this from ~/.config/hypr-control-center/")
    sys.exit(1)

print("Checking panel.py...")
with open("src/pages/panel.py", 'r') as f:
    content = f.read()
    
    # Check for new features
    checks = {
        "Position dropdown (top/bottom only)": '"top", "bottom"]  # Only horizontal' in content,
        "Add module dialog": 'available_modules = [m for m in all_modules if m not in used_modules]' in content,
        "Page refresh function": '_refresh_panel_page(window)' in content,
        "Auto-save on remove": '_on_panel_apply(window, is_dock=is_dock)' in content and '_refresh_panel_page(window)' in content,
    }
    
    all_good = True
    for feature, found in checks.items():
        if found:
            print(f"  ✅ {feature}")
        else:
            print(f"  ❌ {feature} - MISSING!")
            all_good = False

print()
print("Checking waybar_style_manager.py...")
if Path("src/waybar_style_manager.py").exists():
    print("  ✅ File exists")
    with open("src/waybar_style_manager.py", 'r') as f:
        if 'class WaybarStyleManager' in f.read():
            print("  ✅ WaybarStyleManager class found")
        else:
            print("  ❌ Class not found!")
            all_good = False
else:
    print("  ❌ File missing!")
    all_good = False

print()
print("Checking waybar_manager.py...")
with open("src/waybar_manager.py", 'r') as f:
    content = f.read()
    if 'config.jsonc' in content:
        print("  ✅ Uses config.jsonc")
    else:
        print("  ⚠️  Still uses config.json (should be .jsonc)")
        all_good = False

print()
print("=" * 60)
if all_good:
    print("✅ ALL FILES UP TO DATE!")
    print()
    print("If you still see issues:")
    print("1. Clear Python cache:")
    print("   find . -type d -name __pycache__ -exec rm -rf {} +")
    print("2. Restart the app completely")
else:
    print("❌ SOME FILES ARE OLD!")
    print()
    print("Copy the updated files:")
    print("  cp /path/to/outputs/src/waybar_manager.py src/")
    print("  cp /path/to/outputs/src/waybar_style_manager.py src/")
    print("  cp /path/to/outputs/src/pages/panel.py src/pages/")
print("=" * 60)