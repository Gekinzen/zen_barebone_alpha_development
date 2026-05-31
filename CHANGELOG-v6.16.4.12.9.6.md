# v6.16.4.12.9.6 — Modori (戻り) · hotfix 6

**Channel:** alpha
**Release date:** 2026-05-06
**Predecessor:** v6.16.4.12.9.5 — Modori hotfix 5

## Summary

Two follow-up fixes on .9.5:

1. **Bulletproof sidebar user labels** — .9.5's Layout-system race
   fix didn't actually solve the problem. User reported labels
   STILL disappearing when the Settings window crossed monitors.
   Re-investigation found a deeper cause: `UserProfileService`
   itself transiently entered a bad state during the move (the
   avatar's fallback glyph showing instead of the photo confirmed
   the service's `effectiveAvatarSource` was returning empty —
   when a singleton's properties go null/empty, every binding
   pointing at it gets the empty value too). Fix: read username
   directly from `Quickshell.env("USER")` — that env var is
   populated at process start and never changes within the shell's
   lifetime. Hostname keeps `UserProfileService` as primary source
   but falls back to env `HOSTNAME` if the service is empty.

2. **README image URLs corrected** — the previous README rewrite
   in .9.4 referenced filenames like `hero_desktop.png` and
   `modori-wallpaper-dark.png` in the `zen_6_16_4_12_9_3/` demo
   folder. Those filenames don't exist there. The actual folder
   contains 6 UUID-named JPEGs (e.g. `139a7e9c-15f9-4a32-bf1c-
   01af9e733206.jpeg`). Fixed all six image references in the
   README's Modori sections to point to actual files in the demo
   repo, and added a new "Modori demo gallery" section showing
   all 6 images with both inline previews and "Open original"
   links to the GitHub blob URLs.

## Detail — sidebar user labels root cause

User screenshot from .9.5 testing showed:

- The bg2 Rectangle (the pill backdrop) — visible, correct width.
- The avatar circle — visible, but showing the BLUE FALLBACK GLYPH
  (`\uf007` fa-user) instead of the user's actual photo.
- The username + @hostname Text labels — completely missing.

The avatar fallback glyph appearing was the key clue. The fallback
fires when:

```qml
visible: !sidebarAvatarImg.visible
        || sidebarAvatarImg.status !== Image.Ready
        || sidebarAvatarImg.source.toString().length === 0
```

Specifically the third condition (`source.toString().length === 0`).
That means `sidebarAvatarImg.source` had become an empty string,
which happens when `UserProfileService.effectiveAvatarSource` is
empty. The singleton's whole identity surface had transiently
gone null.

The labels' `text` properties had this binding:

```qml
text: (typeof UserProfileService !== "undefined")
      ? UserProfileService.userName : Quickshell.env("USER")
```

The `typeof !== "undefined"` check passes (the singleton object
exists), but `UserProfileService.userName` was returning empty.
Texts elide to empty when their text content is empty.

## Detail — fix

Replaced the singleton-based bindings with cached env-read at
component-completed time:

```qml
Item {
    id: userTextWrap
    readonly property string _envUser: Quickshell.env("USER") || "user"
    readonly property string _envHost: Quickshell.env("HOSTNAME") || ""

    readonly property string resolvedName: {
        // Prefer service value (handles /etc/passwd full names)
        if (typeof UserProfileService !== "undefined"
            && UserProfileService.userName
            && UserProfileService.userName.length > 0) {
            return UserProfileService.userName
        }
        return _envUser
    }
    readonly property string resolvedHost: {
        if (typeof UserProfileService !== "undefined"
            && UserProfileService.hostname
            && UserProfileService.hostname.length > 0) {
            return UserProfileService.hostname
        }
        return _envHost
    }
    // ... Texts bind to userTextWrap.resolvedName / resolvedHost
}
```

