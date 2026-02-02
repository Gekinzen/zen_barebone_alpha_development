"""START MENU SECTION - Start Menu & Taskbar UI"""
import gi
gi.require_version('Gtk', '4.0')
from gi.repository import Gtk, GLib, GdkPixbuf
import subprocess, shutil, re
from pathlib import Path
from .constants import START_ICONS_DIR, WAYBAR_STYLE
from .ui_components import create_setting_row

def get_available_icons():
    icons = []; START_ICONS_DIR.mkdir(parents=True, exist_ok=True)
    for ext in ['*.svg', '*.png', '*.SVG', '*.PNG', '*.jpg', '*.jpeg', '*.webp']:
        for p in START_ICONS_DIR.glob(ext): icons.append({'name': p.stem, 'path': str(p), 'filename': p.name})
    return sorted(icons, key=lambda x: x['name'].lower())

def get_current_icon():
    try:
        if WAYBAR_STYLE.exists():
            m = re.search(r'#custom-start-menu\s*\{[^}]*background-image:\s*url\(["\']?([^"\')\s]+)["\']?\)', WAYBAR_STYLE.read_text(), re.DOTALL)
            if m: return m.group(1)
    except: pass
    return str(START_ICONS_DIR / "arch.svg")

def set_icon(path, w=None):
    try:
        if not WAYBAR_STYLE.exists(): return False
        c = WAYBAR_STYLE.read_text()
        p = r'(#custom-start-menu\s*\{[^}]*background-image:\s*url\()["\']?[^"\')\s]+["\']?(\))'
        if re.search(p, c, re.DOTALL): c = re.sub(p, rf'\1"{path}"\2', c, flags=re.DOTALL)
        else:
            sp = r'(#custom-start-menu\s*\{)'
            if re.search(sp, c): c = re.sub(sp, rf'\1\n    background-image: url("{path}");', c)
            else: return False
        WAYBAR_STYLE.write_text(c); subprocess.run(['pkill', '-SIGUSR2', 'waybar'], capture_output=True); return True
    except: return False

def import_icon(src):
    try:
        s = Path(src)
        if not s.exists() or s.suffix.lower() not in ['.svg', '.png', '.jpg', '.jpeg', '.webp']: return None
        START_ICONS_DIR.mkdir(parents=True, exist_ok=True); d = START_ICONS_DIR / s.name; n = 1
        while d.exists(): d = START_ICONS_DIR / f"{s.stem}_{n}{s.suffix}"; n += 1
        shutil.copy(s, d); return str(d)
    except: return None

def delete_icon(path):
    try:
        p = Path(path)
        if p.exists() and str(START_ICONS_DIR) in str(p.parent): p.unlink(); return True
    except: pass
    return False

def get_taskbar_settings():
    s = {'border_radius': 45, 'font_size': 16, 'padding': 15, 'gap': 12}
    try:
        if WAYBAR_STYLE.exists():
            m = re.search(r'#custom-taskbar\s*\{([^}]+)\}', WAYBAR_STYLE.read_text())
            if m:
                b = m.group(1)
                r = re.search(r'border-radius:\s*(\d+)', b); f = re.search(r'font-size:\s*(\d+)', b)
                p = re.search(r'padding:\s*\d+(?:px)?\s+(\d+)', b); g = re.search(r'margin:\s*\d+(?:px)?\s+\d+(?:px)?\s+\d+(?:px)?\s+(\d+)', b)
                if r: s['border_radius'] = int(r.group(1))
                if f: s['font_size'] = int(f.group(1))
                if p: s['padding'] = int(p.group(1))
                if g: s['gap'] = int(g.group(1))
    except: pass
    return s

