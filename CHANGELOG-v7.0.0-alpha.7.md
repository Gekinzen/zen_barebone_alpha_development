# v7.0.0-alpha.7 — Karui (軽い) · Cleanup + Polish

**Channel:** alpha
**Codename:** Karui (軽い · "lightweight")
**Sub-theme:** Performance trio · drop 2 of 3 · RAM hygiene + onboarding
**Released:** 2026-05-09
**Branch:** `dev`

---

## What this drop adds

Three major features in one drop, building on the perf trio kicked
off by alpha.5 LaptopMode:

### 1. ZenCleanupService — RAM cleaner + zombie reaper

Manual + automatic memory hygiene. Three operations bundled into a
single pkexec-prompted pipeline:

| Operation | What it does | Privileged? |
|---|---|---|
| **drop_caches** | `echo 3 > /proc/sys/vm/drop_caches` — frees pagecache + dentries + inodes | Yes (pkexec) |
| **compact_memory** | `echo 1 > /proc/sys/vm/compact_memory` — defragments free pages | Yes (pkexec) |
| **zombie reaper** | `kill -CHLD <ppid>` for each `<defunct>` process whose parent isn't init | No (user-space) |

#### Auto-trigger (aggressive — Paul's chosen behavior)

When free RAM drops below threshold (default 5%, configurable
1-20%), the service:

1. **Latches** the pressure state immediately
2. **Waits 60s** of sustained pressure (avoids flapping on momentary spikes)
3. **Fires cleanup** if `autoTrigger == true` AND not session-suppressed
4. **Resets latch** when free RAM recovers to threshold + 5% (hysteresis)

User can disable per-session via "Suppress this session" or
permanently via Settings toggle.

#### Three mount points (per Paul's "Both" choice)

**SysRow bar badge** (`MemoryPressureBadge.qml`):
- Hidden by default (zero width when memory healthy)
- Appears with red border + warning icon when `memoryPressure` becomes true
- Slow pulse animation while pressure sustained
- Click → triggers `freeMemoryNow()`
- Spinning refresh icon + blue color while cleanup running

**Settings → General → System Cleanup** section:
- "Free RAM now" button (turns into "Cleaning…" + disabled while running)
- Last cleanup result display (bytes freed + cumulative total)
- "Auto-trigger when memory low" switch
- Threshold stepper (1-20%, only visible if auto-trigger enabled)
- "Re-enable" button when session-suppressed

State persisted to `~/.local/share/zen-shell/cleanup.state`. Session
suppression deliberately NOT persisted (resets on each login).

### 2. Clipboard onboarding diagnostic

Replaces the cryptic "cliphist not running" empty state with a full
diagnostic panel that shows what's missing and how to fix it.

`ClipboardOnboardingService.qml` probes:

1. Is cliphist installed? (`command -v cliphist`)
2. Are watchers running? (`pgrep -af 'wl-paste.*cliphist'` — count of 0/1/2)
3. Does the DB exist? (`[ -e ~/.cache/cliphist/db ]`)

UI shows three checklist rows, each with:
- ✓ green check (OK) or ✗ red close (missing)
- Action button (Install / Start) when relevant
- Status sub-text (path, count, etc.)

#### Action buttons

- **Install** → spawns terminal (`alacritty`/`kitty`/`foot`/`xterm` in fallback chain) running `sudo pacman -S cliphist wl-clipboard`
- **Start** → spawns both `wl-paste --watch cliphist store` daemons via nohup (text + image)
- **Re-check** → re-runs the probe (also auto-fires 5s after Install/Start clicks)

After fixing all three, the panel naturally transitions to the
"Clipboard is empty — copy something to start" state, and as soon
as the user copies anything, entries appear.

### 3. SettingsSearchBar mounted in Hypr Control Center

Same component, same 240px width as ZenSettings header (per Paul's
"Same width everywhere" choice). The CC search bar:

- Filters results to `surface: "controlpanel"` (only CC entries surface)
- Routes selections to `ControlPanel.expandedTab` via tab name map
- Auto-expands the panel if collapsed when navigating

#### Ctrl+F overlay → Control Panel routing

The Spotlight-style overlay (alpha.6-hf2) already had Control Panel
entries indexed but logged-only on selection. Now wired:

```qml
// User picks a CC entry from Ctrl+F overlay:
1. root.pendingControlPanelTab = entry.page  // e.g. "wifi"
2. root.controlPanelVisible = true
3. ControlPanel.onVisibleChanged reads pendingControlPanelTab
4. expandedTab = pendingControlPanelTab
5. expanded = true
6. Tab flips, panel expands automatically
```

Connections-based fallback handler also catches the case where CC
is already open and user picks a different entry.

### 4. install.sh adds cliphist as recommended dep

Previous installs only checked for `wl-copy`. Now also checks for
`cliphist` and reports missing if absent. Doesn't auto-install
(needs interactive sudo) but surfaces the dep clearly so users
know to run `sudo pacman -S cliphist`.

---

## Files added

