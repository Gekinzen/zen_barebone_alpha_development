"""
ConfigManager - Central Configuration Hub
==========================================

Manages ZenPyBar's own JSON config while keeping sync with Waybar.
- Stores ZenPyBar-specific overrides
- Tracks pinned apps
- Manages theme preferences
"""

import json
import os
from pathlib import Path
from typing import Dict, List, Optional, Any, Callable
from dataclasses import dataclass, field, asdict
from datetime import datetime
import threading
import hashlib


@dataclass
class ModuleConfig:
    """Configuration for a single module"""
    enabled: bool = True
    position: str = "left"  # left, center, right
    order: int = 0
    config: Dict[str, Any] = field(default_factory=dict)
    
    
@dataclass
class BarConfig:
    """Main bar configuration"""
    height: int = 40
    position: str = "bottom"  # top, bottom
    spacing: int = 4
    margin_top: int = 4
    margin_bottom: int = 3
    margin_left: int = 4
    margin_right: int = 4
    
    modules_left: List[str] = field(default_factory=list)
    modules_center: List[str] = field(default_factory=list)
    modules_right: List[str] = field(default_factory=list)
    
    module_configs: Dict[str, ModuleConfig] = field(default_factory=dict)


@dataclass
class ZenPyBarConfig:
    """Complete ZenPyBar configuration"""
    version: str = "2.0.0"
    last_sync: str = ""
    waybar_config_hash: str = ""
    
    bar: BarConfig = field(default_factory=BarConfig)
    
    # ZenPyBar-specific settings
    taskbar_enabled: bool = True
    taskbar_icon_size: int = 24
    taskbar_show_labels: bool = False
    taskbar_group_windows: bool = True
    
    # Pin/Unpin settings
    pinned_apps: List[str] = field(default_factory=list)
    pinned_apps_data: Dict[str, Dict] = field(default_factory=dict)
    
    # Theme override (if different from Waybar)
    theme_override: Optional[str] = None
    
    # Performance
    update_interval_ms: int = 100
    ipc_enabled: bool = True


