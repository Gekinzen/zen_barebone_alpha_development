#!/usr/bin/env python3
"""
System Monitor - Compact 360x220 Design  
4-card grid with graphs, temps, usage
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
    """Tiny graph widget"""
    def __init__(self):
        super().__init__()
        self.data = deque([0] * 30, maxlen=30)
        self.set_content_width(145)
        self.set_content_height(35)
        self.set_draw_func(self._draw)
        
    def add_data_point(self, value):
        self.data.append(max(0, min(100, value)))
        self.queue_draw()
        
    def _draw(self, area, cr, width, height):
        # Background
        cr.set_source_rgba(0.18, 0.18, 0.19, 0.5)
        cr.rectangle(0, 0, width, height)
        cr.fill()
        
        if len(self.data) < 2:
            return
        
        # Graph line
        cr.set_source_rgba(0.04, 0.52, 1.0, 0.8)
        cr.set_line_width(1.2)
        
        points = list(self.data)
        x_step = width / (len(points) - 1)
        
        first_point = 100 - points[0]
        cr.move_to(0, (first_point / 100) * height)
        
        for i, value in enumerate(points):
            x = i * x_step
            y = ((100 - value) / 100) * height
            cr.line_to(x, y)
        
        cr.stroke_preserve()
        
        # Fill
        cr.line_to(width, height)
        cr.line_to(0, height)
        cr.close_path()
        cr.set_source_rgba(0.04, 0.52, 1.0, 0.2)
        cr.fill()


class SystemMonitorWidget(BaseWidget):
    def __init__(self):
        super().__init__("system_monitor")
        
        # Detect hardware
        self.cpu_name = self.detect_cpu()
        self.gpu_name, self.gpu_type = self.detect_gpu()
        
        # Main container - COMPACT
        main = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        main.add_css_class("widget-container")
        main.add_css_class("sysmon-compact")
        main.set_size_request(360, 220)
        
        # Header
        header = Gtk.Label(label="SYSTEM MONITOR")
        header.add_css_class("sysmon-title")
        header.set_halign(Gtk.Align.START)
        header.set_margin_start(15)
        header.set_margin_top(12)
        header.set_margin_bottom(8)
        main.append(header)
        
        # Grid 2x2
        grid = Gtk.Grid()
        grid.set_column_spacing(8)
        grid.set_row_spacing(8)
        grid.set_margin_start(12)
        grid.set_margin_end(12)
        grid.set_margin_bottom(12)
        
        # Cards
        self.cpu_card = self.create_card(self.cpu_name, "🖥️")
        grid.attach(self.cpu_card['widget'], 0, 0, 1, 1)
        
        self.gpu_card = self.create_card(self.gpu_name, "🎮")
        grid.attach(self.gpu_card['widget'], 1, 0, 1, 1)
        
        self.ram_card = self.create_card("RAM", "💾")
        grid.attach(self.ram_card['widget'], 0, 1, 1, 1)
        
        self.network_card = self.create_card("NETWORK", "🌐")
        grid.attach(self.network_card['widget'], 1, 1, 1, 1)
        
        main.append(grid)
        self.set_child(main)
        
        # Network tracking
        self.prev_net_io = None
        
        # Update
        self.update_stats()
        GLib.timeout_add(1000, self.update_stats)
    
    def detect_cpu(self):
        """Detect CPU"""
        try:
            with open('/proc/cpuinfo', 'r') as f:
                for line in f:
                    if 'model name' in line:
                        cpu = line.split(':')[1].strip()
                        if 'AMD' in cpu and 'Ryzen' in cpu:
                            parts = cpu.split()
                            for i, part in enumerate(parts):
                                if 'Ryzen' in part and i+2 < len(parts):
                                    return f"Ryzen {parts[i+1]} {parts[i+2]}"
                        elif 'Intel' in cpu:
                            parts = cpu.split()
                            for i, part in enumerate(parts):
                                if 'Core' in part and i+1 < len(parts):
                                    return f"Intel {part} {parts[i+1]}"
                        return cpu[:15]
        except:
            pass
        return "CPU"
    
    def detect_gpu(self):
        """Detect GPU"""
        # Try NVIDIA
        try:
            result = subprocess.run(
                ['nvidia-smi', '--query-gpu=name', '--format=csv,noheader'],
                capture_output=True, text=True, timeout=2
            )
            if result.returncode == 0 and result.stdout.strip():
                name = result.stdout.strip().replace('NVIDIA GeForce ', '').replace('NVIDIA ', '')
                return name[:15], "nvidia"
        except:
            pass
        
        # Try AMD
        try:
            result = subprocess.run(['lspci'], capture_output=True, text=True, timeout=2)
            for line in result.stdout.split('\n'):
                if 'VGA' in line or 'Display' in line:
                    if 'AMD' in line or 'Radeon' in line:
                        match = re.search(r'(RX\s+\d+\s*\w*)', line)
                        if match:
                            return match.group(1), "amd"
                        return "Radeon", "amd"
        except:
            pass
        
        return "GPU", "unknown"
    
    def create_card(self, title, icon):
        """Create compact card"""
        card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
        card.add_css_class("monitor-card-compact")
        card.set_size_request(165, 80)
        
        # Header with icon
        header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=5)
        
        icon_label = Gtk.Label(label=icon)
        icon_label.add_css_class("card-icon")
        header.append(icon_label)
        
        title_label = Gtk.Label(label=title)
        title_label.add_css_class("card-title-compact")
        title_label.set_halign(Gtk.Align.START)
        title_label.set_ellipsize(3)
        title_label.set_max_width_chars(15)
        header.append(title_label)
        
        card.append(header)
        
        # Graph
        graph = GraphWidget()
        card.append(graph)
        
        # Stats row
        stats = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=15)
        stats.set_halign(Gtk.Align.START)
        
        temp_label = Gtk.Label()
        temp_label.add_css_class("card-stat")
        stats.append(temp_label)
        
        usage_label = Gtk.Label()
        usage_label.add_css_class("card-stat")
        stats.append(usage_label)
        
        card.append(stats)
        
        return {
            'widget': card,
            'graph': graph,
            'temp': temp_label,
            'usage': usage_label
        }
    
    def update_stats(self):
        """Update all stats"""
        try:
            # CPU
            cpu_percent = psutil.cpu_percent(interval=0.1)
            cpu_temp = self.get_cpu_temp()
            self.cpu_card['graph'].add_data_point(cpu_percent)
            self.cpu_card['temp'].set_text(cpu_temp)
            self.cpu_card['usage'].set_text(f"{cpu_percent:.0f}%")
            
            # GPU
            gpu_temp, gpu_usage = self.get_gpu_stats()
            try:
                gpu_percent = float(gpu_usage.replace('%', '')) if '%' in gpu_usage else 0
            except:
                gpu_percent = 0
            self.gpu_card['graph'].add_data_point(gpu_percent)
            self.gpu_card['temp'].set_text(gpu_temp)
            self.gpu_card['usage'].set_text(gpu_usage)
            
            # RAM
            mem = psutil.virtual_memory()
            self.ram_card['graph'].add_data_point(mem.percent)
            self.ram_card['temp'].set_text(f"{mem.used/(1024**3):.1f}GB")
            self.ram_card['usage'].set_text(f"{mem.percent:.0f}%")
            
            # Network
            down, up, percent = self.get_network_speed()
            self.network_card['graph'].add_data_point(percent)
            self.network_card['temp'].set_text(down)
            self.network_card['usage'].set_text(up)
        except:
            pass
        return True
    
    def get_cpu_temp(self):
        """Get CPU temp"""
        try:
            temps = psutil.sensors_temperatures()
            for sensor in ['k10temp', 'coretemp']:
                if sensor in temps and temps[sensor]:
                    return f"{temps[sensor][0].current:.0f}°C"
        except:
            pass
        return "--°C"
    
    def get_gpu_stats(self):
        """Get GPU stats"""
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
        
        if self.gpu_type == "amd":
            try:
                for hwmon in Path('/sys/class/hwmon').iterdir():
                    if (hwmon / 'name').exists():
                        name = (hwmon / 'name').read_text().strip()
                        if name == 'amdgpu':
                            temp_file = hwmon / 'temp1_input'
                            if temp_file.exists():
                                temp = int(temp_file.read_text().strip()) // 1000
                                temp_str = f"{temp}°C"
                            else:
                                temp_str = "--°C"
                            
                            usage_str = "--%"
                            for card in Path('/sys/class/drm').glob('card[0-9]'):
                                busy = card / 'device' / 'gpu_busy_percent'
                                if busy.exists():
                                    usage_str = f"{int(busy.read_text().strip())}%"
                                    break
                            return temp_str, usage_str
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
                
                if 'MB/s' in down_str:
                    percent = min(100, (float(down_str.replace('MB/s', '')) / 10) * 100)
                elif 'KB/s' in down_str:
                    percent = min(100, (float(down_str.replace('KB/s', '')) / 10000) * 100)
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