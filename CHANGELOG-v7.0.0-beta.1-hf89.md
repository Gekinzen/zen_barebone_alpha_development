# Zen Shell v7.0.0-beta.1-hf89 — Karui (軽い)

Release date: 2026-05-30
Channel: beta · Codename: Karui (軽い)

**Load-error hotfix for hf88.** Wala tayong babawasan.

---

## Fix: shell failed to load — DisplaysPage button

hf88 (via the hf87 button migration) failed to load:

```
DisplaysPage.qml[671]: Cannot assign to non-existent property "font"
```

Cause: the Refresh button in DisplaysPage was written **inline on one
line** (`Button { text: "\uf021 Refresh"; font.family: "..."; onClicked: ... }`).
The hf87 auto-migrator's parser assumed one property per line, so for
this single-line button it converted `Button` → `ZenButton` but left the
`font.family:` assignment in place. `ZenButton` has no `font` group
property → hard load error (and Quickshell stops at the first error, so
the whole shell wouldn't start).

Fix:
- **`DisplaysPage.qml`** — the button is now a proper `ZenButton`:
  glyph → `iconText: "\uf021"`, label → `text: "Refresh"`, `font.family`
  dropped, `onClicked` kept.

## Audit: all other converted buttons verified

Ran a validator over **every** `ZenButton` block in the codebase
checking each property against the component's real API. Result: **0
invalid properties** anywhere else — DisplaysPage's inline button was the
only casualty. Also confirmed no converted `ZenButton` carries an `id`
referenced elsewhere with `Button`-only API (`checked`/`down`).

---

## Files touched

```
ZenVersion.qml    → v7.0.0-beta.1-hf89
DisplaysPage.qml  inline Refresh button → valid ZenButton
```

Carries forward hf83–hf88 in full (uniform module height, Quick Settings
position, ZenButton migration, dotfile clone, custom PNG icons, dock
reserve-space, single-widget desktop icons, fit-contents, etc.).

> Lesson logged for the roadmap open-threads: the button auto-migrator
> mis-handles single-line (`;`-separated) `Button` blocks. If more inline
> buttons surface, convert them by hand (glyph → iconText, drop
> `font.*`).
