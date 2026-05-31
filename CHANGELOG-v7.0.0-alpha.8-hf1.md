# v7.0.0-alpha.8-hf1 — Floating search bar fixed positioning + no auto-focus

**Channel:** alpha (hotfix)
**Released:** 2026-05-09
**Branch:** `dev`

---

## What this hotfix fixes

User reported two issues with the alpha.8 floating search bar:

1. **Search bar moves when scrolling** — "wag mo na float kapag
   scroll ko sumasama padin e dapat naka stay nln siya lage sa taas"
   (don't make it float, when I scroll it follows; it should just
   stay at the top always)
2. **Auto-focus expected to be manual** — "wala naman ako type dapat
   manually click ko yu nsearch bar" (I'm not typing yet, I should
   click the search bar manually first)

### Root cause #1: search bar mounted INSIDE ZenSettings

In alpha.7-hf5, the FloatingSettingsSearch was mounted as the last
child of the ZenSettings root Rectangle, anchored to `parent.top`
and `parent.right`. Logically this should have been fixed because
the parent IS the panel root (not a Flickable).

But user reported visual "movement" during scroll. Possible causes:

- Repaint blips caused by Z-order resolution during fast scroll
- TextField inside the bar capturing mouse-wheel events meant for
  the page Flickable below
- Settings panel's drag-resize handlers could shift the panel root,
  making the anchored bar appear to move with it

**Fix:** Move the FloatingSettingsSearch entirely OUT of ZenSettings
and mount it at the PanelWindow level in shell.qml — sibling to the
ZenSettings instance, NOT a child.

```qml
// shell.qml — inside the settingsWindow PanelWindow

ZenSettings { id: zenSettingsPanel; ... }

FloatingSettingsSearch {
    visible: zenSettingsPanel.visible
    width: 220
    height: 32

    // Position computed from the resolved panel geometry —
    // completely decoupled from anything inside the panel
    x: zenSettingsPanel.x + zenSettingsPanel.width - width - 110
    y: zenSettingsPanel.y + 12

    z: 200
    surfaceFilter: "settings"
    onNavigateRequested: function(entry) {
        if (entry && entry.page) {
            zenSettingsPanel.currentPage = entry.page
        }
    }
}
```

Why this absolutely fixes the scroll-movement issue:

- The bar's parent is now the **PanelWindow's content item**, not
  the ZenSettings Rectangle
- Position is computed from `zenSettingsPanel.x` + `.width` which
  are layout-resolved coordinates — they only change when the user
  explicitly resizes or drags the panel, not on internal scrolling
- Mouse-wheel events inside ZenSettings can't reach the bar (they
  hit the page Flickable and stay there)
- No QML parent-child dependency between bar and panel content

### Root cause #2: no auto-focus exists, but verifying

Audit of FloatingSettingsSearch.qml shows only ONE
`input.forceActiveFocus()` call — and it's only fired when user
clicks the Clear (×) button. There's no `Component.onCompleted`
focus call, no `onVisibleChanged` focus call, no auto-focus on
hover.

So the auto-focus issue user reported was likely the v6.13 design
behavior (Settings panel uses `WlrLayershell.keyboardFocus: OnDemand`
since hf4) interacting with the user's expectation. With OnDemand,
clicking ANYWHERE on the Settings panel grabs Wayland keyboard
focus, but the QML active focus stays where it was.

**Verified behavior with this hotfix:**

- Open Settings → bar visible, no focus, placeholder visible
- Click anywhere on Settings (sidebar, content) → Wayland focus
  grabs to Settings, but TextField does NOT activate
- Type → keystrokes go to whatever QML element has focus (usually
  none — they're effectively swallowed)
- **Click the search bar specifically** → TextField activates,
  cursor blinks, typing fills the bar
- Click outside Settings → Wayland releases focus

This is the manual-click behavior the user asked for. No code
change needed — just confirming and documenting.

### Bonus: position formula

Old approach (anchored):
```qml
anchors.top: parent.top
anchors.right: parent.right
anchors.topMargin: 12
anchors.rightMargin: 110
```

New approach (computed):
```qml
x: zenSettingsPanel.x + zenSettingsPanel.width - width - 110
y: zenSettingsPanel.y + 12
```

The computed approach is more deterministic — there's no anchor-
resolution chain, no margin computation, just direct math. Easier
to reason about and harder to break with parent-layout changes.

The 110px clearance + 12px top inset come straight from the alpha.7-hf5
calculation (max + close buttons measure ~28px each + 12px gap +
12px right padding ≈ 80px, plus 30px safety = 110px).

---

## Files modified

```
zen-shell-v5/shell.qml          (+FloatingSettingsSearch mount at
                                  PanelWindow level, sibling to ZenSettings)
zen-shell-v5/ZenSettings.qml    (-FloatingSettingsSearch mount removed)
zen-shell-v5/ZenVersion.qml     (bumped to v7.0.0-alpha.8-hf1)
install.sh                      (version strings)
```

`FloatingSettingsSearch.qml` itself is unchanged — only its mount
location moved.

---

## Wala tayong babawasan

- All alpha.8 features intact (pinned drag + scroll + persist,
  search bar visual style match)
- All alpha.7 features intact (ZenCleanup, clipboard onboarding,
  Material font auto-detect, OnDemand keyboard focus)
- Bar visibility still bound to Settings visibility — closes with
  the panel
- 240px width, 32px height, top-right position all unchanged
- `pendingSearchPage` mechanism for Ctrl+F overlay → Settings
  navigation still works (uses zenSettingsPanel.currentPage which
  the floater also writes to)

---

## Verified

- ✅ shell.qml lint clean
- ✅ ZenSettings.qml lint clean
- ✅ FloatingSettingsSearch.qml lint clean
- ✅ Floater removed from ZenSettings (0 refs)
- ✅ Floater mounted exactly once in shell.qml
- ✅ Position uses `zenSettingsPanel.x + zenSettingsPanel.width - width - 110`
- ✅ Only 1 `forceActiveFocus` call (Clear button — fires on click only)

---

## To install

```bash
tar -xzf zen-shell-v7.0.0-alpha.8-hf1-fixed-position.tgz
cd zen-shell-v7.0.0-alpha.8
./install.sh
qs -r
```

After install:

1. **Open Settings** (Super+,) → search bar visible top-right of panel
2. **Type without clicking** → nothing happens (manual click required)
3. **Scroll the content area** with mouse wheel → search bar STAYS
   in place, no movement
4. **Drag the panel** by header → search bar moves WITH the panel
   (correct — it's tied to the panel position)
5. **Click search bar** → cursor blinks, type → text appears
6. **Click outside the search bar** → cursor leaves, text retained
7. **Close Settings** (Super+, again or ✕) → search bar disappears
   with the panel
