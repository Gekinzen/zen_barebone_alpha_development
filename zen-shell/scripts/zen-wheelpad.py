#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
zen-wheelpad — circular ("wheel pad") scrolling for Panasonic Let's Note
                touchpads under Wayland / Hyprland.

  Zen Shell v8.0.0-alpha-hf179 · Karui (軽い)

WHY THIS EXISTS
───────────────
Panasonic Let's Note laptops (CF-SV9, CF-SV1, CF-SZ5/6, CF-LX, CF-NX, CF-RZ,
CF-QV, CF-FV, CF-SR ...) ship a small ROUND touchpad. The Windows driver lets
you scroll by drawing circles around its outer ring — the "wheel pad". On a
12.1" machine with a pad that small, that ring is not a gimmick; two-finger
scrolling on it is genuinely awkward.

libinput implements exactly three scroll methods: two-finger, edge, and
on-button. Circular is not among them and upstream has said circular pads are
not a thing they target. The old Xorg xf86-input-synaptics driver had
`CircularScrolling`, which is why the ArchWiki pages for CF-SV9 and CF-SV1
both tell you circular scroll works under Xorg and NOT under Wayland.

Hyprland is Wayland-only. So there is no configuration that turns this on —
it has to be synthesised. That is this daemon.

HOW IT WORKS
────────────
1. Find the touchpad's evdev node.
2. EVIOCGRAB it, so the compositor stops seeing the physical device.
3. Re-publish it as a uinput clone with identical capabilities. libinput binds
   to the clone and every normal behaviour — pointer accel, tap-to-click,
   two-finger scroll, gestures — keeps working exactly as before, because as
   far as the stack is concerned nothing changed.
4. Watch the finger. When a single finger enters the outer ring and starts
   travelling tangentially, ENGAGE: tell the clone the finger lifted, stop
   forwarding motion, and start converting angular travel into wheel events on
   a second virtual device.
5. On finger-up, disengage and go back to plain forwarding.

The clone is what makes this safe. A daemon that merely watched the touchpad
could emit scroll but could not stop the pointer moving at the same time, so
circling would scroll AND drag the cursor across the screen. Grab-and-republish
is the only arrangement that can suppress the motion it replaces.

If this daemon dies, crashes, or is killed, the kernel drops the grab
automatically and the physical touchpad returns to the compositor. Worst case
you lose circular scroll, never the pointer.

REQUIREMENTS
────────────
  python-evdev          (Arch: python-evdev)
  read access to /dev/input/event*   (group `input`)
  write access to /dev/uinput        (udev rule ships with Zen Shell)

