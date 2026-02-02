"""
Time & Language Page - System Time and Locale Configuration
Includes: Timezone, Date/Time formats, Language settings
"""

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
from gi.repository import Gtk, Adw, GLib, Gdk
import subprocess
import os
import json
from datetime import datetime
import re

# ════════════════════════════════════════════════════════════════════════════
# NERD FONT ICONS
# ════════════════════════════════════════════════════════════════════════════
ICONS = {
    'time': '󰥔',
    'date': '󰃭',
    'timezone': '󰗠',
    'language': '󰗊',
    'locale': '󱀫',
    'calendar': '󰃭',
    'clock': '󰅐',
    'globe': '󰖟',
    'settings': '󰒓',
    'refresh': '󰑐',
    'sync': '󰓦',
    'format': '󰘝',
}

# ════════════════════════════════════════════════════════════════════════════
# COMMON TIMEZONES
# ════════════════════════════════════════════════════════════════════════════
COMMON_TIMEZONES = [
    ('Asia/Manila', 'Manila, Philippines (PHT)'),
    ('Asia/Singapore', 'Singapore (SGT)'),
    ('Asia/Tokyo', 'Tokyo, Japan (JST)'),
    ('Asia/Seoul', 'Seoul, Korea (KST)'),
    ('Asia/Shanghai', 'Shanghai, China (CST)'),
    ('Asia/Hong_Kong', 'Hong Kong (HKT)'),
    ('Asia/Bangkok', 'Bangkok, Thailand (ICT)'),
    ('Asia/Jakarta', 'Jakarta, Indonesia (WIB)'),
    ('Asia/Kolkata', 'Kolkata, India (IST)'),
    ('Asia/Dubai', 'Dubai, UAE (GST)'),
    ('Europe/London', 'London, UK (GMT/BST)'),
    ('Europe/Paris', 'Paris, France (CET)'),
    ('Europe/Berlin', 'Berlin, Germany (CET)'),
    ('Europe/Moscow', 'Moscow, Russia (MSK)'),
    ('America/New_York', 'New York, USA (EST/EDT)'),
    ('America/Chicago', 'Chicago, USA (CST/CDT)'),
    ('America/Denver', 'Denver, USA (MST/MDT)'),
    ('America/Los_Angeles', 'Los Angeles, USA (PST/PDT)'),
    ('America/Sao_Paulo', 'São Paulo, Brazil (BRT)'),
    ('Australia/Sydney', 'Sydney, Australia (AEST)'),
    ('Pacific/Auckland', 'Auckland, New Zealand (NZST)'),
]

# ════════════════════════════════════════════════════════════════════════════
# TIME FORMATS
# ════════════════════════════════════════════════════════════════════════════
TIME_FORMATS = [
    ('%I:%M %p', '12-hour (3:45 PM)'),
    ('%H:%M', '24-hour (15:45)'),
    ('%I:%M:%S %p', '12-hour with seconds (3:45:30 PM)'),
    ('%H:%M:%S', '24-hour with seconds (15:45:30)'),
]

DATE_FORMATS = [
    ('%B %d, %Y', 'January 15, 2025'),
    ('%d %B %Y', '15 January 2025'),
    ('%Y-%m-%d', '2025-01-15'),
    ('%m/%d/%Y', '01/15/2025'),
    ('%d/%m/%Y', '15/01/2025'),
    ('%a, %b %d', 'Wed, Jan 15'),
    ('%A, %B %d, %Y', 'Wednesday, January 15, 2025'),
]

# ════════════════════════════════════════════════════════════════════════════
# COMMON LOCALES
# ════════════════════════════════════════════════════════════════════════════
COMMON_LOCALES = [
    ('en_US.UTF-8', 'English (United States)'),
    ('en_GB.UTF-8', 'English (United Kingdom)'),
    ('en_PH.UTF-8', 'English (Philippines)'),
    ('fil_PH.UTF-8', 'Filipino (Philippines)'),
    ('de_DE.UTF-8', 'German (Germany)'),
    ('fr_FR.UTF-8', 'French (France)'),
    ('es_ES.UTF-8', 'Spanish (Spain)'),
    ('pt_BR.UTF-8', 'Portuguese (Brazil)'),
    ('it_IT.UTF-8', 'Italian (Italy)'),
    ('ru_RU.UTF-8', 'Russian (Russia)'),
    ('ja_JP.UTF-8', 'Japanese (Japan)'),
    ('ko_KR.UTF-8', 'Korean (Korea)'),
    ('zh_CN.UTF-8', 'Chinese (Simplified)'),
    ('zh_TW.UTF-8', 'Chinese (Traditional)'),
]

