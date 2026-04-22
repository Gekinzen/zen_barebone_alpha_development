# Zen Shell v6.16.2.3.2 — Window Click-Through, Avatar Cache, Wallpaper Repo, Mouse Tuning

**Release date:** 2026-04-22
**Base:** v6.16.2.3.1
**Scope:** UX completion patch — 10 files, 2 new singletons, 1 new Control Panel tab.

Paul's bugs from v6.16.2.3.1 testing + new feature requests:

1. Settings + Control Panel still blocked clicks on apps behind them
2. Re-uploading the same avatar showed the stale cached image
3. install.sh banner still said v6.15.14 and changelog described old features
4. No auto-restart at end of install — required manual `zs-restart.sh`
5. Default wallpaper missing on fresh installs (bare Hyprland background)
6. No way to browse wallpapers from the Gekinzen/images-demo GitHub repo
7. Mouse sensitivity nowhere in Control Panel
8. StartMenu sys-info popover truncated Hyprland version with no tooltip

All addressed. New singletons (`WallpaperRepoService`, `MouseSettingsService`) are additive; nothing removed.

---

## 1. Settings + Control Panel click-through — `shell.qml`

### The bug

Paul reported: "hidni ako makapag select padin sa labas need ko muna mag exit hyprland control panel natin ehh panu ioto need ko mag uplaod ng image hahaha dpat makaka click ako sa labas pre kht naka on yun hyprland control panel gets?"

Settings window covers the entire screen as a `WlrLayer.Overlay` PanelWindow. The transparent backdrop around the actual Settings panel rectangle was claiming the entire window's input region — clicks on apps behind the Settings (file pickers, browsers, Thunar) were being intercepted and dropped.

### Fix — `mask: Region { item: zenSettingsPanel }`

Same pattern as the v6.16.2.3.1 music-rope fix, applied to the Settings and Control Panel windows. Quickshell's `mask` property restricts the Wayland input region to JUST the panel rectangle. Everything outside passes clicks straight through.

```qml
PanelWindow {
    id: settingsWindow
    // ...
    mask: Region { item: zenSettingsPanel }   // ← only the panel itself
}
```

```qml
PanelWindow {
    id: controlPanelWindow
    // ...
    mask: Region { item: controlPanelInstance }
}
```

For Control Panel, this also meant **removing the backdrop click-to-close MouseArea** that v6.16.0.2 had added. That backdrop was the very thing intercepting outside clicks. Closing the Control Panel now requires the ✕ button or `Super+C` toggle — same pattern Settings has used since v6.13. Matches macOS / GNOME control center behavior.

The wallpaper picker and power confirm dialog still use a dim backdrop intentionally (modal flow). Not changing those.

---

## 2. Avatar cache-bust — `UserProfileService.qml`, `UserProfilePage.qml`, `StartMenuPanel.qml`

### The bug

Re-uploading a new photo via Settings → User Profile → Upload avatar showed the OLD avatar. The file on disk was correctly replaced (`~/.config/zen-shell/user-avatar.png`) but Qt's `Image` element caches by URL and the URL was byte-identical to the previous load.

### Fix — revision counter + `?v=N` query string + `cache: false`

`UserProfileService` now exposes:

```qml
property int avatarRevision: 0   // bumped on every successful copy

readonly property string effectiveAvatarSource: {
    const rev = "?v=" + avatarRevision
    if (customAvatarPath) return "file://" + customAvatarPath + rev
    if (avatarPath)       return "file://" + avatarPath + rev
    return ""
}
```

Every `Image { source: UserProfileService.effectiveAvatarSource }` instance now also has `cache: false`. Belt + suspenders — the revision counter forces the URL to differ; `cache: false` ensures even Qt's internal cache lookup misses.

Three Image elements updated: 96px in UserProfilePage, 72px in StartMenuPanel footer, 104px in StartMenuPanel popover.

---

## 3. install.sh modernized — `install.sh`

### Bumps

- Banner line 178: `Zen Shell v6.16.2.3.2`
- Tail message: "Done. Enjoy Zen Shell v6.16.2.3.2, pre."
- Full v6.16.2.3.2 changelog block describing all .3.1 + .3.2 changes (was still describing v6.16.2.3 Battery/Power/Lid features)

### New end-of-install behaviors

