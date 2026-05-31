# v7.0.0-beta.1-hf41 — Collapsible Settings search + Input tab redesigned sliders

**Channel:** beta (hotfix)
**Released:** 2026-05-16
**Branch:** `dev`

---

## What this hotfix fixes/adds

User report:

> "yung type of search meron button na hide so magiging arrow lang then
> make it sure kht scroll down ko dapat hindi nag bubukas bukas unless
> manually cclick ko ulit yun arrow pra mag open gets? quick settings sa
> input tab dpat yun design toggle same natin sa current and yun mga
> drag jan mouse sensitivity etc dapat same sa current design natin
> like yun sa volume down and up design gets?"

Two requests, both in the Settings / ControlPanel surfaces.

---

## #1 — Settings search: collapsible

### Before

`FloatingSettingsSearch.qml` was a permanently-visible 220 × 32 pill
in the top-right of the Settings panel. Two annoyances:

1. **Always took up space** even when not searching. Smaller Settings
   panels (when Paul resized) had the bar competing with page content.
2. **Auto-opened dropdown on scroll.** `onActiveFocusChanged` block:
   ```qml
   onActiveFocusChanged: {
       if (activeFocus && text.length > 0) floater.dropdownOpen = true
   }
   ```
   When the user scrolled within a Settings page, intermediate focus
   reshuffles would re-grab the search field's focus → if any text
   was lingering (even one stale character), dropdown popped open. That
   was the "kht scroll down ko nag bubukas bukas" bug.

### After

```
Default (collapsed):       Click glyph:        Expanded:
┌──────┐                  ┌──────┐            ┌──────────────────────────────┐
│  ⌕   │   ← click ─────► │  ⌕   │ ───────►   │  ⌕  Type to search        × │
└──────┘                  └──────┘            └──────────────────────────────┘
                                              (ESC or click outside collapses)
```

- **Defaults to collapsed.** Just the 32×32 search-glyph button.
- **Click the glyph → expand** to the full 220×32 bar. TextField
  receives focus after a brief delay (so the width animation completes
  before the cursor blinks in).
- **ESC or click outside → collapse.** State persists across page
  navigations within the Settings panel.
- **Dropdown ONLY opens on typed text + expanded state.** No focus-
  driven auto-open. No scroll-triggered re-open. The visibility
  binding is now:
  ```qml
  visible: floater.expanded
        && floater.dropdownOpen
        && floater.results.length > 0
  ```
- **State persists** via new `PanelState.settingsSearchExpanded`
  boolean — survives Settings panel close/reopen within the same
  shell session.

### Why this works

The root cause of the scroll-auto-open bug was the implicit binding
between `activeFocus` and `dropdownOpen`. ZenSettings' Flickable
scroll mechanism briefly hands focus around as content scrolls past;
QQC2 TextField regaining focus while it has stale text triggered
the auto-open. By making `dropdownOpen` driven SOLELY by
`onTextChanged` (and gated by `expanded`), focus shuffles can't open
the dropdown anymore.

The collapsed default also means the search field doesn't even exist
in the focus chain unless the user has explicitly expanded it —
double-protection against any focus weirdness.

---

## #2 — ControlPanel Input tab: custom slider design

### Before

Mouse sensitivity (-1.0…+1.0) and scroll speed (0.1…3.0) used the
default QQC2 `Slider` component:

```qml
Slider {
    Layout.fillWidth: true
    from: -1.0; to: 1.0; stepSize: 0.05
    value: MouseSettingsService.sensitivity
    onMoved: { ... }
}
```

That renders the generic Qt Quick Controls slider — different visual
language from the **custom Rectangle-based slider** used by volume in
the Audio tab + the bar's sound popup. Two designs side-by-side felt
disjointed.

### After

Replaced both sliders with the same `Item { Rectangle track + filled
+ knob + MouseArea }` pattern used by volume. Each shares:

- **4 px track** with `ThemeService.alpha(fg, 0.15)` background
- **4 px filled portion** in `ThemeService.blue` (with 60 ms width
  animation for smooth dragging visual)
- **14 × 14 px circular knob** in `ThemeService.fg` with subtle
  border
