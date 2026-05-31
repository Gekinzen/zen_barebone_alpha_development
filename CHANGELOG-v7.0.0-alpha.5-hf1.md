# v7.0.0-alpha.5-hf1 — LaptopModeService load fix

**Channel:** alpha (hotfix)
**Released:** 2026-05-08
**Branch:** `dev`

---

## What this hotfix fixes

### Shell failed to load on alpha.5

```
ERROR: caused by @LaptopModeService.qml[370:5]: Property value set multiple times
```

**Cause:** Three properties had `on<Property>Changed:` handlers
declared TWICE on the same Singleton root — once inline, once inside
a `Connections { target: root }` block at the bottom. QML treats
both as direct property assignments on the root object, and forbids
duplicate assignment with this exact "Property value set multiple
times" error.

The duplicates:

| Property | First decl | Second decl |
|---|---|---|
| `onModeChanged` | line 271 (governor) | line 370 (save) |
| `onAnimationDowngradeChanged` | line 318 (apply config) | inside Connections at 382 (save) |
| `onChargeLimit80Changed` | line 246 (apply limit) | inside Connections at 383 (save) |

**Fix:** Consolidated all multi-effect handlers into a single
`Connections { target: root }` block at the bottom of the file.
Properties that need both saving AND a side-effect (mode,
animationDowngrade, chargeLimit80, batteryCharging) get their
handler ONLY in the Connections block — each function does the
side-effect AND calls `saveDebounced.restart()`.

Properties that only need saving (manualOverride, aggressiveIdle)
keep their inline `on*Changed:` declarations.

Verified zero overlap between inline and Connections handlers — no
property declared in both places.

---

## Files modified

```
zen-shell-v5/LaptopModeService.qml   (handler consolidation, ~30 lines moved)
zen-shell-v5/ZenVersion.qml          (bumped to v7.0.0-alpha.5-hf1)
install.sh                           (version strings)
```

No other files touched. SystemMonitorService, WeatherService,
ZenStrings, BatterySettingsPage all unchanged from alpha.5.

---

## To install

```bash
tar -xzf zen-shell-v7.0.0-alpha.5-hf1-handler-fix.tgz
cd zen-shell-v7.0.0-alpha.5
./install.sh
qs -r
```
