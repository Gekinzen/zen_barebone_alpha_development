#!/usr/bin/env bash
# zen-plugin-bootstrap.sh — Zen Shell plugin bootstrap
#
# v7.0.0-beta.1-hf82m — Smart Hyprland-version-aware bootstrap.
#
# Why this changed: in hf82l we added a version-aware config sanitizer
# that fixes deprecated config keys when Hyprland gets a MINOR bump
# (e.g. 0.54 → 0.55) at install time. But pacman can silently upgrade
# Hyprland — even a PATCH bump (0.55.0 → 0.55.2) — and the user never
# re-runs install.sh. When that happens:
#
#   - hyprpm-built plugins (hyprbars, hyprexpo, etc.) were compiled
#     against the OLD Hyprland headers. They're now stale and
#     hyprpm reload will refuse to load them with a "header version
#     mismatch" error.
#   - Hyprland's release notes for the new patch/minor MAY have
#     removed config keys; the user's config still references them
#     and hyprctl reload spams "config option does not exist" errors.
#
# hf82m adds version stamping + auto-detect-on-boot:
#   1. install.sh writes a stamp at
#      ~/.local/share/zen-shell/hyprland-version-stamp.json with the
#      detected version + commit at install time.
#   2. On EVERY Hyprland boot (autostart.conf → this script), we
#      compare running version to the stamp BEFORE the existing
#      `hyprpm reload`. If they differ:
#      a) Run `hyprpm update` to rebuild plugins against new headers
#         (with auto-purge-cache retry if needed — mirrors install.sh
#         Phase 1 logic from line ~3375).
#      b) Notify the user that a Hyprland version change was detected
#         and what happened (rebuild succeeded/failed, headers OK/not).
#      c) Update the stamp so we don't re-notify on every boot.
#      d) For removed config keys, point the user at running install.sh
#         again — we don't try to auto-sanitize from this script
#         because the install.sh's `_strip_hl5N_breakages` functions
#         operate across many files + back things up, which is
#         heavyweight for the boot path.
#   3. Then proceed with the existing bootstrap (hyprpm reload +
#      sleep + hyprctl reload).
#
# Wala tayong babawasan — the existing bootstrap behavior is fully
# preserved at the end of this script. We just ADD the version-check
# stage in front of it. If the stamp file doesn't exist (fresh install
# under an older Zen Shell version that didn't write stamps), the
# version check is silently skipped — no error, no notification.

set -u

LOG=/tmp/zen-plugin-bootstrap.log
STAMP_FILE="${HOME}/.local/share/zen-shell/hyprland-version-stamp.json"
NOTIFY_THROTTLE_FILE="${HOME}/.cache/zen-shell/last-hyprversion-notify"

echo "[$(date)] Starting Zen Shell plugin bootstrap (hf82m)" > "$LOG"

# Wait for Hyprland IPC ready (5 second budget)
for i in 1 2 3 4 5; do
    if hyprctl version >/dev/null 2>&1; then
        echo "[bootstrap] Hyprland ready (attempt $i)" >> "$LOG"
        break
    fi
    sleep 1
done

# ═══════════════════════════════════════════════════════════════════
# v7.0.0-beta.1-hf82m — Hyprland version-stamp comparison
# ═══════════════════════════════════════════════════════════════════

