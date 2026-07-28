#!/usr/bin/env python3
"""
Wi-Fi Selector for Hyprland Control Center
GTK4/Libadwaita implementation with integrated styling
"""

import gi
import subprocess
import os
import sys
import signal
import json

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Gtk, Adw, Gio, GLib

LOCK_FILE = "/tmp/wifi_selector.pid"
CONFIG_DIR = os.path.expanduser("~/.config/hypr-control-center")
STYLE_CSS = os.path.join(CONFIG_DIR, "assets/style.css")

class WiFiSelectorWindow(Adw.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app)
        
        # Window setup
        self.set_title("Wi-Fi Selector")
        self.set_default_size(420, 500)
        self.set_resizable(False)
        
        # Main layout
        self.main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.set_content(self.main_box)
        
        # Header bar
        self.setup_header()
        
        # Content area
        self.setup_content()
        
        # Load custom CSS if available
        self.load_custom_css()
        
        # Initial refresh
        self.refresh_wifi_list()
    
    def setup_header(self):
        """Setup header bar with close button"""
        header = Adw.HeaderBar()
        header.set_show_end_title_buttons(False)
        header.set_show_start_title_buttons(False)
        
        # Title
        title_label = Gtk.Label(label="Wi-Fi Networks")
        title_label.add_css_class("title-3")
        header.set_title_widget(title_label)
        
        # Refresh button
        refresh_btn = Gtk.Button()
        refresh_btn.set_icon_name("view-refresh-symbolic")
        refresh_btn.add_css_class("flat")
        refresh_btn.set_tooltip_text("Refresh networks")
        refresh_btn.connect("clicked", lambda w: self.refresh_wifi_list())
        header.pack_start(refresh_btn)
        
        # Close button
        close_btn = Gtk.Button()
        close_btn.set_icon_name("window-close-symbolic")
        close_btn.add_css_class("flat")
        close_btn.set_tooltip_text("Close")
        close_btn.connect("clicked", lambda w: self.close())
        header.pack_end(close_btn)
        
        self.main_box.append(header)
    
    def setup_content(self):
        """Setup scrolled content area"""
        # Scrolled window
        scrolled = Gtk.ScrolledWindow()
        scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scrolled.set_vexpand(True)
        scrolled.set_hexpand(True)
        
        # Main content box
        self.content_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        self.content_box.set_margin_top(12)
        self.content_box.set_margin_bottom(12)
        self.content_box.set_margin_start(12)
        self.content_box.set_margin_end(12)
        
        scrolled.set_child(self.content_box)
        self.main_box.append(scrolled)
    
    def load_custom_css(self):
        """Load custom CSS from Control Center assets"""
        css_provider = Gtk.CssProvider()
        
        # Try to load Control Center CSS
        if os.path.exists(STYLE_CSS):
            try:
                css_provider.load_from_path(STYLE_CSS)
            except Exception as e:
                print(f"Could not load custom CSS: {e}")
        
        # Add default WiFi selector CSS
        default_css = """
        /* Wi-Fi Selector Styles */
        .wifi-card {
            background: alpha(currentColor, 0.05);
            border-radius: 12px;
            padding: 8px;
            margin: 4px 0;
        }
        
        .wifi-card:hover {
            background: alpha(currentColor, 0.08);
        }
        
        .wifi-ssid {
            font-weight: bold;
            font-size: 14px;
        }
        
        .wifi-active {
            color: @accent_color;
        }
        
        .wifi-signal {
            font-size: 12px;
            opacity: 0.7;
        }
        
        .wifi-security {
            font-size: 12px;
            opacity: 0.5;
        }
        
        .section-header {
            font-weight: bold;
            font-size: 12px;
            opacity: 0.7;
            margin-top: 8px;
            margin-bottom: 4px;
        }
        
        .forget-button {
            min-width: 32px;
            min-height: 32px;
        }
        """
        
        css_provider.load_from_data(default_css.encode())
        Gtk.StyleContext.add_provider_for_display(
            self.get_display(),
            css_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )
    
    def refresh_wifi_list(self):
        """Refresh the list of Wi-Fi networks"""
        # Clear existing content
        while self.content_box.get_first_child():
            self.content_box.remove(self.content_box.get_first_child())
        
        # Get network information
        current_ssid = self.get_current_wifi()
        saved_ssids = self.get_saved_networks()
        networks = self.scan_wifi()
        
        # Saved Networks Section
        if saved_ssids:
            saved_header = Gtk.Label(label="SAVED NETWORKS")
            saved_header.set_halign(Gtk.Align.START)
            saved_header.add_css_class("section-header")
            self.content_box.append(saved_header)
            
            for ssid in saved_ssids:
                card = self.create_network_card(
                    ssid, 
                    security="--", 
                    signal=100,
                    is_current=(ssid == current_ssid),
                    is_saved=True
                )
                self.content_box.append(card)
        
        # Available Networks Section
        other_networks = [n for n in networks if n["ssid"] not in saved_ssids and n["ssid"]]
        
        if other_networks:
            available_header = Gtk.Label(label="AVAILABLE NETWORKS")
            available_header.set_halign(Gtk.Align.START)
            available_header.add_css_class("section-header")
            available_header.set_margin_top(16)
            self.content_box.append(available_header)
            
            for net in other_networks:
                card = self.create_network_card(
                    net["ssid"],
                    security=net["security"],
                    signal=net["signal"],
                    is_current=(net["ssid"] == current_ssid),
                    is_saved=False
                )
                self.content_box.append(card)
    
    def create_network_card(self, ssid, security, signal, is_current, is_saved):
        """Create a network card widget"""
        # Main card box
        card = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        card.add_css_class("wifi-card")
        card.set_halign(Gtk.Align.FILL)
        
        # Left side: Network info button
        info_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        info_box.set_hexpand(True)
        
        # SSID label
        ssid_label = Gtk.Label(label=ssid)
        ssid_label.set_halign(Gtk.Align.START)
        ssid_label.add_css_class("wifi-ssid")
        if is_current:
            ssid_label.add_css_class("wifi-active")
        info_box.append(ssid_label)
        
        # Details box (signal + security)
        details_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        
        # Signal strength
        signal_icon = self.get_signal_icon(signal)
        signal_label = Gtk.Label(label=f"{signal_icon} {signal}%")
        signal_label.add_css_class("wifi-signal")
        details_box.append(signal_label)
        
        # Security
        if security and security != "--":
            security_label = Gtk.Label(label=f"🔒 {security}")
            security_label.add_css_class("wifi-security")
            details_box.append(security_label)
        
        info_box.append(details_box)
        
        # Connect button
        connect_btn = Gtk.Button()
        connect_btn.set_child(info_box)
        connect_btn.add_css_class("flat")
        connect_btn.set_hexpand(True)
        connect_btn.connect("clicked", lambda w: self.connect_wifi(ssid, security, is_saved))
        card.append(connect_btn)
        
        # Right side: Forget button (only for saved networks)
        if is_saved:
            forget_btn = Gtk.Button()
            forget_btn.set_icon_name("user-trash-symbolic")
            forget_btn.add_css_class("destructive-action")
            forget_btn.add_css_class("forget-button")
            forget_btn.set_tooltip_text("Forget network")
            forget_btn.connect("clicked", lambda w: self.forget_wifi(ssid))
            card.append(forget_btn)
        
        return card
    
    def get_signal_icon(self, signal):
        """Get appropriate signal strength icon"""
        if signal >= 80:
            return "📶"
        elif signal >= 60:
            return "📶"
        elif signal >= 40:
            return "📶"
        else:
            return "📶"
    
    def connect_wifi(self, ssid, security, is_saved):
        """Connect to a Wi-Fi network"""
        if is_saved:
            # Already saved, just connect
            subprocess.run(["nmcli", "connection", "up", ssid])
            GLib.timeout_add(1000, self.refresh_wifi_list)
        else:
            # Need password for secured networks
            if security and security != "--":
                self.show_password_dialog(ssid)
            else:
                # Open network
                subprocess.run(["nmcli", "device", "wifi", "connect", ssid])
                GLib.timeout_add(1000, self.refresh_wifi_list)
    
    def show_password_dialog(self, ssid):
        """Show password entry dialog"""
        dialog = Adw.MessageDialog.new(self)
        dialog.set_heading(f"Connect to {ssid}")
        dialog.set_body("Enter the network password")
        
        # Password entry
        entry = Gtk.PasswordEntry()
        entry.set_show_peek_icon(True)
        entry.set_hexpand(True)
        entry.set_margin_top(12)
        entry.set_margin_bottom(12)
        entry.set_margin_start(12)
        entry.set_margin_end(12)
        
        dialog.set_extra_child(entry)
        
        # Buttons
        dialog.add_response("cancel", "Cancel")
        dialog.add_response("connect", "Connect")
        dialog.set_response_appearance("connect", Adw.ResponseAppearance.SUGGESTED)
        dialog.set_default_response("connect")
        dialog.set_close_response("cancel")
        
        # Handle response
        def on_response(dialog, response):
            if response == "connect":
                password = entry.get_text()
                if password:
                    subprocess.run([
                        "nmcli", "device", "wifi", "connect", ssid,
                        "password", password
                    ])
                    GLib.timeout_add(1000, self.refresh_wifi_list)
        
        dialog.connect("response", on_response)
        dialog.present()
    
    def forget_wifi(self, ssid):
        """Forget a saved network"""
        dialog = Adw.MessageDialog.new(self)
        dialog.set_heading("Forget Network?")
        dialog.set_body(f"Remove saved connection for '{ssid}'?")
        
        dialog.add_response("cancel", "Cancel")
        dialog.add_response("forget", "Forget")
        dialog.set_response_appearance("forget", Adw.ResponseAppearance.DESTRUCTIVE)
        dialog.set_default_response("forget")
        dialog.set_close_response("cancel")
        
        def on_response(dialog, response):
            if response == "forget":
                subprocess.run(["nmcli", "connection", "delete", ssid])
                self.refresh_wifi_list()
        
        dialog.connect("response", on_response)
        dialog.present()
    
    # Network scanning functions
    def scan_wifi(self):
        """Scan for available Wi-Fi networks"""
        try:
            output = subprocess.run(
                ["nmcli", "-t", "-f", "SSID,SECURITY,SIGNAL", "device", "wifi", "list"],
                capture_output=True, text=True, check=True
            ).stdout
            
            networks = []
            for line in output.strip().split("\n"):
                if not line.strip():
                    continue
                parts = line.split(":")
                ssid = parts[0].strip()
                sec = parts[1].strip() if len(parts) > 1 else "--"
                sig = int(parts[2].strip()) if len(parts) > 2 else 0
                
                if ssid:  # Skip empty SSIDs
                    networks.append({
                        "ssid": ssid,
                        "security": sec,
                        "signal": sig
                    })
            
            # Sort by signal strength
            networks.sort(key=lambda x: x["signal"], reverse=True)
            return networks
        except subprocess.CalledProcessError:
            return []
    
    def get_current_wifi(self):
        """Get currently connected Wi-Fi SSID"""
        try:
            output = subprocess.run(
                ["nmcli", "-t", "-f", "ACTIVE,SSID", "device", "wifi"],
                capture_output=True, text=True, check=True
            ).stdout
            
            for line in output.strip().split("\n"):
                if line.startswith("yes:"):
                    return line.split(":", 1)[1].strip()
            return ""
        except subprocess.CalledProcessError:
            return ""
    
    def get_saved_networks(self):
        """Get list of saved Wi-Fi networks"""
        try:
            output = subprocess.run(
                ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"],
                capture_output=True, text=True, check=True
            ).stdout
            
            saved = []
            for line in output.strip().split("\n"):
                parts = line.split(":")
                name = parts[0].strip()
                type_ = parts[1].strip() if len(parts) > 1 else ""
                
                if type_ == "802-11-wireless":
                    saved.append(name)
            
            return saved
        except subprocess.CalledProcessError:
            return []


