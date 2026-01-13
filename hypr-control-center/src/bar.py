"""
Zephyr-Style Waveform Visualizer
================================
Module: waveform_visualizer
Class: WaveformVisualizer

Window Properties (for Hyprland rules):
  - Title: "Waveform Visualizer"
  - Class: "waveform-visualizer"
  - App ID: "com.zenpy.waveform"

Add to hyprland.conf:
  windowrulev2 = float, class:^(waveform-visualizer)$
  windowrulev2 = size 350 80, class:^(waveform-visualizer)$
  windowrulev2 = nofocus, class:^(waveform-visualizer)$
  windowrulev2 = noborder, class:^(waveform-visualizer)$
  windowrulev2 = noshadow, class:^(waveform-visualizer)$
  windowrulev2 = noanim, class:^(waveform-visualizer)$
  windowrulev2 = pin, class:^(waveform-visualizer)$
  windowrulev2 = plugin:hyprbars:nobar, class:^(waveform-visualizer)$
"""

import gi
gi.require_version('Gtk', '4.0')
from gi.repository import Gtk, GLib, Gdk
import subprocess
import os
import math
from pathlib import Path


class WaveformVisualizer(Gtk.DrawingArea):
    """
    Zephyr-style waveform visualizer widget
    
    For Hyprland window rules, use:
      class:^(waveform-visualizer)$
    """
    
    # Fixed size - not resizable
    WIDTH = 350
    HEIGHT = 80
    
    def __init__(self):
        super().__init__()
        
        # Fixed size
        self.set_size_request(self.WIDTH, self.HEIGHT)
        self.set_hexpand(False)
        self.set_vexpand(False)
        self.add_css_class("waveform-visualizer")
        
        # Audio data
        self.sample_count = 50
        self.smoothed = [0.0] * self.sample_count
        self.target = [0.0] * self.sample_count
        
        # Individual line phases for organic movement (8 lines now)
        self.line_phases = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
        self.line_speeds = [0.04, 0.035, 0.045, 0.038, 0.042, 0.036, 0.044, 0.04]  # Slower, smoother
        
        # Animation state
        self.global_phase = 0.0
        self.is_playing = False
        self.silence_frames = 0
        self.play_intensity = 0.0
        self.cava = None
        self.cava_failed = False
        
        # Number of strings (more lines for fuller look)
        self.num_lines = 8
        
        # Zephyr light blue
        self.base_color = (0.494, 0.784, 0.890)  # #7ec8e3
        
        # Config
        self.config_path = os.path.expanduser("~/.config/cava/zenpybar.conf")
        
        # Initialize
        self.ensure_cava_config()
        self.start_cava()
        
        # Drawing
        self.set_draw_func(self.on_draw)
        
        # Animation - 30 FPS
        self.animation_id = GLib.timeout_add(33, self.update)
    
    def ensure_cava_config(self):
        """Create CAVA config"""
        config_dir = Path(self.config_path).parent
        config_dir.mkdir(parents=True, exist_ok=True)
        
        config_content = """[general]
framerate = 30
bars = 50
autosens = 1
sensitivity = 150

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
noise_reduction = 66
"""
        try:
            with open(self.config_path, 'w') as f:
                f.write(config_content)
        except Exception as e:
            print(f"[Waveform] Config error: {e}")
    
    def start_cava(self):
        """Start CAVA process"""
        try:
            result = subprocess.run(['which', 'cava'], capture_output=True, text=True)
            if result.returncode != 0:
                self.cava_failed = True
                return
        except:
            self.cava_failed = True
            return
        
        try:
            subprocess.run(['pkill', '-f', 'cava.*zenpybar'], capture_output=True, timeout=2)
        except:
            pass
        
        try:
            self.cava = subprocess.Popen(
                ['cava', '-p', self.config_path],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                bufsize=1
            )
            
            import fcntl
            flags = fcntl.fcntl(self.cava.stdout.fileno(), fcntl.F_GETFL)
            fcntl.fcntl(self.cava.stdout.fileno(), fcntl.F_SETFL, flags | os.O_NONBLOCK)
        except Exception as e:
            self.cava_failed = True
    
    def read_cava_data(self):
        """Read audio data from CAVA"""
        if not self.cava or self.cava.poll() is not None:
            if not self.cava_failed:
                self.start_cava()
            return False
        
        try:
            line = self.cava.stdout.readline()
            if line:
                line = line.strip()
                if line:
                    parts = line.split(';')
                    raw_values = [int(v.strip()) for v in parts if v.strip().isdigit()]
                    
                    if len(raw_values) > 0:
                        step = len(raw_values) / self.sample_count
                        for i in range(self.sample_count):
                            idx = min(int(i * step), len(raw_values) - 1)
                            self.target[i] = float(raw_values[idx])
                        return True
        except BlockingIOError:
            pass
        except:
            pass
        
        return False
    
    def update(self):
        """Update animation frame"""
        self.read_cava_data()
        
        # Check if audio is playing
        max_val = max(self.target) if self.target else 0
        if max_val > 0.5:
            self.is_playing = True
            self.silence_frames = 0
        else:
            self.silence_frames += 1
            if self.silence_frames > 25:
                self.is_playing = False
        
        # Smooth intensity transition (gentler)
        target_intensity = 1.0 if self.is_playing else 0.0
        self.play_intensity += (target_intensity - self.play_intensity) * 0.05
        
        # Smooth audio values (extra smooth for gentle motion)
        smoothing = 0.15 if self.is_playing else 0.1
        for i in range(self.sample_count):
            if self.is_playing:
                self.smoothed[i] += (self.target[i] - self.smoothed[i]) * smoothing
            else:
                self.smoothed[i] *= 0.95  # Slower decay
        
        # Update individual line phases
        for i in range(self.num_lines):
            self.line_phases[i] += self.line_speeds[i]
        
        self.global_phase += 0.03  # Slower for smoother motion
        
        self.queue_draw()
        return True
    
    def on_draw(self, area, cr, width, height):
        """Draw visualization"""
        # Clear
        cr.set_operator(0)
        cr.paint()
        cr.set_operator(2)
        
        # Padding
        padding_x = 24
        padding_y = 12
        
        draw_width = width - (padding_x * 2)
        draw_height = height - (padding_y * 2)
        center_y = height / 2
        
        left_x = padding_x
        right_x = width - padding_x
        
        dot_radius = 7 + self.play_intensity * 2
        
        if self.play_intensity < 0.05:
            self._draw_idle_line(cr, left_x, right_x, center_y, dot_radius)
        else:
            self._draw_playing_strings(cr, width, height, padding_x, padding_y,
                                       draw_width, draw_height, center_y,
                                       left_x, right_x, dot_radius)
    
    def _draw_idle_line(self, cr, left_x, right_x, center_y, dot_radius):
        """Single straight line when idle"""
        color = (*self.base_color, 0.5)
        
        cr.set_line_width(2.0)
        cr.set_source_rgba(*color)
        cr.set_line_cap(1)
        cr.move_to(left_x, center_y)
        cr.line_to(right_x, center_y)
        cr.stroke()
        
        self._draw_endpoint_dot(cr, left_x, center_y, dot_radius, 0.6)
        self._draw_endpoint_dot(cr, right_x, center_y, dot_radius, 0.6)
    
    def _draw_playing_strings(self, cr, width, height, padding_x, padding_y,
                              draw_width, draw_height, center_y,
                              left_x, right_x, dot_radius):
        """Multiple soft flowing strings"""
        
        line_spacing = draw_height / (self.num_lines + 1)
        step = draw_width / (self.sample_count - 1)
        
        for line_idx in range(self.num_lines):
            spread_y = padding_y + line_spacing * (line_idx + 1)
            phase = self.line_phases[line_idx]
            depth = 0.6 + (line_idx / (self.num_lines - 1)) * 0.4
            opacity = (0.15 + (line_idx / (self.num_lines - 1)) * 0.85) * self.play_intensity
            color = (*self.base_color, opacity)
            line_width = 1.0 + (line_idx / (self.num_lines - 1)) * 1.5
            
            points = []
            for i in range(self.sample_count):
                x = left_x + i * step
                t = i / (self.sample_count - 1)
                convergence = math.sin(t * math.pi) ** 0.7
                
                base_y = center_y + (spread_y - center_y) * convergence
                audio_amp = (self.smoothed[i] / 7.0) * (line_spacing * 0.9) * depth
                
                wave1 = math.sin(phase + i * 0.08) * 2.5 * depth
                wave2 = math.sin(phase * 0.8 + i * 0.05) * 1.5 * depth
                wave3 = math.sin(phase * 0.5 + i * 0.1) * 1.0 * depth
                organic_wave = (wave1 + wave2 + wave3) * self.play_intensity * 0.7
                
                audio_wave = audio_amp * math.sin(i * 0.06 + phase * 0.3) * 0.8
                y = base_y + organic_wave + audio_wave * self.play_intensity
                
                points.append((x, y))
            
            if line_idx >= self.num_lines - 3:
                cr.set_line_width(line_width + 5)
                cr.set_source_rgba(*self.base_color, 0.1 * self.play_intensity)
                cr.set_line_cap(1)
                cr.set_line_join(1)
                self._draw_smooth_path(cr, points)
                cr.stroke()
            
            cr.set_line_width(line_width)
            cr.set_source_rgba(*color)
            cr.set_line_cap(1)
            cr.set_line_join(1)
            self._draw_smooth_path(cr, points)
            cr.stroke()
        
        intensity = min(1.0, self.play_intensity + 0.2)
        self._draw_endpoint_dot(cr, left_x, center_y, dot_radius, intensity)
        self._draw_endpoint_dot(cr, right_x, center_y, dot_radius, intensity)
    
    def _draw_smooth_path(self, cr, points):
        """Draw smooth bezier curve"""
        if len(points) < 2:
            return
        
        cr.move_to(points[0][0], points[0][1])
        
        for i in range(1, len(points)):
            x, y = points[i]
            prev_x, prev_y = points[i - 1]
            tension = 0.4
            cp1_x = prev_x + (x - prev_x) * tension
            cp2_x = x - (x - prev_x) * tension
            cr.curve_to(cp1_x, prev_y, cp2_x, y, x, y)
    
    def _draw_endpoint_dot(self, cr, x, y, radius, intensity):
        """Circular endpoint with glow"""
        cr.arc(x, y, radius + 5, 0, 2 * math.pi)
        cr.set_source_rgba(*self.base_color, 0.12 * intensity)
        cr.fill()
        
        cr.arc(x, y, radius + 2, 0, 2 * math.pi)
        cr.set_source_rgba(*self.base_color, 0.25 * intensity)
        cr.fill()
        
        cr.arc(x, y, radius, 0, 2 * math.pi)
        cr.set_source_rgba(*self.base_color, 0.85 * intensity)
        cr.fill()
        
        cr.arc(x, y, radius * 0.35, 0, 2 * math.pi)
        cr.set_source_rgba(1, 1, 1, 0.35 * intensity)
        cr.fill()
    
    def cleanup(self):
        """Clean up"""
        if hasattr(self, 'animation_id') and self.animation_id:
            GLib.source_remove(self.animation_id)
            self.animation_id = None
        
        if self.cava:
            try:
                self.cava.terminate()
                self.cava.wait(timeout=1)
            except:
                try:
                    self.cava.kill()
                except:
                    pass
            self.cava = None
    
    def __del__(self):
        self.cleanup()