# ════════════════════════════════════════════════════════════════════════════
# CUSTOM CSS
# ════════════════════════════════════════════════════════════════════════════
TIME_LANG_CSS = """
/* Time & Language Page Styles */
.timelang-section {
    background: alpha(@card_bg_color, 0.6);
    border-radius: 12px;
    border: 1px solid alpha(@borders, 0.3);
    margin-bottom: 12px;
    padding: 0;
}

.timelang-section-header {
    padding: 16px 20px;
    border-radius: 12px;
    transition: background 200ms ease;
}

.timelang-section-header:hover {
    background: alpha(@card_bg_color, 0.8);
}

.timelang-section-header.expanded {
    border-bottom: 1px solid alpha(@borders, 0.2);
    border-radius: 12px 12px 0 0;
}

.timelang-section-content {
    padding: 16px 20px;
    background: alpha(@card_bg_color, 0.3);
    border-radius: 0 0 12px 12px;
}

.time-display {
    padding: 24px;
    border-radius: 12px;
    background: linear-gradient(135deg, alpha(@accent_color, 0.15), alpha(@accent_color, 0.05));
    border: 1px solid alpha(@accent_color, 0.2);
    margin-bottom: 16px;
}

.time-display-clock {
    font-size: 48px;
    font-weight: 300;
    font-family: monospace;
    color: @theme_fg_color;
    letter-spacing: 2px;
}

.time-display-date {
    font-size: 16px;
    color: alpha(@theme_fg_color, 0.7);
    margin-top: 8px;
}

.time-display-timezone {
    font-size: 13px;
    color: @accent_color;
    margin-top: 4px;
}

.timelang-setting-row {
    padding: 12px 16px;
    border-radius: 8px;
    margin-bottom: 8px;
    background: alpha(@card_bg_color, 0.5);
    border: 1px solid alpha(@borders, 0.15);
}

.timelang-setting-row:hover {
    background: alpha(@card_bg_color, 0.7);
    border-color: alpha(@accent_color, 0.3);
}

.timelang-setting-label {
    font-size: 14px;
    font-weight: 500;
}

.timelang-setting-description {
    font-size: 12px;
    color: alpha(@theme_fg_color, 0.5);
}

.timelang-setting-icon {
    font-size: 18px;
    min-width: 28px;
    color: @accent_color;
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

.ntp-status {
    padding: 8px 12px;
    border-radius: 6px;
    font-size: 12px;
    font-weight: 500;
}

.ntp-status.synced {
    background: alpha(@success_color, 0.15);
    color: @success_color;
}

.ntp-status.not-synced {
    background: alpha(@warning_color, 0.15);
    color: @warning_color;
}

.locale-info {
    font-size: 12px;
    color: alpha(@theme_fg_color, 0.6);
    padding: 8px 12px;
    background: alpha(@card_bg_color, 0.4);
    border-radius: 6px;
    margin-top: 8px;
}
"""


# ════════════════════════════════════════════════════════════════════════════
# SYSTEM FUNCTIONS
# ════════════════════════════════════════════════════════════════════════════

def run_command(cmd, timeout=5):
    """Run a shell command"""
    try:
        result = subprocess.run(
            cmd, shell=True, capture_output=True, 
            text=True, timeout=timeout
        )
        return result.stdout.strip(), result.returncode == 0
    except Exception as e:
        return str(e), False


def get_current_timezone():
    """Get current system timezone"""
    output, success = run_command("timedatectl show --property=Timezone --value")
    if success and output:
        return output
    
    # Fallback
    if os.path.exists('/etc/timezone'):
        with open('/etc/timezone', 'r') as f:
            return f.read().strip()
    
    return "UTC"


def get_ntp_status():
    """Get NTP synchronization status"""
    output, success = run_command("timedatectl show --property=NTPSynchronized --value")
    return output.lower() == 'yes' if success else False


def get_ntp_enabled():
    """Check if NTP is enabled"""
    output, success = run_command("timedatectl show --property=NTP --value")
    return output.lower() == 'yes' if success else False


def set_timezone(timezone):
    """Set system timezone"""
    output, success = run_command(f"timedatectl set-timezone {timezone}")
    return success


def set_ntp(enabled):
    """Enable/disable NTP"""
    value = "true" if enabled else "false"
    output, success = run_command(f"timedatectl set-ntp {value}")
    return success