Wala tayong babawasan — nothing in the shell depends on this. It is opt-in,
it is a separate process, and with it stopped the machine behaves precisely as
it did before it was installed.
"""

import math
import os
import sys
import time
import json
import argparse
import signal

VERSION = "v8.0.0-alpha-hf179"

# ═══════════════════════════════════════════════════════════════════════════
# GEOMETRY / STATE ENGINE
#
# Deliberately free of evdev imports so it can be unit-tested on any machine,
# including the one this was written on, which has no touchpad. Everything
# that decides *what should happen* lives here; the evdev half below only
# feeds it coordinates and acts on what it returns.
# ═══════════════════════════════════════════════════════════════════════════


class WheelPadEngine:
    """
    Converts a stream of absolute finger positions into scroll clicks.

    Coordinates are normalised to 0..1 on both axes by the caller, so the
    engine never needs to know the device's ABS ranges — and a pad that is
    not perfectly square still yields a circular ring, because we normalise
    per-axis before measuring the radius.
    """

    # Returned by feed() so the caller knows what to do with the event.
    FORWARD = "forward"      # pass the finger through untouched
    ENGAGE = "engage"        # first swallowed event — lift the virtual finger
    SCROLL = "scroll"        # swallowed; emit the clicks in .pending_clicks
    SWALLOW = "swallow"      # swallowed; nothing to emit this frame

    def __init__(self,
                 ring_inner=0.62,
                 degrees_per_click=18.0,
                 engage_degrees=12.0,
                 natural=False,
                 horizontal=False,
                 max_jump_degrees=90.0):
        # Fraction of the radius at which the ring starts. 0.62 keeps the
        # middle ~62% of the pad as a normal pointing surface, which is about
        # where the printed ring sits on an SV9.
        self.ring_inner = ring_inner
        # Angular travel per wheel click. 18° = 20 clicks per full circle.
        self.degrees_per_click = degrees_per_click
        # How far you must travel round the ring before we take over. This is
        # what stops a tap near the edge, or a straight flick that clips the
        # corner, from being read as a scroll.
        self.engage_degrees = engage_degrees
        self.natural = natural
        self.horizontal = horizontal
        # A jump larger than this between samples is not a finger, it is a
        # second finger being picked up as the first, or a re-seat after a
        # dropped frame. Discard rather than emit a wild scroll burst.
        self.max_jump_degrees = max_jump_degrees

        self.reset()

    def reset(self):
        """Finger lifted, or engine re-armed. Forget everything."""
        self._touching = False
        self._engaged = False
        self._armed = False
        self._last_angle = None
        self._accum_travel = 0.0     # signed, drives clicks
        self._arm_travel = 0.0       # unsigned, drives engagement
        self.pending_clicks = 0

    # ── queries, for the daemon's logging and the settings UI ──
    @property
    def engaged(self):
        return self._engaged

    def radius(self, x, y):
        """Distance from pad centre, 0 at the middle, 1.0 at the edge."""
        dx = (x - 0.5) * 2.0
        dy = (y - 0.5) * 2.0
        return math.sqrt(dx * dx + dy * dy)

    def angle(self, x, y):
        """Degrees, 0 at 3 o'clock, increasing clockwise on screen."""
        dx = (x - 0.5)
        dy = (y - 0.5)
        return math.degrees(math.atan2(dy, dx))

    @staticmethod
    def _delta(prev, cur):
        """Shortest signed angular distance, wrap-safe across ±180°."""
        d = cur - prev
        while d > 180.0:
            d -= 360.0
        while d < -180.0:
            d += 360.0
        return d

    def finger_up(self):
        was = self._engaged
        self.reset()
        return was

    def feed(self, x, y, fingers=1):
        """
        Feed one normalised sample. Returns one of the class constants.
        `pending_clicks` carries the signed click count for SCROLL.
        """
        self.pending_clicks = 0

        # More than one finger is libinput's business — two-finger scroll,
        # pinch, three-finger swipe all still belong to the compositor.
        if fingers != 1:
            if self._engaged:
                self.reset()
            self._touching = False
            return self.FORWARD

        r = self.radius(x, y)
        a = self.angle(x, y)

        if not self._touching:
            # New contact. Arm only if it LANDED in the ring — starting in the
            # middle and wandering out is pointing, not scrolling.
            self._touching = True
            self._armed = r >= self.ring_inner
            self._last_angle = a
            self._accum_travel = 0.0
            self._arm_travel = 0.0
            return self.FORWARD

        prev = self._last_angle
        self._last_angle = a

        if prev is None:
            return self.FORWARD

        d = self._delta(prev, a)

        # Implausible jump — drop the sample, keep the state.
        if abs(d) > self.max_jump_degrees:
            return self.SWALLOW if self._engaged else self.FORWARD

        if not self._armed:
            return self.FORWARD

        # Leaving the ring inward ends the gesture. Keeps a spiral inward
        # from scrolling forever after the finger has left the edge.
        if r < self.ring_inner * 0.85:
            if self._engaged:
                self.reset()
                self._touching = True
                self._last_angle = a
                return self.FORWARD
            self._armed = False
            return self.FORWARD

        if not self._engaged:
            self._arm_travel += abs(d)
            if self._arm_travel < self.engage_degrees:
                return self.FORWARD
            # Take over. The travel spent arming is not thrown away — it is
            # carried into the click accumulator so the scroll starts from
            # where the finger actually is, not from where it engaged.
            self._engaged = True
            self._accum_travel = d
            return self.ENGAGE

        self._accum_travel += d

        clicks = 0
        while self._accum_travel >= self.degrees_per_click:
            self._accum_travel -= self.degrees_per_click
            clicks += 1
        while self._accum_travel <= -self.degrees_per_click:
            self._accum_travel += self.degrees_per_click
            clicks -= 1

        if clicks == 0:
            return self.SWALLOW

        # Clockwise travel is a positive angle delta on screen coordinates
        # (y grows downward), and clockwise should scroll DOWN — which is a
        # negative REL_WHEEL. Natural scrolling flips it.
        out = -clicks
        if self.natural:
            out = -out

        self.pending_clicks = out
        return self.SCROLL


# ═══════════════════════════════════════════════════════════════════════════
# CONFIG
# ═══════════════════════════════════════════════════════════════════════════

CONFIG_PATH = os.path.expanduser("~/.config/zen-shell/wheelpad.json")

DEFAULTS = {
    "enabled": True,
    "ring_inner": 0.62,
    "degrees_per_click": 18.0,
    "engage_degrees": 12.0,
    "natural": False,
    "horizontal": False,
    "device": "",          # "" = auto-detect
    "require_panasonic": True,
}


