"""
Updates Page - System Package Updates Management
Shows pacman and AUR updates with version details
Supports individual and bulk updates
"""

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
from gi.repository import Gtk, Adw, GLib, Gdk, Pango
import subprocess
import os
import threading
from typing import List, Dict, Tuple, Tuple

# ════════════════════════════════════════════════════════════════════════════
# NERD FONT ICONS
# ════════════════════════════════════════════════════════════════════════════
ICONS = {
    'updates': '󰚰',
    'pacman': '󰮯',
    'aur': '󱓞',
    'package': '󰏗',
    'update': '󰁪',
    'update_all': '󰚰',
    'check': '󰑐',
    'updated': '󰄬',
    'arrow': '󰁕',
    'terminal': '󰆍',
    'info': '󰋽',
}

# ════════════════════════════════════════════════════════════════════════════
# CUSTOM CSS
# ════════════════════════════════════════════════════════════════════════════
UPDATES_PAGE_CSS = """
.updates-section {
    background: alpha(@card_bg_color, 0.6);
    border-radius: 12px;
    border: 1px solid alpha(@borders, 0.3);
    margin-bottom: 12px;
}

.updates-section:hover {
    border-color: alpha(@accent_color, 0.4);
}

.updates-section-header {
    padding: 16px 20px;
    border-radius: 12px;
    transition: background 200ms ease;
}

.updates-section-header:hover {
    background: alpha(@card_bg_color, 0.8);
}

.updates-section-header.expanded {
    border-bottom: 1px solid alpha(@borders, 0.2);
    border-radius: 12px 12px 0 0;
}

.updates-section-content {
    padding: 16px 20px;
    background: alpha(@card_bg_color, 0.3);
    border-radius: 0 0 12px 12px;
}

.section-icon { font-size: 20px; min-width: 32px; color: @accent_color; }
.section-title-text { font-size: 15px; font-weight: 600; }
.section-subtitle { font-size: 12px; color: alpha(@theme_fg_color, 0.6); }
.expand-arrow { font-size: 14px; color: alpha(@theme_fg_color, 0.5); }
.expand-arrow.expanded { color: @accent_color; }

.updates-summary {
    padding: 20px;
    border-radius: 12px;
    background: linear-gradient(135deg, alpha(@accent_color, 0.15), alpha(@accent_color, 0.05));
    border: 1px solid alpha(@accent_color, 0.25);
    margin-bottom: 16px;
}

.updates-count { font-size: 42px; font-weight: 700; color: @accent_color; }
.updates-label { font-size: 14px; color: alpha(@theme_fg_color, 0.7); }
.updates-breakdown { font-size: 13px; color: alpha(@theme_fg_color, 0.6); margin-top: 8px; }

.package-card {
    padding: 12px 16px;
    border-radius: 8px;
    margin-bottom: 6px;
    background: alpha(@card_bg_color, 0.5);
    border: 1px solid alpha(@borders, 0.15);
}

.package-card:hover {
    background: alpha(@card_bg_color, 0.7);
    border-color: alpha(@accent_color, 0.3);
}

.package-icon { font-size: 18px; min-width: 28px; color: @accent_color; }
.package-icon.aur { color: #c678dd; }
.package-name { font-size: 14px; font-weight: 600; }
.package-versions { font-size: 12px; margin-top: 4px; }
.version-current { color: alpha(@theme_fg_color, 0.5); font-family: monospace; }
.version-arrow { color: @accent_color; margin: 0 6px; }
.version-new { color: @success_color; font-family: monospace; font-weight: 500; }

.status-box { padding: 16px; border-radius: 8px; text-align: center; }
.status-box.loading { background: alpha(@card_bg_color, 0.4); }
.status-box.uptodate { background: alpha(@success_color, 0.1); border: 1px solid alpha(@success_color, 0.3); }
.status-icon { font-size: 32px; margin-bottom: 8px; }
.status-text { font-size: 14px; color: alpha(@theme_fg_color, 0.7); }

.quick-action-card {
    padding: 14px 16px;
    border-radius: 8px;
    margin-bottom: 8px;
    background: alpha(@card_bg_color, 0.5);
    border: 1px solid alpha(@borders, 0.15);
}
.quick-action-card:hover { background: alpha(@card_bg_color, 0.7); }
.action-icon { font-size: 20px; min-width: 32px; color: @accent_color; }
.action-title { font-size: 14px; font-weight: 500; }
.action-description { font-size: 12px; color: alpha(@theme_fg_color, 0.5); }

.updates-actions { padding: 12px 0 4px 0; border-top: 1px solid alpha(@borders, 0.15); margin-top: 12px; }
"""