def get_system_locale():
    """Get current system locale"""
    output, success = run_command("localectl status")
    if success:
        for line in output.split('\n'):
            if 'LANG=' in line:
                match = re.search(r'LANG=(\S+)', line)
                if match:
                    return match.group(1)
    return "en_US.UTF-8"


def get_all_timezones():
    """Get all available timezones"""
    output, success = run_command("timedatectl list-timezones")
    if success:
        return output.split('\n')
    return []


# ════════════════════════════════════════════════════════════════════════════
# EXPANDABLE SECTION COMPONENT
# ════════════════════════════════════════════════════════════════════════════

class TimeLangExpandableSection(Gtk.Box):
    """Expandable section for time & language page"""
    
    def __init__(self, icon, title, subtitle="", expanded=False):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.add_css_class('timelang-section')
        
        self._expanded = expanded
        self._subtitle_label = None
        
        # Header
        self.header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        self.header.add_css_class('timelang-section-header')
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
        self.content.add_css_class('timelang-section-content')
        
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

def build_time_language_page(window):
    """Build the Time & Language page"""
    
    # Apply CSS
    _apply_timelang_css()
    
    # Main container
    page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
    page.set_margin_start(32)
    page.set_margin_end(32)
    page.set_margin_top(24)
    page.set_margin_bottom(24)
    
    # Header
    header = _create_page_header(
        f"{ICONS['time']} Time & Language",
        "Configure timezone, date/time formats, and language settings"
    )
    page.append(header)
    
    # Store widgets
    window.timelang_widgets = {}
    
    # Current timezone
    current_tz = get_current_timezone()
    
    # Date & Time Section
    datetime_section = TimeLangExpandableSection(
        ICONS['clock'],
        "Date & Time",
        f"Timezone: {current_tz}",
        expanded=True
    )
    window.timelang_widgets['datetime_section'] = datetime_section
    _build_datetime_content(window, datetime_section)
    page.append(datetime_section)
    
    # Time Format Section
    format_section = TimeLangExpandableSection(
        ICONS['format'],
        "Time & Date Format",
        "Customize how time and date are displayed"
    )
    window.timelang_widgets['format_section'] = format_section
    _build_format_content(window, format_section)
    page.append(format_section)
    
    # Language & Region Section
    locale = get_system_locale()
    locale_name = next((name for code, name in COMMON_LOCALES if code == locale), locale)
    
    language_section = TimeLangExpandableSection(
        ICONS['language'],
        "Language & Region",
        f"System locale: {locale_name}"
    )
    window.timelang_widgets['language_section'] = language_section
    _build_language_content(window, language_section)
    page.append(language_section)
    
    # Start clock update
    _start_clock_update(window)
    
    return page


def _apply_timelang_css():
    """Apply custom CSS"""
    provider = Gtk.CssProvider()
    provider.load_from_data(TIME_LANG_CSS.encode())
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


def _create_setting_row(label, description=None, widget=None, icon=None):
    """Create a setting row"""
    row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
    row.add_css_class('timelang-setting-row')
    
    if icon:
        icon_label = Gtk.Label(label=icon)
        icon_label.add_css_class('timelang-setting-icon')
        row.append(icon_label)
    
    label_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
    label_box.set_hexpand(True)
    
    main_label = Gtk.Label(label=label)
    main_label.set_halign(Gtk.Align.START)
    main_label.add_css_class('timelang-setting-label')
    label_box.append(main_label)
    
    if description:
        desc_label = Gtk.Label(label=description)
        desc_label.set_halign(Gtk.Align.START)
        desc_label.add_css_class('timelang-setting-description')
        label_box.append(desc_label)
    
    row.append(label_box)
    
    if widget:
        row.append(widget)
    
    return row


# ════════════════════════════════════════════════════════════════════════════
# DATE & TIME SECTION
# ════════════════════════════════════════════════════════════════════════════

