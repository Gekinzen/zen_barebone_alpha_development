# CHANGELOG — Zen Shell v8 Complete

_Current build: **v8.1.0-alpha-hf202** · 2026-08-21 · Karui (軽い) · alpha channel_
_Public stable: Modori (戻り) v6.16.4.12.9.10_

Layout: **STATUS** (what's done, what's next) → **current builds** (hf202, hf201, hf200, hf199, hf198, hf197, hf196, hf195, hf194, hf193, hf192, hf191, hf190, hf189, hf188, hf187, hf186, hf185, hf184, hf183, hf182, hf181, hf180, hf179, hf178, hf177, hf176, hf175, hf174, hf173, hf172, hf171, hf170, hf169, hf168, hf167, hf166, hf165, hf164, hf163, hf162, hf161, hf160, hf159, hf158, hf157, hf156, hf155, hf154, hf153, hf152, hf151, hf150, hf149, hf148, hf147, hf146, hf145, hf144, hf143, hf142, hf141, hf140, hf139, hf138, hf137, hf136, hf135, hf134, hf133, hf132, hf131, hf130, hf129)
→ **ARCHIVE** (hf128 back to v7.0.0-beta.1-hf99, verbatim).

---

## STATUS — anu na done / on-going / planned

**Lock screen & install**
- **Lock background is your current wallpaper (hf157).** hyprlock now shows the live
  desktop wallpaper (blurred a touch), kept in sync on every wallpaper switch + seeded
  on start. Empty-safe: a `color` fallback means the lock never comes up broken.
- **All lock text reads on any wallpaper (hf157).** Clock, greeting, and the daily
  random line got soft drop shadows — white text over a bright wallpaper is visible now
  (this is likely why the random message looked missing).
- **Lock screen greeting + message now read the clock — five buckets.** The
  greeting flips morning / lunch / afternoon / evening / late-night (with a matching
  emoji), and the inspirational line below it draws from a pool themed to that same
  bucket, so a 3am lock reads different from a 9am one. All the hf152 quotes are
  still there — just sorted into the hours they fit, plus time-specific ones. Same
  20s rotation, same tuned positions (hf154)
- **Profile guard: reinstall never touches your bar/panel state.** If you already
  have a valid `panel-state.json` / `bar-layout.json`, the installer snapshots them
  before any migration and restores them verbatim at the end — so a reinstall can't
  swallow your QML bar panel layout. The one-shot migrations still run for
  first-timers; opt in on an existing box with `ZEN_ALLOW_PROFILE_MIGRATE=1` (hf153)
- **Lock screen: eye removed, black wash off.** The decorative eye is gone (hyprlock
  genuinely can't reveal a password — confirmed in source back in hf142), and the
  dim scrim now ships at alpha 0, so no black overlay. The lock glyph stays (hf152)
- **fuzzel is production-ready.** Confirmed on a clean install: the script lands in
  ~/.local/bin and thins a fresh fuzzel.ini to white frost on Glass+ (hf152)

**Shell Look & icons**
- **Glass+ stays readable on a bright wallpaper (hf158).** The clear frost now reads the
  wallpaper's luminance and ramps a dark "smoke" into the panel only as the wallpaper
  gets bright — dark wallpapers keep the exact white glass, bright ones get a smoked
  panel so white text/icons stay legible. Smooth, per-wallpaper, and it drives every
  surface through one `LookService.clearFill()` helper.
- **Glass survives login now — no more re-scrolling the slider.** The frost blur is a
  Hyprland layerrule pushed with `hyprctl`; at login the shell fired it once before
  Hyprland had mapped the zen-shell-* layers, so the rule hit nothing and the panels
  came up at the wrong strength until you nudged the Glassiness slider. It now
  re-issues the rule a few times over the first ~3.5s, so full glass lands on its own
  (hf155)
- **The weather + system-monitor desktop cards frost on Glass+.** They were the last
  solid slabs on the clear look — dark boxes over the frosted desktop. Now they wear
  the same white frost as every shell panel: body, the 7-day forecast tiles, and the
  CPU/GPU/RAM/NET metric cards, all gated on the clear look (every other look is
  byte-identical). The MERGED Glance blob is deliberately left alone — "except sa
  merged nila" (hf153)
- **fuzzel matches the white frost, and actually installs.** hf150's fuzzel script
  thinned the theme colour (cream on a light theme — didn't match the white-frost
  panels) and, more importantly, was only reachable through the install shim.
  It now forces a neutral white background like every other surface, restores the
  theme background off Glass+ (jq or a grep fallback), and is confirmed to reach
  ~/.local/bin (hf151)
- **Power menu, taskbar menu, clock, fuzzel.** The session menu, both taskbar
  right-click menus, and the clock module now frost on Glass+. And the fuzzel
  launcher — its own app, opaque black before — gets a translucent background
  through a small post-regen script, so even the app launcher is glass (hf150)
- **The right notification panel, the Control Center, and the hyprbars.** hf148
  frosted `ZenNotificationCenter` — but the popup that actually shows is
  `NotificationListPanel`. Fixed that, and extended the frost to the whole Control
  Center window and to the window title bars (hyprbars go translucent white on
  Glass+, tracking the frost slider) (hf149)
- **Frosted everywhere.** The start menu, the notification centre and the calendar
  popup now get the same frosted-white body on Glass+ that the dock, bars and
  desktop panel already had — one neutral fill, no border. Eight surfaces, one
  treatment (hf148)
- **Frosted panel bodies on Glass+.** The dock and both bars painted their body as
  bg0 × barOpacity, which Glass+ had written down to ~0.07 — so they went
  see-through ("butas-butas"). They now use the same white-frost fill the desktop
  panel does: one neutral colour, no theme tint, no border — but only on the clear
  look; every other look is untouched (hf147)
- **Glass+ keeps your colourful icons.** It no longer forces white icons on — the
  toggle stays, just off by default, so icons are Apple-style colourful on the
  glass (hf147)
- **White app icons.** Monochrome-icon mode for the dock and both bars — every app
  icon flattened to white, silhouette preserved, via `ColorOverlay`. One
  `Taskbar.qml` feeds all three surfaces. Toggle on the Shell Look page; Glass+
  turns it on by default (hf146)
- **Frost floor lifted** from 0.04 to 0.10 so max frost still shows a pane (hf146)
- **Notification + look-switch chimes removed** — the "tingg" is gone; the volume
  tick stays (hf146)

**Audio**
- **The volume slider was silent.** The tick sound lived only in the poll-driven
  `onAudioVolumeChanged`, which a slider drag never re-entered — it set the value
  directly. Hardware keys ticked; the slider didn't. It now ticks on the
  user-initiated path, with a self-set window so the wpctl echo doesn't
  double-fire (hf145)
- **Per-event sound throttle.** 80ms let a 60fps drag through at ~20% cadence, so
  fast adjustments felt silent. Volume ticks are 45ms now (login/logout keep the
  wider window) (hf145)

**Shell Look — Glass Advanced+**
- **New look: Glass — Advanced+.** Fully clear — no theme tint, just a white
  frost over Hyprland's blur. Every surface follows it: Control Center,
  notifications, dock, start menu, and the desktop icons panel (hf144)
- **A frost slider.** One 0–100% knob on the Shell Look page (shown only for
  Glass+) that drives panel fill AND Hyprland blur strength together, live. The
  border stays crisp so panels remain readable at full glass (hf144)
- **The notification toast and desktop panel now follow the look.** The toast was
  hardcoded to a solid box; the desktop panel had its own glass toggle. Both read
  LookService now (hf144)
- **Sounds on every look change**, and a soft chime when a notification arrives —
  both through the existing sound service, both toggleable (hf144)

### ✅ DONE — this cycle (hf129 · hf130 · hf131 · hf132 · hf133 · hf134 · hf135 · hf136 · hf137 · hf138 · hf139 · hf140 · hf141 · hf142 · hf143 · hf144 · hf145)

**Lock screen & themes**
- **The random message rotated every 15 minutes.** `cmd[update:900000]` arms a
  timer for exactly that many ms (`Label.cpp:59`). Lock for five minutes and you
  see one message, forever. Now 20s (hf143)
- **The scrim is capped and padded.** `100%, 100%` is viewport-relative — the
  wider the monitor, the more of it goes dark, which is exactly backwards on a
  3440px screen. `$zenScrimSize` / `$zenScrimRound`, defaulting to `76%, 88%`
  with rounding. Three presets documented in the file (hf143)
- **The eye still cannot show your password.** Third time, with the code: nothing
  in `PasswordInputField.cpp` renders the typed characters. See hf142 (hf143)
- **The lock and eye icons were cut off on the right.** hyprgraphics sizes a
  label's cairo surface with `logical.width` — the ADVANCE — and ignores the ink
  extents it just computed (`TextResource.cpp:88`). At 18px the JetBrainsMono cell
  is 10.8px; the lock's ink runs to 15px, the eye-slash's to 21px. A non-breaking
  space either side takes the advance to 32.4px against 32px of ink (hf142)
- **hyprlock has no plaintext password mode at all.** Not "no toggle" — no mode.
  `hide_input` chooses between dots and a coloured border quadrant, and nothing in
  `PasswordInputField.cpp` renders the typed characters as text. `$zenEyeColor`
  lets you delete the eye with one alpha (hf142)
- **The installer now REMOVES the duplicate source line.** hf140 stopped it from
  adding a second one; it did nothing about the one hf139 had already written, so
  a reinstall politely left your doubled buttons exactly where they were (hf141)
- **The dim is the whole screen, not a box.** hf138 drew an 820×620 rounded
  `shape`. A layout value ending in `%` is multiplied by the viewport
  (`ConfigDataValues.hpp:48-53`), so the scrim is `size = 100%, 100%` now. It
  cannot swallow the buttons: hyprlock calls `onClick` on **every** widget under
  the cursor and `CShape::onClick` does nothing without an `onclick` (hf141)
- **`systemctl poweroff` was spawned twice per click.** Both the pill `shape` and
  its `label` carried `onclick`, and hyprlock dispatches to every widget under the
  cursor. The shape owns it now (hf141)
- **install.sh sourced BOTH includes, so every button drew twice.** The guard
  looked for `zen-hyprlock-power.conf`; after `--ui` your file sources
  `zen-hyprlock-ui.conf` instead, the guard missed, and the power include was
  appended alongside. `zen-hyprlock-ui.conf` already contains the buttons — the
  guard now matches either, and `--fix` refuses to run when the UI is wired (hf140)
- **I made your clock thin.** hf138 set the clock's `font_family` to
  `Adwaita Sans`. `install.sh:2195` says out loud that `zen-lock.sh` maps
  fontFamilyId → **`Adwaita Sans Black`** "to match the desktop widget clock
  weight". New `$zenClockFont` variable; the clock, and only the clock, uses it (hf140)
- **`Good afternoon, paul`** → `Paul`. `id -un` is lowercase; the greeting now
  reads GECOS first and capitalises either way. Tested against `paul`, `Paul`,
  `juan-dela-cruz`, `"Paul Yuki"` (hf140)
- **Your geometry, kept.** 820×620 card, 480×68 field, 250×66 pills, your
  positions and your seven messages — shipped as you tuned them (hf140)
- **A trailing comment on a block opener made the migrator go blind.**
  `label {   # the clock` never matched `is_open`, so its closing `}` drove the
  depth counter negative and every widget after it was invisible. hyprlock's own
  example config has that shape. The migrator now reads structure through
  hyprlang's real comment rule (hf139)
- **`zen-hyprlock-doctor --status`** — is the UI wired, how many live widgets
  remain, and what the `cmd[]` labels render right now. Answers "did it work?"
  without locking the screen (hf139)
- **`zen-hyprlock-ui.conf` — the whole centre stack.** Dim card, clock, ONE
  greeting, ONE message, the password pill with a lock glyph left and an eye
  right, and the two power pills. Apply with `zen-hyprlock-doctor --ui`, which
  comments out your existing widgets (backup + one-command undo) and sources this
  instead. Your `background` / `general` / `auth` blocks are never touched (hf138)
- **The `<span>` in a `cmd[…]` label is a shell redirection.** Everything after
  `cmd[…]` goes to `/bin/sh -c` and its **stdout** becomes the text — markup must
  be *printed by* the command, not written beside it. Caught by executing every
  embedded command; dash said `Syntax error: redirection unexpected` (hf138)
- **Two `source =` lines drew every button twice.** hf135's message told you to
  append the line by hand; hf136 then only looked for its own `# >>>` marker,
  found none, and appended a second one. An **active** `source =` line now counts,
  marker or not. Reproduced and regression-tested (hf137)
- **`zen-hyprlock-doctor`** — a script that inventories your `hyprlock.conf`
  (every top-level widget, its position, its `onclick`) and can `--fix` or
  `--undo` the power-button migration. We don't own that file; this is how we
  look at it without asking you to paste it (hf137)
- **Power-button detection widened** to `poweroff|reboot|shutdown|halt`, not just
  `systemctl poweroff|reboot` (hf137)
- **The installer now MIGRATES your power buttons instead of refusing.** hf135
  detected them and backed away, so nothing changed on Paul's machine — the safe
  answer to the wrong question. A block-aware awk pass comments them out
  (prefixed, never deleted; one `sed` undoes it), then sources ours.
  `ZEN_HYPRLOCK_KEEP=1` restores the refusal (hf136)
- **hyprlock power buttons ship at last** — as `hypr-config/zen-hyprlock-power.conf`,
  pulled in by ONE `source =` line the installer appends to your `hyprlock.conf`.
  Your file is never rewritten. The installer refuses in three cases: no
  hyprlock.conf (won't create one), you already have power buttons (would draw a
  second pair), already sourced (idempotent). All four paths tested (hf135)
- **`&##xf011;`, not `&#xf011;`** — in hyprlang a bare `#` truncates the rest of
  the line; `##` is the escape. My first draft's Pango entity would have been cut
  off at the ampersand, silently. Caught by simulating hyprlang's own parser (hf135)
- **Light Paper theme** — the sage/beige/cream palette, all four source colours
  used verbatim as the surface ramp. Audited: fg 11.78:1 on cream, every accent
  ≥4.5:1 on bg0 *and* bg1, accents ≥45 apart. Seeded to `themes/custom/` and never
  overwritten once yours (hf135)

**Desktop icons**
- **The panel shook when dragged.** The move handler read `m.x` — local to a
  MouseArea living *inside* the panel it was moving. Move the panel, the mouse
  area moves, the same cursor reports a different `m.x`. Solving the fixed point
  gives `P = P0 + (C − C0)/2`: the panel tracked exactly **half** the cursor and
  stalled every other event. The resize grip had the identical loop. Now
  `drag.target` (what the clock/weather/sysmon widgets have used since v6.11e)
  and scene-frame coordinates (hf134)
- **Icons blinked back to the generic glyph twice a minute.** `refresh()` rebuilt
  `entries` from scratch every 30s with the provisional icon, then re-resolved
  asynchronously; and `_patchEntryIcon` swapped the whole array once *per*
  resolver, rebuilding every delegate. Resolved icons are cached by path and the
  patches are batched into one swap — the hf129 System Monitor bug, again (hf134)
- **Custom icons only worked in Single-widget mode.** `DesktopIconsWidget` has
  honoured `customIcons` since hf85; `DesktopIcon.qml` (free-form) never read it,
  so a right-click override silently did nothing there (hf134)
- **Desktop items manager** — Settings → Desktop lists every entry the scanner
  found, its resolved icon, and **where that icon came from** (custom / .desktop /
  icon theme / none). Choose… and Reset per row. The picker moved onto the
  singleton so the page can reach it (hf134)
- **Panel redesign** — the frosted card from Paul's mockup, with an *Open Folder*
  button. The dark slab is one toggle away: Settings → Desktop → Panel style (hf134)

**Control Center — dropdowns and pickers**
- **A dropdown that overflowed the panel dismissed it.** The Control Center, the
  Settings window and Quick Notes are full-screen layer surfaces with
  `mask: Region { item: … }` — only the panel takes pointer input. A QQC2 `Popup`
  lives in the window's *overlay*, so it drew outside the panel happily, but every
  click there fell through to the desktop and the panel closed. `ZenDropdown`
  measured its space against the **window** (3440×1440), not the mask: a trigger
  70px above the panel's bottom saw 282px of room and opened downward, hanging
  184px past the edge. It now clamps to the mask, flips, scrolls, and clamps
  horizontally too (hf133)
- **System Tray colour pickers didn't open.** They were never pickers — a bare
  `Rectangle` painted with the current value, no MouseArea, nothing to click.
  Every other colour row in the shell uses `ColorSwatch` → `ColorPickerState` →
  the one global overlay hf114 mounted. This page predates that plumbing (hf133)
- **Hot Corners used a bare QQC2 `ComboBox`** — the last one in the shell. Native
  arrow, square corners, no hover fade, no bounds-aware popup. Now `ZenDropdown`,
  which is a drop-in (hf133)

**Weather icons**
- **Coloured icons** — Material and Nerd glyphs are single outlines, so hf131
  painted a sun and a thunderstorm the same aqua. There are two fixed palettes
  now, picked by the surface's luminance. My first pass was one table with a
  comment claiming it worked on both; measured, **20 of 29 colours failed on a
  light bar** — snow scored a contrast ratio of 1.05, invisible. Audited: worst
  contrast 3.84 dark / 2.50 light, and 22/22 pairs a person must tell apart are
  separated. Fog and overcast stay close on purpose — they are both grey sky.
  Settings → Bar Modules → Weather → Icon colour (hf132)
- **Dashboard weather card, detailed** — feels-like / humidity / wind, an
  "Updated" stamp, a labelled hourly strip and the **7-day row**, mirroring the
  desktop widget. Sections appear as the card grows; thresholds are measured in
  an offscreen QQuickView, not guessed. Default height 190 → 300 (hf132)
- **The bar and dock were drawing Font Awesome.** `wmoIcon()` returned Weather
  Icons codepoints (U+F0xx) and `ZenWeather.qml` rendered them in
  "JetBrainsMono Nerd Font", where U+F0xx is Font Awesome. Overcast (U+F013) came
  out as `fa-cog` — a gear, beside "30° Overcast". Rain was `fa-download`, clear
  was an ✕, snow was `fa-magnet`. All 21 mapped codes were wrong; only the
  fallback looked right, and by accident (U+F0C2 really is `fa-cloud`). Nerd Fonts
  relocates Weather Icons into the PUA at U+E3xx. Retabled from
  ryanoasis/nerd-fonts `glyphnames.json`, and coverage went 21 → 28 codes (hf131)
- **One source of truth for weather glyphs** — `WeatherService` keeps the raw
  `weatherCode` now and exposes `materialIcon` / `nerdIcon` / `emojiIconLive`.
  ZenGlanceWidget's private Nerd→Material lookup is superseded. That is backlog
  item **[G3]**, done (hf131)
- **Windy** — WMO has no windy code, so it is derived: a quiet sky (clear, cloudy,
  fog) plus wind at or over `windyThresholdKmh` (default 25) reads as windy →
  `air` / wi-windy / 🌬️. Rain, snow and storms always win. Threshold in
  Settings → Bar Modules → Weather (hf131)
- **Weather icon style** — Material (default, matches the Glance blob) · Emoji
  (matches the dashboard + Quick Settings cards) · Nerd Font (now correct).
  Settings → Bar Modules → Weather → Icon style (hf131)

**Dock**
- **The power menu opened nowhere near the power button.** Two bugs. It anchored
  to the dock *window* and offset by `root.x`, which is local to the Loader the
  dock mounts modules through — always 0, never the ~1206 it needed. And it took
  its direction from `PanelState` (the **bar's** edge), so on a top-bar +
  bottom-dock layout it was told to open downward, ran off screen, and got
  flipped somewhere else. Now `anchor.item: root` with edges/gravity from the new
  `DockState.popupAnchorEdges` (hf131)

**Zen Control Center**
- **Sidebar geometry** — the nav pill, profile card and quick-action buttons
  overflowed the sidebar and got clipped, but *only* on the Dashboard page. The
  Edit pencil is `visible: currentPage === 0`, a layout skips invisible children,
  and a single-column `ColumnLayout` hands its widest child's minimum width to
  every `fillWidth` sibling. Header wrapped in a plain `Item` — the ZenSettings
  idiom. Reproduced and confirmed offscreen: 233px in a 204px box → 204px on all
  32 pages (hf129)
- **Collapsible nav categories** — 14 headers for 6 categories became 6. Dashboard
  stays top-level; APPEARANCE / INPUT & DISPLAY / CONNECTIVITY / SYSTEM /
  PRODUCTIVITY / OTHER are single-open accordions, collapsed by default. Reveal
  height is arithmetic, so a closed group's rows are never built (31 nav delegates
  on every open → typically 0). New `ZenDashNavRow.qml` (hf129)
- **System Monitor flicker** — the bars restarted from zero every second.
  `sysModel` was a binding over an array literal that read `SystemMonitorService`,
  so any tick rebuilt the array, the `Repeater` rebuilt all five delegates, and
  `Behavior on width` re-ran from 0. The model is constant now; readings are
  per-delegate bindings (hf129)
- **Hide dashboard sections** — an eye toggle in edit mode. Hidden cards stay
  visible (dimmed, labelled) while editing and drop out of the grid otherwise;
  slot, span and height are preserved so un-hiding restores them exactly.
  Persisted as `dashHidden` in `panel-state.json` (hf129)

**Screenshot**
- **Freeze frame** — the whole focused monitor is grabbed with `grim -l 0` *before*
  the overlay window exists, painted as the backdrop, and cropped at capture time.
  Open menus, popups and the Control Center are in the shot instead of dismissing
  when the overlay takes focus. Capture is instant (no unmap, no 300ms wait).
  HiDPI-correct: the crop scales by the image's own natural size and the annotation
  SVG rasterises at device pixels. Toggle in Settings → General → Strings (hf129)
- **Whole-monitor capture** — `Ctrl+A`, `F`, or the *Full screen* button on the new
  selecting-phase hint chip (hf129)
- **Rope origin follows the cursor** — the monitor is split into three vertical
  bands and the four ropes pin to the corners of the band the cursor is in. Glides
  between bands, ~2%-of-screen hysteresis, locks on press. `Rope origin: band |
  corners` in Settings. On a 3440 monitor with the cursor at x=2900 the longest
  rope goes from 2900px of stretch to 607px (hf130)
- **Fix — the rig was seeded against a window with no size.** A layer surface is
  configured a frame or two after it maps, so `resetState()` could run with
  `width == 0`; hf129's `cursorLocalX >= 0 && width > 0` guard then fell through to
  `Math.round(width/2)` = 0 and put every anchor back at the origin. This is why
  hf129 didn't fix "galing sa upper left". Reset defers until the surface is sized;
  the anchor glide is disarmed for the first 60ms so a 0→3440 width step can't
  animate the ropes in from the left edge (hf130)
- **Fix — `swingDir` was a garnish.** The physics tick hard-clamps the last four
  points onto the pull, so hf129's tip-weighted kick was discarded on frame 1.
  Simulated over 12 frames, `swingDir` −1 vs +1 differed by **3px**. The kick now
  scales across the free section only, and is documented as the settling flourish
  it is. The *anchors* do the work (hf130)

### ✅ DONE — earlier (v7 → hf128)

- **ZenSlider** — circle handles everywhere (37 sliders) + antialiasing; height fix (hf99, hf99b)
- **Color picker** — drag works + WYSIWYG accurate colors (hf99, hf99b)
- **Quick Settings — system stats** — GPU/VRAM aligned + dividers + labeled temp (hf99c)
- **Quick Settings — big weather + 7-day forecast** card (hf99d)
- **Quick Settings — horizontal** (weather ‖ system side-by-side) (hf99g)
- **Quick Settings — responsive** width + auto-stack on small screens (hf99h)
- **Quick Settings — calendar grid + big time/date** cards (hf99h)
- **Quick Settings — Notifications tab** (click to view; reuses NotificationService) (hf99i)
- **Attached mode** (Caelestia-style — hugs the bar edge, squared corner) (hf99j)
- **Classic Dots** workspace style — glyph-free, active pill + inactive circles (hf99k)
- **Desktop clock — design variants** — Outline / Solid / Raised / Mono / **Stacked (03/28)** / **Analog (Google Pixel)**, pickable in Settings → Desktop Widgets → Clock Design (hf99o, hf99r, hf99s)
- **Desktop clocks — up to 10** — add/remove timezone clocks (primary is permanent) (hf99p)
- **Independent draggable clocks** — toggle so each clock is its own widget with its own position (hf99y)
- **Weather widget** — Pixel-style squircle + **click to expand**: hourly forecast (temp / icon / precip% / hour) + 7-day; WeatherService now fetches hourly (hf99zd)
- **System Monitor design** — dropdown: **Classic** (tabs + graphs) or **Pills** (Pixel capsule cards), fully themeable (hf99zf–hf99zh)
- **Per-widget fonts** — clock / weather / system monitor each pick their own font family (hf99zh)
- **Per-widget accent colour** — weather and system monitor each pick Default/Theme/Custom accent (hf99zg, hf99zi)
- **Draggable Quick Settings sections** — reorder + persist, in a right-side **Layout** tab; QS cards mirror your desktop-widget look *and behaviour* (hf99zj–hf99zn)
- **Glass — Advanced Quick Settings** — frosted card treatment + optional profile card at the bottom (hf99zo)
- **Zen Control Center** — merged Quick Settings + Hyprland Control Center dashboard, bound to SUPER+C / SUPER+,; mirrors your widget designs, has QS modules, and is drag-reorderable via the Edit button (hf99zp–hf99zs)
- **Custom hex colours + Material Symbols icons** in Desktop Widgets settings; background opacity can now go to 0% (hf99zh)
- **CPU + GPU clock speed** readouts added to SystemMonitorService (hf99zf)
- **Per-widget scale** — global scale (linked) OR individual per-widget sliders (unlinked); the inactive set is greyed/disabled via the **Link all** toggle (hf99z–hf99zc)
- **Per-clock style** — each clock can pick its own design (Inherit / Outline / Solid / Raised / Mono / Stacked / Analog), incl. **analog per clock** in independent mode (hf99zb)
- **Shell Look selector** — `LookService` + Settings page (Classic/Zen/Glass/Minimal/Custom) with **live preview**; **all surfaces** follow the look — Control Panel, Bar, Dock, Start Menu, Notifications (radius + opacity), plus **Glass frost** via Hyprland layer blur (hf99l–hf99n)
- **Installer** — smart install + bundled bootstrap + layout-compat shim (hf99); doesn't block on slow AUR font builds (hf99e); sources zen-shell-look.conf for Glass frost (hf99n)
- **Fix** — hypridle display-wake after lock/idle (`on-resume`/`after_sleep_cmd` dpms on) (hf99f)
- **Fix** — Glance blob icons blinked on hover (child MouseAreas stealing `containsMouse` from the parent); hovering the widget now reveals all controls at once (hf116)
- **Glance widget** — merge weather + system monitor into ONE Pixel-style blob with a cloud/thermostat icon switcher; asymmetric elliptical corners that morph into a card on expand; auto-contrasting ink derived from the surface's own hue. Toggle in Settings → Desktop Widgets → Glance Widget (hf113)
- **Dock** — `weather` and `power` modules; the Control Center button opens the Control Center instead of a notify-send stub (hf126)
- **Fix** — the dashboard nav's selection pill ran flush to the sidebar border; its Flickable never set `contentWidth`, so the column sized itself from its children (hf128)
- **Fix** — the dashboard sidebar was inside the zoomable, scrollable content surface: it resized with the zoom and could run past the panel. Hoisted out and anchored to the window (hf126 clip, hf127 root cause)
- **Expansion lift** — expanding the weather widget or the Glance blob moves it clear of its neighbours and the screen edge, then returns it home on collapse. Saved positions are never touched (hf125)
- **Fix** — the Weather / System Monitor *Background* settings sections sat 400 lines above their own widgets' sections (hf125)
- **Fix** — dashboard clock faces were pinned to a fixed pixel size and got sliced by the card's clip; they scale with their cell now (hf124)
- **Fix** — the Control Center blinked on open: it painted, collapsed, vanished and faded back in (hf122)
- **Window placement** — Control Center and Settings open where you tell them: a visual 3×3 anchor grid (same idiom as Notification Position), a separate *Remember last position* switch that dims the grid when on, edge-margin stepper, and a notification-style slide-in from the anchored edge. **Settings → Panel → Window Placement** (hf113, hf117, hf123)
- **Fix** — Control Center / Settings opened at the upper-left corner: first from an `anchors.centerIn` that reverted to 0,0 (hf113), then from a slide-in animation latching a target computed against an unsized surface (hf119)
- **Fix** — music strings stuck on "Loading…". Two bugs: a `positionReady` deadlock (hf115) and, with **All Monitors**, two bars writing one global bar-local coordinate — which is why island worked and fullwidth/floating didn't (hf118)
- **Fix** — screenshot rope colour ignored the picker; `ZenScreenshotOverlay` hardcoded theme blue/purple over `ZenRope`'s default (hf118)
- **Fix** — the colour picker committed `#RRGGBBAA` while `ColorSwatch` and Qt read `#AARRGGBB`, rotating every applied colour by one byte. One hex convention now, alpha preserved for Hyprland borders, legacy values self-heal (hf120)
- **Fix** — colour swatches in the Zen Control Center opened no picker; the overlay was only ever mounted in the legacy Settings window (hf114)
- **Fix** — hf113 regression: a cross-singleton call inside `PanelState.applyState()` could silently drop every setting parsed after it (hf114)
- **Fix** — `install.sh` corrupted `panel-state.json` with a structure-blind `sed`, resetting the bar position, dashboard cards and bar layout on every install; and re-ran a one-time `strings-state.json` migration that reverted custom colours. Installer now repairs, snapshots and verifies every state file (hf121)

### 🔨 ON-GOING / NEXT

*(The widget-set redesign is complete — #W1–#W5 and #2–#6 all shipped.
These are the next candidates, roughly by value.)*

**Polish / correctness**
- **[N1] Media card needs `playerctl`** — detect it once and surface a one-line
  "install playerctl" hint in the card instead of hiding silently
- **[N2] Dashboard remembers its page** — `currentPage` and `maximized` still
  reset on close. (Position is done as of hf113: pick *Remember last position*.)
- **[N3] Search should also match settings *rows*, not just page names**
  (e.g. "gaps" → General → Gaps) — needs a per-page keyword index
- **[N8] `QuickNotesPanel` still uses the old `anchors.centerIn: … : undefined`
  pattern** (`shell.qml:3746`) — same upper-left trap hf113 fixed for the
  Control Center. Port it to `ZenWindowPlacement._place()`.
- **[N9] Confirm the strings root cause.** hf113 hardens three separate failure
  paths but the actual trigger was never observed in a log. If "Loading…" ever
  comes back, capture `qs -c zen-shell 2>&1 | grep -i strings` — the new
  `console.warn` lines say which guard fired.
- **[N10] Per-core CPU in `SystemMonitorService`** — the Glance detail view wants
  a 16-bar core strip; the service only exposes an aggregate `cpuPercent`, so it
  ships with RAM/VRAM meters instead.

**Dashboard**
- **[D1] Classic graphs in the dashboard's System Monitor card.** `sysmonStyle` is
  already `classic | pills`, and the desktop widget honours it — but `cmpSysmon` in
  `ZenDashboard.qml` draws its own thing regardless. Doing it properly means
  extracting `ZenSparkline.qml` and `ZenSysmonClassic.qml` out of `DesktopWidgets.qml`
  so both surfaces share one renderer. That file has bitten us three times this
  cycle; it deserves a release of its own.

**Glance follow-ups**
- **Desktop widgets remember if they were open (hf156).** Weather (both the standard
  card's expanded state and the pixel blob's view) and the merged Glance now persist
  open/closed across a restart — "kung open yan dapat open padin."
- **Weather has a Pixel-blob style (hf156).** A weather-only ZenGlanceWidget blob,
  selectable via a Style dropdown in the new Weather tab. Weather only — the system
  monitor still only joins it in the merged Glance. Theme flows through (accent +
  background modes drive the blob).
- **Widget settings are tabbed (hf156):** Home (widget display → colors, merge blob,
  positions) / Weather / Clock / Sys Monitor. Nothing removed — sections just group.
- **[G1] Glance in the Quick Settings dashboard** — `WidgetsState` already mirrors
  the glance keys; the dashboard card doesn't render them yet
- **[G2] Per-glance scale** — it currently rides the global `_scale`; the classic
  widgets each have their own slider
- ~~**[G3] `wmoMaterial(code)` in `WeatherService`**~~ — **DONE in hf131.** The
  service keeps `weatherCode`, `forecast[]`/`hourly[]` carry `code` and
  `material`, and `wmoMaterial()` exists. `ZenGlanceWidget._wxMap` survives only
  as a fallback for a stale cache.

**Features**
- **[N4] Calendar card on the dashboard** (the mockup's month grid; the panel
  already has month navigation to reuse)
- **[N5] Clocks card: "+ Add Clock"** inline, like the mockup, writing straight
  to widgets-state.json
- **[N6] Per-module resize** — let each dashboard card set its own height
  (you asked for this: "pwd din ma resize kada section module")
- **[N7] Custom Shell Look** — edit look tokens as JSON (the picker's 5th slot
  is still a placeholder)

**Backlog**
- Vertical-bar option
- Font/element scaling on smaller resolutions (beyond just width)
- Fold the remaining lock/resume scripts into the tarball (zen-sleep-hook,
  zen-lock.sh, zen-hypridle-sync.sh — needs your current copies)

### 🩺 FOUND WHILE FIXING hf129 / hf130 — verified, not yet touched

Each of these was checked against the tree, not guessed. None is fixed; none blocks
anything. Filed so they don't get rediscovered a fourth time.

- **[F1] `ropeSegments` and `ropeSegmentLength` are dead settings.**
  `ZenStringsState` declares them, persists them, loads them and resets them —
  and `ZenRope.qml` hardcodes `segments: 10` / `segment_length: 5` and never reads
  either. Changing them in `strings-state.json` does nothing. One-line fix
  (`property int segments: ZenStringsState.ropeSegments`), but it changes rope feel,
  so it wants its own build.

- **[F2] `install.sh` prints the wrong version banner.**
  Line 244 does
  `grep 'property string version:' ZenVersion.qml | sed -E 's/.*"([^"]+)".*/\1/'`,
  but since the v7 versioning reform `version` is *derived*:
  `readonly property string version: "v" + semver + "-" + prerelease`.
  The greedy `.*` grabs the last quoted group, so the installer announces
  `Zen Shell - — Karui (軽い)`. Cosmetic; the shell itself is unaffected. Should
  read `semver` + `hotfix` instead of the derived string.

- **[F3] Freeze covers the focused monitor only.**
  `grim -l 0 -o "$NAME"` grabs one output. That is deliberate — the overlay is one
  window on one output and can't select across monitors anyway — but a future
  "capture all monitors" mode would need `grim` with no `-o` plus global-coordinate
  cropping.

- **[F4] Cropping the freeze needs `magick` or `convert`.**
  `freezeCrop` is gated on `magickBin.length > 0`. Without ImageMagick the overlay
  silently falls back to hiding itself and re-grimming the live screen — correct,
  but you lose the whole point of the freeze. A `grim`-only crop path (or `ffmpeg`)
  would close the gap.

- **[F7] `CalendarButton` has the same local-coordinate anchoring.**
  It also does `anchor.window: QsWindow.window` with `anchor.rect.x` built from
  `root.x`. It looks correct only because it sits directly in the bar's row,
  where local x ≈ window x. Move it to `anchor.item` before anything reparents
  it. Not touched — it works today.

- **[F8] `ZenWeather`'s hover tip is a plain `Rectangle`, not a `PopupWindow`.**
  In the dock (a content-sized layer surface) it will be clipped by the dock's
  own bounds. The dock has mounted `ZenWeather` since hf126. Same class of bug
  DockPowerButton's comment warns about.

- **[F10] Nothing verifies that a settings page's `saveState()` call exists.**
  `DesktopPage.qml` called `DesktopIconsState.saveState()`. That function has
  never existed — the singleton debounces through `markDirty()`. QML resolves the
  call at runtime, so the row silently did nothing and no lint caught it. A grep
  for `State.saveState()` against each singleton's declared functions would.

- **[F11] `hyprlock.conf` and `scripts/zen-lock*.sh` are not in the tarball.**
  The installer provisions them (`for v6163f in hypridle.conf hyprlock.conf`) but
  `hypr-config/hyprlock.conf` is absent and `[ -f "$src" ] || continue` skips it.
  Same for the whole `scripts/` folder. Lock-screen work is therefore blind. This
  is the long-standing backlog item; it needs Paul's current copies.

- **[F9] `AppFloatRuleEditPopup.qml` still uses a bare `ComboBox`.**
  The last one after hf133 migrated Hot Corners. It lives inside another `Popup`,
  so nesting the bounds-aware ZenDropdown wants a look rather than a swap. Not
  touched.

- **[F5] [N6] looks already shipped.**
  "Per-module resize — let each dashboard card set its own height" is filed as
  pending, but `ZenDashboard.qml` has had three affordances since hf101/hf107:
  a horizontal grip that snaps to columns, a corner grip for width+height, and a
  bottom-right height grip. Verify and retire the item.

- **[F6] [N2] is filed imprecisely.**
  It says `currentPage` and `maximized` "reset on close". Nothing in `shell.qml`
  ever assigns `zenDashboardPanel.currentPage` — they survive close/open *within a
  session* and reset only when the shell restarts. What's actually missing is
  persistence to `panel-state.json`.

### 🧊 BACKLOG

- Vertical-bar option
- Font/element scaling on smaller resolutions (beyond just width)
- Fold the remaining lock/resume scripts into the tarball (zen-sleep-hook,
  zen-lock.sh, zen-hypridle-sync.sh — needs your current copies)

---

## v8.1.0-alpha-hf202 — 2026-08-21 · "install lahat, wag patungan"

Installer-only build. No QML changed, no module touched, no feature
removed. What changed is that the installer now actually installs the
whole tarball, and stops being able to reset your settings.

**The installer was laying down the v7 tree and calling it v8.**
- This is the big one, and it took a real end-to-end run to surface. The
  tarball ships BOTH `zen-shell/` (201 qml, v8.1.0) and the legacy
  `zen-shell-v5/` (179 qml, v7.0.0). The install body hardcoded
  `$SCRIPT_DIR/zen-shell-v5/` for the QML copy, the asset copy, the stale
  prune and the vertical-bar self-heal. The layout-compat shim was meant
  to redirect that name to the v8 tree, but it only links a legacy name
  when the legacy directory is ABSENT — and it is very much present.
- So every install copied 179 v7 modules over the top and finished with a
  banner claiming v8. **Twenty-one v8-only modules never landed**, among
  them `LookService.qml` (the entire Look/Glass system), `ZenDashboard.qml`
  and `UnifiedDashboard.qml` (the Control Center), `ZenGlanceWidget.qml`,
  `ZenWindowPlacement.qml`, `CursorPage`/`CursorService`, `PanasonicPage`/
  `PanasonicService`, `ShellLookPage`, `TaskbarPage`, `WavyAnalogClock`,
  `ZenDashNavRow`, `ZenSlider`, `TimezoneService`, `MprisService`,
  `IconThemeService`, `DashController`, `DashState`, `DockPowerButton`,
  `WidgetsState`.
- The evidence was on screen the whole time: the hf113 self-check has been
  printing `❌ hf113 files missing from install: ZenGlanceWidget.qml
  ZenWindowPlacement.qml` at the end of every install, and the finish line
  read `Enjoy Zen Shell v`. Both were symptoms of this.
- Every source-tree path now reads `$ZEN_SRC_SHELL`, resolved once at the
  top by preferring `zen-shell/` and falling back to `zen-shell-v5/` only
  when there is no v8 tree. `zen-shell-v5/` is untouched and still ships.

**`_sanitize_hl_conf` never ran.**
- Defined at line 3922, called at 3679, 3685, 3718 and 3722. Bash resolves
  a function name when the call executes, so all four calls died with
  `command not found` on every install and the Hyprland 0.54 / 0.55 syntax
  stripping silently never ran on `binds.conf`, `keybinds-update.conf` or
  the drop-ins. The five-function cluster is hoisted above first use,
  moved verbatim.

**Eight scripts were shipping and never landing.**
- `V7_SCRIPTS` copied from `$SCRIPT_DIR/scripts/`. On the v8 layout
  those files live in `zen-shell/scripts/`. The loop found nothing,
  printed nothing, and moved on — so `zen-boost-guard.sh` (the hf200
  compressor+limiter guard) and `zen-callwatch.sh` (the hf197 call-popup
  reaper) did not exist on disk after a fresh install, while
  `ConnectivityService.qml` and `zen-input.conf` called them by absolute
  path. The Boost Guard toggle did nothing and SUPER+SHIFT+C did
  nothing, on every clean box, since hf197.
- Same for `zen-wifi-selector.py`, `zen-wifi-doctor.sh`,
  `zen-wifi-watch.sh`, `zen-wheelpad.py`, `zen-panasonic-setup.sh`.
- `zen-fuzzel-glass.sh` was in the `[5/9]` whitelist but read from the
  same wrong directory, so it printed `⚠ missing` every install.
  `ThemeService.qml` runs it out of `~/.local/bin`, where it never was:
  Glass fuzzel theming has never applied from a tarball install.

**Three themes were shipping and never landing.**
- `themes/builtin/` holds `sakura.json`, `darkmatter.json` and
  `caelestia.json`. The layout-compat shim only bridges `themes-builtin/`
  when that legacy directory is ABSENT, and it is present, so the whole
  v8 theme directory was skipped. Sakura is a headline v8 theme that no
  installed shell has ever had.

**Also never landing:** the five Look presets in `zen-shell/looks/`
(no install step existed at all), and `openrgb-autoload.sh`, which
`autostart.conf` has been `exec-once`ing by absolute path for releases.
`hypr-config/zen-multimonitor.conf` is referenced nowhere in the whole
installer; it is seeded now, not auto-sourced, because monitor rules
are hardware specific.

**[5.5/9] PAYLOAD SWEEP — the reason none of that gets to happen again.**
- Every copy step above it worked off a hardcoded list of filenames,
  which is correct exactly until someone adds a file to the tarball and
  does not also edit install.sh. The sweep walks DIRECTORIES instead.
  New files land automatically on the next drop.

**[9/9] COVERAGE AUDIT.**
- Walks the tarball at the end and names anything shipped that has no
  counterpart on disk. Report only, never aborts. The point is to make
  the next gap loud instead of silent, the way these eleven were silent.

**Your \*.json is yours — deep merge, not restore.**
- Every state file is snapshotted before the migrations and merged back
  after, key by key: your value wins, and only genuinely NEW keys from
  the build get added. A straight restore would have protected your
  settings by throwing away new features (the `glance` seed in
  `widgets-state.json` is the standing example); a straight migration
  does the reverse. This does neither.
- `panel-state.json` + `bar-layout.json` keep the stricter hf153
  verbatim guard on top. Opt out with `ZEN_NO_MERGE=1`.

**Only what changed gets written.**
- Every file is byte-compared first. Identical file = untouched, no
  `.bak` spam, no churn. A second `./install.sh` back to back now writes
  literally nothing.

**CRLF guard.**
- All 48 files in `scripts/` ship with CRLF, 45 of them with a CRLF
  shebang, which on Linux means `bad interpreter: /usr/bin/env bash^M`.
  They are normalised to LF on the way in. Comparing on normalised bytes
  also stops the four scripts that exist in BOTH `scripts/` and
  `zen-shell/scripts/` from overwriting each other every run over
  nothing but line endings.

**Branding and version.**
- `ZEN_BRAND` / `ZEN_SITE` / `ZEN_MAJOR` are variables at the top now.
  The version is READ from `zen-shell/ZenVersion.qml` instead of being
  hardcoded, so the banner cannot drift again: the header still said
  `v7.0.0-beta.1-hf99` and the finish banner said `v7.0.0-beta.1-hf82y`
  while the QML said `v8.1.0-alpha-hf201`. Three versions, one file.
- The final line grepped `property string version:` and sed'd the first
  quoted literal out of it. That property is a derived expression
  (`"v" + semver + "-" + prerelease`), so it returned the bare `"v"` and
  the install finished with `Enjoy Zen Shell v`. Fixed.
- New `--version` / `-V` flag. Site printed on the finish banner:
  https://zenithshell.dev/

## v8.1.0-alpha-hf201 — 2026-08-09 · "100% means a full bar"

**OSD bar mapping fixed — the notification finally reads right.**
- The hf198 mapping (bar = fraction of the 300% ceiling) was
  mathematically honest and perceptually broken: at everyday 100% the
  bar sat one-third full and looked like a bug. New model:
  0–100% fills the bar 0→100 in the normal accent; past 100 the bar
  STAYS full while the fill walks the yellow→orange→red gradient and
  the label shows the true percent ("120%", "250%"). The bar is the
  safe meter, the COLOR is the boost meter.

**Volume keys are the safe range again — capped at 100%.**
- Per Paul's sync model: Fn+< / Fn+> (XF86 keys and the SUPER+SHIFT
  comma/period pair) go back to `wpctl -l 1.0` — "shortcut ko din sa
  volume and up till 100 siya." Boost (100–300, behind the hf200
  guard) is slider-only. Side effect by design: pressing volume-UP
  while boosted snaps you back to 100 — the keys always return you to
  the safe range.

**Installer now installs swh-plugins itself.**
- `sudo pacman -S swh-plugins --needed --noconfirm` runs during
  install when SC4 / the lookahead limiter .so files are missing, so
  the Boost Guard comes up at full quality on a fresh box instead of
  the clamp fallback. Non-fatal: a repo hiccup logs a manual command
  and the shell install continues.

## v8.1.0-alpha-hf200 — 2026-08-09 · "loud without the crunch"

**Boost Guard — compressor + limiter behind the 300% boost.**
- The problem with the raw hf197 boost: wpctl's 3.0x gain is PipeWire's
  LAST stage before the float→int conversion at the ALSA boundary.
  Nothing sits after it, so everything past 0 dBFS hard-clipped at the
  DAC — the harsh distortion at 173%+. Exactly the ask:
  "Volume: 0-100% · Amplification: 100-300% · Compression: ~80% ·
  Limiter: ON."
- Fix: `zen-boost-guard.sh` runs a PipeWire filter-chain GUARD SINK
  ("Zen Boost 保護") and makes it the default:
  apps → guard (your 0-300% volume lands here, PRE-chain) →
  SC4 compressor (~80% intensity: threshold -17.2 dB, ratio 6.6:1,
  knee 6 dB, +4.8 dB makeup — the makeup is why 300% actually sounds
  LOUDER now instead of just clipping harder) →
  fast lookahead limiter (brick wall at -1 dBFS, 150 ms release) →
  real device sink, pinned at 100%.
- The shell's whole volume plumbing (hf197-hf199) is UNTOUCHED — the
  default sink is simply the guard now, and the sink volume on a
  filter-chain applies on the adapter input, i.e. before the chain.
- Quality ladder: SC4 + lookahead limiter come from **swh-plugins**
  (`sudo pacman -S swh-plugins`). Without it the guard falls back to a
  builtin hard clamp at ±1 — same loudness, more edge, and the
  Connectivity page says so out loud.
- Device dropdown while guarded: the default STAYS the guard; picking a
  device re-TARGETS the guard's output (`set-target`, <1 s relaunch,
  streams stay parked and resume). The guard sink itself is hidden from
  the picker — it's not a device. Bar tooltip shows
  "<device> · boost-guarded".
- Lifecycle: autostarts with the shell (4 s delay so PipeWire is up),
  Connectivity → "Boost Guard" toggle turns it off/on (off = raw boost,
  clipping and all — documented on the toggle). Disabled state persists
  via a flag file. Tunables: ZEN_BOOST_INTENSITY (0-1, default 0.80),
  ZEN_BOOST_LIMIT_DB (default -1.0). Logs: ~/.cache/zen-shell/boost-guard.log.
- Wala tayong babawasan: stop returns the exact pre-hf200 path.

## v8.1.0-alpha-hf199 — 2026-08-09 · "the row that stacked its buttons"

**Desktop Icons page: the right side is readable again.**
- HMRow's control slot was a plain `Item` — and an Item STACKS children at
  (0,0). Every page that put ONE control there never noticed; DesktopPage
  puts THREE (icon preview + Choose + Reset), so they rendered
  superimposed as one garbled pill. The slot is now a `RowLayout`
  (spacing 8): multiple controls sit side by side, and it honors the
  `Layout.preferredWidth` / `fillWidth` props existing single-control
  pages already use — those are pixel-identical.
- Related latent bug in ZenButton: a plain Item's width does NOT default
  to implicitWidth (only Layouts read it), so inside the old positioner
  slot the button had ZERO geometry — the centered label still painted
  (no clip), the pill and the click area did not. `width/height` now bind
  to implicit; explicit sizes and Layouts still override.

**Wallpaper picker: whole folder in one grid.**
- New "Show all wallpapers" toggle (default ON) renders the entire
  (search-filtered) folder in one scrolling grid — thumbnails stay
  asynchronous and sourceSize-capped so a big folder streams in.
  Toggle OFF restores the classic 16-per-page Prev/Next view; the
  pagination code is intact (wala tayong babawasan), the buttons just
  hide while Show-all is on. Persisted in wallpaper-v5.json.
- For the record: the slideshow was NEVER limited by pagination —
  `randomWallpaper()` has always drawn from the full folder list. The
  picker just didn't show that.

**Wallpaper display modes — Fill / Fit / Center / Stretch.**
- New "Display Mode" dropdown next to Transition Effect. Fill = cover +
  crop (old behavior, default), Fit = letterbox (whole image, black
  bars), Center = 1:1 pixels, Stretch = fill both axes ignoring aspect.
- Mapping: fill/fit/center ride swww's `--resize crop|fit|no` (with
  black fill); swww has no native stretch, so Stretch pre-resizes the
  image to the primary monitor's size via ImageMagick (already a shell
  dependency for luminance detection) into ~/.cache/zen-shell and
  applies that. No magick / no monitor size → logged fall back to Fill.
- Old swww builds without `--resize` are detected via `--help` and the
  args are dropped, so a version gap can't hard-fail the apply.
- Changing the mode re-applies the current wallpaper immediately.

## v8.1.0-alpha-hf198 — 2026-08-09 · "the OSD learns to count past 100"

**OSD volume computation follows the boost.** (the hf197 gap)
- `showVolumeOSD` still clamped at 1.0, so any boosted volume rendered a
  FULL bar reading "100%" — "notification sounds computation natin till
  100 percent pero till 300 percent na tlga yan." The clamp is now the
  shell ceiling (`maxVolume/100` = 3.0).
- OSDPopup now separates the two numbers that were fused: the BAR maps
  value against the 300% ceiling (250% ≈ 83% full), the LABEL shows the
  TRUE percent ("250%"). Bar fill and label pick up the boost warning
  color past 100. Label column widened 40→44px for three digits + %.
- External `notify-send`-style volume notifications that report >100 now
  flow through un-mangled too (same D-Bus parse path, new ceiling).

**Boost warning is now a yellow → orange → red gradient.**
- "kapag malakas na warning siya yellow na yun color, orange till red" —
  `volumeColor()` no longer steps orange@101/red@201; past 100 it blends
  ThemeService.yellow → orange (~200) → red (300), so the hue itself says
  how far past safe you are. One function, every surface shifts together:
  all seven sliders, the bar module tint, and the OSD.

**Portrait monitors: the middle column stops hiding.**
- Real cause: `minContentWidth`'s main term was 420, but a SettingRow
  (label + description + value control) needs ~620 — QML Layouts don't
  clip, so on a rotated monitor the overflowing controls painted UNDER
  the right rail and looked amputated, while the fit math insisted
  everything fit. Main term is now 620 (and the main column's
  Layout.minimumWidth matches).
- **Automatic horizontal scroll below the readability floor.** Auto-shrink
  now stops at fitScale 0.85 — past that, content holds its minimum
  width, overflows the viewport, and dashFlick's AlwaysOn-when-overflow
  horizontal scrollbar (hf127) switches on by itself. Mildly tight →
  gentle shrink (a 1080-wide portrait lands at ~0.88, everything
  visible); genuinely tight → pan sideways, nothing hidden. Manual zoom
  below 0.85 still allowed — the floor binds only the automatic fit.

## v8.1.0-alpha-hf197 — 2026-08-09 · "boost, devices, and the popup that ate your prompts"

**v8.1 line opens.** Same Karui major, same alpha channel — semver minor bump
because hf197 changes behaviour across seven audio surfaces at once.

**Volume boost to 300% (with warning colors).**
- The sink volume is no longer clamped at 100%. Every volume surface — Quick
  Settings, bar sound popup, Control Center quick-audio row, the right-rail
  audio tab, Settings → Connectivity, the unified dashboard — now maps
  0..300%. PipeWire's software gain handles >1.0 natively (same mechanism as
  pavucontrol's boost).
- One color rule, one place: `ConnectivityService.volumeColor()` — ≤100 the
  usual accent, 101–200 **orange** (boost — soft clipping possible), 201–300
  **red** (distortion + speaker strain). Fill AND % readout follow it; the bar
  module's icon tints too, so a boosted volume is visible at a glance.
- Every boost track carries a tick at the 100% mark (ZenSlider grew a
  `tickAt` knob; the hand-rolled tracks draw their own) so the safe/boost
  boundary is always visible.
- The poll parser's `Math.min(100, …)` clamp is gone — an externally boosted
  volume (pavucontrol) round-trips instead of snapping the UI back to 100.
- `zen-input.conf`: RaiseVolume keys were `wpctl -l 1.0` — press volume-UP at
  250% and wpctl "raises" you DOWN to the limit. Now `-l 3.0`, matching the
  shell ceiling.

**Output-device dropdown — click the soundbar, pick earphones.**
- `ConnectivityService.audioSinks` — live device list parsed from
  `wpctl status` (Sinks block) on the existing poll, zero extra processes.
  `setDefaultSink(id)` wraps `wpctl set-default`; PipeWire moves ACTIVE
  streams with the default, so music mid-play jumps devices instantly.
- Pickers everywhere the volume lives: sink name in the Quick Settings audio
  row is now a dropdown trigger (chevron when >1 device); the bar sound
  popup's speaker label unfolds the same list (popup height grows to fit);
  the Control Center right-rail audio tab got rows; Settings → Connectivity
  got a proper ComboBox next to the pavucontrol button (which stays — escape
  hatch, wala tayong babawasan).
- Radio-dot marks the default; optimistic UI flips the dot before the next
  poll confirms.

**zen-callwatch v2 — the popup reaper stopped eating your prompts.**
- The hf196 daemon (shipped out-of-band, see below) closed call windows on
  ANY title transition. Clicking **End Call** transitions the title → the
  post-call prompt got closewindow'd before you could touch it. Opening
  video settings mid-call retitles some clients → the CALL got closed.
- v2 closes a window only when ALL hold: class matches a call app
  (Zoom/Teams/Lark/Workvivo), title matched an ENDED pattern (not merely
  "changed"), a 25s grace fully elapsed, and the window was never focused
  during the grace — **focus disarms**, because focus means you're clicking
  that prompt. Still `hyprctl dispatch closewindow`, still reaches frozen
  render processes via the main process (the hf196 insight that was right).
- SUPER+SHIFT+C stays: manual instant close of unfocused floating call
  popups. Tunables via env: ZEN_CALLWATCH_GRACE / _CLASSES / _ENDED.
- Ships in scripts/, registered in the installer, autostarted via exec-once.

**RAM cleanup — "make it sure gumagana."**
- The auto-trigger was calling pkexec from a background timer: either a GUI
  auth prompt materialised out of nowhere, or (no polkit agent) it died
  silently with an error nothing surfaced. You could not tell if it worked.
- Escalation ladder now: `sudo -n true` probe first — passwordless sudo →
  silent, timer-safe cleanup. Manual runs without it fall back to pkexec
  (interactive prompt is fine when YOU clicked). Auto runs without it never
  prompt: zombie pass still runs, then a notification tells you to run
  Free RAM manually (or add a NOPASSWD rule for silent auto-clean).
- Every completion now posts a notification: "Freed 1.8 GB · 2 zombies
  reaped", or exactly why it couldn't (auth dismissed / no agent / write
  failed). Negative freed deltas clamp to 0.

**Control Center fixes.**
- Footer dark/light toggle is STATEFUL again: glyph flips moon/sun with
  `DarkModeService.isDark` and the tile gets the same accent highlight the
  Quick Settings tile has. The old delegate drew the static model glyph and
  only *called* toggle() — state changed underneath, button never did.
- Sidebar nav grew a visible scrollbar (AlwaysOn when overflowing, same
  policy dashFlick has had since hf127). The nav has scrolled since hf126,
  but on a short screen with no indicator the below-the-fold modules looked
  like they didn't exist ("hindi makikita pre").

## v8.0.0-alpha-hf196 — 2026-08 · out-of-band (not in the hf195 tarball)

Shipped directly on the dev box between tarball snapshots: zen-callwatch v1
(closes stuck Lark/Workvivo/Teams call popups on title transition, reads
socket2, SUPER+SHIFT+C manual dismiss). Its title-transition trigger proved
too aggressive — superseded by the v2 rewrite in hf197 above. Recorded here
so the build-tag lineage stays continuous.

## v8.0.0-alpha-hf195 - the GTK Wi-Fi selector is now part of the shell

"if ever click yun ethernet port sa qml bar dapat mag open up din yun python wifi natin na UI,
same goes dito sa wifi dashboard natin."

Paul's own GTK4/libadwaita selector ships in `zen-shell/scripts/zen-wifi-selector.py` and installs
with everything else, instead of living loose in his home directory.

### Where it opens from

  * **bar network icon, left-click** — was the Control Center, now the selector. That is what the
    icon is for nine times in ten. The Control Center did not go anywhere: it is one right-click
    away and still on SUPER+C.
  * **Network Pulse module, middle-click** — left still toggles the throughput graph, right still
    opens its settings. That module is about bandwidth, so the selector is its third action, not
    its first.
  * **dashboard Wi-Fi rail** — a button beside Scan. The rail is deliberately a summary: pick a
    network, see state, done. Hidden SSIDs, editing a profile, retyping a password all belong in a
    real window.

### Not wrapped in the usual toggle

The Bluetooth and audio launchers from hf192 use a pgrep/pkill toggle. This one does not, on
purpose: the script **already guards itself** with a PID lockfile — a second invocation SIGTERMs
the first and exits. Wrapping it would put two mechanisms in a race over one window, and the loser
leaves a stale `/tmp/wifi_selector.pid` behind that blocks the next launch. It manages itself; the
shell just runs it.

Falls back to `nm-connection-editor`, then `nmtui` in a terminal, so the button still does
something useful on a box without GTK4/libadwaita rather than failing silently.

### SysRowIcon learned right-click

New `rightClicked` signal, gated on an explicit `rightClickEnabled` flag. The tempting version of
that gate does not work and is worth recording: `rightClicked.length > 0` reads the number of
DECLARED ARGUMENTS on a QML signal — zero here — not the number of connections. The test is always
false, the right button is never accepted, and the second action silently does nothing. A boolean
cannot lie about itself.

Default false, so every other SysRowIcon in the bar behaves exactly as before.

### Files
zen-shell/scripts/zen-wifi-selector.py (new) , zen-shell/ConnectivityService.qml
(openWifiSelector + fallbacks) , zen-shell/SysRowIcon.qml (optional right-click) ,
zen-shell/SysRow.qml (network icon) , zen-shell/NetworkPulseModule.qml (middle-click) ,
zen-shell/ZenDashboard.qml (rail button) , install.sh , ZenVersion.qml (hf195).
Needs python-gobject, gtk4, libadwaita.
Nuclear-clear the qmlcache: rm -rf ~/.cache/quickshell.

---

## v8.0.0-alpha-hf194 - zen-input.conf installs itself, and one of its binds was stealing yours

"palagay na mismo sa hyprland.conf, kasama sa patch yan, dapat independent."

Right — a config file that only works if you remember to add a line by hand is not part of the
patch, it is homework.

`zen-input.conf` is now registered with the same `_zen_dropin` machinery that already handles
`zen-shell-look.conf` and `zen-shell-dashboard.conf`: install.sh copies the file to
`~/.config/hypr/` and appends the `source =` line only if it is not already present. Re-running
the installer repairs a missing file or a missing line rather than duplicating either. Verified
idempotent — two consecutive runs leave exactly one source line.

It is registered **last** of the three deliberately. `_zen_dropin` appends, so the file sourced
last wins any bind collision, and the media keysyms are the ones that must not be overridden by
anything above them.

### Which is exactly how a bind of mine was stealing one of yours

That "sourced last wins" property cuts both ways, and hf192 had already walked into it.
`zen-input.conf` bound **SUPER + comma** to volume-down. `zen-shell-dashboard.conf` has bound
SUPER + comma to `toggleDashboard` since it shipped. Sourced last, mine would have silently taken
it — the kind of regression you notice a week later and cannot place.

Caught by diffing every `bind` line across all shipped confs rather than trusting that the new
file was self-contained. Three problems in one pass:

  * **SUPER + comma** → moved to **SUPER + SHIFT + comma/period**, which on a US layout *is*
    SUPER + `<` and SUPER + `>`: the same two glyphs the old Fn layer produced, so the muscle
    memory transfers, and nothing existing is touched. `less`/`greater` bound alongside
    `comma`/`period` because layouts disagree on which the shifted key reports.
  * **SUPER + C** → removed. `zen-shell-dashboard.conf` already owns it; keeping a copy here
    would mean two files to edit the day it changes.
  * **SUPER + M** (mute) → shipped **commented out**. It is a common user bind — monitors, music,
    mute, everyone picks something — and sourced-last would have overridden whatever you had
    without a word. `XF86AudioMute` already covers mute on any keyboard that has the key.

Final inventory across every shipped conf: seventeen binds, zero duplicates.

The file's header no longer tells you to add a source line, because you no longer do.

### Files
install.sh (registers the drop-in) , hypr-config/zen-input.conf (collisions resolved, header
rewritten) , ZenVersion.qml (hf194).
Run install.sh, then `hyprctl reload`.

---

## v8.0.0-alpha-hf193 - the centre zone was never centred, it was averaging

"kapag may add ako sa left, lalo na window kapag mahahaba words, yun center ko dynamically
umuusog-usog. Dapat as is sila sa pwesto if left center right."

Correct, and the arithmetic says why.

### Spacer centring is not centring

The bar was one RowLayout of five items:

    leftRow │ leftSpacer(fill) │ centerRow │ rightSpacer(fill) │ rightRow

Two fillWidth spacers split the leftover space EQUALLY, which sounds like centring. Work it out:

    spacer     = (W - left - centre - right) / 2
    centre.mid = left + spacer + centre/2
               = W/2 + (left - right)/2

**The centre sits half the left-minus-right difference from true centre.** Add an icon on the
left and it slides right by half that icon. A long window title pushes it further. It is only
genuinely centred when the two side zones happen to be exactly equal, which is never.

On a 1920 bar with a 200px centre module: left 100 / right 400 puts it **150px left** of centre;
left 900 / right 400 puts it **250px right**; left 1200 / right 300 is **450px off**. Only the
400/400 row lands correctly, and that is coincidence, not design.

This cannot be fixed by tuning the spacers — it is the wrong mechanism. Anchors are the right
one: each zone positions against the BAR, not against its neighbours, so none of the three can
move any other. Left is left, right is right, centre is centre, whatever is in them. Verified at
exactly 0 drift across every case above.

### What anchoring gives up, and how that is handled

A flow layout cannot overlap; anchored items can. So the centre gets an explicit budget:

    centerMaxWidth = 2 × min(W/2 − left − gap, W/2 − right − gap)

Symmetric by construction — whichever side is wider decides — and the centre lives in a clipping
slot sized to it. When the sides grow, the centre **narrows evenly from both edges while holding
the true middle**, instead of sliding away. At the extreme it reaches zero width and hides rather
than colliding.

### The vertical bar had the identical bug, rotated

Two fillHeight spacers between top/centre/bottom, so the centre drifted by (top − bottom)/2 the
moment either end changed. Fixed the same way. Doing only the horizontal bar would have left it
alive for anyone who moves their bar to the side.

That conversion nearly cost something silently: `rootColV` was a ColumnLayout, which derives
implicitHeight from its children for free, and `vFitScale` — the auto-shrink that keeps a full
vertical bar on screen — is bound directly to it. A plain Item reports 0, the condition
`implicitHeight > height` could then never be true, and the scale would have pinned to 1.0 with a
full bar overflowing off-screen and no error anywhere. implicitHeight and implicitWidth are now
computed by hand from the three zones. Auto-fit re-verified at 1.0 / 1.0 / 0.833 / 0.5 across
fits-comfortably, exactly-fits, overflows-20%, overflows-a-lot.

Checked before touching anything: nothing outside these files reads the spacers, the
`forceLayout()` calls are all `typeof`-guarded so they skip harmlessly now that the parent is an
Item, and `contentImplicitWidth` / `contentImplicitHeight` read only the zones' implicit sizes,
which are unchanged.

### Files
zen-shell/Bar.qml (anchor centring, centre budget, clipping slot) ,
zen-shell/BarVertical.qml (same, plus hand-computed implicit size) , ZenVersion.qml (hf193).
Nuclear-clear the qmlcache: rm -rf ~/.cache/quickshell.

---

## v8.0.0-alpha-hf192 - keyboard-independent media keys, cheatsheet follows the theme, OSD clears the dock

Five things, from the batch after the wifi saga.

### The volume keys moved when the keyboard did

A bind written as `bind = , code:60, ...` names a PHYSICAL POSITION on the matrix. Change
keyboards and position 60 is a different key, so the shortcut silently lands somewhere else. That
is the whole failure — nothing was broken, the bind was just describing the wrong thing.

A bind written against a KEYSYM names the MEANING. `XF86AudioRaiseVolume` is emitted by any
keyboard that has a volume key, dedicated or Fn-layer or media strip, so the same line survives
the move to the EG75 untouched.

New `hypr-config/zen-input.conf` binds the full XF86Audio/MonBrightness set with `bindle`
(repeat-on-hold, works while locked). The old Fn + `<` / `>` pair is rebound as **SUPER + comma /
period** — Fn layers are firmware, often never reaching the compositor at all, so they cannot be
bound portably; SUPER is a real modifier on keys every board has in the same place. `less` and
`greater` are bound alongside `comma` and `period` because layouts disagree on which the bare key
reports.

### The cheatsheet ignored the theme

Every colour in `KeybindCheatsheet.qml` was a `Qt.rgba()` literal — a fixed dark card with fixed
white text. It never picked up Glass, and on a light theme it was a black slab. Thirteen colour
rules now route through ThemeService/LookService; the card uses the same `surfaceColor()` as every
other panel, which is what actually applies the Glass treatment, and text uses
textColor/textDimColor/textFaintColor so the clear-look outlines apply here too. Zero `Qt.rgba`
literals remain. The category accent colours are deliberately left as-is — they are semantic, not
surface.

### The OSD drew over the dock

The volume popup's margin knew about the bar and nothing else, so with a bottom dock it landed
across the app icons.

`DockState` now exposes `edgeFootprint` — `height * min(iconSizeScale, 1.6) + marginEdge`, the
actual screen edge the dock owns — plus `topFootprint` / `bottomFootprint` which are zero when the
dock is off or on the far edge, so callers can add them unconditionally. The OSD margin is now
"clear whichever of the bar and the dock is on this edge, and if both, the taller one".

Stated once, holds for every layout: bar bottom, bar top with dock bottom, dock with 1.6x icons,
dock on top, nothing at the bottom. All six verified.

### Bluetooth and audio got their escape hatches

The Bluetooth rail said "0 device(s)", which is accurate and useless. It now reads the connected
device's name when there is one, "N connected" for several, "N paired · none connected" when
paired but idle, and turns blue when something is actually connected.

Both rails gained buttons: **Manage** on Bluetooth, **Mixer** and **EasyEffects** on audio. They
reproduce the toggle behaviour from Paul's own bluetoothrun.sh / audiotop.sh — already running
means close it, not spawn a second copy — and each tries a list of candidates in turn
(blueman-manager → overskride → gnome-bluetooth-panel → blueberry) so the button works without
being configured. `pkill -x` not `-f`: `-f` matches the whole command line and would kill the
shell command issuing it, which is the classic way a toggle script takes itself out.

### EasyEffects at login

`exec-once = easyeffects --gapplication-service` in the same config — starts hidden with the DSP
chain live. `exec-once` rather than `exec` because `exec` re-runs on every `hyprctl reload`, which
is how you end up with four of them. The systemd alternative is documented alongside, with a note
not to use both.

### Also

The IPC name in the config was checked rather than assumed — it is `toggleKeybindCheatsheet`, not
`toggleCheatsheet`, and the config would have shipped a dead Super+/ bind otherwise. Both IPC
targets verified present in shell.qml.

### Files
hypr-config/zen-input.conf (new) , zen-shell/DockState.qml (edge footprint) ,
zen-shell/shell.qml (OSD margins) , zen-shell/KeybindCheatsheet.qml (theme-aware) ,
zen-shell/ConnectivityService.qml (manager toggles) , zen-shell/ZenDashboard.qml (BT status +
Manage, audio Mixer/EasyEffects) , ZenVersion.qml (hf192).
Nuclear-clear the qmlcache: rm -rf ~/.cache/quickshell.

---

## v8.0.0-alpha-hf191 - the UI could not fix a wrong password, because it never wrote one

"sa terminal naman gumagana, dito lang sa UI natin ang may problema."

Exactly right, and it was never the escaping. Sixteen special-character passwords were pushed
through the identical code path — dollar, bang, backtick, double quote, single quote, backslash,
spaces, semicolon, pipe, glob, and one containing every ASCII symbol at once — and all sixteen
reach nmcli byte-for-byte intact. `password.replace(/'/g, "'\\''")` is correct.

### The actual fault

NetworkManager keeps a failed attempt. A connection tried with the wrong password **stays saved
in the profile, with those wrong credentials**. From that point the two paths diverge:

    terminal   `nmcli connection delete` first → no profile → a new one is created
               with the password just typed → works
    the UI     never deletes. The probe sees a profile with psk-flags 0, answers
               SAVED, and runs `nmcli connection up` — with the STALE WRONG KEY.
               The user is never even asked for a password.

And the path that does ask was no better: `nmcli device wifi connect <ssid> password <pw>` reuses
an existing profile for that SSID, so the typed password went nowhere.

**The UI could not fix a bad password no matter how many times the right one was typed, because
it never wrote it anywhere.** That is the whole bug, and it explains every "bumibitaw" since the
key first went bad.

### Fixed

`_pwConnectCmd()` writes the key straight into the profile:

    nmcli connection modify '<ssid>' 802-11-wireless-security.key-mgmt wpa-psk \
                            802-11-wireless-security.psk '<pw>' \
                            802-11-wireless-security.psk-flags 0
    nmcli connection up '<ssid>'

`key-mgmt` is set alongside the psk because a profile half-built by an earlier failure can be
missing it, and nmcli then refuses with "802-11-wireless-security.key-mgmt: property is missing".
With no profile it falls back to creating one and pins psk-flags after. Used by both the
new-network callback and the NOSECRET repair.

### And a known-bad key no longer counts as saved

hf190 detects `WRONG_KEY` from the supplicant; hf191 acts on it. If the last handshake for this
SSID was rejected, the probe's SAVED answer is overridden to NOSECRET, so Connect **prompts for
the password** instead of silently reusing a key already watched failing. Without this the user
can click Connect forever and never be asked.

Verified against a password containing `$`, `!`, backtick, `\`, spaces and a single quote: in
both branches the psk argument nmcli receives is byte-identical to what was typed, the existing
profile is modified rather than reused, and `device wifi connect` is not used when a profile
already exists.

Also fixed: `const result` in the probe callback is now `let` — hf191 reassigns it, and assigning
to a const throws at runtime, which would have taken the entire connect path down.

### Files
zen-shell/ConnectivityService.qml (_pwConnectCmd, forcePrompt override, wrongKeySsid, const→let) ,
ZenVersion.qml (hf191).
Nuclear-clear the qmlcache: rm -rf ~/.cache/quickshell.

---

## v8.0.0-alpha-hf190 - the watcher caught it: the stored key is simply wrong

zen-wifi-watch recorded the whole failure live, and it settles the question.

    802-11-wireless-security.psk-flags   0
    Activation: connection 'KiyuFamilyFibr' has security, and secrets exist.
                No new secrets needed.
    Config: added 'psk' value '<hidden>'
    SME: Trying to authenticate with 50:0f:f5:d4:c9:71 (freq=2437 MHz)
    Associated with 50:0f:f5:d4:c9:71
    ✓ 05:56:02  connected  -31 dBm
    05:56:06  WPA: 4-Way Handshake failed - pre-shared key may be incorrect
    05:56:06  CTRL-EVENT-SSID-TEMP-DISABLED auth_failures=1 reason=WRONG_KEY

psk-flags is 0. The key is stored. NM says so, and hands it to the supplicant. It associates at
-31 dBm — the router is across the room. Then the four-way handshake is rejected: **WRONG_KEY**.

### The chain I had backwards

`no secrets: No agents were available` is a **consequence**, not a cause:

    1. four-way handshake fails, because the key is wrong
    2. NM concludes the psk must be bad and asks for a replacement
    3. no secret agent exists → "no-secrets" → activation failed

hf183 read step 3 as the origin and shipped an agent-owned-PSK theory around it. That theory was
coherent, it explained the log, and it was wrong — the profile was recreated, psk-flags became 0,
and the same thing kept happening because nothing had touched the actual fault.

### "Secrets were required" means two different things

nmcli emits the same message for both, and the difference is everything:

    A  no key is stored              → supply one
    B  a key IS stored and is WRONG  → handshake fails, NM asks for a replacement,
                                        finds no agent, reports "secrets required"

Case B is indistinguishable from case A in nmcli's output alone. That ambiguity cost this project
most of a night. Only the supplicant knows which it was, and it says so plainly.

So on a secrets-shaped failure, `wrongKeyProbe` now greps the last 60 seconds of wpa_supplicant
and NetworkManager for `WRONG_KEY`, `4-Way Handshake failed` or `pre-shared key may be incorrect`.
On a hit it sets `wrongKey` and replaces nmcli's wording with **"Wrong password for X — the
network rejected the saved key"**. It runs only after an activation has already failed, never on
the 3s poll. When the supplicant is quiet it stays conservative and keeps the prompt-for-a-key
path, since that is the safe reading.

Classifier verified against four shapes: a stored-but-rejected key, a genuinely absent key, an
out-of-range AP, and a secrets error with no supplicant corroboration.

### For the record, what was never the cause

The LAN cable. The driver — PCIe iwlwifi, in-tree. USB autosuspend — not a USB adapter. Signal —
-31 dBm. Band steering. The scan-cache dedupe. Power saving is still on and still worth turning
off, but it was never this: the handshake fails four seconds after association, long before power
management is relevant.

### Files
zen-shell/ConnectivityService.qml (wrongKey, wrongKeyProbe, status precedence) ,
ZenVersion.qml (hf190).
Nuclear-clear the qmlcache: rm -rf ~/.cache/quickshell.

---

## v8.0.0-alpha-hf189 - a bug of mine in the detection, and a watcher instead of another theory

Still dropping. Two things in this build, and only one of them is a fix.

### My probe needed a permission it does not have

hf183's saved-network probe read the key back and required it to be non-empty:

    K=$(nmcli -s -t -f 802-11-wireless-security.psk connection show '<SSID>')
    case "$F" in ''|0) [ -n "$K" ] && echo SAVED || echo NOSECRET ;; *) echo NOSECRET ;; esac

`nmcli -s` / `--show-secrets` needs **polkit authorization** to read a SYSTEM connection's
secrets. Without an interactive agent nmcli returns the field EMPTY rather than failing — so a
perfectly healthy, system-owned, working profile could be read as having no key and classified
NOSECRET. A false alarm that prompts for a password already stored and already working.

Reading the key was never necessary. `psk-flags` answers the question on its own and needs no
authorization at all:

    0 / unset   NM stores the key itself — nothing more is needed
    1           agent-owned — NM stores nothing, needs an agent
    2           not-saved — must be supplied every activation
    4           not-required

The probe decides on flags alone now. Retested across eight flag/key-mgmt shapes.

### And I am going to stop guessing

Every diagnosis in this thread has been a **reconstruction**: the link goes down, and some time
later we read a journal and work backwards. That has already been wrong once — I told Paul his
wifi was never dropping when it was — and the reason is structural. **The reason a reconnect
fails is not the reason the link dropped**, and both end up in the same scrollback where they are
easy to confuse. "Warning: password not given" is a reconnect failure. It says nothing about what
knocked the link over in the first place.

`zen-shell/scripts/zen-wifi-watch.sh` watches live instead. One command, no flags:

    ./zen-wifi-watch.sh

It snapshots the profile first (key-mgmt, psk-flags, proto, pairwise, autoconnect,
autoconnect-retries, powersave, bssid pin, cloned-mac, route-metric, driver, regdom, power
profile), then follows NetworkManager and wpa_supplicant live, filtered to this interface, and
polls the device every 3s logging only transitions. When the link goes, it records the moment:
which BSSID you were on, the last signal reading before it went, the device state immediately
after, and the route that took over.

Everything lands in `~/zen-wifi-watch.log`. Leave it running, and send that file after it drops
once.

Read-only. It runs nothing that changes anything. Hardened for the two ways a diagnostic betrays
you at the worst moment: `set -u` unbound variables in the drop branch — the one path that only
executes when it matters — and an unwritable log, which previously would have flooded every line
with a tee error instead of recording.

### Files
zen-shell/ConnectivityService.qml (probe decides on psk-flags alone) ,
zen-shell/scripts/zen-wifi-watch.sh (new) , install.sh , ZenVersion.qml (hf189).

---

## v8.0.0-alpha-hf188 - the Wi-Fi Keeper: stop it dropping, and know why when it cannot

hf187 made the failure visible and the rail immediately said what had been hidden all along:

    Warning: password for '802-11-wireless-security.psk' not given in
    'passwd-file' and nmcli cannot ask without '--ask' option.

So the profile still has no key nmcli can use, even after the delete-and-recreate. But "here is
why" is not the same as "fixed", and the ask was to make it stop dropping. This is that.

### Why NM's own autoconnect was not enough

NetworkManager retries on its own, and when that works nobody thinks about wifi. It stops working
in two situations that both applied here:

  1. After a few failed activations NM sets an **internal autoconnect block** on the profile and
     quietly stops trying. No UI anywhere reports it. From the outside the wifi is simply "off
     now", and it stays that way until something clears the block.
  2. When activation fails for want of a secret, retrying is **pointless** — NM asks an agent,
     there is no agent, it fails identically forever.

### The Keeper

Deliberately not a retry loop. It:

  * remembers the SSID you were **genuinely connected to** and retries only that one — it will
    never go chasing a network you have never been on
  * backs off 5s → 10s → 20s → 40s → 60s → 60s, capped at six attempts (~4 minutes), then stops
    rather than hammering an AP that is actually gone
  * runs `connection.autoconnect yes` before each `connection up`, clearing NM's invisible block
  * **gives up immediately on a secrets failure** and raises the password prompt instead, because
    no amount of retrying can supply a password. The classifier catches all the phrasings nmcli
    uses: "secret", "password for", "no agents", "without '--ask'"
  * **never fights you.** An explicit Disconnect stands it down until you choose to connect
    again; an explicit Connect re-arms it and clears the stale secrets flag
  * reports itself: "Reconnecting to KiyuFamilyFibr — attempt 2 of 6"

Tested across eleven scenarios: a blip that reconnects and resets the backoff, the exact
password error from the screenshot above stopping the loop, NM's other secrets phrasing, a
transient failure continuing to back off, a user Disconnect being respected, Connect re-arming
after that, the hard cap, refusing to chase an unknown network, wifi switched off entirely,
the master toggle making it fully inert, and the backoff curve itself.

### Power saving, surfaced where it matters

A 60s probe reads `iw dev <dev> get power_save`, off the 3s hot path. When it is on — and on this
machine it has been on the whole time, with power-profiles-daemon sitting on power-saver — the
Wi-Fi settings page grows a row explaining that the adapter is allowed to idle down, and a button.

The button writes `/etc/NetworkManager/conf.d/zen-wifi-powersave.conf` with `wifi.powersave = 2`,
which survives reboots and reasserts on every activation. `iw dev wlan0 set power_save off` does
not — it is forgotten the next time the interface comes up, which is exactly when you need it.

The row only appears when power saving is actually on. A row that says everything is fine is a row
nobody reads.

### Also

The Wi-Fi settings section's subtitle now uses `wifiStatusText`, the same string as the dashboard
rail and the bar tooltip, so the three cannot disagree about whether you are online.

### Files
zen-shell/ConnectivityService.qml (keeper, backoff, failure classifier, power-save probe and fix,
disconnect/connect arming) , zen-shell/ConnectivityPage.qml (keeper toggle, conditional power-save
row, shared status string) , ZenVersion.qml (hf188).
Nuclear-clear the qmlcache: rm -rf ~/.cache/quickshell.

---

## v8.0.0-alpha-hf187 - the Connect button was never clickable, and every failure was silent

"nung click ko connect wala naman." Correct, and for two reasons stacked on top of each other.

### The button was dead

The rail row's outer MouseArea, from hf183 and carried into the hf185 merge unexamined:

    MouseArea {
        id: wMa; anchors.fill: parent; hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        // Only the top 30px header toggles; the action row has its own areas.
        height: 30
        onClicked: wRow.expanded = !wRow.expanded
    }

`anchors.fill` sets width **and** height, so the explicit `height: 30` conflicts and loses — QML
logs "Cannot specify height for items anchored with fill" and the anchor wins. The comment says
the top 30px toggles; the code covered all 62px of the expanded row.

And this MouseArea is the **last child** of the row, so it sits above the ColumnLayout in z-order
and received every click first. Tapping Connect never reached `cMa`. It hit this, which collapsed
the expander. Same for Forget. The buttons were decoration.

Anchored to left/right/top with an explicit height now, so it covers only the header strip and the
action row's own MouseAreas get their clicks. Swept the rest of the tree for the same
`anchors.fill` + explicit-size pattern: three candidates, all false positives (sibling objects, not
the same object).

### And a failure would have looked identical anyway

`_runAction` fired nmcli, nmcli printed its reason to stderr, and `actionRunner` sent that to
`console.warn` — where no user will ever see it. A failed Connect and a Connect that was never
wired up produce exactly the same thing on screen: nothing. That ambiguity is why a dead button
survived a merge and a version bump.

New `wifiLastError`, shown in `wifiStatusText` when not connected. A non-zero exit takes nmcli's
first stderr line, strips the `Error:` prefix, caps it at 120 characters, and **clears the busy
state immediately** rather than making you wait out the 20-second watchdog for something that is
never going to converge. `_beginWifiAction` clears the old reason so a stale message cannot outlive
its attempt.

So instead of nothing, the rail will now say things like "Connection activation failed: (7) Secrets
were required, but not provided." or "unknown connection 'KiyuFamilyFibr'." Shaping verified
against six real nmcli failure shapes including an empty stderr and a 200-character message.

### Separate: it dropped again

Connected at 18:12 after the psk repair, disconnected by 19:28. The key is fixed — this is a
different fault, and the most likely candidate has not been ruled out yet because it has not been
tried:

    sudo iw dev wlan0 set power_save off

`power_save: on` on iwlwifi, with power-profiles-daemon still on **power-saver**, which is what
turns it on. Worth testing before looking anywhere else.

### Files
zen-shell/ZenDashboard.qml (wMa anchored to the header strip) ,
zen-shell/ConnectivityService.qml (wifiLastError, non-zero exit handling) , ZenVersion.qml (hf187).
Nuclear-clear the qmlcache: rm -rf ~/.cache/quickshell.

---

## v8.0.0-alpha-hf186 - the Panasonic page was invisible on the machine it was written on

Everything from the parallel branch was already merged in hf185 — Panasonic support, the settings
fixes and the wifi repair are all in that tarball. But one of them could not be SEEN, and that
looked identical to it not having shipped.

`PanasonicPage` is hardware-gated. The nav entry is filtered out of `navGroups` when
`PanasonicService.isPanasonic` is false, which covers the grouped sidebar, the narrow rail and the
Ctrl+K search index in one place. That is right for users — a Panasonic page on a Ryzen desktop is
noise. It is wrong for the person writing it, whose Ryzen desktop is exactly where the code lives.

### forceShow

`isPanasonic` stays pure hardware truth. A new, deliberately separate `forceShow` surfaces the
page anyway, and `pageVisible = isPanasonic || forceShow` is what the sidebar now gates on.

    ZEN_PANASONIC_FORCE=1 quickshell     one session, nothing written
    zen-panasonic-setup.sh --force       writes force_page to wheelpad.json, persists

`--force` already existed in the setup script for the hypr snippet; it now also persists the page
flag, merging into an existing wheelpad.json rather than overwriting it.

The two stay separate on purpose. The wheelpad daemon reads `require_panasonic`, not `force_page`,
so it still refuses to grab a touchpad on hardware it has no business grabbing — `--any-machine`
remains the only way to override that, and it is a different decision from "let me look at the
settings page".

The page states its own situation rather than leaving it to be discovered: with the override
active and DMI disagreeing, the Hardware section carries a banner saying so, and `statusLine`
reads "Shown by override — DMI says this is not a Let's Note". Every reading on the page comes
from real sysfs, so on a non-Panasonic box most rows are simply empty — which is honest, but only
useful if you know why.

### Already in hf185, for the record

  * Panasonic — PanasonicService.qml, PanasonicPage.qml, scripts/zen-wheelpad.py,
    scripts/zen-panasonic-setup.sh
  * Wifi repair — NOSECRET probe, psk-flags 0 repair, secretsMissing, WIFI_DEV third source,
    _isWirelessType, scripts/zen-wifi-doctor.sh with --why
  * Settings — SettingRow icon slot, SysRowPage tray spacing, start menu gear → Control Center,
    Densho sidebar vocabulary

### Files
zen-shell/PanasonicService.qml (forceShow, pageVisible, persisted force_page) ,
zen-shell/PanasonicPage.qml (override banner) , zen-shell/ZenDashboard.qml (gate on pageVisible) ,
zen-shell/scripts/zen-panasonic-setup.sh (--force persists the flag) , ZenVersion.qml (hf186).
Nuclear-clear the qmlcache: rm -rf ~/.cache/quickshell.

---

## v8.0.0-alpha-hf185 - merge: two parallel branches of the same fix, reconciled

Two lineages had been running against the same hf176 base without knowing about each other.
This build is their merge. Nothing from either side was dropped.

### What happened

The hf177-hf184 line (dock plate, Lark popup, game warning, reset defaults, dock menus, Taskbar
page, rail connect/disconnect/forget, wifi connected-state) was built from an hf176 tarball. A
second line, also numbered hf177-hf183, was built from the SAME hf176 tarball in a separate
session that never saw the first. Both attacked the wifi badge. Both were partly right, and
neither was complete.

    hf184's diagnosis   duplicate rows: one router on 2.4 + 5GHz shows as several scan rows,
                        and only the joined BSSID is marked active → dedupe by SSID
    hf183's diagnosis   the active marker itself: NM 1.40+ prints `*` in IN-USE, not `yes`,
                        so `parts[0] === "yes"` never matched and nothing was ever active

**They are two halves of one bug.** hf184's `NetworkPulseModule` icon fix — the bar glyph that
switches wifi / ethernet / disconnected — reads `ConnectivityService.wifiConnected`, which the
other branch proved was permanently false. That icon fix could not have worked on its own. And
the dedupe could not help when no row was ever flagged active. Merged, they do.

### Conflicts and how each was settled

**ConnectivityService.qml** → the parallel branch, wholesale. Its dedupe does everything hf184's
did (one row per SSID, strongest signal, active if any BSSID is, security carried forward) and
adds `bssCount` for the "N AP" hint. On top of that it carries the work hf184 never had: the
`*`/`yes`/`1`/`true` marker fix, `_nmSplit` for nmcli's escaped colons, three independent
detection sources ORed rather than chained (`iw dev link` → `nmcli device show` →
`connection show --active`), `_isWirelessType` accepting both nmcli type spellings, a synthesised
row for a connected AP missing from a stale cache, `--rescan no` on the poll, the
`disconnectWifi` interface-glob fix, busy/connecting state, and the NOSECRET probe that detects
an agent-owned PSK and repairs it to `psk-flags 0`. One signal-picking difference: where hf184
always kept the strongest radio's signal, this keeps the signal of the radio you are actually
associated to, and falls back to strongest otherwise.

**SysRow.qml** → both. hf184's en-space (U+2002) in `fmtModule` fixed the BAR spacing; the other
branch fixed the SETTINGS PAGE spacing in `SysRowPage.qml` via a new `SettingRow` icon slot. Two
different places, two different fixes, both wanted. The busy-aware tooltip is layered on top.

**ZenDashboard.qml** → hf184's structure, with the other branch's work applied to it.

  * hf183's rail **expander** is kept — explicit Connect / Disconnect / Forget buttons and a lock
    glyph beat the parallel branch's tap-to-toggle on discoverability, which was the original
    complaint. Layered onto it: the green **Connected** pill (a check alone reads as "saved"),
    connected-first sorting, `isBusy` with a "Connecting…" pill, the hairline border, the "N AP"
    hint, a click guard while an action is in flight, and `wifiStatusText` in the header.
  * `isActive` now routes through `ConnectivityService.isConnectedTo()` so the rail, the Control
    Center tab and the bar glyph share one predicate and cannot disagree. hf184's model-flag check
    is kept as an OR.

**Page index collision.** Both branches added a page at `p33` — Taskbar (hf182) and Panasonic
(hf179). `navCatFor` is a POSITIONAL table, so shipping both would have re-filed Taskbar into the
wrong category and pointed its loader at the wrong page. Taskbar keeps `p33`; **Panasonic is
`p34`.** navItems and navCatFor are both 35 entries and every index 1-34 has a loader; verified.

### Carried in from the parallel branch, unconflicted

Start menu gear → Zen Control Center (it was toggling `PanelState.settingsVisible`, gated behind
a `legacyUiEnabled` that defaults to false, so it did nothing) · `SettingRow` optional icon slot
and `SysRowPage` adopting it · Densho vocabulary for the sidebar — 34 module kanji, 6 category
kanji, romaji tails, kanji brand mark and 禅 · 制御中枢 subtitle · Panasonic Let's Note support:
`PanasonicService`, `PanasonicPage`, the `zen-wheelpad` circular-scroll daemon, and
`zen-panasonic-setup.sh` · `zen-wifi-doctor.sh` with `--why` · install.sh ships the three new
scripts.

### Kept untouched from hf184

DockPowerButton, InputPage, LookService, MouseSettingsService, NetworkPulseModule, PanelState,
ShellLookPage, Taskbar, TaskbarPage, ThemeService, ZenDock, scripts/zen-fuzzel-glass.sh.

### Verified

45 presence checks across both change sets — every hf177-184 feature and every parallel-branch
feature confirmed in the merged tree. Positional nav tables aligned. All QML bracket skews
present in the merged tree were confirmed pre-existing in BOTH hf184 and the hf176 base (they
live inside shell-command string literals). install.sh, both new shell scripts and the wheelpad
daemon syntax-check clean.

Nuclear-clear the qmlcache: rm -rf ~/.cache/quickshell.

---

## v8.0.0-alpha-hf184 - wifi connected-state, bar network icon, system tray spacing

Three from your screenshots.

### The Connect button now knows you're connected
Your rail showed three "KiyuFamilyFibr" rows and a green Connect on the 100% one even
while you were online. Cause: a router broadcasting the same name on 2.4 and 5 GHz (or a
mesh) shows up as several scan rows, and nmcli marks active=yes on only the ONE BSSID
you actually joined — often not the strongest. So the other rows read as not-connected.
ConnectivityService now collapses duplicate SSIDs into one row: strongest signal, and
active if ANY of its BSSIDs is. One "KiyuFamilyFibr", and it flips to Disconnect the
moment you're on it. This also declutters the list everywhere it's shown.

### The bar network icon switches wifi / ethernet again
The bar's network module (NetworkPulseModule) had a hardcoded sitemap glyph that never
changed. It now shows the wifi signal-tier glyph on wifi, the ethernet glyph on LAN, and
the disconnected glyph otherwise — the same logic the SysRow module already used, so the
two agree.

### System tray icon spacing
fmtModule joined the glyph and its value with a single space, which crowded them. It uses
an en space (U+2002) now — a touch wider — for both the value and bargraph forms.

### Files
zen-shell/ConnectivityService.qml (dedupe wifi by SSID) , zen-shell/NetworkPulseModule.qml
(link-aware icon) , zen-shell/SysRow.qml (en-space separator) , ZenVersion.qml (hf184).
Nuclear-clear the qmlcache: rm -rf ~/.cache/quickshell.

---

## v8.0.0-alpha-hf183 - Wi-Fi connect / disconnect / forget in the dashboard rail

You couldn't tell how to connect, and you were right — there was no button. The compact
Networks list in the dashboard's right rail (ZenDashboard.qml, separate from the Control
Center's fuller Wi-Fi tab, which already had these) was a silent row: tapping it fired
connectWifi with no label, no connection state, and no way to disconnect or forget.

The row is an expander now. Tap a network and it opens an action bar with explicit buttons:
  • Connect — for a network you're not on
  • Disconnect — shown instead of Connect when that network is the active one (green check,
    green tint on the row, so you can see which one you're on)
  • Forget — shown only for saved networks (red), removes the saved connection

All three were already implemented in ConnectivityService (connectWifi, disconnectWifi,
forgetWifi) — this build only wires them to buttons. Secured networks now also show a lock
glyph in the row, matching the Control Center's list.

Nothing else changed: the model is still ConnectivityService.wifiNetworks, Scan still
rescans, and the Control Center's own Wi-Fi tab (which already had connect/reconnect/forget)
is untouched.

### Files
zen-shell/ZenDashboard.qml (rail Wi-Fi row → expander with Connect/Disconnect/Forget) ,
ZenVersion.qml (hf183). Nuclear-clear the qmlcache: rm -rf ~/.cache/quickshell.

---

## v8.0.0-alpha-hf182 - a Taskbar page, and the dock/bar split you asked about

You asked whether the QML bar's taskbar could have its own opacity. Turns out it already
had one — the same one — and that was a bug, not a feature.

Taskbar.qml is ONE component mounted in three places: Bar.qml, BarVertical.qml and
ZenDock.qml. It had no idea which one it was. So hf181's "Dock plate" slider was quietly
changing the QML bar's taskbar too, and would have gone on doing that for every taskbar
setting I ever added. It knows now — `surface` is "dock" for the ZenDock instance and "bar"
for the other two — which is the thing that makes the rest of this possible.

New page: APPEARANCE -> Taskbar (任務列), at the bottom of the group.
  • Link dock and bar — ON by default, which is exactly how it behaved before, so nothing
    moves on upgrade. Turn it off and the two get their own values.
  • Plate opacity — 0 to 100%. At 0 the plate, its border and its inner highlight all stop
    drawing. The Bar row only appears once you unlink, because until then it would be a
    slider that silently does nothing.
  • Icon size — 60% to 140%. This scales the icon INSIDE its button box, not the box, so
    growing the icons can't reflow the bar or push them into the overflow chevrons.
  • Icon backgrounds — the hf178 toggle, here too since this is where you'd look for it.

Nav indices: appended at the END (navItems[32] -> currentPage 33 -> Loader 33 ->
navCatFor[33]), and verified rather than assumed this time — General is still currentPage 1,
Displays still 5, Cursor & Icons still Loader 32. Nothing shifted.

On "background colors babaguhin": not in this build, deliberately. The plate takes the
theme's colour, or the Glass+ tint when that look is on — one colour shared with every
other surface, which is the whole point of hf173. A per-taskbar colour override would be
the first thing to break that. If you want it anyway, say so and I'll add it as an explicit
override with the theme as its default, so it can't drift by accident.

### Files
zen-shell/TaskbarPage.qml (new) , zen-shell/PanelState.qml (taskbarBarOpacity /
taskbarLinkSurfaces / taskbarIconScale) , zen-shell/Taskbar.qml (surface property,
per-surface plate, icon scale) , zen-shell/ZenDock.qml (surface: "dock") ,
zen-shell/ZenDashboard.qml (nav entry + category + Loader) , ZenVersion.qml (hf182).
Nuclear-clear the qmlcache: rm -rf ~/.cache/quickshell.

---

## v8.0.0-alpha-hf181 - the dock plate, which is the background you actually meant

I removed the wrong plate in hf178. You said "icons background" and I took out the little
pill behind each icon — your screenshot shows those are indeed gone. What you circled is
the DOCK'S OWN panel, the rounded slab behind all of them. That one had its alpha
hardcoded at 0.32 inside Taskbar.qml with no setting anywhere near it.

Shell Look -> OPACITY -> "Dock plate". It's the only slider in that section that starts at
0% instead of 30%, because 0 is the point: at 0 the plate stops drawing, and so do its
border and its inner highlight — otherwise you'd be left with an outline around nothing,
which is worse than the plate. Turn Icon backgrounds off too and the icons float straight
on the wallpaper. That's the macOS dock you described.

It defaults to 0.32, exactly what it has always been, so nothing moves until you drag it.

Two things fixed on the way past:
  • The plate was hand-rolled Qt.rgba(ThemeService.bg0…) — the same shape that hid the
    dropdown popup from my hf173 sweep. On the clear look it now uses the white-dominant
    tint like every other surface, instead of painting the theme's colour.
  • I glued a RowLayout onto the Start Menu row with a bad edit while doing this, then
    caught it by diffing the file against the hf180 tarball: 0 lines removed, 16 added,
    purely additive. Worth doing every time.

### Files
zen-shell/PanelState.qml (taskbarOpacity: property + save + load, 0 allowed) ,
zen-shell/Taskbar.qml (plate + border + highlight follow it; clear-look tint) ,
zen-shell/ShellLookPage.qml (Dock plate slider) , ZenVersion.qml (hf181).
Nuclear-clear the qmlcache: rm -rf ~/.cache/quickshell.

---

## v8.0.0-alpha-hf180 - "Reset all to defaults" now resets the focus settings

Your screenshot showed the Input page with a "Reset all to defaults" button at the bottom,
and it only ever reset sensitivity, scroll speed and the two natural-scroll switches. hf171
and hf177 added four focus settings above it and never taught the button about them.

So when Morimens started flickering and you went looking for the way out, the most obvious
control on the page would have done nothing about the cause. That's the wrong behaviour for
a panic button. It now also restores mouse_move_focuses_monitor, follow_mouse,
float_switch_override_focus and focus_on_activate to Hyprland's own defaults.

Verified by comparing every MouseSettingsService property the page can write against what
the reset block restores — the two sets now match, so this can't drift again without
showing up in that check.

### Files
zen-shell/InputPage.qml (reset covers the focus settings) , ZenVersion.qml (hf180).
Nuclear-clear the qmlcache: rm -rf ~/.cache/quickshell.

---

## v8.0.0-alpha-hf179 - warning on the toggle that broke your game

Morimens blinking was my fault: "Apps may take focus when they ask" (misc:focus_on_activate,
new in hf177) is GLOBAL, and games are exactly why Hyprland ships it off. Wine/Proton titles
re-request activation constantly, so with it on, every request is granted and you get a
focus war — the screen flickers and clicks never land.

The toggle's description now says so, in the place you'd actually read it, so this can't
bite you twice. It stays available (wala tayong babawasan) — it's just no longer described
as if it were free.

Where it is, since you couldn't find it: INPUT & DISPLAY is a COLLAPSED category in the
sidebar (that's the "2 >" next to it). Click the category header to expand it, then Input.
Verified the routing rather than guessing this time: navItems[5] = "Input" -> currentPage 6
-> Loader 6 -> InputPage.qml, and the two entries under INPUT & DISPLAY are Displays and
Input, which matches the "2" your sidebar shows.

You're right that App Float Rules is the better home for this, and it already knows Lark's
class is `lark` - so I don't need hyprctl clients after all. But the per-app rule for this
is `stayfocused`, and two things make it a bad idea to just ship blind:
  - upstream users report that with stayfocused on a class you can't flip away from that
    app at all while it's up - on the whole `lark` class you'd be trapped in Lark
  - Hyprland has no per-window focusonactivate rule (confirmed upstream: it's a setprop
    property, not a windowrule), so the surgical version of the hf177 toggle doesn't exist
So it has to be scoped to the call popup's TITLE, and that's the one thing I still don't
have. With the call up: `hyprctl clients | grep -iA3 lark` — send me the title line and
I'll wire a title-scoped stayfocused into WindowRulesService, which already writes per-app
rules to ~/.config/hypr/modules/zen-window-rules.conf.

### Do this now
1. Input -> turn OFF "Apps may take focus when they ask"  (Morimens stops blinking)
2. Input -> leave "Floating popups keep focus" ON  (that's float_switch_override_focus = 0,
   the safe one — it never grants focus to anyone, it only stops focus being STOLEN when
   the cursor crosses between a floating window and a tiled one)
3. Try Lark with only #2 on. There's a fair chance that was the whole fix.

### Files
zen-shell/InputPage.qml (warning text) , ZenVersion.qml (hf179).
Nuclear-clear the qmlcache: rm -rf ~/.cache/quickshell.

---

## v8.0.0-alpha-hf178 - dock menus, Super+D, and floating icons

### Right-click menus on the dock (and the power menu)
Both taskbar context menus and the power menu painted their sheet with
LookService.bodyColor(), which on the clear look routes to clearFill() — white at 0.10-0.22
alpha. That's correct for a PANEL, which has Hyprland's blur behind it, but a menu is not a
panel: at 16% white with white text it's a ghost. You said the power menu looked right and
the taskbar one didn't — worth knowing that they are the same code. The power menu just
happened to be over a dark patch of wallpaper in your screenshot; move it over something
light and it disappears too. All three now use popupColor() + popupInk, so they have body
and their text picks its own colour, like every other menu since hf174.

### Super+D (fuzzel)
Two things stacked. Look closely at your screenshot and you can read the Claude window
THROUGH the app list — fuzzel wasn't frosted, it was see-through. The shell was handing it
0.30 - 0.14*strength, so at the hf173 default of level 5 the launcher was white at 16%
alpha; our panels survive that because Hyprland blurs them, and fuzzel's surface has no
blur rule. On top of that, zen-fuzzel-glass.sh only ever rewrote `background` — the text
stayed whatever the theme set, which on a dark theme is light text. White on white.

So fuzzel now gets body (0.97 -> 0.92 across the five levels, same reasoning as
popupColor), and the script rewrites text / match / selection / selection-text /
selection-match too. Tested against a real dark-theme fuzzel.ini: text lands at 17.2:1 on
the sheet, the match accent at 5.0:1.

Testing that also caught a bug I'd just written: --opaque restored the theme's dark
background but left the dark ink from the glass run behind it — dark on dark. Leaving
Glass+ would have broken the launcher. --opaque now pulls fg / blue / bg2 back from the
theme as well, and the round-trip is verified in both directions.

### Icon backgrounds (new toggle, Shell Look)
"prang pang macbook prang naka float nga yun design e." Off — dock icons sit straight on
the dock with no plate. The dot under an icon still says it's running and a faint wash
still says what you're hovering, which is exactly how macOS does it. On brings the plate
back — nothing is removed, wala tayong babawasan. Defaults to OFF since that's what you
asked for; the toggle is in Shell Look next to "White app icons".

### On sizes and the width limit
Worth saying before you go looking: both already exist. Dock -> Height drives the icon
size (btnSize is the bar height minus padding, so the icons scale with it), and the
taskbar already clamps itself to maxVisibleWidth and shows chevrons past that. Try Height
first — if it doesn't give you the range you want, tell me and I'll add a separate icon-size
control rather than have two settings fight over the same number.

### Files
zen-shell/Taskbar.qml (2 context menus + icon pill) , zen-shell/DockPowerButton.qml (menu) ,
zen-shell/ThemeService.qml (fuzzel alpha) , zen-shell/scripts/zen-fuzzel-glass.sh (text
colours + --opaque restore) , zen-shell/PanelState.qml + zen-shell/LookService.qml +
zen-shell/ShellLookPage.qml (icon-background toggle) , ZenVersion.qml (hf178).
Re-run install.sh (the fuzzel script is code — it always overwrites), then
rm -rf ~/.cache/quickshell.

---

## v8.0.0-alpha-hf177 - the Lark / Zoom call popup that closes before you can click it

Three new focus controls in Control Center -> Input. Together they are the levers behind
"the call popup exits on its own before I can hit the smiley or End call".

What is actually happening. A Lark/Zoom call popup is a FLOATING window sitting over your
normal TILED ones. Hyprland's default is follow_mouse = 1, and it has a documented quirk:
focus ALWAYS changes on mouse enter when you cross between a floating window and a tiled
one - the quirk fires even if you turn follow_mouse off. So the instant the cursor drifts
off the popup, the window behind takes focus and the popup hides itself. That is also why
you can't reach the smiley: clicking it opens a child menu, but your cursor is still on the
button, focus snaps back to the parent, and the menu closes.

  • "Floating popups keep focus"  -> input:float_switch_override_focus (ON = 0)
    This is the one to try first. It is what kills the float/tile quirk - upstream reports
    that with it at 0, floating dialogs "retain focus even if the mouse leaves the window".

  • "Apps may take focus when they ask" -> misc:focus_on_activate
    Hyprland ignores activation requests by default, so a popup that asks for focus as it
    opens never gets it, and hides again. The other half of the same bug.

  • "Focus follows mouse" -> input:follow_mouse (Full / Loose / Click to focus)
    Full is Hyprland's default. Loose lets the mouse focus without dragging the keyboard
    along. Click to focus means hovering never steals focus at all.

All three default to Hyprland's own defaults, so nothing changes until you flip them. Each
applies live via hyprctl and is written to zen-mouse.conf + mouse-settings.json, so it
survives reload and reboot - same 5-point path as the hf171 monitor-focus toggle.

I went with settings rather than a windowrule on purpose: a rule needs Lark's exact window
class, I still don't have it, and a guessed class silently does nothing. These work
whatever the class is. If flipping the first two doesn't do it, then it IS app-specific -
run `hyprctl clients | grep -iA3 lark` with the call popup open, send me the class and
title, and I'll write a surgical rule through WindowRulesService (which already manages
per-app rules in ~/.config/hypr/modules/zen-window-rules.conf).

### Files
zen-shell/MouseSettingsService.qml (followMouse / floatSwitchOverrideFocus / focusOnActivate:
property + apply + conf + state + load) , zen-shell/InputPage.qml (three controls) ,
ZenVersion.qml (hf177). Nuclear-clear the qmlcache: rm -rf ~/.cache/quickshell.

---

## v8.0.0-alpha-hf176 - the other two dropdowns (your hunch was right)

You said the problem is Glass+ only and you felt it was the dropdowns. Both correct - and
there were two more I hadn't touched.

hf175 fixed ZenDropdown, and because that is one shared component it covered the dropdowns
on 16 pages at once (Themes, Displays, Wallpaper, Cursor & Icons, Animations, Dock, Panel,
General, Bar Modules, Hot Corners, Widgets, Desktop, Plugins, Default Apps, Battery,
User Profile). But the Control Center has two MORE list panels that are dropdowns in every
way that matters, and both were built by hand with the same Qt.rgba(bg1…, 0.98) sheet my
sweeps never matched:

  • SettingsSearchBar   - the "Search modules…" bar at the top; its results panel
  • SettingsSearchOverlay - the Ctrl+K spotlight

Both now use the same rule: popupColor() for the sheet, popupInk / popupInkDim for text,
popupInkAlpha() for the borders, separators and hover washes that were also built from
ThemeService.fg (white on clear = invisible on a light sheet - the hover feedback had
quietly gone too). Both had the multi-line-ternary trap that bit me in hf174, and the
overlay had the accent-as-text problem: on clear, blue measures 1.7:1 against the light
sheet for DarkMatter, so on clear those labels take the ink and keep the accent only on
non-clear. Nine glass outlines dropped inside the overlay, four in the bar - they only
muddy dark-on-light glyphs on an opaque sheet.

Deliberately NOT touched: the search INPUT at SettingsSearchBar:115 sits on the glass bar,
not on the sheet, so it keeps hf163's white + outline. It was never broken.

Also checked, so you don't have to wonder: ZenComboBox.qml is dead code (nothing
instantiates it - every page already migrated to ZenDropdown), so it stays untouched per
wala tayong babawasan. The only other bare ComboBox is in AppFloatRuleEditPopup, a QQC2
Dialog with default styling - a different rendering path, and not something you're looking
at. Say the word if you ever hit it.

Everything here is clear-look only. On Zen / Classic / Glass / Minimal / Custom every one
of these falls back to ThemeService.fg / grey1 / bg1 exactly as before.

### Files
zen-shell/SettingsSearchOverlay.qml (sheet + ink + 9 outlines + accent) ,
zen-shell/SettingsSearchBar.qml (results sheet + ink + 4 outlines) , ZenVersion.qml (hf176).
Nuclear-clear the qmlcache: rm -rf ~/.cache/quickshell.

---

## v8.0.0-alpha-hf175 - the dropdown for real: the WHOLE popup follows its sheet

My hf174 fix was half a fix, and your screenshot showed exactly where it stopped: the
"current" row was readable and every other row was ghost-faint.

Two things I got wrong.

1. The row label sets its colour with a MULTI-LINE ternary:
       color: realIndex === root.currentIndex
              ? ThemeService.blue : ThemeService.fg
   My hf174 pass matched `color: ThemeService.fg` on a single line, so it never saw this
   one. The current row read because it took the blue branch; every other row took
   ThemeService.fg, which on the clear look is WHITE — white on a light sheet. Ghost text.

2. It was never only the text. Inside the popup the borders, the hover wash and the row
   separators were ALL built from ThemeService.fg at a low alpha, on the same assumption
   that fg contrasts with the sheet. On the clear look fg is white, so on a light sheet
   the hover feedback and the separators had vanished too — you just couldn't see them to
   report it. New LookService.popupInkAlpha(a) gives them the popup's own ink at whatever
   alpha the caller asked for. Six of them.

Also fixed: the accent as text. On the clear look the sheet is the white tint, and
ThemeService.blue measured 1.72:1 against it for DarkMatter and 4.50:1 for Sakura — the
"current" row would have been unreadable on a dark theme. On clear, that label now takes
the ink too; the row is already marked by its blue background wash, Medium weight and the
"current" badge. On non-clear looks it keeps the blue exactly as before.

Verified: zero ThemeService.fg/grey references remain anywhere in the popup region, and on
every installed theme the popup ink comes out at 14-16:1 contrast. Balance unchanged
(ZenDropdown's (2,0) is pre-existing, in a string).

The 17 other hand-rolled opaque sheets from hf174 are still outstanding - same class, and
now I know to look for multi-line ternaries and fg-alpha borders in them too, not just
plain text colours. Tell me which ones you hit, or say "do them all".

### Files
zen-shell/LookService.qml (popupInkAlpha) , zen-shell/ZenDropdown.qml (row label ternary,
6 fg-alpha borders/hover/separators, accent contrast) , ZenVersion.qml (hf175).
Nuclear-clear the qmlcache: rm -rf ~/.cache/quickshell.

---

## v8.0.0-alpha-hf174 - text picks its own colour on opaque sheets (theme dropdown fixed)

The theme dropdown was unreadable and you were right that this should be automatic.

Cause: hf163 made every text white. That is correct ON GLASS - the panel is mostly blurred
wallpaper, so white plus the dark outline always reads. But a dropdown popup is not glass:
it paints its own near-opaque sheet. ZenDropdown built it by hand with
Qt.rgba(ThemeService.bg1.r, …, 0.98), which my hf173 sweep never saw (it matched
ThemeService.alpha(…), not hand-rolled rgba). So on a light theme like Densho Hi that sheet
is cream, and white-on-cream is invisible. That was your theme list.

Now anything with its own background ASKS what colour to write on it instead of assuming:

  LookService.inkOn(bg) / inkDimOn(bg)   - measures the background's relative luminance
                                          (WCAG) and returns white or near-black
  LookService.popupBase / popupInk / popupInkDim / popupColor(opacity)
                                        - the matching sheet + text for menus and lists

Checked against every installed theme: on the clear look the sheet is the same
white-dominant tint as hf173 and the ink comes out dark at 14-16:1 contrast; on DarkMatter's
dark sheet it comes out white at 16.3:1. Automatic on any theme, light or dark, including
ones you make later.

This is NOT the hf160 auto-contrast you rejected - that darkened text on the GLASS panels.
This only touches surfaces that are opaque to begin with. Glass keeps white + outline
exactly as approved, and on non-clear looks popupInk/popupInkDim fall back to
ThemeService.fg/grey1, so those looks are byte-identical.

ZenDropdown: the popup sheet, its search field, group headers, row labels, icons, meta text
and the empty state all follow the sheet now. The hf163 dark outline is dropped inside the
popup (it only muddies dark-on-light glyphs); the TRIGGER, which sits on glass, keeps white
+ outline untouched.

STILL TO DO - 17 more surfaces build a near-opaque sheet the same hand-rolled way and will
have the same white-on-light text: Battery, ClipboardPanel, MusicStrings, MusicWidget,
SysRow, SysRowIcon, SysMonitor, ZenSysMonitor, ZenAnnotationToolbar, ZenWeather, ZenCalendar,
ZenClock, Taskbar (2 previews), ThemesPage, DockPowerButton. They are mostly tooltips and
hover cards. Each needs its text scoped to its own sheet, and guessing that structure
without being able to run the QML is how things break - so tell me which ones you actually
hit, or say "do them all" and I'll work through them one file at a time.

### Files
zen-shell/LookService.qml (inkOn/inkDimOn + popup helpers) , zen-shell/ZenDropdown.qml
(popup sheet + auto ink) , ZenVersion.qml (hf174).
Nuclear-clear the qmlcache: rm -rf ~/.cache/quickshell.

---

## v8.0.0-alpha-hf173 - one surface rule for Glass+, glassiness as 5 levels, Sakura theme

### The theme no longer eats the glass
You were right, and the cause was not the theme system. The outer frost was already
neutral white (clearFill, since hf160) - but 213 INNER surfaces painted ThemeService.bgN
straight, so a cream theme (Yousai) or a sage one (Light Paper) turned every card and row
into a solid sheet of that colour. The glass disappeared and the text stopped reading.

There is now ONE rule they all route through - LookService.surfaceColor(base, opacity):
  • non-clear looks -> ThemeService.alpha(base, opacity), byte-identical to before
  • clear look      -> white tinted by 14% of the theme's own bg4 (its most characteristic
                       colour), at an alpha scaled from the caller's intended opacity
                       (x0.20, clamped 0.05-0.22)
Scaling from the caller's opacity means the depth hierarchy each page was designed with
survives - a 0.9 fill still sits above a 0.55 one - but everything lands in the glass range
instead of going opaque. The theme still reads through ACCENTS (selected nav, toggles,
sliders, palette swatches); none of those go through this function. That is the "kunting
mixture" - one main colour, glass wins.

Two numbers to taste, both at the top of LookService: clearTint (how much theme colour in
the white, 0.14) and clearSurfaceScale (how much of the caller's opacity survives, 0.20).
Say the word and I'll move them.

How it was done safely (213 surfaces, 61 files):
  • ThemeService.alpha(ThemeService.bgN, X) -> LookService.surfaceColor(ThemeService.bgN, X)
    is a pure prefix rename: same arguments, same parens, so it CANNOT change a file's
    bracket balance. 190 of these.
  • 23 bare `color: ThemeService.bgN` fills were wrapped (one balanced paren pair each).
  • Qt palette lines are EXCLUDED - palette.highlightedText and palette.window are TEXT
    colours, and sweeping them would have broken text. Verified untouched.
  • LookService/ThemeService themselves excluded, so the fallback can't self-recurse.
  • Verified against the hf172 tarball that every file's bracket balance is IDENTICAL
    before and after (the 11 files that look imbalanced were already like that - the
    imbalances live in strings/comments, same as shell.qml's "[0,20)").

### Glassiness is 5 levels now, default 5
The 0-100% drag had 50 stops but only about five visually distinct results - the in-between
positions were false precision. It is now stepSize 0.25 with SnapAlways, which snaps to
exactly 0 / .25 / .5 / .75 / 1 - the SAME curve glassFill and glassBlur already use, just
quantised, so no range is lost. The readout shows "3 · Glass" instead of "58%". Default is
now level 5, as you wanted. Levels: 1 Card, 2 Frosted, 3 Glass, 4 Clear, 5 Pure.

### Sakura theme
Added as a builtin - cherry blossom pink paper with plum ink, the one from the mockup.
Full 16-colour palette matching the theme schema exactly; contrast checked (fg on bg0 is
11.2:1, grey1 4.8:1 - both pass AA). install.sh seeds it on install and never overwrites.

### Files
zen-shell/LookService.qml (surfaceColor + clearTint + clearSurfaceScale) , 61 component
files (surface sweep) , zen-shell/ShellLookPage.qml (5 levels) , zen-shell/PanelState.qml
(default level 5) , themes/builtin/sakura.json (new) , ZenVersion.qml (hf173).
Re-run install.sh (to seed Sakura), then rm -rf ~/.cache/quickshell.
Static-verified only - balance identical to hf172 across every file, palette lines
untouched, no self-recursion. I can't run QML here, so check it on the rig.

---

## v8.0.0-alpha-hf172 - cursor survives relogin from the very first frame

The cursor picker already re-applied on shell start (via cursor.json), but there was a beat
of the default cursor before that kicked in, and you wanted the pick locked in from the
moment the session comes up.

CursorService now ALSO writes the theme + size to ~/.config/hypr/modules/zen-cursor-env.conf
as env lines (XCURSOR_THEME / HYPRCURSOR_THEME / XCURSOR_SIZE / HYPRCURSOR_SIZE). Hyprland
reads env at LAUNCH, so on the next login the cursor is correct from the first frame - no
default-cursor flash before the shell re-applies. The live hyprctl setcursor + gsettings
path and the cursor.json re-apply both stay as before (belt and suspenders). install.sh now
seeds that conf empty and adds the source line to hyprland.conf.

Icons already persist on their own: IconThemeService sets them through gsettings, which
dconf saves across reboots and GTK apps read at startup - so your icon pick is kept without
anything extra.

IMPORTANT: for the launch-time cursor env to take effect you must re-run install.sh once
(it adds the source line + seeds the file). After that it is automatic. Note this covers
the cursor inside your Hyprland session; the cursor on the SDDM LOGIN screen itself is set
by the display manager, not the shell - that needs SDDM's own cursorTheme (say the word and
I'll walk you through it).

### Files
zen-shell/CursorService.qml (write cursor env conf) , install.sh (seed + source
zen-cursor-env.conf) , ZenVersion.qml (hf172). Re-run install.sh, then rm -rf ~/.cache/quickshell.

---

## v8.0.0-alpha-hf171 - windows/popup stop chasing the cursor across monitors

Two monitor-focus fixes.

### Super+W picker stays on the monitor it opened on
The wallpaper picker was shown on whichever monitor was focused LIVE (isFocusedMonitor), so
moving the cursor to another monitor dragged it along. It now captures the focused monitor
at OPEN time and pins itself there for that session, so it no longer follows the cursor.

### "Cursor doesn't steal monitor focus" toggle (Input)
New toggle in Control Center -> Input (mouse section). When ON, moving the cursor onto
another monitor does NOT focus that monitor - so a newly opened app (Steam, etc.) lands on
the monitor you're actually working on, not wherever the cursor drifted. It maps to
misc:mouse_move_focuses_monitor (inverted for the user-facing sense), applied live via
hyprctl and written to zen-mouse.conf + mouse-settings.json so it survives reload and
reboot. Default is unchanged (Hyprland default), so nothing changes until you flip it.

### Files
zen-shell/shell.qml (pin picker monitor at open) , zen-shell/MouseSettingsService.qml
(mouse_move_focuses_monitor: property + apply + conf + state + load) , zen-shell/InputPage.qml
(toggle) , ZenVersion.qml (hf171). Nuclear-clear the qmlcache: rm -rf ~/.cache/quickshell.

---

## v8.0.0-alpha-hf170 - GTK icon theme picker (no more GTK settings detour)

Added an icon-theme picker next to the cursor one, so you can switch GTK app icons from the
Control Center. The nav entry under APPEARANCE is now "Cursor & Icons".

New IconThemeService scans installed icon themes - a directory with an index.theme that has
a `Directories=` line, which is what tells a real icon theme apart from a cursor theme (so
cursor themes don't pollute the icon list) - across ~/.icons, ~/.local/share/icons and the
system paths. It applies via `gsettings set org.gnome.desktop.interface icon-theme`, which
dconf persists across reboots, and it reads the current value back so the dropdown shows
what's actually set. Verified the detection (lists icon themes, skips a cursor theme) and
the gsettings command.

The Cursor & Icons page now has: cursor theme + size (CursorService, hyprctl + gsettings),
and icon theme (IconThemeService, gsettings) - each with a rescan button and a live
"Applied" readout.

### Files
zen-shell/IconThemeService.qml (new) , zen-shell/CursorPage.qml (icon section + title) ,
zen-shell/ZenDashboard.qml (nav label -> "Cursor & Icons") , ZenVersion.qml (hf170).
Nuclear-clear the qmlcache: rm -rf ~/.cache/quickshell.

---

## v8.0.0-alpha-hf169 - cursor scan also detects hyprcursor themes

Confirmed the scan already finds standard Xcursor themes in ~/.icons (Win10Sur, Bibata-*,
etc. all have a cursors/ subdir, which is what the scan keys on). If those were not showing
for you, it is because the picker itself was invisible until hf168 (it had been added to a
non-mounted legacy page) - hf168 moved it to its own "Cursor" entry under APPEARANCE.

This build broadens detection so it ALSO catches hyprcursor themes: a directory now counts
as a cursor theme if it has a cursors/ subdir (Xcursor) OR a manifest.hl file OR a
hyprcursors/ subdir (hyprcursor). Verified against theme folders named like yours plus a
hyprcursor-style one.

So: make sure you are on hf168+, open Control Center -> APPEARANCE -> Cursor (bottom of the
group), and hit the rescan button if you installed themes after opening it. Your ~/.icons
themes will be listed.

### Files
zen-shell/CursorService.qml (hyprcursor detection) , ZenVersion.qml (hf169).
Nuclear-clear the qmlcache: rm -rf ~/.cache/quickshell.

---

## v8.0.0-alpha-hf168 - Cursor picker is now its own page under Appearance

The hf165 cursor picker was added to AppearancePage.qml - which turned out to be a legacy
file that is NOT mounted by the Control Center nav (the real pages are GeneralPage,
DecorationPage, etc., each loaded by its own nav entry). So it never showed up. That is why
you could not find it.

Fixed properly: "Cursor" is now its own nav entry under APPEARANCE (last item in that
group), loading a new CursorPage.qml. Appended as nav index 32 - at the END of navItems /
navCatFor / the page Loaders - so no existing page index shifts. The dead section was
removed from AppearancePage.qml.

CursorPage has the theme dropdown (+ a rescan button), the currently-applied theme, and a
size slider - all driven by CursorService, which still scans ~/.icons, ~/.themes, ~/.cursor
and the system paths and applies live via hyprctl setcursor + gsettings, persisting to
cursor.json. Verified navItems / navCatFor / Loader all line up at index 32.

### Files
zen-shell/CursorPage.qml (new) , zen-shell/ZenDashboard.qml (nav entry + category + Loader) ,
zen-shell/AppearancePage.qml (removed dead section) , ZenVersion.qml (hf168).
Nuclear-clear the qmlcache: rm -rf ~/.cache/quickshell.

---

## v8.0.0-alpha-hf167 - cursor picker scans more folders (.themes, .cursor)

The hf165 cursor picker (Appearance -> Cursor) only scanned ~/.icons, ~/.local/share/icons
and the system paths. Broadened it to also look in ~/.themes, ~/.cursor, and
~/.local/share/cursors, so a theme lands in the list wherever you keep it. A "cursor theme"
is still any directory that has a cursors/ subdir - verified the scan finds them across all
those roots and ignores plain GTK theme folders (no cursors/ subdir). It still applies live
on select and re-applies on shell start.

Note on APPLYING: `hyprctl setcursor` (and GTK) resolve a theme through the standard
Xcursor path - ~/.icons, ~/.local/share/icons, /usr/share/icons. A theme that only lives in
~/.themes or ~/.cursor will show in the list but may not actually apply, because the cursor
loader will not find it there. For one that lists but does not apply, move it to
~/.icons/<name>/cursors/. (And heads up - ~/.cursor is usually the Cursor editor's config,
not a cursor-theme folder.)

### Files
zen-shell/CursorService.qml (scan roots) , ZenVersion.qml (hf167).
Nuclear-clear the qmlcache: rm -rf ~/.cache/quickshell.

---

## v8.0.0-alpha-hf166 - Glass+ frost no longer vanishes after a settings apply / reload

Bug: on Glass Advanced+ at 100% glassiness, changing settings / applying / anything that
triggers a hyprctl reload made the frost disappear and the panels go fully transparent.

Cause: the live blur is a runtime layerrule that LookService pushes via hyprctl
(carrying the current glassiness as ignore_alpha). A `hyprctl reload` - which SettingsState
issues on a theme change, animation preset, and other applies - makes Hyprland re-read its
config, DROP that live rule (reverting to the conf's static value), and often remap the
zen-shell-* layer surfaces. At 100% glass the fill is almost nothing, so with the live blur
gone the panels read as invisible. hf155 only re-applied on login, not after a reload.

Fix: LookService now listens for Hyprland's `configreloaded` event and re-runs the same
startup re-apply burst (a few re-issues over ~3.5s, to catch the layers remapping), which
re-pushes the layerrule at the CURRENT glassiness. glassStrength is the shell's own
persisted state and is never touched by the reload - only the Hyprland-side rule was lost -
so the frost comes back at exactly the strength you had. This is general: it catches EVERY
config reload, whatever triggered it (theme, animation, decoration, lid, manual). Restart
is already covered by the hf155 startup burst.

### Files
zen-shell/LookService.qml (configreloaded listener + import Quickshell.Hyprland) ,
ZenVersion.qml (hf166). Nuclear-clear the qmlcache: rm -rf ~/.cache/quickshell.

---

## v8.0.0-alpha-hf165 - cursor theme picker + dashboard forecast + monitor check

### Mouse cursor theme picker (Appearance)
New "Cursor" section in Appearance. A CursorService scans your installed Xcursor themes
(any directory with a cursors/ subdir under ~/.icons, ~/.local/share/icons, /usr/share/
icons) and the dropdown applies the chosen one LIVE - hyprctl setcursor + gsettings so GTK
apps follow too - with a size slider. The choice is saved to cursor.json and re-applied on
shell start, so it survives a relogin without editing hyprland.conf. Verified the scan
(finds themes by cursors/ subdir, ignores non-cursor icon themes) and the apply command.

### Dashboard weather: forecast shows more readily
The hourly + 7-day strips were already built and the fetch/parse is correct (the API asks
for daily + hourly and both are parsed). Lowered the height thresholds (hourly 172->150,
7-day 262->234) so they appear at more card sizes, and the dashboard now kicks a weather
refresh on open if the forecast/hourly arrays are empty (stale/old cache), so they fill in.
If they are still blank it is a data issue, not layout - needs a successful fetch (net);
since hf157 the hourly is cached, so once fetched it persists offline.

### Monitor auto-primary (checked, per your ask)
We already have this and it is stable: MonitorRecoveryService auto-re-enables the internal
laptop monitor when the external is removed and the internal was left disabled (3 recovery
cases; runs on startup + monitoradded/removed events + every 5s, and clears the disable
line so it survives reboot). Panels are built per-screen (Variants over Quickshell.screens)
so the bar follows to the internal automatically, popups follow Hyprland.focusedMonitor
(which Hyprland repoints to the internal on disconnect), and NO primary monitor name is
persisted that could get stuck on the removed external. So the internal becomes the
effective primary on its own. (If you want an explicit focusmonitor nudge after recovery
for extra safety, say the word.)

### Files
zen-shell/CursorService.qml (new) , zen-shell/AppearancePage.qml (Cursor section) ,
zen-shell/ZenDashboard.qml (lower thresholds + refresh-on-open) , ZenVersion.qml (hf165).
Nuclear-clear the qmlcache: rm -rf ~/.cache/quickshell.

---

## v8.0.0-alpha-hf164 - wallpaper page: fuzzy search + auto-load on open

Two things for the Control Center wallpaper page.

### Fuzzy search
There was already a searchQuery + filteredList in WallpaperServiceV5, but no search box in
the UI and it only did substring matching. Added a search field above the grid, and
upgraded the filter to FUZZY (subsequence) matching: every character of the query appears
in order in the name, so "frst" finds forest, "df63" finds downloaded-file (63), "drml"
finds dreamlike. Whitespace ignored, jumps to page 1 on each keystroke, with a clear (x)
button. Verified the match logic against a real filename set.

### Auto-load on open
The folder is already scanned on shell start, but new wallpapers needed a manual refresh.
The page now rescans the folder every time it becomes visible (a cheap find), so the grid
is current the moment you open it - no refresh click. Any stale search is cleared on open
too.

### Files
zen-shell/WallpaperServiceV5.qml (fuzzy filteredList) , zen-shell/WallpaperPage.qml
(search field + auto-refresh on visible) , ZenVersion.qml (hf164).
Nuclear-clear the qmlcache: rm -rf ~/.cache/quickshell.

---

## v8.0.0-alpha-hf163 - white text + dark outline EVERYWHERE on Glass+ (rollout complete)

The full rollout you asked for. Every text element in the shell now renders white with a
dark outline on the Glass+ look - Appearance page, dock, notifications, dashboard cards,
control panel, bars, start menu, all of it - so it reads over any wallpaper while the
glass stays white.

How it was done safely (1369 Text elements across the shell, no shared component to hook):
- fg / grey0 / grey1 / grey2 now resolve to WHITE on the clear look (one central change in
  LookService.clearInk*), so every component's text goes white at once.
- The dark OUTLINE is a per-Text property with no global switch, so it was applied by a
  QML-aware sweep: a brace/string/comment-tracking parser that adds, to each genuine
  `Text {` block only, `style: isClear ? Text.Outline : Text.Normal` and `styleColor:
  clearTextOutline`. It skips any Text that already sets style (the desktop-clock outline,
  etc.), and it skips TextInput / TextField / TextEdit (which have no style property).
- Safety net: the two inserted lines contain no braces/parens/brackets, so a correct
  insertion cannot change a file's bracket balance. The sweep verified balance was
  IDENTICAL before and after for all 195 files, then re-verified tree-wide that no
  styleColor got glued to following content and no block got a duplicate style.
- On every NON-clear look, style falls back to Text.Normal and the colours to the theme
  values - so Zen / Classic / Glass / Minimal / Custom are byte-for-byte unchanged.

The outline is Qt.rgba(0,0,0,0.60) - a soft dark border, "kunting border" as you put it.
If you want it heavier or lighter it is one value (clearTextOutline in LookService).

### Files
zen-shell/LookService.qml (fg->white on clear + clearTextOutline) + ~120 component files
(one Text-outline sweep) + ZenVersion.qml (hf163).
Static-verified only (brace/paren balance identical pre/post on all 195 files, no glued
lines, no duplicates, TextInput/etc. untouched) - I can't run QML here, so nuclear-clear
the qmlcache (rm -rf ~/.cache/quickshell) and check. If any single surface looks off,
tell me which and I'll fix that Text.

---

## v8.0.0-alpha-hf162 - white text + dark outline on Glass+ (your idea), rollout begins

You were right that the dark auto-contrast text of hf160 felt too heavy, and that white
text + a subtle dark outline keeps the white glass AND stays readable. That IS the correct
answer - white-on-light fails, but white-on-light-with-a-dark-outline reads fine.

The honest catch: QML has no global Text style. Colour I could flip in one place (I did,
in ThemeService). Outline/shadow is a per-Text-element property - and the shell has ~1399
Text elements across 121 files with no shared text component. So this can't be a one-line
switch; it's a rollout, surface by surface.

What's in this build:
- The MECHANISM, in LookService: clearTextOutline + textColor / textDimColor /
  textFaintColor. A component opts in with three lines (color via the helper, style =
  isClear ? Text.Outline : Text.Normal, styleColor = clearTextOutline). Non-clear looks
  fall straight back, so nothing regresses.
- CONVERTED so far: the dashboard sidebar nav (the faint APPEARANCE / INPUT & DISPLAY
  rows you circled), plus the shared settings-row + section-header components (HMRow,
  HMSection) - which covers every settings page at once.
- Everything NOT yet converted keeps the auto-contrast fg from hf160, so it stays readable
  (just dark-on-light, not white-on-outline) until its turn.

Still to convert (big files, next builds if you want them): the dashboard CARDS
themselves (ZenDashboard, ~124 Text - clock / weather / sysmon / workspaces), the control
panel, and the bar + dock. Say the word and I'll grind through them.

### Files
zen-shell/LookService.qml (text helpers) , zen-shell/ZenDashNavRow.qml ,
zen-shell/HMSection.qml , zen-shell/HMRow.qml , ZenVersion.qml (hf162).
Nuclear-clear the qmlcache: rm -rf ~/.cache/quickshell.

---

## v8.0.0-alpha-hf161 - the lock message, for real this time (shuf -e, one line)

Third attempt, and this time I found the ACTUAL cause. Every prior version built the pool
with printf %s-backslash-n piped into shuf, all inside command substitution. That combo -
a literal backslash-n, a pipe, AND $( ) folded across hyprlang's line-continuation - is
what broke it. My earlier /bin/sh test only "passed" because it ran the already-joined
string and skipped hyprlang entirely. The greeting always worked because it has none of
that.

So the message is now the simplest thing that can render: ONE line, no continuations, no
backslash-n, no pipe, no nested $( ). Just:

    text = cmd[update:20000] shuf -e -n1 "msg" "msg" "msg" ...

shuf -e treats each argument as a candidate and prints exactly one, every 20s. Ran it the
way hyprlock will (the whole cmd through /bin/sh -c) - random line each time, clean. Time
buckets are dropped for now so it is guaranteed to show; once you confirm it renders I can
fold morning/lunch/evening back in around this same shuf -e call.

IMPORTANT - this file is read by hyprlock, NOT by Quickshell. Clearing the qmlcache does
nothing for it. To actually get the new message you MUST refresh the live file:
  1. re-run install.sh  (it overwrites ~/.config/hypr/zen-hyprlock-ui.conf on diff, backup kept)
  2. zen-hyprlock-doctor --ui
  3. lock and check (undo: zen-hyprlock-doctor --undo)
If it has looked unchanged across hf157-hf160, this is almost certainly why: the live conf
was never refreshed.

### Files
hypr-config/zen-hyprlock-ui.conf (message -> single-line shuf -e) , ZenVersion.qml (hf161).

---

## v8.0.0-alpha-hf160 - Glass+ keeps the white glass; the TEXT goes dynamic

You picked option C, and you were right - the dark-glass of hf159 lost the feel. So the
white glass is back, and readability comes from the text adapting instead of the frost.

### White glass restored
`clearFill()` is plain white frost again (rgba(1,1,1, glassFill)) - the exact glass you
liked. The hf158/hf159 smoke is gone.

### Text + icons auto-contrast against the panel
LookService computes the effective panel luminance (the wallpaper, lightened by the white
frost on top) and derives three inks - clearInk / clearInkDim / clearInkFaint - that flip
on a 0.42 pivot: dark near-black ink on a light/medium panel, crisp white on a dark one.
iconTint uses the same, so icons never go white on a light panel while the text went dark.

The reach is the point: ThemeService.fg / grey0 / grey1 / grey2 are now COMPUTED - on the
clear look they return the auto-contrast inks, everywhere else they equal the theme values
byte-for-byte. Since every component already reads those four, the whole shell adapts from
ONE place - no 114-file sweep, and non-clear looks are untouched. Raw theme values live on
as _fgBase etc. (what gets saved/loaded), and LookService.clearInk* read only PanelState +
WallpaperServiceV5, so there is no binding cycle.

Why dark-on-light (not the "white on bright" you pictured)? White text on a light panel is
the low-contrast case - on a ~0.5 panel near-black scores ~3.7 to white's ~1.8. Dark-on-
light is what actually reads; white is kept for genuinely dark panels. Pivot is one number
if it leans wrong on your set.

### Files
zen-shell/LookService.qml (white clearFill + clearPanelLuma + clearInk/Dim/Faint + iconTint) ,
zen-shell/ThemeService.qml (fg/grey0/grey1/grey2 computed from _base, clear-aware) ,
ZenVersion.qml (hf160). Static-verified (balances, no cycle, contrast math). Nuclear-clear
the qmlcache: rm -rf ~/.cache/quickshell.

---

## v8.0.0-alpha-hf159 — lock message actually renders + Glass+ readable on a mid wallpaper

### The daily lock message shows now (and no stars)

The hf154 message nested a multi-line `$(printf '%s\n' \ <line> \ <line> … | shuf -n1)`
— too many backslash-continuations for hyprlang to fold into valid shell, so /bin/sh got
a malformed command and printed nothing. (The greeting is simpler, which is why IT showed
and the message did not.) Each bucket's pool is now ONE line — only the bucket if/elif
continues, exactly like the working greeting — and the output is plain text: no Pango
markup, no ✨ ("wala yun mga stars stars"). Still time-bucketed, still 20s rotation.
Simulated hyprlang's line-join and ran it in /bin/sh across all five buckets: every one
returns a message. (Pango markup itself is fine in hyprlock — the Shutdown/Restart/glyph
labels use it and render; the message's problem was purely the malformed join.)

### Glass+ stays readable on a medium wallpaper

hf158 detected wallpaper luminance and smoked the frost, but the ramp started at 0.50 —
and a medium wallpaper like the beach one sits ~0.5, so it never triggered: white frost
over a mid-tone wallpaper reads as a muddy mid-grey, the worst case for any text colour
(which is why the sidebar came up faint). Two changes, both in the one central helper:

- **Smoke ramps earlier + reaches full sooner** (starts 0.30, full by 0.45). Genuinely
  dark wallpapers (< 0.30) still keep the pure white glass; anything medium-or-brighter
  is pulled to a real dark panel.
- **The smoked end is darker and much more opaque** (0.70), so the panel lands dark
  (~0.2–0.35 effective over the wallpaper) instead of mid-grey — which is what lets the
  existing light theme text (primary AND the secondary greys) read.

No component touched — every surface already routes through `clearFill()`, so the whole
shell adapts from one place. Verified by luminance math: dark wall → white glass; Paul's
~0.5 beach → dark panel ≈0.22; a white wall → ≈0.38. All comfortably readable.

Why not "just flip the text colour dynamically"? Because a mid-grey panel defeats *every*
text colour — neither white nor black reads on 50% grey. The fix has to move the panel
off mid-grey, and darkening it (keeping your light text) is the clean, central way.

### Files

`hypr-config/zen-hyprlock-ui.conf` (message rewritten, single-line pools, no stars) ·
`zen-shell/LookService.qml` (smoke ramp + opacity retuned) · `ZenVersion.qml` (hf159)

Static-verified + message run in /bin/sh across all buckets. Nuclear-clear the qmlcache:
`rm -rf ~/.cache/quickshell`.

---

## v8.0.0-alpha-hf158 — Glass+ that stays readable on a bright wallpaper (smart)

Your call: "hindi ba kaya smart detect natin?" — yes. Instead of forcing one look, the
clear frost now adapts to the wallpaper.

### The problem

Glass Advanced+ paints panels as a white frost, and turns icons/text white to match.
Over a dark wallpaper that reads fine (the Hyprland blur behind is dark). Over a bright
or white wallpaper it's white-on-white and the text disappears — which is what you saw.

### Smart readability

`WallpaperServiceV5` now measures the wallpaper's **mean luminance** (0 = black, 1 =
white) with ImageMagick — it reduces the image to a single grey pixel and reads its
value. That runs on every wallpaper switch and once on start, and the value is persisted
in `wallpaper-v5.json` so it's known immediately next boot (no white-glass flash before
detection). No ImageMagick installed → it exits empty and the luminance stays at its
default, so the frost simply behaves exactly as before (safe fallback).

`LookService` turns that into a **smoke ramp** on the clear look:

- luminance ≤ 0.50 → smoke 0 → the **same white glass as before** (dark wallpapers are
  completely untouched — byte-identical to hf157)
- luminance ≥ 0.82 → smoke 1 → a **smoked panel** (dark tint, slightly more opaque), so
  white text and icons stay legible over the bright wallpaper
- in between, a smooth blend of both the tint and the opacity

One helper, `LookService.clearFill()`, is the single source of the clear-look fill, so
every surface that already routed through `panelColor()` / `bodyColor()` — the bars,
dock, start menu, notifications, calendar, control panel — adapts at once. The desktop
widget bodies (`DesktopWidgets._bodyBg`) call the same helper, so they match. Non-clear
looks (Zen / Classic / Glass / Minimal / Custom) never touch any of this.

Verified end-to-end (the build box happens to have ImageMagick): white → smoke 1,
`#1a1a2e` dark wall → smoke 0 (untouched), `#e8e4dc` light wall → smoke 1, and a path
with spaces/`&`/parens parses correctly.

### Tuning

If the smoke comes in too early or too late, the two knobs are the `_smoke` thresholds
in `LookService.qml` (0.50 / 0.82) and the smoked-end colour/opacity in `clearFill()`
(`0.12,0.12,0.16` at `0.34`). Say the word and I'll dial it.

### Files

`zen-shell/WallpaperServiceV5.qml` (luminance detector + persistence) ·
`zen-shell/LookService.qml` (`_smoke` ramp + `clearFill()`, used by panelColor/bodyColor) ·
`zen-shell/DesktopWidgets.qml` (`_bodyBg` routes through `clearFill()`) ·
`ZenVersion.qml` (hf158)

Static-verified (balances) + the luminance detection tested for real. Nuclear-clear the
qmlcache to see it: `rm -rf ~/.cache/quickshell`.

---

## v8.0.0-alpha-hf157 — lock screen wears your wallpaper, weather survives offline

Three of the four you flagged. The fourth (Glass Advanced+ text vanishing on a white
wallpaper) is a genuine look decision — asked separately rather than changed blind.

### Weather never comes up null offline

Two real gaps, both fixed in `WeatherService.qml`:

- **`hourly` was never cached.** `saveCache()` wrote `forecast` (the 7-day) but not
  `hourly` (the 24-hour), and the loader only restored `forecast`. So the 24h strip
  came up empty on every restart until a live fetch landed. It's in the cache now, and
  restored on load.
- **The 6-hour freshness gate nulled everything past 21600s.** That's exactly when you
  most want the last reading — no net after a long downtime. Restore is now
  UNCONDITIONAL (like `history` already was): temperature, forecast, hourly, the lot,
  regardless of age. `lastUpdated` still shows how old it is, and the 30-min timer keeps
  refreshing; a failed fetch is a caught parse of empty curl output, so it leaves the
  last values untouched (never wipes to null).

Net: restart or login with no net → the widget shows the last-known 7-day + 24h
immediately, and quietly updates when the network returns.

### Lock background is your current wallpaper

hyprlock reads a static config — there's no command substitution in its `path=`. So
`zen-hyprlock-ui.conf` gets one `$zenWall` variable and a `background { path = $zenWall
… }` block, and `WallpaperServiceV5` keeps that line pointed at the live wallpaper: it
rewrites it on every wallpaper switch (`applyWallpaper`) and seeds it once on shell
start. The rewrite uses `awk` with the path as a positional arg — never interpolated —
so a path with spaces, `&`, or regex characters is safe (verified against
`My Wall & Co (v2).jpg`). If `$zenWall` is ever empty, the block's `color` fallback
stands in, so the lock never comes up broken. A little blur + slight dim so foreground
text stays readable and it reads as "lock", not "desktop".

### The daily line (and all lock text) reads on any wallpaper

Every lock label is white ($zenInk / $zenDim) — invisible over a bright wallpaper, which
is likely why the random message looked missing. The clock, greeting, and random
message now carry a soft drop shadow (`shadow_passes/size/color`), so white text reads
over anything. The message itself was already correct (same `\`-continuation pattern as
the working greeting, valid Pango) — if it still doesn't appear after this, your live
`~/.config/hypr/zen-hyprlock-ui.conf` predates it: re-run the installer (it overwrites
on diff, with a backup) and `zen-hyprlock-doctor --ui`.

### Files

`zen-shell/WeatherService.qml` (cache hourly + unconditional restore) ·
`hypr-config/zen-hyprlock-ui.conf` ($zenWall + background block + label shadows) ·
`zen-shell/WallpaperServiceV5.qml` (`_syncLockWallpaper` on apply + seed on start) ·
`ZenVersion.qml` (hf157)

Static-verified only (brace/paren/bracket balance, JSON round-trip, awk-rewrite
simulated against a nasty path). **hyprlock can't run in the build box** — test the lock
with a terminal open before trusting it, and `zen-hyprlock-doctor --undo` reverts.

---

## v8.0.0-alpha-hf156 — widgets that remember, a pixel weather, and tabbed settings

Four things you asked for, shipped as one batch. Additive throughout — **wala tayong
binawas**, everything from the old layout is still there, just grouped.

### 1 — Open-state survives a restart

*"kapag open ko yan kahit mag-restart ako, kung open yan dapat open padin — same din
sa merged."*

The weather card's expanded state, the pixel blob's view, and the merged Glance's
view now persist. The subtlety here is the save path: **two** serializers both write
the whole `widgets-state.json` — `DesktopWidgets.qml` (on drag/expand) and
`WidgetsPage.qml` (on a settings change) — and if one omits a field, the other's save
wipes it. So the open-state lives in a new top-level `open: { weatherExpanded,
weatherPixelView, glanceView }` that **both** serializers read and write.
DesktopWidgets owns the live values; WidgetsPage round-trips them untouched, so saving
a setting can never clobber whether a widget was left open. On load the values are
pushed onto the widgets *after* positions are applied, so a widget that was expanded
lifts against its real resting spot. A one-shot `_applyingOpen` guard stops the restore
from echoing back into another save.

While in there I also made the two serializers agree on the weather object —
DesktopWidgets was writing `weather:{enabled}` while WidgetsPage wrote
`{enabled,mode,location}`, so a drag could quietly drop your manual location. Both now
write `{enabled,mode,location,style}`.

### 2 — Weather Pixel style

The weather widget gets a **Style** dropdown: *Standard card* or *Pixel blob*. The blob
isn't a new renderer — it's the existing `ZenGlanceWidget` instantiated weather-only
(`sysmonEnabled:false`). Its `toggleFace()` already no-ops when sysmon is off, so the
system face is unreachable: you get the porcelain 27° blob and nothing else. **The
system monitor is not in it** — sysmon only ever joins weather in the *merged* Glance,
exactly as before. The pixel weather shares the standard card's position slot
(`weatherPosX/Y`), so flipping Standard⇄Pixel never moves it.

### 3 — Theme on the weather widget

Accent already had Default / Theme-synced / Custom, and the background already had a
Theme-synced mode. hf156 carries that theme through the new pixel blob: its surface
follows the weather background setting (theme → `ThemeService.bg1`, custom → your
colour, else porcelain), its accent is the weather accent, and its ink auto-contrasts.
So "theme" now works in both weather styles.

### 4 — Tabbed widget settings

The Desktop Widgets page was getting long. It's now four tabs — **Home / Weather /
Clock / Sys Monitor** — with Home holding the shared band you described, *"widget
display till widget colors"* (display, scale, fonts, per-widget scale, colors), plus
the merge-blob master and positions. This is done the safe way: every section is the
same `HMSection` as before, just gated with `visible: uiTab === …`. No section was
moved or rewritten, so nothing can regress.

### Files

`zen-shell/DesktopWidgets.qml` (weather passthrough + style + open-state schema on both
serializers; weather-only pixel blob; placement; open-state persist/restore) ·
`zen-shell/WidgetsPage.qml` (style + open passthrough schema; tab bar; per-section tab
gates; Style dropdown) · `ZenVersion.qml` (hf156)

Static-verified only (brace/paren/bracket balance, JSON round-trip, schema symmetry) —
QML/Quickshell can't run in the build box, so nuclear-clear the qmlcache and test on
the rig.

---

## v8.0.0-alpha-hf155 — glass that survives the login

*"pre napansin ko kapag nag-login nawawala yun 100 percent glass, need ko pa ulit
i-rescroll, paki-ayos."*

This one was a startup race, and it's the kind that only ever shows at login.

The frost you see on the panels is two things stacked: a neutral white fill painted
by the shell (that part is a live binding, always correct), and a real Hyprland blur
underneath it. The blur is a `layerrule` — the shell pushes it with
`hyprctl keyword layerrule "blur 1, ignore_alpha …, match:namespace ^(zen-shell-.*)$"`.
The rule matches the shell's layer surfaces by namespace.

At login, the singleton that owns that rule runs its one-shot apply the moment it
finishes loading — which is *before* Hyprland has actually mapped the `zen-shell-*`
layers. So the rule matched nothing, and the panels came up with the fill but no
blur: the "100% glass" looked gone. The reason nudging the Glassiness slider fixed it
is that any slider move re-fires the exact same `hyprctl` — by then the layers exist,
so the second time it lands. You were manually re-applying it.

Fix: the shell now re-issues the layerrule a handful of times over the first ~3.5s
after startup (700ms apart, five times), on top of the original one-shot. Whichever
attempt first runs after Hyprland has the layers up is the one that sticks. It's
idempotent — every run just re-sends the same keyword with the current `ignore_alpha`,
so on any look it's harmless, and once the rule has landed the extra sends change
nothing. No slider-nudging, glass is correct straight out of login.

### Files

`zen-shell/LookService.qml` (startup re-apply of the blur layerrule) · `ZenVersion.qml` (hf155)

---

## v8.0.0-alpha-hf154 — the lock screen tells the time of day

*"yun sa hyprlock natin, dati may random message ako depende din morning lunch
evening late night, tas may random messages siya na pang-inspiration … 'Good morning
Paul' tas sa ibaba niyan may mga messages siya per nag-hyprlock."*

You already had the bones of this since hf140 — a time-aware greeting and a rotating
message. But the greeting only knew three parts of the day (morning / afternoon /
evening) and the message pool was one flat list, the same at 3am as at noon. This
makes both of them actually track the clock, the way you remembered it.

### The greeting — five buckets, not three

`date +%H` now sorts into five windows, each with its own line and emoji:

- **05–10** — "Good morning, Paul ☀️"
- **11–13** — "Good afternoon, Paul 🍜" (lunch)
- **14–17** — "Good afternoon, Paul 👋"
- **18–21** — "Good evening, Paul 🌆"
- **22–23** — "Good evening, Paul 🌙"
- **00–04** — "Working late, Paul 🌙" (the small hours get their own line — you're
  usually the one awake for these)

The name logic from hf140 is untouched: GECOS real-name first, login name as
fallback, first letter capitalised either way (paul / Paul / "Paul Yuki" all land as
"Paul"). It still refreshes on a 60s timer, so if you're locked across a boundary the
greeting turns over with the hour. And it stays base-10-safe in the `[ ]` test — no
`$(( ))`, so 08/09 never trip the octal trap.

### The message — same buckets, themed pool

The line under the greeting now picks from a pool that matches the greeting's window,
so the tone fits the hour: morning is "fresh start" energy, lunch nudges you to step
away, evening winds down, and the small hours get the "don't forget to sleep" ones.
It's the same 20s rotation hf143 set, so a longer lock still cycles through a few.

Additive, wala tayong binawas: **every hf152 quote is still in here, verbatim** —
"Stay focused, keep pushing forward.", "Progress beats perfection.", "Consistency
compounds.", and the rest — just filed into the hours they suit, with new
time-specific lines added around them. `shuf -n1` draws one from the current bucket.

### Verified

Both blocks were run the way hyprlock runs them — the label `cmd[…]` collapsed to a
single line and handed to `/bin/sh -c` — at nine spoofed hours spanning every
boundary (02, 07, 09, 12, 13, 16, 19, 21, 23). Every hour returned clean, non-empty,
with valid Pango markup and the em-dashes / apostrophes intact. `sh -n` passes on both.

### Files

`hypr-config/zen-hyprlock-ui.conf` (greeting + message buckets) · `ZenVersion.qml` (hf154)

---

## v8.0.0-alpha-hf153 — the last two slabs, and a guard for your panels

*"yung advanced glass + natin sa shell look dapat ma apply din dito sa weather and
system monitor except sa merged nila … kapag mag install.sh if current settings na
ko wag mo papatungan yun profile kasi nawawala yun settings ko sa qml bar ko panels."*

### The weather and system-monitor cards finally join the glass

Everything else already frosts on Glass+ — the dock, both bars, the Control Center,
the start menu, notifications, the desktop panel (hf144–hf152). The two DESKTOP
widgets never read the look, so on the clear look they sat there as solid dark boxes
floating over frosted glass. That's the last inconsistency, and it's gone.

Both cards now follow the exact same material the shell panels use: a neutral white
frost body (Hyprland blur is the material, no theme tint), no hairline border (the
blur defines the edge), and the inner tiles a touch brighter than the body so they
lift off it as raised frosted tiles. That covers:

- **Weather** — the card body, and the 7-day forecast tiles. "Today" keeps its
  accent so it still reads as today; the other six days frost.
- **System monitor** — the card body, and all seven metric/sparkline cards
  (the 2×2 CPU/GPU/RAM/NET overview grid plus the per-tab detail cards).

### One helper, one gate — nothing else moves

All of it routes through four tiny helpers on the `DesktopWidgets` root
(`_bodyBg` / `_bodyBorderC` / `_bodyBorderW` / `_tile`), each gated on
`LookService.isClear`. Off the clear look they return the caller's ORIGINAL value —
so on Zen, Classic, Glass, Minimal and Custom these widgets render byte-for-byte
identical to hf152. The frost fill tracks the same `glassFill` curve as the rest of
the shell, so dragging the frost slider moves the widgets with everything else.

The **merged Glance blob** (`ZenGlanceWidget`) is deliberately untouched — that's
its own Pixel-blob material and it's what you meant by "except sa merged nila."
Wala tayong sinira.

### Profile guard — reinstall keeps your hands off my panels

The installer's `*.qml` copy already skipped `*.json`, but the one-shot migrations
(powerbadge → `bar-layout.json`) could still rewrite your bar layout on a reinstall,
and that's what was eating your panel settings.

New in install.sh: right after the state files are validated and before any
migration runs, your **already-valid** `panel-state.json` and `bar-layout.json` are
snapshotted into `~/.config/quickshell/zen-shell/.profile-guard/`. After every
migration has run and the JSON has been re-verified, those two files are restored
verbatim — the migration's version is kept beside them as `*.migrated-<ts>` (nothing
is destroyed), then your originals go back. Net result: a reinstall leaves your QML
bar panels exactly as you left them.

Scope is narrow on purpose — only the two files you named. `widgets-state.json` is
NOT guarded, so the additive `glance` seed still lands for first-time installs. On a
first install there's nothing to snapshot, so the guard is a silent no-op. Want the
new default layout on an existing box? `ZEN_ALLOW_PROFILE_MIGRATE=1 ./install.sh`.

### Files

`zen-shell/DesktopWidgets.qml` (Glass+ helpers + weather/sysmon frost) ·
`install.sh` (profile-guard snapshot + restore) · `ZenVersion.qml` (hf153)

---

## v8.0.0-alpha-hf152 — the eye comes off, the wash comes off

*"yun password show hindi pa rin clickable, kaya ba yan sa hyprlock? … yun overlay
effect black, pangit, alisin mo na … zen-fuzzel-glass paki sama sa install.sh,
para sa production, dapat comfy."*

### The eye — no, hyprlock can't, and now it's gone

I'll say it plainly one more time: hyprlock cannot reveal a password. `input-field`
has no `onclick` (`CLICKABLE("input-field")` is zero in the source), and
`hide_input` is read exactly once at widget construction — there is no runtime
path from a click to the password buffer. The eye was decoration that looked like a
button, which is worse than no eye. It's removed, along with its `$zenEyeColor`
variable. The lock glyph on the left stays — it's honest, it claims nothing.

### The black overlay

The dim scrim shipped at `rgba(0,0,0,0.35)` — the grey wash over your wallpaper.
It's `rgba(0,0,0,0.0)` now: off. The variable and its presets are still documented
in the file, so raising the alpha brings back a dim if you ever want one, but the
default is a clean, undimmed lock screen.

After both changes the config still has exactly its 1 input-field, 2 power pills,
clock, greeting, message and lock glyph — verified against hyprlock's schema and
hyprlang's parser, with every `cmd[]` label executed.

### fuzzel, for real users

You were right to push on this: a preset that only works on the machine that built
it is no good. Confirmed end-to-end on a clean layout — the install shim symlinks
`scripts/`, the copy loop lands `zen-fuzzel-glass.sh` in `~/.local/bin`, and a
fresh `fuzzel.ini` thins to `ffffff3b` on Glass+. A new user runs `install.sh`
once and the launcher is glass with everything else; if they've never set up
fuzzel, the `-x` guards make every call a silent no-op. Comfy.

### Files

`hypr-config/zen-hyprlock-ui.conf` (eye removed, scrim off) · `ZenVersion.qml`

---

## v8.0.0-alpha-hf151 — fuzzel, done right and actually installed

*"bat ganito, dapat kasama na din sa install.sh natin, fuzzel ko yan."*

Two things were wrong with hf150's fuzzel support.

### It thinned the wrong colour

The script rewrote only the alpha byte of the theme's background. On your light
theme that's `fdf6ed` (cream), so the launcher became translucent *cream* — while
every shell panel on Glass+ is a neutral **white** frost. It wouldn't have
matched even once installed.

It now writes the whole background to `ffffffAA` on Glass+ — the same white frost
the panels use, independent of theme — and on any other look restores the theme's
real `bg0` (read via `jq`, or a `grep`/`sed` fallback when jq isn't around).

```
dark theme  1a1c1eff  ─┐
light theme fdf6edff  ─┼─ Glass+ ─→  ffffff3b   (white frost, matches panels)
             off Glass+        ─→  <theme bg0>ff  (restored)
```

### It was never going to install

More to the point: the script lives in `zen-shell/scripts/`, and `install.sh`
copies from `$SCRIPT_DIR/scripts/`. That works only because the install shim
symlinks `scripts/ → zen-shell/scripts/` before the copy loop — which it does
(line 69, well before line 2703). I verified the whole path end-to-end this time:
the file is in the drop, it's in the install list, and a sandbox run of the copy
step lands it in `~/.local/bin`.

So: run this build's `install.sh` once. That installs `zen-fuzzel-glass.sh`, and
`ThemeService` calls it on the next theme regen or look change. Until it's
installed, the ThemeService call is a silent no-op (the `-x` guard) — which is
exactly why yours was still opaque: the script wasn't on disk yet.

### Verified

Tested on both a dark and a light theme (both → `ffffff3b`), `--opaque` restore
with and without jq, and idempotency. `qmllint` clean on all 195 files;
`install.sh` and the script both `bash -n` clean.

### Files

`zen-shell/scripts/zen-fuzzel-glass.sh` (white frost, jq-less restore) ·
`ZenVersion.qml`

---

## v8.0.0-alpha-hf150 — the last solid slabs: menus, clock, and fuzzel

*"sa fuzzel ko need mo din update, dapat glassy din … sa clock ko now black yung
effect … yun pop-up neto paki update dynamically din, taskbar din yun right-click."*

### Three more QML surfaces

The session menu (`DockPowerButton`), both taskbar right-click context menus
(`Taskbar` — running-app and pinned), and the clock module (`Clock`) all still
painted a solid theme body. They route through the `bodyColor` helpers now, so on
Glass+ each is frosted white with no border. The clock in particular read as a
black pill over a light wallpaper; on the clear look it's glass, and hover still
flips to the blue accent.

### fuzzel is a different animal

fuzzel is not part of the shell — it's a separate launcher with its own
`~/.config/fuzzel/fuzzel.ini`, rewritten by `regen-terminal-themes.sh` from the
theme. That script always writes an **opaque** background, so on the clear look
the launcher stayed a solid black slab.

A new drop-in, `zen-fuzzel-glass.sh`, runs after regen and rewrites **only the
alpha byte** of the `[colors]` background — RGB kept, every other key untouched,
idempotent. On Glass+ it thins the alpha to match the shell frost; off Glass+ it
restores `ff`. fuzzel blurs its own layer when the compositor does, so a low alpha
reads as frosted glass. `ThemeService` fires it on theme regen and on any look or
frost change.

```
before:  background=1a1c1eff   (opaque black)
Glass+:  background=1a1c1e3b   (RGB kept, ~23% — frosted)
opaque:  background=1a1c1eff   (restored off the clear look)
```

Tested against a sample `fuzzel.ini`: only that one line's last two hex digits
move, and running it twice is a no-op. Installed to `~/.local/bin` alongside the
other regen scripts.

### The set is now fourteen surfaces

The eleven from hf149 plus the **power menu**, the **taskbar context menus**, the
**clock**, and **fuzzel** — every panel, menu, bar and even the external launcher
follows one look, frosted-white on Glass+, untouched everywhere else.

### Files

`DockPowerButton.qml` · `Taskbar.qml` · `Clock.qml` · `ThemeService.qml` ·
**`zen-shell/scripts/zen-fuzzel-glass.sh`** (new) · `install.sh`

---

## v8.0.0-alpha-hf149 — the right notification panel, the whole panel, and the title bars

*"yun notification qml natin, nung check ko ganito pa rin, hindi nabago … sa
hyprbars apply din natin yun glassy look … sa hypr control panel sa buo paki apply
pati color na pang-glass."*

### I frosted the wrong notification file

hf148 wired `ZenNotificationCenter.qml`. But that is the notification section
*inside the calendar flyout* — the popup you actually see when a notification
arrives is `NotificationListPanel.qml`, a different component (`shell.qml`
instantiates it at line 3141). It still painted `bg0 @ 0.98`, solid. That is why
nothing changed for you.

`NotificationListPanel` is frosted now, through the same `bodyColor` helpers. The
one I edited in hf148 stays wired too — both notification surfaces follow the look,
but this is the one on screen.

### The whole Control Center

`ZenDashboard` — the Control Center window itself — painted `bg0 × dashOpacity`.
Now it routes through `LookService.bodyColor`, so on Glass+ the entire panel is
frosted white glass with no border, the glass colour included, not just the cards
inside it.

### The window title bars

Hyprbars is a Hyprland plugin; its bar colour comes from a config block
`HyprbarsService` generates from `ThemeService.bg1`. On Glass+ that block now emits
a translucent white instead — `rgba(ffffffAA)` — with the alpha riding the same
frost slider:

```
frost   0% → rgba(ffffff4d)   white @ 0.30
frost  50% → rgba(ffffff3b)   white @ 0.23
frost 100% → rgba(ffffff29)   white @ 0.16
```

A thin title bar needs a little more body than a big panel to stay legible, so the
bar's alpha sits a touch above the panels' (0.30→0.16 vs 0.22→0.10). When you
switch looks or drag the frost slider, `HyprbarsService` rewrites its config and
the bars re-colour — a `Connections` block on `LookService` fires the rewrite.

Driven live: on a non-clear look the bar stays the theme `bg1`; on Glass+ it's
`rgba(ffffffAA)` at every frost level.

### The set is now eleven surfaces

desktop panel · notification toast · dock · top bar · vertical bar · notification
centre (calendar) · calendar popup · start menu · **notification panel (real)** ·
**Control Center** · **hyprbars** — all through one look, all frosted-white with no
border on Glass+, all untouched on every other look.

### Files

`NotificationListPanel.qml` · `ZenDashboard.qml` · `HyprbarsService.qml`

---

## v8.0.0-alpha-hf148 — frosted everywhere, and a floor that never fully clears

*"start menu kapag open ganito dapat lagi … yung default gawin natin smart, wag
hahayaan na transparent talaga kasi not good … calendar din … sa notification
dapat apply din."*

Three surfaces still painted a solid theme body on Glass+ while the rest had gone
frosted: the start menu's app panel, the notification centre, and the calendar
popup. They now use the same `LookService.bodyColor` / `bodyBorderColor` /
`bodyBorderWidth` helpers the dock and bars adopted in hf147 — so on the clear
look each becomes one frosted-white pane with no border, and on every other look
it's exactly what it was.

That closes the set. Eight surfaces now follow the look through one code path:

| surface | since |
|---|---|
| desktop icons panel | hf144 |
| notification toast | hf144 |
| dock body | hf147 |
| top bar body | hf147 |
| vertical bar body | hf147 |
| **notification centre** | **hf148** |
| **calendar popup** | **hf148** |
| **start menu** | **hf148** |

### The "smart" default

"Don't let it be fully transparent" — it can't be. The frost floor is `0.10`
(hf146), and switching into Glass+ seeds `0.5`, which is `fill 0.16`: a clear pane
you can always see. Even dragging the frost slider to 100% lands at `0.10`, not
zero. There is no setting that makes these panels vanish; the blur does the depth,
the floor guarantees the sheet.

### Verified

`qmllint` clean on all 195 files. All eight surfaces confirmed to route their body
through the look helpers, and the three new ones confirmed to drop their border on
the clear look. Rendered a before/after of the full set.

### Files

`ZenNotificationCenter.qml` · `CalendarButton.qml` · `StartMenuPanel.qml`

---

## v8.0.0-alpha-hf147 — the dock and bar bodies, frosted like the desktop panel

*"tingnan mo, butas-butas na, transparent na mismo … dapat approach existing pa
rin, blurry glassy ganun diskarte sa body ng qml bar and dock … iisang color lang,
d na mag-reflect yun themes … border color alisin mo na kapag glassy advanced+."*

### Why they went see-through

The desktop icons panel got the frosted treatment in hf144 and looks the way you
want. The dock and bars didn't — they still paint their body as
`bg0 × Theme.barOpacity`, and the Glass+ preset wrote `barOpacity` down to about
0.07. At that opacity a theme-tinted body is barely there, so the wallpaper reads
straight through: butas-butas.

The fix gives the bodies the same treatment the desktop panel already has. Three
small helpers on `LookService`:

```
bodyColor(fallback)        clear → white frost at glassFill · else fallback
bodyBorderColor(fallback)  clear → transparent            · else fallback
bodyBorderWidth(fallback)  clear → 0                       · else fallback
```

The dock, the top bar and the vertical bar wrap their existing colour/border
expressions in these. On the clear look the body becomes one frosted white fill —
**one neutral colour, no theme tint** — with **no border**. On every other look
the helper returns the caller's own value, so nothing changes off Glass+.

Proven in a real QML engine: on a non-clear look the body stays the theme value
(bg0 @ 0.07, 1px border); on Glass+ it's white frost at every frost level (0.22 →
0.10) with the border gone. And the wrap is reactive — Qt tracks `barOpacity` and
`bg0` through the function, so live changes still flow.

### Colourful icons on the glass

You want the Apple look — icons keep their colour, the glass does the work. So
Glass+ no longer flips white icons on when you switch into it. The white-icons
toggle is still there (hf146) if you ever want it, but it's off by default now,
and switching into Glass+ seeds a mid 50% frost instead of forcing mono.

### Files

`LookService.qml` (`bodyColor` / `bodyBorderColor` / `bodyBorderWidth`, Glass+
seeds frost not mono) · `ZenDock.qml` · `Bar.qml` · `BarVertical.qml`

---

## v8.0.0-alpha-hf146 — white icons, a quieter shell, a thicker frost

*"white lahat ng icons? … glass advanced+ naka clear pero pwede toggle: clear or
normal icons … alisin mo tingg … mga background wag masyado transparent."*

### White app icons, everywhere at once

The dock, the top bar and the vertical bar all render app icons through one file,
`Taskbar.qml`. The monochrome mode is a single wiring that lands in all three:
each icon's `Image` is hidden and a `ColorOverlay` draws in its place, flattening
every opaque pixel to `iconTint` while keeping the icon's alpha. The silhouette
survives; the colour is unified to white.

`ColorOverlay` is `Qt5Compat.GraphicalEffects` — the module the profile avatars
use (`OpacityMask`) in five shipped files, so it resolves on any real Quickshell
build. I first tried a base-Qt `ShaderEffect`, but Qt6's `fragmentShader` wants a
compiled `.qsb`, not an inline GLSL string — the overlay is the proven path here.

It's a real toggle (`PanelState.monoIcons`) on the Shell Look page under Frost.
Glass+ turns it on when you switch into it — the clear look wants uniform white —
but you can force white on any look, or keep colour on Glass+. Tint is white on
the clear look, the theme foreground otherwise. System-tray icons (network,
bluetooth) are left alone; those are status glyphs, not app icons.

### The frost was too clear at the top

```
          old fill    new fill
   0%       0.140       0.220     a clear card
  50%       0.090       0.160
 100%       0.040       0.100     still a visible pane
```

### The chime is gone

hf144 added a chime on notification arrival and on look-switch. Both removed. The
volume tick from hf145 is untouched.

### Files

`Taskbar.qml` · `LookService.qml` · `PanelState.qml` · `ShellLookPage.qml` ·
`ZenNotifyToast.qml`

---

## v8.0.0-alpha-hf145 — the volume slider had no voice

*"notification sounds — kapag nag-adjust ako ng sounds"*

Not the notification chime — the **volume tick**, the click you should hear each
time the volume moves. The keyboard keys made it. The slider didn't.

The tick lived in `onAudioVolumeChanged`, which is poll-driven: it fires when the
wpctl poll notices the volume changed underneath us. A hardware key changes the
sink, the poll sees it, the handler ticks. But the slider calls `setVolume()`,
which sets `audioVolume` **directly** — the handler's `!==` guard sees no change
by the time the poll echoes back, so it never ticked. Silent drag.

The tick moved to `setVolume()`, the user-initiated path, where we know the value
moved and know it was deliberate:

```
1. slider drag 30→40 at 60fps   -> 4 ticks over 160ms   feels continuous
2. hardware key +5 (via poll)   -> 1 tick               unchanged
3. drag sets 40, poll echoes 40 -> still 1 tick          no double
4. drag lands on 40 then 40     -> 1 tick                moved-check suppresses
```

Scenario 3 is why there's a `_selfSetMs` stamp: for 400ms after our own
`setVolume`, the poll handler stays quiet, so the echo doesn't tick a second
time. Hardware changes are outside that window and still tick.

### The throttle was eating the drag

`SoundEffectsService` throttles per event to stop scroll-spam. At 80ms, a 60fps
drag (an event every ~16ms) got one tick per five events — 20% cadence, which
reads as "some adjustments are silent". A volume tick is a discrete click; 45ms is
the floor before canberra samples overlap. It's per-event now, so login and
logout keep their wider window — they're one-shots and never drag.

### Verified

Both volume paths transliterated and simulated across four scenarios — drag,
hardware key, poll echo, and a repeat on the same integer — all pass: the drag
ticks continuously, nothing double-fires, and the same-value case is suppressed.
`qmllint` clean on all 195 files.

### Files

`ConnectivityService.qml` (tick on `setVolume`, self-set de-dupe) ·
`SoundEffectsService.qml` (per-event throttle)

---

## v8.0.0-alpha-hf144 — Glass Advanced+, the clear one

*"paki gawa new shell looks natin … wala na anything colors, as in clear siya
kapag glass advanced+ … tas may draggable siya kung gaano ka-glassy ganun."*

### A new look, not a tweak to Glass

`Glass — Advanced+` sits next to `Glass` in the picker. Where Glass holds a 0.58
fill and still shows the theme's colour through it, Glass+ drops the fill to a
near-invisible white and lets Hyprland's blur be the entire material. No tint, no
accent — clear.

The one flag that makes it different is `clear: true` on the preset. Every surface
gates on `LookService.isClear`: when it's set, `panelColor()` returns neutral
white at `glassFill` instead of the theme tint. One helper, called from each
surface, so there is a single definition of "what clear looks like".

### The frost slider drives fill *and* blur

You asked for draggable glassiness, and for it to be fill + blur with the border
left crisp. It is one knob:

```
glassStrength   panel fill α     Hyprland ignore_alpha
    0%             0.140              0.60      (a faint pane, blur only the solid bits)
   25%             0.115              0.475
   50%             0.090              0.350
   72%             0.068              0.240     ← default
  100%             0.040              0.100      (almost pure blur)
```

Driven live in a real QML engine across the sweep — the fill binding and the
`ignore_alpha` that goes to `hyprctl` both track the slider, and a non-clear look
ignores it entirely. The Hyprland reblur is debounced 120ms so a drag doesn't
spawn a `hyprctl` per pixel. The **border is deliberately off this curve** — a
fixed ~0.30 white so panels stay legible at 100% frost.

The slider only appears on the Shell Look page when Glass+ is active, since it's
the only look that reads it. Picking Glass+ seeds it to 72% once; your drags own
it after that, and re-picking Glass+ won't stomp a frost you've tuned.

### Two surfaces that weren't following any look

- **The notification toast** was hardcoded to `bg1 @ 0.95` — a solid box on every
  look. It reads `LookService.panelColor` now, so Glass and Glass+ finally reach
  it, with a neutral crisp border on the clear look.
- **The desktop icons panel** had its own `widgetLightGlass` toggle from hf134.
  That still works as a manual override, but with *Apply to → Desktop icons* on
  (default) the active look drives it — so the glass you liked there is now the
  same glass as everywhere else, Glass+ included.

### Sounds

Every look switch plays a `complete` chime, and a notification toast chimes on
arrival — `bell` for critical, `complete` for the rest. Both go through the
existing `SoundEffectsService` (freedesktop theme via canberra), both respect a
toggle, and the new notification toggle persists with the others. When you send
the sound design you mentioned, swapping the event IDs is a one-line change per
event.

### Verified

`qmllint` clean on all 195 files. The glass curve was read back out of the
shipped QML and driven live in an offscreen `QQuickView` — fill and `ignore_alpha`
both move with the slider, both bounded and monotonic, and non-clear looks are
unaffected. A surface×look matrix and a frost sweep were rendered from the shipped
numbers. Fourteen structural assertions cover the preset, the tokens, the
per-surface wiring and the sound toggles.

### Files

`LookService.qml` (Glass+ preset, `isClear` / `glassFill` / `glassBlur` /
`panelColor`, live blur) · `PanelState.qml` (`glassStrength`) ·
`ZenNotifyToast.qml` (follows look + chime) · `DesktopIconsWidget.qml` +
`DesktopIconsState.qml` (`lookApplyDesktop`) · `ShellLookPage.qml` (frost slider,
switch sound) · `SoundEffectsService.qml` (`playNotificationSound`)

---

## v8.0.0-alpha-hf143 — fifteen minutes, and a wall of dim

### The message never changed because it was set to change every 15 minutes

```
text = cmd[update:900000] …
```

`Label.cpp:59` arms a timer for exactly `updateEveryMs`. 900000ms is fifteen
minutes. Unlock inside that window — which is every time — and you see the message
that was drawn when the screen locked. It was never broken; it was set to a value
that makes it look broken. **20000** now.

`shuf` was doing its job the whole time: eight draws from the seven-message pool
give six distinct results.

### The scrim

hf141 made it `100%, 100%` because you asked for the whole screen. Percent is
viewport-relative, so on your 3440px monitor the dim scales *with* the width —
the wider the screen, the more of it goes black. That is the wrong direction.

Two variables now, three presets written into the file:

```
full bleed   $zenScrimSize = 100%, 100%   $zenScrimRound = 0
padded       $zenScrimSize = 76%, 88%     $zenScrimRound = 64   <- default
card         $zenScrimSize = 820, 620     $zenScrimRound = 44
```

Absolute pixels work too, and are the honest way to cap an ultrawide:
`$zenScrimSize = 1900, 88%`.

**A trap worth naming.** `$zenScrim` is a prefix of `$zenScrimSize`. If hyprlang
substituted variables shortest-first, `size = $zenScrimSize` would expand to
`size = rgba(0,0,0,0.35)Size`. It sorts longest-first (`config.cpp:539`), so this
is safe — but only by luck of that one line, and it is the kind of thing that
would have looked like a hyprlock bug.

### The eye. Once more, and then I will stop.

> *"yung show password kapag click ko hindi nag show yun password, tas kapag
> unclick ko … tska ma hide ulit"*

Click-and-hold to reveal, release to hide. That is a good design. hyprlock cannot
do it, and not because the toggle is hard to reach:

```cpp
// PasswordInputField.cpp:49 — the only write, at construction
hiddenInputState.enabled = std::any_cast<Hyprlang::INT>(props.at("hide_input"));

// :218  hide_input = true   -> paint one quadrant of the border
// :237  hide_input = false  -> draw dots
```

There is no branch that draws the typed characters. `dots_text_format` swaps the
dot's *shape* for a fixed string — the same string for every keypress, not your
password. `CLICKABLE("input-field")` appears zero times, so the field has no
`onclick`, and `onclick` on a label only does `spawnAsync(cmd)` — a shell command,
which cannot reach into hyprlock's password buffer.

To make this work, hyprlock needs a feature it does not have. I could wire the eye
to a command and let it do nothing when you click it. I would rather it stayed
honest paint.

```
$zenEyeColor = rgba(255,255,255,0.0)
```

That removes it. Say the word and it goes out of the shipped file.

### Files

`ZenVersion.qml` · `hypr-config/zen-hyprlock-ui.conf` (`update:20000`,
`$zenScrimSize`, `$zenScrimRound`)

---

## v8.0.0-alpha-hf142 — the advance, and the reveal that does not exist

### Why the icons were cut off

`hyprgraphics` renders a label into a cairo surface sized like this:

```cpp
// TextResource.cpp
pango_layout_get_pixel_extents(layout, &ink, &logical);       // line 81
…
m_asset.cairoSurface = makeShared<CCairoSurface>(
    cairo_image_surface_create(CAIRO_FORMAT_ARGB32, logical.width, logical.height));   // line 88
```

It asks Pango for the **ink** extents and then sizes the surface with the
**logical** ones. Logical width is the advance. Any ink past it is not in the
surface — it never gets drawn.

Measured in JetBrainsMono Nerd Font at `font_size = 18`:

```
glyph                  advance     ink x0..x1   clipped
lock       U+F023         10.8       0..15        4.2px on the right
eye_slash  U+F070         10.8      -1..21       10.2px on the right (+1px left)
```

The cell is 10.8px because the font is monospace. The icons are drawn wider than
their cell. So the right side of every standalone icon label is guillotined.

A **non-breaking space** either side fixes it — nbsp, not a plain space, because
a plain trailing space can be trimmed out of the logical rect:

```
&##xa0;&##xf023;&##xa0;    advance 32.4px   ink 0..32   clipped 0.0px
```

and the ink centre lands 0.2px from the box centre, so `position` doesn't move.
Both icons, unchanged coordinates.

The power and refresh glyphs inside the pills were never clipped — their overhang
runs into the spaces before "Shutdown", which are part of the same surface.

### The eye cannot be clickable, and this time here is why

I have said this twice and been vague about it. The precise statement:

**hyprlock has no plaintext password mode.** Not "the toggle is hard" — there is
nothing to toggle *to*.

`hiddenInputState.enabled` is written exactly once in the entire codebase:

```cpp
// PasswordInputField.cpp:49 — at widget construction, from config
hiddenInputState.enabled = std::any_cast<Hyprlang::INT>(props.at("hide_input"));
```

And what it selects between is not "dots" and "characters":

```cpp
// PasswordInputField.cpp:218 — hide_input = true: paint a border quadrant
if (passwordLength != 0 && !checkWaiting && hiddenInputState.enabled) { … }

// PasswordInputField.cpp:237 — hide_input = false: draw the dots
if (!hiddenInputState.enabled) { … RECTPASSSIZE … }
```

Nothing in that file draws the typed characters. `dots_text_format` replaces the
dot *shape* with a fixed string — the same string for every character, not the
password. `CLICKABLE("input-field")` appears zero times, so the field takes no
`onclick` either.

An eye that reveals the password would need a feature hyprlock does not have. I
am not going to wire an icon to a command that cannot do the thing the icon
promises.

`$zenEyeColor` is now a variable. Set its alpha to `0` and the eye is gone:

```
$zenEyeColor = rgba(255,255,255,0.0)
```

Say the word and I will take it out of the shipped file. The lock stays — it is
honest decoration; it claims nothing.

### Files

`ZenVersion.qml` · `hypr-config/zen-hyprlock-ui.conf` (nbsp padding, `$zenEyeColor`)

---

## v8.0.0-alpha-hf141 — remove the line, remove the box

### The duplicate was still there

hf140 stopped `install.sh` from *adding* a second `source =` line. It never
occurred to me to *remove* the one hf139 had already written. So a reinstall found
`zen-hyprlock-ui.conf` in the guard, said "already sources a zen include — left
alone", and walked past `source = …zen-hyprlock-power.conf` sitting right below
it. Two Shutdowns, two Restarts, forever.

The UI include contains the buttons. The power line is one *we* wrote. Remove it:

```
BEFORE:  ui=1  power=1
   ✓ removed a duplicate zen-hyprlock-power.conf source (the UI include has the buttons)
     backup: ~/.config/hypr/hyprlock.conf.bak.<ts>
AFTER:   ui=1  power=0
```

Idempotent on the second run, `background` untouched, your commented widgets left
commented.

### The box

*"yung shadow bakit may box, alisin mo yan — kala ko sa buong screen background yun black"*

Because it was a box. hf138 drew an 820×620 rounded `shape` behind the stack. You
asked for a darker screen and I gave you a card.

A layout value ending in `%` is multiplied by the viewport:

```cpp
// ConfigDataValues.hpp:48-53
return { (m_sIsRelative.x ? (m_vValues.x / 100) * viewport.x : m_vValues.x), … };
```

So the scrim is `size = 100%, 100%`, `rounding = 0`. Whole monitor. Set
`$zenScrim = rgba(0,0,0,0.0)` to turn it off.

**It cannot swallow the buttons.** I checked before shipping it:

```cpp
// hyprlock.cpp:714-717 — every widget under the cursor is asked
for (const auto& widget : widgets)
    if (widget->containsPoint(SCALEDPOS))
        widget->onClick(button, down, pos);

// Shape.cpp:119-122 — and a shape without an onclick does nothing
if (down && !onclickCommand.empty())
    spawnAsync(onclickCommand);
```

### And `systemctl poweroff` ran twice

That same loop is why. Both the pill `shape` **and** its `label` carried
`onclick = systemctl poweroff`, and a click on the text lands inside both. Two
spawns per press. Harmless for `poweroff`, ugly for anything else. The `shape`
owns the click now; the label is just paint.

### Files

`ZenVersion.qml` · `hypr-config/zen-hyprlock-ui.conf` (full-screen scrim,
`$zenScrim`, one `onclick` per pill) · `install.sh` (removes the stale source line)

---

## v8.0.0-alpha-hf140 — two includes, and a clock I had no business touching

### Why there were two of everything

`install.sh`'s guard:

```sh
grep -qE '^[[:space:]]*source[[:space:]]*=.*zen-hyprlock-power\.conf'
```

After `zen-hyprlock-doctor --ui`, your `hyprlock.conf` sources
**`zen-hyprlock-ui.conf`** — not the power include. The guard missed, install.sh
appended `source = …zen-hyprlock-power.conf`, and hyprlock parsed both. The UI
include already contains the buttons. Two Shutdowns, two Restarts.

Reproduced on your exact state:

```
before hf140:  ui source lines: 1   power source lines: 1
after  hf140:  ui source lines: 1   power source lines: 0
```

The guard matches **either** include now, and `zen-hyprlock-doctor --fix` refuses
to run at all when the UI is already wired. `--status` calls it out and hands you
the one-line fix.

**Fix your current install without reinstalling:**

```sh
sed -i -E '/^[[:space:]]*source[[:space:]]*=.*zen-hyprlock-power\.conf/d' \
    ~/.config/hypr/hyprlock.conf
```

### The clock

hf138 wrote `font_family = $zenFont` on the clock label — `Adwaita Sans`. Your
clock had always been the **Black** weight. This project's own installer says so,
at line 2195:

> *zen-lock.sh maps fontFamilyId → "Adwaita Sans Black" / "Inter Black" etc. to
> match the desktop widget clock weight.*

I read that line weeks ago, wrote the config, and set the regular weight anyway.
There is now a `$zenClockFont = Adwaita Sans Black` variable, used by the clock
and nothing else. Change it there if you ever want to.

### `paul` → `Paul`

`id -un` returns the login name, lowercase. The greeting reads the GECOS real name
first and capitalises the first letter either way. Executed against four name
shapes before shipping:

```
id -un=paul             -> Good afternoon, Paul 👋
id -un=Paul             -> Good afternoon, Paul 👋
id -un=juan-dela-cruz   -> Good afternoon, Juan-dela-cruz 👋
GECOS="Paul Yuki"       -> Good morning, Paul 👋
```

### Your geometry

The shipped `zen-hyprlock-ui.conf` is now yours: 820×620 card, 480×68 field,
250×66 pills, `-142,-182` buttons, your seven messages, your backslash
continuations. hyprlang joins a line ending in `\` (`config.cpp:67`), which I
confirmed before adopting them. All three `cmd[]` labels were executed with the
continuations resolved; all three emit what they should.

### Files

`ZenVersion.qml` · `hypr-config/zen-hyprlock-ui.conf` (rebuilt from your file +
`$zenClockFont` + capitalisation) · `hypr-config/zen-hyprlock-doctor.sh`
(`--status` flags double-sourcing, `--fix` refuses to double) · `install.sh`
(guard matches either include)

---

## v8.0.0-alpha-hf139 — no, you don't need to restart Hyprland

hyprlock reads its config **at launch**. Lock again — `hyprlock`, or your Super+L
bind — and the new stack is there. Nothing about Hyprland needs restarting, and
neither does the shell.

`zen-hyprlock-doctor --status` answers it without locking anything:

```
ui include : present (192 lines)
wired      : 1 source line(s)  (want exactly 1)
live widgets in hyprlock.conf: 0  (want 0 after --ui)

what the cmd[] labels render right now:
   04:02
   Good morning, Paul 👋
   <span size="13pt">✨</span> <i>Stay focused, keep pushing forward.</i>
```

### Four things I checked instead of assuming

Your doctor output said `hyprlock 0.9.5`, so `onclick` is there (0.9.0+). Then I
went looking for reasons the new config might be silently rejected.

**`placeholder_text = <span foreground="#ffffffaa">`.** Eight hex digits. Pango's
`pango_color_parse` accepts 3, 6, 9 or 12 — I was ready to call this a bug. But
markup goes through `span_parse_color`, which calls
`pango_color_parse_with_alpha(color, alpha, spec)` with a **non-NULL** alpha:

```c
case 4: case 8: case 16:
  if (!alpha) return FALSE;      // pango-color.c
```

`foreground` passes `&alpha` (pango-markup.c:1521). So `#rrggbbaa` is valid there.
`underline_color` passes NULL and would reject it. Left as it was.

**`$H`, `$G`, `$N` in the greeting's shell.** hyprlang substitutes `$name` only for
variables it has seen declared (`config.cpp:751`). Undeclared shell variables pass
through untouched.

**`cmd[update:60000] … if [ "$H" -lt 12 ]; …`** — the greeting's shell has a `]` in
it. hyprlock closes the option list at `in.find_first_of(']')` (IWidget.cpp:255).
First bracket, not last. Safe.

**Escapes.** hyprlang processes `##` → `#` and `{{ }}` expressions. Nothing else.
`printf '%s\n'` survives.

### The bug I did find

```
label {   # the clock
```

`is_open` required the line to *end* at the brace. With a trailing comment it
matched nothing, the block never opened, and its closing `}` drove the depth
counter to −1 — after which every widget in the file was invisible to the
migrator. hyprlock's own `assets/example.conf` writes blocks that way.

Structure is now read through a transliteration of hyprlang's comment stripper
(`config.cpp:688-716`), the same one that turns `&##xf011;` into `&#xf011;`. So a
comment can sit anywhere a comment can legally sit.

Retested: the trailing-comment config now migrates correctly, all seven earlier
configs still pass with zero live `onclick`, `--ui` still clears every widget,
and `sed 's/^##zen## //'` still restores the original byte-for-byte.

### Files

`ZenVersion.qml` · `hypr-config/zen-hyprlock-doctor.sh` (hardened migrator,
`--status`) · `install.sh` (same migrator)

---

## v8.0.0-alpha-hf138 — the whole centre stack

*"paki alis yun nasa ilalim … paki gawa ganito … lagyan mo ng show password eye
and lock icon sa left side"*

`zen-hyprlock-ui.conf` now draws the entire centre stack, so there is nothing
left to double:

| | |
|---|---|
| dim card | `shape`, 780×580, rounding 44, `rgba(0,0,0,0.30)` |
| clock | `date +"%H:%M"`, 112px |
| greeting | **one** line, time-of-day aware, your real name, one 👋 |
| message | **one** line, a rotating tip, one ✨ |
| password | 430×62 pill — not corner to corner |
| lock glyph | `nf-fa-lock` at the field's left inset |
| eye glyph | `nf-fa-eye_slash` at the right inset |
| power pills | 220×58, icon + label, symmetric padding |

Apply it with **`zen-hyprlock-doctor --ui`**. It comments out every one of your
`label` / `shape` / `image` / `input-field` blocks — including the pair pinned to
the bottom — takes a timestamped backup, and leaves exactly one `source =` line.
`--undo` puts all of it back. Your `background`, `general` and `auth` blocks are
never opened as candidates, so they are never touched.

Tested on a config shaped like yours: 6 widgets commented, `background` /
`general` / `auth` intact, 0 live `onclick`, 0 `zen-hyprlock-power.conf` source
lines, exactly 1 `zen-hyprlock-ui.conf` source line. `--undo` restored all 6.

### The `<span>` that was a shell redirection

I wrote the message label like this:

```
text = cmd[update:900000] <span size="13pt">✨</span> <i>$(… | shuf -n1)</i>
```

Everything after `cmd[…]` is handed to `/bin/sh -c`
(`MiscFunctions.cpp:146`), and its **stdout** becomes the label. So `<span …>` is
not markup there — it is a redirection. Running every embedded command for real:

```
[FAIL] rc=2   stderr: /bin/sh: 1: Syntax error: redirection unexpected
```

The markup has to be *printed by* the command:

```
text = cmd[update:900000] M=$(printf '%s\n' "…" "…" | shuf -n1); printf '<span size="13pt">✨</span> <i>%s</i>' "$M"
```

All three `cmd[]` labels now execute cleanly and emit what they should. So does
the greeting, which is why there is exactly one of it, with exactly one emoji.

### The eye is decorative, and I am not going to pretend otherwise

`input-field` takes `hide_input`, `dots_*`, `fail_text`, `swap_font_color` — and
`CLICKABLE("input-field")` appears **zero** times in hyprlock's source. There is no
`onclick` on the field, and `hide_input` is read once at startup. Nothing in
hyprlock can reveal a typed password at runtime.

The eye is drawn because you asked for it and it belongs in the design. It does
not toggle. Set `hide_input = false` in `zen-hyprlock-ui.conf` if you want the
characters visible from the start.

The lock glyph on the left is a plain `label` and works exactly as it looks.

### The darker layer

A `shape` cannot blur, so the dim card is a flat rounded rectangle at 30% black.
If you would rather darken the *wallpaper*, `background` has a `brightness` key —
add `brightness = 0.7` to your own block. I did not touch it.

### Files

`ZenVersion.qml` · **`hypr-config/zen-hyprlock-ui.conf`** (new) ·
`hypr-config/zen-hyprlock-doctor.sh` (`--ui`) · `install.sh` (ships the UI conf)

---

## v8.0.0-alpha-hf137 — two source lines, and a doctor

### Why you saw two sets of buttons

hf135 refused to touch your config and printed instructions:

```
2. append:  source = ~/.config/hypr/zen-hyprlock-power.conf
```

You did. Your old blocks stayed. Two pairs of buttons — exactly what the refusal
was meant to prevent, now caused by the refusal's own advice.

And hf136 would have made it worse. Its "already sourced" guard looked for its own
`# >>> zen-shell hyprlock power buttons >>>` marker, not for an actual `source =`
line. A hand-added line has no marker, so hf136 would have appended a **second**
one, hyprlock would have parsed the include twice, and every button would have
drawn on top of itself. Reproduced:

```
before: source= lines: 1
after hf136: source= lines: 2   <-- every widget drawn twice
after hf137: source= lines: 1
```

An **active** `source =` line now counts, marker or not.

### The doctor

We do not own `~/.config/hypr/hyprlock.conf`, and I have now guessed at its
contents three times. `zen-hyprlock-doctor` ends that:

```
$ zen-hyprlock-doctor

hyprlock: hyprlock 0.9.1
config  : /home/paul/.config/hypr/hyprlock.conf  (48 lines)
include : present
sources our include: 1 time(s)

widget inventory (top-level blocks):
lines  block       position         onclick   text / notes
7-14   label       0,200            -         cmd[update:1000] echo "$(date +%H:%M)"
15-22  label       0,95             -         cmd[update:60000] zen-lock-message.sh greet
23-29  input-field 0,-10            -
30-38  label       -120,60          systemctl <span font_family="JetBrainsMono …
39-47  label       120,60           systemctl RESTART
```

`--fix` comments out the power blocks and leaves exactly one `source =` line.
`--undo` puts everything back. Both take a timestamped backup.

Installed to `~/.local/bin/zen-hyprlock-doctor`.

### What hyprlock cannot do

You asked for a **show-password eyelid**. Checked against the schema: `input-field`
takes `monitor size inner_color outer_color outline_thickness dots_* fade_*
font_color font_family halign valign position placeholder_text hide_input
hide_input_base_color rounding check_color fail_color fail_text check_text
capslock_color numlock_color bothlock_color invert_numlock swap_font_color zindex`
— and `CLICKABLE("input-field")` appears **zero** times.

There is no `onclick` on the field and no reveal toggle. `hide_input` is a static
config value, read once at startup. An eyelid can be drawn as a `label`; it cannot
toggle anything. The lock icon on the left is a plain `label` and works fine.

I would rather tell you that than ship an icon that does nothing and let you
discover it.

### Files

`ZenVersion.qml` · `install.sh` (active-source guard, wider detection, doctor
install) · **`hypr-config/zen-hyprlock-doctor.sh`** (new)

---

## v8.0.0-alpha-hf136 — migrate, don't refuse

*"hyprlock buttons hindi padin nabago pre — kala ko nasama mo na ito sa tarball
and install.sh"*

It was in the tarball. It was in `install.sh`. It ran. And it **refused**, exactly
as I built it to:

```
⚠ hyprlock.conf already has its own power buttons — NOT sourcing ours.
```

Your config has `onclick = systemctl poweroff`, so the installer backed away
rather than draw a second pair of pills on top of yours. That was the safe answer
to the wrong question. You asked for the buttons to be fixed, not for a warning.

### Comment, never delete

A block-aware `awk` pass, embedded in the installer:

1. records every **top-level** `label` / `shape` / `image` block, its line range,
   its `position`, and whether it carries an uncommented
   `onclick = systemctl poweroff|reboot`;
2. marks those blocks — **plus every `shape` sharing a `position` with one**,
   because that is the pill behind the label and the idiom is that they overlap;
3. prefixes every marked line with `##zen## `. Nothing is deleted.

The original is backed up to `hyprlock.conf.bak.<timestamp>`, and one line undoes
the whole thing:

```
sed -i 's/^##zen## //' ~/.config/hypr/hyprlock.conf
```

`##zen## ` is a comment to hyprlang (a `#` in column 0 comments the line), and
the marker makes the undo a single unambiguous match.

`ZEN_HYPRLOCK_KEEP=1` restores hf135's refusal.

### The bug I wrote, found, and had to unwrite

First cut counted `{` and `}` on every line. Then I "hardened" it: ignore
everything after the first `=`, so a value like `text = ${USER}` could not
perturb the depth counter.

That broke hyprlock's **own example config**, on line two:

```
general { hide_cursor = true }
```

Truncated at the `=`, the counter saw the `{` and never the `}`. Depth was off by
one for the rest of the file and **nothing was detected**. My hardening was worse
than the bug it fixed. It only surfaced because a regression test still had that
line in it.

Structure is recognised by shape now, not by counting:

```awk
function is_open(l)  { return !iscomment(l) && l ~ /^[ \t]*[A-Za-z_-]+[ \t]*\{[ \t]*$/ }
function is_close(l) { return !iscomment(l) && l ~ /^[ \t]*\}[ \t]*$/ }
```

hyprlock blocks put the opener and the closer on their own lines. A one-line
block matches neither pattern and is ignored — which is exactly right, because a
one-line block cannot be a power button.

### Tested, seven configs

| config | result |
|---|---|
| shape **with** `onclick`, label with `onclick` | both commented |
| shape **without** `onclick`, matched by `position` | both commented |
| shape at an unrelated `position` | left alone, and **warned about** — an empty pill may remain |
| value containing `${USER} {x}` | clock label survives, braces ignored |
| `general { … }` one-liner + nested `auth { fingerprint { } }` | untouched |
| no power buttons at all | file byte-for-byte unchanged |
| already migrated | idempotent — no double prefix, one `source =` line |

Live `onclick` survivors after migration, across all seven: **zero**. The undo
`sed` restores the original byte-for-byte. All six exit paths of the installer
function leak no temp files. And `trap … RETURN` came out — it is a bashism, and
this file gets sourced in odd ways.

### Files

`ZenVersion.qml` · `install.sh` (`install_zen_hyprlock_power`, embedded migrator)

---

## v8.0.0-alpha-hf135 — the lock screen, without touching your lock screen

### The buttons ship, your config doesn't get eaten

We do not own `~/.config/hypr/hyprlock.conf`. The changelog has said so since
v7.0.0-beta.1-hf99f: *"hyprlock.conf is left to the user (visual config,
untouched)."* Overwriting it takes your wallpaper path, blur passes, monitor
rules, PAM config and the `$font` line `zen-lock.sh` rewrites.

So the buttons ship as **`hypr-config/zen-hyprlock-power.conf`**, and the
installer appends exactly one line to your file, between markers:

```
# >>> zen-shell hyprlock power buttons >>>
source = ~/.config/hypr/zen-hyprlock-power.conf
# <<< zen-shell hyprlock power buttons <<<
```

`source =` is real — `registerHandler(&handleSource, "source", …)` in hyprlock's
`src/config/ConfigManager.cpp`, with `~` expansion and globbing. **A missing
source file is a hard error**, so the include is installed first and the line
appended second, never the reverse.

Three refusals, on purpose, all tested in a sandbox:

| situation | what happens |
|---|---|
| no `hyprlock.conf` | install the include, print the line, **create nothing** |
| you already have power buttons | install the include, **do not source it** — you'd get two overlapping pills |
| already sourced | refresh the include, leave the line alone (idempotent) |
| clean config | back up, append the three-line block |

**That second row is you.** Your screenshot's lock screen already has Shutdown and
Restart, so the installer will refuse and tell you what to delete first.

### `&##xf011;`

The pill is a `shape` and the text is a `label`. A `label` has **no `size` and no
padding** — checked against hyprlock's schema; its only keys are `monitor
position color font_size text font_family halign valign rotate text_align zindex
onclick`. The shape and the label share the same `position`/`halign`/`valign`, so
the text is centred and the inner padding is `(shape_width − text_width) / 2` on
each side, symmetric by construction. 31px → 57px.

Then this, from hyprlang's `config.cpp:688-716`:

```cpp
auto commentPos = line.find('#');
...
if (!escaped) { line = line.substr(0, commentPos); break; }   // truncates
else          { line = line.substr(0,commentPos+1) + line.substr(commentPos+2); }  // ## -> #
```

A bare `#` **cuts the rest of the line**. My first draft wrote the Nerd Font power
glyph as the XML entity `&#xf011;`, which hyprlang would have truncated at the
ampersand — broken markup, no error. Simulating hyprlang's own parser over the
shipped file:

```
in : text = <span … rise="1400">&##xf011;</span>  <span …>Shutdown</span>
out: text = <span … rise="1400">&#xf011;</span>  <span …>Shutdown</span>
     glyph entity survived: YES

with a single '#':
out: 'text = <span … rise="1400">&'
     -> truncated. Broken markup, silently.
```

The file declares its own `$zenIconFont` / `$zenLabelFont` and never references
`$font`, so `zen-lock.sh` cannot rewrite it out from under you. Verified: zero
undeclared variable references, zero invalid keys, after running the config
through hyprlang's comment stripper.

Requires hyprlock **≥ 0.9.0** — `onclick` does not exist in 0.8.x. Checked the
tags.

### Light Paper theme

The sage palette, as a theme. All four source colours land verbatim in the
surface ramp — the palette read top to bottom:

| | | |
|---|---|---|
| `bg0` | `#fdf6ed` | cream |
| `bg2` | `#dccfc0` | beige |
| `bg3` | `#a1bc98` | sage light |
| `bg4` | `#778873` | sage dark |

`bg1` is the only interpolation, and it earns its place: 70 call sites paint on
it, so accents have to clear contrast on `bg0` **and** `bg1`.

The seven accents had to be invented. They are drawn as *text* throughout the
shell (491 uses of `ThemeService.blue` alone), so they were searched for, not
chosen: the **lowest saturation** at each earthy hue that still clears 4.5:1 on
both light surfaces and stays 45 RGB apart from every accent already picked.
Vintage means muted; we buy only as much chroma as separation demands.

```
fg      #2e352c  bg0 11.78  bg1 11.09   (AAA body text)
grey1   #5f6e59  bg0  5.07  bg1  4.77
red     #8c625a  bg0  4.88  bg1  4.59   terracotta
orange  #675442  bg0  6.70  bg1  6.30   sienna
yellow  #443f2c  bg0  9.82  bg1  9.24   ochre
green   #4c7737  bg0  4.89  bg1  4.60   sage
aqua    #4a7372  bg0  4.91  bg1  4.62   verdigris
blue    #3a4b5a  bg0  8.39  bg1  7.89   denim
purple  #8f5b8f  bg0  4.82  bg1  4.54   plum
closest accent pair: orange/green = 46   (need >= 45)
```

I first demanded `fg` reach 4.5:1 on `bg4` too, and it doesn't — 3.34. Then I
checked: **`bg4` has two uses in the whole shell** — one palette swatch and one
border. It never carries text. The requirement was mine, not the shell's, so it
came out.

Seeded to `themes/custom/light-paper-theme.json`. An existing file of that name is
**never** overwritten, not even with `ZEN_FORCE_THEMES=1` — a custom theme is
yours the moment it lands. The shipped copy is written beside it as `.new`.

*(The name is what you asked for. Your builtin `paper` theme's description is also
"Light paper theme", so the two will read alike in the dropdown. One word changes
it if that bothers you.)*

### Files

`ZenVersion.qml` · **`hypr-config/zen-hyprlock-power.conf`** (new) ·
**`themes/custom/light-paper-theme.json`** (new) · `install.sh`
(`install_zen_hyprlock_power`, custom-theme seeding)

### Verification

`qmllint` clean on all 195 QML files; `bash -n` clean on `install.sh`. The
installer step was run in a sandbox across all four situations — no config, clean
config, re-run, and existing power buttons — and never wrote to a file it doesn't
own. Every key in the hyprlock include was linted against hyprlock's real schema
*after* passing the config through a transliteration of hyprlang's comment
stripper. The theme JSON was validated against the builtin schema and the whole
palette audited for contrast and separability.

---

## v8.0.0-alpha-hf134 — the panel that shook

### It shook because it moved

*"prang nangingig kasi now hahaha"*

```qml
onPressed:  _px = m.x;  _ox = panel.x
onMove:     panel.x = _ox + (m.x - _px)
```

`m.x` is local to the MouseArea, and that MouseArea lives **inside** the panel it
is moving. Move the panel and the mouse area moves with it, so an unmoved cursor
reports a different `m.x` on the next event. The handler feeds its own output
back in. Solve the fixed point:

```
P = 2·P0 + C − C0 − P     →     P = P0 + (C − C0)/2
```

Simulated over ten 20px cursor steps, the panel ends **100px behind**, stalling
every other event on the way:

```
event  cursor  m.x (local)   panel.x   error
    1     320        220.0     120.0    +0.0
    2     340        220.0     120.0   -20.0
    3     360        240.0     140.0   -20.0
    ...
   10     500        300.0     200.0  -100.0
```

Half speed, plus a stutter. That is the shake.

`drag.target` is what `DesktopWidgets`' clock, weather and system-monitor widgets
have used since **v6.11e** — that file's own comment says so: *"removed x/y
property bindings that fought with drag.target."* Qt tracks the cursor in the
scene frame, which the panel cannot perturb. The bounds go to
`drag.minimumX/maximumX` rather than a clamp written behind Qt's back, which
would be overwritten each frame and rubber-band at the edge.

The **resize grip had the identical loop** — the nub is anchored to the panel's
bottom-right, so growing the panel moved the nub. It now measures in the scene
frame via `mapToItem(null, …)`, called per event, never a stale binding.

### The icons blinked twice a minute

`refresh()` runs on a 30s timer. It rebuilt `entries` from scratch with the
**provisional** icon — `application-x-executable` for every `.desktop` file — 
assigned it, and only then kicked off the async resolvers. So every Brave
shortcut and every Steam game dropped back to the generic page glyph until its
resolver landed. With a recursive `find` over `/usr/share/icons`, that is not
instant.

And `_patchEntryIcon` replaced the whole `entries` array once **per resolver**. A
`Repeater` cannot know the new array describes the same tiles, so it destroyed
and rebuilt every delegate — five times a scan on Paul's desktop. This is exactly
the failure hf129 fixed in the System Monitor.

Resolved icons are cached by absolute path, seeded into the new list *before* it
is assigned, and the patches are coalesced into one array swap by a 40ms timer. A
rescan that finds the same files is now visually a no-op, and it doesn't re-spawn
a `find` for anything already known.

**The resolver itself is fine.** I checked before touching it — a synthetic Brave
PWA (`Icon=brave-<appid>-Default`) and a Steam shortcut (`Icon=steam_icon_255710`)
both resolve to their PNGs under `~/.local/share/icons/hicolor/128x128/apps/`.
So if a specific icon is still generic, the new **Desktop items** list will say
why rather than leave you guessing.

### Custom icons only worked in one of the two renderers

`DesktopIconsWidget` has honoured `DesktopIconsState.customIcons` since hf85.
`DesktopIcon.qml` — the free-form renderer — never read it. Right-clicking a tile
to set a custom icon worked in Single-widget mode and silently did nothing in
free-form. Same state, same precedence, both renderers now.

### Desktop items

Settings → Desktop grows a section listing every entry the scanner found, with a
34px preview of the icon it actually resolved and, next to it, **where that icon
came from**:

| | |
|---|---|
| `custom` | your override wins |
| `from .desktop` | the `Icon=` field resolved to a real file |
| `icon theme` | matched by name in the icon theme |
| `none — generic glyph` | nothing matched |

**Choose…** and **Reset** per row, plus a **Rescan** that drops the cache. The
picker moved from `DesktopIconsWidget` onto `DesktopIconsState`, because a
singleton is the right home for a thing that mutates singleton state — and
because the settings page could not reach it where it was.

### The panel

The frosted card from the mockup: radius 20, translucent white, a soft border,
and an **Open Folder** pill under the grid that hides itself when the panel is too
short to hold it. The dark slab hf83 shipped is one toggle away —
Settings → Desktop → Panel style. *Wala tayong babawasan.*

### Caught before shipping

`DesktopPage.qml` called `DesktopIconsState.saveState()`. **That function has
never existed** — the singleton debounces its writes through `markDirty()`. QML
resolves the call at runtime, so the row would have silently done nothing and no
lint would have said a word. I wrote it, then grepped for it. Filed as [F10].

### Files

`ZenVersion.qml` · `DesktopIconsWidget.qml` (drag, resize, chrome, footer) ·
`DesktopIconsService.qml` (icon cache, batched patches, `openFolder`,
`forceRefresh`) · `DesktopIconsState.qml` (`pickIconFor`, `widgetLightGlass`) ·
`DesktopIcon.qml` (custom override) · `DesktopPage.qml` (Desktop items, Panel style)

### Verification

`qmllint` (Qt 6.11) clean on all 195 QML files. The drag feedback loop was solved
analytically and simulated. The `.desktop` icon resolver was run — verbatim,
extracted from the QML — against a synthetic Brave PWA and a Steam shortcut in a
sandboxed `$HOME`; both resolved. Sixteen structural assertions confirm the old
handlers, the per-resolver array swap and the phantom `saveState()` are gone from
the code.

---

## v8.0.0-alpha-hf133 — the dropdown that closed the window

### A popup outside the mask is a click on the desktop

*"sa buong zen control panel natin sa drop down kapag lumalagpas sa window hindi
na ma-seselect, nag-exit na mismo… dapat hindi ganun, makakapag select padin and
scroll"*

The Control Center, the Settings window and the Quick Notes panel are full-screen
layer surfaces with an input mask:

```qml
mask: Region { item: zenDashboardPanel }
```

Only the panel rectangle takes pointer input. Everything else on that surface is
click-through **by design**, so the desktop behind stays usable.

A QQC2 `Popup` is not its own surface — it lives in the window's overlay. So it
happily *draws* outside the panel, but every click there falls through to
whatever is behind, the Control Center loses focus, and the whole thing closes.

`ZenDropdown` measured its room against the **window**, which is the entire
screen:

```qml
const win = root.Window.window
const triggerBottom = root.mapToItem(null, 0, root.height).y
return Math.max(120, win.height - triggerBottom - 16)
```

Reproduced offscreen with a 3440×1440 screen and a 1440×920 panel:

```
window 3440x1440   panel y 260..1180
trigger y 1110..1142   popup content 200px

hf132 measures against the WINDOW:
   spaceBelow = max(120, 1440 - 1142 - 16) = 282
   flipUp = False   ->  popup spans y 1148..1364
   panel ends at 1180  ->  184px OUTSIDE the mask
```

There *is* 282px below the trigger — on the screen. Inside the panel there are
22. So it opened downward and hung out in click-through territory. That is the
dock's "Add module" list you watched dismiss the panel.

**The fix.** `boundsItem` is the rectangle the popup may occupy, discovered by
walking up to the nearest ancestor carrying `zenPopupBounds: true`. The Control
Center's root and the Settings window's root both declare it. Leave it null — an
unmasked window — and it falls back to the window, which is the old behaviour and
correct there.

```
case                         popup y         flip     h    inside the mask?
top of panel                 358..574        False   216   YES
middle of panel              738..954        False   216   YES
near bottom (Paul's)         888..1104       True    216   YES
very bottom                  918..1134       True    216   YES
long list, mid panel         738..1058       False   320   YES   (ListView scrolls)
narrow trigger, right edge   x 2232..2432    False   216   YES   (clamped sideways)
```

Also gone: the `Math.max(120, …)` floor, which papered over an unmapped trigger by
inventing 120px of room that might not exist. And `y` now follows the **clamped**
height — it used to subtract the *wanted* height, so a shortened popup floated
with a gap beneath it. And the popup is clamped horizontally: `width` is at least
200, so a narrow trigger near the right edge used to push the list past the panel.

**Two staleness bugs I had to fix in my own fix.** `mapToItem()` is a function
call, not a bindable expression — nothing re-runs the binding when the panel is
dragged, so `boundsItem.x/.y` are read inside the block to register them as
dependencies. And the `Popup` object is created **once** and reused for every
open, so a page scrolled since the last open would hand it a stale trigger
position; reading `zenPopup.visible` forces a re-measure on each open.

### The System Tray colour pickers were not pickers

*"sa system tray hindi ma-select yun mga color picker nila"*

They were a bare `Rectangle` painted with the current value. No `MouseArea`, no
click handler, nothing to open. Every other colour row in the shell uses
`ColorSwatch`, which routes through the `ColorPickerState` singleton to the one
global `ColorPickerOverlay` that hf114 mounted in the Control Center. `SysRowPage`
was written before that plumbing existed and was never migrated.

Six rows — CPU, RAM, Temp, Sound, Network, Bluetooth — are real swatches now. The
✕ still clears back to the theme-reactive default.

**The trap in the seed value.** An empty key means "auto", and the swatch should
show the theme colour it would have drawn. `"" + ThemeService.grey2` looks right
and is wrong:

```
QML color -> string:
   Qt.rgba(.6,.65,.7,1)     ->  '#99a6b3'
   Qt.rgba(.6,.65,.7,.75)   ->  '#bf99a6b3'

through ColorSwatch._rgb(), which takes substring(0,6):
   opaque  -> '#99a6b3'
   alpha   -> '#bf99a6'     <- channels rotated
```

That is the hf120 channel-rotation bug waiting to happen the moment a theme ships
a translucent grey. The hex is built from `.r/.g/.b` instead, where no alpha byte
can sneak in.

### Hot Corners had the last bare ComboBox

*"yun hot corners yun design principle natin ng drop down iba yun itsura"*

A raw QQC2 `ComboBox`: platform arrow, square corners, no hover fade, and — since
it isn't a `ZenDropdown` — no bounds-aware popup either. `ZenDropdown` extends
`ComboBox`, normalizes `{id, label}` entries to `{value, text}`, and emits
`activated(realIndex)` against the same model, so this was a drop-in. The
`currentIndex` resolution is unchanged.

`ZenComboBox.qml` is untouched, as its own header promises.

### Files

`ZenVersion.qml` · `ZenDropdown.qml` (`boundsItem`, bounds-relative flip/clamp,
live bindings) · `ZenDashboard.qml` + `ZenSettings.qml` (`zenPopupBounds: true`) ·
`SysRowPage.qml` (`ColorSwatch`, `_hex()`) · `HotCornersPage.qml` (`ZenDropdown`)

### Verification

`qmllint` (Qt 6.11) clean on all 195 QML files. The popup geometry was
transliterated from the **shipped** source and run across six trigger positions —
all clamped inside the mask, where hf132 spilled 184px and 214px at the bottom two.
Qt's colour-to-string behaviour was measured in a real QML engine rather than
assumed. A structural assertion confirms the 120px floor and the window-relative
measurement are gone from the code, not just from the comments.

---

## v8.0.0-alpha-hf132 — colour, and the dashboard card grows up

### Coloured weather icons

*"kaya yun mag colors din pre? yung mga icons? prang sa widget desktop ko haha"*

The desktop widget's icons are coloured because they are **emoji** — emoji carry
their own palette. Material Symbols and Nerd Font glyphs are single outlines:
whatever colour you paint them, they stay that colour. hf131 painted them all
`ThemeService.aqua`, so a sun and a thunderstorm differed only in shape.

**Two palettes, because one cannot work.** My first pass was a single table tuned
on a dark bar, with a comment claiming it stayed legible on a light one. Then I
measured it:

```
   71 Snow           #e3f2fd    dark 14.23    light  1.05   FAIL
    0 Clear          #ffc53d    dark 10.30    light  1.31   FAIL
   -1 Windy          #5eead4    dark 10.98    light  1.23   FAIL
   ... 20 of 29 colours below a contrast ratio of 2.0 on a light bar
```

A contrast ratio of 1.05 is invisible. Nor does a lightness transform rescue it:
forcing snow dark enough to read on white turns it into rain's blue. So the tint
follows the surface — `_darkSurface` is the WCAG relative luminance of
`ThemeService.bg0`, and there is a hand-tuned table on each side.

Both audited, straight out of the shipped QML:

```
dark  palette / dark  bar   (28 codes + windy + fallback)
   contrast     worst 3.84  (need >= 3.0)   OK
   separability 22/22 required pairs >= 45   OK
light palette / light bar   (28 codes + windy + fallback)
   contrast     worst 2.50  (need >= 2.5)   OK
   separability 22/22 required pairs >= 45   OK
```

Fog and overcast **are** close — 46 apart on dark, 27 on light. Deliberately.
They are both grey sky, and a weather app that makes them wildly different is
lying to you. The pairs that must never be confused — clear, rain, snow, storm,
windy — are all well clear of one another. Snow vs freezing rain is exempt for
the same reason.

A fixed palette, not theme-derived, for the reason a traffic light is not
theme-derived: rain should read as rain on every Shell Look.
**Settings → Bar Modules → Weather → Icon colour** — `Condition` (default) or
`Accent` (the pre-hf132 single colour). Emoji ignore it; they already have colour.

### The dashboard weather card

*"tas yun sa dashboard pre dapat ganito din sana detailed per hourly tas sa ibaba
yun daily 7 days"*

The card had a header and an hourly strip. The desktop widget also carries
feels-like / humidity / wind, an "Updated" stamp, and the 7-day row. All of it is
there now, in the same order, reading the same service. The wind figure colours
itself when it crosses the windy threshold, because that is the number that
decided.

**Sections appear as the card grows.** The thresholds are measured, not guessed —
an offscreen `QQuickView` with the same children reports:

```
   header + updated    70px content box
   + hourly strip     163px
   + 7-day row        248px
```

so `showHourly >= 172` and `showDaily >= 262`, with headroom for a taller font
than the probe's. My first pass shipped 150 and 240, which clip by 13px and 8px.

Default card height 190 → 300 (content box 272 ≥ 248). Anyone who has already
dragged the grip keeps their own height — `dashCards` only stores cards you
changed.

The 7-day row drops days from the end rather than squeezing them illegibly:
`dayCount = clamp(3, floor(width / 54), 7)`. A span-2 card is 416px wide, which
gives all seven at 56px each.

### The bug the probe found

`Layout.fillHeight` **defaults to `true` for a nested layout** and `false` for a
plain Item. Without pinning it, the header `RowLayout` and the 7-day `RowLayout`
both stretched to eat leftover space — the header measured 54px in one pass and
90px in another, and the height thresholds meant nothing. Both are pinned now;
the spring `Item` at the bottom is the only thing that absorbs slack.

### Files

`ZenVersion.qml` · `WeatherService.qml` (`wmoTintDark` / `wmoTintLight` /
`_darkSurface` / `iconTint`) · `ZenWeather.qml` · `WidgetsPage.qml` ·
`PanelState.qml` (`weatherIconTint`, weather card default height) ·
`BarModulesPage.qml` (Icon colour) · `ZenDashboard.qml` (`cmpWeather` rebuilt)

### Verification

`qmllint` (Qt 6.11) clean on all 195 QML files. The palette audit parses the
tables **out of the shipped QML** and re-checks contrast, separability and
coverage, so the code cannot drift from the claim. Both palettes rendered with
the real JetBrainsMono Nerd Font and Material Symbols Rounded on both surfaces.
Card section heights and the 7-day cell widths measured in an offscreen
`QQuickView`.

---

## v8.0.0-alpha-hf131 — the bar was drawing a gear for "Overcast"

### The weather icons were Font Awesome

Paul: *"yung mga widgets sa weather dito sa qml bar and dock dapat same sa logic
icons nung sa desktop widgets ko if cloudy, sunny, windy, rainy"*

Not a styling preference. `ZenWeather.qml` — mounted by **both** `Bar.qml` and
`ZenDock.qml` — drew `WeatherService.icon` with `font.family: "JetBrainsMono Nerd
Font"`. The codepoints in `wmoIcon()` were written against the standalone Weather
Icons font (weathericons.io), where `wi-cloudy` really is U+F013. Nerd Fonts
relocates that whole set into the Private Use Area at U+E3xx and leaves **Font
Awesome** sitting at U+F0xx.

Resolved against ryanoasis/nerd-fonts `glyphnames.json`:

```
 WMO  condition       codepoint  what a Nerd Font ACTUALLY draws there
   0  Clear           U+F00D     fa-close, fa-remove, fa-times, fa-xmark
   1  Mostly Clear    U+F00C     fa-check
   2  Partly Cloudy   U+F002     fa-magnifying_glass, fa-search
   3  Overcast        U+F013     fa-cog, fa-gear            <- the gear
  45  Fog             U+F014     fa-trash_can, fa-trash_o
  61  Rain            U+F019     fa-download
  71  Snow            U+F01B     fa-arrow_circle_o_up
  75  Heavy Snow      U+F076     fa-magnet
  95  Thunderstorm    U+F01E     fa-arrow_rotate_right, fa-repeat
dflt  (fallback)      U+F03E     fa-image
```

All 21 mapped codes were wrong. Only the fallback looked plausible, and by
accident: U+F0C2 really is `fa-cloud`. That is why this survived 130 builds.

The naive remap (`nf = 0xE300 + (wi - 0xF000)`) holds for `day_sunny` and then
quietly breaks — `wi-cloudy` F013 lands on E312, not E313, and E313 is fog. Every
codepoint in the new table was looked up, not computed.

Coverage went from 21 codes to 28: freezing drizzle (56/57), freezing rain
(66/67), snow grains (77) and snow showers (85/86) used to fall through to the
fallback.

### One source of truth — backlog [G3], done

`WeatherService` computed three representations at fetch time and threw away the
number that produced them, so `ZenGlanceWidget` had to map Nerd codepoints *back*
into Material ligature names with a private table. Two lossy hops for a value we
already had.

The service keeps `weatherCode` now, `forecast[]` and `hourly[]` carry `code` and
`material`, and it exposes:

| | |
|---|---|
| `materialIcon` | Material Symbols Rounded ligature — what the bar/dock draw |
| `nerdIcon` | corrected Nerd Font weather glyph, windy-aware |
| `emojiIconLive` | emoji, windy-aware |

Every ligature name was checked against the actual `MaterialSymbolsRounded`
variable font. `cloudy` does **not** exist in it — which is why overcast maps to
`cloud`, and why guessing would have failed.

`ZenGlanceWidget._wxMap` stays as a fallback. Its keys are the pre-hf131 Font
Awesome codepoints, so it doubles as a translator for a stale weather cache.

### Windy

WMO has no windy code. Wind is a separate measurement, and the API already sends
it in `wind_speed_10m`. So it is derived: **a quiet sky (clear, cloudy or fog)
plus wind at or over `windyThresholdKmh` reads as windy.** Rain, snow and
thunderstorms always win — you want to know it is raining more than you want to
know it is breezy, and codes 65/82 already draw a wind-blown rain glyph.

Default 25 km/h ≈ Beaufort 4–5, the point where an umbrella stops working.
Settings → Bar Modules → Weather → Windy above.

### Which style?

The desktop widgets don't agree with each other. The Glance blob draws Material
Symbols; the classic widget, the dashboard card and the Quick Settings card draw
emoji. Rather than pick for you:

**Settings → Bar Modules → Weather → Icon style** — `Material` (default) ·
`Emoji` · `Nerd Font`.

### Self-healing cache

Weather caches written before hf131 hold Font Awesome codepoints in `icon`, and
they live for six hours. Restoring one would put the gear straight back in the
bar. The loader re-derives from `weatherCode` when it is present, and otherwise
discards any single character at or above U+F000 rather than trusting it.

### The dock's power menu opened nowhere near the power button

Paul: *"kapag click ko yun power button sa dock, hindi naka-align yun prompt"*

Two bugs, compounding.

**One — the coordinate space.** It used `anchor.window: QsWindow.window` with a
hand-computed `anchor.rect.x` built from `root.x`. But `root.x` is the item's x
**in its immediate parent**, not in the anchor window. The dock mounts its
modules through a `Loader` inside a `RowLayout` inside the island pill, so
`root.x` is 0. Reproduced offscreen with the dock's real nesting:

```
  root.x  (local to its Loader)      = 0
  window x of the button             = 1206

  anchor.rect.x = root.x + root.width/2 - popupW/2
                = 0 + 18 - 95 = -77          <- 77px LEFT of the dock window
  correct value would be              = 1129
```

The compositor then slid the popup back on-screen, which is why the menu appeared
parked at the far left with nothing under it.

**Two — the wrong edge.** `PanelState.isTop / isLeft / isRight` describe the
**bar**. On the default layout — top bar, bottom dock — `isTop` is true, so the
menu was told to open *downward* from a dock already on the bottom edge. It ran
off the screen and got flipped.

The fix is the pattern `Taskbar` and `SysRowIcon` have used since v6.14:
`anchor.item: root`, and let Quickshell do the window mapping. Edges and gravity
now come from the new `DockState.popupAnchorEdges` / `popupAnchorGravity`, which
know which edge the **dock** is on.

`CalendarButton` does the same arithmetic but lives directly in the bar's row,
where local x ≈ window x. It looks fine, so it stays as it is — filed as [F7].

### Files

`ZenVersion.qml` · `WeatherService.qml` (retabled `wmoIcon`, new `wmoMaterial`,
`weatherCode`, `windy`, self-healing cache) · `ZenWeather.qml` (bar + dock icon) ·
`ZenGlanceWidget.qml` ([G3]) · `WidgetsPage.qml` (preview) · `PanelState.qml`
(`weatherIconStyle`) · `BarModulesPage.qml` (Weather section) ·
`DockPowerButton.qml` · `DockState.qml` (`popupAnchorEdges`)

### Verification

`qmllint` (Qt 6.11) clean on all 195 QML files. Every shipped codepoint was
resolved against the real `glyphnames.json`; every Material ligature was resolved
against the real `MaterialSymbolsRounded` TTF via fontTools — including `cloudy`,
which does not exist. The bar module was rasterised with the actual JetBrainsMono
Nerd Font and Material Symbols Rounded, before and after. The dock's nesting was
reproduced in an offscreen `QQuickView` to measure `root.x` against window x.

Caught before shipping: `NumericStepper` emits `valueEdited`, not
`valueModified`. The wrong handler name would have made the whole Bar Modules page
fail to load.

---

## v8.0.0-alpha-hf130 — an anchor is where a rope comes from

hf129 claimed to fix "lagi nasa upper left" and did not. This is why.

### What hf129 got wrong

hf129 moved the **pull point** to the cursor and seeded a lateral **swing**. Both
were real changes. Neither touched the thing that decides where a rope appears to
come from — its **anchor**. Those were still welded to the four screen corners:

```qml
anchorX: 0             anchorX: parent.width
anchorY: 0             anchorY: parent.height
```

With the cursor at x=2900 on a 3440 monitor, `ropeTL` still had to drag 2900px
across the screen from the top-left.

And the swing seed was doing almost nothing. Transliterating ZenRope's integrator
and running it shows the tick hard-clamps the last four points onto the pull:

```
if (i < segments - 3) { ...spring... } else { point.center = pull }

  free (springy) : [1, 2, 3, 4, 5, 6]
  clamped to pull: [7, 8, 9, 10]   <- their seed is thrown away on frame 1
```

and the spring dominates whatever velocity points 1..6 started with:

```
swingDir = -1  ->  mean lateral drift after 12 frames = +826.3px
swingDir = +1  ->  mean lateral drift after 12 frames = +823.1px
```

Three pixels. `swingDir` was a garnish I mistook for the meal.

### Cursor bands

The monitor is split into three vertical bands. The four ropes pin to the corners
of whichever band the cursor is in.

```
┌─────────┬─────────┬─────────┐
│ TL   TR │         │         │   cursor left   → ropes from 0    .. w/3
│  band-1 │  band 0 │  band+1 │   cursor centre → ropes from w/3  .. 2w/3
│ BL   BR │         │         │   cursor right  → ropes from 2w/3 .. w
└─────────┴─────────┴─────────┘
```

Simulated on 3440×1440 with the cursor at x=2900 (right third), measuring how far
each rope must stretch:

```
hf128/hf129 — anchors on the four screen corners
   ropeTL: origin (   0,   0)   span across screen = 2900px
   ropeTR: origin (3440,   0)   span               =  540px
   ropeBL: origin (   0,1440)   span               = 2900px
   ropeBR: origin (3440,1440)   span               =  540px

hf130 — anchors on the corners of the cursor's band (x=2293..3440)
   ropeTL: origin (2293,   0)   span               =  607px
   ropeTR: origin (3440,   0)   span               =  540px
   ropeBL: origin (2293,1440)   span               =  607px
   ropeBR: origin (3440,1440)   span               =  540px
```

- the band follows the cursor live while selecting; anchors **glide** between bands
  (260ms `OutCubic`) rather than teleporting
- **hysteresis** — a band only yields once the cursor is clear of the boundary by
  ~2% of the screen (69px on the ultrawide). Parking the pointer on a boundary and
  jittering ±8px produces **0 band changes**; a full left-to-right sweep produces
  exactly **2 transitions**, at x=1220 and x=2380
- the band **locks on press**, so dragging across a boundary can't yank the anchors
  out from under the rope you're aiming with
- the hint chip grows a three-pip indicator showing which band the rig is on

**New setting.** *Settings → General → Strings → Rope origin* — `band` (default) or
`corners` (the classic rig, welded to the four screen corners).

### The rig was being seeded against a window with no size

The other half of "still comes from the upper left", and it would have bitten the
band fix too.

A layer surface gets its dimensions from a compositor configure that can land a
frame or two **after** the window maps. `resetState()` runs on the visible
transition — so `width` could still be `0`. Every anchor collapses to `0,0`.

hf129 made it worse with this guard:

```qml
const seedX = (cursorLocalX >= 0 && width > 0) ? Math.round(cursorLocalX)
                                               : Math.round(width / 2)
```

A cursor x of 2900 is 2900 whether or not we know how wide the screen is. Only the
*fallback* needs the width. With `width == 0` that expression quietly returned `0`.

`resetState()` now refuses to seed against an unsized window and re-arms;
`onSizedChanged` picks it back up, and it re-seeds if the size arrives late and no
drag has started. Verified in a real QML engine:

```
1) window maps at 0x0, then the compositor configures it
  [PASS] resetState deferred (no seed against width=0)
  [PASS] _needsReset armed
  [PASS] seeded once the surface is sized
  [PASS] seeded at the cursor, not 0 (lastSeedX=2900)
  [PASS] band picked up from the cursor (zone=1)
```

Related: the anchor glide is **disarmed for the first 60ms** of a session.
`bandRightX` derives from `width`, so when width goes `0 → 3440` in one step an
armed `Behavior` would animate the right-hand ropes sweeping in from the left edge —
reintroducing the exact flourish we're removing.

### The swing kick now lands on points that exist

Kept, demoted, corrected. The impulse is scaled across the **free** section
(`1 .. segments-4`) instead of the whole chain. `swingImpulse` 2.6 → 4.2 to
compensate. It is a settling flourish. The anchors do the work.

### Trap I walked into

Adding `hoverEnabled: true` to the selection `MouseArea` — needed so the band can
follow the pointer before you press — makes `onPositionChanged` fire on **plain
hover**. The existing body of that handler drags out a selection rectangle. Without
a guard the overlay would start drawing a selection box the moment you moved the
mouse, button or no button. Hence the `if (!pressed)` on its very first line.

Also: `Row` positions its children, so the three band pips must not carry
`anchors.verticalCenter` — that fights the positioner.

### Files

`ZenVersion.qml` · `ZenScreenshotOverlay.qml` (bands, hysteresis, band lock, live
hover, deferred reset, glide arming, band pips) · `ZenRope.qml` (`animateAnchor` +
`Behavior on anchorX/anchorY`, swing kick scaled to the free section) ·
`ZenStringsState.qml` (`ropeOriginMode`) · `GeneralPage.qml` (*Rope origin*)

### Verification

`qmllint` (Qt 6.11) clean on all 195 QML files. ZenRope's integrator transliterated
and simulated — that is what exposed both the clamped points and the 3px `swingDir`.
Deferred reset, band selection, hysteresis, full-sweep transition count and the
`corners` fallback all tested in an offscreen `QQuickView`.

---

## v8.0.0-alpha-hf129 — the sidebar, the nav, the flicker, and the freeze

Six items. Nothing removed, nothing renamed, no feature turned off.

### 1. Sidebar highlights are level again

Select **Dashboard** and the nav pill, profile card and quick-action buttons all ran
past the sidebar's right border and got sliced by its `clip`. Select **General** — or
any of the other 30 pages — and everything sat correctly inset.

The Edit pencil is `visible: dash.currentPage === 0`. A `QQuickLayout` skips invisible
children, so on page 0 — and *only* page 0 — the brand `RowLayout` gained 28px of
button plus 10px of spacing. That pushed its minimum width to

```
44 (badge) + 10 + 130 (unelided "Zen Control Center") + 10 + 28 (edit)  =  218px
```

against a 204px content box (232px sidebar − 2×14px margins). A single-column
`ColumnLayout` sizes its column to the **widest child minimum** and then hands that
width to *every* `fillWidth` child.

Reproduced offscreen:

```
hf128, Dashboard page (edit button VISIBLE)
  pill            width= 233.0  <-- wider than the 204px content box (clipped)
  profile         width= 233.0  <-- wider than the 204px content box (clipped)
hf128, any other page (edit button hidden)
  pill            width= 204.0  fits
hf129, every page
  pill            width= 204.0  fits
  profile         width= 204.0  fits
```

The header now lives inside a plain `Item` with the `RowLayout` anchored to it — the
idiom `ZenSettings.qml` has used since v6.13 (`ZenSettings.qml:387`). An `Item`'s
`Layout.minimumWidth` is 0, so the header can never widen the column again.

Belt and braces: the title elides and declares `Layout.minimumWidth: 0`; the Edit
slot is reserved on every page and fades rather than collapsing; the pencil moved
down onto the version line, where there was already room (~9px lower, title keeps its
full 13px); the window-drag `MouseArea` is now a `z: -1` sibling instead of a layout
child carrying `anchors.fill`.

### 2. One header per category, collapsible

`OTHER` appeared twice. So did the others — **APPEARANCE ×4, SYSTEM ×3, OTHER ×2:
14 headers for 6 categories.** The old code printed a header whenever the *previous*
item had a different category, and `navCatFor` interleaves.

Groups are derived **from** `navCatFor`, not hand-listed, so adding a module files it
automatically.

```
DASHBOARD                    (top-level row, outside every group)
APPEARANCE     (11)  General · Decoration · Animations · Themes · Panel ·
                     Bar Modules · System Tray · Hot Corners · Hyprbars ·
                     Dock · Shell Look
INPUT & DISPLAY (2)  Displays · Input
CONNECTIVITY    (2)  Sound & Network · Notifications
SYSTEM          (8)  Battery & Power · User Profile · Updates · Game Detection ·
                     Default Apps · App Float Rules · User Management · Login Screen
PRODUCTIVITY    (5)  Focus Spaces · Quick Notes · Network Pulse · Smart Dim ·
                     Title Translator
OTHER           (3)  Desktop Widgets · Wallpaper · Desktop
```

Verified: 31 of 31 modules placed, no duplicates, no orphans, 6 unique headers.

Every group starts collapsed. Clicking a header opens it and closes the other one;
clicking an open header closes it. 190ms `OutCubic` reveal, chevron rotates with it.
A collapsed header shows its module count and turns blue if it holds the current
page. Arriving at a page from search, a quick action or the profile card opens the
owning group. A narrow (62px) sidebar keeps the old flat icon list.

**Optimised.** The reveal height is arithmetic (`n·32 + (n−1)·2`), not measured,
which lets the rows sit behind a `Loader` that only exists while the group is open:

```
=== all collapsed (default) ===
  appearance    body h=  0.0  loader active=False  delegates=none
  display       body h=  0.0  loader active=False  delegates=none
  connectivity  body h=  0.0  loader active=False  delegates=none

=== appearance open ===
  appearance    body h=372.0  loader active=True   rows built = 11/11
  expected bodyH = 11*32 + 10*2 = 372   actual = 372
  column width = 204.0   (parent Loader width = 204.0)   <- no binding loop
```

New file: **`ZenDashNavRow.qml`**. The installer's `*.qml` glob picks it up.

### 3. System Monitor bars stopped restarting

`sysModel` was a `var` binding over a JS array literal whose elements read
`SystemMonitorService.cpuPercent`, `.gpuUsage`, `.netUp` and a dozen more. Touch
**any** of them and the binding re-runs and builds a brand-new array of brand-new
objects. A `Repeater` cannot know the new array describes the same five cards — it
sees a different model, destroys all five delegates and builds five more. The fill
`Rectangle` is born at width 0 and `Behavior on width` catches the jump.

The model is now **constant** — five cards, identity only, no readings. Readings come
from `sysPct()` / `sysS1()` / `sysS2()`, called from inside each delegate: QML's
dependency capture follows the call and subscribes the delegate's own property to
just the service values it actually read.

### 4. Hide dashboard sections, and it sticks

`PanelState.dashHidden` plus an eye toggle in the edit-mode chrome, left of the span
badge. Edit mode still renders hidden cards — dimmed to 22%, grey border, labelled
`· hidden`. Leave edit mode and they drop out; the first-fit packer closes the gap.
Slot, span and height are preserved. Hide everything and the dashboard tells you
where the way back is. Unknown ids are filtered on load.

### 5. Freeze frame — "para walang takas"

The old pipeline grabbed pixels at the **end**: hide the overlay, wait 300ms, then
`grim -g <region>` the live screen. But the overlay takes exclusive keyboard focus the
instant it maps, and every Zen surface holding a `HyprlandFocusGrab` — Control Center,
Start Menu, dock popups, tray menu — dismisses itself. By the time the shutter opened,
the subject had left.

`shell.qml` now grabs the whole focused monitor with `grim -l 0` *before* the overlay
window is allowed to exist — the probe `Process` is the last thing that runs before
`screenshotRopeVisible = true`. That ordering *is* the feature.

HiDPI: `grim` writes device pixels, QML selection coords are logical. The crop scales
by `freezeScale`, derived from the image's own natural size with the compositor's
`.scale` as fallback. The annotation SVG keeps a **logical** `viewBox` but gets
**device-pixel** `width`/`height`. Verified against a real rasteriser:

```
scale 1.5  (2560x1440 @ 1.5)
   freezeScale       = 1.5000
   -crop geometry    = 600x450+180+135
   crop is selection = OK        (no off-by-one)
   svg scaled to fit = OK        (annotations aligned)
```

Every downstream decision hangs off the decode actually succeeding
(`Image.status === Ready && implicitWidth > 0`), not merely on a path being handed
down. A truncated PNG, no `grim`, no `magick`, or the toggle off — any of these falls
back to the hf128 live-grim path, window hide and all.

**New setting.** *Settings → General → Strings → Freeze the screen* (on by default).

**Also:** whole-monitor capture — `Ctrl+A`, `F`, or the *Full screen* button on the
new hint chip.

### 6. Rope swing (superseded by hf130)

hf129 moved the pull point to the cursor and added `swingDir`. It reduced the problem
but did not fix it, because the anchors never moved. See hf130.

### Files

`ZenVersion.qml` · `ZenDashboard.qml` · **`ZenDashNavRow.qml`** (new) ·
`PanelState.qml` · `ZenScreenshotOverlay.qml` · `ZenRope.qml` · `shell.qml` ·
`ZenStringsState.qml` · `GeneralPage.qml`

No installer change: `cp "$SCRIPT_DIR/zen-shell-v5/"*.qml` is a glob, and the
`zen-shell-v5` → `zen-shell` shim already runs.

---

# ARCHIVE — shipped builds

_Everything below is the historical record, unchanged. hf128 back to
v7.0.0-beta.1-hf99._

## v8.0.0-alpha-hf128 — the selection pill was flush against the sidebar border

### Measured, not guessed
From your screenshot, at the "Dashboard" row:

```
sidebar card border   x = 120  ..  350      (inner 230px)
selection pill fill   x = 133  ..  349
                      left inset 13px, right inset 1px
```

The column's `anchors.margins` is 14. The pill should be inset ~13px on **both**
sides. It runs to the border instead. That's the "sagad".

### Cause
```qml
Flickable {
    contentHeight: navCol.implicitHeight     // no contentWidth
    ColumnLayout { id: navCol; width: parent.width }
}
```

Inside a `Flickable`, `parent` is the **contentItem**, not the Flickable. With
`contentWidth` unset, the contentItem is not the viewport width — so `navCol` sized
itself from its own children, and the `Layout.fillWidth` pill grew past the column's
right margin.

You only ever see it on the selected row, because that's the only row with a fill.

### The reference you sent was right
`ZenSettings.qml:530` has always done it properly:

```qml
Flickable {
    id: navFlick
    contentWidth: navFlick.width
    contentHeight: navCol.implicitHeight
    ColumnLayout { id: navCol; width: navFlick.width }
}
```

The dashboard's nav now matches, plus `interactive: contentHeight > height` so it
stops swallowing wheel events when the list already fits.

```
before:  pill 133..349   left 13   right  1   flush
after :  pill = navFlick.width = 204   left 13   right 13   symmetric
```

### On "lagpas padin"
I measured the bottom block on both pages again — user card, button row, card bottom.
Gaps are 11px and 14px on **both**, and the user card is 95px and the button row 33px
on both. The bottom is fine; hf127 settled it. What's left was the pill, and it's the
same pill on every page — you just can't see an unselected one.

### Files
- **Changed:** `ZenDashboard.qml`, `ZenVersion.qml`

## v8.0.0-alpha-hf127 — the sidebar is chrome, not content

### Where it actually lived
```
dashFlick (Flickable, clip)
  └─ contentRoot (transform: Scale { xScale: uiScale })
       └─ RowLayout
            ├─ sidebar          ← here
            ├─ main
            └─ rail
```

Two consequences, both of which are exactly "iba ang size" and "lagpas":

1. **It was zoomed.** `contentRoot` carries the `Scale` transform, so the − 100% +
   control resized the sidebar along with the cards. The sidebar is chrome; zoom is
   for content.
2. **It was inside a scroll surface that can be taller than the window.**
   `contentRoot.height` is `Math.max(minContentHeight /* 560 */, dashFlick.height /
   uiScale)`. Whenever that first term wins — a short window, an aggressive zoom —
   `contentRoot` is taller than the viewport, and a `Layout.fillHeight` sidebar
   grows with it and runs off the bottom. hf126's `clip: true` hid the symptom.
   It didn't remove the cause.

### Now
```
dash (Rectangle)
  ├─ dashSidebar   anchors left/top/bottom, margins 14, width sidebarWidth
  └─ dashFlick     anchors.left: dashSidebar.right
       └─ contentRoot (Scale)
            └─ RowLayout [ main | rail ]
```

The sidebar belongs to the window. Fixed width, exactly `panel.height − 28`, never
scaled, never scrolled. **The same size on every page and at every zoom, and there is
no longer a mechanism by which it could overflow.**

`minContentWidth` drops the sidebar term — it isn't content that has to fit any more.
`fitScale` measures the width the Flickable actually gets, derived from `dash.width`
rather than `dashFlick.width` so `fitScale → uiScale → contentRoot → dashFlick` can't
close a loop:

```
1440px panel : sidebar 232   flick 1168   minContent 720   fitScale 1.00
1032px panel : sidebar 232   flick  760   minContent 720   fitScale 1.00
 700px panel : sidebar  62   flick  598   minContent 420   fitScale 1.00
```

### On what I measured before this
Aligning your two screenshots put every sidebar landmark — user card, button row,
card bottom, panel bottom — at exactly +18px on the Dashboard, i.e. the crop offset,
with identical 11 / 13 / 14px gaps. At **that** zoom and **that** window height they
already matched. The bug wasn't in the pixels you sent; it was one binding away,
waiting for a different height or a different zoom. Hoisting it out settles it for
all of them.

### Files
- **Changed:** `ZenDashboard.qml`, `ZenVersion.qml`

## v8.0.0-alpha-hf126 — dock: weather, power, and a Control Center button that works

### Dock — Control Center
`ControlCenterButton.qml` was a **stub**. Clicking it fired a `notify-send` saying
the popup "ships in hf82l". That popup shipped a long time ago; it's called the Zen
Control Center and it opens from SUPER+C. The button routes there now — and
*toggles*, because clicking a launcher affordance while its window is up should put
it away.

### Dock — Weather
`ZenWeather` is the component the bar's `"weather"` module already renders. The dock
gets the same one. One renderer, two surfaces — no second copy to drift.

### Dock — Power
New `DockPowerButton.qml`: a power glyph that opens Lock / Suspend / Logout /
Restart / Shutdown, using the **same five commands the Start Menu uses**, so
"shutdown" means one thing in this shell.

- It's a `PopupWindow`, not a Rectangle. The dock is a layer-shell surface sized to
  its content; a Rectangle menu would be clipped by the dock's own height. The popup
  gets its own surface, anchored to the button, and opens *away* from whichever
  screen edge the dock is docked to — up from a bottom dock, down from a top one.
- **No `HyprlandFocusGrab`.** v6.12 tore that out because it stole focus and killed
  the Taskbar's context menu. It dismisses the way `CalendarButton` does: toggled by
  its button, closed by choosing an action, and by Escape.

Add either from **Settings → Dock → Modules → Add module**.

### FIX — the dashboard sidebar ran past the panel
`ZenDashboard`'s sidebar `Rectangle` had **no `clip`**. Its `ColumnLayout` holds four
fixed-height children — brand row, divider, user card, button row — plus the nav
`Flickable`. A `ColumnLayout` only hands leftover space to a `fillHeight` child after
every fixed child has its minimum, so when the fixed ones outgrow the sidebar the
bottom block is laid out *past the rectangle*. And `dashFlick`'s clip is rectangular,
so it doesn't follow the panel's rounded corner either — the button row escaped
through it.

- `clip: true` on the sidebar.
- `Layout.minimumHeight: 0` and `Layout.preferredHeight: 0` on the nav `Flickable`,
  so the *nav* yields (it scrolls; that's its job) instead of the user card and the
  power row getting shoved out of the window.

**What I could not reproduce:** why it looked fine on the sub-pages and wrong on the
Dashboard. Both render the same sidebar inside the same `contentRoot`, and I traced
every height binding without finding a page-dependent term. The two mechanisms above
are real and the fix holds at any height and any zoom — but if it still misbehaves on
one page and not another, that's a third thing I haven't found.

### Files
- **New:** `DockPowerButton.qml`
- **Changed:** `ControlCenterButton.qml`, `ZenDock.qml`, `DockPage.qml`,
  `DockState.qml`, `ZenDashboard.qml`, `ZenVersion.qml`

## v8.0.0-alpha-hf125 — expanding a widget moves it out of the way

### The approach, since you asked
**The expanding widget moves. Its neighbours never do.**

Three reasons, in order of how much they'd hurt:

1. **Reversibility.** A widget has exactly one saved home. If neighbours moved too,
   collapsing would have to unwind N moves in the right order — and if you dragged
   anything in between, "the old position" stops having an answer. One mover, one
   undo.
2. **Least surprise.** Widgets you didn't touch shouldn't jump.
3. **Determinism.** The solver runs against *static* obstacles. With moving obstacles
   you're looking for a fixed point that may not exist (three widgets wedged into a
   corner) and the outcome depends on iteration order.

### How it works
- `homeX` / `homeY` is the resting position, and it is **the only thing ever
  persisted**. A lift never writes it. Expanding and collapsing must not drift your
  layout — that's a state clobber, just slower.
- On expand: clamp the expanded rect into the desktop with a 12px margin, then push
  it out of every overlapping neighbour along the **axis of least penetration**,
  discarding any push that would leave the screen. Up to six passes.
- Boxed in with no legal move? It stays and raises `z`. **Overlapping is better than
  teleporting.**
- On collapse: 260ms back to home.
- Drag while expanded and you re-home it, so it collapses where you left it.
- Startup and monitor changes place instantly (`_liftAnim = false`), otherwise the
  widgets would fly in from 0,0.

Worked through on your layout — weather at (760, 300), sysmon at (700, 460):

```
expanded 400×300 at home  → overlaps sysmon
resolved                  → (760, 160)     up, because that's the shortest push
near the right edge (3200,60) → (3028, 60) clamped in, no neighbour needed
```

The glance blob gets the same treatment on `blob → compact → detail`, solved against
`targetWidth`/`targetHeight` rather than `width`/`height` — the blob has a 620ms size
Behavior and we'd otherwise be solving against a half-grown box.

### FIX — the weather background dropdown you couldn't find
`HMSection { title: "Weather Widget Background" }` existed all along. It was sitting
between **Clock Design** and **Glance Widget**, about four hundred lines above the
**Weather Widget** section it belongs to. Same for **System Monitor Widget
Background**. Both now sit directly under their own widget. Pure reorder — no state,
no bindings touched.

### Files
- **Changed:** `DesktopWidgets.qml`, `ZenGlanceWidget.qml`, `WidgetsPage.qml`,
  `ZenVersion.qml`

## v8.0.0-alpha-hf124 — the dashboard clocks were sliced at the card edge

### What you're seeing
Not the panel overflowing. The panel fits. What's chopped is the *content inside the
cards*, and the chop happens at the card's own clip.

The clocks card gives each clock a `Layout.fillWidth` cell. At its default 2-of-4
column span the card is roughly 400px wide, so six clocks get:

```
cell = (400 - 5×8) / 6 = 60px
```

But the clock face was pinned:

```qml
WavyAnalogClock { Layout.preferredWidth: 72; Layout.preferredHeight: 72 }
```

72 into 60. The face's `ColumnLayout` is `anchors.centerIn: parent`, so the overflow
splits — 6px hanging off each side of every cell. The leftmost one hangs past the
card's content rect, and the card `Loader` has `clip: true` with a 14px inset. That
straight vertical cut you drew a box around **is that clip**.

`WavyAnalogClock` itself was innocent — it sizes every hand and tick from
`root.width * k`. It was being told to be 72px in a 60px hole.

### Fixed
- **The face follows the cell.** `Math.max(26, Math.min(72, Math.min(width - 10,
  height - 30)))`. Six clocks → 50px faces. Ten clocks → 26px. Nothing spills.
  No binding loop: the cell's width comes from the `RowLayout`, and the anchored
  `ColumnLayout` inside never feeds back into it.
- **The time card's clock** had the same bug at 100px. It now derives from the card,
  and its digital variant uses `fontSizeMode: Text.HorizontalFit` (46px → 18px floor)
  instead of running past the edge.
- **Clock labels elide.** "California" in a 43px cell used to just keep going.
- **The digital clocks fit.** `fontSizeMode: Text.HorizontalFit`, 11px floor.
- **`clip: true` on each cell**, so a clock can never bleed over its neighbour's
  border even if some future size slips through.

`Workspaces` was already a `Flow` and wraps correctly; nothing else in the grid uses
a fixed width it can't shrink out of.

### Files
- **Changed:** `ZenDashboard.qml`, `ZenVersion.qml`

## v8.0.0-alpha-hf123 — "Remember last position" is not an anchor

No, this wasn't the blink — that was hf122. But you were right to be confused,
because the panel was lying to you.

### The design mistake
hf113 gave `dashPlacement` **ten** values: nine anchors plus `"free"`. But "reopen
where I dragged it" isn't a place on the screen; it's a separate question about
whether the anchor applies at all. Two independent things wearing one property:

- With `placement == "free"`, **no grid cell matched** — nine cells, none selected,
  so the picker looked broken.
- Flipping the switch off wrote `"center"`, **silently discarding** whatever anchor
  you'd picked before.
- Clicking a grid cell while the switch was on **silently flipped the switch off**.

Three ways for the UI to contradict itself, from one conflated property.

### Split
- `ZenWindowPlacement.modes` is nine anchors, full stop. `isFree()` is gone.
- **`PanelState.dashRememberDrag`** / **`settingsRememberDrag`** — booleans of their
  own, saved and loaded independently.
- The switch moves **above** the grid, where it belongs: it decides whether the grid
  matters. When it's on, the grid dims to 40%, stops accepting clicks, and the
  caption under the monitor reads *"Anchor ignored while the window remembers its
  position."* Your anchor is still there, still selected, waiting.
- Turning the switch off **re-anchors immediately** rather than at the next open.
- Migration: an existing `"free"` becomes `center` + `rememberDrag: true`. Any other
  saved anchor is preserved exactly. Nothing is lost.

### Also
The no-slide path (switch on, or slide-in disabled, or maximised) opened at
`opacity = 0` after hf122 and then snapped straight to `1`. That's a pop. It fades
over 140ms now.

### Files
- **Changed:** `ZenWindowPlacement.qml`, `PanelState.qml`, `PanelPage.qml`,
  `shell.qml`, `ZenVersion.qml`

## v8.0.0-alpha-hf122 — the Control Center blinked on open

Mine again. hf117 added the entrance, hf119 added the deferred placement, and
together they produced a four-step opening:

```
1. visible = true, opacity = 1   → the panel PAINTS, at its old size
2. parent.width is still 0       → width binds to Math.min(1440, 0 - 48) = -48
                                   Behavior on width animates 1440 → -48 → 1440
                                   (collapses to nothing, grows back)
3. placement timer fires         → _place(true), _playEntrance()
4. entrance opacity from:0 to:1  → the panel VANISHES, then fades in
```

Paint, shrink, vanish, fade. That's the blink.

### Three fixes, one per step
- **Open hidden.** `opacity = 0` the moment `visible` flips. Nothing paints until
  the placement timer knows where the window goes. The no-animation path (slide-in
  off, maximised, free-mode-after-drag) is now responsible for setting `opacity = 1`
  itself.
- **Clamp the geometry.** `Math.max(1, …)` on width and height, and `Behavior on
  width/height` is disabled while `_sized` is false — so the 0 → full surface
  reconfigure snaps instead of playing as a grow. `_sized` keys off the **parent**
  only (`parent.width > 200`); including the panel's own clamped `width` would have
  reported "sized" inside a 1px box.
- **Retarget, don't stop.** hf119's `_place()` called `dashEntrance.stop()` so a
  stale animation target couldn't outrun a correction. But that also froze the
  entrance's *opacity* animation wherever it stood — a half-faded panel. `_place()`
  now updates `dashEntX.to` / `dashEntY.to` in flight instead. The animation lands
  on the corrected position and finishes its fade.

### Files
- **Changed:** `shell.qml`, `ZenVersion.qml`

## v8.0.0-alpha-hf121 — the installer was eating your settings

Not a QML bug. `install.sh` has been corrupting `panel-state.json` on every run
that saw the word "calendar".

### Cause 1 — a sed that didn't know what JSON is
```bash
sed -i 's/"calendar",\?\s*//g; s/,\s*"calendar"//g' "$PANEL_STATE_FILE"
```
Written in v6.16.4.12.6.49 to drop a bar module, back when the only `"calendar"` in
that file lived inside `barLayout`'s arrays. Then **hf99zs added `dashCards`** — an
object *keyed by card id*, one of which is `"calendar"`. The sed is blind to
structure:

```json
"dashCards": { "calendar": { "span": 2, "h": 150 } }
      ↓
"dashCards": { : { "span": 2, "h": 150 } }
```

That is not JSON. `PanelState.applyState()` throws on `JSON.parse`, every default
stays in memory — and `panelPosition` defaults to **`"bottom"`**. That is your bar
moving from top to bottom. `dashCards`, `barLayout`, `borderColor`, the whole file:
gone, replaced by defaults.

Then `_loadDegraded` correctly suppressed all writes, so the broken file was never
overwritten — and every reboot reset everything again, silently. The guard that was
supposed to protect you is what made it permanent.

**Fixed:** a structure-aware Python migration confined to `barLayout.left/center/right`.
`dashCards` and every other key are left alone. Backed up to `.pre-calendar-<ts>`
before it writes.

### Cause 2 — a one-time migration that ran every time
The `strings-state.json` jq block had no guard at all:

```
| if .colorMode == "synced" then . else .colorMode = "theme" end
| .ropeSegments      = 10
| .ropeSegmentLength = 5
```

Every install forced `colorMode` back to `theme` unless it was exactly `"synced"` —
so your custom start/end colours reverted each time — and reset the rope physics.
That's why the Colour dropdown kept showing **theme** after you'd set **custom**.

**Fixed:** gated on the legacy keys (`mode`, `leftEnabled`, `barPosition`, …)
actually being present, and a `colorMode` this build understands is never
overwritten. If jq fails, the original is restored.

### The reason nobody noticed: nothing checked
Three new guards, so this class of bug can't come back quietly:

- **`_zs_repair_state`** — before anything else, every `$SHELL_DIR/*.json` is
  parsed. Anything broken is restored from the newest valid backup (the shell's own
  `.bak` first, then the timestamped snapshots) and the broken copy is kept as
  `.corrupt-<ts>`. **This heals the machine you're on right now.**
- **`_zs_backup_state`** — snapshots *every* `*.json`, not four hand-picked names.
- **`_zs_verify_state`** — runs after every migration. Anything that stopped parsing
  is rolled back to this run's snapshot, loudly.
- **`ZEN_NO_MIGRATE=1 ./install.sh`** — skips every migration.

### And the shell now uses the backup it makes
`PanelState`'s recovery path copied `.bak` to a `.restored` file and stopped. Nothing
ever read it. It now swaps the good backup in, keeps the bad one as `.corrupt`, and
reloads — once per session, so a bad backup can't loop.

### Files
- **Changed:** `install.sh`, `PanelState.qml`, `ZenVersion.qml`

## v8.0.0-alpha-hf120 — the colour picker rotated every channel it touched

### One line
`ColorPickerOverlay.qml:382`

```qml
ColorPickerState.commit(overlay.currentHex + "ff")
```

`currentHex` is `#RRGGBB`. Appending `"ff"` makes `#RRGGBBAA`. But `ColorSwatch`
read 8-hex as **`#AARRGGBB`** — alpha first — and so does **Qt's `color` type**.
Every applied colour came back with its channels rotated one byte:

```
pick #ff1010  →  stored #ff1010ff  →  substring(2,8)  →  #1010ff   (red → blue)
pick #c08f3f  →  stored #c08f3fff  →  substring(2,8)  →  #8f3fff   (amber → violet)
```

Both your screenshots land exactly on that. The picker itself was never wrong.

The `"ff"` was there for Hyprland's border colours, which are `rgba(RRGGBBAA)`.
But `SettingsStateV2.hexToHyprRgba()` **already appends `ff` to a 6-hex value**. It
was redundant there and destructive everywhere else.

### One convention, everywhere: `#RRGGBB`, optionally `+ AA`
That's what `ColorPickerOverlay`'s own parser assumes (it reads `substring(0,2)` as
red) and what Hyprland wants. Three places disagreed with it; now none do.

- **`ColorPickerOverlay`** commits `currentHex`. Alpha is not the picker's business.
- **`ColorSwatch`** gets one parser — `_rgb()` / `_alpha()` / `_compose()` — used by
  the chip, the hex field and the write-back. It **preserves the alpha byte it was
  given**, so `#595959aa` inactive-border transparency survives an edit while
  `#ff9e64` string colours stay six characters.
- **`ZenStringsState`** never hands an 8-hex string to `color` again. `_rgb6()`
  guards `color1`, `color2` and `ropeColor`, and normalises on load — so the
  `#ff1010ff` already sitting in your `zen-strings-state.json` heals itself on the
  next start.
- **`ZenStrings`** was coercing `ZenStringsState.customColor1` (a *string*) straight
  to `color`, which is where the rendered strings got a different colour from the
  swatch. It reads `ZenStringsState.color1` / `color2` now. One source of truth.

Screenshot ropes follow, since hf118 pointed `ZenScreenshotOverlay` at
`ZenStringsState.ropeColor`.

### Verified
```
pick #ff1010 → chip #ff1010 → strings #ff1010 → rope #ff1010
legacy #c08f3fff on disk → _rgb6 → #c08f3f
border #595959aa + pick #ff1010 → #ff1010aa → rgba(ff1010aa)
```

### Files
- **Changed:** `ColorPickerOverlay.qml`, `ColorSwatch.qml`, `ZenStringsState.qml`,
  `ZenStrings.qml`, `ZenVersion.qml`

## v8.0.0-alpha-hf119 — FIX: hf117's slide-in parked both windows at 0,0

My regression, introduced one release ago.

### What happened
A layer-shell surface is torn down when the window hides. On show, `visible` flips
**before** the compositor reconfigures the surface — so at `onVisibleChanged`:

```
parent.width                    = 0
width = Math.min(1440, 0 - 48)  = -48
_place()  → x = 0, y = 0
_playEntrance() → dashEntX.to = 0        ← latched a stale target
```

Milliseconds later the surface gets its real size, `width` rebinds to 1440, and
`_place()` correctly recomputes the centre. But `dashEntrance` was **still running**
for 300ms, still writing `x` toward `0`. The animation outlived the correction and
won. Upper-left corner, every single open.

hf113 had no entrance animation, so its `_place()` corrections always landed. I
added the animation in hf117 without asking what happens if the geometry changes
while it plays.

### The fix
- **`_sized`** — `_place()` and `_playEntrance()` refuse to run against a parent
  with no width. No more computing an anchor inside a 0×0 box.
- **`dashPlaceTimer` / `settingsPlaceTimer`** — placement is deferred to one frame
  after the last geometry change, and re-arms itself while `_sized` is still false.
  So the entrance starts from a surface that actually has a size. It also collapses
  the ~8 `_place()` calls the 140ms `Behavior on width` used to trigger per resize
  into one.
- **`_place()` stops any running entrance** before it writes. A stale animation
  target must never outrun a correction. That's the invariant hf117 was missing.
- `_place(instant)` — snaps when it's about to hand off to the entrance, glides via
  the Behaviors when the user picks a different anchor on an open window.

### Files
- **Changed:** `shell.qml`, `ZenVersion.qml`

## v8.0.0-alpha-hf118 — strings die in fullwidth because you run two bars

### Why island worked and fullwidth/floating didn't
`musicSlotLocalX` and `musicSlotLocalWidth` are **bar-local** coordinates, and they
live in `ZenStringsState` as **one global pair**. Your bar target is **All
Monitors**, so there is one `Bar` per screen — and every one of them writes that
pair.

```
fullwidth, DP-2  3440px : centred 280px slot → localX = 1580
fullwidth, HDMI  1920px : centred 280px slot → localX =  820
```

The two bars overwrite each other. The 760px swing trips `shell.qml`'s `bigJump`
guard (threshold: 200px), `positionReady` re-settles, and the placeholder never
goes away.

**Island hides the bug entirely.** The bar hugs its content, so both monitors
produce the *same bar width* and therefore the *same local X*. The two writers
agree by accident. That is precisely why you saw strings come back the moment you
switched to island, and die again on fullwidth and floating.

hf115 fixed a real deadlock in the same file, which is why island became reliable.
It could not fix this one: the flag was never the problem here, the coordinates
were.

### Fix — one screen owns the strings
- **`ZenStringsState.stringScreen`** — computed, not claimed. With `all` or
  `primary` it's `Quickshell.screens[0].name`; otherwise it's the named target.
  Deterministic, so there is no construction-order race to lose.
- **`Bar.qml` publishes only if it owns the strings.** Three lines: a `screenName`
  property, an early return in `_doUpdatePos()`, and a loader that falls back to
  the plain `MusicWidget` on non-owning bars. Your other monitors now show the
  normal music module instead of an empty 280px slot.
- `stringsWindow.visible` gains `&& isReadyOwner`. The overlay renders on one
  screen, which is all a single-string design was ever able to do.
- hf115's claim/release machinery is retired in favour of the computed owner. The
  `Component.onCompleted` symmetry fix and `_setGlobalReady()` single-writer gate
  stay — both are still correct and still needed.

### FIX — screenshot rope colour ignored your picker
`ZenScreenshotOverlay.qml` had:

```qml
readonly property color ropeColor1: ThemeService.blue
readonly property color ropeColor2: ThemeService.purple
```

`ZenRope.qml` already defaults `ropeColor` to `ZenStringsState.ropeColor` — but the
overlay passes `ropeColor1`/`ropeColor2` down into all four `ZenRope` instances,
**shadowing that default**. So *Rope color → custom → `#c3c6ff`* reached the bar's
music strings and never reached the screenshot ropes. Hardcoded theme blue, every
time.

Both now resolve from `ZenStringsState.ropeColor`. `"inherit"` keeps the two-tone
look by falling back to the strings' colour pair; `theme` / `synced` / `custom` are
used verbatim, no remapping. The ropes, corner handles, selection border and
dimension label all follow.

The bar's own string colours (`ZenStrings.qml`) were already correct — they read
`ZenStringsState.customColor1/2` directly, and the picker emits plain `#rrggbb`.
Only the screenshot overlay was lying to you.

### Files
- **Changed:** `ZenStringsState.qml`, `Bar.qml`, `shell.qml`,
  `ZenScreenshotOverlay.qml`, `ZenVersion.qml`

## v8.0.0-alpha-hf117 — Window Placement is a grid now, and the windows fly in

Where it lives: **Settings → Panel → Window Placement**. It shipped in hf113 as two
dropdowns, which is why it was easy to walk past.

### Visual 3x3 picker
- Same idiom as **Notification Position**: a rectangle standing in for the monitor,
  a grid of anchor cells with arrow glyphs, the selected one outlined in the theme
  blue. Nine cells (the notification picker has six — no centre row), one grid each
  for the Control Center and the Settings window.
- **Remember last position** is its own switch instead of a hidden tenth dropdown
  entry. Flip it on and the window reopens where you dragged it; flip it off and it
  re-anchors to whatever cell is selected.
- Edge-margin stepper appears only for the anchors it actually affects — a centred
  window ignores the margin, so the row hides.
- Written as an inline `component PlacementGrid`, instantiated twice. One picker,
  two windows, no copy-paste.

### Slide-in entrance
- New **Slide in from the edge** switch (on by default). The window starts offset
  toward whichever edge it's anchored to and flies to its resting spot over 300ms,
  fading in. A centred window just rises. `ZenWindowPlacement.entranceOffset()` —
  written in hf113 and never called until now — supplies the direction.
- Maximised, fullscreen, and free-mode-after-drag skip the animation. Reopening a
  window you dragged somewhere specific shouldn't throw it across the screen.

### Two bugs caught while building it
- `ParallelAnimation.children[0]` is not a thing. The default property is
  `animations`. The animation targets carry ids now.
- `_playEntrance()` sampled `x` immediately after `_place()` to learn the resting
  position — but `Behavior on x` was mid-glide, so it captured wherever the glide
  happened to be, not the target. Resting position is computed from
  `ZenWindowPlacement` directly (`_restPos()`), and a `_snap` flag disables the
  Behaviors for the single frame where the entrance sets its start point.

### Files
- **Changed:** `PanelPage.qml`, `shell.qml`, `PanelState.qml`, `ZenVersion.qml`

## v8.0.0-alpha-hf116 — Glance: icons flickered on hover

### The flicker
`_showControls` was `open || dragArea.containsMouse`, and every `IconButton` has
its own `MouseArea { hoverEnabled: true }`.

An ancestor MouseArea's `containsMouse` drops to **false** the instant a descendant
MouseArea with `hoverEnabled` takes the hover. So:

1. Cursor enters the blob → `dragArea.containsMouse = true` → controls fade in.
2. Cursor lands on a button → the button's MouseArea steals the hover →
   `dragArea.containsMouse = false` → controls fade **out**.
3. Cursor is now over nothing (the controls are transparent) →
   `containsMouse = true` → fade in.

A loop, running at the fade animation's frame rate. Hence the blinking.

### The fix
- **`HoverHandler` instead of `containsMouse`.** A HoverHandler is passive: it
  stays `hovered` while the pointer is anywhere inside the item, children included.
  Nothing steals from it, so hovering the widget reveals *everything at once* and
  it stays revealed.
- `dragArea.hoverEnabled` turned off — `cursorShape` doesn't need it, and a second
  hover consumer was the whole problem.
- **Hidden controls are no longer hittable.** An `opacity: 0` Item still receives
  mouse events in QML, so the blob had invisible buttons sitting on top of it,
  eating clicks that should have expanded it. `enabled: g._showControls` on both
  control rows — `enabled` propagates to child MouseAreas.

### Files
- **Changed:** `ZenGlanceWidget.qml`, `ZenVersion.qml`

## v8.0.0-alpha-hf115 — the music strings deadlock, found properly this time

### First: hf113's strings "fix" was wrong, and is reverted
`Bar.qml`'s `_modeTransitioning` **defaults to `false`** and is only armed by
`onPanelModeChanged`. At a fresh login that lockout never runs. hf113 widened its
tolerance and added an expiry for a code path that isn't even active when the bug
appears. `Bar.qml` is restored byte-for-byte to its pre-hf113 state — it's a
delicate path tuned across five versions and it wasn't the problem.

### The actual deadlock
`ZenStringsState.positionReady` is **one global flag**. `shell.qml` creates **one
`stringsWindow` per screen** (`Variants { model: Quickshell.screens }`). Every
instance wrote that global, while its own *local* `positionReady` decided whether
it would ever write again.

`Component.onCompleted` was the asymmetry:

```qml
Component.onCompleted {
    ZenStringsState.positionReady = false   // global cleared
    stringsStabilityTimer.restart()         // …but NOT stringsWindow.positionReady
}
```

Every other reset site in the file sets **both**. This one set only the global.

Now follow it through. Instance A (the bar monitor) settles and commits:
`_tryMarkReady()` sets both flags true and calls **`.stop()` on both its timers**.
From then on `_onPosChanged()` early-returns, because the local flag is true.
A is retired.

Then `Quickshell.screens` changes — a second monitor arriving late at login, a
DPMS wake, a hotplug, `MonitorRecoveryService` doing its job. `Variants`
constructs an instance. Its `Component.onCompleted` fires and clears the **global**
flag. Instance A still holds `positionReady === true` locally, its timers are
stopped, and `_onPosChanged` won't touch anything.

**Nobody is left to set the global back to true.** The bar shows "Loading…" until
you restart the shell. That is the whole bug.

It also explains why hf113's hardening didn't help: `stringsHardFuse` fires once,
twenty seconds after construction. If the clobber lands after that, it's already
spent. `_gateRetries` never helps either, because `_tryMarkReady()` is never
called again.

### The fix — one writer
- **`ZenStringsState.readyOwner`** (new). The first instance whose screen carries
  the bar claims it; it's released on destruction and re-claimed by a surviving bar
  monitor if the owner's screen goes away.
- Every write to the global now goes through `stringsWindow._setGlobalReady()`,
  which is a no-op unless the instance owns the flag. **Nine call sites, one
  writer.** Non-bar screens can no longer clear a flag they don't own.
- `Component.onCompleted` resets **both** flags, claims ownership, and arms both
  timers.
- A watchdog on the owner: if the global goes false while the owner is locally
  ready, re-settle instead of hanging.
- `ZenStringsState.onPositionReadyChanged` logs every transition with the owner and
  slot coords. `qs -c zen-shell 2>&1 | grep ZenStrings` now tells you what happened
  instead of leaving you to guess. Given the two wrong guesses that preceded this,
  that log is the point.

### Kept from hf113
`stringsHardFuse` and the bounded `_gateRetries` stay — they're correct belts even
though neither was the buckle. The `musicSlotLocalX = -1` sentinel stays removed
from the `_onPosChanged` re-settle path.

### Files
- **Reverted:** `Bar.qml` (to pre-hf113)
- **Changed:** `shell.qml`, `ZenStringsState.qml`, `ZenVersion.qml`

## v8.0.0-alpha-hf114 — FIX: colour swatches did nothing (two causes, one mine)

### FIX — hf113 could silently wipe every setting parsed after `dashPlacement`
- **My regression.** hf113 added this to `PanelState.applyState()`:
  ```qml
  if (typeof s.dashPlacement === "string" && ZenWindowPlacement.isValid(s.dashPlacement))
  ```
  `applyState()` is one big `try { … } catch (e)`. If `ZenWindowPlacement` isn't
  resolvable at parse time, the `ReferenceError` is swallowed and **every key
  after that line keeps its default** — `borderColor`, the palette, the module
  layout, all of it. The next `saveState()` then writes the defaults back over
  `panel-state.json`. That is precisely the hf110 failure mode, reintroduced.
- **`applyState()` must never depend on another singleton.** The placement ids
  are validated against a local array literal now. No cross-singleton call.
- Nothing else in hf113 is touched. The Glance widget and the placement feature
  work as shipped.

### FIX — clicking a colour swatch in the Control Center did nothing (pre-existing)
- `ColorSwatch` delegates every swatch click to `ColorPickerState.requestOpen()`.
  Exactly **one** `ColorPickerOverlay` has ever listened for that signal, and it
  is mounted inside `ZenSettings`.
- The **Zen Control Center hosts the same settings pages** (`GeneralPage`,
  `ThemesPage`, `WidgetsPage`…) but **never mounted an overlay**. Since the
  dashboard became the default UI in hf99zu (`legacyUiEnabled = false`), every
  swatch click in the Control Center has fired the signal into the void.
- The hex `TextField` next to each swatch kept working, which is why this read as
  "the colours don't apply" instead of "the picker doesn't open".
- **Fix:** mount one `ColorPickerOverlay { anchors.fill: parent; z: 9999 }` at the
  root of `ZenDashboard`, same as `ZenSettings` does. `ColorPickerState` is a
  singleton, so the two coexist safely when legacy UI is re-enabled.
- This bug predates hf113 — it shipped with hf99zu. It only became visible now
  because the Control Center is where you actually live.

### Files
- **Changed:** `PanelState.qml`, `ZenDashboard.qml`, `ZenVersion.qml`

## v8.0.0-alpha-hf113 — Glance blob, window placement, and two old bugs

### NEW — Glance widget (merged weather + system)
- **One blob, two faces.** Settings → Desktop Widgets → **Glance Widget** →
  *Merge widgets*. Weather and the system monitor collapse into a single
  Pixel-style blob with a **cloud / thermostat icon switcher**. Turn it off and
  the classic `weatherWidget` + `sysmonWidget` come back untouched — they're
  gated on `!glanceMerged`, not removed.
- **The shape is a `Shape`, not a `Rectangle`.** The reference blob needs four
  corners with *different* elliptical radii (78×70 top-left, 66×84 top-right,
  72×64 bottom-right, 86×74 bottom-left). `Rectangle.topLeftRadius` and friends
  are **circular only**, so the background is one `ShapePath`: four `PathLine`
  edges, four elliptical `PathArc` corners. Every radius lerps toward 28 as the
  widget opens — the blob physically melts into a card.
- **Three tiers:** blob → compact → detail. `expand_circle_down` /
  `expand_circle_up` / `collapse_content`, exactly the Material set. Controls sit
  above the drag area so they're always clickable, and fade in on hover while
  collapsed.
- **The glyph is slanted at −13° and straightens as it opens.** One motion
  moment, nothing else animated for decoration.
- **Ink is derived, not hardcoded.** `_autoInk` reads the *surface's own hue*,
  then drops it dark + saturated on light surfaces or lifts it pale on dark ones.
  Porcelain `#FBEDE8` resolves to ≈`#6A2B16` — the burnt sienna from the
  reference — and Zen's `bg1 #24283b` resolves to a pale periwinkle. Near-greys
  (saturation < 0.08) are exempted so a grey surface doesn't come back red.
  So *Auto* is readable on any look, with no manual colour picking.
- Surface / text / accent each take **Default · Theme (auto-sync) · Custom**,
  matching the existing sysmon rows. New keys in `widgets-state.json`:
  `glance{}` + `positions.glanceX/Y`. **Both serialisers** — `WidgetsPage.saveState()`
  and `DesktopWidgets.posSaveTimer` — carry the block, so dragging a widget no
  longer clobbers the settings (the v6.16.3.4.3 trap, avoided this time).
- Requires **Material Symbols Rounded** for the icons. `install.sh` now checks
  for it and tells you the AUR package if it's missing. There is no fallback:
  `MaterialIcons.materialAvailable` is hardcoded `false` since alpha.10-hf6 and
  its Nerd Font codepoints don't cover `expand_circle_down` et al.

### NEW — Window placement (notification-style)
- Settings → Panel → **Window Placement**. Nine anchors — top-left, top-center,
  top-right, center-left, **center** (default), center-right, bottom-left,
  bottom-center, bottom-right — plus **Remember last position**. Independent
  settings for the Control Center and the Settings window, each with an edge-margin
  stepper (0–200px).
- New `ZenWindowPlacement` singleton owns the maths: `px()` / `py()` clamp inside
  the parent (a negative x on a layer-shell surface puts content off-screen with
  no way to drag it back), `clampX/clampY` for free mode, `entranceOffset()` for
  the slide-in direction, `isValid()` so a hand-edited `panel-state.json` can't
  strand a window.

### FIX — the Control Center opened at the upper-left corner
- **Root cause, two faults stacked.** `shell.qml` had both `anchors.centerIn` and
  `anchors.fill` declared on `zenSettingsPanel` — Qt logs *"Cannot specify
  centerIn and fill"* and the geometry is undefined. Worse: when
  `anchors.centerIn: (…) ? parent : undefined` flips to `undefined`, Qt tears the
  anchor down and the item reverts to its **base x/y = 0,0**, because nothing ever
  assigned them.
- **The trigger** was `onPressed: root.hasBeenDragged = true` (`ZenSettings.qml:284`
  and `:439`, `ZenDashboard.qml:905`). A **press**, not a drag. One click on the
  header — zero movement — and the window teleported to the corner.
- **Fix:** no anchors at all. Explicit `x`/`y` via a `_place()` function, the same
  shape as `DesktopWidgets._applyPositions()`. Drag state now sets on
  `onPositionChanged: if (drag.active)`. Placement fell out as a free feature.
- The dashboard's old `_clamp()` + `onXChanged`/`onYChanged` handlers are gone —
  they would have fought `_place()` and the drag target for ownership of x/y.

### FIX — music strings stuck on "Loading…"
The placeholder in `MusicStrings.qml` is bound to one thing: `positionReady`.
Nothing to do with cava, playerctl or the rope colour. Three separate ways it
could wedge, all now closed:
- **The `-1` poison.** `shell.qml`'s re-settle path set
  `ZenStringsState.musicSlotLocalX = -1`, but `_tryMarkReady()`'s sanity gate
  rejects anything `< 20` and the visibility gate needs `>= 0`. If `Bar.qml`
  didn't republish, the stability timer restarted itself forever. The `bigJump`
  check already detects a real move — the sentinel is gone.
- **The starved fuse.** `stringsMaxWaitTimer` is the "just show it already" escape
  hatch, but **four** handlers call `.restart()` on it. A re-settle more often
  than every 15s starved it. Added `stringsHardFuse`: armed once at construction,
  nothing may restart it.
- **The lockout that never lifts** (the likely trigger). `Bar.qml`'s
  `_modeTransitioning` gate demanded **two consecutive reads within 2px**. Your bar
  renders seconds and an active-window title; both resize the side rows every
  second, which shifts the centred music slot's `x`. The gate could never clear,
  `updatePos()` never wrote. Tolerance widened to 3px (nowhere near a real mode
  change, which moves the slot by hundreds of px) and the lockout now expires after
  ~4s.
- Each guard logs a `console.warn` when it fires, so if this ever recurs,
  `qs -c zen-shell 2>&1 | grep -i strings` names the culprit instead of leaving you
  to guess.

### Files
- **New:** `ZenGlanceWidget.qml`, `ZenWindowPlacement.qml`
- **Changed:** `shell.qml`, `Bar.qml`, `DesktopWidgets.qml`, `WidgetsPage.qml`,
  `WidgetsState.qml`, `PanelState.qml`, `PanelPage.qml`, `ZenSettings.qml`,
  `ZenDashboard.qml`, `ZenVersion.qml`, `install.sh`

## v8.0.0-alpha-hf112 — FIX: opacity sliders did nothing (the look was overriding them)
- **Root cause.** Since hf99m the Shell Look **overrode the opacity at render
  time**: `PanelState.lookApplyBar ? LookService.panelOpacity : Theme.barOpacity`.
  So the Bar Opacity slider wrote `Theme.barOpacity` faithfully — and the bar
  ignored it, because the look always won. Same for the dock, Quick Settings,
  Start Menu and notifications.
- **A look is now a PRESET, not an override.** Picking one *writes* its values
  (opacity + corner radius) into the real settings, honouring the Apply-To
  flags; afterwards **your sliders are the single source of truth** and nothing
  re-overrides them at render time. **"Custom" never touches your values.**
- **Second bug found while fixing this:** `ZenDock` read
  **`PanelState.barOpacity` — a property that does not exist** (the bar's
  opacity lives on `Theme`). So "sync from bar" dock opacity was reading
  `undefined`. Now reads `Theme.barOpacity`. Verified: **0 references** left,
  and every preset target checked to exist and be writable.
- **New: the Zen Control Center has its own opacity**, plus per-surface sliders
  under **Shell Look → Opacity** — Control Center, Quick Settings, Start Menu,
  Notifications (30–100%). The look preset writes them; you adjust freely.

## v8.0.0-alpha-hf111 — every timezone in the world, not a hand-picked 20
- The clock picker shipped a **curated list of ~20 zones** — no Qatar, no
  Kigali, no Chatham. New **`TimezoneService`** reads the real list from the
  system: `timedatectl list-timezones` first, falling back to a
  `/usr/share/zoneinfo` walk (works without systemd), and finally to a small
  built-in list so the picker is never empty.
- **484 zones** on a normal install, across Africa / America / Antarctica /
  Asia / Atlantic / Australia / Etc / Europe / Indian / Pacific — `Asia/Qatar`
  included. Labels read `Asia / Qatar`, sorted region-then-city, with **UTC
  pinned first**.
- Two things the walk got wrong until tested: `-type f` alone **dropped every
  symlinked zone (UTC among them)** — now `\( -type f -o -type l \)` — and
  `posix/`, `right/`, `SystemV/` aliases are filtered out.
- Nothing else changed: the clocks already convert with `TZ=<zone> date`, so
  any IANA id works the moment it's picked.

## v8.0.0-alpha-hf110 — FIX: settings could be silently overwritten with defaults
- **Root cause of "nawala yung panel sa top at colours".** `applyState()` wraps
  the whole load in one `try/catch` and only logs on error. So a *single* field
  it couldn't apply aborted every assignment after it, leaving **defaults** in
  memory — and `onLoaded` still flipped `_loaded = true`, which allowed the next
  `saveState()` to write those defaults straight over your real
  `panel-state.json`. Panel position, colours, everything.
- **Fixes, all verified with simulated files:**
  - `applyState()` now **reports success**; a partial apply sets `_loadDegraded`
    and **all writes are refused** — a broken read can never overwrite good data.
  - The write is **atomic**: temp file → validate → rotate `.bak` → `mv` into
    place. A truncated heredoc can no longer corrupt the file. (Validation uses
    python3 only if present, so a machine without it still saves.)
  - **Unknown keys are preserved.** The file is merged over what was read, so a
    field written by a newer shell — or a client's own key — survives instead of
    being dropped on the next save. Tested: `clientOnlyKey` round-trips.
  - A malformed payload is **refused before writing** (QML-side `JSON.parse`
    check plus the shell-side validation).
  - On a partial load the previous `panel-state.json.bak` is copied to
    `.restored` for you, untouched.
- **install.sh now snapshots your state** (`panel-state.json`,
  `widgets-state.json`, animation/notification state) to `*.bak-<timestamp>`
  before doing anything. It still never writes them — this is belt-and-braces
  for client machines, alongside the theme guard from hf99zy.

## v8.0.0-alpha-hf109 — window stays on screen; layout drops columns instead of overflowing
- **FIX — the window could sit half off the monitor.** Once dragged, nothing
  stopped it: move it toward an edge (or switch to a smaller/rotated screen) and
  the right side of the dashboard simply hung outside the display. It now
  **clamps back inside** on every move / resize / screen change, and the default
  size leaves a smaller margin (48px) so it fits narrow panels.
- **FIX — three columns can't fit a rotated 1080 panel**, so scaling them down
  just made everything illegible. The layout now **drops columns instead**:
    - under **980px** the right rail hides (Quick Settings / media / power live
      on their own pages anyway),
    - under **720px** the sidebar collapses to **icons only** — the hover
      tooltips already name each module.
  Minimum content width falls 992 → 692 → 522px accordingly, so the fit scale
  stays at 100% instead of shrinking the text.
- Checked across 1440 / 1200 / 1000 / 900 / 760 / 640px: content always fits.

## v8.0.0-alpha-hf108 — the NETWORK pill lines up with the rest
- **FIX — NET was the odd one out.** Every pill is `badge · label · value ·
  s1 · s2 · bar`, but NETWORK has no percentage and no usage bar, so those two
  slots collapsed and its contents floated to a different height than CPU / GPU
  / RAM / VRAM beside it.
- The slots are now **fixed-height containers**, not collapsing items: NET fills
  the value slot with its ↑/↓ readings and the bar slot with a thin accent rule,
  and reserves the two text slots as blank space. Both layouts total **113px**,
  so the badges, labels and bars land on exactly the same lines.

## v8.0.0-alpha-hf107 — nothing overflows; rows line up
- **FIX — cards ran off the right edge.** hf105 gave the content a minimum size
  and let it scroll, so on a smaller window the rail and half the cards simply
  sat outside the view. Now the dashboard computes a **fit scale** — the largest
  scale at which the three columns still fit — and treats your zoom as a
  **ceiling**: zooming out always works, zooming in stops at the fit. The
  percentage reads **"Fit 88%"** when it's clamped. Verified from 2560px down to
  760px: content width never exceeds the viewport.
- **FIX — ragged rows.** Each card used its own height, so neighbours in the
  same row ended at different points (System Monitor vs Clocks, Calendar vs
  Active Window). The packer now computes **one height per row — the tallest
  card in it** — and every card in that row uses it, so a row reads as a single
  band. Resizing one card lifts its whole row, which is what "pantay" means.

## v8.0.0-alpha-hf106 — bigger brand mark + colour variant
- The mark was **smaller than the title next to it** (34px badge, 20px glyph).
  It's now a **44px badge with a 34px glyph** — roughly 3.4× the cap height of
  "Zen Control Center", so it reads as the brand.
- **Colour variant added** (`assets/zen-logo-color.svg`): the six facets in
  purple / pink / blue / white / teal / green around a yellow core, same
  geometry as the mono mark. It ships as the **default**, on a neutral plate so
  its own palette isn't fighting a blue tint.
- Clicking the badge now **cycles colour → mono → 禅 → colour** (tooltip names
  the next one). Still falls back to 禅 if the SVG can't load.
- Both SVGs go out with the `assets/` sync added in hf103, so a plain
  `./install.sh` picks them up.

## v8.0.0-alpha-hf105 — responsive: horizontal scroll + UI scale
- **Narrow / vertical monitors don't crush the layout any more.** The three
  columns need ~**992px** (232 sidebar + 288 rail + a readable 420 main +
  margins). Below that the content keeps its minimum size and the view
  **scrolls horizontally** — a scrollbar appears automatically, and only when
  it's actually needed (same for vertical).
- **UI scale (0.70–1.40).** New **− 100% +** control next to the window buttons:
  shrink the whole Control Center to fit a vertical monitor, or blow it up on a
  4K. Click the percentage to reset. Keyboard: **Ctrl +**, **Ctrl −**,
  **Ctrl 0**. Persisted in panel-state.json.
- The window itself already sizes to the screen (`min(1440, screen − 80)`), so
  scale + scroll together mean the dashboard is usable from a 1366×768 laptop to
  a 3440×1440 ultrawide to a rotated 1080×1920 panel.

## v8.0.0-alpha-hf104 — content max-width; capsules keep their shape
- **FIX — everything stretched when maximized.** On a 3440px monitor the pages
  and the dashboard grid ran edge-to-edge, which breaks the proportions the
  design assumes (look at the Displays page in that screenshot). The main
  content is now **capped at 1500px and centred** — search bar included — so a
  fullscreen window gives margins, not stretched rows.
- **FIX — the System Monitor pills turned into circles, then sausages.** Their
  size came from the card: a short card made `min(w,h)/2` ≈ half the width (a
  circle), a tall one made a 2.8:1 sausage. The pill now derives from the
  available height, **clamped to 110–260px tall and ≤150px wide**, holding the
  **1.75:1 capsule** at every card size — extra card height becomes padding
  around the pills, not stretch. Same cap applied to the **desktop widget**
  (≤300px × ≤170px, scaled), which is where you first saw them run long.
- Default System Monitor card is a bit shorter (268 → 236px).
- The yellow circle is a mockup artifact — it never existed in the shell
  (checked: no yellow fill in either the widget or the dashboard).

## v8.0.0-alpha-hf103 — buttery drag, arrow keys, clock hour strip, hex logo
- **Drag now feels like the desktop widgets.** A `GridLayout` snaps items to
  their slots instantly — that was the stiffness. Cards now **animate their
  x/y/width** into place (170ms OutCubic), skipped for the card you're holding
  so it tracks the cursor, and the held card lifts (scale + fade).
- **Arrow keys move a card.** Press a card's drag handle to select it (blue
  ring), then **←/→** step it one slot, **↑ / Home** send it to the top,
  **↓ / End** to the bottom, **Esc** deselects.
- **Clocks card taps to expand**, like weather: each clock gets a **scrollable
  strip of the next 12 hours** (drag left/right), with "now" highlighted —
  handy for lining up a call across Manila / Winnipeg / Sydney.
- **New hex brand mark** (`assets/zen-logo.svg`) — click the badge to switch
  between the **hex logo** and the written **禅** mark; the choice persists.
  Falls back to 禅 automatically if the SVG can't load.
- **FIX (would have shipped broken):** the installer only ever copied `*.qml`
  plus `assets/logos/*.svg`, so the new asset would have silently gone missing
  on a real install. It now syncs the whole **`assets/` tree** — verified with a
  simulated install (2 files, including the new logo).

## v8.0.0-alpha-hf102 — FIX: the right rail was eating the dashboard
- **FIX — the rail ballooned and squeezed the grid.** The sidebar and the right
  rail only had a `preferredWidth`, which a `RowLayout` treats as a hint. A long
  string in a rail child — the MPRIS player name (`brave.instanc…`), the active
  window title — grows that column's `implicitWidth`, and since `preferredWidth`
  is not a cap, the rail simply took the space. The main grid got whatever was
  left, which is why the cards were crushed and their labels overlapped.
- Both columns now have **hard min == max clamps** (sidebar 232, rail 288), the
  main area has a `minimumWidth` of 420, and the strings that caused it
  (player name, window title/class) are bounded + elided.
- Layout maths, checked: at 1440px → sidebar 232 | **main 844** | rail 288, i.e.
  **202px per grid column**; still healthy down to a 1120px window.

## v8.0.0-alpha-hf101 — 4-column grid, real H/V resize, gap-free packing
- **The gaps are gone.** A `GridLayout` auto-flow leaves a hole whenever the
  next card doesn't fit the remaining columns — that's the blank space you saw.
  The dashboard now runs its own **first-fit packing**: each card is placed in
  the first free slot that fits, so a narrow card slides into the hole beside a
  wide one and two cards sit shoulder-to-shoulder. Verified in simulation:
  the default layout leaves **0 empty cells**, and mixed spans (3,2,1,4,1)
  pack with **no overlaps**.
- **The grid is 4 columns**, so a card can be a **quarter / half / three-quarter
  / full** width (was only half or full). Old saved layouts migrate cleanly —
  a stored `span:1` (old half) becomes 2/4, `span:2` (old full) becomes 4/4 —
  and new values are tagged so they're never migrated twice.
- **Resize horizontally *and* vertically:** drag the **right edge** to change
  width (snaps to columns), the **bottom grip** for height, or the **corner
  grip** for both at once. A small badge shows the current span (e.g. `2/4`).
  Cards in a row stretch to the row height, so there's no vertical gap either.
- All three grips reorder/resize live and write `panel-state.json` **once, on
  release** (same fix as the drag).

## v8.0.0-alpha-hf100 — performance, smooth drag, v8 versioning
- **FIX — dragging felt like glue.** `dashMove()` called `saveState()` on every
  pointer-move frame, so each pixel of drag wrote panel-state.json to disk.
  Reorder is now live but **writes once, on release** (`commit` flag); the same
  for the resize grip. Added **hysteresis** (the pointer must be well inside a
  target card) so cards stop ping-ponging on the boundary, plus a small lift
  (scale + fade) on the card you're holding.
- **FIX — the dashboard stalled on open.** A `StackLayout` builds **every**
  child eagerly, so all **31 settings pages** were constructed the instant you
  pressed SUPER+C. They're **asynchronous `Loader`s** now — a page is created
  only when you navigate to it. Verified the 31 loaders still map 1:1 to the
  31 nav entries.
- **Profile card opens User Profile.** Clicking your avatar in the sidebar jumps
  to that page — resolved by **label lookup**, not a hardcoded index, so it
  can't drift when modules are added or removed.
- **Versioning moved to v8, alpha channel; the beta line is retired.**
  `ZenVersion` now derives everything: `semver = "8.0." + patchNum`,
  `version = "v8.0.0-alpha-hf100"`, `series = "v8.0"`. The two places that
  hardcoded a version string (Quick Settings + dashboard sidebar) now read
  `ZenVersion`, so a bump happens in exactly one file.

## v7.0.0-beta.1-hf99zz — dashboard: resizable, drag-anywhere card grid
- **The dashboard is a real grid now.** Cards are driven by a model
  (`PanelState.dashOrder` + a `Loader` per id), so reordering just moves the
  model — no code moves, and a new card is one Component + one id.
- **Time and Weather are separate cards** (they were one hero strip), joining
  **Calendar** and **Active Window** as first-class cards. Nine in total:
  Time · Calendar · System Monitor · Clocks · Weather · Workspaces ·
  Active Window · Workflow · Audio.
- **Per-module resize** (you asked for this): in **Edit mode** each card gets
  - a **drag handle** — drag it over another card to swap places, like the
    pinned items in the Start Menu (nearest-centre targeting, live),
  - a **span toggle** — half width ⇄ full width,
  - a **resize grip** — drag to set that card's height (70–600px).
  Every card's `{span, height}` persists in panel-state.json; only cards you've
  actually changed are stored. **Reset** restores the mockup layout.
- Defaults mirror your mockup: Time | Calendar side by side, System Monitor
  full width, Clocks | Weather, Workspaces | Active Window.
- Verified the nine ids line up across the three places that must agree —
  `cardComponent()`, `dashCardDefaults`, and `dashOrder` — and removed the
  fragile `parent.parent.parent` lookups in the calendar (id-based now).

## v7.0.0-beta.1-hf99zy — installer never clobbers your themes; media / active window / quick actions
- **Installer: your edited themes are safe.** `install.sh` used to `cp` every
  shipped builtin theme straight over yours. Now a builtin is only written when
  it's **missing** or **byte-identical**; if you changed it, **yours is kept**
  and the shipped copy is parked beside it as `<name>.json.new` so you can diff.
  `ZEN_FORCE_THEMES=1 ./install.sh` restores the old overwrite (with a backup).
  Verified with a simulated edited theme — the edit survived.
- Audited the rest: the QML prune only ever touches `*.qml`; **no state file
  (`panel-state.json`, `widgets-state.json`, …) is copied by the installer**;
  `current-theme.json` is written only when absent. Save/load symmetry checked
  for every setting added this session (shellLook, look apply-flags, attach,
  qsOrder, qsProfileAtBottom, dashOrder, legacyUiEnabled) — all persist.
- **New `MprisService`** — media state via `playerctl`, polled 1s, pipe-separated
  in one call so a missing field can't shift the others; degrades quietly when
  playerctl or a player is absent. Exposes status/title/artist/art/position/length
  and playPause/next/previous. Parse verified against a stubbed playerctl.
- **Media Controls card** (right rail): album art, title/artist, progress bar with
  times, and prev / play-pause / next in Material Symbols.
- **Active Window card** — current window title + class, polled from
  `hyprctl activewindow -j`.
- **Quick actions** under the sidebar profile: dark mode, Displays, General
  settings, lock session — each with a hover tooltip.
- Caught before shipping: the new cards used `Process`/`StdioCollector` while
  `Quickshell.Io` wasn't imported — that would have failed at load.

## v7.0.0-beta.1-hf99zx — dashboard stays on its monitor; readable text everywhere
- **FIX — the dashboard followed the cursor to another monitor.** Its window
  keyed off `Hyprland.focusedMonitor` *live*, so moving the pointer to a second
  screen dragged the panel along. It now pins to the monitor it was **opened
  on** (`root.dashboardScreenName`, captured on open, cleared on close) —
  exactly how the Settings window has always behaved.
- **FIX — black, unreadable text on the dark shell.** QtQuick Controls ship a
  *light* palette (black text, black placeholders), which is why the search box
  looked black. The dashboard now sets a **theme-aware palette** — text,
  placeholder, base, highlight, button — and the search field sets its own
  `placeholderTextColor` / selection colours.
  Implementation detail: `palette` does **not** exist on a plain `Item` /
  `Rectangle` (qmllint: *"palette is used but it is not resolved"* — the same
  class of runtime crash as the earlier `onDChanged` bug). It lives on
  `Control`, so the dashboard's content is wrapped in a padding-less, background-less
  **`Pane`**, whose palette propagates to **every descendant control** —
  including all 31 settings pages mounted inside.

## v7.0.0-beta.1-hf99zw — fuzzy search results, QS expand panel, draggable window
- **Fuzzy search that shows pages, not just a sidebar filter.** Typing opens a
  ranked **results dropdown** under the box listing every matching module
  (name + category); click or press Enter to open it. Subsequence matching with
  a score that favours word-starts and runs — `bmod` → Bar Modules, `shl` →
  Shell Look, `gamedet` → Game Detection (verified). The sidebar now always
  shows every module.
- **The old Quick Settings expand panel is in the dashboard**, on the right rail:
  **Wi-Fi** (network list + Scan + connect), **Bluetooth** (devices),
  **Audio** (output + mic sliders), **Notifications** (list + Clear all) —
  driven by the same `ConnectivityService` / `NotificationService`.
- **Window behaves like a window**: **drag** it by the sidebar brand row (title
  bar), **maximize** toggles full-screen, **✕** closes. The **minimise** button
  is gone (it just closed the panel anyway). Dragging is disabled while
  maximized; the panel re-centres when un-dragged.

## v7.0.0-beta.1-hf99zv — remove Plugins from the dashboard sidebar
- **Plugins** module removed from the Zen Control Center sidebar (Hyprbars has
  its own page now, so it was redundant). Removed from all three places that
  must stay in lockstep — the nav list, the category map, and the StackLayout
  page mounts — then re-verified: **32 nav = 32 categories = 31 pages + 1**,
  and each label still maps to its own page (Wallpaper → WallpaperPage, …).
  Get this wrong in one place and every module after it opens the wrong page.
- The Settings window keeps its Plugins page (it's hidden by default anyway).

## v7.0.0-beta.1-hf99zu — dashboard: capsules, search, window buttons, categories
- **FIX — pills still drew as circles.** With five cards across a wide area each
  card was *wider* than it was tall, so `min(w,h)/2` = half the width = a circle.
  The pills row is taller now and each card is width-capped (150px), so it's a
  proper vertical capsule like the desktop widget.
- **Search bar** (Ctrl K hint) over the main area — filters the sidebar modules
  live and Enter jumps to the first hit. Clear button included.
- **Window controls** (Material Symbols): minimise / maximise / close, top right.
- **No auto-exit.** Clicking outside no longer closes the dashboard (it used to
  vanish mid-edit). Only Esc or the ✕ button close it.
- **Sidebar grouped by category** — APPEARANCE / INPUT & DISPLAY / CONNECTIVITY /
  SYSTEM / PRODUCTIVITY / OTHER, with a **hover tooltip** naming the module and
  its category. Nav ↔ category ↔ page indices verified aligned (33 = 1 + 32).
- **Classic Quick Settings popup and Settings window are hidden** now that both
  live in the dashboard (`PanelState.legacyUiEnabled`, default off). Escape
  hatch: `qs -c zen-shell ipc call zen toggleLegacyUi` brings them back.
- Still to come: MPRIS media controls (needs a playerctl-backed service),
  active-window card, sidebar quick-action buttons.

## v7.0.0-beta.1-hf99zt — dashboard: real Pills colours, per-clock cards, ALL modules
- **FIX — "circle" pills didn't follow your colours.** The dashboard drew its
  capsules with theme colours instead of the widget's **card colour / opacity**.
  `WidgetsState` now also mirrors `sysmonCardColor` + `sysmonCardOpacity` and
  exposes the same derived `sysmonCardBg / sysmonCardText / sysmonCardSubText /
  sysmonCardLine` (auto-contrast). The dashboard capsules now render **exactly**
  like the desktop widget — white cards with dark text, or whatever you picked.
- **Clocks module** — one card **per configured clock** (so each can be sized
  and read on its own), each honouring its **own style**: an analog Pixel face
  when that clock is Analog, otherwise digital in your clock font. Timezone
  times come from the OS zoneinfo cache (same `TZ=… date` mechanism the desktop
  widget uses — Intl isn't available in the Quickshell JS engine). It's part of
  the drag-reorder list.
- **All 32 Settings modules moved into the dashboard** — General, Decoration,
  Animations, Themes, Displays, Input, Panel, Bar Modules, System Tray, Hot
  Corners, Sound & Network, Notifications, Battery, User Profile, Updates,
  Desktop Widgets, Wallpaper, Plugins, Focus Spaces, Quick Notes, Network Pulse,
  Smart Dim, Title Translator, Hyprbars, Game Detection, Dock, Default Apps,
  App Float Rules, Desktop, User Management, Login Screen, Shell Look. They are
  the **same components** the Settings window mounts (no copies), and the
  sidebar is now scrollable. Nav ↔ page indices verified 1:1 (33 = 1 + 32).

## v7.0.0-beta.1-hf99zs — dashboard: fixed pills, mirroring, QS modules, Edit/reorder
- **FIX — capsules rendered as circles/ellipses.** `radius: width / 2` on a
  wide card makes the radius exceed half the *height*. Clamped to
  `Math.min(width, height) / 2` in the dashboard, the Quick Settings mini-pills
  and the desktop widget, so they're proper capsules at any size.
- **System Monitor now mirrors the desktop widget design** in the dashboard:
  **Pills** → capsule cards; **Classic** → compact labelled bars. Both read one
  shared `sysModel`, so the numbers can't drift apart. Accent + font follow
  `WidgetsState` as everywhere else.
- **Weather** in the dashboard **taps to expand**, same as the widget and the
  Quick Settings: hourly strip (temp · icon · precip% · hour, drag left/right)
  plus the 7-day row.
- **Quick Settings modules are in the dashboard as-is**: the **same**
  `WorkflowProfilePicker` component the panel uses, and **audio + mic sliders**
  driven by the same `ConnectivityService` (`setVolume` / `setMicVolume`).
- **Edit button** (Google **Material Symbols** `edit` ligature) in the sidebar
  toggles **reorder mode**: drag a row or use ▲▼ to rearrange the dashboard
  cards (Time+Weather / System Monitor / Weather / Workflow / Audio /
  Workspaces), Reset restores the default. Order persists in
  `PanelState.dashOrder` — same 1-column-GridLayout `Layout.row` technique as
  the panel, so nothing moves in code.
- The hero clock also mirrors the **Analog (Pixel)** design when selected.

## v7.0.0-beta.1-hf99zr — FIX: Hyprland 0.55 layerrule syntax (Glass frost)
- **Hyprland 0.55 changed `layerrule`** and the shipped conf broke on it:
  `invalid field blur: missing a value` / `invalid field type ignorealpha`.
  Verified against the 0.55.0 source (`handleLayerrule`,
  `LayerRuleEffectContainer`): elements are now **`key value`**
  (space-separated), matchers take a **`match:`** prefix, and **`ignorealpha`
  was renamed `ignore_alpha`**. Valid layer effects: blur, blur_popups,
  ignore_alpha, xray, dim_around, no_anim, animation, order, above_lock,
  no_screen_share.
- `zen-shell-look.conf` now ships the 0.55 form active:
  `layerrule = blur 1, ignore_alpha 0.35, match:namespace ^(zen-shell-.*)$`
  with the 0.54 form kept as a commented LEGACY block.
- **install.sh auto-detects your Hyprland version** and swaps to the legacy
  lines on 0.54 or older (tested both ways with a stubbed hyprctl).
- **LookService** (runtime frost for pop-ups) now probes the new syntax with
  `hyprctl keyword` and falls back to the legacy form if it's rejected — so
  the shell frosts correctly on 0.54 *and* 0.55 without any user action.

## v7.0.0-beta.1-hf99zq — FIX: installer never copied the Hyprland drop-in confs
- **Root cause of "source= globbing error: found no match".** The installer's
  `zen-shell-look.conf` / `zen-shell-dashboard.conf` copy steps were nested
  inside the monitor-watcher block, which is gated on
  `scripts/zen-monitor-watcher.service` — a file this tarball doesn't ship.
  The gate was always false, so the confs were **never copied**, while
  hyprland.conf still ended up with a `source =` line → Hyprland errored.
  (`hypridle.conf` lived outside the gate, which is why only that one worked.)
- Both drop-ins now live in a standalone, **always-run** `install_zen_hypr_dropins()`
  that copies the file **first**, then adds the `source =` line idempotently.
  **Re-running install.sh repairs an already-broken config** — the missing file
  simply appears, and no duplicate source line is added. Verified against a
  simulated broken setup.

## v7.0.0-beta.1-hf99zp — Zen Control Center (merged dashboard) — v1
- **New `ZenDashboard.qml`** — the merge you asked for: **Quick Settings
  styling at Control-Center size**, one glassy window:
    - **Left sidebar** — brand, nav (Dashboard / System Monitor / Appearance /
      Shell Look / Widgets / Panel) and the **profile card pinned at the
      bottom** (avatar, user@host, Online, distro).
    - **Main area** — Dashboard page: hero card (big clock + weather), the
      **System Monitor capsule row** (CPU/GPU/RAM/VRAM/NET with clock speeds),
      a 7-day weather strip, and a clickable **workspaces** grid. The other nav
      entries mount the **same** settings pages the Settings window uses
      (ThemesPage / ShellLookPage / WidgetsPage / PanelPage) — merged, not
      duplicated.
    - **Right rail** — quick toggles (Wi-Fi / Bluetooth / Audio / Dark Mode),
      **Power Profile** selector, and **System Uptime**.
- **Glass-aware**: with the Glass look the whole dashboard and every card go
  translucent so Hyprland's layer blur shows through. Fonts/accents follow the
  same `WidgetsState` settings as the desktop widgets.
- **Keybinds**: shipped `hypr-config/zen-shell-dashboard.conf` binds **SUPER+C**
  and **SUPER+,** to the same dashboard (`ipc call zen toggleDashboard`); the
  installer sources it. New IPC: `toggleDashboard` / `openDashboard` /
  `closeDashboard`.
- Window is layer-shell Overlay, masked to the panel (clicks pass through
  around it), **OnDemand** keyboard focus, focused-monitor only, Esc to close.
- Existing Quick Settings panel and Settings window are **untouched** — this is
  additive, so nothing you rely on changed.
- v1 scope: the mockup's media player, search bar and bottom tab bar aren't in
  yet (no MPRIS service exists yet); everything else is live.

## v7.0.0-beta.1-hf99zo — "Glass — Advanced" Quick Settings + profile at the bottom
- **Glass card treatment.** When the Shell Look is **Glass — Advanced** (and
  the Control Panel apply-flag is on), every Quick Settings card switches to a
  frosted style: much more translucent (0.28 vs 0.6 alpha), rounder (18px), and
  a brighter border — so the Hyprland layer blur reads through the cards, not
  just the panel. Animated on switch. Applies to all nine cards (profile,
  weather, system, time, calendar, workflow, audio, connectivity, power).
  `SettingsSection` gained an opt-in `glass` property, default **off**, so every
  settings page is untouched.
- **Profile card at the bottom** (mockup layout). New toggle in the panel's
  **Layout** tab: the user/profile card moves from the top of the panel to the
  bottom, and slims down (the long Hyprland build line hides) so it reads as a
  footer bar with avatar + name. Persisted in `PanelState.qsProfileAtBottom`.
- Both are additive: defaults reproduce the current panel exactly.

## v7.0.0-beta.1-hf99zn — fix: shell wouldn't load (calendar change handler)
- **FIX:** hf99zm failed to start —
  `Cannot assign to non-existent property "onDChanged"`. The calendar's
  day property was named `_d`, and QML derives the change handler from the
  property name (an underscore-prefixed `_d` would need `on_DChanged`).
  Renamed it to `todayD` with `onTodayDChanged`. qmllint can't catch this
  (it's resolved at runtime), so all change handlers in the touched files were
  audited against their declared properties — this was the only mismatch.

## v7.0.0-beta.1-hf99zm — QS mirrors Analog + Pills; calendar month navigation
- **Analog (Pixel) clock now mirrors into Quick Settings** — pick Analog in
  Clock Design and the QS time card shows the same scalloped analog face
  (the digital text + weekday hide, since the face carries the day label).
- **System Monitor "Pills" mirrors too** — choosing Pills shows a compact row
  of four capsule cards (CPU / GPU / RAM / VRAM) in Quick Settings: icon badge,
  label, big % with superscript, a temp/GB readout and a progress bar, all in
  your accent + font. Classic keeps the existing bars/detail views (its toggle
  hides in Pills mode).
- **Calendar month navigation** — ‹ › step through months; click the month
  title to jump back to today. The "today" highlight only appears when you're
  viewing the current month, and the view follows the clock across midnight.

## v7.0.0-beta.1-hf99zl — Quick Settings weather behaves like the desktop widget
- The QS weather card now **taps to expand**, exactly like the desktop widget:
  collapsed shows the current conditions (with a "tap for hourly + 7-day"
  hint); expanded reveals the **hourly strip** — temperature, icon, precip %,
  hour — which you **drag left/right** to scroll, followed by the 7-day row.
- The hourly precip % and the highlighted Today card follow the weather accent
  you picked; all text uses your chosen weather font.
- Implementation note: `SettingsSection`'s default slot is a `ColumnLayout`,
  so the tap target is a **TapHandler** (an event handler, not an item) —
  an anchored MouseArea would have been inserted as a layout row.

## v7.0.0-beta.1-hf99zk — section order moves to the side panel + responsive height
- The section-order list at the **bottom** made the Quick Settings panel run
  off the screen. It now lives in the **side (expand) panel** as a **Layout**
  tab — same drag / ▲▼ / Reset, just opened to the right like Wi-Fi, Audio and
  Notifs. The ≡ header button toggles it (and highlights while open).
- **Responsive height:** the single-column limit now adapts to the screen
  (`min(720, screenHeight − 120)`, floor 520), so on shorter displays the panel
  flips to the two-column cascade sooner instead of growing past the display.

## v7.0.0-beta.1-hf99zj — draggable Quick Settings sections + QS mirrors widgets
- **Drag-to-reorder Quick Settings.** A new **reorder button** (≡ icon) in the
  panel header opens a **Section order** editor: drag a row (or use ▲▼) to
  rearrange Profile / Weather+System / Time+Calendar / Workflow / Audio /
  Connectivity / Power. **Reset** restores the default. The order persists in
  `PanelState.qsOrder` (validated + forward-compatible on load).
  Implementation note: the panel's main column became a 1-column `GridLayout`
  so each section is placed by `Layout.row` — reordering moves nothing in the
  code, it just re-binds a row index. The two decorative dividers are hidden
  since sections are cards.
- **Quick Settings now mirrors your desktop widgets.** New read-only
  `WidgetsState` singleton watches `widgets-state.json` (`watchChanges: true`,
  plus a 5s safety reload), so the QS cards follow the settings you already
  chose for the desktop:
    - **Time card** — clock design (stacked / mono / raised …) + clock font
    - **Weather card** — weather font + accent colour (temperature, Today card)
    - **System stats** — system-monitor font + accent (Multi keeps the usual
      green/amber/red usage colours; Theme/Custom override them)
  Change a setting once and both the desktop widget and Quick Settings update
  live, no restart.

## v7.0.0-beta.1-hf99zi — per-widget accent colour (weather + sysmon)
- **Weather** now has its own **Accent color** setting: **Default** (the
  existing blue — look unchanged), **Theme** (auto-syncs to your theme), or
  **Custom** (10 swatches + hex input). It drives the big temperature, the
  hourly rain-% figures, and the highlighted "Today" forecast card.
- **System Monitor's** accent (Multi / Theme / Custom) now also drives the
  **Classic** design's header bar — previously it only affected Pills. The row
  is always visible, not just in Pills mode.
- Defaults keep both widgets looking exactly as before.

## v7.0.0-beta.1-hf99zh — hex colours, Material icons, 0% opacity, per-widget fonts
- **Fix:** the "None (transparent)" background mode landed on the **Weather**
  section last build instead of the System Monitor. Both now have it, and both
  `weatherBgColor` / `sysmonBgColor` honour `none`.
- **Opacity sliders now start at 0%** (were floored at 50%) for the weather and
  sysmon backgrounds — so a widget can be fully background-free.
- **Custom hex colour input** next to the swatches for: weather bg, sysmon bg,
  Pills card colour, and Pills accent colour. Type `#rrggbb` and press Enter
  (invalid input reverts).
- **Icons fixed** — Desktop Widgets rows now use **Google Material Symbols
  Rounded** (ligature names: palette, opacity, link, memory, dashboard…),
  replacing Nerd Font glyphs that rendered as null boxes. `HMRow` gained an
  `iconFont` property, so this is opt-in per row and nothing else changed.
- **Per-widget fonts** — new **Widget Fonts** section: the clock, weather and
  system monitor each choose their own font family (from ZenConstants' font
  list). Applied across all 82 text elements (6 clock / 15 weather / 61 sysmon).

## v7.0.0-beta.1-hf99zg — Pills: themeable colours, transparent bg, Bars removed
- **Bars design removed** (per request) — the dropdown is now **Classic** or
  **Pills**. Anyone already on "bars" is migrated to "pills" on load.
- **Widget background → "None (transparent)"** mode added, so the sysmon
  widget can float on the wallpaper with no panel behind it (the existing
  Default / Theme / Custom + opacity modes are unchanged).
- **Card colour + card opacity** are now settings (10 swatches, light and
  dark). Card **text auto-contrasts**: light card → dark text, dark card →
  light text, and below ~35% opacity the text falls back to the widget text
  colour, so "SYSTEM MONITOR", the CPU/GPU chips and every stat stay readable
  whatever you pick.
- **Accent colours** are now a setting too: **Multi** (per-metric, default),
  **Theme** (auto-sync), or **Custom** (one colour for all). Header bar,
  icon badges, numbers, bars and sparklines all follow it.

## v7.0.0-beta.1-hf99zf — System Monitor: "Pills" design (Pixel capsule cards)
- New **Pills (Pixel)** option in the System Monitor Design dropdown — five
  tall **capsule cards** (CPU · GPU · RAM · VRAM · NETWORK), each with a
  circular coloured icon badge, the label, a big number with a superscript %,
  a divider, two stat columns, then a **sparkline** (CPU/GPU/NET) or a
  **progress bar** (RAM/VRAM), and a coloured footer ("23% Usage" /
  "Network Traffic"). Header shows the title + CPU/GPU name chips.
- **New data:** `SystemMonitorService.cpuMhz` (avg from /proc/cpuinfo) and
  `gpuMhz` (amdgpu `pp_dpm_sclk`, best-effort) power the "Clock Speed" stats;
  they show "—" when unavailable. NETWORK card shows ↑/↓ with a traffic
  sparkline.
- Classic and Bars are untouched — this is a third option (wala tayong
  babawasan).

## v7.0.0-beta.1-hf99ze — System Monitor: "Bars" design + picker
- New **Design** dropdown for the System Monitor (Settings → Desktop Widgets):
  **Classic** (the existing tabs + sparkline graphs) or **Bars** — a modern,
  **slanted** bars-with-numbers layout (CPU / GPU / RAM / VRAM), each a
  sheared/parallelogram bar with a big italic % and a temp/GB readout.
- The slant is a real transform (Matrix4x4 shear) on the bar track + fill;
  the fill animates. Classic is untouched (default).

## v7.0.0-beta.1-hf99zd — weather: hourly forecast + click-to-expand (Pixel-ish)
- **WeatherService** now also fetches **hourly** data from open-meteo
  (`hourly=temperature_2m,precipitation_probability,weather_code`) and exposes
  the next ~12 hours as `hourly` [{ hour, temp, precip, icon, emoji }].
- **Weather widget** is now a rounder **squircle** and **taps to expand**:
  collapsed shows just the current conditions (compact blob); expanded reveals
  a horizontal **Hourly forecast** strip (temp · icon · precip% · hour, like
  the Pixel widget) plus the **7-day** row. Tap again to collapse.
- (Live API couldn't be tested from the build sandbox — open-meteo isn't in
  its allow-list — but the hourly schema matches the existing daily parse.)

## v7.0.0-beta.1-hf99zc — scale: link toggle drives which set is active
- Reworked the **Link all widgets** toggle: **ON** = the single global scale
  drives every widget and the per-widget sliders are **disabled/greyed**;
  **OFF** = the three per-widget sliders are active and the **global** slider
  is disabled/greyed. So exactly one control set is live at a time (default:
  linked). Effective scale = linked ? global : (per-widget × monitor).

## v7.0.0-beta.1-hf99zb — per-clock style (incl. analog per clock)
- Each clock now has its own **Style** picker (Settings → Desktop Widgets →
  per clock): Inherit (follow the global Clock Design), Outline, Solid, Raised,
  Mono, Stacked, or **Analog**. "Inherit" keeps the old behaviour.
- Answers "pano kapag analog na": in **independent mode**, any single clock
  can be its own analog face (primary large, secondaries a smaller face with
  the timezone/name as the label) while others stay digital. In grouped mode
  the primary follows its own style too; the small timezone row stays digital.
- Stored as `style` on each clock; both serializers preserve it.

## v7.0.0-beta.1-hf99za — per-widget scale: link toggle
- Added a **Link all widgets** toggle to the Per-Widget Scale section. When
  on, the three sliders (clock / weather / system monitor) move together —
  one scale for all; when off, each is independent. Persisted (carried by both
  serializers so a widget drag doesn't drop it).

## v7.0.0-beta.1-hf99z — per-widget scale
- New **Per-Widget Scale** section (Settings → Desktop Widgets) with a slider
  for the **Clock**, **Weather**, and **System Monitor** each. This multiplies
  on top of the global widget scale, so you can make one widget bigger/smaller
  without touching the others (each renders at global × its own multiplier).
- Crisp: the multiplier feeds the font/size math (not a blurry transform).
- Persisted per widget in widgets-state.json; Reset returns a widget to 1.0×.

## v7.0.0-beta.1-hf99y — independent draggable clocks
- New **Independent clocks** toggle (Settings → Desktop Widgets → Clock
  Design). When on, **every clock becomes its own draggable widget** with its
  own position instead of one stacked group — drag the primary and each
  timezone anywhere on the desktop independently.
- Per-clock position is stored in the clock object (`posX`/`posY`) and
  persisted in widgets-state.json; both serializers preserve it, so it
  survives config changes and restarts. First time, clocks appear staggered
  so they don't overlap.
- Each independent clock keeps its style (Outline/Solid/Raised/Mono/Stacked,
  and Analog for the primary) + custom names.
- Toggle off → back to the grouped, aligned layout.

## v7.0.0-beta.1-hf99x — fix: sub-clocks not right-aligning on the right edge
- When the widget sat on the right of the screen, the numbers + date
  right-aligned but the timezone grid stayed left. Cause: the grid used
  conditional anchors (`anchors.right` toggled with `undefined`), which didn't
  re-apply reliably. Switched to an explicit `x` per alignment (left → 0,
  centre → centred, right → flush right), so the sub-clocks now line up with
  the big clock's right edge too.

## v7.0.0-beta.1-hf99w — sub-clocks: smaller + properly centered
- **Smaller timezone clocks** — time 36→26px, name 14→11px, so the row of
  sub-clocks is lighter and no longer the widest element.
- Because they're narrower now, the timezone grid actually **centres** under
  the big clock when the widget sits in the middle (before, being the widest
  element, it had no room to move and looked stuck left). Each cell's time +
  name also align per the widget's position (left / centre / right).

## v7.0.0-beta.1-hf99v — clock: position-aware dynamic alignment
- The clock content now **auto-aligns based on where the widget sits on
  screen**: drag it to the **left** third → everything left-aligns (numbers,
  date, timezone grid share the same left edge); **centre** third → centre;
  **right** third → right-aligns. Updates live as you drag.
- This also fixes the "Wednesday" + timezone rows drifting right of the big
  numbers — they now share one alignment edge instead of relying on glyph
  metrics. Implemented with an explicit content width (no binding loop).

## v7.0.0-beta.1-hf99u — clock layout: left-aligned date, 2-col timezones, custom names
- **Date left-aligned** with the big stacked numbers (was drifting right).
- **Secondary timezone clocks now flow in a 2-column grid** instead of one
  tall column — more compact, nicer with several zones.
- **Per-clock custom name** — each secondary clock gets a "Custom name" field
  in Settings → Desktop Widgets; blank falls back to the timezone name.
- Primary clock split out from the secondary Repeater for a clean layout.
- (Next: per-clock style + independent draggable clocks — #W1/#W3.)

## v7.0.0-beta.1-hf99t — timezone clocks: use OS zoneinfo (Intl doesn't work here)
- **Root cause found:** `Intl.DateTimeFormat` with a `timeZone` isn't supported
  by the Quickshell JS engine — it silently returned local time, so **every
  clock showed the same (local) time** regardless of zone.
- Fixed by asking the OS zoneinfo directly: a `Process` runs
  `TZ=<zone> date +%H:%M` for each configured zone and caches the result,
  refreshed every 20s. Verified correct + DST-aware (e.g. LA = PDT −7, not
  PST −8; Winnipeg CDT −5; Sydney +10). Every clock now shows its real time.

## v7.0.0-beta.1-hf99s — Stacked (03/28) clock design
- New **Stacked** option in Clock Design — the primary clock renders the hour
  over the minutes as two big bold outlined numbers (03 above 28), tightened
  line height, like your sample. Digital timezone clocks stay inline.

## v7.0.0-beta.1-hf99r — Google-Pixel wavy analog clock design
- New **Analog (Pixel)** option in Settings → Desktop Widgets → **Clock
  Design** — a Material-You style **scalloped/cog-edged round face** (Canvas)
  with chunky rounded hour + minute hands (smoothly animated) and a day label,
  like the Google Pixel clock (your Image 3). New `WavyAnalogClock.qml`.
- In Analog mode the primary (local) time shows as the analog face; the
  digital multi-clock list hides. Switch back to any digital style for the
  timezone list.

## v7.0.0-beta.1-hf99q — fix: wrong timezone clock times (DST + primary-relative)
- Selecting e.g. **Los Angeles** showed the wrong time. Two bugs:
  1. `convertTime` used a **hardcoded offset table relative to Manila**,
     frozen to one DST season — so it broke for a non-Manila primary and for
     PST↔PDT (LA in July is PDT, not PST). Replaced with proper **Intl /
     IANA** conversion (`Intl.DateTimeFormat` with `timeZone`) — DST-aware,
     correct for every zone, independent of the primary clock. Falls back to
     local time if a zone id isn't recognised.
  2. The timezone dropdown read `currentIndex` (which raced its binding and
     sometimes left the clock on its old zone). Now uses the emitted index.
- Timezone labels made DST-neutral (Los Angeles **(PT)**, New York **(ET)**,
  Chicago **(CT)**, Paris (CET/CEST), Sydney/Auckland, …) instead of a single
  season's abbreviation.

## v7.0.0-beta.1-hf99p — up to 10 desktop clocks + hf99o load-crash fix
- **FIX (important):** hf99o failed to load the shell — the clockStyle load
  edit accidentally split an `if (…clocks…) { } else { … }` so an `else`
  dangled ("Expected token ,"). Repaired. **Every edited QML now passes
  qmllint** (22 files checked), so the shell parses clean again.
- **Up to 10 desktop clocks.** The clock list already rendered from an array;
  added **+ Add** (caps at 10) and per-clock **Remove** (the Primary clock is
  permanent). Each new clock defaults to UTC — set its timezone + 12/24h.
- Persisted in widgets-state.json like the existing clocks.

## v7.0.0-beta.1-hf99o — Desktop clock design variants
- The desktop time widget now has a **Style** picker (Settings → Desktop
  Widgets → Clock Design):
    - **Outline** — bold Adwaita Black with a dark outline (the original)
    - **Solid** — clean solid-colour bold, no outline (the "Bolder" look)
    - **Raised** — solid bold with a soft drop shadow (chunky/embossed)
    - **Mono** — tabular JetBrainsMono, lighter weight, understated
- Persisted in `widgets-state.json` (WidgetsPage writes it, DesktopWidgets
  renders it) — same path as the other clock config.
- Still a design idea: a **wavy/scalloped analog clock** (your Image 3) — that
  one's a different widget shape (Canvas + hands), so it's a separate build.

## v7.0.0-beta.1-hf99n — Glass frost (Hyprland blur) + Start Menu / Notifications
- **Start Menu and Notifications** now follow the active look (corner radius +
  opacity), so every major surface reacts to Shell Look.
- **Glass frost is real now** — `LookService` applies a Hyprland
  `layerrule = blur, zen-shell-` (+ `ignorealpha`) to all zen-shell layer
  surfaces on start, so Glass reads as *frosted* glass, not just transparent.
  Pop-ups (Control Panel / Notifications / Start Menu) frost immediately (they
  remap on open); the persistent **Bar / Dock** stay frosted via the shipped
  `hypr-config/zen-shell-look.conf`, which the installer sources into
  hyprland.conf (idempotent). Blur stays on for every look — opacity decides
  whether it shows, so there's no fragile runtime toggling.
- Existing installs (no reinstall): add `source = ~/.config/hypr/zen-shell-look.conf`
  to hyprland.conf + `hyprctl reload` to frost the Bar/Dock too.

## v7.0.0-beta.1-hf99m — Shell Look now applies to Bar + Dock (more "ramdam")
- The look was only visible on the Control Panel, so switching felt subtle.
  Now the **Bar** (horizontal + vertical) and the **Dock** also follow the
  active look — their corner radius and background opacity track
  `LookService` (gated by the per-surface Apply-To toggles). Switching Classic
  ⇄ Glass now visibly reshapes the whole shell: square+opaque vs round+glassy.
- Look opacity also applies over a custom background colour (your hue stays;
  the look controls the transparency), so Glass reads even with Custom BG on.
- Tokens tuned more dramatic (Classic radius ×0.18 / opaque; Glass radius
  ×1.35 / 0.58 opacity + glow).
- Still to do (#4c): inject Hyprland layer blur so Glass is truly *frosted*
  (right now it's transparent, not blurred), + Start Menu / Notifications.

## v7.0.0-beta.1-hf99l — Shell Look selector (foundation)
- New **`LookService`** singleton — a shell "look" is a token set
  (`radiusScale`, `panelOpacity`, `borderAlpha`, `blur`, `glow`, `animated`).
  Ships **Classic / Zen / Glass / Minimal / Custom**. Additive: Zen is the
  current default, untouched — switching just re-reads tokens. Active look +
  per-surface apply flags persist via PanelState (no new state layer).
- New **Settings → Shell Look** page: look picker (name + blurb + live swatch)
  and **Apply To** toggles (Bar / Control Panel / Start Menu / Dock /
  Notifications / OSD).
- **Control Panel wired** as the first surface — its corner radius, panel
  opacity and border follow the active look (when "Control Panel" apply is on),
  so the switch is visible immediately.
- Next: extend to Bar/Dock/Start Menu/Notifications + inject Glass's Hyprland
  layer blur via look_and_feel.conf.

## v7.0.0-beta.1-hf99k — Classic Dots workspace style
- New **Classic Dots** option in Settings → Bar Modules → Number format.
  Glyph-free indicator: the **active** workspace is an elongated **pill**,
  inactive ones are small **circles** (occupied = brighter, empty = faint) —
  the classic Waybar/macOS-style dot row.
- Wired in `ZenConstants.workspaceFormats` + the Bar Modules dropdown, and
  rendered in **both** `Workspaces.qml` (what the bar runs) and
  `ZenWorkspaces.qml` (the template it's copied from) so it survives the
  auto-apply copy. Non-dots formats unchanged.

## v7.0.0-beta.1-hf99j — Attached mode (Caelestia-style)
- New **Attach to bar** toggle (Settings → Panel, and persisted in
  `PanelState.controlPanelAttached`). When on, the Quick Settings panel
  **hugs the bar edge** instead of floating: it follows the bar (top/bottom),
  sits flush against it (margin = bar height), and the two corners touching
  the bar are **squared** so it reads as connected — Caelestia-style.
- Dragging the panel still breaks the attachment (free-float), same as before.
- Additive — floating behaviour unchanged when the toggle is off.

## v7.0.0-beta.1-hf99i — Notifications tab in Quick Settings
- Added a **Notifs** tab to the Quick Settings expand area (next to Wi-Fi /
  Bluetooth / Audio / Input). Click Expand → Notifs to see recent
  notifications: app name, summary, body; ✕ dismisses one, "Clear all"
  wipes the list; empty-state when caught up.
- **No dup** — reuses the existing `NotificationService` (`notifications`,
  `dismiss`, `clearAll`); no new daemon/state/list.

## v7.0.0-beta.1-hf99h — responsive Quick Settings + calendar + big time/date
- **Responsive width:** the panel now sizes to the screen (~half, clamped
  440–700px) instead of a fixed 700, so it shrinks on smaller resolutions and
  never overflows.
- **Responsive layout:** the paired rows (weather ‖ system, and the new
  time ‖ calendar) use a `GridLayout` that drops from 2 columns to 1
  (auto-stacked) when the panel is narrow — cards stay readable on small
  screens.
- **Calendar grid card** — month grid with weekday headers + today
  highlighted, in the Quick Settings. Light: date parts are split into int
  properties so the grid only recomputes when the day changes, not every
  second (reuses the existing 1s clock — no new timer).
- **Big time/date card** — large HH:mm + weekday + full date, paired next to
  the calendar.
- Additive/structural only. Wala tayong babawasan.

## v7.0.0-beta.1-hf99g — Quick Settings goes horizontal (Caelestia-style), 1/n
- The panel was one tall single column; adding the weather card made the
  scroll even longer. First horizontal step: **widen the panel** (columnWidth
  460 → 700) and put the **weather card and system-stats card side by side**
  in a RowLayout (dropped the divider between them). That's the two tallest
  medium cards paired, so the panel is noticeably shorter and more horizontal.
- Each card gets `Layout.preferredWidth: 1` so the split is an even 50/50.
- Next passes can pair more rows the same way (audio ‖ connectivity, etc.).
- Additive/structural only — no widget logic changed. Wala tayong babawasan.

## v7.0.0-beta.1-hf99f — fix: display won't wake after lock/idle (audio still plays)
- Symptom: after hyprlock / idle the screen goes black and never comes back,
  but audio keeps playing.
- Two causes, both fixed in a shipped `hypr-config/hypridle.conf`:
  1. The screen-off (dpms) listener had no `on-resume = hyprctl dispatch
     dpms on`, so any wake left the monitor in DPMS-off.
  2. No `after_sleep_cmd = hyprctl dispatch dpms on`, so the panel stayed
     dark after a real suspend/resume.
- Also fixes a tarball gap: the installer's Phase B provisions
  `hypr-config/hypridle.conf` (and `hyprlock.conf`), but that folder was
  missing from the package, so the config was silently skipped on every
  install — which is why a reinstall couldn't repair it and why Phase F's
  hypridle restart re-armed a bad config ("dati ok, ngayon hindi"). The
  folder now ships with a correct `hypridle.conf`; `hyprlock.conf` is left
  to the user (visual config, untouched).

## v7.0.0-beta.1-hf99e — installer no longer blocks on slow AUR font builds
- The optional-packages step ran `paru -S` in the foreground, so a slow or
  stuck AUR build (e.g. `ttf-material-symbols-variable-git`, the Material
  Symbols variable font) would stall the whole installer *before* the shell
  ever installed.
- Now that step is **interruptible + non-fatal**: it prints a heads-up that
  AUR fonts can take a few minutes, and **Ctrl+C skips only the fonts** and
  drops through to the shell install instead of aborting everything. Build
  failures are tolerated too, with a "install later" hint.
- Fonts are cosmetic — the shell runs fine without them.

## v7.0.0-beta.1-hf99d — Quick Settings widget set (1/n): big weather + forecast
- **New big weather widget in Quick Settings** (ControlPanel), placed right
  under the user/info card: large emoji icon + temperature, condition,
  location, and **labeled** stats (Feels / Humidity / Wind — no guessing
  which number is which), plus a **7-day forecast row** (day · emoji ·
  hi/lo) with evenly-sized cells (`Layout.preferredWidth: 1`).
- Binds to the existing `WeatherService` (current + `forecast[]`); no new
  service or fetch logic. Hidden until the first fetch lands (no empty flash).
- Themed with `ThemeService` colours to match the panel (not the desktop
  widget's hardcoded white).
- First of the Quick Settings widget set; time/date + calendar grid next.
- Additive only. Wala tayong babawasan.

## v7.0.0-beta.1-hf99c — Quick Settings system stats: alignment + dividers + labeled temp
- **GPU / VRAM now align with CPU / RAM.** The detail-view 2×2 grid used
  `Layout.fillWidth` with no preferred width, so columns split by content
  width — the long CPU name ("Ryzen 9 5950X") made the CPU cell wider than
  RAM, pushing the GPU column to a different x than VRAM. Each of the four
  cells now gets `Layout.preferredWidth: 1`, forcing an exact 50/50 split so
  the right column lines up top-to-bottom.
- **Vertical `ZenDivider` between the columns** (CPU|GPU and RAM|VRAM),
  matching the existing horizontal divider between the rows — clean grid look.
- **Top temp readout is now labeled:** `43° / 50°` → `CPU 43° · GPU 50°`,
  so it's obvious which number is which.
- Additive only. Wala tayong babawasan.

## v7.0.0-beta.1-hf99b — slider height regression fix (drag + visibility)
- **Fixes the hf99 ZenSlider regression:** sliders collapsed to ~0 height
  inside plain `Row`s, so the L (lightness) slider in the color picker was
  stuck / un-draggable and the Background-opacity slider disappeared.
- Cause: a QQC2 `Slider` derives its `implicitHeight` from the handle +
  background *implicit* sizes. ZenSlider's custom handle/background set
  `width`/`height` but not `implicitWidth`/`implicitHeight`, so
  `availableHeight` went to ~0 — no track, no hit-area.
- Fix: ZenSlider now sets `implicitHeight` (+ `topPadding`/`bottomPadding`)
  and gives its handle/background real implicit sizes. All 37 sliders
  render and drag again.
- While double-checking every slider: the ConnectivityPage audio + mic
  sliders got the same implicit-size hardening, and the **mic slider's
  missing `onMoved` was wired up** (dragging it now actually sets mic
  volume — it previously did nothing).
- Color-picker L slider switched to `onMoved` (the proven audio-slider
  pattern) for rock-solid dragging.
- Additive only. Wala tayong babawasan.

## v7.0.0-beta.1-hf99 — circle sliders + smart installer + bootstrap + color picker
- **New `ZenSlider.qml`** — one reusable circle-handle slider (the audio-
  slider look, baked once). Track 4px, accent fill, 14px handle
  (`radius = width/2`, `antialiasing: true`). Consumers set `accent:` to
  recolor (e.g. purple for mic). Falls back to literal colors if
  `ThemeService` isn't resolved yet (same defensive pattern as ZenDivider).
- **All 37 bare `Slider {}`** across 11 control-panel pages
  (Appearance, Panel, Hyprbars, Themes, Input, Widgets, Gaming, Battery,
  Plugins, ColorPicker, AppFloatRuleEdit) now use `ZenSlider` — square
  default handles are gone.
- **Antialiasing fix applied to the remaining hand-rolled knobs** too:
  ConnectivityPage audio + mic handles and the SysRow speaker/mic knobs
  now set `antialiasing: true`. (ControlPanel knobs already had it.)
  This is the real root cause from the note below — a `radius = w/2`
  circle still renders blocky without AA.
- **Installer merged to the smart build** (`--bootstrap` / auto-detect /
  version pin / self-heal / atomic QML copy). Ships with a **layout-compat
  shim** so the legacy body (`zen-shell-v5/`, `scripts/`, `themes-builtin/`)
  resolves against the v8 tarball layout (`zen-shell/`, `zen-shell/scripts/`,
  `themes/builtin/`) via self-cleaning symlinks — the destructive stale-prune
  can no longer wipe the shell on a name mismatch.
- **`bootstrap.sh` now bundled** in the tarball so `--bootstrap` / auto
  bootstrap has something to run.
- **Color picker — drag + accuracy fixed** (ColorPickerOverlay, the quick-
  settings picker, and the ThemesPage inline picker):
    - Dragging the selector on the saturation/hue plane now works, not just
      single-click. Cause: an unqualified `pressed` inside a `function(){}`
      `onPositionChanged` handler didn't resolve to the MouseArea, so move
      events were dropped. Now references the MouseArea by id + sets
      `preventStealing` so no ancestor Flickable can hijack the gesture.
    - The plane is now painted at the CURRENT lightness (was pinned to 0.5)
      using exact per-saturation HSL stops (was a single linear-RGB
      gradient). The color under the cursor is exactly what Apply emits.
      Repaints live as the L slider moves.
- Additive only — no page logic, no bindings, no features removed.
  Wala tayong babawasan.

## Fixed — volume slider handles render as smooth circles
- Root cause: the knobs WERE circular in code (`radius = width/2`), but Qt
  `Rectangle`s don't antialias rounded corners by default, so at 16 px the
  "circle" rendered blocky/square. All slider knobs now set
  **`antialiasing: true`** and are 18 px (`radius: 9`) — smooth circles across
  every volume/sensitivity slider in the Control Panel.
- **IMPORTANT:** if it still looks square after installing, it's a stale
  compiled-QML cache. Do the nuclear clear (below) before judging.

## Already fixed in this build
- Installer preserves your `*.json` settings/profile on reinstall.
- Decoration shadow color swatch shows the correct color (CSS #RRGGBBAA).
- Themes: DarkMatter + Caelestia. System monitoring deduped/centered with your
  StatChip icons + divider + bars/detail toggle. Wider Control Panel;
  system/user info card; glass-synced background; ethernet icon fixed;
  brightness OSD suppressed on desktop.

## Next — widget set (incremental + tested)
Notification tab (existing, no dup); big weather widget (icon + forecast); big
time/date widget; calendar grid; vertical-bar option; drag-to-reorder.
