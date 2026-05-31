# v7.0.0-alpha.7-hf2 — Settings header structural fix

**Channel:** alpha (hotfix 2)
**Released:** 2026-05-09
**Branch:** `dev`

---

## What this hotfix fixes

User reported: search bar in Settings header still broken — rendering
at ~80px width instead of 240px, with placeholder text overlapping
icons.

### Root cause: nested fillWidth in the header layout

The Settings header has a 3-level layout:

```
RowLayout (outer header)
  ├── Item { Layout.fillWidth: true }    ← drag handle wrapper
  │     └── RowLayout (inner)
  │           ├── gear icon
  │           ├── "Settings" text
  │           ├── Item { fillWidth }     ← spacer (alpha.6 added)
  │           └── SettingsSearchBar      ← alpha.6 added here
  └── window controls (✕ ▢ —)
```

In hf1 my SettingsSearchBar had a fixed `Layout.preferredWidth: 240`,
which should have been honored. But it was being squeezed because:

1. The OUTER drag handle Item is `Layout.fillWidth: true` — it claims
   ALL available space minus the window controls
2. INSIDE that, the inner RowLayout has the spacer + SearchBar fighting
   for slack
3. When the panel is at minimum width, the spacer collapsed to 0px,
   then the SearchBar was forced to share width with everything else
   in the inner RowLayout (gear, title, spacer — all competing for
   the same space)

The visual was: SearchBar collapsed to ~80px, spacer to 0px, and the
TextField placeholder + close button overlapped the search icon
because the SearchBar's internal RowLayout couldn't fit them all.

### Fix: shrink drag handle, move search outside

Restructured the outer header:

```
RowLayout (outer header)
  ├── Item                                ← drag handle, shrunk
  │     Layout.preferredWidth: dragInner.implicitWidth + 8
  │     └── RowLayout (inner)
  │           ├── gear icon
  │           └── "Settings" text         ← stops here now
  │     └── MouseArea (drag.target = root)
  ├── Item { Layout.fillWidth: true }     ← spacer (NEW location)
  ├── SettingsSearchBar                    ← OUTSIDE drag handle
  │     Layout.preferredWidth: 240
  └── window controls (✕ ▢ —)
```

Key changes:

1. **Drag handle is `Layout.preferredWidth`** instead of fillWidth —
   sizes itself to fit gear + title + small padding, no more.
2. **Spacer is now in the OUTER RowLayout**, between drag handle and
   SearchBar — eats slack at the correct level.
3. **SearchBar is at the OUTER RowLayout level**, with its 240px
   width preserved against any window-shrinking.
4. **Drag MouseArea covers ONLY the drag handle Item now** — clicking
   on the SearchBar doesn't accidentally trigger a panel drag (UX
   bonus: the SearchBar text input gets focus normally on click).

### Bonus: dragInner.implicitWidth pattern

The drag handle's preferredWidth binds to `dragInner.implicitWidth + 8`
where `dragInner` is the inner RowLayout. As the title text changes
(e.g. localized to "設定" vs "Settings"), the drag handle auto-resizes
to fit. No hardcoded width to maintain.

ControlPanel header was already correctly structured (uses
`Layout.preferredWidth: 130` for its drag handle) — that surface
needs no fix.

---

## Files modified

```
zen-shell-v5/ZenSettings.qml      (header layout restructure)
zen-shell-v5/ZenVersion.qml       (bumped to v7.0.0-alpha.7-hf2)
install.sh                        (version strings)
```

No other files touched. SettingsSearchBar.qml itself is unchanged
from hf1 — its internals were correct, the issue was its parent
container.

---

## Wala tayong babawasan

- All alpha.7 features intact
- Drag still works on gear+title (the original drag handle scope)
- Window controls unaffected — same Rectangle/MouseArea blocks
- Search bar internals (icon, text input, clear button) unchanged
- Hypr Control Center search bar unaffected (already had correct
  preferredWidth pattern)

---

## To install

```bash
tar -xzf zen-shell-v7.0.0-alpha.7-hf2-search-layout-fix.tgz
cd zen-shell-v7.0.0-alpha.7
./install.sh
qs -r
```

After install:

The Settings header should render as:

```
[⚙ Settings]                               [🔍 Search…]    [— ▢ ✕]
↑ drag handle                              ↑ 240px wide   ↑ window
  (auto-sizes)                                              controls
```

Click + type in search bar → dropdown appears below, no more
overlap or squeeze. Drag from gear/title still moves the panel.
Drag attempt from search bar = focuses input instead (correct UX).
