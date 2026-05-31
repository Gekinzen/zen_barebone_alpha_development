# v7.0.0-beta.1-hf82m.1 — hyprpm self-healing for "no repos / hyprbars missing" state

**Channel:** beta (mini-patch on hf82m)
**Released:** 2026-05-25
**Scope:** 2 files (install.sh + zen-plugin-bootstrap.sh)

## Why

User report after upgrading Hyprland 0.53 → 0.55:

```
hyprpm reload    → ✖ No repos to update
hyprpm enable hyprbars   → ✖ Couldn't enable plugin (missing?)
```

Root cause: install.sh's Phase 1 (`hyprpm update`) failed because headers were stale immediately after the 0.53 → 0.55 jump. `HYPRPM_OK=0` was set, which gated Phases 2-4 (add repos / build / enable / reload) to all SKIP. User manually fixed headers later via `hyprpm update` but the registry was still empty.

## Fix layer 1 — install.sh prints copy-paste recovery commands

When Phase 1 hyprpm update fails even after auto purge-cache retry, install.sh now prints an explicit recovery block:

```
─────────────────────────────────────────────────────
📋 MANUAL RECOVERY — copy-paste these AFTER you fix
   the headers issue (e.g. via 'hyprpm update' once
   hyprctl reports the correct Hyprland version):

   hyprpm add https://github.com/hyprwm/hyprland-plugins
   hyprpm enable hyprbars
   hyprpm reload

   Or just re-run this install.sh — Phases 2-4 are
   idempotent and will pick up where they left off.
─────────────────────────────────────────────────────
```

User no longer needs to dig through Hyprland wiki to figure out what's missing.

## Fix layer 2 — bootstrap self-heals on every boot

The hf82m boot-time bootstrap already does version-stamp comparison + auto `hyprpm update`. hf82m.1 adds a NEW `_check_and_recover_hyprpm_state()` function that runs on EVERY boot regardless of version change:

1. **Zero repos detected** → auto `hyprpm add https://github.com/hyprwm/hyprland-plugins`
2. **hyprbars present but disabled** → auto `hyprpm enable hyprbars`
3. **Both worked** → throttled notify-send "Hyprland plugins auto-recovered"
4. **Add failed** → critical-priority notify with exact manual commands

Numeric-safe parsing: grep -c + `|| echo 0` was concatenating "0" + "0" into "00" string, breaking the original simple `[ "$x" = "0" ]` check. Rewrote with proper numeric guards.

Safety: only the OFFICIAL hyprwm repo gets auto-added. Only hyprbars gets auto-enabled (Zen Shell's documented default plugin). Other plugins the user previously disabled stay disabled.

## Tested

Parser tested on 4 synthetic `hyprpm list` outputs:
- Empty (no repos) → `repos=0` → recovery triggers
- 1 repo + hyprbars enabled → `repos=1, hyprbars_enabled=true` → no-op
- 1 repo + hyprbars disabled → `repos=1, hyprbars_enabled=false` → enable triggers
- User's actual broken-state output → `repos=0` → recovery triggers

## Install

Drop-in over hf82m:

```fish
tar -xzf zen-shell-v7_0_0-beta_1-hf82m_1-patch-only.tgz
cd zen-shell-v7.0.0-beta.1-hf82m.1
./install.sh
```

After install, log out + log back in. The bootstrap will detect your current "no repos" state and auto-recover on first boot.

OR run the bootstrap manually right now to test without logging out:
```fish
~/.local/bin/zen-plugin-bootstrap.sh
cat /tmp/zen-plugin-bootstrap.log   # should show recovery steps
hyprpm list                         # should now show hyprland-plugins repo + hyprbars enabled
```

## Wala tayong babawasan

Both files purely additive. install.sh adds ~16 lines (the recovery block). bootstrap adds ~85 lines (the recovery function + invocation). All existing behavior preserved verbatim.
