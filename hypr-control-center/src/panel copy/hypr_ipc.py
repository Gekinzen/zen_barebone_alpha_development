#!/usr/bin/env python3
"""
Hyprland IPC Module
Handles communication with Hyprland via Unix sockets

Location: ~/.config/hypr-control-center/src/panel/hypr_ipc.py

Hyprland exposes two sockets:
- .socket.sock  - For sending commands (hyprctl equivalent)
- .socket2.sock - For receiving events (window open/close/focus etc)
"""

import os
import socket
import json
import asyncio
from pathlib import Path
from typing import Callable, Optional, Dict, List, Any
from dataclasses import dataclass, field
from enum import Enum


class HyprEventType(Enum):
    """Hyprland event types we care about"""
    WINDOW_OPEN = "openwindow"
    WINDOW_CLOSE = "closewindow"
    WINDOW_MOVED = "movewindow"
    WINDOW_FOCUS = "activewindow"
    WINDOW_TITLE = "windowtitle"
    WORKSPACE_CHANGE = "workspace"
    ACTIVE_LAYOUT = "activelayout"
    FULLSCREEN = "fullscreen"
    URGENT = "urgent"


@dataclass
class HyprWindow:
    """Represents a Hyprland window"""
    address: str
    wm_class: str
    title: str
    workspace_id: int
    workspace_name: str
    is_floating: bool
    is_fullscreen: bool
    is_focused: bool = False
    pid: int = 0
    
    @classmethod
    def from_dict(cls, data: dict) -> 'HyprWindow':
        """Create HyprWindow from hyprctl clients JSON"""
        return cls(
            address=data.get('address', ''),
            wm_class=data.get('class', ''),
            title=data.get('title', ''),
            workspace_id=data.get('workspace', {}).get('id', 0),
            workspace_name=data.get('workspace', {}).get('name', ''),
            is_floating=data.get('floating', False),
            is_fullscreen=data.get('fullscreen', False),
            is_focused=data.get('focusHistoryID', -1) == 0,
            pid=data.get('pid', 0)
        )


@dataclass
class HyprEvent:
    """Parsed Hyprland event"""
    event_type: str
    data: str
    parsed: Dict[str, Any] = field(default_factory=dict)
    
    @classmethod
    def parse(cls, raw: str) -> Optional['HyprEvent']:
        """Parse raw event string: 'eventtype>>data'"""
        if '>>' not in raw:
            return None
        
        parts = raw.split('>>', 1)
        event_type = parts[0]
        data = parts[1] if len(parts) > 1 else ''
        
        # Parse data based on event type
        parsed = {}
        
        if event_type == HyprEventType.WINDOW_OPEN.value:
            # openwindow>>ADDR,WORKSPACE,CLASS,TITLE
            segments = data.split(',', 3)
            if len(segments) >= 4:
                parsed = {
                    'address': f"0x{segments[0]}",
                    'workspace': segments[1],
                    'class': segments[2],
                    'title': segments[3]
                }
        
        elif event_type == HyprEventType.WINDOW_CLOSE.value:
            # closewindow>>ADDR
            parsed = {'address': f"0x{data}"}
        
        elif event_type == HyprEventType.WINDOW_FOCUS.value:
            # activewindow>>CLASS,TITLE
            segments = data.split(',', 1)
            if len(segments) >= 2:
                parsed = {
                    'class': segments[0],
                    'title': segments[1]
                }
        
        elif event_type == HyprEventType.WINDOW_TITLE.value:
            # windowtitle>>ADDR
            parsed = {'address': f"0x{data}"}
        
        elif event_type == HyprEventType.WORKSPACE_CHANGE.value:
            # workspace>>NAME
            parsed = {'name': data}
        
        elif event_type == HyprEventType.FULLSCREEN.value:
            # fullscreen>>0/1
            parsed = {'fullscreen': data == '1'}
        
        return cls(event_type=event_type, data=data, parsed=parsed)


