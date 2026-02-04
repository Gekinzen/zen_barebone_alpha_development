"""
Plugins Page - Hyprland Plugin Management
FIXED: Case-sensitive plugin names for hyprpm commands
FIXED: Store original plugin name, not lowercased
FIXED: Better error handling and status display
"""

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
from gi.repository import Gtk, Adw, GLib, Gdk
import subprocess
import os
import json
import re
import threading

# ════════════════════════════════════════════════════════════════════════════
# NERD FONT ICONS
# ════════════════════════════════════════════════════════════════════════════
ICONS = {
    'plugin': '󰐱',
    'plugins': '󱁤',
    'enabled': '󰄬',
    'disabled': '󰅖',
    'install': '󰏔',
    'uninstall': '󰆴',
    'update': '󰚰',
    'refresh': '󰑐',
    'settings': '󰒓',
    'github': '󰊤',
    'warning': '󰀪',
    'info': '󰋽',
    'hyprland': '󰖯',
    'loading': '󰦖',
    'version': '󰓾',
    'error': '󰅚',
}

# ════════════════════════════════════════════════════════════════════════════
# KNOWN PLUGINS DATABASE
# ════════════════════════════════════════════════════════════════════════════
KNOWN_PLUGINS = {
    'hyprspace': {
        'name': 'Hyprspace',
        'description': 'Workspace overview plugin with gesture support',
        'repo': 'https://github.com/KZDKM/Hyprspace',
        'icon': '󰍺',
        'hyprpm_name': 'Hyprspace',  # EXACT name for hyprpm
    },
    'hyprbars': {
        'name': 'Hyprbars',
        'description': 'Window titlebars with buttons',
        'repo': 'https://github.com/hyprwm/hyprland-plugins',
        'icon': '󰖯',
        'hyprpm_name': 'hyprbars',
    },
    'hyprexpo': {
        'name': 'Hyprexpo',
        'description': 'Expo-style workspace overview',
        'repo': 'https://github.com/hyprwm/hyprland-plugins',
        'icon': '󱇙',
        'hyprpm_name': 'hyprexpo',
    },
    'hyprtrails': {
        'name': 'Hyprtrails',
        'description': 'Cursor trails effect',
        'repo': 'https://github.com/hyprwm/hyprland-plugins',
        'icon': '󰮏',
        'hyprpm_name': 'hyprtrails',
    },
    'hyprwinwrap': {
        'name': 'Hyprwinwrap',
        'description': 'Live wallpaper support',
        'repo': 'https://github.com/hyprwm/hyprland-plugins',
        'icon': '󰸉',
        'hyprpm_name': 'hyprwinwrap',
    },
    'borders-plus-plus': {
        'name': 'Borders++',
        'description': 'Additional border customization',
        'repo': 'https://github.com/hyprwm/hyprland-plugins',
        'icon': '󰃚',
        'hyprpm_name': 'borders-plus-plus',
    },
    'csgo-vulkan-fix': {
        'name': 'CS:GO Vulkan Fix',
        'description': 'Fix for CS:GO/CS2 on Vulkan',
        'repo': 'https://github.com/hyprwm/hyprland-plugins',
        'icon': '󰊖',
        'hyprpm_name': 'csgo-vulkan-fix',
    },
    'hy3': {
        'name': 'Hy3',
        'description': 'i3-like manual tiling layout',
        'repo': 'https://github.com/outfoxxed/hy3',
        'icon': '󰕰',
        'hyprpm_name': 'hy3',
    },
    'split-monitor-workspaces': {
        'name': 'Split Monitor Workspaces',
        'description': 'Independent workspaces per monitor',
        'repo': 'https://github.com/Duckonaut/split-monitor-workspaces',
        'icon': '󰍹',
        'hyprpm_name': 'split-monitor-workspaces',
    },
    'hyprfocus': {
        'name': 'Hyprfocus',
        'description': 'Focus animations and effects',
        'repo': 'https://github.com/pyt0xic/hyprfocus',
        'icon': '󰈈',
        'hyprpm_name': 'hyprfocus',
    },
    'hyprscroller': {
        'name': 'Hyprscroller',
        'description': 'Scrolling window layout',
        'repo': 'https://github.com/dawsers/hyprscroller',
        'icon': '󰜱',
        'hyprpm_name': 'hyprscroller',
    },
    'hyprscrolling': {
        'name': 'Hyprscrolling',
        'description': 'Scrolling window layout',
        'repo': 'https://github.com/dawsers/hyprscroller',
        'icon': '󰜱',
        'hyprpm_name': 'hyprscrolling',
    },
    'xtra-dispatchers': {
        'name': 'Xtra Dispatchers',
        'description': 'Additional Hyprland dispatchers',
        'repo': 'https://github.com/hyprwm/hyprland-plugins',
        'icon': '󰘳',
        'hyprpm_name': 'xtra-dispatchers',
    },
}

