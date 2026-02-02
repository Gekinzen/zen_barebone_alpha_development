#!/usr/bin/env python3
"""
═══════════════════════════════════════════════════════════════════════════════
THEMING.PY PATCHER - Add Start Menu & Taskbar Section (FIXED)
═══════════════════════════════════════════════════════════════════════════════
"""

import re
import shutil
from pathlib import Path
from datetime import datetime

THEMING_FILE = Path.home() / ".config/hypr-control-center/src/pages/theming.py"

# ═══════════════════════════════════════════════════════════════════════════════
# CODE TO INSERT
# ═══════════════════════════════════════════════════════════════════════════════

PATH_CODE = '''
# Start Menu Icons Directory
START_ICONS_DIR = CONFIG_DIR / "assets" / "start-icons"
WAYBAR_STYLE = WAYBAR_DIR / "style.css"
'''

FUNCTIONS_CODE = r'''

# ═══════════════════════════════════════════════════════════════════════════════
# START MENU & TASKBAR FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

def get_available_start_icons() -> list:
    """Get all start menu icons from assets/start-icons/"""
    icons = []
    START_ICONS_DIR.mkdir(parents=True, exist_ok=True)
    for ext in ['*.svg', '*.png', '*.SVG', '*.PNG', '*.jpg', '*.jpeg', '*.webp']:
        for icon_path in START_ICONS_DIR.glob(ext):
            icons.append({'name': icon_path.stem, 'path': str(icon_path), 'filename': icon_path.name})
    icons.sort(key=lambda x: x['name'].lower())
    return icons


def get_current_start_icon() -> str:
    """Get current start icon from waybar style.css"""
    try:
        if WAYBAR_STYLE.exists():
            content = WAYBAR_STYLE.read_text()
            match = re.search(r'#custom-start-menu\s*\{[^}]*background-image:\s*url\(["\']?([^"\')\s]+)["\']?\)', content, re.DOTALL)
            if match: return match.group(1)
    except: pass
    return str(START_ICONS_DIR / "arch.svg")


def set_start_menu_icon(icon_path: str, window=None) -> bool:
    """Update start menu icon in waybar style.css"""
    try:
        if not WAYBAR_STYLE.exists(): return False
        content = WAYBAR_STYLE.read_text()
        pattern = r'(#custom-start-menu\s*\{[^}]*background-image:\s*url\()["\']?[^"\')\s]+["\']?(\))'
        if re.search(pattern, content, re.DOTALL):
            content = re.sub(pattern, rf'\1"{icon_path}"\2', content, flags=re.DOTALL)
        else:
            start_pattern = r'(#custom-start-menu\s*\{)'
            if re.search(start_pattern, content):
                content = re.sub(start_pattern, rf'\1\n    background-image: url("{icon_path}");', content)
            else: return False
        WAYBAR_STYLE.write_text(content)
        subprocess.run(['pkill', '-SIGUSR2', 'waybar'], capture_output=True)
        return True
    except: return False


def import_start_icon(source_path: str) -> str:
    """Import custom icon to assets/start-icons/"""
    try:
        source = Path(source_path)
        if not source.exists(): return None
        if source.suffix.lower() not in ['.svg', '.png', '.jpg', '.jpeg', '.webp']: return None
        START_ICONS_DIR.mkdir(parents=True, exist_ok=True)
        dest = START_ICONS_DIR / source.name
        counter = 1
        while dest.exists():
            dest = START_ICONS_DIR / f"{source.stem}_{counter}{source.suffix}"
            counter += 1
        shutil.copy(source, dest)
        return str(dest)
    except: return None


def delete_start_icon(icon_path: str) -> bool:
    """Delete icon from assets/start-icons/"""
    try:
        path = Path(icon_path)
        if not path.exists(): return False
        if str(START_ICONS_DIR) not in str(path.parent): return False
        path.unlink()
        return True
    except: return False


def get_current_taskbar_settings() -> dict:
    """Read taskbar settings from waybar style.css"""
    settings = {'border_radius': 45, 'font_size': 16, 'padding': 15, 'gap': 12}
    try:
        if WAYBAR_STYLE.exists():
            content = WAYBAR_STYLE.read_text()
            match = re.search(r'#custom-taskbar\s*\{([^}]+)\}', content)
            if match:
                block = match.group(1)
                r = re.search(r'border-radius:\s*(\d+)', block)
                if r: settings['border_radius'] = int(r.group(1))
                f = re.search(r'font-size:\s*(\d+)', block)
                if f: settings['font_size'] = int(f.group(1))
                p = re.search(r'padding:\s*\d+(?:px)?\s+(\d+)', block)
                if p: settings['padding'] = int(p.group(1))
                m = re.search(r'margin:\s*\d+(?:px)?\s+\d+(?:px)?\s+\d+(?:px)?\s+(\d+)', block)
                if m: settings['gap'] = int(m.group(1))
    except: pass
    return settings


def update_taskbar_css(options: dict, window=None) -> bool:
    """Update taskbar styling in waybar style.css"""
    try:
        if not WAYBAR_STYLE.exists(): return False
        content = WAYBAR_STYLE.read_text()
        if 'border_radius' in options:
            val = options['border_radius']
            content = re.sub(r'(#custom-taskbar\s*\{[^}]*border-radius:\s*)\d+px', rf'\g<1>{val}px', content, flags=re.DOTALL)
            content = re.sub(r'(#taskbar\s*\{[^}]*border-radius:\s*)\d+px', rf'\g<1>{max(8,int(val*0.4))}px', content, flags=re.DOTALL)
            content = re.sub(r'(#taskbar button\s*\{[^}]*border-radius:\s*)\d+px', rf'\g<1>{max(6,int(val*0.3))}px', content, flags=re.DOTALL)
        if 'font_size' in options:
            content = re.sub(r'(#custom-taskbar\s*\{[^}]*font-size:\s*)\d+px', rf'\g<1>{options["font_size"]}px', content, flags=re.DOTALL)
        if 'padding' in options:
            content = re.sub(r'(#custom-taskbar\s*\{[^}]*padding:\s*)0\s+\d+px', rf'\g<1>0 {options["padding"]}px', content, flags=re.DOTALL)
        if 'gap' in options:
            content = re.sub(r'(#custom-taskbar\s*\{[^}]*margin:\s*)0\s+0\s+0\s+\d+px', rf'\g<1>0 0 0 {options["gap"]}px', content, flags=re.DOTALL)
            content = re.sub(r'(#taskbar\s*\{[^}]*margin:\s*)0\s+0\s+0\s+\d+px', rf'\g<1>0 0 0 {options["gap"]}px', content, flags=re.DOTALL)
        WAYBAR_STYLE.write_text(content)
        subprocess.run(['pkill', '-SIGUSR2', 'waybar'], capture_output=True)
        return True
    except: return False


def _build_start_menu_taskbar_section(window, colors: dict):
    """Build Start Menu & Taskbar customization section"""
    from gi.repository import GdkPixbuf
    
    content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
    content.set_margin_start(16); content.set_margin_end(16); content.set_margin_top(8); content.set_margin_bottom(16)
    
    # START MENU BUTTON SECTION
    sm_header = Gtk.Label(label="START MENU BUTTON"); sm_header.add_css_class("heading"); sm_header.set_xalign(0)
    sm_header.set_margin_top(8); sm_header.set_margin_bottom(12); content.append(sm_header)
    
    current_icon_path = get_current_start_icon()
    current_icon_name = Path(current_icon_path).stem if current_icon_path else "arch"
    
    # Current icon preview
    current_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12); current_row.set_margin_bottom(12)
    preview_frame = Gtk.Frame(); preview_frame.set_size_request(64, 64)
    preview_box = Gtk.Box(); preview_box.set_halign(Gtk.Align.CENTER); preview_box.set_valign(Gtk.Align.CENTER)
    preview_box.set_margin_top(8); preview_box.set_margin_bottom(8); preview_box.set_margin_start(8); preview_box.set_margin_end(8)
    try:
        if current_icon_path and Path(current_icon_path).exists():
            pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(current_icon_path, 40, 40, True)
            preview_img = Gtk.Image.new_from_pixbuf(pixbuf)
        else:
            preview_img = Gtk.Image.new_from_icon_name("start-here-symbolic"); preview_img.set_pixel_size(40)
    except:
        preview_img = Gtk.Image.new_from_icon_name("start-here-symbolic"); preview_img.set_pixel_size(40)
    preview_box.append(preview_img); preview_frame.set_child(preview_box); current_row.append(preview_frame)
    window._start_preview_img = preview_img
    
    info_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2); info_box.set_valign(Gtk.Align.CENTER); info_box.set_hexpand(True)
    current_lbl = Gtk.Label(label="Current Icon"); current_lbl.add_css_class("dim-label"); current_lbl.add_css_class("caption"); current_lbl.set_xalign(0)
    info_box.append(current_lbl)
    name_lbl = Gtk.Label(label=current_icon_name); name_lbl.add_css_class("title-4"); name_lbl.set_xalign(0); info_box.append(name_lbl)
    window._start_icon_name_label = name_lbl
    current_row.append(info_box); content.append(current_row)
    
    # Icon picker
    picker_label = Gtk.Label(label="Choose Icon"); picker_label.set_xalign(0); picker_label.add_css_class("dim-label"); picker_label.set_margin_bottom(8)
    content.append(picker_label)
    
    scroll = Gtk.ScrolledWindow(); scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
    scroll.set_min_content_height(150); scroll.set_max_content_height(200)
    
    icon_flow = Gtk.FlowBox(); icon_flow.set_selection_mode(Gtk.SelectionMode.SINGLE)
    icon_flow.set_max_children_per_line(6); icon_flow.set_min_children_per_line(4)
    icon_flow.set_column_spacing(8); icon_flow.set_row_spacing(8); icon_flow.set_homogeneous(True)
    window._start_icon_flow = icon_flow; window._selected_start_icon = current_icon_path
    
    def load_icons():
        while True:
            child = icon_flow.get_first_child()
            if child is None: break
            icon_flow.remove(child)
        for icon in get_available_start_icons():
            child = Gtk.FlowBoxChild(); child.icon_path = icon['path']; child.icon_name = icon['name']
            box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
            box.set_halign(Gtk.Align.CENTER); box.set_valign(Gtk.Align.CENTER)
            box.set_margin_top(8); box.set_margin_bottom(8); box.set_margin_start(8); box.set_margin_end(8)
            try:
                pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(icon['path'], 40, 40, True)
                img = Gtk.Image.new_from_pixbuf(pixbuf)
            except:
                img = Gtk.Image.new_from_icon_name("image-missing"); img.set_pixel_size(40)
            box.append(img)
            lbl = Gtk.Label(label=icon['name'][:12]); lbl.add_css_class("caption"); lbl.add_css_class("dim-label")
            lbl.set_max_width_chars(12); lbl.set_ellipsize(3); box.append(lbl)
            child.set_child(box); icon_flow.append(child)
            if icon['path'] == current_icon_path or icon['filename'] in str(current_icon_path):
                GLib.idle_add(lambda c=child: icon_flow.select_child(c))
    
    load_icons(); window._reload_start_icons = load_icons
    
    def on_icon_selected(flow, child):
        if child is None or not hasattr(child, 'icon_path'): return
        window._selected_start_icon = child.icon_path
        try:
            pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(child.icon_path, 40, 40, True)
            window._start_preview_img.set_from_pixbuf(pixbuf)
        except: pass
        window._start_icon_name_label.set_text(Path(child.icon_path).stem)
    
    icon_flow.connect("child-activated", on_icon_selected)
    scroll.set_child(icon_flow); content.append(scroll)
    
    # Buttons
    btn_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8); btn_row.set_margin_top(12)
    import_btn = Gtk.Button()
    import_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
    import_box.append(Gtk.Image.new_from_icon_name("list-add-symbolic")); import_box.append(Gtk.Label(label="Import"))
    import_btn.set_child(import_box); import_btn.set_tooltip_text("Import icon (SVG, PNG)")
    
    def on_import(btn):
        dialog = Gtk.FileChooserDialog(title="Import Start Icon", transient_for=window, action=Gtk.FileChooserAction.OPEN)
        dialog.add_button("Cancel", Gtk.ResponseType.CANCEL); dialog.add_button("Import", Gtk.ResponseType.ACCEPT)
        filt = Gtk.FileFilter(); filt.set_name("Icons"); filt.add_pattern("*.svg"); filt.add_pattern("*.png"); dialog.add_filter(filt)
        def on_resp(d, r):
            if r == Gtk.ResponseType.ACCEPT:
                f = d.get_file()
                if f:
                    imported = import_start_icon(f.get_path())
                    if imported: window._reload_start_icons()
            d.destroy()
        dialog.connect("response", on_resp); dialog.present()
    
    import_btn.connect("clicked", on_import); btn_row.append(import_btn)
    
    del_btn = Gtk.Button(); del_btn.set_icon_name("user-trash-symbolic"); del_btn.set_tooltip_text("Delete"); del_btn.add_css_class("flat")
    def on_del(btn):
        if hasattr(window, '_selected_start_icon') and window._selected_start_icon:
            if delete_start_icon(window._selected_start_icon): window._reload_start_icons()
    del_btn.connect("clicked", on_del); btn_row.append(del_btn)
    btn_row.append(Gtk.Box(hexpand=True))
    
    apply_btn = Gtk.Button(label="Apply Icon"); apply_btn.add_css_class("suggested-action")
    def on_apply(btn):
        if hasattr(window, '_selected_start_icon') and window._selected_start_icon:
            if set_start_menu_icon(window._selected_start_icon):
                if hasattr(window, '_show_toast'): window._show_toast("✅ Icon applied!")
    apply_btn.connect("clicked", on_apply); btn_row.append(apply_btn)
    content.append(btn_row)
    
    # TASKBAR SECTION
    tb_header = Gtk.Label(label="TASKBAR STYLING"); tb_header.add_css_class("heading"); tb_header.set_xalign(0)
    tb_header.set_margin_top(24); tb_header.set_margin_bottom(12); content.append(tb_header)
    
    taskbar_settings = get_current_taskbar_settings(); window._taskbar_settings = taskbar_settings.copy()
    
    for label, key, min_v, max_v, default in [("Corner Radius", "border_radius", 0, 50, 45), ("Font Size", "font_size", 12, 24, 16),
                                               ("Horizontal Padding", "padding", 5, 30, 15), ("Gap from Modules", "gap", 0, 24, 12)]:
        row = _create_setting_row(label, f"{label} ({min_v}-{max_v})")
        spin = Gtk.SpinButton.new_with_range(min_v, max_v, 1); spin.set_value(taskbar_settings.get(key, default)); spin.set_valign(Gtk.Align.CENTER)
        spin.connect('value-changed', lambda s, k=key: window._taskbar_settings.update({k: int(s.get_value())}))
        row.append(spin); content.append(row)
    
    tb_btn_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8); tb_btn_row.set_margin_top(16)
    reset_btn = Gtk.Button(label="Reset")
    reset_btn.connect("clicked", lambda b: window._taskbar_settings.update({'border_radius': 45, 'font_size': 16, 'padding': 15, 'gap': 12}))
    tb_btn_row.append(reset_btn); tb_btn_row.append(Gtk.Box(hexpand=True))
    
    tb_apply = Gtk.Button(label="Apply Taskbar Style"); tb_apply.add_css_class("suggested-action")
    def on_tb_apply(btn):
        if update_taskbar_css(window._taskbar_settings):
            if hasattr(window, '_show_toast'): window._show_toast("✅ Taskbar style applied!")
    tb_apply.connect("clicked", on_tb_apply); tb_btn_row.append(tb_apply)
    content.append(tb_btn_row)
    
    # Info
    info = Gtk.Label(); info.set_markup("💡 <span size='small'>Icons: ~/.config/hypr-control-center/assets/start-icons/</span>")
    info.add_css_class("dim-label"); info.set_xalign(0); info.set_margin_top(16); content.append(info)
    
    return content

'''

