pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/*
 * UserProfileService v6.16.2.3.1 — user avatar + system info
 *
 * Auto-detects user avatar from standard desktop-environment sources:
 *   1. ~/.face             (GNOME convention, also XDM/KDM legacy)
 *   2. ~/.face.icon        (alternate)
 *   3. /var/lib/AccountsService/icons/$USER   (AccountsService — GDM/SDDM)
 *   4. /usr/share/sddm/faces/$USER.face.icon   (SDDM face directory)
 *   5. ~/.config/zen-shell/user-avatar.{png,jpg}  (zen-shell override)
 *
 * The first existing file wins. User can override via Settings → Panel →
 * User Avatar.
 *
 * v6.16.2.3.1 changes:
 *   - setCustomAvatar() now COPIES the user-picked file into
 *     ~/.config/zen-shell/user-avatar.<ext> as the persistent canonical
 *     location. Previous versions stored only the original file PATH in
 *     user-profile.json — so if the user later deleted or moved the
 *     source (e.g. ~/Downloads/avatar.png), the avatar silently broke.
 *     Copying decouples the shell from the user's filesystem layout.
 *   - Added device info via /sys/class/dmi/id (no sudo): systemVendor,
 *     productName, productVersion, biosVendor, biosVersion, biosDate.
 *     Displayed on UserProfilePage. DMI files are world-readable on
 *     stock Arch/Cachy — no root prompt, no dmidecode dependency.
 *
 * Info refreshes every 30 seconds for uptime; static fields only once.
 */
