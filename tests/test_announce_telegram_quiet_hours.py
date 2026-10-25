import json
import sys
import tempfile
import types
import unittest
from datetime import datetime, timedelta
from pathlib import Path
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

    def test_nse_announcement_gets_a_separate_telegraph_page_and_link(self):
        now = datetime(2026, 10, 25, 12, 0, tzinfo=dispatcher.IST)
        page_url = "https://telegra.ph/test-nse-announcement"
        source_url = "https://nsearchives.nseindia.com/corporate/sample-filing.pdf"
        card = {
            "hash": "nse-hash-001",
            "symbol": "TESTCO",
            "headline": "TestCo announces a new manufacturing facility",
            "broadcast_date": (now - timedelta(minutes=10)).strftime("%d-%b-%Y %H:%M:%S"),
            "pdf_link": source_url,
            "telegram_post": (
                "🏭 <b>TESTCO</b>\n\n"
                "TestCo announces a new manufacturing facility\n"
                f"🔗 <b>Source:</b> <a href=\"{source_url}\">NSE filing</a>"
            ),
        }

        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            input_path = root / "nse_content_feed.json"
            posted_path = root / "telegram_posted_log.json"
            state_path = root / "telegraph_state.json"
            input_path.write_text(json.dumps({"content_feed": [card]}), encoding="utf-8")

            with (
                patch.object(dispatcher, "INPUT_FILE", str(input_path)),
                patch.object(dispatcher, "POSTED_LOG_FILE", str(posted_path)),
                patch.object(dispatcher, "TELEGRAPH_STATE_FILE", str(state_path)),
                patch.object(
                    dispatcher,
                    "SHARED_TELEGRAPH_STATE_FILE",
                    str(root / "missing-shared-state.json"),
                ),
                patch.object(dispatcher, "BOT_TOKEN", "test-token"),
                patch.object(dispatcher, "is_posting_window", return_value=True),
                patch.object(dispatcher, "get_telegraph_token", return_value="telegraph-token"),
                patch.object(dispatcher, "publish_to_telegraph", return_value=(page_url, None)) as publish,
                patch.object(dispatcher, "send_to_telegram", return_value=(True, "ok")) as send,
                patch.object(dispatcher.time, "sleep"),
            ):
                dispatcher.dispatch_feed(now)

            sent_text = send.call_args.args[0]
            self.assertIn(page_url, sent_text)
            self.assertIn("Read on Web", sent_text)
            publish.assert_called_once()
            state = json.loads(state_path.read_text(encoding="utf-8"))
            self.assertIn("nse:nse-hash-001", state["published"])
            self.assertEqual(state["published"]["nse:nse-hash-001"]["url"], page_url)


if __name__ == "__main__":
    unittest.main()
