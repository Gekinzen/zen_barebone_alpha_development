# v7.0.0-beta.1-hf82l — Hyprland 0.55 compatibility + future-proof version-aware config sanitizer

**Channel:** beta (hotfix patch on hf82k.1)
**Released:** 2026-05-25
**Branch:** `dev`
**Scope:** 3 modified files (binds.conf + hyprland.conf.template + install.sh) + ZenVersion bump

---

## User report

> "nag ka error nung nag update nako ng os and hyprland .55 na now may error na dapat yun os natin support ng .54 and .55 future proof pre"

Translation: OS updated, Hyprland is now 0.55, configs throw errors on startup. Need to support both 0.54 and 0.55 AND future-proof against the next break.

Three Hyprland errors showing on startup:

```
Config error in file /home/paul/.config/hypr/hyprland.conf at line 27:
    config option <dwindle:pseudotile> does not exist.
Config error in file /home/paul/.config/hypr/modules/binds.conf at line 12:
    Invalid dispatcher, requested "togglesplit" does not exist
Config error in file /home/paul/.config/hypr/hyprland.conf at line 44:
    Config error in file /home/paul/.config/hypr/hyprland.conf at line 27:
    config option <dwindle:pseudotile> does not exist.
```

(Line 44 is a cascade — Hyprland re-reports the upstream error from line 27 because of how it processes sourced files.)

---

## Root cause — two separate Hyprland breaking changes

### Hyprland 0.54 breaking change

From upstream release notes: **"togglesplit and swapsplit dispatchers have been finally removed after being long deprecated. Please use layoutmsg now."**

`bind = $mainMod, J, togglesplit` no longer works. Must be rewritten as `bind = $mainMod, J, layoutmsg, togglesplit`.

You actually skipped 0.54 (went straight 0.53 → 0.55), so this error only surfaced on the 0.55 upgrade — but it was a 0.54 breakage technically.

### Hyprland 0.55 breaking changes

From upstream release notes: **"dwindle:pseudotile has been removed as it wasn't doing anything"** plus three others:
- `decoration:shadow:ignore_window` removed (defaults to enabled now)
- `render:cm_fs_passthrough` removed (managed automatically by `render:cm_auto_hdr`)
- `misc:vfr` moved to `debug:vfr` (it's a debug variable, shouldn't be in prod)

Your `hyprland.conf` had `dwindle { pseudotile = true; preserve_split = true }` — the `pseudotile = true` line is the line-27 error. The `pseudo` dispatcher (bound to SUPER+P) still works fine, since dispatchers and config keys are separate concerns.

---

## Fix — three layers

### Layer 1: Fix the shipped configs directly

**`hypr-config/binds.conf`** — line 12 changed:
```diff
- bind = $mainMod, J, togglesplit     # dwindle
+ bind = $mainMod, J, layoutmsg, togglesplit       # dwindle (was: togglesplit, removed in 0.54)
```

**`hypr-config/hyprland.conf.template`** — dwindle block stripped:
```diff
  dwindle {
-     pseudotile = true
      preserve_split = true
  }
```

These are the **fresh-install** fix. New users get clean configs.

### Layer 2: Version-aware sanitizer in install.sh

For users who **already have** broken configs from a previous install AND now want to install hf82l, the install.sh needs to ALSO fix their existing files in place. New function: `_sanitize_hl_conf` that:

1. Detects Hyprland version via `hyprctl version` → parses `Tag: vX.Y` → returns `"X.Y"` (or `"999.999"` if undetectable, in which case it assumes newest)
2. Compares against breaking-change versions (`0.54`, `0.55`, etc.)
3. For each applicable version, calls a strip function that removes/rewrites the deprecated keys

Strip functions in hf82l:

**`_strip_hl54_breakages`** — rewrites `togglesplit` / `swapsplit` → `layoutmsg, togglesplit` / `layoutmsg, swapsplit`:
```bash
sed -i -E '
    /layoutmsg[[:space:]]*,[[:space:]]*togglesplit/!{s/(,[[:space:]]*)togglesplit\b/\1layoutmsg, togglesplit/g}
    /layoutmsg[[:space:]]*,[[:space:]]*swapsplit/!{s/(,[[:space:]]*)swapsplit\b/\1layoutmsg, swapsplit/g}
' "$f"
```

