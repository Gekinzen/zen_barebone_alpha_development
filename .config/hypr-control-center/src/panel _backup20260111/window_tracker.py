#!/usr/bin/env python3
"""
Window Tracker Module
Maintains real-time window state for taskbar

Location: ~/.config/hypr-control-center/src/panel/window_tracker.py

Features:
- Tracks all open windows grouped by app class
- Real-time updates via Hyprland IPC events
- Focus state tracking
- Callback system for UI updates
"""

import asyncio
import sys
from dataclasses import dataclass, field
from typing import Dict, List, Callable, Optional, Set
from collections import OrderedDict
from pathlib import Path
import time

# Fix imports for both module and direct execution
_panel_dir = Path(__file__).parent
if str(_panel_dir) not in sys.path:
    sys.path.insert(0, str(_panel_dir))

from hypr_ipc import (
    HyprlandIPC,
    HyprEvent,
    HyprEventType,
    HyprWindow,
    hyprctl_json
)


@dataclass
class TrackedWindow:
    """Individual tracked window"""
    address: str
    wm_class: str
    title: str
    workspace_id: int
    is_focused: bool = False
    is_floating: bool = False
    is_fullscreen: bool = False
    pid: int = 0
    last_focus_time: float = 0
    
    @classmethod
    def from_hypr_window(cls, hw: HyprWindow) -> 'TrackedWindow':
        return cls(
            address=hw.address,
            wm_class=hw.wm_class,
            title=hw.title,
            workspace_id=hw.workspace_id,
            is_focused=hw.is_focused,
            is_floating=hw.is_floating,
            is_fullscreen=hw.is_fullscreen,
            pid=hw.pid,
            last_focus_time=time.time() if hw.is_focused else 0
        )


@dataclass
class AppGroup:
    """Group of windows belonging to same app"""
    wm_class: str
    windows: Dict[str, TrackedWindow] = field(default_factory=dict)
    
    @property
    def window_count(self) -> int:
        return len(self.windows)
    
    @property
    def has_focus(self) -> bool:
        return any(w.is_focused for w in self.windows.values())
    
    @property
    def focused_window(self) -> Optional[TrackedWindow]:
        for w in self.windows.values():
            if w.is_focused:
                return w
        return None
    
    @property
    def most_recent_window(self) -> Optional[TrackedWindow]:
        """Get most recently focused window"""
        if not self.windows:
            return None
        return max(self.windows.values(), key=lambda w: w.last_focus_time)
    
    @property
    def display_title(self) -> str:
        """Get display title (from focused or most recent window)"""
        focused = self.focused_window
        if focused:
            return focused.title
        recent = self.most_recent_window
        if recent:
            return recent.title
        return self.wm_class
    
    @property
    def all_titles(self) -> List[str]:
        """Get all window titles"""
        return [w.title for w in self.windows.values()]
    
    def add_window(self, window: TrackedWindow):
        self.windows[window.address] = window
    
    def remove_window(self, address: str) -> bool:
        if address in self.windows:
            del self.windows[address]
            return True
        return False
    
    def get_window(self, address: str) -> Optional[TrackedWindow]:
        return self.windows.get(address)


