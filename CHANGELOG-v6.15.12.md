# Zen Shell v6.15.12 — Patch Changelog

**Release date:** 2026-04-20
**Base:** v6.15.11 (self-suiciding helper script)

**Scope:** Fix v6.15.11's self-suicide + install helper permanently.
**3 files touched:** `shell.qml`, `install.sh`, new `scripts/zs-restart.sh`.

---

## The self-suicide bug

v6.15.11's helper was written to `/tmp/zen-shell-nuclear-restart.sh`.
That filename contains "zen-shell". Inside, it ran:

```bash
pkill -f zen-shell
```

`pkill -f` matches full cmdline. The script's own bash process has
cmdline `/bin/bash /tmp/zen-shell-nuclear-restart.sh` which contains
"zen-shell". **Script killed itself mid-execution.** The `sleep 0.2
&& quickshell -p ...` after pkill never ran → Quickshell stayed dead.

Paul reported exactly this:
> "nung nag pkill -f zen-shell wala na hindi nag load yung sleep mo
> 0.2 quickshell -p ..."

## Three fixes

### 1. Safe filename: `zs-restart.sh`

No "zen-shell" substring anywhere. Process cmdline becomes
`/bin/bash /home/paul/.local/bin/zs-restart.sh` — doesn't match any
pkill pattern we'd use.

### 2. Tightened pkill pattern: `quickshell.*zen-shell`

```bash
pkill -f 'quickshell.*zen-shell'
```

Matches `quickshell -p ~/.config/quickshell/zen-shell` but NOT
`/bin/bash .../zs-restart.sh` (no "quickshell" in cmdline).

### 3. Permanent install via install.sh

New file `scripts/zs-restart.sh` gets installed to
`~/.local/bin/zs-restart.sh` as part of install.sh step 5 (alongside
regen-swaync-theme.sh, zen-screenshot.sh, etc.). Falls back to
inline `/tmp/zs-restart.sh` if user applied hotfix without re-running
install.sh.

## Helper script contents

```bash
#!/usr/bin/env bash
LOG=/tmp/zs-restart.log
exec >> "$LOG" 2>&1

echo "[$(date -Iseconds)] zs-restart: starting (pid=$$)"
echo "[$(date -Iseconds)] zs-restart: invoked as: $0"
echo "[$(date -Iseconds)] zs-restart: my cmdline: $(tr '\0' ' ' < /proc/$$/cmdline)"

sleep 0.3

echo "[$(date -Iseconds)] zs-restart: matching quickshell processes:"
pgrep -af 'quickshell.*zen-shell' || echo "  (none found)"

pkill -f 'quickshell.*zen-shell' 2>/dev/null
echo "[$(date -Iseconds)] zs-restart: pkill returned $? (0=killed, 1=no matches)"

sleep 0.3

echo "[$(date -Iseconds)] zs-restart: launching fresh quickshell"
quickshell -p "$HOME/.config/quickshell/zen-shell" </dev/null >/dev/null 2>&1 &
LAUNCH_PID=$!
disown

echo "[$(date -Iseconds)] zs-restart: dispatched pid=$LAUNCH_PID"
exit 0
```

Heavy diagnostic logging so `/tmp/zs-restart.log` tells you exactly
what happened:
- What file was invoked
- Own PID and cmdline
- Which quickshell processes were matched BEFORE kill
- pkill return code (0 = killed, 1 = no match found)
- Respawn PID

## Files changed

```
zen-shell-v5/shell.qml      v6.15.11 → v6.15.12 (use zs-restart.sh + tightened pattern)
install.sh                  v6.15.11 → v6.15.12 (install zs-restart.sh in step 5)
scripts/zs-restart.sh       NEW FILE (v6.15.12)
```

## Migration

**Option A — full reinstall (recommended):**
```bash
cd zen-shell-v6.15.12
./install.sh
```
Installs `~/.local/bin/zs-restart.sh` + updates shell.qml.

**Option B — hotfix patch:**
```bash
tar -xzf zen-shell-v6.15.12-hotfix-patch.tar.gz
cd zen-shell-v6.15.12-hotfix
./APPLY.sh
# Then also install the helper:
mkdir -p ~/.local/bin
cp scripts/zs-restart.sh ~/.local/bin/
chmod +x ~/.local/bin/zs-restart.sh
```

**Option C — skip installing helper:**
Apply only `shell.qml`. Inline `/tmp/zs-restart.sh` fallback will be
used. Works, but writes to /tmp at every transition.

## Manual tests

**1. Direct helper test:**
```bash
~/.local/bin/zs-restart.sh
# Should kill + respawn quickshell in ~1s
cat /tmp/zs-restart.log   # → full trace
```

**2. IPC test (requires running shell):**
```bash
quickshell -p ~/.config/quickshell/zen-shell ipc call zen testNuclearRestart
# → flicker + respawn
```

**3. Real scenario:**
- Start in Island
- Float → FW → Island
- Expected: brief ~600ms flicker, then clean island with music string
  at correct position

## Why the long tail of patches

| Ver | Issue |
|-----|-------|
| v6.15.10 | Wrong pkill pattern, wrong respawn command (`qs -c` vs `quickshell -p`) |
| v6.15.11 | Right commands, but helper script filename contained "zen-shell" → self-suicided |
| v6.15.12 | Safe filename + tightened pattern + permanent install |

Lesson: `pkill -f <broad-pattern>` is dangerous in self-executing
scripts. Always use the narrowest possible pattern, or name scripts
so they can't match themselves.