# ════════════════════════════════════════════════════════════════════════════
# CUSTOM CSS
# ════════════════════════════════════════════════════════════════════════════
PLUGINS_PAGE_CSS = """
/* Plugins Page Styles */
.plugins-section {
    background: alpha(@card_bg_color, 0.6);
    border-radius: 12px;
    border: 1px solid alpha(@borders, 0.3);
    margin-bottom: 12px;
    padding: 0;
}

.plugins-section-header {
    padding: 16px 20px;
    border-radius: 12px;
    transition: background 200ms ease;
}

.plugins-section-header:hover {
    background: alpha(@card_bg_color, 0.8);
}

.plugins-section-header.expanded {
    border-bottom: 1px solid alpha(@borders, 0.2);
    border-radius: 12px 12px 0 0;
}

.plugins-section-content {
    padding: 16px 20px;
    background: alpha(@card_bg_color, 0.3);
    border-radius: 0 0 12px 12px;
}

.plugin-card {
    padding: 16px;
    border-radius: 10px;
    margin-bottom: 8px;
    background: alpha(@card_bg_color, 0.5);
    border: 1px solid alpha(@borders, 0.15);
    transition: all 200ms ease;
}

.plugin-card:hover {
    background: alpha(@card_bg_color, 0.7);
    border-color: alpha(@accent_color, 0.3);
}

.plugin-card.enabled {
    border-left: 3px solid @success_color;
    background: alpha(@success_color, 0.05);
}

.plugin-card.disabled {
    opacity: 0.7;
}

.plugin-card.processing {
    opacity: 0.6;
    pointer-events: none;
}

.plugin-icon {
    font-size: 24px;
    min-width: 40px;
    color: @accent_color;
}

.plugin-name {
    font-size: 15px;
    font-weight: 600;
    color: @theme_fg_color;
}

.plugin-description {
    font-size: 12px;
    color: alpha(@theme_fg_color, 0.6);
    margin-top: 2px;
}

.plugin-version {
    font-size: 11px;
    color: alpha(@theme_fg_color, 0.5);
    font-family: monospace;
}

.plugin-status {
    font-size: 11px;
    padding: 4px 10px;
    border-radius: 4px;
    font-weight: 500;
}

.plugin-status.enabled {
    background: alpha(@success_color, 0.15);
    color: @success_color;
}

.plugin-status.disabled {
    background: alpha(@warning_color, 0.15);
    color: @warning_color;
}

.plugin-status.processing {
    background: alpha(@accent_color, 0.15);
    color: @accent_color;
}

.plugin-status.error {
    background: alpha(@error_color, 0.15);
    color: @error_color;
}

.plugin-repo {
    font-size: 11px;
    color: alpha(@theme_fg_color, 0.4);
}

.plugins-actions {
    padding: 12px 0 4px 0;
    border-top: 1px solid alpha(@borders, 0.15);
    margin-top: 12px;
}

.plugins-action-btn {
    padding: 8px 16px;
    border-radius: 8px;
    font-size: 13px;
}

.plugin-update-btn {
    padding: 6px 12px;
    border-radius: 6px;
    font-size: 12px;
    min-width: 80px;
}

.hyprpm-status {
    padding: 12px 16px;
    border-radius: 8px;
    background: alpha(@card_bg_color, 0.4);
    margin-bottom: 12px;
}

.hyprpm-status-label {
    font-size: 13px;
    color: alpha(@theme_fg_color, 0.7);
}

.hyprpm-version {
    font-size: 12px;
    color: @accent_color;
    font-weight: 500;
}

.version-box {
    padding: 8px 12px;
    border-radius: 6px;
    background: alpha(@accent_color, 0.1);
    border: 1px solid alpha(@accent_color, 0.2);
}

.version-label {
    font-size: 11px;
    color: alpha(@theme_fg_color, 0.6);
    margin-bottom: 2px;
}

.version-value {
    font-size: 13px;
    font-weight: 600;
    color: @accent_color;
    font-family: monospace;
}

.empty-plugins {
    padding: 32px;
    text-align: center;
    color: alpha(@theme_fg_color, 0.5);
}

.empty-plugins-icon {
    font-size: 48px;
    margin-bottom: 12px;
    opacity: 0.4;
}

.section-icon {
    font-size: 20px;
    min-width: 32px;
    color: @accent_color;
}

.section-title-text {
    font-size: 15px;
    font-weight: 600;
}

.section-subtitle {
    font-size: 12px;
    color: alpha(@theme_fg_color, 0.6);
}

.expand-arrow {
    font-size: 14px;
    color: alpha(@theme_fg_color, 0.5);
}

.expand-arrow.expanded {
    color: @accent_color;
}

.loaded-badge {
    font-size: 10px;
    padding: 2px 8px;
    border-radius: 4px;
    background: alpha(@accent_color, 0.15);
    color: @accent_color;
    margin-left: 8px;
}

@keyframes spin {
    from { transform: rotate(0deg); }
    to { transform: rotate(360deg); }
}

.spinner {
    animation: spin 1s linear infinite;
}
"""

# ════════════════════════════════════════════════════════════════════════════
# HYPRPM & HYPRCTL FUNCTIONS
# ════════════════════════════════════════════════════════════════════════════

def run_command(cmd, timeout=30):
    """Run a shell command and return output
    
    Default timeout increased to 30s for hyprpm operations
    """
    try:
        print(f"[Plugins] Running: {cmd}")
        result = subprocess.run(
            cmd, shell=True, capture_output=True, 
            text=True, timeout=timeout
        )
        print(f"[Plugins] Return code: {result.returncode}")
        if result.stdout:
            print(f"[Plugins] STDOUT: {result.stdout[:500]}")
        if result.stderr:
            print(f"[Plugins] STDERR: {result.stderr[:500]}")
        return result.stdout.strip(), result.returncode == 0
    except subprocess.TimeoutExpired:
        print(f"[Plugins] Command timed out after {timeout}s: {cmd}")
        return f"Command timed out after {timeout} seconds", False
    except Exception as e:
        print(f"[Plugins] Command error: {e}")
        return str(e), False


