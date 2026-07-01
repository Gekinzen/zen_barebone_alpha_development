#!/usr/bin/env bash
# zen-update-check.sh v7.0.0-alpha.1
#
# Fetches the latest release from a GitHub repo, filtered by channel.
# Prints a single JSON line on stdout for ZenUpdateService to parse.
#
# Usage: zen-update-check.sh <owner/repo> <channel>
#   channel: stable | beta | alpha
#
# Output format (success):
#   {"tag":"v7.0.1","name":"...","url":"...","body":"...","date":"...","prerelease":false}
#
# Output format (failure):
#   {"error":"reason here"}
#
# Exit codes:
#   0 on success (even if no update found — JSON tag will be empty)
#   1 on network/parse failure
#
# Dependencies: curl, jq (preferred). Falls back to grep/sed if jq missing.

set -u

REPO="${1:-}"
CHANNEL="${2:-stable}"

if [ -z "$REPO" ]; then
    echo '{"error":"missing repo argument"}'
    exit 1
fi

# ── Network check ──
if ! command -v curl >/dev/null 2>&1; then
    echo '{"error":"curl not installed"}'
    exit 1
fi

# ── Cache to avoid hammering GitHub ──
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/zen-shell"
CACHE_FILE="$CACHE_DIR/releases-$(echo "$REPO" | tr '/' '_').json"
mkdir -p "$CACHE_DIR"

# Use cache if < 5 minutes old (lets the user click "Check" repeatedly
# without rate-limiting GitHub; throttling for auto-check is in QML).
CACHE_AGE_OK=0
if [ -f "$CACHE_FILE" ]; then
    age=$(( $(date +%s) - $(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0) ))
    if [ "$age" -lt 300 ]; then
        CACHE_AGE_OK=1
    fi
fi

if [ "$CACHE_AGE_OK" -eq 0 ]; then
    # Fetch /releases (not /releases/latest — latest skips prereleases).
    HTTP_CODE=$(curl -sL -w "%{http_code}" -o "$CACHE_FILE.tmp" \
        -H "Accept: application/vnd.github+json" \
        --max-time 12 \
        "https://api.github.com/repos/$REPO/releases?per_page=20" 2>/dev/null)

    if [ "$HTTP_CODE" != "200" ]; then
        rm -f "$CACHE_FILE.tmp"
        # If we have any cached file, use it as fallback.
        if [ -f "$CACHE_FILE" ]; then
            echo '{"error":"GitHub returned HTTP '"$HTTP_CODE"' — using cached data"}' >&2
        else
            echo '{"error":"GitHub fetch failed (HTTP '"$HTTP_CODE"')"}'
            exit 1
        fi
    else
        mv "$CACHE_FILE.tmp" "$CACHE_FILE"
    fi
fi

if [ ! -s "$CACHE_FILE" ]; then
    echo '{"error":"empty release data"}'
    exit 1
fi

# ── Channel filter ──
# stable: prerelease=false AND tag has no -alpha/-beta/-rc suffix
# beta:   prerelease=false OR -beta tags
# alpha:  any release (most permissive)

if command -v jq >/dev/null 2>&1; then
    case "$CHANNEL" in
        stable)
            FILTER='[.[] | select(.prerelease == false) | select(.tag_name | test("-(alpha|beta|rc)") | not)]'
            ;;
        beta)
            FILTER='[.[] | select(.tag_name | test("-alpha") | not)]'
            ;;
        alpha|*)
            FILTER='.'
            ;;
    esac
    LATEST=$(jq -c "$FILTER | .[0] // empty" "$CACHE_FILE" 2>/dev/null)
    if [ -z "$LATEST" ] || [ "$LATEST" = "null" ]; then
        echo '{"tag":"","name":"","url":"","body":"","date":"","prerelease":false}'
        exit 0
    fi
    TAG=$(echo "$LATEST"   | jq -r '.tag_name      // ""')
    NAME=$(echo "$LATEST"  | jq -r '.name          // ""')
    URL=$(echo "$LATEST"   | jq -r '.html_url      // ""')
    BODY=$(echo "$LATEST"  | jq -r '.body          // ""' | head -c 1000)
    DATE=$(echo "$LATEST"  | jq -r '.published_at  // ""')
    PRE=$(echo "$LATEST"   | jq -r '.prerelease    // false')

    # Re-emit as compact single-line JSON
    jq -nc \
        --arg tag "$TAG" --arg name "$NAME" --arg url "$URL" \
        --arg body "$BODY" --arg date "$DATE" \
        --argjson pre "$PRE" \
        '{tag:$tag, name:$name, url:$url, body:$body, date:$date, prerelease:$pre}'
    exit 0
else
    # Fallback: very crude grep parse, no channel filtering beyond
    # picking the first tag_name. Better than nothing if jq unavailable.
    TAG=$(grep -m1 '"tag_name":' "$CACHE_FILE" | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')
    URL=$(grep -m1 '"html_url":' "$CACHE_FILE" | sed 's/.*"html_url": *"\([^"]*\)".*/\1/')
    DATE=$(grep -m1 '"published_at":' "$CACHE_FILE" | sed 's/.*"published_at": *"\([^"]*\)".*/\1/')
    if [ -z "$TAG" ]; then
        echo '{"error":"could not parse release (install jq for proper parsing)"}'
        exit 1
    fi
    # Escape minimal — assumes URL/DATE have no quotes (true for GitHub).
    printf '{"tag":"%s","name":"%s","url":"%s","body":"","date":"%s","prerelease":false}\n' \
        "$TAG" "$TAG" "$URL" "$DATE"
    exit 0
fi
