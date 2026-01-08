"""
Taskbar Configuration Page
Manages pinned applications and shows current icon style
Icon style is controlled by Panel Appearance → Panel Style setting
"""

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
from gi.repository import Gtk, Adw, GLib
import json
import os
import subprocess

from ..widgets import SettingsGroup


def build_taskbar_page(window) -> Gtk.ScrolledWindow:
    """Build Taskbar settings page"""
    scrolled = Gtk.ScrolledWindow()
    scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
    
    content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
    content.add_css_class('content-area')
    
    # Header
    page_header = window._create_page_header(
        "Taskbar",
        "Manage pinned applications and taskbar behavior"
    )
    content.append(page_header)
    
    # Main content
    main_content = _build_taskbar_content(window)
    content.append(main_content)
    
    scrolled.set_child(content)
    return scrolled


def _build_taskbar_content(window) -> Gtk.Box:
    """Build taskbar configuration content"""
    content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16)
    content.set_margin_start(32)
    content.set_margin_end(32)
    content.set_margin_top(16)
    content.set_margin_bottom(16)
    
    # Load preferences
    prefs = _load_taskbar_preferences()
    panel_style = _load_panel_style()
    
    # ═══════════════════════════════════════════════════════════════
    # ICON STYLE INFO (READ-ONLY)
    # ═══════════════════════════════════════════════════════════════
    
    info_group = SettingsGroup("Icon Style")
    
    # Info banner explaining that style is controlled elsewhere
    info_banner = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
    info_banner.add_css_class('info-banner')
    info_banner.set_margin_top(8)
    info_banner.set_margin_bottom(8)
    
    info_icon = Gtk.Image.new_from_icon_name('dialog-information-symbolic')
    info_icon.set_pixel_size(16)
    info_banner.append(info_icon)
    
    info_text = Gtk.Label()
    info_text.set_markup(
        "Taskbar icons follow the <b>Panel Appearance → Panel Style</b> setting.\n"
        "Change it there to switch between Minimal and Modern icons."
    )
    info_text.set_halign(Gtk.Align.START)
    info_text.set_wrap(True)
    info_text.set_xalign(0)
    info_banner.append(info_text)
    
    info_group.append(info_banner)
    
    # Current style display
    style_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
    style_row.set_margin_top(8)
    style_row.set_margin_bottom(8)
    
    style_label = Gtk.Label(label="Current Style")
    style_label.add_css_class('setting-label')
    style_label.set_halign(Gtk.Align.START)
    style_label.set_hexpand(True)
    style_row.append(style_label)
    
    # Style badge
    style_badge = Gtk.Label()
    if panel_style == 'modern':
        style_badge.set_markup("<b>Modern</b> (System Theme Icons) 🎨")
    else:
        style_badge.set_markup("<b>Minimal</b> (Nerd Font Icons) 󰈹")
    style_badge.add_css_class('style-badge')
    style_row.append(style_badge)
    
    info_group.append(style_row)
    
    # Preview
    preview_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
    preview_row.set_margin_top(8)
    preview_row.set_margin_bottom(8)
    
    preview_label = Gtk.Label(label="Preview")
    preview_label.add_css_class('setting-label')
    preview_label.set_halign(Gtk.Align.START)
    preview_label.set_hexpand(True)
    preview_row.append(preview_label)
    
    # Preview icons
    preview_icons = Gtk.Label()
    if panel_style == 'modern':
        preview_icons.set_markup("<span font='14'>🦊 💻 📁 🖥️</span>")
    else:
        preview_icons.set_markup("<span font='18'>󰈹 󰊯 󰨞 󰆍 󰝰</span>")
    preview_row.append(preview_icons)
    
    info_group.append(preview_row)
    
    content.append(info_group)
    
    # ═══════════════════════════════════════════════════════════════
    # PINNED APPLICATIONS
    # ═══════════════════════════════════════════════════════════════
    
    pinned_group = SettingsGroup("Pinned Applications")
    
    # Description
    desc_label = Gtk.Label(
        label="Applications that always appear in the taskbar"
    )
    desc_label.add_css_class('setting-description')
    desc_label.set_halign(Gtk.Align.START)
    desc_label.set_margin_bottom(12)
    pinned_group.append(desc_label)
    
    # List of pinned apps
    pinned_list = Gtk.ListBox()
    pinned_list.set_selection_mode(Gtk.SelectionMode.NONE)
    pinned_list.add_css_class('boxed-list')
    
    pinned_apps = prefs.get('pinned', [])
    
    if pinned_apps:
        for app_id in pinned_apps:
            row = _create_pinned_app_row(window, app_id)
            pinned_list.append(row)
    else:
        # Empty state
        empty_row = Gtk.ListBoxRow()
        empty_row.set_activatable(False)
        
        empty_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        empty_box.set_margin_top(16)
        empty_box.set_margin_bottom(16)
        
        empty_icon = Gtk.Image.new_from_icon_name('folder-symbolic')
        empty_icon.set_pixel_size(48)
        empty_icon.add_css_class('dim-label')
        empty_box.append(empty_icon)
        
        empty_label = Gtk.Label(label="No pinned applications")
        empty_label.add_css_class('dim-label')
        empty_box.append(empty_label)
        
        empty_row.set_child(empty_box)
        pinned_list.append(empty_row)
    
    pinned_group.append(pinned_list)
    
    # Add button
    add_btn = Gtk.Button()
    add_btn.set_label("Add Application")
    add_btn.set_icon_name('list-add-symbolic')
    add_btn.add_css_class('suggested-action')
    add_btn.set_margin_top(12)
    add_btn.connect('clicked', lambda b: _on_add_app_clicked(window))
    pinned_group.append(add_btn)
    
    content.append(pinned_group)
    
    # ═══════════════════════════════════════════════════════════════
    # USAGE HELP
    # ═══════════════════════════════════════════════════════════════
    
    help_group = SettingsGroup("Usage")
    
    help_items = [
        ("Left Click", "Focus window (or launch if pinned)"),
        ("Right Click", "Show menu (close, pin/unpin)"),
        ("Multiple Windows", "Shows count in parentheses")
    ]
    
    for title, subtitle in help_items:
        help_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        help_row.set_margin_top(6)
        help_row.set_margin_bottom(6)
        
        title_label = Gtk.Label(label=title)
        title_label.add_css_class('setting-label')
        title_label.set_halign(Gtk.Align.START)
        title_label.set_hexpand(True)
        help_row.append(title_label)
        
        subtitle_label = Gtk.Label(label=subtitle)
        subtitle_label.add_css_class('setting-description')
        subtitle_label.set_halign(Gtk.Align.END)
        help_row.append(subtitle_label)
        
        help_group.append(help_row)
    
    content.append(help_group)
    
    return content


