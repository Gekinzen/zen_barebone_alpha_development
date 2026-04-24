# Zen Shell v6.16.4.11 — Custom Themes management in Themes page

**Release date:** 2026-04-24
**Base:** v6.16.4.10
**Severity:** FEATURE — Phase 1 of profile management rework
**Scope rule:** WALA TAYONG BABAWASAN — pure additive, zero existing code changes

---

## Paul's ask

> *"tas make it sure yung mga profile settings and themes kapag
>   custom general pag pili ng mga colors tingin ko mas magand
>   ailipat natin sa themes page na? tas kunting may babago
>   mating mag pproduce ng custom theme page na so default so
>   nasa user if want niya rename yun custom page niya tas once
>   save magiigng json natin iba tas sa general may save profile
>   naman yun profile na yun kabuoan lht ng settings pati
>   naiamtion na ka select kunin pra kapag export and import ng
>   mga kaibigan nila sa same dotfiles matic mag reflect tas pwd
>   din rename pre. gets? and make it sure kht mag restart si
>   user kung anu yun mga save na profile dpat yun padin ah
>   please and wala na tayo babaguhin codes baka may matamaan
>   nanamn iba please"*

Two major features requested:
1. **Custom Themes management** — move color palette saving/naming
   to Themes page, keep custom theme JSONs renameable
2. **Profile Export/Import** — whole-system settings snapshot on
   General page, portable JSON for sharing with dotfile friends

Both must survive shell restart. No existing code should be
modified.

---

## What ships in 4.11 (Phase 1)

**Just the Custom Themes management** on the Themes page.

Phase 2 (Profile Export/Import on General page) ships next drop —
splitting into two phases lets you test each piece without a
giant diff that's hard to debug.

## Why this phase is TINY

I investigated the existing code and found most of the
infrastructure already exists in `ThemeService.qml`:

```
EXISTING (reused, not modified):
  ThemeService.saveAsCustomTheme(customName)     ← writes JSON
  ThemeService.deleteCustomTheme(theme)           ← removes JSON
  ThemeService.availableThemes                    ← lists all
  ThemeService.customDir                          ← storage path
  ThemeService.currentThemePath                   ← active file
```

Only one new function added to ThemeService: `renameCustomTheme()`.
Everything else is NEW UI in ThemesPage that calls the existing
service methods. GeneralPage is completely untouched — the
existing Save-as-profile button there keeps working the same way.

## What "Custom Themes" section does

New section added to the bottom of Themes page (before the footer):

1. **"Save current palette as new theme"** button
   - Opens zenity name prompt
   - Captures the currently-active palette (including any edits
     made via General page)
   - Writes `~/.config/hypr-control-center/themes/custom/<name>.json`
   - Invokes existing `ThemeService.saveAsCustomTheme(name)` — no
     duplicate logic

2. **Per-custom-theme row** with 3 action buttons:
   - **Activate** (shown only for non-active themes) — flips the
     active theme to this one
   - **Rename** — zenity input prompt, rewrites JSON id+name via
     jq, renames file on disk, updates current-theme.json if this
     was the active theme
   - **Delete** (trash icon) — zenity confirmation prompt, then
     removes the JSON

3. **Empty state** — friendly hint if user has no custom themes yet

4. **Filter** — only non-builtin themes shown (builtins can't be
   renamed or deleted; safe by design in existing service code)

## New: renameCustomTheme()

```qml
function renameCustomTheme(theme, newName) {
    if (!theme || theme.is_builtin) { statusMsg = "Cannot rename builtin"; return }
    if (!newName || newName.length === 0) { statusMsg = "Name required"; return }

    const newId = newName.replace(/[^a-zA-Z0-9_-]/g, "-").toLowerCase()
    const newPath = customDir + "/" + newId + ".json"

    // jq rewrites id + name fields, then mv renames the file,
    // and if this is the currently-active theme, re-copies to
    // current-theme.json so the change takes effect immediately.
    renamer.command = ["bash", "-c",
        "jq '.id = \"" + newId + "\" | .name = \"" + newName + "\"' '" + theme.path + "' > ..."
        // (full command in ThemeService.qml)
    ]
    renamer.running = true
}
```

Requires `jq` to be installed (it's in Arch base-devel and in
our recommended deps list). If missing: `paru -S jq`.

---

## Draft-on-edit behavior

Paul asked for "edit creates draft, explicit button commits with
name." The existing General page already does something similar:

1. User edits colors in General → Theme Palette section
2. Colors update live in-memory (ThemeService reactive properties
   drive the UI re-render)
3. `palettedDirty = true` flag activates the blue "Save" button
4. User clicks Save → zenity name prompt → writes JSON via
   `saveAsCustomTheme()`

So the "draft" is effectively the in-memory edit state, and the
"explicit commit with name" is the existing Save button. This
behavior is KEPT AS-IS — we don't touch General page in 4.11.

What's NEW in 4.11: the same `saveAsCustomTheme()` is ALSO
invocable from the Themes page, so users who don't remember
the General page flow have a clear path from Themes page
("Save as…" button).

---

## Why no GeneralPage changes in 4.11

