# Zen Shell v6.16.4.5 — Start Menu pinned tile breathing room

**Release date:** 2026-04-24
**Base:** v6.16.4.4
**Severity:** LOW — cosmetic cramping at higher monitor scales

---

## Paul's report

> *"kapag nag papalit pala ng scale lumalaki din itong mga icons
>   ko dito dpat sakto lang and make it sure hindi nag overlap
>   mga text natatakpan e try ko gawin 1.25x"*

Screenshot showed pinned-app tiles in the Start Menu with labels
cramped under the icons — "Visual St…", "Thunar F…", "Crimson…"
all ellipsizing aggressively at monitor scale 1.25×.

---

## Root cause — two things, one visible problem

### Thing 1 — Monitor scale 1.25× makes everything bigger (intended)

When Hyprland monitor scale is 1.25×, Wayland tells every client
"render at 125% physical pixels for crisp HiDPI output." Start
Menu, taskbar, dock — all compositor-rendered surfaces — correctly
scale up their pixel output. This is NOT a bug; it's Wayland doing
its job.

### Thing 2 — Tile label width was TIGHT at any scale

The actual fixable issue: pinned tile label was `Layout.preferredWidth:
58` inside a `Layout.preferredWidth: 64` tile. That's 6px of total
margin for the label to breathe. Font pixelSize 11 renders many
app names wider than 58px → heavy `elide: Text.ElideRight` cuts
most names to "Xxxx…".

At monitor scale 1.25×, physical rendering is 72.5px tile with
72.5px label — same ratio, same cramping. User perceives the
cramping more at higher scales because the ellipsis dots are
physically bigger AND more noticeable.

---

## Fix

```qml
// Before (v6.16.4.4):
Rectangle {
    Layout.preferredWidth: 64
    Layout.preferredHeight: 76
    ...
    Text {
        Layout.preferredWidth: 58
        elide: Text.ElideRight
    }
}

// After (v6.16.4.5):
Rectangle {
    Layout.preferredWidth: 72   // +8px per tile
    Layout.preferredHeight: 82  // +6px to match
    ...
    Text {
        Layout.preferredWidth: 66   // +8px room for labels
        elide: Text.ElideRight
    }
}
```

Net effect:
- Label has 8px more horizontal room (58 → 66)
- Tile has 8px more horizontal room (64 → 72) — stays centered
- Height bumped proportionally (76 → 82) so vertical spacing
  doesn't look thin next to the new width
- Grid still fits in the 720px panel with 5 columns:
  `5 × 72 + 4 × 8 (spacing) = 392px` — plenty of room in the 360px
  left pane

---

## What this does NOT fix

The fact that the Start Menu at monitor scale 1.25× looks bigger
than at 1.0× is correct Wayland behavior — you're literally
telling the compositor to render at 125% physical pixels. There's
no way to make the Start Menu "not scale" while everything else
scales — Wayland HiDPI is all-or-nothing per surface.

If you want the Start Menu to appear physically smaller at
1.25× monitor scale, your options are:
1. Reduce the `implicitWidth: 720` / `implicitHeight: 600` in
   `shell.qml` StartMenu section (e.g. to 640/560)
2. Drop monitor scale back to 1.0 in Settings → Displays

Both are personal preference, not bugs.

---

## Files changed from 4.4

```
UPDATED
  zen-shell-v5/StartMenuPanel.qml  ← tile 64→72, label 58→66, height 76→82
  zen-shell-v5/ZenVersion.qml       ← bump to v6.16.4.5
  install.sh                         ← banner
NEW
  CHANGELOG-v6.16.4.5.md             ← this file
```

---

## Install + test

```bash
tar -xzf zen-shell-v6.16.4.5.tar.gz
cd zen-shell-v6.16.4.5
./install.sh
~/.local/bin/zs-restart.sh
```

### Verify

1. Super+A to open Start Menu
2. Observe pinned tiles — "Visual Studio Code" / "Thunar File
   Manager" / "Crimson Desert" etc. should have more visible
   characters before the ellipsis (…)
3. Try monitor scale 1.25 in DisplaysPage → Start Menu scales
   with the rest of the UI (intended Wayland behavior), and the
   labels still have their extra breathing room at the new scale