def check_hyprpm_installed():
    """Check if hyprpm is available"""
    output, success = run_command("which hyprpm")
    return success and output


def get_hyprpm_version():
    """Get hyprpm version"""
    output, success = run_command("hyprpm --version 2>/dev/null")
    if success and output:
        return output.split('\n')[0]
    return None


def get_hyprland_version():
    """Get Hyprland version from hyprctl"""
    output, success = run_command("hyprctl version -j 2>/dev/null")
    if not success:
        return "Unknown"
    
    try:
        data = json.loads(output)
        version = data.get('tag', data.get('commit', 'Unknown'))
        return version
    except:
        output_plain, success = run_command("hyprctl version 2>/dev/null")
        if success and output_plain:
            for line in output_plain.split('\n'):
                if 'Tag:' in line or 'Hyprland' in line:
                    parts = line.split()
                    if len(parts) >= 2:
                        return parts[-1]
        return "Unknown"


def get_loaded_plugins():
    """Get list of currently LOADED plugins using hyprctl plugin list
    
    Returns dict mapping lowercase name -> original name for case-sensitive operations
    """
    loaded = {}  # lowercase -> original name
    
    # Method 1: Try hyprctl plugin list (JSON)
    output, success = run_command("hyprctl plugin list -j 2>/dev/null")
    if success and output:
        try:
            plugins_data = json.loads(output)
            for plugin in plugins_data:
                name = plugin.get('name', '')
                if name:
                    loaded[name.lower()] = name  # Store original case
            print(f"[Plugins] Loaded plugins (JSON): {loaded}")
            return loaded
        except json.JSONDecodeError:
            pass
    
    # Method 2: Try hyprctl plugin list (plain text)
    output, success = run_command("hyprctl plugin list 2>/dev/null")
    if success and output:
        for line in output.split('\n'):
            line = line.strip()
            if line.startswith('Plugin '):
                parts = line.split()
                if len(parts) >= 2:
                    name = parts[1]
                    loaded[name.lower()] = name  # Store original case
            elif line and not line.startswith('(') and 'no plugins' not in line.lower():
                parts = line.split()
                if parts:
                    name = parts[0]
                    if name.lower() not in ['plugin', 'plugins', 'loaded']:
                        loaded[name.lower()] = name
    
    print(f"[Plugins] Loaded plugins: {loaded}")
    return loaded


def get_installed_plugins():
    """Parse hyprpm list output with Repository format
    
    FIXED: Store original plugin name (hyprpm_name) for case-sensitive commands
    """
    plugins = []
    
    loaded_plugins = get_loaded_plugins()  # dict: lowercase -> original
    print(f"[Plugins] Currently loaded: {loaded_plugins}")
    
    output, success = run_command("hyprpm list 2>/dev/null")
    if not success:
        # Fallback: use loaded plugins
        for name_lower, name_original in loaded_plugins.items():
            known_info = KNOWN_PLUGINS.get(name_lower, {})
            plugins.append({
                'name': name_lower,
                'hyprpm_name': name_original,  # ORIGINAL CASE for hyprpm
                'display_name': known_info.get('name', name_original.title()),
                'description': known_info.get('description', 'Hyprland plugin'),
                'icon': known_info.get('icon', ICONS['plugin']),
                'repo': known_info.get('repo', ''),
                'repo_name': '',
                'version': '',
                'enabled': True,
                'loaded': True,
            })
        return plugins
    
    current_repo = None
    current_repo_name = None
    current_plugin = None
    current_plugin_original = None  # Store original case
    found_plugins = set()
    
    lines = output.split('\n')
    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        
        # Repository header
        if '→ Repository' in line or line.strip().startswith('Repository'):
            repo_match = re.search(r'Repository\s+([^:]+)', line)
            if repo_match:
                current_repo_name = repo_match.group(1).strip()
                current_repo = KNOWN_PLUGINS.get(current_repo_name.lower(), {}).get('repo', '')
                print(f"[Plugins] Found repository: {current_repo_name}")
            i += 1
            continue
        
        # Plugin line - capture EXACT name
        if 'Plugin ' in line:
            plugin_match = re.search(r'Plugin\s+([^\s│└─]+)', line)
            if plugin_match:
                current_plugin_original = plugin_match.group(1).strip()  # ORIGINAL CASE
                current_plugin = current_plugin_original.lower()
                print(f"[Plugins] Found plugin: {current_plugin_original} (key: {current_plugin})")
            i += 1
            continue
        
        # Enabled status
        if '└─ enabled:' in line or 'enabled:' in line:
            if current_plugin:
                enabled_match = re.search(r'enabled:\s*(true|false)', line)
                hyprpm_enabled = enabled_match and enabled_match.group(1) == 'true'
                
                if current_plugin in found_plugins:
                    i += 1
                    continue
                found_plugins.add(current_plugin)
                
                # Check if actually loaded (from hyprctl)
                is_loaded = current_plugin in loaded_plugins
                
                # Get the hyprpm_name - prefer from loaded_plugins if available (actual runtime name)
                # Otherwise use what we parsed from hyprpm list
                if current_plugin in loaded_plugins:
                    hyprpm_name = loaded_plugins[current_plugin]
                else:
                    hyprpm_name = current_plugin_original
                
                # Also check known plugins for override
                known_info = KNOWN_PLUGINS.get(current_plugin, {})
                if 'hyprpm_name' in known_info:
                    hyprpm_name = known_info['hyprpm_name']
                
                version = ''
                if i + 1 < len(lines):
                    next_line = lines[i + 1].strip()
                    ver_match = re.search(r'version:\s*([^\s]+)', next_line)
                    if ver_match:
                        version = ver_match.group(1)
                
                plugins.append({
                    'name': current_plugin,  # lowercase for lookups
                    'hyprpm_name': hyprpm_name,  # EXACT CASE for hyprpm commands!
                    'display_name': known_info.get('name', current_plugin_original.replace('-', ' ').title()),
                    'description': known_info.get('description', 'Hyprland plugin'),
                    'icon': known_info.get('icon', ICONS['plugin']),
                    'repo': current_repo or known_info.get('repo', ''),
                    'repo_name': current_repo_name or '',
                    'version': version,
                    'enabled': is_loaded,
                    'loaded': is_loaded,
                    'hyprpm_enabled': hyprpm_enabled,
                })
                
                current_plugin = None
                current_plugin_original = None
            i += 1
            continue
        
        i += 1
    
    # Add any loaded plugins not in hyprpm list
    for name_lower, name_original in loaded_plugins.items():
        if name_lower not in found_plugins:
            known_info = KNOWN_PLUGINS.get(name_lower, {})
            plugins.append({
                'name': name_lower,
                'hyprpm_name': known_info.get('hyprpm_name', name_original),
                'display_name': known_info.get('name', name_original.title()),
                'description': known_info.get('description', 'Hyprland plugin (loaded)'),
                'icon': known_info.get('icon', ICONS['plugin']),
                'repo': known_info.get('repo', ''),
                'repo_name': '',
                'version': '',
                'enabled': True,
                'loaded': True,
            })
    
    print(f"[Plugins] Parsed {len(plugins)} plugins")
    for p in plugins:
        print(f"  - {p['name']} (hyprpm: {p['hyprpm_name']}): enabled={p['enabled']}, loaded={p.get('loaded', False)}")
    
    return plugins


