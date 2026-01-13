"""
PinnedManager - Pinned Apps Management for ZenPyBar v2
======================================================

Manages the list of pinned applications for the taskbar.
Windows-style pin/unpin functionality with persistence.

Features:
- Pin/Unpin apps to taskbar
- App launching via .desktop files
- Drag-to-reorder support
- JSON persistence
- Desktop file auto-detection
"""

import json
import subprocess
import os
from pathlib import Path
from typing import Dict, List, Optional, Callable, Any
from dataclasses import dataclass, field, asdict
from datetime import datetime
import threading


@dataclass
class PinnedApp:
    """Represents a pinned application"""
    app_id: str
    wm_class: str = ""
    exec_cmd: str = ""
    icon: str = ""
    desktop_file: str = ""
    pinned_at: str = field(default_factory=lambda: datetime.now().isoformat())
    order: int = 0
    
    def __post_init__(self):
        if not self.wm_class:
            self.wm_class = self.app_id


class PinnedManager:
    """
    Manages pinned apps for the taskbar.
    
    SINGLETON - shared across all bars to ensure consistent state.
    
    Usage:
        pm = get_pinned_manager()
        pm.pin_app("firefox", wm_class="firefox", exec_cmd="firefox")
        pm.unpin_app("firefox")
        pm.launch_app("firefox")
    """
    
    DEFAULT_PATH = Path.home() / ".config/hypr-control-center/preferences/pinned_apps.json"
    
    # Desktop file search paths
    DESKTOP_PATHS = [
        Path.home() / ".local/share/applications",
        Path("/usr/share/applications"),
        Path("/usr/local/share/applications"),
    ]
    
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
    
    def __init__(self, config_path: Optional[Path] = None):
        if self._initialized:
            return
        
        self.config_path = config_path or self.DEFAULT_PATH
        self.config_path.parent.mkdir(parents=True, exist_ok=True)
        
        # State
        self._pinned: Dict[str, PinnedApp] = {}
        self._order: List[str] = []  # Ordered list of app_ids
        
        # Listeners
        self._listeners: List[Callable[[], None]] = []
        
        # Desktop file cache
        self._desktop_cache: Dict[str, dict] = {}
        
        # Load existing config
        self._load()
        
        self._initialized = True
        print(f"[PinnedManager] ✅ Initialized ({len(self._pinned)} pinned apps)")
    
    # ═══════════════════════════════════════════════════════════════════════
    # PUBLIC API
    # ═══════════════════════════════════════════════════════════════════════
    
    def get_pinned_apps(self) -> List[PinnedApp]:
        """Get ordered list of pinned apps"""
        return [self._pinned[app_id] for app_id in self._order if app_id in self._pinned]
    
    def is_pinned(self, app_id: str) -> bool:
        """Check if app is pinned"""
        normalized = app_id.lower()
        return normalized in self._pinned or app_id in self._pinned
    
    def get_pinned_app(self, app_id: str) -> Optional[PinnedApp]:
        """Get pinned app by ID"""
        normalized = app_id.lower()
        return self._pinned.get(normalized) or self._pinned.get(app_id)
    
    def pin_app(self, app_id: str, wm_class: str = "", 
                exec_cmd: str = "", icon: str = "") -> PinnedApp:
        """Pin an application to the taskbar"""
        normalized = app_id.lower()
        
        if normalized in self._pinned:
            print(f"[PinnedManager] ℹ️ {app_id} already pinned")
            return self._pinned[normalized]
        
        # Try to get info from desktop file
        desktop_info = self._find_desktop_info(app_id)
        
        pinned = PinnedApp(
            app_id=normalized,
            wm_class=wm_class or desktop_info.get('wm_class', app_id),
            exec_cmd=exec_cmd or desktop_info.get('exec', ''),
            icon=icon or desktop_info.get('icon', ''),
            desktop_file=desktop_info.get('path', ''),
            order=len(self._order),
        )
        
        self._pinned[normalized] = pinned
        self._order.append(normalized)
        
        self._save()
        self._notify_listeners()
        
        print(f"[PinnedManager] 📌 Pinned: {app_id}")
        return pinned
    
    def unpin_app(self, app_id: str) -> bool:
        """Unpin an application from the taskbar"""
        normalized = app_id.lower()
        
        if normalized not in self._pinned:
            print(f"[PinnedManager] ⚠️ {app_id} not pinned")
            return False
        
        del self._pinned[normalized]
        if normalized in self._order:
            self._order.remove(normalized)
        
        self._save()
        self._notify_listeners()
        
        print(f"[PinnedManager] 📍 Unpinned: {app_id}")
        return True
    
    def toggle_pin(self, app_id: str, wm_class: str = "", 
                   exec_cmd: str = "", icon: str = "") -> bool:
        """Toggle pin state - returns True if now pinned"""
        if self.is_pinned(app_id):
            self.unpin_app(app_id)
            return False
        else:
            self.pin_app(app_id, wm_class, exec_cmd, icon)
            return True
    
    def reorder(self, new_order: List[str]) -> None:
        """Reorder pinned apps"""
        valid_order = [app_id.lower() for app_id in new_order if app_id.lower() in self._pinned]
        
        # Add any missing apps at the end
        for app_id in self._pinned:
            if app_id not in valid_order:
                valid_order.append(app_id)
        
        self._order = valid_order
        
        # Update order field
        for i, app_id in enumerate(self._order):
            if app_id in self._pinned:
                self._pinned[app_id].order = i
        
        self._save()
        self._notify_listeners()
    
    def move_app(self, app_id: str, new_index: int) -> None:
        """Move a pinned app to a new position"""
        normalized = app_id.lower()
        
        if normalized not in self._order:
            return
        
        self._order.remove(normalized)
        self._order.insert(max(0, min(new_index, len(self._order))), normalized)
        
        for i, aid in enumerate(self._order):
            if aid in self._pinned:
                self._pinned[aid].order = i
        
        self._save()
        self._notify_listeners()
    
    # ═══════════════════════════════════════════════════════════════════════
    # APP LAUNCHING
    # ═══════════════════════════════════════════════════════════════════════
    
    def launch_app(self, app_id: str) -> bool:
        """Launch a pinned or any application"""
        normalized = app_id.lower()
        
        exec_cmd = None
        
        if normalized in self._pinned:
            exec_cmd = self._pinned[normalized].exec_cmd
        
        if not exec_cmd:
            desktop_info = self._find_desktop_info(app_id)
            exec_cmd = desktop_info.get('exec', '')
        
        if not exec_cmd:
            return self._gtk_launch(app_id)
        
        exec_cmd = self._clean_exec_cmd(exec_cmd)
        
        try:
            subprocess.Popen(
                exec_cmd,
                shell=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True,
            )
            print(f"[PinnedManager] 🚀 Launched: {exec_cmd}")
            return True
        except Exception as e:
            print(f"[PinnedManager] ❌ Launch failed: {e}")
            return self._gtk_launch(app_id)
    
    def _gtk_launch(self, app_id: str) -> bool:
        """Launch using gtk-launch"""
        try:
            subprocess.Popen(
                ['gtk-launch', app_id],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True,
            )
            print(f"[PinnedManager] 🚀 gtk-launch: {app_id}")
            return True
        except Exception as e:
            print(f"[PinnedManager] ❌ gtk-launch failed: {e}")
            return False
    
    def _clean_exec_cmd(self, cmd: str) -> str:
        """Remove field codes from exec command"""
        for code in ['%f', '%F', '%u', '%U', '%d', '%D', '%n', '%N', 
                     '%i', '%c', '%k', '%v', '%m']:
            cmd = cmd.replace(code, '')
        return ' '.join(cmd.split())
    
    # ═══════════════════════════════════════════════════════════════════════
    # DESKTOP FILE PARSING
    # ═══════════════════════════════════════════════════════════════════════
    
    def _find_desktop_info(self, app_id: str) -> dict:
        """Find and parse .desktop file for app"""
        if app_id in self._desktop_cache:
            return self._desktop_cache[app_id]
        
        desktop_file = self._find_desktop_file(app_id)
        if not desktop_file:
            return {}
        
        info = self._parse_desktop_file(desktop_file)
        self._desktop_cache[app_id] = info
        return info
    
    def _find_desktop_file(self, app_id: str) -> Optional[Path]:
        """Find .desktop file for app"""
        normalized = app_id.lower()
        
        variations = [
            f"{app_id}.desktop",
            f"{normalized}.desktop",
            f"{app_id.replace('-', '_')}.desktop",
            f"{app_id.replace('_', '-')}.desktop",
            f"org.gnome.{app_id.capitalize()}.desktop",
        ]
        
        for desktop_path in self.DESKTOP_PATHS:
            if not desktop_path.exists():
                continue
            
            for variation in variations:
                desktop_file = desktop_path / variation
                if desktop_file.exists():
                    return desktop_file
            
            try:
                for file in desktop_path.glob("*.desktop"):
                    if normalized in file.stem.lower():
                        return file
            except Exception:
                pass
        
        return None
    
    def _parse_desktop_file(self, path: Path) -> dict:
        """Parse .desktop file"""
        info = {'path': str(path)}
        
        try:
            content = path.read_text()
            in_desktop_entry = False
            
            for line in content.split('\n'):
                line = line.strip()
                
                if line == '[Desktop Entry]':
                    in_desktop_entry = True
                    continue
                elif line.startswith('[') and in_desktop_entry:
                    break
                
                if not in_desktop_entry or '=' not in line:
                    continue
                
                key, value = line.split('=', 1)
                key = key.strip()
                value = value.strip()
                
                if key == 'Exec':
                    info['exec'] = value
                elif key == 'Icon':
                    info['icon'] = value
                elif key == 'Name' and 'name' not in info:
                    info['name'] = value
                elif key == 'StartupWMClass':
                    info['wm_class'] = value
            
        except Exception as e:
            print(f"[PinnedManager] ⚠️ Parse error {path}: {e}")
        
        return info
    
    # ═══════════════════════════════════════════════════════════════════════
    # PERSISTENCE
    # ═══════════════════════════════════════════════════════════════════════
    
    def _load(self) -> None:
        """Load pinned apps from JSON"""
        if not self.config_path.exists():
            self._create_defaults()
            return
        
        try:
            with open(self.config_path, 'r') as f:
                data = json.load(f)
            
            self._pinned.clear()
            self._order.clear()
            
            for app_data in data.get('pinned_apps', []):
                pinned = PinnedApp(
                    app_id=app_data.get('app_id', ''),
                    wm_class=app_data.get('wm_class', ''),
                    exec_cmd=app_data.get('exec_cmd', ''),
                    icon=app_data.get('icon', ''),
                    desktop_file=app_data.get('desktop_file', ''),
                    pinned_at=app_data.get('pinned_at', ''),
                    order=app_data.get('order', 0),
                )
                
                self._pinned[pinned.app_id] = pinned
                self._order.append(pinned.app_id)
            
            self._order.sort(key=lambda x: self._pinned.get(x, PinnedApp('')).order)
            
        except Exception as e:
            print(f"[PinnedManager] ⚠️ Load error: {e}")
            self._create_defaults()
    
    def _save(self) -> None:
        """Save pinned apps to JSON"""
        try:
            data = {
                'version': '2.0',
                'last_updated': datetime.now().isoformat(),
                'pinned_apps': [
                    asdict(self._pinned[app_id]) 
                    for app_id in self._order 
                    if app_id in self._pinned
                ],
            }
            
            with open(self.config_path, 'w') as f:
                json.dump(data, f, indent=2)
            
        except Exception as e:
            print(f"[PinnedManager] ❌ Save error: {e}")
    
    def _create_defaults(self) -> None:
        """Create default pinned apps"""
        defaults = [
            ('firefox', 'firefox', 'firefox'),
            ('kitty', 'kitty', 'kitty'),
            ('nautilus', 'org.gnome.Nautilus', 'nautilus'),
            ('code', 'code', 'code'),
        ]
        
        for app_id, wm_class, exec_cmd in defaults:
            desktop_info = self._find_desktop_info(app_id)
            if desktop_info or True:  # Always add defaults
                self._pinned[app_id] = PinnedApp(
                    app_id=app_id,
                    wm_class=wm_class,
                    exec_cmd=desktop_info.get('exec', exec_cmd) if desktop_info else exec_cmd,
                    icon=desktop_info.get('icon', '') if desktop_info else '',
                    desktop_file=desktop_info.get('path', '') if desktop_info else '',
                    order=len(self._order),
                )
                self._order.append(app_id)
        
        self._save()
    
    # ═══════════════════════════════════════════════════════════════════════
    # LISTENERS
    # ═══════════════════════════════════════════════════════════════════════
    
    def on_change(self, callback: Callable[[], None]) -> None:
        """Register change listener"""
        if callback not in self._listeners:
            self._listeners.append(callback)
    
    def remove_listener(self, callback: Callable[[], None]) -> None:
        """Remove change listener"""
        if callback in self._listeners:
            self._listeners.remove(callback)
    
    def _notify_listeners(self) -> None:
        """Notify all listeners"""
        try:
            from gi.repository import GLib
            for listener in self._listeners:
                GLib.idle_add(listener)
        except ImportError:
            for listener in self._listeners:
                try:
                    listener()
                except Exception as e:
                    print(f"[PinnedManager] ⚠️ Listener error: {e}")


def get_pinned_manager() -> PinnedManager:
    """Get singleton PinnedManager instance"""
    return PinnedManager()


# ═══════════════════════════════════════════════════════════════════════════════
# TESTING
# ═══════════════════════════════════════════════════════════════════════════════

if __name__ == "__main__":
    pm = get_pinned_manager()
    
    print(f"\n📌 Pinned Apps ({len(pm.get_pinned_apps())}):")
    for app in pm.get_pinned_apps():
        exec_preview = app.exec_cmd[:30] + "..." if app.exec_cmd else 'N/A'
        print(f"   {app.app_id}: {app.wm_class} -> {exec_preview}")
    
    print("\n🧪 Testing pin/unpin...")
    pm.pin_app("test-app", wm_class="test", exec_cmd="echo test")
    print(f"   Is test-app pinned? {pm.is_pinned('test-app')}")
    
    pm.unpin_app("test-app")
    print(f"   Is test-app pinned? {pm.is_pinned('test-app')}")
    
    print("\n🚀 Desktop file lookup test:")
    print(f"   Firefox: {pm._find_desktop_info('firefox')}")