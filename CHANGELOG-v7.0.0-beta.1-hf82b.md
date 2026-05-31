# v7.0.0-beta.1-hf82b — Critical fix: GameProfileService FileView text() unwrap

**Channel:** beta (hotfix patch on hf82)
**Released:** 2026-05-22
**Branch:** `dev`
**Scope:** 1 file patched — `zen-shell-v5/GameProfileService.qml`

---

## What broke

User reported persistent SIGSEGV after hf82 install when Lark
notifications fired. Initial assumption was that hf82's Lark
sanitization (summary + appName) didn't fully close the crash
path — but the crash log told a different story:

```
[GameProfileService] games.json parse error:
TypeError: Property 'trim' of object function text() { [native code] }
is not a function
```

## Actual root cause

Quickshell's `FileView` exposes its loaded content via a
**callable** `text()`, not a plain string property. The
`gamesJsonReader.onTextChanged` handler was passing the function
reference (not the invocation result) to `_parseGamesJson(raw)`,
which then tried `raw.trim()` on what was actually a JS function.

```qml
// BROKEN since whenever learnedGames persistence was introduced:
onTextChanged: root._parseGamesJson(text)

// CORRECT:
onTextChanged: {
    const raw = (typeof text === "function") ? text() : text
    root._parseGamesJson(raw)
}
```

The error was caught silently by `_parseGamesJson`'s try/catch.
Result:

1. All persisted state from `games.json` was silently lost on
   every shell start: `classPatterns`, `titlePatterns`,
   `processPatterns`, `ignoreClasses`, `gpuBusyThreshold`,
   `learnedGames`, and (newly in hf82) `autoPowerSwitch`.
2. Repeated parse failures during shell warmup, paired with
   `FileView.watchChanges = true` re-firing on every `_queueSave`
   write, created a hot signal-handler loop that races with the
   notification handler. Under sustained notification pressure
   (Lark notification storm in the user's case), the race
   eventually triggers a use-after-free SIGSEGV during QML's
   signal slot dispatch — appearing as "Lark notification
   crashed the shell" when the real culprit was the FileView
   handler thrashing in the background.

## Fix

Two layers of defense in `GameProfileService.qml`:

### Layer 1 — gamesJsonReader.onTextChanged handler

Unwrap `text` correctly at the call site:

```qml
onTextChanged: {
    const raw = (typeof text === "function") ? text() : text
    root._parseGamesJson(raw)
}
```

Works regardless of whether the installed Quickshell version
exposes `text` as a callable or a plain property — both shapes
have shipped in 0.x releases.

### Layer 2 — _parseGamesJson defensive coercion

Even if a future call site forgets to unwrap, the function now
guards itself:

```qml
function _parseGamesJson(raw) {
    try {
        if (typeof raw === "function") raw = raw()
        if (typeof raw !== "string") return
        if (!raw || !raw.trim()) return
        ...
```

## Side effects (positive)

After hf82b install, persisted state from `games.json` correctly
loads on shell start for the first time since `learnedGames` was
introduced:

- Auto-learned games are remembered across reboots.
- Custom `classPatterns` / `titlePatterns` from
  `~/.config/quickshell/zen-shell/games.json` actually apply.
- The hf82 `autoPowerSwitch` toggle persists.
- The FileView reload loop no longer thrashes on every save →
  one less race vector during notification handling.

## File diff

| File | hf82 | hf82b | Δ |
|---|---:|---:|---:|
| `zen-shell-v5/GameProfileService.qml` | 790 | 821 | +31 |

Pure additive. No code paths removed. Existing behavior for users
without a `games.json` (fresh installs) is unchanged.

## Install

Drop-in the single file:

```bash
tar -xzf zen-shell-v7_0_0-beta_1-hf82b.tgz
cp zen-shell-v7.0.0-beta.1-hf82b/zen-shell-v5/GameProfileService.qml \
   ~/.config/quickshell/zen-shell/zen-shell-v5/

# Reload shell
pkill -f quickshell && sleep 1
quickshell -p ~/.config/quickshell/zen-shell &
```

Or use the full tarball as a complete reinstall via the existing
`install.sh` flow.

## Verification

Watch the log on relaunch. The TypeError line should be gone:

```bash
# Should now print clean game pattern compile messages instead:
grep -E "GameProfileService" ~/zen-shell-debug/crash-*.log | tail -5
```

If `games.json` exists, the next save (any toggle of
`autoPowerSwitch` in Settings → Gaming, or any game detection)
should serialize and persist correctly. Verify with:

```bash
cat ~/.config/quickshell/zen-shell/games.json
# Should now contain "autoPowerSwitch": <bool>, learnedGames: [...], etc.
```

---

## Why this slipped through hf82 review

The bug existed before hf82 (silently — caught by try/catch),
which meant the failing-load path was already the "normal" state
for every user. The hf82 changes added `autoPowerSwitch`
persistence on top of the same broken plumbing, but never
exercised a working load during testing because the existing
warning was assumed to be a benign "first install, no file yet"
notice. The Lark notification race exposed it as fatal under
production load. Lesson: test FileView round-trips explicitly,
not just write-then-read-back-in-same-session.

## Wala tayong babawasan

| File | Status |
|---|---|
| `GameProfileService.qml` | +31 lines, 0 removed. Header bumped hf82 → hf82b. The 1-line `onTextChanged` block was widened from inline expression to a 4-line block with type-check + invocation; the underlying behavior is now correct rather than always-fail-silently. The original `onTextChanged: root._parseGamesJson(text)` semantic intent is preserved and finally actually works. |

All other 6 files from hf82 are unchanged; if you've already
installed hf82, just drop in the single
`GameProfileService.qml` from this tarball.
