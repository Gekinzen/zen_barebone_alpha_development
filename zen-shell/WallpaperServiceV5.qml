pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

/*
 * WallpaperServiceV5 — Port of Python WallpaperPage features
 *
 * v6.2 changes (pre, wala akong sinirang existing behavior):
 * - Modernized swww daemon startup (uses `swww-daemon` binary directly;
 *   deprecated `swww init` is now only a fallback for old installs).
 * - Added dedicated swww-state.json persistence (separate from wallpaper-v5.json)
 *   so yung swww-specific runtime state (daemon PID tracking, lastApplied,
 *   lastTransitionUsed, daemonMode, swwwVersion) may sariling file.
 * - Existing wallpaper-v5.json still saved — same schema, backward compat.
 * - applyWallpaper() now logs into ~/.cache/zen-shell/swww.log for debugging.
 *
 * Features:
 * - Local folder scan (configurable folder, persisted)
 * - Remote GitHub fetch (legacy, kept for backward compat)
 * - Current wallpaper tracking (highlight in picker)
 * - Slideshow with intervals
 * - Transition types (fade, wipe, grow, outer, wave, random)
 * - Pagination state (for picker UI)
 * - JSON persistence at ~/.config/quickshell/zen-shell/wallpaper-v5.json
 * - Dedicated swww state at ~/.config/quickshell/zen-shell/swww-state.json
 * - Robust swww daemon handling with retry + modern binary detection
 */
