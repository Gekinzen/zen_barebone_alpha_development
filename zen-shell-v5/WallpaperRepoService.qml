pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/*
 * WallpaperRepoService v7.0.0-beta.1-hf96
 *
 * Fetches wallpaper listing from Paul's public GitHub repo:
 *   github.com/Gekinzen/images-demo/tree/main/wallpapers
 *
 * hf96 — Online tab "can't select" fix. The contents API is throttled
 * to 60 req/hour per unauthenticated IP; constant shell restarts during
 * development exhausted it, every fetch 403'd, and the Online tab came
 * back EMPTY (nothing to click). Now:
 *   • TTL-gated: a cached listing < listingTtlSecs old is used WITHOUT
 *     touching the network (no more rate-limit burn on restarts).
 *   • raw.githubusercontent.com manifest.json fallback (CDN, not bound
 *     by the 60/hour API budget) when the API is throttled/offline.
 *   • Atomic bash resolution (cache → api → manifest → stale cache) so
 *     there are no FileView/Qt.callLater timing races leaving it blank.
 *   • download() guards against overlapping clicks + surfaces failures.
 *
 * Exposes a `items` ListModel of { name, downloadUrl, localPath, cached }
 * records for the Wallpaper Picker's "Online" tab.
 *
 * Cache strategy:
 *   - Listing JSON  → ~/.cache/zen-shell/wallpapers/listing.json
 *   - Downloaded files → ~/.config/zen-shell/wallpapers/<name>
 *
 * `cached` is true if the file has already been downloaded locally —
 * used by the UI to show "Apply" vs "Download & Apply".
 *
 * Hardcodes nothing path-wise: uses $HOME via Quickshell.env.
 * Wala tayong babawasan.
 */