def load_config():
    cfg = dict(DEFAULTS)
    try:
        with open(CONFIG_PATH, "r") as fh:
            user = json.load(fh)
        if isinstance(user, dict):
            for k in DEFAULTS:
                if k in user:
                    cfg[k] = user[k]
    except FileNotFoundError:
        pass
    except Exception as exc:
        log("config unreadable, using defaults: %s" % exc)
    return cfg


def log(msg):
    sys.stderr.write("[zen-wheelpad] %s\n" % msg)
    sys.stderr.flush()


# ═══════════════════════════════════════════════════════════════════════════
# HARDWARE DETECTION
# ═══════════════════════════════════════════════════════════════════════════

def read_dmi(name):
    try:
        with open("/sys/class/dmi/id/" + name, "r") as fh:
            return fh.read().strip()
    except Exception:
        return ""


def is_panasonic():
    """
    Let's Note machines report the vendor either as the old Matsushita name or
    as Panasonic, depending on vintage, and the model as CF-xx / FZ-xx.
    """
    vendor = (read_dmi("sys_vendor") + " " + read_dmi("board_vendor")).lower()
    if "panasonic" in vendor or "matsushita" in vendor:
        return True
    product = read_dmi("product_name").upper()
    return product.startswith("CF-") or product.startswith("FZ-")


def panasonic_model():
    p = read_dmi("product_name").strip()
    return p if p else "unknown"


def find_touchpad(evdev, want=""):
    """
    A touchpad is an absolute device that reports a finger tool. Trackpoints
    are relative, touchscreens report BTN_TOUCH without BTN_TOOL_FINGER, and
    tablets carry a pen tool — so this triple is a reliable filter.
    """
    ecodes = evdev.ecodes
    candidates = []
    for path in evdev.list_devices():
        try:
            dev = evdev.InputDevice(path)
        except Exception:
            continue
        caps = dev.capabilities()
        abs_caps = [c for c, _ in caps.get(ecodes.EV_ABS, [])]
        key_caps = caps.get(ecodes.EV_KEY, [])
        has_xy = (ecodes.ABS_X in abs_caps or ecodes.ABS_MT_POSITION_X in abs_caps)
        has_finger = ecodes.BTN_TOOL_FINGER in key_caps
        has_pen = ecodes.BTN_TOOL_PEN in key_caps
        if has_xy and has_finger and not has_pen:
            candidates.append(dev)
        else:
            dev.close()

    if want:
        for dev in candidates:
            if want in dev.path or want.lower() in dev.name.lower():
                for other in candidates:
                    if other is not dev:
                        other.close()
                return dev
        log("requested device %r not found, falling back to auto-detect" % want)

    if not candidates:
        return None
    # Prefer a name that says touchpad; otherwise take the first.
    for dev in candidates:
        if "touchpad" in dev.name.lower() or "trackpad" in dev.name.lower():
            for other in candidates:
                if other is not dev:
                    other.close()
            return dev
    chosen = candidates[0]
    for other in candidates[1:]:
        other.close()
    return chosen


# ═══════════════════════════════════════════════════════════════════════════
# DAEMON
# ═══════════════════════════════════════════════════════════════════════════

