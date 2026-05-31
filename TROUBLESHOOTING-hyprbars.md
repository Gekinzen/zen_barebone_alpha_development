# Hyprbars troubleshooting — `zen-hyprbars-doctor.sh`

If the title bars (hyprbars) won't load, or you see one of these toasts:

- `[hyprpm] Failed to load plugins: Outdated headers. Please run hyprpm update manually.`
- `[hyprbars] Failure in initialization: Version mismatch (headers ver is not equal to running hyprland ver)`

…run the doctor:

```bash
zen-hyprbars-doctor.sh
```

It's installed to `~/.local/bin/` by `install.sh`. To inspect without
changing anything first:

```bash
zen-hyprbars-doctor.sh --diagnose
```

## What it does, in order

1. **Detects your Hyprland build** — version, commit, and whether it's a
   git/dev build.
2. **Checks for a version SKEW** — running (`hyprctl`) vs installed
   (`pacman -Q hyprland`). If a recent `pacman -Syu` upgraded Hyprland but
   your session is still the old binary, it stops and tells you to **log
   out / back in (or reboot)**, then re-run. (No tool can bridge a live
   ABI mismatch.)
3. **Tries `hyprpm` first** (with sudo): `hyprpm update`, and if that hits
   the classic header failure it auto-runs **`hyprpm purge-cache`** and
   retries once (the official fix for "error code 4 / Headers version
   mismatched" on a clean build).
4. **AUR fallback** — if hyprpm still can't produce a matching build, it
   **purges any stale `hyprbars.so`**, then builds the plugin from AUR
   against your **system headers** (`/usr/include/hyprland`). It picks the
   right package for your build:
   - repo/tagged Hyprland → **stable** `hyprland-plugin-hyprbars` first
   - git/dev Hyprland → `hyprland-plugin-hyprbars-git` first
5. **Loads it** directly via `hyprctl plugin load` (works even when hyprpm
   marks the plugin failed), and verifies it's listed.

## Why these errors happen

`hyprpm` pins plugins to a Hyprland release tag and builds them against
headers it fetches for that tag. On fast-moving / CachyOS / git Hyprland,
or right after an upgrade, those headers don't line up with the running
compositor, so the plugin either won't build or won't initialise. The
doctor routes around that by building against your installed system
headers and loading the result directly.

## Prerequisites for the AUR path

- An AUR helper: `paru` or `yay`
- System Hyprland headers: the `hyprland` package (provides
  `/usr/include/hyprland`)

If either is missing, the doctor tells you exactly what to install.

## Making it stick

Once loaded, either toggle **Settings → Hyprbars** ON (Zen Shell remembers
and reloads it), or add the printed line to
`~/.config/hypr/modules/plugins.conf`:

```
plugin = /usr/lib/libhyprbars.so   # (path the doctor reports)
```