# ═══════════════════════════════════════════════════════════════
# Standalone Window (with proper class for Hyprland rules)
# ═══════════════════════════════════════════════════════════════

def main():
    import sys
    
    class WaveformWindow(Gtk.ApplicationWindow):
        """
        Window class: waveform-visualizer
        Window title: Waveform Visualizer
        """
        def __init__(self, app):
            super().__init__(application=app)
            
            # Set window properties for Hyprland rules
            self.set_title("Waveform Visualizer")
            self.set_resizable(False)  # Not resizable
            self.set_decorated(False)  # No decorations
            self.set_default_size(WaveformVisualizer.WIDTH, WaveformVisualizer.HEIGHT)
            
            # Dark transparent background
            css = """
            window {
                background-color: rgba(26, 29, 35, 0.8);
                border-radius: 12px;
            }
            window.background {
                background-color: rgba(26, 29, 35, 0.8);
            }
            .waveform-visualizer {
                margin: 0;
            }
            """
            provider = Gtk.CssProvider()
            provider.load_from_data(css.encode())
            Gtk.StyleContext.add_provider_for_display(
                Gdk.Display.get_default(), provider,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            )
            
            # Add visualizer
            self.visualizer = WaveformVisualizer()
            self.set_child(self.visualizer)
        
        def do_close_request(self):
            self.visualizer.cleanup()
            return False
    
    class WaveformApp(Gtk.Application):
        """
        App ID: waveform-visualizer
        WM Class: waveform-visualizer
        """
        def __init__(self):
            # Use simple ID for WM class matching
            super().__init__(application_id="waveform-visualizer")
            GLib.set_prgname("waveform-visualizer")
            GLib.set_application_name("Waveform Visualizer")
        
        def do_activate(self):
            win = WaveformWindow(self)
            win.present()
    
    app = WaveformApp()
    sys.exit(app.run(sys.argv))


if __name__ == "__main__":
    main()