# Internal Guide — Wiring the Zen Shell updater to GitHub

> **Audience:** the maintainer (Paul). This explains exactly how
> **Settings → Updates → "Check for updates"** talks to GitHub, what you
> must publish for it to find an update, and how channels / snapshots /
> rollback fit together. The infrastructure already ships; this is the
> operational playbook.

---

## 1. The moving parts

| Piece | Where | Role |
|------|-------|------|
| `ZenUpdateService.qml` | `zen-shell-v5/` | The brain. Holds `releaseRepo`, `preferredChannel`, current/latest version, snapshot list. Calls the scripts. |
| `zen-update-check.sh` | `scripts/` → `~/.local/bin/` | Fetches the latest release from GitHub's API, filtered by channel, prints one JSON line. |
| `zen-snapshot-create.sh` | `scripts/` → `~/.local/bin/` | Tars the current install into `~/.local/share/zen-shell/snapshots/`. |
| `zen-rollback.sh` | `scripts/` → `~/.local/bin/` | Restores a chosen snapshot (snapshots CURRENT first as a failsafe). |
| `ZenVersion.qml` | `zen-shell-v5/` | Source of `currentVersion` + `channel`. **This is what every release must bump.** |
| `UpdatesPage.qml` | `zen-shell-v5/` | The Settings UI (channel buttons, auto-check toggle, snapshot list). |

State/cache:
- `~/.local/share/zen-shell/snapshots/manifest.json` — snapshot metadata
- `~/.cache/zen-shell/releases-Gekinzen_zen-shell.json` — 5-min release cache

---

## 2. How a check actually works

