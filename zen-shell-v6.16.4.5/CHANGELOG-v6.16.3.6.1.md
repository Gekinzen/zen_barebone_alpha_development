# Zen Shell v6.16.3.6.1 — Lock clock matches desktop widget weight

**Release date:** 2026-04-24
**Base:** v6.16.3.6

---

## TL;DR

> *"heto pre yung font same ganito sa widget natin haha!"*

v6.16.3.6's lock-screen font sync read `fontFamilyId` from
PanelState correctly but mapped `adwaita` → `"Adwaita Sans Light"`
— exactly the wrong weight. Paul's desktop ZenWidget clock uses:

```qml
font.family: "Adwaita Sans"
font.weight: Font.Black       // weight 900 — chunky/rounded look
font.letterSpacing: -4
```

Result: desktop widget clock looks bold+rounded (image 1), lock
clock looked thin+elegant (image 2). Same family, opposite weights.

**Fix**: rewrote the `CLOCK_FONT` mapping table in `zen-lock.sh` to
use Black / Heavy / Bold weight variants per font family. The
`MSG_FONT` mapping (for weather mood + care lines) stays at the
regular weight — those lines don't want to compete with the clock
for visual weight.

### New mapping table

| `fontFamilyId` | CLOCK_FONT (was → is)                             | MSG_FONT (unchanged)                  |
|----------------|---------------------------------------------------|---------------------------------------|
| adwaita        | Adwaita Sans Light → **Adwaita Sans Black**       | Adwaita Sans                          |
| jetbrains      | JetBrainsMono Nerd Font → **… Bold**              | JetBrainsMono Nerd Font Propo         |
| geist          | GeistMono Nerd Font Mono → **… Bold**             | GeistMono Nerd Font Mono              |
| firacode       | FiraCode Nerd Font → **… Bold**                   | FiraCode Nerd Font                    |
| caskaydia      | CaskaydiaCove Nerd Font → **… Bold**              | CaskaydiaCove Nerd Font               |
| iosevka        | Iosevka Nerd Font → **… Heavy**                   | Iosevka Nerd Font                     |
| hack           | Hack Nerd Font → **… Bold**                       | Hack Nerd Font                        |
| ubuntu         | UbuntuMono Nerd Font → **… Bold**                 | UbuntuMono Nerd Font                  |
| sfpro          | SF Pro Display → **… Black**                      | SF Pro Text                           |
| inter          | Inter → **Inter Black**                           | Inter                                 |

Also updated `hypr-config/hyprlock.conf`'s baseline `font_family`
line from `Adwaita Sans Light` to `Adwaita Sans Black` so fresh
installs / first lock before sed substitution runs also get the
correct look.

**Wala tayong binawasan.** Gender messages + weather mood logic
carried byte-identical from 3.6.

---

## Files

```
UPDATED
  scripts/zen-lock.sh              ← CLOCK_FONT mapping → Black/Heavy/Bold
  hypr-config/hyprlock.conf        ← default font_family → Adwaita Sans Black
  zen-shell-v5/ZenVersion.qml      ← bump to v6.16.3.6.1
  install.sh                        ← banner bump
NEW
  CHANGELOG-v6.16.3.6.1.md          ← this file
```

### CARRIED OVER from 3.6

- Hover popup parity (ZenClock, ZenSysMonitor)
- Gender-aware lock messages (3 pools per time × weather bucket)
- English-only message pools
- User Profile → Personal Preferences picker
- Weather mood line + care line with 350ms hover intent
- Clock-font-sync-from-PanelState architecture

---

## Install / verify

```bash
tar -xzf zen-shell-v6.16.3.6.1.tar.gz
cd zen-shell-v6.16.3.6.1
./install.sh
```

No shell restart needed — the change only affects lock screen.

### Lock test

1. `~/.local/bin/zen-lock.sh` (or wait for hypridle timeout)
2. Lock clock should now render in **chunky Black weight**,
   matching your desktop widget's clock styling
3. Message lines (weather mood + care) stay at regular Adwaita Sans
   weight so they read as secondary text, not competing with clock

### Troubleshooting

If the clock looks the same thin weight after this update, your
installed Adwaita Sans font may not ship a "Black" variant. Test
via fc-list:

```bash
fc-list | grep -i "adwaita sans"
```

Expected output includes `Adwaita Sans:style=Black` or similar.
If not, install the full Adwaita Sans family:

```bash
# On CachyOS/Arch
sudo pacman -S adwaita-fonts
# Or install the full GNOME font pack
sudo pacman -S gnome-themes-extra
```

If the Black variant STILL isn't available, edit `zen-lock.sh`
line with `CLOCK_FONT="Adwaita Sans Black"` → try `"Adwaita Sans
Heavy"` or `"Adwaita Sans ExtraBold"`. fc-list will show what your
system has.