def _build_datetime_content(window, section):
    """Build date & time content"""
    
    # Live clock display
    clock_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
    clock_box.add_css_class('time-display')
    clock_box.set_halign(Gtk.Align.CENTER)
    
    clock_label = Gtk.Label(label="--:--:--")
    clock_label.add_css_class('time-display-clock')
    window.timelang_widgets['clock_label'] = clock_label
    clock_box.append(clock_label)
    
    date_label = Gtk.Label(label="Loading...")
    date_label.add_css_class('time-display-date')
    window.timelang_widgets['date_label'] = date_label
    clock_box.append(date_label)
    
    tz_label = Gtk.Label(label=get_current_timezone())
    tz_label.add_css_class('time-display-timezone')
    window.timelang_widgets['tz_display_label'] = tz_label
    clock_box.append(tz_label)
    
    section.add_content(clock_box)
    
    # Timezone dropdown
    tz_dropdown = Gtk.DropDown()
    tz_strings = Gtk.StringList()
    tz_list = [tz for tz, _ in COMMON_TIMEZONES]
    
    for tz, name in COMMON_TIMEZONES:
        tz_strings.append(name)
    
    tz_dropdown.set_model(tz_strings)
    tz_dropdown.set_size_request(250, -1)
    
    # Set current selection
    current_tz = get_current_timezone()
    try:
        idx = tz_list.index(current_tz)
        tz_dropdown.set_selected(idx)
    except ValueError:
        pass
    
    def on_tz_changed(dropdown, _):
        idx = dropdown.get_selected()
        new_tz = tz_list[idx]
        if set_timezone(new_tz):
            window.timelang_widgets['tz_display_label'].set_text(new_tz)
            section.set_subtitle(f"Timezone: {new_tz}")
            _show_toast(window, f"Timezone set to {new_tz}")
        else:
            _show_toast(window, "Failed to set timezone (may need root)")
    
    tz_dropdown.connect('notify::selected', on_tz_changed)
    
    tz_row = _create_setting_row(
        "Timezone",
        "Select your timezone",
        tz_dropdown,
        ICONS['timezone']
    )
    section.add_content(tz_row)
    
    # NTP Sync toggle
    ntp_enabled = get_ntp_enabled()
    ntp_synced = get_ntp_status()
    
    ntp_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
    
    ntp_switch = Gtk.Switch()
    ntp_switch.set_valign(Gtk.Align.CENTER)
    ntp_switch.set_active(ntp_enabled)
    
    ntp_status = Gtk.Label(label="Synced" if ntp_synced else "Not synced")
    ntp_status.add_css_class('ntp-status')
    ntp_status.add_css_class('synced' if ntp_synced else 'not-synced')
    window.timelang_widgets['ntp_status'] = ntp_status
    
    ntp_box.append(ntp_status)
    ntp_box.append(ntp_switch)
    
    def on_ntp_changed(switch, _):
        enabled = switch.get_active()
        if set_ntp(enabled):
            _show_toast(window, f"NTP {'enabled' if enabled else 'disabled'}")
            # Update status after a delay
            GLib.timeout_add(1000, lambda: _update_ntp_status(window) or False)
        else:
            _show_toast(window, "Failed to change NTP (may need root)")
            switch.set_active(not enabled)
    
    ntp_switch.connect('notify::active', on_ntp_changed)
    
    ntp_row = _create_setting_row(
        "Automatic Time Sync (NTP)",
        "Synchronize time automatically with network servers",
        ntp_box,
        ICONS['sync']
    )
    section.add_content(ntp_row)


def _update_ntp_status(window):
    """Update NTP status display"""
    ntp_status = window.timelang_widgets.get('ntp_status')
    if ntp_status:
        synced = get_ntp_status()
        ntp_status.set_text("Synced" if synced else "Not synced")
        ntp_status.remove_css_class('synced')
        ntp_status.remove_css_class('not-synced')
        ntp_status.add_css_class('synced' if synced else 'not-synced')
    return False


def _start_clock_update(window):
    """Start updating the clock display"""
    def update_clock():
        clock_label = window.timelang_widgets.get('clock_label')
        date_label = window.timelang_widgets.get('date_label')
        
        if clock_label and date_label:
            now = datetime.now()
            clock_label.set_text(now.strftime("%H:%M:%S"))
            date_label.set_text(now.strftime("%A, %B %d, %Y"))
        
        return True  # Continue updating
    
    # Update immediately
    update_clock()
    # Then update every second
    GLib.timeout_add(1000, update_clock)


# ════════════════════════════════════════════════════════════════════════════
# TIME FORMAT SECTION
# ════════════════════════════════════════════════════════════════════════════

