#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# zen-version-check.sh
# ═══════════════════════════════════════════════════════════════
# Sourced by install.sh and bootstrap.sh. Reads versions.lock and
# verifies the currently-installed hyprland / quickshell / qt6 stack
# against the pinned major.minor recorded at release time.
#
# Patch-level drift (e.g. 0.54.3 → 0.54.4) is silently OK.
# Major.minor mismatches WARN (newer) or BLOCK (older).
#
# Public API:
#   zen_version_check_init <path-to-versions.lock>
#   zen_version_check_report                  # prints summary, sets ZEN_PIN_RC
#   zen_version_verify <pkg>                  # returns 0/1/2/3 per pkg
#
# Return-code legend for zen_version_check_report:
#   0 — all pins satisfied (patch drift allowed)
#   1 — at least one pkg is NEWER than pinned major.minor (warn-level)
#   2 — at least one pkg is OLDER than pinned major.minor (block-level)
#
# Override env:
#   ZEN_FORCE_VERSIONS=1   → silence all warnings/blocks; proceed regardless
#   ZEN_PIN_SILENT=1       → suppress report output (still sets ZEN_PIN_RC)
# ═══════════════════════════════════════════════════════════════

# Don't set -e here; we're being sourced into scripts that may not want strict mode.
# But pipefail is safe:
set -o pipefail 2>/dev/null || true

# Bash 4+ assoc arrays. install.sh/bootstrap.sh both already assume bash.
declare -gA ZEN_PIN_MM=()     # pkg → pinned major.minor (e.g. "0.54")
declare -gA ZEN_PIN_FULL=()   # pkg → full version baked at release time
declare -gA ZEN_PIN_PKG=()    # pkg → alternate AUR pkg name (e.g. quickshell-git)
declare -gA ZEN_INSTALLED=()  # pkg → currently installed version on this host

ZEN_PIN_LOCK=""
ZEN_PIN_RC=0

# ── helpers ───────────────────────────────────────────────────

_zen_strip_pacver() {
    sed -E 's/^[0-9]+://; s/-[0-9]+$//'
}

_zen_mm() {
    echo "$1" | awk -F. '{print ($1==""?"0":$1)"."($2==""?"0":$2)}'
}

_zen_pacver() {
    pacman -Q "$1" 2>/dev/null | awk '{print $2}' | _zen_strip_pacver
}

# Compare two "major.minor" strings.
# Echoes  1 if A > B, -1 if A < B, 0 if equal.
_zen_mm_cmp() {
    local a_maj a_min b_maj b_min
    IFS=. read -r a_maj a_min <<<"$1"
    IFS=. read -r b_maj b_min <<<"$2"
    a_maj=${a_maj:-0}; a_min=${a_min:-0}
    b_maj=${b_maj:-0}; b_min=${b_min:-0}
    if   [ "$a_maj" -gt "$b_maj" ] 2>/dev/null; then echo 1
    elif [ "$a_maj" -lt "$b_maj" ] 2>/dev/null; then echo -1
    elif [ "$a_min" -gt "$b_min" ] 2>/dev/null; then echo 1
    elif [ "$a_min" -lt "$b_min" ] 2>/dev/null; then echo -1
    else echo 0
    fi
}

# Resolve installed version for a known pin key.
# Returns empty if not installed.
_zen_get_installed() {
    local pkg="$1" ver=""
    case "$pkg" in
        hyprland)
            if command -v hyprctl >/dev/null 2>&1; then
                ver=$(hyprctl version 2>/dev/null \
                      | grep -oE 'Tag: v?[0-9]+(\.[0-9]+)+' | head -1 \
                      | sed 's/Tag: v\?//')
            fi
            [ -z "$ver" ] && ver=$(_zen_pacver hyprland)
            [ -z "$ver" ] && ver=$(_zen_pacver hyprland-git)
            ;;
        quickshell)
            # Honor the alternate pkg name from versions.lock if present
            local alt="${ZEN_PIN_PKG[quickshell]:-}"
            if [ -n "$alt" ]; then
                ver=$(_zen_pacver "$alt")
            fi
            [ -z "$ver" ] && ver=$(_zen_pacver quickshell-git)
            [ -z "$ver" ] && ver=$(_zen_pacver quickshell)
            # Trim git-revision tails (0.2.0.r123.g521ece4 → 0.2.0)
            ver=$(echo "$ver" | grep -oE '^[0-9]+(\.[0-9]+){0,2}' || echo "$ver")
            ;;
        qt6_declarative) ver=$(_zen_pacver qt6-declarative) ;;
        qt6_wayland)     ver=$(_zen_pacver qt6-wayland)     ;;
        qt6_5compat)     ver=$(_zen_pacver qt6-5compat)     ;;
        qt6_svg)         ver=$(_zen_pacver qt6-svg)         ;;
        *)
            # Unknown pin key — try pacman with hyphens for underscores
            ver=$(_zen_pacver "${pkg//_/-}")
            ;;
    esac
    echo "$ver"
}

# ── public API ────────────────────────────────────────────────

