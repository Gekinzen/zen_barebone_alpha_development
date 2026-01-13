"""
ZenPyBar Modules
================

Bar modules that render in the bar.
"""

from .base import BaseModule
from .workspaces import WorkspacesModule
from .window import WindowModule
from .clock import ClockModule
from .taskbar import TaskbarModule
from .custom import CustomModule
from .music import MusicModule

__all__ = [
    'BaseModule',
    'WorkspacesModule', 
    'WindowModule',
    'ClockModule',
    'TaskbarModule',
    'CustomModule',
    'MusicModule',
]

# Module registry
MODULE_REGISTRY = {
    'hyprland/workspaces': WorkspacesModule,
    'hyprland/window': WindowModule,
    'clock': ClockModule,
    'custom/taskbar': TaskbarModule,
    'custom/pinned': TaskbarModule,
    'custom/panel': TaskbarModule,  # Our panel = taskbar
    'custom/music': MusicModule,    # Our music module
}

def create_module(name: str, config: dict, bar):
    """Factory function to create modules"""
    if name in MODULE_REGISTRY:
        return MODULE_REGISTRY[name](name, config, bar)
    elif name.startswith('custom/'):
        return CustomModule(name, config, bar)
    elif name.startswith('group/'):
        # Groups handled separately
        return None
    else:
        # Try generic custom module
        return CustomModule(name, config, bar)
