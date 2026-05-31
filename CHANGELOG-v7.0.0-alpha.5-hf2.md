# v7.0.0-alpha.5-hf2 — desktop UX entry point

**Channel:** alpha (hotfix 2)
**Released:** 2026-05-08
**Branch:** `dev`

---

## What this hotfix fixes

### Manual override toggle was unreachable on desktops

**Issue:** In alpha.5/hf1, the whole "Laptop Mode" section in
Settings → Battery & Power was hidden on desktops (no laptop chassis,
no battery). The "Manual override on desktop" toggle — the ONLY way
for desktop users to access the Laptop Mode controls — was inside
that hidden section.

**Result:** chicken-and-egg. Desktop users could never reach the
override toggle through the UI to even know it exists.

**Fix:** Two-tier visibility:

1. **Section is always visible**. On desktops, the subtitle reads
   "Desktop hardware · enable manual override below to access controls".
2. **Mode dropdown / Status / charge limit / Endurance sub-toggles**
   only show when `isLaptop || manualOverride` is true (gated via a
   readonly `_showFull` property on the section).
3. **Manual override row** is always visible on hardware where
   `detectedAsLaptop === false` — that's the entry point users see
   on desktop installs. On real laptops, this row hides since it's
   not relevant (full controls are auto-shown).

### Behavior on Paul's desktop (Ryzen 5950X, no battery)

Before flipping override:

```
┌─ Laptop Mode ─────────────────────────────────────┐
│ Desktop hardware · enable manual override below   │
│ to access controls                                │
│                                                   │
│ ☐ Manual override on desktop                      │
│   Show full Laptop Mode controls on this desktop  │
└───────────────────────────────────────────────────┘
```

After flipping override on:

```
┌─ Laptop Mode ─────────────────────────────────────┐
│ Desktop hardware · manual override active         │
│                                                   │
│ Mode: [ Off ▾ ]                                   │
│ Status: Off · no battery                          │
│ Endurance: animation downgrade  ☐                 │
│ Endurance: aggressive idle      ☐                 │
│ ☑ Manual override on desktop                      │
└───────────────────────────────────────────────────┘
```

Note: charge-limit row stays hidden because the kernel doesn't expose
`charge_control_end_threshold` on a desktop (no battery).

### Behavior on detected laptop (unchanged)

Full controls visible immediately on first install. "Manual override"
row hides since it's not relevant (the section is already showing
because hardware is detected as laptop).

---

## Files modified

```
zen-shell-v5/BatterySettingsPage.qml   (visibility logic refactor)
zen-shell-v5/ZenVersion.qml            (bumped to v7.0.0-alpha.5-hf2)
install.sh                             (version strings)
```

LaptopModeService.qml unchanged from hf1 — service logic was correct,
only the UI gating was the bug.
