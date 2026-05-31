# v7.0.0-alpha.7-hf5 — Floating search bar (top-right corner)

**Channel:** alpha (hotfix 5)
**Released:** 2026-05-09
**Branch:** `dev`

---

## What this hotfix fixes

User asked: "hindi nakikita if gawin nln natin floating search siya
sa upper right corner pre? tas make it sure kapag lumabas yun mga
search niya scrollable siya yun nasa ibabaw pre hindi yun na overlap
ng iba."

Translation: make the search bar a floating overlay in the upper-right
corner, and make sure when results show, they're scrollable AND
floating above everything else (no overlap from other elements).

In the screenshot, the hf3 sidebar mount was overlapping the user
pill — the search bar's bottom edge was sitting RIGHT ON TOP of
"paul @cachyos-x8664" with "Settings" text peeking through. Plus
the dropdown when typing was getting clipped by the user pill +
content area.

### Solution: dedicated FloatingSettingsSearch component

New component file (~280 lines): **`FloatingSettingsSearch.qml`** —
purpose-built for the floating-overlay use case. Replaces the
generic SettingsSearchBar inline mount.

#### Position

Anchored to top-right of ZenSettings root via:

```qml
FloatingSettingsSearch {
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.topMargin: 12
    anchors.rightMargin: 110     // clears max + close window controls
    z: 200                       // above EVERYTHING
    ...
}
```

The 110px right margin clears both the maximize and close window
control buttons (28px each + spacing + safety = ~110px). The 12px
top margin aligns vertically with the gear icon and "Settings"
title in the header.

#### z-stacking

The floater sits at `z: 200` on the ZenSettings root. The dropdown
INSIDE it inherits that stacking context AND has its own `z: 100`
relative to the bar. Combined, this puts the dropdown above:

- Sidebar (z: 0)
- Content area (z: 0)
- Sidebar user pill (z: 0)
- Theme indicator footer (z: 0)
- Page Flickable scrollbar (z: 0)

The dropdown can never be visually clipped or overlapped by these
elements.

#### Compact bar

220px wide × 32px tall pill. The compact size matters because the
floater sits inside the visible header strip — it shouldn't dominate
the panel chrome. The user types into 220px; results render in a
WIDER 320px dropdown below (so titles + subtitles fit cleanly).

#### Scrollable dropdown

Dropdown uses ListView with proper ScrollBar:

```qml
property real rowHeight: 48
property real maxRows: 6   // ~288px max visible
height: visible
        ? Math.min(results.length, maxRows) * rowHeight + 8
        : 0
```

- 6 rows visible at a time = ~288px tall
- If results > 6, scrollbar appears (`ScrollBar.AsNeeded`) on the
  right edge
- If results ≤ 6, scrollbar hides (`ScrollBar.AlwaysOff`)
- ListView caches reusable delegates for smooth scroll

Each row is 48px tall:
- 16px Material/Nerd icon (left, fixed-width)
- Title (12px medium) + Subtitle (10px) — both elide on overflow

Click row OR Enter on highlighted row → fires `navigateRequested`
signal → ZenSettings flips `currentPage` → input clears + dropdown
collapses.

#### Internal layout fixes carried forward

The internal RowLayout uses the same fixed-width Item wrappers
introduced in hf1 + hf2:

- Search icon: 16×16 fixed-width Item with anchors.centerIn
- TextField: padding 0 (no Qt control implicit padding)
- Clear button (×): 16×16 fixed-width Item, animated visibility on
  text-presence

These fixes prevent the icon-overlap-text bug regardless of which
font (Material vs Nerd) renders the glyphs.

---

## Files added

```
zen-shell-v5/FloatingSettingsSearch.qml   (NEW, ~280 lines)
```

## Files modified

```
zen-shell-v5/ZenSettings.qml      (removed sidebar SettingsSearchBar mount,
                                    added FloatingSettingsSearch as last
                                    child of root with top-right anchors)
zen-shell-v5/ZenVersion.qml       (bumped to v7.0.0-alpha.7-hf5)
install.sh                        (version strings)
```

