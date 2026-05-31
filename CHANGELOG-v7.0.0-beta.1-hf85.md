# Zen Shell v7.0.0-beta.1-hf85 — Karui (軽い)

Release date: 2026-05-30
Channel: beta · Codename: Karui (軽い)

Four user-requested items. Additive; defaults preserve current behavior
except where noted. Wala tayong babawasan.

---

## 1. Settings search — auto-hide removed

The floating settings search now stays pinned (it lives in the
full-width header since hf83); it no longer tucks away while scrolling.

- **`ZenSettings.qml`** — `isContentScrolling` hard-returns `false`
  (former scroll-detection kept as a comment). This disables the search
  tuck **and** the peek-tab automatically, since both keyed off it.

## 2. Bar contents — centered with even top/bottom padding

Modules stay vertically centered with a guaranteed, even gap above and
below, regardless of bar height.

- **`PanelState.qml`** — new `barContentPaddingV` (int, default `4`),
  saved / loaded / reset.
- **`Bar.qml`** — the content `RowLayout` is inset top + bottom by
  `barContentPaddingV`; zones fillHeight within the inset area and each
  module is `AlignVCenter`, so content stays centered with symmetric
  padding when the height changes.
- **`PanelPage.qml`** — new "Content padding (top/bottom)" slider.

## 3. New user → clone your dotfiles

Creating a user can now copy the current user's Zen Shell + Hyprland
rice into the new account so it boots into the same desktop.

- **`UserManagementService.qml`** — `createUser()` gains a
  `copyDotfiles` arg (default true). In the same pkexec call, after
  `useradd` + `chpasswd`, it copies a curated set from the source home
  (`~/.config/quickshell`, `~/.config/hypr`, `kitty`, `fish`, `matugen`,
  `swww`, `~/.local/share/quickshell`, `~/.local/bin`), rewrites
  absolute `/home/<src>/` paths in the copied text configs to the new
  home, then `chown -R`s the clone to the new user. Curated on purpose —
  no ssh keys / tokens / browser profiles.
- **`UserManagementPage.qml`** — new "Clone my dotfiles" switch
  (default on), passed to `createUser()`.

> Foundation for the planned standalone installer (roadmap §4): the
> same curated-copy + path-rewrite logic is what an installer would run
> for a fresh user.

## 4. Desktop icons — custom PNG icons

Each icon in the single-widget desktop panel can now be given a custom
image.

- **`DesktopIconsState.qml`** — new `customIcons` map (entry name →
  image path) + `setCustomIcon()` / `clearCustomIcon()`, persisted.
- **`DesktopIconsWidget.qml`** — `resolveIcon()` checks `customIcons`
  first (wins over theme / .desktop / taskbar resolution).
  **Right-click a tile** → file picker (zenity, kdialog fallback) →
  pick a PNG/SVG/JPG. **Shift+right-click** clears the override.

---

## Files touched

```
ZenVersion.qml             → v7.0.0-beta.1-hf85
ZenSettings.qml            search auto-hide disabled
PanelState.qml             barContentPaddingV
Bar.qml                    vertical content inset
PanelPage.qml              content-padding slider
UserManagementService.qml  createUser dotfile clone + path rewrite
UserManagementPage.qml     "Clone my dotfiles" toggle
DesktopIconsState.qml      customIcons map + setters
DesktopIconsWidget.qml     custom-icon resolution + right-click picker
```

Carries forward hf83 (auto bar height, full-width header, dock
reserve-space, single-widget desktop icons) and hf84 (fit-contents
scaling). Wala tayong babawasan.

---

## Deferred to roadmap (asked, not yet built)
- **Desktop-icons app-list pinning** — pin arbitrary installed apps into
  the widget (not just `~/Desktop` entries). Roadmap §4 mid-term.
- **Standalone installer** — first-run/new-user provisioning wrapping
  the hf85 dotfile-clone logic. Roadmap §4 / §8.
