#!/usr/bin/env python3
# ~/.config/hypr-control-center/widgets/system_monitor_widget.py
"""
System Monitor - Windows 11 Task Manager Style with Live Graphs
Supports: AMD Radeon, NVIDIA, Intel GPUs
"""

import gi
gi.require_version('Gtk', '4.0')
from gi.repository import Gtk, GLib
import subprocess
import psutil
import re
from collections import deque
from pathlib import Path
from base_widget import BaseWidget


class GraphWidget(Gtk.DrawingArea):
    """Custom widget for drawing graphs"""
    def __init__(self, max_points=60):
        super().__init__()
        self.data = deque([0] * max_points, maxlen=max_points)
        self.set_content_width(230)
        self.set_content_height(80)
        self.set_draw_func(self._draw)
        
    def add_data_point(self, value):
        """Add new data point"""
        self.data.append(max(0, min(100, value)))
        self.queue_draw()
        
    def _draw(self, area, cr, width, height):
        """Draw the graph"""
        # Background
        cr.set_source_rgba(0.18, 0.18, 0.19, 0.6)
        cr.rectangle(0, 0, width, height)
        cr.fill()
        
        if len(self.data) < 2:
            return
            
        # Draw grid lines
        cr.set_source_rgba(1, 1, 1, 0.05)
        cr.set_line_width(1)
        for i in range(5):
            y = (height / 4) * i
            cr.move_to(0, y)
            cr.line_to(width, y)
            cr.stroke()
        
        # Draw graph line
        cr.set_source_rgba(0.04, 0.52, 1.0, 0.8)
        cr.set_line_width(1.5)
        
        points = list(self.data)
        x_step = width / (len(points) - 1)
        
        first_point = 100 - points[0]
        cr.move_to(0, (first_point / 100) * height)
        
        for i, value in enumerate(points):
            x = i * x_step
            y = ((100 - value) / 100) * height
            cr.line_to(x, y)
        
        cr.stroke_preserve()
        
        # Fill under curve
        cr.line_to(width, height)
        cr.line_to(0, height)
        cr.close_path()
        cr.set_source_rgba(0.04, 0.52, 1.0, 0.3)
        cr.fill()


