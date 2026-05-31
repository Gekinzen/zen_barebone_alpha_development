# v7.0.0-alpha.3 — Karui (軽い) · Densho Surfaces

**Channel:** alpha
**Codename:** Karui (軽い)
**Sub-theme:** Densho Surfaces (伝承 表面)
**Released:** 2026-05-08
**Branch:** `dev`

---

## What this drop adds

This is the **mount + restyle** drop. alpha.2 shipped the Densho
infrastructure (toggles, components, themes); alpha.3 wires them into
their host surfaces so flipping Densho mode actually transforms what
you see.

When Densho mode is OFF, every surface looks identical to alpha.2.
When ON, the following changes take effect:

### Bar — Start button → 禅 logo

`StartMenu.qml` now hides its distro logo image and shows a thin
shu-iro circle with the kanji `禅` (Zen) centered. The hover state
brightens the ring opacity to match the existing button feedback.

### Bar — Workspace labels (already shipped in alpha.2)

`ZenWorkspaces.qml` swaps in 一二三四五… kanji workspace labels —
no change since alpha.2 (carrying forward).

### Clock — Vertical kanji year column

`Clock.qml` now mounts `DenshoVerticalDate` as the leading child of
the existing RowLayout. When `useVerticalDate` is on:

- Kanji year column renders top-to-bottom (e.g. 二/〇/二/六)
- Thin sumi divider
- Day-of-week kanji in shu-iro accent (月火水木金土日)
- The Nerd Font clock-face icon (\uf017) auto-hides since the kanji
  column already serves as the leading visual anchor

When off, layout is unchanged from alpha.2.

### Desktop — Right-edge seasonal kanji column

`DesktopWidgets.qml` mounts `DenshoSeasonal` anchored to the right
edge, vertically centered. Renders the current 24-sekki seasonal
kanji as a vertical column (e.g. for May 8: 立/夏/の/候).

Sits at z=0 (above wallpaper, below interactive widgets), so click
events still pass through to widget surfaces underneath.

Hover surfaces a tooltip with the romaji + English meaning.

### Settings — Bilingual sidebar

`ZenSettings.qml` navigation gets a complete bilingual treatment when
Densho mode is on:

**Section headers:**

| Key | Default | Densho |
|---|---|---|
| APPEARANCE | `APPEARANCE` | `外観 · APPEARANCE · GAIKAN` |
| INPUT & DISPLAY | `INPUT & DISPLAY` | `入出力 · INPUT & DISPLAY · NYŪSHUTSURYOKU` |
| CONNECTIVITY | `CONNECTIVITY` | `接続 · CONNECTIVITY · SETSUZOKU` |
| SYSTEM | `SYSTEM` | `系統 · SYSTEM · KEITŌ` |
| OTHER | `OTHER` | `その他 · OTHER · SONOTA` |

**Nav items** (all 14):

| Page | Default label | Densho kanji | Romaji |
|---|---|---|---|
| general | General | 一般 | Ippan |
| decoration | Decoration | 装飾 | Sōshoku |
| animations | Animations | 動き | Ugoki |
| themes | Themes | 主題 | Shudai |
| displays | Displays | 画面 | Gamen |
| input | Input | 入力 | Nyūryoku |
| panel | Panel | 板 | Ban |
| barmodules | Bar Modules | 部品 | Buhin |
| sysrow | System Tray | 系統盤 | Keitōban |
| connectivity | Sound & Network | 通信 | Tsūshin |
| notifications | Notifications | 通知 | Tsūchi |
| battery | Battery & Power | 電池 | Denchi |
| userprofile | User Profile | 利用者 | Riyōsha |
| updates | Updates | 更新 | Kōshin |
| widgets | Desktop Widgets | 飾り | Kazari |
| wallpaper | Wallpaper | 壁紙 | Kabegami |

**Layout when Densho is on:** kanji label (14px, Noto Serif CJK JP)
+ "English · Romaji" subtitle (11px), no Nerd Font icon. Active row
gets a 2px shu-iro vertical accent strip on the left edge plus a
subtle shu-iro fill (instead of the default blue accent).

When Densho is off: unchanged from alpha.2 — same Nerd Font icon
+ single label, blue accent on active.

---

## How it stays safe

Every patch is a pure conditional addition driven by
`DenshoService.denshoMode` or its derived `useX` properties:

- New components have `visible:` bound to the relevant `use*` flag
  and `width: visible ? N : 0` so they collapse to zero size when off
- The `iconText` in Clock.qml uses `visible: !DenshoService.useVerticalDate`
  to step out of the way when the kanji column takes over its role
- ZenSettings nav delegates duplicate the icon-mode and Densho-mode
  Text elements with `visible: !denshoMode` / `visible: denshoMode`
  guards. Toggling the master flag is a smooth visual swap, no
  layout reflow

The toggle widgets themselves are unchanged: still using
`SettingRow` + `Switch` from your existing component library.

---

## Files modified

```
zen-shell-v5/Clock.qml          (mount DenshoVerticalDate, hide nerd icon when on)
zen-shell-v5/DesktopWidgets.qml (mount DenshoSeasonal at right edge)
zen-shell-v5/StartMenu.qml      (禅 kanji overlay when Densho on)
zen-shell-v5/ZenSettings.qml    (bilingual nav: kanji + romaji subtitle)
zen-shell-v5/ZenVersion.qml     (bumped to v7.0.0-alpha.3)
install.sh                      (version strings)
README.md                       (banner)
```

## Files added

```
CHANGELOG-v7.0.0-alpha.3.md     (this file)
```

No new QML files in alpha.3 — all new logic lives in the
DenshoService / DenshoVerticalDate / DenshoSeasonal /
DenshoBrushSeparator files shipped in alpha.2.

---

## What's still pending

- **Bar — brush separator under window title** — DenshoBrushSeparator
  shipped in alpha.2 but not yet mounted into Bar.qml. Deferred to a
  later drop because the WindowTitle.qml internal layout needs more
  surgery than a single-line conditional.
- **Page header bilingualification** — each individual settings page
  (BarModulesPage, GeneralPage, etc.) still renders its hardcoded
  English title at the top. Next pass.
- **Widget icon overrides** — sumi-e cloud for weather, brush note
  for music, kanji label for CPU. Pending alpha.4.
- **ControlPanel + Quick Settings + StartMenu Densho restyle** —
  alpha.4 scope.
- **Zen Notification Center (native QML, replaces SwayNC)** — alpha.5
  scope.

---

## Wala tayong babawasan

- Master toggle off → every surface identical to alpha.2 → identical
  to v6 baseline.
- Each component's mount uses `visible: bound-to-flag` with collapsing
  width/height so layout flow is unaffected when off.
- All existing nav data (label, icon, id) preserved on every entry.
  Densho fields (kanji, romaji) added as additional optional
  properties.
- No theme JSON changes since alpha.2.
- No state file format changes — `densho.state` schema unchanged.
- Rollback via Updates Panel snapshot system or `.bak-*` directory
  (still 7-day retention).
