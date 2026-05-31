# v7.0.0-beta.1-hf61 — CRITICAL: fix .so search path (XDG runtime dir)

**Channel:** beta (hotfix)
**Released:** 2026-05-18
**Branch:** `dev`

---

## The actual root cause (after 9 hyprbars hotfixes)

User ran `hyprpm update -v` in terminal per hf60's diagnostic guide
and shared the output:

```
✓ built hyprbars into hyprbars/hyprbars.so
make: Leaving directory '/run/user/1000/hyprpm/paul/hyprbars'
...
✓ Loaded borders-plus-plus
✓ Plugin load state ensured
Hyprland 0.54.3 built from branch v0.54.3 at commit 521ece463c...
```

**Two critical facts visible in that output:**

1. **The .so file WAS built successfully** — `built hyprbars into
   hyprbars/hyprbars.so`. No compile error. ABI pin matches.

2. **The .so lives at `/run/user/1000/hyprpm/paul/hyprbars/hyprbars.so`** —
   NOT `~/.local/share/hyprpm/...` which our code was searching.

Modern hyprpm (Hyprland 0.50+) moved its build output directory to
`$XDG_RUNTIME_DIR/hyprpm/$USER/` to keep builds clean per-session
and avoid stale state across reboots. Our auto-load `find` command
searched only the legacy `~/.local/share/hyprpm` path, which on
modern hyprpm doesn't exist or is empty.

So the chain was:
1. `hyprpm update` built `/run/user/1000/hyprpm/paul/hyprbars/hyprbars.so` ✓
2. Auto-load ran `find ~/.local/share/hyprpm -name 'hyprbars*.so'` → empty
3. Emitted `STATUS=missing-so` → attempt counter incremented
4. After 3 attempts → "Auto-load exhausted — check plugin .so / ABI match"

The plugin was sitting there built and ready the entire time. We
just looked in the wrong place.

This is what the hf60 diagnostic surfaces were designed to catch —
the moment user shared the build output showing the runtime dir
path, the fix became obvious.

---

## Fix — multi-location search

New centralized snippet in `HyprbarsService.qml`:

```qml
function _findSoSnippet() {
    return ""
        + "SO=''; "
        + "for SEARCH_DIR in "
        + "  \"${XDG_RUNTIME_DIR:-/run/user/$(id -u 2>/dev/null)}/hyprpm\" "
        + "  \"$HOME/.local/share/hyprpm\" "
        + "  \"$HOME/.cache/hyprpm\" ; do "
        + "  [ -d \"$SEARCH_DIR\" ] || continue; "
        + "  FOUND=$(find \"$SEARCH_DIR\" -name 'hyprbars*.so' 2>/dev/null | head -1); "
        + "  if [ -n \"$FOUND\" ]; then SO=\"$FOUND\"; break; fi; "
        + "done; "
}
```

Priority order:

1. **`$XDG_RUNTIME_DIR/hyprpm`** — modern hyprpm (Hyprland 0.50+).
   Expands to `/run/user/$UID/hyprpm` when XDG_RUNTIME_DIR not set
   (which it always is under systemd-logind sessions).
2. **`~/.local/share/hyprpm`** — legacy hyprpm location (pre-0.50).
3. **`~/.cache/hyprpm`** — rare fallback for some forks/distros.

The loop breaks on the first hit, so modern systems find the .so
in `/run/user/$UID/hyprpm` immediately. Legacy systems still work.

### Sites patched (5 places)

All five locations that previously hardcoded
`$HOME/.local/share/hyprpm` now use the multi-location loop:

1. `_autoLoadCmd()` — the silent auto-load fired by verifyProc
2. `installPlugin()` Step 8 verification + fallback load
3. `enablePlugin()` Step 4 fallback load
4. `checkStatus()` Step 4 .so existence diagnostic
5. `manualLoadPlugin()` — the purple Force load button

`checkStatus()` Step 4 now also reports which directory it found
the .so in:

```
[4/7] Plugin .so file built?
  ✅ Built .so:
    /run/user/1000/hyprpm/paul/hyprbars/hyprbars.so
  (found in: /run/user/1000/hyprpm)
```

So pre, sasabihin niya kung XDG_RUNTIME_DIR ang nag-yield ng .so
or legacy path. Confirms the fix landed correctly.

### Settings UI

The diagnostic card "no .so found" message now lists all three
search locations:

> No hyprbars*.so found in any hyprpm location (checked
> $XDG_RUNTIME_DIR/hyprpm, ~/.local/share/hyprpm, ~/.cache/hyprpm)
> — plugin build failed. Run in terminal: hyprpm update -v

