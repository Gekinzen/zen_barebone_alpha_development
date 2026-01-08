#!/usr/bin/env python3
"""
Get application icon path from GTK icon theme
Returns COLORED PNG icon path (strictly avoids SVG for compatibility)
"""

import sys
import os
import subprocess

# Try GTK3 first, fallback to basic search
try:
    import gi
    gi.require_version('Gtk', '3.0')
    from gi.repository import Gtk
    HAS_GTK = True
except:
    HAS_GTK = False

def get_icon_with_gtk(app_id, size=48):
    """Get icon using GTK IconTheme - PNG ONLY (no SVG)"""
    if not HAS_GTK:
        return None
    
    icon_theme = Gtk.IconTheme.get_default()
    
    # App name variations to try
    variations = [
        app_id,
        app_id.lower(),
        app_id.replace('_', '-'),
        app_id.replace(' ', '-'),
        app_id.replace('-', ''),  # Try without dashes
    ]
    
    # Extra variations for specific apps
    if 'code' in app_id.lower():
        variations.extend([
            'visual-studio-code',
            'com.visualstudio.code',
            'vscode',
            'code'
        ])
    
    if 'kitty' in app_id.lower():
        variations.extend([
            'kitty',
            'org.codeberg.dnkl.kitty'
        ])
    
    # Special mappings for common apps
    special_maps = {
        'firefox': 'firefox',
        'org.mozilla.firefox': 'firefox',
        'google-chrome': 'google-chrome',
        'chrome': 'google-chrome',
        'chromium': 'chromium-browser',
        'chromium-browser': 'chromium-browser',
        'code': 'visual-studio-code',
        'code-oss': 'com.visualstudio.code',  # Try this first
        'vscode': 'visual-studio-code',
        'org.gnome.nautilus': 'org.gnome.Nautilus',
        'nautilus': 'org.gnome.Nautilus',
        'thunar': 'Thunar',
        'discord': 'discord',
        'telegram-desktop': 'telegram',
        'telegram': 'telegram',
        'spotify': 'spotify-client',
        'kitty': 'kitty',  # Should work but add fallback
        'alacritty': 'Alacritty',
        'obs': 'com.obsproject.Studio',
        'gimp': 'org.gimp.GIMP',
        'gimp-2.10': 'org.gimp.GIMP',
        'steam': 'steam',
        'vlc': 'vlc',
    }
    
    app_lower = app_id.lower()
    if app_lower in special_maps:
        variations.insert(0, special_maps[app_lower])
    
    # Try to find PNG icon ONLY (avoid SVG for GTK compatibility)
    for name in variations:
        try:
            icon_info = icon_theme.lookup_icon(
                name, 
                size, 
                Gtk.IconLookupFlags.FORCE_SIZE | Gtk.IconLookupFlags.FORCE_REGULAR
            )
            
            if icon_info:
                icon_path = icon_info.get_filename()
                
                # STRICT: Only accept PNG files, skip SVG and symbolic
                if icon_path and icon_path.endswith('.png') and '-symbolic' not in icon_path:
                    return icon_path
        except:
            continue
    
    return None

def find_icon_manual(app_id):
    """Manual search in common icon directories - PNG ONLY"""
    # Get icon theme
    try:
        result = subprocess.run(
            ['gsettings', 'get', 'org.gnome.desktop.interface', 'icon-theme'],
            capture_output=True, text=True, timeout=2
        )
        icon_theme = result.stdout.strip().strip("'\"") if result.returncode == 0 else "Papirus"
    except:
        icon_theme = "Papirus"
    
    app_lower = app_id.lower()
    
    # Special name mappings
    name_map = {
        'firefox': 'firefox',
        'chrome': 'google-chrome',
        'chromium': 'chromium',
        'code': 'visual-studio-code',
        'code-oss': 'visual-studio-code',
        'vscode': 'visual-studio-code',
        'nautilus': 'org.gnome.Nautilus',
        'thunar': 'Thunar',
        'discord': 'discord',
        'telegram': 'telegram',
        'spotify': 'spotify-client',
        'kitty': 'kitty',
        'alacritty': 'Alacritty',
    }
    
    search_name = name_map.get(app_lower, app_lower)
    
    # Icon search paths
    search_paths = [
        f"/usr/share/icons/{icon_theme}",
        f"{os.path.expanduser('~')}/.local/share/icons/{icon_theme}",
        f"{os.path.expanduser('~')}/.icons/{icon_theme}",
        "/usr/share/icons/hicolor",
        "/usr/share/pixmaps",
    ]
    
    # Sizes to check (prefer larger for better quality)
    sizes = ['48x48', '64x64', '32x32', '128x128']
    
    for base_path in search_paths:
        if not os.path.isdir(base_path):
            continue
        
        for size in sizes:
            for category in ['apps', 'categories', 'places']:
                icon_dir = os.path.join(base_path, size, category)
                
                if not os.path.isdir(icon_dir):
                    continue
                
                # ONLY PNG files (no SVG)
                icon_file = os.path.join(icon_dir, f"{search_name}.png")
                
                if os.path.isfile(icon_file) and '-symbolic' not in icon_file:
                    return icon_file
    
    return None

