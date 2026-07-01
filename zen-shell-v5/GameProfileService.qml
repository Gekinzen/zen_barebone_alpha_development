pragma Singleton

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

/*
 * GameProfileService v7.0.0-beta.1-hf82b — Karui (軽い)
 *
 * Auto-detects games/heavy 3D apps and switches to gaming workflow
 * profile. Three detection tiers run in parallel:
 *
 *   Tier 1 — Window class + title regex (event-driven + poll)
 *   Tier 2 — Process name via hyprctl clients -j → /proc/PID/comm
 *   Tier 3 — GPU load heuristic (amdgpu gpu_busy_percent > threshold
 *            + focused window not in a desktop-app whitelist)
 *
 * Event path:  Hyprland focused-window change → immediate Tier 1 scan
 * Poll path:   Timer every 1000ms → full Tier 1+2+3 scan
 *
 * Power saver awareness:
 *   Detection ALWAYS runs, regardless of power profile. The poll timer
 *   interval is NEVER reduced in power-saver mode — the whole point is
 *   to detect the game so we can switch OUT of power-saver into
 *   performance. When a game is detected while on power-saver, the
 *   service auto-engages gaming boost (via PowerProfileService) with a
 *   notification so the user knows.
 *
 * Custom patterns: ~/.config/quickshell/zen-shell/games.json
 *   {
 *     "classPatterns":   ["^my-custom-game"],
 *     "titlePatterns":   ["My Custom Game"],
 *     "processPatterns": ["my-game-bin"],
 *     "ignoreClasses":   ["some-false-positive"]
 *   }
 *
 * Wala tayong babawasan — fully additive.
 */
