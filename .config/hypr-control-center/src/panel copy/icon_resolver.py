#!/usr/bin/env python3
"""
Icon Resolver Module - With Nerd Font Fallback
Location: ~/.config/hypr-control-center/src/panel/icon_resolver.py
"""

import os
import re
import subprocess
from pathlib import Path
from typing import Dict, Optional, List, Tuple
from dataclasses import dataclass, field

import gi
gi.require_version('Gtk', '4.0')
from gi.repository import Gtk, Gdk, GdkPixbuf

# ==========================================
# NERD FONT ICON MAPPINGS
# ==========================================

NERD_FONT_ICONS = {
    # Browsers
    'firefox': '󰈹', 'mozilla': '󰈹', 'librewolf': '󰈹', 'floorp': '󰈹',
    'chrome': '󰊯', 'chromium': '󰊯', 'google-chrome': '󰊯',
    'brave': '󰖟', 'brave-browser': '󰖟', 'vivaldi': '󰖟',
    'edge': '󰇩', 'microsoft-edge': '󰇩', 'zen-browser': '󰈹', 'zen': '󰈹',
    
    # Terminals
    'kitty': '󰆍', 'alacritty': '󰆍', 'wezterm': '󰆍', 'foot': '󰆍',
    'terminal': '󰆍', 'gnome-terminal': '󰆍', 'konsole': '󰆍',
    'xterm': '󰆍', 'urxvt': '󰆍', 'terminator': '󰆍', 'tilix': '󰆍',
    
    # Code Editors
    'code': '󰨞', 'code-oss': '󰨞', 'vscode': '󰨞', 'vscodium': '󰨞',
    'visual-studio-code': '󰨞', 'sublime_text': '󰅳', 'sublime-text': '󰅳',
    'gedit': '󰏫', 'kate': '󰏫', 'mousepad': '󰏫',
    'neovim': '', 'nvim': '', 'vim': '', 'emacs': '󰯸',
    
    # IDEs
    'jetbrains': '󰬷', 'intellij': '󰬷', 'pycharm': '󰌠',
    'webstorm': '󰜈', 'phpstorm': '󰜈', 'android-studio': '󰀴',
    'unity': '󰚯', 'godot': '󰊖', 'unreal': '󰊖',
    
    # File Managers
    'thunar': '󰝰', 'nautilus': '󰝰', 'org.gnome.nautilus': '󰝰',
    'dolphin': '󰝰', 'pcmanfm': '󰝰', 'nemo': '󰝰', 'caja': '󰝰',
    
    # Media Players
    'spotify': '󰓇', 'vlc': '󰕼', 'mpv': '󰐹', 'celluloid': '󰐹',
    'totem': '󰐹', 'rhythmbox': '󰓃', 'audacious': '󰓃',
    
    # Communication
    'discord': '󰙯', 'telegram': '󰚩', 'telegram-desktop': '󰚩',
    'slack': '󰒱', 'teams': '󰊻', 'microsoft-teams': '󰊻',
    'zoom': '󰊻', 'skype': '󰒯', 'element': '󰭻', 'signal': '󰭻',
    
    # Gaming
    'steam': '󰓓', 'lutris': '󰺷', 'heroic': '󰺷', 'bottles': '󰺷',
    'retroarch': '󰊴', 'minecraft': '󰍳',
    
    # Graphics
    'gimp': '󰏘', 'gimp-2.10': '󰏘', 'inkscape': '󰕙', 'krita': '󰏘',
    'blender': '󰂫', 'darktable': '󰄄', 'eog': '󰋩', 'loupe': '󰋩',
    
    # Office
    'libreoffice': '󰈙', 'libreoffice-writer': '󰈙', 'libreoffice-calc': '󰈛',
    'evince': '󰈦', 'okular': '󰈦', 'zathura': '󰈦',
    
    # System Tools
    'settings': '󰒓', 'gnome-control-center': '󰒓', 'pavucontrol': '󰕾',
    'blueman': '󰂯', 'nm-connection-editor': '󰖩', 'gparted': '󰋊',
    'htop': '󰍛', 'btop': '󰍛', 'gnome-system-monitor': '󰍛',
    
    # Notes & Productivity
    'obsidian': '󰎚', 'notion': '󰎚', 'standard notes': '󰎚',
    'standardnotes': '󰎚', 'simplenote': '󰎚', 'joplin': '󰎚',
    'logseq': '󰎚', 'typora': '󰎚', 'marktext': '󰎚',
    
    # Utilities
    'flameshot': '󰹑', 'spectacle': '󰹑', 'obs': '󰑋', 'obs-studio': '󰑋',
    'kdenlive': '󰑋', 'file-roller': '󰀼', 'ark': '󰀼',
    
    # Others
    'transmission': '󰇚', 'qbittorrent': '󰇚', 'virt-manager': '󰍺',
    'virtualbox': '󰍺', 'docker': '󰡨', 'keepassxc': '󰌋',
    'bitwarden': '󰌋', 'thunderbird': '󰇮', 'evolution': '󰇮',
    
    # Hyprland specific
    'hyprland': '󰖌', 'waybar': '󰖌', 'rofi': '󰍉', 'wofi': '󰍉',
}

