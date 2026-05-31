# Zen Shell v6.16.3.4.4 — The animations.conf is-never-sourced bug + UI consistency + version surface

**Release date:** 2026-04-24
**Branch:** `beta-v12.6.16.3.4.4`
**Base:** v6.16.3.4.3
**Status:** Beta — hotfix for issues found during 3.4.3 field testing

---

## TL;DR

Four follow-up issues surfaced immediately after 3.4.3 landed. One is
a **3-year-old config bug** that's been silently defeating every
animation preset switch since animations.conf was introduced — worth
reading the root-cause below even if you just want the patch.

```
┌─────────────────────────────────────────────────────────────────┐
│  FIX 1 · Animations switches actually APPLY now                 │
│          (hyprland.conf was never sourcing animations.conf —    │
│           look_and_feel.conf's animations{} block was winning)  │
├─────────────────────────────────────────────────────────────────┤
│  FIX 2 · Animations preset dropdown is now scrollable           │
│          (popup was growing past window edge → bottom half      │
│           of presets unclickable)                               │
├─────────────────────────────────────────────────────────────────┤
│  FIX 3 · Input page toggles match System Tray design            │
│          (stock Qt Switch → HMSwitch pill, same component       │
│           used by SysRowPage / ControlPanel / BatterySettings)  │
├─────────────────────────────────────────────────────────────────┤
│  FIX 4 · Current version shown in User Profile page             │
│          (new ZenVersion.qml singleton = single source of       │
│           truth; bump once, everywhere updates)                 │
└─────────────────────────────────────────────────────────────────┘
```

**Wala tayong binawasan.** All v6.16.3.4.3 fixes (4-fix bundle from
the previous drop) carried byte-identical.

---

## The big one — why preset switches silently did nothing

> *"nag switch ako ng animation mukhang hindi padin nag rereflect pre"*

**Root cause:** `~/.config/hypr/hyprland.conf` never had a
`source = ~/.config/hypr/modules/animations.conf` line. Neither the
canonical `hyprland.conf.template` nor the idempotent `install.sh`
appender added it. So the flow was:

```
┌──────────────────────────────────────────────────────────────┐
│  AnimationsPage.applyPreset("HyDe Diablo-2")                 │
│     ↓                                                         │
│  writes to ~/.config/hypr/modules/animations.conf            │
│     ↓                                                         │
│  hyprctl reload                                              │
│     ↓                                                         │
│  Hyprland re-parses hyprland.conf → sources                  │
│    autostart.conf, look_and_feel.conf, binds.conf, …         │
│     ↓                                                         │
│  look_and_feel.conf has its own animations{ } block          │
│  (zenSmooth, zenSnap — the defaults)                         │
│     ↓                                                         │
│  animations.conf is NEVER read → HyDe Diablo-2 is ignored    │
│     ↓                                                         │
│  User sees no change in actual animations, despite the       │
│  dropdown, preview pane, and state JSON all being correct    │
└──────────────────────────────────────────────────────────────┘
```

This was a silent bug because:
1. The file *is* written to (so inspecting disk looked fine)
2. The AnimationsPage reconciliation logic in 3.4.3 correctly
   matched the file content to the preset dict (so the UI looked
   fine — dropdown in sync with disk)
3. But Hyprland never loaded the file (so behaviour stayed default)
4. The default `look_and_feel.conf` animations were visually close
   enough to "Default (Current)" preset that most users couldn't
   tell when a preset "worked"

**Fix:** two edits.

1. `hyprland.conf.template` — add `source = animations.conf` directly
   after `look_and_feel.conf`. Placement matters: Hyprland's
   last-write-wins semantics mean the later source overrides the
   earlier `animations{ }` block.
2. `install.sh` — add idempotent appender lines (both in the main
   and fallback blocks) so existing users on an already-installed
   `hyprland.conf` get the source line added without touching
   anything else.

Placement order after this fix:

```
source = ~/.config/hypr/modules/autostart.conf
source = ~/.config/hypr/modules/look_and_feel.conf       # default animations{}
source = ~/.config/hypr/modules/binds.conf
source = ~/.config/hypr/modules/animations.conf          # ← preset wins
source = ~/.config/quickshell/.../hyprland-layer-rules.conf
…
```