Paul's hard rule: "wala na tayo babaguhin codes baka may matamaan
nanamn iba please." The existing General page has intricate
interactions with ThemeService reactive properties, palettedDirty
state, and the zenity name prompt Process. Modifying it risks
regressing the current working flow.

Phase 2 (next drop) will add a NEW section to GeneralPage (Profile
Manager) at the TOP of the column, leaving the existing palette
editor + save button completely intact below it.

---

## Files changed from 4.10

```
UPDATED (additive only)
  zen-shell-v5/ThemeService.qml     ← added renameCustomTheme() function
                                       + renamer Process handler
                                       (zero other changes)
  zen-shell-v5/ThemesPage.qml        ← added "Custom Themes" HMSection
                                       before PageFooter
                                       (zero other changes)
  zen-shell-v5/ZenVersion.qml        ← bump to v6.16.4.11
  install.sh                          ← banner

UNCHANGED (explicit note)
  zen-shell-v5/GeneralPage.qml       ← UNTOUCHED
                                       Existing palette editor + Save
                                       button still work exactly the
                                       same way. Nothing broken.

NEW
  CHANGELOG-v6.16.4.11.md            ← this file
```

All v6.16.4.10 features carry byte-identical (including the
PopupWindow color picker + live hex typing).

---

## Install + verify

```bash
tar -xzf zen-shell-v6.16.4.11.tar.gz
cd zen-shell-v6.16.4.11
./install.sh
~/.local/bin/zs-restart.sh
```

### Test 1 — save a custom theme from Themes page

1. Settings → General → Theme Palette
2. Edit a couple of colors (e.g., change Background to a custom shade)
3. Settings → Themes (switch pages)
4. Scroll down to the NEW "Custom Themes" section
5. Click **"Save as…"** button → zenity prompt appears
6. Type a name like `my-test-theme` → OK
7. A new row appears listing `my-test-theme` with Activate/Rename/Delete
8. Verify file:
   ```bash
   ls ~/.config/hypr-control-center/themes/custom/
   cat ~/.config/hypr-control-center/themes/custom/my-test-theme.json
   ```

### Test 2 — rename a custom theme

1. In the Custom Themes section, click **Rename** on your theme
2. Zenity input prompt appears pre-filled with current name
3. Change to `renamed-theme` → OK
4. Row updates immediately with new name
5. Verify file moved:
   ```bash
   ls ~/.config/hypr-control-center/themes/custom/
   # my-test-theme.json is gone, renamed-theme.json is there
   ```
6. If this was the active theme, bar/panel colors persist (no
   accidental reset to default)

### Test 3 — activate + delete

1. Click **Activate** on a non-active custom theme → UI colors
   switch immediately
2. Click **Delete** (trash icon) on a custom theme
3. Zenity confirmation asks "Delete '<name>'? This cannot be undone."
4. Click Yes → row disappears, file removed from disk

### Test 4 — restart persistence

1. Save a couple of custom themes with different names
2. Close Settings, reboot (or `~/.local/bin/zs-restart.sh`)
3. Open Settings → Themes → Custom Themes section
4. All your saved themes are still listed ✅

### Test 5 — verify General page UNCHANGED

1. Open Settings → General
2. Scroll to Theme Palette section
3. Color swatches + "Save edits as custom profile" row should
   look exactly the same as in 4.10
4. Edit a color, click Save → same zenity flow as before ✅

---

## Dependencies

- **jq** — required for rename (already in our deps list)
- **zenity** — required for all prompts (already in our deps list)
- **Quickshell** — with PopupWindow support (from 4.10)

If any of these are missing:
```bash
paru -S jq zenity
```

---

## Phase 2 preview (next drop, NOT shipping in 4.11)

What's coming in v6.16.4.12:

**New file:** `UserProfileExportService.qml` singleton
  - Captures full Settings snapshot into portable JSON
  - Saves profiles to `~/.config/zen-shell/profiles/<name>.json`
  - Active profile persisted to `active-profile.state`
  - Includes: theme palette, animations, panel, bar layout,
    widgets, wallpaper basename

**New component:** `ProfileManagerSection.qml`
  - Added to the TOP of GeneralPage (above existing palette editor)
  - "Save current profile" / "Import profile" / "Export profile"
  - Per-profile rename/delete/activate buttons
  - Existing GeneralPage content kept UNCHANGED below

**Architecture:**
```
~/.config/zen-shell/
├── themes/custom/              ← existing (custom themes)
│   ├── my-nord.json
│   └── paul-dark.json
│
└── profiles/                   ← NEW in Phase 2
    ├── active-profile.state    ← name of loaded profile
    ├── default.json
    ├── gaming-setup.json
    └── work-minimal.json
```

Once Phase 2 ships and you test it for a few days, we promote
4.1→4.X of this cascade as the new stable baseline.

---

## Running tally

```
v6.16.4.1 — LAST STABLE ON MAIN
v6.16.4.2 → v6.16.4.11 — ALL ALPHA (11 iterations)
  4.10 — ColorPicker PopupWindow rewrite + live hex typing
  4.11 — Custom Themes management on Themes page ← YOU'RE HERE
  4.12 — Profile Export/Import on General page (next session)
```
