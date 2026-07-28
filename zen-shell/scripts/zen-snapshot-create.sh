#!/usr/bin/env bash
# zen-snapshot-create.sh v7.0.0-alpha.1
#
# Snapshot management for Zen Shell installations.
#
# Subcommands:
#   create   (default — when --version provided)
#     --version <vX.Y.Z>     [required]
#     --codename <name>      [optional, default ""]
#     --channel <chan>       [optional, default "alpha"]
#     --label <text>         [optional, default "manual"]
#
#   --delete <snapshot-path>     Delete a snapshot directory + manifest entry
#   --pin    <snapshot-path>     Mark snapshot as pinned (protected from prune)
#   --unpin  <snapshot-path>     Unmark
#   --prune                      Run retention pruning (auto-called after create)
#
# Snapshot layout:
#   ~/.local/share/zen-shell/snapshots/
#     v7.0.0-alpha.1-2026-05-08T14-32-10/
#       qml/                  ← copy of installed QML files
#       state/                ← copy of state JSON files
#       SNAPSHOT.json         ← per-snapshot metadata
#     manifest.json           ← top-level index
#
# Stdout: human-readable status messages (last line shown in UI footer).
# Exit 0 on success, non-zero on failure.

set -euo pipefail

SHELL_DIR="$HOME/.config/quickshell/zen-shell"
STATE_DIR="$HOME/.local/share/zen-shell"
SNAP_DIR="$STATE_DIR/snapshots"
MANIFEST="$SNAP_DIR/manifest.json"
LOG="$STATE_DIR/updates.log"

mkdir -p "$SNAP_DIR" "$STATE_DIR"

log() {
    echo "[$(date -Iseconds)] $*" >> "$LOG"
    echo "$*"
}

# Ensure manifest exists with valid skeleton.
ensure_manifest() {
    if [ ! -s "$MANIFEST" ]; then
        echo '{"_schema":7,"snapshots":[]}' > "$MANIFEST"
    fi
}

# JSON manipulation helpers (require jq).
require_jq() {
    if ! command -v jq >/dev/null 2>&1; then
        log "ERROR: jq is required for snapshot management."
        exit 2
    fi
}

# Atomic write: write to .tmp then mv.
write_json_atomic() {
    local path="$1"; local content="$2"
    local tmp; tmp=$(mktemp "${path}.XXXXXX")
    printf '%s\n' "$content" > "$tmp"
    mv "$tmp" "$path"
}

# Compute size of a directory in bytes.
dir_size_bytes() {
    du -sb "$1" 2>/dev/null | awk '{print $1}'
}

