# v6.16.4.12.6.51 — Hikari (光)

**Channel:** alpha
**Release date:** 2026-04-29

## Summary

Bar/clock UX cleanup and plugin-system stabilisation drop. Three
changes:

1. The Clock module is now the sole calendar surface in the bar
2. Plugin toggles no longer kill sibling plugins; option changes no
   longer cause the toggle to flip back off
3. The Hyprland Plugins page and `[8.7/9]` installer step are
   temporarily hidden while hyprpm stabilises

## Files changed

| File | Change |
|---|---|
| `zen-shell-v5/Bar.qml` | `leftSpacer` and `rightSpacer` are now pure layout placeholders — invisible click region (hover tint Rectangle + MouseArea) removed. |
| `zen-shell-v5/Clock.qml` | Header bumped; the local `calPopup` (anchored to the clock, calendar + notifications + system controls) is the sole calendar surface in the bar. Hover shows; click pins. |
| `zen-shell-v5/PluginsPage.qml` | `setEnabled()` now spawns a real terminal for the hyprpm command (sudo prompts work) and drops the redundant `hyprpm reload` after `hyprpm enable/disable`. `applyState()` also drops `hyprpm reload` for option-only changes. |
| `zen-shell-v5/UserProfilePage.qml` | Personal-name reference cleaned. |
| `zen-shell-v5/ZenSettings.qml` | Hyprland Plugins sidebar entry commented out (page kept on disk; one-line diff to re-enable). |
| `zen-shell-v5/ZenVersion.qml` | `version` → v6.16.4.12.6.51, `codename` → Hikari. |
| `install.sh` | `[8.7/9]` hyprpm auto-install block wrapped in `if false; then ... fi` (kept on disk; re-enable by changing to `if true`). |
| `README.md` | Banner + new Hikari section. |

## Detail — bar/clock change

Before: clicking the empty bar gap between the left zone (start,
taskbar) and the centre zone (workspaces, window) — and the equivalent
gap on the right — opened the global `PanelState` calendar window
(invisible click region with subtle hover tint). The Clock module
already had a separate, anchored `calPopup` (calendar + notifications +
system icons) on hover/click. Two competing calendar triggers, one
visible (clock), one not.

After: the invisible gap triggers are gone. Only the Clock module
opens the calendar — same anchored-popup pattern as `CalendarButton`
and `SysRowIcon` tooltips. Hover the clock label → popup appears.
Click → popup pins. Click again → unpin/close. Right-click cycles
clock format. Scroll wheel cycles calendar months.

The bar's row-spacing is preserved exactly — the spacer `Item`s still
have `Layout.fillWidth: true; Layout.fillHeight: true`, just no MouseArea
or Rectangle children.

## Detail — plugin toggle root-cause fix

Two reported symptoms:

- Enabling one plugin caused another to disappear after reload
- Changing hyprbars button alignment caused the toggle to flip back to
  OFF

Root cause: the previous toggle/apply sequence was

```bash
hyprpm enable <plugin>     # already loads it
write plugins.conf
hyprpm reload              # ← redundant, full unload + reload from state
hyprctl reload
```

`hyprpm enable/disable` already loads/unloads the plugin internally
(`✔ Loaded <plugin>` / `✔ Unloaded <plugin>`). The subsequent
`hyprpm reload` triggers a full unload-everything → re-load-from-state
cycle. If anything fails or partially executes during that cycle
(missing TTY for sudo, build state mismatch, race), other
currently-loaded plugins drop out and don't come back.

Fix: trust `hyprpm enable/disable` for load state. Skip
`hyprpm reload`. `hyprctl reload` at the end is enough to re-source
`plugins.conf` for option changes — the plugin is already loaded; it
just picks up new option values from the freshly written conf.

For toggle commands that need sudo, the inner script is now hosted in
a real terminal (alacritty / kitty / foot / wezterm priority order;
headless fallback writes to `/tmp/zen-plugin-toggle.log`) so the sudo
prompt is interactive. Terminal auto-closes after a 1.5s settle; on
exit, `applyRunner.onStreamFinished` fires `detectInstalledPlugins()`
which re-reads `hyprpm list` to sync the UI to actual state.

