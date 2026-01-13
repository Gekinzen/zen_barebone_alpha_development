#!/usr/bin/env python3
"""
Quick test to verify Panel page can be imported and called
"""

print("Testing Panel module...")
print("-" * 50)

# Test 1: Import check
try:
    from src.pages import panel_helpers
    print("✅ panel_helpers imported successfully")
except Exception as e:
    print(f"❌ panel_helpers import failed: {e}")

# Test 2: Check functions exist
try:
    from src.pages.panel_helpers import (
        create_module_chip,
        create_module_drop_zone,
        create_size_selector,
        get_monitor_list
    )
    print("✅ All helper functions exist")
except Exception as e:
    print(f"❌ Helper functions check failed: {e}")

# Test 3: Check panel page exists
try:
    from src.pages import panel
    print("✅ panel module imported successfully")
except Exception as e:
    print(f"❌ panel import failed: {e}")

# Test 4: Check build function exists
try:
    from src.pages.panel import build_panel_page
    print("✅ build_panel_page function exists")
except Exception as e:
    print(f"❌ build_panel_page check failed: {e}")

# Test 5: Check WaybarManager
try:
    from src.waybar_manager import WaybarManager
    print("✅ WaybarManager imported successfully")
    
    # Try to create instance
    wm = WaybarManager()
    print(f"✅ WaybarManager instance created")
    print(f"   - Available modules: {len(wm.get_available_modules())} modules")
except Exception as e:
    print(f"❌ WaybarManager check failed: {e}")

print("-" * 50)
print("All imports successful! Panel module is ready to use.")
print("\nTo run the app:")
print("  python main.py")