# ════════════════════════════════════════════════════════════════════════════
# UPDATE FUNCTIONS
# ════════════════════════════════════════════════════════════════════════════

def run_command(cmd, timeout=30):
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
        return result.stdout.strip(), result.returncode == 0
    except Exception as e:
        return str(e), False


def get_updates_from_script() -> Tuple[List[Dict], List[Dict]]:
    """Try to get updates from the pacman-updates.sh script (same as Waybar uses)"""
    script_path = os.path.join(os.path.expanduser("~"), ".config", "hypr-control-center", "scripts", "pacman-updates.sh")
    
    if not os.path.exists(script_path):
        return [], []
    
    try:
        # Use --list flag to get raw update list
        result = subprocess.run(
            ['bash', script_path, '--list'],
            capture_output=True,
            text=True,
            timeout=120
        )
        
        # Also get the cache file directly
        cache_file = os.path.join(
            os.environ.get('XDG_CACHE_HOME', os.path.join(os.path.expanduser("~"), ".cache")),
            "pacman-updates", "updates.cache"
        )
        
        pacman_updates = []
        aur_updates = []
        
        if os.path.exists(cache_file):
            with open(cache_file, 'r') as f:
                content = f.read()
            
            in_pacman = False
            in_aur = False
            
            for line in content.split('\n'):
                line = line.strip()
                
                if line == "PACMAN:":
                    in_pacman = True
                    in_aur = False
                    continue
                elif line == "AUR:":
                    in_pacman = False
                    in_aur = True
                    continue
                
                if not line:
                    continue
                
                parts = line.split()
                if len(parts) >= 4:
                    pkg = {
                        'name': parts[0],
                        'current': parts[1],
                        'new': parts[3],
                        'source': 'pacman' if in_pacman else 'aur'
                    }
                    if in_pacman:
                        pacman_updates.append(pkg)
                    elif in_aur:
                        aur_updates.append(pkg)
        
        return pacman_updates, aur_updates
        
    except Exception as e:
        print(f"[Updates] Script error: {e}")
        return [], []


def get_pacman_updates() -> List[Dict]:
    """Get pacman updates - note: checkupdates returns exit code 2 when no updates"""
    updates = []
    
    try:
        result = subprocess.run(
            ['checkupdates'],
            capture_output=True,
            text=True,
            timeout=60
        )
        output = result.stdout.strip()
        
        # Parse output regardless of return code
        if output:
            for line in output.split('\n'):
                line = line.strip()
                if line:
                    # Format: package old_ver -> new_ver
                    parts = line.split()
                    if len(parts) >= 4:
                        updates.append({
                            'name': parts[0],
                            'current': parts[1],
                            'new': parts[3],
                            'source': 'pacman'
                        })
    except (FileNotFoundError, subprocess.TimeoutExpired) as e:
        print(f"[Updates] checkupdates error: {e}")
    
    return updates


