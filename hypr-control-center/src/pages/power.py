"""
Power & Battery Page - Power profiles and smart RAM cleaning
Optimized for performance with zombie process detection
"""

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
from gi.repository import Gtk, Adw, GLib
import subprocess
from pathlib import Path
from typing import Optional

from ..preferences import PowerPreferences

class PowerPage:
    """Power & Battery page with smart features"""
    
    def __init__(self, window):
        self.window = window
        self.prefs = PowerPreferences()
        self._cleanup_timer_id = None
        
    def build(self) -> Gtk.Box:
        """Build power page"""
        page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        page.set_margin_top(24)
        page.set_margin_bottom(24)
        page.set_margin_start(32)
        page.set_margin_end(32)
        
        # Header
        header = self._build_header()
        page.append(header)
        
        # Power Profiles
        profiles_group = self._build_profiles_group()
        page.append(profiles_group)
        
        # RAM Cleanup
        cleanup_group = self._build_cleanup_group()
        page.append(cleanup_group)
        
        # System Info
        info_group = self._build_info_group()
        page.append(info_group)
        
        return page
    
    def _build_header(self) -> Gtk.Box:
        """Build page header"""
        header = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        header.set_margin_bottom(24)
        
        title = Gtk.Label(label="Power & Battery")
        title.add_css_class('page-title')
        title.set_xalign(0)
        header.append(title)
        
        subtitle = Gtk.Label(
            label="Manage power profiles and system optimization"
        )
        subtitle.add_css_class('page-subtitle')
        subtitle.set_xalign(0)
        header.append(subtitle)
        
        return header
    
    def _build_profiles_group(self) -> Adw.PreferencesGroup:
        """Build power profiles group"""
        group = Adw.PreferencesGroup()
        group.set_title("Power Profile")
        group.set_description("Choose performance level")
        
        # Get current profile
        current_profile = self.prefs.get_current_profile()
        
        # Profile options
        profiles = [
            ("saver", "Power Saver", "Lower CPU frequency, reduce animations"),
            ("neutral", "Balanced", "Normal performance (Recommended)"),
            ("performance", "Performance", "Maximum CPU frequency, full animations"),
            ("developer", "Developer", "Always-on mode, prevent sleep"),
        ]
        
        for profile_id, name, desc in profiles:
            row = Adw.ActionRow()
            row.set_title(name)
            row.set_subtitle(desc)
            
            # Radio button
            check = Gtk.CheckButton()
            check.set_active(profile_id == current_profile)
            check.set_valign(Gtk.Align.CENTER)
            
            # Group radio buttons
            if hasattr(self, '_profile_group'):
                check.set_group(self._profile_group)
            else:
                self._profile_group = check
            
            check.connect('toggled', lambda c, pid=profile_id: self._on_profile_change(pid) if c.get_active() else None)
            
            row.add_prefix(check)
            row.set_activatable_widget(check)
            
            group.add(row)
        
        return group
    
    def _build_cleanup_group(self) -> Adw.PreferencesGroup:
        """Build smart RAM cleanup group"""
        group = Adw.PreferencesGroup()
        group.set_title("Smart RAM Cleanup")
        group.set_description("Automatic zombie process detection and cleanup")
        
        # Enable toggle
        enable_row = Adw.ActionRow()
        enable_row.set_title("Auto Cleanup")
        enable_row.set_subtitle("Detect and clean zombie processes automatically")
        
        enable_switch = Gtk.Switch()
        enable_switch.set_active(self.prefs.get('cleanup_enabled', False))
        enable_switch.set_valign(Gtk.Align.CENTER)
        enable_switch.connect('notify::active', self._on_cleanup_toggle)
        enable_row.add_suffix(enable_switch)
        
        group.add(enable_row)
        
        # Interval selection
        interval_row = Adw.ActionRow()
        interval_row.set_title("Check Interval")
        interval_row.set_subtitle("How often to check for zombie processes")
        
        intervals = ["30 sec", "1 min", "2 min", "5 min"]
        interval_values = [30, 60, 120, 300]
        
        current_interval = self.prefs.get('cleanup_interval', 60)
        current_idx = interval_values.index(current_interval) if current_interval in interval_values else 1
        
        interval_dropdown = Gtk.DropDown()
        interval_dropdown.set_model(Gtk.StringList.new(intervals))
        interval_dropdown.set_selected(current_idx)
        interval_dropdown.set_valign(Gtk.Align.CENTER)
        interval_dropdown.connect('notify::selected',
                                 lambda d, _: self._on_interval_change(interval_values[d.get_selected()]))
        interval_row.add_suffix(interval_dropdown)
        
        group.add(interval_row)
        
        # Manual cleanup button
        manual_row = Adw.ActionRow()
        manual_row.set_title("Clean Now")
        manual_row.set_subtitle("Manually trigger zombie process cleanup")
        
        clean_button = Gtk.Button(label="Clean")
        clean_button.set_valign(Gtk.Align.CENTER)
        clean_button.connect('clicked', lambda b: self._run_cleanup())
        manual_row.add_suffix(clean_button)
        
        group.add(manual_row)
        
        return group
    
    def _build_info_group(self) -> Adw.PreferencesGroup:
        """Build system info group"""
        group = Adw.PreferencesGroup()
        group.set_title("System Information")
        
        # RAM usage
        ram_row = Adw.ActionRow()
        ram_row.set_title("RAM Usage")
        ram_usage = self._get_ram_usage()
        ram_row.set_subtitle(ram_usage)
        group.add(ram_row)
        
        # Zombie processes
        zombie_row = Adw.ActionRow()
        zombie_row.set_title("Zombie Processes")
        zombie_count = self._count_zombie_processes()
        zombie_row.set_subtitle(f"{zombie_count} found")
        group.add(zombie_row)
        
        return group
    
    def _on_profile_change(self, profile: str):
        """Handle power profile change"""
        self.prefs.set_current_profile(profile)
        self._apply_power_profile(profile)
        self.window._show_toast(f"Power profile: {profile.capitalize()}")
    
    def _apply_power_profile(self, profile: str):
        """Apply power profile using powerprofilesctl"""
        try:
            # Map profiles to system profiles
            profile_map = {
                'saver': 'power-saver',
                'neutral': 'balanced',
                'performance': 'performance',
                'developer': 'performance',  # Same as performance but prevent sleep
            }
            
            system_profile = profile_map.get(profile, 'balanced')
            
            # Apply profile
            subprocess.run(
                ['powerprofilesctl', 'set', system_profile],
                timeout=2,
                check=False
            )
            
            # Developer mode: prevent sleep
            if profile == 'developer':
                self._prevent_sleep(True)
            else:
                self._prevent_sleep(False)
                
        except:
            pass
    
    def _prevent_sleep(self, prevent: bool):
        """Prevent system sleep (developer mode)"""
        try:
            if prevent:
                # Inhibit sleep
                subprocess.Popen([
                    'systemd-inhibit',
                    '--what=sleep:idle',
                    '--who=hypr-control-center',
                    '--why=Developer mode',
                    'sleep', 'infinity'
                ])
            else:
                # Kill inhibit
                subprocess.run(['pkill', '-f', 'systemd-inhibit.*hypr-control-center'], check=False)
        except:
            pass
    
    def _on_cleanup_toggle(self, switch, _):
        """Handle cleanup toggle"""
        enabled = switch.get_active()
        self.prefs.set('cleanup_enabled', enabled)
        
        if enabled:
            self._start_cleanup_timer()
        else:
            self._stop_cleanup_timer()
        
        self.window._show_toast(f"Auto cleanup: {'Enabled' if enabled else 'Disabled'}")
    
    def _on_interval_change(self, interval: int):
        """Handle interval change"""
        self.prefs.set('cleanup_interval', interval)
        
        # Restart timer if enabled
        if self.prefs.get('cleanup_enabled', False):
            self._stop_cleanup_timer()
            self._start_cleanup_timer()
    
    def _start_cleanup_timer(self):
        """Start automatic cleanup timer"""
        interval = self.prefs.get('cleanup_interval', 60)
        
        # Convert to milliseconds
        interval_ms = interval * 1000
        
        # Start timer
        self._cleanup_timer_id = GLib.timeout_add(
            interval_ms,
            self._cleanup_timer_callback
        )
    
    def _stop_cleanup_timer(self):
        """Stop cleanup timer"""
        if self._cleanup_timer_id:
            GLib.source_remove(self._cleanup_timer_id)
            self._cleanup_timer_id = None
    
    def _cleanup_timer_callback(self) -> bool:
        """Timer callback - check and clean zombies"""
        self._run_cleanup(silent=True)
        return True  # Continue timer
    
    def _run_cleanup(self, silent: bool = False):
        """Run smart zombie cleanup"""
        try:
            # Create cleanup script path
            script_path = Path.home() / ".config/hypr-control-center/scripts/smart-cleanup.sh"
            script_path.parent.mkdir(parents=True, exist_ok=True)
            
            # Create script if it doesn't exist
            if not script_path.exists():
                self._create_cleanup_script(script_path)
            
            # Run script
            result = subprocess.run(
                ['bash', str(script_path)],
                capture_output=True,
                text=True,
                timeout=5
            )
            
            if not silent:
                if "Cleaned" in result.stdout:
                    self.window._show_toast("Zombie processes cleaned!")
                else:
                    self.window._show_toast("No cleanup needed - system healthy!")
                    
        except Exception as e:
            if not silent:
                self.window._show_toast(f"Cleanup failed: {str(e)}")
    
    def _create_cleanup_script(self, script_path: Path):
        """Create smart zombie cleanup script"""
        script_content = '''#!/bin/bash
# Smart Zombie Process Cleaner
# Only runs if zombies are detected

# Count zombie processes
ZOMBIE_COUNT=$(ps aux | awk '$8=="Z" {print $2}' | wc -l)

# Exit if no zombies
if [ "$ZOMBIE_COUNT" -eq 0 ]; then
    echo "No zombies found"
    exit 0
fi

echo "Found $ZOMBIE_COUNT zombie processes"

# Get zombie PIDs
ZOMBIE_PIDS=$(ps aux | awk '$8=="Z" {print $2}')

# Try to clean zombies by killing parent processes
for PID in $ZOMBIE_PIDS; do
    # Get parent PID
    PPID=$(ps -o ppid= -p $PID 2>/dev/null | tr -d ' ')
    
    if [ -n "$PPID" ] && [ "$PPID" != "1" ]; then
        # Don't kill init/systemd
        PNAME=$(ps -o comm= -p $PPID 2>/dev/null)
        
        # Skip critical processes
        if [[ "$PNAME" != "systemd" ]] && [[ "$PNAME" != "init" ]]; then
            echo "Cleaning zombie $PID (parent: $PPID - $PNAME)"
            kill -SIGCHLD $PPID 2>/dev/null
        fi
    fi
done

# Wait a moment
sleep 1

# Check if zombies were cleaned
NEW_ZOMBIE_COUNT=$(ps aux | awk '$8=="Z" {print $2}' | wc -l)

if [ "$NEW_ZOMBIE_COUNT" -lt "$ZOMBIE_COUNT" ]; then
    CLEANED=$((ZOMBIE_COUNT - NEW_ZOMBIE_COUNT))
    echo "Cleaned $CLEANED zombie processes"
else
    echo "Some zombies persist (system will clean on reboot)"
fi
'''
        script_path.write_text(script_content)
        script_path.chmod(0o755)
    
    def _get_ram_usage(self) -> str:
        """Get current RAM usage"""
        try:
            result = subprocess.run(
                ['free', '-h'],
                capture_output=True,
                text=True,
                timeout=1
            )
            
            lines = result.stdout.split('\n')
            for line in lines:
                if line.startswith('Mem:'):
                    parts = line.split()
                    total = parts[1]
                    used = parts[2]
                    return f"{used} / {total}"
        except:
            pass
        
        return "Unknown"
    
    def _count_zombie_processes(self) -> int:
        """Count zombie processes"""
        try:
            result = subprocess.run(
                ['ps', 'aux'],
                capture_output=True,
                text=True,
                timeout=1
            )
            
            count = 0
            for line in result.stdout.split('\n'):
                if ' Z ' in line or '<defunct>' in line:
                    count += 1
            
            return count
        except:
            return 0


def build_power_page(window) -> Gtk.Box:
    """Build power page (factory function)"""
    page_builder = PowerPage(window)
    return page_builder.build()