class SystemMonitorWidget(BaseWidget):
    def __init__(self):
        super().__init__("system_monitor")
        
        # Auto-detect hardware
        self.cpu_name = self.detect_cpu()
        self.gpu_name, self.gpu_type = self.detect_gpu()
        
        print(f"[sysmon] 🖥️  CPU: {self.cpu_name}")
        print(f"[sysmon] 🎮 GPU: {self.gpu_name} ({self.gpu_type})")
        
        # Main container
        container = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        container.add_css_class("widget-container")
        container.add_css_class("system-monitor-modern")
        
        # Header
        header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        header.add_css_class("monitor-header")
        
        title = Gtk.Label(label="SYSTEM MONITOR")
        title.add_css_class("monitor-title-main")
        title.set_halign(Gtk.Align.START)
        title.set_hexpand(True)
        header.append(title)
        
        container.append(header)
        
        # Grid (2x2)
        grid = Gtk.Grid()
        grid.add_css_class("monitor-grid")
        grid.set_column_spacing(12)
        grid.set_row_spacing(12)
        
        # Cards
        self.cpu_card = self.create_card_with_graph(self.cpu_name, "CPU")
        grid.attach(self.cpu_card['widget'], 0, 0, 1, 1)
        
        self.gpu_card = self.create_card_with_graph(self.gpu_name, "GPU")
        grid.attach(self.gpu_card['widget'], 1, 0, 1, 1)
        
        self.ram_card = self.create_card_with_graph("RAM", "MEMORY")
        grid.attach(self.ram_card['widget'], 0, 1, 1, 1)
        
        self.network_card = self.create_card_with_graph("NETWORK", "CONNECTION")
        grid.attach(self.network_card['widget'], 1, 1, 1, 1)
        
        container.append(grid)
        self.set_child(container)
        
        # Network tracking
        self.prev_net_io = None
        
        # Update every second
        self.update_stats()
        GLib.timeout_add(1000, self.update_stats)
        
    def detect_cpu(self):
        """Auto-detect CPU"""
        try:
            with open('/proc/cpuinfo', 'r') as f:
                for line in f:
                    if 'model name' in line:
                        cpu = line.split(':')[1].strip()
                        cpu = cpu.replace('(R)', '').replace('(TM)', '')
                        cpu = re.sub(r'\s+', ' ', cpu)
                        
                        if 'AMD' in cpu:
                            parts = cpu.split()
                            for i, part in enumerate(parts):
                                if 'Ryzen' in part and i+2 < len(parts):
                                    return f"AMD {parts[i]} {parts[i+1]} {parts[i+2]}..."
                        elif 'Intel' in cpu:
                            parts = cpu.split()
                            for i, part in enumerate(parts):
                                if 'Core' in part and i+1 < len(parts):
                                    return f"Intel {part} {parts[i+1]}"
                        
                        return cpu[:25] + "..."
        except:
            pass
        return "CPU"
        
    def detect_gpu(self):
        """Auto-detect GPU - AMD, NVIDIA, Intel"""
        
        # Try NVIDIA first
        try:
            result = subprocess.run(
                ['nvidia-smi', '--query-gpu=name', '--format=csv,noheader'],
                capture_output=True, text=True, timeout=2
            )
            if result.returncode == 0 and result.stdout.strip():
                gpu = result.stdout.strip()
                name = gpu.replace('NVIDIA GeForce ', '').replace('NVIDIA ', '')
                return name[:18] + "...", "nvidia"
        except:
            pass
        
        # Try AMD via AMDGPU
        try:
            # Check for AMD GPU via DRM
            amd_cards = list(Path('/sys/class/drm').glob('card*/device/vendor'))
            for vendor_file in amd_cards:
                vendor = vendor_file.read_text().strip()
                if vendor == '0x1002':  # AMD vendor ID
                    # Get GPU name from marketing name or device ID
                    card_dir = vendor_file.parent.parent
                    
                    # Try marketing name
                    marketing_name = card_dir / 'device' / 'product_name'
                    if marketing_name.exists():
                        name = marketing_name.read_text().strip()
                        return name[:18] + "...", "amd"
                    
                    # Fallback to lspci
                    result = subprocess.run(['lspci'], capture_output=True, text=True, timeout=2)
                    for line in result.stdout.split('\n'):
                        if 'VGA' in line or 'Display' in line:
                            if 'AMD' in line or 'Radeon' in line:
                                # Extract model
                                match = re.search(r'(Radeon\s+RX\s+\d+\s*\w*|RX\s+\d+\s*\w*)', line)
                                if match:
                                    return match.group(1)[:18] + "...", "amd"
                                match = re.search(r'\[(.+?)\]', line)
                                if match:
                                    return match.group(1)[:18] + "...", "amd"
                    
                    return "AMD Radeon", "amd"
        except:
            pass
        
        # Try lspci fallback
        try:
            result = subprocess.run(['lspci'], capture_output=True, text=True, timeout=2)
            if result.returncode == 0:
                for line in result.stdout.split('\n'):
                    if 'VGA' in line or 'Display' in line:
                        if 'AMD' in line or 'Radeon' in line:
                            match = re.search(r'(Radeon\s+RX\s+\d+\s*\w*|RX\s+\d+\s*\w*)', line)
                            if match:
                                return match.group(1)[:18] + "...", "amd"
                            return "AMD Radeon", "amd"
                        elif 'NVIDIA' in line:
                            return "NVIDIA GPU", "nvidia"
                        elif 'Intel' in line:
                            match = re.search(r'(HD|UHD|Iris).*?(\d+)?', line)
                            if match:
                                return f"Intel {match.group(0)}"[:18], "intel"
        except:
            pass
            
        return "GPU", "unknown"
        
    def create_card_with_graph(self, title, subtitle):
        """Create card with live graph"""
        card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        card.add_css_class("monitor-card")
        card.set_size_request(250, 180)
        
        # Header
        header = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        header.add_css_class("monitor-card-header")
        
        title_label = Gtk.Label(label=title)
        title_label.add_css_class("monitor-card-title")
        title_label.set_halign(Gtk.Align.START)
        title_label.set_ellipsize(3)
        title_label.set_max_width_chars(22)
        header.append(title_label)
        
        card.append(header)
        
        # Graph
        graph = GraphWidget()
        card.append(graph)
        
        # Stats row
        stats_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=30)
        stats_row.set_halign(Gtk.Align.START)
        
        # Left stat
        left_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        left_label = Gtk.Label(label=subtitle)
        left_label.add_css_class("monitor-card-subtitle")
        left_label.set_halign(Gtk.Align.START)
        left_box.append(left_label)
        
        left_value = Gtk.Label()
        left_value.add_css_class("monitor-card-value")
        left_value.set_halign(Gtk.Align.START)
        left_box.append(left_value)
        
        stats_row.append(left_box)
        
        # Right stat
        right_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        right_label = Gtk.Label(label="USAGE")
        right_label.add_css_class("monitor-card-subtitle")
        right_label.set_halign(Gtk.Align.START)
        right_box.append(right_label)
        
        right_value = Gtk.Label()
        right_value.add_css_class("monitor-card-value")
        right_value.set_halign(Gtk.Align.START)
        right_box.append(right_value)
        
        stats_row.append(right_box)
        
        card.append(stats_row)
        
        return {
            'widget': card,
            'graph': graph,
            'left_value': left_value,
            'right_value': right_value
        }
        
    def update_stats(self):
        """Update all stats"""
        try:
            # CPU
            cpu_percent = psutil.cpu_percent(interval=0.1)
            cpu_temp = self.get_cpu_temp()
            self.cpu_card['graph'].add_data_point(cpu_percent)
            self.cpu_card['left_value'].set_text(cpu_temp)
            self.cpu_card['right_value'].set_text(f"{cpu_percent:.0f}%")
            
            # GPU
            gpu_temp, gpu_usage = self.get_gpu_stats()
            try:
                gpu_percent = float(gpu_usage.replace('%', '')) if '%' in gpu_usage else 0
            except:
                gpu_percent = 0
            self.gpu_card['graph'].add_data_point(gpu_percent)
            self.gpu_card['left_value'].set_text(gpu_temp)
            self.gpu_card['right_value'].set_text(gpu_usage)
            
            # RAM
            mem = psutil.virtual_memory()
            mem_used = mem.used / (1024**3)
            self.ram_card['graph'].add_data_point(mem.percent)
            self.ram_card['left_value'].set_text(f"{mem_used:.1f}GB")
            self.ram_card['right_value'].set_text(f"{mem.percent:.0f}%")
            
            # Network
            down_speed, up_speed, net_percent = self.get_network_speed()
            self.network_card['graph'].add_data_point(net_percent)
            self.network_card['left_value'].set_text(down_speed)
            self.network_card['right_value'].set_text(up_speed)
            
        except Exception as e:
            print(f"[sysmon] Error: {e}")
            
        return True
        
    def get_cpu_temp(self):
        """Get CPU temp"""
        try:
            temps = psutil.sensors_temperatures()
            for sensor in ['k10temp', 'coretemp', 'cpu_thermal', 'zenpower']:
                if sensor in temps and temps[sensor]:
                    return f"{temps[sensor][0].current:.0f}°C"
            
            for name, entries in temps.items():
                if entries and 'cpu' in name.lower():
                    return f"{entries[0].current:.0f}°C"
        except:
            pass
        return "--°C"
        
    def get_gpu_stats(self):
        """Get GPU temp and usage"""
        
        # NVIDIA
        if self.gpu_type == "nvidia":
            try:
                result = subprocess.run(
                    ['nvidia-smi', '--query-gpu=temperature.gpu,utilization.gpu', 
                     '--format=csv,noheader,nounits'],
                    capture_output=True, text=True, timeout=2
                )
                if result.returncode == 0:
                    temp, usage = result.stdout.strip().split(',')
                    return f"{temp.strip()}°C", f"{usage.strip()}%"
            except:
                pass
        
        # AMD via sysfs
        if self.gpu_type == "amd":
            try:
                # Find AMD GPU hwmon
                for hwmon in Path('/sys/class/hwmon').iterdir():
                    name_file = hwmon / 'name'
                    if name_file.exists():
                        name = name_file.read_text().strip()
                        if name == 'amdgpu':
                            # Temperature
                            temp_file = hwmon / 'temp1_input'
                            if temp_file.exists():
                                temp = int(temp_file.read_text().strip()) // 1000
                                temp_str = f"{temp}°C"
                            else:
                                temp_str = "--°C"
                            
                            # GPU Usage via /sys/class/drm
                            usage_str = "--%"
                            for card in Path('/sys/class/drm').glob('card[0-9]'):
                                busy_file = card / 'device' / 'gpu_busy_percent'
                                if busy_file.exists():
                                    usage = int(busy_file.read_text().strip())
                                    usage_str = f"{usage}%"
                                    break
                            
                            return temp_str, usage_str
            except Exception as e:
                print(f"[sysmon] AMD GPU error: {e}")
        
        # Intel via sysfs
        if self.gpu_type == "intel":
            try:
                for hwmon in Path('/sys/class/hwmon').iterdir():
                    name_file = hwmon / 'name'
                    if name_file.exists():
                        name = name_file.read_text().strip()
                        if 'i915' in name or 'intel' in name.lower():
                            temp_file = hwmon / 'temp1_input'
                            if temp_file.exists():
                                temp = int(temp_file.read_text().strip()) // 1000
                                return f"{temp}°C", "--%"
            except:
                pass
        
        return "--°C", "--%"
        
    def get_network_speed(self):
        """Get network speed"""
        try:
            net_io = psutil.net_io_counters()
            
            if self.prev_net_io:
                down_bytes = net_io.bytes_recv - self.prev_net_io.bytes_recv
                up_bytes = net_io.bytes_sent - self.prev_net_io.bytes_sent
                
                down_str = self.format_speed(down_bytes)
                up_str = self.format_speed(up_bytes)
                
                # Graph percentage (10MB/s = 100%)
                if 'MB/s' in down_str:
                    mbps = float(down_str.replace('MB/s', ''))
                    percent = min(100, (mbps / 10) * 100)
                elif 'KB/s' in down_str:
                    kbps = float(down_str.replace('KB/s', ''))
                    percent = min(100, (kbps / 10000) * 100)
                else:
                    percent = 0
                
                self.prev_net_io = net_io
                return down_str, up_str, percent
            
            self.prev_net_io = net_io
            return "0B/s", "0B/s", 0
        except:
            return "N/A", "N/A", 0
            
    def format_speed(self, bps):
        """Format speed"""
        if bps < 1024:
            return f"{bps:.0f}B/s"
        elif bps < 1024 * 1024:
            return f"{bps/1024:.0f}KB/s"
        else:
            return f"{bps/(1024*1024):.1f}MB/s"


def main():
    app = Gtk.Application(application_id="com.hypr.widget.sysmon")
    
    def on_activate(app):
        widget = SystemMonitorWidget()
        widget.set_application(app)
        widget.present()
    
    app.connect("activate", on_activate)
    app.run(None)


if __name__ == "__main__":
    main()