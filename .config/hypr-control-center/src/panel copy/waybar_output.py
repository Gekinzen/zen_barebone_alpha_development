#!/usr/bin/env python3
"""
Waybar Output Module
Generates Waybar-compatible JSON output for taskbar

Location: ~/.config/hypr-control-center/src/panel/waybar_output.py

This module provides:
- render_taskbar() - Returns JSON string for Waybar
- handle_click() - Handles click events from Waybar
"""

import json
import subprocess
import os
from pathlib import Path
from typing import List, Dict, Optional

# Local imports
try:
    from .icon_resolver import get_resolver, get_nerd_icon, NERD_FONT_ICONS
    from .pinned_manager import get_pinned_manager
except ImportError:
    import sys
    sys.path.insert(0, str(Path(__file__).parent))
    from icon_resolver import get_resolver, get_nerd_icon, NERD_FONT_ICONS
    from pinned_manager import get_pinned_manager


# ==========================================
# HYPRLAND HELPERS
# ==========================================

def get_hypr_clients() -> List[Dict]:
    """Get all windows from Hyprland"""
    try:
        result = subprocess.run(
            ['hyprctl', '-j', 'clients'],
            capture_output=True, text=True, timeout=2
        )
        if result.returncode == 0:
            return json.loads(result.stdout)
    except:
        pass
    return []


def get_active_window() -> Optional[Dict]:
    """Get currently focused window"""
    try:
        result = subprocess.run(
            ['hyprctl', '-j', 'activewindow'],
            capture_output=True, text=True, timeout=2
        )
        if result.returncode == 0:
            data = json.loads(result.stdout)
            if data.get('address'):
                return data
    except:
        pass
    return None


def focus_window(address: str):
    """Focus a window by address"""
    subprocess.run(['hyprctl', 'dispatch', 'focuswindow', f'address:{address}'],
                   capture_output=True, timeout=2)


def close_window(address: str):
    """Close a window by address"""
    subprocess.run(['hyprctl', 'dispatch', 'closewindow', f'address:{address}'],
                   capture_output=True, timeout=2)


# ==========================================
# GROUP WINDOWS BY CLASS
# ==========================================

def group_windows_by_class(clients: List[Dict]) -> Dict[str, List[Dict]]:
    """Group windows by WM class"""
    groups = {}
    
    # Ignored classes
    ignored = {'', 'hypr-widget-clock', 'hypr-widget-weather', 'hypr-widget-system_monitor'}
    
    for client in clients:
        wm_class = client.get('class', '')
        if not wm_class or wm_class in ignored or wm_class.startswith('hypr-widget'):
            continue
        
        if wm_class not in groups:
            groups[wm_class] = []
        groups[wm_class].append(client)
    
    return groups


# ==========================================
# RENDER TASKBAR
# ==========================================

