"""
WindowTracker - Real-time Hyprland Window Tracking
===================================================

Connects to Hyprland IPC socket and tracks all windows.
Provides grouped window data for taskbar rendering.

Key Features:
- Async IPC listener
- Window grouping by wm_class
- Focus tracking
- Multi-monitor support
"""

import json
import os
import socket
import subprocess
import asyncio
import threading
from pathlib import Path
from typing import Dict, List, Optional, Callable, Set
from dataclasses import dataclass, field
from datetime import datetime


@dataclass
class Window:
    """Represents a single Hyprland window"""
    address: str
    title: str
    wm_class: str
    workspace: int
    monitor: str
    floating: bool = False
    fullscreen: bool = False
    focused: bool = False
    pid: int = 0
    
    @classmethod
    def from_hyprctl(cls, data: dict) -> 'Window':
        """Create Window from hyprctl JSON data"""
        return cls(
            address=data.get('address', ''),
            title=data.get('title', ''),
            wm_class=data.get('class', ''),
            workspace=data.get('workspace', {}).get('id', 0),
            monitor=data.get('monitor', ''),
            floating=data.get('floating', False),
            fullscreen=data.get('fullscreen', False),
            focused=data.get('focused', False),
            pid=data.get('pid', 0),
        )


@dataclass
class AppGroup:
    """Group of windows belonging to the same application"""
    wm_class: str
    windows: List[Window] = field(default_factory=list)
    
    @property
    def app_id(self) -> str:
        """Get normalized app ID"""
        return self.wm_class.lower().replace(' ', '-')
    
    @property
    def is_focused(self) -> bool:
        """Check if any window in group is focused"""
        return any(w.focused for w in self.windows)
    
    @property
    def focused_window(self) -> Optional[Window]:
        """Get focused window if any"""
        for w in self.windows:
            if w.focused:
                return w
        return None
    
    @property
    def window_count(self) -> int:
        """Get number of windows"""
        return len(self.windows)
    
    @property
    def first_window(self) -> Optional[Window]:
        """Get first window"""
        return self.windows[0] if self.windows else None
    
    def get_windows_on_monitor(self, monitor: str) -> List[Window]:
        """Get windows on specific monitor"""
        return [w for w in self.windows if w.monitor == monitor]