class HyprlandIPC:
    """
    Hyprland IPC Client
    
    Usage:
        ipc = HyprlandIPC()
        
        # One-shot commands
        windows = await ipc.get_clients()
        active = await ipc.get_active_window()
        
        # Event subscription
        ipc.subscribe(HyprEventType.WINDOW_OPEN, my_callback)
        await ipc.listen_events()
    """
    
    def __init__(self):
        self.instance_signature = self._get_instance_signature()
        self.socket_dir = self._get_socket_dir()
        self.command_socket = self.socket_dir / ".socket.sock"
        self.event_socket = self.socket_dir / ".socket2.sock"
        
        # Event subscribers: {event_type: [callbacks]}
        self._subscribers: Dict[str, List[Callable]] = {}
        
        # Global subscriber (receives all events)
        self._global_subscribers: List[Callable] = []
        
        # Running flag for event loop
        self._running = False
        
        print(f"[HyprIPC] Instance: {self.instance_signature}")
        print(f"[HyprIPC] Socket dir: {self.socket_dir}")
    
    def _get_instance_signature(self) -> str:
        """Get Hyprland instance signature from environment"""
        sig = os.environ.get('HYPRLAND_INSTANCE_SIGNATURE', '')
        if not sig:
            # Try to find it
            runtime_dir = Path(os.environ.get('XDG_RUNTIME_DIR', '/tmp'))
            hypr_dir = runtime_dir / 'hypr'
            if hypr_dir.exists():
                # Get first directory
                for item in hypr_dir.iterdir():
                    if item.is_dir():
                        sig = item.name
                        break
        return sig
    
    def _get_socket_dir(self) -> Path:
        """Get Hyprland socket directory"""
        runtime_dir = Path(os.environ.get('XDG_RUNTIME_DIR', '/tmp'))
        return runtime_dir / 'hypr' / self.instance_signature
    
    async def send_command(self, command: str) -> str:
        """Send command to Hyprland and return response"""
        try:
            reader, writer = await asyncio.open_unix_connection(
                str(self.command_socket)
            )
            
            writer.write(command.encode())
            await writer.drain()
            
            response = await reader.read()
            writer.close()
            await writer.wait_closed()
            
            return response.decode()
        
        except Exception as e:
            print(f"[HyprIPC] Command error: {e}")
            return ""
    
    async def send_command_json(self, command: str) -> Any:
        """Send command and parse JSON response"""
        # Add 'j/' prefix for JSON output
        if not command.startswith('j/'):
            command = f"j/{command}"
        
        response = await self.send_command(command)
        
        try:
            return json.loads(response) if response else None
        except json.JSONDecodeError:
            print(f"[HyprIPC] JSON parse error: {response[:100]}")
            return None
    
    # ==========================================
    # HIGH-LEVEL COMMANDS
    # ==========================================
    
    async def get_clients(self) -> List[HyprWindow]:
        """Get all windows/clients"""
        data = await self.send_command_json("clients")
        if not data:
            return []
        
        return [HyprWindow.from_dict(w) for w in data]
    
    async def get_active_window(self) -> Optional[HyprWindow]:
        """Get currently focused window"""
        data = await self.send_command_json("activewindow")
        if not data or not data.get('address'):
            return None
        
        return HyprWindow.from_dict(data)
    
    async def get_workspaces(self) -> List[dict]:
        """Get all workspaces"""
        return await self.send_command_json("workspaces") or []
    
    async def get_active_workspace(self) -> Optional[dict]:
        """Get active workspace"""
        return await self.send_command_json("activeworkspace")
    
    async def get_monitors(self) -> List[dict]:
        """Get all monitors"""
        return await self.send_command_json("monitors") or []
    
    async def dispatch(self, command: str) -> str:
        """Execute a dispatch command"""
        return await self.send_command(f"dispatch {command}")
    
    async def focus_window(self, address: str) -> str:
        """Focus a specific window by address"""
        return await self.dispatch(f"focuswindow address:{address}")
    
    async def close_window(self, address: str) -> str:
        """Close a specific window by address"""
        return await self.dispatch(f"closewindow address:{address}")
    
    # ==========================================
    # EVENT SUBSCRIPTION
    # ==========================================
    
    def subscribe(self, event_type: HyprEventType, callback: Callable[[HyprEvent], None]):
        """Subscribe to specific event type"""
        key = event_type.value
        if key not in self._subscribers:
            self._subscribers[key] = []
        self._subscribers[key].append(callback)
        print(f"[HyprIPC] Subscribed to: {key}")
    
    def subscribe_all(self, callback: Callable[[HyprEvent], None]):
        """Subscribe to all events"""
        self._global_subscribers.append(callback)
        print(f"[HyprIPC] Subscribed to all events")
    
    def unsubscribe(self, event_type: HyprEventType, callback: Callable):
        """Unsubscribe from event type"""
        key = event_type.value
        if key in self._subscribers and callback in self._subscribers[key]:
            self._subscribers[key].remove(callback)
    
    def _dispatch_event(self, event: HyprEvent):
        """Dispatch event to subscribers"""
        # Specific subscribers
        if event.event_type in self._subscribers:
            for callback in self._subscribers[event.event_type]:
                try:
                    callback(event)
                except Exception as e:
                    print(f"[HyprIPC] Callback error: {e}")
        
        # Global subscribers
        for callback in self._global_subscribers:
            try:
                callback(event)
            except Exception as e:
                print(f"[HyprIPC] Global callback error: {e}")
    
    async def listen_events(self):
        """Start listening for Hyprland events (blocking)"""
        print(f"[HyprIPC] Connecting to event socket: {self.event_socket}")
        
        self._running = True
        
        while self._running:
            try:
                reader, writer = await asyncio.open_unix_connection(
                    str(self.event_socket)
                )
                
                print("[HyprIPC] Connected to event socket")
                
                while self._running:
                    data = await reader.readline()
                    if not data:
                        break
                    
                    line = data.decode().strip()
                    if not line:
                        continue
                    
                    event = HyprEvent.parse(line)
                    if event:
                        self._dispatch_event(event)
                
                writer.close()
                await writer.wait_closed()
                
            except ConnectionRefusedError:
                print("[HyprIPC] Connection refused, retrying in 2s...")
                await asyncio.sleep(2)
            
            except Exception as e:
                print(f"[HyprIPC] Event loop error: {e}")
                await asyncio.sleep(1)
        
        print("[HyprIPC] Event listener stopped")
    
    def stop(self):
        """Stop event listener"""
        self._running = False