Singleton {
    id: root

    // ── Config paths ──
    readonly property string home: Quickshell.env("HOME")
    readonly property string configDir: home + "/.config/quickshell/zen-shell"
    readonly property string stateFilePath: configDir + "/wallpaper-v5.json"
    readonly property string swwwStatePath: configDir + "/swww-state.json"
    readonly property string cacheDir: home + "/.cache/zen-shell"
    readonly property string swwwLogPath: cacheDir + "/swww.log"
    readonly property string defaultFolder: home + "/Pictures/Wallpapers"

    // ── Legacy remote config (backward compat) ──
    property string githubUser: "Gekinzen"
    property string githubRepo: "zen_barebone_alpha_development"
    property string githubBranch: "main"
    property string githubPath: "wallpapers"

    // ── Persisted state ──
    property string localFolder: defaultFolder
    property string currentWallpaper: ""
    property bool   _lockWallSeeded: false   // v8.0.0-alpha-hf157 — seed hyprlock bg once
    // v8.0.0-alpha-hf158 — mean luminance of the current wallpaper, 0 (black) .. 1
    // (white). Drives the Glass+ smart-readability "smoke" in LookService: a bright
    // wallpaper ramps a dark tint into the white frost so text stays legible.
    // Persisted so it's the last-known on start (no white-glass flash before the
    // detector runs), and re-detected on every wallpaper change + once on start.
    property real   wallpaperLuminance: 0.5
    property string transitionType: "fade"   // fade, wipe, grow, outer, wave, random
    property bool slideshowEnabled: false
    property int slideshowInterval: 60       // seconds
    property bool randomTransition: false

    // ── Source switching (remote GitHub or local folder) ──
    property string source: "local"          // "local" | "remote"

    // ── Wallpaper lists ──
    property var localWallpapers: []
    property var remoteWallpapers: []

    // ── UI state ──
    property string searchQuery: ""
    property bool loading: false
    property string errorMsg: ""

    // ── swww runtime state (separately persisted in swww-state.json) ──
    property string daemonMode: "unknown"    // "swww-daemon" | "swww-init-legacy" | "unavailable" | "unknown"
    property string swwwVersion: ""
    property string lastApplied: ""
    property string lastTransitionUsed: ""
    property real transitionDuration: 1.0
    property int transitionFps: 60

    // ── Pagination (8 per page for 4-col × 2-row grid fit) ──
    // v6.13: Dynamic page size — columns × 4 rows max, no 5th row spillover
    // Columns are determined by WallpaperPicker grid width at runtime.
    // Default 16 is safe for 4 cols × 4 rows. The picker can override
    // this by setting wallpapersPerPage from its own column count.
    property int wallpapersPerPage: 16
    property int currentPage: 0

    // ── Derived ──
    property var activeList: source === "remote" ? remoteWallpapers : localWallpapers

    property var filteredList: {
        if (!searchQuery) return activeList
        // v8.0.0-alpha-hf164 — FUZZY (subsequence) match: every character of the query
        // appears in order somewhere in the name, so "frst" finds "forest", "sakura"
        // finds "cherry-sakura-01", and small typos still land. Whitespace is ignored.
        const q = searchQuery.toLowerCase().replace(/\s+/g, "")
        function fz(name) {
            const s = name.toLowerCase()
            let i = 0
            for (let c = 0; c < s.length && i < q.length; c++)
                if (s.charAt(c) === q.charAt(i)) i++
            return i === q.length
        }
        return activeList.filter(w => fz(w.name))
    }

    property int totalPages: {
        const n = filteredList.length
        if (n === 0) return 1
        return Math.ceil(n / wallpapersPerPage)
    }

    property var pagedList: {
        const start = currentPage * wallpapersPerPage
        return filteredList.slice(start, start + wallpapersPerPage)
    }

    // ── Signals ──
    signal wallpaperApplied(string path)
    signal listChanged()
    signal swwwStateChanged()

    // ─────────────────────────────────────────────────────────────
    // STATE PERSISTENCE — wallpaper-v5.json (unchanged schema)
    // ─────────────────────────────────────────────────────────────

    function saveState() {
        const state = {
            localFolder: localFolder,
            currentWallpaper: currentWallpaper,
            wallpaperLuminance: wallpaperLuminance,     // v8.0.0-alpha-hf158
            transitionType: transitionType,
            slideshowEnabled: slideshowEnabled,
            slideshowInterval: slideshowInterval,
            randomTransition: randomTransition,
            source: source
        }
        const json = JSON.stringify(state, null, 2)
        stateSaver.command = ["bash", "-c",
            "mkdir -p '" + configDir + "' && " +
            "cat > '" + stateFilePath + "' << 'ZENEOF'\n" + json + "\nZENEOF"]
        stateSaver.running = true
    }

    function applyState(text: string) {
        if (!text) return
        // v6.13: Don't let FileView reload override a user action in progress
        if (_saving) return
        try {
            const s = JSON.parse(text)
            if (s.localFolder) localFolder = s.localFolder
            if (typeof s.wallpaperLuminance === "number") wallpaperLuminance = s.wallpaperLuminance
            if (s.currentWallpaper) currentWallpaper = s.currentWallpaper
            // v8.0.0-alpha-hf157 — seed the hyprlock background once on start, so the
            // lock uses the current wallpaper even before the first wallpaper switch.
            if (currentWallpaper && !_lockWallSeeded) {
                _lockWallSeeded = true
                _syncLockWallpaper(currentWallpaper)
                _detectLuminance(currentWallpaper)   // v8.0.0-alpha-hf158 — refresh on start
            }
            if (s.transitionType) transitionType = s.transitionType
            if (typeof s.slideshowEnabled === "boolean") slideshowEnabled = s.slideshowEnabled
            if (s.slideshowInterval) slideshowInterval = s.slideshowInterval
            if (typeof s.randomTransition === "boolean") randomTransition = s.randomTransition
            if (s.source) source = s.source

            // v6.13: Sync timer state from loaded config
            if (slideshowEnabled && activeList.length > 0) {
                slideshowTimer.interval = slideshowInterval * 1000
                slideshowTimer.restart()
            } else {
                slideshowTimer.stop()
            }

            console.log("[WallpaperV5] State loaded, folder:", localFolder,
                        "slideshow:", slideshowEnabled, "timer:", slideshowTimer.running)
        } catch (e) {
            console.error("[WallpaperV5] State parse error:", e)
        }
    }

    Process { id: stateSaver; running: false }

    FileView {
        id: stateLoader
        path: root.stateFilePath
        blockLoading: false
        onLoaded: root.applyState(this.text())
    }

    // ─────────────────────────────────────────────────────────────
    // STATE PERSISTENCE — swww-state.json (dedicated swww runtime)
    // ─────────────────────────────────────────────────────────────

    function saveSwwwState() {
        const s = {
            daemonMode: daemonMode,
            swwwVersion: swwwVersion,
            lastApplied: lastApplied,
            lastTransitionUsed: lastTransitionUsed,
            transitionDuration: transitionDuration,
            transitionFps: transitionFps,
            updatedAt: new Date().toISOString()
        }
        const json = JSON.stringify(s, null, 2)
        swwwStateSaver.command = ["bash", "-c",
            "mkdir -p '" + configDir + "' && " +
            "cat > '" + swwwStatePath + "' << 'ZENEOF'\n" + json + "\nZENEOF"]
        swwwStateSaver.running = true
    }

    function applySwwwState(text: string) {
        if (!text) return
        try {
            const s = JSON.parse(text)
            if (s.daemonMode) daemonMode = s.daemonMode
            if (s.swwwVersion) swwwVersion = s.swwwVersion
            if (s.lastApplied) lastApplied = s.lastApplied
            if (s.lastTransitionUsed) lastTransitionUsed = s.lastTransitionUsed
            if (typeof s.transitionDuration === "number") transitionDuration = s.transitionDuration
            if (typeof s.transitionFps === "number") transitionFps = s.transitionFps
            console.log("[WallpaperV5] swww state loaded, mode:", daemonMode)
            swwwStateChanged()
        } catch (e) {
            console.error("[WallpaperV5] swww state parse error:", e)
        }
    }

    Process { id: swwwStateSaver; running: false }

    FileView {
        id: swwwStateLoader
        path: root.swwwStatePath
        blockLoading: false
        onLoaded: root.applySwwwState(this.text())
    }

    // ─────────────────────────────────────────────────────────────
    // LOCAL FOLDER SCAN (primary in v5)
    // ─────────────────────────────────────────────────────────────

    function setFolder(path: string) {
        if (!path) return
        localFolder = path
        currentPage = 0
        saveState()
        fetchLocal()
    }

    function fetchLocal() {
        loading = true
        errorMsg = ""
        localScanner.command = ["bash", "-c",
            "mkdir -p '" + localFolder + "' && " +
            "find '" + localFolder + "' -maxdepth 2 -type f " +
            "\\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.bmp' -o -iname '*.gif' \\) " +
            "-printf '%f\\t%p\\t%s\\n' 2>/dev/null | sort"]
        localScanner.running = true
    }

    Process {
        id: localScanner
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false
                const lines = this.text.trim().split("\n").filter(l => l.length > 0)
                const list = lines.map(line => {
                    const parts = line.split("\t")
                    return {
                        name: parts[0] || "",
                        url: "file://" + (parts[1] || ""),
                        path: parts[1] || "",
                        size: parseInt(parts[2]) || 0,
                        isRemote: false
                    }
                })
                root.localWallpapers = list
                console.log("[WallpaperV5] Found", list.length, "local wallpapers in", root.localFolder)
                root.listChanged()
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text && this.text.trim()) {
                    console.error("[WallpaperV5] Scan stderr:", this.text)
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────────────
    // REMOTE GITHUB FETCH (backward compat)
    // ─────────────────────────────────────────────────────────────

    function rawUrl(filename) {
        return "https://raw.githubusercontent.com/" + githubUser + "/" + githubRepo +
               "/" + githubBranch + "/" + githubPath + "/" + encodeURIComponent(filename)
    }

    function apiUrl() {
        return "https://api.github.com/repos/" + githubUser + "/" + githubRepo +
               "/contents/" + githubPath + "?ref=" + githubBranch
    }

    function fetchRemote() {
        loading = true
        errorMsg = ""
        remoteFetcher.command = ["curl", "-s", "-L",
            "-H", "Accept: application/vnd.github+json",
            "-H", "User-Agent: zen-shell",
            apiUrl()]
        remoteFetcher.running = true
    }

    Process {
        id: remoteFetcher
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false
                try {
                    const data = JSON.parse(this.text)
                    if (Array.isArray(data)) {
                        const imgExt = [".jpg", ".jpeg", ".png", ".webp", ".bmp"]
                        const list = data
                            .filter(item => item.type === "file")
                            .filter(item => imgExt.some(ext => item.name.toLowerCase().endsWith(ext)))
                            .map(item => ({
                                name: item.name,
                                url: root.rawUrl(item.name),
                                downloadUrl: item.download_url || root.rawUrl(item.name),
                                size: item.size,
                                isRemote: true
                            }))
                        list.sort((a, b) => a.name.localeCompare(b.name))
                        root.remoteWallpapers = list
                        console.log("[WallpaperV5] Loaded", list.length, "remote wallpapers")
                        root.listChanged()
                    } else if (data.message) {
                        root.errorMsg = "GitHub: " + data.message
                    }
                } catch (e) {
                    root.errorMsg = "Parse error: " + e
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────────────
    // WALLPAPER APPLICATION — modernized swww handling
    // ─────────────────────────────────────────────────────────────

    function selectWallpaper(wp) {
        if (!wp) return
        if (wp.isRemote) {
            downloadAndApply(wp)
        } else {
            applyWallpaper(wp.path)
        }
    }

    function downloadAndApply(wp) {
        loading = true
        const targetPath = localFolder + "/" + wp.name
        downloader.command = ["bash", "-c",
            "mkdir -p '" + localFolder + "' && " +
            "if [ ! -f '" + targetPath + "' ]; then " +
            "  curl -s -L -o '" + targetPath + "' '" + wp.downloadUrl + "'; " +
            "fi && " +
            "echo '" + targetPath + "'"]
        downloader.running = true
    }

    Process {
        id: downloader
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false
                const output = this.text.trim()
                const lines = output.split("\n")
                let path = ""
                for (let i = lines.length - 1; i >= 0; i--) {
                    if (lines[i].startsWith("/")) { path = lines[i]; break }
                }
                if (path) {
                    root.applyWallpaper(path)
                    root.fetchLocal()
                } else {
                    root.errorMsg = "Download failed"
                }
            }
        }
    }

    function pickTransition() {
        if (transitionType === "random" || randomTransition) {
            const opts = ["fade", "wipe", "grow", "outer", "wave"]
            return opts[Math.floor(Math.random() * opts.length)]
        }
        return transitionType
    }

    // v8.0.0-alpha-hf157 — hyprlock reads a STATIC config; there's no command
    // substitution in its `path=`. So we keep the one `$zenWall = …` line in
    // ~/.config/hypr/zen-hyprlock-ui.conf pointed at the live wallpaper. awk (not
    // sed) rewrites it, so a path with slashes / & / regex metacharacters is safe,
    // and the path is a positional arg — never interpolated into the program.
    // No-op if the file or the variable line isn't present (e.g. lock UI not set up).
    Process { id: lockWallSyncer; running: false }
    function _syncLockWallpaper(path) {
        if (!path) return
        lockWallSyncer.command = ["bash", "-c",
            "UI=\"$HOME/.config/hypr/zen-hyprlock-ui.conf\"; W=\"$1\"; " +
            "[ -f \"$UI\" ] || exit 0; " +
            "grep -q '^[$]zenWall ' \"$UI\" || exit 0; " +
            "awk -v w=\"$W\" '/^[$]zenWall / {print \"$zenWall  = \" w; next} {print}' \"$UI\" > \"$UI.zentmp\" && mv \"$UI.zentmp\" \"$UI\"",
            "_", path]
        lockWallSyncer.running = true
    }

    // v8.0.0-alpha-hf158 — wallpaper luminance detector for Glass+ smart readability.
    // magick/convert reduces the image to one grey pixel and prints its value (the
    // whole-image mean luma, 0..1). No ImageMagick → exits empty → luminance stays at
    // its last-known/default, so the frost simply behaves as before (safe fallback).
    // Path is a positional arg, never interpolated.
    Process {
        id: lumaDetector
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseFloat((this.text || "").trim())
                if (!isNaN(v) && v >= 0 && v <= 1) {
                    root.wallpaperLuminance = v
                    root.saveState()   // remember it for next start
                }
            }
        }
    }
    function _detectLuminance(path) {
        if (!path) return
        lumaDetector.command = ["bash", "-c",
            "W=\"$1\"; BIN=\"\"; " +
            "for c in magick convert; do command -v $c >/dev/null 2>&1 && { BIN=$c; break; }; done; " +
            "[ -z \"$BIN\" ] && exit 0; " +
            "$BIN \"$W\" -colorspace Gray -resize 1x1 -format '%[fx:mean]' info: 2>/dev/null",
            "_", path]
        lumaDetector.running = true
    }

    function applyWallpaper(path) {
        if (!path) return
        currentWallpaper = path
        // v8.0.0-alpha-hf157 — keep the hyprlock background pointed at this wallpaper.
        _syncLockWallpaper(path)
        // v8.0.0-alpha-hf158 — refresh luminance so Glass+ readability adapts.
        _detectLuminance(path)
        const t = pickTransition()
        lastTransitionUsed = t
        console.log("[WallpaperV5] Applying:", path, "transition:", t)

        // v6.7.3: Multi-session aware swww workflow
        //
        // Problem: Paul runs cosmic, hyprland, AND dwl sessions on the same
        // machine. swww daemon binds to a Wayland socket per-session via
        // $WAYLAND_DISPLAY. If the daemon was started in a different session
        // (or not at all for the current one), `swww img` silently fails or
        // targets the wrong compositor — wallpaper stays black.
        //
        // Fix:
        //   0. Resolve binary (swww OR awww symlink from v6.7.2 installer)
        //   1. Detect current WAYLAND_DISPLAY — this is the session anchor
        //   2. Check if daemon is alive FOR THIS session's socket
        //   3. If not, kill any stale daemon and spawn fresh for current session
        //   4. Apply wallpaper to ALL connected outputs (multi-monitor)
        //   5. Log everything for debugging
        swwwApplier.command = ["bash", "-c",
            "set +e; " +
            "mkdir -p '" + cacheDir + "' 2>/dev/null; " +
            "LOG='" + swwwLogPath + "'; " +
            "echo \"--- $(date -Iseconds) apply: " + path + " (transition=" + t + ") ---\" >> \"$LOG\"; " +

            // Step 0: resolve binary — check swww first, then awww (v6.7.2 rebranded)
            "SWWW_BIN=''; " +
            "for candidate in swww awww; do " +
            "  if command -v $candidate > /dev/null 2>&1; then " +
            "    SWWW_BIN=$(command -v $candidate); break; " +
            "  fi; " +
            "done; " +
            "if [ -z \"$SWWW_BIN\" ]; then " +
            "  for p in /usr/bin/swww /usr/local/bin/swww $HOME/.local/bin/swww " +
            "           /usr/bin/awww /usr/local/bin/awww $HOME/.local/bin/awww; do " +
            "    [ -x \"$p\" ] && SWWW_BIN=\"$p\" && break; " +
            "  done; " +
            "fi; " +
            "if [ -z \"$SWWW_BIN\" ]; then " +
            "  echo 'ERR: swww/awww binary not found' | tee -a \"$LOG\"; exit 127; " +
            "fi; " +
            "echo \"binary: $SWWW_BIN\" >> \"$LOG\"; " +
            "SWWW_DAEMON_BIN=''; " +
            "BIN_DIR=$(dirname \"$SWWW_BIN\"); " +
            "for d in \"${BIN_DIR}/swww-daemon\" \"${BIN_DIR}/awww-daemon\"; do " +
            "  [ -x \"$d\" ] && SWWW_DAEMON_BIN=\"$d\" && break; " +
            "done; " +
            "[ -z \"$SWWW_DAEMON_BIN\" ] && command -v swww-daemon >/dev/null 2>&1 && SWWW_DAEMON_BIN=$(command -v swww-daemon); " +
            "[ -z \"$SWWW_DAEMON_BIN\" ] && command -v awww-daemon >/dev/null 2>&1 && SWWW_DAEMON_BIN=$(command -v awww-daemon); " +

            // Step 1: session-aware socket detection
            // swww uses $XDG_RUNTIME_DIR/swww-$WAYLAND_DISPLAY.socket
            "WL_DISP=\"${WAYLAND_DISPLAY:-}\"; " +
            "echo \"WAYLAND_DISPLAY=$WL_DISP\" >> \"$LOG\"; " +
            "if [ -z \"$WL_DISP\" ]; then " +
            "  echo 'WARN: WAYLAND_DISPLAY not set, trying to detect...' >> \"$LOG\"; " +
            "  for sock in $XDG_RUNTIME_DIR/wayland-*; do " +
            "    [ -S \"$sock\" ] && WL_DISP=$(basename \"$sock\") && break; " +
            "  done; " +
            "  if [ -n \"$WL_DISP\" ]; then " +
            "    export WAYLAND_DISPLAY=\"$WL_DISP\"; " +
            "    echo \"auto-detected WAYLAND_DISPLAY=$WL_DISP\" >> \"$LOG\"; " +
            "  fi; " +
            "fi; " +

            // Step 2: check if daemon is alive for THIS session
            "if ! \"$SWWW_BIN\" query > /dev/null 2>&1; then " +
            "  echo 'daemon not responding for current session, restarting...' >> \"$LOG\"; " +
            // Kill any stale daemon — they won't serve our session anyway
            "  pkill -f 'swww-daemon' 2>/dev/null; " +
            "  pkill -f 'awww-daemon' 2>/dev/null; " +
            "  sleep 0.3; " +
            // Spawn daemon for current Wayland session
            "  if [ -n \"$SWWW_DAEMON_BIN\" ]; then " +
            "    echo \"spawning $SWWW_DAEMON_BIN\" >> \"$LOG\"; " +
            "    nohup \"$SWWW_DAEMON_BIN\" >> \"$LOG\" 2>&1 & " +
            "  else " +
            "    echo 'no daemon binary, trying swww init (legacy)' >> \"$LOG\"; " +
            "    \"$SWWW_BIN\" init >> \"$LOG\" 2>&1 & " +
            "  fi; " +
            "  for i in $(seq 1 30); do " +
            "    \"$SWWW_BIN\" query > /dev/null 2>&1 && break; " +
            "    sleep 0.2; " +
            "  done; " +
            "fi; " +

            // Step 3: verify daemon is alive
            "if ! \"$SWWW_BIN\" query > /dev/null 2>&1; then " +
            "  echo 'ERR: daemon not responding after startup attempt' | tee -a \"$LOG\"; " +
            "  exit 1; " +
            "fi; " +

            // Step 4: apply with retries + output targeting
            // Query all connected outputs and apply to each — ensures multi-monitor
            // sessions (and multi-compositor setups) all get the wallpaper.
            "OUTPUTS=$( \"$SWWW_BIN\" query 2>/dev/null | grep -oP '^[^:]+' ); " +
            "echo \"detected outputs: $(echo $OUTPUTS | tr '\\n' ' ')\" >> \"$LOG\"; " +
            "APPLY_OK=0; " +
            "for i in 1 2 3; do " +
            "  \"$SWWW_BIN\" img '" + path + "' " +
            "    --transition-type " + t + " " +
            "    --transition-duration " + transitionDuration.toFixed(2) + " " +
            "    --transition-fps " + transitionFps + " >> \"$LOG\" 2>&1; " +
            "  rc=$?; " +
            "  if [ $rc -eq 0 ]; then " +
            "    APPLY_OK=1; " +
            "    echo \"OK: applied " + path.substring(path.lastIndexOf("/") + 1) + " (attempt $i)\" | tee -a \"$LOG\"; " +
            "    break; " +
            "  fi; " +
            "  echo \"Retry $i failed (rc=$rc)\" >> \"$LOG\"; " +
            "  sleep 0.4; " +
            "done; " +
            "if [ $APPLY_OK -eq 0 ]; then " +
            "  echo 'ERR: all retries failed' | tee -a \"$LOG\"; exit 1; " +
            "fi"]
        swwwApplier.running = true
        lastApplied = path
        saveState()
        saveSwwwState()
        wallpaperApplied(path)
    }

    Process {
        id: swwwApplier
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text && this.text.trim()) console.log("[WallpaperV5] swww:", this.text.trim())
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text && this.text.trim()) console.error("[WallpaperV5] swww err:", this.text.trim())
            }
        }
    }

    // ─────────────────────────────────────────────────────────────
    // SLIDESHOW
    // ─────────────────────────────────────────────────────────────

    Timer {
        id: slideshowTimer
        interval: root.slideshowInterval * 1000
        repeat: true
        // v6.13: DO NOT use declarative `running:` binding here.
        // The binding fights with explicit stop()/restart() calls
        // because QML re-evaluates bindings after imperative changes.
        // Timer is controlled ONLY by setSlideshow() imperatively.
        running: false
        onTriggered: root.randomWallpaper()
    }

    // v6.13: Guard — true while saveState() is writing to prevent
    // FileView reload from overriding the in-memory state.
    property bool _saving: false

    function setSlideshow(enabled: bool) {
        slideshowEnabled = enabled
        if (!enabled) {
            slideshowTimer.stop()
        } else if (activeList.length > 0) {
            slideshowTimer.restart()
        }
        _saving = true
        saveState()
        // Clear saving guard after a short delay (let Process finish)
        Qt.callLater(function() { _saving = false })
        console.log("[WallpaperV5] Slideshow:", enabled ? "ON" : "OFF",
                    "timer.running:", slideshowTimer.running)
    }

    function setSlideshowInterval(seconds: int) {
        slideshowInterval = seconds
        saveState()
    }

    function setTransition(type: string) {
        transitionType = type
        saveState()
    }

    function setRandomTransition(enabled: bool) {
        randomTransition = enabled
        saveState()
    }

    function setTransitionDuration(sec: real) {
        transitionDuration = sec
        saveSwwwState()
    }

    function setTransitionFps(fps: int) {
        transitionFps = fps
        saveSwwwState()
    }

    // ─────────────────────────────────────────────────────────────
    // PAGINATION
    // ─────────────────────────────────────────────────────────────

    function nextPage() {
        if (currentPage < totalPages - 1) currentPage++
    }

    function prevPage() {
        if (currentPage > 0) currentPage--
    }

    function resetPage() {
        currentPage = 0
    }

    // ─────────────────────────────────────────────────────────────
    // UTILITIES
    // ─────────────────────────────────────────────────────────────

    function randomWallpaper() {
        const list = activeList
        if (list.length === 0) return
        const wp = list[Math.floor(Math.random() * list.length)]
        selectWallpaper(wp)
    }

    function toggleSource() {
        source = source === "remote" ? "local" : "remote"
        if (source === "local" && localWallpapers.length === 0) fetchLocal()
        if (source === "remote" && remoteWallpapers.length === 0) fetchRemote()
        saveState()
    }

    function refresh() {
        if (source === "remote") fetchRemote()
        else fetchLocal()
    }

    // ─────────────────────────────────────────────────────────────
    // DAEMON / VERSION DETECTION
    // ─────────────────────────────────────────────────────────────

    function detectSwww() {
        swwwDetector.running = true
    }

    Process {
        id: swwwDetector
        running: false
        command: ["bash", "-c",
            // v6.7.3: detect swww or awww (v6.7.2 rebranded)
            "SWWW_BIN=''; " +
            "for c in swww awww; do command -v $c >/dev/null 2>&1 && SWWW_BIN=$(command -v $c) && break; done; " +
            "if [ -z \"$SWWW_BIN\" ]; then echo 'unavailable|'; exit 0; fi; " +
            "VER=$(\"$SWWW_BIN\" --version 2>/dev/null | head -n1 | awk '{print $NF}'); " +
            "DAEMON=''; " +
            "for d in swww-daemon awww-daemon; do command -v $d >/dev/null 2>&1 && DAEMON=$d && break; done; " +
            "if [ -n \"$DAEMON\" ]; then " +
            "  echo \"swww-daemon|$VER\"; " +
            "else " +
            "  echo \"swww-init-legacy|$VER\"; " +
            "fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = this.text.trim()
                const parts = out.split("|")
                root.daemonMode = parts[0] || "unknown"
                root.swwwVersion = parts[1] || ""
                console.log("[WallpaperV5] swww detected:", root.daemonMode, "v" + root.swwwVersion)
                root.saveSwwwState()
                root.swwwStateChanged()
            }
        }
    }

    function startSwwwDaemon() { daemonStarter.running = true }

    Process {
        id: daemonStarter
        command: ["bash", "-c",
            // v6.7.3: session-aware daemon start with awww compat
            "SWWW_BIN=''; " +
            "for c in swww awww; do command -v $c >/dev/null 2>&1 && SWWW_BIN=$(command -v $c) && break; done; " +
            "[ -z \"$SWWW_BIN\" ] && exit 0; " +
            "if ! \"$SWWW_BIN\" query > /dev/null 2>&1; then " +
            "  DAEMON=''; " +
            "  for d in swww-daemon awww-daemon; do command -v $d >/dev/null 2>&1 && DAEMON=$(command -v $d) && break; done; " +
            "  if [ -n \"$DAEMON\" ]; then " +
            "    nohup \"$DAEMON\" > /dev/null 2>&1 & " +
            "  else " +
            "    \"$SWWW_BIN\" init > /dev/null 2>&1 & " +
            "  fi; " +
            "  for i in $(seq 1 30); do " +
            "    \"$SWWW_BIN\" query > /dev/null 2>&1 && break; " +
            "    sleep 0.2; " +
            "  done; " +
            "fi"]
        running: false
    }

    // ── Init ──
    Component.onCompleted: {
        console.log("[WallpaperV5] Init, folder:", localFolder)
        stateLoader.reload()
        swwwStateLoader.reload()
        detectSwww()
        startSwwwDaemon()
        Qt.callLater(fetchLocal)
    }
}