def get_aur_updates() -> List[Dict]:
    """Get AUR updates - note: yay/paru return exit code 1 when no updates, so don't check returncode"""
    updates = []
    
    # Try yay first
    try:
        result = subprocess.run(
            ['yay', '-Qua'],
            capture_output=True,
            text=True,
            timeout=60
        )
        output = result.stdout.strip()
    except (FileNotFoundError, subprocess.TimeoutExpired):
        # Try paru if yay not found
        try:
            result = subprocess.run(
                ['paru', '-Qua'],
                capture_output=True,
                text=True,
                timeout=60
            )
            output = result.stdout.strip()
        except (FileNotFoundError, subprocess.TimeoutExpired):
            return updates
    
    # Parse output regardless of return code
    if output:
        for line in output.split('\n'):
            line = line.strip()
            if line:
                # Format: package old_ver -> new_ver
                parts = line.split()
                if len(parts) >= 4:
                    updates.append({
                        'name': parts[0],
                        'current': parts[1],
                        'new': parts[3],
                        'source': 'aur'
                    })
                elif len(parts) >= 2:
                    # Alternative format: package new_ver
                    updates.append({
                        'name': parts[0],
                        'current': '?',
                        'new': parts[1] if len(parts) > 1 else '?',
                        'source': 'aur'
                    })
    
    return updates


def update_single_package(name: str, source: str = 'pacman'):
    terminal = os.environ.get('TERMINAL', 'kitty')
    if source == 'aur':
        helper = 'yay' if subprocess.run("which yay", shell=True, capture_output=True).returncode == 0 else 'paru'
        cmd = f'{terminal} -e bash -c "{helper} -S {name}; echo; read -p \\"Press Enter...\\""'
    else:
        cmd = f'{terminal} -e bash -c "sudo pacman -S {name}; echo; read -p \\"Press Enter...\\""'
    subprocess.Popen(cmd, shell=True)


def update_all_packages():
    terminal = os.environ.get('TERMINAL', 'kitty')
    helper = 'yay' if subprocess.run("which yay", shell=True, capture_output=True).returncode == 0 else 'paru' if subprocess.run("which paru", shell=True, capture_output=True).returncode == 0 else 'sudo pacman'
    cmd = f'{terminal} -e bash -c "{helper} -Syu; echo; read -p \\"Press Enter to close...\\""'
    subprocess.Popen(cmd, shell=True)


# ════════════════════════════════════════════════════════════════════════════
# EXPANDABLE SECTION
# ════════════════════════════════════════════════════════════════════════════

class UpdatesExpandableSection(Gtk.Box):
    def __init__(self, icon, title, subtitle="", expanded=False):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.add_css_class('updates-section')
        self._expanded = expanded
        
        self.header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        self.header.add_css_class('updates-section-header')
        if expanded: self.header.add_css_class('expanded')
        
        click = Gtk.GestureClick.new()
        click.connect('pressed', self._on_click)
        self.header.add_controller(click)
        
        icon_lbl = Gtk.Label(label=icon)
        icon_lbl.add_css_class('section-icon')
        self.header.append(icon_lbl)
        
        title_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        title_box.set_hexpand(True)
        
        title_lbl = Gtk.Label(label=title)
        title_lbl.add_css_class('section-title-text')
        title_lbl.set_halign(Gtk.Align.START)
        title_box.append(title_lbl)
        
        self._subtitle = Gtk.Label(label=subtitle or " ")
        self._subtitle.add_css_class('section-subtitle')
        self._subtitle.set_halign(Gtk.Align.START)
        title_box.append(self._subtitle)
        self.header.append(title_box)
        
        self.arrow = Gtk.Label(label="󰅀" if expanded else "󰅂")
        self.arrow.add_css_class('expand-arrow')
        if expanded: self.arrow.add_css_class('expanded')
        self.header.append(self.arrow)
        self.append(self.header)
        
        self.content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        self.content.add_css_class('updates-section-content')
        
        self.revealer = Gtk.Revealer()
        self.revealer.set_transition_type(Gtk.RevealerTransitionType.SLIDE_DOWN)
        self.revealer.set_transition_duration(200)
        self.revealer.set_reveal_child(expanded)
        self.revealer.set_child(self.content)
        self.append(self.revealer)
    
    def _on_click(self, g, n, x, y):
        self._expanded = not self._expanded
        self.revealer.set_reveal_child(self._expanded)
        self.header.add_css_class('expanded') if self._expanded else self.header.remove_css_class('expanded')
        self.arrow.add_css_class('expanded') if self._expanded else self.arrow.remove_css_class('expanded')
        self.arrow.set_text("󰅀" if self._expanded else "󰅂")
    
    def set_subtitle(self, text): self._subtitle.set_text(text)
    def add_content(self, w): self.content.append(w)
    def clear_content(self):
        while self.content.get_first_child(): self.content.remove(self.content.get_first_child())


