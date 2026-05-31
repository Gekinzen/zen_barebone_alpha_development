# v7.0.0-beta.1-hf82j — Screenshot rope colors + UpdatesPage HMSwitch + Update mechanism setup guide

**Channel:** beta (hotfix patch on hf82i)
**Released:** 2026-05-24
**Branch:** `dev`
**Scope:** 4 QML + 1 ZenVersion + this changelog (which doubles as the setup guide)

---

## Three user asks

> "yung sa string colors pati screenshot ropes dapat pwd din palitan ng colors and yung colors dapat accurate yun coloring and yung updates dapat yun toggle same design sa current toggle natin like sa general . and panu ko coconnect ito check for updates basta yun repository existing and anu mga paths pra gumana ? gawa ka guide"

1. **Screenshot ropes need their own configurable colors** (currently only the music strings have color config)
2. **UpdatesPage toggles use the ugly Qt platform-native `Switch`** instead of the project-standard pill-style `HMSwitch`
3. **How do I connect "Check for updates" to a real GitHub repo** — what paths, what scripts, what's the setup guide?

---

## Fix 1 — Independent screenshot rope colors

Pre-hf82j: ScreenshotRope (via `ZenRope.qml`) used `ZenStringsState.color1` directly. There was no way to set the rope color separately from the music strings. The "theme" mode also forced `ThemeService.blue` regardless of user pick.

hf82j adds 3 new properties to `ZenStringsState`:

```qml
property string ropeColorMode: "inherit"     // "inherit" | "theme" | "synced" | "custom"
property string ropeSyncedColorKey: "blue"   // when ropeColorMode === "synced"
property string ropeCustomColor: "#ff9e64"   // when ropeColorMode === "custom"
```

And a new resolved binding:

```qml
readonly property color ropeColor: {
    if (ropeColorMode === "custom")  return ropeCustomColor    // direct hex passthrough — "accurate"
    if (ropeColorMode === "theme")   return ThemeService.blue
    if (ropeColorMode === "synced")  return _resolveKey(ropeSyncedColorKey)
    return color1   // "inherit" — pre-hf82j behavior (match strings)
}
```

`ZenRope.qml` now reads `ZenStringsState.ropeColor` instead of `color1`. The new dropdown + palette key + hex picker appear in GeneralPage → Strings section, just below the "Screenshot ropes" toggle, only visible when both `enabled` and `screenshotRopeEnabled` are true.

**"Accurate" coloring guarantee**: when `ropeColorMode === "custom"`, the rope color is a direct hex passthrough — no ThemeService remapping, no auto-contrast adjustment, no synced-from-wallpaper override. You get the hex you set.

Defaults: `ropeColorMode = "inherit"` so existing users see zero change until they pick a different mode.

Persisted to `~/.config/quickshell/zen-shell/string-state.json` alongside the existing strings color config. `resetDefaults()` also covers the new fields.

---

## Fix 2 — UpdatesPage HMSwitch

Two `Switch { }` blocks in `UpdatesPage.qml` were the only remaining places in the Settings tree still using Qt's platform-native `Switch` instead of the project-standard `HMSwitch` pill toggle:

```qml
// BEFORE (hf82i and earlier):
SettingRow {
    label: "Check automatically"
    Switch {                                          // ← ugly platform-native
        checked: ZenUpdateService.autoCheckEnabled
        onToggled: ZenUpdateService.autoCheckEnabled = checked
    }
}

// AFTER (hf82j):
SettingRow {
    label: "Check automatically"
    HMSwitch {                                        // ← matches General / Battery / Widgets / ZenStrings
        checked: ZenUpdateService.autoCheckEnabled
        onToggled: ZenUpdateService.autoCheckEnabled = checked
    }
}
```

Same swap for the "Snapshot before installing" toggle. The signal name is identical (`toggled`), so no other code changes needed.

`HMSwitch` ships from `HMSwitch.qml` (already present in the install) — Rectangle-based pill with `ThemeService.blue` fill when on, translucent fg when off, 150ms cubic animations.

---

## Fix 3 — How to connect Check for Updates to a real GitHub repo