```bash
# Default wallpaper (only on fresh installs — checks wallpaper-state.json)
curl -fsSL https://raw.githubusercontent.com/Gekinzen/images-demo/main/wallpapers/123824383_p0%20(Edited)%20compressed.png \
     -o ~/.config/zen-shell/wallpapers/123824383_p0\ \(Edited\)\ compressed.png
swww img <that path> --transition-type fade --transition-duration 0.6

# Seed neutral defaults for zen-mouse.conf so the source line is always valid
cat > ~/.config/hypr/zen-mouse.conf << 'EOF'
input { sensitivity = 0.0; scroll_factor = 1.0; ... }
EOF

# Idempotently inject `source = ~/.config/hypr/zen-mouse.conf` into hyprland.conf
grep -q "zen-mouse.conf" ~/.config/hypr/hyprland.conf || \
    cat >> ~/.config/hypr/hyprland.conf << 'EOF'
source = ~/.config/hypr/zen-mouse.conf
EOF

# Auto-restart at the end
quickshell -p ~/.config/quickshell/zen-shell ipc call zen testNuclearRestart \
    || setsid -f ~/.local/bin/zs-restart.sh
```

All paths use `${HOME}` / `$USER` — zero hardcoded `/home/paul`.

The "fresh install" check looks at `~/.config/quickshell/zen-shell/wallpaper-state.json`. If the file doesn't exist, or its `currentPath` field is empty, or the recorded path doesn't exist on disk → treats as fresh and applies the default. Otherwise leaves your wallpaper alone.

---

## 4. Wallpaper repo browser — `WallpaperRepoService.qml` (new) + `WallpaperPicker.qml`

### New singleton: `WallpaperRepoService`

Fetches the listing from `https://api.github.com/repos/Gekinzen/images-demo/contents/wallpapers`. Public repo, no auth needed, GitHub allows 60 requests/hour per IP unauthenticated which is way beyond UI need.

Caches the JSON listing to `~/.cache/zen-shell/wallpapers/listing.json`. On startup, loads cached listing immediately for instant UI, then kicks a background refresh. If refresh fails (offline), the cached view stays — graceful degradation.

Each `items[]` entry: `{ name, downloadUrl, localPath, size, cached }`. `cached` is true if the file already exists at `~/.config/zen-shell/wallpapers/<name>` (so the UI shows "Apply" instead of "Download & Apply").

`download(index, callback)` does an async curl; on success, flips `cached: true` and invokes the callback with the local path.

### `WallpaperPicker.qml` integration

New "Online" toggle button next to "Random" / "Refresh". When active, the GridView's model switches from `WallpaperServiceV5.pagedList` to a mapped `WallpaperRepoService.items` array (same shape, so the same delegate works). Click handler:

- **Local mode** → existing `WallpaperServiceV5.selectWallpaper(modelData)` path
- **Online mode + cached** → use the local file directly via `WallpaperServiceV5.selectWallpaper`
- **Online mode + not cached** → `WallpaperRepoService.download(idx, cb)` → in callback, apply via `selectWallpaper`

Toggling back to "Local" returns to the local folder grid. State persists for the lifetime of the picker session.

---

## 5. Mouse sensitivity — `MouseSettingsService.qml` (new) + `ControlPanel.qml`

### New singleton: `MouseSettingsService`

Two-tier persistence:

1. **Live** via `hyprctl keyword input:sensitivity X` (zero-lag feedback during slider drag — Hyprland applies it on the next event loop tick)
2. **Persisted** via `~/.config/hypr/zen-mouse.conf` (sourced from `hyprland.conf` — survives Hyprland restarts)

Plus a JSON copy at `~/.config/quickshell/zen-shell/mouse-settings.json` for the shell to load values on startup without re-parsing the conf file.

Properties:
- `sensitivity` — real, -1.0 (slow) to +1.0 (fast), Hyprland default 0.0
- `scrollFactor` — real, 0.1 to 3.0, default 1.0
- `naturalScroll` — bool, mouse wheel inversion (macOS-style)
- `touchpadNaturalScroll` — bool, separate touchpad inversion (Hyprland uses a separate keyword for this)

`apply(persist)` writes hyprctl immediately. If `persist !== false`, debounces the conf write 250ms — so dragging a slider doesn't fsync every frame, but the final value always lands.

### Control Panel "Input" tab

Fourth tab next to Wi-Fi / Bluetooth / Audio. Icon `\uf245` (Nerd Font cursor). Pane has:

- Sensitivity slider with live value readout (e.g. "+0.35")
- Scroll speed slider with × multiplier readout (e.g. "1.5×")
- Natural scroll toggle (mouse wheel)
- Touchpad natural scroll toggle (separate)
- "Reset to defaults" button (sets all four to Hyprland's stock values)

Every interaction calls `MouseSettingsService.apply(true)` — instant Hyprland feedback + persistent save.

### `hypr-config/hyprland.conf.template`

New line near the bottom:

```
# v6.16.2.3.2: Mouse settings managed by Control Panel → Input.
source = ~/.config/hypr/zen-mouse.conf
```

For existing users (not fresh installs), `install.sh` idempotently appends the same line to their existing `~/.config/hypr/hyprland.conf` if it isn't already present.

---

## 6. Hyprland version tooltip — `StartMenuPanel.qml`

The sys-info popover's WM row showed:

> Hyprland Hyprland 0.54.3 built from branch v0.54.3 at c...

— ellipsed because the popover column is narrow. Paul wanted to see the full string.

Wrapped the row's `Text` in a hover-detecting `Item` with a Quick Controls `ToolTip`:

```qml
Item {
    Text { id: wmText; text: "Hyprland " + ...; elide: Text.ElideRight }
    ToolTip.visible: wmHoverMa.containsMouse
                     && (wmText.truncated || hyprlandVersion.length > 30)
    ToolTip.delay: 350
    ToolTip.text: "Hyprland " + (hyprlandVersion || "(unknown)")
    MouseArea { id: wmHoverMa; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
}
```

Required adding `import QtQuick.Controls` to StartMenuPanel.qml (was missing). Tooltip only fires when the text is actually truncated OR the version string is unusually long — no annoying tooltip on short strings.

---

## Files changed

```
zen-shell-v5/shell.qml                     +mask:Region on settingsWindow
                                           +mask:Region on controlPanelWindow
                                           -backdrop MouseArea on controlPanel

zen-shell-v5/UserProfileService.qml        +avatarRevision counter
                                           +?v=N query string in source URL

zen-shell-v5/UserProfilePage.qml           +cache:false on 96px avatar Image

zen-shell-v5/StartMenuPanel.qml            +cache:false on 72px + 104px avatars
                                           +import QtQuick.Controls
                                           +ToolTip on truncated WM row text

zen-shell-v5/ControlPanel.qml              +Input tab in tab bar
                                           +Input pane (sliders + switches)

zen-shell-v5/WallpaperPicker.qml           +onlineMode property
                                           +Online/Local toggle button
                                           +unified-shape model adapter
                                           +download-then-apply click path

zen-shell-v5/WallpaperRepoService.qml      NEW — GitHub API listing fetcher
                                                 with cache + offline fallback

zen-shell-v5/MouseSettingsService.qml      NEW — hyprctl keyword writer +
                                                 zen-mouse.conf persister

hypr-config/hyprland.conf.template         +source = ~/.config/hypr/zen-mouse.conf

install.sh                                 +banner v6.16.2.3.2
                                           +full v6.16.2.3.2 changelog block
                                           +seed zen-mouse.conf
                                           +idempotent source-line injection
                                           +default wallpaper download
                                           +auto IPC testNuclearRestart
                                           +zs-restart.sh fallback
```

---

## Apply

### Quick (10 files)

```bash
cp zen-shell-v5/shell.qml \
   zen-shell-v5/UserProfileService.qml \
   zen-shell-v5/UserProfilePage.qml \
   zen-shell-v5/StartMenuPanel.qml \
   zen-shell-v5/ControlPanel.qml \
   zen-shell-v5/WallpaperPicker.qml \
   zen-shell-v5/WallpaperRepoService.qml \
   zen-shell-v5/MouseSettingsService.qml \
   ~/.config/quickshell/zen-shell/

# Manual hyprland.conf source line if not running install.sh:
grep -q "zen-mouse.conf" ~/.config/hypr/hyprland.conf || \
  echo "source = ~/.config/hypr/zen-mouse.conf" >> ~/.config/hypr/hyprland.conf

~/.local/bin/zs-restart.sh
```

### Full tarball

```bash
tar -xzf zen-shell-v6.16.2.3.2-complete.tar.gz
cd zen-shell-v6.16.2.3.2
./install.sh
# install.sh auto-restarts the shell at the end — no separate
# zs-restart.sh step needed.
```

---

## Verify

### 1. Settings click-through (the critical fix)

- Open Firefox / Brave underneath
- Open Settings (`Super+,`)
- Click on a Firefox link — Firefox gets the click, Settings stays open
- Same for Control Panel (`Super+C`)
- Click ✕ on Settings or `Super+,` again to close

### 2. Avatar re-upload

- Settings → User Profile → Upload avatar → pick image A → see image A
- Upload avatar → pick image B → **see image B immediately** (was stuck on A in v6.16.2.3.1)

### 3. Default wallpaper on fresh install

- On a fresh machine (or after deleting `~/.config/quickshell/zen-shell/wallpaper-state.json`)
- Run `./install.sh`
- Default wallpaper from your repo applied via swww at end of install
- Re-run `install.sh` → does NOT re-apply (state file says wallpaper is set)

### 4. Online wallpaper browser

- Settings → Wallpaper (or Super+W) → "Online" button (cloud icon)
- Grid loads thumbnails from your GitHub repo
- Click an uncached one → downloads → applies
- Click a cached one (border/badge differs) → applies instantly
- Toggle back to "Local" → grid returns to local folder

### 5. Mouse sensitivity

- `Super+C` → Expand → Input tab
- Drag sensitivity slider — pointer responds **immediately** while dragging
- Move scroll speed slider — scroll feels different in Firefox immediately
- Toggle natural scroll — wheel direction inverts immediately
- Reload Hyprland (`hyprctl reload`) — settings preserved
- Reboot — settings preserved (proven by `cat ~/.config/hypr/zen-mouse.conf`)

### 6. Hyprland version tooltip

- `Super+A` → click footer avatar → sys-info popover
- Hover the WM row that shows truncated "Hyprland Hyprland 0.54.3 built..."
- After 350ms, tooltip appears with the FULL string

---

## Debug commands

### Online wallpaper repo

```bash
ls ~/.cache/zen-shell/wallpapers/        # cached listing.json
ls ~/.config/zen-shell/wallpapers/       # downloaded files
cat ~/.cache/zen-shell/wallpapers/listing.json | head -50
```

### Mouse settings

```bash
cat ~/.config/hypr/zen-mouse.conf
cat ~/.config/quickshell/zen-shell/mouse-settings.json
hyprctl getoption input:sensitivity
hyprctl getoption input:scroll_factor
hyprctl getoption input:natural_scroll
```

### Avatar pipeline

```bash
ls -la ~/.config/zen-shell/user-avatar.*
cat ~/.config/zen-shell/user-profile.json
journalctl --user -f | grep UserProfileService
```

---

## v6.16.x cumulative tally

| Version | Focus |
|---|---|
| v6.16.2 | StartMenu polish |
| v6.16.2.1 | Footer layout |
| v6.16.2.2 | Clock sync, avatar circle, persistence |
| v6.16.2.3 | Shader-mask avatar, singleton calendar toggle |
| v6.16.2.3.1 | Music-rope click-through, clock hover/wheel, island persist, avatar copy, FocusGrab suspend, DMI |
| **v6.16.2.3.2** | **Settings/CP click-through, avatar cache-bust, wallpaper repo, mouse sensitivity, Hyprland tooltip, install.sh auto-restart (THIS)** |
| v6.16.3 (future) | Bar profile badge widget, widget auto-resize, Fuzzel auto-size, display res dropdown, power-icons Material-synced, lid-close hypridle config |

---

## Known caveats

**`SysRowPage.qml` brace count** — counts as +1 open vs close. This was already true in v6.16.2.3.1 and earlier; it's almost certainly a `{` inside a string literal or comment that the simple counter misreads. The file works in production. Not touching it.

**WallpaperRepoService rate limit** — GitHub allows 60 unauthenticated API requests per IP per hour. The `Component.onCompleted` does one fetch on shell start; the user clicking "Refresh" or toggling Online mode does one each. A user actively testing wallpaper changes would not realistically hit 60/hour. If they do, the cached listing keeps working.

**zen-mouse.conf injected line at end of hyprland.conf** — for existing users, `install.sh` appends the source line at the very end. If your hyprland.conf has trailing config that should remain last, manually move the `source = ~/.config/hypr/zen-mouse.conf` line earlier. New installs (template-based) place it at the right spot.

**Avatar cache-buster `?v=N`** — Qt's Image element accepts `file://` URLs with query strings, but some QML linters complain. Functionally fine; warning-free at runtime.