def toggle_plugin(hyprpm_name, enable):
    """Enable or disable a plugin via hyprpm
    
    FIXED: Use hyprpm_name (exact case) instead of lowercase name
    FIXED: Increased timeout to 30s for slow operations
    """
    action = "enable" if enable else "disable"
    cmd = f"hyprpm {action} {hyprpm_name}"
    
    print(f"[Plugins] Toggle command: {cmd}")
    
    # hyprpm can be slow, especially disable - use 30s timeout
    output, success = run_command(cmd, timeout=30)
    
    # Check for common errors
    if not success:
        if "timed out" in output.lower():
            print(f"[Plugins] Command timed out - hyprpm may still be running")
            # Check if it actually worked despite timeout
            import time
            time.sleep(2)
            loaded = get_loaded_plugins()
            actually_worked = (hyprpm_name.lower() in loaded) == enable
            if actually_worked:
                print(f"[Plugins] Despite timeout, operation appears successful")
                return True, "Completed (after timeout)"
        elif "missing" in output.lower():
            print(f"[Plugins] Plugin not found - check case sensitivity. Name: {hyprpm_name}")
        elif "couldn't" in output.lower():
            print(f"[Plugins] Couldn't {action} plugin: {output}")
    
    return success, output


def reload_plugins():
    """Reload hyprpm plugins"""
    print(f"[Plugins] Reloading plugins...")
    output, success = run_command("hyprpm reload 2>&1", timeout=30)
    
    if success:
        print(f"[Plugins] Reload SUCCESS")
    else:
        print(f"[Plugins] Reload FAILED: {output}")
    
    return success, output


def update_plugins():
    """Update all plugins"""
    output, success = run_command("hyprpm update 2>&1", timeout=60)
    return success, output


def update_plugin(hyprpm_name):
    """Update a specific plugin"""
    output, success = run_command(f"hyprpm update {hyprpm_name} 2>&1", timeout=60)
    if not success:
        output, success = update_plugins()
    return success, output


# ════════════════════════════════════════════════════════════════════════════
# EXPANDABLE SECTION COMPONENT
# ════════════════════════════════════════════════════════════════════════════

