# Zen Shell v7.0.0-beta.1-hf95.29 — Karui (軽い)

Release date: 2026-05-31
Channel: beta · Codename: Karui (軽い)

**The doctor now purges stale hyprbars builds and force-rebuilds against
your CURRENT Hyprland headers — fixing the "headers ver != running" error
that persists even when hyprctl and pacman report the SAME version.**
Wala tayong babawasan.

---

## Your situation (versions already match!)

You confirmed:
- running: `Tag: v0.55.2`
- installed: `hyprland 0.55.2-2.1`

Same version — so it's NOT a relogin/skew problem. The persistent
"Version mismatch (headers ver is not equal to running hyprland ver)"
means an OLD hyprbars `.so` — built against a previous Hyprland, before
your update — is still cached/loaded. A matching-version build just needs
to REPLACE that stale binary.

## What changed in the doctor

Before building:

1. **Unload** any currently-loaded hyprbars.
2. **Purge** every stale `*hyprbars*.so` from hyprpm dirs
   (`~/.local/share/hyprpm`, `$XDG_RUNTIME_DIR/hyprpm`, `/tmp/hyprpm`).
3. **Force rebuild** (not `--needed`) so even an already-installed package
   is recompiled against the CURRENT headers.

Plus smarter package choice:

- **Repo/tagged Hyprland (your case)** → tries the STABLE
  `hyprland-plugin-hyprbars` FIRST. The `-git` plugin often targets
  newer hyprland-git headers and would re-trigger the same mismatch.
- **git/dev Hyprland** → tries `-git` first.

## TL;DR for you

```
zen-hyprbars-doctor.sh
```

It will unload the stale plugin, rebuild the stable hyprbars against your
0.55.2 headers, symlink + load it. No relogin needed this time — versions
already match; we're just replacing the old binary.

## Version

- `ZenVersion.qml` bumped `hf95.28` → `hf95.29`.

## Files touched

- `scripts/zen-hyprbars-doctor.sh` — purge stale .so, force rebuild, build-aware package order
- `zen-shell-v5/ZenVersion.qml` — version string

No feature, setting, or file removed.
