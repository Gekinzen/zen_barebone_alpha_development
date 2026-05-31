# Zen Shell v7.0.0-beta.1-hf94.2 — Karui (軽い)

Release date: 2026-05-30
Channel: beta · Codename: Karui (軽い)

**Crash hotfix #2 for hf94.** Wala tayong babawasan.

---

## Fix: GridLayout `columns: 999` → 32

hf94.1 still crashed within 10s. Strongest remaining suspect: the
vertical-capable modules used `columns: 999` on their `GridLayout` for
the horizontal "all on one row" case. Qt's `GridLayout` allocates
internal structures per column, and a count like 999 can overflow /
assert and **hard-crash the scene graph** — and since SysRow + tray load
in the horizontal bar too, this crashes regardless of which edge the bar
is on.

- **`SysRow.qml`** + **`SystemTray.qml`** — `columns` for the horizontal
  case is now `32` (a sane bound — far more than the handful of children
  these ever have, small enough that Qt allocates fine). Vertical stays
  `1`. (Workspaces already used `wsCount`, which is small — left as is.)

---

## If it STILL crashes — please grab the backtrace

If this build still crashes, the exact culprit is in the coredump and
will name the QML file + line. Please run and paste the output:

```fish
# newest crash dir:
set crashdir (ls -dt ~/.cache/quickshell/crashes/*/ | head -1)
echo $crashdir
cat $crashdir/*.txt 2>/dev/null | head -60

# if there is a coredump, a backtrace:
coredumpctl gdb (cat $crashdir/pid 2>/dev/null) 2>/dev/null <<'EOF'
bt
quit
EOF
```

Even just the first ~40 lines of the crash `.txt` (or `journalctl -b -0
--no-pager | grep -i quickshell | tail -40`) will pinpoint which module
faults, so the next fix is exact instead of a guess.

---

## Files touched

```
ZenVersion.qml   → v7.0.0-beta.1-hf94.2
SysRow.qml       GridLayout columns 999 → 32 (horizontal case)
SystemTray.qml   GridLayout columns 999 → 32 (horizontal case)
```

Carries forward hf83–hf94.1. Horizontal bar otherwise remains the
known-good pre-hf90 version; vertical modules are opt-in via explicit
flags.

> Lesson logged: never use an arbitrarily huge `columns`/`rows` constant
> on a Qt `GridLayout` to mean "one line" — it pre-allocates per track
> and can crash. Use the real (small) child count or a sane bound.