EXPANDER_CODE = '''
    # Start Menu & Taskbar
    sm_exp = Gtk.Expander(label="  Start Menu & Taskbar")
    sm_exp.set_margin_start(16); sm_exp.set_margin_end(16); sm_exp.set_margin_top(8); sm_exp.set_margin_bottom(8)
    sm_exp.set_child(_build_start_menu_taskbar_section(window, colors))
    apps_group.append(sm_exp)
'''

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN PATCHER - Using string find/insert instead of regex sub
# ═══════════════════════════════════════════════════════════════════════════════

def patch_theming():
    print("═" * 60)
    print("THEMING.PY PATCHER - Start Menu & Taskbar Section")
    print("═" * 60)
    
    if not THEMING_FILE.exists():
        print(f"❌ File not found: {THEMING_FILE}")
        return False
    
    # Backup
    backup = THEMING_FILE.with_suffix(f".py.bak.{datetime.now().strftime('%Y%m%d_%H%M%S')}")
    shutil.copy(THEMING_FILE, backup)
    print(f"✅ Backup: {backup.name}")
    
    content = THEMING_FILE.read_text()
    
    # Check if already patched
    if 'START_ICONS_DIR' in content:
        print("⚠️  Already patched (START_ICONS_DIR found)")
        return False
    
    # 1. Add PATH after _CONTROL_CENTER_CSS_PROVIDER = None
    marker1 = "_CONTROL_CENTER_CSS_PROVIDER = None"
    pos1 = content.find(marker1)
    if pos1 != -1:
        insert_pos = pos1 + len(marker1)
        content = content[:insert_pos] + PATH_CODE + content[insert_pos:]
        print("✅ Added START_ICONS_DIR path")
    else:
        print("❌ Could not find _CONTROL_CENTER_CSS_PROVIDER")
        return False
    
    # 2. Add Functions before "# CSS GENERATION - Control Center"
    marker2 = "# CSS GENERATION - Control Center"
    pos2 = content.find(marker2)
    if pos2 != -1:
        # Find the start of the separator line before it
        line_start = content.rfind("# ═", 0, pos2)
        if line_start != -1:
            content = content[:line_start] + FUNCTIONS_CODE + "\n\n" + content[line_start:]
            print("✅ Added Start Menu & Taskbar functions")
        else:
            content = content[:pos2] + FUNCTIONS_CODE + "\n\n" + content[pos2:]
            print("✅ Added functions (no separator found)")
    else:
        print("❌ Could not find CSS GENERATION section")
        return False
    
    # 3. Add Expander after Hyprland section
    marker3 = "hy_exp.set_child(hy_content); apps_group.append(hy_exp)"
    pos3 = content.find(marker3)
    if pos3 != -1:
        insert_pos = pos3 + len(marker3)
        content = content[:insert_pos] + EXPANDER_CODE + content[insert_pos:]
        print("✅ Added expander in build_theming_page()")
    else:
        print("❌ Could not find Hyprland expander")
        return False
    
    # Write patched file
    THEMING_FILE.write_text(content)
    
    print("")
    print("═" * 60)
    print("✅ PATCH COMPLETE!")
    print("═" * 60)
    print("")
    print("Changes made:")
    print("  • Added START_ICONS_DIR and WAYBAR_STYLE paths")
    print("  • Added 8 functions for Start Menu & Taskbar")
    print("  • Added expander section in build_theming_page()")
    print("")
    print("Next: Restart Hyprland Control Center to test")
    
    return True


if __name__ == "__main__":
    patch_theming()