# v7.0.0-alpha.11 — Karui (軽い) · Spotlight files + Densho restyle

**Channel:** alpha
**Codename:** Karui (軽い · "lightweight")
**Sub-theme:** File search in Spotlight + bilingual page headers
**Released:** 2026-05-09
**Branch:** `dev`

---

## What this drop adds

Two parallel tracks per master roadmap:

### Track 1: File search in Spotlight palette

New service: **`FileSearchService.qml`** (~150 lines)

Indexes the user's common directories on shell start + every 5 minutes:
- `~/Documents`
- `~/Downloads`
- `~/Desktop`
- `~/Pictures`

Strategy:
- `find -maxdepth 3 -type f` to walk efficiently (caps depth so huge
  trees don't blow up index time)
- Excludes hidden files (`.git`, `.cache`, `.tmp`, `.swp`)
- Caps result count at 5000 entries (enough for typical home use)
- Sorts by `mtime` descending so newest files surface first

Search API:
- `FileSearchService.search(query)` returns up to 8 matches
- Prefix-match on basename gets top score
- Contains-match gets mid score
- Returns Spotlight-compatible result entries with
  `surface: "file"` + `_filePath` payload

Spotlight integration:
- `SettingsSearchService.search()` now calls `FileSearchService.search()`
  and appends file results AFTER Settings + Apps results
- New surface label: "File"
- New icon: `description` (Nerd Font `\uf15b` document glyph)

Navigation handler:
```qml
} else if (entry.surface === "file" && entry._filePath) {
    FileSearchService.open(entry._filePath)
}
```

`FileSearchService.open()` calls `xdg-open` which routes to the user's
configured handler for the file's MIME type (text → editor, image →
viewer, PDF → reader, etc.)

#### Search result composition (alpha.11 final ordering)

```
1. Calculator result   (if math expression)   — top
2. Settings entries    (prefix → contains → keyword) — primary
3. Apps                (up to 5)              — secondary
4. Files               (up to 5)              — tertiary, new in alpha.11
```

So typing "resume" might surface:
- 📄 resume.pdf (in Documents) [File]
- 📄 resume_v3.docx [File]
- 📄 john_resume_2024.pdf [File]

And typing "2+2" still gives 🧮 4 [Calc] at the top.

### Track 2: Densho restyle (bilingual page headers)

New component: **`DenshoPageHeader.qml`** (~95 lines)

Reusable bilingual header for Settings pages. When `DenshoService.
denshoMode` is enabled, renders kanji-primary with romaji + English
subtitle. When disabled, falls back to plain English title.

Usage:
```qml
DenshoPageHeader {
    Layout.fillWidth: true
    title: "General"
    subtitle: "Window gaps, borders, layout, tearing, snap"
    kanji: "一般"
    romaji: "Ippan"
}
```

Densho mode ON:
```
一般           ← 28px Noto Sans CJK JP, primary
Ippan          ← 11px italic, romaji hint

General        ← 16px secondary
Window gaps, borders, layout, tearing, snap

━━━━━━━━━━     ← brush separator (if brushSeparators toggle on)
```

Densho mode OFF:
```
General        ← 22px primary
Window gaps, borders, layout, tearing, snap
                ← no brush separator
```

#### Pages migrated

- **GeneralPage** — title="General", kanji="一般" (Ippan)
- **ThemesPage** — title="Themes", kanji="色" (Iro)

More pages will adopt this in alpha.12+ — DenshoPageHeader is fully
additive, pages opt in at their own pace. Pages NOT using it still
work fine with their inline headers.

#### ControlPanel header bilingual

Quick Settings header now shows the kanji 操 (sou — "operation/control")
when Densho mode is on, stacked above the English "Quick Settings"
text:

```
☰  操              ← 13px kanji (Densho mode only)
   Quick Settings  ← 15px English
```

Brush separator below the header section:
- Implicit via the existing DenshoBrushSeparator pattern
- Hidden when Densho mode is off (no extra visual weight)

---

## Files added

```
zen-shell-v5/FileSearchService.qml      (NEW, ~150 lines)
zen-shell-v5/DenshoPageHeader.qml        (NEW, ~95 lines)
CHANGELOG-v7.0.0-alpha.11.md             (NEW, this file)
```

## Files modified