def run(cfg, dry_run=False):
    try:
        import evdev
        from evdev import UInput, ecodes, AbsInfo
    except ImportError:
        log("python-evdev is not installed.")
        log("  Arch/CachyOS:  sudo pacman -S python-evdev")
        return 3

    if cfg["require_panasonic"] and not is_panasonic():
        log("not a Panasonic machine (DMI says %r) — refusing to start."
            % read_dmi("sys_vendor"))
        log("override with --any-machine if you know what you are doing.")
        return 4

    dev = find_touchpad(evdev, cfg.get("device", ""))
    if dev is None:
        log("no touchpad found. `sudo libinput list-devices` to check.")
        return 5

    log("%s on %s" % (VERSION, panasonic_model()))
    log("touchpad: %s (%s)" % (dev.name, dev.path))

    # ── Absolute ranges, for normalising to 0..1 ──
    caps = dev.capabilities(absinfo=True)
    abs_info = dict(caps.get(ecodes.EV_ABS, []))

    def axis_range(code_mt, code_st):
        info = abs_info.get(code_mt) or abs_info.get(code_st)
        if info is None:
            return None
        span = info.max - info.min
        return (info.min, span if span else 1)

    rx = axis_range(ecodes.ABS_MT_POSITION_X, ecodes.ABS_X)
    ry = axis_range(ecodes.ABS_MT_POSITION_Y, ecodes.ABS_Y)
    if rx is None or ry is None:
        log("touchpad reports no usable X/Y range — cannot compute a ring.")
        return 6
    log("range: x %d..%d  y %d..%d" % (rx[0], rx[0] + rx[1], ry[0], ry[0] + ry[1]))

    engine = WheelPadEngine(
        ring_inner=float(cfg["ring_inner"]),
        degrees_per_click=float(cfg["degrees_per_click"]),
        engage_degrees=float(cfg["engage_degrees"]),
        natural=bool(cfg["natural"]),
        horizontal=bool(cfg["horizontal"]),
    )

    if dry_run:
        log("--dry-run: reading only, no grab, no virtual devices.")
        log("circle the OUTER ring; engage/scroll decisions print below.")

    # ── Virtual devices ──
    # The clone carries the touchpad's own capabilities verbatim, minus the
    # synthetic EV_SYN that evdev reports back to us, so libinput treats it
    # exactly like the real thing.
    ui_pad = None
    ui_wheel = None
    if not dry_run:
        clone_caps = dev.capabilities(absinfo=True)
        clone_caps.pop(ecodes.EV_SYN, None)
        clone_caps.pop(ecodes.EV_FF, None)
        try:
            ui_pad = UInput(clone_caps,
                            name="Zen WheelPad (%s)" % dev.name,
                            vendor=dev.info.vendor,
                            product=dev.info.product,
                            version=dev.info.version)
        except Exception as exc:
            log("cannot create virtual touchpad: %s" % exc)
            log("  is /dev/uinput writable? (see the udev rule Zen Shell ships)")
            return 7

        try:
            ui_wheel = UInput(
                {ecodes.EV_REL: [ecodes.REL_WHEEL, ecodes.REL_HWHEEL,
                                 ecodes.REL_WHEEL_HI_RES, ecodes.REL_HWHEEL_HI_RES]},
                name="Zen WheelPad Scroll")
        except Exception:
            # HI_RES is newer; fall back to plain wheel axes.
            ui_wheel = UInput(
                {ecodes.EV_REL: [ecodes.REL_WHEEL, ecodes.REL_HWHEEL]},
                name="Zen WheelPad Scroll")

        try:
            dev.grab()
        except Exception as exc:
            log("cannot grab the touchpad: %s" % exc)
            return 8
        log("grabbed; republished as %r" % "Zen WheelPad")

    # ── Live finger state ──
    cur_x, cur_y = None, None
    slot = 0
    fingers = 0
    frame = []          # events buffered until the next EV_SYN
    swallowing = False

    def emit_scroll(clicks):
        if ui_wheel is None:
            return
        axis = ecodes.REL_HWHEEL if engine.horizontal else ecodes.REL_WHEEL
        ui_wheel.write(ecodes.EV_REL, axis, clicks)
        hi = ecodes.REL_HWHEEL_HI_RES if engine.horizontal else ecodes.REL_WHEEL_HI_RES
        try:
            ui_wheel.write(ecodes.EV_REL, hi, clicks * 120)
        except Exception:
            pass
        ui_wheel.syn()

    def lift_virtual_finger():
        """
        Tell the clone the finger is gone, so libinput closes the touch
        sequence cleanly instead of seeing it teleport when we resume.
        """
        if ui_pad is None:
            return
        try:
            ui_pad.write(ecodes.EV_ABS, ecodes.ABS_MT_TRACKING_ID, -1)
        except Exception:
            pass
        ui_pad.write(ecodes.EV_KEY, ecodes.BTN_TOUCH, 0)
        ui_pad.write(ecodes.EV_KEY, ecodes.BTN_TOOL_FINGER, 0)
        ui_pad.syn()

    def flush(events):
        if ui_pad is None:
            return
        for ev in events:
            ui_pad.write(ev.type, ev.code, ev.value)
        ui_pad.syn()

    running = {"go": True}

    def stop(_sig, _frm):
        running["go"] = False

    signal.signal(signal.SIGINT, stop)
    signal.signal(signal.SIGTERM, stop)

    try:
        for ev in dev.read_loop():
            if not running["go"]:
                break

            if ev.type == ecodes.EV_ABS:
                if ev.code == ecodes.ABS_MT_SLOT:
                    slot = ev.value
                elif ev.code == ecodes.ABS_MT_TRACKING_ID:
                    if ev.value == -1:
                        fingers = max(0, fingers - 1)
                        if fingers == 0:
                            if engine.finger_up() and not dry_run:
                                # We had lifted the virtual finger already;
                                # nothing to close, just resume forwarding.
                                swallowing = False
                            cur_x = cur_y = None
                    else:
                        fingers += 1
                elif ev.code in (ecodes.ABS_MT_POSITION_X, ecodes.ABS_X):
                    if slot == 0:
                        cur_x = ev.value
                elif ev.code in (ecodes.ABS_MT_POSITION_Y, ecodes.ABS_Y):
                    if slot == 0:
                        cur_y = ev.value
            elif ev.type == ecodes.EV_KEY:
                if ev.code == ecodes.BTN_TOUCH and ev.value == 0:
                    fingers = 0
                    engine.finger_up()
                    swallowing = False
                    cur_x = cur_y = None

            if ev.type != ecodes.EV_SYN:
                frame.append(ev)
                continue

            # ── frame boundary ──
            action = WheelPadEngine.FORWARD
            if cur_x is not None and cur_y is not None:
                nx = (cur_x - rx[0]) / float(rx[1])
                ny = (cur_y - ry[0]) / float(ry[1])
                nx = min(1.0, max(0.0, nx))
                ny = min(1.0, max(0.0, ny))
                action = engine.feed(nx, ny, fingers if fingers else 1)

            if dry_run:
                if action in (WheelPadEngine.ENGAGE, WheelPadEngine.SCROLL):
                    log("%-7s r=%.2f clicks=%+d"
                        % (action, engine.radius(nx, ny), engine.pending_clicks))
                frame = []
                continue

            if action == WheelPadEngine.ENGAGE:
                lift_virtual_finger()
                swallowing = True
            elif action == WheelPadEngine.SCROLL:
                emit_scroll(engine.pending_clicks)
            elif action == WheelPadEngine.FORWARD:
                swallowing = False

            if not swallowing:
                flush(frame)
            frame = []

    except KeyboardInterrupt:
        pass
    except OSError as exc:
        log("input stream ended: %s" % exc)
    finally:
        try:
            dev.ungrab()
        except Exception:
            pass
        for u in (ui_pad, ui_wheel):
            if u is not None:
                try:
                    u.close()
                except Exception:
                    pass
        dev.close()
        log("stopped; physical touchpad released back to the compositor.")

    return 0


