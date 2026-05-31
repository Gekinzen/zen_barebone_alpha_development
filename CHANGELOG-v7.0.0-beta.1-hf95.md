# Zen Shell v7.0.0-beta.1-hf95 — Karui (軽い)

Release date: 2026-05-30
Channel: beta · Codename: Karui (軽い)

**Vertical overflow (taskbar scroll + SysRow expand cap) + the REAL
permanent fix: install.sh now clean-wipes stale QML and clears the QML
cache.** Wala tayong babawasan.

---

## 0. install.sh — the permanent stale-file fix (THE big one)

The whole "Cannot assign to non-existent property" saga was your
**install.sh**: step [4/9] did a plain `cp *.qml` MERGE into the config
dir — it never removed old files or cleared Qt's compiled QML cache. So a
renamed property (`vertical` → `zenVertical`), a removed module, or a
stale `.qmlc` kept loading and broke the launch. The final banner was
also hardcoded to `hf82y`, which is why every run "ended" announcing the
old version no matter what you installed.

Fixed in **`install.sh`**:
- **[4/9] now clean-wipes** the top-level `*.qml` in the config dir
  before copying the fresh set (so removed/renamed files can't linger),
  then **clears the compiled QML cache** (`*.qmlc`/`*.jsc` under
  `~/.cache/quickshell/…`). Your `*.json` settings, `scripts/`, and other
  subdirs are preserved.
- After copying it **verifies** `Workspaces.qml` actually has
  `zenVertical` and prints ✓ / a warning.
- The **banner and final "Enjoy Zen Shell …" line now read the REAL
  version** from the build's `ZenVersion.qml` instead of the hardcoded
  `hf82y`. So running `./install.sh` from this folder will say
  `v7.0.0-beta.1-hf95` and actually install hf95 cleanly.

> Run `./install.sh` from the hf95 build folder and it handles
> everything (clean QML, cache clear, settings preserved, spawn). No more
> manual clean-copy, no more stale hf82y.

---

## 1. Taskbar — vertical scroll (▲ / ▼)

On a vertical bar, a long app list grew the taskbar column tall enough to
push other modules (the clock) off the bar. Now it behaves like the
horizontal overflow, but vertically:

- **`Taskbar.qml`**
  - `maxVisibleHeight` (360px) caps the visible column; `fullColH` is the
    true height of all icons; `taskbarColH` = the capped visible height.
  - When the list exceeds the cap, **▲ / ▼ chevrons** appear (the chevron
    container is now an axis-flipping GridLayout: row `‹ viewport ›`
    horizontal, column `▲ / viewport / ▼` vertical).
  - The icon column clips to the cap and **scrolls on Y** (scrollOffset),
    2 icons per chevron click, smooth-animated.
  - Root `implicitHeight` uses the capped height (+ chevron space), so the
    taskbar never dominates the bar.
  - Horizontal taskbar behaviour is unchanged.

## 2. SysRow — expand height capped

Expanding SysRow on a vertical bar grew its column tall enough to shove
the clock out. Now:

- **`SysRow.qml`** — vertical expanded height is capped (`vMaxExpandedH`
  260px) and the cluster `clip`s to that band, so an expanded SysRow
  stays put and neighbouring modules keep their place. Horizontal
  unchanged.

---

## Not a shell bug: Hyprland keybinds / screenshot not working

Your "music / hypr-control-center / screenshot stopped working" is the
Hyprland **config globbing error**:

```
Config error in hyprland.conf line 46/47: source= globbing error: found no match
```

When Hyprland hits a bad `source=` line, it can fail to finish loading
the config — so keybinds (screenshot, etc.) never register. This is in
`~/.config/hypr/hyprland.conf`, NOT the shell. Paste lines 44–50 and I'll
give the exact edit; the general fix is to create the missing dir/file
(`mkdir -p ~/.config/hypr/modules && touch ~/.config/hypr/modules/placeholder.conf`)
or comment out the dead `source=` line.

---

## Files touched

```
install.sh       [4/9] clean-wipe stale QML + clear QML cache + verify;
                 banner + final line read REAL version (not hardcoded hf82y)
ZenVersion.qml   → v7.0.0-beta.1-hf95
Taskbar.qml      vertical overflow: maxVisibleHeight cap + ▲/▼ scroll
SysRow.qml       vertical expand height capped + clipped
```

Carries forward hf83–hf94.9 (vertical bar fully working after the hf94.4
crash fix).
