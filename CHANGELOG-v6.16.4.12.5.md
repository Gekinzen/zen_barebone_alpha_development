# Zen Shell v6.16.4.12.5 — Hikari (光)

**Release date:** 2026-04-27
**Base:** v6.16.4.11.2 Kintsugi
**Severity:** FEATURE RELEASE — additive changes, non-breaking
**Status:** Alpha
**Codename:** Hikari (光) — light, illumination

---

## Revision history within v6.16.4.12

| Revision | Notes |
|----------|-------|
| .1 | Initial Hikari drop. Panel position, profile export/import, per-monitor widgets, display drag rewrite, volume cap, monitor recovery service, calendar in shell.qml. |
| .2 | Calendar moved into Clock.qml as inline PopupWindow with click toggle. Format selector pills added. Internal popup elements flattened (no nested boxes). |
| .3 | Switched popup activation from click to hover. Used SysRowIcon tooltip pattern (anchor.item + Edges.Top). Removed redundant peek popup. |
| .4 | Fixed popup not rendering: PopupWindow requires `width:` and `height:` directly, not `implicitWidth/Height` (despite deprecation warning). Removed calendar bar module from picker since clock module already shows calendar on hover. |
| .5 | ZenComboBox: custom delegate with WCAG 2.0 luminance-aware text color (white on dark themes, dark on light themes for highlighted blue rows). Added 4px footer padding so last item in dropdown is fully clickable on Wayland. |


---

## Overview

This release opens the Hikari cycle. The theme is illumination across every
surface of the shell. Panels can now sit at the top or bottom of the screen.
Profiles capture and restore complete shell configurations as portable JSON.
Per-monitor widget control replaces the previous binary primary-or-all toggle.
The display preview is rebuilt on top of GPU-composited primitives. The clock
opens an inline panel containing the calendar, notification status, and
system actions in a single surface. Volume is hard-capped at 100 percent
across every entry point. A monitor recovery service runs in the background
to prevent the user from disabling their last working display.

The release contains four new singleton or component QML files, fourteen
modified files, one modified script, and adds two new state directories
under the user configuration tree. All existing state files continue to load
without migration.

---

## Paul's reports leading to this release

The work in this cycle was driven by a sequence of issues raised over the
course of one development session. Each item below was a specific request.

1. The display configuration preview was using a Canvas, which produced
   visible jank when dragging monitor positions. Snapping was correct but
   the drag itself stuttered. Zooming the preview was not possible. There
   was no way to disable an external monitor without dropping to a
   terminal and editing Hyprland configuration directly.

2. Widget display was binary — either primary monitor only, or all
   monitors. The user wanted explicit per-monitor control: pick HDMI-A-1
   and eDP-1, exclude DP-1.

3. The volume slider permitted values from 0 to 150, with a soft boost
   region above 100 displayed in orange. The user wanted the value
   strictly clamped at 100 across the slider, the wpctl invocation, and
   the keyboard volume keys.

4. The panel was hard-coded to the bottom of the screen. The user wanted
   to choose between top and bottom positioning, with all overlay surfaces
   adapting to the selection.

5. The user requested the v6.16.4.12 Hikari profile export and import
   feature described in the project roadmap, captured as a single
   portable JSON file.

6. The clock click handler opened a standalone calendar popup. The user
   wanted that popup unified with notification status and system quick
   actions in one surface — notifications row at the top, calendar in the
   middle, Bluetooth, WiFi, Lock, Logout, Restart, Shutdown buttons at the
   bottom.

7. The user noted that disabling an external monitor and then unplugging
   it would leave the laptop with no working display. The user mentioned
   they had a fallback compositor (cosmic) but recognized that this was
   a panic-prone failure mode that needed automatic recovery.

---

## Root cause analysis

### Display preview drag jank

The previous preview used a Canvas element with imperative paint() calls
fired on every onPositionChanged event from a single MouseArea. Each paint
invalidated the entire canvas, recomputed monitor rectangles, and
re-rasterized text. At 1920x1080 with three monitors, this ran at roughly
12 frames per second on the user's hardware.

A first attempt replaced the Canvas with per-monitor MouseAreas attached
to QML Rectangle delegates. That introduced a coordinate-space feedback
loop: monRect.x was bound to baseX + dragOffsetX, and the next
onPositionChanged computed dragOffsetX from mouse.x + monRect.x, which
already contained the previous offset. Each frame compounded the error
exponentially and the dragged rectangle flew off-screen on the first move.

The correct fix uses a single parent-level MouseArea covering the entire
preview area, which has stable coordinates that never include the drag
offset. Hit-testing on press identifies the dragged monitor; subsequent
position changes compute the offset as a pure subtraction from the press
point.

### Widget display granularity

The widgetDisplay property accepted only "primary" or "all". The
visibility binding on the widget PanelWindow was a single-line ternary.
Moving to per-monitor control required adding a widgetMonitors array
property on DesktopWidgets, threading it through the state save and load
payload, and replacing the visibility binding with an array membership
check that falls back to the legacy widgetDisplay value when
widgetMonitors is empty.