def _build_format_content(window, section):
    """Build time format content"""
    
    # Note about format settings
    note = Gtk.Label(label="These settings affect how time/date appear in your Waybar and widgets")
    note.add_css_class('timelang-setting-description')
    note.set_halign(Gtk.Align.START)
    note.set_margin_bottom(8)
    section.add_content(note)
    
    # Time format dropdown
    time_dropdown = Gtk.DropDown()
    time_strings = Gtk.StringList()
    
    now = datetime.now()
    for fmt, _ in TIME_FORMATS:
        time_strings.append(now.strftime(fmt))
    
    time_dropdown.set_model(time_strings)
    time_dropdown.set_size_request(200, -1)
    
    def on_time_format_changed(dropdown, _):
        idx = dropdown.get_selected()
        fmt, name = TIME_FORMATS[idx]
        window.timelang_widgets['selected_time_format'] = fmt
        _show_toast(window, f"Time format: {name}")
    
    time_dropdown.connect('notify::selected', on_time_format_changed)
    
    time_row = _create_setting_row(
        "Time Format",
        "Choose 12-hour or 24-hour format",
        time_dropdown,
        ICONS['clock']
    )
    section.add_content(time_row)
    
    # Date format dropdown
    date_dropdown = Gtk.DropDown()
    date_strings = Gtk.StringList()
    
    for fmt, example in DATE_FORMATS:
        date_strings.append(example)
    
    date_dropdown.set_model(date_strings)
    date_dropdown.set_size_request(250, -1)
    
    def on_date_format_changed(dropdown, _):
        idx = dropdown.get_selected()
        fmt, example = DATE_FORMATS[idx]
        window.timelang_widgets['selected_date_format'] = fmt
        _show_toast(window, f"Date format: {example}")
    
    date_dropdown.connect('notify::selected', on_date_format_changed)
    
    date_row = _create_setting_row(
        "Date Format",
        "Choose how dates are displayed",
        date_dropdown,
        ICONS['calendar']
    )
    section.add_content(date_row)
    
    # First day of week
    week_dropdown = Gtk.DropDown()
    week_strings = Gtk.StringList()
    week_days = ['Sunday', 'Monday', 'Saturday']
    
    for day in week_days:
        week_strings.append(day)
    
    week_dropdown.set_model(week_strings)
    week_dropdown.set_selected(1)  # Default to Monday
    
    week_row = _create_setting_row(
        "First Day of Week",
        "For calendar displays",
        week_dropdown,
        ICONS['date']
    )
    section.add_content(week_row)


# ════════════════════════════════════════════════════════════════════════════
# LANGUAGE SECTION
# ════════════════════════════════════════════════════════════════════════════

def _build_language_content(window, section):
    """Build language content"""
    
    current_locale = get_system_locale()
    
    # System language dropdown
    lang_dropdown = Gtk.DropDown()
    lang_strings = Gtk.StringList()
    locale_list = [code for code, _ in COMMON_LOCALES]
    
    for code, name in COMMON_LOCALES:
        lang_strings.append(name)
    
    lang_dropdown.set_model(lang_strings)
    lang_dropdown.set_size_request(250, -1)
    
    # Set current selection
    try:
        idx = locale_list.index(current_locale)
        lang_dropdown.set_selected(idx)
    except ValueError:
        pass
    
    def on_lang_changed(dropdown, _):
        idx = dropdown.get_selected()
        new_locale = locale_list[idx]
        locale_name = COMMON_LOCALES[idx][1]
        _show_toast(window, f"Language change requires logout to take effect")
        section.set_subtitle(f"System locale: {locale_name}")
    
    lang_dropdown.connect('notify::selected', on_lang_changed)
    
    lang_row = _create_setting_row(
        "System Language",
        "Display language for applications",
        lang_dropdown,
        ICONS['language']
    )
    section.add_content(lang_row)
    
    # Current locale info
    locale_info = Gtk.Label(label=f"Current: {current_locale}")
    locale_info.add_css_class('locale-info')
    locale_info.set_halign(Gtk.Align.START)
    section.add_content(locale_info)
    
    # Regional format dropdown
    region_dropdown = Gtk.DropDown()
    region_strings = Gtk.StringList()
    
    for code, name in COMMON_LOCALES:
        region_strings.append(name)
    
    region_dropdown.set_model(region_strings)
    region_dropdown.set_size_request(250, -1)
    
    try:
        idx = locale_list.index(current_locale)
        region_dropdown.set_selected(idx)
    except ValueError:
        pass
    
    region_row = _create_setting_row(
        "Regional Format",
        "Number, currency, and measurement formats",
        region_dropdown,
        ICONS['globe']
    )
    section.add_content(region_row)
    
    # Note
    note = Gtk.Label(label="󰋽 Changes to system locale require root access and may need a system restart")
    note.add_css_class('timelang-setting-description')
    note.set_halign(Gtk.Align.START)
    note.set_margin_top(12)
    section.add_content(note)


def _show_toast(window, message):
    """Show toast notification"""
    if hasattr(window, 'toast_overlay'):
        toast = Adw.Toast(title=message)
        toast.set_timeout(3)
        window.toast_overlay.add_toast(toast)
    else:
        print(f"[TimeLang] {message}")