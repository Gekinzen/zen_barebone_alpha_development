"""
IconResolver - Application Icon Resolution for ZenPyBar v2
==========================================================

Resolves application icons from multiple sources:
1. Custom icons directory
2. Current GTK icon theme (Papirus, Tela, etc.)
3. Hicolor fallback
4. /usr/share/pixmaps
5. Nerd Font fallback

Uses caching for performance.
"""

import os
from pathlib import Path
from typing import Dict, Optional, List
import threading


class IconResolver:
    """
    Resolves application icons from system icon themes.
    
    SINGLETON - shared across all components for cache efficiency.
    """
    
    # Common icon search paths
    ICON_PATHS = [
        Path.home() / ".config/hypr-control-center/icons",
        Path.home() / ".local/share/icons",
        Path.home() / ".icons",
        Path("/usr/share/icons"),
        Path("/usr/share/pixmaps"),
    ]
    
    # Nerd Font icon fallbacks
    NERD_ICONS = {
        # Browsers
        'firefox': '',
        'firefox-developer-edition': '',
        'chromium': '',
        'google-chrome': '',
        'brave': '󰖟',
        'brave-browser': '󰖟',
        'vivaldi': '󰖟',
        'microsoft-edge': '󰇩',
        'zen-browser': '󰖟',
        'zen': '󰖟',
        
        # Terminals
        'kitty': '',
        'alacritty': '',
        'foot': '',
        'wezterm': '',
        'konsole': '',
        'gnome-terminal': '',
        'xterm': '',
        'terminator': '',
        
        # Development
        'code': '󰨞',
        'code-oss': '󰨞',
        'visual-studio-code': '󰨞',
        'vscodium': '󰨞',
        'sublime-text': '',
        'neovim': '',
        'nvim': '',
        'vim': '',
        'emacs': '',
        'jetbrains-idea': '',
        'jetbrains-pycharm': '',
        'jetbrains-clion': '',
        'jetbrains-webstorm': '',
        'android-studio': '',
        
        # Files & Editors
        'nautilus': '',
        'org.gnome.nautilus': '',
        'thunar': '',
        'dolphin': '',
        'pcmanfm': '',
        'nemo': '',
        'caja': '',
        'gedit': '',
        'kate': '',
        'mousepad': '',
        'geany': '',
        
        # Media
        'spotify': '',
        'vlc': '󰕼',
        'mpv': '',
        'rhythmbox': '󰎆',
        'audacious': '󰎆',
        'clementine': '󰎆',
        'elisa': '󰎆',
        'amberol': '󰎆',
        
        # Communication
        'discord': '󰙯',
        'slack': '󰒱',
        'telegram-desktop': '',
        'telegramdesktop': '',
        'signal-desktop': '󰭹',
        'element': '',
        'teams': '󰊻',
        'zoom': '',
        'skype': '󰒯',
        
        # System
        'gnome-control-center': '',
        'systemsettings': '',
        'pavucontrol': '󰕾',
        'blueman-manager': '',
        'nm-connection-editor': '󰖩',
        'gnome-system-monitor': '',
        
        # Graphics
        'gimp': '',
        'gimp-2.10': '',
        'inkscape': '',
        'blender': '󰂫',
        'krita': '',
        
        # Office
        'libreoffice-writer': '󰈙',
        'libreoffice-calc': '󰧷',
        'libreoffice-impress': '󰐩',
        'libreoffice-draw': '',
        'onlyoffice': '󰈙',
        
        # Games
        'steam': '',
        'lutris': '',
        'heroic': '',
        
        # Utilities
        'obs': '󰑋',
        'obs-studio': '󰑋',
        'com.obsproject.studio': '󰑋',
        'flameshot': '',
        'grim': '',
        'keepassxc': '󰌋',
        'bitwarden': '󰌋',
        '1password': '󰌋',
        
        # Default
        'default': '󰣆',
    }
    
    # Known wm_class to icon name mappings
    WM_CLASS_MAP = {
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
        'thunar': 'Thunar',
        'Thunar': 'Thunar',
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
        'zen-browser': 'zen-browser',
        'Zen Browser': 'zen-browser',
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
        
        self._cache: Dict[str, Optional[str]] = {}
        self._current_theme: Optional[str] = None
        
        # Detect current icon theme
        self._detect_icon_theme()
        
        self._initialized = True
        print(f"[IconResolver] ✅ Initialized (theme: {self._current_theme})")
    
    def _detect_icon_theme(self) -> None:
        """Detect current GTK icon theme"""
        import subprocess
        
        # Try gsettings
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
        
        # Try GTK settings file
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
        
        # Fallback
        self._current_theme = "Adwaita"
    
    # ═══════════════════════════════════════════════════════════════════════
    # PUBLIC API
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
        
        if cache_key in self._cache:
            return self._cache[cache_key]
        
        # Normalize app_id
        normalized = self._normalize_app_id(app_id)
        
        # Search in order
        path = None
        
        # 1. Custom icons
        path = self._find_in_custom(normalized, size)
        
        # 2. Current theme
        if not path:
            path = self._find_in_theme(normalized, size)
        
        # 3. Hicolor fallback
        if not path:
            path = self._find_in_hicolor(normalized, size)
        
        # 4. Pixmaps
        if not path:
            path = self._find_in_pixmaps(normalized)
        
        # Cache result
        self._cache[cache_key] = path
        
        return path
    
    def get_nerd_icon(self, app_id: str) -> str:
        """Get Nerd Font icon fallback"""
        normalized = app_id.lower().replace(' ', '-')
        
        # Direct match
        if normalized in self.NERD_ICONS:
            return self.NERD_ICONS[normalized]
        
        # Partial match
        for key, icon in self.NERD_ICONS.items():
            if key in normalized or normalized in key:
                return icon
        
        return self.NERD_ICONS['default']
    
    def clear_cache(self) -> None:
        """Clear icon cache"""
        self._cache.clear()
    
    # ═══════════════════════════════════════════════════════════════════════
    # INTERNAL SEARCH METHODS
    # ═══════════════════════════════════════════════════════════════════════
    
    def _normalize_app_id(self, app_id: str) -> str:
        """Normalize app ID for searching"""
        if app_id in self.WM_CLASS_MAP:
            return self.WM_CLASS_MAP[app_id]
        
        return app_id.lower().replace(' ', '-').replace('_', '-')
    
    def _find_in_custom(self, app_id: str, size: int) -> Optional[str]:
        """Find in custom icons directory"""
        custom_dir = Path.home() / ".config/hypr-control-center/icons"
        if not custom_dir.exists():
            return None
        
        for ext in ['.png', '.svg', '.xpm']:
            icon_path = custom_dir / f"{app_id}{ext}"
            if icon_path.exists():
                return str(icon_path)
        
        return None
    
    def _find_in_theme(self, app_id: str, size: int) -> Optional[str]:
        """Find in current icon theme"""
        if not self._current_theme:
            return None
        
        theme_paths = [
            Path.home() / ".local/share/icons" / self._current_theme,
            Path.home() / ".icons" / self._current_theme,
            Path("/usr/share/icons") / self._current_theme,
        ]
        
        size_dirs = [
            f"{size}x{size}/apps",
            "scalable/apps",
            "48x48/apps",
            "32x32/apps",
            "24x24/apps",
            "22x22/apps",
            "16x16/apps",
        ]
        
        # Also try variations of app_id
        app_ids_to_try = [
            app_id,
            app_id.lower(),
            app_id.replace('-', '.'),
            f"org.gnome.{app_id.capitalize()}",
        ]
        
        for theme_path in theme_paths:
            if not theme_path.exists():
                continue
            
            for size_dir in size_dirs:
                icon_dir = theme_path / size_dir
                if not icon_dir.exists():
                    continue
                
                for aid in app_ids_to_try:
                    for ext in ['.svg', '.png', '.xpm']:
                        icon_path = icon_dir / f"{aid}{ext}"
                        if icon_path.exists():
                            return str(icon_path)
        
        return None
    
    def _find_in_hicolor(self, app_id: str, size: int) -> Optional[str]:
        """Find in hicolor theme"""
        hicolor_paths = [
            Path("/usr/share/icons/hicolor"),
            Path.home() / ".local/share/icons/hicolor",
        ]
        
        size_dirs = [
            f"{size}x{size}/apps",
            "scalable/apps",
            "48x48/apps",
            "32x32/apps",
            "24x24/apps",
        ]
        
        for hicolor_path in hicolor_paths:
            if not hicolor_path.exists():
                continue
            
            for size_dir in size_dirs:
                icon_dir = hicolor_path / size_dir
                if not icon_dir.exists():
                    continue
                
                for ext in ['.svg', '.png', '.xpm']:
                    icon_path = icon_dir / f"{app_id}{ext}"
                    if icon_path.exists():
                        return str(icon_path)
        
        return None
    
    def _find_in_pixmaps(self, app_id: str) -> Optional[str]:
        """Find in /usr/share/pixmaps"""
        pixmaps = Path("/usr/share/pixmaps")
        if not pixmaps.exists():
            return None
        
        for ext in ['.png', '.svg', '.xpm']:
            icon_path = pixmaps / f"{app_id}{ext}"
            if icon_path.exists():
                return str(icon_path)
        
        return None


def get_resolver() -> IconResolver:
    """Get singleton IconResolver instance"""
    return IconResolver()


def get_nerd_icon(app_id: str) -> str:
    """Convenience function to get Nerd icon"""
    return get_resolver().get_nerd_icon(app_id)


# ═══════════════════════════════════════════════════════════════════════════════
# TESTING
# ═══════════════════════════════════════════════════════════════════════════════

if __name__ == "__main__":
    resolver = get_resolver()
    
    print(f"\n🎨 Current Theme: {resolver._current_theme}")
    
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
        path = resolver.get_icon_path(app, 24)
        nerd = resolver.get_nerd_icon(app)
        status = "✅" if path else f"⚠️ Nerd: {nerd}"
        print(f"   {app}: {path or 'None'} {status}")