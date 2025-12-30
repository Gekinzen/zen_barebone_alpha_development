#!/usr/bin/env python3
"""
Diagnostic Script - Run this to check why Panel shows "Coming Soon"
Run from: ~/.config/hypr-control-center/
"""

import os
import sys
from pathlib import Path

print("=" * 60)
print("HYPRLAND CONTROL CENTER - PANEL DIAGNOSTIC")
print("=" * 60)
print()

# Check 1: Current directory
print("1. Checking directory...")
cwd = Path.cwd()
print(f"   Current: {cwd}")
if not (cwd / "main.py").exists():
    print("   ❌ main.py not found!")
    print("   Please run from ~/.config/hypr-control-center/")
    sys.exit(1)
print("   ✅ In correct directory")
print()

# Check 2: Panel.py exists and size
print("2. Checking panel.py...")
panel_file = Path("src/pages/panel.py")
if not panel_file.exists():
    print("   ❌ src/pages/panel.py NOT FOUND!")
    print("   This is the problem - file is missing!")
    sys.exit(1)

lines = len(panel_file.read_text().splitlines())
print(f"   ✅ File exists: {lines} lines")

if lines < 200:
    print(f"   ⚠️  WARNING: File too small ({lines} lines)")
    print("   Expected: ~336 lines")
    print("   This might be the old placeholder version!")
print()

# Check 3: File content
print("3. Checking panel.py content...")
content = panel_file.read_text()

checks = {
    "PlaceholderPage": "❌ FOUND (This is BAD - means old version)",
    "build_panel_page": "✅ Found function",
    "Panel Behavior": "✅ Found settings section",
    "WaybarManager": "✅ Found waybar import",
    "Dock (Waybar2) coming soon": "✅ Found dock message",
}

for search_text, message in checks.items():
    if search_text in content:
        if "BAD" in message:
            print(f"   {message} - '{search_text}'")
            print("   THIS IS THE PROBLEM!")
        else:
            print(f"   {message}")
    else:
        if "Found" in message:
            print(f"   ❌ Missing: {search_text}")
print()

# Check 4: Required files
print("4. Checking required files...")
required = {
    "src/waybar_manager.py": 280,
    "src/pages/panel_helpers.py": 150,
    "assets/waybar/default-style.css": 100,
}

missing = []
for file, expected_lines in required.items():
    filepath = Path(file)
    if filepath.exists():
        actual_lines = len(filepath.read_text().splitlines())
        print(f"   ✅ {file} ({actual_lines} lines)")
        if actual_lines < expected_lines - 50:
            print(f"      ⚠️  Expected ~{expected_lines} lines")
    else:
        print(f"   ❌ {file} MISSING!")
        missing.append(file)

if missing:
    print()
    print("   MISSING FILES - This is likely the problem!")
print()

# Check 5: Import test
print("5. Testing imports...")
try:
    from src.pages import panel
    print("   ✅ src.pages.panel imported")
except ImportError as e:
    print(f"   ❌ Import failed: {e}")
    sys.exit(1)

try:
    from src.pages.panel import build_panel_page
    print("   ✅ build_panel_page imported")
except ImportError as e:
    print(f"   ❌ build_panel_page import failed: {e}")
    sys.exit(1)

# Check if it's the placeholder
import inspect
source = inspect.getsource(build_panel_page)
if "PlaceholderPage" in source:
    print("   ❌ PROBLEM FOUND!")
    print("   build_panel_page is returning PlaceholderPage")
    print("   You have the OLD version!")
elif "Panel Behavior" in source:
    print("   ✅ build_panel_page has full implementation")
else:
    print("   ⚠️  Unclear - check manually")
print()

# Check 6: Python cache
print("6. Checking for stale cache...")
cache_dirs = list(Path(".").rglob("__pycache__"))
if cache_dirs:
    print(f"   ⚠️  Found {len(cache_dirs)} cache directories")
    print("   Run: find . -type d -name __pycache__ -exec rm -rf {{}} +")
else:
    print("   ✅ No cache found")
print()

# Check 7: Window.py imports
print("7. Checking window.py imports...")
window_file = Path("src/window.py")
if window_file.exists():
    window_content = window_file.read_text()
    if "from .pages.panel import build_panel_page" in window_content:
        print("   ✅ window.py imports panel correctly")
    else:
        print("   ❌ window.py not importing panel!")
        print("   Check imports in src/window.py")
else:
    print("   ❌ src/window.py not found!")
print()

# Summary
print("=" * 60)
print("DIAGNOSIS COMPLETE")
print("=" * 60)
print()

if "PlaceholderPage" in content:
    print("🔴 PROBLEM IDENTIFIED:")
    print("   Your panel.py is the OLD placeholder version!")
    print()
    print("SOLUTION:")
    print("   1. Download the updated files from outputs/")
    print("   2. Copy to ~/.config/hypr-control-center/:")
    print("      cp src/waybar_manager.py ~/.config/hypr-control-center/src/")
    print("      cp src/pages/panel.py ~/.config/hypr-control-center/src/pages/")
    print("      cp src/pages/panel_helpers.py ~/.config/hypr-control-center/src/pages/")
    print("   3. Clear cache:")
    print("      find . -type d -name __pycache__ -exec rm -rf {} +")
    print("   4. Restart app")
elif missing:
    print("🟡 MISSING FILES:")
    for f in missing:
        print(f"   - {f}")
    print()
    print("SOLUTION:")
    print("   Copy missing files from outputs/ directory")
elif lines < 200:
    print("🟡 FILE TOO SMALL:")
    print(f"   panel.py has only {lines} lines (expected ~336)")
    print()
    print("SOLUTION:")
    print("   Replace with updated panel.py from outputs/")
else:
    print("✅ Everything looks good!")
    print()
    print("If still showing 'Coming Soon', try:")
    print("   1. Clear Python cache")
    print("   2. Restart the app completely")
    print("   3. Check terminal for error messages")
print()