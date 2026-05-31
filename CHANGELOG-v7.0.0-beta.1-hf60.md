# v7.0.0-beta.1-hf60 — Surface load error + mimic gating

**Channel:** beta (hotfix)
**Released:** 2026-05-18
**Branch:** `dev`

---

## What this hotfix fixes

User report (with screenshot showing "Auto-load exhausted" badge):

> "naka window float ako try ko sa brave wala naman yun hyprbars
> jusko amd uim jupr control panel ko bakit ganito itsura dapat yun
> totoong hyprbars hindi mimic"

Two distinct problems:

1. **"Auto-load exhausted"** badge from hf59 was a dead-end — said
   "check plugin .so / ABI match" but didn't say which one or show
   the actual error. User had no way to know if .so was missing or
   ABI was off without running `Check status` manually.

2. **Mimic bars on Settings/Control Panel** even when the real
   hyprbars plugin can't load — confusing because real Hyprland
   windows had no bars, but Zen Shell popups did. Looked like fake
   bars that the user (correctly) found suspicious.

---

## Architectural reality check first

The real hyprbars plugin **physically cannot paint** on Zen Shell's
popup surfaces (ControlPanel, Settings panel, etc). Those are
layer-shell surfaces — Hyprland-side, plugins only register window
effects on XDG/X11 toplevels. Layer-shell surfaces bypass the plugin
hook path entirely.

So on Zen popups, the choice is:
- Show an in-shell mimic that visually matches hyprbars colors/style
- Show nothing

hf53 chose "show mimic always when enabled." hf60 changes that to
"show mimic only when the real plugin is loaded" by default — so the
UX stays consistent (bars everywhere on a working setup, bars
nowhere on a broken setup). User can opt back into the always-show
behavior via a new toggle.

---

## Fix — surface the actual load error

### Problem

`autoLoadProc` ran `hyprctl plugin load <so>` and just incremented
the attempt counter on failure. Stderr went to `console.warn` only,
invisible unless tailing journalctl.

### Fix

New service properties:

```qml
property string lastLoadError: ""  // captured from hyprctl plugin load
property string soPath: ""         // detected .so path or ""
property bool soExists: false      // convenience flag
```

`_autoLoadCmd()` now emits structured tokens the QML stdout handler
parses without regex:

```bash
SO=/home/paul/.local/share/hyprpm/.../hyprbars.so
LOAD_OUT=$(hyprctl plugin load "$SO" 2>&1)
if hyprctl plugin list 2>/dev/null | grep -qi hyprbars; then
  echo "STATUS=ok"
else
  echo "STATUS=load-failed"
  echo "ERR=$(echo "$LOAD_OUT" | tr '\n' ' | ' | head -c 240)"
fi
```

The stdout handler matches `SO=`, `STATUS=`, `ERR=` line prefixes
and routes the values into the service properties. No regex on
free-form text. Path with spaces, special chars all fine.

Stderr is also captured separately as a belt-and-braces — different
hyprctl versions write to different streams.

### UI

New red-bordered diagnostic card appears under the badge whenever
`enabled && !pluginLoaded && (lastLoadError || soPath || attempts > 0)`:

```
Diagnostic detail
─────────────────────────────────────────────────────
Built .so:  /home/paul/.local/share/hyprpm/.../hyprbars.so
hyprctl plugin load error:  Plugin failed to load: ABI mismatch...
Most common cause: ABI mismatch — your Hyprland version (check
'hyprctl version') doesn't have a matching commit pin for hyprbars
yet. Wait for upstream pin update, or build hyprbars manually
against your Hyprland commit.
```

Or, when build failed entirely:

```
Diagnostic detail
─────────────────────────────────────────────────────
No hyprbars*.so found in ~/.local/share/hyprpm — plugin build
failed. Run in terminal:  hyprpm update -v
```

Only renders when there's something to show. Hidden completely
when plugin is loaded (green badge).

---

## Fix — mimic gating

### Problem

`HyprbarsMimic.qml`:

```qml
visible: HyprbarsService.enabled
```

This rendered the in-shell faux bar on every Zen popup whenever
hyprbars was *configured* on, regardless of whether the real plugin
was actually loaded into Hyprland. Result: Settings panel had a
title bar (mimic), regular Hyprland windows had none. User stares
at the Settings page wondering why it's different — exactly Paul's
"bakit ganito itsura dapat yun totoong hyprbars hindi mimic."

### Fix

