# Zen Shell v6.16.3.4.5 — Universal dropdown scroll + PowerBadge A+B

**Release date:** 2026-04-24
**Branch:** `beta-v12.6.16.3.4.5`
**Base:** v6.16.3.4.4
**Status:** Beta — UX consistency pass + long-standing PowerBadge visibility fix

---

## TL;DR

Two tracks:

```
┌─────────────────────────────────────────────────────────────────┐
│  TRACK 1 · ZenComboBox — every dropdown now scrolls             │
│            1 new reusable component · 30 ComboBox migrations    │
│            across 9 Settings pages, all with capped popup       │
│            height + internal scroll indicator                   │
├─────────────────────────────────────────────────────────────────┤
│  TRACK 2 · PowerBadge A+B fix (ongoing since v6.16.3.4)         │
│            A · install.sh one-shot migration — auto-adds        │
│                "powerbadge" to existing bar-layout.json         │
│            B · Bar Modules Settings page — live toggle with     │
│                instant reload (no shell restart needed)         │
└─────────────────────────────────────────────────────────────────┘
```

**Wala tayong binawasan.** All prior fixes carried byte-identical.

---

## Track 1 — every dropdown scrolls now

### Problem

Paul reported (2026-04-24) that the Themes dropdown had the same cutoff
issue as Animations in 3.4.3/3.4.4: with 16+ builtin + custom themes
the popup extended past the Settings window edge, making the bottom
half of the list unclickable.

Rather than patch Themes individually, this was the moment to audit
every dropdown in the shell. Count:

| Page                     | Dropdowns |
|--------------------------|-----------|
| WidgetsPage              | 6         |
| BatterySettingsPage      | 5         |
| BarModulesPage           | 4         |
| DisplaysPage             | 4         |
| GeneralPage              | 4         |
| PanelPage                | 4         |
| WallpaperPage            | 2         |
| AnimationsPage           | 1         |
| ThemesPage               | 1         |
| **Total**                | **31**    |

Every single one of these uses stock `ComboBox { }` with the default
popup that grows to fit the full model — meaning any list that's
taller than the window puts its bottom items off-screen. Latent bug
in 30 places.

### Solution — reusable component

New file: **`zen-shell-v5/ZenComboBox.qml`** — drop-in replacement
for `ComboBox` that bakes in:

- Popup capped at 280px tall (~8 rows at 36px each), overridable per-
  instance via `maxPopupHeight` property
- Internal ListView with always-visible `ScrollIndicator`
- Auto-scrolls to centre `currentIndex` on popup open so long lists
  are navigable in both directions without hunting
- Matches `ThemeService` colour language (bg1 fill, 15% fg border)
- 6px corner radius (design system)

Inherits from ComboBox so **every standard API survives**: `model`,
`currentIndex`, `currentText`, `onActivated`, `textRole`,
`displayText`, `editable`, etc. are all untouched.

### Migration — drop-in rename

Because `ZenComboBox` IS a ComboBox, migration across all 9 pages
was literally `sed 's/\bComboBox {/ZenComboBox {/g'` — 30 files
touched, zero API changes required at call sites.

The 3.4.4 AnimationsPage had an inline Popup override we've now
retired — it's using the shared component instead, so there's one
place to fix any future dropdown issue.

### Regression risk

- `ZenComboBox` inherits `ComboBox` so all existing binding behaviour
  works identically.
- The `popup` override only affects visual presentation — no logic,
  no model changes, no activation-signal changes.
- QML syntax identical: `ZenComboBox { model: ...; onActivated: ... }`
  behaves exactly like the old `ComboBox` version.

### Per-instance customisation

If a specific dropdown warrants a different cap (e.g. a very short
picker that shouldn't scroll, or a huge list that should use more
screen), set `maxPopupHeight`:

```qml
ZenComboBox {
    maxPopupHeight: 400    // taller popup for huge lists
    model: [...]
}
```

Default (280) works for every current call site.

---

