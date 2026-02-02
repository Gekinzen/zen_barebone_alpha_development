"""
═══════════════════════════════════════════════════════════════════════════════
PROFILE MANAGER - Create, Read, Update, Delete theme profiles
═══════════════════════════════════════════════════════════════════════════════
"""

import json
import shutil
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Optional, Any

from .constants import (
    THEMES_DIR, BUILTIN_DIR, CUSTOM_DIR, PROFILES_FILE,
    DEFAULT_WAYBAR_CONFIG, DEFAULT_WAYBAR_STYLE
)
from .themes import BUILTIN_THEMES


class ThemeProfileManager:
    """Manages theme profiles - builtin and custom"""
    
    def __init__(self):
        self._ensure_directories()
        self._init_builtin_themes()
        self.profiles = self._load_profiles()
    
    def _ensure_directories(self):
        """Create necessary directories"""
        THEMES_DIR.mkdir(parents=True, exist_ok=True)
        BUILTIN_DIR.mkdir(parents=True, exist_ok=True)
        CUSTOM_DIR.mkdir(parents=True, exist_ok=True)
    
    def _init_builtin_themes(self):
        """Initialize builtin theme files"""
        for theme_id, theme_data in BUILTIN_THEMES.items():
            theme_file = BUILTIN_DIR / f"{theme_id}.json"
            if not theme_file.exists():
                self._save_theme_file(theme_file, theme_id, theme_data, is_builtin=True)
    
    def _save_theme_file(self, path: Path, theme_id: str, theme_data: Dict, is_builtin: bool = False):
        """Save theme to JSON file"""
        data = {
            "id": theme_id,
            "name": theme_data.get("name", theme_id),
            "description": theme_data.get("description", ""),
            "is_builtin": is_builtin,
            "version": "2.0",
            "created_at": datetime.now().isoformat(),
            "modified_at": datetime.now().isoformat(),
            "colors": theme_data.get("colors", {}),
            "rofi": theme_data.get("rofi", {}),
            "kitty": theme_data.get("kitty", {}),
            "waybar": theme_data.get("waybar", DEFAULT_WAYBAR_CONFIG.copy()),
            "waybar_style": theme_data.get("waybar_style", DEFAULT_WAYBAR_STYLE.copy()),
        }
        with open(path, 'w') as f:
            json.dump(data, f, indent=2)
    
    def _load_profiles(self) -> Dict:
        """Load profiles registry"""
        if PROFILES_FILE.exists():
            try:
                with open(PROFILES_FILE) as f:
                    return json.load(f)
            except:
                pass
        return {
            "version": "2.0",
            "active_profile": "one-dark",
            "active_profile_type": "builtin",
            "use_custom_scheme": True,
            "sync_control_center": True,
        }
    
    def save_profiles(self):
        """Save profiles registry"""
        with open(PROFILES_FILE, 'w') as f:
            json.dump(self.profiles, f, indent=2)
    
    def get_active_theme(self) -> Dict:
        """Get currently active theme data"""
        profile_id = self.profiles.get("active_profile", "one-dark")
        profile_type = self.profiles.get("active_profile_type", "builtin")
        
        if profile_type == "builtin":
            theme_file = BUILTIN_DIR / f"{profile_id}.json"
        else:
            theme_file = CUSTOM_DIR / f"{profile_id}.json"
        
        if theme_file.exists():
            with open(theme_file) as f:
                return json.load(f)
        
        # Fallback to builtin
        if profile_id in BUILTIN_THEMES:
            return {
                "id": profile_id,
                "is_builtin": True,
                **BUILTIN_THEMES[profile_id],
                "waybar": DEFAULT_WAYBAR_CONFIG.copy(),
                "waybar_style": DEFAULT_WAYBAR_STYLE.copy(),
            }
        
        return {
            "id": "one-dark",
            "is_builtin": True,
            **BUILTIN_THEMES["one-dark"],
            "waybar": DEFAULT_WAYBAR_CONFIG.copy(),
            "waybar_style": DEFAULT_WAYBAR_STYLE.copy(),
        }
    
    def set_active_theme(self, theme_id: str, is_builtin: bool = True):
        """Set active theme"""
        self.profiles["active_profile"] = theme_id
        self.profiles["active_profile_type"] = "builtin" if is_builtin else "custom"
        self.save_profiles()
    
    def get_all_themes(self) -> List[Dict]:
        """Get list of all available themes"""
        themes = []
        
        # Builtin themes
        for theme_id, theme_data in BUILTIN_THEMES.items():
            themes.append({
                "id": theme_id,
                "name": theme_data["name"],
                "description": theme_data.get("description", ""),
                "is_builtin": True
            })
        
        # Custom themes
        for theme_file in CUSTOM_DIR.glob("*.json"):
            try:
                with open(theme_file) as f:
                    data = json.load(f)
                    themes.append({
                        "id": data.get("id", theme_file.stem),
                        "name": data.get("name", theme_file.stem),
                        "description": data.get("description", "Custom theme"),
                        "is_builtin": False
                    })
            except:
                pass
        
        return themes
    
    def create_custom_theme(self, name: str, base_theme_id: str = None) -> str:
        """Create new custom theme based on existing"""
        # Generate safe ID
        theme_id = ''.join(c for c in name.lower().replace(" ", "-").replace("_", "-") 
                          if c.isalnum() or c == '-')
        
        # Ensure unique
        counter = 1
        original_id = theme_id
        while (CUSTOM_DIR / f"{theme_id}.json").exists():
            theme_id = f"{original_id}-{counter}"
            counter += 1
        
        # Get base theme
        if base_theme_id and base_theme_id in BUILTIN_THEMES:
            base_data = BUILTIN_THEMES[base_theme_id].copy()
        else:
            base_data = BUILTIN_THEMES["one-dark"].copy()
        
        base_data["name"] = name
        base_data["description"] = f"Custom theme based on {base_theme_id or 'One Dark'}"
        
        # Save new theme
        theme_file = CUSTOM_DIR / f"{theme_id}.json"
        self._save_theme_file(theme_file, theme_id, base_data, is_builtin=False)
        
        return theme_id
    
    def update_custom_theme(self, theme_id: str, updates: Dict) -> bool:
        """Update custom theme with new values"""
        theme_file = CUSTOM_DIR / f"{theme_id}.json"
        if not theme_file.exists():
            return False
        
        with open(theme_file) as f:
            data = json.load(f)
        
        # Deep merge updates
        for key, value in updates.items():
            if isinstance(value, dict) and key in data and isinstance(data[key], dict):
                data[key].update(value)
            else:
                data[key] = value
        
        data["modified_at"] = datetime.now().isoformat()
        
        with open(theme_file, 'w') as f:
            json.dump(data, f, indent=2)
        
        return True
    
    def delete_custom_theme(self, theme_id: str) -> bool:
        """Delete custom theme"""
        theme_file = CUSTOM_DIR / f"{theme_id}.json"
        if theme_file.exists():
            theme_file.unlink()
            if self.profiles.get("active_profile") == theme_id:
                self.set_active_theme("one-dark", is_builtin=True)
            return True
        return False
    
    def export_theme(self, theme_id: str, export_path: Path) -> bool:
        """Export theme to file"""
        theme_file = BUILTIN_DIR / f"{theme_id}.json"
        if not theme_file.exists():
            theme_file = CUSTOM_DIR / f"{theme_id}.json"
        
        if not theme_file.exists():
            # Create from builtin definition
            if theme_id in BUILTIN_THEMES:
                data = {
                    "id": theme_id,
                    "name": BUILTIN_THEMES[theme_id]["name"],
                    "colors": BUILTIN_THEMES[theme_id]["colors"],
                    "rofi": BUILTIN_THEMES[theme_id]["rofi"],
                    "kitty": BUILTIN_THEMES[theme_id]["kitty"],
                    "waybar": DEFAULT_WAYBAR_CONFIG.copy(),
                    "waybar_style": DEFAULT_WAYBAR_STYLE.copy(),
                    "exported_at": datetime.now().isoformat()
                }
                with open(export_path, 'w') as f:
                    json.dump(data, f, indent=2)
                return True
            return False
        
        shutil.copy(theme_file, export_path)
        return True
    
    def import_theme(self, import_path: Path) -> Optional[str]:
        """Import theme from file"""
        try:
            with open(import_path) as f:
                data = json.load(f)
            
            if "colors" not in data:
                return None
            
            # Create new custom theme
            name = data.get("name", import_path.stem)
            theme_id = self.create_custom_theme(name)
            
            # Update with imported data
            theme_file = CUSTOM_DIR / f"{theme_id}.json"
            with open(theme_file) as f:
                existing = json.load(f)
            
            existing.update({
                "colors": data.get("colors", {}),
                "rofi": data.get("rofi", {}),
                "kitty": data.get("kitty", {}),
                "waybar": data.get("waybar", DEFAULT_WAYBAR_CONFIG.copy()),
                "waybar_style": data.get("waybar_style", DEFAULT_WAYBAR_STYLE.copy()),
            })
            
            with open(theme_file, 'w') as f:
                json.dump(existing, f, indent=2)
            
            return theme_id
        except Exception as e:
            print(f"Import error: {e}")
            return None
    
    def get_sync_control_center(self) -> bool:
        """Check if Control Center sync is enabled"""
        return self.profiles.get("sync_control_center", True)
    
    def set_sync_control_center(self, enabled: bool):
        """Enable/disable Control Center sync"""
        self.profiles["sync_control_center"] = enabled
        self.save_profiles()
