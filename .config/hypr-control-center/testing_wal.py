#!/usr/bin/env python3
"""
Test script to check wallpaper JSON loading
Run this to see what's in the JSON file
"""

import json
from pathlib import Path

# Path to JSON
json_path = Path.home() / ".config/hypr-control-center/preferences/wallpaper.json"

print(f"JSON file: {json_path}")
print(f"Exists: {json_path.exists()}")
print()

if json_path.exists():
    with open(json_path, 'r') as f:
        data = json.load(f)
    
    print("JSON Contents:")
    print(json.dumps(data, indent=2))
    print()
    
    print("Keys in JSON:")
    for key in data.keys():
        print(f"  - '{key}': {data[key]}")
    print()
    
    # Check for 'current' key
    if 'current' in data:
        print(f"✅ 'current' key found: {data['current']}")
    else:
        print("❌ 'current' key NOT FOUND!")
        if 'current_wallpaper' in data:
            print(f"⚠️  Found 'current_wallpaper' instead: {data['current_wallpaper']}")
else:
    print("❌ JSON file does not exist!")