DEFAULT_NERD_ICON = '󰣆'


@dataclass
class DesktopEntry:
    """Parsed .desktop file entry"""
    name: str
    icon: str
    exec_cmd: str
    wm_class: str
    desktop_file: str
    generic_name: str = ""
    categories: List[str] = field(default_factory=list)
    
    @property
    def app_id(self) -> str:
        return Path(self.desktop_file).stem


class IconResolver:
    """Resolves application icons with Nerd Font fallback"""
    
    def __init__(self):
        self._entries_by_class: Dict[str, DesktopEntry] = {}
        self._entries_by_name: Dict[str, DesktopEntry] = {}
        self._icon_path_cache: Dict[Tuple[str, int], Optional[str]] = {}
        
        self._class_aliases: Dict[str, str] = {
            'code - oss': 'code-oss', 'code': 'visual-studio-code',
            'code-oss': 'code-oss', 'navigator': 'firefox',
            'telegram-desktop': 'telegram', 'telegramdesktop': 'telegram',
            'standard notes': 'standard-notes', 'standardnotes': 'standard-notes',
        }
        
        self._desktop_dirs = [
            Path("/usr/share/applications"),
            Path("/usr/local/share/applications"),
            Path.home() / ".local/share/applications",
            Path("/var/lib/flatpak/exports/share/applications"),
            Path.home() / ".local/share/flatpak/exports/share/applications",
        ]
        
        self._icon_dirs = [
            Path.home() / ".local/share/icons",
            Path.home() / ".icons",
            Path("/usr/share/icons"),
            Path("/usr/share/pixmaps"),
        ]
        
        self._icon_theme = self._get_current_icon_theme()
        self._icon_themes = [self._icon_theme, "Papirus", "Papirus-Dark", "Adwaita", "hicolor"]
        self._icon_sizes = ['48x48', '64x64', '32x32', '128x128', '256x256']
        
        self._load_desktop_entries()
        print(f"[IconResolver] Loaded {len(self._entries_by_class)} entries, theme: {self._icon_theme}")
    
    def _get_current_icon_theme(self) -> str:
        try:
            result = subprocess.run(
                ['gsettings', 'get', 'org.gnome.desktop.interface', 'icon-theme'],
                capture_output=True, text=True, timeout=2
            )
            if result.returncode == 0:
                return result.stdout.strip().strip("'\"")
        except:
            pass
        return "Papirus"
    
    def _load_desktop_entries(self):
        for desktop_dir in self._desktop_dirs:
            if not desktop_dir.exists():
                continue
            try:
                for desktop_file in desktop_dir.glob("*.desktop"):
                    try:
                        entry = self._parse_desktop_file(desktop_file)
                        if entry:
                            if entry.wm_class:
                                self._entries_by_class[entry.wm_class.lower()] = entry
                            self._entries_by_name[entry.name.lower()] = entry
                            app_id = desktop_file.stem.lower()
                            if app_id not in self._entries_by_class:
                                self._entries_by_class[app_id] = entry
                    except:
                        pass
            except:
                pass
    
    def _parse_desktop_file(self, desktop_file: Path) -> Optional[DesktopEntry]:
        try:
            with open(desktop_file, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
        except:
            return None
        
        if 'NoDisplay=true' in content:
            return None
        
        def get_field(field):
            match = re.search(rf'^{field}=(.+)$', content, re.MULTILINE)
            return match.group(1).strip() if match else ''
        
        name = get_field('Name')
        if not name:
            return None
        
        return DesktopEntry(
            name=name,
            icon=get_field('Icon'),
            exec_cmd=re.sub(r'%[UuFfDdNnickvm]', '', get_field('Exec')).strip(),
            wm_class=get_field('StartupWMClass'),
            desktop_file=str(desktop_file),
            generic_name=get_field('GenericName'),
            categories=get_field('Categories').split(';') if get_field('Categories') else []
        )
    
    # ==========================================
    # PUBLIC API
    # ==========================================
    
    def get_nerd_icon(self, wm_class: str) -> str:
        """Get Nerd Font icon for a window class"""
        if not wm_class:
            return DEFAULT_NERD_ICON
        
        wm_class_lower = wm_class.lower()
        
        if wm_class_lower in NERD_FONT_ICONS:
            return NERD_FONT_ICONS[wm_class_lower]
        
        for key, icon in NERD_FONT_ICONS.items():
            if key in wm_class_lower or wm_class_lower in key:
                return icon
        
        return DEFAULT_NERD_ICON
    
    def get_icon_for_class(self, wm_class: str) -> str:
        """Get icon name for a window class"""
        if not wm_class:
            return "application-x-executable"
        
        wm_class_lower = wm_class.lower()
        
        if wm_class_lower in self._class_aliases:
            alias = self._class_aliases[wm_class_lower]
            if alias in self._entries_by_class:
                return self._entries_by_class[alias].icon or alias
            return alias
        
        if wm_class_lower in self._entries_by_class:
            return self._entries_by_class[wm_class_lower].icon or wm_class_lower
        
        if wm_class_lower in self._entries_by_name:
            return self._entries_by_name[wm_class_lower].icon or wm_class_lower
        
        for key, entry in self._entries_by_class.items():
            if wm_class_lower in key or key in wm_class_lower:
                return entry.icon or key
        
        return wm_class_lower
    
    def get_icon_path(self, icon_name: str, size: int = 48) -> Optional[str]:
        """Get actual file path for an icon (PNG ONLY)"""
        if not icon_name:
            return None
        
        cache_key = (icon_name, size)
        if cache_key in self._icon_path_cache:
            return self._icon_path_cache[cache_key]
        
        if icon_name.startswith('/') and icon_name.endswith('.png') and os.path.exists(icon_name):
            self._icon_path_cache[cache_key] = icon_name
            return icon_name
        
        path = self._search_icon_themes_png(icon_name)
        self._icon_path_cache[cache_key] = path
        return path
    
    def _search_icon_themes_png(self, icon_name: str) -> Optional[str]:
        """Search icon themes for PNG icon only"""
        for icon_dir in self._icon_dirs:
            if not icon_dir.exists():
                continue
            for theme in self._icon_themes:
                theme_dir = icon_dir / theme
                if not theme_dir.exists():
                    continue
                for size_dir in self._icon_sizes:
                    for category in ['apps', 'categories']:
                        apps_dir = theme_dir / size_dir / category
                        if apps_dir.exists():
                            icon_file = apps_dir / f"{icon_name}.png"
                            if icon_file.exists() and '-symbolic' not in str(icon_file):
                                return str(icon_file)
        
        pixmaps = Path("/usr/share/pixmaps")
        if pixmaps.exists():
            icon_file = pixmaps / f"{icon_name}.png"
            if icon_file.exists():
                return str(icon_file)
        
        return None
    
    def get_desktop_entry(self, wm_class: str) -> Optional[DesktopEntry]:
        """Get full desktop entry for a window class"""
        if not wm_class:
            return None
        wm_class_lower = wm_class.lower()
        if wm_class_lower in self._class_aliases:
            wm_class_lower = self._class_aliases[wm_class_lower]
        return self._entries_by_class.get(wm_class_lower) or self._entries_by_name.get(wm_class_lower)
    
    def create_icon_image(self, wm_class: str, size: int = 32, use_nerd_fallback: bool = True) -> Gtk.Widget:
        """Create a GTK widget for an app icon with Nerd Font fallback"""
        icon_name = self.get_icon_for_class(wm_class)
        icon_path = self.get_icon_path(icon_name, size)
        
        if icon_path and os.path.exists(icon_path):
            try:
                pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(icon_path, size, size, True)
                image = Gtk.Image.new_from_pixbuf(pixbuf)
                image.set_pixel_size(size)
                return image
            except:
                pass
        
        image = Gtk.Image.new_from_icon_name(icon_name)
        image.set_pixel_size(size)
        
        display = Gdk.Display.get_default()
        if display:
            theme = Gtk.IconTheme.get_for_display(display)
            if theme.has_icon(icon_name):
                return image
        
        if use_nerd_fallback:
            nerd_icon = self.get_nerd_icon(wm_class)
            label = Gtk.Label(label=nerd_icon)
            label.add_css_class("nerd-icon")
            label.set_markup(f'<span font_size="{int(size * 1000)}">{nerd_icon}</span>')
            return label
        
        return image
    
    def reload(self):
        """Reload all desktop entries"""
        self._entries_by_class.clear()
        self._entries_by_name.clear()
        self._icon_path_cache.clear()
        self._load_desktop_entries()


# ==========================================
# SINGLETON & CONVENIENCE FUNCTIONS
# ==========================================

_resolver_instance: Optional[IconResolver] = None

def get_resolver() -> IconResolver:
    global _resolver_instance
    if _resolver_instance is None:
        _resolver_instance = IconResolver()
    return _resolver_instance

def get_icon_for_class(wm_class: str) -> str:
    return get_resolver().get_icon_for_class(wm_class)

def get_icon_path(icon_name: str, size: int = 48) -> Optional[str]:
    return get_resolver().get_icon_path(icon_name, size)

def get_nerd_icon(wm_class: str) -> str:
    return get_resolver().get_nerd_icon(wm_class)

def create_icon_image(wm_class: str, size: int = 32) -> Gtk.Widget:
    return get_resolver().create_icon_image(wm_class, size)


# ==========================================
# TEST / DEMO
# ==========================================

def demo():
    print("""
╔══════════════════════════════════════════════════════════╗
║       ICON RESOLVER (with Nerd Font Fallback)            ║
╚══════════════════════════════════════════════════════════╝
""")
    
    resolver = IconResolver()
    
    test_classes = [
        "firefox", "code-oss", "kitty", "thunar", "steam",
        "discord", "spotify", "Standard Notes", "chromium",
        "nautilus", "vlc", "obs", "unknown-app",
    ]
    
    print(f"  {'WM_CLASS':<20} {'ICON':<20} {'PNG':<5} {'NERD'}")
    print("  " + "-"*60)
    
    for wm_class in test_classes:
        icon_name = resolver.get_icon_for_class(wm_class)
        icon_path = resolver.get_icon_path(icon_name, 48)
        nerd_icon = resolver.get_nerd_icon(wm_class)
        has_png = "✓" if icon_path else "✗"
        print(f"  {wm_class:<20} {icon_name:<20} {has_png:<5} {nerd_icon}")
    
    print(f"\n  Theme: {resolver._icon_theme}")
    print(f"  Nerd icons: {len(NERD_FONT_ICONS)}")


if __name__ == "__main__":
    demo()