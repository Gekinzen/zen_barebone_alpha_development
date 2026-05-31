pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

/*
 * TitleTranslatorService v7.0.0-beta.1-hf39 — Karui (軽い)
 *
 * Auto-detect non-Latin window titles and provide translations on
 * hover. Useful for users playing JP/CN/KR games or browsing
 * Japanese YouTube (like Paul's screenshot earlier with 眠れない夜
 * BGM = "sleepless night BGM").
 *
 * Detection:
 *   - Scan title for Unicode scripts that aren't ASCII Latin
 *   - Japanese: Hiragana U+3040–309F, Katakana U+30A0–30FF, CJK Unified
 *   - Chinese: CJK Unified Ideographs U+4E00–9FFF, ext A/B
 *   - Korean: Hangul Syllables U+AC00–D7AF
 *   - Cyrillic: U+0400–04FF
 *   - Arabic: U+0600–06FF
 *
 * Translation source priority:
 *   1. In-memory cache (faster, offline)
 *   2. Persisted cache file (~/.cache/zen-shell/title-translations.json)
 *   3. LibreTranslate via curl if internet + user-enabled
 *
 * The translation cache is a flat JSON map: { "original": "translated" }
 *
 * Wala tayong babawasan — fully additive. Hooks nothing existing.
 */
