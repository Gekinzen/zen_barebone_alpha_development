"""
Power & Battery Page - TLP/cpupower integration with smart RAM cleaning
Aligned with Arch Linux + Hyprland power optimization setup
Supports AMD pstate-epp driver with EPP control
"""

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
gi.require_version('Gdk', '4.0')
from gi.repository import Gtk, Adw, GLib, Gio, Gdk
import subprocess
import os
import threading
from pathlib import Path
from typing import Optional, Tuple
from dataclasses import dataclass

# Try to import preferences, fallback if not available
try:
    from ..preferences import PowerPreferences
except ImportError:
    class PowerPreferences:
        """Fallback preferences class"""
        def __init__(self):
            self._prefs = {}
        def get(self, key, default=None):
            return self._prefs.get(key, default)
        def set(self, key, value):
            self._prefs[key] = value
        def get_current_profile(self):
            return self.get('power_profile', 'balanced')
        def set_current_profile(self, profile):
            self.set('power_profile', profile)


@dataclass
class SystemStats:
    """System statistics container"""
    ram_used: str = "0"
    ram_total: str = "0"
    ram_percent: float = 0.0
    swap_used: str = "0"
    swap_total: str = "0"
    cache_size: str = "0"
    zombie_count: int = 0
    cpu_governor: str = "unknown"
    battery_percent: Optional[int] = None
    battery_charging: bool = False
    tlp_mode: str = "unknown"


class SudoersManager:
    """Manage passwordless sudo setup for power management"""
    
    SUDOERS_PATH = "/etc/sudoers.d/hypr-control-center"
    SUDOERS_CONTENT = """%wheel ALL=(ALL) NOPASSWD: /usr/bin/cpupower frequency-set *
%wheel ALL=(ALL) NOPASSWD: /usr/bin/tlp bat
%wheel ALL=(ALL) NOPASSWD: /usr/bin/tlp ac
%wheel ALL=(ALL) NOPASSWD: /usr/bin/tlp start
%wheel ALL=(ALL) NOPASSWD: /usr/bin/swapoff -a
%wheel ALL=(ALL) NOPASSWD: /usr/bin/swapon -a
%wheel ALL=(ALL) NOPASSWD: /usr/bin/tee /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference
"""
    
    @staticmethod
    def is_configured() -> bool:
        """Check if passwordless sudo is already configured"""
        # Test by running an allowed command with invalid argument
        # This will fail with "invalid governor" if NOPASSWD works
        # Or fail with "password required" if not configured
        try:
            result = subprocess.run(
                ['sudo', '-n', 'cpupower', 'frequency-set', '-g', 'INVALID_TEST_GOV'],
                capture_output=True,
                text=True,
                timeout=3
            )
            stderr = result.stderr.lower()
            # If sudo asks for password, not configured
            if 'password' in stderr or 'sudo:' in stderr:
                return False
            # If we get here (even with error about invalid governor), NOPASSWD works!
            return True
        except subprocess.TimeoutExpired:
            return False
        except Exception:
            pass
        
        # Fallback: try tlp which doesn't need args
        try:
            result = subprocess.run(
                ['sudo', '-n', 'tlp', 'start'],
                capture_output=True,
                text=True,
                timeout=3
            )
            stderr = result.stderr.lower()
            if 'password' in stderr or 'sudo:' in stderr:
                return False
            return True
        except:
            pass
        
        return False
    
    @staticmethod
    def check_sudoers_file_exists() -> bool:
        """Check if our sudoers file exists - uses is_configured() result"""
        # We can't directly check /etc/sudoers.d/ without root
        # So we rely on the is_configured check
        return SudoersManager.is_configured()
    
    @staticmethod
    def setup_sudoers_sync() -> Tuple[bool, str]:
        """Setup sudoers file (blocking - call from thread)"""
        try:
            if SudoersManager.is_configured():
                return True, "Already configured"
            
            import tempfile
            temp_dir = tempfile.gettempdir()
            temp_path = os.path.join(temp_dir, 'hypr-sudoers.tmp')
            
            with open(temp_path, 'w') as f:
                f.write(SudoersManager.SUDOERS_CONTENT)
            
            os.chmod(temp_path, 0o644)
            
            install_script = f'''#!/bin/bash
cp "{temp_path}" "{SudoersManager.SUDOERS_PATH}"
chmod 440 "{SudoersManager.SUDOERS_PATH}"
chown root:root "{SudoersManager.SUDOERS_PATH}"
rm -f "{temp_path}"
'''
            script_path = os.path.join(temp_dir, 'hypr-install-sudoers.sh')
            with open(script_path, 'w') as f:
                f.write(install_script)
            os.chmod(script_path, 0o755)
            
            result = subprocess.run(
                ['pkexec', 'bash', script_path],
                capture_output=True,
                text=True,
                timeout=60
            )
            
            try:
                os.unlink(script_path)
                os.unlink(temp_path)
            except:
                pass
            
            if result.returncode == 0:
                if SudoersManager.is_configured():
                    return True, "Setup complete"
                else:
                    return False, "Setup completed but verification failed"
            elif result.returncode == 126:
                return False, "Authentication cancelled"
            elif result.returncode == 127:
                return False, "pkexec not found"
            else:
                return False, f"Setup failed (code {result.returncode})"
                
        except subprocess.TimeoutExpired:
            return False, "Setup timed out - try again"
        except FileNotFoundError:
            return False, "pkexec not found - install polkit"
        except Exception as e:
            return False, f"Error: {e}"
    
    @staticmethod
    def get_status() -> dict:
        """Get detailed status of power management setup"""
        status = {
            'sudoers_configured': False,
            'sudoers_file_exists': False,
            'cpupower_installed': False,
            'tlp_installed': False,
            'tlp_running': False,
            'in_wheel_group': False,
            'auth_agent_running': False,
        }
        
        # Check if file exists first
        status['sudoers_file_exists'] = SudoersManager.check_sudoers_file_exists()
        status['sudoers_configured'] = SudoersManager.is_configured()
        
        try:
            result = subprocess.run(['which', 'cpupower'], capture_output=True, timeout=2)
            status['cpupower_installed'] = result.returncode == 0
        except:
            pass
        
        try:
            result = subprocess.run(['which', 'tlp'], capture_output=True, timeout=2)
            status['tlp_installed'] = result.returncode == 0
            
            if status['tlp_installed']:
                result = subprocess.run(
                    ['systemctl', 'is-active', 'tlp'],
                    capture_output=True,
                    text=True,
                    timeout=2
                )
                status['tlp_running'] = result.stdout.strip() == 'active'
        except:
            pass
        
        try:
            result = subprocess.run(['groups'], capture_output=True, text=True, timeout=2)
            status['in_wheel_group'] = 'wheel' in result.stdout
        except:
            pass
        
        try:
            result = subprocess.run(
                ['pgrep', '-f', 'polkit|authentication-agent'],
                capture_output=True,
                timeout=2
            )
            status['auth_agent_running'] = result.returncode == 0
        except:
            pass
        
        return status
    
    @staticmethod
    def get_manual_setup_command() -> str:
        """Get command for manual setup via terminal"""
        return '''echo '%wheel ALL=(ALL) NOPASSWD: /usr/bin/cpupower frequency-set *
%wheel ALL=(ALL) NOPASSWD: /usr/bin/tlp bat
%wheel ALL=(ALL) NOPASSWD: /usr/bin/tlp ac
%wheel ALL=(ALL) NOPASSWD: /usr/bin/tlp start
%wheel ALL=(ALL) NOPASSWD: /usr/bin/swapoff -a
%wheel ALL=(ALL) NOPASSWD: /usr/bin/swapon -a
%wheel ALL=(ALL) NOPASSWD: /usr/bin/tee /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference' | sudo tee /etc/sudoers.d/hypr-control-center && sudo chmod 440 /etc/sudoers.d/hypr-control-center'''


