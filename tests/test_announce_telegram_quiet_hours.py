import sys
import types
import unittest
from datetime import datetime
from unittest.mock import patch

try:
    import requests  # noqa: F401
except ModuleNotFoundError:
    requests_stub = types.ModuleType("requests")
    sys.modules["requests"] = requests_stub

import announce_telegram_bot as dispatcher


class AnnouncementQuietHoursTests(unittest.TestCase):
    def test_posting_window_is_08_to_22_ist(self):
        cases = (
            (datetime(2026, 10, 24, 7, 59, tzinfo=dispatcher.IST), False),
            (datetime(2026, 10, 24, 8, 0, tzinfo=dispatcher.IST), True),
            (datetime(2026, 10, 24, 21, 59, tzinfo=dispatcher.IST), True),
            (datetime(2026, 10, 24, 22, 0, tzinfo=dispatcher.IST), False),
        )
        for now, expected in cases:
            with self.subTest(now=now):
                self.assertEqual(dispatcher.is_posting_window(now), expected)

    def test_quiet_hours_skip_the_separate_nse_sender(self):
        now = datetime(2026, 10, 24, 2, 0, tzinfo=dispatcher.IST)
        with patch.object(
            dispatcher,
            "send_to_telegram",
            side_effect=AssertionError("NSE announcements must not send during quiet hours"),
        ):
            dispatcher.dispatch_feed(now)


if __name__ == "__main__":
    unittest.main()
