# v7.0.0-alpha.7-hf3 — Search bar moved to sidebar bottom

**Channel:** alpha (hotfix 3)
**Released:** 2026-05-09
**Branch:** `dev`

---

## What this hotfix fixes

User reported (looking at screenshot): the maximize and close (✕)
buttons disappeared from the Settings header after hf2's restructure
attempt. User asked: "pwd ba search lagay nln sa ibaba nung
settings?" — can we just put the search at the bottom of the
sidebar instead?

**Yes — and that's the cleaner solution all along.** The header has
genuine constraints (drag handle + window controls + title text
all need horizontal space), and trying to fit a 240px search bar
there was always going to be cramped on smaller window widths.

The sidebar has a **guaranteed sidebarWidth** — 220px in normal
mode, 260px in fullscreen — so the search bar always renders at
full width without competing with anything else. Plus it sits
right next to the nav list it filters, which is a more
intuitive pairing.

### What changed

#### 1. ZenSettings header — reverted to original

Restored the drag handle `Item` to `Layout.fillWidth: true` (was
`preferredWidth: dragInner.implicitWidth + 8` in hf2). Window
controls (maximize, close) get their proper space back. "Settings"
title text restored to `Layout.fillWidth: true` so it expands
naturally within the drag handle area.

Removed:
- The spacer `Item { Layout.fillWidth: true }` from the outer header
- The `SettingsSearchBar` block from the outer header
- The `dragInner` id reference

The header is now visually identical to v6.16 + alpha.6 pre-search,
with all three buttons (drag handle, maximize, close) visible
correctly.

#### 2. ZenSettings sidebar — SearchBar at the bottom

New mount point inside the sidebar's outer `ColumnLayout`, between
the `Flickable` (which holds the nav list) and the user-pill
`ColumnLayout` footer:

```qml
}  // close Flickable

// v7.0.0-alpha.7-hf3: Settings search bar
SettingsSearchBar {
    Layout.fillWidth: true               // takes full sidebar width
    Layout.preferredHeight: 36           // bigger than 32 so it's tappable
    Layout.bottomMargin: 8               // breathing room above user pill
    surfaceFilter: "settings"
    onNavigateRequested: function(entry) {
        if (entry && entry.page) {
            root.currentPage = entry.page
        }
    }
}

// (user pill ColumnLayout follows)
```

Visual layout becomes:

```
┌────────────┬──────────────────────────┐
│ ⚙ Settings │  [General page content]  │  ← header back to normal
├────────────┤                          │     [— ▢ ✕]
│ APPEARANCE │                          │
│  General   │                          │
│  Decoration│                          │
│  Animations│                          │
│  Themes    │                          │
│            │                          │
│ INPUT&DISP │                          │
│  Displays  │                          │
│  Input     │                          │
│  ...       │                          │
│            │                          │
│ ─────────  │                          │
│ [🔍 Search]│  ← NEW: full sidebar    │
│            │     width search bar    │
│ ─────────  │                          │
│ [👤 paul ] │                          │
│ Matugen... │                          │
└────────────┴──────────────────────────┘
```

Why this is better:

- **Full sidebar width** (220-260px) instead of 240px squeezed in header
- **No fight with window controls** — header chrome unchanged
- **Persistent visibility** — visible regardless of which page is
  active in the content area
- **Semantic grouping** — search next to the nav it filters, above
  the user/theme footer
- **Familiar pattern** — VS Code, GitHub, Discord all use sidebar-
  bottom search

#### 3. ControlPanel — SearchBar removed entirely

CC has tighter constraints than Settings (compact 320px column in
non-cascade mode). Even with the alpha.7 attempt at `Layout.preferredWidth: 130`
on the drag handle, fitting search bar + drag handle + close button
in 320px was always going to look cramped.

**Solution:** Remove the inline CC search bar entirely. Use the
**Ctrl+F overlay** (alpha.6-hf2 — works system-wide) to search
Control Center entries. Same `SettingsSearchService` backend, just
accessed via the overlay modal instead of an inline bar.

The Ctrl+F overlay already shows CC entries with `surface: "controlpanel"`
filter — the navigation handler in shell.qml (alpha.7) routes
selections to `expandedTab` correctly.

So users still get full CC search, just through a different (more
spacious) UI surface.

---

## Files modified

```
zen-shell-v5/ZenSettings.qml      (header reverted, SearchBar in sidebar)
zen-shell-v5/ControlPanel.qml     (SearchBar removed from header,
                                    drag handle back to fillWidth)
zen-shell-v5/ZenVersion.qml       (bumped to v7.0.0-alpha.7-hf3)
install.sh                        (version strings)
```

No other files touched. SettingsSearchBar.qml internals unchanged.

---

## Wala tayong babawasan

- All alpha.7 features intact (ZenCleanup, clipboard onboarding,
  CC tab navigation via Ctrl+F)
- Settings still searchable inline (just from sidebar bottom now)
- Control Panel still searchable (via Ctrl+F overlay — same backend)
- Window controls (max, close) restored
- Header drag still works on gear+title area
- Sidebar nav list, scrollbar, user pill, theme indicator all
  untouched

---

## Verified

- ✅ ZenSettings.qml lint clean
- ✅ ControlPanel.qml lint clean
- ✅ SettingsSearchBar.qml lint clean
- ✅ ZenSettings drag handle restored to `Layout.fillWidth: true`
- ✅ SearchBar mounted at line 458, right after Flickable close (line 441)
- ✅ ControlPanel: zero SettingsSearchBar references (removed cleanly)
- ✅ ControlPanel drag handle restored to `Layout.fillWidth: true`

---

## To install

```bash
tar -xzf zen-shell-v7.0.0-alpha.7-hf3-search-sidebar.tgz
cd zen-shell-v7.0.0-alpha.7
./install.sh
qs -r
```

After install:

1. **Open Settings** → header should look exactly like v6 / pre-search
   (gear + "Settings" title + maximize button + close button — all
   visible, no overlap)
2. **Sidebar bottom** → search bar visible above the user/theme
   footer, full sidebar width
3. **Type in sidebar search** → dropdown appears with matched entries
4. **Press Ctrl+F anywhere** → Spotlight overlay opens, searches
   both Settings AND Control Center entries
5. **Open Control Panel** → no inline search bar (just drag handle
   + close button) — use Ctrl+F to search CC

Test if everything renders cleanly now pre.