class CPUPowerManager:
    """Manage CPU frequency and power with support for different drivers"""
    
    @staticmethod
    def get_driver_info() -> dict:
        """Get CPU frequency driver information"""
        info = {
            'driver': 'unknown',
            'available_governors': [],
            'current_governor': 'unknown',
            'is_amd_pstate': False,
            'epp_available': False,
            'available_epp': [],
            'current_epp': 'unknown',
        }
        
        try:
            driver_path = Path("/sys/devices/system/cpu/cpu0/cpufreq/scaling_driver")
            if driver_path.exists():
                info['driver'] = driver_path.read_text().strip()
                info['is_amd_pstate'] = 'amd-pstate' in info['driver']
            
            gov_path = Path("/sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors")
            if gov_path.exists():
                info['available_governors'] = gov_path.read_text().strip().split()
            
            cur_gov_path = Path("/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor")
            if cur_gov_path.exists():
                info['current_governor'] = cur_gov_path.read_text().strip()
            
            epp_path = Path("/sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference")
            if epp_path.exists():
                info['epp_available'] = True
                info['current_epp'] = epp_path.read_text().strip()
                
                avail_epp_path = Path("/sys/devices/system/cpu/cpu0/cpufreq/energy_performance_available_preferences")
                if avail_epp_path.exists():
                    info['available_epp'] = avail_epp_path.read_text().strip().split()
                    
        except Exception as e:
            print(f"Error getting driver info: {e}")
        
        return info
    
    @staticmethod
    def get_profile_mapping(driver_info: dict) -> list:
        """Get profile definitions based on available governors/EPP"""
        governors = driver_info.get('available_governors', [])
        is_amd_pstate = driver_info.get('is_amd_pstate', False)
        epp_available = driver_info.get('epp_available', False)
        available_epp = driver_info.get('available_epp', [])
        
        profiles = []
        
        # Power Saver
        if 'powersave' in governors:
            epp = 'power' if epp_available and 'power' in available_epp else None
            profiles.append({
                'id': 'powersave',
                'name': 'Power Saver',
                'subtitle': 'Minimum power, maximum battery life',
                'icon': 'battery-level-10-symbolic',
                'governor': 'powersave',
                'epp': epp
            })
        
        # Balanced
        if is_amd_pstate and epp_available:
            epp = 'balance_performance' if 'balance_performance' in available_epp else 'default'
            profiles.append({
                'id': 'balanced',
                'name': 'Balanced',
                'subtitle': 'Dynamic scaling (powersave + balanced EPP)',
                'icon': 'battery-level-50-symbolic',
                'governor': 'powersave',
                'epp': epp
            })
        elif 'schedutil' in governors:
            profiles.append({
                'id': 'balanced',
                'name': 'Balanced',
                'subtitle': 'Dynamic scaling based on load (schedutil)',
                'icon': 'battery-level-50-symbolic',
                'governor': 'schedutil',
                'epp': None
            })
        elif 'ondemand' in governors:
            profiles.append({
                'id': 'balanced',
                'name': 'Balanced',
                'subtitle': 'Dynamic scaling (ondemand)',
                'icon': 'battery-level-50-symbolic',
                'governor': 'ondemand',
                'epp': None
            })
        
        # Performance
        if 'performance' in governors:
            epp = 'performance' if epp_available and 'performance' in available_epp else None
            profiles.append({
                'id': 'performance',
                'name': 'Performance',
                'subtitle': 'Maximum frequency, highest power draw',
                'icon': 'battery-level-100-charging-symbolic',
                'governor': 'performance',
                'epp': epp
            })
        
        return profiles
    
    @staticmethod
    def set_profile_sync(governor: str, epp: Optional[str] = None) -> Tuple[bool, str]:
        """Set CPU profile (blocking - call from thread)"""
        success = True
        messages = []
        
        try:
            result = subprocess.run(
                ['sudo', '-n', 'cpupower', 'frequency-set', '-g', governor],
                capture_output=True,
                text=True,
                timeout=5
            )
            
            if result.returncode != 0:
                driver_info = CPUPowerManager.get_driver_info()
                if governor not in driver_info['available_governors']:
                    return False, f"Governor '{governor}' not available"
                return False, f"Failed to set governor: {result.stderr}"
            
            messages.append(f"Governor: {governor}")
            
        except subprocess.TimeoutExpired:
            return False, "Timeout setting governor"
        except Exception as e:
            return False, f"Error: {e}"
        
        if epp:
            try:
                cpu_dirs = list(Path("/sys/devices/system/cpu/").glob("cpu[0-9]*"))
                
                for cpu_dir in cpu_dirs:
                    epp_path = cpu_dir / "cpufreq/energy_performance_preference"
                    if epp_path.exists():
                        result = subprocess.run(
                            ['sudo', '-n', 'tee', str(epp_path)],
                            input=epp,
                            capture_output=True,
                            text=True,
                            timeout=2
                        )
                        
                        if result.returncode != 0:
                            subprocess.run(
                                ['sudo', '-n', 'sh', '-c', f'echo {epp} > {epp_path}'],
                                capture_output=True,
                                timeout=2
                            )
                
                messages.append(f"EPP: {epp}")
                
            except Exception as e:
                messages.append(f"EPP failed: {e}")
        
        return success, ", ".join(messages)


