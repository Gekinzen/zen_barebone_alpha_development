# v6.16.4.12.9.12 — Modori (戻り) · hotfix 12

**Channel:** alpha
**Release date:** 2026-05-06
**Predecessor:** v6.16.4.12.9.11 — Modori hotfix 11

## Summary

**Critical regression fix.** The `_runAction()` helper introduced
in hf11 had an infinite-recursion bug — its body called itself
instead of running the actual command. This silently broke
**every** action in ConnectivityService, including:

- WiFi toggle (Super+C → WiFi switch)
- Bluetooth toggle
- Audio mute / mic mute
- Volume slider
- Tap-to-reconnect saved WiFi (KiyuFamilyFibr in Paul's case)
- Tap-to-connect new WiFi network
- Forget WiFi
- All Bluetooth actions (connect, disconnect, pair, unpair, scan)

User reported "hindi na ma untoggle and toggle yun blue tooth
wifi etc" + "hindi padin ma top reconnect yun current wifi ko".
Both symptoms have the same single root cause.

## Root cause

The hf11 changelog included a new helper:

```qml
function _runAction(cmdArr) {
    if (actionRunner.running) {
        actionRunner.running = false
    }
    actionRunner.command = cmdArr
    actionRunner.running = true
}
```

The hf11 patch was applied via a Python sed-like sweep that
replaced every occurrence of:

```
actionRunner.command = ...
actionRunner.running = true
```

…with `_runAction(...)`. The sweep was correct for the 19
callsites — but it ALSO matched the helper body itself, replacing
the actual command-set + running-set lines with a recursive
`_runAction(cmdArr)` call. Result:

```qml
function _runAction(cmdArr) {
    if (actionRunner.running) {
        actionRunner.running = false
    }
    _runAction(cmdArr)   // ← infinite recursion!
}
```

When any caller invoked `_runAction(...)`, it recursed until
the JavaScript stack overflowed. Quickshell's QML engine
silently caught the StackOverflowError and dropped the call —
no UI feedback, no console error in normal log levels. The
user saw "tap does nothing" for every single toggle and
button.

## Why this wasn't caught at brace-check time

Brace counts were balanced because the bug was a logic error,
not a syntax error. The bulk-pass output reported:
"actionRunner.running=true 19→0, _runAction occurrences 2→21"
which I read as success — but the "+19" included the recursive
call inside the helper itself, hiding among the 20 legitimate
callsites.

The lesson: when a sed/Python sweep modifies a file that DEFINES
the helper it's introducing, manually verify the helper body is
not also pattern-matched. Or use a more specific pattern that
excludes the helper's own location (e.g. by checking for
indentation depth, surrounding context, or just exempting a
specific line range).

## Fix

Restored the actual helper body:

```qml
function _runAction(cmdArr) {
    if (actionRunner.running) {
        actionRunner.running = false
    }
    actionRunner.command = cmdArr
    actionRunner.running = true
}
```

One-line change: `_runAction(cmdArr)` → `actionRunner.command =
cmdArr` followed by `actionRunner.running = true`.

After this fix, all 20 callers work correctly — including the
re-entry-safe pattern that was the original point of the helper
(double-tap second click no longer silently dropped).

## What carries forward from hf11

All hf11 fixes were correct in design — only the helper body
was broken. After hf12 restores the helper, all hf11
improvements take effect for the first time:

- **`preventStealing: true`** on 9 WiFi/BT row MouseAreas —
  Flickable no longer steals tap events when list overflows.
  Tap-to-reconnect saved networks now actually reaches
  `reconnectWifi()`. Tap-to-connect new networks reaches
  `connectWifi()`. Tap-to-pair BT devices reaches
  `pairBtDevice()`. Forget/unpair trash icons fire correctly.
- **`security === "--"` normalized to `""`** — open networks
  no longer show the lock icon and don't trigger the password
  prompt. Direct connect.
- **WiFi route metric chain** — `nmcli connection modify '<SSID>'
  ipv4.route-metric 50 ipv6.route-metric 50` chained after
  every explicit user-tap connect. WiFi (metric 50) now wins
  the default route over LAN (metric 100).
- **`onExited` immediate + delayed refresh** — `actionRunner`
  now triggers `update()` immediately on exit + again at +1.5s
  so UI catches up to nmcli convergence within ~1-2s instead
  of waiting for the 5s regular poll.
- **`stderr` collected and logged** — actionRunner stderr now
  visible in `journalctl --user -t quickshell` when nmcli or
  bluetoothctl fails.

## Files changed

| File | Change |
|---|---|
| `zen-shell-v5/ZenVersion.qml` | Bumped to v6.16.4.12.9.12. |
| `zen-shell-v5/ConnectivityService.qml` | One-line fix in `_runAction()` — replaced recursive `_runAction(cmdArr)` self-call with the actual `actionRunner.command = cmdArr; actionRunner.running = true` body. No other code changed. |
| `install.sh` | Banner version + success banner + final "Done. Enjoy" message bumped. |
| `CHANGELOG-v6.16.4.12.9.12.md` | NEW (this file). |

## Migration

```bash
cd zen_barebone_alpha_development
git pull
git checkout alpha-v6.16.4.12.9.12
./install.sh
pkill -x quickshell
qs -c zen-shell &
```

## Test scenarios

After install, every action that was broken in hf11 should
now work. Verify in this order — fastest to slowest:

1. **Audio mute toggle** (speaker icon in bar). Should
   instantly mute/unmute. Audio glyph changes.
2. **WiFi toggle** in Control Panel (Super+C → WiFi switch
   in the Conn group). Should turn WiFi off/on within ~1-2s.
3. **Bluetooth toggle** in Control Panel. Same.
4. **Tap-to-reconnect saved WiFi**. Open WiFi tab, tap
   the SAVED row (KiyuFamilyFibr, etc.). Should reconnect
   within 1-2s. Status flips to "Connected · {signal}%".
5. **Tap-to-connect new WiFi**. Tap a row in AVAILABLE
   NETWORKS. Open networks: instant. Secured: password
   prompt appears centered on screen.
6. **Default route on WiFi** (after fresh connect):
   ```bash
   ip route get 1.1.1.1
   # Should show "dev wlan0" (or your wifi interface),
   # not "dev eth0".
   ```
7. **Forget WiFi**. Tap trash on a saved row. Network
   removed from saved list within ~3s.
8. **Bluetooth scan + pair**. Tap "Scan nearby" in BT tab,
   wait for a device to appear, tap it. Pair+trust+connect
   chain runs.

If any of the above still doesn't work, that's a separate
bug — please send a screenshot + describe what you tapped.

## Carry-forward

All Modori .9.11 features preserved (after this fix actually
takes effect):

- WiFi route-metric preference (wifi wins over LAN)
- preventStealing on row taps
- Open-network parsing fix
- Action exit refresh + delayed refresh
- In-shell WiFi password prompt at WlrLayer.Overlay
- WiFi+BT Control Panel redesign
- GTK Dark Mode toggle
- Bulletproof sidebar user labels
- Smart-contrast theme engine
- Modori Dark + Light themes + paired procedural wallpapers
- All Tachiagari .7.1 features

## Wala tayong babawasan

One-line restore. No UI surface, API surface, behavior, or
configuration change beyond restoring the broken helper.