class WiFiSelectorApp(Adw.Application):
    def __init__(self):
        super().__init__(
            application_id="com.hyprland.wifi-selector",
            flags=Gio.ApplicationFlags.FLAGS_NONE
        )
        self.window = None
    
    def do_activate(self):
        if not self.window:
            self.window = WiFiSelectorWindow(self)
        self.window.present()


def main():
    # Toggle setup - close if already running
    if os.path.exists(LOCK_FILE):
        with open(LOCK_FILE, "r") as f:
            try:
                pid = int(f.read())
                os.kill(pid, signal.SIGTERM)
                os.remove(LOCK_FILE)
                sys.exit(0)
            except (ProcessLookupError, ValueError):
                os.remove(LOCK_FILE)
    
    # Write PID
    with open(LOCK_FILE, "w") as f:
        f.write(str(os.getpid()))
    
    # Cleanup on exit
    def cleanup(*args):
        if os.path.exists(LOCK_FILE):
            os.remove(LOCK_FILE)
        sys.exit(0)
    
    signal.signal(signal.SIGTERM, cleanup)
    signal.signal(signal.SIGINT, cleanup)
    
    # Run app
    app = WiFiSelectorApp()
    try:
        app.run(sys.argv)
    finally:
        cleanup()


if __name__ == "__main__":
    main()