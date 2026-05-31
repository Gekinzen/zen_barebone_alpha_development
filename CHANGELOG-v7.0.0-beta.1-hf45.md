# v7.0.0-beta.1-hf45 — Bar layout save sync + Title Translator browser fallback

**Channel:** beta (hotfix)
**Released:** 2026-05-17
**Branch:** `dev`

---

## What this hotfix fixes

User report:

> "kung anu yun setup and pinili ko sa qml bar panel ko dapt kapag
> nag restart ako as is padin pre prang hindi ata na sasave yun mga
> setup ko last time. title translator panu ginagamit ito prang hindi
> ata gumagana e"

Two real bugs found in this round.

---

## Bug 1 — Bar layout reverting after restart

### Root cause

There are **two parallel state stores** for bar layout in the shell:

1. **`panel-state.json`** at `~/.config/quickshell/zen-shell/panel-state.json`
   — written by `PanelState.saveState()`. Contains barLayout, opacity,
   radius, styleMode, and many other panel settings.

2. **`bar-layout.json`** at `~/.local/share/quickshell/zen-shell/bar-layout.json`
   — written by external scripts (e.g. `~/.local/bin/zen-bar-add-powerbadge.sh`)
   triggered from the Bar Modules settings page. Contains only barLayout.

Both load on shell start and both can write to `Theme.barLayout`.

### The failure mode

```
T+0:   User toggles PowerBadge ON in Settings → Bar Modules
T+0:   Script writes "powerbadge" into bar-layout.json
T+0:   Theme.reloadBarLayout() re-reads bar-layout.json
       → Theme.barLayout updates in memory (UI shows badge)
T+0:   ← PanelState.saveState() is NEVER called!
       ← panel-state.json's barLayout STILL has the old value
T+X:   User restarts shell
T+X:   stateLoader reads panel-state.json
T+X:   applyState() sees s.barLayout (stale)
T+X:   Theme.barLayout = stale value
       → PowerBadge disappears, user thinks "setting reverted"
```

Same exact problem applies to **any** UI surface that mutates
`bar-layout.json` directly instead of going through
`PanelState.saveState()`.

### Fix

Added a `Connections` watcher in `PanelState` that observes
`Theme.barLayout`, `Theme.barOpacity`, `Theme.barRadius`, and
`Theme.styleMode`. Whenever ANY of these changes from ANY source,
PanelState fires a debounced `saveState()` automatically — keeping
`panel-state.json` in sync with the live state.

```qml
Connections {
    target: Theme
    function onBarLayoutChanged() {
        if (root._hf45_loaded) {
            console.log("[PanelState] hf45: Theme.barLayout changed externally")
            root.saveState()
        }
    }
    function onBarOpacityChanged()  { if (_hf45_loaded) saveState() }
    function onBarRadiusChanged()   { if (_hf45_loaded) saveState() }
    function onStyleModeChanged()   { if (_hf45_loaded) saveState() }
}
```

### Initial-load guard

The `_hf45_loaded` flag prevents the watcher from firing during the
shell's brief startup window — between PanelState instantiation and
stateLoader's onLoaded. Without this guard, the watcher would write
the DEFAULT Theme.barLayout to panel-state.json before applyState
had a chance to restore the user's saved layout — effectively
destroying their saved state on every launch.

The flag flips to true on the `panelStateLoaded()` signal which
fires AFTER applyState completes. From that point on, every Theme
mutation is treated as user-initiated and saved correctly.

### What this also fixes

Any third-party script, manual JSON edit, or future feature that
writes to `bar-layout.json` will now automatically sync to
`panel-state.json` too. No more "two sources of truth" surprises.

---

## Bug 2 — Title Translator not working

### Root cause: dead default backend

The hf39 default LibreTranslate URL was
`https://translate.argosopentech.com`. **As of 2026 that endpoint
is no longer reachable** — likely shut down or restructured.

Per the official LibreTranslate mirrors list, the only free public
instances that DON'T require an API key are now:

- `https://translate.cutie.dating`
- `https://translate.fedilab.app`

`libretranslate.com` itself now requires a paid API key.

