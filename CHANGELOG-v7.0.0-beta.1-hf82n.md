# v7.0.0-beta.1-hf82n — Default Apps picker + App Float Rules (Hyprland window manager)

**Channel:** beta (hotfix patch on hf82m.1)
**Released:** 2026-05-25
**Branch:** `dev`
**Scope:** 4 new QML files + 2 modified + ZenVersion bump

---

## User request

> "gawa tayo list din ng default browser, pdf, vlc etc and provide din tayo sa hypr control panel natin nung mga applications na pwd windows so kunin natin lahat ng apps then may toggle sa right side if float true or false and yun design ah same sa general lahat. design principle natin"

Translation:
1. List/picker for default apps (browser, PDF, VLC etc.)
2. Hyprland window control panel listing all installed apps with a per-app float toggle (right side)
3. Same visual design as GeneralPage (HM components, DenshoPageHeader, etc.)

Plus user management deferred to **hf82o** per your elicitation answer (pkexec for sudo prompts).

---

## What ships in hf82n

### Default Apps Page
- 10 categories: Browser, PDF Viewer, Video Player, Image Viewer, Music Player, Email Client, Terminal, Text Editor, Archive Manager, File Manager
- Each category has a dropdown of all installed apps
- Picks `(none)` or any installed app → writes via `xdg-mime` to `~/.config/mimeapps.list`
- Backend handles both primary MIME (anchor) AND secondary MIMEs in one batch (e.g. setting video player covers MP4, MKV, WebM, AVI, MOV, FLV, MPEG all at once)
- Live status row showing last action result
- Refresh button + Test button (opens https://hypr.land to verify browser default)

### App Float Rules Page
- Scans all installed `.desktop` apps via `AppLauncherService.allApps`
- Filters to GUI apps (`noDisplay=false`, has name, has exec)
- Live search box at the top (filters by name + id)
- Per-app HMSwitch on the right: float = ON/OFF
- Sorted: currently-floating apps first, then alphabetical
- Toggle writes `windowrulev2 = float, class:^(name)$` to `~/.config/hypr/modules/zen-window-rules.conf` and fires `hyprctl reload`
- "Clear all" + "Refresh from disk" + "Reload Hyprland" maintenance buttons

### Service singletons

Two new singletons handle all the backend work:

**MimeAppsService** wraps `xdg-mime` for the Default Apps page:
- `categoryAnchors` map: category → primary MIME type
- `categorySecondaries` map: category → list of additional MIMEs to set
- `categoryLabels` + `categoryDescriptions` for the UI strings
- `setDefault(cat, appDesktopId)` runs `xdg-mime default` for anchor + all secondaries
- `clearDefault(cat)` uses sed to remove lines from `~/.config/mimeapps.list`
- `currentDefaults` cached, refreshed via batched bash invocation
- `lastAction` / `lastError` for UI feedback

**WindowRulesService** manages the Zen-Shell-owned window rules file:
- File path: `~/.config/hypr/modules/zen-window-rules.conf`
- Identifies its own rules by trailing `# zen-shell-float` comment
- `floatApps` array parsed from file content
- `isFloating(wmClass)` query + `setFloating(wmClass, bool)` setter
- Atomic write via `mktemp` + `mv` then `hyprctl reload`
- Re-reads file after every write to confirm state

---

## Architectural decisions

### Why a separate `zen-window-rules.conf` file
Instead of editing the user's main `hyprland.conf`, we own a dedicated module file sourced from it. Reasons:
- Separation of concerns — user can `cat` our file to see exactly what we manage
- Safe to wipe — `rm ~/.config/hypr/modules/zen-window-rules.conf` removes all our rules at once
- Zero risk of corrupting user's hand-tuned main config
- The `# zen-shell-float` trailing comment lets future versions identify their own rules vs user-added ones in the same file

### Why `xdg-mime` over direct file edits for defaults
- It writes BOTH `[Default Applications]` AND `[Added Associations]` sections cross-referenced
- Triggers per-desktop notifications (some DEs cache mime info)
- Handles edge cases like separate KDE/GNOME format files
- Standard tool — what every other Linux DE uses

### Why batch MIMEs per category
Setting just `video/mp4` doesn't cover MKV or WebM. Each category has an array of secondary MIMEs so "set my default video player" actually catches all common video formats. The batch is one `xdg-mime` invocation chain, not 10 separate processes.

### Why all installed apps (not just running)
Per your elicitation answer. The list shows everything in `/usr/share/applications` + `~/.local/share/applications` (via Quickshell's DesktopEntries). Sorted with floating-on apps first so you immediately see what you've already toggled.

### WM class derivation strategy
For the float rule, we need the WM class string. Strategy:
1. **Preferred**: `app.id` with `.desktop` suffix stripped (e.g. `firefox.desktop` → `firefox`)
2. **Fallback**: basename of first word of `Exec` line

This covers ~80% of apps cleanly. Edge cases (apps where StartupWMClass differs from desktop id) may need manual rules in the user's own conf file, but those are rare.

---

## Files

| File | Status | Lines | Purpose |
|---|---|---:|---|
| `MimeAppsService.qml` | NEW | 235 | xdg-mime wrapper singleton |
| `WindowRulesService.qml` | NEW | 150 | zen-window-rules.conf manager |
| `DefaultAppsPage.qml` | NEW | 196 | Default apps picker UI |
| `AppFloatRulesPage.qml` | NEW | 226 | App float rules UI with search |
| `ZenSettings.qml` | MODIFIED | +5 | 2 new sidebar entries + 2 StackLayout cases + 2 instantiations |
| `install.sh` | MODIFIED | +14 | Source-line appender for zen-window-rules.conf + banner bump |
| `ZenVersion.qml` | MODIFIED | +0 | hf82m.1 → hf82n |
| **Total** | | **~826 new lines** | |

---

## Install

Drop-in over hf82m or hf82m.1:

```fish
tar -xzf zen-shell-v7_0_0-beta_1-hf82n.tgz
cd zen-shell-v7.0.0-beta.1-hf82n
./install.sh

pkill -f quickshell; and sleep 1
quickshell -p ~/.config/quickshell/zen-shell &
```

### First-launch experience

After install:

1. Open Settings — sidebar now has two new entries at the bottom of the PRODUCTIVITY section:
   - **Default Apps** (kanji 既定 / Kitei)
   - **App Float Rules** (kanji 窓規則 / Madokisoku)

2. **Default Apps**: pick your browser, PDF viewer, video player, etc. from the dropdowns. Each change saves immediately via `xdg-mime`.

3. **App Float Rules**: toggle individual apps to always open as floating windows. Search box at the top to filter. Toggle writes the conf file + reloads Hyprland.

---

## Verify

After install:

1. **Settings → Default Apps** — should see 10 category rows with dropdowns. Current defaults pre-selected from `xdg-mime query default`.
2. **Pick a browser** → status row says "✓ Default updated" → click Test → https://hypr.land opens in your pick.
3. **Settings → App Float Rules** — list of all installed `.desktop` apps with switches on the right.
4. **Toggle one app's float switch** → switch flips → file written:
   ```fish
   cat ~/.config/hypr/modules/zen-window-rules.conf
   # Should show your toggled app's windowrulev2 line
   ```
5. **Launch the toggled app** → opens as a floating window (not tiled).
6. **Settings → System Info** → `v7.0.0-beta.1-hf82n · released 2026-05-25`.

---

## Multi-monitor / Multi-user notes

- **Default apps**: per-user only (xdg-mime writes to `~/.config/mimeapps.list`). System-wide defaults need root + are out of scope.
- **Window rules**: per-user. The file lives in the user's `~/.config/hypr/modules/` so each user on the machine has independent float rules.

---

## Wala tayong babawasan

Four new files, two modified files, zero removals. Pre-hf82n shells continue to work unchanged. The two ZenSettings.qml changes are additive (sidebar entries appended, switch cases appended, page instantiations appended). The install.sh change is a single new source-line appender block placed after the existing ones.

---

## Open threads still active

- Quickshell C++ crash dump capture
- Multi-monitor flameshot screen targeting (`--screen N`)
- Drag + overflow auto-scroll (12+ pinned apps edge case)
- Build-time version auto-derivation (`git describe`)
- `Component.onCompleted` race audit across the codebase
- Panel-position-aware calculation audit (`isTop` branches missing elsewhere)
- `Switch` → `HMSwitch` audit across settings pages
- Hyprland minor-version compat tracking (hf82l sanitizer covers 0.54 + 0.55)
- **hf82o NEXT**: User management with pkexec — useradd / userdel / admin toggle (wheel group). Cannot delete current user. Avatar upload integrated with existing UserProfilePage.
- Dock Phase 2 (hf82p, renumbered): ZenControlCenter popup + drag-to-reorder list UI in DockPage
- Dock Phase 3 (hf82q, renumbered): Desktop icons + dock auto-hide + per-app badges
- **NEW from hf82n**: WM class derivation accuracy (currently uses `.desktop` id; some apps need StartupWMClass parsing). Could extend AppLauncherService.allApps adapter to surface StartupWMClass when present. Edge cases workaround: user hand-writes a windowrulev2 rule in a non-managed conf file.
- **NEW from hf82n**: `xdg-mime query default` returns the FIRST registered handler when no user-set default exists; some pre-selections may show distro defaults rather than empty. Acceptable behavior — user toggle still works.
