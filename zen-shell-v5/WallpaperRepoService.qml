pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/*
 * WallpaperRepoService v6.16.2.3.2
 *
 * Fetches wallpaper listing from Paul's public GitHub repo:
 *   github.com/Gekinzen/images-demo/tree/main/wallpapers
 *
 * Exposes a `items` ListModel of { name, downloadUrl, localPath, cached }
 * records for the Wallpaper Picker's "Online" tab. Uses the GitHub
 * contents API (no auth required for public repos — rate-limited to
 * 60/hour per unauthenticated IP, which is plenty for this UI).
 *
 * Cache strategy:
 *   - Listing JSON  → ~/.cache/zen-shell/wallpapers/listing.json
 *   - Downloaded files → ~/.config/zen-shell/wallpapers/<name>
 *
 * `cached` is true if the file has already been downloaded locally —
 * used by the UI to show "Apply" vs "Download & Apply".
 *
 * Hardcodes nothing path-wise: uses $HOME via Quickshell.env.
 */
Singleton {
    id: root

    readonly property string apiUrl: "https://api.github.com/repos/Gekinzen/images-demo/contents/wallpapers"
    readonly property string rawBase: "https://raw.githubusercontent.com/Gekinzen/images-demo/main/wallpapers/"

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

    // ───── Fetch listing from GitHub contents API ─────
    function refresh() {
        loading = true
        lastError = ""
        fetchProc.running = true
    }

    Process {
        id: fetchProc
        running: false
        command: ["bash", "-c",
            "mkdir -p \"$HOME/.cache/zen-shell/wallpapers\" "
          + "\"$HOME/.config/zen-shell/wallpapers\"; "
            // curl to stdout. Fail softly on network error so UI can show
            // a message rather than just hang.
          + "curl -fsSL --connect-timeout 10 --max-time 20 "
          +   "\"" + root.apiUrl + "\" 2>&1 || "
          + "echo '__ZEN_FETCH_FAILED__'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const raw = (text || "").trim()
                root.loading = false
                root.hasFetchedOnce = true

                if (!raw || raw.indexOf("__ZEN_FETCH_FAILED__") >= 0) {
                    root.lastError = "Could not reach GitHub (offline?). "
                                   + "Using cached listing if present."
                    root._loadCachedListing()
                    return
                }

                try {
                    const arr = JSON.parse(raw)
                    if (!Array.isArray(arr)) {
                        root.lastError = "Unexpected API response."
                        return
                    }
                    root._applyListing(arr)
                    // Persist cache
                    writeCacheProc.command = ["bash", "-c",
                        "cat > \"" + root.listingPath + "\" << 'ZENCACHE'\n"
                      + raw + "\nZENCACHE"]
                    writeCacheProc.running = true
                } catch (e) {
                    root.lastError = "Parse error: " + e
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
    function download(index, onDone) {
        if (index < 0 || index >= items.length) return
        const it = items[index]
        if (it.cached) { if (onDone) onDone(it.localPath); return }

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
                const ok = (text || "").indexOf("OK") >= 0
                if (ok && _targetIndex >= 0 && _targetIndex < root.items.length) {
                    const upd = root.items.slice()
                    upd[_targetIndex] = Object.assign({}, upd[_targetIndex],
                                                       { cached: true })
                    root.items = upd
                    if (_onDone) _onDone(upd[_targetIndex].localPath)
                } else if (_onDone) {
                    _onDone("")
                }
                _targetIndex = -1
                _onDone = null
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