```qml
visible: HyprbarsService.enabled
         && (HyprbarsService.pluginLoaded
             || HyprbarsService.showMimicFallback)
```

Default: mimic only shows when real plugin is loaded. Now the UI
state is consistent — if real bars are working, mimic shows on
popups too; if real bars aren't working, no mimic either.

### Opt-in fallback

New service property + Settings toggle:

```qml
property bool showMimicFallback: false
```

Settings UI:

```
Show fallback bars on Zen popups when plugin unavailable    [OFF pill]
Paints an in-shell mimic bar on Control Panel / Settings even
when the real hyprbars plugin can't load. The real plugin
physically can't paint on layer-shell surfaces (Hyprland
architectural limit).
```

Persists in `hyprbars.json` as `showMimicFallback`. Users who
prefer always-on title bars on Zen popups (regardless of plugin
state) can flip this back on.

---

## Files modified (5)

```
zen-shell-v5/HyprbarsService.qml       — lastLoadError + soPath + soExists
                                          properties, restructured
                                          autoLoadProc with stdout token
                                          parser + stderr capture,
                                          showMimicFallback persistence
zen-shell-v5/HyprbarsMimic.qml         — visibility gated on pluginLoaded
                                          (or showMimicFallback override)
zen-shell-v5/HyprbarsSettingsPage.qml  — diagnostic detail card,
                                          mimic-fallback pill toggle
zen-shell-v5/ZenVersion.qml            — bumped to hf60
install.sh                              — banner + changelog entry
```

**No core framework changes.** All hyprbars-scoped.

---

## How to install

```bash
tar -xzf zen-shell-v7_0_0-beta_1-hf60-surface-load-error.tgz
cd zen-shell-v7.0.0-beta.1-hf60
./install.sh
pkill quickshell
```

---

## What you'll see after install

### If plugin loads successfully

Badge: 🟢 "Plugin loaded in Hyprland — bars active"
Bars appear on Hyprland windows, mimic appears on Zen popups.

### If plugin can't load

Badge: 🔴 "Auto-load exhausted — check plugin .so / ABI match"
**+ NEW diagnostic card** showing:
- Whether .so was built (and the path if so)
- The exact error from `hyprctl plugin load`
- A hint about the most likely cause

No mimic bars on Zen popups (consistent — bars nowhere). User now
has actionable information about what to fix.

### Want mimic anyway?

Settings → Hyprbars → toggle "Show fallback bars on Zen popups
when plugin unavailable" ON. Restores legacy hf53 behavior.

---

## Diagnosing your specific case

Pre, after install, your Settings page should now tell you exactly
why auto-load is exhausted. Most likely scenarios:

**Scenario A — `.so` missing entirely**

Diagnostic card shows:
> No hyprbars*.so found in ~/.local/share/hyprpm — plugin build failed.
> Run in terminal: hyprpm update -v

→ The build itself failed. Run `hyprpm update -v` to see the
   compile error. Usually missing devel package or compiler
   incompatibility.

**Scenario B — `.so` exists but `hyprctl plugin load` fails**

Diagnostic card shows:
> Built .so: /home/paul/.local/share/hyprpm/.../hyprbars.so
> hyprctl plugin load error: <actual error message>

→ ABI mismatch — the plugin was built against a different Hyprland
   commit than what's running. Wait for upstream pin update, or
   manually build hyprbars from a matching commit.

**Scenario C — `.so` exists, load reports OK, but plugin not in list**

(Unusual.) Suggests Hyprland accepted the load call but the plugin
self-disabled or crashed on init. Check `hyprctl plugin list` and
the Hyprland log (`journalctl --user -u Hyprland.service` or
`~/.cache/hyprland/hyprland.log`).

---

## Wala tayong babawasan

All previous fixes preserved:

- ✅ hf59 auto force-load + Hyprland reload watchdog
- ✅ hf58 diagnostic + manual force-load button
- ✅ hf57 plugin verify gate + portable paths
- ✅ hf56 block windowrule syntax (gated)
- ✅ hf55 auto-rewrite timer
- ✅ hf54 mimic layout
- ✅ hf53 popup mimic foundation (now gated by default, opt-in fallback)
- ✅ hf52 hyprbars integration
- ✅ hf51-32 all preserved

🍃 Pre, install + reload. Tingnan mo yung Settings → Hyprbars page.
Pag may "Diagnostic detail" red card na lalabas, screenshot mo +
send sa akin — based sa exact error, sasabihin ko exactly anong
gawin (ABI mismatch fix vs build dependency fix vs upstream issue).
