#!/usr/bin/env bash
# zen-hyprpm-fix.sh — v6.16.4.12.6.26
#
# Recovery + full reinstall script for hyprpm. Runs when:
#   - "Couldn't update headers"
#   - "Headers outdated, please run hyprpm update"
#   - Settings → Plugins shows "not installed" after broken install
#
# v26 FIX: previous version purged cache then re-ran update, but FORGOT
# to re-add the plugin repos. So `hyprpm update` showed "No repos to
# update" and no .so files were built — leaving Settings toggles grayed.
# This v26 explicitly re-adds the hyprland-plugins repo with verbose
# output so you can see each plugin compile.

set -euo pipefail

BOLD=$(tput bold 2>/dev/null||echo)
DIM=$(tput dim 2>/dev/null||echo)
G=$(tput setaf 2 2>/dev/null||echo)
Y=$(tput setaf 3 2>/dev/null||echo)
R=$(tput setaf 1 2>/dev/null||echo)
B=$(tput setaf 4 2>/dev/null||echo)
N=$(tput sgr0 2>/dev/null||echo)
section(){ echo;echo "${BOLD}${B}═══ $* ═══${N}";}
ok(){ echo "${G}  ✓${N} $*";}
warn(){ echo "${Y}  ⚠${N} $*";}
fail(){ echo "${R}  ✗${N} $*";}
info(){ echo "${DIM}    $*${N}";}

PLUGIN_REPOS=(
    "https://github.com/hyprwm/hyprland-plugins"
)
DEFAULT_PLUGINS=(
    "hyprbars"
    "hyprexpo"
    "hyprglass"
)

section "Zen hyprpm recovery (v26)"
if ! command -v hyprpm >/dev/null 2>&1; then
    fail "hyprpm not found"; exit 1
fi
if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    fail "Not in Hyprland session — open terminal inside Hyprland and re-run"
    exit 1
fi
ok "hyprpm available"
ok "Inside Hyprland session"

section "Step 1/6: Verify build dependencies"
MISSING=""
for cmd in cmake meson make gcc g++ pkg-config git; do
    command -v "$cmd" >/dev/null 2>&1 || MISSING="$MISSING $cmd"
done
if [ -n "$MISSING" ]; then
    fail "Missing:$MISSING"
    info "  sudo pacman -S --needed base-devel cmake meson git"
    exit 1
fi
ok "All build tools present"

section "Step 2/6: Snapshot enabled plugins"
ENABLED_BEFORE=$(hyprpm list 2>/dev/null \
    | awk '/Plugin / {p=$NF; next} /enabled: true/ {print p}' \
    | tr '\n' ' ' || echo "")
if [ -n "${ENABLED_BEFORE:-}" ]; then
    ok "Will re-enable:$ENABLED_BEFORE"
else
    info "Nothing currently enabled — installing defaults: ${DEFAULT_PLUGINS[*]}"
    ENABLED_BEFORE="${DEFAULT_PLUGINS[*]}"
fi

section "Step 3/6: Purge hyprpm cache"
hyprpm purge-cache 2>&1 | sed 's/^/    /' || \
    info "(purge-cache not on older hyprpm — using manual cleanup)"
rm -rf "$HOME/.local/share/hyprpm/headersRoot" 2>/dev/null && \
    ok "Removed ~/.local/share/hyprpm/headersRoot"
rm -rf "/tmp/hyprpm" 2>/dev/null && ok "Removed /tmp/hyprpm"
rm -rf "$HOME/.cache/hyprpm" 2>/dev/null || true
ok "Cache purged"

section "Step 4/6: hyprpm update (verbose, will prompt for sudo)"
echo "  ${DIM}Clones Hyprland source + compiles headers (1-5 min)${N}"
echo ""
if hyprpm -v update 2>&1 | sed 's/^/    │ /'; then
    ok "Headers rebuilt successfully"
else
    fail "hyprpm update failed"
    exit 1
fi

# ★ THE V26 FIX: Re-add plugin REPOS (was missing in v25)
section "Step 5/6: Re-add plugin repositories (verbose)"
echo "  ${DIM}Builds plugin .so files — visible compile output below${N}"
echo ""

EXISTING_REPOS=$(hyprpm list 2>/dev/null \
    | awk '/^→ Repository/ {print $3}' \
    | tr '\n' ' ' || echo "")

for repo in "${PLUGIN_REPOS[@]}"; do
    repo_name=$(basename "$repo")
    if echo " $EXISTING_REPOS " | grep -q " $repo_name "; then
        ok "$repo_name already added (--needed skip)"
        continue
    fi
    echo ""
    echo "  Adding + building: $repo_name"
    echo "  ────────────────────────────────────────────"
    if hyprpm -v add "$repo" 2>&1 | sed 's/^/    │ /'; then
        ok "$repo_name done"
    else
        warn "$repo_name had issues — check output above"
    fi
    echo "  ────────────────────────────────────────────"
done

echo ""
echo "  Plugin status after re-add:"
hyprpm list 2>&1 | sed 's/^/    /' | head -40

section "Step 6/6: Re-enable plugins + reload"
re_enabled=0
re_skipped=0
for plugin in $ENABLED_BEFORE; do
    EN_OUT=$(hyprpm enable "$plugin" 2>&1)
    if echo "$EN_OUT" | grep -qE "enabled|already enabled"; then
        ok "$plugin enabled"
        re_enabled=$((re_enabled+1))
    elif echo "$EN_OUT" | grep -qE "no such plugin|not found|failed"; then
        warn "$plugin: build failed (try AUR: paru -S hyprland-plugins-git)"
        re_skipped=$((re_skipped+1))
    else
        warn "$plugin: $EN_OUT"
    fi
done
info "$re_enabled enabled / $re_skipped skipped"

echo ""
echo "  Running hyprpm reload..."
hyprpm reload 2>&1 | sed 's/^/    /' || true

# Update state file for PluginsPage UI
STATE_DIR="$HOME/.config/quickshell/zen-shell"
mkdir -p "$STATE_DIR"
STATE_FILE="$STATE_DIR/hyprpm-state.json"
BUILT=$(hyprpm list 2>/dev/null \
    | awk '/Plugin / {p=$NF; next} /enabled:/ {if (!/failed/) print p}' \
    | tr '\n' ' ')
FAILED=$(hyprpm list 2>/dev/null \
    | awk '/Plugin / {p=$NF; next} /enabled:.*failed/ {print p}' \
    | tr '\n' ' ')
{
    echo "{"
    echo "  \"updated_at\": \"$(date -Iseconds)\","
    echo "  \"built\": ["
    FIRST=1
    for p in $BUILT; do
        [ "$FIRST" = 1 ] || echo ","
        printf '    "%s"' "$p"
        FIRST=0
    done
    echo ""
    echo "  ],"
    echo "  \"failed\": ["
    FIRST=1
    for p in $FAILED; do
        [ "$FIRST" = 1 ] || echo ","
        printf '    "%s"' "$p"
        FIRST=0
    done
    echo ""
    echo "  ]"
    echo "}"
} > "$STATE_FILE"
ok "State file written"

echo ""
echo "${BOLD}${G}═══ Recovery complete ═══${N}"
[ -n "$BUILT" ] && echo "  Built: $BUILT"
[ -n "$FAILED" ] && echo "  ${Y}Failed: $FAILED${N}"
echo ""
echo "Next: refresh Settings → Hyprland Plugins (toggles should now work)"
echo "If toggles still grayed: zs-restart.sh to refresh shell"
