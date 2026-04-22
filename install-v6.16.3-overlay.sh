#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
# install-v6.16.3-overlay.sh
# ────────────────────────────────────────────────────────────────
# In v6.16.3.3 the overlay phases were merged into the main
# install.sh, so this is now just a convenience shim that forwards
# to `./install.sh`. Keeping it around means old docs, bookmarks,
# and muscle memory ("overlay command") still work.
#
# If you want ONLY the v6.16.3 stack (skip the big [1/9]…[9/9]
# fresh-install steps), run the main install.sh — all of those
# earlier steps are idempotent and detect existing installs, so
# re-running them is cheap:
#
#   ./install.sh
#
# is the same as what the old standalone overlay did, plus it
# guarantees your base install is in sync with the tarball too.
# ════════════════════════════════════════════════════════════════

set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ ! -x "$SCRIPT_DIR/install.sh" ]; then
    echo "ERROR: install.sh not found/executable at $SCRIPT_DIR/install.sh" >&2
    exit 1
fi

echo "── v6.16.3 overlay is now integrated into install.sh ──"
echo "   forwarding to: $SCRIPT_DIR/install.sh"
echo ""
exec "$SCRIPT_DIR/install.sh" "$@"