# ==========================================
# CONVENIENCE FUNCTIONS (sync wrappers)
# ==========================================

def hyprctl(command: str) -> str:
    """Synchronous hyprctl command (for simple use cases)"""
    import subprocess
    try:
        result = subprocess.run(
            ['hyprctl', command],
            capture_output=True,
            text=True,
            timeout=5
        )
        return result.stdout
    except Exception as e:
        print(f"[hyprctl] Error: {e}")
        return ""


def hyprctl_json(command: str) -> Any:
    """Synchronous hyprctl with JSON output"""
    import subprocess
    try:
        result = subprocess.run(
            ['hyprctl', '-j', command],
            capture_output=True,
            text=True,
            timeout=5
        )
        return json.loads(result.stdout) if result.stdout else None
    except Exception as e:
        print(f"[hyprctl_json] Error: {e}")
        return None


# ==========================================
# TEST / DEMO
# ==========================================

async def demo():
    """Demo the IPC module"""
    ipc = HyprlandIPC()
    
    print("\n=== Getting all windows ===")
    windows = await ipc.get_clients()
    for w in windows:
        print(f"  [{w.wm_class}] {w.title[:40]} @ workspace {w.workspace_id}")
    
    print("\n=== Active window ===")
    active = await ipc.get_active_window()
    if active:
        print(f"  [{active.wm_class}] {active.title}")
    
    print("\n=== Workspaces ===")
    workspaces = await ipc.get_workspaces()
    for ws in workspaces:
        print(f"  {ws.get('name', 'N/A')} - {ws.get('windows', 0)} windows")
    
    print("\n=== Listening for events (Ctrl+C to stop) ===")
    
    def on_window_open(event: HyprEvent):
        print(f"  [OPEN] {event.parsed.get('class')} - {event.parsed.get('title')}")
    
    def on_window_close(event: HyprEvent):
        print(f"  [CLOSE] {event.parsed.get('address')}")
    
    def on_focus(event: HyprEvent):
        print(f"  [FOCUS] {event.parsed.get('class')} - {event.parsed.get('title')}")
    
    ipc.subscribe(HyprEventType.WINDOW_OPEN, on_window_open)
    ipc.subscribe(HyprEventType.WINDOW_CLOSE, on_window_close)
    ipc.subscribe(HyprEventType.WINDOW_FOCUS, on_focus)
    
    try:
        await ipc.listen_events()
    except KeyboardInterrupt:
        print("\nStopping...")
        ipc.stop()


if __name__ == "__main__":
    asyncio.run(demo())