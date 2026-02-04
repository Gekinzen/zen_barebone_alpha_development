#!/usr/bin/env python3
"""
Widgets Page - Control Center Module
Configure desktop widgets: Clock, Weather, System Monitor

Uses start-widgets.sh for proper layer shell support
Widgets stay on BACKGROUND layer (behind all windows, all workspaces)
"""

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
from gi.repository import Gtk, Adw, GLib, Gdk
import json
import subprocess
from pathlib import Path
from datetime import datetime

# Optional pytz
try:
    import pytz
    HAS_PYTZ = True
except ImportError:
    HAS_PYTZ = False


class WidgetsPage(Gtk.Box):
    """Widgets configuration page for Control Center"""
    
    def __init__(self, window=None):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.window = window
        
        # Paths
        self.config_dir = Path.home() / ".config/hypr-control-center/preferences"
        self.config_path = self.config_dir / "widgets.json"
        self.config_dir.mkdir(parents=True, exist_ok=True)
        
        self.widgets_dir = Path.home() / ".config/hypr-control-center/widgets"
        self.scripts_dir = Path.home() / ".config/hypr/scripts"
        self.start_script = self.scripts_dir / "start-widgets.sh"
        
        # Load config
        self.config = self._load_config()
        
        # Timezones
        self.common_timezones = [
            ("Asia/Manila", "Manila (PHT)"),
            ("Asia/Tokyo", "Tokyo (JST)"),
            ("Asia/Singapore", "Singapore (SGT)"),
            ("Asia/Hong_Kong", "Hong Kong (HKT)"),
            ("Asia/Seoul", "Seoul (KST)"),
            ("Asia/Shanghai", "Shanghai (CST)"),
            ("Asia/Kolkata", "India (IST)"),
            ("Asia/Dubai", "Dubai (GST)"),
            ("Europe/London", "London (GMT/BST)"),
            ("Europe/Paris", "Paris (CET)"),
            ("Europe/Berlin", "Berlin (CET)"),
            ("America/New_York", "New York (EST)"),
            ("America/Los_Angeles", "Los Angeles (PST)"),
            ("America/Chicago", "Chicago (CST)"),
            ("Australia/Sydney", "Sydney (AEST)"),
            ("Pacific/Auckland", "Auckland (NZST)"),
            ("UTC", "UTC"),
        ]
        
        self._build_ui()
        
        # Check running status on load
        GLib.timeout_add(500, self._update_running_status)
        # Keep checking every 3 seconds
        GLib.timeout_add_seconds(3, self._update_running_status)
    
    def _load_config(self) -> dict:
        """Load widgets configuration"""
        default_config = {
            "widgets": {
                "clock": {
                    "enabled": True,
                    "x": 100,
                    "y": 100,
                    "timezone": "Asia/Manila",
                    "format_24h": True
                },
                "clock_secondary": {
                    "enabled": False,
                    "x": 100,
                    "y": 250,
                    "timezone": "America/New_York",
                    "format_24h": True
                },
                "weather": {
                    "enabled": True,
                    "x": 100,
                    "y": 400,
                    "location": "auto",
                    "location_name": "",
                    "lat": None,
                    "lon": None
                },
                "system_monitor": {
                    "enabled": True,
                    "x": 1500,
                    "y": 100
                }
            },
            "detected_location": {
                "city": "",
                "lat": None,
                "lon": None
            }
        }
        
        if self.config_path.exists():
            try:
                with open(self.config_path, 'r') as f:
                    saved = json.load(f)
                    for key in default_config:
                        if key not in saved:
                            saved[key] = default_config[key]
                        elif isinstance(default_config[key], dict):
                            for subkey in default_config[key]:
                                if subkey not in saved[key]:
                                    saved[key][subkey] = default_config[key][subkey]
                    return saved
            except Exception as e:
                print(f"[WidgetsPage] Config load error: {e}")
        
        return default_config
    
    def _save_config(self):
        """Save configuration"""
        try:
            with open(self.config_path, 'w') as f:
                json.dump(self.config, f, indent=2)
        except Exception as e:
            print(f"[WidgetsPage] Config save error: {e}")
    
    def _build_ui(self):
        """Build the UI"""
        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroll.set_vexpand(True)
        
        content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=24)
        content.set_margin_start(32)
        content.set_margin_end(32)
        content.set_margin_top(24)
        content.set_margin_bottom(32)
        
        # Header
        header = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        header.set_margin_bottom(24)
        
        title = Gtk.Label(label="Desktop Widgets")
        title.add_css_class("page-title")
        title.set_halign(Gtk.Align.START)
        header.append(title)
        
        subtitle = Gtk.Label(label="Configure clock, weather, and system monitor widgets")
        subtitle.add_css_class("page-subtitle")
        subtitle.set_halign(Gtk.Align.START)
        header.append(subtitle)
        
        content.append(header)
        
        # Location Section
        content.append(self._build_location_section())
        
        # Clock Section
        content.append(self._build_clock_section())
        
        # Secondary Clock Section
        content.append(self._build_secondary_clock_section())
        
        # Weather Section
        content.append(self._build_weather_section())
        
        # System Monitor Section
        content.append(self._build_sysmon_section())
        
        # Action Buttons
        content.append(self._build_action_buttons())
        
        scroll.set_child(content)
        self.append(scroll)
        
        self._apply_css()
    
    def _build_location_section(self) -> Gtk.Widget:
        """Location detection section"""
        group = Adw.PreferencesGroup()
        group.set_title("Location Detection")
        group.set_description("Auto-detected location for weather")
        
        row = Adw.ActionRow()
        row.set_title("Detected Location")
        
        self.location_label = Gtk.Label(label="Detecting...")
        self.location_label.add_css_class("dim-label")
        row.add_suffix(self.location_label)
        
        refresh_btn = Gtk.Button()
        refresh_btn.set_icon_name("view-refresh-symbolic")
        refresh_btn.add_css_class("flat")
        refresh_btn.set_valign(Gtk.Align.CENTER)
        refresh_btn.connect("clicked", self._on_detect_location)
        row.add_suffix(refresh_btn)
        
        group.add(row)
        
        GLib.timeout_add(500, self._on_detect_location, None)
        
        return group
    
    def _build_clock_section(self) -> Gtk.Widget:
        """Clock widget section"""
        group = Adw.PreferencesGroup()
        group.set_title("Clock Widget")
        group.set_description("Primary desktop clock")
        
        clock_config = self.config["widgets"]["clock"]
        
        # Enable toggle
        enable_row = Adw.SwitchRow()
        enable_row.set_title("Enable Clock")
        enable_row.set_subtitle("Show clock on desktop")
        enable_row.set_active(clock_config.get("enabled", True))
        enable_row.connect("notify::active", self._on_clock_toggle)
        self.clock_switch = enable_row
        group.add(enable_row)
        
        # Status indicator
        status_row = Adw.ActionRow()
        status_row.set_title("Status")
        self.clock_status = Gtk.Label(label="Checking...")
        self.clock_status.add_css_class("dim-label")
        status_row.add_suffix(self.clock_status)
        group.add(status_row)
        
        # Timezone
        tz_row = Adw.ComboRow()
        tz_row.set_title("Timezone")
        
        tz_model = Gtk.StringList()
        current_tz = clock_config.get("timezone", "Asia/Manila")
        selected_idx = 0
        
        for i, (tz_id, tz_name) in enumerate(self.common_timezones):
            tz_model.append(tz_name)
            if tz_id == current_tz:
                selected_idx = i
        
        tz_row.set_model(tz_model)
        tz_row.set_selected(selected_idx)
        tz_row.connect("notify::selected", self._on_clock_tz_changed)
        self.clock_tz_combo = tz_row
        group.add(tz_row)
        
        # 24h format
        format_row = Adw.SwitchRow()
        format_row.set_title("24-Hour Format")
        format_row.set_active(clock_config.get("format_24h", True))
        format_row.connect("notify::active", self._on_clock_format_toggle)
        group.add(format_row)
        
        # Preview
        preview_row = Adw.ActionRow()
        preview_row.set_title("Preview")
        self.clock_preview = Gtk.Label()
        self.clock_preview.add_css_class("monospace")
        preview_row.add_suffix(self.clock_preview)
        group.add(preview_row)
        
        self._update_clock_preview()
        GLib.timeout_add_seconds(1, self._update_clock_preview)
        
        return group
    
    def _build_secondary_clock_section(self) -> Gtk.Widget:
        """Secondary clock section"""
        group = Adw.PreferencesGroup()
        group.set_title("Secondary Clock (Dual Clock)")
        group.set_description("Additional clock with different timezone")
        
        clock_config = self.config["widgets"]["clock_secondary"]
        
        # Enable
        enable_row = Adw.SwitchRow()
        enable_row.set_title("Enable Secondary Clock")
        enable_row.set_active(clock_config.get("enabled", False))
        enable_row.connect("notify::active", self._on_secondary_toggle)
        self.secondary_switch = enable_row
        group.add(enable_row)
        
        # Timezone
        tz_row = Adw.ComboRow()
        tz_row.set_title("Timezone")
        
        tz_model = Gtk.StringList()
        current_tz = clock_config.get("timezone", "America/New_York")
        selected_idx = 0
        
        for i, (tz_id, tz_name) in enumerate(self.common_timezones):
            tz_model.append(tz_name)
            if tz_id == current_tz:
                selected_idx = i
        
        tz_row.set_model(tz_model)
        tz_row.set_selected(selected_idx)
        tz_row.connect("notify::selected", self._on_secondary_tz_changed)
        group.add(tz_row)
        
        # Preview
        preview_row = Adw.ActionRow()
        preview_row.set_title("Preview")
        self.secondary_preview = Gtk.Label()
        self.secondary_preview.add_css_class("monospace")
        preview_row.add_suffix(self.secondary_preview)
        group.add(preview_row)
        
        self._update_secondary_preview()
        GLib.timeout_add_seconds(1, self._update_secondary_preview)
        
        return group
    
    def _build_weather_section(self) -> Gtk.Widget:
        """Weather widget section"""
        group = Adw.PreferencesGroup()
        group.set_title("Weather Widget")
        group.set_description("Desktop weather display")
        
        weather_config = self.config["widgets"]["weather"]
        
        # Enable
        enable_row = Adw.SwitchRow()
        enable_row.set_title("Enable Weather")
        enable_row.set_subtitle("Show weather on desktop")
        enable_row.set_active(weather_config.get("enabled", True))
        enable_row.connect("notify::active", self._on_weather_toggle)
        self.weather_switch = enable_row
        group.add(enable_row)
        
        # Status
        status_row = Adw.ActionRow()
        status_row.set_title("Status")
        self.weather_status = Gtk.Label(label="Checking...")
        self.weather_status.add_css_class("dim-label")
        status_row.add_suffix(self.weather_status)
        group.add(status_row)
        
        # Auto location
        auto_row = Adw.SwitchRow()
        auto_row.set_title("Auto-Detect Location")
        is_auto = weather_config.get("location", "auto") == "auto"
        auto_row.set_active(is_auto)
        auto_row.connect("notify::active", self._on_weather_auto_toggle)
        self.weather_auto = auto_row
        group.add(auto_row)
        
        # Manual location
        location_row = Adw.EntryRow()
        location_row.set_title("Manual Location")
        location_row.set_text(weather_config.get("location_name", ""))
        location_row.set_sensitive(not is_auto)
        location_row.connect("changed", self._on_weather_location_changed)
        self.weather_entry = location_row
        group.add(location_row)
        
        # Quick select PH cities
        cities_row = Adw.ComboRow()
        cities_row.set_title("Quick Select (PH)")
        cities_row.set_sensitive(not is_auto)
        
        cities = [
            "-- Select City --",
            "Manila", "Quezon City", "Makati", "Taguig", "Pasig",
            "Antipolo", "Cebu City", "Davao City", "Zamboanga",
            "Baguio", "Iloilo City", "Cagayan de Oro", "Batangas"
        ]
        
        cities_model = Gtk.StringList()
        for city in cities:
            cities_model.append(city)
        
        cities_row.set_model(cities_model)
        cities_row.set_selected(0)
        cities_row.connect("notify::selected", self._on_city_selected)
        self.cities_combo = cities_row
        group.add(cities_row)
        
        return group
    
    def _build_sysmon_section(self) -> Gtk.Widget:
        """System monitor section"""
        group = Adw.PreferencesGroup()
        group.set_title("System Monitor Widget")
        group.set_description("CPU, GPU, RAM, Network stats")
        
        sysmon_config = self.config["widgets"]["system_monitor"]
        
        # Enable
        enable_row = Adw.SwitchRow()
        enable_row.set_title("Enable System Monitor")
        enable_row.set_subtitle("Show stats on desktop")
        enable_row.set_active(sysmon_config.get("enabled", True))
        enable_row.connect("notify::active", self._on_sysmon_toggle)
        self.sysmon_switch = enable_row
        group.add(enable_row)
        
        # Status
        status_row = Adw.ActionRow()
        status_row.set_title("Status")
        self.sysmon_status = Gtk.Label(label="Checking...")
        self.sysmon_status.add_css_class("dim-label")
        status_row.add_suffix(self.sysmon_status)
        group.add(status_row)
        
        # Quick actions
        action_row = Adw.ActionRow()
        action_row.set_title("Quick Actions")
        
        btm_btn = Gtk.Button(label="btm")
        btm_btn.add_css_class("flat")
        btm_btn.set_valign(Gtk.Align.CENTER)
        btm_btn.connect("clicked", lambda b: subprocess.Popen(['alacritty', '-e', 'btm']))
        action_row.add_suffix(btm_btn)
        
        htop_btn = Gtk.Button(label="htop")
        htop_btn.add_css_class("flat")
        htop_btn.set_valign(Gtk.Align.CENTER)
        htop_btn.connect("clicked", lambda b: subprocess.Popen(['alacritty', '-e', 'htop']))
        action_row.add_suffix(htop_btn)
        
        group.add(action_row)
        
        return group
    
    def _build_action_buttons(self) -> Gtk.Widget:
        """Action buttons"""
        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        box.set_halign(Gtk.Align.END)
        box.set_margin_top(16)
        
        # Restart all
        restart_btn = Gtk.Button(label="Restart All Widgets")
        restart_btn.add_css_class("suggested-action")
        restart_btn.connect("clicked", self._on_restart_all)
        box.append(restart_btn)
        
        # Stop all
        stop_btn = Gtk.Button(label="Stop All")
        stop_btn.add_css_class("destructive-action")
        stop_btn.connect("clicked", self._on_stop_all)
        box.append(stop_btn)
        
        return box
    
    def _apply_css(self):
        """Apply CSS"""
        css = Gtk.CssProvider()
        css.load_from_string("""
            .monospace {
                font-family: "JetBrainsMono Nerd Font", monospace;
                font-size: 14px;
            }
            .status-running {
                color: #30d158;
                font-weight: 600;
            }
            .status-stopped {
                color: #ff453a;
            }
            .location-highlight {
                color: #30d158;
                font-weight: 600;
            }
        """)
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(), css,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )
    
    # ═══════════════════════════════════════════════════════════════
    # WIDGET CONTROL - Uses start-widgets.sh
    # ═══════════════════════════════════════════════════════════════
    
    def _run_widget_script(self, args: list):
        """Run start-widgets.sh with arguments"""
        if self.start_script.exists():
            cmd = ['bash', str(self.start_script)] + args
            subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        else:
            print(f"[WidgetsPage] Script not found: {self.start_script}")
    
    def _is_widget_running(self, widget_name: str) -> bool:
        """Check if widget is running"""
        result = subprocess.run(
            ['pgrep', '-f', f'{widget_name}_widget.py'],
            capture_output=True
        )
        return result.returncode == 0
    
    def _start_widget(self, widget_name: str):
        """Start a specific widget using the script"""
        self._run_widget_script([widget_name])
    
    def _stop_widget(self, widget_name: str):
        """Stop a specific widget"""
        subprocess.run(['pkill', '-f', f'{widget_name}_widget.py'], capture_output=True)
    
    def _update_running_status(self) -> bool:
        """Update status labels"""
        # Clock
        if self._is_widget_running("clock"):
            self.clock_status.set_text("● Running")
            self.clock_status.remove_css_class("status-stopped")
            self.clock_status.add_css_class("status-running")
        else:
            self.clock_status.set_text("○ Stopped")
            self.clock_status.remove_css_class("status-running")
            self.clock_status.add_css_class("status-stopped")
        
        # Weather
        if self._is_widget_running("weather"):
            self.weather_status.set_text("● Running")
            self.weather_status.remove_css_class("status-stopped")
            self.weather_status.add_css_class("status-running")
        else:
            self.weather_status.set_text("○ Stopped")
            self.weather_status.remove_css_class("status-running")
            self.weather_status.add_css_class("status-stopped")
        
        # System Monitor
        if self._is_widget_running("system_monitor"):
            self.sysmon_status.set_text("● Running")
            self.sysmon_status.remove_css_class("status-stopped")
            self.sysmon_status.add_css_class("status-running")
        else:
            self.sysmon_status.set_text("○ Stopped")
            self.sysmon_status.remove_css_class("status-running")
            self.sysmon_status.add_css_class("status-stopped")
        
        return True  # Keep running
    
    # ═══════════════════════════════════════════════════════════════
    # EVENT HANDLERS
    # ═══════════════════════════════════════════════════════════════
    
    def _on_detect_location(self, btn):
        """Detect location"""
        def detect():
            try:
                result = subprocess.run(
                    ['curl', '-s', '--connect-timeout', '3', 'https://ipapi.co/json/'],
                    capture_output=True, text=True, timeout=5
                )
                if result.returncode == 0:
                    data = json.loads(result.stdout)
                    city = data.get('city', '')
                    region = data.get('region', '')
                    
                    if city:
                        self.config["detected_location"] = {
                            "city": city,
                            "region": region,
                            "lat": data.get('latitude'),
                            "lon": data.get('longitude')
                        }
                        self._save_config()
                        
                        GLib.idle_add(self.location_label.set_text, f"{city}, {region}")
                        GLib.idle_add(self.location_label.remove_css_class, "dim-label")
                        GLib.idle_add(self.location_label.add_css_class, "location-highlight")
                        return
            except:
                pass
            GLib.idle_add(self.location_label.set_text, "Detection failed")
        
        import threading
        threading.Thread(target=detect, daemon=True).start()
        return False
    
    def _on_clock_toggle(self, switch, param):
        """Toggle clock"""
        enabled = switch.get_active()
        self.config["widgets"]["clock"]["enabled"] = enabled
        self._save_config()
        
        if enabled:
            self._start_widget("clock")
        else:
            self._stop_widget("clock")
        
        GLib.timeout_add(500, self._update_running_status)
    
    def _on_clock_tz_changed(self, combo, param):
        """Change clock timezone"""
        idx = combo.get_selected()
        if 0 <= idx < len(self.common_timezones):
            tz_id, _ = self.common_timezones[idx]
            self.config["widgets"]["clock"]["timezone"] = tz_id
            self._save_config()
            self._update_clock_preview()
    
    def _on_clock_format_toggle(self, switch, param):
        """Toggle 24h format"""
        self.config["widgets"]["clock"]["format_24h"] = switch.get_active()
        self._save_config()
        self._update_clock_preview()
    
    def _on_secondary_toggle(self, switch, param):
        """Toggle secondary clock"""
        enabled = switch.get_active()
        self.config["widgets"]["clock_secondary"]["enabled"] = enabled
        self._save_config()
        
        if enabled:
            self._start_widget("clock_secondary")
        else:
            self._stop_widget("clock_secondary")
    
    def _on_secondary_tz_changed(self, combo, param):
        """Change secondary timezone"""
        idx = combo.get_selected()
        if 0 <= idx < len(self.common_timezones):
            tz_id, _ = self.common_timezones[idx]
            self.config["widgets"]["clock_secondary"]["timezone"] = tz_id
            self._save_config()
            self._update_secondary_preview()
    
    def _on_weather_toggle(self, switch, param):
        """Toggle weather"""
        enabled = switch.get_active()
        self.config["widgets"]["weather"]["enabled"] = enabled
        self._save_config()
        
        if enabled:
            self._start_widget("weather")
        else:
            self._stop_widget("weather")
        
        GLib.timeout_add(500, self._update_running_status)
    
    def _on_weather_auto_toggle(self, switch, param):
        """Toggle weather auto location"""
        is_auto = switch.get_active()
        self.config["widgets"]["weather"]["location"] = "auto" if is_auto else "manual"
        self._save_config()
        
        self.weather_entry.set_sensitive(not is_auto)
        self.cities_combo.set_sensitive(not is_auto)
    
    def _on_weather_location_changed(self, entry):
        """Weather location changed"""
        self.config["widgets"]["weather"]["location_name"] = entry.get_text()
        self._save_config()
    
    def _on_city_selected(self, combo, param):
        """PH city selected"""
        idx = combo.get_selected()
        if idx > 0:
            city = combo.get_model().get_string(idx)
            self.weather_entry.set_text(city)
            self.config["widgets"]["weather"]["location_name"] = city
            self._save_config()
    
    def _on_sysmon_toggle(self, switch, param):
        """Toggle system monitor"""
        enabled = switch.get_active()
        self.config["widgets"]["system_monitor"]["enabled"] = enabled
        self._save_config()
        
        if enabled:
            self._start_widget("system_monitor")
        else:
            self._stop_widget("system_monitor")
        
        GLib.timeout_add(500, self._update_running_status)
    
    def _on_restart_all(self, btn):
        """Restart all widgets"""
        self._run_widget_script(['restart'])
        GLib.timeout_add(1000, self._update_running_status)
    
    def _on_stop_all(self, btn):
        """Stop all widgets"""
        self._run_widget_script(['stop'])
        GLib.timeout_add(500, self._update_running_status)
    
    def _update_clock_preview(self) -> bool:
        """Update clock preview"""
        try:
            tz_id = self.config["widgets"]["clock"].get("timezone", "Asia/Manila")
            
            if HAS_PYTZ:
                tz = pytz.timezone(tz_id)
                now = datetime.now(tz)
            else:
                now = datetime.now()
            
            if self.config["widgets"]["clock"].get("format_24h", True):
                time_str = now.strftime("%H:%M:%S")
            else:
                time_str = now.strftime("%I:%M:%S %p")
            
            self.clock_preview.set_text(f"{time_str} ({tz_id.split('/')[-1]})")
        except:
            self.clock_preview.set_text("--:--:--")
        return True
    
    def _update_secondary_preview(self) -> bool:
        """Update secondary preview"""
        try:
            tz_id = self.config["widgets"]["clock_secondary"].get("timezone", "America/New_York")
            
            if HAS_PYTZ:
                tz = pytz.timezone(tz_id)
                now = datetime.now(tz)
            else:
                now = datetime.now()
            
            self.secondary_preview.set_text(f"{now.strftime('%H:%M:%S')} ({tz_id.split('/')[-1]})")
        except:
            self.secondary_preview.set_text("--:--:--")
        return True


# Standalone test
if __name__ == "__main__":
    app = Adw.Application(application_id="com.hypr.widgets.test")
    
    def on_activate(app):
        win = Adw.ApplicationWindow(application=app)
        win.set_default_size(600, 800)
        win.set_content(WidgetsPage())
        win.present()
    
    app.connect("activate", on_activate)
    app.run(None)