class PluginsExpandableSection(Gtk.Box):
    """Expandable section for plugins page"""
    
    def __init__(self, icon, title, subtitle="", expanded=False):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.add_css_class('plugins-section')
        
        self._expanded = expanded
        self._subtitle_label = None
        
        # Header
        self.header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        self.header.add_css_class('plugins-section-header')
        if expanded:
            self.header.add_css_class('expanded')
        
        click_gesture = Gtk.GestureClick.new()
        click_gesture.connect('pressed', self._on_header_clicked)
        self.header.add_controller(click_gesture)
        
        # Icon
        icon_label = Gtk.Label(label=icon)
        icon_label.add_css_class('section-icon')
        self.header.append(icon_label)
        
        # Title box
        title_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        title_box.set_hexpand(True)
        
        title_label = Gtk.Label(label=title)
        title_label.add_css_class('section-title-text')
        title_label.set_halign(Gtk.Align.START)
        title_box.append(title_label)
        
        self._subtitle_label = Gtk.Label(label=subtitle if subtitle else " ")
        self._subtitle_label.add_css_class('section-subtitle')
        self._subtitle_label.set_halign(Gtk.Align.START)
        title_box.append(self._subtitle_label)
        
        self.header.append(title_box)
        
        # Arrow
        self.arrow = Gtk.Label(label="󰅀" if expanded else "󰅂")
        self.arrow.add_css_class('expand-arrow')
        if expanded:
            self.arrow.add_css_class('expanded')
        self.header.append(self.arrow)
        
        self.append(self.header)
        
        # Content
        self.content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        self.content.add_css_class('plugins-section-content')
        
        self.revealer = Gtk.Revealer()
        self.revealer.set_transition_type(Gtk.RevealerTransitionType.SLIDE_DOWN)
        self.revealer.set_transition_duration(200)
        self.revealer.set_reveal_child(expanded)
        self.revealer.set_child(self.content)
        
        self.append(self.revealer)
    
    def _on_header_clicked(self, gesture, n_press, x, y):
        self._expanded = not self._expanded
        self.revealer.set_reveal_child(self._expanded)
        
        if self._expanded:
            self.header.add_css_class('expanded')
            self.arrow.add_css_class('expanded')
            self.arrow.set_text("󰅀")
        else:
            self.header.remove_css_class('expanded')
            self.arrow.remove_css_class('expanded')
            self.arrow.set_text("󰅂")
    
    def set_subtitle(self, text):
        if self._subtitle_label:
            self._subtitle_label.set_text(text)
    
    def add_content(self, widget):
        self.content.append(widget)
    
    def clear_content(self):
        while self.content.get_first_child():
            self.content.remove(self.content.get_first_child())


# ════════════════════════════════════════════════════════════════════════════
# MAIN PAGE BUILDER
# ════════════════════════════════════════════════════════════════════════════

def build_plugins_page(window):
    """Build the Plugins management page"""
    
    _apply_plugins_css()
    
    page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
    page.set_margin_start(32)
    page.set_margin_end(32)
    page.set_margin_top(24)
    page.set_margin_bottom(24)
    
    header = _create_page_header(
        f"{ICONS['plugins']} Plugins",
        "Manage Hyprland plugins with hyprpm"
    )
    page.append(header)
    
    window.plugins_widgets = {}
    
    if not check_hyprpm_installed():
        _build_no_hyprpm_view(page)
        return page
    
    status_section = PluginsExpandableSection(
        ICONS['info'],
        "System Status",
        "Hyprland and hyprpm versions",
        expanded=True
    )
    _build_status_content(window, status_section)
    page.append(status_section)
    
    plugins = get_installed_plugins()
    enabled_count = sum(1 for p in plugins if p['enabled'])
    loaded_count = sum(1 for p in plugins if p.get('loaded', False))
    
    plugins_section = PluginsExpandableSection(
        ICONS['plugin'],
        "Installed Plugins",
        f"{loaded_count} loaded, {len(plugins)} total" if plugins else "No plugins installed",
        expanded=True
    )
    window.plugins_widgets['plugins_section'] = plugins_section
    _build_plugins_content(window, plugins_section)
    page.append(plugins_section)
    
    actions_section = PluginsExpandableSection(
        ICONS['settings'],
        "Plugin Actions",
        "Update and reload all plugins",
        expanded=False
    )
    _build_actions_content(window, actions_section)
    page.append(actions_section)
    
    return page


def _apply_plugins_css():
    """Apply custom CSS"""
    provider = Gtk.CssProvider()
    provider.load_from_data(PLUGINS_PAGE_CSS.encode())
    Gtk.StyleContext.add_provider_for_display(
        Gdk.Display.get_default(),
        provider,
        Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
    )


def _create_page_header(title, subtitle):
    """Create page header"""
    header = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
    header.set_margin_bottom(24)
    
    title_label = Gtk.Label(label=title)
    title_label.add_css_class('page-title')
    title_label.set_halign(Gtk.Align.START)
    header.append(title_label)
    
    subtitle_label = Gtk.Label(label=subtitle)
    subtitle_label.add_css_class('page-subtitle')
    subtitle_label.set_halign(Gtk.Align.START)
    header.append(subtitle_label)
    
    return header


def _build_no_hyprpm_view(page):
    """Build view when hyprpm is not installed"""
    empty_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16)
    empty_box.add_css_class('empty-plugins')
    empty_box.set_valign(Gtk.Align.CENTER)
    empty_box.set_vexpand(True)
    
    icon = Gtk.Label(label=ICONS['warning'])
    icon.add_css_class('empty-plugins-icon')
    empty_box.append(icon)
    
    title = Gtk.Label(label="Hyprpm Not Found")
    title.add_css_class('page-title')
    empty_box.append(title)
    
    desc = Gtk.Label(label="hyprpm is required to manage Hyprland plugins.\nIt should be included with your Hyprland installation.")
    desc.set_justify(Gtk.Justification.CENTER)
    empty_box.append(desc)
    
    page.append(empty_box)