**Testing note:** Existing users will have the `animations.conf`
file already populated (AnimationsPage wrote to it). So right after
the 3.4.4 install + `hyprctl reload`, whatever preset was "stuck"
in the dropdown will IMMEDIATELY become live. If you had HyDe
Diablo-2 selected but the animations looked default, they're about
to actually be HyDe Diablo-2 for the first time.

---

## Fix 2 — scrollable preset dropdown

> *"hanggang Optimized lang ako hindi ko na ma-click sa ibaba"*

The stock Qt Controls ComboBox popup grows to fit its full model.
With 21 presets at ~36px each, that's ~760px of popup — taller than
the Settings window at 720px. Presets at the bottom (Standard,
Vertical, Elifouts, Linuxfam) extended past the window edge and
their hitboxes landed off-screen → unclickable.

**Fix:** override the popup with:

- `implicitHeight: Math.min(contentHeight, 280)` — caps popup at ~8
  visible rows
- `ListView { ScrollIndicator.vertical: ScrollIndicator { active: true } }`
  — scrolls internally when content overflows
- `positionViewAtIndex(currentIndex, ListView.Center)` on open so
  the current selection is centred, making both directions
  scrollable without hunting

The popup now looks like this when opening with "Optimized" selected:

```
┌────────────────────┐
│ Ja (JaKooLit)      │  (scrolls up to reach Default)
│ LimeFrenzy         │
│ Me-1               │
│ Me-2               │
│ Minimal-1          │
│ Minimal-2          │
│ Moving             │
│ Optimized     ✓    │  ← highlighted, centred in viewport
│ Standard           │
│ Vertical           │  (scrolls down to reach Linuxfam)
└────────────────────┘ ▎ scroll indicator
```

Keyboard nav (↑/↓) still works — ListView auto-scrolls to keep
`currentIndex` in view.

---

## Fix 3 — Input page toggle design

> *"yun Input yung toggle design hindi syncronized, katulad dapat
>   nung System Tray natin toggle"*

`InputPage.qml` was using stock `Switch { }` (Qt Controls default —
the dated-looking macOS-style toggle). Everywhere else in the shell
uses `HMSwitch { }` — the rounded pill with the smooth-animated knob
that was standardized in v6.16.1.4 for design consistency.

**Fix:** two `Switch` → `HMSwitch` swaps in InputPage (mouse natural
scroll and touchpad natural scroll). The component API differs
slightly — HMSwitch doesn't auto-mutate its binding source on click;
instead `onToggled` fires and the consumer explicitly flips the
external state. This is the pattern used by SysRowPage and all other
pages that now use HMSwitch.

Before/after visual:

```
BEFORE (stock Switch)     AFTER (HMSwitch)
┌─────────────────┐       ┌─────────────────┐
│ [●OOO]  (dated) │  →    │ [●━━━]  (pill)  │
└─────────────────┘       └─────────────────┘
```

Now every toggle across Settings, Control Panel, Bar Modules, and
System Tray pages shares the same motion, hover, and colour language.

---

## Fix 4 — Version display in User Profile

> *"paki lagay sa current version natin sa profile yung versioning
>   natin now — everytime may babaguhin tayo update nanatin
>   versioning natin user profile"*

**Two changes:**

1. **NEW `ZenVersion.qml` singleton** — single source of truth.
   Any surface that needs the version string reads from this one
   file. Bumping the version on each release is a one-line edit:

   ```qml
   readonly property string version:     "v6.16.3.4.4"
   readonly property string versionRaw:  "6.16.3.4.4"
   readonly property string releaseDate: "2026-04-24"
   readonly property string channel:     "beta"
   readonly property string series:      "6.16.3.4"    // computed
   ```

2. **UserProfilePage.qml** — two updated rows in System Information:

   ```
   Shell     Zen Shell v6.16.3.4.4 · beta · Quickshell
   Version   v6.16.3.4.4  ·  released 2026-04-24
   ```

   Both rows bind to `ZenVersion.*` — when we cut v6.16.3.4.5,
   bump `ZenVersion.qml` once and these rows refresh automatically.