class WindowTracker:
    """
    Real-time window tracker for taskbar
    
    Usage:
        tracker = WindowTracker()
        tracker.on_change(my_callback)  # Called when windows change
        await tracker.start()           # Start tracking
        
        # Access state
        apps = tracker.get_app_groups()  # All apps with windows
        focused = tracker.get_focused_app()  # Currently focused app
    """
    
    def __init__(self):
        self.ipc = HyprlandIPC()
        
        # App groups: {wm_class: AppGroup}
        self._app_groups: OrderedDict[str, AppGroup] = OrderedDict()
        
        # Quick lookup: {address: wm_class}
        self._address_to_class: Dict[str, str] = {}
        
        # Currently focused
        self._focused_address: Optional[str] = None
        self._focused_class: Optional[str] = None
        
        # Change callbacks
        self._change_callbacks: List[Callable[[], None]] = []
        
        # App order (for taskbar ordering)
        self._app_order: List[str] = []
        
        # Ignored classes (system windows, etc.)
        self._ignored_classes: Set[str] = {
            '',  # Empty class
            'hypr-widget-clock',
            'hypr-widget-weather', 
            'hypr-widget-system_monitor',
            'Hyprland',
            'com.hyprland.panel',  # Our taskbar panel
            'com.hyprland.controlcenter',  # Control center
        }
        
        print("[WindowTracker] Initialized")
    
    def add_ignored_class(self, wm_class: str):
        """Add class to ignore list"""
        self._ignored_classes.add(wm_class)
    
    def _should_track(self, wm_class: str) -> bool:
        """Check if window class should be tracked"""
        if not wm_class:
            return False
        if wm_class in self._ignored_classes:
            return False
        # Ignore windows starting with hypr-widget
        if wm_class.startswith('hypr-widget'):
            return False
        return True
    
    # ==========================================
    # PUBLIC API
    # ==========================================
    
    def on_change(self, callback: Callable[[], None]):
        """Register callback for when window state changes"""
        self._change_callbacks.append(callback)
        print(f"[WindowTracker] Change callback registered")
    
    def get_app_groups(self) -> List[AppGroup]:
        """Get all app groups in order"""
        return [self._app_groups[cls] for cls in self._app_order if cls in self._app_groups]
    
    def get_app_group(self, wm_class: str) -> Optional[AppGroup]:
        """Get specific app group"""
        return self._app_groups.get(wm_class)
    
    def get_focused_app(self) -> Optional[AppGroup]:
        """Get currently focused app group"""
        if self._focused_class:
            return self._app_groups.get(self._focused_class)
        return None
    
    def get_focused_window(self) -> Optional[TrackedWindow]:
        """Get currently focused window"""
        if self._focused_class and self._focused_address:
            group = self._app_groups.get(self._focused_class)
            if group:
                return group.get_window(self._focused_address)
        return None
    
    def get_window_count(self, wm_class: str) -> int:
        """Get window count for app"""
        group = self._app_groups.get(wm_class)
        return group.window_count if group else 0
    
    def get_all_windows(self) -> List[TrackedWindow]:
        """Get all tracked windows"""
        windows = []
        for group in self._app_groups.values():
            windows.extend(group.windows.values())
        return windows
    
    def get_windows_for_class(self, wm_class: str) -> List[TrackedWindow]:
        """Get all windows for a class"""
        group = self._app_groups.get(wm_class)
        if group:
            return list(group.windows.values())
        return []
    
    # ==========================================
    # WINDOW ACTIONS
    # ==========================================
    
    async def focus_window(self, address: str):
        """Focus a specific window"""
        await self.ipc.focus_window(address)
    
    async def focus_app(self, wm_class: str):
        """Focus most recent window of an app"""
        group = self._app_groups.get(wm_class)
        if group:
            window = group.most_recent_window
            if window:
                await self.focus_window(window.address)
    
    async def close_window(self, address: str):
        """Close a specific window"""
        await self.ipc.close_window(address)
    
    async def close_app(self, wm_class: str):
        """Close all windows of an app"""
        group = self._app_groups.get(wm_class)
        if group:
            for address in list(group.windows.keys()):
                await self.close_window(address)
    
    # ==========================================
    # STATE MANAGEMENT
    # ==========================================
    
    def _notify_change(self):
        """Notify all callbacks of state change"""
        for callback in self._change_callbacks:
            try:
                callback()
            except Exception as e:
                print(f"[WindowTracker] Callback error: {e}")
    
    def _add_window(self, window: TrackedWindow):
        """Add window to tracking"""
        wm_class = window.wm_class
        
        if not self._should_track(wm_class):
            return
        
        # Create app group if needed
        if wm_class not in self._app_groups:
            self._app_groups[wm_class] = AppGroup(wm_class=wm_class)
            self._app_order.append(wm_class)
            print(f"[WindowTracker] New app: {wm_class}")
        
        # Add window to group
        self._app_groups[wm_class].add_window(window)
        self._address_to_class[window.address] = wm_class
        
        print(f"[WindowTracker] Window added: [{wm_class}] {window.title[:30]}")
        self._notify_change()
    
    def _remove_window(self, address: str):
        """Remove window from tracking"""
        wm_class = self._address_to_class.get(address)
        if not wm_class:
            return
        
        group = self._app_groups.get(wm_class)
        if group:
            group.remove_window(address)
            print(f"[WindowTracker] Window removed: {address}")
            
            # Remove app group if empty
            if group.window_count == 0:
                del self._app_groups[wm_class]
                if wm_class in self._app_order:
                    self._app_order.remove(wm_class)
                print(f"[WindowTracker] App removed: {wm_class}")
        
        # Clean up lookups
        del self._address_to_class[address]
        
        if self._focused_address == address:
            self._focused_address = None
            self._focused_class = None
        
        self._notify_change()
    
    def _update_focus(self, wm_class: str, title: str):
        """Update focus state"""
        # Clear old focus
        if self._focused_class and self._focused_address:
            old_group = self._app_groups.get(self._focused_class)
            if old_group:
                old_window = old_group.get_window(self._focused_address)
                if old_window:
                    old_window.is_focused = False
        
        # Find new focused window
        # We get class and title from event, need to find the window
        group = self._app_groups.get(wm_class)
        if group:
            # Find window by title (best match)
            for addr, window in group.windows.items():
                if window.title == title or title in window.title:
                    window.is_focused = True
                    window.last_focus_time = time.time()
                    self._focused_address = addr
                    self._focused_class = wm_class
                    print(f"[WindowTracker] Focus: [{wm_class}] {title[:30]}")
                    self._notify_change()
                    return
            
            # Fallback: just mark the most recent as focused
            recent = group.most_recent_window
            if recent:
                recent.is_focused = True
                recent.last_focus_time = time.time()
                self._focused_address = recent.address
                self._focused_class = wm_class
        
        self._notify_change()
    
    def _update_window_title(self, address: str):
        """Update window title (need to fetch from hyprctl)"""
        # We need to get the new title
        clients = hyprctl_json('clients')
        if not clients:
            return
        
        for client in clients:
            if client.get('address') == address:
                wm_class = self._address_to_class.get(address)
                if wm_class:
                    group = self._app_groups.get(wm_class)
                    if group:
                        window = group.get_window(address)
                        if window:
                            old_title = window.title
                            window.title = client.get('title', '')
                            if old_title != window.title:
                                print(f"[WindowTracker] Title updated: {window.title[:40]}")
                                self._notify_change()
                break
    
    # ==========================================
    # INITIAL LOAD
    # ==========================================
    
    async def _load_initial_state(self):
        """Load current windows from Hyprland"""
        print("[WindowTracker] Loading initial state...")
        
        windows = await self.ipc.get_clients()
        active = await self.ipc.get_active_window()
        
        for hw in windows:
            tw = TrackedWindow.from_hypr_window(hw)
            
            # Check if this is the focused window
            if active and hw.address == active.address:
                tw.is_focused = True
                tw.last_focus_time = time.time()
                self._focused_address = tw.address
                self._focused_class = tw.wm_class
            
            self._add_window(tw)
        
        print(f"[WindowTracker] Loaded {len(self._app_groups)} apps, {len(self._address_to_class)} windows")
    
    # ==========================================
    # EVENT HANDLERS
    # ==========================================
    
    def _on_window_open(self, event: HyprEvent):
        """Handle window open event"""
        data = event.parsed
        if not data:
            return
        
        tw = TrackedWindow(
            address=data.get('address', ''),
            wm_class=data.get('class', ''),
            title=data.get('title', ''),
            workspace_id=int(data.get('workspace', 0)) if data.get('workspace', '').isdigit() else 0
        )
        
        self._add_window(tw)
    
    def _on_window_close(self, event: HyprEvent):
        """Handle window close event"""
        address = event.parsed.get('address', '')
        if address:
            self._remove_window(address)
    
    def _on_window_focus(self, event: HyprEvent):
        """Handle focus change event"""
        data = event.parsed
        if data:
            self._update_focus(
                data.get('class', ''),
                data.get('title', '')
            )
    
    def _on_window_title(self, event: HyprEvent):
        """Handle title change event"""
        address = event.parsed.get('address', '')
        if address:
            self._update_window_title(address)
    
    # ==========================================
    # MAIN LOOP
    # ==========================================
    
    async def start(self):
        """Start tracking windows"""
        print("[WindowTracker] Starting...")
        
        # Load current state
        await self._load_initial_state()
        
        # Subscribe to events
        self.ipc.subscribe(HyprEventType.WINDOW_OPEN, self._on_window_open)
        self.ipc.subscribe(HyprEventType.WINDOW_CLOSE, self._on_window_close)
        self.ipc.subscribe(HyprEventType.WINDOW_FOCUS, self._on_window_focus)
        self.ipc.subscribe(HyprEventType.WINDOW_TITLE, self._on_window_title)
        
        print("[WindowTracker] Subscribed to events, starting listener...")
        
        # Start event listener
        await self.ipc.listen_events()
    
    def stop(self):
        """Stop tracking"""
        self.ipc.stop()
        print("[WindowTracker] Stopped")