class ConfigManager:
    """
    Central configuration manager for ZenPyBar.
    
    Responsibilities:
    - Load/save ZenPyBar config
    - Track Waybar config changes
    - Manage pinned apps state
    - Notify listeners on config changes
    """
    
    DEFAULT_CONFIG_DIR = Path.home() / ".config/hypr-control-center"
    ZENPYBAR_CONFIG = "preferences/zenpybar.json"
    WAYBAR_CONFIG_PATH = Path.home() / ".config/waybar"
    
    _instance = None
    _lock = threading.Lock()
    
    def __new__(cls, *args, **kwargs):
        """Singleton pattern - one ConfigManager for all bars"""
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = super().__new__(cls)
                    cls._instance._initialized = False
        return cls._instance
    
    def __init__(self, config_dir: Optional[Path] = None):
        if self._initialized:
            return
            
        self.config_dir = config_dir or self.DEFAULT_CONFIG_DIR
        self.config_path = self.config_dir / self.ZENPYBAR_CONFIG
        
        # Ensure directories exist
        self.config_path.parent.mkdir(parents=True, exist_ok=True)
        
        # Current config
        self._config: ZenPyBarConfig = ZenPyBarConfig()
        
        # Change listeners
        self._listeners: List[Callable[[ZenPyBarConfig], None]] = []
        
        # Load existing config
        self._load_config()
        
        self._initialized = True
        print(f"[ConfigManager] ✅ Initialized at {self.config_path}")
    
    @property
    def config(self) -> ZenPyBarConfig:
        return self._config
    
    def _load_config(self) -> None:
        """Load config from JSON file"""
        if not self.config_path.exists():
            print("[ConfigManager] No existing config, using defaults")
            self._save_config()
            return
        
        try:
            with open(self.config_path, 'r') as f:
                data = json.load(f)
            
            # Parse bar config
            bar_data = data.get('bar', {})
            bar_config = BarConfig(
                height=bar_data.get('height', 40),
                position=bar_data.get('position', 'bottom'),
                spacing=bar_data.get('spacing', 4),
                margin_top=bar_data.get('margin_top', 4),
                margin_bottom=bar_data.get('margin_bottom', 3),
                margin_left=bar_data.get('margin_left', 4),
                margin_right=bar_data.get('margin_right', 4),
                modules_left=bar_data.get('modules_left', []),
                modules_center=bar_data.get('modules_center', []),
                modules_right=bar_data.get('modules_right', []),
            )
            
            self._config = ZenPyBarConfig(
                version=data.get('version', '2.0.0'),
                last_sync=data.get('last_sync', ''),
                waybar_config_hash=data.get('waybar_config_hash', ''),
                bar=bar_config,
                taskbar_enabled=data.get('taskbar_enabled', True),
                taskbar_icon_size=data.get('taskbar_icon_size', 24),
                taskbar_show_labels=data.get('taskbar_show_labels', False),
                taskbar_group_windows=data.get('taskbar_group_windows', True),
                pinned_apps=data.get('pinned_apps', []),
                pinned_apps_data=data.get('pinned_apps_data', {}),
                theme_override=data.get('theme_override'),
                update_interval_ms=data.get('update_interval_ms', 100),
                ipc_enabled=data.get('ipc_enabled', True),
            )
            
            print(f"[ConfigManager] Loaded config v{self._config.version}")
            
        except Exception as e:
            print(f"[ConfigManager] ⚠️ Error loading config: {e}")
            self._config = ZenPyBarConfig()
    
    def _save_config(self) -> None:
        """Save config to JSON file"""
        try:
            data = {
                'version': self._config.version,
                'last_sync': self._config.last_sync,
                'waybar_config_hash': self._config.waybar_config_hash,
                'bar': {
                    'height': self._config.bar.height,
                    'position': self._config.bar.position,
                    'spacing': self._config.bar.spacing,
                    'margin_top': self._config.bar.margin_top,
                    'margin_bottom': self._config.bar.margin_bottom,
                    'margin_left': self._config.bar.margin_left,
                    'margin_right': self._config.bar.margin_right,
                    'modules_left': self._config.bar.modules_left,
                    'modules_center': self._config.bar.modules_center,
                    'modules_right': self._config.bar.modules_right,
                },
                'taskbar_enabled': self._config.taskbar_enabled,
                'taskbar_icon_size': self._config.taskbar_icon_size,
                'taskbar_show_labels': self._config.taskbar_show_labels,
                'taskbar_group_windows': self._config.taskbar_group_windows,
                'pinned_apps': self._config.pinned_apps,
                'pinned_apps_data': self._config.pinned_apps_data,
                'theme_override': self._config.theme_override,
                'update_interval_ms': self._config.update_interval_ms,
                'ipc_enabled': self._config.ipc_enabled,
            }
            
            with open(self.config_path, 'w') as f:
                json.dump(data, f, indent=2)
            
            print(f"[ConfigManager] 💾 Saved config to {self.config_path}")
            
        except Exception as e:
            print(f"[ConfigManager] ❌ Error saving config: {e}")
    
    def save(self) -> None:
        """Public save method"""
        self._save_config()
        self._notify_listeners()
    
    def update(self, **kwargs) -> None:
        """Update config fields"""
        for key, value in kwargs.items():
            if hasattr(self._config, key):
                setattr(self._config, key, value)
        self._save_config()
        self._notify_listeners()
    
    def update_bar(self, **kwargs) -> None:
        """Update bar-specific config"""
        for key, value in kwargs.items():
            if hasattr(self._config.bar, key):
                setattr(self._config.bar, key, value)
        self._save_config()
        self._notify_listeners()
    
    # ═══════════════════════════════════════════════════════════════════════
    # PINNED APPS MANAGEMENT
    # ═══════════════════════════════════════════════════════════════════════
    
    def pin_app(self, app_id: str, wm_class: str = "", 
                exec_cmd: str = "", icon: str = "") -> None:
        """Pin an app to the taskbar"""
        if app_id not in self._config.pinned_apps:
            self._config.pinned_apps.append(app_id)
            self._config.pinned_apps_data[app_id] = {
                'wm_class': wm_class or app_id,
                'exec': exec_cmd,
                'icon': icon,
                'pinned_at': datetime.now().isoformat(),
            }
            self._save_config()
            self._notify_listeners()
            print(f"[ConfigManager] 📌 Pinned: {app_id}")
    
    def unpin_app(self, app_id: str) -> None:
        """Unpin an app from the taskbar"""
        if app_id in self._config.pinned_apps:
            self._config.pinned_apps.remove(app_id)
            self._config.pinned_apps_data.pop(app_id, None)
            self._save_config()
            self._notify_listeners()
            print(f"[ConfigManager] 📍 Unpinned: {app_id}")
    
    def is_pinned(self, app_id: str) -> bool:
        """Check if app is pinned"""
        return app_id in self._config.pinned_apps
    
    def get_pinned_apps(self) -> List[Dict[str, Any]]:
        """Get list of pinned apps with their data"""
        result = []
        for app_id in self._config.pinned_apps:
            data = self._config.pinned_apps_data.get(app_id, {})
            result.append({
                'app_id': app_id,
                'wm_class': data.get('wm_class', app_id),
                'exec': data.get('exec', ''),
                'icon': data.get('icon', ''),
            })
        return result
    
    def reorder_pinned_apps(self, new_order: List[str]) -> None:
        """Reorder pinned apps"""
        # Keep only valid apps
        self._config.pinned_apps = [
            app for app in new_order 
            if app in self._config.pinned_apps
        ]
        self._save_config()
        self._notify_listeners()
    
    # ═══════════════════════════════════════════════════════════════════════
    # WAYBAR SYNC
    # ═══════════════════════════════════════════════════════════════════════
    
    def get_waybar_config_hash(self) -> str:
        """Calculate hash of Waybar config for change detection"""
        config_path = self.WAYBAR_CONFIG_PATH / "config.jsonc"
        if not config_path.exists():
            config_path = self.WAYBAR_CONFIG_PATH / "config.json"
        
        if not config_path.exists():
            return ""
        
        try:
            content = config_path.read_bytes()
            return hashlib.md5(content).hexdigest()
        except Exception:
            return ""
    
    def needs_sync(self) -> bool:
        """Check if Waybar config has changed since last sync"""
        current_hash = self.get_waybar_config_hash()
        return current_hash != self._config.waybar_config_hash
    
    def mark_synced(self) -> None:
        """Mark current Waybar config as synced"""
        self._config.waybar_config_hash = self.get_waybar_config_hash()
        self._config.last_sync = datetime.now().isoformat()
        self._save_config()
    
    # ═══════════════════════════════════════════════════════════════════════
    # LISTENERS
    # ═══════════════════════════════════════════════════════════════════════
    
    def add_listener(self, callback: Callable[[ZenPyBarConfig], None]) -> None:
        """Add config change listener"""
        if callback not in self._listeners:
            self._listeners.append(callback)
    
    def remove_listener(self, callback: Callable[[ZenPyBarConfig], None]) -> None:
        """Remove config change listener"""
        if callback in self._listeners:
            self._listeners.remove(callback)
    
    def _notify_listeners(self) -> None:
        """Notify all listeners of config change"""
        for listener in self._listeners:
            try:
                listener(self._config)
            except Exception as e:
                print(f"[ConfigManager] ⚠️ Listener error: {e}")


def get_config_manager() -> ConfigManager:
    """Get singleton ConfigManager instance"""
    return ConfigManager()


# ═══════════════════════════════════════════════════════════════════════════════
# TESTING
# ═══════════════════════════════════════════════════════════════════════════════

if __name__ == "__main__":
    # Test ConfigManager
    cm = get_config_manager()
    
    print(f"\n📋 Current Config:")
    print(f"   Version: {cm.config.version}")
    print(f"   Bar Height: {cm.config.bar.height}")
    print(f"   Position: {cm.config.bar.position}")
    print(f"   Pinned Apps: {cm.config.pinned_apps}")
    
    # Test pin/unpin
    print("\n🧪 Testing pin/unpin...")
    cm.pin_app("firefox", wm_class="firefox", exec_cmd="firefox")
    print(f"   Is firefox pinned? {cm.is_pinned('firefox')}")
    
    cm.unpin_app("firefox")
    print(f"   Is firefox pinned? {cm.is_pinned('firefox')}")
    
    # Test sync check
    print(f"\n🔄 Needs Waybar sync? {cm.needs_sync()}")