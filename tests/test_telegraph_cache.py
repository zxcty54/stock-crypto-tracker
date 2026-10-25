import unittest

from telegraph_cache import find_cached_page, remember_page


class TelegraphContentCacheTests(unittest.TestCase):
    def test_matching_content_reuses_page(self):
        state = {"published": {}}
        remember_page(
            state,
            "ai0001",
            "Current title",
            "Current text",
            "https://telegra.ph/current-page",
            "evergreen",
            "2026-10-25 12:00:00 IST",
        )

        self.assertEqual(
            find_cached_page(state, "ai0001", "Current title", "Current text"),
            "https://telegra.ph/current-page",
        )

    def test_reused_post_id_does_not_reuse_page_for_different_content(self):
        state = {"published": {}}
        remember_page(
            state,
            "ai0002",
            "Old title",
            "Old body",
            "https://telegra.ph/old-page",
            "evergreen",
            "2026-10-07 12:00:00 IST",
        )

        self.assertIsNone(
            find_cached_page(state, "ai0002", "New title", "New body")
        )

    def test_legacy_entry_without_fingerprint_is_not_trusted(self):
        state = {"published": {"ai0003": {"url": "https://telegra.ph/unknown-page"}}}
        self.assertIsNone(
            find_cached_page(state, "ai0003", "Title", "Text")
        )


if __name__ == "__main__":
    unittest.main()
