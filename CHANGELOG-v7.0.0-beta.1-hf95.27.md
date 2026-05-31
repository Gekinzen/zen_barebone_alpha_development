# Zen Shell v7.0.0-beta.1-hf95.27 — Karui (軽い)

Release date: 2026-05-31
Channel: beta · Codename: Karui (軽い)

**The hyprbars doctor now auto-runs `hyprpm purge-cache` and retries when
`hyprpm update` hits "Headers version mismatched" (error code 4) — the
official fix for that failure on a clean tagged Hyprland build.** Wala
tayong babawasan.

---

## Why this matters for your box

Your `hyprctl version` is a CLEAN tagged build (v0.55.2, all library
versions matching) — no skew, no dev build. On clean builds, hyprpm's
"error code 4 / Headers version mismatched" is almost always a STALE
cached header tree from a previous Hyprland version. Per the Hyprland
maintainers, the fix is `hyprpm purge-cache` then `hyprpm update` again.

## What changed

In the doctor's "try hyprpm first" phase:

1. Run `hyprpm update`. If it succeeds → enable hyprbars, done.
2. If it fails, AUTOMATICALLY run `hyprpm purge-cache` (and clean the
   `headersRoot` / cache dirs as a fallback for older hyprpm), then run
   `hyprpm update` ONCE more.
3. If the retry succeeds → enable hyprbars via hyprpm.
4. If it STILL fails → fall through to the AUR build against system
   headers, then direct `hyprctl plugin load`.

So the full auto order is now: relogin-check → hyprpm update → **purge-cache
+ retry** → hyprpm enable, else AUR fallback → direct load.

## How to use

```
zen-hyprbars-doctor.sh
```

Given your clean 0.55.2, the purge-cache retry alone will very likely fix
it without needing AUR at all.

## Version

- `ZenVersion.qml` bumped `hf95.26` → `hf95.27`.

## Files touched

- `scripts/zen-hyprbars-doctor.sh` — auto purge-cache + retry on header mismatch
- `zen-shell-v5/ZenVersion.qml` — version string

No feature, setting, or file removed.