## Track 2 — PowerBadge A+B permanent fix

### Root cause recap (from 3.4.4 diagnosis)

`Theme.qml`'s default `barLayout` includes `"powerbadge"` in the
right row, but `layoutLoader` reads `~/.local/share/quickshell/
zen-shell/bar-layout.json` at startup and OVERWRITES that default.
Users who saved their layout BEFORE v6.16.3.4 (when PowerBadge was
introduced) had JSON files that silently dropped the new module.

### Plan A — install.sh one-shot migration

Added to `install.sh` between First-run tasks and QML integrity check:

```bash
MIG_DIR="$HOME/.config/quickshell/zen-shell/.migrations"
mkdir -p "$MIG_DIR"

# Migration: powerbadge bar module (introduced v6.16.3.4)
if [ ! -f "$MIG_DIR/powerbadge-v6.16.3.4" ]; then
    if [ -x "$BIN_DIR/zen-bar-add-powerbadge.sh" ]; then
        "$BIN_DIR/zen-bar-add-powerbadge.sh"
        touch "$MIG_DIR/powerbadge-v6.16.3.4"
    fi
fi
```

Properties:
- **Idempotent.** Marker file ensures the migration runs exactly once
  per user, even across re-installs. If the user later toggles
  PowerBadge OFF via Settings (Track 2B), the marker prevents
  future installs from silently re-adding it.
- **Non-destructive.** `zen-bar-add-powerbadge.sh` already backs up
  the original `bar-layout.json` before modifying (see script's
  existing `.bak.<TS>` behaviour).
- **Pattern for future migrations.** Adding a new bar module later
  follows the same shape: drop another guarded block with its own
  marker filename.

### Plan B — Bar Modules Settings page toggle

Added new section to `BarModulesPage.qml`:

```
┌─ Optional Bar Modules ──────────────────────────────────────┐
│  ⚡  Power Profile badge                       [ ●━━━ ]      │
│     Small pill showing current power profile + GPU mode.    │
│     Hides itself on systems without powerprofilesctl or     │
│     multi-GPU.                                              │
├──────────────────────────────────────────────────────────────┤
│  ↻  Reload shell after change           [ Restart shell ]   │
│     The bar re-renders instantly after toggle — but if the  │
│     badge doesn't appear, click here to force a restart.    │
└──────────────────────────────────────────────────────────────┘
```

Wiring:
1. `HMSwitch.checked` binds live to `Theme.barLayout.right.indexOf("powerbadge") >= 0`
2. `onToggled` runs the helper script with `add` or `--remove` args
3. `Process.onExited` calls `Theme.reloadBarLayout()` which reloads
   the FileView → Theme.barLayout reassigns → Bar.qml's Repeater
   rebuilds its model → PowerBadge appears/disappears on the bar
   instantly

**No shell restart required** for the toggle to take effect. The
"Restart shell" button is there as a fallback if the live reload
doesn't propagate for some reason.

### New Theme.qml helper

```qml
function reloadBarLayout() {
    layoutLoader.reload()
}
```

Exposed so any future surface that mutates `bar-layout.json` can
trigger the same reload. Avoided `watchChanges: true` on the FileView
because we don't want the bar re-rendering on every unrelated JSON
write — explicit calls are cleaner.

---

## Files in this drop

### NEW

```
zen-shell-v5/ZenComboBox.qml         ← Reusable scrollable ComboBox
CHANGELOG-v6.16.3.4.5.md             ← this file
```

### UPDATED

