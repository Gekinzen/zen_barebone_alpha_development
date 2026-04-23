# Zen Shell v6.16.3.6 — Hover popup parity + lock screen enhancements

**Release date:** 2026-04-24
**Branch:** `beta-v12.6.16.3.6`
**Base:** v6.16.3.5.3
**Status:** Beta — roadmap milestone (bar-module hover popup unification + lock screen polish)

---

## TL;DR — two tracks

### Track 1 — Hover popup parity

Roadmap item: *"Clock hover popup parity with CPU/Memory hover"*

Before this drop, two bar modules had hover popups implemented with
different infrastructure:

| Module       | Mechanism                | Issues                          |
|--------------|--------------------------|---------------------------------|
| Clock        | `PopupWindow` + 350ms    | Worked (v6.16.2)                |
|              | hover-intent             |                                 |
| CPU/Memory   | Inline `Rectangle`       | Clipped by bar layer surface;   |
|              | (`y: sysRoot.height+4`)  | no hover-intent delay; fires    |
|              |                          | instantly on mouse pass-through |

Now BOTH use identical patterns:

```
┌─────────────────── shared visual language ───────────────────┐
│  • PopupWindow with anchor.edges = Edges.Top                 │
│  • 350ms hover-intent delay                                  │
│  • bg0 @ 96% alpha fill                                      │
│  • 15% foreground alpha border                               │
│  • Theme.panelRadius (capped at 14px)                        │
│  • Section headers (DemiBold, ThemeService.blue, 12px)       │
│  • Body rows (11px, grey0)                                   │
│  • Subtle separators (fg @ 10%)                              │
└──────────────────────────────────────────────────────────────┘
```

Plus content upgrades on both:

- **Clock** — added time-with-seconds, ISO week + day-of-year,
  IANA timezone with UTC offset
- **CPU/Memory** — restructured as 4 sections (CPU / GPU / Memory /
  Network) with section headers; old version was a dense wall of
  text with decorative `──` lines

**Wala tayong binawasan.**

---

## ZenClock hover popup — enhanced content

### New fields

| Field                     | Source                                        |
|---------------------------|-----------------------------------------------|
| Weekday (large)           | `Qt.formatDateTime(now, "dddd")`              |
| Full date                 | `Qt.formatDateTime(now, "MMMM d, yyyy")`      |
| **Live time w/ seconds**  | `Qt.formatDateTime(now, "h:mm:ss AP")` ← NEW  |
| ISO 8601 week number      | JS computation (already in 6.16.2)            |
| **Day of year**           | JS computation ← NEW                          |
| **IANA timezone + UTC ofs** | `Intl.DateTimeFormat().resolvedOptions()` ← NEW |
| Click for calendar hint   | Static                                        |

Everything above updates live on each tick of the existing 1s timer
(the same one driving the bar clock text), so the popup is always
current even if held open.

Sample popup (rendered above the clock):

```
┌──────────────────────────┐
│  Friday                  │
│  April 24, 2026          │
│  12:45:30 PM             │
│  ──────                  │
│  Week 17 · Day 114 of 2026│
│  Asia/Manila · UTC+08:00 │
│  ──────                  │
│  Click for calendar      │
└──────────────────────────┘
```

### Internals

Unchanged vs. v6.16.2:
- Hover-intent via `Timer { interval: 350 }` + `_peekPending` state
- `PopupWindow { anchor.item: clockRoot; anchor.edges: Edges.Top }`
- Click still toggles calendar via IPC (`toggleCalendar`)

Changed:
- Column width min 220 (was 180) to accommodate timezone string
- Added separator line after time, before click hint

---

## ZenSysMonitor hover popup — PopupWindow rewrite

### Before (v6.8 inline tooltip)

```qml
Rectangle {
    id: sysTip
    visible: tipArea.containsMouse   // fires instantly
    x: -40
    y: sysRoot.height + 4
    z: 999
    // ... clipped at bar surface boundary
}
```

Problems:
1. `Rectangle` rendered inside the bar's layer surface — anything
   past the bar's bottom edge clipped