def render_taskbar() -> str:
    """
    Render taskbar as Waybar-compatible JSON
    
    Returns JSON with:
    - text: The icons/labels to display
    - tooltip: Hover tooltip text
    - class: CSS classes for styling
    """
    resolver = get_resolver()
    pinned_manager = get_pinned_manager()
    
    # Get current state
    clients = get_hypr_clients()
    active = get_active_window()
    active_class = active.get('class', '').lower() if active else ''
    
    # Group running windows
    running_groups = group_windows_by_class(clients)
    running_classes = {k.lower(): k for k in running_groups.keys()}
    
    # Get pinned apps
    pinned_apps = pinned_manager.get_pinned_apps()
    pinned_ids = set()
    for p in pinned_apps:
        if p.wm_class:
            pinned_ids.add(p.wm_class.lower())
        pinned_ids.add(p.app_id.lower())
    
    # Build output
    items = []
    tooltip_lines = []
    css_classes = []
    
    # 1. Render pinned apps
    for pinned in pinned_apps:
        # Check if running
        is_running = False
        window_count = 0
        original_class = None
        
        if pinned.wm_class and pinned.wm_class.lower() in running_classes:
            original_class = running_classes[pinned.wm_class.lower()]
            is_running = True
            window_count = len(running_groups.get(original_class, []))
        elif pinned.app_id.lower() in running_classes:
            original_class = running_classes[pinned.app_id.lower()]
            is_running = True
            window_count = len(running_groups.get(original_class, []))
        
        # Get icon
        icon = get_nerd_icon(pinned.wm_class or pinned.app_id)
        
        # Check if focused
        is_focused = False
        if original_class and active_class == original_class.lower():
            is_focused = True
        
        # Build item
        if is_running:
            if is_focused:
                item = f'<span color="#89b4fa">{icon}</span>'
                css_classes.append('focused')
            else:
                item = f'<span color="#cdd6f4">{icon}</span>'
            
            if window_count > 1:
                item += f'<span size="small" color="#f38ba8">{window_count}</span>'
        else:
            # Pinned but not running (dimmed)
            item = f'<span color="#6c7086">{icon}</span>'
        
        items.append(item)
        tooltip_lines.append(f"{icon} {pinned.name}" + (f" ({window_count})" if window_count > 1 else ""))
    
    # 2. Add separator if we have both pinned and non-pinned running
    non_pinned_running = [c for c in running_groups.keys() if c.lower() not in pinned_ids]
    
    if pinned_apps and non_pinned_running:
        items.append('<span color="#45475a">│</span>')
    
    # 3. Render non-pinned running apps
    for wm_class in non_pinned_running:
        windows = running_groups[wm_class]
        window_count = len(windows)
        
        icon = get_nerd_icon(wm_class)
        is_focused = active_class == wm_class.lower()
        
        if is_focused:
            item = f'<span color="#89b4fa">{icon}</span>'
            css_classes.append('focused')
        else:
            item = f'<span color="#cdd6f4">{icon}</span>'
        
        if window_count > 1:
            item += f'<span size="small" color="#f38ba8">{window_count}</span>'
        
        items.append(item)
        tooltip_lines.append(f"{icon} {wm_class}" + (f" ({window_count})" if window_count > 1 else ""))
    
    # Build final output
    text = ' '.join(items) if items else ''
    tooltip = '\n'.join(tooltip_lines) if tooltip_lines else 'No windows'
    
    output = {
        'text': text,
        'tooltip': tooltip,
        'class': ' '.join(css_classes) if css_classes else 'normal'
    }
    
    return json.dumps(output)


# ==========================================
# HANDLE CLICKS
# ==========================================

def handle_click(button: str = '1'):
    """
    Handle click events from Waybar
    
    Button:
    - 1: Left click - show rofi window switcher
    - 2: Middle click - close focused window
    - 3: Right click - show app menu
    """
    if button == '1':
        # Left click - show window switcher with rofi
        show_window_switcher()
    
    elif button == '2':
        # Middle click - close focused window
        active = get_active_window()
        if active and active.get('address'):
            close_window(active['address'])
    
    elif button == '3':
        # Right click - show app menu
        show_app_menu()


def show_window_switcher():
    """Show rofi window switcher"""
    try:
        subprocess.Popen(['rofi', '-show', 'window', '-window-format', '{c} {t}'])
    except:
        # Fallback to wofi
        try:
            subprocess.Popen(['wofi', '--show', 'drun'])
        except:
            pass


def show_app_menu():
    """Show application launcher"""
    try:
        subprocess.Popen(['rofi', '-show', 'drun'])
    except:
        try:
            subprocess.Popen(['wofi', '--show', 'drun'])
        except:
            pass


# ==========================================
# SPECIFIC APP CLICK (for individual icons)
# ==========================================

def click_app(app_id: str, button: str = '1'):
    """
    Handle click on specific app
    
    Button:
    - 1: Focus app / Launch if not running
    - 2: Close all windows
    - 3: Show context menu
    """
    resolver = get_resolver()
    pinned_manager = get_pinned_manager()
    
    clients = get_hypr_clients()
    running_groups = group_windows_by_class(clients)
    
    # Find matching windows
    app_id_lower = app_id.lower()
    matching_class = None
    
    for wm_class in running_groups.keys():
        if wm_class.lower() == app_id_lower or app_id_lower in wm_class.lower():
            matching_class = wm_class
            break
    
    if button == '1':
        if matching_class:
            # App is running - focus most recent window
            windows = running_groups[matching_class]
            if windows:
                focus_window(windows[0]['address'])
        else:
            # App not running - launch it
            pinned_manager.launch_app(app_id)
    
    elif button == '2':
        if matching_class:
            # Close all windows
            for window in running_groups[matching_class]:
                close_window(window['address'])
    
    elif button == '3':
        # Show context menu (could use rofi)
        pass


