# v7.0.0-alpha.6-hf1 — Singleton root type fix

**Channel:** alpha (hotfix)
**Released:** 2026-05-09
**Branch:** `dev`

---

## What this hotfix fixes

### Shell failed to load on alpha.6

```
ERROR: caused by @MaterialIcons.qml[39:1]: Singleton is not a type
```

**Cause:** `MaterialIcons.qml` and `SettingsSearchService.qml` used
`Singleton { ... }` as their root QML type, but `Singleton` is
defined inside the `Quickshell` import — these two files don't
import Quickshell because they're pure data + functions (no Process,
no FileView, no Quickshell.env). The QML engine couldn't resolve
`Singleton` and bailed.

**Why DenshoService et al. worked:** they DO import Quickshell (they
use FileView for state persistence) — so `Singleton` is in scope.

**Fix:** changed both files' root from `Singleton {}` to `QtObject {}`
— the canonical Qt singleton base for data-only services. The
`pragma Singleton` directive on line 1 of each file is what actually
registers the file as a singleton; the root type just needs to be
something the QML engine can instantiate, which `QtObject` is
without any extra imports.

### Singleton audit (all 3 services I added in alpha.6)

| File | pragma Singleton | Imports Quickshell | Root type |
|---|---|---|---|
| `MaterialIcons.qml` | ✓ | ✗ (pure data) | `QtObject` ✓ |
| `SettingsSearchService.qml` | ✓ | ✗ (pure data) | `QtObject` ✓ |
| `ClipboardService.qml` | ✓ | ✓ (Process + FileView) | `Singleton` ✓ |

The third one was already correct — uses Quickshell APIs so its
import + Singleton root were valid.

---

## Files modified

```
zen-shell-v5/MaterialIcons.qml          (root: Singleton → QtObject)
zen-shell-v5/SettingsSearchService.qml  (root: Singleton → QtObject)
zen-shell-v5/ZenVersion.qml             (bumped to v7.0.0-alpha.6-hf1)
install.sh                              (version strings)
```

No other files touched. ClipboardService, ClipboardPanel,
ClipboardModule, SettingsSearchBar, PanelState, Bar, PanelPage,
ZenSettings all unchanged from alpha.6.

---

## Wala tayong babawasan

- All alpha.6 features intact: Settings search bar, Material icons,
  Clipboard service + panel + bar module.
- All alpha.1-5 features carry forward unchanged.
- `pragma Singleton` declaration preserved → both services still
  register globally as `MaterialIcons.icon(...)` and
  `SettingsSearchService.search(...)`.

---

## To install

```bash
tar -xzf zen-shell-v7.0.0-alpha.6-hf1-singleton-fix.tgz
cd zen-shell-v7.0.0-alpha.6
./install.sh
qs -r
```

Sorry sa miss ko sa main alpha.6 — should have caught the missing
Quickshell import vs Singleton type mismatch sa lint pass. The
qmlformat parser doesn't actually verify root-type imports at lint
time (only syntax structure), so the issue only surfaced when
quickshell tried to load the singleton at runtime.