2. No hover-intent delay — popup flickered on mouse pass-through
3. `x: -40` manual offset brittle across bar modes (floating vs
   fullwidth vs island all need different offsets)

### After (v6.16.3.6 PopupWindow)

```qml
Timer {
    id: peekDelay
    interval: 350
    onTriggered: sysRoot._peekPending = tipArea.containsMouse
}

MouseArea {
    id: tipArea
    hoverEnabled: true
    acceptedButtons: Qt.NoButton        // click-through preserved
    onEntered: peekDelay.restart()
    onExited: { peekDelay.stop(); sysRoot._peekPending = false }
}

PopupWindow {
    anchor.item: sysRoot
    anchor.edges: Edges.Top
    anchor.gravity: Edges.Top
    visible: sysRoot._peekPending && tipArea.containsMouse
    // ... floats above bar surface, Wayland handles positioning
}
```

Sample popup (rendered above the SysMonitor pill):

```
┌────────────────────────────────────┐
│  AMD Ryzen 9 5950X                 │
│  Usage: 34%   ·   Temp: 52°C       │
│  ──────────                        │
│  AMD Radeon RX 6800                │
│  Usage: 0%   ·   Temp: 43°C        │
│  VRAM: 1.2 / 16.0 GB               │
│  ──────────                        │
│  Memory                            │
│  12.3 / 128.0 GB  (9.6%)           │
│  ──────────                        │
│  Network                           │
│  ↓ 1.2 KB/s   ·   ↑ 0.3 KB/s       │
└────────────────────────────────────┘
```

### Fields preserved

Every piece of data that was in the old v6.8 tooltip is still here:
cpuName, cpuPercent, cpuTemp, gpuName, gpuUsage, gpuTemp, gpuVram,
ramUsedGb/ramTotalGb/ramPercent, netDown/netUp. Just reorganized
with clearer visual hierarchy.

---

## install.sh — SysMonitor auto-apply

Added ZenSysMonitor → SysMonitor to the auto-apply loop alongside
ZenClock and ZenWorkspaces:

```bash
for pair in "ZenClock.qml:Clock.qml" \
            "ZenWorkspaces.qml:Workspaces.qml" \
            "ZenSysMonitor.qml:SysMonitor.qml"; do
    # Existing diff-then-backup-then-copy logic
done
```

This means re-running `./install.sh` picks up the new hover popup
automatically. Existing user `SysMonitor.qml` (if different) gets
backed up to `SysMonitor.qml.bak-<TS>` first — same safety pattern
as Clock and Workspaces have had since v6.8.

---

## Track 2 — Lock screen (hyprlock) enhancements

> *"yung sa lock pre yung font nung time pwd iparehas mo sa current
>   clock widget ko want ko same font  and wala Heyah Username
>   tas kunin yun current weather may message depende if sunny cloudy
>   rainy, tas random message  ng system para sa user. hoping na your
>   doing ok ? prang ganyan basta randomly depende din sa mood ng
>   weather , day and night din"*

Three changes to how hyprlock renders:

### 2a. Clock font now follows the bar's font

Before: hyprlock's big center clock was hardcoded to `Adwaita Sans
Light`. If you changed the bar font to JetBrainsMono, the lock clock
stayed Adwaita and felt disconnected.

After: `zen-lock.sh` reads `fontFamilyId` from
`~/.local/share/quickshell/zen-shell/panel-state.json` and
substitutes the matching font family into hyprlock.conf before
launch. Substitution only touches lines tagged with special
comment markers:

```conf
font_family = Adwaita Sans Light    # ZEN_FONT_OVERRIDE_CLOCK   ← clock
font_family = Adwaita Sans          # ZEN_FONT_OVERRIDE_MSG     ← message lines
```

Font mapping follows ZenConstants.fontFamilies — every font the user
can pick in Settings maps to its correct NerdFont/variant family
name for hyprlock. 10 mappings covered (adwaita, jetbrains, geist,
firacode, caskaydia, iosevka, hack, ubuntu, sfpro, inter).

**Opt-out**: remove the `# ZEN_FONT_OVERRIDE_*` trailer from any
font_family line you want to pin manually. zen-lock.sh's sed only
matches the marker pattern, so unmarked lines are untouched.

