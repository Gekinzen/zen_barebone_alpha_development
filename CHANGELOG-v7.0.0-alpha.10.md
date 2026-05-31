# v7.0.0-alpha.10 — Karui (軽い) · Spotlight palette + slide-out search

**Channel:** alpha
**Codename:** Karui (軽い · "lightweight")
**Sub-theme:** Spotlight command palette + search bar polish
**Released:** 2026-05-09
**Branch:** `dev`

---

## What this drop adds

User feedback: "dapat hide sa gilid pre kapag scroll ko yung search
and yun close dapat close icon now kasi box yung itsura. game
proceed kana din now sa alpha 10 alpha.10 — Spotlight palette
(apps + files + calculator) while ifix mo ito search natin."

Two parallel tracks delivered together:

### Track 1: Search bar polish

#### 1.1 Slide-out animation on scroll

The bar now physically slides RIGHT (off-screen past the panel
edge) when the user scrolls content, instead of just fading. The
slide is more intuitive than fade for "the thing got out of my
way" — feels like the bar respectfully steps aside.

Math:

```qml
readonly property real restingX:
    zenSettingsPanel.x + zenSettingsPanel.width - width - 110
readonly property real slidOutX:
    zenSettingsPanel.x + zenSettingsPanel.width + 20

x: zenSettingsPanel.isContentScrolling ? slidOutX : restingX

Behavior on x {
    NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
}
```

`slidOutX` is 20px PAST the panel's right edge — bar is fully
off-screen during scroll. 240ms ease-out for the slide; 200ms
fade alongside for visual polish.

#### 1.2 Close button uses Unicode × instead of Material/Nerd glyph

`MaterialIcons.icon("close")` was returning Nerd Font's `\uf00d`
glyph, which on Paul's setup was rendering as a square box (font
fallback issue when neither Material nor a proper Nerd Font var
is installed). Changed to plain Unicode MULTIPLICATION SIGN
(`U+00D7` — "×") which is present in every font:

```qml
Text {
    text: "×"
    font.family: Theme.fontFamily      // system default font
    font.pixelSize: 16
    font.weight: Font.Bold
    color: clearMa.containsMouse ? ThemeService.fg : ThemeService.grey0
}
```

The character renders identically across all fonts → no more
"box" appearance regardless of font installation state.

### Track 2: Spotlight command palette

The Ctrl+F (and Super+Space alpha.9) overlay now searches **three
new surfaces** in addition to Settings + Control Panel:

#### 2.1 App launching

`SettingsSearchService.search()` extended to scan
`AppLauncherService.apps` for prefix + contains matches. Up to 5
app results per query, surfaced with a "rocket_launch" icon and
"App" badge. Selecting an app result calls
`AppLauncherService.launch(_appData)` which spawns it via the
existing gtk-launch / dex pipeline.

```
Type "brav" in Ctrl+F overlay
↓
Results:
  🚀 Brave              [App]    ← prefix match, top
     Web Browser

Press Enter → Brave launches
```

App results are appended AFTER Settings results in the result
list, since searching for an app via Settings overlay is a
secondary use-case (Settings entries are the primary).

#### 2.2 Calculator

If the query parses as a math expression (digits + operators +
parens + decimals), evaluator returns a single result entry with
the formatted answer:

```
Type "100*1.08" in overlay
↓
Result:
  🧮 108              [Calc]    ← top (calc results come first)
     100*1.08 = 108

Press Enter → "108" copied to clipboard via wl-copy
```

Implementation:

```qml
function _evaluateMath(query) {
    if (!/\d/.test(query)) return []                         // no digits = not math
    const sanitized = query.replace(/\s+/g, "")
    if (!/^[\d+\-*/.()%]+$/.test(sanitized)) return []       // whitelist chars
    if (/^-?\d+(\.\d+)?$/.test(sanitized)) return []          // just a number isn't a calc
    try {
        const result = (new Function("return (" + sanitized + ")"))()
        if (typeof result !== "number" || !isFinite(result)) return []
        const formatted = (result === Math.floor(result))
            ? result.toString()
            : parseFloat(result.toFixed(6)).toString()
        return [{
            id: "calc:" + sanitized,
            title: formatted,
            subtitle: sanitized + " = " + formatted,
            icon: "calculator",
            surface: "calculator",
            page: "",
            _calcResult: formatted
        }]
    } catch (e) { return [] }
}
```

Safety: char whitelist + Function() constructor (isolated scope,
no closure access). Never `eval()` raw user input.

Supports: `+ - * / ( ) % .` and decimals. Rejects: variables,
function calls, anything not in the whitelist. Calc result
position FIRST in result list (above Settings + apps) so it's
immediately visible when typing a math query.

#### 2.3 Files (deferred to alpha.11)

File search needs a separate `FileSearchService` that watches
`~/Documents`, `~/Downloads`, `~/Desktop` recent file changes.
That's a non-trivial new service with its own state file and
inotify watchers — splitting to alpha.11 keeps alpha.10 focused
on the easy wins.

#### 2.4 Result ordering

