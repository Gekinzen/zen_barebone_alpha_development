# v7.0.0-beta.1-hf57 — Path portability + plugin verification gate

**Channel:** beta (hotfix)
**Released:** 2026-05-17
**Branch:** `dev`

---

## What this hotfix fixes

User report (with screenshot + uploaded config files):

> "pre .54 hyprland ko. please take note yun mga path dito diba home/
> tas name dapat kapag install natin automatically dynamic yan kasi
> iba iba pc user name yan"

```
Config error in file /home/paul/.config/hypr/zen-hyprbars.conf at line 33:
  config option <windowrule:hyprbars:no_bar> does not exist.
Config error in file /home/paul/.config/hypr/hyprland.conf at line 70:
  Config error in file /home/paul/.config/hypr/zen-hyprbars.conf at line 33:
  config option <windowrule:hyprbars:no_bar> does not exist.
```

Two distinct problems:

1. **Hardcoded `/home/paul/` in hyprland.conf** — `source = /home/paul/.config/hypr/zen-hyprbars.conf` — completely breaks on any other machine/user.

2. **`config option does not exist` error** — different from previous "missing a value" or "invalid field type." This time it means the **plugin isn't actually loaded** in the running Hyprland, so the windowrule effect names aren't registered.

---

## Bug 1 — Hardcoded path

### Root cause

`HyprbarsService.ensureMainConfSources()` was building the source line as:

```qml
const line = "source = " + root.configPath
// where configPath = Quickshell.env("HOME") + "/.config/hypr/zen-hyprbars.conf"
// → resolves to "source = /home/paul/.config/hypr/zen-hyprbars.conf"
```

Yung absolute path is correct for the runtime user — but PERMANENTLY EMBEDS that user's home dir into the user's own hyprland.conf, which they may share / version control / migrate to other machines.

The user pointed out: yung iba pang source lines sa kanilang hyprland.conf use `~/`:

```hypr
source = ~/.config/hypr/hyprland-monitors.conf
source = ~/.config/hypr/modules/hardware.conf
source = ~/.config/hypr/zen-mouse.conf
# ...
source = /home/paul/.config/hypr/zen-hyprbars.conf   ← OUR BUG
```

Hyprland's `~/` is natively expanded to $HOME by hyprlang, so this form is both portable AND consistent.

### Fix

Build the source line with tilde:

```qml
readonly property string sourceLineTilde: "source = ~/.config/hypr/zen-hyprbars.conf"
```

Auto-migration cleanup via sed in `ensureMainConfSources()`:

```bash
# Strip any old absolute-path source lines (hf52-hf56 bug)
sed -E -i '\|^source = /home/[^/]+/\.config/hypr/zen-hyprbars\.conf$|d' ~/.config/hypr/hyprland.conf

# Append portable tilde form if not already present
grep -qxF 'source = ~/.config/hypr/zen-hyprbars.conf' ~/.config/hypr/hyprland.conf \
    || echo 'source = ~/.config/hypr/zen-hyprbars.conf' >> ~/.config/hypr/hyprland.conf
```

Key details:
- **`sed -E` (extended regex)** so `+` works without escaping
- **`|` delimiter** (not `/`) so forward slashes in the path pattern don't need escaping
- **`[^/]+` matches any username** — works for paul, mom, anyone
- **Idempotent** — safe to re-run; if file already has tilde line, no-op

Tested on the user's actual uploaded `hyprland.conf`:
```
=== BEFORE ===
70: source = /home/paul/.config/hypr/zen-hyprbars.conf

=== AFTER ===
70: source = ~/.config/hypr/zen-hyprbars.conf
```

The boot Timer fires `ensureMainConfSources()` 1.2s after shell start, so existing users get the migration automatically without doing anything.

---

## Bug 2 — `config option does not exist`

### Why hf56's block syntax still errored

hf56 emitted:

```hypr
windowrule {
    name = zen-hyprbars-no-bar-on-tiled
    hyprbars:no_bar = true
    match:float = 0
}
```

Per upstream Issue #586 this is the correct syntax... **when the plugin is loaded**. The `hyprbars:no_bar` effect is dynamically registered by the plugin at startup via `Desktop::Rule::windowEffects()->registerEffect("hyprbars:no_bar")`. Until that registration happens, Hyprland's parser doesn't know about it and rejects the windowrule as "config option does not exist."

So the real question is: **why isn't the plugin loaded?**

Several possible causes:

1. **`hyprpm` add/enable/reload sequence failed silently** during install — pre-flight checks passed but the actual build/load step crashed
2. **Plugin built but not loaded** — `hyprpm reload` didn't successfully inject into running Hyprland
3. **Plugin permission denied** — Hyprland's permission management blocking hyprpm
4. **ABI mismatch** — plugin built against different Hyprland version
5. **Stale stale state** — hyprpm reports enabled but actual plugin missing from running instance

In ALL these cases, the user sees:
- `hyprctl plugin list` returns empty (or no hyprbars)
- BUT our config still tries to use `hyprbars:no_bar` → parse error

