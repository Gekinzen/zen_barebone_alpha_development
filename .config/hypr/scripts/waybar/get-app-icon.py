#!/usr/bin/env python3
"""
Get application icon path from GTK icon theme
Returns COLORED PNG icon path (not symbolic/monochrome)
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

def get_icon_with_gtk(app_id, size=64):  # ← INCREASED from 48 to 64
    """Get icon using GTK IconTheme - COLORED icons only"""
    if not HAS_GTK:
        return None
    
    icon_theme = Gtk.IconTheme.get_default()
    
    # App name variations to try
    variations = [
        app_id,
        app_id.lower(),
        app_id.replace('_', '-'),
        app_id.replace(' ', '-'),
    ]
    
    # Special mappings for common apps
    special_maps = {
        'firefox': 'firefox',
        'org.mozilla.firefox': 'firefox',
        'google-chrome': 'google-chrome',
        'chrome': 'google-chrome',
        'chromium': 'chromium-browser',
        'chromium-browser': 'chromium-browser',
        'code': 'visual-studio-code',
        'vscode': 'visual-studio-code',
        'org.gnome.nautilus': 'org.gnome.Nautilus',
        'nautilus': 'org.gnome.Nautilus',
        'thunar': 'Thunar',
        'discord': 'discord',
        'telegram-desktop': 'telegram',
        'telegram': 'telegram',
        'spotify': 'spotify-client',
        'kitty': 'kitty',
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
    
    # Try to find COLORED icon (avoid -symbolic)
    for name in variations:
        try:
            # Use FORCE_SIZE to get actual colored icon, not symbolic
            icon_info = icon_theme.lookup_icon(
                name, 
                size, 
                Gtk.IconLookupFlags.FORCE_SIZE | Gtk.IconLookupFlags.FORCE_REGULAR
            )
            
            if icon_info:
                icon_path = icon_info.get_filename()
                
                # Skip symbolic icons (they're monochrome/white)
                if icon_path and '-symbolic' not in icon_path:
                    # Prefer PNG over SVG (better compatibility)
                    if icon_path.endswith('.png'):
                        return icon_path
                    elif icon_path.endswith('.svg'):
                        # Try to find PNG version first
                        png_path = icon_path.replace('.svg', '.png')
                        if os.path.exists(png_path):
                            return png_path
                        return icon_path
        except:
            continue
    
    return None

def get_icon_from_desktop(app_id):
    """Get icon from .desktop file"""
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
                    
                    # If it's a full path and exists
                    if os.path.isfile(icon_name):
                        # Skip symbolic icons
                        if '-symbolic' not in icon_name:
                            return icon_name
                    
                    # Otherwise, try to find it in icon theme
                    if HAS_GTK:
                        icon_theme = Gtk.IconTheme.get_default()
                        try:
                            icon_info = icon_theme.lookup_icon(
                                icon_name, 
                                64,  # ← INCREASED
                                Gtk.IconLookupFlags.FORCE_SIZE | Gtk.IconLookupFlags.FORCE_REGULAR
                            )
                            if icon_info:
                                icon_path = icon_info.get_filename()
                                if icon_path and '-symbolic' not in icon_path:
                                    return icon_path
                        except:
                            pass
                    
                    break
    except:
        pass
    
    return None

def find_icon_manual(app_id):
    """Manual search in common icon directories for COLORED icons"""
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
    
    # Sizes to check (prefer larger for better quality) - INCREASED SIZES
    sizes = ['64x64', '48x48', '32x32', 'scalable']
    
    for base_path in search_paths:
        if not os.path.isdir(base_path):
            continue
        
        for size in sizes:
            for category in ['apps', 'categories', 'places']:
                icon_dir = os.path.join(base_path, size, category)
                
                if not os.path.isdir(icon_dir):
                    continue
                
                # Try PNG first (avoid symbolic)
                for ext in ['.png', '.svg']:
                    icon_file = os.path.join(icon_dir, f"{search_name}{ext}")
                    
                    if os.path.isfile(icon_file) and '-symbolic' not in icon_file:
                        return icon_file
    
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
    
    # Try multiple methods in order
    # 1. GTK IconTheme (most reliable for colored icons)
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