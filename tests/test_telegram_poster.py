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

import telegram_poster as poster


class TelegramPosterScheduleTests(unittest.TestCase):
    def test_quiet_window_blocks_posts_from_22_until_08_ist(self):
        cases = (
            (datetime(2026, 10, 24, 7, 59, tzinfo=poster.IST), False),
            (datetime(2026, 10, 24, 8, 0, tzinfo=poster.IST), True),
            (datetime(2026, 10, 24, 21, 59, tzinfo=poster.IST), True),
            (datetime(2026, 10, 24, 22, 0, tzinfo=poster.IST), False),
        )
        for now, expected in cases:
            with self.subTest(now=now):
                self.assertEqual(poster.is_posting_window(now), expected)

    def test_due_business_news_is_selected_before_older_queue_posts(self):
        now = datetime(2026, 10, 24, 12, 0, tzinfo=poster.IST)
        queue = {"queue": [
            {
                "id": "evergreen-1", "kind": "evergreen",
                "scheduled_ist": "2026-10-24 08:00", "used": False,
            },
            {
                "id": "business-news-1", "kind": "business_news_insight",
                "scheduled_ist": "2026-10-24 12:00", "used": False,
            },
        ]}
        with patch.object(poster, "NOW", now), patch.object(
            poster, "is_duplicate", return_value=False
        ):
            item, index = poster.pick_evergreen_post(queue, {})

        self.assertEqual(item["id"], "business-news-1")
        self.assertEqual(index, 1)

    def test_quiet_hours_main_returns_without_sending(self):
        now = datetime(2026, 10, 24, 2, 0, tzinfo=poster.IST)
        loaded = {
            poster.QUEUE_FILE: {"queue": []},
            poster.FEED_FILE: {"content_feed": []},
            poster.STATE_FILE: {},
            poster.POSTED_LOG: {},
        }
        with (
            patch.object(poster, "NOW", now),
            patch.object(poster, "load_json", side_effect=lambda path, _default: loaded[path]),
            patch.object(poster, "send_telegram_message", side_effect=AssertionError("must not send")),
        ):
            poster.main()


if __name__ == "__main__":
    unittest.main()
