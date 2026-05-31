# v7.0.0-alpha.7-hf1 — Search bar layout fix + Material font auto-install

**Channel:** alpha (hotfix)
**Released:** 2026-05-09
**Branch:** `dev`

---

## What this hotfix fixes

User reported: search bar in Settings header still looked broken (icon
overlapping with placeholder text), and asked for Material font +
cliphist to be auto-installed via the existing optional-package offer
during install.sh.

### 1. Search bar layout reworked

**Cause:** The search icon was a bare `<Text>` element with no fixed
width. When Material Symbols Outlined isn't installed and the font
family chain falls through to JetBrainsMono Nerd Font, the glyph at
the search codepoint may render at a different width — pushing the
TextField left/right and overlapping the placeholder text visually.

**Fixes:**

- **Icon wrapped in fixed-width Item (18×18px)** — anchors.centerIn
  centers the glyph regardless of its rendered width
- **TextField padding stripped to 0** — Qt controls add implicit
  padding which competed with our anchors.leftMargin
- **Tighter row margins** — 8px (was 10px)
- **Shorter placeholder** — "Search…" (was "Search settings…") so
  it fits cleanly in 240px even with both icons visible
- **Slightly smaller icon size** — 16px (was 18px), better proportion
  to a 32px-tall bar
- **Clear button also wrapped** in fixed-width Item with width-animated
  transitions when the input gains/loses content

### 2. install.sh now offers Material Symbols font

Existing install.sh already auto-offers cliphist (added in alpha.7).
hf1 adds:

- **Font check via fc-list** — `fc-list | grep -iq 'Material Symbols Outlined'`
- **Auto-add to MISSING_OPTIONAL** if absent → existing Y/n offer
  flow installs via `paru -S --needed` (or `yay`/`pacman`)
- Package: `ttf-material-symbols-variable-git` (AUR — paru/yay handles)

Now when user runs install.sh on a fresh system, they get prompted
once like:

```
  Missing optional packages: cliphist ttf-material-symbols-variable-git ...

  Install optional packages with paru? [Y/n]
```

Hit `Y` → both deps install → restart shell → everything works.

### 3. MaterialIcons auto-detect via fc-list

Previously `materialAvailable` was a hardcoded `false` default.
Users had to manually edit MaterialIcons.qml after installing the
font. Now:

- A small async `Process` runs `fc-list | grep -iq 'Material Symbols Outlined'`
  on first singleton load
- On `INSTALLED` output → flips `materialAvailable = true` automatically
- All consumer surfaces (search bars, clipboard module/panel) auto-
  switch to Material codepoints + family without restart-needed-then-edit

So the flow becomes seamless:

1. install.sh → answer Y to the optional-deps prompt
2. Shell restarts → MaterialIcons probes fc-list → detects Material → flips flag
3. All Material UI surfaces render with crisp Material glyphs

If the user skips the install (answers `n`) → glyphs stay on Nerd
Font fallback (still readable, just less crisp).

---

## Files modified

```
zen-shell-v5/SettingsSearchBar.qml   (layout rework — fixed-width icons,
                                       tighter margins, padding fixes)
zen-shell-v5/MaterialIcons.qml       (added fc-list Process probe +
                                       auto-flip on detection)
install.sh                           (added Material Symbols font check)
zen-shell-v5/ZenVersion.qml          (bumped to v7.0.0-alpha.7-hf1)
```

No other files touched. ZenCleanupService, ClipboardOnboardingService,
ClipboardPanel, GeneralPage, SysRow, ControlPanel, shell.qml all
unchanged from alpha.7.

---

## Wala tayong babawasan

- All alpha.7 features intact
- `materialAvailable` retains its property declaration → users can
  still manually override (force false even when font is installed)
- Detection happens once at startup, no continuous polling
- Font check uses the same `fc-list` that install.sh uses → consistent
  detection logic between install-time and runtime
- Search bar API (surfaceFilter, navigateRequested signal) unchanged

---

## To install

```bash
tar -xzf zen-shell-v7.0.0-alpha.7-hf1-search-fix.tgz
cd zen-shell-v7.0.0-alpha.7
./install.sh    # answers Y to optional packages → installs Material font + cliphist
qs -r
```

After install:

1. **Search bar** in Settings header should render properly:
   `[🔍] Search…             [— ▢ ✕]`
   No icon-text overlap, clean 240px width
2. **Same in Hypr Control Center** header
3. If you answered Y during install.sh and Material font was
   installed, glyphs should now be crisp Material instead of Nerd
   Font fallback (the difference is subtle but noticeable on the
   clipboard panel + onboarding diagnostic icons)
