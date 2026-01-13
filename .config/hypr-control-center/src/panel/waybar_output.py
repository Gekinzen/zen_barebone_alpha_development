#!/usr/bin/env python3
"""
Waybar Output Module (Lightweight - No GTK)
Generates Waybar-compatible JSON output for taskbar
"""

import json
import subprocess
from pathlib import Path
from typing import List, Dict, Optional

# ==========================================
# NERD FONT ICONS
# ==========================================

NERD_FONT_ICONS = {
    'firefox': '󰈹', 'chrome': '󰊯', 'chromium': '󰊯', 'google-chrome': '󰊯',
    'brave': '󰖟', 'edge': '󰇩', 'zen-browser': '󰈹', 'zen': '󰈹',
    'kitty': '󰆍', 'alacritty': '󰆍', 'wezterm': '󰆍', 'foot': '󰆍',
    'terminal': '󰆍', 'gnome-terminal': '󰆍', 'konsole': '󰆍',
    'code': '󰨞', 'code-oss': '󰨞', 'vscode': '󰨞', 'vscodium': '󰨞',
    'visual-studio-code': '󰨞', 'sublime': '󰅳', 'gedit': '󰏫',
    'neovim': '', 'nvim': '', 'vim': '', 'emacs': '󰯸',
    'thunar': '󰝰', 'nautilus': '󰝰', 'dolphin': '󰝰', 'nemo': '󰝰',
    'spotify': '󰓇', 'vlc': '󰕼', 'mpv': '󰐹',
    'discord': '󰙯', 'telegram': '󰚩', 'telegram-desktop': '󰚩',
    'slack': '󰒱', 'teams': '󰊻', 'zoom': '󰊻',
    'steam': '󰓓', 'lutris': '󰺷', 'heroic': '󰺷',
    'gimp': '󰏘', 'inkscape': '󰕙', 'blender': '󰂫',
    'libreoffice': '󰈙', 'evince': '󰈦', 'okular': '󰈦',
    'obsidian': '󰎚', 'notion': '󰎚', 'standard notes': '󰎚', 'standardnotes': '󰎚',
    'obs': '󰑋', 'obs-studio': '󰑋', 'flameshot': '󰹑',
    'openrgb': '󰌁', 'pavucontrol': '󰕾', 'blueman': '󰂯',
    'rofi': '󰍉', 'wofi': '󰍉',
}
DEFAULT_NERD_ICON = '󰣆'

def get_nerd_icon(wm_class: str) -> str:
    if not wm_class:
        return DEFAULT_NERD_ICON
    wm_class_lower = wm_class.lower()
    if wm_class_lower in NERD_FONT_ICONS:
        return NERD_FONT_ICONS[wm_class_lower]
    for key, icon in NERD_FONT_ICONS.items():
        if key in wm_class_lower or wm_class_lower in key:
            return icon
    return DEFAULT_NERD_ICON

# ==========================================
# PINNED APPS
# ==========================================

def load_pinned_apps() -> List[Dict]:
    config_file = Path.home() / ".config/hypr-control-center/taskbar.json"
    if not config_file.exists():
        return []
    try:
        with open(config_file, 'r') as f:
            data = json.load(f)
        pinned_list = data.get('pinned', [])
        apps = []
        for item in pinned_list:
            if isinstance(item, str):
                apps.append({'app_id': item.lower(), 'name': item.capitalize(), 'wm_class': item.lower()})
            elif isinstance(item, dict):
                apps.append(item)
        return apps
    except:
        return []

# ==========================================
# HYPRLAND HELPERS
# ==========================================

def get_hypr_clients() -> List[Dict]:
    try:
        result = subprocess.run(['hyprctl', '-j', 'clients'], capture_output=True, text=True, timeout=2)
        if result.returncode == 0:
            return json.loads(result.stdout)
    except:
        pass
    return []

def get_active_window() -> Optional[Dict]:
    try:
        result = subprocess.run(['hyprctl', '-j', 'activewindow'], capture_output=True, text=True, timeout=2)
        if result.returncode == 0:
            data = json.loads(result.stdout)
            if data.get('address'):
                return data
    except:
        pass
    return None