# ════════════════════════════════════════════════════════════════════════════
# MAIN PAGE
# ════════════════════════════════════════════════════════════════════════════

def build_updates_page(window) -> Gtk.Box:
    provider = Gtk.CssProvider()
    provider.load_from_data(UPDATES_PAGE_CSS.encode())
    Gtk.StyleContext.add_provider_for_display(Gdk.Display.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
    
    page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
    page.set_margin_start(32); page.set_margin_end(32); page.set_margin_top(24); page.set_margin_bottom(24)
    
    header = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
    header.set_margin_bottom(24)
    title = Gtk.Label(label=f"{ICONS['updates']} System Updates")
    title.add_css_class('page-title'); title.set_halign(Gtk.Align.START)
    header.append(title)
    subtitle = Gtk.Label(label="Check and install pacman and AUR package updates")
    subtitle.add_css_class('page-subtitle'); subtitle.set_halign(Gtk.Align.START)
    header.append(subtitle)
    page.append(header)
    
    window.updates_widgets = {}
    window.updates_data = {'pacman': [], 'aur': [], 'selected': set()}
    
    # Summary Section
    summary = UpdatesExpandableSection(ICONS['info'], "Update Summary", "Checking...", True)
    window.updates_widgets['summary_section'] = summary
    _build_summary(window, summary)
    page.append(summary)
    
    # Pacman Section
    pacman = UpdatesExpandableSection(ICONS['pacman'], "Official Repositories", "Loading...", True)
    window.updates_widgets['pacman_section'] = pacman
    page.append(pacman)
    
    # AUR Section
    aur = UpdatesExpandableSection(ICONS['aur'], "AUR Packages", "Loading...", False)
    window.updates_widgets['aur_section'] = aur
    page.append(aur)
    
    # Actions Section
    actions = UpdatesExpandableSection(ICONS['terminal'], "Quick Actions", "Update options", False)
    _build_actions(window, actions)
    page.append(actions)
    
    GLib.timeout_add(100, lambda: _check_async(window, refresh_cache=True) or False)
    return page


def _build_summary(window, section):
    loading = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
    loading.add_css_class('status-box'); loading.add_css_class('loading')
    loading.set_halign(Gtk.Align.CENTER)
    
    spinner = Gtk.Spinner(); spinner.set_size_request(32, 32); spinner.start()
    loading.append(spinner)
    lbl = Gtk.Label(label="Checking for updates...")
    lbl.add_css_class('status-text')
    loading.append(lbl)
    window.updates_widgets['loading'] = loading
    section.add_content(loading)
    
    summary_card = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=24)
    summary_card.add_css_class('updates-summary')
    summary_card.set_visible(False)
    
    count_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
    count_box.set_halign(Gtk.Align.CENTER)
    
    count_lbl = Gtk.Label(label="0")
    count_lbl.add_css_class('updates-count')
    window.updates_widgets['count'] = count_lbl
    count_box.append(count_lbl)
    
    upd_lbl = Gtk.Label(label="updates available")
    upd_lbl.add_css_class('updates-label')
    count_box.append(upd_lbl)
    
    breakdown = Gtk.Label(label="")
    breakdown.add_css_class('updates-breakdown')
    window.updates_widgets['breakdown'] = breakdown
    count_box.append(breakdown)
    
    summary_card.append(count_box)
    window.updates_widgets['summary_card'] = summary_card
    section.add_content(summary_card)


