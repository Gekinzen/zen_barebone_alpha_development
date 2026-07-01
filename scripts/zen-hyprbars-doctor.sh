#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
# zen-hyprbars-doctor.sh v7.0.0-beta.1-hf95.25
# ────────────────────────────────────────────────────────────────
# One-shot diagnose + auto-repair for the recurring hyprpm
# "Outdated headers. Please run hyprpm update manually." failure.
#
# WHY hyprpm keeps failing on your box:
#   `hyprpm update` clones the Hyprland SOURCE matching your release
#   TAG and builds headers from it, then builds the plugin against
#   those headers. On a fast-moving / -git / CachyOS Hyprland (e.g.
#   0.55.2 with a dirty/dev commit) there is no exact-match tagged
#   source hyprpm can resolve, so the header build never succeeds —
#   and `hyprpm add/enable/reload` ALL depend on that, so they all
#   fail too. Running them again can't help; the headers are the wall.
#
# WHAT THIS DOES instead — it BYPASSES hyprpm's header build entirely:
#   builds hyprbars from the AUR (`-git`, then stable) against your
#   SYSTEM headers (/usr/include/hyprland from the `hyprland` package),
#   symlinks the .so into hyprpm's plugin dir so Zen Shell detects it,
#   and loads it directly with `hyprctl plugin load` (which works even
#   when hyprpm marks the plugin as failed).
#
# Safe + idempotent. Re-run anytime. Wala tayong babawasan.
#
# Usage:
#   zen-hyprbars-doctor.sh            # diagnose + auto-repair
#   zen-hyprbars-doctor.sh --diagnose # diagnose only, no changes
# ════════════════════════════════════════════════════════════════
set -u

B=$(tput bold 2>/dev/null || echo); N=$(tput sgr0 2>/dev/null || echo)
G=$(tput setaf 2 2>/dev/null || echo); Y=$(tput setaf 3 2>/dev/null || echo)
R=$(tput setaf 1 2>/dev/null || echo); C=$(tput setaf 6 2>/dev/null || echo)
ok(){   echo "${G}✓${N} $*"; }
warn(){ echo "${Y}⚠${N} $*"; }
bad(){  echo "${R}✗${N} $*"; }
hdr(){  echo; echo "${B}${C}━━ $* ━━${N}"; }

DIAGNOSE_ONLY=0
[ "${1:-}" = "--diagnose" ] && DIAGNOSE_ONLY=1

HYPRPM_PLUGIN_DIR="$HOME/.local/share/hyprpm/hyprland-plugins/hyprbars"

# ─────────────────────────────────────────────────────────────────
hdr "1. Hyprland build"
# ─────────────────────────────────────────────────────────────────
RAW="$(hyprctl version 2>/dev/null)"
if [ -z "$RAW" ]; then
    bad "hyprctl not responding — are you inside a running Hyprland session?"
    exit 1
fi
TAG="$(echo "$RAW" | grep -oE 'Tag: v?[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 | sed 's/Tag: v\?//')"
[ -z "$TAG" ] && TAG="$(echo "$RAW" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)"
COMMIT="$(echo "$RAW" | grep -oE 'commit [0-9a-f]{7,}' | head -1 | awk '{print $2}')"
IS_DEV=0
echo "$RAW" | grep -qiE "dirty|dev|git" && IS_DEV=1
pacman -Qq hyprland-git >/dev/null 2>&1 && IS_DEV=1
echo "    Version : ${TAG:-unknown}"
echo "    Commit  : ${COMMIT:-unknown}"
if [ "$IS_DEV" = "1" ]; then
    warn "git/dev/dirty build → hyprpm's pinned headers will NOT match."
    echo "    This is exactly why 'hyprpm update' reports Outdated headers."
else
    ok "tagged release build (hyprpm MIGHT work, but AUR is still safest)"
fi

# v7.0.0-beta.1-hf95.26 — RUNNING vs INSTALLED version skew.
# The #1 cause of "hyprpm says a different version than hyprctl" is a
# `pacman -Syu` that upgraded the hyprland PACKAGE while your CURRENT
# session is still the OLD binary (you haven't logged out/in since).
# hyprctl reports the RUNNING version; hyprpm checks the INSTALLED one;
# they disagree → hyprpm refuses. NO script can bridge this — the running
# compositor must be restarted. Detect + warn loudly.
SKEW=0
PKG_VER="$(pacman -Q hyprland 2>/dev/null | awk '{print $2}' | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)"
if [ -z "$PKG_VER" ]; then
    PKG_VER="$(pacman -Q hyprland-git 2>/dev/null | awk '{print $2}' | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)"