### Fix — pluginLoaded gate

New service property:

```qml
property bool pluginLoaded: false
```

Populated by polling `hyprctl plugin list`:

```qml
Process {
    id: verifyProc
    stdout: StdioCollector {
        onStreamFinished: {
            const out = this.text || ""
            const nowLoaded = /hyprbars/i.test(out) && !/^$/.test(out.trim())
            root.pluginLoaded = nowLoaded
            // Re-emit config now that pluginLoaded changed
            if (nowLoaded && root.floatingOnly) {
                root._lastWritten = ""
                root.writeConfig()
            }
        }
    }
}

function verifyPluginLoaded() {
    verifyProc.command = ["bash", "-c",
        "hyprctl plugin list 2>/dev/null || echo ''"]
    verifyProc.running = true
}
```

Triggers:
- 800ms after every install / enable / disable / update operation
- 800ms after shell boot (alongside boot config rewrite)
- Manually via the "Check status" button

### Config emission gate

```qml
// Only emit windowrules when BOTH conditions are true
if (root.floatingOnly && root.pluginLoaded) {
    lines.push("windowrule { ... hyprbars:no_bar = true ... }")
}
else if (root.floatingOnly && !root.pluginLoaded) {
    // Emit a comment explaining why bars are on all windows
    lines.push("# Floating-only mode is enabled in Settings, but the")
    lines.push("# hyprbars plugin isn't verified loaded yet — windowrules")
    lines.push("# omitted to prevent parse errors. ...")
}
```

So if the plugin ever fails to load, the config file is **pure plugin block, no windowrules** — which parses cleanly. No more config errors.

When the user successfully installs the plugin, the next verify call sets `pluginLoaded = true`, triggers a config rewrite, and the windowrules get emitted properly.

### Safer default

`floatingOnly` default changed from `true` → `false`. Fresh installs no longer attempt windowrules at all, until the user opts in via Settings AND the plugin is verified.

### Settings UI badge

```
●  Plugin loaded in Hyprland — bars active        (green dot)
●  Plugin NOT verified loaded — click 'Check      (red dot)
   status' or 'Install / reinstall'
```

Live indicator that updates whenever `verifyPluginLoaded()` runs.

---

## Files modified (3)

```
zen-shell-v5/HyprbarsService.qml      — pluginLoaded property + verify
                                          process, gated windowrule
                                          emission, portable ~/ source
                                          line + sed migration
zen-shell-v5/HyprbarsSettingsPage.qml — pluginLoaded status badge
zen-shell-v5/ZenVersion.qml           — bumped to hf57
install.sh                             — banner + changelog
```

---

## How to install

```bash
tar -xzf zen-shell-v7_0_0-beta_1-hf57-path-portability-plugin-verify.tgz
cd zen-shell-v7.0.0-beta.1-hf57
./install.sh
pkill quickshell
```

On next quickshell start, within ~1.2s:
1. State loads
2. Plugin verification runs (`hyprctl plugin list`)
3. Config gets rewritten using current pluginLoaded state
4. Source line migration cleans up `/home/paul/` hardcoded paths
5. Tilde form added if missing
6. `hyprctl reload` fires
7. **Config errors disappear** (windowrules omitted since plugin probably isn't loaded yet)

---

## How to verify

### Path migration

```bash
grep -n "zen-hyprbars" ~/.config/hypr/hyprland.conf
```

Should show ONLY:
```
70:source = ~/.config/hypr/zen-hyprbars.conf
```

No more `/home/paul/...` line.

### Plugin loaded state

1. Settings → Hyprbars
2. Look at the status badge:
   - 🔴 Red dot = plugin not loaded → click "Install / reinstall"
   - 🟢 Green dot = plugin active, bars working

### Config file content

```bash
cat ~/.config/hypr/zen-hyprbars.conf | tail -10
```

If plugin NOT loaded yet, should end without windowrules (or with a comment explaining they're suppressed).

If plugin IS loaded AND floatingOnly is on, should have the windowrule blocks.

---

## Story so far (5 hyprbars hotfixes)

| Hotfix | Issue | Status |
|---|---|---|
| hf52 | Initial integration | Worked but wrong syntax shipped |
| hf53 | Added floating-only | `missing a value` error |
| hf55 | Inline w/ `on` value | `invalid field type` error |
| hf56 | Block syntax | `config option does not exist` error |
| **hf57** | Gate on pluginLoaded + portable paths | Config parses cleanly regardless of plugin state |

---

## Wala tayong babawasan

All previous fixes preserved:

- ✅ hf56 block windowrule syntax (still emitted, just gated)
- ✅ hf55 auto-rewrite on boot
- ✅ hf54 mimic layout + robust install
- ✅ hf53 floating-only + status feedback + popup mimic
- ✅ hf52 hyprbars integration foundation
- ✅ hf51-32 all preserved

🍃 Pre, **multiple layers of fix**: portable paths, plugin-state gated windowrules, auto-migration. Config will parse cleanly even if hyprpm still hasn't successfully loaded the plugin — user just won't see bars until plugin gets verified loaded.
