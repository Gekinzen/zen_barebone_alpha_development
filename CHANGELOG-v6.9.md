# Zen Shell v6.9 — Changelog

## v6.9 — Phase 1A: Bar Widgets + Display Persistence

### New QML Services

**WeatherService.qml** — singleton weather data provider.
Fetches from Open-Meteo (free, no API key). Auto-detects location
via ipapi.co. Caches to ~/.cache/zen-shell/weather.json. Refreshes
every 30 minutes. Bar modules and desktop widgets bind to its
properties: temperature, condition, icon, humidity, windSpeed,
forecast (7-day array), locationName.

**SystemMonitorService.qml** — singleton system stats provider.
Reads from /proc/stat, /proc/meminfo, /sys/class/hwmon (AMD GPU),
nvidia-smi (NVIDIA), /proc/net/dev. No Python or psutil dependency.
Updates every 2 seconds. Provides: cpuPercent, cpuTemp, cpuName,
gpuUsage, gpuTemp, gpuVramUsed, gpuName, ramPercent, ramUsedGb,
ramTotalGb, netDown, netUp. Includes 40-point history arrays for
graphing. Color helper functions: tempColor(), usageColor().

### New Bar Modules

**ZenWeather.qml** — compact bar weather module. Shows weather icon
(Nerd Font) + temperature + condition text. Tooltip expands to show
feels-like, humidity, wind, location, and last-updated time. Add
"weather" to Theme.barLayout.right to enable.

**ZenSysMonitor.qml** — compact bar system monitor. Shows CPU% with
temp, RAM used (GB), GPU temp. All color-coded (green/yellow/orange/red).
Tooltip shows full details: CPU name + per-core hint, GPU name + VRAM,
RAM total, network speeds. Add "sysmonitor" to Theme.barLayout.right.

**ZenClock.qml** (enhanced) — bar clock with PanelState format binding.
Multiline support for date+time formats. Auto-applies when user changes
format in Bar Modules settings.

**ZenWorkspaces.qml** (enhanced) — configurable workspace count via
PanelState.workspaceLimit (default 5, range 3-10). Bar Modules page
now has a "Visible count" dropdown. Active workspace highlighted,
click to switch via hyprctl dispatch.

### Display Persistence

Monitor configuration now persists across logout and animation reload.
When you apply a monitor setting (resolution, Hz, scale, rotation,
position), it writes to ~/.config/hypr/hyprland-monitors.conf. The
installer auto-adds `source = ~/.config/hypr/hyprland-monitors.conf`
to hyprland.conf if not already present.

The draggable monitor preview also applies positions via hyprctl AND
saves to the conf file simultaneously. No more "nag-change ng display
tas pagbalik reset" problem.

### Bar.qml Updates

Module factory now includes "weather" and "sysmonitor" components.
To add them to your bar, edit Theme.barLayout in your theme JSON:
```json
"barLayout": {
  "left": ["start", "workspaces", "taskbar"],
  "center": ["clock"],
  "right": ["weather", "sysmonitor", "tray", "sysrow", "notifications"]
}
```

### Other Changes

- PanelState: added workspaceLimit property (default 5)
- BarModulesPage: workspace limit dropdown (3-10), preview uses
  dynamic count
- ZenSettings sidebar: left corners now rounded to match parent radius
- ColorSwatch: Popup-based picker (proper z-order, no clipping)
- WallpaperPicker: dynamic column count, no 5th-item overflow
- WallpaperServiceV5: page size 8 (was 10)
- install.sh: clean design, no emoji, elegant output

## Files

### New in v6.9
- zen-shell-v5/WeatherService.qml
- zen-shell-v5/SystemMonitorService.qml
- zen-shell-v5/ZenWeather.qml
- zen-shell-v5/ZenSysMonitor.qml

### Modified in v6.9
- zen-shell-v5/Bar.qml (weather + sysmonitor modules)
- zen-shell-v5/PanelState.qml (workspaceLimit)
- zen-shell-v5/BarModulesPage.qml (ws limit dropdown, dynamic preview)
- zen-shell-v5/DisplaysPage.qml (persistence to hyprland-monitors.conf)
- zen-shell-v5/ZenClock.qml (enhanced)
- zen-shell-v5/ZenWorkspaces.qml (configurable limit)
- zen-shell-v5/ZenSettings.qml (sidebar corner fix)
- zen-shell-v5/ColorSwatch.qml (Popup z-order fix)
- zen-shell-v5/WallpaperPicker.qml (dynamic columns)
- zen-shell-v5/WallpaperServiceV5.qml (page size 8, swww multi-session)
- install.sh (elegant redesign)

## Install

    tar -xzf zen-shell-v6_9-complete.tar.gz
    cd zen-shell-v6_9-complete
    ./install.sh

## Next (Phase 1B)

- Desktop overlay widgets (QML layer-shell clock, weather, sysmon)
- Start menu auto-detect island position + button size adjustment
- Notification position settings (9-grid)
- Keybind shortcut cheatsheet popup
- Primary monitor selection in display settings
- Animation reload should not reset display config