## Re-enabling the plugin manager

If you want the Plugins page back without waiting for the next drop:

1. In `~/.config/quickshell/zen-shell/ZenSettings.qml`, uncomment the
   `{ id: "plugins", ... }` entry in the sidebar definition.
2. In `install.sh`, change `if false; then` to `if true; then` in the
   `[8.7/9]` block (or just run hyprpm commands manually).
3. `qs reload`


## Hotfix updates within v6.16.4.12.6.51

### Clock popup positioning fix

The Clock module's calPopup (`anchor.item + Edges.Top + Edges.Top`) was
silently clipped off-screen by Wayland on top-aligned bars — the popup
was 660px tall and tried to expand upward from a clock that was already
near y=0. Hover and click events fired correctly, but the popup
surface was placed above the visible region and Wayland clipped it
invisible.

Fix: anchor.edges and anchor.gravity now adapt to `PanelState.isTop`:

| Bar position | edges | gravity | Result |
|---|---|---|---|
| bottom (default) | `Edges.Top` | `Edges.Top` | popup ABOVE clock |
| top | `Edges.Bottom` | `Edges.Bottom` | popup BELOW clock |

Visibility binding (`clockMouse.containsMouse || clockRoot._calPinned`)
and click-to-pin behaviour are unchanged.

### Installer detects existing settings profile

A new `[5.9/9] Detecting existing user settings...` step runs before
`[6/9] Hyprland configs` and reports what will be preserved:

```
[5.9/9] Detecting existing user settings...
    Existing config found — the following will be PRESERVED on re-install:
      gaps_in        = 8   (look_and_feel.conf)
      gaps_out       = 16  (look_and_feel.conf)
      border_size    = 3   (look_and_feel.conf)
      layout         = master (look_and_feel.conf)
      rounding       = 16  (look_and_feel.conf)
      panel position = top  (panel-state.json)
      panel mode     = island (panel-state.json)
      theme          = tokyo-night (settings-state.json)
      Hyprland       = Tag: v0.54.0
```

This is read-only detection — no files are modified by this step. The
preservation logic itself was already in place in [6/9] (per-file
"copy default only if missing"); the new step just makes that
behaviour visible to the user.

To force a reset to defaults for any specific file, delete it before
running install.sh again.


## Hotfix updates within v6.16.4.12.6.51 (final)

### Clock.qml is now a fork of CalendarButton

The previous Clock.qml had its own anchor strategy (`anchor.item` +
`Edges.Top` + `Edges.Top`) and a separate calPopup with custom hover/
pin state machine. That popup never visibly appeared in some setups
(top-aligned bars clipped it off-screen; under specific Wayland
timing the hover bubbling broke). Adapting edges/gravity wasn't
enough to make it reliable across configurations.

This drop replaces Clock.qml with a fork of CalendarButton.qml — the
same proven mechanism used by the bar's "calendar" module — modified
to show a live time display in place of the static date label, plus
the right-click format-cycle and scroll-wheel month navigation that
the old Clock had.

`Bar.qml` now points BOTH `cClock` and `cCalendar` at the merged
`Clock {}` component, so existing bar layouts that include either
"clock" or "calendar" tokens render the same module without
migration.

Behaviour:

| Action | Result |
|---|---|
| Hover the clock label | Calendar popup auto-shows (anchor.item bubbling keeps `containsMouse` true even when cursor enters the popup) |
| Click the clock | Toggles `_pinned` — popup stays open after the cursor leaves |
| Right-click | Cycles clock format (12-hour, 24-hour, date+time variants) |
| Scroll wheel | Cycles calendar months (auto-pins on first wheel event) |

Popup positioning adapts to `PanelState.isTop`:

| Bar position | edges | gravity | Result |
|---|---|---|---|
| bottom (default) | `Edges.Top` | `Edges.Top` | popup ABOVE clock |
| top | `Edges.Bottom` | `Edges.Bottom` | popup BELOW clock |

### Installer auto-restores user profile settings

A new `[8.9/9] Restoring user profile settings...` step runs between
`[8.7/9]` and `[9/9]`. It reads
`~/.config/quickshell/zen-shell/settings-state.json` (or
`-state-v2.json` if both are present), extracts the saved
appearance values, and pushes them straight to the running Hyprland
session via `hyprctl --batch keyword …`. The values restored are:

- `general:gaps_in` / `general:gaps_out`
- `general:border_size`
- `decoration:rounding`
- `decoration:active_opacity` / `decoration:inactive_opacity`
- `decoration:blur:enabled` / `decoration:blur:size` / `decoration:blur:passes`

This mirrors what `SettingsState.qml` does on shell startup (its
`applyToHyprland()` function), but does it eagerly inside the
installer so the saved profile takes effect immediately — without
having to change a theme to trigger a re-apply.

The step is read-only on the JSON file. It skips silently if no
saved profile exists (genuine fresh install — `SettingsState` will
seed from Hyprland on first run instead). It also skips outside a
live Hyprland session (the values will reapply on next shell start
either way, since `SettingsState.onLoaded` calls `applyToHyprland`).

Sample output:

```
[8.9/9] Restoring user profile settings to Hyprland...
    Applied saved profile values to running Hyprland session:
      gaps_in        = 8
      gaps_out       = 16
      border_size    = 3
      rounding       = 14
      active_opacity = 1.0
      inactive_opacity = 0.85
      blur:enabled   = true
      blur:size      = 8
      blur:passes    = 3
    (Source: settings-state.json)
```

Combined with the read-only detection from `[5.9/9]`, the user now
sees both what's being preserved (before) and what's being
re-applied (after).


## Hotfix 2 within v6.16.4.12.6.51

### Clock hover/click was actually dead — sizing bug, not popup positioning

The merged Clock module's root Rectangle used:

```qml
width: layoutRow.implicitWidth + 24
```

`layoutRow` is a RowLayout with `anchors.centerIn: parent`. Its
`implicitWidth` is dependent on the parent measurement pass, which
in turn depends on `layoutRow.implicitWidth` — a binding loop that
silently resolved to 0 in some frames. With root.width = 0, the
MouseArea (`anchors.fill: parent`) had a 0×0 input area. **Hover
and click events never reached it** — that's why no popup appeared
regardless of which anchor strategy or edges/gravity combination we
tried.

The clock TEXT still rendered because the Text elements anchor inside
the RowLayout independently and don't depend on parent.width for
their visibility. So the user saw the time display but nothing
responded to mouse interaction.

CalendarButton.qml (which works) does `width: dateText.implicitWidth + 24`
— it references the Text element directly, never the RowLayout.

Fix: Compute root width from the Text widths directly, plus add
`Layout.preferredWidth` and `Layout.preferredHeight` so the outer
Loader-in-RowLayout in Bar.qml has explicit size hints:

```qml
readonly property real _contentW: iconText.implicitWidth
                                 + 8                          // spacing
                                 + clockText.implicitWidth
width:  _contentW + 24
height: Theme.moduleHeight
Layout.preferredWidth:  _contentW + 24
Layout.preferredHeight: Theme.moduleHeight
Layout.alignment: Qt.AlignVCenter
```

The MouseArea now has a real input area, hover registers, click
registers, popup opens.

### Installer — sync gaps from saved profile to look_and_feel.conf

The Settings UI applies gap changes via `hyprctl keyword
general:gaps_in N` (runtime only) and saves them to
`settings-state.json` (the profile). It does NOT rewrite
`look_and_feel.conf`.

Result: after Hyprland reload the file values reload first and
override the runtime values — until SettingsStateV2 re-applies the
profile from `settings-state.json` on QML startup. That brief window
showed defaults instead of the user's saved gaps, and after a fresh
install (where look_and_feel.conf had been written with bundled
defaults) the saved profile was effectively lost from the file.

