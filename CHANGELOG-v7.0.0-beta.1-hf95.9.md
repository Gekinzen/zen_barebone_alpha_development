# Zen Shell v7.0.0-beta.1-hf95.9 — Karui (軽い)

Release date: 2026-05-30
Channel: beta · Codename: Karui (軽い)

**User management auto-install fixed: creating a user now reliably clones
your Zen Shell desktop into the new account, so they boot into the same
rice instead of a bare or broken desktop.** Wala tayong babawasan.

---

## Two bugs that made it "seem not to work"

`UserManagementService.createUser(..., copyDotfiles)` is what auto-installs
Zen Shell for a new user (by cloning the desktop-relevant dotfiles). Two
defects made the result bare or broken:

1. **Silent skip.** The clone was gated on `copyDotfiles && srcHome &&
   srcName`, where `srcName` came from the QML-side `currentUser`. If that
   wasn't populated at the moment of creation, the entire clone block was
   omitted — the new account was created BARE (no Zen Shell). Now the clone
   is always attempted when `copyDotfiles` is on, and the source user is
   resolved AUTHORITATIVELY root-side from `PKEXEC_UID` (the human who
   authenticated), falling back to the QML hint, then `logname`.

2. **Incomplete path rewrite.** Eight directories were copied, but the
   `/home/<src>/ → /home/<new>/` rewrite only touched three
   (`.config/quickshell`, `.config/hypr`, `.config/matugen`). State under
   `.local/share/quickshell` (e.g. `panel-state.json`) kept absolute paths
   pointing at the source user's home — which the new user can't read, so
   their wallpaper/theme broke. The rewrite now covers EVERY copied
   directory, and uses a trailing slash (`/home/paul/`) so a lookalike
   like `/home/paul2/` isn't accidentally matched.

Verified by simulation: a copied `panel-state.json` and `hyprland.conf`
have their source-home paths rewritten to the new home, with no leftover
source paths anywhere in the clone.

## Safety unchanged

All the hard safety rules (never delete current user / uid < 1000 / root;
per-action pkexec auth; audit log) are untouched. This change only affects
the dotfile-clone portion of `createUser`. No file, feature, or setting
removed.

## Version

- `ZenVersion.qml` bumped `hf95.8` → `hf95.9`.

## Files touched

- `zen-shell-v5/UserManagementService.qml` — robust source resolution + full path rewrite in `createUser`
- `zen-shell-v5/ZenVersion.qml` — version string
