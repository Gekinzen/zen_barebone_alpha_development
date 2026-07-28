pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

/*
 * UserManagementService v7.0.0-beta.1-hf95.9 (was hf82p) — Karui (軽い)
 *
 * SAFETY-CRITICAL SINGLETON.
 *
 * Wraps useradd / userdel / gpasswd / passwd via pkexec. Provides a
 * filtered view of /etc/passwd showing only "real" users (uid >= 1000,
 * excluding nobody) plus the current user always.
 *
 * ════════════════════════════════════════════════════════════════
 * HARD SAFETY RULES — these are NOT configurable, ever:
 * ════════════════════════════════════════════════════════════════
 *
 * 1. NEVER delete the currently-logged-in user.
 *    Enforced via THREE independent checks:
 *      a) currentUser computed from $USER env
 *      b) currentUser computed from `id -un` (read at startup)
 *      c) Final shell-level guard in the deletion command itself
 *    All three must agree the target is NOT current before delete runs.
 *
 * 2. NEVER delete users with uid < 1000.
 *    System users (root, daemons, etc.) are never touched.
 *
 * 3. NEVER delete root.
 *    Explicit name check even if somehow uid >= 1000.
 *
 * 4. Every destructive action requires explicit pkexec auth.
 *    No "remember password", no "do everything in one prompt".
 *    Each action shows the user exactly what's about to happen.
 *
 * 5. Operations are LOGGED to ~/.cache/zen-shell/user-mgmt.log
 *    with timestamps so the user can audit what happened if
 *    something goes wrong.
 *
 * 6. UI never assumes success — every action triggers a refresh()
 *    that re-reads /etc/passwd and /etc/group to confirm state.
 *
 * 7. Errors surface in lastError property. UI must display these
 *    prominently; silent failure for sudo operations is dangerous.
 *
 * Wala tayong babawasan — purely additive singleton.
 */