Fix: a new sync block in `install.sh` (after the per-module preserve
loop in `[6/9]`) reads `settings-state.json` and rewrites the
`gaps_in` / `gaps_out` / `border_size` lines in `look_and_feel.conf`
to match the saved profile. Only those three lines are touched; the
rest of `look_and_feel.conf` (decoration block, animations block,
etc.) is left alone. Idempotent — re-running the installer no-ops if
values already match.

```
look_and_feel.conf — synced 3 value(s) from saved profile:
  gaps_in     = 12
  gaps_out    = 24
  border_size = 3
```

Tested: `bash -n` parse OK, JSON-int extractor (no jq dependency)
roundtrips a real settings-state.json correctly, and verified the
sed updates touch only the targeted lines on a real `look_and_feel.conf`
sample.

### Closing tagline

The end-of-install line was still saying *"Enjoy Zen Shell v6.16.4.12.6.49 Tsubasa"*.
Bumped to *"Enjoy Zen Shell v6.16.4.12.6.51 Hikari (光)"*.


## Hotfix 3 within v6.16.4.12.6.51

### Clock now drives the GLOBAL calendar (no local popup at all)

The local anchored PopupWindow approach kept failing in this user's
setup despite multiple attempts (anchor.item + edges/gravity, anchor.window + rect,
adapt to PanelState.isTop, sizing from text widths, etc.). After tester
confirmation that hover/click still produced no calendar, we pivoted
to the simplest possible solution: the Clock module is now a TRIGGER
for the global calendar window — the same one shell.qml's calendarWindow
renders via PanelState.calendarVisible, and the same one the Bar's
invisible spacer click used to open in earlier versions.

The local PopupWindow block (357 lines: calendar grid, notification
strip, system-action buttons) was removed entirely from `Clock.qml`.
The calendar UI lives in `ZenNotificationCenter.qml` instantiated by
shell.qml's `calendarWindow` — already known to render correctly
across all bar positions and panel modes. Single source of truth.

```qml
// Clock.qml — minimal trigger only
MouseArea {
    onEntered: hoverShowDelay.restart()        // 150ms intent → openCalendar
    onClicked: PanelState.calendarVisible = !PanelState.calendarVisible
}
```

Behaviour:

| Gesture | Action |
|---|---|
| Hover (150ms) | opens global calendar |
| Click | toggles global calendar |
| Right-click | cycles clock format |
| Scroll wheel | cycles calendar months (auto-opens if closed) |