def _create_pinned_app_row(window, app_id: str) -> Gtk.ListBoxRow:
    """Create a row for a pinned application"""
    row = Gtk.ListBoxRow()
    row.set_activatable(False)
    
    box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
    box.set_margin_top(8)
    box.set_margin_bottom(8)
    box.set_margin_start(12)
    box.set_margin_end(12)
    
    # App icon/name
    app_label = Gtk.Label(label=app_id)
    app_label.set_halign(Gtk.Align.START)
    app_label.set_hexpand(True)
    box.append(app_label)
    
    # Remove button
    remove_btn = Gtk.Button()
    remove_btn.set_icon_name('user-trash-symbolic')
    remove_btn.add_css_class('destructive-action')
    remove_btn.set_valign(Gtk.Align.CENTER)
    remove_btn.connect('clicked', lambda b: _on_remove_app_clicked(window, app_id))
    box.append(remove_btn)
    
    row.set_child(box)
    return row


def _on_add_app_clicked(window):
    """Show dialog to add a pinned application"""
    dialog = Adw.MessageDialog.new(
        window,
        "Add Pinned Application",
        "Enter the application class name (e.g., firefox, code, thunar)"
    )
    
    # Entry field
    entry_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
    entry_box.set_margin_start(12)
    entry_box.set_margin_end(12)
    entry_box.set_margin_top(12)
    entry_box.set_margin_bottom(12)
    
    entry = Gtk.Entry()
    entry.set_placeholder_text("Application class name")
    entry_box.append(entry)
    
    # Hint
    hint = Gtk.Label()
    hint.set_markup("<span size='small'>💡 Tip: Right-click a running app in taskbar to pin it</span>")
    hint.add_css_class('dim-label')
    hint.set_halign(Gtk.Align.START)
    entry_box.append(hint)
    
    dialog.set_extra_child(entry_box)
    
    dialog.add_response("cancel", "Cancel")
    dialog.add_response("add", "Add")
    dialog.set_response_appearance("add", Adw.ResponseAppearance.SUGGESTED)
    dialog.set_default_response("add")
    
    def on_response(dialog, response_id):
        if response_id == "add":
            app_id = entry.get_text().strip()
            
            if app_id:
                prefs = _load_taskbar_preferences()
                
                if app_id in prefs.get('pinned', []):
                    window._show_toast(f"{app_id} is already pinned")
                else:
                    if 'pinned' not in prefs:
                        prefs['pinned'] = []
                    
                    prefs['pinned'].append(app_id)
                    _save_taskbar_preferences(prefs)
                    
                    window._show_toast(f"Pinned {app_id}")
                    
                    # Refresh page
                    _refresh_taskbar_page(window)
    
    dialog.connect('response', on_response)
    dialog.present()