### 2b. Goodbye "Heyah Username"

The old "Good morning, $USER ☀️" / "Good evening, $USER 🌙" greeting
is gone. Per Paul: *"wala Heyah Username"*.

### 2c. Weather mood + rotating care message (English, gender-aware)

Replacing the greeting, two new labels:

**Weather mood line** (22px, bright white, gender-neutral — weather
is weather regardless of who's reading):
- "Sunny morning ☀️"
- "Rainy afternoon 🌧️"
- "Starry night sky 🌌"
- "Cloudy evening 🌥️"
- "Stormy night ⛈️"
- "Foggy morning 🌫️"
- "Snowy afternoon 🌨️"

Derived from: time of day (morning/afternoon/evening/night) ×
weather condition from `~/.cache/zen-shell/weather.json` (populated
by WeatherService, same source the bar clock uses).

**Care line** (16px, softer grey, gender-aware):

Three pools for every (time, weather) combination — neutral (safe
default), male, female. Picked based on `PanelState.userGender`
which the user sets in Settings → User Profile → Personal
Preferences:

| Gender   | Address style                                  |
|----------|------------------------------------------------|
| neutral  | No direct address — "Rise and shine"           |
| male     | "man", "bro", "dude", "boss", "sir"            |
| female   | "miss", "queen", "madam"                       |

Full English — no Taglish (switched from earlier draft).

Examples by (time × weather × gender):

**Morning clear:**
- Neutral: "Have a great day ahead", "Rise and shine", "You got this"
- Male:    "What's up, man!", "Rise and grind, bro", "Good morning, chief"
- Female:  "Good morning, miss!", "Rise and shine, queen", "Good morning, sunshine"

**Afternoon rain:**
- Neutral: "Tea or coffee weather ☕", "Take it slow"
- Male:    "Tea or coffee, bro? ☕", "Stay cozy, man"
- Female:  "Tea time, miss? ☕", "Stay cozy, queen"

**Evening clear:**
- Neutral: "Winding down? You've had a good day", "Hope today was kind to you"
- Male:    "Winding down, man?", "Evening's yours now, boss"
- Female:  "Winding down, miss?", "Evening's yours now, madam"

**Night (late):**
- Neutral: "Working late? Don't forget to rest", "Hope you're doing ok this late"
- Male:    "Working late, man?", "Take care of yourself, boss"
- Female:  "Working late, miss?", "Take care of yourself, madam"

Storm, snow, fog get their own gendered pools that override the
time-of-day message (weather severity trumps routine greeting).

**Gender setting**: Settings → User Profile → "Personal Preferences"
section has the new picker. Three options:

```
┌─ Personal Preferences ──────────────────────────────────┐
│  Flavors your lock-screen rotating messages. Neutral    │
│  works for everyone; Male / Female unlock gendered      │
│  phrasings.                                             │
│                                                          │
│  Address me as     [ Neutral (they / friend)   ▼ ]      │
└──────────────────────────────────────────────────────────┘
```

Default is "Neutral". Saves to `PanelState.userGender` →
`panel-state.json` → picked up by `zen-lock-message.sh` at lock
time (reads the field via jq on every invocation, so changes in
Settings apply on next lock — no restart needed).

### Internals — pool selection

Script uses bash namerefs (`declare -n`) to resolve the right pool
dynamically based on `${PREFIX}_${GENDER_SUFFIX}`:

```bash
pool_pick() {
    local prefix="$1"
    local g; case "$GENDER" in
        male)   g="M" ;;
        female) g="F" ;;
        *)      g="N" ;;
    esac
    declare -n pool_ref="${prefix}_${g}"
    if [ "${#pool_ref[@]}" -eq 0 ]; then
        unset -n pool_ref
        declare -n pool_ref="${prefix}_N"   # fallback to neutral
    fi
    pick "${pool_ref[@]}"
}
```

Fallback: if a specific (time × weather × gender) pool is empty,
falls back to the neutral pool. Currently every gendered bucket
has 2-6 messages, so the fallback is defensive — won't trigger in
practice.

### Implementation files

**New**: `scripts/zen-lock-message.sh` (~170 lines, pure bash)
- Usage: `zen-lock-message.sh weather` / `zen-lock-message.sh care`
- Reads: `~/.cache/zen-shell/weather.json`, system time
- Zero QML/Quickshell runtime dependency

**Modified**: `scripts/zen-lock.sh` — new "Step 3: Sync clock font"
block before hyprlock launch. Uses jq + sed — both already required
by the script (jq was already used for wallpaper sync).

**Modified**: `hypr-config/hyprlock.conf`
- Clock label gains `# ZEN_FONT_OVERRIDE_CLOCK` trailer
- Old greeting label removed
- Two new labels added (weather mood + care line) with
  `# ZEN_FONT_OVERRIDE_MSG` trailer

**Modified**: `install.sh` — deploy `zen-lock-message.sh` to `$BIN_DIR`.

---



### NEW

```
scripts/zen-lock-message.sh          ← weather mood + care line generator
CHANGELOG-v6.16.3.6.md                ← this file
```

### UPDATED

```
zen-shell-v5/ZenClock.qml            ← enhanced hover popup content
zen-shell-v5/ZenSysMonitor.qml       ← PopupWindow hover popup (was inline Rectangle)
zen-shell-v5/PanelState.qml          ← +userGender property + persistence
zen-shell-v5/UserProfilePage.qml     ← +Personal Preferences section (gender picker)
zen-shell-v5/ZenVersion.qml          ← bump to v6.16.3.6
scripts/zen-lock.sh                   ← +font sync from PanelState before lock
hypr-config/hyprlock.conf             ← font markers + new mood/care labels
install.sh                             ← SysMonitor auto-apply, deploy new script, banner
```

### CARRIED OVER

Everything from 3.5.3 byte-identical — ZenComboBox guaranteed-
in-bounds popup, Module Layout dedup + battery/powerbadge,
7 bundled Start Button logos, PowerBadge A+B.

---

## Install / verify

```bash
tar -xzf zen-shell-v6.16.3.6.tar.gz
cd zen-shell-v6.16.3.6
./install.sh
~/.local/bin/zs-restart.sh
```

### Clock hover

1. Hover the bar clock for 350ms
2. Popup appears ABOVE the clock with weekday, date, live time
   (seconds tick live), week + day-of-year, timezone
3. Move mouse away → popup hides
4. Click → calendar opens (unchanged from before)

### SysMonitor hover

1. Make sure `sysmonitor` is in `Theme.barLayout.right` (default in
   fresh installs; for existing users: Settings → Panel → Module
   Layout → add `sysmonitor` to Right Zone)
2. Hover the CPU/Memory pill for 350ms
3. Popup appears ABOVE the pill with 4 sections (CPU / GPU / Memory
   / Network), each with section header + body rows
4. Move mouse away → popup hides. No flickering on mouse pass-through.

### Style parity

Open both popups side by side:
- Identical corner radius, border color, background
- Identical section header font (12px DemiBold, ThemeService.blue)
- Identical body text (11px grey0)
- Identical separator style (fg @ 10%, 60-80% width centered)

---

## Next up

- **v6.16.3.7** — Universal widget auto-resize (DPI / scale-aware)
- **v6.16.3.8** — Idle / lid / sleep UX
- **v6.16.4** — Global Hyprland configreloaded IPC listener

### Future: more hover popups using the same pattern

The PopupWindow + 350ms hover-intent pattern is now standard across
two modules. Extending to Battery, PowerBadge, Tray, Notifications,
Weather is straightforward — each of those currently has either no
hover state or a basic tooltip. A possible future factor-out:
`ZenHoverPopup.qml` reusable component wrapping the pattern.