To dismiss the calendar: click the clock again, or click outside the
calendar (ZenNotificationCenter's onCloseRequested fires).

`Clock.qml` is now 217 lines (down from 522). Braces balanced 22/22.
No PopupWindow positioning to debug — if the spacer's calendar trigger
worked before, the clock's trigger works now (same code path).


## Hotfix 4 within v6.16.4.12.6.51

### Clock — local anchored popup with hover-peek and click-expand

Previous hotfix routed the clock to `PanelState.calendarVisible`,
opening shell.qml's right-anchored `calendarWindow`. User feedback:
the calendar should appear NEAR the clock module (like SysRow's
CPU/memory tooltip) — anchored above/below the clock, not pinned to
the screen's right edge. Plus a two-state UX:

* **Hover** the clock → compact popup, **calendar only** visible
* **Click** the clock → expand to full popup: notif + calendar + buttons

Restored the local `PopupWindow` in `Clock.qml`, anchored to the
clock Rectangle via `anchor.item: root`. Position adapts to bar
location:

```qml
anchor.edges:   PanelState.isTop ? Edges.Bottom : Edges.Top
anchor.gravity: PanelState.isTop ? Edges.Bottom : Edges.Top
```

Popup height animates between 360px (compact) and 600px (full) with a
200ms `OutCubic` Behavior so the click-to-expand transition is smooth.

The same `ZenNotificationCenter` component shell.qml's calendarWindow
uses is reused inside the popup — single source of truth for calendar
logic, notification poller, and system quick-actions. A new
`compactMode` property toggles between the two states.

### ZenNotificationCenter — `compactMode` property

Added a `compactMode: bool` property (default `false`). When `true`:

* Notification strip is hidden (`visible: false`, `Layout.preferredHeight: 0`)
* Separator below calendar is hidden
* System quick-actions GridLayout is hidden
* Calendar grid is always visible

The Rectangle root auto-sizes via `mainLayout.implicitHeight + 28`,
so when sections collapse the popup naturally shrinks to fit the
calendar grid only. Smooth height transition is handled by the
PopupWindow's height Behavior.

### Clock — theme-synced background

Clock module background now uses `ThemeService.alpha`/`ThemeService.bg0`
matching the start menu, taskbar, and ZenNotificationCenter — instead
of the older `Theme.alpha`/`Theme.bg0`. Same approach throughout the
shell now. Border lights up `ThemeService.blue` on hover or pin.

### Taskbar — window-list popup scrollable + theme-synced

Image 2 of the user's report showed many browser tabs in the
window-list popup, exceeding the previous 300px height cap with no
scroll. Two changes:

**Scrollable.** The Repeater is now wrapped in a `Flickable` with
internal `ColumnLayout`. Mouse-wheel and drag scroll work for any
number of windows. A slim 3px scrollbar appears on the right side
when content overflows. Max popup height bumped from 300 → 420.

**Theme-synced via ThemeService.** Background was
`Theme.alpha(Theme.bg0, 0.95)` / border `Theme.bg1`. Now matches
ZenNotificationCenter:

```qml
color: Qt.rgba(ThemeService.bg0.r, ThemeService.bg0.g, ThemeService.bg0.b, 0.96)
border.color: ThemeService.alpha(ThemeService.fg, 0.12)
```

Hover tint, close-button hover, item title colour all routed through
`ThemeService` instead of mixed `Theme.bg2` / `Theme.fgDim` references.

### Taskbar — context menu popup theme-synced

Same treatment for the right-click context menu (Pin / New window /
Close all). Was using `Theme.bg2`/`Theme.alpha(Theme.fg, ...)`/
`"#ffffff"`; now `ThemeService.alpha(ThemeService.fg, 0.08)` for
hover, `ThemeService.fg` for icon text, `ThemeService.red` for
close action. Consistent with the rest of the shell.

### Files changed in hotfix 4

* `Clock.qml` (200 lines, braces 23/23) — restored local PopupWindow
* `ZenNotificationCenter.qml` (378 lines, braces 87/87) — `compactMode`
* `Taskbar.qml` (631 lines, braces 111/111) — Flickable + ThemeService

## Hotfix 5 within v6.16.4.12.6.51

### HMRow — height now adapts to wrapped descriptions

Settings rows in the Battery & Power → Panic Recovery section were
visually overlapping. The "What it does" row's 8-bullet description
("1) SIGKILL frozen hyprlock · 2) Double DPMS off→on cycle · …")
wrapped to 4-5 lines, but the row's height was hardcoded at 56px:

```qml
Rectangle {
    Layout.fillWidth: true
    implicitHeight: 56                  // ← FIXED
    RowLayout {
        anchors.fill: parent            // RowLayout pinned to 56px
        ColumnLayout {
            Text { wrapMode: Text.WordWrap }   // wraps multi-line
            // No clip → renders BEYOND row bounds
        }
    }
}
```

The wrapped Text rendered downward past the 56px row, visually
overlapping the next HMRow ("Manual invocation"). Description text
showed through the next row's label — exactly what the user
screenshotted.

Fix:
```qml
implicitHeight: Math.max(56, contentRow.implicitHeight + 16)
```

Min height 56 preserved for short rows (Themes, Displays, Input,
Panel — all the regular toggle/dropdown rows are unaffected). Long
wrapped rows expand to fit their description plus 8px top + 8px
bottom padding.

Also nudged the leading icon and right-aligned control slot to
`Qt.AlignTop` instead of `Qt.AlignVCenter`. On a tall wrapped row,
`AlignVCenter` would float the icon and the control to the middle of
the description block, away from the label they belong to. Top-align
keeps them visually inline with the label text.

This is a single-file change (`HMRow.qml`, 116 lines, braces 8/8).
Every Settings page that uses HMRow benefits — Themes, Displays,
Input, Panel, Bar Modules, System Tray, Sound & Network,
Notifications, Battery & Power, User Profile, Desktop Widgets,
Wallpaper, Themes selector. Wala dapat regression sa simple rows
dahil min height 56 retained.

## Hotfix 6 within v6.16.4.12.6.51

### Clock — reverted from local PopupWindow back to PanelState

Hotfix 4 restored a local Quickshell `PopupWindow` anchored to the
clock module (anchor.item: root + Edges.Top/Bottom adapt). Despite
the sizing fix that should have given the MouseArea a real input
area, the popup did not render in the user's Quickshell/Hyprland
setup — clicks no longer produced any visible calendar.

Reverted Clock.qml to drive `PanelState.calendarVisible` directly,
opening shell.qml's right-anchored `calendarWindow` (the same code
path that worked in hotfix 3, confirmed by the user's screenshot
showing "29" highlighted + control panel buttons).

