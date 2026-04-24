pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // ── Config ──
    property string githubUser: "Gekinzen"
    property string githubRepo: "zen_barebone_alpha_development"
    property string githubBranch: "main"
    property string githubPath: "wallpapers"
    property string localDir: Quickshell.env("HOME") + "/Pictures/Wallpapers"

    // ── State ──
    property string source: "remote"  // "remote" or "local"
    property var remoteWallpapers: []
    property var localWallpapers: []
    property bool loading: false
    property string errorMsg: ""
    property string currentWallpaper: ""
    property string searchQuery: ""

    // ── Derived ──
    property var activeList: source === "remote" ? remoteWallpapers : localWallpapers

    property var filteredList: {
        if (!searchQuery) return activeList
        const q = searchQuery.toLowerCase()
        return activeList.filter(w => w.name.toLowerCase().includes(q))
    }

    // Raw URL helpers
    function rawUrl(filename) {
        return "https://raw.githubusercontent.com/" + githubUser + "/" + githubRepo +
               "/" + githubBranch + "/" + githubPath + "/" + encodeURIComponent(filename)
    }

    function apiUrl() {
        return "https://api.github.com/repos/" + githubUser + "/" + githubRepo +
               "/contents/" + githubPath + "?ref=" + githubBranch
    }

    // ── Fetch remote list from GitHub API ──
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
                        console.log("[wallpaper] Loaded", list.length, "remote wallpapers")
                    } else if (data.message) {
                        root.errorMsg = "GitHub: " + data.message
                        console.error("[wallpaper] GitHub API error:", data.message)
                    }
                } catch (e) {
                    root.errorMsg = "Parse error: " + e
                    console.error("[wallpaper] Parse error:", e)
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text && this.text.trim()) {
                    console.error("[wallpaper] curl stderr:", this.text)
                }
            }
        }
    }

    // ── Scan local wallpapers ──
    function fetchLocal() {
        loading = true
        localScanner.command = ["bash", "-c",
            "mkdir -p '" + localDir + "' && " +
            "find '" + localDir + "' -maxdepth 2 -type f " +
            "\\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.bmp' \\) " +
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
                console.log("[wallpaper] Found", list.length, "local wallpapers")
            }
        }
    }

    // ── Download & apply ──
    function selectWallpaper(wp) {
        if (wp.isRemote) {
            downloadAndApply(wp)
        } else {
            applyWallpaper(wp.path)
        }
    }

    function downloadAndApply(wp) {
        loading = true
        const targetPath = localDir + "/" + wp.name
        downloader.command = ["bash", "-c",
            "mkdir -p '" + localDir + "' && " +
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
                const path = this.text.trim()
                if (path) {
                    console.log("[wallpaper] Downloaded to:", path)
                    root.applyWallpaper(path)
                    // Refresh local list
                    root.fetchLocal()
                }
            }
        }
    }

    function applyWallpaper(path) {
        currentWallpaper = path
        // Save to state file so it persists
        stateSaver.command = ["bash", "-c",
            "echo '" + path + "' > '" + Quickshell.dataPath("current-wallpaper.txt") + "'"]
        stateSaver.running = true
        // Apply via swww
        swwwApplier.command = ["swww", "img", path,
            "--transition-type", "grow",
            "--transition-duration", "1.5",
            "--transition-fps", "60"]
        swwwApplier.running = true
    }

    Process { id: stateSaver; running: false }
    Process {
        id: swwwApplier
        running: false
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text && this.text.trim()) {
                    console.error("[wallpaper] swww error:", this.text)
                    // Maybe swww-daemon not running?
                    if (this.text.includes("not running") || this.text.includes("connect")) {
                        root.startSwwwDaemon()
                    }
                }
            }
        }
    }

    function startSwwwDaemon() {
        daemonStarter.running = true
    }

    Process {
        id: daemonStarter
        command: ["bash", "-c", "swww-daemon &"]
        running: false
    }

    // ── Random wallpaper (for keybind) ──
    function randomWallpaper() {
        const list = activeList
        if (list.length === 0) return
        const wp = list[Math.floor(Math.random() * list.length)]
        selectWallpaper(wp)
    }

    // ── Init ──
    Component.onCompleted: {
        // Load saved current wallpaper
        stateLoader.reload()
        // Start swww daemon in case it's not running
        startSwwwDaemon()
        // Initial fetch
        fetchLocal()
        fetchRemote()
    }

    FileView {
        id: stateLoader
        path: Quickshell.dataPath("current-wallpaper.txt")
        blockLoading: true
        onLoaded: root.currentWallpaper = this.text().trim()
    }

    function toggleSource() {
        source = source === "remote" ? "local" : "remote"
        if (source === "local" && localWallpapers.length === 0) fetchLocal()
        if (source === "remote" && remoteWallpapers.length === 0) fetchRemote()
    }

    function refresh() {
        if (source === "remote") fetchRemote()
        else fetchLocal()
    }
}