### Volume cap

Three independent surfaces accepted volume values: the ControlPanel
slider with to:150, the ConnectivityPage slider with to:150, and the
wpctl invocation in zen-volume-notify.sh with -l 1.5. Each surface
needed its own clamp. The ConnectivityService setVolume function
performed a Math.min(150, vol) clamp on input, which had to become
Math.min(100, vol). The wpctl read in the same service also needed an
output clamp because external tools (pavucontrol, headset buttons) could
push the system value above 100, and that value would otherwise display
in the UI.

### Panel position

PanelState.panelMode controlled fullwidth, floating, and island styling
but did not address vertical placement. Adding position required:

1. A new panelPosition property on PanelState accepting "top" or
   "bottom".
2. An isTop computed convenience property.
3. A companion panelMarginTop for the existing panelMarginBottom.
4. Anchor flips on every overlay window in shell.qml: the bar itself,
   the start menu (which opens from the bar edge), the calendar popup,
   and the ZenStrings overlay. Each surface needed both anchors.bottom
   and anchors.top driven by isTop, plus margins.bottom and margins.top
   similarly conditional.
5. An update to StartMenu.qml globalY calculation, which previously
   assumed bottom-anchored bars (screenH - barHeight) and now must
   conditionally use barHeight when at the top.

### Profile export and import

The roadmap entry called for a full-system snapshot. Implementation
required:

1. A new singleton UserProfileExportService that captures Theme,
   PanelState, SettingsStateV2, WallpaperService state, and bar layout
   into a single JSON object.
2. A new UI component ProfileManagerSection placed at the top of
   GeneralPage, providing Save (with zenity name prompt), Overwrite,
   Import (with zenity file picker), Export (to ~/Downloads), Activate,
   and Delete actions.
3. A new state directory at ~/.config/zen-shell/profiles/ with
   per-profile JSON files and an active-profile.state pointer.
4. A _buildSnapshot and _applySnapshot pair on the service that handle
   the capture and restoration. _applySnapshot validates the _format
   field to reject foreign JSON.

### Inline calendar popup

The previous design had a standalone calendar window in shell.qml
anchored to the bottom-right of the screen, controlled by
PanelState.calendarVisible. Wiring the click handler in Clock.qml to
toggle that property required four hops: Clock to PanelState to
shell.qml binding to window visibility. The user reported that clicks
appeared to do nothing.

The fix replaces all of that with an inline PopupWindow declared
directly inside Clock.qml. The popup's anchor.window is bound to
QsWindow.window and its anchor.rect.x and anchor.rect.y are computed
from clockRoot.x and clockRoot.width. This means the popup automatically
positions itself relative to the clock module wherever the clock sits
in the bar layout — left zone, center zone, or right zone, top-anchored
or bottom-anchored bar.

Inside the popup are three sections in a ColumnLayout: a notifications
row showing count and DND state (clicking the row opens swaync via
swaync-client -t -sw), a calendar grid with prev and next navigation
and today highlighting, and a 4-column GridLayout of system action
buttons (Bluetooth toggle, WiFi toggle, Lock, Logout, Restart, Shutdown).

### Monitor recovery service

Disabling the only working monitor produces an unrecoverable state from
within the shell — the user cannot see the UI to undo the action. The
existing UI guard counted enabled monitors but did not check whether
those monitors were physically connected, so a phantom enabled-but-
unplugged monitor would satisfy the guard while the user lost their
display.

The fix has three layers:

1. A stronger UI guard. DisplaysPage adds a physicallyConnectedCount
   helper and a workingDisplayCount helper that requires both !disabled
   and availableModes.length > 0. The disable toggle refuses if
   workingDisplayCount() <= 1.

2. A new MonitorRecoveryService singleton that polls
   hyprctl monitors all -j every five seconds. It detects two panic
   states: every monitor disabled, and a disabled monitor that is the
   only physically-connected one. In both cases it emits an
   hyprctl keyword monitor call to re-enable the monitor at native
   resolution.

3. Persistence repair. After re-enabling, the service rewrites
   ~/.config/hypr/hyprland-monitors.conf to remove the offending
   <n>,disable line, so the recovery survives a reboot.

The service is activated by binding MonitorRecoveryService to a
readonly property var in the shell root. Quickshell singletons are
lazy by default; touching the singleton instantiates it.

---

## Files changed from 4.11.2