Singleton {
    id: root

    // ─────────────────────────────────────────────────────────────
    // CONFIG
    // ─────────────────────────────────────────────────────────────
    property bool enabled: true
    property bool autoTranslate: false   // hit network automatically — off by default

    // LibreTranslate URL — user can set to a self-hosted instance
    // or use a free public one. As of 2026, the only widely-known
    // free public instances (no API key required) per the official
    // LibreTranslate docs mirrors list are:
    //   - https://translate.cutie.dating  ← default
    //   - https://translate.fedilab.app
    //
    // The previous default (translate.argosopentech.com, set in hf39)
    // is no longer reachable. Updated in hf45 to a working endpoint.
    // libretranslate.com itself now requires a paid API key.
    //
    // Self-hosted is recommended for any heavy use:
    //   docker run -d -p 5000:5000 libretranslate/libretranslate
    //   then set this URL to http://localhost:5000
    property string libreTranslateUrl: "https://translate.cutie.dating"
    property string targetLang: "en"

    // v7.0.0-beta.1-hf45: Google Translate browser fallback. When
    // LibreTranslate fails (server down, rate-limited, offline, etc.)
    // OR when the user just wants to open the full translation page,
    // this option opens https://translate.google.com/?sl=auto&tl=en
    // with the title text pre-filled.
    //
    // Set true (default) so the bar module's click action ALWAYS
    // works — falls back to opening the browser if the LibreTranslate
    // API call fails. Set false to require LibreTranslate only
    // (useful for privacy-conscious users with self-hosted instance).
    property bool browserFallback: true

    readonly property string cachePath:
        Quickshell.env("HOME") + "/.cache/zen-shell/title-translations.json"
    readonly property string statePath:
        Quickshell.env("HOME") + "/.config/quickshell/zen-shell/title-translator.json"

    // In-memory translation cache: { original: translated }
    property var cache: ({})

    // History of recently-detected foreign titles (for the UI)
    property var recent: []   // [{original, translated, sourceLang, when}]
    readonly property int maxRecent: 30

    // Track current active window title for the bar module display
    property string currentTitle: ""
    property string currentTranslation: ""
    property string currentLang: ""    // "ja", "zh", "ko", "ru", "ar", "" (none)

    // ─────────────────────────────────────────────────────────────
    // INIT
    // ─────────────────────────────────────────────────────────────
    Component.onCompleted: {
        loadState()
        loadCache()
    }

    // ─────────────────────────────────────────────────────────────
    // POLLING — active window title watcher
    // ─────────────────────────────────────────────────────────────
    Timer {
        id: pollTimer
        interval: 2000
        running: root.enabled
        repeat: true
        triggeredOnStart: true
        onTriggered: activeWinProc.running = true
    }

    Process {
        id: activeWinProc
        running: false
        command: ["hyprctl", "activewindow", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const txt = (this.text || "").trim()
                    if (!txt || txt === "{}") {
                        root.currentTitle = ""
                        root.currentTranslation = ""
                        root.currentLang = ""
                        return
                    }
                    const j = JSON.parse(txt)
                    const title = String(j.title || "").trim()
                    root._processTitle(title)
                } catch (e) {}
            }
        }
    }

    function _processTitle(title) {
        if (!title) {
            root.currentTitle = ""
            root.currentTranslation = ""
            root.currentLang = ""
            return
        }
        if (title === root.currentTitle) return   // no change

        const lang = root.detectLang(title)
        root.currentTitle = title
        root.currentLang = lang

        if (!lang) {
            root.currentTranslation = ""
            return
        }

        // Look up in cache first
        if (root.cache[title]) {
            root.currentTranslation = root.cache[title]
            return
        }

        // If auto-translate is on, fetch
        if (root.autoTranslate) {
            root.translate(title, lang)
        } else {
            // Just record that we noticed it, no translation yet
            root.currentTranslation = "(translation available)"
        }
    }

    /**
     * Detect dominant script of `text`. Returns short ISO lang code:
     * "ja", "zh", "ko", "ru", "ar", or "" if all-ASCII.
     */
    function detectLang(text) {
        if (!text) return ""
        let hira = 0, kata = 0, cjk = 0, hangul = 0, cyrillic = 0, arabic = 0
        for (let i = 0; i < text.length; i++) {
            const cp = text.charCodeAt(i)
            if (cp >= 0x3040 && cp <= 0x309F) hira++
            else if (cp >= 0x30A0 && cp <= 0x30FF) kata++
            else if (cp >= 0x4E00 && cp <= 0x9FFF) cjk++
            else if (cp >= 0x3400 && cp <= 0x4DBF) cjk++    // CJK Ext A
            else if (cp >= 0xAC00 && cp <= 0xD7AF) hangul++
            else if (cp >= 0x0400 && cp <= 0x04FF) cyrillic++
            else if (cp >= 0x0600 && cp <= 0x06FF) arabic++
        }
        // Japanese disambiguation: presence of hira/kata = JP even if CJK present
        if (hira > 0 || kata > 0) return "ja"
        if (cjk > 0) return "zh"
        if (hangul > 0) return "ko"
        if (cyrillic > 0) return "ru"
        if (arabic > 0) return "ar"
        return ""
    }

    // ─────────────────────────────────────────────────────────────
    // TRANSLATE
    // ─────────────────────────────────────────────────────────────
    function translate(text, sourceLang) {
        if (!text) return
        if (root.cache[text]) {
            root.currentTranslation = root.cache[text]
            return
        }
        // Use curl with JSON POST to LibreTranslate
        const payload = JSON.stringify({
            q: text,
            source: sourceLang || "auto",
            target: root.targetLang,
            format: "text"
        }).replace(/'/g, "'\\''")
        translateProc._original = text
        translateProc.command = ["bash", "-c",
            "curl -s --max-time 6 -X POST -H 'Content-Type: application/json' " +
            "-d '" + payload + "' '" + root.libreTranslateUrl + "/translate' 2>/dev/null"
        ]
        translateProc.running = true
    }

    Process {
        id: translateProc
        running: false
        property string _original: ""
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(this.text || "{}")
                    const translated = String(j.translatedText || "").trim()
                    if (translated) {
                        const updated = Object.assign({}, root.cache)
                        updated[translateProc._original] = translated
                        root.cache = updated
                        if (translateProc._original === root.currentTitle) {
                            root.currentTranslation = translated
                        }
                        // Add to recent
                        const rec = root.recent.slice()
                        rec.unshift({
                            original: translateProc._original,
                            translated: translated,
                            sourceLang: root.currentLang,
                            when: Math.floor(Date.now() / 1000)
                        })
                        if (rec.length > root.maxRecent) rec.length = root.maxRecent
                        root.recent = rec
                        root.lastError = ""
                        saveCache()
                    } else {
                        // v7.0.0-beta.1-hf45: LibreTranslate returned
                        // empty / failed. Surface the error so the UI
                        // can show it, then auto-fall-back to browser
                        // if enabled (always default ON).
                        const errMsg = j.error
                                       ? String(j.error)
                                       : "Empty response from " + root.libreTranslateUrl
                        root.lastError = errMsg
                        console.warn("[TitleTranslator] hf45: API failed:", errMsg)
                        if (translateProc._original === root.currentTitle) {
                            root.currentTranslation = "(API unavailable — opening browser)"
                        }
                        if (root.browserFallback) {
                            root.translateInBrowser()
                        }
                    }
                } catch (e) {
                    // Same fallback for parse errors (e.g. server
                    // returned HTML 502 page instead of JSON).
                    root.lastError = "Network/parse error: " + e
                    console.warn("[TitleTranslator] hf45: parse error:", e)
                    if (translateProc._original === root.currentTitle) {
                        root.currentTranslation = "(connection failed — opening browser)"
                    }
                    if (root.browserFallback) {
                        root.translateInBrowser()
                    }
                }
            }
        }
    }

    /**
     * Manual translate for the bar module's "translate now" button.
     */
    function translateCurrent() {
        if (!root.currentTitle || !root.currentLang) return
        root.translate(root.currentTitle, root.currentLang)
    }

    // v7.0.0-beta.1-hf45 — open Google Translate sa browser with the
    // current foreign title pre-filled. Bulletproof fallback when
    // LibreTranslate is unreachable + always-better full-page UX.
    //
    // URL format:
    //   https://translate.google.com/?sl=ja&tl=en&text=...
    //
    // sl = source lang (auto-detected by Google, but we hint with our
    // detection so the page loads with the right side selected).
    // tl = target lang (user's targetLang setting).
    // text = URL-encoded title.
    //
    // Uses xdg-open via execDetached. Failsafe — if xdg-open is
    // missing for some reason, the call just no-ops without crashing.
    function translateInBrowser() {
        if (!root.currentTitle) return
        const sl = root.currentLang || "auto"
        const tl = root.targetLang || "en"
        const txt = encodeURIComponent(root.currentTitle)
        const url = "https://translate.google.com/?sl=" + sl
                  + "&tl=" + tl + "&text=" + txt + "&op=translate"
        try {
            Quickshell.execDetached({command: ["xdg-open", url]})
            console.log("[TitleTranslator] hf45: opened browser →", url)
        } catch (e) {
            console.warn("[TitleTranslator] browser open failed:", e)
        }
    }

    // v7.0.0-beta.1-hf45 — visible status for the UI. Tells user
    // what's happening when LibreTranslate fails. Bar module tooltip
    // reads this so user isn't left wondering "why nothing happened."
    property string lastError: ""

    // ─────────────────────────────────────────────────────────────
    // CACHE PERSISTENCE
    // ─────────────────────────────────────────────────────────────
    function loadCache() { loadCacheProc.running = true }

    Process {
        id: loadCacheProc
        running: false
        command: ["bash", "-c", "cat '" + root.cachePath + "' 2>/dev/null || echo '{}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(this.text || "{}")
                    if (j && typeof j === "object") root.cache = j
                } catch (e) {}
            }
        }
    }

    Process { id: saveCacheProc; running: false }
    Timer {
        id: saveCacheDebounce; interval: 1500; repeat: false
        onTriggered: {
            saveCacheProc.command = ["bash", "-c",
                "mkdir -p \"$(dirname '" + root.cachePath + "')\" && " +
                "cat > '" + root.cachePath + "' << 'EOF'\n" +
                JSON.stringify(root.cache, null, 2) + "\nEOF"]
            saveCacheProc.running = true
        }
    }

    function saveCache() { saveCacheDebounce.restart() }

    // ─────────────────────────────────────────────────────────────
    // STATE PERSISTENCE (config only — not cache)
    // ─────────────────────────────────────────────────────────────
    function loadState() { loadStateProc.running = true }

    Process {
        id: loadStateProc
        running: false
        command: ["bash", "-c", "cat '" + root.statePath + "' 2>/dev/null || echo '{}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(this.text || "{}")
                    if (typeof j.enabled === "boolean") root.enabled = j.enabled
                    if (typeof j.autoTranslate === "boolean") root.autoTranslate = j.autoTranslate
                    if (typeof j.libreTranslateUrl === "string" && j.libreTranslateUrl) root.libreTranslateUrl = j.libreTranslateUrl
                    if (typeof j.targetLang === "string" && j.targetLang) root.targetLang = j.targetLang
                } catch (e) {}
            }
        }
    }

    Process { id: saveStateProc; running: false }
    Timer {
        id: saveStateDebounce; interval: 400; repeat: false
        onTriggered: {
            const obj = {
                enabled: root.enabled,
                autoTranslate: root.autoTranslate,
                libreTranslateUrl: root.libreTranslateUrl,
                targetLang: root.targetLang
            }
            saveStateProc.command = ["bash", "-c",
                "mkdir -p \"$(dirname '" + root.statePath + "')\" && " +
                "cat > '" + root.statePath + "' << 'EOF'\n" +
                JSON.stringify(obj, null, 2) + "\nEOF"]
            saveStateProc.running = true
        }
    }

    onEnabledChanged: saveStateDebounce.restart()
    onAutoTranslateChanged: saveStateDebounce.restart()
    onLibreTranslateUrlChanged: saveStateDebounce.restart()
    onTargetLangChanged: saveStateDebounce.restart()

    // ─────────────────────────────────────────────────────────────
    // HELPER LABELS
    // ─────────────────────────────────────────────────────────────
    function langLabel(code) {
        switch (code) {
            case "ja": return "Japanese"
            case "zh": return "Chinese"
            case "ko": return "Korean"
            case "ru": return "Russian"
            case "ar": return "Arabic"
            case "":   return ""
            default:   return code
        }
    }
}