1. User clicks **Check for updates** (or the 24h auto-check fires).
2. `ZenUpdateService` runs:
   ```
   zen-update-check.sh <releaseRepo> <channel>
   ```
   with `releaseRepo = "Gekinzen/zen-shell"` and
   `channel = ZenVersion.channel` (or the user's chosen channel).
3. The script hits the GitHub REST API:
   ```
   https://api.github.com/repos/Gekinzen/zen-shell/releases
   ```
   filters by channel (see §4), and prints:
   ```json
   {"tag":"v7.0.1","name":"…","url":"…","body":"…","date":"…","prerelease":false}
   ```
4. `ZenUpdateService` compares `tag` against `currentVersion`
   (`ZenVersion.version`). If newer → shows the update with its notes +
   download URL.

> **Key implication:** the updater finds releases, **not commits/tags
> alone.** You must cut a **GitHub Release** for it to see anything.

---

## 3. One-time setup checklist

### a. The repo must exist and be the one the service points at
`ZenUpdateService.releaseRepo` is `Gekinzen/zen-shell`. Two options:
- **Recommended:** create/rename your public repo to exactly
  `github.com/Gekinzen/zen-shell`, OR
- Change the constant in `ZenUpdateService.qml` to your real repo
  (`owner/repo`) and ship that build.

> Note: the README/site historically used
> `Gekinzen/zen_barebone_alpha_development`. Pick ONE and make the
> service's `releaseRepo` match it. They must agree.

### b. `ZenVersion.qml` must carry the real version + channel
This is the comparison baseline. It must look like:
```qml
readonly property string version: "v7.0.0-beta.1-hf95.32"  // or the clean tag
readonly property string channel: "beta"                    // stable | beta | alpha
```
The tag you publish on GitHub must be **newer** than this for an update to
show. (See §6 on version comparison.)

### c. The scripts must be installed + executable
`install.sh` already copies them to `~/.local/bin/`. Verify:
```bash
ls -l ~/.local/bin/zen-update-check.sh \
      ~/.local/bin/zen-snapshot-create.sh \
      ~/.local/bin/zen-rollback.sh
command -v curl jq   # jq preferred; script falls back to grep/sed
```

---

## 4. Publishing a release GitHub (the part that makes it light up)

### Tag format — channel is encoded in the tag
The check script decides a release's channel from its tag + the
GitHub "prerelease" flag:

| Channel | Tag example | GitHub "prerelease" checkbox |
|---------|-------------|------------------------------|
| **stable** | `v7.0.1` | unchecked |
| **beta** | `v7.1.0-beta.1` | checked |
| **alpha** | `v7.1.0-alpha.3` | checked |

Rules of thumb the script follows:
- A tag containing `-alpha` → alpha channel.
- A tag containing `-beta` → beta channel.
- A clean `vX.Y.Z` with prerelease=false → stable.
- Channel filtering is **inclusive downward**: a user on *alpha* sees
  alpha+beta+stable; *beta* sees beta+stable; *stable* sees only stable.
  (So cut the narrowest channel that's correct.)

### Steps to cut a release
1. Bump `ZenVersion.qml` (`version` + `channel`) and commit.
2. Tag it:
   ```bash
   git tag v7.1.0-beta.1
   git push origin v7.1.0-beta.1
   ```
3. On GitHub → **Releases → Draft a new release**:
   - **Tag:** the one you pushed.
   - **Title:** e.g. `Zen Shell v7.1.0-beta.1 — Karui`.
   - **Description:** paste the release notes (this becomes the `body`
     shown in-shell).
   - **Attach the tarball** as a release asset:
     `zen-shell-v7.1.0-beta.1.tgz` (this is the download `url`).
   - **Set the "This is a pre-release" checkbox** for alpha/beta; leave
     unchecked for stable.
4. Publish. Within the cache window (5 min) the in-shell check will see
   it.

> The updater currently surfaces the release + notes + download URL. The
> actual apply is via snapshot → download → install (see §5); for the
> first cut you can also just direct users to download the asset and run
> `./install.sh`.

---

## 5. Snapshots & rollback (already wired)

- **Snapshot now** (button) → `zen-snapshot-create.sh` tars the live
  install (QML config root + the `~/.local/bin/zen-*` helpers so they
  roll back atomically) into the snapshots dir and appends to
  `manifest.json`.
- **Snapshot before installing** (toggle) → a snapshot is auto-created
  before any update apply, so a bad update is one click to undo.
- **Rollback** → `zen-rollback.sh <snapshot>` restores it, snapshotting
  CURRENT first as a failsafe.
- **Keep snapshots** (stepper) → older unpinned snapshots auto-prune
  beyond this count; **pin** protects one.

Nothing extra to set up — these work the moment the scripts are installed.

---

## 6. Version comparison gotcha

`currentVersion` is `ZenVersion.version`. If you ship hotfix suffixes like
`v7.0.0-beta.1-hf95.32`, make sure the **published tag sorts as newer**.
Safest scheme:
- Publish clean, monotonic tags: `v7.0.0-beta.1`, `v7.0.0-beta.2`,
  `v7.1.0-beta.1`, `v7.1.0`, …
- Keep the `-hfNN` detail in `ZenVersion.qml` and the changelog, but tag
  releases on the clean `vX.Y.Z[-channel.N]` boundary.
- This matches the existing **branch convention** (beta branches
  `beta-v12.*` strip to `v6.x.x.x` on release).

If you must compare hotfix suffixes, confirm the comparator in
`ZenUpdateService` treats `-beta.2` as newer than `-beta.1` and a clean
`vX.Y.Z` as newer than any `-beta.N` of the same version (standard
semver precedence). Test with §7.

---

## 7. Testing the whole loop

```bash
# 1. Does the script reach GitHub and parse a release?
zen-update-check.sh Gekinzen/zen-shell beta
# → expect a JSON line with a tag, or {"tag":""} if no beta release yet.

# 2. Force a "newer" release in a scratch repo to see the UI light up:
#    - tag v9.9.9-beta.1 in a test repo, publish as pre-release,
#    - temporarily point ZenUpdateService.releaseRepo at it,
#    - click Check for updates → should show v9.9.9.

# 3. Snapshot + rollback round-trip:
zen-snapshot-create.sh
ls ~/.local/share/zen-shell/snapshots/
zen-rollback.sh <one-listed-snapshot>   # confirm install restored

# 4. Channel filtering:
zen-update-check.sh Gekinzen/zen-shell stable   # should ignore -beta/-alpha tags
zen-update-check.sh Gekinzen/zen-shell alpha    # should see everything
```

---

## 8. Common pitfalls

- **No release cut** → check returns empty; the UI says "Never checked /
  up to date". Cutting a *tag* is not enough — publish a **Release**.
- **`releaseRepo` ≠ the repo you published to** → silent empty result.
  Make them match.
- **Prerelease flag wrong** → a beta shows up for stable users (flag
  unchecked) or a stable is hidden (flag checked). Match the channel.
- **GitHub rate limit** (unauthenticated 60 req/h) → the 5-min cache
  protects manual clicking; auto-check is throttled in QML. For heavy
  testing, set a `GITHUB_TOKEN` env var if the script supports it, or
  wait out the window.
- **`jq` missing** → script uses a grep/sed fallback; install `jq` for
  reliable parsing.
- **Version didn't bump** → if `ZenVersion.version` already equals the
  latest tag, nothing shows. Bump it per release.

---

## 9. TL;DR release ritual

1. Bump `ZenVersion.qml` (`version` + `channel`).
2. `git tag vX.Y.Z[-channel.N] && git push origin <tag>`.
3. GitHub → Releases → new release on that tag, paste notes, attach
   `zen-shell-<tag>.tgz`, set prerelease for alpha/beta.
4. Publish. In-shell **Check for updates** sees it within 5 minutes.

That's the whole loop. Snapshots/rollback are automatic; channels are
encoded in the tag + prerelease flag; the only per-release human steps are
bump → tag → publish-release-with-asset.