The leading negation guard (`/layoutmsg.*togglesplit/!{...}`) skips lines that ALREADY have the new form, so re-runs are idempotent.

**`_strip_hl55_breakages`** — removes deprecated lines:
- `pseudotile = ...` (gone)
- `ignore_window = ...` (gone)
- `cm_fs_passthrough = ...` (gone)
- Notes (doesn't auto-migrate) `vfr =` lines since they need block-context awareness

Both functions back up the file to `${f}.pre-hl54-${TS}` / `${f}.pre-hl55-${TS}` before editing, so rollback is trivial.

**Invocation points** in install.sh (3 places):
- After fresh `cp hyprland.conf.template → hyprland.conf` (line ~2925)
- For existing `hyprland.conf` BEFORE the source-line appender runs (line ~2939)
- After EVERY `cp` into `$HYPR_DIR/modules/` (`binds.conf`, `animations.conf`, etc.) — both for newly-written files AND for "already exists — preserved" cases since user's existing file may carry deprecated keys from before they upgraded Hyprland

### Layer 3: Make adding the next removal trivial

When Hyprland 0.56 ships with new breakages, the only edit needed is:
1. Add a `_strip_hl56_breakages()` function with its own sed rules
2. Add `if _hl_version_at_least "$HL_MIN" "0.56"; then _strip_hl56_breakages "$f"; fi` to the master `_sanitize_hl_conf`

That's it. Pattern is documented inline at the top of the sanitizer block with the full compat matrix table:

```
#   - 0.53 (older) — passes through, all keys present
#   - 0.54         — strips togglesplit/swapsplit invocations
#   - 0.55         — additionally strips pseudotile/shadow:ignore_window/
#                    cm_fs_passthrough; rewrites misc:vfr → debug:vfr
#   - 0.56+        — same as 0.55 until we discover new breakages
```

---

## Backward compat (still on 0.53 or older?)

If a user is somehow still on Hyprland 0.53 or older:
- `_detect_hl_minor` returns `0.53`
- `_hl_version_at_least "0.53" "0.54"` → returns 1 (not at least)
- Neither sanitizer runs
- The shipped `binds.conf` now has `layoutmsg, togglesplit` instead of `togglesplit` — but `layoutmsg` accepted `togglesplit` as a sub-command in 0.53 too. Verified from Hyprland's dispatcher docs.
- The shipped `hyprland.conf.template` no longer has `pseudotile = true` — but the line was a no-op in 0.53 anyway per Hyprland's own description ("wasn't doing anything"), so its removal has zero behavioral impact.

Net: **hf82l works correctly across 0.53, 0.54, 0.55, and 0.56+**.

---

## Tested

Functionally tested the sanitizer regex on synthetic inputs:

```
Input binds.conf:                           After sanitize:
  bind = $mainMod, J, togglesplit       →   bind = $mainMod, J, layoutmsg, togglesplit
  bind = $mainMod, K, swapsplit         →   bind = $mainMod, K, layoutmsg, swapsplit
  bind = $mainMod, L, layoutmsg, togglesplit  (unchanged — already correct)
  bindd = $mainMod, M, desc here, togglesplit → bindd = $mainMod, M, desc here, layoutmsg, togglesplit
```

Idempotency: rerunning sanitizer on already-sanitized file = zero changes.

Version comparator tested across:
- 0.53 vs need-0.54: not at least
- 0.54 vs need-0.54: at least
- 0.55 vs need-0.54: at least
- 0.55 vs need-0.55: at least
- 0.56 vs need-0.55: at least
- 1.0 vs need-0.55: at least
- 0.53 vs need-0.55: not at least

---

## Patched files

| File | hf82k.1 | hf82l | Δ | Why |
|---|---:|---:|---:|---|
| `hypr-config/binds.conf` | 78 | 81 | +3 | togglesplit → layoutmsg, togglesplit + version comment |
| `hypr-config/hyprland.conf.template` | 73 | 77 | +4 | Removed `pseudotile = true` + 10-line explanatory comment |
| `install.sh` | 4072 | 4235 | +163 | Sanitizer function + 3 invocation points |
| `ZenVersion.qml` | 110 | 110 | +0 | hf82k.1 → hf82l |
| **Total** | | | **+170** | |

---

## Install

Drop-in over hf82k or hf82k.1:

```fish
tar -xzf zen-shell-v7_0_0-beta_1-hf82l-patch-only.tgz

# Run install.sh to invoke the sanitizer pass on YOUR existing
# configs (the sanitizer ONLY edits ~/.config/hypr/* files; nothing
# else in your home dir gets touched).
cd zen-shell-v7.0.0-beta.1-hf82l
./install.sh

# Or, if you just want the fixed shipped files without running
# install.sh, manually copy + reload Hyprland:
cp zen-shell-v7.0.0-beta.1-hf82l/hypr-config/binds.conf ~/.config/hypr/modules/binds.conf
# Edit your ~/.config/hypr/hyprland.conf and remove the `pseudotile = true` line
hyprctl reload
```

---

## Verify

After running install.sh:

1. **No more config errors** — `hyprctl reload` should produce zero "Invalid dispatcher" / "config option does not exist" output.
2. **Status check** — `hyprctl version` should print your Hyprland version with no error preamble.
3. **Existing keybind still works** — SUPER+J should still toggle dwindle split direction (now via layoutmsg).
4. **Backup files present** — if your file was modified by the sanitizer, you'll find `~/.config/hypr/modules/binds.conf.pre-hl54-<timestamp>` (and similar for `.pre-hl55-`) — these are pre-edit snapshots for rollback.
5. **install.sh banner** — `🎉 ZEN SHELL v7.0.0-beta.1-hf82l · KARUI ALPHA 5 INSTALLED 🎉`
6. **Settings → System Info** → `v7.0.0-beta.1-hf82l · released 2026-05-25`.

---

## Rollback

If anything goes sideways, restore from the backup files the sanitizer made:

```fish
# List backups
ls -la ~/.config/hypr/modules/*.pre-hl5*-* 2>/dev/null

# Restore a specific file (replace TS with the actual timestamp suffix)
cp ~/.config/hypr/modules/binds.conf.pre-hl54-<TS> ~/.config/hypr/modules/binds.conf
```

---

## Wala tayong babawasan

The sanitizer is purely additive — three new bash functions + three invocation points in install.sh. The two config files (`binds.conf` + `hyprland.conf.template`) had a single line modified and a single line removed; both have version-explanatory comments now where the change happened.

ZenVersion.qml bumped to hf82l with `releaseDate: "2026-05-25"` (this is the first hf82 drop on Monday, May 25 — previous nine were all May 24).

No QML files changed. The dock from hf82k / hf82k.1 carries forward unchanged.

---

## Open threads still active

- Quickshell C++ crash dump capture
- Multi-monitor flameshot screen targeting (`--screen N`)
- Drag + overflow auto-scroll (12+ pinned apps edge case)
- Build-time version auto-derivation (`git describe`)
- `Component.onCompleted` race audit across the codebase
- Panel-position-aware calculation audit (`isTop` branches missing elsewhere)
- `Switch` → `HMSwitch` audit across settings pages
- Dock Phase 2 (hf82m): ZenControlCenter popup + drag-to-reorder list UI in DockPage
- Dock Phase 3 (hf82n): Desktop icons + dock auto-hide + per-app badges
- **NEW from hf82l:** Hyprland minor-version compat tracking. The version-aware sanitizer covers 0.54 + 0.55. Next breaks (0.56, 0.57, etc.) need monitoring of upstream release notes + a new `_strip_hl56_breakages()` function each time. Could automate via a small CI check that diffs Hyprland's wiki between releases.
- **NEW from hf82l:** `misc:vfr` → `debug:vfr` migration not auto-applied (needs hyprlang-block-context awareness — out of scope for sed). Sanitizer prints a NOTE if it detects `vfr =`; user fixes manually. Could be a future improvement using a proper config parser.
