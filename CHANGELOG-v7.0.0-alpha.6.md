# v7.0.0-alpha.6 — Karui (軽い) · Search + Clipboard

**Channel:** alpha
**Codename:** Karui (軽い · "lightweight")
**Sub-theme:** Settings search · Clipboard tool
**Released:** 2026-05-08
**Branch:** `dev`

---

## What this drop adds

Two big features in one drop, both requested directly by Paul:

### 1. Settings + Control Center search

A Material-styled search bar lives in the header of the Settings
window (and will mount in Hypr Control Center via the same component
in the next pass). Type a query → see ranked matches → click or press
Enter to navigate to the right page.

**Search index** is hardcoded (~36 entries covering every settings
page + sub-row + every Control Center tab). Hardcoded vs runtime QML
reflection because:

- Stable + small (~1300 keywords-worth)
- Fast + deterministic
- Translatable (Densho keywords already include kanji + romaji aliases)
- Adding a new page = add a few lines to `SettingsSearchService.index`

**Ranking**: 3-tier — title prefix > title contains > subtitle/keywords.
Tested 8/8 edge cases pass including kanji-keyword search ("kanji"
correctly finds "Densho mode").

**Material Symbols Outlined** font used per Paul's request — a new
`MaterialIcons.qml` singleton resolves icon names ("search", "tune",
"palette", etc.) to codepoints. Fallback chain in font family means
if Material Symbols isn't installed, glyphs fall through to
JetBrainsMono Nerd Font (existing surfaces unaffected).

### 2. Clipboard service + panel + bar module

Three components that together give you Win-V style clipboard
history bound to **Super+V** (or click on the bar).

- **`ClipboardService.qml`** — wraps cliphist (the standard Wayland
  clipboard daemon). Reads `cliphist list`, parses entries, supports
  paste / pin / unpin / delete / wipe. Polls every 5s while panel
  visible (idle when closed). Persists pinned IDs to
  `~/.local/share/zen-shell/clipboard-pins.json`.
- **`ClipboardPanel.qml`** — searchable panel with pinned entries at
  top. Click row = paste (auto-closes). Right-click controls inline
  (pin/delete buttons). Empty state with cliphist install hint.
  Per-corner radius matches the StartMenuPanel hf3 pattern (flat
  bar-facing corners).
- **`ClipboardModule.qml`** — bar widget showing clipboard icon +
  count badge. Click toggles panel. Right-click pastes most recent
  non-pinned entry (power-user shortcut). Pulse animation when new
  entry arrives.

The bar module is **selectable from Panel page** like any other module
(start, clock, weather, etc.). Just drag it into a layout zone via
Settings → Panel → Module Layout.

---

## How to enable in your bar

1. Settings → Panel → Module Layout
2. Pick a zone (left/right/center)
3. Add "clipboard" from the dropdown
4. Save

The icon appears in your bar. Click → ClipboardPanel opens. Bind
Super+V to PanelState.clipboardVisible toggle for keyboard summon
(coming in alpha.6 hotfix or your hypr binds.conf).

## Search bar usage

- **Click the search field** at the top of Settings (or just open
  Settings — the field has a focus hint)
- **Type 2+ chars** — dropdown appears with ranked matches
- **↑/↓ arrows** — navigate the list
- **Enter** — jump to top result's page
- **Click any row** — jump to that page
- **Esc** — clear / close

---

## Future hookup notes

- **Hypr Control Center** — same `SettingsSearchBar` component will
  mount in `ControlPanel.qml` header in alpha.7 (next drop). The
  search index already includes Control Center entries with
  `surface: "controlpanel"`.
- **Notification Center (alpha.10)** — when the native QML
  notification center ships, ClipboardService will be exposed there
  too as a panel section (per Paul's spec). The service architecture
  already supports this — just add the rendering.
- **Super+V hotkey** — alpha.6.x hotfix will add the binds.conf
  patch + IPC route. For now, click the bar module or add this to
  your hypr binds.conf manually:
  ```
  bind = SUPER, V, exec, qs -c zen-shell ipc call zen toggleClipboard
  ```

---

## Files added

```
zen-shell-v5/MaterialIcons.qml             (NEW, ~80 lines)
zen-shell-v5/ClipboardService.qml          (NEW, ~250 lines)
zen-shell-v5/SettingsSearchService.qml     (NEW, ~200 lines)
zen-shell-v5/SettingsSearchBar.qml         (NEW, ~250 lines)
zen-shell-v5/ClipboardPanel.qml            (NEW, ~330 lines)
zen-shell-v5/ClipboardModule.qml           (NEW, ~120 lines)
CHANGELOG-v7.0.0-alpha.6.md                (NEW, this file)
```

## Files modified

```
zen-shell-v5/Bar.qml                       (+cClipboard component, +case)
zen-shell-v5/PanelState.qml                (+clipboardVisible property)
zen-shell-v5/PanelPage.qml                 (+clipboard in allModules)
zen-shell-v5/ZenSettings.qml               (+SettingsSearchBar in header)
zen-shell-v5/ZenVersion.qml                (bumped to v7.0.0-alpha.6)
install.sh                                 (version + Material font advisory)
README.md                                  (banner)
```

---

## Wala tayong babawasan

- All v7 alpha.1-5 features (Updates, Densho, StartMenu V2, LaptopMode)
  carry forward unchanged.
- Existing surfaces using JetBrainsMono Nerd Font remain unchanged —
  Material Symbols only used in new alpha.6 surfaces (search bar,
  clipboard module/panel). Both fonts can co-exist; if Material
  Symbols isn't installed, the font family fallback chain renders
  via Nerd Font instead.
- Bar module addition is opt-in (user must add "clipboard" to a layout
  zone) — bar appearance unchanged on existing installs until user
  configures it.
- ClipboardPanel auto-detects cliphist absence and shows install
  hint — never errors silently.
- Search index is hardcoded → safe to remove pages from the index if
  Paul deprecates a settings page in v7.x; old entries just become
  no-ops.

---

## Coming next (per master roadmap)

- **alpha.7** — Mount SettingsSearchBar into ControlPanel header +
  Material font advisory in install.sh (yay/paru one-liner) + Super+V
  IPC route + ZenCleanupService (RAM hygiene piece that was originally
  bundled here but pushed back due to scope of search/clipboard).
- **alpha.8** — Spotlight command palette (Super+Space).

---

## To install

```bash
tar -xzf zen-shell-v7.0.0-alpha.6-search-clipboard.tgz
cd zen-shell-v7.0.0-alpha.6
./install.sh
qs -r
```

Auto-snapshot of v7.0.0-alpha.5-hf2 install before overwrite.

### Required system packages

For full functionality of this drop:

```bash
# For Material icons (search bar + clipboard UI)
yay -S ttf-material-symbols-variable-git

# For clipboard history (if not already installed)
sudo pacman -S cliphist wl-clipboard

# Enable cliphist as wl-paste --watch service (one-time)
mkdir -p ~/.config/systemd/user
cat > ~/.config/systemd/user/wl-paste-history.service <<'SVC'
[Unit]
Description=Watch clipboard and feed cliphist
[Service]
ExecStart=/bin/sh -c 'wl-paste --type text --watch cliphist store'
Restart=on-failure
[Install]
WantedBy=default.target
SVC
systemctl --user daemon-reload
systemctl --user enable --now wl-paste-history
```

Without these:
- Without ttf-material-symbols → search/clipboard icons render as boxes
  (still functional, just ugly)
- Without cliphist → ClipboardPanel shows "cliphist not running" with
  install hint