```
[Calculator result (if math expression)]   ← topmost, exact match
[Settings — title prefix matches]
[Settings — title contains matches]
[Settings — subtitle/keyword matches]
[Apps (up to 5)]                            ← bottom, secondary
```

Surface labels:
- `surface: "settings"` → "Settings" badge
- `surface: "controlpanel"` → "Control Center" badge
- `surface: "app"` → "App" badge
- `surface: "calculator"` → "Calc" badge

#### 2.5 Empty-state hint updated

Old: `"Try: densho · clipboard · matugen · battery · themes"`
New: `"Try: brave · 2+2 · densho · matugen · battery · clipboard"`

Now hints at the new capabilities (app launching + calc) alongside
the existing Settings search.

---

## Files modified

```
zen-shell-v5/shell.qml                 (slide-out animation, app +
                                          calc nav handlers in overlay)
zen-shell-v5/SettingsSearchService.qml (extended search() with apps +
                                          calc, +_evaluateMath, +new
                                          surface labels)
zen-shell-v5/SettingsSearchOverlay.qml  (updated empty-state hint)
zen-shell-v5/FloatingSettingsSearch.qml (close icon → Unicode ×)
zen-shell-v5/ZenVersion.qml             (bumped to v7.0.0-alpha.10)
install.sh                              (version strings)
```

---

## Wala tayong babawasan

- All alpha.9 features intact (auto-hide on scroll, Super+Space
  alias, manual-click focus)
- All alpha.8 features intact (pinned drag + scroll + persist)
- All alpha.7 features intact (ZenCleanup, clipboard onboarding)
- `MaterialIcons.icon("close")` still works elsewhere — only the
  FloatingSettingsSearch close button uses Unicode ×
- AppLauncherService API unchanged — we just consume `apps` array
- Settings results are still primary (calc + apps are append-on-
  match, never push them out)
- Original Settings index unchanged → existing keybind muscle
  memory preserved

---

## Behavior summary

### Search bar in Settings

| Action | Result |
|---|---|
| Open Settings | Bar visible top-right |
| Type without click | Nothing (manual click required) |
| Click search bar | Cursor blinks, can type |
| **Scroll content area** | **Bar SLIDES off to the right + fades** ✅ |
| **Stop scrolling** | **Bar slides back in from right** ✅ |
| Click clear (×) | Text clears, dropdown closes; **proper × glyph** ✅ |
| Press Esc | Same as clear button |

### Spotlight palette (Ctrl+F or Super+Space)

| Query | Top result |
|---|---|
| `brave` | 🚀 Brave [App] — Enter launches |
| `2+2` | 🧮 4 [Calc] — Enter copies "4" to clipboard |
| `100*1.08` | 🧮 108 [Calc] |
| `densho` | 🎨 Densho mode [Settings] |
| `wifi` | 📡 Wi-Fi [Control Center] |
| `bra` | Mix: 🚀 Brave [App], plus any settings with "bra" |

---

## Verified

- ✅ All 4 modified files lint clean
- ✅ Slide-out animation: restingX + slidOutX both bound to panel geometry
- ✅ 240ms Behavior on x for slide animation
- ✅ Close icon uses Unicode `×` (U+00D7) — universal glyph
- ✅ `_evaluateMath` function with safety whitelist + isolated Function()
- ✅ AppLauncherService.apps consumed in search()
- ✅ Search overlay nav handler routes 'app' → AppLauncherService.launch()
- ✅ Search overlay nav handler routes 'calculator' → wl-copy clipboard
- ✅ surfaceLabel returns "App" for app, "Calc" for calculator

---

## To install

```bash
tar -xzf zen-shell-v7.0.0-alpha.10-spotlight-slideout.tgz
cd zen-shell-v7.0.0-alpha.10
./install.sh
qs -r
```

After install:

1. **Open Settings** → bar visible top-right
2. **Click search bar** → manual focus
3. **Type "panel"** → dropdown shows results, click × → dropdown closes
4. **Notice × is a proper close icon** (not a square box) ✅
5. **Scroll content area** → bar slides off to the right ✅
6. **Stop scroll** → bar slides back in
7. **Press Ctrl+F or Super+Space** → Spotlight overlay opens
8. **Type "brave"** → see 🚀 Brave [App] result
9. **Press Enter** → Brave launches
10. **Open overlay again, type "2+2"** → see 🧮 4 [Calc]
11. **Press Enter** → "4" copied to clipboard, paste anywhere to verify
12. **Try "100*1.08"** → 108
13. **Try "densho"** → Settings entries surface (still primary use-case)

---

## Roadmap update

```
✅ alpha.5 — LaptopMode
✅ alpha.6 — Search + Clipboard
✅ alpha.7 — Cleanup + Polish
✅ alpha.8 — Pinned drag + scroll
✅ alpha.9 — Auto-hide search + Super+Space
✅ alpha.10 — Spotlight palette + slide-out ← we are here
🎯 alpha.11 — Spotlight files + Densho restyle (CC + page headers)
   alpha.12 — Zen Notification Center (drops SwayNC)
   alpha.13 — Workflow Profiles + Workspace Overview
   alpha.14 — UnifiedOSDService + HotCornerService
   ...
   beta.1-3 → v7.0.0 stable
```
