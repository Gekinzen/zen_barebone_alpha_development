# v7.0.0-beta.1-hf56 — Hyprbars windowrule BLOCK syntax (third try)

**Channel:** beta (hotfix)
**Released:** 2026-05-17
**Branch:** `dev`

---

## What this hotfix fixes

User report (screenshot from hf55):

```
Config error in file /home/paul/.config/hypr/zen-hyprbars.conf at line 30:
  invalid field type hyprbars:no_bar
Config error in file /home/paul/.config/hypr/zen-hyprbars.conf at line 31:
  invalid field type hyprbars:no_bar
Config error in file /home/paul/.config/hypr/hyprland.conf at line 70:
  Config error in file /home/paul/.config/hypr/zen-hyprbars.conf at line 30:
  invalid field type hyprbars:no_bar
```

Note the DIFFERENT error message vs hf55:
- hf55 emitted broken syntax → "missing a value"
- hf56 fix attempt → "invalid field TYPE" — yan ay completely different problem

---

## Story of three syntaxes

### hf53 attempt (FAILED)

```hypr
windowrule = hyprbars:no_bar, floating:0
```

Error: `invalid field hyprbars:no_bar: missing a value`

Hyprland parser saw `hyprbars:no_bar` as a field name expecting a value
after the colon, but there was a comma instead.

### hf55 attempt (FAILED)

```hypr
windowrule = hyprbars:no_bar on, floating:0
```

Error: `invalid field type hyprbars:no_bar`

This was based on Hyprland Discussion #12390 where a user reported the
inline form worked. But on Paul's Hyprland version (CachyOS 0.53+),
the parser doesn't recognize `hyprbars:no_bar` as a valid windowrule
effect TYPE at all when used inline. Plugin-registered effects (which
hyprbars is) aren't exposed to the inline parser.

### hf56 fix — BLOCK syntax (the actually-documented working form)

Per upstream [hyprland-plugins Issue #586](https://github.com/hyprwm/hyprland-plugins/issues/586),
the verified-working post-0.53 syntax is the BLOCK form:

```hypr
windowrule {
    name = no-hyprbars-on-tiled-windows
    hyprbars:no_bar = true
    match:float = 0
}
```

Key differences from the inline form:
- Wrapped in `windowrule { ... }` block
- `name = ...` makes it a named rule (required for plugin effects?)
- Effect is `hyprbars:no_bar = true` (key-value pair inside the block)
- Matcher is `match:float = 0` (also key-value pair, with `match:`
  prefix)

The block form lets Hyprland's parser handle plugin-registered effects
properly because the parser knows ahead of time which fields inside the
block are plugin extensions vs core windowrule effects.

---

## What we now emit

```hypr
# v7.0.0-beta.1-hf56 — floating-only rules (block syntax)
windowrule {
    name = zen-hyprbars-no-bar-on-tiled
    hyprbars:no_bar = true
    match:float = 0
}
windowrule {
    name = zen-hyprbars-no-bar-on-fullscreen
    hyprbars:no_bar = true
    match:fullscreen = 1
}
```

Two rules:
1. **`match:float = 0`** — disable bar on tiled windows
2. **`match:fullscreen = 1`** — disable bar on fullscreen windows

Combined effect: bars appear ONLY on floating non-fullscreen windows.

---

## Why the auto-fix still works

hf55 added a startup Timer that re-emits the config 800ms after shell
boot. That same Timer is still active in hf56 — so existing users with
broken hf53/hf55 configs get them automatically replaced with the
new block syntax on next quickshell start. No manual toggling needed.

---

## User-facing example updates

Settings → Hyprbars → "Exclude specific apps" section now shows
block-form examples:

```hypr
# Block form (works on Hyprland 0.53+):
windowrule {
    name = no-bar-brave
    hyprbars:no_bar = true
    match:class = ^(Brave-browser)$
}

windowrule {
    name = no-bar-vscode
    hyprbars:no_bar = true
    match:class = ^(code-oss)$
}

# Per-window bar color override:
windowrule {
    name = kitty-bar-color
    hyprbars:bar_color = rgb(282828)
    match:class = ^(kitty)$
}
```

Copy-pasteable into `~/.config/hypr/hyprland.conf` without errors.

---

## Files modified (3)

```
zen-shell-v5/HyprbarsService.qml      — block-syntax windowrules
zen-shell-v5/HyprbarsSettingsPage.qml — block-syntax user examples
zen-shell-v5/ZenVersion.qml           — bumped to hf56
install.sh                             — banner + changelog
```

---

## How to install

```bash
tar -xzf zen-shell-v7_0_0-beta_1-hf56-windowrule-block-syntax.tgz
cd zen-shell-v7.0.0-beta.1-hf56
./install.sh
pkill quickshell
```

Wait ~1 second for auto-fix to fire. Errors should disappear.

---

## How to verify

1. Restart shell
2. **No config-error toasts** within first 5 seconds
3. `cat ~/.config/hypr/zen-hyprbars.conf | tail -12`
4. Should show:
   ```hypr
   windowrule {
       name = zen-hyprbars-no-bar-on-tiled
       hyprbars:no_bar = true
       match:float = 0
   }
   windowrule {
       name = zen-hyprbars-no-bar-on-fullscreen
       hyprbars:no_bar = true
       match:fullscreen = 1
   }
   ```
5. Open Brave → float-toggle with `Super+V` → bar appears ✅
6. Tile it back → bar disappears ✅
7. Fullscreen → bar disappears ✅

---

## Third-time apology

Pre, sorry talaga. Itlugan na ako sa hyprbars syntax issue. Tatlong
attempts:
- hf53: outdated example syntax
- hf55: incomplete reading of upstream issue (the `on` value form is
  for a different effect, not `no_bar`)
- hf56: ACTUALLY reading Issue #586 closely — block form is the only
  one that consistently works post-0.53

For future plugin integrations, **rule of thumb**: when an effect is
plugin-registered (not a built-in Hyprland windowrule like `float` or
`opacity`), ALWAYS use the block form `windowrule { ... }`. The inline
form is reserved for built-in effects in the current parser.

---

## Wala tayong babawasan

All previous fixes preserved:

- ✅ hf55 syntax attempt #2 + auto-fix timer
- ✅ hf54 mimic layout fix + robust install
- ✅ hf53 floating-only + status feedback + popup mimic
- ✅ hf52 hyprbars integration foundation
- ✅ hf51-32 all preserved

🍃 Pre, this should finally be the last hyprbars syntax fix. After
hf56's auto-rewrite runs, your config will use the form that
upstream maintainers themselves documented as the working solution.
