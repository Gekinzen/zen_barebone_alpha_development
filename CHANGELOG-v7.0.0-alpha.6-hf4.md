# v7.0.0-alpha.6-hf4 — Clipboard panel position + icon fallback

**Channel:** alpha (hotfix 4)
**Released:** 2026-05-09
**Branch:** `dev`

---

## What this hotfix fixes

Two issues from user testing on multi-monitor + Nerd-Font-only setup:

### 1. Panel popped up at far-left edge instead of under the icon

**Cause:** `clipboardWindow.margins.left` was hardcoded to `8` for
horizontal bars — pinning the panel to the screen's left edge
regardless of where the user placed the clipboard module in their
bar layout. Paul's clipboard sits on the right side; panel appeared
at far-left, which felt disconnected.

**Fix:** Mirrored StartMenu's button-position-reporting pattern.

New PanelState properties:

```qml
property real clipboardButtonCenterX: -1
property real clipboardButtonRightX: -1

function reportClipboardButtonPosition(centerX: real, rightX: real) {
    clipboardButtonCenterX = centerX
    clipboardButtonRightX = rightX
}
```

ClipboardModule's onClicked handler now reports its global position
BEFORE triggering the IPC:

```qml
const localRight = cm.mapToItem(null, cm.width, cm.height / 2)
const barScreenX = ...   // same logic as StartMenu (island/floating/fullwidth)
const globalRight = barScreenX + localRight.x
PanelState.reportClipboardButtonPosition(globalCenter, globalRight)
```

shell.qml's clipboardWindow now anchors its RIGHT edge to the
clipboard button's right edge:

```qml
margins.left: {
    const btnRight = PanelState.clipboardButtonRightX
    if (btnRight < 0) return 8   // fallback if no report yet
    const w = clipboardWindow.implicitWidth
    const desired = btnRight - w   // panel's left = btn right - panel width
    return Math.max(8, Math.min(screenW - w - 8, desired))
}
```

Result: panel pops up directly under (bottom bar) or over (top bar)
the clipboard icon, regardless of whether you placed the module on
the left, center, or right of your bar layout.

I chose RIGHT-anchor (panel's right edge = button's right edge) over
LEFT-anchor (StartMenu's approach) because clipboard typically sits
on the right side of the bar, and right-anchoring keeps the panel
flush with the bar's right edge for a clean look. If user pins
clipboard to the far-left, the panel still expands rightward from
there since the desired position falls within bounds.

### 2. Icon glyphs rendered as garbage X's

**Cause:** Material Symbols Outlined font wasn't installed on Paul's
system (yet). The font.family fallback chain
`"Material Symbols Outlined, Material Icons Outlined, JetBrainsMono Nerd Font"`
fell all the way through to JetBrainsMono Nerd Font — but the
codepoints in MaterialIcons.registry are MATERIAL codepoints
(`\ue14d` etc.). Nerd Font has totally different glyphs at those
codepoints, so we got random symbols and X's.

**Fix:** Added a parallel `nerdFallback` registry with Nerd Font
codepoints for the same icon names, plus a `materialAvailable`
boolean that picks the right registry (and matching font.family).

Default behavior changed: **`materialAvailable` defaults to false**.
Out-of-the-box, every user now gets working Nerd Font glyphs
(consistent with the rest of v6/v7 surfaces). Users who want
crisper Material aesthetics can:

1. Install the font: `yay -S ttf-material-symbols-variable-git`
2. Flip `materialAvailable: true` (manual edit for now; Settings
   toggle coming in alpha.7)

Consumers don't need any changes — both `MaterialIcons.fontFamily`
and `MaterialIcons.icon(name)` auto-switch based on the flag, so
font + codepoint stay in sync.

#### Nerd Font fallback codepoints picked

| Icon name | Material | Nerd Font fallback | Glyph |
|---|---|---|---|
| `search` | `\ue8b6` | `\uf002` | 🔍 |
| `close` | `\ue5cd` | `\uf00d` | ✕ |
| `assignment` (clipboard) | `\ue85d` | `\uf46d` | 📋 |
| `content_paste` | `\ue14f` | `\uf0ea` | 📋 |
| `content_copy` | `\ue14d` | `\uf0c5` | 📄 |
| `push_pin` | `\uf10d` | `\uf08d` | 📌 |
| `delete` | `\ue872` | `\uf2ed` | 🗑 |
| `palette` | `\ue40a` | `\uf53f` | 🎨 |
| `tune` | `\ue429` | `\uf013` | ⚙ |

…and ~30 more. All chosen for visual similarity to the Material
glyph; where no perfect Nerd equivalent exists, closest available
is picked.

---

## Files modified

```
zen-shell-v5/MaterialIcons.qml      (+nerdFallback registry, +materialAvailable
                                      flag, fontFamily becomes auto-switching)
zen-shell-v5/PanelState.qml         (+clipboardButtonCenterX/RightX,
                                      +reportClipboardButtonPosition function)
zen-shell-v5/ClipboardModule.qml    (onClicked reports position before IPC)
zen-shell-v5/shell.qml              (clipboardWindow.margins.left now reads
                                      clipboardButtonRightX with bounds clamp)
zen-shell-v5/ZenVersion.qml         (bumped to v7.0.0-alpha.6-hf4)
install.sh                          (version strings)
```

ClipboardService, ClipboardPanel, SettingsSearchService,
SettingsSearchBar, SettingsSearchOverlay all unchanged from hf3.

---

## Wala tayong babawasan

- `MaterialIcons.fontFamily` API unchanged — just the value it
  resolves to is now conditional on `materialAvailable`. All
  existing consumers (5 files) work without modification.
- Material codepoint registry kept intact — when a user installs
  the Material font and flips the flag, all the original glyphs
  return.
- Nerd Font is already a hard dependency of the shell (every
  v6/v7 surface uses it), so nerdFallback codepoints don't add a
  new requirement.
- ClipboardService logic + cliphist integration unchanged.
- StartMenu / Settings / Search overlay all unaffected.

---

## Verified

- ✅ All 4 modified files lint clean
- ✅ `clipboardButtonCenterX` + `clipboardButtonRightX` declared in PanelState
- ✅ `reportClipboardButtonPosition` function present
- ✅ ClipboardModule reports position on click
- ✅ shell.qml clipboardWindow consumes clipboardButtonRightX
- ✅ `materialAvailable` defaults to false
- ✅ `nerdFallback` registry present with ~40 entries

---

## To install

```bash
tar -xzf zen-shell-v7.0.0-alpha.6-hf4-position-icons-fix.tgz
cd zen-shell-v7.0.0-alpha.6
./install.sh
qs -r
```

After install:

1. **Click clipboard icon in your bar** → panel pops up directly
   under (or over) the icon, anchored to the icon's right edge —
   not the screen's left edge anymore.
2. **Icons render properly** with Nerd Font glyphs (search 🔍,
   clipboard 📋, pin 📌, etc.) instead of X's.
3. (Optional) Install ttf-material-symbols-variable-git and edit
   `MaterialIcons.qml` to set `materialAvailable: true` if you
   want crisper Material glyphs.