**Good news:** the infrastructure is already complete. `ZenUpdateService.qml` + `scripts/zen-update-check.sh` + GitHub API integration + channel filtering + caching + JSON parsing — all shipping since `v7.0.0-alpha.1`. You just need to point it at your repo and have releases tagged there.

### What ships in the release tarball

| File | Where it installs | Purpose |
|---|---|---|
| `zen-shell-v5/ZenUpdateService.qml` | `~/.config/quickshell/zen-shell/` | Singleton: state + auto-check timer + check/install/rollback methods |
| `zen-shell-v5/UpdatesPage.qml` | `~/.config/quickshell/zen-shell/` | Settings page UI (the screen in your screenshot) |
| `scripts/zen-update-check.sh` | `~/.config/quickshell/zen-shell/scripts/` | Fetches latest GitHub release, prints JSON |
| `scripts/zen-snapshot-create.sh` | `~/.config/quickshell/zen-shell/scripts/` | Tars current install → versioned archive |
| `scripts/zen-update-install.sh` | `~/.config/quickshell/zen-shell/scripts/` | Downloads release tarball + extracts over current install |
| `scripts/zen-rollback.sh` | `~/.config/quickshell/zen-shell/scripts/` | Restores from a snapshot |

### Persisted state paths

| Path | Owner | Contents |
|---|---|---|
| `~/.config/quickshell/zen-shell/update-state.json` | ZenUpdateService | settings + last-check cache |
| `~/.local/share/zen-shell/snapshots/` | snapshot scripts | versioned archives of past installs |
| `~/.local/share/zen-shell/snapshots/manifest.json` | snapshot scripts | snapshot metadata (version, date, pinned flag) |
| `~/.local/share/zen-shell/updates.log` | all update scripts | audit log of every check/install/rollback |
| `~/.cache/zen-shell/releases-<owner>_<repo>.json` | zen-update-check.sh | GitHub API response cache (5 min TTL) |

### Setup — three steps

#### Step 1 — verify scripts are installed + executable

```fish
# Check that all four update scripts are present:
ls -la ~/.config/quickshell/zen-shell/scripts/zen-{update-check,update-install,snapshot-create,rollback}.sh

# All should show -rwxr-xr-x (executable). If any show -rw-r--r--, fix:
chmod +x ~/.config/quickshell/zen-shell/scripts/zen-*.sh

# Required deps (most are already present on CachyOS / Arch):
pacman -Q curl jq tar  # all required
# If jq missing (the script does grep/sed fallback but jq is much better):
sudo pacman -S jq
```

#### Step 2 — set your release repo in ZenUpdateService

There are two ways to do this:

**A) Edit `ZenUpdateService.qml` directly (one-time, persists across rollbacks):**

```fish
nvim ~/.config/quickshell/zen-shell/ZenUpdateService.qml
```

Find line ~65:
```qml
property string releaseRepo: "Gekinzen/zen-shell"  // owner/repo on GitHub
```

Change to your repo. For example, if your repo is `paulyuki/zen-shell-dev`:
```qml
property string releaseRepo: "paulyuki/zen-shell-dev"
```

**B) Edit `update-state.json` (one-time, but persists in user state — survives QML refreshes):**

```fish
mkdir -p ~/.config/quickshell/zen-shell

# Either edit existing:
nvim ~/.config/quickshell/zen-shell/update-state.json

# Or write fresh:
cat > ~/.config/quickshell/zen-shell/update-state.json << 'EOF'
{
  "releaseRepo": "paulyuki/zen-shell-dev",
  "preferredChannel": "alpha",
  "autoCheckEnabled": true,
  "autoCheckIntervalHours": 24,
  "autoSnapshotBeforeUpdate": true,
  "maxSnapshotsRetained": 5
}
EOF

pkill -f quickshell; and sleep 1
quickshell -p ~/.config/quickshell/zen-shell &
```

Approach (A) sets the QML default (gets reset on every install). Approach (B) sets the persisted user state (survives across installs unless you wipe `update-state.json`). For a personal fork, use (B).

#### Step 3 — push tagged releases to GitHub

The check script fetches `https://api.github.com/repos/<owner>/<repo>/releases`. For releases to show up:

1. **Tag a commit** in your repo using semver:
   ```fish
   cd ~/Documents/development/v17/v6/zen-shell-v7.0.0-beta.1-hf82j
   git tag -a v7.0.0-beta.1-hf82j -m "v7.0.0-beta.1-hf82j — your changelog summary"
   git push origin v7.0.0-beta.1-hf82j
   ```

2. **Create a GitHub release** for that tag:
   - Browser: go to `https://github.com/<owner>/<repo>/releases/new`, pick the tag, fill the title + body
   - Or CLI: `gh release create v7.0.0-beta.1-hf82j --notes "..." --prerelease zen-shell-v7_0_0-beta_1-hf82j.tgz`

3. **Channel filter** — the tag name controls which channel it appears in:
   - `v7.0.0` → shows in stable, beta, alpha
   - `v7.0.0-beta.1` → shows in beta and alpha
   - `v7.0.0-beta.1-hf82j` or `v7.0.0-alpha.5` → shows in alpha only
   - Setting "prerelease" checkbox on the GitHub release → forces it out of stable

   For hotfix tags like `hf82j`, set "prerelease" checkbox so it stays in alpha-only.

4. **Asset attachment** — upload the release tarball (`zen-shell-v7_0_0-beta_1-hf82j.tgz`) as an asset on the release. `zen-update-install.sh` downloads the first `.tgz` asset.

### Test the connection — verify it works

After steps 1-3, test from the terminal:

```fish
# Direct script test — should print JSON line on stdout:
~/.config/quickshell/zen-shell/scripts/zen-update-check.sh paulyuki/zen-shell-dev alpha

# Expected output:
# {"tag":"v7.0.0-beta.1-hf82j","name":"...","url":"https://github.com/...","body":"...","date":"2026-05-24T...","prerelease":true}

# Or on error:
# {"error":"GitHub fetch failed (HTTP 404)"}

# Cache file written to:
ls -la ~/.cache/zen-shell/releases-paulyuki_zen-shell-dev.json
```

Then click "Check for updates" in the UI — should populate the version field, set "Last checked", and show "Update available" if your repo has a tag newer than your running version.

### Channel cheat sheet

| Channel | Filter | Use case |
|---|---|---|
| **stable** | `prerelease: false` AND no `-alpha`/`-beta`/`-rc` suffix in tag | Production users — only tagged like `v7.0.0`, `v7.1.0` |
| **beta** | excludes `-alpha` tags; allows `-beta` and stable | RC testers — `v7.0.0-beta.1`, `v7.0.0-beta.2` |
| **alpha** | any release (most permissive) | Dev / hotfix loop — `v7.0.0-beta.1-hf82j`, `v7.0.0-alpha.7` |

