# v7.0.0-beta.1-hf58 — Comprehensive diagnostic + manual force-load

**Channel:** beta (hotfix)
**Released:** 2026-05-17
**Branch:** `dev`

---

## What this hotfix addresses

User report:

> "nawala na error pero wala padin lumalabs hyprbar kapag naka float
> window mode ako"

hf57 made the config parse cleanly — but the plugin still isn't loaded
in Hyprland, so no bars appear regardless of window state.

---

## Why hf57 cleared errors but no bars

hf57's pluginLoaded gate **prevented errors** by not emitting
windowrules when plugin isn't loaded. Pero hindi nito ginagawa loaded
yung plugin — only suppresses the error symptom.

The actual problem is upstream-side:
- `hyprpm add/enable/reload` chain reports success but **plugin .so
  isn't actually getting loaded** into running Hyprland
- Multiple known upstream issues report similar behavior (Issue #634,
  Discussion #6315 sa hyprwm/Hyprland)

Common reasons:
1. **Build failed silently** — `hyprpm enable` flips the toggle but
   compile output never produced
2. **ABI mismatch** — your Hyprland version doesn't have a matching
   commit pin in hyprpm.toml, plugin loads but doesn't work
3. **Permission management** — Hyprland's permission system blocks
   hyprpm from injecting plugins
4. **Build but never injected** — .so exists but `hyprpm reload` failed
   to call `hyprctl plugin load` properly

---

## Fix — comprehensive diagnostic

"Check status" button (yellow) now runs a 7-step diagnostic:

```
=== Hyprbars Diagnostic Report ===

[1/7] Hyprland version:
  Hyprland 0.54.0 built from branch at commit...

[2/7] hyprpm available?
  ✅ hyprpm found at: /usr/bin/hyprpm

[3/7] hyprpm list (state from hyprpm):
  Plugin hyprbars
  └─ enabled: true

[4/7] Plugin .so file built?
  ✅ Built .so:
    /home/paul/.local/share/hyprpm/hyprland-plugins/hyprbars/hyprbars.so

[5/7] hyprctl plugin list (runtime loaded):
  ❌ hyprbars NOT in loaded plugins. Currently loaded:
    (empty)

[6/7] Permission management check:
  ✅ No permission management — no allow rule needed

[7/7] Source line:
  source = ~/.config/hypr/zen-hyprbars.conf

=== End Report ===

NEXT STEPS:
  • If .so missing → terminal: hyprpm update -v
  • If loaded but bars missing → Super+V to float a window
  • If permission missing → add line to hyprland.conf
  • If built but not loaded → click Force load button
```

Surfaces EXACTLY which step is broken. If `.so` exists but `hyprctl
plugin list` shows nothing, → `Force load` button.

---

## Fix — Force load button (purple)

NEW button beside Check status. Runs:

```bash
SO=$(find ~/.local/share/hyprpm -name 'hyprbars*.so' | head -1)
hyprctl plugin load "$SO"
```

This bypasses hyprpm's reload mechanism and calls the documented
manual load API directly. Useful when:
- `hyprpm reload` reports success but plugin still missing from list
- After hyprpm update that didn't trigger reload properly
- Recovery after Hyprland version upgrade

Per Hyprland Wiki: "To load plugins manually, use `hyprctl plugin
load path`. Path has to be absolute!"

---

## Better install flow

Updated `installPlugin()` to use 8 steps:

1. Pre-flight: hyprpm + build deps check
2. **Migrate** any old absolute-path source lines (sed cleanup)
3. **`hyprpm update`** — refresh manifest + rebuild
4. `hyprpm add` (idempotent)
5. `hyprpm enable hyprbars`
6. `hyprpm reload`
7. `hyprctl reload`
8. **Verify + manual load fallback** — if step 7 didn't inject, try
   `hyprctl plugin load <.so>` automatically

---

## Files modified (3)

```
zen-shell-v5/HyprbarsService.qml      — comprehensive diagnostic,
                                          manual load function,
                                          enhanced install flow
zen-shell-v5/HyprbarsSettingsPage.qml — Force load button (purple)
zen-shell-v5/ZenVersion.qml           — bumped to hf58
install.sh                             — banner + changelog
```

---

## How to install

```bash
tar -xzf zen-shell-v7_0_0-beta_1-hf58-diagnostic-force-load.tgz
cd zen-shell-v7.0.0-beta.1-hf58
./install.sh
pkill quickshell
```

---

## How to debug your situation

After installing hf58 + reloading shell:

### Step 1: Run diagnostic

1. Settings → Hyprbars
2. Click yellow **"Check status"** button
3. Read the output carefully — surfaces all 7 checks

### Step 2: Interpret results

**If `[4/7] No hyprbars*.so found`** (build failed):
- Open terminal
- Run: `hyprpm update -v`
- Read the verbose output for actual build error
- Likely cause: ABI mismatch with your Hyprland 0.54 version
- Wait for upstream commit pin update OR build manually

**If `[5/7] hyprbars NOT in loaded plugins` but `[4/7]` shows .so exists**:
- Click purple **"Force load"** button
- Should inject the plugin via `hyprctl plugin load`

**If `[6/7] Permission management missing`**:
- Edit `~/.config/hypr/hyprland.conf`
- Add this line:
  ```
  permission = /usr/(bin|local/bin)/hyprpm, plugin, allow
  ```
- Run: `hyprctl reload`
- Click "Install / reinstall" again

**If everything looks OK but still no bars on float**:
- Try: `Super+V` on a window to toggle floating
- The bar should appear immediately
- If not, that's a different bug — likely upstream ABI issue

### Step 3: If all else fails

Try manual install in terminal:

```bash
# Remove any stale state
rm -rf ~/.local/share/hyprpm/

# Fresh install
hyprpm update -v
hyprpm add https://github.com/hyprwm/hyprland-plugins
hyprpm enable hyprbars
hyprpm reload -n

# Manual load if reload didn't work
SO=$(find ~/.local/share/hyprpm -name 'hyprbars*.so' | head -1)
hyprctl plugin load "$SO"

# Verify
hyprctl plugin list
```

If even the manual command fails, the plugin doesn't have a working
commit pin for Hyprland 0.54.0 (CachyOS rolling). You'd need to:
- Wait for upstream pin update, OR
- Build hyprbars manually from a specific commit that matches your
  Hyprland version

---

## Hyprbars hotfix journey (6 attempts)

| Hotfix | What it did | Result |
|---|---|---|
| hf52 | Initial integration | Worked but wrong syntax shipped |
| hf53 | Floating-only inline | `missing a value` error |
| hf55 | Inline w/ `on` value | `invalid field type` error |
| hf56 | Block syntax | `config option does not exist` |
| hf57 | Gate on pluginLoaded + portable paths | Errors gone, no bars |
| **hf58** | Diagnostic + force load | Surfaces WHY plugin isn't loaded |

The journey was syntax-syntax-syntax, then we realized the REAL
problem is plugin not loaded. hf58 helps you figure out which of the
4-5 possible upstream causes is hitting you.

---

## Wala tayong babawasan

All previous fixes preserved:

- ✅ hf57 plugin verify gate + portable paths
- ✅ hf56 block syntax
- ✅ hf55 auto-rewrite timer
- ✅ hf54 mimic layout
- ✅ hf53 popup mimic
- ✅ hf52 hyprbars integration
- ✅ hf51-32 all preserved

🍃 Pre, click yung "Check status" button + send me yung output —
based sa results, sasabihin ko exactly anong gawin sa terminal para
ma-load yung plugin. Yung problem at this point is upstream-side,
not Zen Shell side.
