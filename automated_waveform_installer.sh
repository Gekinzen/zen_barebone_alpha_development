#!/bin/bash
# waveform_visualizer_installer.sh - CORRECT PATHS

echo "=========================================="
echo "  ZenPy Waveform Visualizer Installer"
echo "  Correct paths for .config setup 🎵"
echo "=========================================="
echo ""

# Correct paths
CONFIG_DIR="$HOME/.config/hypr-control-center"
ASSETS_DIR="$CONFIG_DIR/assets"
SRC_DIR="$CONFIG_DIR/src"
MODULES_DIR="$SRC_DIR/modules"
BAR_FILE="$SRC_DIR/bar.py"
MAIN_CSS="$ASSETS_DIR/style.css"

# Create directories
mkdir -p "$MODULES_DIR"
mkdir -p "$ASSETS_DIR"

echo "✓ Directories ready"
echo ""

# Step 1: Install dependencies
echo "Step 1: Installing dependencies..."

# CAVA
if ! command -v cava &> /dev/null; then
    echo "  Installing CAVA..."
    sudo pacman -S --noconfirm cava
else
    echo "  ✓ CAVA already installed"
fi

# GTK4 Layer Shell
if ! pacman -Q gtk4-layer-shell &> /dev/null; then
    echo "  Installing gtk4-layer-shell..."
    sudo pacman -S --noconfirm gtk4-layer-shell
else
    echo "  ✓ gtk4-layer-shell installed"
fi

# Python GTK4 Layer Shell bindings
if ! python -c "import gi; gi.require_version('Gtk4LayerShell', '1.0')" 2>/dev/null; then
    echo "  Installing python-gtk4-layer-shell..."
    if command -v yay &> /dev/null; then
        yay -S --noconfirm python-gtk4-layer-shell
    elif command -v paru &> /dev/null; then
        paru -S --noconfirm python-gtk4-layer-shell
    else
        echo "  ⚠ Install manually: yay -S python-gtk4-layer-shell"
    fi
else
    echo "  ✓ python-gtk4-layer-shell installed"
fi

# playerctl
if ! command -v playerctl &> /dev/null; then
    sudo pacman -S --noconfirm playerctl
fi

# pamixer
if ! command -v pamixer &> /dev/null; then
    sudo pacman -S --noconfirm pamixer
fi

echo ""
echo "Step 2: Creating waveform visualizer module..."

# Create waveform_visualizer.py
cat > "$MODULES_DIR/waveform_visualizer.py" << 'WAVEFORM_EOF'
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
WAVEFORM_EOF

echo "✓ Created waveform_visualizer.py"

# Create __init__.py if doesn't exist
if [ ! -f "$MODULES_DIR/__init__.py" ]; then
    touch "$MODULES_DIR/__init__.py"
    echo "✓ Created modules/__init__.py"
fi

echo ""
echo "Step 3: Creating visualizer.css..."

# Create visualizer.css
cat > "$ASSETS_DIR/visualizer.css" << 'VISUALIZER_CSS_EOF'
/* ═══════════════════════════════════════════════════════════════ */
/* Waveform Visualizer Styles                                       */
/* ═══════════════════════════════════════════════════════════════ */

.waveform-visualizer {
    margin: 0 20px;
    min-width: 220px;
    min-height: 40px;
    background: transparent;
}

/* Optional: Container for waveform */
.waveform-container {
    background: rgba(40, 44, 52, 0.5);
    border-radius: 8px;
    padding: 4px 8px;
}
VISUALIZER_CSS_EOF

echo "✓ Created visualizer.css"

echo ""
echo "Step 4: Updating main style.css to import visualizer.css..."

# Check if import already exists
if ! grep -q "visualizer.css" "$MAIN_CSS"; then
    # Add import after other imports
    sed -i "/^@import url('start-menu.css');/a @import url('visualizer.css');" "$MAIN_CSS"
    echo "✓ Added import to style.css"
else
    echo "✓ Import already exists in style.css"
fi

echo ""
echo "Step 5: Backup and update bar.py..."

# Backup existing bar.py
if [ -f "$BAR_FILE" ]; then
    BACKUP_DIR="$HOME/.config/hypr-control-center/backups"
    mkdir -p "$BACKUP_DIR"
    cp "$BAR_FILE" "$BACKUP_DIR/bar.py.backup.$(date +%Y%m%d_%H%M%S)"
    echo "✓ Backed up bar.py"
fi

# Create complete bar.py
cat > "$BAR_FILE" << 'BARPY_EOF'
#!/usr/bin/env python3
"""
ZenPyBar - Main Bar Module
Hyprland status bar with waveform visualizer
"""

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Gtk4LayerShell', '1.0')
from gi.repository import Gtk, GLib, Gdk
import Gtk4LayerShell as LayerShell
import subprocess
import os
import sys
from pathlib import Path
from datetime import datetime