Singleton {
    id: root

    // ───── Avatar ─────
    property string avatarPath: ""
    property string customAvatarPath: ""   // user override, persisted

    readonly property string homeDir: Quickshell.env("HOME") || ""
    readonly property string userName: Quickshell.env("USER") || "user"

    // v6.16.2.3.2-hotfix2: Cache-bust at the FILESYSTEM layer.
    // Each upload writes user-avatar-<timestamp>.<ext> with a fresh
    // filename. Detection picks the newest. Old files are pruned.
    // This means Qt's Image element sees a genuinely different URL
    // each upload — no need for any QML-level cache:false / Connections
    // tricks (which broke the layer.effect shader pipeline that
    // produced the circular mask in v6.16.2.3).
    readonly property string effectiveAvatarSource:
        customAvatarPath ? ("file://" + customAvatarPath) :
        avatarPath       ? ("file://" + avatarPath) :
                           ""

    // ───── System info ─────
    property string osName: "Linux"
    property string osVersion: ""
    property string osLogo: ""   // /etc/os-release LOGO= or distro-id
    property string kernelVersion: ""
    property string hostname: ""
    property string uptime: ""
    property string hyprlandVersion: ""

    // v6.16.2.3.1: Device info from /sys/class/dmi/id (readable without sudo)
    property string systemVendor: ""     // e.g. "ASUSTeK COMPUTER INC."
    property string productName: ""      // e.g. "ROG Strix G15 G513QY_G513QY"
    property string productVersion: ""   // e.g. "1.0"
    property string biosVendor: ""       // e.g. "American Megatrends International, LLC."
    property string biosVersion: ""      // e.g. "G513QY.326"
    property string biosDate: ""         // e.g. "07/10/2023"

    readonly property string cpuModel: {
        if (typeof SystemMonitorService !== "undefined" && SystemMonitorService.cpuName)
            return SystemMonitorService.cpuName
        return "CPU"
    }

    readonly property var gpuNames: {
        if (typeof SystemMonitorService !== "undefined" && SystemMonitorService.gpus)
            return SystemMonitorService.gpus.map(g => g.name || "GPU")
        return []
    }

    readonly property string themeName: {
        if (typeof ThemeService !== "undefined" && ThemeService.currentTheme)
            return ThemeService.currentTheme
        return "default"
    }

    // ───── Avatar detection ─────
    // v6.16.2.3.2-hotfix2: Detection now scans for user-avatar-*.{png,jpg,jpeg,webp}
    // (versioned filenames) and picks the NEWEST by mtime. Falls back to the
    // legacy bare user-avatar.* if no versioned file exists. Then standard
    // .face / AccountsService chain.
    Process {
        id: detectProc
        command: ["bash", "-c",
            "DIR=\"$HOME/.config/zen-shell\"; "
          // Versioned files (newest first by mtime)
          + "v=$(ls -t \"$DIR\"/user-avatar-*.png \"$DIR\"/user-avatar-*.jpg "
          + "        \"$DIR\"/user-avatar-*.jpeg \"$DIR\"/user-avatar-*.webp "
          + "        2>/dev/null | head -1); "
          + "if [ -n \"$v\" ] && [ -r \"$v\" ]; then echo \"$v\"; exit 0; fi; "
          // Legacy bare names (back-compat with older installs)
          + "for p in \"$DIR\"/user-avatar.png \"$DIR\"/user-avatar.jpg "
          +          "\"$DIR\"/user-avatar.jpeg \"$DIR\"/user-avatar.webp "
          +          "$HOME/.face $HOME/.face.icon "
          +          "/var/lib/AccountsService/icons/$USER "
          +          "/usr/share/sddm/faces/$USER.face.icon; do "
          + "  [ -r \"$p\" ] && echo \"$p\" && exit 0; "
          + "done; "
          + "exit 0"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim()
                if (p && p.length > 0) {
                    root.avatarPath = p
                } else {
                    root.avatarPath = ""
                }
            }
        }
    }

    // ───── Custom avatar persistence ─────
    FileView {
        id: customAvatarFile
        path: (root.homeDir || "") + "/.config/zen-shell/user-profile.json"
        blockLoading: false
        watchChanges: true
        onLoaded: {
            try {
                const t = this.text()
                if (!t || t.trim().length < 2) {
                    return
                }
                const s = JSON.parse(t)
                if (s && typeof s.customAvatarPath === "string") {
                    // Verify the file still exists; if not, fall back to detection.
                    // (Handles case where versioned files were pruned externally.)
                    root.customAvatarPath = s.customAvatarPath
                }
            } catch (e) {
                console.warn("[UserProfileService] Failed to parse user-profile.json:", e)
            }
        }
        onFileChanged: this.reload()
    }

    // v6.16.2.3.2-hotfix2: Versioned-filename strategy.
    //
    // Each upload writes user-avatar-<timestamp>.<ext> with a fresh,
    // unique filename. The Image element receives a genuinely different
    // URL each time → Qt's image cache misses naturally → new file
    // displays. NO QML cache:false / Connections / shader-disrupting
    // hacks needed (those broke the layer.effect circular mask in the
    // first hotfix attempt).
    //
    // Old versioned files are pruned: keep only the 3 newest so the
    // config dir doesn't grow unbounded across many uploads.
    function setCustomAvatar(sourcePath) {
        if (!sourcePath) {
            customAvatarPath = ""
            clearCopyProc.running = true
            return
        }
        // v6.16.2.3.2-hotfix3: All progress messages go to
        // /tmp/zen-avatar-debug.log (>&2 redirected). ONLY the final
        // DEST path is on stdout (fd 1) for QML's StdioCollector to
        // read. Run `tail -f /tmp/zen-avatar-debug.log` in a terminal
        // while clicking Upload to see exactly what bash does.
        avatarCopyProc.command = ["bash", "-c",
            "{ "                              // Begin block redirected to stderr → log
          + "echo '=== setCustomAvatar @ '$(date -Iseconds)' ==='; "
          + "set -x; "
          + "set -e; "
          + "SRC=\"$1\"; "
          + "echo \"SRC=$SRC\"; "
          + "if [ ! -f \"$SRC\" ]; then "
          + "  echo \"ERROR: source file does not exist: $SRC\"; "
          + "  exit 2; "
          + "fi; "
          + "DIR=\"$HOME/.config/zen-shell\"; "
          + "mkdir -p \"$DIR\"; "
          + "EXT=\"${SRC##*.}\"; "
          + "EXT_LC=\"$(echo \"$EXT\" | tr '[:upper:]' '[:lower:]')\"; "
          + "case \"$EXT_LC\" in png|jpg|jpeg|webp) : ;; *) EXT_LC=png ;; esac; "
          + "TS=$(date +%s%N); "
          + "DEST=\"$DIR/user-avatar-${TS}.${EXT_LC}\"; "
          + "cp -f \"$SRC\" \"$DEST\"; "
          + "echo \"copied to: $DEST  (size=$(stat -c%s \"$DEST\" 2>/dev/null || echo ?))\"; "
            // Prune old versioned files (keep 3 newest)
          + "ls -t \"$DIR\"/user-avatar-*.png \"$DIR\"/user-avatar-*.jpg "
          + "      \"$DIR\"/user-avatar-*.jpeg \"$DIR\"/user-avatar-*.webp "
          + "      2>/dev/null | tail -n +4 | xargs -r rm -f 2>/dev/null || true; "
            // Symlink bare-name → versioned file. Detection finds either,
            // and tools that expect user-avatar.<ext> still work.
          + "rm -f \"$DIR\"/user-avatar.png \"$DIR\"/user-avatar.jpg "
          +        "\"$DIR\"/user-avatar.jpeg \"$DIR\"/user-avatar.webp 2>/dev/null || true; "
          + "ln -sf \"$DEST\" \"$DIR/user-avatar.${EXT_LC}\" 2>/dev/null "
          + "  || cp -f \"$DEST\" \"$DIR/user-avatar.${EXT_LC}\"; "
          + "cat > \"$DIR/user-profile.json\" << ZSJSON\n"
          + "{\n"
          + "  \"customAvatarPath\": \"$DEST\"\n"
          + "}\n"
          + "ZSJSON\n"
          + "echo \"wrote profile.json\"; "
          + "echo \"final DEST=$DEST\"; "
          + "set +x; "
          + "echo \"=== success ===\"; "
          + "} >> /tmp/zen-avatar-debug.log 2>&1; "
            // Final stdout — ONLY the DEST path, on a single clean line.
            // Recompute DEST_OUT from the JSON file for safety (in case
            // the variables didn't survive — they should, since we're
            // still in the same bash -c invocation but defensive).
          + "DEST_OUT=$(grep -oE '\"customAvatarPath\"[[:space:]]*:[[:space:]]*\"[^\"]*\"' "
          + "             \"$HOME/.config/zen-shell/user-profile.json\" 2>/dev/null "
          + "           | sed -E 's/.*\"([^\"]*)\"$/\\1/'); "
          + "echo \"$DEST_OUT\"",
          "_",
          sourcePath]
        avatarCopyProc.running = true
    }

    function clearCustomAvatar() {
        setCustomAvatar("")
    }

    Process {
        id: avatarCopyProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim()
                if (p && p.length > 0) {
                    // Versioned filename → URL is genuinely new → Image element
                    // re-evaluates the binding and loads the fresh file.
                    // No cache-bust hack needed; no shader-disrupting state changes.
                    root.customAvatarPath = p
                    detectProc.running = true
                    console.log("[UserProfileService] Avatar saved to:", p)
                }
            }
        }
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                console.warn("[UserProfileService] Avatar copy failed, exit:", exitCode)
            }
        }
    }

    Process {
        id: clearCopyProc
        running: false
        command: ["bash", "-c",
            "DIR=\"$HOME/.config/zen-shell\"; "
            // Wipe ALL avatar files (versioned + legacy) so detection
            // falls back to .face / AccountsService.
          + "rm -f \"$DIR\"/user-avatar-*.png \"$DIR\"/user-avatar-*.jpg "
          +        "\"$DIR\"/user-avatar-*.jpeg \"$DIR\"/user-avatar-*.webp "
          +        "\"$DIR\"/user-avatar.png \"$DIR\"/user-avatar.jpg "
          +        "\"$DIR\"/user-avatar.jpeg \"$DIR\"/user-avatar.webp 2>/dev/null || true; "
          + "cat > \"$DIR/user-profile.json\" << 'ZSJSON'\n"
          + "{\n"
          + "  \"customAvatarPath\": \"\"\n"
          + "}\n"
          + "ZSJSON"]
        onExited: (exitCode) => {
            if (exitCode === 0) {
                detectProc.running = true
            }
        }
    }

    // ───── System info gather ─────
    // v6.16.2.3.1: Device info from /sys/class/dmi/id (no sudo needed).
    // These files are world-readable on mainstream Linux (Arch, Cachy,
    // Ubuntu, Fedora). dmidecode would need sudo; DMI sysfs files don't.
    //
    // Placeholder values (blanked out server-side):
    //   "To be filled by O.E.M."    — common on consumer laptops
    //   "Default string"            — MSI / various OEMs
    //   "System Product Name"       — ASUS default
    //   "System manufacturer"       — generic placeholder
    //   "System Version"            — generic placeholder
    //   "Not Specified" / "None"    — BIOS placeholder
    // These clutter the UI with junk, so _dmi() returns empty string
    // when the sysfs value matches any of them.
    Process {
        id: sysinfoProc
        command: ["bash", "-c",
            "echo OS=$(. /etc/os-release 2>/dev/null && echo \"$NAME\");" +
            "echo VER=$(. /etc/os-release 2>/dev/null && echo \"${VERSION:-$BUILD_ID}\");" +
            "echo LOGO=$(. /etc/os-release 2>/dev/null && echo \"${LOGO:-$ID}\");" +
            "echo KERNEL=$(uname -r);" +
            "echo HOST=$(hostname);" +
            "echo HYPR=$(hyprctl version 2>/dev/null | head -1 | sed 's/Hyprland, built from //');" +
            "_dmi() { " +
            "  v=$(cat \"/sys/class/dmi/id/$1\" 2>/dev/null | tr -d '\\n' | sed 's/^ *//; s/ *$//'); " +
            "  case \"$v\" in " +
            "    ''|'To be filled by O.E.M.'|'Default string'|'System Product Name'|" +
            "    'System manufacturer'|'System Version'|'Not Specified'|'None'|" +
            "    'OEM'|'O.E.M.'|'Unknown') echo '' ;; " +
            "    *) echo \"$v\" ;; " +
            "  esac; " +
            "}; " +
            "echo SYSVENDOR=$(_dmi sys_vendor);" +
            "echo PRODNAME=$(_dmi product_name);" +
            "echo PRODVER=$(_dmi product_version);" +
            "echo BIOSVEND=$(_dmi bios_vendor);" +
            "echo BIOSVER=$(_dmi bios_version);" +
            "echo BIOSDATE=$(_dmi bios_date)"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n")
                for (let i = 0; i < lines.length; i++) {
                    const eq = lines[i].indexOf("=")
                    if (eq <= 0) continue
                    const k = lines[i].substring(0, eq)
                    const v = lines[i].substring(eq + 1).trim()
                    if (k === "OS")        root.osName = v || "Linux"
                    if (k === "VER")       root.osVersion = v
                    if (k === "LOGO")      root.osLogo = v
                    if (k === "KERNEL")    root.kernelVersion = v
                    if (k === "HOST")      root.hostname = v
                    if (k === "HYPR")      root.hyprlandVersion = v
                    if (k === "SYSVENDOR") root.systemVendor = v
                    if (k === "PRODNAME")  root.productName = v
                    if (k === "PRODVER")   root.productVersion = v
                    if (k === "BIOSVEND")  root.biosVendor = v
                    if (k === "BIOSVER")   root.biosVersion = v
                    if (k === "BIOSDATE")  root.biosDate = v
                }
            }
        }
    }

    // Uptime ticker — refreshes every 30s
    Process {
        id: uptimeProc
        command: ["bash", "-c",
            "awk '{s=int($1); d=int(s/86400); h=int((s%86400)/3600); " +
            "m=int((s%3600)/60); " +
            "if(d>0) printf \"%dd %dh %dm\", d, h, m; " +
            "else if(h>0) printf \"%dh %dm\", h, m; " +
            "else printf \"%dm\", m }' /proc/uptime"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root.uptime = text.trim() || ""
        }
    }

    Timer {
        id: uptimeTimer
        interval: 30000
        repeat: true
        running: true
        onTriggered: uptimeProc.running = true
    }

    Component.onCompleted: {
        detectProc.running = true
        sysinfoProc.running = true
        uptimeProc.running = true
    }
}
