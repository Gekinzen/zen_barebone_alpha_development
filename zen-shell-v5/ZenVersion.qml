pragma Singleton

import Quickshell
import QtQuick

/*
 * ZenVersion v7.0.0-beta.1-hf95.34 — single source of truth for the shell version
 *
 * v7 RELEASE NOTES
 * ────────────────
 * v7 is the "Karui" (軽い · "lightweight") major. Theme: performance,
 * battery efficiency, RAM cleanliness, low-spec friendliness.
 *
 * VERSIONING SCHEME REFORM (v7+)
 * ──────────────────────────────
 * Dropped the 5-segment v6 tail (v6.16.4.12.9.12 was painful to grep
 * and tag). v7+ uses clean semver:
 *
 *   - Stable:  v7.0.0, v7.0.1, v7.1.0
 *   - Beta:    v7.0.0-beta.1, v7.0.0-beta.2
 *   - Alpha:   v7.0.0-alpha.1, v7.0.0-alpha.2
 *
 * Hotfixes bump patch (v7.0.0 → v7.0.1), not new tail segments.
 *
 * Branches: `main` (stable) + `next` (beta) + `dev` (alpha) — replacing
 * the scattered alpha-vX.Y.Z branches.
 *
 * Centralized so that UserProfilePage, system-info popover, "About"
 * surfaces, UpdatesPage, and any future update checkers all read the
 * same string. Bump version here ONCE per release and every binding
 * surface refreshes.
 *
 * Convention:
 *   - version    → full version string shown in UI ("v7.0.0-alpha.1")
 *   - versionRaw → without "v" prefix, for compare logic ("7.0.0-alpha.1")
 *   - semver     → numeric core only, no prerelease ("7.0.0")
 *   - prerelease → prerelease tag, "" if stable ("alpha.1" / "beta.2" / "")
 *   - releaseDate → ISO date of this drop
 *   - channel    → "alpha" | "beta" | "stable"
 *   - codename   → optional short tag ("Karui" for v7.0.x)
 *
 * Kept small and dependency-free — no ThemeService / SettingsStateV2
 * references so it can be imported by anyone without load-order concerns.
 *
 * Wala tayong babawasan.
 */
Singleton {
    id: root

    readonly property string version:        "v7.0.0-beta.1-hf95.34"
    readonly property string versionRaw:     "7.0.0-beta.1-hf90.1"
    readonly property string semver:         "7.0.0"
    readonly property string prerelease:     "beta.1-hf90.1"
    readonly property string releaseDate:    "2026-05-30"
    readonly property string channel:        "alpha"
    readonly property string codename:       "Karui"
    readonly property string codenameKanji:  "軽い"
    readonly property string fullLabel:      version + " · " + channel + " · " + codename

    // Major/minor/patch parsed from semver — handy for compare logic.
    readonly property int major: parseInt(semver.split(".")[0]) || 0
    readonly property int minor: parseInt(semver.split(".")[1]) || 0
    readonly property int patch: parseInt(semver.split(".")[2]) || 0

    // Short release-series label ("v7.0 series", "v7.1 series") —
    // for roadmap-style surfaces that group hotfixes.
    readonly property string series: "v" + major + "." + minor

    // Schema version for state files. Bump ONLY when state file
    // format changes incompatibly. v7 launched at schema 7.
    readonly property int schemaVersion: 7

    /*
     * Compare two version strings (semver-aware).
     * Returns -1 if a < b, 0 if equal, 1 if a > b.
     * Handles prereleases: 7.0.0-alpha.1 < 7.0.0-beta.1 < 7.0.0
     */
    function compareVersion(a, b) {
        function parse(v) {
            v = v.replace(/^v/, "")
            const parts = v.split("-")
            const core = parts[0].split(".").map(n => parseInt(n) || 0)
            const pre  = parts[1] || ""
            return { core, pre }
        }
        const A = parse(a), B = parse(b)
        for (let i = 0; i < 3; i++) {
            const x = A.core[i] || 0, y = B.core[i] || 0
            if (x !== y) return x < y ? -1 : 1
        }
        // Same core — prerelease compare. No prerelease ranks higher.
        if (!A.pre && !B.pre) return 0
        if (!A.pre) return 1
        if (!B.pre) return -1
        // Within prereleases: alpha < beta < rc, then numeric tail
        const order = { "alpha": 0, "beta": 1, "rc": 2 }
        const ap = A.pre.split("."), bp = B.pre.split(".")
        const ar = order[ap[0]] !== undefined ? order[ap[0]] : 99
        const br = order[bp[0]] !== undefined ? order[bp[0]] : 99
        if (ar !== br) return ar < br ? -1 : 1
        const an = parseInt(ap[1]) || 0, bn = parseInt(bp[1]) || 0
        if (an !== bn) return an < bn ? -1 : 1
        return 0
    }

    // True if `other` is newer than current shell version.
    function isNewer(other) {
        return compareVersion(version, other) < 0
    }
}