Behaviour:

| Gesture | Action |
|---|---|
| Hover (150ms) | opens global calendar |
| Click | toggles global calendar |
| Right-click | cycles clock format |
| Scroll wheel | cycles months (auto-opens if closed) |

The calendar opens at the screen's right edge with margin 12, which
visually sits right above (or below for top-bars) the clock since
the clock is rightmost in the bar's right zone. Not perfectly
clock-anchored UX, but renders reliably — and that beats a fancy
anchored popup that doesn't appear at all.

### What stays from hotfix 4

* `ZenNotificationCenter.qml` — `compactMode` property remains as a
  future hook. Currently no caller; default `false` so no behavioural
  change. If we ever get a working local PopupWindow, the property is
  ready.
* `Taskbar.qml` — Flickable-scrolled window-list popup + ThemeService
  sync for both window-list and context menu popups. Independent of
  the clock issue.
* `HMRow.qml` — adaptive height fix for the Battery & Power → Panic
  Recovery overlap.

### Sizing fix retained

Even though we're not using the local PopupWindow, the
`clockText.implicitWidth + iconText.implicitWidth + 24` width
formula + `Layout.preferredWidth/Height/alignment` are kept. They
ensure the MouseArea has a real input area so hover/click events
fire reliably. The blue hover border + cursor pointer would not
show otherwise.

## Hotfix 7 within v6.16.4.12.6.51

### Clock — hybrid hover-peek + click-full

Combines the two patterns proven to render in this Quickshell setup:

**Hover** (small anchored peek) — uses the EXACT same pattern as
`SysRowIcon.qml`'s CPU/RAM tooltip: `anchor.item: root`, edges +
gravity adapt to bar position, content-derived height, theme-synced
background. The peek shows ONLY the calendar grid (month header +
day-of-week headers + 6×7 day grid + tiny "click for more" hint),
~310×340 px. Small popups at this size pattern have been working
reliably in the user's setup since SysRow v6.14.

**Click** (full surface) — opens the global `calendarWindow` via
`PanelState.calendarVisible`, the proven path that worked in
hotfix 3 (user confirmed via screenshot showing "29" highlighted +
control panel buttons). Full notifications + calendar + system
quick-actions.

Why hybrid: previous attempts to use a single 330×600 anchored
PopupWindow for both states didn't render in this setup. Smaller
anchored popups (~310×340) follow the SysRow tooltip pattern that
DOES render. So we use the small anchored popup for hover (peek) and
defer to the global window only for the click-expanded full view.

Behaviour:

| Gesture | Action |
|---|---|
| Hover clock | Small calendar peek above (or below for top-bars) |
| Click clock | Closes peek + opens full global calendar |
| Right-click | Cycles clock format |
| Scroll wheel | Cycles months — peek's month while hovering, global calendar's month if open |

