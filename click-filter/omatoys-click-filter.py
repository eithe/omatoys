#!/usr/bin/env python3
"""Suppress accidental rapid clicks from worn mouse buttons."""

import select
import signal
import time

from evdev import InputDevice, UInput, ecodes, list_devices

WINDOW_SECONDS = 0.025
BUTTONS = {ecodes.BTN_LEFT, ecodes.BTN_RIGHT, ecodes.BTN_MIDDLE}
running = True


def is_mouse(device):
    keys = set(device.capabilities().get(ecodes.EV_KEY, []))
    return bool(keys & BUTTONS) and not device.name.startswith("Omatoys Click Filter")


def stop(_signum, _frame):
    global running
    running = False


def main():
    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)

    devices = [InputDevice(path) for path in list_devices()]
    mice = [device for device in devices if is_mouse(device)]
    if not mice:
        raise RuntimeError("No mouse input devices found")

    outputs = []
    try:
        for device in mice:
            output = UInput.from_device(device, name=f"Omatoys Click Filter ({device.name})")
            device.grab()
            outputs.append((device, output))

        poller = select.poll()
        for device, _output in outputs:
            poller.register(device.fd, select.POLLIN)

        last_click = {}
        suppressed = set()
        while running:
            ready = {fd for fd, _events in poller.poll(250)}
            for device, output in outputs:
                if device.fd not in ready:
                    continue
                try:
                    events = device.read()
                except BlockingIOError:
                    continue
                for event in events:
                    if event.type != ecodes.EV_KEY:
                        output.write_event(event)
                        continue

                    button = event.code
                    if button not in BUTTONS:
                        output.write_event(event)
                        continue
                    if event.value == 1:
                        now = time.monotonic()
                        if now - last_click.get((device.fd, button), 0) < WINDOW_SECONDS:
                            suppressed.add((device.fd, button))
                            continue
                        last_click[(device.fd, button)] = now
                    elif event.value == 0 and (device.fd, button) in suppressed:
                        suppressed.remove((device.fd, button))
                        continue
                    output.write_event(event)
                output.syn()
    finally:
        for device, output in outputs:
            try:
                device.ungrab()
            finally:
                output.close()
                device.close()


if __name__ == "__main__":
    main()