class WindowTracker:
    """
    Tracks Hyprland windows via IPC socket.
    
    IMPORTANT: Should be SHARED across all ZenPyBar instances
    to prevent duplicate taskbar items!
    
    Usage:
        tracker = WindowTracker()
        tracker.on_change(callback)
        tracker.start()
    """
    
    _instance = None
    _lock = threading.Lock()
    
    def __new__(cls, *args, **kwargs):
        """Singleton pattern - ONE tracker for ALL bars"""
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = super().__new__(cls)
                    cls._instance._initialized = False
        return cls._instance
    
    def __init__(self):
        if self._initialized:
            return
        
        # Hyprland socket paths
        self._runtime_dir = os.environ.get('XDG_RUNTIME_DIR', '/run/user/1000')
        self._hypr_instance = os.environ.get('HYPRLAND_INSTANCE_SIGNATURE', '')
        
        # State
        self._windows: Dict[str, Window] = {}  # address -> Window
        self._app_groups: Dict[str, AppGroup] = {}  # wm_class -> AppGroup
        self._focused_address: Optional[str] = None
        
        # Listeners
        self._listeners: List[Callable[[], None]] = []
        
        # Async handling
        self._loop: Optional[asyncio.AbstractEventLoop] = None
        self._thread: Optional[threading.Thread] = None
        self._running = False
        
        # Initial state
        self._load_initial_state()
        
        self._initialized = True
        print(f"[WindowTracker] ✅ Initialized ({len(self._windows)} windows)")
    
    # ═══════════════════════════════════════════════════════════════════════
    # PUBLIC API
    # ═══════════════════════════════════════════════════════════════════════
    
    def get_app_groups(self) -> Dict[str, AppGroup]:
        """Get all app groups"""
        return self._app_groups.copy()
    
    def get_running_apps(self) -> List[str]:
        """Get list of running app wm_classes"""
        return list(self._app_groups.keys())
    
    def get_focused_app(self) -> Optional[str]:
        """Get wm_class of focused app"""
        if self._focused_address and self._focused_address in self._windows:
            return self._windows[self._focused_address].wm_class
        return None
    
    def get_windows_for_app(self, wm_class: str) -> List[Window]:
        """Get all windows for an app"""
        if wm_class in self._app_groups:
            return self._app_groups[wm_class].windows
        return []
    
    def on_change(self, callback: Callable[[], None]) -> None:
        """Register change listener"""
        if callback not in self._listeners:
            self._listeners.append(callback)
    
    def remove_listener(self, callback: Callable[[], None]) -> None:
        """Remove change listener"""
        if callback in self._listeners:
            self._listeners.remove(callback)
    
    # ═══════════════════════════════════════════════════════════════════════
    # HYPRLAND COMMANDS
    # ═══════════════════════════════════════════════════════════════════════
    
    def focus_window(self, address: str) -> bool:
        """Focus a window by address"""
        try:
            subprocess.run(
                ['hyprctl', 'dispatch', 'focuswindow', f'address:{address}'],
                check=True, capture_output=True
            )
            return True
        except Exception as e:
            print(f"[WindowTracker] ❌ Focus failed: {e}")
            return False
    
    def close_window(self, address: str) -> bool:
        """Close a window by address"""
        try:
            subprocess.run(
                ['hyprctl', 'dispatch', 'closewindow', f'address:{address}'],
                check=True, capture_output=True
            )
            return True
        except Exception as e:
            print(f"[WindowTracker] ❌ Close failed: {e}")
            return False
    
    def close_all_windows(self, wm_class: str) -> bool:
        """Close all windows of an app"""
        if wm_class not in self._app_groups:
            return False
        
        for window in self._app_groups[wm_class].windows:
            self.close_window(window.address)
        
        return True
    
    # ═══════════════════════════════════════════════════════════════════════
    # INITIAL STATE
    # ═══════════════════════════════════════════════════════════════════════
    
    def _load_initial_state(self) -> None:
        """Load current window state from hyprctl"""
        try:
            result = subprocess.run(
                ['hyprctl', '-j', 'clients'],
                capture_output=True, text=True, check=True
            )
            windows_data = json.loads(result.stdout)
            
            # Get focused window
            active_result = subprocess.run(
                ['hyprctl', '-j', 'activewindow'],
                capture_output=True, text=True
            )
            
            focused_address = None
            if active_result.returncode == 0:
                try:
                    active_data = json.loads(active_result.stdout)
                    focused_address = active_data.get('address')
                except json.JSONDecodeError:
                    pass
            
            self._windows.clear()
            self._app_groups.clear()
            
            for win_data in windows_data:
                window = Window.from_hyprctl(win_data)
                window.focused = (window.address == focused_address)
                
                self._windows[window.address] = window
                
                # Group by wm_class
                wm_class = window.wm_class
                if wm_class not in self._app_groups:
                    self._app_groups[wm_class] = AppGroup(wm_class=wm_class)
                self._app_groups[wm_class].windows.append(window)
            
            self._focused_address = focused_address
            
        except Exception as e:
            print(f"[WindowTracker] ❌ Initial load failed: {e}")
    
    # ═══════════════════════════════════════════════════════════════════════
    # ASYNC IPC LISTENER
    # ═══════════════════════════════════════════════════════════════════════
    
    def start(self) -> None:
        """Start async IPC listener in background thread"""
        if self._running:
            return
        
        self._running = True
        self._thread = threading.Thread(target=self._run_async_loop, daemon=True)
        self._thread.start()
        print("[WindowTracker] 🚀 Started IPC listener")
    
    def stop(self) -> None:
        """Stop IPC listener"""
        self._running = False
        if self._loop:
            self._loop.call_soon_threadsafe(self._loop.stop)
        print("[WindowTracker] 🛑 Stopped IPC listener")
    
    def _run_async_loop(self) -> None:
        """Run async event loop in thread"""
        self._loop = asyncio.new_event_loop()
        asyncio.set_event_loop(self._loop)
        
        try:
            self._loop.run_until_complete(self._listen_ipc())
        except Exception as e:
            print(f"[WindowTracker] ❌ Async loop error: {e}")
        finally:
            self._loop.close()
    
    async def _listen_ipc(self) -> None:
        """Listen to Hyprland IPC socket"""
        socket_path = f"{self._runtime_dir}/hypr/{self._hypr_instance}/.socket2.sock"
        
        if not Path(socket_path).exists():
            print(f"[WindowTracker] ❌ Socket not found: {socket_path}")
            return
        
        while self._running:
            try:
                reader, writer = await asyncio.open_unix_connection(socket_path)
                
                while self._running:
                    data = await reader.readline()
                    if not data:
                        break
                    
                    await self._handle_ipc_event(data.decode().strip())
                
            except Exception as e:
                print(f"[WindowTracker] ⚠️ IPC error: {e}")
                await asyncio.sleep(1)
    
    async def _handle_ipc_event(self, line: str) -> None:
        """Handle a single IPC event"""
        if '>>' not in line:
            return
        
        event_type, *data = line.split('>>')
        data = '>>'.join(data) if data else ''
        
        # Events we care about
        if event_type in ['openwindow', 'closewindow', 'activewindow', 
                          'movewindow', 'windowtitle', 'focusedmon']:
            # Reload full state (simple approach)
            self._load_initial_state()
            self._notify_listeners()
    
    def _notify_listeners(self) -> None:
        """Notify all listeners of state change"""
        try:
            from gi.repository import GLib
            for listener in self._listeners:
                GLib.idle_add(listener)
        except ImportError:
            # No GTK, call directly
            for listener in self._listeners:
                try:
                    listener()
                except Exception as e:
                    print(f"[WindowTracker] ⚠️ Listener error: {e}")
    
    # ═══════════════════════════════════════════════════════════════════════
    # DEBUG
    # ═══════════════════════════════════════════════════════════════════════
    
    def debug_print(self) -> None:
        """Print current state for debugging"""
        print(f"\n[WindowTracker] 📊 State:")
        print(f"   Total windows: {len(self._windows)}")
        print(f"   App groups: {len(self._app_groups)}")
        print(f"   Focused: {self._focused_address}")
        
        for wm_class, group in self._app_groups.items():
            print(f"\n   📦 {wm_class} ({group.window_count} windows)")
            for w in group.windows:
                focus = "👁️" if w.focused else "  "
                print(f"      {focus} {w.address[:12]}... - {w.title[:30]}")


def get_window_tracker() -> WindowTracker:
    """Get singleton WindowTracker instance"""
    return WindowTracker()


# ═══════════════════════════════════════════════════════════════════════════════
# TESTING
# ═══════════════════════════════════════════════════════════════════════════════

if __name__ == "__main__":
    import time
    
    tracker = get_window_tracker()
    tracker.debug_print()
    
    # Test callback
    def on_change():
        print("\n🔔 Windows changed!")
        tracker.debug_print()
    
    tracker.on_change(on_change)
    tracker.start()
    
    print("\n⏳ Listening for window events (Ctrl+C to stop)...")
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        tracker.stop()
        print("\n👋 Stopped")