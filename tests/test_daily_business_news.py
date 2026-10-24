import importlib.util
import sys
import types
import unittest
from datetime import timedelta, timezone
from email.utils import format_datetime
from unittest.mock import patch
from pathlib import Path


# The scraper needs requests only when it fetches RSS/article pages. Keep these
# unit tests fully offline when the optional runtime dependency is not installed.
try:
    import requests  # noqa: F401
except ModuleNotFoundError:
    requests_stub = types.ModuleType("requests")
    sys.modules["requests"] = requests_stub

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
import daily_business_news as news  # noqa: E402


class DailyBusinessNewsFilterTests(unittest.TestCase):
    def item(self, title, hours_ago=1, url=None, source="CNBC-TV18", priority=3, summary=""):
        return {
            "source": source,
            "source_priority": priority,
            "title": title,
            "url": url or f"https://www.cnbctv18.com/market/stocks/{abs(hash(title))}.htm",
            "summary": summary,
            "published": news.NOW - timedelta(hours=hours_ago),
        }

    def record(self, item, status="new", post_id=None):
        published = item["published"]
        return {
            "id": news._alpha_id(item["url"]),
            "source": item["source"],
            "source_priority": item["source_priority"],
            "headline": item["title"],
            "url": item["url"],
            "published_at": published.isoformat(),
            "published_ist": published.strftime("%Y-%m-%d %H:%M IST"),
            "summary": item.get("summary", ""),
            "first_seen_at": (published - timedelta(minutes=10)).isoformat(),
            "last_seen_at": published.isoformat(),
            "status": status,
            "post_id": post_id,
        }

    def test_accepts_economy_capital_markets_and_stock_events(self):
        self.assertEqual(
            news.classify_news_story("RBI keeps repo rate unchanged as inflation eases"),
            "economy",
        )
        self.assertEqual(
            news.classify_news_story("SEBI approves new IPO norms for NSE"),
            "capital_market",
        )
        self.assertEqual(
            news.classify_news_story("SEBI orders Avadhut Academy to refund ₹546 crore and pay a penalty"),
            "capital_market",
        )
        self.assertEqual(
            news.classify_news_story("Government launches new subsidy scheme for exporters"),
            "economy",
        )
        self.assertEqual(
            news.classify_news_story("BSE launches new settlement system for trading"),
            "capital_market",
        )
        self.assertEqual(
            news.classify_news_story("NSE updates rules for Nifty futures contracts"),
            "capital_market",
        )
        self.assertEqual(
            news.classify_news_story(
                "Amagi Media shares slip after company flags cybersecurity threat",
                url="https://www.cnbctv18.com/market/stocks/amagi-cybersecurity.htm",
            ),
            "stock_market",
        )
        self.assertIsNone(
            news.classify_news_story(
                "Highway Infrastructure wins ₹340 crore NHAI contract",
                url="https://www.cnbctv18.com/market/stocks/highway-infra.htm",
            )
        )

    def test_headline_scope_is_not_inferred_from_unrelated_rss_summary(self):
        self.assertIsNone(
            news.classify_news_story(
                "iPhone Duo display cracks reported by users",
                summary="The report has economic implications for retail markets and share prices.",
                url="https://economictimes.indiatimes.com/markets/us-stocks/iphone.htm",
            )
        )

    def test_fetch_feeds_filters_before_returning_items(self):
        pub_date = format_datetime(news.NOW.astimezone(timezone.utc))

        def fake_get(feed_url, **kwargs):
            source = next(feed for feed in news.FEEDS if feed["url"] == feed_url)
            host = source["domains"][0]
            xml = f"""<rss><channel>
                <item><title>RBI keeps repo rate unchanged as inflation eases</title>
                    <link>https://{host}/markets/rbi-repo-rate-test.html</link>
                    <pubDate>{pub_date}</pubDate>
                    <description>Official monetary policy update.</description></item>
                <item><title>iPhone Duo display cracks reported by users</title>
                    <link>https://{host}/markets/iphone-display-test.html</link>
                    <pubDate>{pub_date}</pubDate>
                    <description>Consumer technology report.</description></item>
                <item><title>Defence manufacturer bags 2000 crore order from MoD</title>
                    <link>https://{host}/markets/defence-order-test.html</link>
                    <pubDate>{pub_date}</pubDate>
                    <description>Commercial order award for a listed supplier.</description></item>
            </channel></rss>""".encode()
            return types.SimpleNamespace(
                status_code=200,
                content=xml,
                raise_for_status=lambda: None,
            )

        with patch.object(news.requests, "get", side_effect=fake_get, create=True):
            result = news.fetch_feeds()

        self.assertEqual(len(result["items"]), len(news.FEEDS))
        self.assertTrue(all(item["topic"] == "economy" for item in result["items"]))
        for status in result["status"].values():
            self.assertEqual(status["fresh_items"], 3)
            self.assertEqual(status["accepted_items"], 1)
            self.assertEqual(status["filtered_items"], 2)

    def test_rejects_company_results_and_opinion_or_recommendation_stories(self):
        for title in (
            "Tata Motors CV posts Rs 2,138 crore Q2 profit",
            "Acme Ltd revenue up 12% over last year",
            "ONGC profit falls as crude prices rise",
            "Analyst says these defence stocks could gain 30%",
            "Sell these defence stocks, says Goldman Sachs",
            "Brent crude may surge to $120 a barrel, broker forecasts",
            "Nippon Life AMC sees mutual fund slowdown as investors turn to alternatives",
            "Jio IPO dents investor bandwidth for listed stocks; liquidity shift weighs on markets",
        ):
            with self.subTest(title=title):
                self.assertIsNone(news.classify_news_story(title))

    def test_government_tax_revenue_is_not_misclassified_as_company_results(self):
        self.assertEqual(
            news.classify_news_story("Government tax revenue rises 12% in September"),
            "economy",
        )

    def test_excludes_generic_market_wraps_and_live_roundups(self):
        for title in (
            "US Markets Today: Dow ends 600 points lower",
            "Jio Platforms IPO Day 3 Highlights: Issue subscribed 6.9 times",
            "Stocks to Watch for October 23: RIL, Swiggy and HPCL",
        ):
            with self.subTest(title=title):
                self.assertIsNone(news.classify_news_story(title))

    def test_filters_routine_price_moves_but_keeps_material_market_events(self):
        for title in (
            "US Treasury yields rise but 10-year stays below 5% as AI jitters persist",
            "US stocks fall as AI spending worries hit tech shares, oil tops $112",
            "Rupee little changed this week as oil-fueled declines wipe out early gains",
            "Wall Street futures dip after AI rout, telecoms slide",
            "Sensex, Nifty end lower as Midcaps tumble; Swiggy suffers biggest single-day fall",
            "Stock Crash: This specialty chemical stock has seen its worst weekly fall in nearly two decades",
            "Stock Crash: eMudhra shares down 34% in three sessions; Management says one-off incident",
            "Nifty Smallcap Crash: Index set for worst week in 20 months; Here are the worst performers",
            "Lemon Tree Hotels signs 63-room Keys Lite property in Bhilwara, Rajasthan",
            "BSE begins hunt for MD & CEO successor ahead of 2027 exit",
            "A company names a new director to its board",
            "Highway Infrastructure wins ₹340 crore NHAI contract",
            "KEC International bags ₹1,006 crore in orders, shares hit 52-week low",
            "Defence manufacturer bags ₹2,000 crore order from MoD",
            "Listed engineering company wins ₹700 crore highway project",
            "Manufacturer secures a multi-year supply contract",
            "Company order book crosses ₹10,000 crore",
            "Balkrishna Industries shares rise on proposed 50:50 Pirelli JV",
            "GE Shipping to buy gas carrier as fleet expansion gathers pace",
            "Angel One rolls out US stock investing for investors",
            "Infosys announces Rs 26 per share dividend",
            "Ola Electric rights issue draws applications from investors",
            "UBS acquires a 4.8% stake in a listed wealth manager",
            "NCDEX forays into equity markets with launch of two new indices",
            "Persistent Systems launches QIP to raise capital",
            "HDFC Bank shares hover near a 52-week low ahead of CEO handover",
        ):
            with self.subTest(title=title):
                self.assertIsNone(news.classify_news_story(title))

        retained = {
            "Amagi Media shares slip after company flags cybersecurity threat": "stock_market",
            "eMudhra shares crash 20% to a 52-week low after govt orders security probe": "stock_market",
            "Stock Crash: Australian company shares tank 50% after flagging US fraud": "stock_market",
            "Small and midcap indices post worst weekly decline in two years": "capital_market",
            "Sensex plunges 8% in a market crash after an emergency decision": "capital_market",
            "China stocks sink deeper into bear market despite state buying": "stock_market",
        }
        for title, expected_topic in retained.items():
            with self.subTest(title=title):
                self.assertEqual(news.classify_news_story(title), expected_topic)

    def test_collapses_weekly_fii_summary_and_same_china_bear_market_event(self):
        fii_weekly = self.item(
            "FIIs pull out ₹2,697 crore this week; DIIs pump in nearly ₹11,000 crore",
            hours_ago=8,
        )
        fii_daily = self.item(
            "FIIs sell ₹3,459 crore of Indian stocks as market falls for third straight session",
            hours_ago=32,
        )
        other_fii_day = self.item(
            "FIIs sell ₹1,200 crore of Indian stocks on Friday",
            hours_ago=7,
        )
        china_older = self.item(
            "Chinese stock market in bear territory after 20% fall from June peak",
            hours_ago=32,
        )
        china_newer = self.item(
            "China stocks sink deeper into bear market despite state buying",
            hours_ago=8,
        )
        unrelated_bear_market = self.item(
            "Australian stocks enter bear territory after a 20% decline",
            hours_ago=7,
        )

        self.assertTrue(news._stories_are_duplicates(fii_weekly, fii_daily))
        self.assertFalse(news._stories_are_duplicates(fii_daily, other_fii_day))
        self.assertTrue(news._stories_are_duplicates(china_older, china_newer))
        self.assertFalse(news._stories_are_duplicates(china_newer, unrelated_bear_market))

    def test_deduplicates_same_ipo_phase_but_keeps_distinct_phase_and_issuer(self):
        day_two = self.item("Jio Platforms IPO Day 2 draws ₹3 lakh crore demand", hours_ago=40)
        day_three = self.item("Jio Platforms IPO Day 3 crosses 1 crore applications", hours_ago=10)
        liquidity_impact = self.item(
            "Jio Platforms IPO dents investor bandwidth for listed stocks",
            hours_ago=8,
        )
        other_issuer = self.item(
            "Tonbo Imaging shares debut at a premium over IPO price",
            hours_ago=9,
        )
        unrelated_issuer = self.item(
            "Fusion CX shares list at a premium over IPO price",
            hours_ago=9,
        )
        tonbo_first = self.item(
            "Tonbo Imaging shares make stellar market debut; jump 66%",
            hours_ago=12,
        )
        tonbo_second = self.item(
            "Tonbo Imaging shares make bumper debut, list at 66% premium over IPO price",
            hours_ago=10,
        )

        self.assertTrue(news._stories_are_duplicates(day_two, day_three))
        self.assertFalse(news._stories_are_duplicates(day_three, liquidity_impact))
        self.assertFalse(news._stories_are_duplicates(other_issuer, unrelated_issuer))
        self.assertTrue(news._stories_are_duplicates(tonbo_first, tonbo_second))

    def test_near_duplicate_news_collapses_but_separate_days_do_not(self):
        first = self.item("SEBI proposes automatic approval route for stock exchanges", hours_ago=2)
        second = self.item("SEBI proposes an automatic approval route for stock exchanges", hours_ago=1)
        old = self.item(
            "SEBI proposes automatic approval route for stock exchanges",
            hours_ago=100,
            url="https://www.cnbctv18.com/market/stocks/older-sebi-story.htm",
        )
        self.assertTrue(news._stories_are_duplicates(first, second))
        self.assertFalse(news._stories_are_duplicates(first, old))

    def test_merge_filters_and_deduplicates_without_resetting_queue_status(self):
        existing_item = self.item("Jio Platforms IPO Day 2 draws ₹3 lakh crore demand", hours_ago=30)
        existing = self.record(existing_item, status="queued", post_id="queued-news-id")
        results = self.record(
            self.item("Tata Motors Q2 profit rises 18%", hours_ago=20),
            status="new",
        )
        archive = {"stories": [existing, results]}
        feed_items = [
            self.item("Jio Platforms IPO Day 3 crosses 1 crore applications", hours_ago=5),
            self.item("RBI keeps repo rate unchanged as inflation eases", hours_ago=2),
            self.item("Sell these defence stocks, says Goldman Sachs", hours_ago=1),
            self.item("Defence manufacturer bags 2000 crore order from MoD", hours_ago=1),
        ]

        updated, added, changed_urls = news.merge_archive(
            archive,
            {
                "items": feed_items,
                "status": {"CNBC-TV18": {"fresh_items": 4, "filtered_items": 0}},
                "any_success": True,
            },
        )

        self.assertEqual(added, 1)
        self.assertEqual(len(updated["stories"]), 2)
        self.assertEqual(len({story["url"] for story in updated["stories"]}), 2)
        jio = next(story for story in updated["stories"] if "Jio Platforms IPO" in story["headline"])
        self.assertIn("Day 3", jio["headline"])
        self.assertEqual(jio["status"], "queued")
        self.assertEqual(jio["post_id"], "queued-news-id")
        self.assertIn(jio["url"], changed_urls)
        self.assertEqual(updated["last_run_stats"]["filtered_feed_items"], 2)
        self.assertEqual(updated["last_run_stats"]["duplicate_items_collapsed"], 1)
        self.assertEqual(updated["last_run_stats"]["archive_items_removed_by_curation"], 1)


if __name__ == "__main__":
    unittest.main()