def _check_async(window, refresh_cache=True):
    def check():
        # Refresh the script cache first (if requested)
        if refresh_cache:
            script_path = os.path.join(os.path.expanduser("~"), ".config", "hypr-control-center", "scripts", "pacman-updates.sh")
            if os.path.exists(script_path):
                try:
                    subprocess.run(['bash', script_path, '--refresh'], capture_output=True, timeout=120)
                except subprocess.TimeoutExpired:
                    print("[Updates] Cache refresh timeout")
        
        # First try to use the pacman-updates.sh script (same as Waybar)
        pacman, aur = get_updates_from_script()
        
        # If script didn't return anything, try direct commands
        if not pacman and not aur:
            pacman = get_pacman_updates()
            aur = get_aur_updates()
        
        GLib.idle_add(lambda: _on_loaded(window, pacman, aur))
    
    thread = threading.Thread(target=check, daemon=True)
    thread.start()


def _on_loaded(window, pacman: List[Dict], aur: List[Dict]):
    window.updates_data['pacman'] = pacman
    window.updates_data['aur'] = aur
    total = len(pacman) + len(aur)
    
    window.updates_widgets['loading'].set_visible(False)
    window.updates_widgets['summary_card'].set_visible(True)
    window.updates_widgets['count'].set_text(str(total))
    window.updates_widgets['breakdown'].set_text(f"{ICONS['pacman']} {len(pacman)} official  •  {ICONS['aur']} {len(aur)} AUR")
    
    summary = window.updates_widgets['summary_section']
    summary.set_subtitle("System is up to date!" if total == 0 else f"{total} update{'s' if total != 1 else ''} available")
    
    _build_pkg_list(window, 'pacman', pacman)
    _build_pkg_list(window, 'aur', aur)


def _build_pkg_list(window, source: str, packages: List[Dict]):
    section = window.updates_widgets[f'{source}_section']
    section.clear_content()
    
    if not packages:
        empty = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        empty.add_css_class('status-box'); empty.add_css_class('uptodate')
        empty.set_halign(Gtk.Align.CENTER)
        icon = Gtk.Label(label=ICONS['updated']); icon.add_css_class('status-icon'); icon.set_opacity(0.6)
        empty.append(icon)
        lbl = Gtk.Label(label="All packages are up to date"); lbl.add_css_class('status-text')
        empty.append(lbl)
        section.add_content(empty)
        section.set_subtitle("No updates")
        return
    
    section.set_subtitle(f"{len(packages)} update{'s' if len(packages) != 1 else ''}")
    
    for pkg in packages:
        card = _create_pkg_card(window, pkg)
        section.add_content(card)
    
    btn_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
    btn_box.add_css_class('updates-actions')
    
    update_btn = Gtk.Button(label=f"{ICONS['update_all']} Update All {source.upper()}")
    update_btn.add_css_class('suggested-action')
    
    def on_update(b, pkgs=packages):
        terminal = os.environ.get('TERMINAL', 'kitty')
        names = ' '.join([p['name'] for p in pkgs])
        if source == 'aur':
            helper = 'yay' if subprocess.run("which yay", shell=True, capture_output=True).returncode == 0 else 'paru'
            cmd = f'{terminal} -e bash -c "{helper} -S {names}; read -p \\"Press Enter...\\""'
        else:
            cmd = f'{terminal} -e bash -c "sudo pacman -S {names}; read -p \\"Press Enter...\\""'
        subprocess.Popen(cmd, shell=True)
        _toast(window, f"Updating {len(pkgs)} packages...")
    
    update_btn.connect('clicked', on_update)
    btn_box.append(update_btn)
    section.add_content(btn_box)


