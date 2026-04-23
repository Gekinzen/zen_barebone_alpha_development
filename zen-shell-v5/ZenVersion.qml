pragma Singleton

import Quickshell
import QtQuick

/*
 * ZenVersion v6.16.3.4.4 — single source of truth for the shell version
 *
 * Centralized so that UserProfilePage, system-info popover, "About"
 * surfaces, and future update checkers can all read the same string.
 * When we bump the version in a hotfix drop, we change it here ONCE
 * and every surface that binds to `ZenVersion.version` refreshes.
 *
 * NOTE: `import Quickshell` is REQUIRED because the `Singleton` type
 * is exported by the Quickshell module, not QtQuick. All other
 * singletons in this shell (PowerProfileService, MouseSettingsService,
 * etc.) follow the same import pattern. Missing this import causes
 * the entire shell load to cascade-fail with "Singleton is not a type".
 *
 * Convention:
 *   - version    → full version string shown in UI ("v6.16.3.4.4")
 *   - versionRaw → numeric form without "v" prefix (for compare logic)
 *   - releaseDate → ISO date of this drop
 *   - channel    → "beta" | "stable" — beta = v6.16.3.x hotfix series,
 *                  stable = tagged cut (v6.16.0, v6.16.1, etc.)
 *   - codename   → optional short tag
 *
 * Kept small and dependency-free — no ThemeService / SettingsStateV2 references
 * so it can be imported by anyone without load-order concerns.
 *
 * Wala tayong babawasan.
 */
Singleton {
    id: root

    readonly property string version:        "v6.16.4.1"
    readonly property string versionRaw:     "6.16.4.1"
    readonly property string releaseDate:    "2026-04-24"
    readonly property string channel:        "beta"
    readonly property string codename:       "Zen Shell"
    readonly property string fullLabel:      version + " · " + channel

    // Short release-series label ("6.16.3.4 series", "6.16.1 series") —
    // handy for roadmap-style surfaces that want to group hotfixes.
    readonly property string series: {
        const parts = versionRaw.split(".")
        if (parts.length < 4) return versionRaw
        return parts.slice(0, 4).join(".")
    }
}
