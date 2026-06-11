# Zen Shell v7.0.0-beta.1-hf96 — Karui (軽い)

Release date: 2026-06-11
Channel: beta · Codename: Karui (軽い)

**Two bug fixes: Settings → Input "Natural scroll" toggles now actually
work (mouse + touchpad invert), and the Super+W wallpaper picker's Online
tab can select/apply wallpapers again. Strictly additive — wala tayong
babawasan.**

---

## Changes

### 1. Mouse / touchpad invert toggle did nothing (HMSwitch double-emit)

**Symptom:** Settings → Input → "Natural scroll (mouse wheel)" and
"Natural scroll (touchpad)" toggles flipped visually but had no effect —
scroll direction never changed.

**Root cause:** `HMSwitch.qml`'s click handler emitted `toggled()` **twice**
per click. The `MouseArea.onClicked` set `_userToggled = true`, then did
`checked = !checked` — which synchronously fires the guarded
`onCheckedChanged`, emitting `toggled()` once — and *then* re-emitted
`root.toggled()` explicitly. Two emits per click.

Handlers that assign from the switch state (`= checked`) are idempotent
under a double-fire, so most of the 27 HMSwitch consumers were unaffected
and the bug stayed hidden. But flip-style handlers — `naturalScroll =
!naturalScroll` on the Input page — flipped twice, netting **no change**.
That's why it looked dead. `ControlPanel.qml`'s inline single-emit toggle
for the same setting worked, which confirmed the diagnosis.

**Fix:** removed the redundant explicit `root.toggled()` from `onClicked`.
The guarded `onCheckedChanged` now emits exactly once. This fixes mouse +
touchpad invert *and* the other 5 flip-style toggles in the shell.

### 2. Online wallpaper tab couldn't select a wallpaper (GitHub rate-limit)

**Symptom:** Super+W → Online tab → grid empty / nothing selectable.

**Root cause:** the Online listing comes from the GitHub **contents API**
(`api.github.com/repos/Gekinzen/images-demo/contents/wallpapers`), which is
throttled to **60 requests/hour per IP** when unauthenticated. During shell
development the shell restarts constantly; every restart hit the contents
API, the 60/hr budget drained, and the API started returning **HTTP 403**.
With the listing fetch failing, `items` stayed empty → empty grid → nothing
to click. The per-item download/apply path was fine; it just never had
items to act on. The empty-state text also wrongly showed the *local*-folder
message in online mode, hiding the real cause.

**Fix (all additive):**

- **TTL-gated cache.** A cached `listing.json` younger than `listingTtlSecs`
  (6 h) is used **without touching the network** — restarts no longer burn
  the rate-limit budget.
- **Raw manifest fallback.** Optional `manifest.json` on
  `raw.githubusercontent.com` (rate-limit-proof CDN) is tried if the
  contents API fails. No-ops cleanly if the file doesn't exist.
- **Stale-cache fallback.** If everything network fails, the last cached
  listing is reused so the grid isn't empty.
- Single atomic bash resolver with explicit source markers
  (`__ZEN_CACHE_FRESH__` / `__ZEN_API_OK__` / `__ZEN_MANIFEST_OK__` /
  `__ZEN_STALE_CACHE__` / `__ZEN_FETCH_FAILED__`).
- **Download guard.** A `downloading` flag ignores overlapping clicks so a
  second tap can't clobber the in-flight target index / callback.
- **Online-aware empty state.** Shows "Loading online wallpapers…", the real
  error (with a retry hint), or "No online wallpapers yet…" instead of the
  local-folder message. Refresh button force-pulls (bypasses TTL) in online
  mode.

> **Optional, to make the Online tab fully rate-limit-proof:** commit
> `images-demo/wallpapers/manifest.json` to the repo — either a plain array
> of filenames `["a.jpg","b.png"]` or an array of objects `[{"name":"a.jpg"}]`.
> The shell will prefer the contents API but fall back to this raw manifest,
> which has no API rate limit.

## Version

- `ZenVersion.qml` bumped `hf95.34` → `hf96` (releaseDate `2026-06-11`).

## Files touched

- `zen-shell-v5/HMSwitch.qml` — double-emit fix + comment
- `zen-shell-v5/WallpaperRepoService.qml` — TTL cache, manifest fallback,
  stale-cache fallback, download guard, source markers
- `zen-shell-v5/WallpaperPicker.qml` — online-aware refresh + empty state
- `zen-shell-v5/ZenVersion.qml` — version string + release date
- `install.sh` — changelog header entry (banner reads version dynamically)

No feature, setting, or file removed.