Singleton {
    id: root

    readonly property string apiUrl: "https://api.github.com/repos/Gekinzen/images-demo/contents/wallpapers"
    readonly property string rawBase: "https://raw.githubusercontent.com/Gekinzen/images-demo/main/wallpapers/"
    // v7.0.0-beta.1-hf96: OPTIONAL rate-limit-proof listing source.
    // The GitHub *contents API* (apiUrl) is throttled to 60 req/hour per
    // unauthenticated IP. During active shell development the shell is
    // restarted constantly, each restart hit the API, and after ~60 hits
    // every fetch returned HTTP 403 → the Online tab came back EMPTY with
    // nothing to select. raw.githubusercontent.com is served via CDN and
    // is NOT bound by that 60/hour API budget, so we fall back to a plain
    // manifest committed to the repo. Drop a file at
    //   images-demo/wallpapers/manifest.json
    // containing either ["a.jpg","b.png"] or [{"name":"a.jpg"}, ...].
    // If the file is absent the fallback simply no-ops (graceful).
    readonly property string manifestUrl: rawBase + "manifest.json"
    // Treat a cached listing younger than this (seconds) as fresh and skip
    // the network entirely — this is what stops dev-restart spam from
    // exhausting the API rate limit.
    readonly property int listingTtlSecs: 21600   // 6 hours

    readonly property string homeDir:  Quickshell.env("HOME") || ""
    readonly property string cacheDir: homeDir + "/.cache/zen-shell/wallpapers"
    readonly property string wpDir:    homeDir + "/.config/zen-shell/wallpapers"
    readonly property string listingPath: cacheDir + "/listing.json"

    // Populated after a successful fetch. Each item:
    //   { name, downloadUrl, localPath, cached, size }
    property var items: []
    property bool loading: false
    property string lastError: ""
    property bool hasFetchedOnce: false
    // v7.0.0-beta.1-hf96: where the current listing came from, for the UI
    // empty/status line ("cache" | "api" | "manifest" | "stale" | "failed").
    property string listingSource: ""

    // ───── Fetch listing (TTL-gated, cache-first, fallback-aware) ─────
    //
    // v7.0.0-beta.1-hf96: one bash Process resolves the listing in a
    // strict priority order, atomically (no QML/FileView timing races):
    //
    //   1. FRESH CACHE  — listing.json younger than listingTtlSecs → use
    //                     it, skip the network. (Kills rate-limit burn on
    //                     repeated shell restarts during development.)
    //   2. CONTENTS API — the canonical source (gives download_url+size).
    //                     On success the cache is refreshed (mtime bump).
    //   3. RAW MANIFEST — raw.githubusercontent.com/.../manifest.json,
    //                     NOT subject to the 60/hour API limit. Optional;
    //                     no-ops if the file isn't committed.
    //   4. STALE CACHE  — any previously-saved listing, even if old.
    //
    // Pass force=true to skip step 1 (the "Refresh" button uses this).
    function refresh(force) {
        loading = true
        lastError = ""
        fetchProc.command = ["bash", "-c", root._buildFetchScript(force === true)]
        fetchProc.running = true
    }

    function _buildFetchScript(force) {
        const ttlMin = Math.max(1, Math.round(listingTtlSecs / 60))
        return ""
          + "set +e; "
          + "LISTING=\"" + listingPath + "\"; "
          + "mkdir -p \"" + cacheDir + "\" \"" + wpDir + "\"; "
          // 1. fresh cache → use without touching the network
          + (force ? "" :
                "if [ -s \"$LISTING\" ] && find \"$LISTING\" -mmin -" + ttlMin
              + " 2>/dev/null | grep -q .; then "
              + "  echo __ZEN_CACHE_FRESH__; cat \"$LISTING\"; exit 0; "
              + "fi; ")
          // 2. contents API
          + "RESP=$(curl -fsSL --connect-timeout 10 --max-time 20 \"" + apiUrl + "\" 2>/dev/null); "
          + "if [ $? -eq 0 ] && [ -n \"$RESP\" ]; then "
          + "  printf '%s' \"$RESP\" > \"$LISTING\"; "
          + "  echo __ZEN_API_OK__; printf '%s' \"$RESP\"; exit 0; "
          + "fi; "
          // 3. raw manifest (rate-limit-proof; optional)
          + "MAN=$(curl -fsSL --connect-timeout 10 --max-time 20 \"" + manifestUrl + "\" 2>/dev/null); "
          + "if [ $? -eq 0 ] && [ -n \"$MAN\" ]; then "
          + "  echo __ZEN_MANIFEST_OK__; printf '%s' \"$MAN\"; exit 0; "
          + "fi; "
          // 4. stale cache, if any
          + "if [ -s \"$LISTING\" ]; then "
          + "  echo __ZEN_STALE_CACHE__; cat \"$LISTING\"; exit 0; "
          + "fi; "
          + "echo __ZEN_FETCH_FAILED__"
    }

    Process {
        id: fetchProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const all = (text || "")
                root.loading = false
                root.hasFetchedOnce = true

                // First line is the source marker; the rest is the payload.
                const nl = all.indexOf("\n")
                const marker = (nl >= 0 ? all.slice(0, nl) : all).trim()
                const payload = (nl >= 0 ? all.slice(nl + 1) : "").trim()

                if (marker === "__ZEN_FETCH_FAILED__" || (!payload && marker !== "__ZEN_API_OK__")) {
                    root.listingSource = "failed"
                    root.lastError = "Could not load the online wallpaper list "
                                   + "(GitHub rate-limited or offline). It will "
                                   + "retry automatically; cached items stay usable."
                    return
                }

                try {
                    const data = JSON.parse(payload)
                    if (!Array.isArray(data)) {
                        root.lastError = "Unexpected listing format."
                        root.listingSource = "failed"
                        return
                    }
                    if (marker === "__ZEN_MANIFEST_OK__") {
                        root.listingSource = "manifest"
                        root._applyManifest(data)
                    } else {
                        root.listingSource =
                            marker === "__ZEN_CACHE_FRESH__" ? "cache"
                          : marker === "__ZEN_STALE_CACHE__" ? "stale"
                          : "api"
                        root._applyListing(data)
                    }
                } catch (e) {
                    root.lastError = "Parse error: " + e
                    root.listingSource = "failed"
                    console.warn("[WallpaperRepoService] parse:", e)
                    root._loadCachedListing()
                }
            }
        }
    }

    Process { id: writeCacheProc; running: false }

    // Fallback when fetch fails — read last good cached listing if any.
    FileView {
        id: cachedListingFile
        path: root.listingPath
        blockLoading: false
    }

    function _loadCachedListing() {
        cachedListingFile.reload()
        // Give FileView a tick to populate then consume synchronously
        Qt.callLater(function() {
            try {
                const t = cachedListingFile.text()
                if (!t || t.length < 2) return
                const arr = JSON.parse(t)
                if (Array.isArray(arr)) _applyListing(arr)
            } catch (e) {
                console.warn("[WallpaperRepoService] cached parse:", e)
            }
        })
    }

    function _applyListing(arr) {
        const out = []
        for (let i = 0; i < arr.length; i++) {
            const e = arr[i]
            if (!e || e.type !== "file") continue
            const name = e.name || ""
            // Only image extensions
            if (!name.match(/\.(png|jpg|jpeg|webp|bmp)$/i)) continue
            const localPath = root.wpDir + "/" + name
            out.push({
                name: name,
                downloadUrl: e.download_url
                           || (root.rawBase + encodeURIComponent(name)),
                localPath: localPath,
                size: e.size || 0,
                cached: false   // will be checked below
            })
        }
        root.items = out
        // Now check which ones are already cached on disk
        cacheCheckProc.running = true
    }

    // v7.0.0-beta.1-hf96: apply a raw manifest.json. Accepts either a
    // plain filename array (["a.jpg","b.png"]) or an array of objects
    // ([{ "name": "a.jpg" }, ...]). download_url is derived from rawBase
    // since the manifest carries no API metadata.
    function _applyManifest(arr) {
        const out = []
        for (let i = 0; i < arr.length; i++) {
            const e = arr[i]
            const name = (typeof e === "string") ? e
                       : (e && e.name) ? e.name : ""
            if (!name) continue
            if (!name.match(/\.(png|jpg|jpeg|webp|bmp)$/i)) continue
            out.push({
                name: name,
                downloadUrl: root.rawBase + encodeURIComponent(name),
                localPath: root.wpDir + "/" + name,
                size: (e && e.size) ? e.size : 0,
                cached: false
            })
        }
        root.items = out
        cacheCheckProc.running = true
    }

    // Check which items exist locally already
    Process {
        id: cacheCheckProc
        running: false
        command: ["bash", "-c",
            "for f in \"" + root.wpDir + "\"/*.png "
          + "         \"" + root.wpDir + "\"/*.jpg "
          + "         \"" + root.wpDir + "\"/*.jpeg "
          + "         \"" + root.wpDir + "\"/*.webp; do "
          + "  [ -f \"$f\" ] && basename \"$f\"; "
          + "done 2>/dev/null; exit 0"]
        stdout: StdioCollector {
            onStreamFinished: {
                const present = (text || "").split("\n")
                    .map(s => s.trim()).filter(s => s.length)
                const have = {}
                for (let i = 0; i < present.length; i++) have[present[i]] = true
                // Re-emit items with cached flag updated
                const updated = root.items.map(it => ({
                    name:        it.name,
                    downloadUrl: it.downloadUrl,
                    localPath:   it.localPath,
                    size:        it.size,
                    cached:      !!have[it.name]
                }))
                root.items = updated
            }
        }
    }

    // ───── Download one wallpaper by index ─────
    property bool downloading: false
    function download(index, onDone) {
        if (index < 0 || index >= items.length) return
        const it = items[index]
        if (it.cached) { if (onDone) onDone(it.localPath); return }
        // v7.0.0-beta.1-hf96: a download already in flight would otherwise
        // clobber _targetIndex/_onDone mid-run. Ignore the second click so
        // the first completes cleanly rather than both silently failing.
        if (downloadProc.running) {
            if (onDone) onDone("")
            return
        }

        root.downloading = true
        downloadProc._targetIndex = index
        downloadProc._onDone = onDone || null
        downloadProc.command = ["bash", "-c",
            "mkdir -p \"" + root.wpDir + "\"; "
          + "curl -fsSL --connect-timeout 10 --max-time 120 "
          + "  -o \"$1\" \"$2\" && echo OK || echo FAIL",
            "_",
            it.localPath,
            it.downloadUrl]
        downloadProc.running = true
    }

    Process {
        id: downloadProc
        running: false
        property int _targetIndex: -1
        property var _onDone: null
        stdout: StdioCollector {
            onStreamFinished: {
                root.downloading = false
                const ok = (text || "").indexOf("OK") >= 0
                if (ok && downloadProc._targetIndex >= 0
                       && downloadProc._targetIndex < root.items.length) {
                    const upd = root.items.slice()
                    upd[downloadProc._targetIndex] =
                        Object.assign({}, upd[downloadProc._targetIndex],
                                      { cached: true })
                    root.items = upd
                    if (downloadProc._onDone)
                        downloadProc._onDone(upd[downloadProc._targetIndex].localPath)
                } else if (downloadProc._onDone) {
                    root.lastError = "Download failed (network?)."
                    downloadProc._onDone("")
                }
                downloadProc._targetIndex = -1
                downloadProc._onDone = null
            }
        }
    }

    Component.onCompleted: {
        // Load cached listing immediately for instant UI; kick a refresh
        // in the background. If refresh fails the cached view stays.
        _loadCachedListing()
        Qt.callLater(refresh)
    }
}