def update_taskbar_css(opts, w=None):
    try:
        if not WAYBAR_STYLE.exists(): return False
        c = WAYBAR_STYLE.read_text()
        if 'border_radius' in opts:
            v = opts['border_radius']
            c = re.sub(r'(#custom-taskbar\s*\{[^}]*border-radius:\s*)\d+px', rf'\g<1>{v}px', c, flags=re.DOTALL)
            c = re.sub(r'(#taskbar\s*\{[^}]*border-radius:\s*)\d+px', rf'\g<1>{max(8,int(v*0.4))}px', c, flags=re.DOTALL)
        if 'font_size' in opts: c = re.sub(r'(#custom-taskbar\s*\{[^}]*font-size:\s*)\d+px', rf'\g<1>{opts["font_size"]}px', c, flags=re.DOTALL)
        if 'padding' in opts: c = re.sub(r'(#custom-taskbar\s*\{[^}]*padding:\s*)0\s+\d+px', rf'\g<1>0 {opts["padding"]}px', c, flags=re.DOTALL)
        if 'gap' in opts:
            c = re.sub(r'(#custom-taskbar\s*\{[^}]*margin:\s*)0\s+0\s+0\s+\d+px', rf'\g<1>0 0 0 {opts["gap"]}px', c, flags=re.DOTALL)
            c = re.sub(r'(#taskbar\s*\{[^}]*margin:\s*)0\s+0\s+0\s+\d+px', rf'\g<1>0 0 0 {opts["gap"]}px', c, flags=re.DOTALL)
        WAYBAR_STYLE.write_text(c); subprocess.run(['pkill', '-SIGUSR2', 'waybar'], capture_output=True); return True
    except: return False