`Quickshell.env("USER")` is populated at process start by the
shell's stdlib initialization. It NEVER becomes empty within the
shell's lifetime — no service-state involvement, no async
filesystem dependency, no race window. As long as the shell is
running, `_envUser` has a value.

The `resolvedName` / `resolvedHost` readonly properties prefer
the singleton (which can include /etc/passwd full names like
"Paul Hansen Yuki" instead of just "paul" if configured), but
fall back instantly when the singleton is empty. Texts bind to
the resolved properties, not the raw service values.

The sidebar avatar's fallback glyph still works the same — if the
service's `effectiveAvatarSource` is empty, the user-icon glyph
renders. That part is intentional and stays.

## Detail — README image URLs

The .9.4 README rewrite added a Modori showcase section with
references to `hero_desktop.png`, `modori-wallpaper-dark.png`,
and `modori-wallpaper-light.png` — assuming the demo repo had
been populated with those specific filenames. It hadn't. The
actual `zen_6_16_4_12_9_3/` folder in `Gekinzen/images-demo`
contains 6 UUID-named JPEGs:

```
139a7e9c-15f9-4a32-bf1c-01af9e733206.jpeg
6f6b715b-23ff-4848-9951-271b37c9d181.jpeg
88899f5d-988a-40a3-b617-11793c725ace.jpeg
ba068284-016a-4c0f-9558-d3a75856ed23.jpeg
caceb645-19f7-4d12-b7ce-dbac49945fbb.jpeg
cde0b11c-cf67-40ca-9153-5d88008cd884.jpeg
```

The README now uses these UUID filenames directly. Added a new
"Modori demo gallery" section listing all 6 images with inline
previews + "Open original →" GitHub blob links. The hero image
at the top of the README also points to the first jpeg in the
folder.

## Files changed

| File | Change |
|---|---|
| `zen-shell-v5/ZenVersion.qml` | Bumped to v6.16.4.12.9.6. |
| `zen-shell-v5/ZenSettings.qml` | Sidebar user-row inner Item: added cached `_envUser` / `_envHost` env-reads, `resolvedName` / `resolvedHost` properties that prefer service value but fall back to env. Texts bind to resolved properties instead of raw `UserProfileService.userName/hostname`. Comment block above explains the singleton-state race that .9.5's Layout fix missed. |
| `README.md` | Hero image at top + 6 demo images in Modori gallery section now reference actual UUID-named JPEGs in the `zen_6_16_4_12_9_3/` demo folder. New "Modori demo gallery" section with all 6 images + "Open original →" GitHub blob links. Codename history table extended to include .9.5 + .9.6. Top version line bumped. |
| `install.sh` | Banner version + success banner + final "Done. Enjoy" message bumped. |
| `CHANGELOG-v6.16.4.12.9.6.md` | NEW (this file). |

## Migration

```bash
cd zen_barebone_alpha_development
git pull
git checkout alpha-v6.16.4.12.9.6
./install.sh
pkill -x quickshell
qs -c zen-shell &
```

After the fix, the sidebar user labels should be present **at all
times** regardless of any window manipulation. Even if you SSH
into the system without a graphical session and somehow trigger
quickshell to load (which would normally fail other parts of
UserProfileService), the labels still render via env fallback.

## Carry-forward

All Modori .9.5 features preserved:

- Smart-contrast theme engine
- Modori Dark + Light themes + paired procedural wallpapers
- Default wallpaper switched to Modori Dark on fresh install
- Settings persistence fix
- Slider-drag save corruption fix
- Left/Right panel position cards hidden + L/R-to-Bottom
  migration safety net
- All Tachiagari .7.1 features

## Wala tayong babawasan

The user row UI is unchanged — same avatar circle (with shader
masking + fallback glyph), same username + @hostname text, same
hover-highlight border, same click-to-userprofile MouseArea. Only
the data path changed: env-first resolution instead of
singleton-first. UserProfileService is still the primary source
when it's populated; env is just the safety net for transient
empties.
