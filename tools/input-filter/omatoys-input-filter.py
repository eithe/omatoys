#!/usr/bin/env python3
"""Suppress accidental repeated input events from worn keyboards and mice.

Runs in one of two modes:

  key    debounce repeated presses of the same key on keyboard devices
  click  debounce repeated presses of the same button on mouse devices

The debounce window defaults to 10 ms for keys and 25 ms for clicks and can be
overridden with the OMATOYS_FILTER_WINDOW_MS environment variable.
"""

import contextlib
import errno
import os
import select
import signal
import sys
import time

from evdev import InputDevice, UInput, ecodes, list_devices

# How often to look for newly attached devices, in seconds.
RESCAN_SECONDS = 2.0
# Poll timeout, in milliseconds. Bounds how quickly the loop reacts to SIGTERM.
POLL_TIMEOUT_MS = 250

MOUSE_BUTTONS = frozenset({ecodes.BTN_LEFT, ecodes.BTN_RIGHT, ecodes.BTN_MIDDLE})

running = True


def stop(_signum, _frame):
    global running
    running = False


def _capabilities(device):
    try:
        return device.capabilities()
    except OSError:
        return {}


def is_keyboard(device):
    """A device that reports the alphanumeric keys a typist actually uses."""
    caps = _capabilities(device)
    keys = set(caps.get(ecodes.EV_KEY, []))
    return ecodes.KEY_A in keys and ecodes.KEY_SPACE in keys


def is_mouse(device):
    """A relative pointing device with mouse buttons.

    Touchpads, touchscreens and graphics tablets also report BTN_LEFT, but they
    are absolute devices. Grabbing them and replaying through uinput loses the
    device properties libinput uses to classify them, which breaks gestures and
    pointer acceleration, so they are deliberately excluded.
    """
    caps = _capabilities(device)
    keys = set(caps.get(ecodes.EV_KEY, []))
    if not keys & MOUSE_BUTTONS:
        return False

    rel_axes = set(caps.get(ecodes.EV_REL, []))
    if not {ecodes.REL_X, ecodes.REL_Y} <= rel_axes:
        return False

    abs_axes = set(caps.get(ecodes.EV_ABS, []))
    if {ecodes.ABS_X, ecodes.ABS_Y} <= abs_axes:
        return False

    try:
        props = set(device.input_props())
    except (AttributeError, OSError):
        props = set()
    excluded = {
        getattr(ecodes, name)
        for name in ("INPUT_PROP_BUTTONPAD", "INPUT_PROP_DIRECT", "INPUT_PROP_SEMI_MT")
        if hasattr(ecodes, name)
    }
    return not props & excluded


MODES = {
    "key": {
        "match": is_keyboard,
        "codes": None,  # every key code is debounced
        "window_ms": 10,
        "uinput_name": "Omatoys Key Filter",
    },
    "click": {
        "match": is_mouse,
        "codes": MOUSE_BUTTONS,
        "window_ms": 25,
        "uinput_name": "Omatoys Click Filter",
    },
}


def window_seconds(mode):
    """Debounce window, overridable via OMATOYS_FILTER_WINDOW_MS."""
    raw = os.environ.get("OMATOYS_FILTER_WINDOW_MS", "").strip()
    if not raw:
        return mode["window_ms"] / 1000.0
    try:
        value = float(raw)
    except ValueError:
        print(
            f"Ignoring invalid OMATOYS_FILTER_WINDOW_MS={raw!r}",
            file=sys.stderr,
            flush=True,
        )
        return mode["window_ms"] / 1000.0
    if value < 0:
        print(
            f"Ignoring negative OMATOYS_FILTER_WINDOW_MS={raw!r}",
            file=sys.stderr,
            flush=True,
        )
        return mode["window_ms"] / 1000.0
    return value / 1000.0