```
zen-shell-v5/ZenVersion.qml          ← bump to v6.16.3.4.5
zen-shell-v5/Theme.qml               ← +reloadBarLayout() function
zen-shell-v5/AnimationsPage.qml      ← ComboBox → ZenComboBox, removed inline popup
zen-shell-v5/BarModulesPage.qml      ← +Optional Bar Modules section, 4 ComboBox→ZenComboBox
zen-shell-v5/BatterySettingsPage.qml ← 5 ComboBox → ZenComboBox
zen-shell-v5/DisplaysPage.qml        ← 4 ComboBox → ZenComboBox
zen-shell-v5/GeneralPage.qml         ← 4 ComboBox → ZenComboBox
zen-shell-v5/PanelPage.qml           ← 4 ComboBox → ZenComboBox
zen-shell-v5/ThemesPage.qml          ← 1 ComboBox → ZenComboBox (Paul's reported case)
zen-shell-v5/WallpaperPage.qml       ← 2 ComboBox → ZenComboBox
zen-shell-v5/WidgetsPage.qml         ← 6 ComboBox → ZenComboBox
install.sh                            ← +PowerBadge migration block + banner bump
```

### CARRIED OVER

Everything from 3.4.4 byte-identical.

---

## Install / verify

```bash
tar -xzf zen-shell-v6.16.3.4.5.tar.gz
cd zen-shell-v6.16.3.4.5
./install.sh
~/.local/bin/zs-restart.sh
```

### Verify Track 1 — scrollable dropdowns everywhere

1. Settings → Themes → open the theme picker — popup capped, scrolls
2. Settings → Animations → preset picker — still works (same ZenComboBox)
3. Settings → Widgets → any of the 6 dropdowns — all scrollable now
4. Settings → Battery & Power → Brightness device picker (if multiple
   backlights detected) — uses the same component
5. Every other Settings page's dropdowns — ZenComboBox under the hood

Keyboard: ↑/↓ scroll smoothly, current selection stays centred.

### Verify Track 2A — PowerBadge auto-migration

```bash
# Check that the migration marker was created
ls -la ~/.config/quickshell/zen-shell/.migrations/
# Expected: powerbadge-v6.16.3.4

# Check the bar layout now includes powerbadge
jq '.layout.right' ~/.local/share/quickshell/zen-shell/bar-layout.json
# Expected: ["music","sysrow","tray","battery","powerbadge","notifications","clock"]
```

The badge should be visible on the bar immediately after restart.
Click it to open Control Panel; right-click to cycle power profile.

### Verify Track 2B — Settings toggle

1. Settings → Bar Modules → scroll to "Optional Bar Modules" section
2. Toggle "Power Profile badge" OFF → badge disappears from bar instantly
3. Toggle back ON → badge reappears
4. Inspect JSON — `jq '.layout.right' ~/.local/share/quickshell/zen-shell/bar-layout.json`
   should update to match each toggle

If the toggle doesn't reflect immediately, click "Restart shell" —
it's a fallback that forces a full shell restart via `zs-restart.sh`.

---

## What's NOT in v6.16.3.4.5

- **Option C (runtime auto-heal) rejected** per earlier discussion —
  silently modifying user's saved config on every startup is more
  aggressive than users expect. The A+B combo gives discoverability
  (the Settings toggle) AND invisibility-fix (the one-shot migration)
  without the runtime footgun.
- **Other bar modules still don't have toggles.** Clock, Workspaces,
  Taskbar, Weather etc. are still hand-edit-only via `bar-layout.json`.
  Pattern is now in place — adding toggles for them is straightforward
  future work using the same HMSwitch + Process + Theme.reloadBarLayout()
  template from this drop.
- **Migration system for future modules.** The install.sh block is
  one-off-per-module today. A future cleanup could generalise it into
  a `migrations/` directory of scripts that each ship with their own
  marker filename. Out of scope for 3.4.5.

---

## Next up

Queued post-3.4.5:

- **v6.16.3.5** — Start Menu logo image picker (paused since 3.4.2)
- **v6.16.3.6** — Clock hover popup parity with CPU/Memory hover
- **v6.16.3.7** — Universal widget auto-resize (DPI / scale aware)
- **v6.16.3.8** — Idle / lid / sleep UX
- **v6.16.4** — Global Hyprland configreloaded IPC listener

Phase 4 (Hyprland dark mode + hyprbars + auto-clean memory + window
tile/float policy) still queued after the 3.x series wraps.
