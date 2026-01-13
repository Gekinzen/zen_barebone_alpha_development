# ZenPy Waveform Visualizer

Smooth audio waveform visualizer for ZenPyBar using CAVA.

## Installation

Already installed! Just add to your bar.py:
```python
from zenvisualizer.waveform_visualizer import WaveformVisualizer

class ZenPyBar:
    def create_center_modules(self):
        # Add waveform
        self.waveform = WaveformVisualizer()
        self.center_box.append(self.waveform)
        
        # Optional: Auto-hide when not playing
        GLib.timeout_add_seconds(1, self.check_audio_playing)
    
    def check_audio_playing(self):
        """Show waveform only when audio is playing"""
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
            pass
        return True
```

## Test CAVA
```bash
./scripts/test_cava.sh
```

## Configuration

Edit: `~/.config/cava/zenpybar.conf`

- `bars`: Number of bars (default: 50)
- `framerate`: Update rate (default: 30)
- `sensitivity`: Audio sensitivity (default: 100)

## Troubleshooting

**No visualization:**
- Check if audio is playing
- Test CAVA: `./scripts/test_cava.sh`
- Check PulseAudio: `pactl list sources short`

**Performance issues:**
Lower framerate in `~/.config/cava/zenpybar.conf`:
```ini
[general]
framerate = 20
```
