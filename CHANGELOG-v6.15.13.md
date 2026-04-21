# Zen Shell v6.15.13 — Patch Changelog

**Release date:** 2026-04-20
**Base:** v6.15.12 (working nuclear restart, but had cosmetic/upgrade issues)

**Scope:** Polish the install automation + make zs-restart.sh fully
generic. **2 files touched:** `scripts/zs-restart.sh`, `install.sh`.
No QML changes — v6.15.12's shell.qml logic is preserved.

---

## Why this patch

Paul asked:
> "automate ba ito sa install.sh and whole installer natin? i mean
> automatic mag generate nung zs restart? kasi panu kapag first timer
> na tao lang ito fresh install dpat kasama yan satin package natin.
> mas maganda nasa scripts yan and dynamic yan dpende sa user pc
> hindi dapat static paul yan haha"

Translation:
1. Is this automated in install.sh and our whole installer?
2. Auto-generate zs-restart?
3. What if it's a first-timer with a fresh install?
4. Should be part of our package
5. Better in scripts/
6. Dynamic depending on user's PC, shouldn't be static "Paul" lol

**Status check:**
1. ✅ Yes — added to install.sh step 5 in v6.15.12
2. ✅ Yes — `cp scripts/zs-restart.sh ~/.local/bin/` + chmod +x
3. ✅ Fresh install works end-to-end via `./install.sh`
4. ✅ `scripts/zs-restart.sh` shipped in the package
5. ✅ Lives in `scripts/` dir like all other helpers
6. ⚠️ Had "/home/paul/..." hardcoded in 3 comment examples

Point 6 is what v6.15.13 fixes. Plus some other polish.

---

## Three improvements

### 1. Fully generic zs-restart.sh

Removed all "/home/paul/..." examples from comments. Script now uses
`$HOME` and `$USER` consistently:

```bash
echo "[$(date -Iseconds)] zs-restart:   user   = ${USER:-unknown}"
echo "[$(date -Iseconds)] zs-restart:   home   = ${HOME:-unknown}"
echo "[$(date -Iseconds)] zs-restart:   script = $0"
echo "[$(date -Iseconds)] zs-restart:   cmdline= $(tr '\0' ' ' < /proc/$$/cmdline)"
```

Comment examples updated from `/home/paul/...` to `/home/$USER/...`.
Works for any user on any system out-of-box. Paul-agnostic. 🤖

### 2. Pre-flight checks for robustness

Before attempting to kill + respawn, the script now verifies:

**Quickshell binary exists:**
```bash
if ! command -v quickshell >/dev/null 2>&1; then
    echo "FATAL — 'quickshell' binary not found in PATH"
    exit 1
fi
QUICKSHELL_BIN=$(command -v quickshell)
```

**Zen Shell config dir exists:**
```bash
ZEN_SHELL_DIR="$HOME/.config/quickshell/zen-shell"
if [ ! -d "$ZEN_SHELL_DIR" ]; then
    echo "FATAL — Zen Shell config dir not found: $ZEN_SHELL_DIR"
    echo "Did you run install.sh?"
    exit 1
fi
```

If either is missing, the script **fails fast with a clear diagnostic
in /tmp/zs-restart.log** instead of silently running pkill and then
failing to respawn (which is what v6.15.12 would have done).

Also uses the resolved `$QUICKSHELL_BIN` explicitly when launching,
avoiding a PATH race if the user's shell environment is unusual.

### 3. Stale file cleanup on upgrade

Users upgrading from v6.15.11 (which installed
`~/.local/bin/zen-shell-nuclear-restart.sh`) would end up with BOTH
the old and new scripts after running install.sh.

v6.15.13's install.sh step 5 now detects and removes the stale file:

```bash
if [ -f "$BIN_DIR/zen-shell-nuclear-restart.sh" ]; then
    rm -f "$BIN_DIR/zen-shell-nuclear-restart.sh"
    echo "    removed stale: zen-shell-nuclear-restart.sh (replaced by zs-restart.sh)"
fi
```

Only runs if the file exists — no-op for fresh installs.

---

## Enhanced diagnostic log format

v6.15.13's zs-restart.log now shows:

```
==================================================================
[2026-04-20T22:17:34+08:00] zs-restart: starting
[2026-04-20T22:17:34+08:00] zs-restart:   pid    = 12345
[2026-04-20T22:17:34+08:00] zs-restart:   user   = alice
[2026-04-20T22:17:34+08:00] zs-restart:   home   = /home/alice
[2026-04-20T22:17:34+08:00] zs-restart:   script = /home/alice/.local/bin/zs-restart.sh
[2026-04-20T22:17:34+08:00] zs-restart:   cmdline= /bin/bash /home/alice/.local/bin/zs-restart.sh
[2026-04-20T22:17:34+08:00] zs-restart:   qs bin = /usr/bin/quickshell
[2026-04-20T22:17:34+08:00] zs-restart:   config = /home/alice/.config/quickshell/zen-shell
[2026-04-20T22:17:35+08:00] zs-restart: matching quickshell processes BEFORE kill:
                                 12300 quickshell -p /home/alice/.config/quickshell/zen-shell
[2026-04-20T22:17:35+08:00] zs-restart: pkill returned 0
                                 (0 = processes killed)
[2026-04-20T22:17:35+08:00] zs-restart: launching: /usr/bin/quickshell -p /home/alice/.config/quickshell/zen-shell
[2026-04-20T22:17:35+08:00] zs-restart: respawn dispatched (pid=12380)
[2026-04-20T22:17:35+08:00] zs-restart: done
```

First 7 lines are pre-flight info (user/paths/binary). Rest is the
actual kill + respawn sequence. If something fails, the FATAL line
tells you exactly what's missing.

---

## Files changed

```
scripts/zs-restart.sh      v6.15.12 → v6.15.13 (fully generic, pre-flight checks)
install.sh                 v6.15.12 → v6.15.13 (stale file cleanup + banner)
```

No QML changes. `shell.qml`, `Bar.qml`, `SettingsStateV2.qml` all
identical to v6.15.12.

## Migration

**Fresh install (first-timer):**
```bash
cd zen-shell-v6.15.13
./install.sh
```
Everything automatic — helper installed, QML patched, Hyprland config
sourced, done.

**Upgrade from v6.15.12:**
```bash
cd zen-shell-v6.15.13
./install.sh
```
Same command. `cp` is idempotent, overwrites `~/.local/bin/zs-restart.sh`
with the improved version.

**Upgrade from v6.15.11 or earlier:**
```bash
cd zen-shell-v6.15.13
./install.sh
```
Same command. Additionally removes the stale
`~/.local/bin/zen-shell-nuclear-restart.sh` from old installs.

**Hotfix only (no full reinstall):**
```bash
tar -xzf zen-shell-v6.15.13-hotfix-patch.tar.gz
cd zen-shell-v6.15.13-hotfix
./APPLY.sh
```
Installs new zs-restart.sh, removes stale one if present.

## Testing

**1. Fresh install verification:**
```bash
# Remove old installs first (if testing on Paul's machine)
rm -f ~/.local/bin/zs-restart.sh ~/.local/bin/zen-shell-nuclear-restart.sh

# Fresh install
cd zen-shell-v6.15.13
./install.sh

# Verify
ls -la ~/.local/bin/zs-restart.sh          # should exist, +x
test -f ~/.local/bin/zen-shell-nuclear-restart.sh && echo "stale present!" || echo "clean"
~/.local/bin/zs-restart.sh                  # should show pre-flight checks pass
cat /tmp/zs-restart.log
```

**2. Verify no user-specific hardcoding:**
```bash
grep -c "paul\|/home/paul" ~/.local/bin/zs-restart.sh
# Should be 0
```

**3. Test the actual bug fix (same as v6.15.12):**
- Island → Fullwidth → Floating → Island: brief flicker, correct position

## Why another patch for this

Paul explicitly called out the hardcoded "paul" in the script as a
concern for anyone else using this package. Fair point — this is a
public-facing release and the script should work generically for any
user.

The pre-flight checks + stale cleanup are small quality-of-life
additions that make the fresh-install experience smoother and
upgrade-from-old-versions work without manual cleanup.

No functional changes to the nuclear restart logic itself. v6.15.12's
fix still does the work. v6.15.13 just polishes the deployment.
