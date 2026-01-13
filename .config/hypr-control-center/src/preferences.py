"""
Preferences Manager - Base class for managing user preferences
All preferences are stored in ~/.config/hypr-control-center/preferences/
"""

import json
from pathlib import Path
from typing import Any, Dict, Optional

class PreferencesManager:
    """Base class for managing JSON preference files"""
    
    def __init__(self, filename: str):
        """
        Initialize preferences manager
        
        Args:
            filename: Name of JSON file (e.g., 'theme.json')
        """
        self.config_dir = Path.home() / ".config" / "hypr-control-center"
        self.preferences_dir = self.config_dir / "preferences"
        self.prefs_file = self.preferences_dir / filename
        
        # Create preferences directory if it doesn't exist
        self.preferences_dir.mkdir(parents=True, exist_ok=True)
    
    def load(self) -> Dict[str, Any]:
        """Load preferences from JSON file"""
        if self.prefs_file.exists():
            try:
                with open(self.prefs_file, 'r') as f:
                    return json.load(f)
            except (json.JSONDecodeError, IOError):
                return {}
        return {}
    
    def save(self, data: Dict[str, Any]) -> bool:
        """Save preferences to JSON file"""
        try:
            with open(self.prefs_file, 'w') as f:
                json.dump(data, f, indent=2)
            return True
        except IOError:
            return False
    
    def get(self, key: str, default: Any = None) -> Any:
        """Get a preference value"""
        data = self.load()
        return data.get(key, default)
    
    def set(self, key: str, value: Any) -> bool:
        """Set a preference value"""
        data = self.load()
        data[key] = value
        return self.save(data)
    
    def update(self, updates: Dict[str, Any]) -> bool:
        """Update multiple preferences at once"""
        data = self.load()
        data.update(updates)
        return self.save(data)
    
    def delete(self, key: str) -> bool:
        """Delete a preference key"""
        data = self.load()
        if key in data:
            del data[key]
            return self.save(data)
        return False
    
    def clear(self) -> bool:
        """Clear all preferences"""
        return self.save({})
    
    def exists(self) -> bool:
        """Check if preferences file exists"""
        return self.prefs_file.exists()


# Specific preference managers

class ThemePreferences(PreferencesManager):
    """Manage theme preferences"""
    
    def __init__(self):
        super().__init__('theme.json')
    
    def get_current_theme(self) -> str:
        """Get currently selected theme"""
        return self.get('current_theme', 'one-dark')
    
    def set_current_theme(self, theme_id: str) -> bool:
        """Set current theme"""
        return self.set('current_theme', theme_id)
    
    def get_theme_source(self) -> str:
        """Get theme source: 'custom' or 'gtk'"""
        return self.get('theme_source', 'custom')
    
    def set_theme_source(self, source: str) -> bool:
        """Set theme source"""
        return self.set('theme_source', source)


class WallpaperPreferences(PreferencesManager):
    """Manage wallpaper preferences"""
    
    def __init__(self):
        super().__init__('wallpaper.json')
    
    def get_wallpaper_folder(self) -> str:
        """Get wallpaper folder path"""
        default = str(Path.home() / "wallpapers")
        return self.get('folder', default)
    
    def set_wallpaper_folder(self, folder_path: str) -> bool:
        """Set wallpaper folder path"""
        return self.set('folder', folder_path)
    
    def get_current_wallpaper(self) -> Optional[str]:
        """Get current wallpaper path"""
        return self.get('current')
    
    def set_current_wallpaper(self, wallpaper_path: str) -> bool:
        """Set current wallpaper"""
        return self.set('current', wallpaper_path)
    
    def get_transition_type(self) -> str:
        """Get wallpaper transition type"""
        return self.get('transition', 'fade')
    
    def set_transition_type(self, transition: str) -> bool:
        """Set transition type: fade, wipe, grow, etc."""
        return self.set('transition', transition)


class PowerPreferences(PreferencesManager):
    """Manage power profile preferences"""
    
    def __init__(self):
        super().__init__('power.json')
    
    def get_current_profile(self) -> str:
        """Get current power profile"""
        return self.get('profile', 'neutral')
    
    def set_current_profile(self, profile: str) -> bool:
        """Set power profile: saver, neutral, performance, developer"""
        return self.set('profile', profile)
    
    def get_auto_profile(self) -> bool:
        """Check if auto profile switching is enabled"""
        return self.get('auto', False)
    
    def set_auto_profile(self, enabled: bool) -> bool:
        """Enable/disable auto profile switching"""
        return self.set('auto', enabled)


class NotificationPreferences(PreferencesManager):
    """Manage notification preferences"""
    
    def __init__(self):
        super().__init__('notifications.json')
    
    def get_position_x(self) -> str:
        """Get horizontal position: left, center, right"""
        return self.get('positionX', 'right')
    
    def set_position_x(self, position: str) -> bool:
        """Set horizontal position"""
        return self.set('positionX', position)
    
    def get_position_y(self) -> str:
        """Get vertical position: top, center, bottom"""
        return self.get('positionY', 'top')
    
    def set_position_y(self, position: str) -> bool:
        """Set vertical position"""
        return self.set('positionY', position)
    
    def get_display(self) -> str:
        """Get target display: display1, display2, all"""
        return self.get('display', 'all')
    
    def set_display(self, display: str) -> bool:
        """Set target display"""
        return self.set('display', display)


class DisplayPreferences(PreferencesManager):
    """Manage display/monitor preferences"""
    
    def __init__(self):
        super().__init__('displays.json')
    
    def get_monitor_config(self, monitor_name: str) -> Optional[Dict]:
        """Get configuration for a specific monitor"""
        monitors = self.get('monitors', {})
        return monitors.get(monitor_name)
    
    def set_monitor_config(self, monitor_name: str, config: Dict) -> bool:
        """Set configuration for a specific monitor"""
        monitors = self.get('monitors', {})
        monitors[monitor_name] = config
        return self.set('monitors', monitors)
    
    def get_primary_monitor(self) -> Optional[str]:
        """Get primary monitor name"""
        return self.get('primary')
    
    def set_primary_monitor(self, monitor_name: str) -> bool:
        """Set primary monitor"""
        return self.set('primary', monitor_name)