def group_windows_by_class(clients: List[Dict]) -> Dict[str, List[Dict]]:
    groups = {}
    ignored = {
        '', 
        'hypr-widget-clock', 
        'hypr-widget-weather', 
        'hypr-widget-system_monitor',
        'com.hyprland.panel',  # Our own panel - exclude from taskbar
        'com.hyprland.controlcenter',  # Control center
    }
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
    clients = get_hypr_clients()
    active = get_active_window()
    active_class = (active.get('class') or '').lower() if active else ''
    
    running_groups = group_windows_by_class(clients)
    running_classes = {k.lower(): k for k in running_groups.keys()}
    
    pinned_apps = load_pinned_apps()
    pinned_ids = set()
    for p in pinned_apps:
        wm_class = p.get('wm_class') or p.get('app_id') or ''
        if wm_class:
            pinned_ids.add(wm_class.lower())
        app_id = p.get('app_id') or ''
        if app_id:
            pinned_ids.add(app_id.lower())
    
    items = []
    tooltip_lines = []
    
    # Pinned apps
    for pinned in pinned_apps:
        app_id = pinned.get('app_id') or ''
        wm_class = pinned.get('wm_class') or app_id or ''
        name = pinned.get('name') or app_id.capitalize() or 'App'
        
        is_running = False
        window_count = 0
        original_class = None
        
        wm_class_lower = wm_class.lower() if wm_class else ''
        app_id_lower = app_id.lower() if app_id else ''
        
        if wm_class_lower and wm_class_lower in running_classes:
            original_class = running_classes[wm_class_lower]
            is_running = True
            window_count = len(running_groups.get(original_class, []))
        elif app_id_lower and app_id_lower in running_classes:
            original_class = running_classes[app_id_lower]
            is_running = True
            window_count = len(running_groups.get(original_class, []))
        
        icon = get_nerd_icon(wm_class or app_id)
        is_focused = original_class and active_class == original_class.lower()
        
        if is_running:
            if is_focused:
                item = f'<span color="#89b4fa">{icon}</span>'
            else:
                item = f'<span color="#cdd6f4">{icon}</span>'
            if window_count > 1:
                item += f'<sup><span size="small" color="#f38ba8">{window_count}</span></sup>'
        else:
            item = f'<span color="#6c7086">{icon}</span>'
        
        items.append(item)
        status = "●" if is_running else "○"
        tooltip_lines.append(f"{status} {icon} {name}" + (f" ({window_count})" if window_count > 1 else ""))
    
    # Separator
    non_pinned = [c for c in running_groups.keys() if c.lower() not in pinned_ids]
    if pinned_apps and non_pinned:
        items.append('<span color="#45475a">│</span>')
    
    # Non-pinned running
    for wm_class in non_pinned:
        windows = running_groups[wm_class]
        window_count = len(windows)
        icon = get_nerd_icon(wm_class)
        is_focused = active_class == wm_class.lower()
        
        if is_focused:
            item = f'<span color="#89b4fa">{icon}</span>'
        else:
            item = f'<span color="#cdd6f4">{icon}</span>'
        if window_count > 1:
            item += f'<sup><span size="small" color="#f38ba8">{window_count}</span></sup>'
        
        items.append(item)
        tooltip_lines.append(f"● {icon} {wm_class}" + (f" ({window_count})" if window_count > 1 else ""))
    
    text = '  '.join(items) if items else ''
    tooltip = '\n'.join(tooltip_lines) if tooltip_lines else 'No windows'
    
    return json.dumps({'text': text, 'tooltip': tooltip, 'class': 'has-windows' if items else 'empty'})

# ==========================================
# HANDLE CLICKS
# ==========================================

def handle_click(button: str = '1'):
    if button == '1':
        subprocess.Popen(['rofi', '-show', 'window', '-window-format', '{c} {t}'])
    elif button == '2':
        active = get_active_window()
        if active and active.get('address'):
            subprocess.run(['hyprctl', 'dispatch', 'closewindow', f"address:{active['address']}"], capture_output=True)
    elif button == '3':
        subprocess.Popen(['rofi', '-show', 'drun'])

if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == 'click':
        button = sys.argv[2] if len(sys.argv) > 2 else '1'
        handle_click(button)
    else:
        print(render_taskbar())