Set this via `preferredChannel` in `update-state.json` (or via the dropdown in UpdatesPage UI once it's wired up).

### Common pitfalls

1. **GitHub rate limit**: unauthenticated GitHub API allows 60 requests/hour per IP. The script caches for 5 minutes per repo so manual "Check" clicks don't hammer it; auto-check is throttled to `interval/2` minimum in QML. If you genuinely hit the limit, set `GH_TOKEN` env var in your fish config and pass to curl in the script.

2. **Private repo**: not supported out of the box. You'd need to add `-H "Authorization: token $GH_TOKEN"` to the curl call in `zen-update-check.sh` and set the env var.

3. **Tag format mismatch**: `ZenVersion.isNewer()` compares against `version` string. If your tag is `v7.0.0-beta.1-hf82j` and `ZenVersion.version` is `v7.0.0-beta.1-hf82j`, they match → no update. If tag is `v7.0.0-beta.1-hf82k`, it's newer → update shown. Make sure tags follow the same format as `ZenVersion.qml`'s `version` property.

4. **Cache stale**: if you push a tag and the UI doesn't see it within 5 minutes, manually invalidate:
   ```fish
   rm ~/.cache/zen-shell/releases-*.json
   ```
   Then click Check.

5. **install.sh banner mismatch**: hf82g fixed the install.sh banner to read the current hf, but if you renamed the tarball at build time, the banner reads whatever `ZenVersion.qml` says, not the tarball name. Match them.

### Recommended workflow for your dev loop

Now that you have hf82a → hf82j shipped locally, the next time you want to ship a hotfix as a real "Check for updates" candidate:

```fish
# 1. Build tarball as usual (you already do this — Claude generates them)
# 2. Tag the commit:
cd ~/Documents/development/v17/v8/zen-shell-v7.0.0-beta.1-hf82k
git add -A
git commit -m "hf82k: <summary>"
git tag -a v7.0.0-beta.1-hf82k -m "<full message>"
git push origin main --tags

# 3. Create GitHub release (use gh CLI for one-shot):
gh release create v7.0.0-beta.1-hf82k \
    --prerelease \
    --title "v7.0.0-beta.1-hf82k — <summary>" \
    --notes-file CHANGELOG-v7.0.0-beta.1-hf82k.md \
    zen-shell-v7_0_0-beta_1-hf82k.tgz

# 4. On your install: click "Check for updates" → "Update available" badge appears.
# 5. Click "Install" → autoSnapshotBeforeUpdate fires → snapshot → download → extract → restart shell.
```

If you don't have `gh` CLI installed yet:
```fish
sudo pacman -S github-cli
gh auth login
```

---

## Patched files

| File | hf82i | hf82j | Δ | Why |
|---|---:|---:|---:|---|
| `GeneralPage.qml` | 811 | 867 | +56 | New "Rope color" + "Rope palette key" + "Rope hex color" rows in Strings section |
| `UpdatesPage.qml` | 834 | 838 | +4 | Switch → HMSwitch swap × 2 + explanatory comments |
| `ZenStringsState.qml` | 189 | 244 | +55 | 3 new properties + `ropeColor` resolver + load/save/reset hooks |
| `ZenRope.qml` | 247 | 250 | +3 | `ropeColor` source switched from `color1` → `ZenStringsState.ropeColor` + comment |
| `ZenVersion.qml` | 110 | 110 | +0 | hf82i → hf82j string bumps |
| **Total** | **2191** | **2309** | **+118** | |

---

## Install

Drop-in over hf82i:

```fish
tar -xzf zen-shell-v7_0_0-beta_1-hf82j-patch-only.tgz

cp zen-shell-v7.0.0-beta.1-hf82j/zen-shell-v5/*.qml \
   ~/.config/quickshell/zen-shell/

pkill -f quickshell; and sleep 1
quickshell -p ~/.config/quickshell/zen-shell &
```

After reload, verify:

1. **Strings section** in Settings → General → scroll down to "Strings". Below "Screenshot ropes" toggle, new "Rope color" dropdown should appear. Pick "custom" → hex picker shows → pick a color → trigger a screenshot region → rope should be that exact color.
2. **Updates page** in Settings → Updates. The two toggles ("Check automatically" + "Snapshot before installing") should now use the same blue-pill design as the rest of the settings. No more white/grey native toggle.
3. **Check for updates** — depending on whether you've completed the setup guide steps 1-3 above, the button either:
   - Connects to your repo and shows the version comparison
   - Returns an error like "GitHub fetch failed (HTTP 404)" if the repo doesn't exist
4. Settings → User Profile → System Information → `v7.0.0-beta.1-hf82j · released 2026-05-24`.

---

## Wala tayong babawasan

All four touched QML files are purely additive. The `ropeColorMode = "inherit"` default preserves pre-hf82j visual behavior for users who never touch the new dropdown. The `HMSwitch` swap is API-compatible (same `checked` property, same `toggled` signal).

`update-state.json` schema is backward-compatible — old state files lacking the new rope color fields will load fine; defaults kick in for the missing keys.

Zero removals across all 5 files.

---

## Open threads still active

- Quickshell C++ crash dump capture
- Multi-monitor flameshot screen targeting (`--screen N`)
- Drag + overflow auto-scroll (12+ pinned apps edge case)
- Build-time version auto-derivation (`git describe`)
- `Component.onCompleted` race audit across the codebase
- Panel-position-aware calculation audit (`isTop` branches missing elsewhere)
- **NEW from hf82j:** `Switch` → `HMSwitch` audit across the codebase. Any other Settings page using stock `Switch` should be swapped. Quick grep:
  ```fish
  grep -rn "^\\s*Switch {$" ~/.config/quickshell/zen-shell/*.qml
  ```
  Any hits = candidates for the swap. Likely scattered in older pages that haven't been touched since the HMSwitch centralization in v6.16.1.4.