# Parse current Hyprland version. We capture BOTH the tag (e.g. v0.55.2)
# AND the commit hash. The tag catches major/minor/patch bumps; the
# commit catches "same version, different build" cases (rare, but
# happens when distros rebuild stable tags with patches).
_detect_hl_now() {
    local raw tag commit
    raw=$(hyprctl version 2>/dev/null)
    if [ -z "$raw" ]; then
        echo ""
        return
    fi
    tag=$(echo "$raw" | grep -oE 'Tag: v?[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 | sed 's/Tag: v\?//')
    commit=$(echo "$raw" | grep -oE 'commit[[:space:]]+[a-f0-9]{7,}' | head -1 | awk '{print $2}')
    if [ -z "$tag" ]; then
        # Some Hyprland builds don't expose Tag: — fall back to first
        # numeric token in the version line.
        tag=$(echo "$raw" | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)
    fi
    [ -z "$tag" ] && tag="unknown"
    [ -z "$commit" ] && commit="unknown"
    echo "${tag}|${commit}"
}

HL_NOW=$(_detect_hl_now)
HL_NOW_TAG=$(echo "$HL_NOW" | cut -d'|' -f1)
HL_NOW_COMMIT=$(echo "$HL_NOW" | cut -d'|' -f2)
echo "[bootstrap] Detected Hyprland: tag=$HL_NOW_TAG commit=$HL_NOW_COMMIT" >> "$LOG"

# Read stamp (if any). Cheap grep-based parse — avoid jq dependency
# on the boot path. Format is:
#   { "tag": "v0.55.0", "commit": "abc1234", "stamped_at": "..." }
HL_STAMP_TAG=""
HL_STAMP_COMMIT=""
if [ -f "$STAMP_FILE" ]; then
    HL_STAMP_TAG=$(grep -oE '"tag"[[:space:]]*:[[:space:]]*"[^"]+"' "$STAMP_FILE" | head -1 | sed -E 's/.*"([^"]+)"$/\1/')
    HL_STAMP_COMMIT=$(grep -oE '"commit"[[:space:]]*:[[:space:]]*"[^"]+"' "$STAMP_FILE" | head -1 | sed -E 's/.*"([^"]+)"$/\1/')
    echo "[bootstrap] Stamp file: tag=$HL_STAMP_TAG commit=$HL_STAMP_COMMIT" >> "$LOG"
else
    echo "[bootstrap] No stamp file at $STAMP_FILE — skipping version check (will be created next install.sh run)" >> "$LOG"
fi

# Compare. Decision matrix:
#   - No stamp                            → skip (first run after upgrade
#                                              from pre-hf82m Zen Shell;
#                                              install.sh writes it later)
#   - Stamp present, tag mismatch         → version changed (patch / minor / major)
#   - Stamp present, tag match, commit !  → distro rebuild — also stale
#   - All match                           → no-op, proceed normally
VERSION_CHANGED=0
CHANGE_KIND=""
if [ -n "$HL_STAMP_TAG" ] && [ "$HL_STAMP_TAG" != "unknown" ] \
                          && [ "$HL_NOW_TAG"  != "unknown" ]; then
    if [ "$HL_STAMP_TAG" != "$HL_NOW_TAG" ]; then
        VERSION_CHANGED=1
        # Categorize: major/minor/patch from semver-ish comparison.
        # X.Y vs X.Y.Z handled by just comparing the second segment.
        stamp_maj=$(echo "$HL_STAMP_TAG" | cut -d. -f1)
        stamp_min=$(echo "$HL_STAMP_TAG" | cut -d. -f2)
        stamp_pat=$(echo "$HL_STAMP_TAG" | cut -d. -f3)
        now_maj=$(echo "$HL_NOW_TAG"     | cut -d. -f1)
        now_min=$(echo "$HL_NOW_TAG"     | cut -d. -f2)
        now_pat=$(echo "$HL_NOW_TAG"     | cut -d. -f3)
        if [ "$stamp_maj" != "$now_maj" ]; then
            CHANGE_KIND="major"
        elif [ "$stamp_min" != "$now_min" ]; then
            CHANGE_KIND="minor"
        elif [ "$stamp_pat" != "$now_pat" ]; then
            CHANGE_KIND="patch"
        else
            CHANGE_KIND="rebuild"
        fi
    elif [ -n "$HL_STAMP_COMMIT" ] && [ "$HL_STAMP_COMMIT" != "unknown" ] \
                                   && [ "$HL_NOW_COMMIT"  != "unknown" ] \
                                   && [ "$HL_STAMP_COMMIT" != "$HL_NOW_COMMIT" ]; then
        VERSION_CHANGED=1
        CHANGE_KIND="commit"
    fi
fi

# Throttle notifications: at most one per Hyprland version transition
# per 24h. Prevents spamming on every boot if hyprpm update keeps
# failing (e.g. no network, no build tools).
_should_notify() {
    [ ! -f "$NOTIFY_THROTTLE_FILE" ] && return 0
    local last_tag last_when now
    last_tag=$(head -1 "$NOTIFY_THROTTLE_FILE" 2>/dev/null)
    last_when=$(sed -n '2p' "$NOTIFY_THROTTLE_FILE" 2>/dev/null)
    now=$(date +%s)
    # Always notify if it's a NEW tag we haven't notified about yet
    [ "$last_tag" != "$HL_NOW_TAG" ] && return 0
    # Otherwise throttle 24h
    if [ -n "$last_when" ] && [ "$last_when" -gt "$((now - 86400))" ] 2>/dev/null; then
        return 1
    fi
    return 0
}

_record_notify() {
    mkdir -p "$(dirname "$NOTIFY_THROTTLE_FILE")"
    printf '%s\n%s\n' "$HL_NOW_TAG" "$(date +%s)" > "$NOTIFY_THROTTLE_FILE"
}

if [ "$VERSION_CHANGED" -eq 1 ]; then
    echo "[bootstrap] Hyprland version change detected ($CHANGE_KIND): $HL_STAMP_TAG → $HL_NOW_TAG" >> "$LOG"

    # ── Step 1: hyprpm update (with auto purge-cache retry) ──
    #
    # Mirrors the install.sh Phase 1 logic. We DO try to rebuild
    # plugins on the boot path because that's what the user actually
    # needs — without it, plugins won't load and the SUPER+? keybinds
    # break for hyprbars/hyprexpo/etc.
    #
    # Bail-out: if hyprpm itself isn't installed, skip silently with
    # a log note. Some users disable plugins entirely.
    update_ok=0
    if command -v hyprpm >/dev/null 2>&1; then
        echo "[bootstrap] Running hyprpm update (rebuild plugins against new headers)..." >> "$LOG"
        if hyprpm update -v >> "$LOG" 2>&1; then
            update_ok=1
            echo "[bootstrap] hyprpm update OK" >> "$LOG"
        else
            echo "[bootstrap] hyprpm update FAILED — trying purge-cache + retry..." >> "$LOG"
            hyprpm purge-cache >> "$LOG" 2>&1 || true
            if hyprpm update -v >> "$LOG" 2>&1; then
                update_ok=1
                echo "[bootstrap] hyprpm update OK after purge-cache" >> "$LOG"
            else
                echo "[bootstrap] hyprpm update STILL FAILED after purge-cache" >> "$LOG"
            fi
        fi

        # ── Step 2: notify user (throttled) ──
        if _should_notify; then
            _record_notify
            if [ "$update_ok" -eq 1 ]; then
                notify-send -a "Zen Shell" \
                    -i "system-software-update" \
                    -u normal \
                    "Hyprland updated: $HL_STAMP_TAG → $HL_NOW_TAG ($CHANGE_KIND bump)" \
                    "Plugins rebuilt automatically. Re-run install.sh from your release tarball if you also see 'config option does not exist' errors — that path also re-runs the deprecated-key sanitizer." 2>/dev/null || true
            else
                notify-send -a "Zen Shell" \
                    -i "dialog-warning" \
                    -u critical \
                    "Hyprland updated to $HL_NOW_TAG — plugins need rebuild" \
                    "Auto hyprpm update failed. Try manually: 'hyprpm purge-cache && hyprpm update' in a terminal. Then re-run install.sh from the release tarball. Log: $LOG" 2>/dev/null || true
            fi
        fi
    else
        echo "[bootstrap] hyprpm not installed — skipping rebuild" >> "$LOG"
    fi

    # ── Step 3: update stamp regardless (avoid re-trigger loop) ──
    #
    # Even if hyprpm update failed, we update the stamp to the
    # current version. Reason: leaving the stamp stale would
    # cause the bootstrap to retry hyprpm update on EVERY boot,
    # spam the throttle, and never let the user see a clean
    # state. Better behavior: stamp once, notify once, leave
    # remediation to the user via the install.sh path the
    # notification points them to.
    mkdir -p "$(dirname "$STAMP_FILE")"
    cat > "$STAMP_FILE" << EOF
{
  "tag": "$HL_NOW_TAG",
  "commit": "$HL_NOW_COMMIT",
  "stamped_at": "$(date -Iseconds)",
  "stamped_by": "zen-plugin-bootstrap.sh (auto, version-change-detected)",
  "previous_tag": "$HL_STAMP_TAG",
  "change_kind": "$CHANGE_KIND",
  "update_ok": $update_ok
}
EOF
    echo "[bootstrap] Stamp updated" >> "$LOG"
fi

# ═══════════════════════════════════════════════════════════════════
# v7.0.0-beta.1-hf82m.1 — Detect "headers OK but no repos" state
# ═══════════════════════════════════════════════════════════════════
#
# Real-world bug we're catching: user upgrades Hyprland via pacman
# (0.53 → 0.55), runs install.sh, but install.sh's Phase 1 hyprpm
# update FAILS due to stale headers. Phases 2-4 (add repos / build /
# enable / final reload) are then gated behind HYPRPM_OK=1 and SKIP.
# User later manually runs `hyprpm update` (which succeeds now that
# headers are fresh), but `hyprpm reload` reports "✖ No repos to
# update" and `hyprpm enable hyprbars` says "Couldn't enable plugin
# (missing?)" — because no plugin repo was ever added.
#
# This block detects that broken-but-recoverable state and self-heals:
#   1. If hyprpm reports zero repos added AND we expect at least
#      hyprland-plugins (the official repo Zen Shell uses by default)
#      → run `hyprpm add https://github.com/hyprwm/hyprland-plugins`
#   2. If hyprbars is not in the enabled-plugin list (default for
#      Zen Shell's hyprbars-mimic feature)
#      → run `hyprpm enable hyprbars` after the add completes
#   3. Notify the user once (throttled) that recovery happened
#
# Safe defaults: only auto-add the OFFICIAL hyprwm repo + only auto-
# enable hyprbars (Zen Shell's documented default). Other plugins the
# user previously had are left for the user to re-enable manually if
# they need them — we don't want to silently re-enable a plugin they
# intentionally disabled.

_check_and_recover_hyprpm_state() {
    if ! command -v hyprpm >/dev/null 2>&1; then
        return 0  # nothing to do
    fi

    # Numeric-safe parsing: grep -c on empty input returns "0" with
    # exit 1, which `|| echo 0` would TURN INTO "00" (both grep's 0
    # and our fallback 0 concatenated). Avoid that whole class of
    # bug by capturing without fallback, then numerically coercing.
    local repos_count hyprbars_present hyprbars_enabled recovery_ran=0

    repos_count=$(hyprpm list 2>/dev/null | grep -cE "^→ Repository" 2>/dev/null)
    [ -z "$repos_count" ] && repos_count=0
    if ! [ "$repos_count" -ge 0 ] 2>/dev/null; then repos_count=0; fi

    echo "[bootstrap] hyprpm state check: repos=$repos_count" >> "$LOG"

    # ── Recovery 1: zero repos → auto-add official hyprland-plugins ──
    if [ "$repos_count" -eq 0 ] 2>/dev/null; then
        echo "[bootstrap] No hyprpm repos detected — auto-adding hyprland-plugins..." >> "$LOG"
        if hyprpm add "https://github.com/hyprwm/hyprland-plugins" >> "$LOG" 2>&1; then
            echo "[bootstrap] hyprpm add hyprland-plugins OK" >> "$LOG"
            recovery_ran=1
        else
            echo "[bootstrap] hyprpm add hyprland-plugins FAILED — see log" >> "$LOG"
            if _should_notify; then
                _record_notify
                notify-send -a "Zen Shell" \
                    -i "dialog-warning" \
                    -u critical \
                    "Hyprland plugin auto-recovery failed" \
                    "hyprpm add https://github.com/hyprwm/hyprland-plugins failed. Run manually in a terminal, then 'hyprpm enable hyprbars && hyprpm reload'. Log: $LOG" 2>/dev/null || true
            fi
            return 0  # don't try to enable if add failed
        fi
    fi

    # ── Recovery 2: hyprbars not enabled → auto-enable ──
    # hyprbars is Zen Shell's default-on plugin (used by the title-bar
    # mimic feature in Bar.qml). Only re-enable it; don't touch other
    # plugins the user may have intentionally disabled.
    hyprbars_present=$(hyprpm list 2>/dev/null | grep -cE "Plugin hyprbars" 2>/dev/null)
    [ -z "$hyprbars_present" ] && hyprbars_present=0
    if ! [ "$hyprbars_present" -ge 0 ] 2>/dev/null; then hyprbars_present=0; fi

    if [ "$hyprbars_present" -gt 0 ] 2>/dev/null; then
        # hyprbars is in the registry; check if enabled
        hyprbars_enabled=$(hyprpm list 2>/dev/null \
            | awk '/Plugin hyprbars/{found=1} found && /Enabled:/{print $2; exit}')
        if [ "$hyprbars_enabled" != "true" ]; then
            echo "[bootstrap] hyprbars present but disabled — auto-enabling..." >> "$LOG"
            if hyprpm enable hyprbars >> "$LOG" 2>&1; then
                echo "[bootstrap] hyprpm enable hyprbars OK" >> "$LOG"
                recovery_ran=1
            else
                echo "[bootstrap] hyprpm enable hyprbars FAILED — see log" >> "$LOG"
            fi
        fi
    fi

    # ── Notify on successful recovery (throttled) ──
    if [ "$recovery_ran" = "1" ] && _should_notify; then
        _record_notify
        notify-send -a "Zen Shell" \
            -i "system-software-update" \
            -u normal \
            "Hyprland plugins auto-recovered" \
            "Detected missing repo/enable state — added hyprland-plugins and enabled hyprbars. Title bars should work again after this boot." 2>/dev/null || true
    fi
}

_check_and_recover_hyprpm_state

# ═══════════════════════════════════════════════════════════════════
# ── Original bootstrap below (UNCHANGED from pre-hf82m) ──
# ═══════════════════════════════════════════════════════════════════

# hyprpm reload — loads all enabled plugins per hyprpm state
echo "[bootstrap] hyprpm reload..." >> "$LOG"
hyprpm reload -n 2>&1 >> "$LOG"

# Brief wait for plugins to register their keyword handlers
sleep 1

# SECOND config reload so plugin-registered keywords (buttons, binds)
# get parsed AFTER plugins are loaded.
echo "[bootstrap] hyprctl reload (post-plugin-load)..." >> "$LOG"
hyprctl reload 2>&1 >> "$LOG"

# Verify
echo "[bootstrap] Loaded plugins:" >> "$LOG"
hyprctl plugin list 2>&1 >> "$LOG"

# ═══════════════════════════════════════════════════════════════════
# v7.0.0-beta.1-hf82w — Rebuild plugin cache after successful bootstrap
# ═══════════════════════════════════════════════════════════════════
# Now that hyprpm has rebuilt and reloaded plugins, capture the current
# .so paths into ~/.local/share/zen-shell/plugin-cache.json so the
# next boot's zen-plugin-loader.service can do direct hyprctl plugin
# load without going through hyprpm reload — 5x faster.
#
# This script is silent on success; logs to /tmp/zen-plugin-cache-rebuild.log
if [ -x "$HOME/.local/bin/zen-plugin-cache-rebuild.sh" ]; then
    echo "[bootstrap] Rebuilding plugin cache..." >> "$LOG"
    "$HOME/.local/bin/zen-plugin-cache-rebuild.sh" >> "$LOG" 2>&1
fi

echo "[$(date)] Bootstrap done." >> "$LOG"
