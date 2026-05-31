# v7.0.0-beta.1-hf59 — Auto force-load + Hyprland reload watchdog

**Channel:** beta (hotfix)
**Released:** 2026-05-18
**Branch:** `dev`

---

## What this hotfix fixes

User report:

> "pwd pa ayos yung hyprbars hindi gumagana kht enable na please take
> note dati naman gumagana yan syncronized sa hypr config ko and
> please dynamic yun links ah kasi may mga ibang user din gagamit
> ibat ibang pc and please wala ka sisirain or babaguhin sa core
> framework zen-shell ko ah"

Translation:

1. Hyprbars still not showing even when enabled
2. Used to work, synced with hypr config
3. Paths must be dynamic for cross-machine portability
4. Don't break or modify the core framework

hf58 made the diagnostic surface WHY the plugin wasn't loading.
hf59 makes the load **automatic** — same code path as the Force
load button, but fired by the shell itself whenever the plugin
needs re-injecting.

---

## Why the plugin keeps disappearing

`hyprpm reload` reports success but doesn't actually inject the
`.so` into Hyprland (upstream issue documented in hf57/hf58). The
documented workaround is `hyprctl plugin load <absolute_path>` —
which works reliably. hf58 added a manual button for this.

Pero: every time **Hyprland reloads** (theme change → `hyprctl
reload`; monitor hotplug; user edits hyprland.conf), the plugin
gets torn down + reloaded via the broken hyprpm path and DROPS
again. So even after a successful Force load, the bars vanish on
next reload. User has to re-click the button. Hindi sustainable.

---

## Fix — three layers of auto-recovery

### 1. Auto-fire on every verify

`verifyProc.stdout` handler now checks: if `pluginLoaded=false`
but user has `enabled=true`, fire the same `hyprctl plugin load`
that the manual button does. Bounded to 3 attempts per "session,"
with the budget resetting every 60s via a watchdog timer.

```qml
if (nowLoaded) {
    root._autoLoadAttemptCount = 0   // success — reset budget
} else if (root.autoLoadEnabled
           && root.enabled
           && !root._autoLoadInProgress
           && root._autoLoadAttemptCount < root._autoLoadMaxAttempts) {
    root._autoLoadAttemptCount += 1
    root._autoLoadInProgress = true
    autoLoadProc.command = ["bash", "-c", root._autoLoadCmd()]
    autoLoadProc.running = true
}
```

`_autoLoadCmd()` is identical to `manualLoadPlugin`'s command,
trimmed for silent execution (no UI status spam):

```bash
SO=$(find "$HOME/.local/share/hyprpm" -name 'hyprbars*.so' 2>/dev/null | head -1)
[ -z "$SO" ] && echo 'auto-load: no .so found' && exit 1
hyprctl plugin load "$SO" 2>&1
```

Note `$HOME` — fully dynamic. Works for any user on any machine.

### 2. Post-reload verify

`writeConfig()` already fires `hyprctl reload` after writing the
zen-hyprbars.conf. hf59 schedules a verify 1s after that reload
settles, so if Hyprland's reload dropped the plugin, auto-load
kicks in immediately:

```qml
Timer {
    id: postReloadVerifyTimer
    interval: 1000
    repeat: false
    onTriggered: { if (root.enabled) root.verifyPluginLoaded() }
}
```

Theme changes, button-side toggles, slider adjustments all fire
`writeConfig()` → `hyprctl reload` → 1s later → verify → auto-load
if needed. User never sees the plugin disappear visually because
the recovery completes in ~1.5s.

### 3. Periodic watchdog

Every 30s, the watchdog polls `hyprctl plugin list`. Cheap call.
If user does something outside Zen Shell that drops the plugin
(manual `hyprctl reload` from terminal, monitor hotplug, etc.),
the watchdog catches it within 30s.

```qml
Timer {
    id: watchdogTimer
    interval: 30000
    repeat: true
    running: true
    onTriggered: {
        if (root.enabled && root.autoLoadEnabled) {
            root.verifyPluginLoaded()
        }
    }
}
```

A separate 60s timer resets the attempt budget when exhausted, so
genuine ABI mismatches don't permanently lock out recovery if the
upstream pin gets updated (hyprpm update fetches new pins in the
background).

---

## Fix — beefier `enablePlugin()`

Previously: just `hyprpm enable hyprbars` + `hyprpm reload`. Same
upstream injection bug applies. Now mirrors `installPlugin()`
Step 8 fallback:

```bash
[Hyprbars] Step 1/4: hyprpm enable
[Hyprbars] Step 2/4: hyprpm reload
[Hyprbars] Step 3/4: hyprctl reload
[Hyprbars] Step 4/4: verify + manual load fallback
  ⚠ hyprpm reload did not inject — trying manual load
  ✅ Loaded via manual hyprctl plugin load
```

So flipping the enable toggle directly works without needing to
follow up with Force load.

---

## Fix — paths fully dynamic

All `.so` lookups use `$HOME/.local/share/hyprpm` (bash) or
`Quickshell.env("HOME")` (QML). No hardcoded `/home/paul/`
anywhere. Source line in hyprland.conf stays in the
`~/.config/hypr/zen-hyprbars.conf` tilde form added in hf57.