Singleton {
    id: root

    property bool enabled: true

    // v7.0.0-beta.1-hf82 — opt-in power profile auto-switch.
    //
    // User report:
    //   "tas yung sa power profile kapag nag gaming kapag hindi naman
    //    naka auto wag mag auto performance mode pre"
    //
    // Until hf82, detecting a game ALWAYS triggered
    //   WorkflowProfileService.activate("gaming")
    // which in turn called PowerProfileService.setProfile("performance")
    // (via _applyGaming → _setPower). There was no way to enjoy game
    // detection (DND, brightness, workflow tagging) without also
    // having the power profile yanked under you.
    //
    // hf82 splits the two:
    //   - `enabled`         → game detection ON/OFF (Tier 1+2+3 scans)
    //   - `autoPowerSwitch` → whether detection auto-switches the
    //                          system power profile to "performance".
    //
    // Default: false (off). User must explicitly opt-in via the
    // GamingPage toggle. When off, _enterGameMode still fires the
    // "Gaming mode activated" notification + updates state so the bar
    // badge / workflow indicator still reflect reality — it just
    // doesn't call WorkflowProfileService.activate("gaming"). The
    // user's currently-set power profile is left untouched.
    //
    // Wala tayong babawasan — existing callers that don't know about
    // this property continue to behave as before once user flips it on.
    property bool autoPowerSwitch: false

    // ─────────────────────────────────────────────────────────────
    // BUILT-IN PATTERN LISTS
    // ─────────────────────────────────────────────────────────────

    // Window class patterns (matched case-insensitive via RegExp)
    readonly property var _defaultClassPatterns: [
        "^steam_app_\\d+",       // Steam-launched games
        "^lutris-",              // Lutris-launched
        "^heroic-",              // Heroic Launcher
        "^gamescope",            // Gamescope-wrapped
        "\\.exe$",               // Wine apps
        "^(UnrealEditor|UE[45]Editor)",  // Unreal Engine editor
        "^(godot|Godot)",        // Godot engine
        "^retroarch$",           // RetroArch
        "^(pcsx2|rpcs3|dolphin-emu|ppsspp|yuzu|cemu|ryujinx|citra)", // Emulators
        "^(supertuxkart|xonotic|0ad|minetest|openarena)",            // Common FOSS games
        "^(wine|proton)"         // Direct Wine/Proton fallback
    ]

    // Window title patterns (things that appear in title bars of games)
    readonly property var _defaultTitlePatterns: [
        "\\bVulkan\\b",
        "\\bDirectX\\b",
        "\\bDirect3D\\b",
        "\\bDX1[012]\\b",
        "\\bOpenGL\\b",         // Often in game window titles
        "\\bUnreal\\s*Engine",
        "\\bFPS:\\s*\\d+",      // FPS counter in title
        "\\bGamescope\\b"
    ]

    // Process name patterns (matched against /proc/PID/comm)
    readonly property var _defaultProcessPatterns: [
        "^(wine|wine64|wineserver|proton|reaper|gamescope)",
        "^mangohud",            // MangoHud = definitely gaming
        "^(gamemode|gamemoded)" // Feral GameMode
    ]

    // Desktop-app whitelist — these are NOT games even with high GPU use.
    // Used by Tier 3 (GPU heuristic) to avoid false positives from
    // video players, browsers with HW accel, compositors, etc.
    readonly property var _desktopWhitelist: [
        "firefox", "chromium", "chrome", "brave", "vivaldi", "zen-browser",
        "vlc", "mpv", "celluloid", "totem",
        "obs", "obs-studio", "kdenlive", "shotcut",
        "blender",  // 3D but not a game
        "krita", "gimp", "inkscape",
        "nautilus", "thunar", "dolphin", "nemo",
        "code", "codium", "nvim", "kate",
        "discord", "telegram", "slack",
        "kitty", "alacritty", "foot", "wezterm", "ghostty",
        "quickshell", "hyprland", "waybar"
    ]

    // ─────────────────────────────────────────────────────────────
    // USER PATTERN OVERRIDES (loaded from games.json)
    // ─────────────────────────────────────────────────────────────
    property var _userClassPatterns: []
    property var _userTitlePatterns: []
    property var _userProcessPatterns: []
    property var _userIgnoreClasses: []

    // ─────────────────────────────────────────────────────────────
    // COMPILED REGEX CACHES
    // Pre-compiled on init and whenever games.json reloads.
    // Avoids new RegExp() on every scan cycle.
    // ─────────────────────────────────────────────────────────────
    property var _classRegexes: []
    property var _titleRegexes: []
    property var _processRegexes: []
    property var _ignoreRegexes: []

    function _compilePatterns() {
        const compile = (list) => {
            const out = []
            for (let i = 0; i < list.length; i++) {
                try { out.push(new RegExp(list[i], "i")) } catch (e) {}
            }
            return out
        }
        // Build learned patterns from auto-detected games.
        // Use exact-match anchored regexes so "steam_app_2161700"
        // doesn't accidentally match "steam_app_216170012345".
        const learnedClass = []
        const learnedTitle = []
        const learnedProc  = []
        for (let i = 0; i < root._learnedGames.length; i++) {
            const g = root._learnedGames[i]
            if (g.class)   learnedClass.push("^" + root._escapeRegex(g.class) + "$")
            if (g.title)   learnedTitle.push(root._escapeRegex(g.title))
            if (g.process) learnedProc.push("^" + root._escapeRegex(g.process) + "$")
        }

        const allClass = root._defaultClassPatterns
            .concat(root._userClassPatterns)
            .concat(learnedClass)
        const allTitle = root._defaultTitlePatterns
            .concat(root._userTitlePatterns)
            .concat(learnedTitle)
        const allProc  = root._defaultProcessPatterns
            .concat(root._userProcessPatterns)
            .concat(learnedProc)
        root._classRegexes   = compile(allClass)
        root._titleRegexes   = compile(allTitle)
        root._processRegexes = compile(allProc)
        root._ignoreRegexes  = compile(root._userIgnoreClasses)
    }

    // Escape special regex chars for exact-match learned patterns
    function _escapeRegex(s) {
        return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
    }

    // ─────────────────────────────────────────────────────────────
    // AUTO-LEARN
    //
    // Called from _enterGameMode. Checks if this game's class is
    // already in learnedGames. If not, adds it. If yes, bumps
    // timesDetected and lastSeen. Then queues a save to games.json.
    //
    // After learning, _compilePatterns is called so the new entry
    // is immediately available to the fast Tier 1 path.
    // ─────────────────────────────────────────────────────────────
    function _autoLearn(cls, title, tier) {
        if (!cls) return
        const today = new Date().toISOString().slice(0, 10)

        // Check if already learned (match by class)
        let found = false
        const updated = root._learnedGames.slice()
        for (let i = 0; i < updated.length; i++) {
            if (updated[i].class === cls) {
                // Existing — update metadata
                updated[i] = Object.assign({}, updated[i], {
                    title: title || updated[i].title,  // fresher title wins
                    lastSeen: today,
                    timesDetected: (updated[i].timesDetected || 0) + 1
                })
                found = true
                break
            }
        }

        if (!found) {
            // New game — add entry
            updated.push({
                class: cls,
                title: title || cls,
                process: "",    // enriched async via _enrichProcess
                firstSeen: today,
                lastSeen: today,
                timesDetected: 1,
                detectedVia: tier
            })
        }

        root._learnedGames = updated
        root._compilePatterns()
        root._queueSave()

        // Kick off async process-name enrichment for new entries
        if (!found) {
            root._enrichProcess(cls)
        }
    }

    // ─────────────────────────────────────────────────────────────
    // PROCESS ENRICHMENT
    //
    // After auto-learning a new game by window class, we grab the
    // actual process name (/proc/PID/comm) from hyprctl clients so
    // Tier 2 can detect it by process alone next time (in case the
    // window class changes between sessions, e.g. Wine version bump).
    // ─────────────────────────────────────────────────────────────
    Process {
        id: enrichProc
        running: false
        property string _targetClass: ""
        command: ["bash", "-c", "echo ''"]  // replaced dynamically
        stdout: StdioCollector {
            onStreamFinished: root._onEnrichDone(enrichProc._targetClass, this.text)
        }
    }

    function _enrichProcess(cls) {
        if (enrichProc.running) return
        enrichProc._targetClass = cls
        enrichProc.command = ["bash", "-c",
            "hyprctl clients -j 2>/dev/null | " +
            "python3 -c \"import json,sys,os\\n" +
            "try:\\n" +
            " for c in json.load(sys.stdin):\\n" +
            "  if c.get('class','') == '" + cls.replace(/'/g, "'\\''") + "':\\n" +
            "   pid=c.get('pid',0)\\n" +
            "   try: print(open(f'/proc/{pid}/comm').read().strip())\\n" +
            "   except: pass\\n" +
            "   break\\n" +
            "except: pass\" 2>/dev/null"
        ]
        enrichProc.running = true
    }

    function _onEnrichDone(cls, output) {
        const comm = (output || "").trim()
        if (!comm || !cls) return
        // Patch the learned entry
        const updated = root._learnedGames.slice()
        for (let i = 0; i < updated.length; i++) {
            if (updated[i].class === cls && !updated[i].process) {
                updated[i] = Object.assign({}, updated[i], { process: comm })
                root._learnedGames = updated
                root._compilePatterns()
                root._queueSave()
                break
            }
        }
    }

    // ─────────────────────────────────────────────────────────────
    // STATE
    // ─────────────────────────────────────────────────────────────
    property bool   gameActive: false
    property string previousProfile: ""
    property string activeGameClass: ""
    property string activeGameTitle: ""
    property string detectionTier: ""     // "class", "title", "process", "gpu"

    // GPU heuristic
    property int  gpuBusyThreshold: 70    // percent — above this = GPU-heavy app
    property int  _gpuBusyPercent: 0
    property bool _gpuBusyUpdated: false

    // Debounce: require N consecutive scans with no game before exiting.
    // Prevents flicker when a game briefly loses focus or reloads a level.
    property int  _exitDebounceCount: 0
    readonly property int _exitDebounceMax: 3

    // ─────────────────────────────────────────────────────────────
    // AUTO-LEARN: remembered games
    //
    // When a game is detected via ANY tier, its class + title + process
    // name are saved here. On next launch, these entries are compiled
    // into exact-match class patterns so Tier 1 catches them within
    // 500ms — no need for Tier 2 process scan or Tier 3 GPU heuristic.
    //
    // The more you play, the faster detection gets.
    //
    // Stored in games.json under "learnedGames": [...]. Each entry:
    //   {
    //     "class": "steam_app_2161700",
    //     "title": "Reverse: 1999",
    //     "process": "Reverse1999.exe",
    //     "firstSeen": "2026-05-18",
    //     "lastSeen": "2026-05-18",
    //     "timesDetected": 1,
    //     "detectedVia": "class"
    //   }
    // ─────────────────────────────────────────────────────────────
    property var _learnedGames: []
    property bool _saveQueued: false

    // ─────────────────────────────────────────────────────────────
    // GAMES.JSON LOADER
    // ─────────────────────────────────────────────────────────────
    readonly property string _gamesJsonPath:
        Quickshell.env("HOME") + "/.config/quickshell/zen-shell/games.json"

    FileView {
        id: gamesJsonReader
        path: root._gamesJsonPath
        watchChanges: true
        // hf82b CRITICAL FIX: `text` on Quickshell's FileView is
        // exposed as a callable (`text()`), not a plain string
        // property. Passing it directly to _parseGamesJson made the
        // function receive a JS function reference instead of the
        // file contents, which then failed on `raw.trim()` with
        //   TypeError: Property 'trim' of object function text()
        //     { [native code] } is not a function
        // The error was caught by _parseGamesJson's try/catch and
        // only logged as a warning, so all persisted state silently
        // failed to load: classPatterns, titlePatterns, learned
        // games, gpuBusyThreshold, AND (added in hf82) the
        // autoPowerSwitch toggle. Worse — repeated parse-failure
        // chains during the warmup window have been observed in
        // user logs immediately preceding shell SIGSEGV when paired
        // with a Lark notification storm (notification handler races
        // with FileView signal re-entry).
        //
        // Defensive call: pass `text()` if it's callable, else just
        // `text`. Works regardless of which Quickshell minor revision
        // is installed — both shapes have shipped in 0.x releases.
        onTextChanged: {
            const raw = (typeof text === "function") ? text() : text
            root._parseGamesJson(raw)
        }
    }

    // Writer — separate FileView for atomic saves. Using a different
    // id prevents the watchChanges → onTextChanged → _parseGamesJson
    // loop from interfering mid-write. The reader's watchChanges will
    // fire AFTER the atomic write completes, re-parsing cleanly.
    FileView {
        id: gamesJsonWriter
        path: root._gamesJsonPath
        atomicWrites: true
    }

    Timer {
        id: saveDebounce
        interval: 1000
        repeat: false
        onTriggered: root._writeGamesJson()
    }

    function _parseGamesJson(raw) {
        try {
            // hf82b: defense-in-depth. The caller in
            // gamesJsonReader.onTextChanged now unwraps FileView's
            // callable `text()` before passing, but in case any
            // future call site forgets, coerce here too:
            //   - if it's a function, invoke it to get the string
            //   - if it's still not a string, bail cleanly
            if (typeof raw === "function") raw = raw()
            if (typeof raw !== "string") return
            if (!raw || !raw.trim()) return
            const j = JSON.parse(raw)
            if (Array.isArray(j.classPatterns))   root._userClassPatterns   = j.classPatterns
            if (Array.isArray(j.titlePatterns))    root._userTitlePatterns   = j.titlePatterns
            if (Array.isArray(j.processPatterns))  root._userProcessPatterns = j.processPatterns
            if (Array.isArray(j.ignoreClasses))    root._userIgnoreClasses   = j.ignoreClasses
            if (typeof j.gpuBusyThreshold === "number") root.gpuBusyThreshold = j.gpuBusyThreshold
            // hf82: persisted auto-power-switch opt-in. Missing key
            // falls back to the default (false), preserving the new
            // hf82 hands-off behavior for users upgrading from hf81.
            if (typeof j.autoPowerSwitch === "boolean") root.autoPowerSwitch = j.autoPowerSwitch
            // Auto-learned entries
            if (Array.isArray(j.learnedGames))     root._learnedGames = j.learnedGames
            root._compilePatterns()
        } catch (e) {
            console.warn("[GameProfileService] games.json parse error:", e)
        }
    }

    function _writeGamesJson() {
        try {
            const obj = {
                classPatterns:   root._userClassPatterns,
                titlePatterns:   root._userTitlePatterns,
                processPatterns: root._userProcessPatterns,
                ignoreClasses:   root._userIgnoreClasses,
                gpuBusyThreshold: root.gpuBusyThreshold,
                autoPowerSwitch: root.autoPowerSwitch,   // hf82
                learnedGames:    root._learnedGames
            }
            gamesJsonWriter.setText(JSON.stringify(obj, null, 2) + "\n")
        } catch (e) {
            console.warn("[GameProfileService] games.json write error:", e)
        }
    }

    function _queueSave() {
        saveDebounce.restart()
    }

    // hf82: any toggle of autoPowerSwitch from the GamingPage UI
    // queues a save so the user's choice survives shell restarts.
    onAutoPowerSwitchChanged: root._queueSave()

    // ─────────────────────────────────────────────────────────────
    // INIT
    // ─────────────────────────────────────────────────────────────
    Component.onCompleted: {
        root._compilePatterns()
        // Ensure the config dir + games.json exist so FileView can
        // watch/write without errors.
        ensureDirProc.running = true
    }

    Process {
        id: ensureDirProc
        running: false
        command: ["bash", "-c",
            "mkdir -p \"$(dirname '" + root._gamesJsonPath + "')\" && " +
            "[ -f '" + root._gamesJsonPath + "' ] || " +
            "echo '{}' > '" + root._gamesJsonPath + "'"
        ]
    }

    // ─────────────────────────────────────────────────────────────
    // TIER 1 FAST PATH: hyprctl activewindow -j every 500ms
    //
    // Checks only the focused window — cheap single hyprctl call.
    // This is the primary detection path for the common case: user
    // launches a game, it grabs focus, detected within 500ms.
    //
    // Quickshell.Hyprland does NOT expose focusedClient as a bindable
    // property (only focusedWorkspace + focusedMonitor), so we poll
    // hyprctl activewindow. Same proven pattern as SmartDimService.
    //
    // 500ms is aggressive but hyprctl is a local socket call —
    // typically completes in <1ms. No CPU or GPU cost.
    // ─────────────────────────────────────────────────────────────
    Timer {
        id: fastPoll
        interval: 500
        running: root.enabled
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!activeWinProc.running) activeWinProc.running = true
        }
    }

    Process {
        id: activeWinProc
        running: false
        command: ["hyprctl", "activewindow", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const txt = (this.text || "").trim()
                    if (!txt || txt === "{}") return
                    const j = JSON.parse(txt)
                    const cls = String(j.class || "")
                    const title = String(j.title || "")
                    root._checkFocusedWindow(cls, title)
                } catch (e) {}
            }
        }
    }

    function _checkFocusedWindow(cls, title) {
        // Cache for Tier 3 GPU heuristic
        root._lastFocusedClass = cls
        root._lastFocusedTitle = title

        if (!cls && !title) return

        // Check ignore list first
        if (root._matchesAny(cls, root._ignoreRegexes)) return

        if (root._matchesAny(cls, root._classRegexes)) {
            if (!root.gameActive) root._enterGameMode(cls, title, "class")
            root._exitDebounceCount = 0
            return
        }
        if (root._matchesAny(title, root._titleRegexes)) {
            if (!root.gameActive) root._enterGameMode(cls, title, "title")
            root._exitDebounceCount = 0
            return
        }
    }

    // ─────────────────────────────────────────────────────────────
    // FULL SCAN: all toplevels + process + GPU every 2000ms
    //
    // Catches games that:
    //   - Run on another workspace (not focused)
    //   - Are detectable only via process name (Tier 2)
    //   - Cause high GPU load without matching any pattern (Tier 3)
    //
    // Longer interval than fast path since this is the comprehensive
    // sweep. Tier 1 (focused window) at 500ms handles the common
    // case; this catches edge cases.
    //
    // Interval is NEVER adjusted for power profile — detection must
    // work in power-saver precisely so we can override it.
    // ─────────────────────────────────────────────────────────────
    Timer {
        id: pollTimer
        interval: 2000
        running: root.enabled
        repeat: true
        onTriggered: root._fullScan()
    }

    function _fullScan() {
        try {
            // ── Tier 1: window class + title scan ──
            if (typeof Hyprland === "undefined" || !Hyprland.toplevels) {
                return
            }

            const tops = Hyprland.toplevels.values || []
            let foundClass = ""
            let foundTitle = ""
            let foundTier  = ""

            for (let i = 0; i < tops.length; i++) {
                const t = tops[i]
                if (!t) continue
                const cls = ((t.lastIpcObject && t.lastIpcObject.class) || t.class || "")
                const title = ((t.lastIpcObject && t.lastIpcObject.title) || t.title || "")

                // Ignore list
                if (root._matchesAny(cls, root._ignoreRegexes)) continue

                if (root._matchesAny(cls, root._classRegexes)) {
                    foundClass = cls; foundTitle = title; foundTier = "class"; break
                }
                if (root._matchesAny(title, root._titleRegexes)) {
                    foundClass = cls; foundTitle = title; foundTier = "title"; break
                }
            }

            // ── Tier 2: process-based detection ──
            // Only run if Tier 1 found nothing — saves the hyprctl call.
            if (!foundClass) {
                root._runProcessScan()
                // Process scan is async — result handled in _onProcessScanDone.
                // We'll continue with Tier 3 GPU check synchronously below.
            }

            // ── Tier 3: GPU heuristic ──
            // Uses SystemMonitorService.gpuUsage if available. If GPU is
            // hammered and the focused window isn't a known desktop app,
            // it's likely a game we don't have patterns for.
            if (!foundClass && !root.gameActive) {
                root._checkGpuHeuristic()
            }

            // ── State transition ──
            if (foundClass && !root.gameActive) {
                root._exitDebounceCount = 0
                root._enterGameMode(foundClass, foundTitle, foundTier)
            } else if (foundClass && root.gameActive) {
                // Game still running — reset exit debounce
                root._exitDebounceCount = 0
            } else if (!foundClass && root.gameActive) {
                // No game found THIS scan — but debounce before exiting.
                // This prevents flicker when a game briefly drops its
                // window (level load, cutscene transition, mode switch).
                root._exitDebounceCount++
                if (root._exitDebounceCount >= root._exitDebounceMax) {
                    root._exitGameMode()
                }
            }
        } catch (e) {
            console.warn("[GameProfileService] fullScan error:", e)
        }
    }

    // ─────────────────────────────────────────────────────────────
    // TIER 2: process-based detection (async via hyprctl clients)
    // ─────────────────────────────────────────────────────────────
    Process {
        id: procScan
        running: false
        command: ["bash", "-c",
            // Get all client PIDs + classes from Hyprland, then check
            // /proc/PID/comm for each. Output: "class|pid|comm" per line.
            "hyprctl clients -j 2>/dev/null | " +
            "python3 -c \"" +
            "import json,sys,os\\n" +
            "try:\\n" +
            " clients=json.load(sys.stdin)\\n" +
            " for c in clients:\\n" +
            "  pid=c.get('pid',0)\\n" +
            "  cls=c.get('class','')\\n" +
            "  try: comm=open(f'/proc/{pid}/comm').read().strip()\\n" +
            "  except: comm=''\\n" +
            "  if comm: print(f'{cls}|{pid}|{comm}')\\n" +
            "except: pass\\n" +
            "\" 2>/dev/null"
        ]
        stdout: StdioCollector {
            onStreamFinished: root._onProcessScanDone(this.text)
        }
    }

    function _runProcessScan() {
        if (procScan.running) return
        procScan.running = true
    }

    function _onProcessScanDone(output) {
        if (!output || root.gameActive) return
        try {
            const lines = output.trim().split("\n")
            for (let i = 0; i < lines.length; i++) {
                const parts = lines[i].split("|")
                if (parts.length < 3) continue
                const cls  = parts[0]
                const comm = parts[2]

                // Skip if in ignore list
                if (root._matchesAny(cls, root._ignoreRegexes)) continue

                if (root._matchesAny(comm, root._processRegexes)) {
                    root._exitDebounceCount = 0
                    root._enterGameMode(cls || comm, comm, "process")
                    return
                }
            }
        } catch (e) {
            console.warn("[GameProfileService] process scan parse error:", e)
        }
    }

    // ─────────────────────────────────────────────────────────────
    // TIER 3: GPU load heuristic
    // ─────────────────────────────────────────────────────────────
    // Cache the latest focused window class/title from the fast path
    // so Tier 3 can check it without another hyprctl call.
    property string _lastFocusedClass: ""
    property string _lastFocusedTitle: ""

    function _checkGpuHeuristic() {
        // Read GPU busy percent from SystemMonitorService if available
        let gpuPct = 0
        if (typeof SystemMonitorService !== "undefined") {
            gpuPct = SystemMonitorService.gpuUsage || 0
        }
        root._gpuBusyPercent = gpuPct

        if (gpuPct < root.gpuBusyThreshold) return

        // GPU is hammered — check if the focused window is a known desktop app.
        const cls = root._lastFocusedClass
        if (!cls) return

        // Check desktop whitelist
        const lower = cls.toLowerCase()
        for (let i = 0; i < root._desktopWhitelist.length; i++) {
            if (lower.indexOf(root._desktopWhitelist[i]) >= 0) return
        }

        // Unknown app hammering GPU — probable game
        root._exitDebounceCount = 0
        root._enterGameMode(cls, root._lastFocusedTitle, "gpu")
    }

    // ─────────────────────────────────────────────────────────────
    // MATCHING HELPERS
    // ─────────────────────────────────────────────────────────────
    function _matchesAny(str, regexList) {
        if (!str) return false
        for (let i = 0; i < regexList.length; i++) {
            if (regexList[i].test(str)) return true
        }
        return false
    }

    // ─────────────────────────────────────────────────────────────
    // STATE TRANSITIONS
    // ─────────────────────────────────────────────────────────────
    function _enterGameMode(cls, title, tier) {
        if (root.gameActive) return  // already active — skip

        if (typeof WorkflowProfileService === "undefined") return

        // hf79: Auto-learn — save this game's fingerprint so next
        // time it launches, Tier 1 catches it within 500ms.
        root._autoLearn(cls, title, tier)

        root.previousProfile = WorkflowProfileService.currentProfile
        root.activeGameClass = cls
        root.activeGameTitle = title || cls
        root.detectionTier   = tier
        root.gameActive      = true
        root._exitDebounceCount = 0

        // hf82: only auto-switch the workflow profile (which in turn
        // flips power profile to "performance") when the user has
        // opted in via autoPowerSwitch. Otherwise we still mark
        // gameActive + fire the notification so the UI reflects "yes,
        // a game is running" — we just keep our hands off the user's
        // current power profile.
        if (root.autoPowerSwitch) {
            WorkflowProfileService.activate("gaming")
        }

        // hf79: If we were on power-saver, gaming profile already
        // switched to performance (via WorkflowProfileService._applyGaming
        // → _setPower("performance")). Log which power profile was
        // overridden so the user knows why their battery is draining.
        // hf82: only meaningful when autoPowerSwitch is on. When off,
        // power profile was NOT touched, so the body line is omitted.
        const wasPowerSaver = root.autoPowerSwitch
                              && (typeof PowerProfileService !== "undefined")
                              && PowerProfileService.currentProfile === "power-saver"

        // Notification
        if (typeof NotificationService !== "undefined") {
            let body = "Detected: " + (title || cls)
            body += " [" + tier + "]"
            if (wasPowerSaver) body += "\n⚡ Power-saver → performance"
            // hf82: surface the auto-power-switch mode in the body
            // so the user always knows whether power was touched.
            if (!root.autoPowerSwitch) body += "\n(auto-power off — profile untouched)"

            NotificationService._addToHistory({
                id: "game-detected-" + Date.now(),
                summary: "Gaming mode activated",
                body: body,
                appName: "Zen Shell",
                appIcon: "",
                image: "",
                urgency: 0,
                transient: false,
                timestamp: Date.now(),
                read: false,
                actions: [],
                _native: null
            })
        }
    }

    function _exitGameMode() {
        if (typeof WorkflowProfileService === "undefined") return
        const prev = root.previousProfile || "work"
        const wasClass = root.activeGameClass
        root.gameActive      = false
        root.activeGameClass = ""
        root.activeGameTitle = ""
        root.detectionTier   = ""
        root._exitDebounceCount = 0

        // hf82: only revert the workflow profile if we actually
        // switched it on entry. If autoPowerSwitch was OFF, we never
        // called activate("gaming") so there's nothing to roll back —
        // doing so anyway would yank the user out of whatever profile
        // they manually selected between game-on and game-off.
        if (root.autoPowerSwitch) {
            WorkflowProfileService.activate(prev)
        }

        // Notification
        if (typeof NotificationService !== "undefined") {
            NotificationService._addToHistory({
                id: "game-exited-" + Date.now(),
                summary: "Gaming mode deactivated",
                body: root.autoPowerSwitch
                      ? "Reverted to: " + prev + " profile"
                      : "(auto-power off — no profile change)",
                appName: "Zen Shell",
                appIcon: "",
                image: "",
                urgency: 0,
                transient: false,
                timestamp: Date.now(),
                read: false,
                actions: [],
                _native: null
            })
        }
    }
}