def _build_status_content(window, section):
    """Build hyprpm status content with versions"""
    
    status_container = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
    
    versions_grid = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
    versions_grid.set_homogeneous(True)
    
    hypr_version = get_hyprland_version()
    hypr_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
    hypr_box.add_css_class('version-box')
    
    hypr_label = Gtk.Label(label="Hyprland")
    hypr_label.add_css_class('version-label')
    hypr_label.set_halign(Gtk.Align.START)
    hypr_box.append(hypr_label)
    
    hypr_value = Gtk.Label(label=hypr_version)
    hypr_value.add_css_class('version-value')
    hypr_value.set_halign(Gtk.Align.START)
    hypr_value.set_ellipsize(3)
    hypr_box.append(hypr_value)
    
    versions_grid.append(hypr_box)
    
    hyprpm_version = get_hyprpm_version()
    hyprpm_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
    hyprpm_box.add_css_class('version-box')
    
    hyprpm_label = Gtk.Label(label="Hyprpm")
    hyprpm_label.add_css_class('version-label')
    hyprpm_label.set_halign(Gtk.Align.START)
    hyprpm_box.append(hyprpm_label)
    
    hyprpm_value = Gtk.Label(label=hyprpm_version or "Unknown")
    hyprpm_value.add_css_class('version-value')
    hyprpm_value.set_halign(Gtk.Align.START)
    hyprpm_value.set_ellipsize(3)
    hyprpm_box.append(hyprpm_value)
    
    versions_grid.append(hyprpm_box)
    
    status_container.append(versions_grid)
    
    loaded = get_loaded_plugins()
    
    loaded_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
    loaded_box.add_css_class('hyprpm-status')
    
    loaded_label = Gtk.Label(label="Currently Loaded:")
    loaded_label.add_css_class('hyprpm-status-label')
    loaded_box.append(loaded_label)
    
    loaded_value = Gtk.Label(label=f"{len(loaded)} plugin{'s' if len(loaded) != 1 else ''}")
    loaded_value.add_css_class('hyprpm-version')
    loaded_box.append(loaded_value)
    
    if loaded:
        # Show original case names
        loaded_names = Gtk.Label(label=f"({', '.join(sorted(loaded.values()))})")
        loaded_names.add_css_class('plugin-version')
        loaded_names.set_ellipsize(3)
        loaded_box.append(loaded_names)
    
    status_container.append(loaded_box)
    
    section.add_content(status_container)


def _build_plugins_content(window, section):
    """Build installed plugins list"""
    
    plugins_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
    window.plugins_widgets['plugins_list'] = plugins_box
    section.add_content(plugins_box)
    
    refresh_btn = Gtk.Button(label=f"{ICONS['refresh']} Refresh Plugins")
    refresh_btn.add_css_class('plugins-action-btn')
    refresh_btn.add_css_class('flat')
    refresh_btn.connect('clicked', lambda b: _refresh_plugins(window))
    
    btn_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
    btn_box.add_css_class('plugins-actions')
    btn_box.append(refresh_btn)
    section.add_content(btn_box)
    
    _refresh_plugins(window)


def _refresh_plugins(window):
    """Refresh plugins list"""
    plugins_box = window.plugins_widgets.get('plugins_list')
    section = window.plugins_widgets.get('plugins_section')
    
    if not plugins_box:
        return
    
    while plugins_box.get_first_child():
        plugins_box.remove(plugins_box.get_first_child())
    
    plugins = get_installed_plugins()
    
    if not plugins:
        empty = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        empty.add_css_class('empty-plugins')
        
        icon = Gtk.Label(label=ICONS['plugin'])
        icon.add_css_class('empty-plugins-icon')
        empty.append(icon)
        
        label = Gtk.Label(label="No plugins installed")
        empty.append(label)
        
        hint = Gtk.Label(label="Use 'hyprpm add <repo>' to install plugins")
        hint.add_css_class('plugin-description')
        empty.append(hint)
        
        plugins_box.append(empty)
        
        if section:
            section.set_subtitle("No plugins installed")
        return
    
    for plugin in plugins:
        card = _create_plugin_card(window, plugin)
        plugins_box.append(card)
    
    if section:
        loaded_count = sum(1 for p in plugins if p.get('loaded', False))
        section.set_subtitle(f"{loaded_count} loaded, {len(plugins)} total")