# Add modules to path
sys.path.insert(0, str(Path(__file__).parent))

from modules.waveform_visualizer import WaveformVisualizer


class SimpleClock(Gtk.Box):
    """Simple clock widget"""
    
    def __init__(self):
        super().__init__(orientation=Gtk.Orientation.HORIZONTAL)
        self.add_css_class("clock-widget")
        self.set_spacing(10)
        
        self.time_label = Gtk.Label()
        self.time_label.add_css_class("clock-time")
        
        self.date_label = Gtk.Label()
        self.date_label.add_css_class("clock-date")
        
        self.append(self.time_label)
        self.append(self.date_label)
        
        GLib.timeout_add_seconds(1, self.update)
        self.update()
    
    def update(self):
        now = datetime.now()
        self.time_label.set_label(now.strftime("%H:%M"))
        self.date_label.set_label(now.strftime("%a %d"))
        return True


class SimpleVolume(Gtk.Box):
    """Simple volume indicator"""
    
    def __init__(self):
        super().__init__(orientation=Gtk.Orientation.HORIZONTAL)
        self.add_css_class("volume-widget")
        self.set_spacing(5)
        
        self.icon_label = Gtk.Label()
        self.icon_label.add_css_class("volume-icon")
        
        self.volume_label = Gtk.Label()
        self.volume_label.add_css_class("volume-text")
        
        self.append(self.icon_label)
        self.append(self.volume_label)
        
        GLib.timeout_add_seconds(2, self.update)
        self.update()
    
    def update(self):
        try:
            result = subprocess.run(
                ['pamixer', '--get-volume'],
                capture_output=True,
                text=True,
                timeout=1
            )
            volume = int(result.stdout.strip())
            
            mute_result = subprocess.run(
                ['pamixer', '--get-mute'],
                capture_output=True,
                text=True,
                timeout=1
            )
            is_muted = mute_result.stdout.strip() == 'true'
            
            if is_muted:
                self.icon_label.set_label("󰖁")
                self.volume_label.set_label("Muted")
            else:
                if volume == 0:
                    icon = "󰖁"
                elif volume < 30:
                    icon = "󰕿"
                elif volume < 70:
                    icon = "󰖀"
                else:
                    icon = "󰕾"
                
                self.icon_label.set_label(icon)
                self.volume_label.set_label(f"{volume}%")
        except:
            self.icon_label.set_label("󰖁")
            self.volume_label.set_label("N/A")
        
        return True


