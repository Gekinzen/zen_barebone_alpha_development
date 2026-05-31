# v7.0.0-alpha.2 — Karui (軽い) · Densho Foundation

**Channel:** alpha
**Codename:** Karui (軽い · "lightweight")
**Sub-theme:** Densho Foundation (伝承)
**Released:** 2026-05-08
**Branch:** `dev`

---

## What this drop adds

The first wave of the **Densho** ("tradition transmitted") identity —
Zen Shell's signature aesthetic of washi paper, sumi ink, shu-iro
vermilion, and kanji-primary affordances. Granular by design: a master
toggle plus four independent sub-toggles, each persisted separately.

### New singleton: `DenshoService.qml`

Central brain for the Densho identity. State at
`~/.local/share/zen-shell/densho.state`. Exposes:

- Five flags: `denshoMode` (master), `kanjiWorkspaces`, `verticalDate`,
  `seasonalKanji`, `brushSeparators`.
- Five derived booleans (`useKanjiWorkspaces` etc.) that components
  read — they're true only when master AND the relevant sub-toggle
  are both on. This keeps consumers stupid: one read per feature.
- Helpers: `workspaceKanji(n)` → 一二三四五…, `yearKanji(year)`,
  `weekdayKanji(jsDay)` → 月火水木金土日, `formatJpDate(date)` →
  "5月8日 金", `sekkiLabel()` → "立夏の候".
- 24-sekki (二十四節気) calendar with full kanji + romaji + English
  for each season. Auto-recomputes hourly to track the boundary
  crossings. Wraps the January edge correctly.

### New theme: `densho-hi.json` (light / day mode)

Kamishiro paper ground (`#F5EDDC`), sumi ink foreground (`#1A1410`),
shu-iro vermilion accent (`#B85540`), kogecha brown secondary
(`#6F4E37`), asagi pale aqua (`#6A8E8B`), ōgon gold (`#B8860B`).

### New theme: `densho-yoru.json` (dark / night mode)

Sumi ground (`#1F1816`), warm parchment foreground (`#E8DCC4`), softer
warm vermilion (`#D4715C`) for night-friendly contrast. Same palette
language, inverted ground.

### New components

- **`DenshoSeasonal.qml`** — Right-edge desktop column showing the
  current 24-sekki kanji column (e.g. `立夏の候`). Auto-rotates with
  the season. Hover surfaces a tooltip with romaji + English reading
  so users learn the sekki passively. Visibility gated by
  `DenshoService.useSeasonalKanji`.
- **`DenshoVerticalDate.qml`** — Drop-in Item for the Clock widget.
  Shows year as a vertical kanji column (`二〇二六`), thin sumi divider,
  then day-of-week kanji in shu-iro accent. Visibility gated by
  `DenshoService.useVerticalDate`.
- **`DenshoBrushSeparator.qml`** — Replaces hard 1px separator/underline
  rectangles with a brush-stroke fade gradient that lifts off at both
  ends. When `useBrushSeparators` is false, falls back to a flat 0.5px
  line so it's safe to use anywhere unconditionally.

### Modified files

- **`ZenWorkspaces.qml`** — One-line conditional that swaps
  `ZenConstants.workspaceIcon(...)` for `DenshoService.workspaceKanji(...)`
  when `useKanjiWorkspaces` is true. Font family also gets a CJK serif
  prefix so the kanji renders correctly. Inactive otherwise — full
  fallback to existing `PanelState.workspaceFormat` behavior.
- **`ThemesPage.qml`** — New `Densho · 伝承` SettingsSection injected
  after the ControlCenterBanner. Contains the master toggle, four
  sub-toggle rows, and a recommended-pairing hint card that surfaces
  only when master is on.

---

## How the toggle system works

```
denshoMode  AND  kanjiWorkspaces    →  DenshoService.useKanjiWorkspaces
denshoMode  AND  verticalDate       →  DenshoService.useVerticalDate
denshoMode  AND  seasonalKanji      →  DenshoService.useSeasonalKanji
denshoMode  AND  brushSeparators    →  DenshoService.useBrushSeparators
```

Components only read the derived `use*` booleans, never the raw
sub-toggles. This means the user can pre-configure their preferred
sub-toggle combination while master is OFF (no visible change), and
flipping master ON applies the chosen blend instantly.

Each flag persists independently, so disabling and re-enabling the
master remembers exactly which features the user prefers.

---

## How the seasonal kanji calendar works

`DenshoService.sekki[]` holds all 24 entries with `{kanji, romaji,
english, m, d}` where `m`/`d` is the calendar boundary. `_computeSekki(date)`
finds the latest entry whose threshold is on or before today, with a
correct wrap for January dates (which fall under the late-winter sekki
Daikan / Shōkan, defined in the table at `m: 1`).

A 1-hour Timer recomputes `currentSekki`. Date resolution is enough — the
sekki only change every ~15 days. `onUseSeasonalKanjiChanged` also
forces a recompute so users who enable the toggle mid-season see the
correct kanji immediately.

The right-edge column reads `currentSekki.kanji + "の候"` and renders one
character per row top-to-bottom, e.g. for Rikka: 立 / 夏 / の / 候.

---

## Mount points still pending (next drops)

The components are written and tested, but the **placement** in `Bar.qml`,
`Clock.qml`, and `DesktopWidgets.qml` is intentionally left for the
next drop alongside the broader **Densho Surfaces** restyle (alpha.3),
which will:

- Insert `DenshoVerticalDate` into `Clock.qml` as a leading child
- Mount `DenshoSeasonal` into `DesktopWidgets.qml` at right-edge
- Add a `DenshoBrushSeparator` underneath the WindowTitle in `Bar.qml`
- Restyle `ControlPanel.qml` and Quick Settings with Densho aesthetics
- Restyle `StartMenuPanel.qml` (Win11-style dual-pane with Densho treatment)

This split is deliberate — alpha.2 ships the **infrastructure** so
those mount points are pure placement work, not new logic.

---

## Files added

```
qml/DenshoService.qml          (NEW, ~225 lines)
qml/DenshoSeasonal.qml         (NEW, ~110 lines)
qml/DenshoVerticalDate.qml     (NEW, ~85 lines)
qml/DenshoBrushSeparator.qml   (NEW, ~80 lines)
themes-builtin/densho-hi.json  (NEW)
themes-builtin/densho-yoru.json (NEW)
```

## Files modified

```
zen-shell-v5/ZenVersion.qml    (bumped to v7.0.0-alpha.2)
zen-shell-v5/ZenWorkspaces.qml (conditional kanji label override)
zen-shell-v5/ThemesPage.qml    (Densho settings section)
install.sh                     (version strings)
README.md                      (banner update)
```

---

## Wala tayong babawasan

Every flag defaults to a state that's safe and reversible:

- `denshoMode: false` ships off. No visible change until user enables.
- All sub-toggles ship `true` so when user flips master on, they get
  the full Densho experience immediately. They can toggle individual
  features off afterward.
- `densho.state` doesn't exist on first launch — service writes
  defaults, components read them.
- Existing `themes-builtin/` unchanged. Two new themes added beside
  Modori, Tokyo Night, etc.
- `ZenConstants.workspaceFormats` (numbers, korean, chinese, japanese,
  roman, etc.) untouched — Densho kanji workspaces are an OVERRIDE
  layer on top, not a new format entry.

Rollback path: delete the 4 new QML files + 2 theme JSONs, revert the
two patched files to their alpha.1 versions. Or simpler: use the
Updates Panel snapshot system shipped in alpha.1.