def _on_remove_app_clicked(window, app_id: str):
    """Remove a pinned application"""
    prefs = _load_taskbar_preferences()
    
    if app_id in prefs.get('pinned', []):
        prefs['pinned'].remove(app_id)
        _save_taskbar_preferences(prefs)
        
        window._show_toast(f"Unpinned {app_id}")
        
        # Refresh page
        _refresh_taskbar_page(window)


def _refresh_taskbar_page(window):
    """Refresh taskbar page to show updated configuration"""
    old_page = window.stack.get_child_by_name("taskbar")
    
    # Save scroll position
    vadj_value = 0
    if isinstance(old_page, Gtk.ScrolledWindow):
        vadj = old_page.get_vadjustment()
        vadj_value = vadj.get_value()
    
    # Rebuild page
    new_page = build_taskbar_page(window)
    
    if old_page:
        window.stack.remove(old_page)
    
    window.stack.add_named(new_page, "taskbar")
    window.stack.set_visible_child_name("taskbar")
    
    # Restore scroll position
    def restore_scroll():
        if isinstance(new_page, Gtk.ScrolledWindow):
            vadj = new_page.get_vadjustment()
            vadj.set_value(vadj_value)
        return False
    
    GLib.idle_add(restore_scroll)


def _load_taskbar_preferences() -> dict:
    """Load taskbar preferences from JSON"""
    prefs_file = os.path.expanduser("~/.config/hypr-control-center/preferences/taskbar.json")
    
    try:
        with open(prefs_file, 'r') as f:
            return json.load(f)
    except:
        return {"pinned": []}


def _save_taskbar_preferences(prefs: dict):
    """Save taskbar preferences to JSON"""
    prefs_file = os.path.expanduser("~/.config/hypr-control-center/preferences/taskbar.json")
    os.makedirs(os.path.dirname(prefs_file), exist_ok=True)
    
    with open(prefs_file, 'w') as f:
        json.dump(prefs, f, indent=2)
    
    # Signal Waybar to reload (taskbar will pick up changes)
    try:
        subprocess.run(['pkill', '-USR2', 'waybar'], check=False, timeout=1)
    except:
        pass


def _load_panel_style() -> str:
    """Load current panel style from waybar-menu.json"""
    style_file = os.path.expanduser("~/.config/hypr-control-center/preferences/waybar-menu.json")
    
    try:
        with open(style_file, 'r') as f:
            data = json.load(f)
            return data.get('style_mode', 'minimal')
    except:
        return 'minimal'