fi
if [ -n "$PKG_VER" ] && [ -n "$TAG" ] && [ "$PKG_VER" != "$TAG" ]; then
    SKEW=1
    echo
    bad "VERSION SKEW DETECTED:"
    echo "      running (hyprctl): ${B}$TAG${N}"
    echo "      installed (pacman): ${B}$PKG_VER${N}"
    warn "Your hyprland PACKAGE was updated (likely by a recent 'pacman -Syu')"
    warn "but this SESSION is still the old binary. hyprpm checks the new"
    warn "version, hyprctl reports the old one — so they disagree and hyprpm"
    warn "refuses to build. ${B}No tool can fix this from inside the session.${N}"
    echo
    echo "    ${B}${C}→ FIX: log out and log back in (or reboot), then re-run"
    echo "         this doctor.${N} After relogin hyprctl and hyprpm will"
    echo "         agree and the plugin build will work."
    echo
elif [ -n "$PKG_VER" ]; then
    ok "running and installed Hyprland versions match ($TAG)"
fi

# ─────────────────────────────────────────────────────────────────
hdr "2. Build prerequisites"
# ─────────────────────────────────────────────────────────────────
HELPER=""
command -v paru >/dev/null && HELPER=paru
[ -z "$HELPER" ] && command -v yay >/dev/null && HELPER=yay
if [ -n "$HELPER" ]; then ok "AUR helper: $HELPER"; else bad "no AUR helper (paru/yay)"; fi

HAVE_HEADERS=0
if [ -d /usr/include/hyprland ] || pkg-config --exists hyprland 2>/dev/null; then
    HAVE_HEADERS=1
    ok "system Hyprland headers present (/usr/include/hyprland)"
else
    bad "no system Hyprland headers — install the 'hyprland' package"
fi

HYPR_PKG="$(pacman -Qq 2>/dev/null | grep -E '^hyprland(-git)?$' | head -1)"
echo "    hyprland package: ${HYPR_PKG:-<none / not from pacman>}"

# ─────────────────────────────────────────────────────────────────
hdr "3. Current hyprbars / hyprpm state"
# ─────────────────────────────────────────────────────────────────
if hyprctl plugin list 2>/dev/null | grep -qi hyprbars; then
    ok "hyprbars is currently LOADED"
else
    warn "hyprbars not loaded"
fi
if [ -e "$HYPRPM_PLUGIN_DIR/hyprbars.so" ]; then
    ok "symlink/file present: $HYPRPM_PLUGIN_DIR/hyprbars.so"
    ls -l "$HYPRPM_PLUGIN_DIR/hyprbars.so" | sed 's/^/      /'
else
    warn "no hyprbars.so in hyprpm dir yet"
fi

if [ "$DIAGNOSE_ONLY" = "1" ]; then
    hdr "Diagnosis complete (no changes made)"
    echo "Re-run without --diagnose to auto-repair."
    exit 0
fi

# hf95.26 — if running≠installed, repair is pointless until relogin.
if [ "$SKEW" = "1" ]; then
    hdr "Stopping — relogin required first"
    bad "Running Hyprland ($TAG) ≠ installed ($PKG_VER)."
    echo "    Log out and back in (or reboot), then run this doctor again."
    echo "    Nothing was changed."
    exit 2
fi

