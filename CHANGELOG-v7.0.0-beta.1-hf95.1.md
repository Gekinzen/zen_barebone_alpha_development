# Zen Shell v7.0.0-beta.1-hf95.1 — Karui (軽い)

Release date: 2026-05-30
Channel: beta · Codename: Karui (軽い)

**Deploy-time stale-file guard: corrected `sync-config.sh`'s self-verify
(it grepped the OLD property name and false-warned on every healthy
sync) and widened the verify in BOTH `sync-config.sh` and `install.sh`
from Workspaces-only to the full vertical-bar module set.** No QML
behaviour changed. Wala tayong babawasan.

---

## Background — the crash this guards against

`BarVertical.qml` builds the vertical bar by assigning `zenVertical: true`
to seven modules. If even one of their `.qml` files is stale in the live
config dir (`~/.config/quickshell/zen-shell/`) and predates the
`vertical` → `zenVertical` rename (hf91.1), the load aborts with:

```
ERROR: Type BarVertical unavailable
ERROR:   caused by @BarVertical.qml[..]: Cannot assign to non-existent property "zenVertical"
```

hf95 already fixed the *cause* in `install.sh` (clean-wipe stale top-level
QML + clear the compiled `*.qmlc`/`*.jsc` cache before copying). hf95.1
fixes the *detection* so a stale/missing module is reported accurately
for every vertical module, on both deploy paths.

## 1. `sync-config.sh` — verify corrected + generalized

- **Bug fix:** the self-verify searched for `property bool vertical`,
  but the property was renamed to `zenVertical` in hf91.1. The check
  therefore **always warned** ("STILL missing 'vertical'") even after a
  perfectly healthy clean sync — misleading you into thinking the sync
  failed. Now greps `property bool zenVertical`.
- **Widened:** verifies all seven vertical-bar modules
  (`Clock`, `MusicWidget`, `SysRow`, `SystemTray`, `Taskbar`,
  `WindowTitle`, `Workspaces`) and also flags any that are missing from
  the config dir entirely.
- Copy logic is **unchanged** — it already did a clean wipe + full copy
  + QML-cache clear (the parts that actually prevent the crash).

## 2. `install.sh` — verify widened

- Step `[4/9]` kept its existing `Workspaces.qml` `zenVertical` check
  (preserved verbatim — wala tayong babawasan) and now **additionally**
  loops the remaining six vertical modules, printing ✓ / a per-file
  warning. A stale copy of any one of them is now surfaced at install
  time instead of only Workspaces.

## 3. Version

- `ZenVersion.qml` `version` bumped `hf95` → `hf95.1` so the
  "Installed version:" line printed by both deploy scripts confirms the
  hf95.1 deploy logic is what's actually in your config dir.
- `versionRaw` left untouched (compare-logic field; unchanged by this
  scripts-only revision).

## Files touched

- `sync-config.sh` — verify block + header changelog note
- `install.sh` — step [4/9] verify loop (additive)
- `zen-shell-v5/ZenVersion.qml` — version string + header tag

No module `.qml` logic, no feature, no setting removed.
