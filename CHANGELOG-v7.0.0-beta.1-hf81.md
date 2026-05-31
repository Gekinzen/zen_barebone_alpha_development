# v7.0.0-beta.1-hf81 — Version pin (versions.lock)

**Channel:** beta (hotfix)
**Released:** 2026-05-19
**Branch:** `dev`

---

## What this hotfix adds

Zen Shell now soft-pins the compositor / runtime / Qt stack at release
build time. The maintainer's dev-machine versions of `hyprland`,
`quickshell` (or `quickshell-git`), `qt6-declarative`, `qt6-wayland`,
`qt6-5compat`, and `qt6-svg` are captured into a `versions.lock` file
at the repo root before each release tarball is cut. On install,
`install.sh` (and a lighter notice in `bootstrap.sh`) verify the
running user's installed versions against that lock.

### Pin policy

- **Patch (`.X`) auto-floats.** A user on `hyprland 0.54.5` installing
  a release built against `0.54.3` gets a silent ✓. Arch rolling
  bumps patches constantly; we don't want install.sh to whine about
  every routine update.
- **Minor mismatch (NEWER) → warn-only.** User on `hyprland 0.55.0`
  installing a release built against `0.54.x` sees a ⚠ but install
  proceeds. Hyprland tends to break syntax across minor versions
  (e.g. `windowrulev2 ` → `windowrule`), so this is a "look here
  first if something breaks" pointer.
- **Minor mismatch (OLDER) → block.** User on `hyprland 0.53.0`
  installing a release built against `0.54.x` is asked to confirm
  before continuing. Likely needs `paru -Syu` first.
- **Override at any time:** `ZEN_FORCE_VERSIONS=1 ./install.sh`.

### Wala tayong babawasan

Pure additive — no existing install path or feature was removed. The
new check runs as a `[0/9]` pre-stage before the existing `[1/9]
Dependency check…`, and only fires when `versions.lock` is present
and `scripts/zen-version-check.sh` is readable. Older release
tarballs without a `versions.lock` install exactly as before.

---

## New files

- **`versions.lock`** — at the repo root. The actual pinned values.
- **`scripts/zen-version-check.sh`** — sourced library. Exposes
  `zen_version_check_init`, `zen_version_check_report`, and
  `zen_version_verify`. Sets `ZEN_PIN_RC` to `0` (match), `1` (newer),
  or `2` (older) after running the report.
- **`scripts/zen-make-versions-lock.sh`** — maintainer-side generator.
  Run on the dev machine before tar-ing the release. Detects current
  versions via `hyprctl version` (preferred for hyprland) and
  `pacman -Q` (everything else). Strips git-revision tails from
  `quickshell-git` so the major.minor pin stays sane.

---

## Patched files

### `install.sh`

A new `[0/9]` block was inserted immediately before the existing
`[1/9] Dependency check…`. The block sources
`scripts/zen-version-check.sh`, initializes from `versions.lock`,
prints the per-package match/warn/block table, and gates on the
return code (block + interactive confirm for `rc=2`, warn-only for
`rc=1`, silent pass for `rc=0`).

### `bootstrap.sh`

Right before `[4/6] Install packages…`, a "Tested against"
informational table is now printed. `bootstrap.sh` doesn't block on
mismatches because nothing is installed yet — the gating happens
afterwards in `install.sh`.

### `scripts/zen-update-install.sh`

The `./install.sh --no-bootstrap` invocation now passes through
`ZEN_FORCE_VERSIONS` from the caller environment, so
`ZenUpdateService.qml` can launch a forced upgrade across a major.minor
boundary if the user opts in from the UI.

---

## Maintainer workflow

Every release, on the dev machine:

```bash
./scripts/zen-make-versions-lock.sh
git add versions.lock
git commit -m "lock: zen-shell-v7.0.0-beta.1-hf81 versions"
# … tar -czf the release tarball normally; versions.lock is at the root
```

The generator prefers `hyprctl version` over `pacman -Q hyprland`
specifically because it catches self-built / git variants where the
pacman record might lag behind the actually-running binary.

---

## User-facing behavior

| Scenario | Output | install.sh action |
|---|---|---|
| Installed = pinned (e.g. 0.54.3 vs 0.54.3) | `✓ hyprland : 0.54.3 (pinned 0.54.x — match)` | proceed |
| Installed = patch ahead (0.54.5 vs 0.54.3) | `✓ hyprland : 0.54.5 (pinned 0.54.x — match)` | proceed silently |
| Installed = minor ahead (0.55.0 vs 0.54.x) | `⚠ hyprland : 0.55.0 (NEWER…may have syntax/ABI breaks)` | proceed with warning |
| Installed = minor behind (0.53.0 vs 0.54.x) | `✗ hyprland : 0.53.0 (OLDER…upgrade required)` | prompt y/N |
| Package missing | `○ hyprland : not installed` | proceed (will be installed by `[1/9]`) |
| `ZEN_FORCE_VERSIONS=1` | `proceeding despite version drift.` | proceed regardless |

---

## Honest caveats

1. **Arch is rolling.** There's no clean way to say "give me 0.54.x
   specifically" via `paru -S`. True patch pinning requires Arch
   Linux Archive snapshots, which often breaks dependency chains.
   Soft-pin is the right tradeoff for "stable lage".
2. **`quickshell-git` version strings** look like
   `0.2.0.r123.g521ece4-1`. The checker strips down to the leading
   `MAJOR.MINOR.PATCH` for comparison. Re-run
   `zen-make-versions-lock.sh` whenever Quickshell upstream tags a
   new release that bumps major or minor.
3. **`qml --version` reports the Qt5 binary** from `qt5-declarative`,
   which is unrelated to Quickshell. The lock tracks `qt6-declarative`,
   which is what actually loads Zen Shell QML.
