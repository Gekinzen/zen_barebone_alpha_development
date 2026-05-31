# v7.0.0-alpha.9 — Karui (軽い) · Auto-hide search + Super+Space

**Channel:** alpha
**Codename:** Karui (軽い · "lightweight")
**Sub-theme:** Search bar polish + Spotlight binding
**Released:** 2026-05-09
**Branch:** `dev`

---

## What this drop adds

User feedback after alpha.8-hf1: search bar position is now stable
(doesn't move on scroll), but it visually overlaps the scrolling
content because it's an overlay. User asked: "i mean naka stacked
siya sa taas ln pre kapag scroll ko diba mas ok hindi nadin siya
na sasama or pwd hide?"

Translation: "I mean it just stays stacked at the top — when I
scroll wouldn't it be better if it doesn't follow OR can hide?"

### 1. Auto-hide on scroll

Bar now fades out smoothly when user scrolls the content area, and
fades back in when scrolling stops. Prevents visual overlap of the
overlay bar with the scrolling page content.

#### How it works

New property on ZenSettings root:

```qml
property bool isContentScrolling: {
    if (typeof pageStack === "undefined") return false
    const page = pageStack.itemAt(pageStack.currentIndex)
    if (!page) return false
    if (page.contentItem && page.contentItem.movingVertically !== undefined) {
        return page.contentItem.movingVertically
    }
    return false
}
```

This binds to the **currently-visible page's ScrollView's internal
Flickable**, reading its `movingVertically` flag. That flag is true
while the Flickable is mid-flick or actively moving via wheel/drag,
false when settled. The binding auto-tracks page changes (when user
clicks a different sidebar entry, the binding re-resolves).

In shell.qml, the FloatingSettingsSearch's opacity binds to this:

```qml
opacity: zenSettingsPanel.isContentScrolling ? 0.0 : 1.0
Behavior on opacity {
    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
}
enabled: opacity > 0.5  // disable input mid-fade
```

180ms ease-out fade. Quick enough to feel responsive, slow enough
to feel intentional. The `enabled: opacity > 0.5` clause prevents
accidental input on a half-faded bar.

#### When it triggers

- Mouse wheel scroll on content → fade out → settle → fade in
- Click + drag scrollbar → fade out → release → fade in
- Programmatic scroll (e.g. clicking a Settings nav entry) → no
  fade (instant page change, contentItem reset, no `movingVertically`)
- User idle on page → bar stays visible

### 2. Super+Space binding (Spotlight-style)

Added new keybind alias for the existing Ctrl+F search overlay:

```
bind = $mainMod, Space, exec, qs -c zen-shell ipc call zen toggleSearch
```

Two entry points, same overlay:
- `Ctrl+F` — global text-search idiom (works in browsers, editors,
  etc.)
- `Super+Space` — Spotlight idiom (macOS, GNOME Activities-aligned
  muscle memory)

Both call the same `toggleSearch` IPC, so they hit the exact same
overlay UI with the same SettingsSearchService backend.

App-launching from the overlay (proper Spotlight behavior — type
"Brave" and press Enter to launch the browser) is **deferred to
alpha.10**. Right now the overlay still only searches Settings +
Control Panel entries; alpha.10 will integrate AppLauncherService
into the index so apps surface alongside settings.

### Why Spotlight-palette work was scoped down

Originally alpha.9 was going to be a full Spotlight command palette
(apps + files + calculator + theme switcher). After Paul's feedback
on the search-bar UX, it became clear the priority is **fixing the
existing search experience first** before piling on more features.

So alpha.9 = polish + foundation (Super+Space muscle memory). The
full Spotlight palette work is split off to alpha.10:

- alpha.10 — Spotlight palette: app launching, file search,
  calculator parsing, ~/.local/bin/zen-* command surfacing
- alpha.11 — Densho restyle (CC + page headers + brush separators)
- alpha.12 — Zen Notification Center (drops SwayNC)
- ...

---

## Files modified

```
zen-shell-v5/ZenSettings.qml      (+isContentScrolling computed property)
zen-shell-v5/shell.qml            (floater opacity bound to isContentScrolling
                                    + Behavior on opacity + enabled gating)
hypr-config/binds.conf            (+Super+Space alias for toggleSearch)
zen-shell-v5/ZenVersion.qml       (bumped to v7.0.0-alpha.9)
install.sh                        (version strings)
```

`FloatingSettingsSearch.qml` itself unchanged — the visibility/
opacity logic lives in the mount site (shell.qml), not the
component, because it's a wrapper-level concern.

---

## Wala tayong babawasan

- All alpha.8 features intact (pinned drag + scroll + persist)
- All alpha.7 features intact (ZenCleanup, clipboard onboarding,
  Material font auto-detect, OnDemand keyboard focus)
- Manual-click focus behavior preserved (alpha.8-hf1 audit)
- Floater position computed from panel geometry (alpha.8-hf1 fix)
- Ctrl+F keybind still works — Super+Space is an alias, not a
  replacement
- All search overlay logic (results, navigation, page routing)
  unchanged

---

## Behavior summary

| Action | Result |
|---|---|
| Open Settings (Super+,) | Floater visible, no focus |
| Type without clicking | Nothing (manual click required) |
| Click search bar | Cursor blinks, can type |
| Scroll content (wheel) | Floater **fades out**, content scrolls clean |
| Stop scrolling (release wheel) | Floater **fades back in** after settle |
| Drag panel via header | Floater follows panel position |
| Click sidebar nav (no scroll) | Page changes, floater stays visible |
| Press Ctrl+F (anywhere) | Spotlight overlay opens |
| Press Super+Space (anywhere) | Same Spotlight overlay opens |

---

## Verified

- ✅ shell.qml lint clean
- ✅ ZenSettings.qml lint clean
- ✅ `isContentScrolling` property declared and bound
- ✅ Floater opacity bound to `zenSettingsPanel.isContentScrolling`
- ✅ Behavior on opacity (180ms fade)
- ✅ enabled gated to opacity > 0.5
- ✅ Super+Space bind added to binds.conf

---

## To install

```bash
tar -xzf zen-shell-v7.0.0-alpha.9-autohide-spotlight.tgz
cd zen-shell-v7.0.0-alpha.9
./install.sh
qs -r
hyprctl reload   # picks up Super+Space bind
```

After install:

1. **Open Settings** → floater visible top-right corner
2. **Click search bar** → manual focus required (no auto-focus)
3. **Scroll content area** with wheel → floater fades out smoothly
4. **Stop scrolling** → floater fades back in after a moment
5. **Press Ctrl+F** anywhere → search overlay opens (existing)
6. **Press Super+Space** anywhere → SAME search overlay opens (new)
7. **Type in overlay** → searches Settings + Control Panel entries
   (apps + files coming alpha.10)

---

## Roadmap update

```
✅ alpha.5 — LaptopMode
✅ alpha.6 — Search + Clipboard
✅ alpha.7 — Cleanup + Polish
✅ alpha.8 — Pinned drag + scroll
✅ alpha.9 — Auto-hide search + Super+Space ← we are here
🎯 alpha.10 — Spotlight palette (apps + files + calculator)
   alpha.11 — Densho restyle (CC + page headers)
   alpha.12 — Zen Notification Center (drops SwayNC)
   alpha.13 — Workflow Profiles + Workspace Overview
   alpha.14 — UnifiedOSDService + HotCornerService
   ...
   beta.1-3 → v7.0.0 stable
```