`SettingsSearchBar.qml` itself is **not deleted** — kept on disk
because Ctrl+F overlay's design language still references it for
visual consistency, and it remains a valid component for any future
inline mount that has guaranteed width.

---

## Visual layout after hf5

```
┌─────────────────────────────────────────────────────────────┐
│ ⚙ Settings                              [🔍 Search…]  [— ▢ ✕]│  ← floater here
├─────────┬───────────────────────────────────────────────────┤  ↑ z=200,
│APPEARNCE│  General                                          │    above
│ General │  Window gaps, borders, layout, tearing, snap       │    everything
│ Decorat │                                                    │
│ Animati │  PROFILES                                          │
│ Themes  │  [Active Profile · default     [Save] [Overwrite]] │
│         │  [Share · Import/Export        [Import] [Export]]  │
│INPUT&D  │                                                    │
│ Display │  GAPS                                              │
│ Input   │  [Inner gaps          22px]                        │
│ Panel   │  [Outer gaps          20px]                        │
│ Bar Mod │  ...                                               │
│ Sys Tray│                                                    │
│         │                                                    │
│CONNECT  │                                                    │
│ Sound   │                                                    │
│ Notif   │                                                    │
│         │                                                    │
│SYSTEM   │                                                    │
│ ...     │                                                    │
│         │                                                    │
│─────────│                                                    │
│👤 paul  │                                                    │
│Matugen…│                                                    │
└─────────┴───────────────────────────────────────────────────┘
```

When typing, the dropdown appears BELOW the floater, extending
LEFT (right-anchored at 320px wide), and floats ABOVE everything
else:

```
                                         [🔍 dens|       ]  ← bar
                                        ┌──────────────────┐
                                        │ 🎨 Densho mode   │  ← dropdown
                                        │ 🎨 Densho theme   │     z=200,
                                        │ 📅 Densho calendar│     scrollable
                                        │ ↕ Densho seasonal │     6 rows max
                                        └──────────────────┘
```

---

## Wala tayong babawasan

- All alpha.7 features intact
- `SettingsSearchBar.qml` not deleted (still on disk for any future
  re-use or visual reference)
- `SettingsSearchService` index unchanged — same data, new presentation
- Ctrl+F overlay (alpha.6-hf2) unaffected — uses its own Spotlight
  layout, not this floater
- Header drag, window controls, sidebar nav, user pill, theme indicator
  all unchanged

---

## Verified

- ✅ FloatingSettingsSearch.qml lint clean (qmlformat parse OK)
- ✅ ZenSettings.qml lint clean
- ✅ Mounted exactly once at root level with z: 200
- ✅ Anchored to both `parent.top` AND `parent.right`
- ✅ Sidebar SettingsSearchBar mount cleanly removed (zero references)
- ✅ Right margin 110px clears the max + close window control buttons
- ✅ Top margin 12px aligns vertically with header content
- ✅ Dropdown bounded to max 6 rows visible (288px), scrollable beyond

---

## To install

```bash
tar -xzf zen-shell-v7.0.0-alpha.7-hf5-floating-search.tgz
cd zen-shell-v7.0.0-alpha.7
./install.sh
qs -r
```

After install:

1. **Open Settings** → see the floating search bar in the top-right
   corner of the panel, just to the LEFT of the maximize/close
   buttons
2. **Click the search bar** → focus grabs (thanks to hf4 keyboard
   focus) → cursor blinks
3. **Type "densho"** → dropdown appears below the bar, floats over
   everything else
4. **If many results** → scrollable inside the dropdown (try
   "panel" or "theme" for many matches)
5. **Click any result** → Settings jumps to that page, search clears
6. **Press Esc** → clear text on first press, blur on second
7. **Click outside** → dropdown closes, search clears