```
zen-shell-v5/SettingsSearchService.qml   (+FileSearchService integration,
                                            +"file" surface label)
zen-shell-v5/SettingsSearchOverlay.qml   (updated empty-state hint)
zen-shell-v5/MaterialIcons.qml           (+description, +folder icons)
zen-shell-v5/GeneralPage.qml              (header → DenshoPageHeader)
zen-shell-v5/ThemesPage.qml               (header → DenshoPageHeader)
zen-shell-v5/ControlPanel.qml             (header gets 操 kanji
                                             when Densho mode on)
zen-shell-v5/shell.qml                    (+file navigation handler)
zen-shell-v5/ZenVersion.qml               (bumped to v7.0.0-alpha.11)
install.sh                                (version strings)
```

---

## Wala tayong babawasan

- All alpha.10 features intact (Spotlight palette, slide-out + peek,
  scrollable pinned, drag pinned, app launching, calc)
- `FileSearchService` is fully additive — search still works without
  it (just no file results)
- `DenshoPageHeader` is opt-in — pages keep working with their old
  headers until they adopt the new one
- Densho mode toggle still controls visibility of all Densho features
  including the new bilingual headers + ControlPanel kanji
- All v6 + alpha.5–10 functionality carries forward

---

## Behavior summary

### Spotlight palette result types (alpha.11 final lineup)

| Query | Result | Action |
|---|---|---|
| `2+2` | 🧮 4 [Calc] | Enter copies to clipboard |
| `densho` | 🎨 Densho mode [Settings] | Enter opens Settings → Themes |
| `wifi` | 📡 Wi-Fi [Control Center] | Enter opens CC → Wi-Fi tab |
| `brave` | 🚀 Brave [App] | Enter launches Brave |
| `resume.pdf` | 📄 resume.pdf [File] | Enter opens with xdg-open |
| `screenshot` | Mix: matching files + matching settings | |

### Densho mode visual changes

| Surface | Densho OFF | Densho ON |
|---|---|---|
| GeneralPage header | "General" | 一般 / Ippan + "General" |
| ThemesPage header | "Themes" | 色 / Iro + "Themes" |
| ControlPanel header | "Quick Settings" | 操 + "Quick Settings" |
| (sidebar nav) | English labels | Kanji-primary (existing) |

---

## Verified

- ✅ All 9 modified/new files lint clean
- ✅ FileSearchService singleton properly declared
- ✅ FileSearchService consumed by SettingsSearchService (5 refs)
- ✅ "file" surface label registered
- ✅ shell.qml handles file open via FileSearchService.open()
- ✅ DenshoPageHeader component created
- ✅ GeneralPage + ThemesPage adopt DenshoPageHeader
- ✅ ControlPanel header has 操 kanji (2 refs — declaration + comment)
- ✅ description + folder icons added to MaterialIcons.nerdFallback

---

## To install

```bash
tar -xzf zen-shell-v7.0.0-alpha.11-files-densho.tgz
cd zen-shell-v7.0.0-alpha.11
./install.sh
qs -r
```

After install:

1. **Press Super+Space** → overlay opens
2. **Type partial filename** (e.g. "resume", "screenshot", any file
   you have in Documents/Downloads/Desktop/Pictures)
3. **See file results** marked with [File] badge
4. **Press Enter on a file** → opens with xdg-open
5. **Open Settings → General** → see kanji header (if Densho mode on)
6. **Toggle Densho mode** in Themes settings → headers swap between
   English-only and bilingual
7. **Open Control Panel** → header shows 操 + Quick Settings (Densho on)

---

## Roadmap update

```
✅ alpha.5 — LaptopMode
✅ alpha.6 — Search + Clipboard
✅ alpha.7 — Cleanup + Polish
✅ alpha.8 — Pinned drag + scroll
✅ alpha.9 — Auto-hide search + Super+Space
✅ alpha.10 — Spotlight palette (apps + calc)
✅ alpha.11 — Spotlight files + Densho restyle ← we are here
🎯 alpha.12 — Zen Notification Center (drops SwayNC)
   alpha.13 — Workflow Profiles + Workspace Overview
   alpha.14 — UnifiedOSDService + HotCornerService
   alpha.15 — Per-game profiles + BatteryHealthService
   ...
   beta.1-3 → v7.0.0 stable
```
