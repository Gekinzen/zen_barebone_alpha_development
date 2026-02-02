"""
Plugins Page - Hyprland Plugin Management
Manage hyprpm plugins with toggle on/off functionality
FIXED: Now uses hyprctl plugin list to detect actually loaded plugins
"""

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
from gi.repository import Gtk, Adw, GLib, Gdk
import subprocess
import os
import json
import re

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
    },
    'hyprbars': {
        'name': 'Hyprbars',
        'description': 'Window titlebars with buttons',
        'repo': 'https://github.com/hyprwm/hyprland-plugins',
        'icon': '󰖯',
    },
    'hyprexpo': {
        'name': 'Hyprexpo',
        'description': 'Expo-style workspace overview',
        'repo': 'https://github.com/hyprwm/hyprland-plugins',
        'icon': '󱇙',
    },
    'hyprtrails': {
        'name': 'Hyprtrails',
        'description': 'Cursor trails effect',
        'repo': 'https://github.com/hyprwm/hyprland-plugins',
        'icon': '󰮏',
    },
    'hyprwinwrap': {
        'name': 'Hyprwinwrap',
        'description': 'Live wallpaper support',
        'repo': 'https://github.com/hyprwm/hyprland-plugins',
        'icon': '󰸉',
    },
    'borders-plus-plus': {
        'name': 'Borders++',
        'description': 'Additional border customization',
        'repo': 'https://github.com/hyprwm/hyprland-plugins',
        'icon': '󰃚',
    },
    'csgo-vulkan-fix': {
        'name': 'CS:GO Vulkan Fix',
        'description': 'Fix for CS:GO/CS2 on Vulkan',
        'repo': 'https://github.com/hyprwm/hyprland-plugins',
        'icon': '󰊖',
    },
    'hy3': {
        'name': 'Hy3',
        'description': 'i3-like manual tiling layout',
        'repo': 'https://github.com/outfoxxed/hy3',
        'icon': '󰕰',
    },
    'split-monitor-workspaces': {
        'name': 'Split Monitor Workspaces',
        'description': 'Independent workspaces per monitor',
        'repo': 'https://github.com/Duckonaut/split-monitor-workspaces',
        'icon': '󰍹',
    },
    'hyprfocus': {
        'name': 'Hyprfocus',
        'description': 'Focus animations and effects',
        'repo': 'https://github.com/pyt0xic/hyprfocus',
        'icon': '󰈈',
    },
    'hyprscroller': {
        'name': 'Hyprscroller',
        'description': 'Scrolling window layout',
        'repo': 'https://github.com/dawsers/hyprscroller',
        'icon': '󰜱',
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
"""

# ════════════════════════════════════════════════════════════════════════════
# HYPRPM & HYPRCTL FUNCTIONS
# ════════════════════════════════════════════════════════════════════════════

def run_command(cmd, timeout=10):
    """Run a shell command and return output"""
    try:
        result = subprocess.run(
            cmd, shell=True, capture_output=True, 
            text=True, timeout=timeout
        )
        return result.stdout.strip(), result.returncode == 0
    except (subprocess.TimeoutExpired, Exception) as e:
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


def get_loaded_plugins():
    """
    Get list of currently LOADED plugins using hyprctl plugin list
    This is the source of truth for what's actually running!
    """
    loaded = set()
    
    # Method 1: Try hyprctl plugin list (JSON)
    output, success = run_command("hyprctl plugin list -j 2>/dev/null")
    if success and output:
        try:
            plugins_data = json.loads(output)
            for plugin in plugins_data:
                name = plugin.get('name', '').lower()
                if name:
                    loaded.add(name)
            print(f"[Plugins] Loaded plugins (JSON): {loaded}")
            return loaded
        except json.JSONDecodeError:
            pass
    
    # Method 2: Try hyprctl plugin list (plain text)
    output, success = run_command("hyprctl plugin list 2>/dev/null")
    if success and output:
        for line in output.split('\n'):
            line = line.strip()
            # Format: "Plugin hyprbars v0.1 by vaxry"
            if line.startswith('Plugin '):
                parts = line.split()
                if len(parts) >= 2:
                    name = parts[1].lower()
                    loaded.add(name)
            # Or just the plugin name
            elif line and not line.startswith('(') and 'no plugins' not in line.lower():
                # Could be just plugin name
                name = line.split()[0].lower() if line.split() else ''
                if name and name not in ['plugin', 'plugins', 'loaded']:
                    loaded.add(name)
    
    print(f"[Plugins] Loaded plugins (text): {loaded}")
    return loaded


def get_installed_plugins():
    """
    Get list of installed plugins with their actual status.
    Cross-references hyprpm list with hyprctl plugin list.
    """
    plugins = []
    
    # First, get actually LOADED plugins from Hyprland
    loaded_plugins = get_loaded_plugins()
    print(f"[Plugins] Currently loaded: {loaded_plugins}")
    
    # Then, get installed plugins from hyprpm
    output, success = run_command("hyprpm list 2>/dev/null")
    if not success:
        # If hyprpm list fails, still show loaded plugins
        for name in loaded_plugins:
            known_info = KNOWN_PLUGINS.get(name, {})
            plugins.append({
                'name': name,
                'display_name': known_info.get('name', name.title()),
                'description': known_info.get('description', 'Hyprland plugin'),
                'icon': known_info.get('icon', ICONS['plugin']),
                'repo': known_info.get('repo', ''),
                'enabled': True,  # It's loaded, so it's enabled
                'loaded': True,
            })
        return plugins
    
    # Parse hyprpm list output
    current_repo = None
    found_plugins = set()
    
    for line in output.split('\n'):
        line_stripped = line.strip()
        original_line = line
        
        # Check for repository header
        # Format: "Repository <name>:" or "repo <name>"
        if 'Repository' in line_stripped or line_stripped.startswith('repo '):
            repo_match = re.search(r'(?:Repository|repo)\s+(.+?)(?::|$)', line_stripped, re.IGNORECASE)
            if repo_match:
                current_repo = repo_match.group(1).strip()
            continue
        
        # Skip header lines and separators
        if not line_stripped or line_stripped.startswith('─') or line_stripped.startswith('='):
            continue
        if line_stripped.lower().startswith('plugin') and ':' in line_stripped:
            continue
        
        # Check for plugin line
        # Various formats:
        # "  hyprbars [enabled]"
        # "  hyprbars"
        # "hyprbars v0.1"
        # "* hyprbars"
        
        # Remove leading markers
        plugin_line = line_stripped.lstrip('*').lstrip('-').lstrip('•').strip()
        
        if not plugin_line:
            continue
        
        # Extract plugin name (first word usually)
        parts = plugin_line.split()
        if not parts:
            continue
        
        name = parts[0].lower()
        
        # Skip if it's a keyword
        skip_words = ['plugin', 'plugins', 'repository', 'repo', 'version', 'enabled', 'disabled', 'loaded']
        if name in skip_words:
            continue
        
        # Remove version suffix if present (e.g., "hyprbars-v0.1" -> "hyprbars")
        if '-v' in name:
            name = name.split('-v')[0]
        
        # Already processed this plugin?
        if name in found_plugins:
            continue
        found_plugins.add(name)
        
        # Check if this plugin is actually LOADED (this is the real enabled check!)
        is_loaded = name in loaded_plugins
        
        # Also check for [enabled] tag in hyprpm output
        hyprpm_enabled = '[enabled]' in line_stripped.lower()
        
        # Plugin is considered enabled if it's actually LOADED
        # (hyprpm might say [enabled] but if it's not loaded, it's not really running)
        enabled = is_loaded
        
        # Get plugin info from known plugins
        known_info = KNOWN_PLUGINS.get(name, {})
        
        plugins.append({
            'name': name,
            'display_name': known_info.get('name', name.title().replace('-', ' ')),
            'description': known_info.get('description', 'Hyprland plugin'),
            'icon': known_info.get('icon', ICONS['plugin']),
            'repo': current_repo or known_info.get('repo', ''),
            'enabled': enabled,
            'loaded': is_loaded,
            'hyprpm_enabled': hyprpm_enabled,
        })
    
    # Add any loaded plugins that weren't in hyprpm list
    for name in loaded_plugins:
        if name not in found_plugins:
            known_info = KNOWN_PLUGINS.get(name, {})
            plugins.append({
                'name': name,
                'display_name': known_info.get('name', name.title()),
                'description': known_info.get('description', 'Hyprland plugin (loaded)'),
                'icon': known_info.get('icon', ICONS['plugin']),
                'repo': known_info.get('repo', ''),
                'enabled': True,
                'loaded': True,
            })
    
    print(f"[Plugins] Found {len(plugins)} plugins")
    for p in plugins:
        print(f"  - {p['name']}: enabled={p['enabled']}, loaded={p.get('loaded', False)}")
    
    return plugins


def toggle_plugin(plugin_name, enable):
    """Enable or disable a plugin via hyprpm"""
    action = "enable" if enable else "disable"
    output, success = run_command(f"hyprpm {action} {plugin_name} 2>&1")
    return success, output


def reload_plugins():
    """Reload hyprpm plugins"""
    output, success = run_command("hyprpm reload 2>&1")
    return success, output


def update_plugins():
    """Update all plugins"""
    output, success = run_command("hyprpm update 2>&1", timeout=60)
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
    
    # Apply CSS
    _apply_plugins_css()
    
    # Main container
    page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
    page.set_margin_start(32)
    page.set_margin_end(32)
    page.set_margin_top(24)
    page.set_margin_bottom(24)
    
    # Header
    header = _create_page_header(
        f"{ICONS['plugins']} Plugins",
        "Manage Hyprland plugins with hyprpm"
    )
    page.append(header)
    
    # Store widgets
    window.plugins_widgets = {}
    
    # Check if hyprpm is installed
    if not check_hyprpm_installed():
        _build_no_hyprpm_view(page)
        return page
    
    # Hyprpm Status Section
    status_section = PluginsExpandableSection(
        ICONS['info'],
        "Hyprpm Status",
        "Plugin manager information",
        expanded=False
    )
    _build_status_content(window, status_section)
    page.append(status_section)
    
    # Installed Plugins Section
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
    
    # Actions Section
    actions_section = PluginsExpandableSection(
        ICONS['settings'],
        "Plugin Actions",
        "Update, reload, and manage plugins",
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
    """Build hyprpm status content"""
    
    # Version info
    version = get_hyprpm_version()
    
    status_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
    status_box.add_css_class('hyprpm-status')
    
    version_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
    
    version_label = Gtk.Label(label="Hyprpm Version:")
    version_label.add_css_class('hyprpm-status-label')
    version_row.append(version_label)
    
    version_value = Gtk.Label(label=version or "Unknown")
    version_value.add_css_class('hyprpm-version')
    version_row.append(version_value)
    
    status_box.append(version_row)
    
    # Hyprland version
    hypr_output, _ = run_command("hyprctl version -j 2>/dev/null")
    hypr_version = "Unknown"
    try:
        hypr_data = json.loads(hypr_output)
        hypr_version = hypr_data.get('version', 'Unknown')
    except:
        pass
    
    hypr_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
    
    hypr_label = Gtk.Label(label="Hyprland Version:")
    hypr_label.add_css_class('hyprpm-status-label')
    hypr_row.append(hypr_label)
    
    hypr_value = Gtk.Label(label=hypr_version)
    hypr_value.add_css_class('hyprpm-version')
    hypr_row.append(hypr_value)
    
    status_box.append(hypr_row)
    
    # Loaded plugins count
    loaded = get_loaded_plugins()
    
    loaded_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
    
    loaded_label = Gtk.Label(label="Loaded Plugins:")
    loaded_label.add_css_class('hyprpm-status-label')
    loaded_row.append(loaded_label)
    
    loaded_value = Gtk.Label(label=f"{len(loaded)} ({', '.join(loaded) if loaded else 'none'})")
    loaded_value.add_css_class('hyprpm-version')
    loaded_row.append(loaded_value)
    
    status_box.append(loaded_row)
    
    section.add_content(status_box)


def _build_plugins_content(window, section):
    """Build installed plugins list"""
    
    plugins_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
    window.plugins_widgets['plugins_list'] = plugins_box
    section.add_content(plugins_box)
    
    # Refresh button
    refresh_btn = Gtk.Button(label=f"{ICONS['refresh']} Refresh Plugins")
    refresh_btn.add_css_class('plugins-action-btn')
    refresh_btn.add_css_class('flat')
    refresh_btn.connect('clicked', lambda b: _refresh_plugins(window))
    
    btn_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
    btn_box.add_css_class('plugins-actions')
    btn_box.append(refresh_btn)
    section.add_content(btn_box)
    
    # Initial load
    _refresh_plugins(window)


def _refresh_plugins(window):
    """Refresh plugins list"""
    plugins_box = window.plugins_widgets.get('plugins_list')
    section = window.plugins_widgets.get('plugins_section')
    
    if not plugins_box:
        return
    
    # Clear existing
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
    
    # Build plugin cards
    for plugin in plugins:
        card = _create_plugin_card(window, plugin)
        plugins_box.append(card)
    
    # Update section subtitle
    if section:
        loaded_count = sum(1 for p in plugins if p.get('loaded', False))
        section.set_subtitle(f"{loaded_count} loaded, {len(plugins)} total")


def _create_plugin_card(window, plugin):
    """Create a plugin card widget"""
    card = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=16)
    card.add_css_class('plugin-card')
    
    is_loaded = plugin.get('loaded', False)
    
    if is_loaded:
        card.add_css_class('enabled')
    else:
        card.add_css_class('disabled')
    
    # Plugin icon
    icon = Gtk.Label(label=plugin['icon'])
    icon.add_css_class('plugin-icon')
    card.append(icon)
    
    # Plugin info
    info_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
    info_box.set_hexpand(True)
    
    # Name row
    name_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
    
    name_label = Gtk.Label(label=plugin['display_name'])
    name_label.add_css_class('plugin-name')
    name_label.set_halign(Gtk.Align.START)
    name_row.append(name_label)
    
    # Status badge
    if is_loaded:
        status_label = Gtk.Label(label="Loaded")
        status_label.add_css_class('plugin-status')
        status_label.add_css_class('enabled')
    else:
        status_label = Gtk.Label(label="Not Loaded")
        status_label.add_css_class('plugin-status')
        status_label.add_css_class('disabled')
    
    name_row.append(status_label)
    
    info_box.append(name_row)
    
    # Description
    desc_label = Gtk.Label(label=plugin['description'])
    desc_label.add_css_class('plugin-description')
    desc_label.set_halign(Gtk.Align.START)
    desc_label.set_wrap(True)
    desc_label.set_max_width_chars(50)
    info_box.append(desc_label)
    
    # Repo (if available)
    if plugin['repo']:
        repo_text = plugin['repo']
        if repo_text.startswith('https://'):
            repo_text = repo_text.replace('https://', '')
        repo_label = Gtk.Label(label=f"{ICONS['github']} {repo_text}")
        repo_label.add_css_class('plugin-repo')
        repo_label.set_halign(Gtk.Align.START)
        repo_label.set_ellipsize(3)  # PANGO_ELLIPSIZE_END
        info_box.append(repo_label)
    
    card.append(info_box)
    
    # Toggle switch
    toggle = Gtk.Switch()
    toggle.set_valign(Gtk.Align.CENTER)
    toggle.set_active(is_loaded)
    
    def on_toggle(switch, _, p=plugin):
        enable = switch.get_active()
        success, output = toggle_plugin(p['name'], enable)
        
        if success:
            _show_toast(window, f"{p['display_name']} {'enabled' if enable else 'disabled'}")
            # Reload to apply changes
            reload_success, reload_output = reload_plugins()
            if reload_success:
                _show_toast(window, "Plugins reloaded")
            GLib.timeout_add(1000, lambda: _refresh_plugins(window) or False)
        else:
            _show_toast(window, f"Failed to toggle {p['display_name']}: {output[:50]}")
            # Revert switch
            switch.set_active(not enable)
    
    toggle.connect('notify::active', on_toggle)
    card.append(toggle)
    
    return card


def _build_actions_content(window, section):
    """Build plugin actions content"""
    
    actions_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
    
    # Update all plugins
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
    
    update_desc = Gtk.Label(label="Fetch and build latest versions from repositories")
    update_desc.add_css_class('plugin-description')
    update_desc.set_halign(Gtk.Align.START)
    update_info.append(update_desc)
    
    update_row.append(update_info)
    
    update_btn = Gtk.Button(label="Update")
    update_btn.add_css_class('suggested-action')
    update_btn.set_valign(Gtk.Align.CENTER)
    
    def on_update_clicked(btn):
        btn.set_sensitive(False)
        btn.set_label("Updating...")
        
        def do_update():
            success, output = update_plugins()
            GLib.idle_add(lambda: _on_update_complete(window, btn, success, output))
        
        import threading
        thread = threading.Thread(target=do_update)
        thread.daemon = True
        thread.start()
    
    update_btn.connect('clicked', on_update_clicked)
    update_row.append(update_btn)
    
    actions_box.append(update_row)
    
    # Reload plugins
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
        success, output = reload_plugins()
        if success:
            _show_toast(window, "Plugins reloaded successfully")
            GLib.timeout_add(500, lambda: _refresh_plugins(window) or False)
        else:
            _show_toast(window, "Failed to reload plugins")
    
    reload_btn.connect('clicked', on_reload_clicked)
    reload_row.append(reload_btn)
    
    actions_box.append(reload_row)
    
    section.add_content(actions_box)


def _on_update_complete(window, btn, success, output):
    """Handle update completion"""
    btn.set_sensitive(True)
    btn.set_label("Update")
    
    if success:
        _show_toast(window, "Plugins updated successfully")
        _refresh_plugins(window)
    else:
        _show_toast(window, "Plugin update failed")
    
    return False


def _show_toast(window, message):
    """Show toast notification"""
    if hasattr(window, 'toast_overlay'):
        toast = Adw.Toast(title=message)
        toast.set_timeout(3)
        window.toast_overlay.add_toast(toast)
    else:
        print(f"[Plugins] {message}")