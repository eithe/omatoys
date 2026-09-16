"""Unit tests for the Omatoys input filter.

These cover the device-matching predicates and the debounce logic without
touching real input devices, so they run unprivileged in CI.
"""

import importlib.util
import sys
import unittest
from pathlib import Path
from types import SimpleNamespace

from evdev import ecodes

HELPER = Path(__file__).resolve().parents[1] / "tools" / "input-filter" / "omatoys-input-filter.py"

_spec = importlib.util.spec_from_file_location("omatoys_input_filter", HELPER)
input_filter = importlib.util.module_from_spec(_spec)
sys.modules["omatoys_input_filter"] = input_filter
_spec.loader.exec_module(input_filter)


class FakeDevice:
    def __init__(self, name, capabilities, props=()):
        self.name = name
        self._capabilities = capabilities
        self._props = list(props)
        self.fd = 3
        self.grabbed = False

    def capabilities(self):
        return self._capabilities

    def input_props(self):
        return self._props


class FakeUInput:
    def __init__(self):
        self.written = []
        self.syns = 0

    def write_event(self, event):
        self.written.append(event)

    def syn(self):
        self.syns += 1


def key_event(code, value, etype=ecodes.EV_KEY):
    return SimpleNamespace(type=etype, code=code, value=value)


MOUSE_CAPS = {
    ecodes.EV_KEY: [ecodes.BTN_LEFT, ecodes.BTN_RIGHT, ecodes.BTN_MIDDLE],
    ecodes.EV_REL: [ecodes.REL_X, ecodes.REL_Y, ecodes.REL_WHEEL],
}
TOUCHPAD_CAPS = {
    ecodes.EV_KEY: [ecodes.BTN_LEFT, ecodes.BTN_TOUCH],
    ecodes.EV_ABS: [ecodes.ABS_X, ecodes.ABS_Y],
}
KEYBOARD_CAPS = {
    ecodes.EV_KEY: [ecodes.KEY_A, ecodes.KEY_SPACE, ecodes.KEY_ESC],
}


class DevicePredicateTests(unittest.TestCase):
    def test_plain_mouse_matches(self):
        self.assertTrue(input_filter.is_mouse(FakeDevice("Logitech Mouse", MOUSE_CAPS)))

    def test_touchpad_is_excluded(self):
        self.assertFalse(input_filter.is_mouse(FakeDevice("Synaptics Touchpad", TOUCHPAD_CAPS)))

    def test_buttonpad_property_is_excluded(self):
        device = FakeDevice("Clickpad", MOUSE_CAPS, props=[ecodes.INPUT_PROP_BUTTONPAD])
        self.assertFalse(input_filter.is_mouse(device))

    def test_keyboard_without_relative_axes_is_not_a_mouse(self):
        self.assertFalse(input_filter.is_mouse(FakeDevice("Keyboard", KEYBOARD_CAPS)))

    def test_keyboard_matches(self):
        self.assertTrue(input_filter.is_keyboard(FakeDevice("Keyboard", KEYBOARD_CAPS)))

    def test_mouse_is_not_a_keyboard(self):
        self.assertFalse(input_filter.is_keyboard(FakeDevice("Logitech Mouse", MOUSE_CAPS)))


class WindowSecondsTests(unittest.TestCase):
    def setUp(self):
        self.mode = input_filter.MODES["click"]
        self._saved = input_filter.os.environ.pop("OMATOYS_FILTER_WINDOW_MS", None)

    def tearDown(self):
        if self._saved is None:
            input_filter.os.environ.pop("OMATOYS_FILTER_WINDOW_MS", None)
        else:
            input_filter.os.environ["OMATOYS_FILTER_WINDOW_MS"] = self._saved

    def test_default(self):
        self.assertAlmostEqual(input_filter.window_seconds(self.mode), 0.025)

    def test_override(self):
        input_filter.os.environ["OMATOYS_FILTER_WINDOW_MS"] = "40"
        self.assertAlmostEqual(input_filter.window_seconds(self.mode), 0.040)

    def test_invalid_falls_back_to_default(self):
        input_filter.os.environ["OMATOYS_FILTER_WINDOW_MS"] = "soon"
        self.assertAlmostEqual(input_filter.window_seconds(self.mode), 0.025)

    def test_negative_falls_back_to_default(self):
        input_filter.os.environ["OMATOYS_FILTER_WINDOW_MS"] = "-5"
        self.assertAlmostEqual(input_filter.window_seconds(self.mode), 0.025)