def main():
    ap = argparse.ArgumentParser(
        prog="zen-wheelpad",
        description="Circular scrolling for Panasonic Let's Note touchpads "
                    "under Wayland. Part of Zen Shell.")
    ap.add_argument("--dry-run", action="store_true",
                    help="read the pad and print decisions; no grab, no "
                         "virtual devices, nothing to break. Start here.")
    ap.add_argument("--any-machine", action="store_true",
                    help="skip the Panasonic DMI check (other round pads, or "
                         "just to try it on a normal touchpad)")
    ap.add_argument("--device", default=None,
                    help="event path or name substring; default auto-detect")
    ap.add_argument("--ring", type=float, default=None,
                    help="inner edge of the ring, 0..1 of the radius "
                         "(default %.2f)" % DEFAULTS["ring_inner"])
    ap.add_argument("--degrees-per-click", type=float, default=None,
                    help="angular travel per scroll click (default %.0f)"
                         % DEFAULTS["degrees_per_click"])
    ap.add_argument("--natural", action="store_true",
                    help="invert scroll direction")
    ap.add_argument("--list", action="store_true",
                    help="list candidate touchpads and exit")
    ap.add_argument("--version", action="store_true")
    args = ap.parse_args()

    if args.version:
        print("zen-wheelpad %s" % VERSION)
        return 0

    cfg = load_config()
    if args.any_machine:
        cfg["require_panasonic"] = False
    if args.device is not None:
        cfg["device"] = args.device
    if args.ring is not None:
        cfg["ring_inner"] = args.ring
    if args.degrees_per_click is not None:
        cfg["degrees_per_click"] = args.degrees_per_click
    if args.natural:
        cfg["natural"] = True

    if args.list:
        try:
            import evdev
        except ImportError:
            log("python-evdev is not installed.")
            return 3
        print("DMI: %s / %s" % (read_dmi("sys_vendor"), panasonic_model()))
        print("Panasonic detected: %s" % ("yes" if is_panasonic() else "no"))
        d = find_touchpad(evdev, cfg.get("device", ""))
        if d is None:
            print("no touchpad found")
            return 5
        print("touchpad: %s  %s" % (d.path, d.name))
        d.close()
        return 0

    if not cfg["enabled"]:
        log("disabled in %s — exiting." % CONFIG_PATH)
        return 0

    return run(cfg, dry_run=args.dry_run)


if __name__ == "__main__":
    sys.exit(main())