zen_version_check_init() {
    ZEN_PIN_LOCK="$1"
    if [ ! -r "$ZEN_PIN_LOCK" ]; then
        return 1
    fi

    # Parse k=v lines, skip comments and blanks. Strip trailing whitespace.
    local key val
    while IFS='=' read -r key val; do
        # skip empty keys & comment lines
        case "$key" in ''|\#*) continue ;; esac
        # strip surrounding whitespace
        key="${key#"${key%%[![:space:]]*}"}"
        key="${key%"${key##*[![:space:]]}"}"
        val="${val#"${val%%[![:space:]]*}"}"
        val="${val%"${val##*[![:space:]]}"}"

        if [[ "$key" == *__full ]]; then
            ZEN_PIN_FULL[${key%__full}]="$val"
        elif [[ "$key" == *__pkg ]]; then
            ZEN_PIN_PKG[${key%__pkg}]="$val"
        else
            ZEN_PIN_MM[$key]="$val"
        fi
    done < <(grep -v '^[[:space:]]*#' "$ZEN_PIN_LOCK" | grep '=' || true)

    return 0
}

# Returns:
#   0 — pinned and installed match major.minor (patch may differ)
#   1 — installed is NEWER (potentially-breaking — warn)
#   2 — installed is OLDER than pinned (block — needs upgrade)
#   3 — not installed at all
zen_version_verify() {
    local pkg="$1"
    local pin_mm="${ZEN_PIN_MM[$pkg]:-}"
    [ -z "$pin_mm" ] && return 0

    local installed_full
    installed_full=$(_zen_get_installed "$pkg")
    ZEN_INSTALLED[$pkg]="$installed_full"
    [ -z "$installed_full" ] && return 3

    local installed_mm; installed_mm=$(_zen_mm "$installed_full")
    local cmp;          cmp=$(_zen_mm_cmp "$installed_mm" "$pin_mm")
    case "$cmp" in
        0)  return 0 ;;
        1)  return 1 ;;
        -1) return 2 ;;
    esac
}

# Prints a human-readable table, sets global ZEN_PIN_RC.
zen_version_check_report() {
    [ -z "$ZEN_PIN_LOCK" ] && { ZEN_PIN_RC=0; return 0; }
    [ "${#ZEN_PIN_MM[@]}" -eq 0 ] && { ZEN_PIN_RC=0; return 0; }

    local any_warn=0 any_err=0
    local silent="${ZEN_PIN_SILENT:-0}"

    [ "$silent" != "1" ] && echo "    Version pin check (versions.lock):"

    # Sort keys deterministically so output order is stable across runs.
    local pkg
    for pkg in $(printf '%s\n' "${!ZEN_PIN_MM[@]}" | sort); do
        zen_version_verify "$pkg"; local rc=$?
        local pinmm="${ZEN_PIN_MM[$pkg]}"
        local pinfull="${ZEN_PIN_FULL[$pkg]:-?}"
        local inst="${ZEN_INSTALLED[$pkg]:-not installed}"

        if [ "$silent" != "1" ]; then
            case "$rc" in
                0) echo "      ✓ $pkg : $inst  (pinned ${pinmm}.x — match; tested $pinfull)" ;;
                1) echo "      ⚠ $pkg : $inst  (NEWER than pinned ${pinmm}.x — tested $pinfull; may have syntax/ABI breaks)" ;;
                2) echo "      ✗ $pkg : $inst  (OLDER than pinned ${pinmm}.x — upgrade required; tested $pinfull)" ;;
                3) echo "      ○ $pkg : not installed  (pinned ${pinmm}.x — will be installed by bootstrap)" ;;
            esac
        fi
        case "$rc" in
            1) any_warn=1 ;;
            2) any_err=1  ;;
        esac
    done

    # Decide the overall return code.
    if [ "$any_err" = "1" ]; then
        ZEN_PIN_RC=2
    elif [ "$any_warn" = "1" ]; then
        ZEN_PIN_RC=1
    else
        ZEN_PIN_RC=0
    fi

    # Honor ZEN_FORCE_VERSIONS=1 — force success regardless.
    if [ "${ZEN_FORCE_VERSIONS:-0}" = "1" ]; then
        if [ "$silent" != "1" ] && [ "$ZEN_PIN_RC" != "0" ]; then
            echo ""
            echo "    ZEN_FORCE_VERSIONS=1 set — proceeding despite version drift."
        fi
        ZEN_PIN_RC=0
    elif [ "$silent" != "1" ]; then
        if [ "$ZEN_PIN_RC" = "2" ]; then
            echo ""
            echo "    Some required packages are OLDER than the pinned major.minor."
            echo "    Run bootstrap.sh to install/upgrade, or set ZEN_FORCE_VERSIONS=1 to skip."
        elif [ "$ZEN_PIN_RC" = "1" ]; then
            echo ""
            echo "    Newer-than-tested versions detected. This is usually fine on Arch"
            echo "    rolling but may surface syntax/ABI mismatches (especially Hyprland)."
            echo "    Set ZEN_FORCE_VERSIONS=1 to silence."
        fi
    fi

    return 0
}