**Future uses of the singleton:**
- About popover in Start Menu footer
- "Zen Shell X.Y.Z" label on wallpaper lock screen
- Auto-update check (eventually) — compares `ZenVersion.versionRaw`
  against latest-released tag from the GitHub showcase

No more hand-chasing version strings across install.sh banners,
CHANGELOG filenames, and scattered UI surfaces.

---

## Files in this drop

### NEW

```
zen-shell-v5/ZenVersion.qml              ← Central version singleton
CHANGELOG-v6.16.3.4.4.md                  ← this file
```

### UPDATED

```
zen-shell-v5/AnimationsPage.qml           ← Scrollable ComboBox popup
zen-shell-v5/InputPage.qml                ← Switch → HMSwitch (2 places)
zen-shell-v5/UserProfilePage.qml          ← ZenVersion display (2 rows)
hypr-config/hyprland.conf.template        ← source = animations.conf
install.sh                                 ← 2x idempotent appender + banner bump
```

### CARRIED OVER

Everything from v6.16.3.4.3 byte-identical, including:
- BrightnessService singleton + Battery & Power brightness section (3.4.3)
- AnimationsPage preset reconciliation + external-edit detection (3.4.3)
- DesktopWidgets state-clobber fix for weatherBg/sysmonBg (3.4.3)
- Material You power profile pill (3.4.2)
- PowerBadge bar widget (3.4)
- …and everything else, untouched.

---

## Install / verify

```bash
tar -xzf zen-shell-v6.16.3.4.4.tar.gz
cd zen-shell-v6.16.3.4.4
./install.sh
~/.local/bin/zs-restart.sh
```

### Verify Fix 1 — animations.conf actually sourced now

```bash
grep "animations.conf" ~/.config/hypr/hyprland.conf
# Should output: source = ~/.config/hypr/modules/animations.conf
# If nothing, the install.sh appender didn't run — check for .bak
# backups and re-run install.sh.
```

Then in Settings → Animations:
1. Pick any preset that's visually distinct from your current look
   (e.g. "Vertical" or "HyDe Diablo-1")
2. Move a window — animations should match the preset (slide vertical,
   bouncing, etc.)
3. Pick "Disabled" — animations should literally stop (window appears
   instantly on open/close)

If animations still don't change after this, the source line didn't
get added. Manually edit `~/.config/hypr/hyprland.conf` and add:

```
source = ~/.config/hypr/modules/animations.conf
```

Place it AFTER the `look_and_feel.conf` source line.

### Verify Fix 2 — scrollable dropdown

Open Settings → Animations → click the preset dropdown. Should see
a compact popup (~280px tall) with a scroll indicator on the right.
All 21 presets should be reachable via scroll + click. Keyboard
arrow keys should scroll smoothly.

### Verify Fix 3 — Input toggles

Open Settings → Input. The two toggles ("Natural scroll" under Mouse,
"Natural scroll (touchpad)" under Touchpad) should be pill-shaped
with smooth knob animation — identical to the toggles on System Tray
and Bar Modules pages.

### Verify Fix 4 — version in User Profile

Open Settings → User Profile → scroll to System Information section.
Should now show:

```
Shell     Zen Shell v6.16.3.4.4 · beta · Quickshell
Version   v6.16.3.4.4  ·  released 2026-04-24
```

---

## Next up

Queued post-3.4.4:

- Diagnose bar PowerBadge invisibility (widget files deployed but
  not rendering — ongoing since 3.4.1)
- **v6.16.3.5** — Start Menu logo image picker
- **v6.16.3.6** — Clock hover popup parity with CPU/Memory hover
- **v6.16.3.7** — Universal widget auto-resize (DPI / scale aware)
- **v6.16.3.8** — Idle / lid / sleep UX (dropdown thresholds, auto-lock cascade)
- **v6.16.4** — Global Hyprland configreloaded IPC listener

Phase 4 (Hyprland dark mode + hyprbars + auto-clean memory + window
tile/float policy) still queued after the 3.x series wraps.