def _create_plugin_card(window, plugin):
    """Create a plugin card widget with update button
    
    FIXED: Use plugin['hyprpm_name'] for all hyprpm commands
    """
    card = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=16)
    card.add_css_class('plugin-card')
    
    is_loaded = plugin.get('loaded', False)
    
    if is_loaded:
        card.add_css_class('enabled')
    else:
        card.add_css_class('disabled')
    
    icon = Gtk.Label(label=plugin['icon'])
    icon.add_css_class('plugin-icon')
    card.append(icon)
    
    info_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
    info_box.set_hexpand(True)
    
    name_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
    
    name_label = Gtk.Label(label=plugin['display_name'])
    name_label.add_css_class('plugin-name')
    name_label.set_halign(Gtk.Align.START)
    name_row.append(name_label)
    
    status_label = Gtk.Label()
    status_label.add_css_class('plugin-status')
    
    if is_loaded:
        status_label.set_text("Loaded")
        status_label.add_css_class('enabled')
    else:
        status_label.set_text("Not Loaded")
        status_label.add_css_class('disabled')
    
    name_row.append(status_label)
    
    card.status_label = status_label
    
    info_box.append(name_row)
    
    desc_label = Gtk.Label(label=plugin['description'])
    desc_label.add_css_class('plugin-description')
    desc_label.set_halign(Gtk.Align.START)
    desc_label.set_wrap(True)
    desc_label.set_max_width_chars(50)
    info_box.append(desc_label)
    
    meta_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
    
    # Show hyprpm_name for debugging/clarity
    hyprpm_label = Gtk.Label(label=f"hyprpm: {plugin['hyprpm_name']}")
    hyprpm_label.add_css_class('plugin-version')
    meta_row.append(hyprpm_label)
    
    if plugin.get('version'):
        version_label = Gtk.Label(label=f"{ICONS['version']} {plugin['version']}")
        version_label.add_css_class('plugin-version')
        meta_row.append(version_label)
    
    if plugin.get('repo_name'):
        repo_label = Gtk.Label(label=f"{ICONS['github']} {plugin['repo_name']}")
        repo_label.add_css_class('plugin-repo')
        repo_label.set_ellipsize(3)
        meta_row.append(repo_label)
    elif plugin['repo']:
        repo_text = plugin['repo']
        if repo_text.startswith('https://'):
            repo_text = repo_text.replace('https://', '')
        repo_label = Gtk.Label(label=f"{ICONS['github']} {repo_text}")
        repo_label.add_css_class('plugin-repo')
        repo_label.set_ellipsize(3)
        meta_row.append(repo_label)
    
    info_box.append(meta_row)
    
    card.append(info_box)
    
    actions_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
    actions_box.set_valign(Gtk.Align.CENTER)
    
    update_btn = Gtk.Button(label=f"{ICONS['update']} Update")
    update_btn.add_css_class('plugin-update-btn')
    update_btn.set_tooltip_text(f"Update {plugin['display_name']}")
    
    # Store hyprpm_name for update
    hyprpm_name = plugin['hyprpm_name']
    
    def on_update_clicked(btn):
        btn.set_sensitive(False)
        btn.set_label(f"{ICONS['loading']} Updating...")
        
        def do_update():
            success, output = update_plugin(hyprpm_name)
            if success:
                reload_plugins()
            GLib.idle_add(lambda: _on_plugin_update_complete(window, btn, plugin, success, output))
        
        thread = threading.Thread(target=do_update, daemon=True)
        thread.start()
    
    update_btn.connect('clicked', on_update_clicked)
    actions_box.append(update_btn)
    
    toggle = Gtk.Switch()
    toggle.set_valign(Gtk.Align.CENTER)
    toggle.set_active(is_loaded)
    
    handler_id = None
    
    def on_toggle(switch, gparam):
        enable = switch.get_active()
        
        # USE hyprpm_name (exact case) for the command!
        print(f"[Plugins] Toggle triggered: {hyprpm_name} -> {'enable' if enable else 'disable'}")
        
        switch.set_sensitive(False)
        card.add_css_class('processing')
        
        # Show detailed status
        action_text = "Enabling" if enable else "Disabling"
        status_label.set_text(f"{action_text}...")
        status_label.remove_css_class('enabled')
        status_label.remove_css_class('disabled')
        status_label.remove_css_class('error')
        status_label.add_css_class('processing')
        
        def do_toggle_async():
            # FIXED: Use hyprpm_name instead of plugin['name']
            success, output = toggle_plugin(hyprpm_name, enable)
            reload_success = False
            
            if success:
                # Update status before reload
                GLib.idle_add(lambda: status_label.set_text("Reloading...") or False)
                reload_success, reload_output = reload_plugins()
                if not reload_success:
                    print(f"[Plugins] Reload failed after toggle: {reload_output}")
            
            GLib.idle_add(
                _on_toggle_complete,
                window, card, switch, status_label, plugin, 
                enable, success, output, reload_success, handler_id
            )
        
        thread = threading.Thread(target=do_toggle_async, daemon=True)
        thread.start()
    
    handler_id = toggle.connect('notify::active', on_toggle)
    card.toggle_handler_id = handler_id
    card.toggle_switch = toggle
    
    actions_box.append(toggle)
    
    card.append(actions_box)
    
    return card


def _on_plugin_update_complete(window, btn, plugin, success, output):
    """Handle plugin update completion"""
    btn.set_sensitive(True)
    btn.set_label(f"{ICONS['update']} Update")
    
    if success:
        _show_toast(window, f"{plugin['display_name']} updated successfully")
        GLib.timeout_add(500, lambda: _refresh_plugins(window) or False)
    else:
        error_msg = output[:50] if output else "Unknown error"
        _show_toast(window, f"Failed to update {plugin['display_name']}: {error_msg}")
    
    return False