class Filter:
    """Grabs matching devices and replays their events, minus the bounces."""

    def __init__(self, mode):
        self.mode = mode
        self.window = window_seconds(mode)
        self.poller = select.poll()
        # path -> (device, uinput)
        self.grabbed = {}
        # (path, code) -> monotonic timestamp of the last accepted press
        self.last_press = {}
        # (path, code) of presses that were dropped, so the matching release
        # can be dropped too and the consumer never sees a stuck key.
        self.suppressed = set()

    # -- device bookkeeping -------------------------------------------------

    def _should_grab(self, device):
        if device.name.startswith(self.mode["uinput_name"]):
            return False
        return self.mode["match"](device)

    def scan(self):
        """Grab any matching device that is not grabbed yet."""
        try:
            paths = list_devices()
        except OSError as exc:
            print(f"Cannot enumerate input devices: {exc}", file=sys.stderr, flush=True)
            return

        for path in paths:
            if path in self.grabbed:
                continue
            try:
                device = InputDevice(path)
            except OSError:
                continue
            if not self._should_grab(device):
                device.close()
                continue
            try:
                output = UInput.from_device(
                    device, name=f"{self.mode['uinput_name']} ({device.name})"
                )
                device.grab()
            except OSError as exc:
                print(
                    f"Cannot grab {path} ({device.name}): {exc}",
                    file=sys.stderr,
                    flush=True,
                )
                device.close()
                continue

            self.grabbed[path] = (device, output)
            self.poller.register(device.fd, select.POLLIN)
            print(f"Filtering {device.name} ({path})", file=sys.stderr, flush=True)

    def release(self, path):
        """Drop a device that went away or stopped responding."""
        entry = self.grabbed.pop(path, None)
        if entry is None:
            return
        device, output = entry
        with contextlib.suppress(KeyError, OSError):
            self.poller.unregister(device.fd)
        with contextlib.suppress(OSError):
            device.ungrab()
        try:
            output.close()
        finally:
            device.close()
        self.last_press = {k: v for k, v in self.last_press.items() if k[0] != path}
        self.suppressed = {k for k in self.suppressed if k[0] != path}
        print(f"Stopped filtering {path}", file=sys.stderr, flush=True)

    def release_all(self):
        for path in list(self.grabbed):
            self.release(path)

    # -- event handling -----------------------------------------------------

    def _is_debounced(self, code):
        codes = self.mode["codes"]
        return codes is None or code in codes

    def _handle_events(self, path, device, output):
        """Replay one batch of events. Returns False if the device is gone."""
        try:
            events = list(device.read())
        except BlockingIOError:
            return True
        except OSError as exc:
            if exc.errno not in (errno.ENODEV, errno.ENOENT, errno.EBADF):
                print(f"Read error on {path}: {exc}", file=sys.stderr, flush=True)
            return False

        wrote = False
        for event in events:
            if event.type != ecodes.EV_KEY or not self._is_debounced(event.code):
                output.write_event(event)
                wrote = True
                continue

            token = (path, event.code)
            if event.value == 1:  # press
                now = time.monotonic()
                if now - self.last_press.get(token, 0.0) < self.window:
                    self.suppressed.add(token)
                    continue
                self.last_press[token] = now
            elif event.value == 0 and token in self.suppressed:  # matching release
                self.suppressed.discard(token)
                continue

            output.write_event(event)
            wrote = True

        if wrote:
            output.syn()
        return True

    # -- main loop ----------------------------------------------------------

    def run(self):
        self.scan()
        if not self.grabbed:
            print(
                "No matching input devices found; waiting for one to appear",
                file=sys.stderr,
                flush=True,
            )
        next_scan = time.monotonic() + RESCAN_SECONDS

        try:
            while running:
                try:
                    ready = {fd for fd, _events in self.poller.poll(POLL_TIMEOUT_MS)}
                except InterruptedError:
                    continue

                for path, (device, output) in list(self.grabbed.items()):
                    if device.fd not in ready:
                        continue
                    if not self._handle_events(path, device, output):
                        self.release(path)

                now = time.monotonic()
                if now >= next_scan:
                    self.scan()
                    next_scan = now + RESCAN_SECONDS
        finally:
            self.release_all()


def main(argv):
    mode_name = argv[1] if len(argv) > 1 else ""
    mode = MODES.get(mode_name)
    if mode is None:
        print(f"Usage: {argv[0]} {{{'|'.join(MODES)}}}", file=sys.stderr)
        return 2

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    Filter(mode).run()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
