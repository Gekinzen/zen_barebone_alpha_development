"""
ThemeManager - Icon Theme and Color Management
===============================================

Resolves app icons from current system icon theme.
Supports:
- GTK icon theme (Papirus, Tela, etc.)
- Fallback to Nerd Fonts
- Custom icon paths
- Icon caching for performance
"""

import os
import subprocess
from pathlib import Path
from typing import Dict, Optional, List, Tuple
from dataclasses import dataclass
import threading
import json

try:
    import gi
    gi.require_version('Gtk', '4.0')
    from gi.repository import Gtk, Gio, GdkPixbuf
    HAS_GTK = True
except ImportError:
    HAS_GTK = False


@dataclass
class IconInfo:
    """Information about a resolved icon"""
    path: Optional[str] = None
    is_symbolic: bool = False
    size: int = 24
    source: str = "unknown"  # theme, fallback, nerd, custom


class ThemeManager:
    """
    Manages theme icons and colors for ZenPyBar.
    
    Icon Resolution Priority:
    1. Custom icons in ~/.config/hypr-control-center/icons/
    2. Current GTK icon theme (respects theme settings)
    3. Hardcoded app-specific paths
    4. Nerd Font fallback
    """
    
    # Common icon search paths
    ICON_PATHS = [
        Path.home() / ".config/hypr-control-center/icons",
        Path.home() / ".local/share/icons",
        Path.home() / ".icons",
        Path("/usr/share/icons"),
        Path("/usr/share/pixmaps"),
        Path("/usr/share/applications"),  # For .desktop icon references
    ]
    
    # Nerd Font icon fallbacks
    NERD_ICONS = {
        # Browsers
        'firefox': '',
        'firefox-developer-edition': '',
        'chromium': '',
        'google-chrome': '',
        'brave': '󰖟',
        'vivaldi': '󰖟',
        'microsoft-edge': '󰇩',
        
        # Terminals
        'kitty': '',
        'alacritty': '',
        'foot': '',
        'wezterm': '',
        'konsole': '',
        'gnome-terminal': '',
        'xterm': '',
        
        # Development
        'code': '󰨞',
        'code-oss': '󰨞',
        'vscodium': '󰨞',
        'sublime-text': '',
        'neovim': '',
        'vim': '',
        'emacs': '',
        'jetbrains-idea': '',
        'jetbrains-pycharm': '',
        'jetbrains-clion': '',
        
        # Files & Editors
        'nautilus': '',
        'thunar': '',
        'dolphin': '',
        'pcmanfm': '',
        'nemo': '',
        'gedit': '',
        'kate': '',
        'mousepad': '',
        
        # Media
        'spotify': '',
        'vlc': '󰕼',
        'mpv': '',
        'rhythmbox': '󰎆',
        'audacious': '󰎆',
        'clementine': '󰎆',
        
        # Communication
        'discord': '󰙯',
        'slack': '󰒱',
        'telegram-desktop': '',
        'signal-desktop': '󰭹',
        'element': '',
        'teams': '󰊻',
        'zoom': '',
        
        # System
        'gnome-control-center': '',
        'systemsettings': '',
        'pavucontrol': '󰕾',
        'blueman-manager': '',
        'nm-connection-editor': '󰖩',
        
        # Graphics
        'gimp': '',
        'inkscape': '',
        'blender': '󰂫',
        'krita': '',
        
        # Office
        'libreoffice-writer': '󰈙',
        'libreoffice-calc': '󰧷',
        'libreoffice-impress': '󰐩',
        
        # Games
        'steam': '',
        'lutris': '',
        
        # Default
        'default': '󰣆',
    }
    
    # Known icon name mappings (wm_class -> icon name)
    ICON_NAME_MAP = {
        'firefox': 'firefox',
        'Firefox Developer Edition': 'firefox-developer-edition',
        'google-chrome': 'google-chrome',
        'Google-chrome': 'google-chrome',
        'chromium': 'chromium',
        'Brave-browser': 'brave-browser',
        'code': 'visual-studio-code',
        'Code': 'visual-studio-code',
        'code-oss': 'code-oss',
        'kitty': 'kitty',
        'Alacritty': 'Alacritty',
        'foot': 'foot',
        'org.gnome.Nautilus': 'org.gnome.Nautilus',
        'thunar': 'thunar',
        'Thunar': 'thunar',
        'discord': 'discord',
        'Discord': 'discord',
        'Spotify': 'spotify',
        'spotify': 'spotify',
        'vlc': 'vlc',
        'mpv': 'mpv',
        'Gimp-2.10': 'gimp',
        'steam': 'steam',
        'Steam': 'steam',
        'obs': 'com.obsproject.Studio',
        'telegram-desktop': 'telegram',
        'TelegramDesktop': 'telegram',
    }
    
    _instance = None
    _lock = threading.Lock()
    
    def __new__(cls, *args, **kwargs):
        """Singleton pattern"""
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = super().__new__(cls)
                    cls._instance._initialized = False
        return cls._instance
    
    def __init__(self):
        if self._initialized:
            return
        
        self._icon_cache: Dict[str, IconInfo] = {}
        self._current_theme: Optional[str] = None
        self._icon_theme: Optional[Gtk.IconTheme] = None
        
        # Detect current icon theme
        self._detect_icon_theme()
        
        # Initialize GTK icon theme if available
        if HAS_GTK:
            self._init_gtk_theme()
        
        self._initialized = True
        print(f"[ThemeManager] ✅ Initialized with theme: {self._current_theme}")
    
    def _detect_icon_theme(self) -> None:
        """Detect current GTK icon theme"""
        # Try gsettings first
        try:
            result = subprocess.run(
                ['gsettings', 'get', 'org.gnome.desktop.interface', 'icon-theme'],
                capture_output=True, text=True, timeout=2
            )
            if result.returncode == 0:
                self._current_theme = result.stdout.strip().strip("'\"")
                return
        except Exception:
            pass
        
        # Try reading GTK settings
        gtk_settings = Path.home() / ".config/gtk-4.0/settings.ini"
        if gtk_settings.exists():
            try:
                content = gtk_settings.read_text()
                for line in content.split('\n'):
                    if line.startswith('gtk-icon-theme-name'):
                        self._current_theme = line.split('=')[1].strip()
                        return
            except Exception:
                pass
        
        # Fallback to Adwaita
        self._current_theme = "Adwaita"
    
    def _init_gtk_theme(self) -> None:
        """Initialize GTK IconTheme"""
        if not HAS_GTK:
            return
        
        try:
            display = Gtk.Settings.get_default()
            if display:
                self._icon_theme = Gtk.IconTheme.get_for_display(
                    display.get_property('gtk-display') if hasattr(display, 'get_property') else None
                )
        except Exception as e:
            print(f"[ThemeManager] ⚠️ GTK theme init error: {e}")
    
    # ═══════════════════════════════════════════════════════════════════════
    # ICON RESOLUTION
    # ═══════════════════════════════════════════════════════════════════════
    
    def get_icon_path(self, app_id: str, size: int = 24) -> Optional[str]:
        """
        Get icon path for an application.
        
        Args:
            app_id: Application ID or wm_class
            size: Desired icon size
            
        Returns:
            Path to icon file or None
        """
        cache_key = f"{app_id}:{size}"
        
        # Check cache
        if cache_key in self._icon_cache:
            return self._icon_cache[cache_key].path
        
        # Normalize app_id
        normalized = self._normalize_app_id(app_id)
        
        # Search in order of priority
        icon_info = None
        
        # 1. Custom icons
        icon_info = self._find_custom_icon(normalized, size)
        
        # 2. Theme icons
        if not icon_info:
            icon_info = self._find_theme_icon(normalized, size)
        
        # 3. Hardcoded paths
        if not icon_info:
            icon_info = self._find_hardcoded_icon(normalized, size)
        
        # 4. Desktop file icons
        if not icon_info:
            icon_info = self._find_desktop_icon(normalized, size)
        
        # Cache result
        if icon_info:
            self._icon_cache[cache_key] = icon_info
        else:
            self._icon_cache[cache_key] = IconInfo(source="none")
        
        return icon_info.path if icon_info else None
    
    def _normalize_app_id(self, app_id: str) -> str:
        """Normalize app ID for icon search"""
        # Use mapping if available
        if app_id in self.ICON_NAME_MAP:
            return self.ICON_NAME_MAP[app_id]
        
        # Lowercase and clean
        normalized = app_id.lower()
        normalized = normalized.replace(' ', '-')
        normalized = normalized.replace('_', '-')
        
        return normalized
    
    def _find_custom_icon(self, app_id: str, size: int) -> Optional[IconInfo]:
        """Find icon in custom icons directory"""
        custom_dir = Path.home() / ".config/hypr-control-center/icons"
        if not custom_dir.exists():
            return None
        
        # Check for exact match
        for ext in ['.png', '.svg', '.xpm']:
            icon_path = custom_dir / f"{app_id}{ext}"
            if icon_path.exists():
                return IconInfo(
                    path=str(icon_path),
                    is_symbolic=False,
                    size=size,
                    source="custom"
                )
        
        return None
    
    def _find_theme_icon(self, app_id: str, size: int) -> Optional[IconInfo]:
        """Find icon in current GTK icon theme"""
        if not self._current_theme:
            return None
        
        # Search paths for current theme
        theme_paths = [
            Path.home() / ".local/share/icons" / self._current_theme,
            Path.home() / ".icons" / self._current_theme,
            Path("/usr/share/icons") / self._current_theme,
        ]
        
        # Icon subdirectories to search (in order of preference)
        size_dirs = [
            f"{size}x{size}/apps",
            f"scalable/apps",
            f"48x48/apps",
            f"32x32/apps",
            f"24x24/apps",
            f"22x22/apps",
            f"16x16/apps",
            "apps",
        ]
        
        # Search for icon
        for theme_path in theme_paths:
            if not theme_path.exists():
                continue
            
            for size_dir in size_dirs:
                icon_dir = theme_path / size_dir
                if not icon_dir.exists():
                    continue
                
                for ext in ['.svg', '.png', '.xpm']:
                    icon_path = icon_dir / f"{app_id}{ext}"
                    if icon_path.exists():
                        return IconInfo(
                            path=str(icon_path),
                            is_symbolic='-symbolic' in app_id,
                            size=size,
                            source="theme"
                        )
        
        # Try hicolor fallback
        for hicolor_path in [
            Path("/usr/share/icons/hicolor"),
            Path.home() / ".local/share/icons/hicolor",
        ]:
            if not hicolor_path.exists():
                continue
            
            for size_dir in size_dirs:
                icon_dir = hicolor_path / size_dir
                if not icon_dir.exists():
                    continue
                
                for ext in ['.svg', '.png', '.xpm']:
                    icon_path = icon_dir / f"{app_id}{ext}"
                    if icon_path.exists():
                        return IconInfo(
                            path=str(icon_path),
                            is_symbolic=False,
                            size=size,
                            source="hicolor"
                        )
        
        return None
    
    def _find_hardcoded_icon(self, app_id: str, size: int) -> Optional[IconInfo]:
        """Find icon in common hardcoded paths"""
        # Common paths
        search_paths = [
            Path("/usr/share/pixmaps"),
            Path("/usr/share/icons"),
        ]
        
        for search_path in search_paths:
            if not search_path.exists():
                continue
            
            for ext in ['.png', '.svg', '.xpm']:
                icon_path = search_path / f"{app_id}{ext}"
                if icon_path.exists():
                    return IconInfo(
                        path=str(icon_path),
                        is_symbolic=False,
                        size=size,
                        source="hardcoded"
                    )
        
        return None
    
    def _find_desktop_icon(self, app_id: str, size: int) -> Optional[IconInfo]:
        """Find icon from .desktop file"""
        desktop_paths = [
            Path.home() / ".local/share/applications",
            Path("/usr/share/applications"),
        ]
        
        for desktop_path in desktop_paths:
            if not desktop_path.exists():
                continue
            
            desktop_file = desktop_path / f"{app_id}.desktop"
            if not desktop_file.exists():
                # Try variations
                for suffix in ['', '-browser', '-app']:
                    alt_file = desktop_path / f"{app_id}{suffix}.desktop"
                    if alt_file.exists():
                        desktop_file = alt_file
                        break
            
            if desktop_file.exists():
                try:
                    content = desktop_file.read_text()
                    for line in content.split('\n'):
                        if line.startswith('Icon='):
                            icon_name = line.split('=')[1].strip()
                            
                            # If it's a path, return directly
                            if '/' in icon_name and Path(icon_name).exists():
                                return IconInfo(
                                    path=icon_name,
                                    is_symbolic=False,
                                    size=size,
                                    source="desktop"
                                )
                            
                            # Otherwise, search for it as icon name
                            return self._find_theme_icon(icon_name, size)
                except Exception:
                    pass
        
        return None
    
    # ═══════════════════════════════════════════════════════════════════════
    # NERD FONT FALLBACK
    # ═══════════════════════════════════════════════════════════════════════
    
    def get_nerd_icon(self, app_id: str) -> str:
        """Get Nerd Font icon for app (fallback)"""
        normalized = app_id.lower()
        
        # Direct match
        if normalized in self.NERD_ICONS:
            return self.NERD_ICONS[normalized]
        
        # Partial match
        for key, icon in self.NERD_ICONS.items():
            if key in normalized or normalized in key:
                return icon
        
        return self.NERD_ICONS['default']
    
    # ═══════════════════════════════════════════════════════════════════════
    # GTK IMAGE CREATION
    # ═══════════════════════════════════════════════════════════════════════
    
    def create_icon_widget(self, app_id: str, size: int = 24) -> 'Gtk.Widget':
        """
        Create GTK widget for app icon.
        Returns Gtk.Image if icon found, Gtk.Label with Nerd Font otherwise.
        """
        if not HAS_GTK:
            raise RuntimeError("GTK not available")
        
        icon_path = self.get_icon_path(app_id, size)
        
        if icon_path:
            try:
                # Load as pixbuf and create image
                pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(
                    icon_path, size, size, True
                )
                image = Gtk.Image.new_from_pixbuf(pixbuf)
                image.set_pixel_size(size)
                return image
            except Exception as e:
                print(f"[ThemeManager] ⚠️ Failed to load {icon_path}: {e}")
        
        # Fallback to Nerd Font
        label = Gtk.Label(label=self.get_nerd_icon(app_id))
        label.add_css_class("nerd-icon")
        return label
    
    # ═══════════════════════════════════════════════════════════════════════
    # CACHE MANAGEMENT
    # ═══════════════════════════════════════════════════════════════════════
    
    def clear_cache(self) -> None:
        """Clear icon cache"""
        self._icon_cache.clear()
        print("[ThemeManager] 🗑️ Cache cleared")
    
    def get_cache_stats(self) -> Dict[str, int]:
        """Get cache statistics"""
        stats = {'total': len(self._icon_cache)}
        sources = {}
        
        for info in self._icon_cache.values():
            source = info.source
            sources[source] = sources.get(source, 0) + 1
        
        stats.update(sources)
        return stats


def get_theme_manager() -> ThemeManager:
    """Get singleton ThemeManager instance"""
    return ThemeManager()


# ═══════════════════════════════════════════════════════════════════════════════
# TESTING
# ═══════════════════════════════════════════════════════════════════════════════

if __name__ == "__main__":
    tm = get_theme_manager()
    
    print(f"\n🎨 Current Icon Theme: {tm._current_theme}")
    
    # Test icon resolution
    test_apps = [
        'firefox',
        'kitty',
        'code',
        'spotify',
        'discord',
        'nautilus',
        'steam',
        'unknown-app',
    ]
    
    print("\n📦 Icon Resolution Test:")
    for app in test_apps:
        path = tm.get_icon_path(app, 24)
        nerd = tm.get_nerd_icon(app)
        status = "✅" if path else "⚠️ (Nerd fallback)"
        print(f"   {app}: {path or 'None'} {status} [{nerd}]")
    
    print(f"\n📊 Cache Stats: {tm.get_cache_stats()}")