def build_start_menu_taskbar_section(window, colors):
    c = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
    c.set_margin_start(16); c.set_margin_end(16); c.set_margin_top(8); c.set_margin_bottom(16)
    
    # Start Menu Header
    h = Gtk.Label(label="START MENU BUTTON"); h.add_css_class("heading"); h.set_xalign(0); h.set_margin_top(8); h.set_margin_bottom(12); c.append(h)
    cur_path = get_current_icon(); cur_name = Path(cur_path).stem if cur_path else "arch"
    
    # Preview row
    pr = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12); pr.set_margin_bottom(12)
    pf = Gtk.Frame(); pf.set_size_request(64, 64); pb = Gtk.Box()
    pb.set_halign(Gtk.Align.CENTER); pb.set_valign(Gtk.Align.CENTER); pb.set_margin_top(8); pb.set_margin_bottom(8); pb.set_margin_start(8); pb.set_margin_end(8)
    try:
        if cur_path and Path(cur_path).exists(): pimg = Gtk.Image.new_from_pixbuf(GdkPixbuf.Pixbuf.new_from_file_at_scale(cur_path, 40, 40, True))
        else: pimg = Gtk.Image.new_from_icon_name("start-here-symbolic"); pimg.set_pixel_size(40)
    except: pimg = Gtk.Image.new_from_icon_name("start-here-symbolic"); pimg.set_pixel_size(40)
    pb.append(pimg); pf.set_child(pb); pr.append(pf); window._start_preview_img = pimg
    ib = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2); ib.set_valign(Gtk.Align.CENTER); ib.set_hexpand(True)
    cl = Gtk.Label(label="Current Icon"); cl.add_css_class("dim-label"); cl.add_css_class("caption"); cl.set_xalign(0); ib.append(cl)
    nl = Gtk.Label(label=cur_name); nl.add_css_class("title-4"); nl.set_xalign(0); ib.append(nl); window._start_icon_name_label = nl
    pr.append(ib); c.append(pr)
    
    # Icon picker
    pl = Gtk.Label(label="Choose Icon"); pl.set_xalign(0); pl.add_css_class("dim-label"); pl.set_margin_bottom(8); c.append(pl)
    sc = Gtk.ScrolledWindow(); sc.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC); sc.set_min_content_height(150); sc.set_max_content_height(200)
    fl = Gtk.FlowBox(); fl.set_selection_mode(Gtk.SelectionMode.SINGLE); fl.set_max_children_per_line(6); fl.set_min_children_per_line(4); fl.set_column_spacing(8); fl.set_row_spacing(8); fl.set_homogeneous(True)
    window._start_icon_flow = fl; window._selected_start_icon = cur_path
    def load():
        while (ch := fl.get_first_child()): fl.remove(ch)
        for ic in get_available_icons():
            ch = Gtk.FlowBoxChild(); ch.icon_path = ic['path']; ch.icon_name = ic['name']
            bx = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4); bx.set_halign(Gtk.Align.CENTER); bx.set_valign(Gtk.Align.CENTER)
            bx.set_margin_top(8); bx.set_margin_bottom(8); bx.set_margin_start(8); bx.set_margin_end(8)
            try: im = Gtk.Image.new_from_pixbuf(GdkPixbuf.Pixbuf.new_from_file_at_scale(ic['path'], 40, 40, True))
            except: im = Gtk.Image.new_from_icon_name("image-missing"); im.set_pixel_size(40)
            bx.append(im); lb = Gtk.Label(label=ic['name'][:12]); lb.add_css_class("caption"); lb.add_css_class("dim-label"); lb.set_max_width_chars(12); lb.set_ellipsize(3); bx.append(lb)
            ch.set_child(bx); fl.append(ch)
            if ic['path'] == cur_path or ic['filename'] in str(cur_path): GLib.idle_add(lambda c=ch: fl.select_child(c))
    load(); window._reload_start_icons = load
    def on_sel(f, ch):
        if ch and hasattr(ch, 'icon_path'):
            window._selected_start_icon = ch.icon_path
            try: window._start_preview_img.set_from_pixbuf(GdkPixbuf.Pixbuf.new_from_file_at_scale(ch.icon_path, 40, 40, True))
            except: pass
            window._start_icon_name_label.set_text(Path(ch.icon_path).stem)
    fl.connect("child-activated", on_sel); sc.set_child(fl); c.append(sc)
    
    # Buttons
    br = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8); br.set_margin_top(12)
    ib = Gtk.Button(); ibx = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
    ibx.append(Gtk.Image.new_from_icon_name("list-add-symbolic")); ibx.append(Gtk.Label(label="Import")); ib.set_child(ibx)
    def on_imp(_):
        d = Gtk.FileChooserDialog(title="Import Icon", transient_for=window, action=Gtk.FileChooserAction.OPEN)
        d.add_button("Cancel", Gtk.ResponseType.CANCEL); d.add_button("Import", Gtk.ResponseType.ACCEPT)
        ft = Gtk.FileFilter(); ft.set_name("Icons"); ft.add_pattern("*.svg"); ft.add_pattern("*.png"); d.add_filter(ft)
        d.connect("response", lambda d, r: (import_icon(d.get_file().get_path()) if r == Gtk.ResponseType.ACCEPT and d.get_file() else None, load() if r == Gtk.ResponseType.ACCEPT else None, d.destroy()))
        d.present()
    ib.connect("clicked", on_imp); br.append(ib)
    db = Gtk.Button(); db.set_icon_name("user-trash-symbolic"); db.add_css_class("flat")
    db.connect("clicked", lambda _: (delete_icon(window._selected_start_icon) if hasattr(window, '_selected_start_icon') and window._selected_start_icon else None, load())); br.append(db)
    br.append(Gtk.Box(hexpand=True))
    ab = Gtk.Button(label="Apply Icon"); ab.add_css_class("suggested-action")
    ab.connect("clicked", lambda _: set_icon(window._selected_start_icon) if hasattr(window, '_selected_start_icon') and window._selected_start_icon else None); br.append(ab); c.append(br)
    
    # Taskbar Section
    th = Gtk.Label(label="TASKBAR STYLING"); th.add_css_class("heading"); th.set_xalign(0); th.set_margin_top(24); th.set_margin_bottom(12); c.append(th)
    ts = get_taskbar_settings(); window._taskbar_settings = ts.copy()
    for lbl, k, mn, mx, df in [("Corner Radius", "border_radius", 0, 50, 45), ("Font Size", "font_size", 12, 24, 16), ("Padding", "padding", 5, 30, 15), ("Gap", "gap", 0, 24, 12)]:
        r = create_setting_row(lbl, f"{mn}-{mx}"); sp = Gtk.SpinButton.new_with_range(mn, mx, 1); sp.set_value(ts.get(k, df))
        sp.connect('value-changed', lambda s, k=k: window._taskbar_settings.update({k: int(s.get_value())})); r.append(sp); c.append(r)
    tbr = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8); tbr.set_margin_top(16)
    rb = Gtk.Button(label="Reset"); rb.connect("clicked", lambda _: window._taskbar_settings.update({'border_radius': 45, 'font_size': 16, 'padding': 15, 'gap': 12})); tbr.append(rb)
    tbr.append(Gtk.Box(hexpand=True))
    tb = Gtk.Button(label="Apply"); tb.add_css_class("suggested-action"); tb.connect("clicked", lambda _: update_taskbar_css(window._taskbar_settings)); tbr.append(tb); c.append(tbr)
    inf = Gtk.Label(); inf.set_markup("💡 <span size='small'>Icons: ~/.config/hypr-control-center/assets/start-icons/</span>"); inf.add_css_class("dim-label"); inf.set_xalign(0); inf.set_margin_top(16); c.append(inf)
    return c
