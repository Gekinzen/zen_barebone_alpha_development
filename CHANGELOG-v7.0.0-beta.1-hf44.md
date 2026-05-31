# v7.0.0-beta.1-hf44 — Custom theme profiles save FULL state

**Channel:** beta (hotfix)
**Released:** 2026-05-17
**Branch:** `dev`

---

## What this hotfix fixes

User report (screenshot included the Themes Settings page with
"paultheme" selected):

> "nung nag save ako ng profile ko sa theme nung pinili ko ulit yun
> profile ko hindi na detect yun mga setup ko sa profile ko ? sa themes"

The user saved a custom theme profile ("paultheme"), customized
several settings beyond just colors (bar opacity, brush-stroke
separators, style mode, etc.), then later re-selected the profile
expecting their full setup to come back — but only colors restored.

---

## Root cause

`ThemeService.saveAsCustomTheme()` was capturing **only the colors**:

```qml
const data = {
    id: id,
    name: displayName,
    description: "...",
    is_builtin: false,
    colors: {
        bg0: colorToHex(bg0), bg1: colorToHex(bg1), ..., purple: colorToHex(purple)
    }
}
```

The matching `applyJson()` loader only read `data.colors`. Everything
else — panel opacity, radius, style mode, bar module layout, fonts,
Densho toggles like brush-stroke separators — was completely ignored
both on save AND on load.

So saving was a partial snapshot. Reloading the profile got you
the colors back but reset everything else to whatever the user's
current preferences were (or defaults if first install).

That's why Paul's seasonal-kanji / brush-stroke-separators / panel
tweaks weren't there when he re-selected paultheme.

---

## Fix

### Save side — full state capture

`saveAsCustomTheme()` now adds two new blocks to the JSON:

```json
{
  "id": "paultheme",
  "name": "paultheme",
  "schemaVersion": 2,
  "colors": { ...same as before... },
  "theme": {
    "styleMode": "floating",
    "barOpacity": 0.45,
    "barRadius": 18,
    "fontFamily": "Adwaita Sans",
    "monoFont": "JetBrainsMono Nerd Font Propo",
    "fontSize": 14,
    "iconSize": 20,
    "barLayout": {
      "left": ["start", "taskbar"],
      "center": ["workspaces", "window"],
      "right": ["music", "sysrow", "tray", "workflow", "clipboard",
                "quicknotes", "titletranslator", "battery",
                "powerbadge", "notifications", "clock"]
    }
  },
  "densho": {
    "denshoMode": true,
    "kanjiWorkspaces": true,
    "verticalDate": true,
    "seasonalKanji": true,
    "brushSeparators": true
  }
}
```

The `theme` block captures Theme.qml visual + layout state.
The `densho` block captures DenshoService toggle state.
`schemaVersion: 2` tags this as the new format.

### Load side — backward-compatible restore

`applyJson()` now reads those blocks (if present) and applies them
to `Theme.*` and `DenshoService.*` directly. Uses safe type checks
(`typeof X === "boolean"`, etc.) so falsy values like `false` and `0`
are preserved — naive truthy checks would have skipped them.

**Backward compatible:** old profiles (schemaVersion missing or 1)
don't have `theme` / `densho` blocks. The loader detects this and
leaves the user's CURRENT non-color settings alone. So loading an
old profile = colors restored, everything else stays as you have it
right now. No nuking of unrelated state.

### Persistence chain

After `applyJson` restores Theme + Densho state, it calls
`PanelState.saveState()` (via `Qt.callLater`) so the restored
Theme props are persisted to `panel-state.json` — meaning even
after a shell restart, the profile's setup sticks.

DenshoService has its own auto-save via property bindings to
`densho.state` file, so explicit save isn't needed for that block.

---

## Files changed (2)

```
zen-shell-v5/ThemeService.qml   — saveAsCustomTheme expanded
                                   applyJson extended
                                   schemaVersion stamp
zen-shell-v5/ZenVersion.qml     — bumped to hf44
install.sh                       — banner + changelog
```

Pure additive change. Old profile files load fine. Old code paths
unchanged. No regressions to color handling, smart-contrast pass,
or anywhere else.

---

## How to install

```bash
tar -xzf zen-shell-v7_0_0-beta_1-hf44-theme-profile-full-state.tgz
cd zen-shell-v7.0.0-beta.1-hf44
./install.sh
```

---

## How to verify

### Re-save your existing custom profile

The first save **after** installing hf44 will write the new full-state
JSON.

1. Open Settings → Appearance → Themes
2. Tweak your bar opacity, radius, brush separators, etc.
3. Save profile as something like "paultheme-v2" (or overwrite
   existing "paultheme")
4. Inspect the saved file:

```bash
cat ~/.config/hypr-control-center/themes/custom/paultheme-v2.json
```

You should see the new `schemaVersion`, `theme`, and `densho` blocks
containing all your tweaks.

### Verify full restore on reload

1. Switch to a different theme (e.g. tokyo-night)
2. Switch BACK to paultheme-v2
3. Bar opacity / radius / brush separators / style mode should ALL
   come back exactly as saved

### Verify old profiles still work

If you have old `.json` profiles from pre-hf44:

1. Switch to that old profile
2. Colors should restore (as before)
3. Your CURRENT bar/Densho settings should stay untouched
4. To migrate the old profile to the new format: re-save it with
   the same name after applying it — it'll be written in v2 format

---

## Wala tayong babawasan

All previous fixes preserved:

- ✅ hf43 Quick Notes panel clipping + rounded toggle pills
- ✅ hf42 modules visible in panel + usage docs
- ✅ hf41 collapsible Settings search + Input tab custom sliders
- ✅ hf40 Quick Notes keybinds + sticky notes
- ✅ hf39 5 productivity features
- ✅ hf38 string colors + annotation transparency
- ✅ hf37 event-driven hot corners
- ✅ hf36 refresh rate toggle

Pure data-completeness hotfix. Save what the user expects to be
saved. 🍃
