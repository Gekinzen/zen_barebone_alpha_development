pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

/*
 * DenshoService v7.0.0-alpha.2 — Densho identity toggles + helpers
 *
 * "Densho" (伝承 · "tradition transmitted") is Zen Shell's signature
 * aesthetic: washi paper, sumi ink, shu-iro vermilion, kanji-primary
 * affordances. Granular by design — four independent sub-toggles plus
 * a "Densho Mode" master flag that components subscribe to individually.
 *
 * Sub-toggles (each persisted independently):
 *
 *   1. denshoMode             — master switch. When OFF, all other
 *                               toggles are inert (components don't
 *                               read them). User can flip individual
 *                               sub-toggles freely while master is OFF
 *                               but nothing visible changes until
 *                               master is ON.
 *
 *   2. kanjiWorkspaces        — workspace labels become 一二三四五…
 *                               instead of numeric/nerd icons.
 *                               (Non-destructive: existing
 *                               PanelState.workspaceFormat preserved
 *                               when toggle off.)
 *
 *   3. verticalDate           — Clock widget renders the date as a
 *                               vertical kanji column alongside the
 *                               horizontal time.
 *
 *   4. seasonalKanji          — Adds a seasonal kanji column to the
 *                               desktop (24-sekki, 二十四節気) that
 *                               rotates automatically every ~15 days.
 *
 *   5. brushSeparators        — Bar separators / underlines render as
 *                               brush-stroke fades instead of hard
 *                               lines. (Counted as toggle #4 in user-
 *                               facing UI; implementation-wise it's
 *                               a fifth flag for clarity.)
 *
 * State: ~/.local/share/zen-shell/densho.state (JSON, _schema=7).
 * Atomic writes via mktemp+mv. Debounced save (200ms) — same pattern
 * as PanelState.
 *
 * Wala tayong babawasan — service is purely additive. When master is
 * OFF, every consumer sees default behavior. Existing themes,
 * workspace formats, clock layouts unaffected.
 */
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string stateDir: home + "/.local/share/zen-shell"
    readonly property string statePath: stateDir + "/densho.state"

    // ── The five flags ──
    property bool denshoMode:        false
    property bool kanjiWorkspaces:   true
    property bool verticalDate:      true
    property bool seasonalKanji:     true
    property bool brushSeparators:   true

    // ── Derived: a single boolean per feature that components watch ──
    // This is what consumers read. They do NOT read the sub-toggles
    // directly — they read e.g. `DenshoService.useKanjiWorkspaces`.
    readonly property bool useKanjiWorkspaces:  denshoMode && kanjiWorkspaces
    readonly property bool useVerticalDate:     denshoMode && verticalDate
    readonly property bool useSeasonalKanji:    denshoMode && seasonalKanji
    readonly property bool useBrushSeparators:  denshoMode && brushSeparators

    // ─────────────────────────────────────────────────────────────
    // KANJI HELPERS
    // ─────────────────────────────────────────────────────────────

    // Workspace number → kanji 一二三四五六七八九十.
    // Returns "" if input out of range; caller falls back to numeric.
    function workspaceKanji(n) {
        const map = ["", "一", "二", "三", "四", "五",
                          "六", "七", "八", "九", "十"]
        if (n >= 1 && n <= 10) return map[n]
        return "" + n
    }

    // ─────────────────────────────────────────────────────────────
    // VERTICAL DATE — kanji column for the Clock widget.
    // Returns ["二", "〇", "二", "六"] for year 2026, etc.
    // Combined helper exposes year+month+day as separate arrays so
    // QML Repeaters can render each with its own font weight.
    // ─────────────────────────────────────────────────────────────

    readonly property var kanjiDigits: [
        "〇", "一", "二", "三", "四",
        "五", "六", "七", "八", "九"
    ]

    function _intToKanjiDigits(n) {
        const s = "" + n
        const out = []
        for (var i = 0; i < s.length; i++) {
            const d = parseInt(s.charAt(i))
            out.push(kanjiDigits[d] || s.charAt(i))
        }
        return out
    }

    function yearKanji(year)  { return _intToKanjiDigits(year) }
    function monthKanji(m)    { return _intToKanjiDigits(m) }
    function dayKanji(d)      { return _intToKanjiDigits(d) }

    // Day-of-week kanji (Mon → 月, Tue → 火 ...).
    // JavaScript Date.getDay() returns 0=Sunday … 6=Saturday.
    function weekdayKanji(jsDay) {
        const map = ["日", "月", "火", "水", "木", "金", "土"]
        if (jsDay >= 0 && jsDay <= 6) return map[jsDay]
        return ""
    }

    // Full Japanese-style date label, e.g. "5月8日 金"
    function formatJpDate(date) {
        if (!date) return ""
        return date.getMonth() + 1 + "月" +
               date.getDate() + "日 " +
               weekdayKanji(date.getDay())
    }

    // ─────────────────────────────────────────────────────────────
    // SEASONAL KANJI — 24-sekki (二十四節気) rotation.
    // Each entry covers ~15 days. We pick by month+day with month-day
    // boundaries (approximate but consistent with traditional almanac).
    // Returns an object: { kanji, romaji, english, startMonth, startDay }
    // ─────────────────────────────────────────────────────────────

    readonly property var sekki: [
        { kanji: "立春", romaji: "Risshun",   english: "beginning of spring",  m: 2,  d: 4  },
        { kanji: "雨水", romaji: "Usui",      english: "rain water",           m: 2,  d: 19 },
        { kanji: "啓蟄", romaji: "Keichitsu", english: "awakening of insects", m: 3,  d: 5  },
        { kanji: "春分", romaji: "Shunbun",   english: "spring equinox",       m: 3,  d: 20 },
        { kanji: "清明", romaji: "Seimei",    english: "pure brightness",      m: 4,  d: 5  },
        { kanji: "穀雨", romaji: "Kokuu",     english: "grain rain",           m: 4,  d: 20 },
        { kanji: "立夏", romaji: "Rikka",     english: "beginning of summer",  m: 5,  d: 5  },
        { kanji: "小満", romaji: "Shōman",    english: "lesser fullness",      m: 5,  d: 21 },
        { kanji: "芒種", romaji: "Bōshu",     english: "grain in ear",         m: 6,  d: 6  },
        { kanji: "夏至", romaji: "Geshi",     english: "summer solstice",      m: 6,  d: 21 },
        { kanji: "小暑", romaji: "Shōsho",    english: "lesser heat",          m: 7,  d: 7  },
        { kanji: "大暑", romaji: "Taisho",    english: "greater heat",         m: 7,  d: 23 },
        { kanji: "立秋", romaji: "Risshū",    english: "beginning of autumn",  m: 8,  d: 8  },
        { kanji: "処暑", romaji: "Shosho",    english: "end of heat",          m: 8,  d: 23 },
        { kanji: "白露", romaji: "Hakuro",    english: "white dew",            m: 9,  d: 8  },
        { kanji: "秋分", romaji: "Shūbun",    english: "autumn equinox",       m: 9,  d: 23 },
        { kanji: "寒露", romaji: "Kanro",     english: "cold dew",             m: 10, d: 8  },
        { kanji: "霜降", romaji: "Sōkō",      english: "frost descent",        m: 10, d: 24 },
        { kanji: "立冬", romaji: "Rittō",     english: "beginning of winter",  m: 11, d: 7  },
        { kanji: "小雪", romaji: "Shōsetsu",  english: "lesser snow",          m: 11, d: 22 },
        { kanji: "大雪", romaji: "Taisetsu",  english: "greater snow",         m: 12, d: 7  },
        { kanji: "冬至", romaji: "Tōji",      english: "winter solstice",      m: 12, d: 22 },
        { kanji: "小寒", romaji: "Shōkan",    english: "lesser cold",          m: 1,  d: 6  },
        { kanji: "大寒", romaji: "Daikan",    english: "greater cold",         m: 1,  d: 20 }
    ]

    // Currently active sekki, recomputed every hour (cheaper than every
    // tick — date-resolution is fine).
    property var currentSekki: _computeSekki(new Date())

    function _computeSekki(now) {
        if (!now) now = new Date()
        const m = now.getMonth() + 1   // 1..12
        const d = now.getDate()
        const today = m * 100 + d      // pack as MMDD for compare

        // Build [{key, sekki}] entries sorted by key ascending. We walk
        // them in calendar order and keep the latest entry whose
        // threshold is <= today.
        const entries = []
        for (var i = 0; i < sekki.length; i++) {
            entries.push({ key: sekki[i].m * 100 + sekki[i].d, s: sekki[i] })
        }
        entries.sort(function(a, b) { return a.key - b.key })

        var best = null
        for (var j = 0; j < entries.length; j++) {
            if (entries[j].key <= today) {
                best = entries[j].s
            } else {
                break
            }
        }

        // Wrap: if today falls before the first sekki of the year
        // (i.e. Jan 1-5, before Shōkan on Jan 6), Tōji (Dec 22 of the
        // previous year) is still the active sekki — its window extends
        // to Jan 5.
        if (!best) best = entries[entries.length - 1].s

        return best
    }

    // Recompute every hour — cheap, no per-tick work needed.
    Timer {
        interval: 3600000   // 1 hour
        repeat: true
        running: true
        onTriggered: root.currentSekki = root._computeSekki(new Date())
    }

    // Also recompute when toggle flips (covers the case where seasonal
    // was off, user enables it, expects current sekki immediately).
    onUseSeasonalKanjiChanged: {
        if (useSeasonalKanji) currentSekki = _computeSekki(new Date())
    }

    // Convenience: full label like "立夏の候" ("season of beginning of summer")
    function sekkiLabel(s) {
        if (!s) s = currentSekki
        return s.kanji + "の候"
    }

    // ─────────────────────────────────────────────────────────────
    // v8.0.0-alpha-hf177 — NAV VOCABULARY
    //
    // "kapag naka enable din densho dapat pati appearance logo icon sa
    //  gilid magiging densho — may wordings tayo"
    //
    // Densho already reached the pages themselves (DenshoPageHeader gives
    // every settings page a kanji title) but stopped at the sidebar, so
    // turning it on produced a kanji-headed page hanging off a nav rail
    // that was still pure Nerd Font glyphs and English. The identity broke
    // exactly where you look first.
    //
    // Keyed by the English nav label rather than the page index, so
    // inserting a module in ZenDashboard.navItems can't silently shift
    // every kanji one row down — an unmapped label just falls back to the
    // glyph it has now.
    //
    // Kanji chosen for meaning, not transliteration: 盆 (tray) for System
    // Tray, 港 (harbour) for the Dock, 机 (desk) for Desktop, 窓枠 (window
    // frame) for Hyprbars.
    // ─────────────────────────────────────────────────────────────

    readonly property var navVocab: ({
        "Dashboard":        { kanji: "盤",   romaji: "Ban" },
        "General":          { kanji: "一般", romaji: "Ippan" },
        "Decoration":       { kanji: "装飾", romaji: "Sōshoku" },
        "Animations":       { kanji: "動き", romaji: "Ugoki" },
        "Themes":           { kanji: "色",   romaji: "Iro" },
        "Displays":         { kanji: "画面", romaji: "Gamen" },
        "Input":            { kanji: "入力", romaji: "Nyūryoku" },
        "Panel":            { kanji: "帯",   romaji: "Obi" },
        "Bar Modules":      { kanji: "部品", romaji: "Buhin" },
        "System Tray":      { kanji: "盆",   romaji: "Bon" },
        "Hot Corners":      { kanji: "角",   romaji: "Kado" },
        "Sound & Network":  { kanji: "通信", romaji: "Tsūshin" },
        "Notifications":    { kanji: "通知", romaji: "Tsūchi" },
        "Battery & Power":  { kanji: "電源", romaji: "Dengen" },
        "User Profile":     { kanji: "個人", romaji: "Kojin" },
        "Updates":          { kanji: "更新", romaji: "Kōshin" },
        "Desktop Widgets":  { kanji: "小物", romaji: "Komono" },
        "Wallpaper":        { kanji: "壁紙", romaji: "Kabegami" },
        "Focus Spaces":     { kanji: "集中", romaji: "Shūchū" },
        "Quick Notes":      { kanji: "覚書", romaji: "Oboegaki" },
        "Network Pulse":    { kanji: "脈",   romaji: "Myaku" },
        "Smart Dim":        { kanji: "減光", romaji: "Genkō" },
        "Title Translator": { kanji: "訳",   romaji: "Yaku" },
        "Hyprbars":         { kanji: "窓枠", romaji: "Madowaku" },
        "Game Detection":   { kanji: "遊戯", romaji: "Yūgi" },
        "Dock":             { kanji: "港",   romaji: "Minato" },
        "Default Apps":     { kanji: "既定", romaji: "Kitei" },
        "App Float Rules":  { kanji: "浮遊", romaji: "Fuyū" },
        "Desktop":          { kanji: "机",   romaji: "Tsukue" },
        "User Management":  { kanji: "利用者", romaji: "Riyōsha" },
        "Login Screen":     { kanji: "入口", romaji: "Iriguchi" },
        "Shell Look":       { kanji: "装い", romaji: "Yosooi" },
        "Cursor & Icons":   { kanji: "印",   romaji: "Shirushi" },
        "Taskbar":          { kanji: "仕事帯", romaji: "Shigoto-obi" }
    })

    // Sidebar category headers.
    readonly property var categoryVocab: ({
        "appearance":   { kanji: "外観",   romaji: "Gaikan" },
        "display":      { kanji: "入出力", romaji: "Nyūshutsuryoku" },
        "connectivity": { kanji: "接続",   romaji: "Setsuzoku" },
        "system":       { kanji: "系統",   romaji: "Keitō" },
        "productivity": { kanji: "生産",   romaji: "Seisan" },
        "other":        { kanji: "其他",   romaji: "Sonota" }
    })

    /** Kanji for a nav label, or "" when unmapped / Densho is off. */
    function navKanji(label) {
        if (!denshoMode || !label) return ""
        const e = navVocab[label]
        return e ? e.kanji : ""
    }

    /** Romaji for a nav label, or "" when unmapped / Densho is off. */
    function navRomaji(label) {
        if (!denshoMode || !label) return ""
        const e = navVocab[label]
        return e ? e.romaji : ""
    }

    function categoryKanji(key) {
        if (!denshoMode || !key) return ""
        const e = categoryVocab[key]
        return e ? e.kanji : ""
    }

    function categoryRomaji(key) {
        if (!denshoMode || !key) return ""
        const e = categoryVocab[key]
        return e ? e.romaji : ""
    }

    /**
     * "外観 · Gaikan · APPEARANCE" style label for tooltips and headers.
     * Falls back to plain English when Densho is off or unmapped.
     */
    function bilingual(kanji, romaji, english) {
        if (!denshoMode || !kanji || kanji.length === 0) return english
        let out = kanji
        if (romaji && romaji.length > 0) out += " · " + romaji
        if (english && english.length > 0) out += " · " + english
        return out
    }

    // ─────────────────────────────────────────────────────────────
    // PERSISTENCE
    // ─────────────────────────────────────────────────────────────

    FileView {
        id: stateFile
        path: root.statePath
        blockLoading: true
        blockAllReads: false

        onLoaded: {
            try {
                const txt = stateFile.text()
                if (!txt || !txt.trim()) return
                const j = JSON.parse(txt)
                if (typeof j.denshoMode === "boolean")
                    root.denshoMode = j.denshoMode
                if (typeof j.kanjiWorkspaces === "boolean")
                    root.kanjiWorkspaces = j.kanjiWorkspaces
                if (typeof j.verticalDate === "boolean")
                    root.verticalDate = j.verticalDate
                if (typeof j.seasonalKanji === "boolean")
                    root.seasonalKanji = j.seasonalKanji
                if (typeof j.brushSeparators === "boolean")
                    root.brushSeparators = j.brushSeparators
            } catch (e) {
                console.warn("DenshoService: failed to parse densho.state:", e)
            }
        }

        onLoadFailed: function(err) {
            // Missing file is fine on first launch — write defaults.
            saveDebounced.restart()
        }
    }

    Timer {
        id: saveDebounced
        interval: 200
        repeat: false
        onTriggered: root._writeState()
    }

    function _writeState() {
        const obj = {
            _schema: 7,
            denshoMode: root.denshoMode,
            kanjiWorkspaces: root.kanjiWorkspaces,
            verticalDate: root.verticalDate,
            seasonalKanji: root.seasonalKanji,
            brushSeparators: root.brushSeparators
        }
        const json = JSON.stringify(obj, null, 2)
        atomicWriter.command = ["bash", "-c",
            "mkdir -p '" + root.stateDir + "' && " +
            "tmp=$(mktemp) && " +
            "cat > \"$tmp\" << 'ZEN_DENSHO_EOF'\n" + json + "\nZEN_DENSHO_EOF\n" +
            "mv \"$tmp\" '" + root.statePath + "'"
        ]
        atomicWriter.running = true
    }

    Process { id: atomicWriter; running: false }

    onDenshoModeChanged:       saveDebounced.restart()
    onKanjiWorkspacesChanged:  saveDebounced.restart()
    onVerticalDateChanged:     saveDebounced.restart()
    onSeasonalKanjiChanged:    saveDebounced.restart()
    onBrushSeparatorsChanged:  saveDebounced.restart()
}