# ─────────────────────────────────────────────────────────────────
hdr "4. Try hyprpm update first (automatic, with sudo)"
# ─────────────────────────────────────────────────────────────────
# On a matched tagged-release setup this can just work, so try it before
# the AUR path. We pre-seed sudo so the build step isn't interrupted, and
# parse the output: if it hits the classic header/version failure we fall
# straight through to the AUR build instead of stopping.
HYPRPM_WORKED=0
if command -v hyprpm >/dev/null 2>&1; then
    echo "    Caching sudo credentials (you may be prompted once)…"
    sudo -v 2>/dev/null || warn "sudo not pre-authed; hyprpm may prompt mid-run"

    # hf95.26b — helper: run `hyprpm update` and report pass/fail by output.
    _run_hyprpm_update() {
        local log; log="$(mktemp)"
        hyprpm update 2>&1 | tee "$log" | sed 's/^/      │ /'
        if grep -qiE "outdated headers|version mismatch|headers (missing|mismatched)|error code|couldn't|could not|failed" "$log"; then
            rm -f "$log"; return 1
        fi
        rm -f "$log"; return 0
    }

    echo "    Running: hyprpm update"
    if _run_hyprpm_update; then
        HYPRPM_UPDATE_OK=1
    else
        # error code 4 "Headers version mismatched" on a CLEAN tagged build
        # is almost always a STALE hyprpm cache. The official fix is
        # `hyprpm purge-cache` then update again — do it automatically.
        warn "Update failed — purging hyprpm cache and retrying (official fix)…"
        hyprpm purge-cache 2>&1 | sed 's/^/      │ /' \
            || echo "      (purge-cache unavailable on this hyprpm — cleaning dirs)"
        rm -rf "$HOME/.local/share/hyprpm/headersRoot" \
               "$HOME/.cache/hyprpm" "/tmp/hyprpm" 2>/dev/null || true
        echo "    Retrying: hyprpm update"
        if _run_hyprpm_update; then
            HYPRPM_UPDATE_OK=1
            ok "headers built after purge-cache."
        else
            HYPRPM_UPDATE_OK=0
        fi
    fi

    if [ "${HYPRPM_UPDATE_OK:-0}" = "1" ]; then
        echo "    Adding plugin repo + enabling hyprbars…"
        hyprpm add https://github.com/hyprwm/hyprland-plugins 2>&1 | sed 's/^/      │ /' || true
        hyprpm enable hyprbars 2>&1 | sed 's/^/      │ /' || true
        hyprpm reload 2>&1 | sed 's/^/      │ /' || true
        sleep 1
        if hyprctl plugin list 2>/dev/null | grep -qi hyprbars; then
            HYPRPM_WORKED=1
            ok "hyprbars loaded via hyprpm."
        else
            warn "hyprpm reported OK but hyprbars not listed — using AUR path."
        fi
    else
        warn "hyprpm update still failing after purge — using the AUR path below."
    fi
else
    warn "hyprpm not found — skipping to AUR path."
fi

if [ "$HYPRPM_WORKED" = "1" ]; then
    hdr "Done — installed via hyprpm"
    echo "Toggle hyprbars in Settings → Hyprbars, or add to plugins.conf."
    exit 0
fi

# ─────────────────────────────────────────────────────────────────
hdr "5. Auto-repair — AUR build against system headers"
# ─────────────────────────────────────────────────────────────────
# This is the path that actually works on a mismatched Hyprland: it
# never touches hyprpm's broken header build.
if [ -z "$HELPER" ]; then
    bad "Can't auto-repair without an AUR helper."
    echo "    Install paru first:"
    echo "      sudo pacman -S --needed base-devel git"
    echo "      git clone https://aur.archlinux.org/paru.git"
    echo "      cd paru && makepkg -si"
    exit 1
fi
if [ "$HAVE_HEADERS" = "0" ]; then
    bad "Can't build the AUR plugin without system headers."
    echo "    Install the matching Hyprland package (provides the headers):"
    echo "      sudo pacman -S --needed hyprland"
    echo "    (or the -git package if you run a git build:)"
    echo "      $HELPER -S --needed hyprland-git"
    exit 1
fi

PKG=""
# hf95.28b — package preference depends on the Hyprland build:
#   • repo/tagged Hyprland (your 0.55.2-2.1) → STABLE plugin first; the
#     -git plugin often targets hyprland-git headers (newer) and would
#     re-trigger the "headers != running" mismatch.
#   • git/dev Hyprland → -git plugin first.
if [ "$IS_DEV" = "1" ]; then
    _PKG_ORDER="hyprland-plugin-hyprbars-git hyprland-plugin-hyprbars"
else
    _PKG_ORDER="hyprland-plugin-hyprbars hyprland-plugin-hyprbars-git"
fi
for c in $_PKG_ORDER; do
    if $HELPER -Si "$c" >/dev/null 2>&1; then PKG="$c"; break; fi
done
if [ -z "$PKG" ]; then
    bad "No hyprbars AUR package found. Try: $HELPER -Ss hyprbars"
    exit 1
fi

# hf95.28b — PURGE stale builds first. The "headers ver != running" error
# with MATCHING hyprctl/pacman versions means an OLD .so (built against a
# previous Hyprland) is still cached/loaded. Remove every copy + unload it
# so the fresh build below is the only one, built against current headers.
echo "    Unloading any currently-loaded hyprbars + clearing stale builds…"
hyprctl plugin unload "$(hyprctl plugin list 2>/dev/null | grep -i hyprbars -A2 | grep -oE '/[^ ]+hyprbars[^ ]*\.so' | head -1)" 2>/dev/null || true
rm -f "$HYPRPM_PLUGIN_DIR/hyprbars.so" 2>/dev/null || true
find "$HOME/.local/share/hyprpm" /run/user/$(id -u)/hyprpm /tmp/hyprpm \
     -name "*hyprbars*.so" -delete 2>/dev/null || true
