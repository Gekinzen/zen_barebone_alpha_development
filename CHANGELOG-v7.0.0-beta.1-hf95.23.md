# Zen Shell v7.0.0-beta.1-hf95.23 — Karui (軽い)

Release date: 2026-05-31
Channel: beta · Codename: Karui (軽い)

**User creation now shows live progress and can't appear permanently
stuck. If the pkexec password prompt never shows (e.g. no polkit agent),
you get a clear message instead of a frozen "Creating user…".** Wala
tayong babawasan.

---

## Why it looked stuck

`createUser` runs everything through one `pkexec` call. The banner showed
the START label ("Creating user 'yuki' + cloning your dotfiles…") and
only updated on exit. If no polkit authentication agent was running, no
password prompt appeared, the process never progressed, and the banner sat
on that label with no feedback — looking frozen even though nothing had
actually run.

(The generated shell command itself is fine — syntax-checked end to end.)

## Fixes

1. **Live progress.** The clone command now echoes `>> step` markers
   (creating account, copying each dir, fixing paths, setting ownership,
   clone complete) and the service streams them into the banner via a
   `SplitParser`, so you see exactly what it's doing.
2. **Watchdog.** If an action neither finishes nor errors within 90s, the
   service stops the spinner and explains the likely cause (no polkit
   agent / prompt dismissed) — nothing is forced.
3. **Clearer auth error.** Exit 126/127 now says the prompt was canceled
   or no polkit agent is running, and what to start
   (polkit-gnome / hyprpolkitagent).
4. **Robustness.** Path-rewrite `grep` skips `.git`/`node_modules`; stdout/
   stderr buffers reset per run.

## How to verify your setup

If creation still does nothing instantly, check an auth agent is running:
`pgrep -fa polkit` — Zen's autostart launches
`polkit-gnome-authentication-agent-1`; if you removed it, start a polkit
agent and retry.

## Version

- `ZenVersion.qml` bumped `hf95.22` → `hf95.23`.

## Files touched

- `zen-shell-v5/UserManagementService.qml` — live progress, watchdog, clearer errors, sturdier clone
- `zen-shell-v5/ZenVersion.qml` — version string

No feature, setting, or file removed.
