#!/usr/bin/env python3
"""Suppress accidental same-key presses from worn keyboards."""

import signal
import select
import time

from evdev import InputDevice, UInput, ecodes, list_devices

WINDOW_SECONDS = 0.01
running = True


def is_keyboard(device):
    keys = set(device.capabilities().get(ecodes.EV_KEY, []))
    return (
        ecodes.KEY_A in keys
        and ecodes.KEY_SPACE in keys
        and not device.name.startswith("Omatoys Key Filter")
    )


def stop(_signum, _frame):
    global running
    running = False


def main():
    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)

    devices = [InputDevice(path) for path in list_devices()]
    keyboards = [device for device in devices if is_keyboard(device)]
    if not keyboards:
        raise RuntimeError("No keyboard input devices found")

    outputs = []
    try:
        for device in keyboards:
            output = UInput.from_device(device, name=f"Omatoys Key Filter ({device.name})")
            device.grab()
            outputs.append((device, output))

        last_press = {}
        suppressed = set()
        poller = select.poll()
        for device, _output in outputs:
            poller.register(device.fd, select.POLLIN)

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

                    key = event.code
                    if event.value == 1:
                        now = time.monotonic()
                        if now - last_press.get((device.fd, key), 0) < WINDOW_SECONDS:
                            suppressed.add((device.fd, key))
                            continue
                        last_press[(device.fd, key)] = now
                    elif event.value == 0 and (device.fd, key) in suppressed:
                        suppressed.remove((device.fd, key))
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