# Force a clean rebuild (not --needed) so a stale installed package is
# recompiled against the CURRENT headers.
ok "Rebuilding $PKG fresh against current Hyprland headers…"
echo "    (this will prompt for sudo to install the built package)"
if ! $HELPER -S "$PKG"; then
    bad "AUR build/install failed — see the output above."
    echo "    Most common cause: the -git package needs hyprland-git headers."
    echo "    If you run repo Hyprland, try the stable plugin:"
    echo "      $HELPER -S hyprland-plugin-hyprbars"
    exit 1
fi

# Locate the built .so
SO=""
for cand in /usr/lib/libhyprbars.so \
            /usr/lib/hyprland-plugins/hyprbars.so \
            /usr/lib/hyprland/hyprbars.so; do
    [ -f "$cand" ] && SO="$cand" && break
done
if [ -z "$SO" ]; then
    warn "Built, but couldn't auto-locate hyprbars.so. Package contents:"
    pacman -Ql "$PKG" 2>/dev/null | grep -E '\.so$' | sed 's/^/      /'
    bad "Find the .so above, then run:"
    echo "      ln -sf <path> $HYPRPM_PLUGIN_DIR/hyprbars.so"
    echo "      hyprctl plugin load <path>"
    exit 1
fi
ok "Found built plugin: $SO"

# Symlink into hyprpm's dir so Zen Shell's PluginsPage detects it
mkdir -p "$HYPRPM_PLUGIN_DIR"
ln -sf "$SO" "$HYPRPM_PLUGIN_DIR/hyprbars.so"
ok "Symlinked → $HYPRPM_PLUGIN_DIR/hyprbars.so"

# ─────────────────────────────────────────────────────────────────
hdr "6. Load it (bypassing hyprpm)"
# ─────────────────────────────────────────────────────────────────
hyprctl reload 2>&1 | sed 's/^/    /' || true
echo "    Loading directly via hyprctl plugin load…"
_LOADLOG="$(mktemp)"
hyprctl plugin load "$SO" 2>&1 | tee "$_LOADLOG" | sed 's/^/    /' || true
sleep 1
if hyprctl plugin list 2>/dev/null | grep -qi hyprbars; then
    echo
    ok "${B}hyprbars is now LOADED.${N} Open a floating window — it should have a title bar."
    rm -f "$_LOADLOG"
elif grep -qiE "version mismatch|headers ver is not equal|not equal to running" "$_LOADLOG"; then
    # hf95.28 — THE error Paul hit: the built .so's header version != the
    # RUNNING Hyprland. Almost always because a `pacman -Syu` updated the
    # hyprland headers/package, but THIS session is still the old binary.
    # A rebuilt plugin will keep mismatching until the compositor itself
    # is restarted to match the new headers.
    rm -f "$_LOADLOG"
    echo
    bad "${B}Version mismatch: the plugin's headers ≠ your RUNNING Hyprland.${N}"
    echo
    warn "This means your Hyprland was updated on disk (e.g. the recent"
    warn "'pacman -Syu'), but the COMPOSITOR you're in right now is still the"
    warn "old build. The plugin is compiled for the NEW headers, so it refuses"
    warn "to load into the OLD running instance."
    echo
    echo "    ${B}${C}→ FIX (required): fully restart Hyprland — log out and log"
    echo "         back in, or reboot.${N} That reloads the compositor at the"
    echo "         same version as the headers the plugin was built against."
    echo
    echo "    After you log back in, run this once and hyprbars will load:"
    echo "      ${B}zen-hyprbars-doctor.sh${N}"
    echo
    echo "    (Tip: confirm they match after relogin with —"
    echo "      hyprctl version | grep Tag    # running"
    echo "      pacman -Q hyprland            # installed)"
    exit 3
else
    rm -f "$_LOADLOG"
    warn "Plugin loaded command ran but hyprbars not yet listed."
    echo "    Try: zs-restart.sh   (restart the shell), then check Settings → Hyprbars."
fi

# ─────────────────────────────────────────────────────────────────
hdr "7. Make it persistent"
# ─────────────────────────────────────────────────────────────────
echo "To auto-load hyprbars on Hyprland start, add this to"
echo "  ~/.config/hypr/modules/plugins.conf :"
echo "      ${B}plugin = $SO${N}"
echo "Or just toggle it ON in Settings → Hyprbars (Zen Shell will"
echo "remember and reload it)."
echo
ok "Done. If anything above is still red, copy this whole output to share."