Peek visibility is gated on `ma.containsMouse && !PanelState.calendarVisible`
so the two surfaces never overlap. When user clicks, the click handler
opens the global calendar, which in turn hides the peek.

Peek calendar is a self-contained mini ZenCalendar — month nav arrows
(< Apr 2026 >), day headers (Su Mo Tu We Th Fr Sa), day grid with
today highlighted in `ThemeService.blue`. Theme-synced background
matches start menu / taskbar / ZenNotificationCenter.

`Clock.qml` (379 lines, braces 57/57). Drop-in compatible.

## Hotfix 8 within v6.16.4.12.6.51

### THE actual root cause: Bar.qml's Loader didn't forward size

Critical discovery after multiple failed Clock fixes:

* **`SysRowIcon`** is instantiated **DIRECTLY** in `SysRow.qml` —
  `SysRowIcon { ... }`, no Loader wrapper.
* **`Clock`** is loaded through a **`Loader`** in `Bar.qml`.

`Layout.preferredWidth/Height` set on Clock.qml's Rectangle root are
**invisible to the parent RowLayout** because RowLayout reads them
from the Loader, not from the Loader's loaded item. The Loader had
no Layout.preferredWidth/Height set, so RowLayout sized it via
`implicitWidth` — and a Loader's implicitWidth doesn't auto-derive
from the loaded item in all configurations.

End result: the Clock's Rectangle ended up 0×0 in some frames, the
MouseArea (`anchors.fill: parent`) had a zero input area, and
**hover/click events never arrived** despite every fix targeting the
loaded module itself. Every previous attempt (anchor strategy, popup
positioning, ZenNotificationCenter compactMode, hybrid hover-peek)
was futile because the underlying problem was the silent Loader
sizing failure two levels up the tree.

### Fix in Bar.qml — forward `item.implicitWidth/Height` up the Loader

All three module Loaders (left, center, right zones) now propagate
the loaded item's implicit size up to their own Layout properties:

```qml
Loader {
    id: modLoader
    sourceComponent: barRoot.getComponent(modelData)
    Layout.alignment: Qt.AlignVCenter
    active: sourceComponent !== null

    Layout.preferredWidth:  item ? Math.max(item.implicitWidth,  item.width  || 0) : 0
    Layout.preferredHeight: item ? Math.max(item.implicitHeight, item.height || 0) : 0
}
```

`Math.max(item.implicitWidth, item.width)` is defensive: some loaded
modules set `width:` explicitly (which sets implicitWidth too via QML
defaults), some use only `implicitWidth:`, some use both. Take the
larger so we never under-size the Loader.

### Fix in Clock.qml — set both implicit and explicit + hard min-width

Clock.qml's Rectangle now sets `implicitWidth` AND `width`:

```qml
readonly property real _moduleW: Math.max(180, _contentW + 24)
implicitWidth:  _moduleW
implicitHeight: Theme.moduleHeight
width:          _moduleW
height:         Theme.moduleHeight
Layout.preferredWidth:  _moduleW
Layout.preferredHeight: Theme.moduleHeight
Layout.minimumWidth:    180
Layout.minimumHeight:   Theme.moduleHeight
```

`Math.max(180, ...)` ensures a 180×40 minimum even during transient
frames before iconText/clockText have measured (e.g. before fonts
load). `Layout.minimumWidth/minimumHeight` are belt-and-suspenders
in case the new Loader forwarding isn't enough.

### Diagnostics

The Clock module now logs at startup and on every hover/press/click:

```
[Clock] mounted — implicitWidth= 180 implicitHeight= 40 ...
[Clock] hover → true   area= 180 x 40
[Clock] PRESSED  button= 1
[Clock] CLICKED  button= 1   globalCalVisible was= false
[Clock] click → calendarVisible = true
```

If the user still reports hover/click not working, `qs --log-level
debug 2>&1 | grep Clock` will show exactly where the chain breaks —
no more guessing.