def _create_pkg_card(window, pkg: Dict) -> Gtk.Box:
    card = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
    card.add_css_class('package-card')
    
    checkbox = Gtk.CheckButton()
    checkbox.set_valign(Gtk.Align.CENTER)
    card.append(checkbox)
    
    icon = Gtk.Label(label=ICONS['aur'] if pkg['source'] == 'aur' else ICONS['pacman'])
    icon.add_css_class('package-icon')
    if pkg['source'] == 'aur': icon.add_css_class('aur')
    card.append(icon)
    
    info = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
    info.set_hexpand(True)
    
    name = Gtk.Label(label=pkg['name'])
    name.add_css_class('package-name')
    name.set_halign(Gtk.Align.START)
    name.set_ellipsize(Pango.EllipsizeMode.END)
    info.append(name)
    
    ver_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
    ver_box.add_css_class('package-versions')
    
    cur = Gtk.Label(label=pkg['current']); cur.add_css_class('version-current')
    ver_box.append(cur)
    
    arrow = Gtk.Label(label=f" {ICONS['arrow']} "); arrow.add_css_class('version-arrow')
    ver_box.append(arrow)
    
    new = Gtk.Label(label=pkg['new']); new.add_css_class('version-new')
    ver_box.append(new)
    
    info.append(ver_box)
    card.append(info)
    
    upd_btn = Gtk.Button(label=ICONS['update'])
    upd_btn.add_css_class('flat')
    upd_btn.set_valign(Gtk.Align.CENTER)
    upd_btn.set_tooltip_text(f"Update {pkg['name']}")
    
    def on_upd(b, p=pkg):
        update_single_package(p['name'], p['source'])
        _toast(window, f"Updating {p['name']}...")
    
    upd_btn.connect('clicked', on_upd)
    card.append(upd_btn)
    
    return card


def _build_actions(window, section):
    box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
    
    # Update All
    all_card = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
    all_card.add_css_class('quick-action-card')
    
    all_icon = Gtk.Label(label=ICONS['update_all']); all_icon.add_css_class('action-icon')
    all_card.append(all_icon)
    
    all_info = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
    all_info.set_hexpand(True)
    all_title = Gtk.Label(label="Update All Packages"); all_title.add_css_class('action-title'); all_title.set_halign(Gtk.Align.START)
    all_info.append(all_title)
    all_desc = Gtk.Label(label="Update all pacman and AUR packages"); all_desc.add_css_class('action-description'); all_desc.set_halign(Gtk.Align.START)
    all_info.append(all_desc)
    all_card.append(all_info)
    
    all_btn = Gtk.Button(label="Update All")
    all_btn.add_css_class('suggested-action')
    all_btn.set_valign(Gtk.Align.CENTER)
    all_btn.connect('clicked', lambda b: (update_all_packages(), _toast(window, "Updating all packages...")))
    all_card.append(all_btn)
    box.append(all_card)
    
    # Refresh
    ref_card = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
    ref_card.add_css_class('quick-action-card')
    
    ref_icon = Gtk.Label(label=ICONS['check']); ref_icon.add_css_class('action-icon')
    ref_card.append(ref_icon)
    
    ref_info = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
    ref_info.set_hexpand(True)
    ref_title = Gtk.Label(label="Refresh Update List"); ref_title.add_css_class('action-title'); ref_title.set_halign(Gtk.Align.START)
    ref_info.append(ref_title)
    ref_desc = Gtk.Label(label="Check for new updates"); ref_desc.add_css_class('action-description'); ref_desc.set_halign(Gtk.Align.START)
    ref_info.append(ref_desc)
    ref_card.append(ref_info)
    
    ref_btn = Gtk.Button(label="Refresh")
    ref_btn.set_valign(Gtk.Align.CENTER)
    
    def on_ref(b):
        window.updates_widgets['loading'].set_visible(True)
        window.updates_widgets['summary_card'].set_visible(False)
        window.updates_widgets['summary_section'].set_subtitle("Checking...")
        _check_async(window, refresh_cache=True)
        _toast(window, "Checking for updates...")
    
    ref_btn.connect('clicked', on_ref)
    ref_card.append(ref_btn)
    box.append(ref_card)
    
    section.add_content(box)


def _toast(window, msg):
    if hasattr(window, 'toast_overlay'):
        toast = Adw.Toast(title=msg); toast.set_timeout(3)
        window.toast_overlay.add_toast(toast)