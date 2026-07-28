#!/usr/bin/env bash
# zen-update-install.sh v7.0.0-alpha.1
#
# Downloads a release tarball from GitHub and runs its install.sh.
# Optionally creates a snapshot of the current install first.
#
# Usage:
#   zen-update-install.sh --repo owner/repo --tag vX.Y.Z [--snapshot]
#
# Process:
#   1. (Optional) Create snapshot of current install via zen-snapshot-create.sh
#   2. Download tarball to ~/.cache/zen-shell/updates/
#   3. Verify download (size > 1KB sanity check)
#   4. Extract to temp dir
#   5. Run install.sh from extracted dir with --no-bootstrap
#      (bootstrap is for first-install dependency setup, not updates)
#   6. Clean up
#
# Exit 0 on success, non-zero on failure. Last line of stdout becomes UI footer.

set -euo pipefail

REPO=""
TAG=""
DO_SNAPSHOT=0

while [ $# -gt 0 ]; do
    case "$1" in
        --repo)     REPO="$2"; shift 2 ;;
        --tag)      TAG="$2";  shift 2 ;;
        --snapshot) DO_SNAPSHOT=1; shift ;;
        *) shift ;;
    esac
done

STATE_DIR="$HOME/.local/share/zen-shell"
LOG="$STATE_DIR/updates.log"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/zen-shell/updates"

# Sibling scripts live alongside this one (v7 design — see ZenUpdateService.qml)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SNAPSHOT_BIN="$SCRIPT_DIR/zen-snapshot-create.sh"

mkdir -p "$STATE_DIR" "$CACHE_DIR"

log() {
    echo "[$(date -Iseconds)] $*" >> "$LOG"
    echo "$*"
}

if [ -z "$REPO" ] || [ -z "$TAG" ]; then
    log "ERROR: --repo and --tag required"
    exit 2
fi

# ── Pre-snapshot ──
if [ "$DO_SNAPSHOT" -eq 1 ]; then
    if [ -x "$SNAPSHOT_BIN" ]; then
        ver_now="pre-update"
        zver="$HOME/.config/quickshell/zen-shell/ZenVersion.qml"
        if [ -f "$zver" ]; then
            v=$(grep -m1 'readonly property string version:' "$zver" \
                | sed 's/.*"\([^"]*\)".*/\1/')
            [ -n "$v" ] && ver_now="$v"
        fi
        log "Snapshotting current install ($ver_now)…"
        "$SNAPSHOT_BIN" --version "$ver_now" --label "pre-update-to-$TAG" 2>&1 | tail -1 || {
            log "WARNING: snapshot failed but continuing with install"
        }
    else
        log "WARNING: $SNAPSHOT_BIN missing — proceeding without snapshot"
    fi
fi

# ── Download tarball ──
TARBALL="$CACHE_DIR/${TAG}.tgz"
URL="https://github.com/${REPO}/archive/refs/tags/${TAG}.tar.gz"

log "Downloading $TAG from $REPO…"
HTTP=$(curl -sL -w "%{http_code}" -o "$TARBALL.part" --max-time 120 "$URL")
if [ "$HTTP" != "200" ]; then
    rm -f "$TARBALL.part"
    log "ERROR: download failed (HTTP $HTTP) from $URL"
    exit 3
fi

# Sanity: tarball should be > 1KB.
SIZE=$(stat -c %s "$TARBALL.part" 2>/dev/null || echo 0)
if [ "$SIZE" -lt 1024 ]; then
    rm -f "$TARBALL.part"
    log "ERROR: download too small ($SIZE bytes) — likely a redirect or 404 page"
    exit 4
fi

mv "$TARBALL.part" "$TARBALL"
log "Downloaded $(numfmt --to=iec --suffix=B "$SIZE" 2>/dev/null || echo "${SIZE}B")"

# ── Extract ──
EXTRACT_DIR=$(mktemp -d -t "zen-update-$TAG.XXXXXX")
trap 'rm -rf "$EXTRACT_DIR"' EXIT

log "Extracting…"
if ! tar -xzf "$TARBALL" -C "$EXTRACT_DIR"; then
    log "ERROR: tarball extraction failed"
    exit 5
fi

# Find install.sh — top-level dir is usually <reponame>-<tag-without-v>/
INSTALLER=$(find "$EXTRACT_DIR" -maxdepth 3 -name install.sh -type f 2>/dev/null | head -1)
if [ -z "$INSTALLER" ] || [ ! -f "$INSTALLER" ]; then
    log "ERROR: install.sh not found in tarball"
    exit 6
fi

INSTALL_DIR=$(dirname "$INSTALLER")
log "Running installer from $(basename "$INSTALL_DIR")…"

# Run install.sh in --no-bootstrap mode (deps already met for an upgrade).
# Capture output for log; final line goes to UI.
cd "$INSTALL_DIR"
chmod +x ./install.sh
# v7.0.0-beta.1-hf81 — pass-through version override from caller env.
# ZenUpdateService.qml can set this via launcher to force-update across
# a major.minor jump (e.g. hyprland 0.54 → 0.55).
if ZEN_FORCE_VERSIONS="${ZEN_FORCE_VERSIONS:-0}" ./install.sh --no-bootstrap 2>&1 | tee -a "$LOG" | tail -50; then
    log "Update installed successfully: $TAG"
    exit 0
else
    rc=$?
    log "ERROR: installer exited with code $rc"
    exit $rc
fi