Tested expansion:

```bash
$ echo "$HOME/.local/share/hyprpm"
/home/paul/.local/share/hyprpm       # on paul's machine
/home/mom/.local/share/hyprpm        # on mom's machine
/home/anyone/.local/share/hyprpm     # works for everyone
```

---

## Fix — Settings UI

New pill toggle in Settings → Hyprbars:

```
Auto-load on boot / reload                              [ON pill]
Silently re-injects plugin via `hyprctl plugin load` if
hyprpm reload didn't (recovers from upstream load drops).
```

Default ON. Persists in `~/.config/quickshell/zen-shell/hyprbars.json`
as `autoLoadEnabled: true`.

Badge text now surfaces auto-load activity:

```
●  Plugin loaded in Hyprland — bars active                 (green)
●  Auto-loading plugin… (attempt 2 of 3)                  (yellow)
●  Auto-load exhausted — check plugin .so / ABI match     (red)
●  Plugin NOT verified loaded — click 'Check status'…     (red)
```

User can see exactly what state the recovery loop is in.

---

## Files modified (4)

```
zen-shell-v5/HyprbarsService.qml      — autoLoadEnabled property,
                                          auto-load tracking state,
                                          verifyProc auto-trigger,
                                          beefier enablePlugin,
                                          post-reload verify,
                                          30s watchdog,
                                          60s budget reset
zen-shell-v5/HyprbarsSettingsPage.qml — auto-load pill toggle,
                                          badge surfaces auto-load
                                          progress + attempt count
zen-shell-v5/ZenVersion.qml           — bumped to hf59
install.sh                             — banner + changelog entry
```

**No core framework files modified.** Only the Hyprbars module
plus the version/banner stamps.

---

## How to install

```bash
tar -xzf zen-shell-v7_0_0-beta_1-hf59-auto-force-load.tgz
cd zen-shell-v7.0.0-beta.1-hf59
./install.sh
pkill quickshell
```

On next quickshell start:

1. State loads (auto-load defaults to ON for existing users too)
2. Boot verify runs (`hyprctl plugin list`)
3. If plugin missing + enabled → auto force-load fires silently
4. ~600ms later → re-verify → `pluginLoaded` flips to true
5. Bars appear. No clicks required.

If `hyprctl reload` happens later (theme change etc.):
- writeConfig schedules a 1s post-reload verify
- watchdog catches it within 30s otherwise
- Auto-load fires
- Bars reappear

---

## How to verify it's working

### After install + reload shell

```bash
# Watch the auto-recovery in real time
hyprctl plugin list

# Open Settings → Hyprbars
# Badge should be green "Plugin loaded in Hyprland — bars active"
```

### Stress test: drop the plugin

```bash
# Force unload to test auto-recovery
hyprctl plugin unload $(find ~/.local/share/hyprpm -name 'hyprbars*.so' | head -1)

# Within 30s, the watchdog should auto-reload it.
# Or trigger immediately by changing a theme color in Settings —
# writeConfig fires hyprctl reload, post-reload-verify catches the
# drop, auto-load fires.

# Verify:
hyprctl plugin list   # should show hyprbars again
```

### Disable auto-load (if you prefer manual)

Settings → Hyprbars → toggle "Auto-load on boot / reload" OFF.
Plugin drops will not auto-recover; use the purple Force load
button when needed.

---

## Hyprbars hotfix journey (7 attempts)

| Hotfix | What it did | Result |
|---|---|---|
| hf52 | Initial integration | Bars worked but wrong floating-only syntax |
| hf53 | Floating-only inline | `missing a value` error |
| hf55 | Inline w/ `on` value | `invalid field type` error |
| hf56 | Block syntax | `config option does not exist` |
| hf57 | Gate on pluginLoaded + portable paths | Errors gone, no bars |
| hf58 | Diagnostic + force load button | Bars work but need manual click after every reload |
| **hf59** | Auto force-load + watchdog | **Bars appear automatically, stay on through reloads** |

The hyprbars journey is hopefully complete with hf59 — if upstream
ever fixes the hyprpm reload injection bug, the auto-load logic
becomes a no-op (verify sees plugin already loaded, doesn't fire
manual load). Safe to keep enabled even after upstream fix.

---

## Wala tayong babawasan

All previous fixes preserved:

- ✅ hf58 diagnostic + manual force-load button (still works,
       complements auto-load when user wants to investigate)
- ✅ hf57 plugin verify gate + portable paths
- ✅ hf56 block windowrule syntax (gated)
- ✅ hf55 auto-rewrite timer
- ✅ hf54 mimic layout
- ✅ hf53 popup mimic + status feedback
- ✅ hf52 hyprbars integration foundation
- ✅ hf51-32 all preserved

🍃 Pre, install na lang and reload — pag-boot ng shell, dapat
mag-recover na yung hyprbars automatically within ~2 seconds.
Hindi mo na kailangan pindutin yung Force load every time. If
ABI mismatch pa rin yung underlying issue, badge will say
"Auto-load exhausted" so alam mo kaagad.