def _on_toggle_complete(window, card, switch, status_label, plugin, enable, success, output, reload_success, handler_id):
    """Handle toggle completion with detailed error reporting"""
    
    card.remove_css_class('processing')
    status_label.remove_css_class('processing')
    
    switch.set_sensitive(True)
    
    if success and reload_success:
        action = 'enabled' if enable else 'disabled'
        _show_toast(window, f"{plugin['display_name']} {action} successfully")
        
        # AUTO REFRESH
        print(f"[Plugins] Toggle successful, refreshing in 500ms...")
        GLib.timeout_add(500, lambda: _refresh_plugins(window) or False)
        
    elif success and not reload_success:
        # Toggle succeeded but reload failed
        _show_toast(window, f"{plugin['display_name']} toggled but reload failed")
        
        # Still refresh to show state
        GLib.timeout_add(500, lambda: _refresh_plugins(window) or False)
        
    else:
        # Toggle failed
        error_msg = output[:100] if output else "Unknown error"
        
        # Check for case sensitivity hint
        if "missing" in output.lower() or "couldn't" in output.lower():
            error_msg = f"Plugin not found - try exact name: {plugin.get('hyprpm_name', plugin['name'])}"
        
        _show_toast(window, f"{ICONS['error']} Toggle failed: {error_msg}")
        
        print(f"[Plugins] Toggle FAILED for {plugin.get('hyprpm_name', plugin['name'])}")
        print(f"[Plugins] Full error: {output}")
        
        # Revert switch state
        if handler_id:
            switch.handler_block(handler_id)
        switch.set_active(not enable)
        if handler_id:
            switch.handler_unblock(handler_id)
        
        # Show error status
        status_label.set_text("Error")
        status_label.add_css_class('error')
        
        # Restore original status after 2 seconds
        def restore_status():
            if not enable:
                status_label.set_text("Loaded")
                status_label.remove_css_class('error')
                status_label.add_css_class('enabled')
            else:
                status_label.set_text("Not Loaded")
                status_label.remove_css_class('error')
                status_label.add_css_class('disabled')
            return False
        
        GLib.timeout_add(2000, restore_status)
    
    return False


def _build_actions_content(window, section):
    """Build plugin actions content"""
    
    actions_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
    
    update_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
    update_row.add_css_class('plugin-card')
    
    update_icon = Gtk.Label(label=ICONS['update'])
    update_icon.add_css_class('plugin-icon')
    update_row.append(update_icon)
    
    update_info = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
    update_info.set_hexpand(True)
    
    update_title = Gtk.Label(label="Update All Plugins")
    update_title.add_css_class('plugin-name')
    update_title.set_halign(Gtk.Align.START)
    update_info.append(update_title)
    
    update_desc = Gtk.Label(label="Fetch and build latest versions from all repositories")
    update_desc.add_css_class('plugin-description')
    update_desc.set_halign(Gtk.Align.START)
    update_info.append(update_desc)
    
    update_row.append(update_info)
    
    update_btn = Gtk.Button(label="Update All")
    update_btn.add_css_class('suggested-action')
    update_btn.set_valign(Gtk.Align.CENTER)
    
    def on_update_clicked(btn):
        btn.set_sensitive(False)
        btn.set_label(f"{ICONS['loading']} Updating...")
        
        def do_update():
            success, output = update_plugins()
            GLib.idle_add(lambda: _on_update_complete(window, btn, success, output))
        
        thread = threading.Thread(target=do_update, daemon=True)
        thread.start()
    
    update_btn.connect('clicked', on_update_clicked)
    update_row.append(update_btn)
    
    actions_box.append(update_row)
    
    reload_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
    reload_row.add_css_class('plugin-card')
    
    reload_icon = Gtk.Label(label=ICONS['refresh'])
    reload_icon.add_css_class('plugin-icon')
    reload_row.append(reload_icon)
    
    reload_info = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
    reload_info.set_hexpand(True)
    
    reload_title = Gtk.Label(label="Reload Plugins")
    reload_title.add_css_class('plugin-name')
    reload_title.set_halign(Gtk.Align.START)
    reload_info.append(reload_title)
    
    reload_desc = Gtk.Label(label="Reload all enabled plugins without restarting Hyprland")
    reload_desc.add_css_class('plugin-description')
    reload_desc.set_halign(Gtk.Align.START)
    reload_info.append(reload_desc)
    
    reload_row.append(reload_info)
    
    reload_btn = Gtk.Button(label="Reload")
    reload_btn.set_valign(Gtk.Align.CENTER)
    
    def on_reload_clicked(btn):
        btn.set_sensitive(False)
        btn.set_label(f"{ICONS['loading']} Reloading...")
        
        def do_reload():
            success, output = reload_plugins()
            GLib.idle_add(lambda: _on_reload_complete(window, btn, success, output))
        
        thread = threading.Thread(target=do_reload, daemon=True)
        thread.start()
    
    reload_btn.connect('clicked', on_reload_clicked)
    reload_row.append(reload_btn)
    
    actions_box.append(reload_row)
    
    section.add_content(actions_box)


def _on_update_complete(window, btn, success, output):
    """Handle update completion"""
    btn.set_sensitive(True)
    btn.set_label("Update All")
    
    if success:
        _show_toast(window, "All plugins updated successfully")
        _refresh_plugins(window)
    else:
        _show_toast(window, f"Plugin update failed: {output[:50] if output else 'Unknown error'}")
    
    return False


def _on_reload_complete(window, btn, success, output):
    """Handle reload completion"""
    btn.set_sensitive(True)
    btn.set_label("Reload")
    
    if success:
        _show_toast(window, "Plugins reloaded successfully")
        GLib.timeout_add(500, lambda: _refresh_plugins(window) or False)
    else:
        _show_toast(window, f"Failed to reload plugins: {output[:50] if output else 'Unknown error'}")
    
    return False


def _show_toast(window, message):
    """Show toast notification"""
    if hasattr(window, 'toast_overlay'):
        toast = Adw.Toast(title=message)
        toast.set_timeout(3)
        window.toast_overlay.add_toast(toast)
    else:
        print(f"[Plugins] {message}")