class ZenPyBar(Gtk.ApplicationWindow):
    """Main bar window"""
    
    def __init__(self, app, monitor_id=0):
        super().__init__(application=app)
        self.monitor_id = monitor_id
        
        self.setup_layer_shell()
        self.create_ui()
        self.load_css()
        self.present()
        
    def setup_layer_shell(self):
        """Configure GTK Layer Shell"""
        LayerShell.init_for_window(self)
        LayerShell.set_layer(self, LayerShell.Layer.TOP)
        LayerShell.set_namespace(self, f"zenpybar-{self.monitor_id}")
        
        display = Gdk.Display.get_default()
        monitors = []
        for i in range(display.get_n_monitors()):
            monitors.append(display.get_monitor(i))
        
        if self.monitor_id < len(monitors):
            LayerShell.set_monitor(self, monitors[self.monitor_id])
        
        LayerShell.set_anchor(self, LayerShell.Edge.TOP, True)
        LayerShell.set_anchor(self, LayerShell.Edge.LEFT, True)
        LayerShell.set_anchor(self, LayerShell.Edge.RIGHT, True)
        
        LayerShell.set_margin(self, LayerShell.Edge.TOP, 0)
        LayerShell.set_margin(self, LayerShell.Edge.LEFT, 0)
        LayerShell.set_margin(self, LayerShell.Edge.RIGHT, 0)
        
        LayerShell.auto_exclusive_zone_enable(self)
        LayerShell.set_keyboard_mode(self, LayerShell.KeyboardMode.NONE)
        
    def create_ui(self):
        """Create bar UI"""
        main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        main_box.add_css_class("bar-window")
        
        self.bar_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        self.bar_box.add_css_class("bar-container")
        self.bar_box.set_spacing(0)
        
        # Left
        self.left_box = self.create_left_modules()
        self.left_box.set_halign(Gtk.Align.START)
        self.left_box.set_hexpand(False)
        self.bar_box.append(self.left_box)
        
        # Center
        self.center_box = self.create_center_modules()
        self.center_box.set_halign(Gtk.Align.CENTER)
        self.center_box.set_hexpand(True)
        self.bar_box.append(self.center_box)
        
        # Right
        self.right_box = self.create_right_modules()
        self.right_box.set_halign(Gtk.Align.END)
        self.right_box.set_hexpand(False)
        self.bar_box.append(self.right_box)
        
        main_box.append(self.bar_box)
        self.set_child(main_box)
        
    def create_left_modules(self):
        """Create left section"""
        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        box.set_spacing(10)
        box.add_css_class("bar-section-left")
        
        workspaces = Gtk.Label(label="  ")
        workspaces.add_css_class("workspaces")
        box.append(workspaces)
        
        return box
    
    def create_center_modules(self):
        """Create center section with waveform"""
        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        box.set_spacing(15)
        box.add_css_class("bar-section-center")
        
        # Waveform visualizer
        try:
            self.waveform = WaveformVisualizer()
            box.append(self.waveform)
            GLib.timeout_add_seconds(1, self.check_audio_playing)
            print("✓ Waveform visualizer loaded")
        except Exception as e:
            print(f"✗ Waveform error: {e}")
        
        # Clock
        self.clock = SimpleClock()
        box.append(self.clock)
        
        return box
    
    def create_right_modules(self):
        """Create right section"""
        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        box.set_spacing(15)
        box.add_css_class("bar-section-right")
        
        self.volume = SimpleVolume()
        box.append(self.volume)
        
        power_btn = Gtk.Button(label="⏻")
        power_btn.add_css_class("power-button")
        power_btn.connect('clicked', lambda w: subprocess.run(['wlogout']))
        box.append(power_btn)
        
        return box
    
    def check_audio_playing(self):
        """Auto-hide waveform when not playing"""
        if not hasattr(self, 'waveform'):
            return False
        
        try:
            result = subprocess.run(
                ['playerctl', 'status'],
                capture_output=True,
                text=True,
                timeout=1
            )
            is_playing = result.stdout.strip() == 'Playing'
            self.waveform.set_visible(is_playing)
        except:
            self.waveform.set_visible(True)
        
        return True
    
    def load_css(self):
        """Load CSS from assets"""
        css_provider = Gtk.CssProvider()
        
        # Try to load from assets directory
        css_paths = [
            Path.home() / ".config/hypr-control-center/assets/style.css",
            Path(__file__).parent.parent / "assets/style.css",
        ]
        
        for css_path in css_paths:
            if css_path.exists():
                try:
                    css_provider.load_from_path(str(css_path))
                    Gtk.StyleContext.add_provider_for_display(
                        Gdk.Display.get_default(),
                        css_provider,
                        Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
                    )
                    print(f"✓ Loaded CSS from: {css_path}")
                    return
                except Exception as e:
                    print(f"Error loading CSS: {e}")
        
        print("⚠ No CSS found, using defaults")


class ZenPyBarApp(Gtk.Application):
    """Main application"""
    
    def __init__(self):
        super().__init__(application_id="com.zenpybar.waveform")
        self.bars = []
        
    def do_activate(self):
        display = Gdk.Display.get_default()
        n_monitors = display.get_n_monitors()
        
        print(f"🎵 ZenPyBar Starting...")
        print(f"📺 {n_monitors} monitor(s)")
        
        for i in range(n_monitors):
            try:
                bar = ZenPyBar(self, monitor_id=i)
                self.bars.append(bar)
                print(f"✓ Bar {i} created")
            except Exception as e:
                print(f"✗ Error monitor {i}: {e}")


def main():
    print("=" * 50)
    print("  ZenPyBar - Smooth Waveform Edition")
    print("=" * 50)
    
    app = ZenPyBarApp()
    try:
        app.run(None)
    except KeyboardInterrupt:
        print("\n👋 Shutting down...")


if __name__ == "__main__":
    main()
BARPY_EOF

chmod +x "$BAR_FILE"
echo "✓ Created bar.py"

echo ""
echo "=========================================="
echo "  Installation Complete! 🎵"
echo "=========================================="
echo ""
echo "Directory structure:"
echo "  ~/.config/hypr-control-center/"
echo "  ├── assets/"
echo "  │   ├── style.css (main CSS with imports)"
echo "  │   └── visualizer.css (new waveform styles)"
echo "  └── src/"
echo "      ├── bar.py (updated with waveform)"
echo "      └── modules/"
echo "          └── waveform_visualizer.py"
echo ""
echo "To start:"
echo "  pkill -f bar.py"
echo "  ~/.config/hypr-control-center/src/bar.py &"
echo ""
echo "Play music to test waveform!"
echo ""