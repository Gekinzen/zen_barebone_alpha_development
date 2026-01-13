#!/usr/bin/env python3
# ~/.config/hypr-control-center/widgets/system_monitor_widget.py
"""
System Monitor - Clean Design (Reference Style)
- No icons, text-based labels
- Boxed graphs prominent
- Color-coded stats
- Fits current theme
"""

import gi
gi.require_version('Gtk', '4.0')
from gi.repository import Gtk, GLib, Gdk
import subprocess
import psutil
import re
from collections import deque
from pathlib import Path
from base_widget import BaseWidget


class BoxedGraph(Gtk.DrawingArea):
    """Graph with box background - prominent style"""
    def __init__(self, max_points=40):
        super().__init__()
        self.data = deque([0] * max_points, maxlen=max_points)
        self.color = (0.19, 0.82, 0.35)  # Default green
        self.set_content_width(140)
        self.set_content_height(55)  # Taller graph
        self.set_draw_func(self._draw)
    
    def set_color(self, r, g, b):
        self.color = (r, g, b)
        
    def add_point(self, value):
        self.data.append(max(0, min(100, value)))
        self.queue_draw()
        
    def _draw(self, area, cr, width, height):
        # Box background
        cr.set_source_rgba(0.08, 0.08, 0.09, 0.8)
        self._rounded_rect(cr, 0, 0, width, height, 6)
        cr.fill()
        
        # Box border
        cr.set_source_rgba(1, 1, 1, 0.08)
        self._rounded_rect(cr, 0, 0, width, height, 6)
        cr.set_line_width(1)
        cr.stroke()
        
        if len(self.data) < 2:
            return
        
        pad = 4
        inner_w = width - (pad * 2)
        inner_h = height - (pad * 2)
        
        # Grid lines (subtle)
        cr.set_source_rgba(1, 1, 1, 0.05)
        cr.set_line_width(0.5)
        for i in range(1, 4):
            y = pad + (inner_h / 4) * i
            cr.move_to(pad, y)
            cr.line_to(width - pad, y)
            cr.stroke()
        
        # Graph fill
        points = list(self.data)
        x_step = inner_w / (len(points) - 1)
        
        cr.move_to(pad, height - pad)
        for i, val in enumerate(points):
            x = pad + (i * x_step)
            y = pad + inner_h - (val / 100) * inner_h
            cr.line_to(x, y)
        cr.line_to(width - pad, height - pad)
        cr.close_path()
        cr.set_source_rgba(self.color[0], self.color[1], self.color[2], 0.3)
        cr.fill()
        
        # Graph line
        cr.set_source_rgba(self.color[0], self.color[1], self.color[2], 0.9)
        cr.set_line_width(1.5)
        cr.move_to(pad, pad + inner_h - (points[0] / 100) * inner_h)
        for i, val in enumerate(points):
            x = pad + (i * x_step)
            y = pad + inner_h - (val / 100) * inner_h
            cr.line_to(x, y)
        cr.stroke()
    
    def _rounded_rect(self, cr, x, y, w, h, r):
        cr.new_path()
        cr.arc(x + r, y + r, r, 3.14159, 3.14159 * 1.5)
        cr.arc(x + w - r, y + r, r, 3.14159 * 1.5, 0)
        cr.arc(x + w - r, y + h - r, r, 0, 3.14159 * 0.5)
        cr.arc(x + r, y + h - r, r, 3.14159 * 0.5, 3.14159)
        cr.close_path()


