"""
Hyprland Panel Module
Python GTK4 panel components for Hyprland

Location: ~/.config/hypr-control-center/src/panel/
"""

from .hypr_ipc import (
    HyprlandIPC,
    HyprEvent,
    HyprEventType,
    HyprWindow,
    hyprctl,
    hyprctl_json
)

from .window_tracker import (
    WindowTracker,
    TrackedWindow,
    AppGroup,
    print_state
)

from .icon_resolver import (
    IconResolver,
    DesktopEntry,
    get_resolver,
    get_icon_for_class,
    get_icon_path,
    create_icon_image
)

from .taskbar_widget import (
    TaskbarWidget,
    TaskbarButton,
    TaskbarApp
)

from .pinned_manager import (
    PinnedManager,
    PinnedApp,
    get_pinned_manager
)

from .daemon import (
    HyprPanel,
    HyprPanelApp,
    TaskbarItem
)

__all__ = [
    # IPC
    'HyprlandIPC',
    'HyprEvent', 
    'HyprEventType',
    'HyprWindow',
    'hyprctl',
    'hyprctl_json',
    # Tracker
    'WindowTracker',
    'TrackedWindow',
    'AppGroup',
    'print_state',
    # Icons
    'IconResolver',
    'DesktopEntry',
    'get_resolver',
    'get_icon_for_class',
    'get_icon_path',
    'create_icon_image',
    # Taskbar
    'TaskbarWidget',
    'TaskbarButton',
    'TaskbarApp',
    # Pinned
    'PinnedManager',
    'PinnedApp',
    'get_pinned_manager',
    # Daemon
    'HyprPanel',
    'HyprPanelApp',
    'TaskbarItem'
]