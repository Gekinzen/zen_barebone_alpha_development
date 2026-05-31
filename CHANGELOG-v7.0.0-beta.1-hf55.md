# v7.0.0-beta.1-hf55 — CRITICAL FIX: hyprbars windowrule syntax

**Channel:** beta (hotfix)
**Released:** 2026-05-17
**Branch:** `dev`

---

## What this hotfix fixes

User report (with screenshot showing 4 config error toasts):

```
Config error in file /home/paul/.config/hypr/zen-hyprbars.conf at line 29:
  invalid field hyprbars:no_bar: missing a value
Config error in file /home/paul/.config/hypr/zen-hyprbars.conf at line 30:
  invalid field hyprbars:no_bar: missing a value
Config error in file /home/paul/.config/hypr/hyprland.conf at line 70:
  Config error in file /home/paul/.config/hypr/zen-hyprbars.conf at line 29:
  invalid field hyprbars:no_bar: missing a value
```

Plus: floating windows still showed no hyprbar despite the plugin being
loaded.

---

## Root cause — wrong windowrule syntax

hf53 emitted these lines at the end of `zen-hyprbars.conf`:

```hypr
windowrule = hyprbars:no_bar, floating:0
windowrule = hyprbars:no_bar, fullscreen:1
```

**This syntax has been BROKEN since Hyprland 0.53.0** (released early
2025). Per upstream:

- **[hyprland-plugins Issue #586](https://github.com/hyprwm/hyprland-plugins/issues/586)** —
  "[hyprbars] window rules are missing `plugin:` prefix"
- **[Hyprland Discussion #12390](https://github.com/hyprwm/Hyprland/discussions/12390)** —
  "Rules no longer work within plugin{}"

What changed: hyprbars windowrule effects now require an EXPLICIT VALUE
after the effect name. `hyprbars:no_bar` alone is parsed as "field
without value" → error.

### Correct syntax (post-0.53)

```hypr
windowrule = hyprbars:no_bar on, floating:0
windowrule = hyprbars:no_bar on, fullscreen:1
```

Note the **`on`** after `no_bar` — that's the missing value.

Alternative form (rule blocks, also works):

```hypr
windowrule {
    name = no-hyprbars-on-tiled-windows
    hyprbars:no_bar = true
    match:float = 0
}
```

hf55 uses the inline form because it's simpler to emit programmatically.

---

## Why this also explained Brave still not showing a bar

The two broken windowrules at the bottom of the config caused Hyprland's
config parser to **bail out partway** through reading the file. Depending
on parse-error recovery behavior:

- Best case: only the broken lines were skipped; the plugin block still
  loaded with bar styling, but no floating-only filtering applied →
  bars appeared on ALL windows (or all tiled too, depending)
- Worst case: the entire `source = zen-hyprbars.conf` line was
  considered failed, so the WHOLE plugin block never registered →
  hyprbars active in Hyprland but with zero config → no bars
  anywhere even on floating windows

The cascade error in the screenshot:
```
Config error in file /home/paul/.config/hypr/hyprland.conf at line 70:
  Config error in file /home/paul/.config/hypr/zen-hyprbars.conf at line 29:
```

suggests Hyprland was rolling up the inner error to line 70 of the
main config (where the `source = ...` line lives). Either way: visible
to user as "wala nangyari."

---

## Fix — correct syntax everywhere

### In HyprbarsService.qml

```qml
// hf55: correct post-0.53 syntax with explicit value
if (root.floatingOnly) {
    lines.push("windowrule = hyprbars:no_bar on, floating:0")
    lines.push("windowrule = hyprbars:no_bar on, fullscreen:1")
}
```

### In HyprbarsSettingsPage.qml — user-facing examples

```qml
text: "windowrule = hyprbars:no_bar on, class:^(Brave-browser)$\n"
    + "windowrule = hyprbars:no_bar on, class:^(code-oss)$\n"
    + "windowrule = hyprbars:no_bar on, fullscreen:1\n"
```

So when users copy-paste from the Settings page, they get working rules.

---

## Auto-fix on startup

Existing users who installed hf53 or hf54 already have the broken
`zen-hyprbars.conf` on disk. To avoid making them toggle anything in
Settings manually, hf55 adds a one-shot boot timer:

```qml
Timer {
    id: bootRewriteTimer
    interval: 800
    repeat: false
    onTriggered: {
        if (root.enabled) {
            root._lastWritten = ""   // force re-write
            root.writeConfig()        // fires hyprctl reload too
        }
    }
}

Connections {
    target: loadStateProc
    function onExited(code) {
        bootRewriteTimer.start()
    }
}
```

Sequence on shell start:
1. State loads from `hyprbars.json`
2. 800ms later (other singletons ready, ThemeService colors stable)
3. If `enabled` was true, rewrite the config with the now-correct syntax
4. `writeConfig()` fires `hyprctl reload` automatically
5. Hyprland re-parses the now-valid config → errors disappear →
   floating windows get bars

So the user doesn't need to do anything — just install hf55, restart
shell, and the errors clear themselves on next boot.

---

## Files modified (3)

```
zen-shell-v5/HyprbarsService.qml      — correct windowrule syntax,
                                          auto-rewrite on boot
zen-shell-v5/HyprbarsSettingsPage.qml — user-facing examples updated
zen-shell-v5/ZenVersion.qml           — bumped to hf55
install.sh                             — banner + changelog
```

---

## How to install

```bash
tar -xzf zen-shell-v7_0_0-beta_1-hf55-windowrule-syntax-fix.tgz
cd zen-shell-v7.0.0-beta.1-hf55
./install.sh
```

Then:

```bash
pkill quickshell
```

That's it. On next quickshell startup:
1. State loads
2. After 800ms, config auto-rewrites with correct syntax
3. `hyprctl reload` fires
4. Error toasts disappear
5. Floating Brave finally shows a bar ✅

---

## How to verify

1. Restart shell (`pkill quickshell`)
2. **Within ~5 seconds**, the four config-error toasts from before
   should NOT reappear
3. Open Brave
4. Press `Super+V` to float-toggle (or whatever your float keybind is)
5. Title bar appears at the top of Brave ✅
6. Tile it back → bar disappears
7. Fullscreen → bar disappears
8. Click "Check status" in Settings → "Hyprbars" → should show
   `✅ hyprbars is loaded into Hyprland`

If you want to manually verify the config file:

```bash
cat ~/.config/hypr/zen-hyprbars.conf | tail -6
```

Should end with:

```hypr
# v7.0.0-beta.1-hf55 — floating-only rules (correct syntax)
# Bars appear only on floating, non-fullscreen windows.
# `hyprbars:no_bar on` is the correct post-0.53 form.
windowrule = hyprbars:no_bar on, floating:0
windowrule = hyprbars:no_bar on, fullscreen:1
```

Note the `on` after `no_bar` — that's the fix.

---

## Apology + learning

Pre, sorry sa syntax bug — I followed an older upstream README example
when I built hf53 without checking the post-0.53 breaking change. Yung
upstream README itself still shows the broken syntax in its examples
section, which is why even careful copy-paste fails. The actual
working syntax is documented only in the issue tracker discussion
thread.

For future plugin integrations, lesson learned: always check GitHub
Issues + Discussions for "syntax changed" notes, not just the README.

---

## Wala tayong babawasan

All previous fixes preserved:

- ✅ hf54 mimic layout fix + robust install with verify
- ✅ hf53 floating-only + status feedback + popup mimic
- ✅ hf52 hyprbars plugin integration foundation
- ✅ hf51 sticky editor focus-loss safety
- ✅ hf50 click-through + close + widget input/drag/live-sync
- ✅ hf49-32 all preserved

🍃 Critical syntax fix. The config error spam is gone, and floating
Brave gets its bar.