# ==========================================
# RENDER PINNED ONLY (separate module)
# ==========================================

def render_pinned() -> str:
    """Render only pinned apps for separate Waybar module"""
    resolver = get_resolver()
    pinned_manager = get_pinned_manager()
    
    clients = get_hypr_clients()
    active = get_active_window()
    active_class = active.get('class', '').lower() if active else ''
    
    running_groups = group_windows_by_class(clients)
    running_classes = {k.lower(): k for k in running_groups.keys()}
    
    pinned_apps = pinned_manager.get_pinned_apps()
    
    items = []
    tooltip_lines = []
    
    for pinned in pinned_apps:
        is_running = False
        original_class = None
        
        if pinned.wm_class and pinned.wm_class.lower() in running_classes:
            original_class = running_classes[pinned.wm_class.lower()]
            is_running = True
        elif pinned.app_id.lower() in running_classes:
            original_class = running_classes[pinned.app_id.lower()]
            is_running = True
        
        icon = get_nerd_icon(pinned.wm_class or pinned.app_id)
        is_focused = original_class and active_class == original_class.lower()
        
        if is_running:
            if is_focused:
                item = f'<span color="#89b4fa">{icon}</span>'
            else:
                item = f'<span color="#cdd6f4">{icon}</span>'
        else:
            item = f'<span color="#6c7086">{icon}</span>'
        
        items.append(item)
        tooltip_lines.append(f"{icon} {pinned.name}")
    
    output = {
        'text': ' '.join(items),
        'tooltip': '\n'.join(tooltip_lines) if tooltip_lines else 'No pinned apps',
        'class': 'pinned'
    }
    
    return json.dumps(output)


# ==========================================
# RENDER RUNNING ONLY (separate module)
# ==========================================

def render_running() -> str:
    """Render only running (non-pinned) apps for separate Waybar module"""
    resolver = get_resolver()
    pinned_manager = get_pinned_manager()
    
    clients = get_hypr_clients()
    active = get_active_window()
    active_class = active.get('class', '').lower() if active else ''
    
    running_groups = group_windows_by_class(clients)
    
    # Get pinned IDs to exclude
    pinned_apps = pinned_manager.get_pinned_apps()
    pinned_ids = set()
    for p in pinned_apps:
        if p.wm_class:
            pinned_ids.add(p.wm_class.lower())
        pinned_ids.add(p.app_id.lower())
    
    items = []
    tooltip_lines = []
    
    for wm_class, windows in running_groups.items():
        if wm_class.lower() in pinned_ids:
            continue
        
        icon = get_nerd_icon(wm_class)
        is_focused = active_class == wm_class.lower()
        window_count = len(windows)
        
        if is_focused:
            item = f'<span color="#89b4fa">{icon}</span>'
        else:
            item = f'<span color="#cdd6f4">{icon}</span>'
        
        if window_count > 1:
            item += f'<span size="small" color="#f38ba8">{window_count}</span>'
        
        items.append(item)
        tooltip_lines.append(f"{icon} {wm_class}" + (f" ({window_count})" if window_count > 1 else ""))
    
    output = {
        'text': ' '.join(items),
        'tooltip': '\n'.join(tooltip_lines) if tooltip_lines else 'No running apps',
        'class': 'running'
    }
    
    return json.dumps(output)


# ==========================================
# TEST
# ==========================================

if __name__ == "__main__":
    print("=== TASKBAR OUTPUT ===")
    print(render_taskbar())
    print()
    print("=== PINNED ONLY ===")
    print(render_pinned())
    print()
    print("=== RUNNING ONLY ===")
    print(render_running())