def get_icon_from_desktop(app_id):
    """Get icon from .desktop file - PNG ONLY"""
    app_lower = app_id.lower()
    
    # Search paths
    search_dirs = [
        os.path.expanduser('~/.local/share/applications'),
        '/usr/share/applications',
        '/usr/local/share/applications',
        '/var/lib/flatpak/exports/share/applications',
        os.path.expanduser('~/.local/share/flatpak/exports/share/applications'),
    ]
    
    # Try to find .desktop file
    desktop_file = None
    for search_dir in search_dirs:
        if not os.path.isdir(search_dir):
            continue
        
        try:
            for filename in os.listdir(search_dir):
                if app_lower in filename.lower() and filename.endswith('.desktop'):
                    desktop_file = os.path.join(search_dir, filename)
                    break
        except:
            continue
        
        if desktop_file:
            break
    
    if not desktop_file:
        return None
    
    # Parse .desktop file for Icon= line
    try:
        with open(desktop_file, 'r', encoding='utf-8') as f:
            for line in f:
                if line.startswith('Icon='):
                    icon_name = line.split('=', 1)[1].strip()
                    
                    # If it's a full path to PNG
                    if os.path.isfile(icon_name) and icon_name.endswith('.png') and '-symbolic' not in icon_name:
                        return icon_name
                    
                    # Otherwise, try to find PNG in icon theme
                    if HAS_GTK:
                        icon_theme = Gtk.IconTheme.get_default()
                        try:
                            icon_info = icon_theme.lookup_icon(
                                icon_name, 
                                48,
                                Gtk.IconLookupFlags.FORCE_SIZE | Gtk.IconLookupFlags.FORCE_REGULAR
                            )
                            if icon_info:
                                icon_path = icon_info.get_filename()
                                # ONLY PNG
                                if icon_path and icon_path.endswith('.png') and '-symbolic' not in icon_path:
                                    return icon_path
                        except:
                            pass
                    
                    break
    except:
        pass
    
    return None

def get_fallback_nerd_icon(app_id):
    """Get Nerd Font fallback icon"""
    app_lower = app_id.lower()
    
    icons = {
        'firefox': '󰈹',
        'mozilla': '󰈹',
        'chrome': '󰊯',
        'chromium': '󰊯',
        'google-chrome': '󰊯',
        'brave': '󰖟',
        'vivaldi': '󰖟',
        'opera': '󰖟',
        'edge': '󰇩',
        'code': '󰨞',
        'code-oss': '󰨞',
        'vscode': '󰨞',
        'vscodium': '󰨞',
        'kitty': '󰆍',
        'alacritty': '󰆍',
        'wezterm': '󰆍',
        'foot': '󰆍',
        'terminal': '󰆍',
        'thunar': '󰝰',
        'nautilus': '󰝰',
        'dolphin': '󰝰',
        'pcmanfm': '󰝰',
        'spotify': '󰓇',
        'discord': '󰙯',
        'telegram': '󰚩',
        'slack': '󰒱',
        'vlc': '󰕼',
        'mpv': '󰐹',
        'gimp': '󰏘',
        'inkscape': '󰕙',
        'blender': '󰂫',
        'obs': '󰑋',
        'steam': '󰓓',
        'lutris': '󰺷',
    }
    
    for key, icon in icons.items():
        if key in app_lower:
            return icon
    
    return '󰣆'  # Default fallback

def main():
    if len(sys.argv) < 2:
        print('󰣆')
        return
    
    app_id = sys.argv[1]
    
    # Try multiple methods in order - PNG ONLY
    # 1. GTK IconTheme (most reliable for PNG icons)
    icon_path = get_icon_with_gtk(app_id)
    if icon_path:
        print(f"file://{icon_path}")
        return
    
    # 2. Desktop file parsing
    icon_path = get_icon_from_desktop(app_id)
    if icon_path:
        print(f"file://{icon_path}")
        return
    
    # 3. Manual search in icon directories
    icon_path = find_icon_manual(app_id)
    if icon_path:
        print(f"file://{icon_path}")
        return
    
    # 4. Fallback to Nerd Font
    print(get_fallback_nerd_icon(app_id))

if __name__ == '__main__':
    main()