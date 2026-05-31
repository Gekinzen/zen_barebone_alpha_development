# v7.0.0-beta.1-hf82q — Fix Hyprland source= globbing error from hf82n placeholder

**Channel:** beta (mini-patch on hf82p)
**Released:** 2026-05-25
**Scope:** 2 files (install.sh + ZenVersion.qml)

## Why

User reported error on boot (screenshot):
```
Config error in file /home/paul/.config/hypr/hyprland.conf at line 70:
    source= globbing error: found no match
```

That's line 70 = `source = ~/.config/hypr/modules/zen-window-rules.conf` which was added in hf82n's install.sh.

## Root cause

My hf82n changelog claimed:

> "the source line above can reference a not-yet-existent path safely (Hyprland skips missing sourced files with just a non-fatal warning)"

**This was WRONG.** Hyprland 0.52+ treats missing `source=` targets as a HARD error, per upstream:
- github.com/hyprwm/Hyprland/discussions/12737
- github.com/basecamp/omarchy/issues/5039: "there's no optional sourcing"

The hf82n install wrote the source line expecting WindowRulesService.qml to create the file on first toggle. But on FRESH boot before any toggle, Hyprland errors immediately.

## Fix

install.sh now **creates an empty placeholder** `zen-window-rules.conf` BEFORE writing the source line:

```bash
mkdir -p "$HYPR_DIR/modules"
if [ ! -f "$HYPR_DIR/modules/zen-window-rules.conf" ]; then
    cat > "$HYPR_DIR/modules/zen-window-rules.conf" << 'PLACEHOLDER'
# Managed by Zen Shell — Settings → App Float Rules
# (Placeholder so Hyprland source= doesn't error; will be overwritten
#  by WindowRulesService.qml on first toggle.)
PLACEHOLDER
fi
```

Idempotent — won't clobber a file that already has rules. Safe to re-run.

## Install

```fish
tar -xzf zen-shell-v7_0_0-beta_1-hf82q-patch-only.tgz
cd zen-shell-v7.0.0-beta.1-hf82q
./install.sh
```

Re-running install.sh creates the placeholder. The Hyprland error disappears on next `hyprctl reload`.

If you can't run install.sh right now and need to fix immediately:

```fish
touch ~/.config/hypr/modules/zen-window-rules.conf
hyprctl reload
```

## Wala tayong babawasan

install.sh additive only — adds the placeholder creation block. Existing behavior preserved.