class SystemMonitorWidget(BaseWidget):
    
    COLORS = {
        'green':  '#30d158',
        'yellow': '#ffd60a',
        'orange': '#ff9f0a',
        'red':    '#ff453a',
    }
    
    TEMP_THRESHOLDS = {'green': 50, 'yellow': 65, 'orange': 80, 'red': 100}
    USAGE_THRESHOLDS = {'green': 50, 'yellow': 70, 'orange': 85, 'red': 100}
    
    def __init__(self):
        super().__init__("system_monitor")
        
        self.cpu_name = self.detect_cpu()
        self.gpu_name, self.gpu_type = self.detect_gpu()
        self.prev_net_io = None
        
        # Main container - FIXED SIZE
        main = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        main.add_css_class("widget-container")
        main.add_css_class("sysmon-clean")
        main.set_size_request(340, 360)  # Fixed size
        
        # Title bar with accent
        title_bar = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        title_bar.set_margin_start(16)
        title_bar.set_margin_end(16)
        title_bar.set_margin_top(14)
        title_bar.set_margin_bottom(10)
        
        # Red accent bar (like reference)
        accent = Gtk.Box()
        accent.add_css_class("title-accent")
        accent.set_size_request(3, 16)
        title_bar.append(accent)
        
        title = Gtk.Label(label="SYSTEM MONITOR")
        title.add_css_class("sysmon-title-clean")
        title.set_halign(Gtk.Align.START)
        title.set_hexpand(True)
        title_bar.append(title)
        
        # Details button - horizontal three dots (•••)
        details_btn = Gtk.Button()
        details_btn.add_css_class("details-btn-clean")
        details_btn.set_cursor(Gdk.Cursor.new_from_name("pointer", None))
        details_btn.set_child(Gtk.Label(label="•••"))  # Horizontal three dots
        details_btn.connect("clicked", self.open_detailed_monitor)
        details_btn.set_tooltip_text("Open detailed monitor")
        title_bar.append(details_btn)
        
        main.append(title_bar)
        
        # Cards Grid (2x2)
        grid = Gtk.Grid()
        grid.set_row_spacing(10)
        grid.set_column_spacing(10)
        grid.set_margin_start(12)
        grid.set_margin_end(12)
        grid.set_margin_bottom(14)
        grid.set_halign(Gtk.Align.CENTER)
        
        # CPU Card
        self.cpu_card, self.cpu_name_lbl, self.cpu_graph, self.cpu_temp_lbl, self.cpu_usage_lbl = self.create_card(
            self.cpu_name, "TEMP", "USAGE"
        )
        grid.attach(self.cpu_card, 0, 0, 1, 1)
        
        # GPU Card
        self.gpu_card, self.gpu_name_lbl, self.gpu_graph, self.gpu_temp_lbl, self.gpu_vram_lbl = self.create_card(
            self.gpu_name, "TEMP", "VRAM"
        )
        grid.attach(self.gpu_card, 1, 0, 1, 1)
        
        # RAM Card
        self.ram_card, self.ram_name_lbl, self.ram_graph, self.ram_usage_lbl, self.ram_total_lbl = self.create_card(
            "RAM", "USAGE", "TOTAL"
        )
        grid.attach(self.ram_card, 0, 1, 1, 1)
        
        # Network Card
        self.net_card, self.net_name_lbl, self.net_graph, self.net_down_lbl, self.net_up_lbl = self.create_card(
            "NETWORK", "DOWN", "UP"
        )
        grid.attach(self.net_card, 1, 1, 1, 1)
        
        main.append(grid)
        self.set_child(main)
        
        self.update_stats()
        GLib.timeout_add(2000, self.update_stats)
    
    def create_card(self, name, label1, label2):
        """Create clean card - name on top, graph in middle, stats at bottom"""
        card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        card.add_css_class("sysmon-card-clean")
        card.set_size_request(155, 155)  # Taller cards for bigger graphs
        
        # Name label (top, centered)
        name_lbl = Gtk.Label(label=name)
        name_lbl.add_css_class("card-name-clean")
        name_lbl.set_halign(Gtk.Align.CENTER)
        name_lbl.set_margin_top(10)
        name_lbl.set_ellipsize(3)
        name_lbl.set_max_width_chars(14)
        card.append(name_lbl)
        
        # Graph (middle, prominent)
        graph = BoxedGraph()
        graph.set_halign(Gtk.Align.CENTER)
        graph.set_margin_top(4)
        card.append(graph)
        
        # Stats row (bottom)
        stats_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        stats_box.set_halign(Gtk.Align.FILL)
        stats_box.set_margin_start(10)
        stats_box.set_margin_end(10)
        stats_box.set_margin_top(6)
        stats_box.set_margin_bottom(10)
        
        # Left stat
        left_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        left_box.set_hexpand(True)
        left_box.set_halign(Gtk.Align.START)
        
        left_label = Gtk.Label(label=label1)
        left_label.add_css_class("stat-label-tiny")
        left_label.set_halign(Gtk.Align.START)
        left_box.append(left_label)
        
        left_value = Gtk.Label(label="--")
        left_value.add_css_class("stat-value-clean")
        left_value.set_halign(Gtk.Align.START)
        left_box.append(left_value)
        
        stats_box.append(left_box)
        
        # Right stat
        right_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        right_box.set_hexpand(True)
        right_box.set_halign(Gtk.Align.END)
        
        right_label = Gtk.Label(label=label2)
        right_label.add_css_class("stat-label-tiny")
        right_label.set_halign(Gtk.Align.END)
        right_box.append(right_label)
        
        right_value = Gtk.Label(label="--")
        right_value.add_css_class("stat-value-clean")
        right_value.set_halign(Gtk.Align.END)
        right_box.append(right_value)
        
        stats_box.append(right_box)
        card.append(stats_box)
        
        return card, name_lbl, graph, left_value, right_value
    
    def open_detailed_monitor(self, btn):
        btm_script = Path.home() / ".config" / "alacritty" / "btmrun.sh"
        if btm_script.exists():
            subprocess.Popen(['bash', str(btm_script)])
        else:
            try:
                subprocess.Popen(['alacritty', '-e', 'btm'])
            except:
                subprocess.Popen(['alacritty', '-e', 'htop'])
    
    def detect_cpu(self):
        try:
            with open('/proc/cpuinfo', 'r') as f:
                for line in f:
                    if 'model name' in line:
                        cpu = line.split(':')[1].strip()
                        cpu = cpu.replace('AMD ', '').replace('Intel(R) ', 'Intel ')
                        cpu = cpu.replace('Core(TM) ', 'Core ').replace('Processor', '')
                        cpu = cpu.replace('with Radeon Graphics', '').strip()
                        cpu = re.sub(r'\s+', ' ', cpu)
                        
                        match = re.search(r'(Ryzen \d+ \d+\w*)', cpu)
                        if match:
                            return match.group(1)
                        
                        match = re.search(r'(Core i\d+-?\d+\w*)', cpu)
                        if match:
                            return match.group(1)
                        
                        return cpu[:16]
        except:
            pass
        return "CPU"
    
    def detect_gpu(self):
        try:
            result = subprocess.run(
                ['nvidia-smi', '--query-gpu=name', '--format=csv,noheader'],
                capture_output=True, text=True, timeout=2
            )
            if result.returncode == 0 and result.stdout.strip():
                gpu = result.stdout.strip()
                gpu = gpu.replace('NVIDIA GeForce ', '').replace('NVIDIA ', '')
                return gpu[:14], "nvidia"
        except:
            pass
        
        try:
            amd_cards = list(Path('/sys/class/drm').glob('card*/device/vendor'))
            for vendor_file in amd_cards:
                vendor = vendor_file.read_text().strip()
                if vendor == '0x1002':
                    result = subprocess.run(['lspci'], capture_output=True, text=True, timeout=2)
                    if result.returncode == 0:
                        for line in result.stdout.split('\n'):
                            if 'VGA' in line or 'Display' in line:
                                if 'AMD' in line or 'Radeon' in line:
                                    match = re.search(r'(RX\s*\d+\s*\w*)', line)
                                    if match:
                                        return match.group(1).strip(), "amd"
                    return "AMD Radeon", "amd"
        except:
            pass
        
        return "GPU", "unknown"
    
    def get_color_rgb(self, value, is_temp=False):
        thresholds = self.TEMP_THRESHOLDS if is_temp else self.USAGE_THRESHOLDS
        if value < thresholds['green']:
            return (0.19, 0.82, 0.35)
        elif value < thresholds['yellow']:
            return (1.0, 0.84, 0.04)
        elif value < thresholds['orange']:
            return (1.0, 0.62, 0.04)
        return (1.0, 0.27, 0.23)
    
    def get_color_class(self, value, is_temp=False):
        thresholds = self.TEMP_THRESHOLDS if is_temp else self.USAGE_THRESHOLDS
        if value < thresholds['green']:
            return 'stat-green'
        elif value < thresholds['yellow']:
            return 'stat-yellow'
        elif value < thresholds['orange']:
            return 'stat-orange'
        return 'stat-red'
    
    def set_value_color(self, label, value, is_temp=False):
        for c in ['stat-green', 'stat-yellow', 'stat-orange', 'stat-red']:
            label.remove_css_class(c)
        label.add_css_class(self.get_color_class(value, is_temp))
    
    def update_stats(self):
        self.update_cpu()
        self.update_gpu()
        self.update_ram()
        self.update_network()
        return True
    
    def update_cpu(self):
        try:
            cpu_percent = psutil.cpu_percent(interval=0)
            temp = self.get_cpu_temp()
            
            if temp:
                self.cpu_temp_lbl.set_text(f"{temp}°C")
                self.set_value_color(self.cpu_temp_lbl, temp, is_temp=True)
                rgb = self.get_color_rgb(temp, is_temp=True)
            else:
                self.cpu_temp_lbl.set_text("--°C")
                rgb = self.get_color_rgb(cpu_percent, is_temp=False)
            
            self.cpu_usage_lbl.set_text(f"{cpu_percent:.0f}%")
            self.set_value_color(self.cpu_usage_lbl, cpu_percent, is_temp=False)
            
            self.cpu_graph.set_color(*rgb)
            self.cpu_graph.add_point(cpu_percent)
            
            # Tooltip
            per_cpu = psutil.cpu_percent(interval=0, percpu=True)
            tooltip = [f"━━━ {self.cpu_name} ━━━"]
            tooltip.append(f"Usage: {cpu_percent:.1f}%")
            if temp:
                tooltip.append(f"Temp: {temp}°C")
            tooltip.append("")
            tooltip.append("Per-Core:")
            for i in range(0, len(per_cpu), 4):
                row = per_cpu[i:i+4]
                tooltip.append("  ".join([f"C{i+j}:{c:3.0f}%" for j, c in enumerate(row)]))
            self.cpu_card.set_tooltip_text("\n".join(tooltip))
            
        except Exception as e:
            print(f"CPU error: {e}")
    
    def update_gpu(self):
        try:
            temp, usage, vram_used, vram_total = None, 0, None, None
            
            if self.gpu_type == "nvidia":
                temp, usage, vram_used, vram_total = self.get_nvidia_stats()
            elif self.gpu_type == "amd":
                temp, usage, vram_used, vram_total = self.get_amd_stats()
            
            if temp:
                self.gpu_temp_lbl.set_text(f"{temp}°C")
                self.set_value_color(self.gpu_temp_lbl, temp, is_temp=True)
                rgb = self.get_color_rgb(temp, is_temp=True)
            else:
                self.gpu_temp_lbl.set_text("--°C")
                rgb = (0.19, 0.82, 0.35)
            
            if vram_used is not None:
                self.gpu_vram_lbl.set_text(f"{vram_used:.1f}GB")
            else:
                self.gpu_vram_lbl.set_text(f"{usage}%")
                self.set_value_color(self.gpu_vram_lbl, usage, is_temp=False)
            
            self.gpu_graph.set_color(*rgb)
            self.gpu_graph.add_point(usage)
            
            # Tooltip
            tooltip = [f"━━━ {self.gpu_name} ━━━"]
            tooltip.append(f"Usage: {usage}%")
            if temp:
                tooltip.append(f"Temp: {temp}°C")
            if vram_used and vram_total:
                tooltip.append(f"VRAM: {vram_used:.1f}GB / {vram_total:.1f}GB")
            self.gpu_card.set_tooltip_text("\n".join(tooltip))
            
        except Exception as e:
            print(f"GPU error: {e}")
    
    def update_ram(self):
        try:
            mem = psutil.virtual_memory()
            used_gb = mem.used / (1024**3)
            total_gb = mem.total / (1024**3)
            
            self.ram_usage_lbl.set_text(f"{mem.percent:.0f}%")
            self.set_value_color(self.ram_usage_lbl, mem.percent, is_temp=False)
            
            self.ram_total_lbl.set_text(f"{used_gb:.1f}GB")
            
            rgb = self.get_color_rgb(mem.percent, is_temp=False)
            self.ram_graph.set_color(*rgb)
            self.ram_graph.add_point(mem.percent)
            
            # Tooltip
            swap = psutil.swap_memory()
            tooltip = ["━━━ MEMORY ━━━"]
            tooltip.append(f"Used: {used_gb:.1f}GB / {total_gb:.1f}GB ({mem.percent:.0f}%)")
            tooltip.append(f"Available: {mem.available/(1024**3):.1f}GB")
            tooltip.append(f"Swap: {swap.used/(1024**3):.1f}GB / {swap.total/(1024**3):.1f}GB")
            self.ram_card.set_tooltip_text("\n".join(tooltip))
            
        except Exception as e:
            print(f"RAM error: {e}")
    
    def update_network(self):
        try:
            net_io = psutil.net_io_counters()
            
            if self.prev_net_io:
                down_bps = (net_io.bytes_recv - self.prev_net_io.bytes_recv) / 2
                up_bps = (net_io.bytes_sent - self.prev_net_io.bytes_sent) / 2
                
                self.net_down_lbl.set_text(self.fmt_speed(down_bps))
                self.net_up_lbl.set_text(self.fmt_speed(up_bps))
                
                percent = min(100, (down_bps / (10 * 1024 * 1024)) * 100)
                self.net_graph.add_point(percent)
                
                # Tooltip
                tooltip = ["━━━ NETWORK ━━━"]
                tooltip.append(f"Down: {self.fmt_speed(down_bps)}")
                tooltip.append(f"Up: {self.fmt_speed(up_bps)}")
                tooltip.append("")
                tooltip.append(f"Total ↓: {self.fmt_bytes(net_io.bytes_recv)}")
                tooltip.append(f"Total ↑: {self.fmt_bytes(net_io.bytes_sent)}")
                self.net_card.set_tooltip_text("\n".join(tooltip))
            
            self.prev_net_io = net_io
            
        except Exception as e:
            print(f"Network error: {e}")
    
    def get_cpu_temp(self):
        try:
            temps = psutil.sensors_temperatures()
            for name in ['k10temp', 'coretemp', 'zenpower', 'cpu_thermal']:
                if name in temps:
                    for entry in temps[name]:
                        if 'Tctl' in entry.label or 'Package' in entry.label or entry.label == '':
                            return int(entry.current)
            for name, entries in temps.items():
                for entry in entries:
                    if 0 < entry.current < 110:
                        return int(entry.current)
        except:
            pass
        return None
    
    def get_nvidia_stats(self):
        try:
            result = subprocess.run([
                'nvidia-smi',
                '--query-gpu=temperature.gpu,utilization.gpu,memory.used,memory.total',
                '--format=csv,noheader,nounits'
            ], capture_output=True, text=True, timeout=2)
            if result.returncode == 0:
                p = result.stdout.strip().split(',')
                return int(p[0]), int(p[1]), float(p[2])/1024, float(p[3])/1024
        except:
            pass
        return None, 0, None, None
    
    def get_amd_stats(self):
        try:
            for hwmon in Path('/sys/class/hwmon').iterdir():
                name_file = hwmon / 'name'
                if name_file.exists() and name_file.read_text().strip() == 'amdgpu':
                    temp = None
                    if (hwmon / 'temp1_input').exists():
                        temp = int((hwmon / 'temp1_input').read_text()) // 1000
                    
                    usage = 0
                    if (hwmon / 'device' / 'gpu_busy_percent').exists():
                        usage = int((hwmon / 'device' / 'gpu_busy_percent').read_text())
                    
                    vram_used, vram_total = None, None
                    vu = hwmon / 'device' / 'mem_info_vram_used'
                    vt = hwmon / 'device' / 'mem_info_vram_total'
                    if vu.exists() and vt.exists():
                        vram_used = int(vu.read_text()) / (1024**3)
                        vram_total = int(vt.read_text()) / (1024**3)
                    
                    return temp, usage, vram_used, vram_total
        except:
            pass
        return None, 0, None, None
    
    def fmt_speed(self, bps):
        if bps < 1024:
            return f"{int(bps)}B/s"
        elif bps < 1024**2:
            return f"{bps/1024:.0f}KB/s"
        return f"{bps/(1024**2):.1f}MB/s"
    
    def fmt_bytes(self, b):
        if b < 1024**2:
            return f"{b/1024:.1f}KB"
        elif b < 1024**3:
            return f"{b/(1024**2):.1f}MB"
        return f"{b/(1024**3):.2f}GB"


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