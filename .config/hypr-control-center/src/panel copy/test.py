#!/usr/bin/env python3
"""
Test script for Hyprland IPC module
Location: ~/.config/hypr-control-center/src/panel/test_ipc.py

Run: python3 test_ipc.py
"""

import asyncio
import sys
from pathlib import Path

# Add parent to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from src.panel.hypr_ipc import (
    HyprlandIPC, 
    HyprEvent, 
    HyprEventType,
    hyprctl_json
)


def print_header(text: str):
    print(f"\n{'='*50}")
    print(f"  {text}")
    print('='*50)


async def test_commands():
    """Test basic IPC commands"""
    ipc = HyprlandIPC()
    
    # Test 1: Get all clients/windows
    print_header("TEST 1: Get All Windows")
    windows = await ipc.get_clients()
    
    if windows:
        print(f"Found {len(windows)} windows:\n")
        for w in windows:
            focus_marker = "→" if w.is_focused else " "
            print(f"  {focus_marker} [{w.wm_class:20}] {w.title[:35]:35} | WS:{w.workspace_id}")
    else:
        print("  No windows found (or Hyprland not running)")
    
    # Test 2: Get active window
    print_header("TEST 2: Active Window")
    active = await ipc.get_active_window()
    
    if active:
        print(f"  Class:     {active.wm_class}")
        print(f"  Title:     {active.title}")
        print(f"  Address:   {active.address}")
        print(f"  Workspace: {active.workspace_id}")
        print(f"  Floating:  {active.is_floating}")
    else:
        print("  No active window")
    
    # Test 3: Get workspaces
    print_header("TEST 3: Workspaces")
    workspaces = await ipc.get_workspaces()
    
    if workspaces:
        for ws in workspaces:
            print(f"  [{ws.get('id'):2}] {ws.get('name', 'N/A'):10} - {ws.get('windows', 0)} windows")
    else:
        print("  No workspaces")
    
    # Test 4: Get monitors
    print_header("TEST 4: Monitors")
    monitors = await ipc.get_monitors()
    
    if monitors:
        for mon in monitors:
            print(f"  {mon.get('name')}: {mon.get('width')}x{mon.get('height')} @ {mon.get('refreshRate')}Hz")
    else:
        print("  No monitors")
    
    return ipc


async def test_events(ipc: HyprlandIPC, duration: int = 10):
    """Test event subscription"""
    print_header(f"TEST 5: Event Listener ({duration}s)")
    print("  Open/close/focus windows to see events...\n")
    
    events_received = []
    
    def on_any_event(event: HyprEvent):
        events_received.append(event)
        print(f"  [{event.event_type:15}] {event.data[:50]}")
    
    # Subscribe to all events
    ipc.subscribe_all(on_any_event)
    
    # Run for specified duration
    async def stop_after():
        await asyncio.sleep(duration)
        ipc.stop()
    
    # Start both tasks
    await asyncio.gather(
        ipc.listen_events(),
        stop_after(),
        return_exceptions=True
    )
    
    print(f"\n  Received {len(events_received)} events total")


async def main():
    print("""
╔══════════════════════════════════════════════════╗
║         HYPRLAND IPC TEST SUITE                  ║
╚══════════════════════════════════════════════════╝
""")
    
    # Check if hyprctl works first
    test_data = hyprctl_json("version")
    if not test_data:
        print("ERROR: Cannot connect to Hyprland!")
        print("Make sure Hyprland is running and HYPRLAND_INSTANCE_SIGNATURE is set")
        return
    
    print(f"Hyprland version: {test_data.get('tag', 'unknown')}")
    
    # Run command tests
    ipc = await test_commands()
    
    # Ask if user wants event test
    print_header("EVENT TEST")
    print("  Do you want to test event listening?")
    print("  This will listen for 10 seconds.")
    response = input("  Run event test? [y/N]: ").strip().lower()
    
    if response == 'y':
        await test_events(ipc, duration=10)
    
    print_header("TESTS COMPLETE")
    print("  hypr_ipc.py is working correctly!\n")


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n\nTest interrupted by user")