# ─────────────────────────────────────────────────────────
# CREATE
# ─────────────────────────────────────────────────────────
cmd_create() {
    local version="" codename="" channel="alpha" label="manual"
    while [ $# -gt 0 ]; do
        case "$1" in
            --version)  version="$2";  shift 2 ;;
            --codename) codename="$2"; shift 2 ;;
            --channel)  channel="$2";  shift 2 ;;
            --label)    label="$2";    shift 2 ;;
            *) shift ;;
        esac
    done

    if [ -z "$version" ]; then
        log "ERROR: --version required for snapshot create"
        exit 2
    fi

    require_jq
    ensure_manifest

    if [ ! -d "$SHELL_DIR" ]; then
        log "ERROR: shell dir missing: $SHELL_DIR"
        exit 3
    fi

    local ts
    ts=$(date +%Y-%m-%dT%H-%M-%S)
    local snap_name="${version}-${ts}"
    local snap_path="$SNAP_DIR/$snap_name"

    if [ -e "$snap_path" ]; then
        log "ERROR: snapshot already exists: $snap_path"
        exit 4
    fi

    mkdir -p "$snap_path/qml" "$snap_path/state"

    # Copy QML + .conf files (everything in shell dir).
    cp -a "$SHELL_DIR/." "$snap_path/qml/" 2>/dev/null || true

    # Copy state files (excluding snapshots dir itself — would recurse forever).
    if [ -d "$STATE_DIR" ]; then
        for f in "$STATE_DIR"/*.json "$STATE_DIR"/*.state; do
            [ -f "$f" ] || continue
            cp -a "$f" "$snap_path/state/" 2>/dev/null || true
        done
    fi

    local size_bytes
    size_bytes=$(dir_size_bytes "$snap_path")

    # Per-snapshot metadata
    local snap_meta
    snap_meta=$(jq -nc \
        --arg version "$version" \
        --arg codename "$codename" \
        --arg channel "$channel" \
        --arg label "$label" \
        --arg ts "$(date -Iseconds)" \
        --arg path "$snap_path" \
        --argjson size "$size_bytes" \
        --argjson schema 7 \
        '{_schema:$schema, version:$version, codename:$codename, channel:$channel,
          label:$label, timestamp:$ts, path:$path, sizeBytes:$size, pinned:false}')
    write_json_atomic "$snap_path/SNAPSHOT.json" "$snap_meta"

    # Add to manifest
    local new_manifest
    new_manifest=$(jq --argjson entry "$snap_meta" \
        '.snapshots = [$entry] + .snapshots' "$MANIFEST")
    write_json_atomic "$MANIFEST" "$new_manifest"

    log "Snapshot created: $snap_name ($(numfmt --to=iec --suffix=B "$size_bytes" 2>/dev/null || echo "${size_bytes}B"))"

    # Prune
    cmd_prune
}

# ─────────────────────────────────────────────────────────
# DELETE
# ─────────────────────────────────────────────────────────
cmd_delete() {
    local target="$1"
    require_jq
    ensure_manifest

    if [ -z "$target" ] || [ ! -d "$target" ]; then
        log "ERROR: snapshot path missing or not a directory: $target"
        exit 5
    fi

    # Safety: refuse to delete anything outside SNAP_DIR.
    case "$target" in
        "$SNAP_DIR"/*) ;;
        *) log "ERROR: refusing to delete outside snapshot dir: $target"; exit 6 ;;
    esac

    # Refuse to delete pinned snapshots.
    local is_pinned
    is_pinned=$(jq -r --arg p "$target" '.snapshots[] | select(.path == $p) | .pinned // false' "$MANIFEST" 2>/dev/null)
    if [ "$is_pinned" = "true" ]; then
        log "ERROR: snapshot is pinned — unpin first"
        exit 7
    fi

    rm -rf "$target"

    local new_manifest
    new_manifest=$(jq --arg p "$target" \
        '.snapshots = [.snapshots[] | select(.path != $p)]' "$MANIFEST")
    write_json_atomic "$MANIFEST" "$new_manifest"

    log "Snapshot deleted: $(basename "$target")"
}

# ─────────────────────────────────────────────────────────
# PIN / UNPIN
# ─────────────────────────────────────────────────────────
cmd_setpin() {
    local target="$1"; local pinned="$2"
    require_jq
    ensure_manifest

    if [ -z "$target" ]; then
        log "ERROR: snapshot path required"
        exit 8
    fi

    local found
    found=$(jq -r --arg p "$target" '.snapshots[] | select(.path == $p) | .path' "$MANIFEST")
    if [ -z "$found" ]; then
        log "ERROR: snapshot not in manifest: $target"
        exit 9
    fi

    local new_manifest
    new_manifest=$(jq --arg p "$target" --argjson pin "$pinned" \
        '.snapshots = [.snapshots[] | if .path == $p then .pinned = $pin else . end]' \
        "$MANIFEST")
    write_json_atomic "$MANIFEST" "$new_manifest"

    # Mirror to per-snapshot file.
    if [ -f "$target/SNAPSHOT.json" ]; then
        local snap_meta
        snap_meta=$(jq --argjson pin "$pinned" '.pinned = $pin' "$target/SNAPSHOT.json")
        write_json_atomic "$target/SNAPSHOT.json" "$snap_meta"
    fi

    log "Snapshot $([ "$pinned" = "true" ] && echo pinned || echo unpinned): $(basename "$target")"
}

# ─────────────────────────────────────────────────────────
# PRUNE — keep N newest unpinned, drop the rest
# ─────────────────────────────────────────────────────────
cmd_prune() {
    require_jq
    ensure_manifest

    # Read retention from update-state.json (default 5).
    local retain=5
    local us="$HOME/.config/quickshell/zen-shell/update-state.json"
    if [ -f "$us" ]; then
        local r
        r=$(jq -r '.maxSnapshotsRetained // empty' "$us" 2>/dev/null)
        if [ -n "$r" ] && [ "$r" -gt 0 ] 2>/dev/null; then
            retain="$r"
        fi
    fi

    # Sort unpinned snapshots by timestamp DESC, drop everything past $retain.
    local to_drop
    to_drop=$(jq -r --argjson n "$retain" \
        '[.snapshots[] | select(.pinned != true)]
         | sort_by(.timestamp) | reverse
         | .[$n:] | .[] | .path' "$MANIFEST")

    local count=0
    while IFS= read -r p; do
        [ -z "$p" ] && continue
        [ ! -d "$p" ] && continue
        case "$p" in
            "$SNAP_DIR"/*) ;;
            *) continue ;;
        esac
        rm -rf "$p"
        local new_manifest
        new_manifest=$(jq --arg p "$p" \
            '.snapshots = [.snapshots[] | select(.path != $p)]' "$MANIFEST")
        write_json_atomic "$MANIFEST" "$new_manifest"
        count=$((count + 1))
    done <<< "$to_drop"

    if [ "$count" -gt 0 ]; then
        log "Pruned $count old snapshot(s) (retention: $retain)"
    fi
}

# ─────────────────────────────────────────────────────────
# DISPATCH
# ─────────────────────────────────────────────────────────
case "${1:-}" in
    --delete) shift; cmd_delete "${1:-}" ;;
    --pin)    shift; cmd_setpin "${1:-}" true ;;
    --unpin)  shift; cmd_setpin "${1:-}" false ;;
    --prune)  cmd_prune ;;
    --version|--codename|--channel|--label|"") cmd_create "$@" ;;
    *) log "Unknown command: $1"; exit 1 ;;
esac