- **Wheel scroll** to nudge (+/- step)
- **Click anywhere on the track** to jump to that value
- **Drag** to set continuously (with `preventStealing` so the slider
  doesn't lose grip on rapid moves)
- **Double-click → reset to baseline** (0.0 for sensitivity, 1.0×
  for scroll)

### Sensitivity-specific visual

Sensitivity range is signed (-1.0 to +1.0), so the filled portion
grows from CENTER, not the left edge. There's also a 2 px tall
tick mark at the center showing the 0.0 baseline. Visually:

```
 -1.0                  0.0                   +1.0
  ├──────────────────╫▆▆▆●─────────────────────┤
                     ↑
                center tick (0.0 baseline)
```

When the user has sensitivity at `+0.3`, you see fill from center
(0.5 ratio) → knob position (0.65 ratio). When at `-0.4`, fill goes
from knob position (0.3 ratio) → center (0.5 ratio) but on the LEFT
side. So the sign is immediately visually obvious.

### Scroll speed-specific visual

Scroll speed range is positive-only (0.1 to 3.0), so the filled
portion grows from the LEFT edge like volume. There's a 2 px tick
at the position corresponding to `1.0×` (default scroll factor) so
the user can see "where normal is" at a glance:

```
 0.1×           1.0×                       3.0×
  ├▆▆▆●─────────╫───────────────────────────┤
              ↑
       1.0× baseline tick
```

### What's NOT changed

User said: "**design toggle same natin sa current**" — confirmed,
the Switch components for natural scroll + touchpad natural scroll
are kept as-is. They were already using QQC2 `Switch` which matches
the rest of the shell's toggle design. Same with the "Reset to
defaults" button — already a styled Rectangle button, kept.

---

## Files changed (4)

```
zen-shell-v5/FloatingSettingsSearch.qml   — collapsible logic + dropdown
                                              visibility gate + remove
                                              onActiveFocusChanged auto-open
zen-shell-v5/ControlPanel.qml              — custom Rectangle sliders
                                              for sensitivity + scroll
                                              speed in Input tab
zen-shell-v5/PanelState.qml                — new property
                                              settingsSearchExpanded
zen-shell-v5/ZenVersion.qml                — bumped to hf41
install.sh                                  — banner + changelog
```

No new files. Pure surgical edits.

---

## How to install

```bash
tar -xzf zen-shell-v7_0_0-beta_1-hf41-search-collapse-input-redesign.tgz
cd zen-shell-v7.0.0-beta.1-hf41
./install.sh
```

State is forward-compatible. No schema changes. No keybind changes.

---

## How to verify

### Settings search collapse

1. `Super+comma` (or click Settings icon) → Settings panel opens
2. **Top-right corner** should now show just a small ⌕ button
3. Scroll through any settings page → button STAYS as a button.
   No dropdown ever pops open during scroll.
4. **Click the ⌕** → bar expands to full search field with cursor
   ready to type
5. Type any query → dropdown opens below
6. **Press ESC** → field clears, then ESC again → collapses to button
7. Or click outside the expanded field → collapses

### Input tab redesigned sliders

1. Open ControlPanel (`Super+C`) → switch to Input tab
2. The **Sensitivity** slider should look identical to the volume
   slider in the Audio tab — same track height, same knob style,
   same fill color
3. **Drag** the knob → smooth motion, value updates live
4. **Click** anywhere on the track → knob jumps to that position
5. **Scroll wheel** over the slider → nudges by 0.05 (sensitivity)
   or 0.1 (scroll speed)
6. **Double-click** the slider → snaps back to baseline (0.0 / 1.0×)
7. Center tick on sensitivity shows where 0.0 is; baseline tick on
   scroll shows where 1.0× is

### Compare side-by-side

Open Audio tab → look at volume slider design.
Switch to Input tab → look at sensitivity slider design.
They should be **visually indistinguishable** apart from the value
ranges. That's the "same natin sa current design" goal.

---

## Wala tayong babawasan

All previous fixes preserved:

- ✅ hf32 native toasts + login sound
- ✅ hf35 stable music strings + screenshot tools
- ✅ hf36 refresh rate downgrade toggle
- ✅ hf37 event-driven hot corners
- ✅ hf38 custom string colors + annotation transparency
- ✅ hf39 5 productivity features
- ✅ hf40 Quick Notes keybinds (`Super+Shift+N`) + sticky-note windows

Pure UX polish hotfix. No new features, no behavioral changes
outside the two surfaces touched. 🍃