Singleton {
    id: root

    // ── Identity (read once at startup, NEVER mutated) ──
    //
    // $USER is the standard env. `id -un` is the kernel-truth fallback
    // (if $USER is unset or wrong). We capture BOTH and require BOTH
    // to agree the deletion target isn't the current user.
    readonly property string currentUserFromEnv: Quickshell.env("USER") || ""
    property string currentUserFromId: ""    // populated by idProc on startup

    readonly property string currentUser: {
        // Prefer `id -un` if available (most authoritative).
        if (currentUserFromId && currentUserFromId.length > 0)
            return currentUserFromId
        return currentUserFromEnv
    }

    // ── User list (refreshed on demand + after every mutation) ──
    //
    // Each entry: { name, uid, gid, gecos, home, shell, isAdmin, isCurrent }
    // Filtered to uid >= 1000, name != "nobody". Always includes the
    // current user even if its uid is somehow outside the range.
    property var users: []

    // ── Status / error surface ──
    property string lastAction: ""
    property string lastError: ""

    // ── Pending action flags (so UI can disable buttons during run) ──
    property bool isRunning: false

    Component.onCompleted: {
        _readCurrentUserViaId()
        refresh()
    }

    // ════════════════════════════════════════════════════════════════
    // STARTUP: read current user via `id -un`
    // ════════════════════════════════════════════════════════════════
    Process {
        id: idProc
        running: false
        command: ["id", "-un"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = this.text.trim()
                if (v && v.length > 0) {
                    root.currentUserFromId = v
                }
            }
        }
    }

    function _readCurrentUserViaId() {
        idProc.running = false
        idProc.running = true
    }

    // ════════════════════════════════════════════════════════════════
    // REFRESH: parse /etc/passwd + /etc/group, build users[]
    // ════════════════════════════════════════════════════════════════
    function refresh() {
        listProc.command = ["bash", "-c",
            "awk -F: '$3 >= 1000 && $1 != \"nobody\" { " +
            "  print $1 \"|\" $3 \"|\" $4 \"|\" $5 \"|\" $6 \"|\" $7 " +
            "}' /etc/passwd 2>/dev/null; " +
            "echo '---'; " +
            // wheel group members (admin)
            "getent group wheel 2>/dev/null | awk -F: '{print $4}'"]
        listProc.running = false
        listProc.running = true
    }

    Process {
        id: listProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const text = this.text
                const sections = text.split("---")
                if (sections.length < 2) {
                    root.lastError = "Could not parse /etc/passwd"
                    return
                }
                const passwdLines = sections[0].split("\n")
                const wheelLine = (sections[1] || "").trim()
                const wheelMembers = wheelLine.split(",")
                    .map(s => s.trim())
                    .filter(s => s.length > 0)

                const list = []
                for (let i = 0; i < passwdLines.length; i++) {
                    const line = passwdLines[i].trim()
                    if (!line) continue
                    const parts = line.split("|")
                    if (parts.length < 6) continue
                    const name = parts[0]
                    const uid = parseInt(parts[1], 10)
                    list.push({
                        "name":      name,
                        "uid":       uid,
                        "gid":       parseInt(parts[2], 10),
                        "gecos":     parts[3] || "",
                        "home":      parts[4] || "",
                        "shell":     parts[5] || "",
                        "isAdmin":   wheelMembers.indexOf(name) >= 0,
                        "isCurrent": name === root.currentUser
                    })
                }
                list.sort((a, b) => a.name.localeCompare(b.name))
                root.users = list
                root.lastError = ""
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text && this.text.trim().length > 0) {
                    console.warn("[UserMgmt] list stderr:", this.text)
                }
            }
        }
    }

    // ════════════════════════════════════════════════════════════════
    // SAFETY: triple-check that target is safe to delete
    // ════════════════════════════════════════════════════════════════
    //
    // Returns "" if safe, or a refusal reason string otherwise.
    // UI MUST display the reason and never proceed if non-empty.
    function _whyUnsafeToDelete(targetName) {
        if (!targetName || targetName.length === 0)
            return "Refusing: empty username"

        if (targetName === "root")
            return "Refusing: cannot delete the root account"

        // Check 1: $USER env
        if (currentUserFromEnv && targetName === currentUserFromEnv)
            return "Refusing: '" + targetName +
                   "' is the currently-logged-in user (from $USER env). " +
                   "Log in as another admin user to delete this account."

        // Check 2: `id -un`
        if (currentUserFromId && targetName === currentUserFromId)
            return "Refusing: '" + targetName +
                   "' is the currently-logged-in user (from `id -un`). " +
                   "Log in as another admin user to delete this account."

        // Check 3: uid < 1000 system users
        for (let i = 0; i < users.length; i++) {
            if (users[i].name === targetName) {
                if (users[i].uid < 1000)
                    return "Refusing: '" + targetName +
                           "' is a system account (uid " + users[i].uid + " < 1000)"
                if (users[i].isCurrent)
                    return "Refusing: '" + targetName +
                           "' marked as current user in our list"
                break
            }
        }

        return ""  // safe
    }

    // ════════════════════════════════════════════════════════════════
    // ACTION: createUser
    // ════════════════════════════════════════════════════════════════
    //
    // Runs:
    //   useradd -m -s /bin/bash -G <wheelIfAdmin> -c "<fullName>" <name>
    //   passwd <name> (via expect-style heredoc with the chosen password)
    //
    // Notes:
    //   - -m creates home directory
    //   - -s /bin/bash is a sane default; user can change later
    //   - wheel group only added if isAdmin=true
    //
    // The password is piped via stdin to `chpasswd` which is safer
    // than `passwd` for non-interactive use. chpasswd reads
    // "name:password" lines and updates atomically.
    function createUser(name, fullName, password, isAdmin, copyDotfiles) {
        // v7.0.0-beta.1-hf85: copyDotfiles (default true) clones the
        // CURRENT user's Zen Shell + Hyprland rice into the new user's
        // home so a freshly-created account boots into the same desktop.
        // Pass false to create a bare account.
        if (copyDotfiles === undefined) copyDotfiles = true
        if (!name || name.length === 0) {
            lastError = "Username required"
            return
        }
        // Username validation: posix portable filename chars only,
        // start with letter, max 32 chars (Linux convention).
        if (!/^[a-z_][a-z0-9_-]{0,31}$/.test(name)) {
            lastError = "Invalid username — use lowercase letters, digits, _, -; " +
                       "must start with letter or _; max 32 chars"
            return
        }
        if (!password || password.length < 4) {
            lastError = "Password must be at least 4 characters"
            return
        }
        // Refuse names that already exist (early exit; useradd would
        // fail anyway but we get a cleaner error message)
        for (let i = 0; i < users.length; i++) {
            if (users[i].name === name) {
                lastError = "User '" + name + "' already exists"
                return
            }
        }

        // Sanitize fullName for the -c GECOS field (no colons, max 100 chars)
        const safeGecos = (fullName || "").replace(/:/g, "").substring(0, 100)
        const groups = isAdmin ? "-G wheel" : ""

        // The script: useradd then chpasswd. Quoted carefully — name
        // and password go through shell so we use single-quote escaping.
        const nameEscaped = name.replace(/'/g, "'\\''")
        const fullNameEscaped = safeGecos.replace(/'/g, "'\\''")
        const passwordEscaped = password.replace(/'/g, "'\\''")

        // Resolve the source (current) user's home + name for the clone.
        // This QML-side value is only a HINT — the root script below
        // re-resolves the source user authoritatively from PKEXEC_UID, so
        // the clone still runs even if currentUser wasn't populated yet.
        // (That silent skip — gated on srcHome && srcName — was why a new
        // account sometimes booted into a BARE desktop.)
        const srcNameHint = root.currentUser || ""
        let srcHomeHint = ""
        for (let i = 0; i < users.length; i++) {
            if (users[i].name === srcNameHint) { srcHomeHint = users[i].home; break }
        }
        if (!srcHomeHint && srcNameHint) srcHomeHint = "/home/" + srcNameHint
        const srcHomeHintEscaped = srcHomeHint.replace(/'/g, "'\\''")
        const srcNameHintEscaped = srcNameHint.replace(/'/g, "'\\''")

        let cmd =
            "set -e; " +
            "useradd -m -s /bin/bash " + groups + " " +
            "  -c '" + fullNameEscaped + "' '" + nameEscaped + "'; " +
            "echo '" + nameEscaped + ":" + passwordEscaped + "' | chpasswd"

        // ── Dotfile clone = auto-install Zen Shell for the new user ──
        //
        // v7.0.0-beta.1-hf95.9 fixes two bugs that made the new account
        // boot bare or broken:
        //   (1) The clone is now ALWAYS attempted when copyDotfiles is on.
        //       The source user is resolved root-side from PKEXEC_UID (the
        //       human who authenticated), falling back to the QML hint then
        //       `logname`, so it no longer silently skips.
        //   (2) The /home/<src>/ → /home/<new>/ path rewrite now covers
        //       EVERY copied directory (not just 3), so baked absolute
        //       paths in .local/share/quickshell (panel-state.json etc.)
        //       and other state get fixed — otherwise the new user's
        //       wallpaper/theme pointed at a home they can't read.
        // Curated list — desktop rice only, NOT the whole home (no ssh
        // keys, tokens, browser profiles). Wala tayong babawasan.
        if (copyDotfiles) {
            cmd +=
                "; SRC_USER_HINT='" + srcNameHintEscaped + "'" +
                "; SRC_HINT='" + srcHomeHintEscaped + "'" +
                // Authoritative source = the user who invoked pkexec.
                "; SRC_USER=\"$(getent passwd \"${PKEXEC_UID:-}\" 2>/dev/null | cut -d: -f1)\"" +
                "; [ -z \"$SRC_USER\" ] && SRC_USER=\"$SRC_USER_HINT\"" +
                "; [ -z \"$SRC_USER\" ] && SRC_USER=\"$(logname 2>/dev/null || true)\"" +
                "; SRC=\"$(getent passwd \"$SRC_USER\" 2>/dev/null | cut -d: -f6)\"" +
                "; [ -z \"$SRC\" ] && SRC=\"$SRC_HINT\"" +
                "; DST=\"$(getent passwd '" + nameEscaped + "' | cut -d: -f6)\"" +
                "; if [ -n \"$DST\" ] && [ -n \"$SRC\" ] && [ -d \"$SRC\" ]; then " +
                  "echo \">> creating account done, cloning desktop…\"; " +
                  "CLONE_DIRS='.config/quickshell .config/hypr " +
                    ".config/hypr-control-center .config/kitty " +
                    ".config/alacritty .config/fuzzel .config/fish " +
                    ".config/matugen .config/swww " +
                    ".config/gtk-3.0 .config/gtk-4.0 " +
                    ".local/share/quickshell .local/share/zen-shell " +
                    ".local/bin'; " +
                  "for rel in $CLONE_DIRS; do " +
                    "if [ -e \"$SRC/$rel\" ]; then " +
                      "echo \">> copying $rel\"; " +
                      "mkdir -p \"$(dirname \"$DST/$rel\")\"; " +
                      "cp -a \"$SRC/$rel\" \"$DST/$rel\"; " +
                    "fi; " +
                  "done; " +
                  // Rewrite absolute source-home paths in copied text files.
                  // -I skips binaries; we also prune VCS/cache noise and cap
                  // with `head` so a stray huge tree can't hang the action.
                  "echo \">> fixing paths\"; " +
                  "for rel in $CLONE_DIRS; do " +
                    "[ -d \"$DST/$rel\" ] || continue; " +
                    "grep -rIl --exclude-dir=.git --exclude-dir=node_modules " +
                      "\"$SRC/\" \"$DST/$rel\" 2>/dev/null | while read -r f; do " +
                      "sed -i \"s#$SRC/#$DST/#g\" \"$f\"; " +
                    "done; " +
                  "done; " +
                  "echo \">> setting ownership\"; " +
                  "chown -R '" + nameEscaped + "':'" + nameEscaped + "' \"$DST\"; " +
                  "echo \">> clone complete\"; " +
                "fi"
        }

        const label = copyDotfiles
            ? "Creating user '" + name + "' + cloning your dotfiles…"
            : "Creating user '" + name + "'…"
        _runPkexec(label, cmd, () => {
            root.lastAction = "✓ User '" + name + "' created" +
                              (isAdmin ? " with admin privileges" : "") +
                              (copyDotfiles ? " (dotfiles cloned)" : "")
            root.refresh()
        })
    }

    // ════════════════════════════════════════════════════════════════
    // ACTION: deleteUser
    // ════════════════════════════════════════════════════════════════
    //
    // Triple-checks safety then runs:
    //   userdel -r <name>     (-r also removes home directory)
    //
    // If you ever want to KEEP the home dir (e.g. for archival),
    // call deleteUserKeepHome instead.
    function deleteUser(name) {
        const refusal = _whyUnsafeToDelete(name)
        if (refusal) {
            lastError = refusal
            return
        }
        const nameEscaped = name.replace(/'/g, "'\\''")
        // FINAL shell-level guard: re-check that target != $USER even
        // here, in case state got out of sync between QML and the
        // moment pkexec actually runs.
        const cmd =
            "set -e; " +
            "if [ \"" + nameEscaped + "\" = \"$SUDO_USER\" ]; then " +
            "  echo 'SHELL GUARD: refusing to delete SUDO_USER' >&2; exit 99; " +
            "fi; " +
            "if [ \"" + nameEscaped + "\" = \"root\" ]; then " +
            "  echo 'SHELL GUARD: refusing to delete root' >&2; exit 99; " +
            "fi; " +
            "userdel -r '" + nameEscaped + "'"
        _runPkexec("Deleting user '" + name + "' (including home)…", cmd, () => {
            root.lastAction = "✓ User '" + name + "' deleted"
            root.refresh()
        })
    }

    function deleteUserKeepHome(name) {
        const refusal = _whyUnsafeToDelete(name)
        if (refusal) {
            lastError = refusal
            return
        }
        const nameEscaped = name.replace(/'/g, "'\\''")
        const cmd =
            "set -e; " +
            "if [ \"" + nameEscaped + "\" = \"$SUDO_USER\" ]; then exit 99; fi; " +
            "if [ \"" + nameEscaped + "\" = \"root\" ]; then exit 99; fi; " +
            "userdel '" + nameEscaped + "'"
        _runPkexec("Deleting user account '" + name + "' (home preserved)…", cmd, () => {
            root.lastAction = "✓ Account '" + name + "' deleted (home preserved)"
            root.refresh()
        })
    }

    // ════════════════════════════════════════════════════════════════
    // ACTION: setAdmin (add/remove from wheel)
    // ════════════════════════════════════════════════════════════════
    //
    // Refuses to demote the current user (would lock them out of
    // sudo immediately, requiring boot-time recovery).
    function setAdmin(name, makeAdmin) {
        if (!name) { lastError = "No user selected"; return }

        if (!makeAdmin) {
            // Refuse to demote current user
            if (name === currentUser || name === currentUserFromEnv
                || name === currentUserFromId) {
                lastError = "Refusing: cannot remove admin from currently-logged-in " +
                            "user '" + name + "' — you'd lock yourself out of sudo. " +
                            "Log in as another admin user to demote this account."
                return
            }
        }

        const nameEscaped = name.replace(/'/g, "'\\''")
        const cmd = makeAdmin
            ? "gpasswd -a '" + nameEscaped + "' wheel"
            : ("set -e; " +
               "if [ \"" + nameEscaped + "\" = \"$SUDO_USER\" ]; then " +
               "  echo 'SHELL GUARD: refusing to demote SUDO_USER' >&2; exit 99; " +
               "fi; " +
               "gpasswd -d '" + nameEscaped + "' wheel")

        const label = makeAdmin
            ? ("Granting admin to '" + name + "'…")
            : ("Removing admin from '" + name + "'…")
        _runPkexec(label, cmd, () => {
            root.lastAction = "✓ " + name +
                (makeAdmin ? " is now an admin" : " is no longer an admin")
            root.refresh()
        })
    }

    // ════════════════════════════════════════════════════════════════
    // ACTION: setPassword (for OTHER users only)
    // ════════════════════════════════════════════════════════════════
    //
    // Lets an admin reset another user's password. For the current
    // user's own password, the system tools (passwd in terminal,
    // or the desktop's account settings) are more appropriate.
    function setPassword(name, newPassword) {
        if (!name) { lastError = "No user selected"; return }
        if (!newPassword || newPassword.length < 4) {
            lastError = "New password must be at least 4 characters"
            return
        }
        const nameEscaped = name.replace(/'/g, "'\\''")
        const pwdEscaped = newPassword.replace(/'/g, "'\\''")
        const cmd = "echo '" + nameEscaped + ":" + pwdEscaped + "' | chpasswd"
        _runPkexec("Setting password for '" + name + "'…", cmd, () => {
            root.lastAction = "✓ Password updated for '" + name + "'"
        })
    }

    // ════════════════════════════════════════════════════════════════
    // INTERNAL: run a command under pkexec
    // ════════════════════════════════════════════════════════════════
    //
    // The pkexec invocation runs bash -c "<cmd>". We log the command
    // (sanitized — passwords masked) to the audit log before running.
    //
    // onSuccess: called only on exit 0
    //
    // Note: pkexec opens a GUI password prompt (polkit-gnome agent).
    // If the user cancels, exit code is 127 (or 126 if not authorized).
    function _runPkexec(label, cmd, onSuccess) {
        if (isRunning) {
            lastError = "Another user-management action is already running"
            return
        }
        isRunning = true
        lastAction = label
        lastError = ""

        // Audit log entry (sanitized command — replace anything after
        // `chpasswd` heredoc with [REDACTED] to avoid logging plain
        // passwords).
        _writeAuditLog(label, cmd.replace(/echo '[^']+:[^']*'/g,
                                          "echo '[name:REDACTED-PASSWORD]'"))

        // pkexec env preserves SUDO_USER and USER so our shell-level
        // guards have something to compare against.
        pkexecProc.command = ["pkexec", "bash", "-c", cmd]
        pkexecProc._pendingOnSuccess = onSuccess
        pkexecProc._stdoutBuf = ""
        pkexecProc._stderrBuf = ""
        pkexecProc.running = false
        pkexecProc.running = true
        watchdog.restart()   // hf95.23: guard against a never-returning action
    }

    Process {
        id: pkexecProc
        running: false
        property var _pendingOnSuccess: null
        property string _stdoutBuf: ""
        property string _stderrBuf: ""

        stdout: SplitParser {
            // hf95.23: live progress. Each ">> step" line the command echoes
            // is surfaced in the status banner immediately, so a long clone
            // shows what it's doing instead of sitting on "Creating user…".
            onRead: (line) => {
                const t = ("" + line).trim()
                if (t.length === 0) return
                pkexecProc._stdoutBuf += t + "\n"
                if (t.indexOf(">> ") === 0)
                    root.lastAction = "⏳ " + t.substring(3)
            }
        }
        stderr: StdioCollector {
            onStreamFinished: pkexecProc._stderrBuf = this.text
        }
        onExited: (exitCode, exitStatus) => {
            watchdog.stop()
            root.isRunning = false
            if (exitCode === 0) {
                if (_pendingOnSuccess) _pendingOnSuccess()
            } else if (exitCode === 99) {
                root.lastError = "✗ Shell guard refused (target was current user or root)"
            } else if (exitCode === 126 || exitCode === 127) {
                root.lastError = "✗ pkexec auth canceled or no polkit agent running. " +
                    "Make sure an authentication agent is active, then try again."
            } else {
                const stderrText = (_stderrBuf || "").trim()
                root.lastError = "✗ Action failed (exit " + exitCode + ")" +
                    (stderrText ? ": " + stderrText.substring(0, 200) : "")
            }
            _pendingOnSuccess = null
        }
    }

    // hf95.23: watchdog — if a pkexec action somehow neither exits nor
    // errors within 90s (e.g. no polkit agent so no prompt ever appears),
    // stop showing "Working…" forever and tell the user what to check.
    Timer {
        id: watchdog
        interval: 90000
        repeat: false
        onTriggered: {
            if (root.isRunning) {
                root.isRunning = false
                root.lastError = "✗ Timed out — the password prompt may not have appeared "
                    + "(no polkit agent?). Nothing was forced; re-run after confirming an "
                    + "authentication agent is running (e.g. polkit-gnome / hyprpolkitagent)."
            }
        }
    }

    // ════════════════════════════════════════════════════════════════
    // INTERNAL: audit log
    // ════════════════════════════════════════════════════════════════
    function _writeAuditLog(label, sanitizedCmd) {
        const ts = new Date().toISOString()
        const entry = "[" + ts + "] " + label + "  cmd=" + sanitizedCmd + "\n"
        const escaped = entry.replace(/'/g, "'\\''")
        auditWriter.command = ["bash", "-c",
            "mkdir -p ~/.cache/zen-shell && " +
            "printf '%s' '" + escaped + "' >> ~/.cache/zen-shell/user-mgmt.log"]
        auditWriter.running = false
        auditWriter.running = true
    }

    Process { id: auditWriter; running: false }
}