So when the user clicked the bar module to translate a Japanese
title, the request went to a dead host, got no response (or a 502/
DNS error), the StdioCollector parse failed silently, and nothing
visible happened. Classic silent failure.

### Fix 1: Updated default backend

```qml
property string libreTranslateUrl: "https://translate.cutie.dating"
```

### Fix 2: Google Translate browser fallback

Even with a working LibreTranslate endpoint, public instances are
rate-limited and can become unreachable. So hf45 adds a far more
reliable interaction:

**Left-click the bar module → opens Google Translate in browser**

```
https://translate.google.com/?sl=ja&tl=en&text=<URL-encoded title>&op=translate
```

Launches via `xdg-open` (which all desktop Linux installs have).
Google Translate has no API key requirement, no rate limit for
casual use, and shows the FULL translation page with examples,
alternate translations, pronunciation — way more useful than the
inline tooltip ever was.

### Three click modes in hf45

| Click | Action |
|---|---|
| **Left-click** | Open Google Translate in browser (always works) |
| **Middle-click** | Inline LibreTranslate API attempt (for self-hosted users) |
| **Right-click** | Open Settings page |

### Fix 3: Automatic fallback when LibreTranslate fails

If the middle-click LibreTranslate API attempt fails (empty
response, parse error, network down, etc.), `browserFallback: true`
(default) auto-triggers the browser fallback. So the user ALWAYS
gets a translation no matter which click they used.

### Fix 4: Visible error state

New `lastError` property surfaces what went wrong (rate limit, 502,
parse error, etc.) for diagnostics. Tooltip / Settings page can
display this for users debugging their backend.

---

## Files changed (5)

```
zen-shell-v5/PanelState.qml              — Theme watcher Connections
                                             + _hf45_loaded guard
zen-shell-v5/Theme.qml                   — added hf42 default modules
                                             (quicknotes, titletranslator)
zen-shell-v5/TitleTranslatorService.qml  — new default URL
                                             translateInBrowser() function
                                             browserFallback property
                                             auto-fallback on API failure
                                             lastError property
zen-shell-v5/TitleTranslatorModule.qml   — 3-click action (left/mid/right)
                                             updated tooltip hint
zen-shell-v5/ZenVersion.qml              — bumped to hf45
install.sh                                — banner + changelog
```

---

## How to install

```bash
tar -xzf zen-shell-v7_0_0-beta_1-hf45-barlayout-sync-translator-browser.tgz
cd zen-shell-v7.0.0-beta.1-hf45
./install.sh
```

---

## How to verify

### Bar layout persistence

1. Open Settings → Bar Modules → toggle PowerBadge OFF (or ON)
2. **Restart the shell** (`Super+Shift+R` or `pkill quickshell`)
3. Toggle state should be preserved.

Also try with the Panel page module layout editor — add/remove
any module, restart, the change should stick.

### Title Translator

1. Open a browser, visit a Japanese site (YouTube, Twitter,
   Niconico, whatever)
2. Bar should show globe icon with `JA` badge
3. **Hover** the module → tooltip shows title + "Left-click: open
   in browser · Middle-click: inline API"
4. **Left-click** → Google Translate page opens in your default
   browser with the title pre-filled and translated to English

If you have a self-hosted LibreTranslate instance:

1. Settings → Productivity → Title Translator → set your URL
2. **Middle-click** the bar module → inline tooltip translation
   appears

If LibreTranslate fails for any reason → browser opens as a
fallback. No more silent failures.

---

## Wala tayong babawasan

All previous fixes preserved:

- ✅ hf44 custom theme profiles save full state
- ✅ hf43 Quick Notes panel clipping + rounded toggle pills
- ✅ hf42 modules visible + usage docs
- ✅ hf41 collapsible Settings search + Input tab sliders
- ✅ hf40 Quick Notes keybinds + sticky notes
- ✅ hf39 5 productivity features
- ✅ hf38 string colors + annotation transparency
- ✅ hf37 event-driven hot corners

Two real bugs, both invisible until you hit them. Now both stop
biting. 🍃
