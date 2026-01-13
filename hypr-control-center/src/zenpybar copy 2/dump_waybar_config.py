#!/usr/bin/env python3
"""
Show Exact Waybar Config Content
Debug what's actually in your config.jsonc
"""

import json
import re
from pathlib import Path

WAYBAR_DIR = Path.home() / ".config/waybar"

def parse_jsonc(content: str) -> dict:
    # Remove comments
    content = re.sub(r'//.*?$', '', content, flags=re.MULTILINE)
    content = re.sub(r'/\*.*?\*/', '', content, flags=re.DOTALL)
    content = re.sub(r',\s*([}\]])', r'\1', content)
    
    try:
        return json.loads(content)
    except json.JSONDecodeError as e:
        print(f"Parse error: {e}")
        return {}

config_path = WAYBAR_DIR / "config.jsonc"
if not config_path.exists():
    config_path = WAYBAR_DIR / "config.json"

if not config_path.exists():
    print("❌ No config found!")
    exit(1)

print(f"Reading: {config_path}\n")

raw = parse_jsonc(config_path.read_text())

print("=" * 60)
print("EXACT WAYBAR CONFIG CONTENT")
print("=" * 60)

print(json.dumps(raw, indent=2))

print("\n" + "=" * 60)
print("MODULE SUMMARY")
print("=" * 60)

left = raw.get('modules-left', [])
center = raw.get('modules-center', [])
right = raw.get('modules-right', [])

print(f"\nmodules-left: {left}")
print(f"modules-center: {center}")
print(f"modules-right: {right}")

print("\n" + "=" * 60)
print("AVAILABLE MODULE CONFIGS")
print("=" * 60)

all_keys = [k for k in raw.keys() if not k.startswith('modules-') and k not in ['height', 'position', 'layer', 'margin-top', 'margin-bottom', 'margin-left', 'margin-right']]

print(f"\nFound {len(all_keys)} module configs:")
for key in sorted(all_keys):
    print(f"   - {key}")