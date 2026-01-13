"""
Waveform Visualizer Module
Smooth audio visualization using CAVA
"""

import gi
gi.require_version('Gtk', '4.0')
from gi.repository import Gtk, GLib, Gdk
import subprocess
import os
from pathlib import Path


class WaveformVisualizer(Gtk.DrawingArea):
    """Smooth waveform visualizer"""
    
    def __init__(self):
        super().__init__()
        self.set_size_request(220, 40)
        self.add_css_class("waveform-visualizer")
        
        # Audio data
        self.values = [0] * 50
        self.smoothed = [0] * 50
        self.phase = 0
        self.cava = None
        
        # Colors (One Dark theme)
        self.fg_color = Gdk.RGBA()
        self.fg_color.parse("#61afef")
        
        self.glow_color = Gdk.RGBA()
        self.glow_color.parse("#c678dd")
        
        # Config path
        self.config_path = os.path.expanduser("~/.config/cava/zenpybar.conf")
        
        # Initialize
        self.ensure_config()
        self.start_cava()
        
        # Drawing
        self.set_draw_func(self.on_draw)
        
        # Animation loop
        GLib.timeout_add(33, self.update)  # ~30 FPS
        
    def ensure_config(self):
        """Create CAVA config if doesn't exist"""
        config_dir = Path(self.config_path).parent
        config_dir.mkdir(parents=True, exist_ok=True)
        
        if not Path(self.config_path).exists():
            config_content = """[general]
framerate = 30
bars = 50
autosens = 1
sensitivity = 100

[input]
method = pulse
source = auto

[output]
method = raw
data_format = ascii
ascii_max_range = 7
bar_delimiter = 59

[smoothing]
monstercat = 1
waves = 0
noise_reduction = 77
"""
            with open(self.config_path, 'w') as f:
                f.write(config_content)
            print(f"✓ Created CAVA config: {self.config_path}")
    
    def start_cava(self):
        """Start CAVA process"""
        try:
            self.cava = subprocess.Popen(
                ['cava', '-p', self.config_path],
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True,
                bufsize=1
            )
            print(f"✓ CAVA started")
        except FileNotFoundError:
            print("✗ CAVA not found!")
            self.cava = None
        except Exception as e:
            print(f"✗ Error starting CAVA: {e}")
            self.cava = None
    
    def update(self):
        """Update audio data from CAVA"""
        if self.cava and self.cava.poll() is None:
            try:
                line = self.cava.stdout.readline().strip()
                if line:
                    raw_values = [int(v) for v in line.split(';') if v.isdigit()]
                    
                    if len(raw_values) >= 50:
                        self.values = raw_values[:50]
                    elif len(raw_values) > 0:
                        step = len(raw_values) / 50
                        self.values = [raw_values[int(i * step)] for i in range(50)]
            except:
                pass
        
        # Smooth values
        smoothing = 0.4
        for i in range(len(self.values)):
            self.smoothed[i] += (self.values[i] - self.smoothed[i]) * smoothing
        
        # Increment phase for wave animation
        self.phase += 0.15
        
        # Trigger redraw
        self.queue_draw()
        return True
    
    def on_draw(self, area, cr, width, height):
        """Draw smooth waveform"""
        import math
        
        # Clear background
        cr.set_source_rgba(0, 0, 0, 0)
        cr.paint()
        
        center_y = height / 2
        points = len(self.smoothed)
        step = width / (points - 1)
        
        # Draw glow layer
        self._draw_wave(cr, width, height, center_y, step, points, True)
        
        # Draw main wave
        self._draw_wave(cr, width, height, center_y, step, points, False)
    
    def _draw_wave(self, cr, width, height, center_y, step, points, is_glow):
        """Draw wave with or without glow"""
        import math
        
        if is_glow:
            cr.set_line_width(8)
            cr.set_source_rgba(
                self.glow_color.red,
                self.glow_color.green,
                self.glow_color.blue,
                0.15
            )
        else:
            cr.set_line_width(3)
            cr.set_source_rgba(
                self.fg_color.red,
                self.fg_color.green,
                self.fg_color.blue,
                0.95
            )
        
        cr.set_line_cap(1)
        cr.set_line_join(1)
        
        cr.move_to(0, center_y)
        
        for i in range(points):
            x = i * step
            amplitude = (self.smoothed[i] / 7.0) * (height / 2) * 0.75
            wave_offset = math.sin(self.phase + i * 0.2) * 4
            y = center_y + (amplitude * math.sin(i * 0.25 + self.phase * 0.5)) + wave_offset
            
            if i == 0:
                cr.line_to(x, y)
            else:
                prev_x = (i - 1) * step
                cp1_x = prev_x + step / 2
                cp2_x = x - step / 2
                
                prev_amplitude = (self.smoothed[i-1] / 7.0) * (height / 2) * 0.75
                prev_wave = math.sin(self.phase + (i-1) * 0.2) * 4
                prev_y = center_y + (prev_amplitude * math.sin((i-1) * 0.25 + self.phase * 0.5)) + prev_wave
                
                cp1_y = prev_y
                cp2_y = y
                
                cr.curve_to(cp1_x, cp1_y, cp2_x, cp2_y, x, y)
        
        cr.stroke()
    
    def cleanup(self):
        """Clean up CAVA process"""
        if self.cava:
            self.cava.terminate()
            self.cava.wait()
