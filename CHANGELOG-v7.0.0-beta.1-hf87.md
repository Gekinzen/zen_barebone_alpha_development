# Zen Shell v7.0.0-beta.1-hf87 — Karui (軽い)

Release date: 2026-05-30
Channel: beta · Codename: Karui (軽い)

Two shipped; the rest of the turn's asks are pending answers (see
bottom). Additive. Wala tayong babawasan.

---

## 1. ZenButton — migrated across pages

`ZenButton` is now a true drop-in (added `highlighted` alias for
`accent`, `compact`, and `fontPixelSize`), and the plain platform
`Button {}` instances were migrated.

- **`ZenButton.qml`** — new shims so a `Button` converts cleanly.
- **25 buttons converted** across: Animations, AppFloatRules, BarModules,
  BatterySettings, DefaultApps, Displays, Dock, Panel, Plugins, Themes,
  UserManagement, Wallpaper, Widgets (+ the hf86 set:
  ControlCenterBanner, Desktop, UserManagement). Nerd-glyph labels were
  split into `iconText`; `highlighted` → `accent`.
- **19 buttons intentionally skipped** — these already have custom
  styling (`background:` / `contentItem:` / etc.) or live inline in a
  row, so they're not the "basic" ones and are left working as-is. Most
  are in UpdatesPage (already custom-styled), ThemesPage save/apply, and
  PageFooter. They can be hand-converted later if you want them on the
  exact ZenButton look.

> The migration was an automated, conservative pass (only simple
> `text` + `onClicked` (+ `enabled`/`highlighted`/`Layout`) blocks were
> touched; anything unusual was skipped, not risked). Brace-balance was
> verified on every converted file. Please sanity-check the converted
> pages on load and flag any that look off.

## 2. Content padding — can go beyond

The "Content padding (top/bottom)" range was raised from 0–24 to
**0–64**, so you can push the top/bottom breathing room much further.

- **`PanelState.qml`** — clamp raised to 64.
- **`PanelPage.qml`** — slider `to: 64`.

---

## Files touched

```
ZenVersion.qml   → v7.0.0-beta.1-hf87
ZenButton.qml    highlighted/compact/fontPixelSize shims
PanelState.qml   barContentPaddingV clamp → 64
PanelPage.qml    padding slider → 64
+ 13 pages       Button → ZenButton (25 buttons)
```

Carries forward hf83–hf86.

---

## Pending your answers (asked in chat — not built yet)
- **Draggable "same as music toggle"** — which surface should be
  drag-movable? (Quick Settings panel / dock / desktop widget?)
- **Panel position top/bottom "dito"** — which surface should get
  top/bottom positioning? (Quick Settings popup anchor?)
- **Module height "same as music strings"** — make all bar modules use
  one uniform height (= `Theme.moduleHeight`) so they line up like the
  music widget? (visual change — want to confirm before applying.)
- **Vertical music strings** when bar is on left/right — will ship with
  the vertical-bar (Tategaki) drop, since the strings need the vertical
  bar to attach to.
