import sys
import types
import unittest
from datetime import datetime
from unittest.mock import Mock, patch

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

    def test_business_news_queue_post_includes_its_telegraph_link(self):
        now = datetime(2026, 10, 24, 12, 0, tzinfo=poster.IST)
        page_url = "https://telegra.ph/rbi-policy-update"
        queue = {"queue": [{
            "id": "business-news-1",
            "kind": "business_news_insight",
            "scheduled_ist": "2026-10-24 12:00",
            "title": "RBI holds repo rate as inflation eases",
            "text": "📊 RBI holds repo rate.\n\n🔗 Source: CNBC-TV18",
            "used": False,
        }]}
        loaded = {
            poster.QUEUE_FILE: queue,
            poster.FEED_FILE: {"content_feed": []},
            poster.STATE_FILE: {"published": {}},
            poster.POSTED_LOG: {},
        }

        with (
            patch.object(poster, "NOW", now),
            patch.object(poster, "BOT_TOKEN", "test-token"),
            patch.object(poster, "QUEUE_ONLY", True),
            patch.object(poster, "DRY_RUN", False),
            patch.object(poster, "is_posting_window", return_value=True),
            patch.object(poster, "load_json", side_effect=lambda path, _default: loaded[path]),
            patch.object(poster, "get_telegraph_token", return_value="telegraph-token"),
            patch.object(poster, "publish_to_telegraph", return_value=(page_url, None)),
            patch.object(poster, "send_telegram_message", return_value=(True, 123, None)) as send,
            patch.object(poster, "save_json"),
        ):
            poster.main()

        self.assertIn(page_url, send.call_args.args[0])
        self.assertTrue(queue["queue"][0]["used"])
        self.assertEqual(queue["queue"][0]["telegraph_url"], page_url)

    def test_telegraph_page_keeps_official_source_urls_from_html_links(self):
        response = Mock()
        response.json.return_value = {
            "ok": True,
            "result": {"url": "https://telegra.ph/test-source-link"},
        }
        source_url = "https://nsearchives.nseindia.com/corporate/sample.pdf"
        with (
            patch.object(poster, "DRY_RUN", False),
            patch.object(poster.requests, "post", return_value=response, create=True) as request,
        ):
            page_url, error = poster.publish_to_telegraph(
                "test-token",
                "NSE filing update",
                f'<b>Source:</b> <a href="{source_url}">Official filing</a>',
            )

        self.assertIsNone(error)
        self.assertEqual(page_url, "https://telegra.ph/test-source-link")
        content = request.call_args.kwargs["json"]["content"]
        self.assertIn(source_url, str(content))
        self.assertIn("Official filing", str(content))

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