---

## Files modified (4)

```
zen-shell-v5/HyprbarsService.qml       — _findSoSnippet helper,
                                          5 sites patched to use
                                          multi-location search,
                                          checkStatus Step 4 reports
                                          which dir found
zen-shell-v5/HyprbarsSettingsPage.qml  — error message lists all
                                          3 search locations
zen-shell-v5/ZenVersion.qml            — bumped to hf61
install.sh                              — banner + changelog entry
```

**No core framework changes. All hyprbars-scoped.**

---

## How to install

```bash
tar -xzf zen-shell-v7_0_0-beta_1-hf61-fix-so-path.tgz
cd zen-shell-v7.0.0-beta.1-hf61
./install.sh
pkill quickshell
```

---

## What should happen now

On next quickshell start:

1. ~800ms boot: state loads, verify fires `hyprctl plugin list`
2. Plugin not loaded → auto-load triggers
3. `_findSoSnippet` checks `$XDG_RUNTIME_DIR/hyprpm` → finds
   `/run/user/1000/hyprpm/paul/hyprbars/hyprbars.so` ✓
4. Runs `hyprctl plugin load /run/user/1000/hyprpm/paul/hyprbars/hyprbars.so`
5. ~600ms re-verify → `hyprctl plugin list` shows hyprbars ✓
6. **Badge turns 🟢 green: "Plugin loaded in Hyprland — bars active"**
7. Bars appear on Hyprland windows (Brave, terminal, etc.)
8. Mimic re-appears on Zen Shell popups (Control Panel, Settings)
   — consistent UX, because real plugin is now loaded

Then for Brave specifically:
- If Brave is a tiled window, bars only show if `floatingOnly` is OFF
  (or always-on default)
- If Brave is floating (Super+V), bars always show
- The bar will have your theme colors (gruvbox red/yellow/green
  by default in this build)

---

## Verification commands

```bash
# After install + reload, all these should work:
hyprctl plugin list                                       # shows hyprbars
ls /run/user/$(id -u)/hyprpm/$USER/hyprbars/              # shows .so
cat ~/.config/quickshell/zen-shell/hyprbars.json          # shows enabled=true
```

If "Check status" diagnostic Step 4 shows the new format:

```
✅ Built .so:
    /run/user/1000/hyprpm/paul/hyprbars/hyprbars.so
(found in: /run/user/1000/hyprpm)
```

— the fix landed correctly. Step 5 should also show:

```
✅ hyprbars is LOADED:
    hyprbars by Vaxry, version 1.0
```

---

## Why this took 10 hotfixes

The journey:

| Hotfix | Theory | Reality |
|---|---|---|
| hf52 | Just need install + enable | Wrong floating-only syntax |
| hf53-56 | Tweak windowrule syntax | All variants errored |
| hf57 | Gate windowrules on plugin state | Errors gone, no bars |
| hf58 | Add diagnostic + manual button | Need to click every reload |
| hf59 | Auto force-load + watchdog | Auto-load couldn't find .so |
| hf60 | Surface load error to UI | Showed "exhausted" with no detail |
| **hf61** | **Fix .so search path** | **`.so` is in $XDG_RUNTIME_DIR/hyprpm, not ~/.local/share** |

The lesson: each fix surfaced one more layer of the actual problem.
hf60's diagnostic output was the final missing piece — once we saw
the `make: Leaving directory '/run/user/1000/hyprpm/paul/hyprbars'`
line in user's terminal, the path mismatch was obvious. Without
hf60's diagnostic surfaces, hf61's fix would've stayed undiscovered.

---

## Wala tayong babawasan

All previous fixes preserved:

- ✅ hf60 lastLoadError / soPath / soExists surfaces + diagnostic card
- ✅ hf60 mimic gating + showMimicFallback opt-in
- ✅ hf59 auto force-load + Hyprland reload watchdog
- ✅ hf58 7-step diagnostic + manual force-load button
- ✅ hf57 plugin verify gate + portable tilde paths
- ✅ hf56 block windowrule syntax (gated)
- ✅ hf55 auto-rewrite timer
- ✅ hf54 mimic layout
- ✅ hf53 popup mimic foundation
- ✅ hf52 hyprbars integration
- ✅ hf51-32 all preserved

🍃 Pre, this should be **it**. Pag-install at reload, dapat 🟢 green
badge na within 2 seconds, bars appear sa Brave + iba pang floating
windows automatically. If hindi pa rin gumana, screenshot mo yung
diagnostic Step 4 + 5 output ng "Check status" button — sasabihin
kaagad kung saan ulit nag-miss.