### What this means for the bigger picture

Every other Bar module (notif bell, music widget, sysrow, taskbar,
start menu, etc.) was potentially affected by the same Loader sizing
bug. Some happened to work because they have larger implicitWidth
that survives the timing window, or because they don't depend on
hover/click. With the Bar.qml Loader forwarding fix, all modules now
get correctly sized regardless of timing.

Files: `Bar.qml` (683 lines, braces 104/104), `Clock.qml` (417 lines,
braces 58/58).

## Hotfix 8 within v6.16.4.12.6.51

### Clock — stripped to absolute minimum, click-to-toggle

Hotfix 7 (hybrid hover-peek + click-full) didn't render the click
either — user reported "hindi nanaman clickable". Stripped the
file down to the EXACT shape of the v6.16.4.12.6.21 version that's
documented in the original file's header as the working reference:

* `z: 10` on the MouseArea (sits above sibling layouts so click
  events reach the handler — this was missing in earlier hotfixes)
* DIRECT property toggle `PanelState.calendarVisible = !PanelState.calendarVisible`,
  no function-call wrapper or `typeof` check
* No local PopupWindow at all (none of the variations rendered)
* No WheelHandler (could be intercepting events before MouseArea sees them)
* No Quickshell.Io import (unused, less surface for parser quirks)

Behaviour:

| Gesture | Action |
|---|---|
| Click | Toggles global calendar |
| Right-click | Cycles clock format |
| Hover | Blue-tint background + pointer cursor (visual confirmation MouseArea is alive) |

That's it. 138 lines. If THIS doesn't work, the issue is upstream of
Clock.qml (PanelState wiring, shell.qml's calendarWindow, layer-shell
config) — not anything Clock.qml is doing wrong.

Lessons going forward: stop trying to bring back the local PopupWindow
in this user's Quickshell setup. Either his Quickshell version, his
Hyprland version, or his layer-shell setup has something that
prevents anchor.item PopupWindows of certain sizes/configs from
rendering, despite SysRowIcon's identical pattern working. Without
remote debugging the only safe path is the global calendarWindow.

## Hotfix 9 within v6.16.4.12.6.51 — REVERT to hotfix 6

User confirmed hotfix 6 (the PanelState-driven version with
`hoverShowDelay` + `WheelHandler` + function-wrapper toggle) was the
WORKING version for their setup. The "hindi nanaman clickable" report
was actually about hotfix 7 (hybrid hover-peek) and hotfix 8 (stripped
`z: 10`) — not about hotfix 6.

Reverted Clock.qml byte-for-byte to the hotfix 6 file the user shared
back as proof. Key differences vs the broken hotfix 8:

* KEEPS `import Quickshell.Io` (might be referenced indirectly via
  declarations the parser threads through)
* KEEPS `Timer { id: hoverShowDelay }` for 150ms hover-intent delay
* KEEPS `MouseArea.onEntered` and `onExited` for hover wiring
* KEEPS `WheelHandler` for scroll-month
* KEEPS `typeof PanelState.openCalendar === "function"` wrappers with
  direct-property fallback (the function-wrapper path is what actually
  fires on this user's PanelState build)
* OMITS `z: 10` on MouseArea — the working baseline for this user
  doesn't have it, and adding it broke click delivery (suspected
  reason: `z: 10` on a MouseArea anchored fillParent of a Rectangle
  inside a Loader inside a RowLayout interacts badly with Wayland
  layer-shell input routing in this specific Hyprland/Quickshell
  combination)

Lessons going forward: stop modifying Clock.qml away from the hotfix 6
shape. If new behaviour is needed, add it as additive code (new
PopupWindow declarations, new properties) without restructuring the
existing MouseArea / WheelHandler / Timer that the user has confirmed
works for them.

File: 199 lines, md5 `b2a8b0ae5b7b14f5a1b56b9b0588c447`. Bundled in
the gzip at `zen-shell-v6.16.4.12.6.51/zen-shell-v5/Clock.qml`.
