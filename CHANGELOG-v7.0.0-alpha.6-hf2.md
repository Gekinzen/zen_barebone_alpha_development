# v7.0.0-alpha.6-hf2 — Search layout fix + Spotlight overlay

**Channel:** alpha (hotfix 2)
**Released:** 2026-05-09
**Branch:** `dev`

---

## What this hotfix fixes

User reported the alpha.6 search bar was squeezed in the Settings
header next to the title and window controls (—/▢/✕), getting
clipped on narrower windows. Also Paul wanted both an inline search
bar AND a Spotlight-style overlay.

This hotfix delivers both — Option B + C from the layout mockup.

### 1. Inline search bar (Option B): right-aligned, fixed width

Rebuilt the Settings header layout:

```
BEFORE (alpha.6)                    AFTER (hf2)
┌─────────────────────────────┐    ┌─────────────────────────────┐
│ ⚙ Settings [Searc...] — ▢ ✕ │ →  │ ⚙ Settings  ⋯⋯  [Search] — ▢ ✕ │
│           ↑ clipped         │    │              ↑ spacer       │
└─────────────────────────────┘    └─────────────────────────────┘
```

**Changes:**

- Removed `Layout.fillWidth: true` from "Settings" title (was eating
  the slack that should belong to the spacer)
- Search bar moved AFTER the spacer (previously between title and
  controls)
- Width capped at 240px (was 320px which made the squeeze worse)
- Height reduced to 32px (better proportion vs window controls)

The spacer (`Item { Layout.fillWidth: true }`) absorbs all the slack,
so search bar stays a clean fixed width regardless of window size.
On narrow windows it doesn't compete with anything.

### 2. Spotlight-style overlay (Option C): Ctrl+F system-wide

Brand-new component: **`SettingsSearchOverlay.qml`** — global modal
that pops up over everything when you hit Ctrl+F (or run
`qs ipc call zen toggleSearch`).

**Layout:**

- Full-screen dimmed backdrop (55% black)
- Centered panel, 600px wide, anchored 18% from top (Spotlight-y)
- Large 22px search field with Material search icon
- Up to 8 results rendered in 54px-tall rows
- Empty state with helpful query suggestions
- Footer hint: "↑↓ navigate · ↵ open · Esc close"

**Keyboard:**

- `Ctrl+F` — toggle (open if closed, close if open)
- `Esc` — clear text or close
- `↑/↓` — navigate results
- `Enter` — open the highlighted result

**Architecture:**

- Mounted at `WlrLayer.Overlay` so it floats above all shell surfaces
- `HyprlandFocusGrab` so click-outside closes
- One `PanelWindow` per screen via `Variants` model (only visible on
  the active screen via grab semantics)
- IPC routes: `toggleSearch`, `openSearch`, `closeSearch`

**Result navigation:**

When user picks a Settings entry from overlay results:

1. `pendingSearchPage` property set on shell root
2. `settingsVisible` flipped true → Settings PanelWindow shows
3. `ZenSettings` instance reads `pendingSearchPage` on
   `onVisibleChanged` and flips `currentPage` to the matched entry
4. `Connections { target: root }` block also reacts to
   `pendingSearchPage` changes when Settings is already open
   (e.g. user hits Ctrl+F from inside Settings, picks a different
   entry — the page change still triggers cleanly)

For Control Center entries (alpha.7 mount), the navigation handler
just logs for now — alpha.7 will wire it up to flip the appropriate
tab.

### 3. Clipboard panel mount (was missing)

Found that ClipboardModule + ClipboardPanel + ClipboardService all
shipped in alpha.6 but the `PanelWindow` mount in `shell.qml` was
missing — clicking the clipboard bar module flipped
`PanelState.clipboardVisible` but no window appeared. Added the
missing mount in this hotfix using the same sticky-to-bar geometry
as StartMenu.

Now Super+V (or click the bar module) properly opens
ClipboardPanel as a full overlay panel.

### 4. Hyprland keybinds added

`hypr-config/binds.conf` patched with:

```
bind = CTRL, F, exec, qs -c zen-shell ipc call zen toggleSearch
bind = $mainMod, V, exec, qs -c zen-shell ipc call zen toggleClipboard
```

Install.sh re-applies binds.conf on install, so existing users get
the new bindings automatically.

---

## What you can do now

| Action | Result |
|---|---|
| Open Settings | Header has 240px search bar at top-right |
| Type in header bar | Inline dropdown of matched entries |
| Press Ctrl+F (anywhere) | Spotlight-style overlay opens with focus |
| Type in overlay | Full-width result list, ~54px rows |
| Press ↑↓ in overlay | Navigate results |
| Press Enter in overlay | Open Settings to matched page |
| Click outside overlay | Close (no navigation) |
| Press Super+V | Clipboard panel opens |
| Click clipboard bar module | Same — clipboard panel toggles |

---

## Files modified / added

```
zen-shell-v5/SettingsSearchOverlay.qml   (NEW, ~280 lines)
zen-shell-v5/ZenSettings.qml             (header layout fix)
zen-shell-v5/PanelState.qml              (+searchOverlayVisible property)
zen-shell-v5/shell.qml                   (+overlay mount, +clipboard mount,
                                           +pendingSearchPage state,
                                           +4 IPC routes)
hypr-config/binds.conf                   (+Ctrl+F, +Super+V binds)
zen-shell-v5/ZenVersion.qml              (bumped to v7.0.0-alpha.6-hf2)
install.sh                               (version strings)
```

---

## Wala tayong babawasan

- Inline search bar continues to work (it's the alpha.6 component
  unchanged) — overlay is ADDITIONAL, not replacement
- Same `SettingsSearchService` index serves both surfaces — single
  source of truth, two UI consumers
- Existing Settings/Control Center navigation patterns preserved —
  search just adds a new entry path
- Hyprland binds are append-only (existing binds preserved); install
  is idempotent (re-running won't duplicate the entries because
  install.sh copies the whole file)

---

## To install

```bash
tar -xzf zen-shell-v7.0.0-alpha.6-hf2-search-fix.tgz
cd zen-shell-v7.0.0-alpha.6
./install.sh
qs -r
hyprctl reload   # picks up the new keybinds
```

Auto-snapshot of v7.0.0-alpha.6-hf1 install before overwrite.
