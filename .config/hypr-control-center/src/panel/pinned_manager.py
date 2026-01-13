#!/usr/bin/env python3
"""
Pinned Manager Module
Manages pinned applications in the taskbar

Location: ~/.config/hypr-control-center/src/panel/pinned_manager.py

Features:
- Load/save pinned apps from JSON config
- Add/remove/reorder pinned apps
- Launch pinned apps
- Integration with window tracker
"""

import json
import subprocess
import os
from pathlib import Path
from typing import List, Optional, Dict, Callable
from dataclasses import dataclass, field

# Local imports
try:
    from .icon_resolver import get_resolver, DesktopEntry, get_nerd_icon
except ImportError:
    from icon_resolver import get_resolver, DesktopEntry, get_nerd_icon


@dataclass
class PinnedApp:
    """Represents a pinned application"""
    app_id: str                    # Unique identifier (usually wm_class or desktop file name)
    name: str                      # Display name
    icon: str                      # Icon name
    exec_cmd: str                  # Command to launch
    desktop_file: Optional[str] = None  # Path to .desktop file
    wm_class: Optional[str] = None      # WM_CLASS for matching with running windows
    position: int = 0                    # Position in pinned list
    
    @classmethod
    def from_desktop_entry(cls, entry: DesktopEntry, position: int = 0) -> 'PinnedApp':
        """Create PinnedApp from DesktopEntry"""
        return cls(
            app_id=entry.wm_class.lower() if entry.wm_class else Path(entry.desktop_file).stem.lower(),
            name=entry.name,
            icon=entry.icon,
            exec_cmd=entry.exec_cmd,
            desktop_file=entry.desktop_file,
            wm_class=entry.wm_class.lower() if entry.wm_class else None,
            position=position
        )
    
    @classmethod
    def from_dict(cls, data: dict, position: int = 0) -> 'PinnedApp':
        """Create PinnedApp from dictionary"""
        return cls(
            app_id=data.get('app_id', ''),
            name=data.get('name', ''),
            icon=data.get('icon', ''),
            exec_cmd=data.get('exec_cmd', ''),
            desktop_file=data.get('desktop_file'),
            wm_class=data.get('wm_class'),
            position=position
        )
    
    def to_dict(self) -> dict:
        """Convert to dictionary for JSON serialization"""
        return {
            'app_id': self.app_id,
            'name': self.name,
            'icon': self.icon,
            'exec_cmd': self.exec_cmd,
            'desktop_file': self.desktop_file,
            'wm_class': self.wm_class,
        }
    
    def launch(self) -> bool:
        """Launch the application"""
        if not self.exec_cmd:
            print(f"[PinnedManager] No exec command for {self.name}")
            return False
        
        try:
            # Use subprocess to launch detached
            subprocess.Popen(
                self.exec_cmd,
                shell=True,
                start_new_session=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
            print(f"[PinnedManager] Launched: {self.name}")
            return True
        except Exception as e:
            print(f"[PinnedManager] Failed to launch {self.name}: {e}")
            return False


class PinnedManager:
    """
    Manages pinned applications for the taskbar
    
    Usage:
        manager = PinnedManager()
        
        # Get pinned apps
        pinned = manager.get_pinned_apps()
        
        # Pin an app
        manager.pin_app("firefox")
        
        # Unpin an app
        manager.unpin_app("firefox")
        
        # Reorder
        manager.move_app("firefox", 0)  # Move to first position
        
        # Launch pinned app
        manager.launch_app("firefox")
    """
    
    def __init__(self, config_dir: Optional[Path] = None):
        self.config_dir = config_dir or Path.home() / ".config/hypr-control-center"
        
        # Use existing taskbar.json (same as your current config)
        self.config_file = self.config_dir / "taskbar.json"
        
        # Ensure config directory exists
        self.config_file.parent.mkdir(parents=True, exist_ok=True)
        
        # Pinned apps list
        self._pinned_apps: List[PinnedApp] = []
        
        # Change callbacks
        self._change_callbacks: List[Callable[[], None]] = []
        
        # Icon resolver
        self._resolver = get_resolver()
        
        # Load pinned apps
        self._load_pinned_apps()
        
        print(f"[PinnedManager] Loaded {len(self._pinned_apps)} pinned apps")
    
    # ==========================================
    # PERSISTENCE
    # ==========================================
    
    def _load_pinned_apps(self):
        """Load pinned apps from config file"""
        if not self.config_file.exists():
            # Create default pinned apps
            self._create_default_pinned()
            return
        
        try:
            with open(self.config_file, 'r') as f:
                data = json.load(f)
            
            pinned_list = data.get('pinned', [])
            self._pinned_apps = []
            
            for i, item in enumerate(pinned_list):
                if isinstance(item, str):
                    # Legacy format: just app_id string
                    app = self._create_pinned_from_id(item, i)
                    if app:
                        self._pinned_apps.append(app)
                elif isinstance(item, dict):
                    # Full format: dict with all fields
                    app = PinnedApp.from_dict(item, i)
                    # Try to fill missing info from desktop entry
                    if not app.name or not app.exec_cmd:
                        app = self._enhance_pinned_app(app, i)
                    self._pinned_apps.append(app)
            
            print(f"[PinnedManager] Loaded from {self.config_file}")
        
        except Exception as e:
            print(f"[PinnedManager] Error loading config: {e}")
            self._create_default_pinned()
    
    def _save_pinned_apps(self):
        """Save pinned apps to config file"""
        try:
            data = {
                'pinned': [app.to_dict() for app in self._pinned_apps]
            }
            
            with open(self.config_file, 'w') as f:
                json.dump(data, f, indent=2)
            
            print(f"[PinnedManager] Saved {len(self._pinned_apps)} pinned apps")
        
        except Exception as e:
            print(f"[PinnedManager] Error saving config: {e}")
    
    def _create_default_pinned(self):
        """Create default pinned apps"""
        default_apps = ['firefox', 'thunar', 'kitty', 'code-oss']
        
        self._pinned_apps = []
        for i, app_id in enumerate(default_apps):
            app = self._create_pinned_from_id(app_id, i)
            if app:
                self._pinned_apps.append(app)
        
        self._save_pinned_apps()
        print(f"[PinnedManager] Created default pinned apps")
    
    def _create_pinned_from_id(self, app_id: str, position: int) -> Optional[PinnedApp]:
        """Create PinnedApp from app_id by looking up desktop entry"""
        entry = self._resolver.get_desktop_entry(app_id)
        
        if entry:
            return PinnedApp.from_desktop_entry(entry, position)
        
        # Fallback: create minimal PinnedApp
        nerd_icon = get_nerd_icon(app_id)
        return PinnedApp(
            app_id=app_id.lower(),
            name=app_id.capitalize(),
            icon=app_id.lower(),
            exec_cmd=app_id.lower(),  # Try to run by name
            wm_class=app_id.lower(),
            position=position
        )
    
    def _enhance_pinned_app(self, app: PinnedApp, position: int) -> PinnedApp:
        """Enhance PinnedApp with info from desktop entry"""
        entry = self._resolver.get_desktop_entry(app.app_id)
        
        if entry:
            return PinnedApp(
                app_id=app.app_id,
                name=app.name or entry.name,
                icon=app.icon or entry.icon,
                exec_cmd=app.exec_cmd or entry.exec_cmd,
                desktop_file=app.desktop_file or entry.desktop_file,
                wm_class=app.wm_class or (entry.wm_class.lower() if entry.wm_class else None),
                position=position
            )
        
        return app
    
    # ==========================================
    # PUBLIC API
    # ==========================================
    
    def on_change(self, callback: Callable[[], None]):
        """Register callback for when pinned apps change"""
        self._change_callbacks.append(callback)
    
    def _notify_change(self):
        """Notify all callbacks of change"""
        for callback in self._change_callbacks:
            try:
                callback()
            except Exception as e:
                print(f"[PinnedManager] Callback error: {e}")
    
    def get_pinned_apps(self) -> List[PinnedApp]:
        """Get list of pinned apps in order"""
        return sorted(self._pinned_apps, key=lambda a: a.position)
    
    def get_pinned_app(self, app_id: str) -> Optional[PinnedApp]:
        """Get specific pinned app by ID"""
        app_id_lower = app_id.lower()
        for app in self._pinned_apps:
            if app.app_id == app_id_lower or app.wm_class == app_id_lower:
                return app
        return None
    
    def is_pinned(self, app_id: str) -> bool:
        """Check if app is pinned"""
        return self.get_pinned_app(app_id) is not None
    
    def pin_app(self, app_id: str, position: Optional[int] = None) -> bool:
        """Pin an application"""
        if self.is_pinned(app_id):
            print(f"[PinnedManager] {app_id} is already pinned")
            return False
        
        # Determine position
        if position is None:
            position = len(self._pinned_apps)
        
        # Create PinnedApp
        app = self._create_pinned_from_id(app_id, position)
        if not app:
            print(f"[PinnedManager] Could not find app: {app_id}")
            return False
        
        # Insert at position
        self._pinned_apps.append(app)
        self._reindex_positions()
        
        # Save and notify
        self._save_pinned_apps()
        self._notify_change()
        
        print(f"[PinnedManager] Pinned: {app.name}")
        return True
    
    def unpin_app(self, app_id: str) -> bool:
        """Unpin an application"""
        app = self.get_pinned_app(app_id)
        if not app:
            print(f"[PinnedManager] {app_id} is not pinned")
            return False
        
        self._pinned_apps.remove(app)
        self._reindex_positions()
        
        # Save and notify
        self._save_pinned_apps()
        self._notify_change()
        
        print(f"[PinnedManager] Unpinned: {app.name}")
        return True
    
    def move_app(self, app_id: str, new_position: int) -> bool:
        """Move a pinned app to new position"""
        app = self.get_pinned_app(app_id)
        if not app:
            return False
        
        # Clamp position
        new_position = max(0, min(new_position, len(self._pinned_apps) - 1))
        
        # Remove and reinsert
        self._pinned_apps.remove(app)
        self._pinned_apps.insert(new_position, app)
        self._reindex_positions()
        
        # Save and notify
        self._save_pinned_apps()
        self._notify_change()
        
        print(f"[PinnedManager] Moved {app.name} to position {new_position}")
        return True
    
    def swap_apps(self, app_id1: str, app_id2: str) -> bool:
        """Swap positions of two pinned apps"""
        app1 = self.get_pinned_app(app_id1)
        app2 = self.get_pinned_app(app_id2)
        
        if not app1 or not app2:
            return False
        
        # Swap positions
        app1.position, app2.position = app2.position, app1.position
        
        # Save and notify
        self._save_pinned_apps()
        self._notify_change()
        
        return True
    
    def _reindex_positions(self):
        """Reindex positions after changes"""
        for i, app in enumerate(self._pinned_apps):
            app.position = i
    
    def launch_app(self, app_id: str) -> bool:
        """Launch a pinned app"""
        app = self.get_pinned_app(app_id)
        if app:
            return app.launch()
        
        # Try to launch by looking up desktop entry
        entry = self._resolver.get_desktop_entry(app_id)
        if entry and entry.exec_cmd:
            try:
                subprocess.Popen(
                    entry.exec_cmd,
                    shell=True,
                    start_new_session=True,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL
                )
                return True
            except:
                pass
        
        return False
    
    def get_app_ids(self) -> List[str]:
        """Get list of pinned app IDs"""
        return [app.app_id for app in self.get_pinned_apps()]
    
    def get_wm_classes(self) -> List[str]:
        """Get list of pinned app WM classes"""
        return [app.wm_class for app in self.get_pinned_apps() if app.wm_class]
    
    def matches_pinned(self, wm_class: str) -> Optional[PinnedApp]:
        """Check if a WM class matches any pinned app"""
        wm_class_lower = wm_class.lower()
        
        for app in self._pinned_apps:
            if app.wm_class and app.wm_class == wm_class_lower:
                return app
            if app.app_id == wm_class_lower:
                return app
            # Partial match
            if app.wm_class and (app.wm_class in wm_class_lower or wm_class_lower in app.wm_class):
                return app
        
        return None
    
    def reload(self):
        """Reload pinned apps from config"""
        self._pinned_apps.clear()
        self._load_pinned_apps()
        self._notify_change()


# ==========================================
# SINGLETON INSTANCE
# ==========================================

_manager_instance: Optional[PinnedManager] = None

def get_pinned_manager(config_dir: Optional[Path] = None) -> PinnedManager:
    """Get singleton PinnedManager instance"""
    global _manager_instance
    if _manager_instance is None:
        _manager_instance = PinnedManager(config_dir)
    return _manager_instance


# ==========================================
# TEST / DEMO
# ==========================================

def demo():
    """Demo the pinned manager"""
    print("""
╔══════════════════════════════════════════════════════════╗
║              PINNED MANAGER DEMO                         ║
╚══════════════════════════════════════════════════════════╝
""")
    
    manager = PinnedManager()
    
    print("\n  CURRENT PINNED APPS")
    print("  " + "-"*60)
    print(f"  {'#':<3} {'APP ID':<15} {'NAME':<20} {'WM_CLASS':<15}")
    print("  " + "-"*60)
    
    for app in manager.get_pinned_apps():
        print(f"  {app.position:<3} {app.app_id:<15} {app.name:<20} {app.wm_class or 'N/A':<15}")
    
    print("\n  " + "-"*60)
    print(f"  Config file: {manager.config_file}")
    
    # Interactive demo
    print("\n  INTERACTIVE COMMANDS:")
    print("  - pin <app_id>     : Pin an app")
    print("  - unpin <app_id>   : Unpin an app")
    print("  - launch <app_id>  : Launch an app")
    print("  - list             : Show pinned apps")
    print("  - quit             : Exit demo")
    print()
    
    while True:
        try:
            cmd = input("  > ").strip().split()
            if not cmd:
                continue
            
            action = cmd[0].lower()
            
            if action == 'quit' or action == 'q':
                break
            
            elif action == 'list':
                for app in manager.get_pinned_apps():
                    nerd = get_nerd_icon(app.app_id)
                    print(f"    {nerd} {app.name} ({app.app_id})")
            
            elif action == 'pin' and len(cmd) > 1:
                manager.pin_app(cmd[1])
            
            elif action == 'unpin' and len(cmd) > 1:
                manager.unpin_app(cmd[1])
            
            elif action == 'launch' and len(cmd) > 1:
                manager.launch_app(cmd[1])
            
            else:
                print("    Unknown command")
        
        except KeyboardInterrupt:
            print("\n")
            break
        except EOFError:
            break
    
    print("\n  Done!")


if __name__ == "__main__":
    demo()