class DebounceTests(unittest.TestCase):
    def setUp(self):
        self.filter = input_filter.Filter(input_filter.MODES["click"])
        self.filter.window = 0.025
        self.device = FakeDevice("Mouse", MOUSE_CAPS)
        self.output = FakeUInput()
        self.now = 1000.0
        self._real_monotonic = input_filter.time.monotonic
        input_filter.time.monotonic = lambda: self.now

    def tearDown(self):
        input_filter.time.monotonic = self._real_monotonic

    def feed(self, events):
        self.device.read = lambda: iter(events)
        return self.filter._handle_events("/dev/input/event0", self.device, self.output)

    def values(self, code=ecodes.BTN_LEFT):
        return [e.value for e in self.output.written if e.code == code]

    def test_single_click_passes_through(self):
        self.feed([key_event(ecodes.BTN_LEFT, 1), key_event(ecodes.BTN_LEFT, 0)])
        self.assertEqual(self.values(), [1, 0])

    def test_bounce_within_window_is_dropped_with_its_release(self):
        self.feed([key_event(ecodes.BTN_LEFT, 1), key_event(ecodes.BTN_LEFT, 0)])
        self.now += 0.005
        self.feed([key_event(ecodes.BTN_LEFT, 1), key_event(ecodes.BTN_LEFT, 0)])
        # The bounce and its matching release are both suppressed, so the
        # consumer never sees an unbalanced press.
        self.assertEqual(self.values(), [1, 0])

    def test_deliberate_click_after_window_passes(self):
        self.feed([key_event(ecodes.BTN_LEFT, 1), key_event(ecodes.BTN_LEFT, 0)])
        self.now += 0.050
        self.feed([key_event(ecodes.BTN_LEFT, 1), key_event(ecodes.BTN_LEFT, 0)])
        self.assertEqual(self.values(), [1, 0, 1, 0])

    def test_other_buttons_are_tracked_independently(self):
        self.feed([key_event(ecodes.BTN_LEFT, 1), key_event(ecodes.BTN_LEFT, 0)])
        self.now += 0.005
        self.feed([key_event(ecodes.BTN_RIGHT, 1), key_event(ecodes.BTN_RIGHT, 0)])
        self.assertEqual(self.values(ecodes.BTN_RIGHT), [1, 0])

    def test_untracked_key_codes_are_forwarded_unfiltered(self):
        self.feed([key_event(ecodes.BTN_SIDE, 1), key_event(ecodes.BTN_SIDE, 0)])
        self.now += 0.001
        self.feed([key_event(ecodes.BTN_SIDE, 1), key_event(ecodes.BTN_SIDE, 0)])
        self.assertEqual(self.values(ecodes.BTN_SIDE), [1, 0, 1, 0])

    def test_relative_motion_is_forwarded(self):
        self.feed([key_event(ecodes.REL_X, 5, etype=ecodes.EV_REL)])
        self.assertEqual(len(self.output.written), 1)
        self.assertEqual(self.output.syns, 1)

    def test_vanished_device_reports_gone(self):
        def raise_enodev():
            raise OSError(input_filter.errno.ENODEV, "No such device")

        self.device.read = raise_enodev
        self.assertFalse(self.filter._handle_events("/dev/input/event0", self.device, self.output))

    def test_key_mode_debounces_every_code(self):
        key_filter = input_filter.Filter(input_filter.MODES["key"])
        key_filter.window = 0.010
        device = FakeDevice("Keyboard", KEYBOARD_CAPS)
        output = FakeUInput()
        device.read = lambda: iter([key_event(ecodes.KEY_A, 1), key_event(ecodes.KEY_A, 0)])
        key_filter._handle_events("/dev/input/event1", device, output)
        self.now += 0.002
        key_filter._handle_events("/dev/input/event1", device, output)
        self.assertEqual([e.value for e in output.written], [1, 0])


if __name__ == "__main__":
    unittest.main()