# ==========================================
# DEBUG / PRINT HELPERS
# ==========================================

def print_state(tracker: WindowTracker):
    """Print current tracker state"""
    print("\n" + "="*60)
    print("  WINDOW TRACKER STATE")
    print("="*60)
    
    apps = tracker.get_app_groups()
    
    if not apps:
        print("  No tracked windows")
        return
    
    for group in apps:
        focus_marker = "★" if group.has_focus else " "
        count = f"({group.window_count})" if group.window_count > 1 else ""
        print(f"\n  {focus_marker} [{group.wm_class}] {count}")
        
        for addr, window in group.windows.items():
            wfocus = "→" if window.is_focused else " "
            print(f"      {wfocus} {window.title[:45]}")
            print(f"        addr: {addr} | ws: {window.workspace_id}")
    
    print("\n" + "="*60)


# ==========================================
# TEST / DEMO
# ==========================================

async def demo():
    """Demo the window tracker"""
    print("""
╔══════════════════════════════════════════════════════════╗
║            WINDOW TRACKER DEMO                           ║
╚══════════════════════════════════════════════════════════╝
""")
    
    tracker = WindowTracker()
    
    # Register change callback
    def on_change():
        print("\n[CHANGE DETECTED]")
        print_state(tracker)
    
    tracker.on_change(on_change)
    
    print("Starting tracker... (Ctrl+C to stop)")
    print("Try opening/closing/focusing windows!\n")
    
    try:
        await tracker.start()
    except KeyboardInterrupt:
        print("\n\nStopping tracker...")
        tracker.stop()
    
    print("\nFinal state:")
    print_state(tracker)


if __name__ == "__main__":
    asyncio.run(demo())