```
NEW
  zen-shell-v5/UserProfileExportService.qml   profile snapshot singleton
  zen-shell-v5/ProfileManagerSection.qml      profile management UI
  zen-shell-v5/MonitorRecoveryService.qml     auto-recovery singleton
  zen-shell-v5/CalendarButton.qml             alt bar module
  CHANGELOG-v6.16.4.12.md                      this file

UPDATED
  zen-shell-v5/Clock.qml                       inline calendar popup
  zen-shell-v5/PanelState.qml                  panelPosition + isTop + margins
  zen-shell-v5/PanelPage.qml                   position selector + module list
  zen-shell-v5/Bar.qml                         registered calendar module
  zen-shell-v5/StartMenu.qml                   top-bottom + sticky 2px gap
  zen-shell-v5/GeneralPage.qml                 ProfileManagerSection
  zen-shell-v5/DisplaysPage.qml                drag fix + zoom + disable + guard
  zen-shell-v5/WidgetsPage.qml                 per-monitor widget toggles
  zen-shell-v5/DesktopWidgets.qml              widgetMonitors array
  zen-shell-v5/ConnectivityService.qml         volume 0-100 clamp
  zen-shell-v5/ControlPanel.qml                slider to 100
  zen-shell-v5/ConnectivityPage.qml            slider to 100
  zen-shell-v5/shell.qml                       position-aware anchors + recovery
  zen-shell-v5/ZenVersion.qml                  v6.16.4.12 Hikari
  scripts/zen-volume-notify.sh                 wpctl -l 1.0
  README.md                                    Hikari section
```

---

## State files

New paths added under the user configuration tree.

```
~/.config/zen-shell/profiles/
~/.config/zen-shell/profiles/active-profile.state
~/.config/zen-shell/profiles/<n>.json
```

~/.config/hypr/hyprland-monitors.conf is now written by the monitor
recovery service in addition to the displays page. The file is created
on first write if it does not exist.

---

## Behavior changes

### Default values

```
PanelState.panelPosition       new property,   default "bottom"
DesktopWidgets.widgetMonitors  new property,   default []
ConnectivityService volume cap was 150,         now 100
wpctl set-volume limit         was 1.5,         now 1.0
```

### Compatibility

- Existing panel-state.json loads cleanly. The new panelPosition property
  defaults to "bottom", matching previous behavior.
- Existing widgets-state.json loads cleanly. Empty widgetMonitors array
  triggers the legacy widgetDisplay fallback.
- Volume values previously stored above 100 are clamped on first read.
- Monitor recovery service runs unconditionally on shell start. To
  disable it, remove the _monitorRecoveryActivator binding from
  shell.qml.

---

## Install and test

```bash
tar -xzf zen-shell-v6.16.4.12.tgz
cd zen-shell-v6.16.4.12
./install.sh
~/.local/bin/zs-restart.sh
```

Or use the bundled quick installer next to the archive:

```bash
chmod +x install-quick.sh
./install-quick.sh
```

### Verification steps

1. Open Settings, navigate to Panel section. Confirm a Panel Position
   card group shows Top and Bottom options. Click Top. The bar should
   move to the top of the screen, and the start menu, calendar popup,
   and strings overlay should adjust their anchoring accordingly.

2. Click the clock module. An inline popup should open, anchored to
   the clock screen position. The popup contains a notifications row
   at the top, a full month calendar in the middle, and a grid of
   system action buttons at the bottom.

3. Open Settings, navigate to General. The page should begin with a
   Profiles section. Click Save, enter a profile name, confirm. Verify
   the file appears at ~/.config/zen-shell/profiles/<n>.json. Open the
   file and inspect the captured state.

4. Open Settings, navigate to Displays. Drag a monitor in the preview.
   The drag should be smooth without exponential drift. Use the zoom
   buttons in the top-right of the preview to verify scaling. Toggle
   the Enable switch on a monitor that is not the only working display.
   Verify the monitor disables. Toggle a monitor that IS the only
   working display. Verify the toggle refuses with a warning message.

5. Open Settings, navigate to Widgets. The Widget Display section
   should show a per-monitor toggle for each connected display. Toggle
   monitors on and off. Verify desktop widgets appear or disappear on
   the corresponding monitor.

6. Use the volume slider in the Control Panel and the Connectivity
   page. Confirm both slide from 0 to 100, no further. Press the
   keyboard volume up key past system 100. Confirm the volume does
   not exceed 100.

7. Connect an external monitor. Open Displays, disable the laptop
   panel. Wait approximately five seconds. Verify the monitor recovery
   service does NOT activate while the external is still working.
   Disconnect the external. Within five seconds the laptop panel
   should re-enable automatically and the entry in
   ~/.config/hypr/hyprland-monitors.conf should be cleaned up.

---

## Known limitations

- Left and right panel positions are not yet implemented. The
  panelPosition property accepts "top" and "bottom" only. Left and
  right require a Bar layout rewrite from RowLayout to ColumnLayout
  and are deferred to a future release.

- The notification panel inside the clock popup shows count and DND
  state only. Individual notification entries are not listed. Clicking
  the notifications row opens swaync, which provides the full list. A
  native notification list inside the popup is on the roadmap.

- Profile import does not currently merge with existing state; it
  replaces. A merge mode that preserves user-specific keys (window
  positions, recent files) is planned for a future release.

- The monitor recovery service runs every five seconds. A more
  efficient implementation would subscribe to Hyprland's monitoradded
  and monitorremoved events, but the current polling approach is
  reliable across Hyprland versions and adds approximately 0.1 percent
  CPU overhead.
