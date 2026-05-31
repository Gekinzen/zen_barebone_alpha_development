# v7.0.0-beta.1-hf82u — Fix Hyprland 0.55 "invalid field float: missing a value"

**Channel:** beta (hotfix on hf82t)
**Released:** 2026-05-26
**Scope:** 3 files (WindowRulesService, install.sh, ZenVersion)

## The bug

After installing hf82t, toggling Brave float showed a NEW error:

```
Config error in file /home/paul/.config/hypr/modules/zen-window-rules.conf
at line 8: invalid field float: missing a value
```

Different from hf82s's `windowrulev2 deprecated` error — this one says
the `float` keyword needs an explicit value.

## Root cause

Hyprland 0.53 didn't just deprecate `windowrulev2`. It **overhauled the
entire windowrule syntax**. Per upstream pyprland #201:

> Hyprland 0.53.0 completely overhauled the windowrule syntax.
> Errors: `invalid field float: missing a value`
> Fix: `windowrule = match:class classname, float on`

My hf82t fixed the keyword (`v2` → no `v2`) but kept the old field
format. The new format requires:

1. Match props use `match:class` prefix (not bare `class:^(...)`)
2. Boolean effects need explicit values (`float on`, not just `float`)

## Three historical formats

| Version range | Syntax | Status on 0.55 |
|---|---|---|
| hf82n-s | `windowrulev2 = float, class:^(N)$` | ❌ Deprecated keyword error |
| hf82t | `windowrule = float, class:^(N)$` | ❌ "invalid field float: missing a value" |
| **hf82u** | `windowrule = match:class ^(N)$, float on` | ✅ Works on 0.42 through 0.55+ |

## What ships

### WindowRulesService.qml — emits the correct syntax now

```qml
// Was: "windowrule = float, class:^(N)$  # zen-shell-float\n"
// Now: "windowrule = match:class ^(N)$, float on  # zen-shell-float\n"
```

Parser updated to recognize ALL THREE historical syntaxes so existing
toggles from any prior version are preserved (the writer always emits
the new form, so legacy entries auto-migrate on next toggle).

### install.sh — universal migration via Perl

Rewrites both broken formats to the canonical 0.53+ form in one pass:

```perl
s{^(\s*)windowrule(?:v2)?(\s*=\s*)float\s*,\s*class:\^\(([^)]+)\)\$(.*)$}
 {$1windowrule$2match:class ^($3)\$, float on$4}gx;
```

Idempotent — re-runs safe. Backup at `.pre-hf82u-<timestamp>`.

User-added non-float rules (e.g. `windowrulev2 = opacity ...`) without
the `# zen-shell-float` tag are NOT touched.

## Install

```bash
tar -xzf zen-shell-v7_0_0-beta_1-hf82u.tgz
cd zen-shell-v7.0.0-beta.1-hf82u
./install.sh
```

Hyprland reloads automatically on next toggle, OR run manually:

```bash
hyprctl reload
```

## Verify

After install:

1. `cat ~/.config/hypr/modules/zen-window-rules.conf` should show:
   ```
   windowrule = match:class ^(Brave-browser)$, float on  # zen-shell-float
   ```
   (your old `windowrule = float, class:...` lines auto-migrated)

2. `hyprctl reload` → should return `ok` with **no errors at top of screen**

3. Toggle a new app in Settings → App Float Rules → also no errors

4. Backup exists: `ls ~/.config/hypr/modules/zen-window-rules.conf.pre-hf82u-*`

## Note for users with already-installed hf82r/s/t

If you've been on the cycle of trying-each-fix, this is the final form.
The Perl migration in install.sh handles all 3 historical formats so
you'll converge on the working syntax regardless of which version you
came from.

## Open threads

- Drag easier (still need your pick)
- Samsung folder feature (still need 3 picks)
- Profile setup popup positioning