```
zen-shell-v5/ZenCleanupService.qml             (NEW, ~280 lines)
zen-shell-v5/ClipboardOnboardingService.qml    (NEW, ~140 lines)
zen-shell-v5/MemoryPressureBadge.qml           (NEW, ~80 lines)
CHANGELOG-v7.0.0-alpha.7.md                    (NEW, this file)
```

## Files modified

```
zen-shell-v5/ClipboardPanel.qml      (full diagnostic empty-state, ~200 lines added)
zen-shell-v5/GeneralPage.qml         (+ZenCleanup section, ~110 lines added)
zen-shell-v5/SysRow.qml              (+MemoryPressureBadge mount)
zen-shell-v5/ControlPanel.qml        (+SettingsSearchBar in header)
zen-shell-v5/shell.qml               (+pendingControlPanelTab state +
                                      CC nav handler + Connections fallback)
zen-shell-v5/ZenVersion.qml          (bumped to v7.0.0-alpha.7)
install.sh                           (+cliphist check, version strings)
```

---

## Behavior summary

### When you have a memory pressure event

1. **Free RAM drops below 5%** → red warning badge appears in SysRow
2. **You can ignore it** → badge pulses gently, doesn't auto-fire yet
3. **60 seconds later, still under threshold** → auto-cleanup fires:
   - pkexec prompts for password (one prompt for the whole pipeline)
   - Drop caches + compact memory + reap zombies happen in sequence
   - Notification shows freed bytes when done
4. **Memory recovers above 10% (5% threshold + 5% hysteresis)** → badge
   disappears, latch resets, auto-trigger ready for next event

### When you click the clipboard module on a fresh install

1. Panel opens, shows diagnostic empty state
2. Three checklist rows visible
3. Click "Install" → terminal opens with `sudo pacman -S cliphist`
4. Enter password, install completes, terminal closes
5. Click "Start" → spawns wl-paste watchers
6. Re-check after 5s → all three rows green
7. Copy anything (Ctrl+C) → DB initializes
8. Panel now shows entries on next refresh (5s polling)

### When you press Ctrl+F + type a CC term

1. Overlay opens centered on screen
2. Type "wifi" → Wi-Fi (Control Center) result appears with badge
3. Press Enter → overlay closes
4. Control Panel opens centered, expanded to Wi-Fi tab
5. Same flow for Bluetooth / Audio / Power / Brightness

---

## Wala tayong babawasan

- All v7 alpha.1-6 features carry forward (Updates, Densho, StartMenu,
  LaptopMode, Search + Clipboard).
- ZenCleanupService.autoTrigger defaults to TRUE (per Paul's
  "Aggressive" choice) but cleanup ONLY fires after 60s sustained
  pressure — not instantly. Single-shot dips don't trigger.
- pkexec prompts only once per cleanup pipeline (not three times)
  thanks to bundled bash -c command.
- ClipboardOnboardingService re-probes every 5s after action buttons
  + on-demand via Re-check button. Doesn't poll continuously.
- ClipboardService unchanged — onboarding service is parallel, not
  a replacement.
- SettingsSearchService index unchanged from alpha.6 — alpha.7 just
  consumes it from a new surface (Control Panel).
- SysRow tray icon order unchanged — MemoryPressureBadge inserted at
  start of RowLayout, all other icons shift right when visible
  (which is rare anyway since memory rarely hits the threshold).

---

## Algorithm verification

**Auto-trigger timing edge cases:**

- Drop to 4% → latch true → 60s timer starts
- 30s in, recover to 6% → still under hysteresis (5% + 5% = 10%) → latch held, timer keeps running
- 45s in, drop again to 3% → no change (latch still set, timer continues)
- 60s in → cleanup fires
- After cleanup, memory at 8% → latch held (still below 10%)
- After cleanup, memory at 12% → latch resets

This prevents:
- Quick dip-and-recover from triggering false cleanups
- Multiple cleanups firing within a 60s window
- Cleanup re-firing immediately on a slow recovery

---

## To install

```bash
tar -xzf zen-shell-v7.0.0-alpha.7-cleanup-polish.tgz
cd zen-shell-v7.0.0-alpha.7
./install.sh
qs -r
```

Recommended packages:

```bash
sudo pacman -S cliphist wl-clipboard
hyprctl reload   # so the autostart watchers fire
```

After install:

1. **Settings → General → System Cleanup** — try "Free RAM now"
   button (will pkexec prompt once)
2. **Click clipboard icon** with cliphist NOT installed → see
   diagnostic UI with action buttons
3. **Click clipboard icon** with cliphist installed → see normal
   empty state with "copy something to start" hint
4. **Press Ctrl+F + type "wifi"** → overlay → Enter → CC opens
   to Wi-Fi tab
5. **Settings → General** scroll down → adjust auto-cleanup
   threshold (default 5%)

---

## Coming next

Per master roadmap:

- **alpha.8** — Spotlight command palette (Super+Space) — extends the
  Ctrl+F overlay with apps + files + actions search
- **alpha.9** — Densho restyle (ControlPanel + QuickSettings + brush
  separators + bilingual page headers)
- **alpha.10** — Zen Notification Center (full SwayNC replacement)
- **alpha.11+** — workflow profiles, workspace overview, etc.
- **beta.1-3** — polish + docs
- **v7.0.0** — stable
