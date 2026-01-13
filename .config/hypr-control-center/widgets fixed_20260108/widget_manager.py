#!/usr/bin/env python3
# ~/.config/hypr-control-center/widgets/widget_manager.py
"""
Widget Manager - Launch and manage all desktop widgets
"""

import subprocess
import sys
import os
from pathlib import Path

def main():
    # Get widgets directory
    widgets_dir = Path.home() / ".config/hypr-control-center/widgets"
    
    # Add widgets directory to Python path for imports
    if str(widgets_dir) not in sys.path:
        sys.path.insert(0, str(widgets_dir))
    
    # Change to widgets directory
    os.chdir(str(widgets_dir))
    
    # List of widgets to launch
    widgets = [
        "clock_widget.py",
        "weather_widget.py",
        "system_monitor.py"
    ]
    
    processes = []
    
    print(" Starting Desktop Widgets...")
    print("=" * 60)
    
    for widget in widgets:
        widget_path = widgets_dir / widget
        if widget_path.exists():
            print(f" Starting {widget}...")
            
            # Launch widget with proper environment
            env = os.environ.copy()
            env['PYTHONPATH'] = str(widgets_dir)
            
            proc = subprocess.Popen(
                [sys.executable, str(widget_path)],
                cwd=str(widgets_dir),
                env=env
            )
            processes.append(proc)
        else:
            print(f"⚠️  Warning: {widget} not found")
    
    print("=" * 60)
    print(f" {len(processes)} widget(s) started successfully")
    print(f"📍 Config: ~/.config/hypr-control-center/preferences/widgets.json")
    print(f"🎨 Theme: Synced with Control Center")
    print("\nPress Ctrl+C to stop all widgets\n")
    
    # Wait for all processes
    try:
        for proc in processes:
            proc.wait()
    except KeyboardInterrupt:
        print("\n🛑 Shutting down widgets...")
        for proc in processes:
            proc.terminate()
        print(" All widgets stopped")

if __name__ == "__main__":
    main()