class PowerPage:
    """Power & Battery page with TLP/cpupower integration"""
    
    def __init__(self, window):
        self.window = window
        self.prefs = PowerPreferences()
        self._cleanup_timer_id = None
        self._stats_timer_id = None
        self._profile_buttons = {}
        self._stats_labels = {}
        self._setup_status = None
        self._driver_info = None
        self._setup_banner = None
        
    def build(self) -> Gtk.Box:
        """Build power page"""
        page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        page.set_margin_top(24)
        page.set_margin_bottom(24)
        page.set_margin_start(32)
        page.set_margin_end(32)
        
        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroll.set_vexpand(True)
        
        content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16)
        
        # Check setup status FIRST - needed by header and banner
        self._setup_status = SudoersManager.get_status()
        
        # Header (shows status badge if configured)
        header = self._build_header()
        content.append(header)
        
        # Only show banner if NOT configured
        if not self._setup_status.get('sudoers_configured', False):
            setup_banner = self._build_setup_banner()
            content.append(setup_banner)
        
        # Battery Status (if available)
        battery_group = self._build_battery_group()
        if battery_group:
            content.append(battery_group)
        
        # Power Profiles
        profiles_group = self._build_profiles_group()
        content.append(profiles_group)
        
        # RAM & Cache Cleanup
        cleanup_group = self._build_cleanup_group()
        content.append(cleanup_group)
        
        # System Stats
        stats_group = self._build_stats_group()
        content.append(stats_group)
        
        # Advanced Options
        advanced_group = self._build_advanced_group()
        content.append(advanced_group)
        
        scroll.set_child(content)
        page.append(scroll)
        
        self._start_stats_timer()
        
        if self.prefs.get('cleanup_enabled', False):
            self._start_cleanup_timer()
        
        return page
    
    def _build_setup_banner(self) -> Gtk.Box:
        """Build setup required banner"""
        banner = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        banner.add_css_class('card')
        banner.set_margin_bottom(8)
        
        inner = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        inner.set_margin_top(16)
        inner.set_margin_bottom(16)
        inner.set_margin_start(16)
        inner.set_margin_end(16)
        
        title_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        
        icon = Gtk.Image.new_from_icon_name("dialog-warning-symbolic")
        icon.set_pixel_size(24)
        icon.add_css_class('warning')
        title_row.append(icon)
        
        title = Gtk.Label(label="Setup Required")
        title.add_css_class('title-4')
        title.set_xalign(0)
        title.set_hexpand(True)
        title_row.append(title)
        
        inner.append(title_row)
        
        desc = Gtk.Label(
            label="Power profile switching requires one-time setup for passwordless access."
        )
        desc.set_xalign(0)
        desc.set_wrap(True)
        desc.add_css_class('dim-label')
        inner.append(desc)
        
        status = self._setup_status
        status_text = []
        if not status.get('cpupower_installed', False):
            status_text.append("• cpupower not installed (sudo pacman -S cpupower)")
        if not status.get('tlp_installed', False):
            status_text.append("• TLP not installed (sudo pacman -S tlp)")
        if not status.get('in_wheel_group', False):
            status_text.append("• User not in wheel group")
        if not status.get('auth_agent_running', True):
            status_text.append("• Polkit auth agent not running (use 'Copy Command' instead)")
        
        if status_text:
            status_label = Gtk.Label(label="\n".join(status_text))
            status_label.set_xalign(0)
            status_label.add_css_class('error')
            inner.append(status_label)
        
        button_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        button_row.set_halign(Gtk.Align.END)
        button_row.set_margin_top(8)
        
        refresh_btn = Gtk.Button()
        refresh_btn.set_icon_name("view-refresh-symbolic")
        refresh_btn.set_tooltip_text("Check if setup was done manually")
        refresh_btn.connect('clicked', self._on_refresh_setup_status)
        button_row.append(refresh_btn)
        
        manual_btn = Gtk.Button(label="Copy Command")
        manual_btn.set_tooltip_text("Copy manual setup command to clipboard")
        manual_btn.connect('clicked', self._on_copy_setup_command)
        button_row.append(manual_btn)
        
        self._setup_button = Gtk.Button(label="Auto Setup")
        self._setup_button.add_css_class('suggested-action')
        self._setup_button.set_tooltip_text("Setup via pkexec (requires auth agent)")
        self._setup_button.connect('clicked', self._on_setup_clicked)
        button_row.append(self._setup_button)
        
        inner.append(button_row)
        banner.append(inner)
        
        self._setup_banner = banner
        
        return banner
    
    def _on_refresh_setup_status(self, button):
        """Refresh setup status check"""
        self._setup_status = SudoersManager.get_status()
        
        if self._setup_status.get('sudoers_configured', False):
            self._show_toast("Setup detected! Password-free switching enabled.")
            if self._setup_banner:
                self._setup_banner.set_visible(False)
        else:
            # More detailed feedback
            if self._setup_status.get('sudoers_file_exists', False):
                self._show_toast("Sudoers file exists but may need re-login to take effect.")
            else:
                self._show_toast("Not configured yet. Run the command in terminal.")
    
    def _on_copy_setup_command(self, button):
        """Copy manual setup command to clipboard"""
        command = "# Run this in terminal:\n" + SudoersManager.get_manual_setup_command()
        
        clipboard = Gdk.Display.get_default().get_clipboard()
        clipboard.set(command)
        self._show_toast("Command copied! Paste in terminal and run.")
    
    def _on_setup_clicked(self, button):
        """Handle setup button click"""
        button.set_sensitive(False)
        button.set_label("Setting up...")
        
        def setup_thread():
            success, message = SudoersManager.setup_sudoers_sync()
            GLib.idle_add(self._on_setup_complete, success, message)
        
        thread = threading.Thread(target=setup_thread, daemon=True)
        thread.start()
    
    def _on_setup_complete(self, success: bool, message: str):
        """Handle setup completion"""
        if success:
            self._show_toast("Setup complete! Password-free switching enabled.")
            if self._setup_banner:
                self._setup_banner.set_visible(False)
            self._setup_status = SudoersManager.get_status()
        else:
            self._show_toast(f"Setup failed: {message}")
            if "timed out" in message.lower() or "cancelled" in message.lower():
                GLib.timeout_add(2000, lambda: self._show_toast("Try 'Copy Command' for manual setup") or False)
            self._setup_button.set_sensitive(True)
            self._setup_button.set_label("Auto Setup")
        
        return False
    
    def _build_header(self) -> Gtk.Box:
        """Build page header"""
        header = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        header.set_margin_bottom(16)
        
        title_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        
        title = Gtk.Label(label="Power & Battery")
        title.add_css_class('title-1')
        title.set_xalign(0)
        title.set_hexpand(True)
        title_row.append(title)
        
        # Show status badge when configured
        if self._setup_status and self._setup_status.get('sudoers_configured', False):
            status_badge = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
            status_badge.set_valign(Gtk.Align.CENTER)
            
            status_icon = Gtk.Image.new_from_icon_name("emblem-ok-symbolic")
            status_icon.add_css_class('success')
            status_badge.append(status_icon)
            
            status_label = Gtk.Label(label="Active")
            status_label.add_css_class('success')
            status_label.add_css_class('caption')
            status_badge.append(status_label)
            
            title_row.append(status_badge)
        
        header.append(title_row)
        
        subtitle = Gtk.Label(
            label="CPU governor control, RAM optimization & system cleanup"
        )
        subtitle.add_css_class('dim-label')
        subtitle.set_xalign(0)
        header.append(subtitle)
        
        return header
    
    def _build_battery_group(self) -> Optional[Adw.PreferencesGroup]:
        """Build battery status group (only if battery exists)"""
        battery_path = Path("/sys/class/power_supply/BAT0")
        if not battery_path.exists():
            battery_path = Path("/sys/class/power_supply/BAT1")
        
        if not battery_path.exists():
            return None
        
        group = Adw.PreferencesGroup()
        group.set_title("Battery Status")
        
        battery_row = Adw.ActionRow()
        battery_row.set_title("Battery Level")
        
        level_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        level_box.set_valign(Gtk.Align.CENTER)
        
        self._battery_icon = Gtk.Image()
        self._battery_icon.set_pixel_size(24)
        level_box.append(self._battery_icon)
        
        self._battery_label = Gtk.Label()
        self._battery_label.add_css_class('title-4')
        level_box.append(self._battery_label)
        
        battery_row.add_suffix(level_box)
        group.add(battery_row)
        
        tlp_row = Adw.ActionRow()
        tlp_row.set_title("TLP Mode")
        tlp_row.set_subtitle("Current power management mode")
        
        self._tlp_label = Gtk.Label()
        self._tlp_label.set_valign(Gtk.Align.CENTER)
        self._tlp_label.add_css_class('dim-label')
        tlp_row.add_suffix(self._tlp_label)
        
        group.add(tlp_row)
        
        self._update_battery_display()
        
        return group
    
    def _build_profiles_group(self) -> Adw.PreferencesGroup:
        """Build power profiles group using cpupower"""
        group = Adw.PreferencesGroup()
        group.set_title("CPU Performance Profile")
        
        self._driver_info = CPUPowerManager.get_driver_info()
        profiles = CPUPowerManager.get_profile_mapping(self._driver_info)
        
        driver = self._driver_info.get('driver', 'unknown')
        governors = ', '.join(self._driver_info.get('available_governors', []))
        group.set_description(f"Driver: {driver} | Governors: {governors}")
        
        current_governor = self._driver_info.get('current_governor', 'unknown')
        current_epp = self._driver_info.get('current_epp', '')
        
        current_profile = self._detect_current_profile(profiles, current_governor, current_epp)
        
        first_check = None
        
        for profile in profiles:
            row = Adw.ActionRow()
            row.set_title(profile['name'])
            row.set_subtitle(profile['subtitle'])
            
            icon = Gtk.Image.new_from_icon_name(profile['icon'])
            icon.set_pixel_size(24)
            row.add_prefix(icon)
            
            check = Gtk.CheckButton()
            check.set_active(profile['id'] == current_profile)
            check.set_valign(Gtk.Align.CENTER)
            
            if first_check:
                check.set_group(first_check)
            else:
                first_check = check
            
            check.connect('toggled', self._on_profile_toggled, profile)
            
            row.add_suffix(check)
            row.set_activatable_widget(check)
            
            self._profile_buttons[profile['id']] = check
            
            group.add(row)
        
        state_row = Adw.ActionRow()
        state_row.set_title("Current State")
        
        state_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        state_box.set_valign(Gtk.Align.CENTER)
        
        self._governor_label = Gtk.Label(label=current_governor)
        self._governor_label.add_css_class('dim-label')
        state_box.append(self._governor_label)
        
        if self._driver_info.get('epp_available'):
            epp_label = Gtk.Label(label=f"| EPP: {current_epp}")
            epp_label.add_css_class('dim-label')
            state_box.append(epp_label)
            self._epp_label = epp_label
        
        state_row.add_suffix(state_box)
        group.add(state_row)
        
        return group
    
    def _detect_current_profile(self, profiles: list, governor: str, epp: str) -> str:
        """Detect which profile matches current state"""
        for profile in profiles:
            if profile['governor'] == governor:
                if profile.get('epp'):
                    if profile['epp'] == epp:
                        return profile['id']
                else:
                    return profile['id']
        
        for profile in profiles:
            if profile['governor'] == governor:
                return profile['id']
        
        return 'balanced'
    
    def _build_cleanup_group(self) -> Adw.PreferencesGroup:
        """Build RAM & cache cleanup group"""
        group = Adw.PreferencesGroup()
        group.set_title("RAM & Cache Cleanup")
        group.set_description("Free up memory and clean system caches")
        
        auto_row = Adw.ActionRow()
        auto_row.set_title("Auto Cleanup")
        auto_row.set_subtitle("Periodically clean zombie processes and caches")
        
        auto_switch = Gtk.Switch()
        auto_switch.set_active(self.prefs.get('cleanup_enabled', False))
        auto_switch.set_valign(Gtk.Align.CENTER)
        auto_switch.connect('notify::active', self._on_auto_cleanup_toggle)
        auto_row.add_suffix(auto_switch)
        
        group.add(auto_row)
        
        interval_row = Adw.ActionRow()
        interval_row.set_title("Cleanup Interval")
        
        intervals = ["30 seconds", "1 minute", "2 minutes", "5 minutes", "10 minutes"]
        interval_values = [30, 60, 120, 300, 600]
        
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
        
        buttons_row = Adw.ActionRow()
        buttons_row.set_title("Manual Cleanup")
        buttons_row.set_subtitle("Run cleanup operations now")
        
        buttons_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        buttons_box.set_valign(Gtk.Align.CENTER)
        
        quick_btn = Gtk.Button(label="Quick Clean")
        quick_btn.add_css_class('suggested-action')
        quick_btn.set_tooltip_text("Clean zombies + drop caches")
        quick_btn.connect('clicked', lambda b: self._run_cleanup('quick'))
        buttons_box.append(quick_btn)
        
        deep_btn = Gtk.Button(label="Deep Clean")
        deep_btn.add_css_class('destructive-action')
        deep_btn.set_tooltip_text("Quick clean + clear swap + compact memory")
        deep_btn.connect('clicked', lambda b: self._run_cleanup('deep'))
        buttons_box.append(deep_btn)
        
        buttons_row.add_suffix(buttons_box)
        
        group.add(buttons_row)
        
        return group
    
    def _build_stats_group(self) -> Adw.PreferencesGroup:
        """Build system stats group"""
        group = Adw.PreferencesGroup()
        group.set_title("System Statistics")
        group.set_description("Real-time memory and process info")
        
        ram_row = Adw.ActionRow()
        ram_row.set_title("RAM Usage")
        
        ram_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        ram_box.set_valign(Gtk.Align.CENTER)
        
        self._ram_bar = Gtk.ProgressBar()
        self._ram_bar.set_size_request(120, -1)
        self._ram_bar.set_valign(Gtk.Align.CENTER)
        ram_box.append(self._ram_bar)
        
        self._ram_label = Gtk.Label()
        self._ram_label.add_css_class('dim-label')
        ram_box.append(self._ram_label)
        
        ram_row.add_suffix(ram_box)
        self._stats_labels['ram'] = (self._ram_bar, self._ram_label)
        group.add(ram_row)
        
        cache_row = Adw.ActionRow()
        cache_row.set_title("Cached Memory")
        cache_row.set_subtitle("Reclaimable page cache")
        
        self._cache_label = Gtk.Label()
        self._cache_label.add_css_class('dim-label')
        self._cache_label.set_valign(Gtk.Align.CENTER)
        cache_row.add_suffix(self._cache_label)
        self._stats_labels['cache'] = self._cache_label
        
        group.add(cache_row)
        
        swap_row = Adw.ActionRow()
        swap_row.set_title("Swap Usage")
        
        self._swap_label = Gtk.Label()
        self._swap_label.add_css_class('dim-label')
        self._swap_label.set_valign(Gtk.Align.CENTER)
        swap_row.add_suffix(self._swap_label)
        self._stats_labels['swap'] = self._swap_label
        
        group.add(swap_row)
        
        zombie_row = Adw.ActionRow()
        zombie_row.set_title("Zombie Processes")
        zombie_row.set_subtitle("Defunct processes waiting to be reaped")
        
        self._zombie_label = Gtk.Label()
        self._zombie_label.set_valign(Gtk.Align.CENTER)
        zombie_row.add_suffix(self._zombie_label)
        self._stats_labels['zombie'] = self._zombie_label
        
        group.add(zombie_row)
        
        self._update_stats_display()
        
        return group
    
    def _build_advanced_group(self) -> Adw.PreferencesGroup:
        """Build advanced options group"""
        group = Adw.PreferencesGroup()
        group.set_title("Advanced Options")
        
        gamemode_row = Adw.ActionRow()
        gamemode_row.set_title("GameMode")
        gamemode_row.set_subtitle("Auto performance boost for games")
        
        gamemode_installed = self._is_gamemode_installed()
        
        if gamemode_installed:
            gamemode_status = Gtk.Label(label="Installed ✓")
            gamemode_status.add_css_class('success')
        else:
            gamemode_status = Gtk.Label(label="Not installed")
            gamemode_status.add_css_class('dim-label')
        
        gamemode_status.set_valign(Gtk.Align.CENTER)
        gamemode_row.add_suffix(gamemode_status)
        
        group.add(gamemode_row)
        
        sleep_row = Adw.ActionRow()
        sleep_row.set_title("Prevent Sleep")
        sleep_row.set_subtitle("Keep system awake (for downloads, compiles)")
        
        sleep_switch = Gtk.Switch()
        sleep_switch.set_active(self.prefs.get('prevent_sleep', False))
        sleep_switch.set_valign(Gtk.Align.CENTER)
        sleep_switch.connect('notify::active', self._on_prevent_sleep_toggle)
        sleep_row.add_suffix(sleep_switch)
        
        group.add(sleep_row)
        
        tlp_row = Adw.ActionRow()
        tlp_row.set_title("TLP Quick Actions")
        
        tlp_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        tlp_box.set_valign(Gtk.Align.CENTER)
        
        tlp_bat_btn = Gtk.Button(label="Battery")
        tlp_bat_btn.set_tooltip_text("Force battery mode")
        tlp_bat_btn.connect('clicked', lambda b: self._set_tlp_mode('bat'))
        tlp_box.append(tlp_bat_btn)
        
        tlp_ac_btn = Gtk.Button(label="AC")
        tlp_ac_btn.set_tooltip_text("Force AC mode")
        tlp_ac_btn.connect('clicked', lambda b: self._set_tlp_mode('ac'))
        tlp_box.append(tlp_ac_btn)
        
        tlp_auto_btn = Gtk.Button(label="Auto")
        tlp_auto_btn.set_tooltip_text("Auto-detect power source")
        tlp_auto_btn.connect('clicked', lambda b: self._set_tlp_mode('auto'))
        tlp_box.append(tlp_auto_btn)
        
        tlp_row.add_suffix(tlp_box)
        
        group.add(tlp_row)
        
        return group
    
    # ==================== Profile Management ====================
    
    def _on_profile_toggled(self, check: Gtk.CheckButton, profile: dict):
        """Handle profile selection"""
        if not check.get_active():
            return
        
        governor = profile['governor']
        epp = profile.get('epp')
        profile_id = profile['id']
        
        for btn in self._profile_buttons.values():
            btn.set_sensitive(False)
        
        def set_profile_thread():
            success, message = CPUPowerManager.set_profile_sync(governor, epp)
            GLib.idle_add(self._on_profile_set_complete, success, profile_id, message)
        
        thread = threading.Thread(target=set_profile_thread, daemon=True)
        thread.start()
    
    def _on_profile_set_complete(self, success: bool, profile_id: str, message: str):
        """Called when profile change completes"""
        for btn in self._profile_buttons.values():
            btn.set_sensitive(True)
        
        if success:
            self.prefs.set_current_profile(profile_id)
            self._show_toast(f"Profile set: {message}")
            
            self._driver_info = CPUPowerManager.get_driver_info()
            self._governor_label.set_text(self._driver_info.get('current_governor', 'unknown'))
            
            if hasattr(self, '_epp_label') and self._driver_info.get('epp_available'):
                self._epp_label.set_text(f"| EPP: {self._driver_info.get('current_epp', 'unknown')}")
        else:
            self._show_toast(f"Failed: {message}")
            self._driver_info = CPUPowerManager.get_driver_info()
            profiles = CPUPowerManager.get_profile_mapping(self._driver_info)
            current_profile = self._detect_current_profile(
                profiles,
                self._driver_info.get('current_governor', ''),
                self._driver_info.get('current_epp', '')
            )
            if current_profile in self._profile_buttons:
                self._profile_buttons[current_profile].set_active(True)
        
        return False
    
    # ==================== Stats & Monitoring ====================
    
    def _get_system_stats(self) -> SystemStats:
        """Gather all system statistics"""
        stats = SystemStats()
        
        try:
            meminfo = {}
            with open('/proc/meminfo', 'r') as f:
                for line in f:
                    parts = line.split(':')
                    if len(parts) == 2:
                        key = parts[0].strip()
                        value = parts[1].strip().split()[0]
                        meminfo[key] = int(value)
            
            total_kb = meminfo.get('MemTotal', 0)
            available_kb = meminfo.get('MemAvailable', 0)
            used_kb = total_kb - available_kb
            cached_kb = meminfo.get('Cached', 0) + meminfo.get('Buffers', 0)
            
            stats.ram_total = self._format_bytes(total_kb * 1024)
            stats.ram_used = self._format_bytes(used_kb * 1024)
            stats.ram_percent = (used_kb / total_kb * 100) if total_kb > 0 else 0
            stats.cache_size = self._format_bytes(cached_kb * 1024)
            
            swap_total_kb = meminfo.get('SwapTotal', 0)
            swap_free_kb = meminfo.get('SwapFree', 0)
            swap_used_kb = swap_total_kb - swap_free_kb
            
            stats.swap_total = self._format_bytes(swap_total_kb * 1024)
            stats.swap_used = self._format_bytes(swap_used_kb * 1024)
            
        except Exception as e:
            print(f"Error reading meminfo: {e}")
        
        stats.zombie_count = self._count_zombies()
        
        driver_info = CPUPowerManager.get_driver_info()
        stats.cpu_governor = driver_info.get('current_governor', 'unknown')
        
        battery_info = self._get_battery_info()
        if battery_info:
            stats.battery_percent = battery_info[0]
            stats.battery_charging = battery_info[1]
        
        stats.tlp_mode = self._get_tlp_mode()
        
        return stats
    
    def _count_zombies(self) -> int:
        """Count zombie processes"""
        try:
            result = subprocess.run(
                ['ps', '-eo', 'stat'],
                capture_output=True,
                text=True,
                timeout=2
            )
            
            count = 0
            for line in result.stdout.split('\n'):
                if line.strip().startswith('Z'):
                    count += 1
            
            return count
            
        except:
            return 0
    
    def _format_bytes(self, bytes_val: int) -> str:
        """Format bytes to human readable"""
        for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
            if abs(bytes_val) < 1024.0:
                return f"{bytes_val:.1f} {unit}"
            bytes_val /= 1024.0
        return f"{bytes_val:.1f} PB"
    
    def _get_battery_info(self) -> Optional[Tuple[int, bool]]:
        """Get battery percentage and charging status"""
        for bat in ['BAT0', 'BAT1', 'BAT2']:
            bat_path = Path(f"/sys/class/power_supply/{bat}")
            if bat_path.exists():
                try:
                    capacity = int((bat_path / "capacity").read_text().strip())
                    status = (bat_path / "status").read_text().strip()
                    charging = status in ['Charging', 'Full']
                    return (capacity, charging)
                except:
                    pass
        return None
    
    def _get_tlp_mode(self) -> str:
        """Get current TLP power mode"""
        try:
            result = subprocess.run(
                ['tlp-stat', '-s'],
                capture_output=True,
                text=True,
                timeout=2
            )
            
            for line in result.stdout.split('\n'):
                if 'Mode' in line and '=' in line:
                    return line.split('=')[-1].strip()
                    
        except:
            pass
        
        return "unknown"
    
    def _set_tlp_mode(self, mode: str):
        """Set TLP mode manually"""
        def tlp_thread():
            try:
                if mode == 'bat':
                    cmd = ['tlp', 'bat']
                elif mode == 'ac':
                    cmd = ['tlp', 'ac']
                else:
                    cmd = ['tlp', 'start']
                
                result = subprocess.run(['sudo', '-n'] + cmd, capture_output=True, timeout=5)
                if result.returncode == 0:
                    GLib.idle_add(self._show_toast, f"TLP mode: {mode}")
                    GLib.idle_add(self._update_battery_display)
                    return
                
                result = subprocess.run(['pkexec'] + cmd, capture_output=True, timeout=30)
                if result.returncode == 0:
                    GLib.idle_add(self._show_toast, f"TLP mode: {mode}")
                    GLib.idle_add(self._update_battery_display)
                else:
                    GLib.idle_add(self._show_toast, "TLP: permission denied")
                    
            except Exception as e:
                GLib.idle_add(self._show_toast, f"TLP error: {e}")
        
        thread = threading.Thread(target=tlp_thread, daemon=True)
        thread.start()
    
    def _is_gamemode_installed(self) -> bool:
        """Check if GameMode is installed"""
        try:
            result = subprocess.run(
                ['which', 'gamemoded'],
                capture_output=True,
                timeout=2
            )
            return result.returncode == 0
        except:
            return False
    
    def _update_stats_display(self):
        """Update all stats displays"""
        stats = self._get_system_stats()
        
        self._ram_bar.set_fraction(stats.ram_percent / 100)
        self._ram_label.set_text(f"{stats.ram_used} / {stats.ram_total}")
        
        self._cache_label.set_text(stats.cache_size)
        
        self._swap_label.set_text(f"{stats.swap_used} / {stats.swap_total}")
        
        zombie_count = stats.zombie_count
        if zombie_count == 0:
            self._zombie_label.set_text("None ✓")
            self._zombie_label.remove_css_class('error')
            self._zombie_label.add_css_class('success')
        else:
            self._zombie_label.set_text(f"{zombie_count} found")
            self._zombie_label.remove_css_class('success')
            self._zombie_label.add_css_class('error')
        
        self._governor_label.set_text(stats.cpu_governor)
        
        self._update_battery_display()
    
    def _update_battery_display(self):
        """Update battery display"""
        if not hasattr(self, '_battery_label'):
            return
        
        battery_info = self._get_battery_info()
        
        if battery_info:
            percent, charging = battery_info
            
            self._battery_label.set_text(f"{percent}%")
            
            if charging:
                icon_name = "battery-level-100-charging-symbolic"
            elif percent > 80:
                icon_name = "battery-level-100-symbolic"
            elif percent > 50:
                icon_name = "battery-level-50-symbolic"
            elif percent > 20:
                icon_name = "battery-level-20-symbolic"
            else:
                icon_name = "battery-level-10-symbolic"
            
            self._battery_icon.set_from_icon_name(icon_name)
            
            tlp_mode = self._get_tlp_mode()
            if hasattr(self, '_tlp_label'):
                self._tlp_label.set_text(tlp_mode.upper() if tlp_mode != "unknown" else "Auto")
    
    def _start_stats_timer(self):
        """Start stats update timer"""
        self._stats_timer_id = GLib.timeout_add_seconds(5, self._stats_timer_callback)
    
    def _stats_timer_callback(self) -> bool:
        """Stats timer callback"""
        self._update_stats_display()
        return True
    
    # ==================== Cleanup Operations ====================
    
    def _on_auto_cleanup_toggle(self, switch, _):
        """Handle auto cleanup toggle"""
        enabled = switch.get_active()
        self.prefs.set('cleanup_enabled', enabled)
        
        if enabled:
            self._start_cleanup_timer()
            self._show_toast("Auto cleanup enabled")
        else:
            self._stop_cleanup_timer()
            self._show_toast("Auto cleanup disabled")
    
    def _on_interval_change(self, interval: int):
        """Handle interval change"""
        self.prefs.set('cleanup_interval', interval)
        
        if self.prefs.get('cleanup_enabled', False):
            self._stop_cleanup_timer()
            self._start_cleanup_timer()
    
    def _start_cleanup_timer(self):
        """Start cleanup timer"""
        interval = self.prefs.get('cleanup_interval', 60)
        self._cleanup_timer_id = GLib.timeout_add_seconds(interval, self._cleanup_timer_callback)
    
    def _stop_cleanup_timer(self):
        """Stop cleanup timer"""
        if self._cleanup_timer_id:
            GLib.source_remove(self._cleanup_timer_id)
            self._cleanup_timer_id = None
    
    def _cleanup_timer_callback(self) -> bool:
        """Cleanup timer callback"""
        self._run_cleanup('quick', silent=True)
        return True
    
    def _run_cleanup(self, mode: str = 'quick', silent: bool = False):
        """Run cleanup operation"""
        def cleanup_thread():
            try:
                script_path = Path.home() / ".config/hypr-control-center/scripts/power-cleanup.sh"
                script_path.parent.mkdir(parents=True, exist_ok=True)
                
                self._create_cleanup_script(script_path)
                
                result = subprocess.run(
                    ['bash', str(script_path), mode],
                    capture_output=True,
                    text=True,
                    timeout=60
                )
                
                if not silent:
                    output = result.stdout
                    if "Freed" in output or "Cleaned" in output:
                        lines = output.strip().split('\n')
                        summary = lines[-1] if lines else "Cleanup complete"
                        GLib.idle_add(self._show_toast, summary)
                    else:
                        GLib.idle_add(self._show_toast, "System is clean!")
                
                GLib.idle_add(self._update_stats_display)
                
            except subprocess.TimeoutExpired:
                if not silent:
                    GLib.idle_add(self._show_toast, "Cleanup timed out")
            except Exception as e:
                if not silent:
                    GLib.idle_add(self._show_toast, f"Cleanup error: {e}")
        
        if not silent:
            self._show_toast(f"Running {mode} cleanup...")
        
        thread = threading.Thread(target=cleanup_thread, daemon=True)
        thread.start()
    
    def _create_cleanup_script(self, script_path: Path):
        """Create cleanup script"""
        script = '''#!/bin/bash
MODE="${1:-quick}"
CLEANED=0
FREED_MB=0

cleanup_zombies() {
    ZOMBIE_PIDS=$(ps -eo pid,stat | awk '$2 ~ /^Z/ {print $1}')
    ZOMBIE_COUNT=$(echo "$ZOMBIE_PIDS" | grep -c '[0-9]' 2>/dev/null || echo 0)
    
    if [ "$ZOMBIE_COUNT" -eq 0 ] || [ -z "$ZOMBIE_PIDS" ]; then
        return 0
    fi
    
    for PID in $ZOMBIE_PIDS; do
        [ -z "$PID" ] && continue
        PPID=$(ps -o ppid= -p "$PID" 2>/dev/null | tr -d ' ')
        
        if [ -n "$PPID" ] && [ "$PPID" != "1" ] && [ "$PPID" != "0" ]; then
            PNAME=$(ps -o comm= -p "$PPID" 2>/dev/null)
            case "$PNAME" in
                systemd|init|kthreadd|rcu*|watchdog*) continue ;;
            esac
            kill -SIGCHLD "$PPID" 2>/dev/null
            ((CLEANED++))
        fi
    done
}

cleanup_caches() {
    CACHE_BEFORE=$(grep -E "^(Cached|Buffers):" /proc/meminfo | awk '{sum += $2} END {print sum}')
    sync
    sudo -n sh -c 'echo 3 > /proc/sys/vm/drop_caches' 2>/dev/null
    CACHE_AFTER=$(grep -E "^(Cached|Buffers):" /proc/meminfo | awk '{sum += $2} END {print sum}')
    
    if [ -n "$CACHE_BEFORE" ] && [ -n "$CACHE_AFTER" ]; then
        FREED_KB=$((CACHE_BEFORE - CACHE_AFTER))
        [ "$FREED_KB" -gt 0 ] && FREED_MB=$((FREED_KB / 1024))
    fi
}

cleanup_swap() {
    SWAP_USED=$(free -m | awk '/^Swap:/ {print $3}')
    [ "$SWAP_USED" -eq 0 ] && return 0
    
    FREE_RAM=$(free -m | awk '/^Mem:/ {print $7}')
    if [ "$FREE_RAM" -gt "$SWAP_USED" ]; then
        sudo -n swapoff -a 2>/dev/null && sudo -n swapon -a 2>/dev/null
    fi
}

compact_memory() {
    [ -f /proc/sys/vm/compact_memory ] && \
        sudo -n sh -c 'echo 1 > /proc/sys/vm/compact_memory' 2>/dev/null
}

cleanup_zombies
cleanup_caches

if [ "$MODE" = "deep" ]; then
    cleanup_swap
    compact_memory
fi

echo "Cleanup complete: $CLEANED zombies handled, ~${FREED_MB}MB freed"
'''
        script_path.write_text(script)
        script_path.chmod(0o755)
    
    def _on_prevent_sleep_toggle(self, switch, _):
        """Handle prevent sleep toggle"""
        prevent = switch.get_active()
        self.prefs.set('prevent_sleep', prevent)
        
        try:
            if prevent:
                subprocess.Popen([
                    'systemd-inhibit',
                    '--what=sleep:idle:handle-lid-switch',
                    '--who=hypr-control-center',
                    '--why=User requested',
                    '--mode=block',
                    'sleep', 'infinity'
                ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                self._show_toast("Sleep prevention enabled")
            else:
                subprocess.run(
                    ['pkill', '-f', 'systemd-inhibit.*hypr-control-center'],
                    check=False
                )
                self._show_toast("Sleep prevention disabled")
        except Exception as e:
            self._show_toast(f"Error: {e}")
    
    def _show_toast(self, message: str):
        """Show toast notification"""
        if hasattr(self.window, '_show_toast'):
            self.window._show_toast(message)
        elif hasattr(self.window, 'add_toast'):
            toast = Adw.Toast.new(message)
            self.window.add_toast(toast)
        else:
            print(f"[Toast] {message}")
    
    def cleanup(self):
        """Cleanup timers on page destroy"""
        self._stop_cleanup_timer()
        if self._stats_timer_id:
            GLib.source_remove(self._stats_timer_id)
            self._stats_timer_id = None


def build_power_page(window) -> Gtk.Box:
    """Build power page (factory function)"""
    page_builder = PowerPage(window)
    return page_builder.build()