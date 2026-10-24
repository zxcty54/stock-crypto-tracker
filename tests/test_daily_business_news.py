import importlib.util
import json
import sys
import tempfile
import types
import unittest
from datetime import datetime, timedelta, timezone
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

    def archive_insight_candidate(self, story_id="story_1"):
        context = (
            "The central bank kept its policy rate unchanged while the latest official commentary "
            "described easing inflation pressure. The decision leaves the policy stance steady, but "
            "does not guarantee cheaper borrowing or a change in any listed company's earnings. "
            "Future inflation readings, policy communication and credit conditions will help show "
            "whether the balance between price stability and economic activity is changing. "
        ) * 3
        return {
            "story_id": story_id,
            "headline": "RBI keeps repo rate unchanged as inflation eases",
            "rss_summary": "Official policy update on rates and inflation.",
            "reported_context": context,
        }

    def good_archive_insight(self, story_id="story_1"):
        return {
            "story_id": story_id,
            "why_it_matters": (
                "Repo rate ko stable rakhna policy stance mein continuity dikhata hai; source ke "
                "mutabik inflation eases, isliye decision ko price stability aur growth ke balance "
                "ke lens se samajhna useful hai. Isse kisi company ki borrowing cost ya earnings "
                "automatically badalne ka proof nahi milta."
            ),
            "what_to_watch": [
                "Aage ke RBI policy communication mein inflation aur growth ke balance par diya gaya rationale dekho.",
                "Official inflation readings aur credit conditions se check karo ki easing broad-based rehti hai ya nahi.",
            ],
            "evergreen_lesson": (
                "Policy headlines ko ek single decision se nahi, inflation trend, growth conditions "
                "aur baad ke implementation evidence ke saath compare karo."
            ),
        }

    def test_checked_in_archive_has_no_ipo_or_fii_dii_stories(self):
        archive = json.loads((ROOT / "business_news_archive.json").read_text(encoding="utf-8"))
        curated, removed, duplicates = news._curate_archive_stories(archive["stories"])

        self.assertEqual(removed, 0)
        self.assertEqual(duplicates, 0)
        self.assertEqual(len(curated), len(archive["stories"]))
        self.assertEqual(archive["curation"]["version"], 8)
        self.assertIn("ipo_and_fpo_related_news", archive["curation"]["excludes"])
        self.assertIn("fii_fpi_dii_related_news", archive["curation"]["excludes"])
        self.assertIn("stock_portfolio_and_wealth_listicles", archive["curation"]["excludes"])
        for story in archive["stories"]:
            with self.subTest(title=story["headline"]):
                self.assertFalse(news._is_ipo_related_headline(story["headline"]))
                self.assertFalse(news._is_fii_dii_related_headline(story["headline"]))
                self.assertFalse(news._is_stock_portfolio_listicle_headline(story["headline"]))

    def test_archive_ai_enrichment_adds_durable_notes_once(self):
        source_context = self.archive_insight_candidate()["reported_context"]
        item = self.item(
            "RBI keeps repo rate unchanged as inflation eases",
            summary="Official policy update on rates and inflation.",
        )
        record = self.record(item)
        archive = {"stories": [record]}
        calls = []

        def ai_caller(prompt):
            calls.append(prompt)
            self.assertIn("evergreen_lesson", prompt)
            self.assertIn("RBI keeps repo rate unchanged", prompt)
            return json.dumps({"insights": [self.good_archive_insight(news._alpha_id(item["url"]))]})

        stats = news.enrich_archive_stories(
            archive,
            article_fetcher=lambda _url: source_context,
            ai_caller=ai_caller,
        )

        self.assertEqual(stats["enriched"], 1)
        self.assertEqual(stats["batches"], 1)
        self.assertEqual(len(calls), 1)
        self.assertEqual(record["ai_insight"]["version"], news.ARCHIVE_AI_INSIGHT_VERSION)
        self.assertEqual(record["ai_insight"]["context_source"], "publisher article page")
        self.assertTrue(news._has_current_archive_insight(record["ai_insight"]))

        second_run = news.enrich_archive_stories(
            archive,
            article_fetcher=lambda _url: self.fail("current insights should not refetch source pages"),
            ai_caller=lambda _prompt: self.fail("current insights should not call AI again"),
        )
        self.assertEqual(second_run["pending_stories"], 0)

    def test_archive_ai_validation_rejects_unsupported_numbers_and_trading_calls(self):
        candidate = self.archive_insight_candidate()
        unsupported_number = self.good_archive_insight()
        unsupported_number["why_it_matters"] += " Inflation fell by 20%."
        direct_call = self.good_archive_insight()
        direct_call["what_to_watch"][0] = "Buy this stock now because the policy stance is supportive."

        self.assertEqual(
            news.validate_archive_insights({"insights": [unsupported_number]}, [candidate]),
            {},
        )
        self.assertEqual(
            news.validate_archive_insights({"insights": [direct_call]}, [candidate]),
            {},
        )
        self.assertEqual(
            len(news.validate_archive_insights({"insights": [self.good_archive_insight()]}, [candidate])),
            1,
        )

    def test_manual_archive_enrichment_does_not_fetch_rss(self):
        archive = {"stories": []}
        stats = {
            "enriched": 0,
            "insufficient_context": 0,
            "not_added": 0,
            "deferred_stories": 0,
        }
        with (
            patch.object(news, "load_json", return_value=archive),
            patch.object(news, "enrich_archive_stories", return_value=stats),
            patch.object(news, "fetch_feeds", side_effect=AssertionError("enrich mode must not scrape")) as fetch,
        ):
            self.assertEqual(news.run_archive_enrichment_only(), 0)
        fetch.assert_not_called()

    def test_archive_record_refresh_invalidates_stale_ai_insight(self):
        item = self.item("RBI keeps repo rate unchanged as inflation eases")
        record = self.record(item)
        record["ai_insight"] = {
            "version": news.ARCHIVE_AI_INSIGHT_VERSION,
            "why_it_matters": "Previously generated note with enough detail to be considered current.",
            "what_to_watch": ["One follow-up signal to inspect.", "Another follow-up signal to inspect."],
            "evergreen_lesson": "A reusable lesson grounded in the earlier article details.",
        }
        refreshed = dict(item)
        refreshed["published"] = item["published"] + timedelta(minutes=5)
        refreshed["summary"] = "Updated source summary with material new details."

        self.assertTrue(news._refresh_archive_record(record, refreshed, "economy"))
        self.assertNotIn("ai_insight", record)

    def test_accepts_economy_capital_markets_and_stock_events(self):
        self.assertEqual(
            news.classify_news_story("RBI keeps repo rate unchanged as inflation eases"),
            "economy",
        )
        self.assertIsNone(news.classify_news_story("SEBI approves new IPO norms for NSE"))
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

    def test_official_regulator_feed_context_keeps_orders_and_preserves_exclusions(self):
        sebi_source = "SEBI RSS"
        self.assertEqual(
            news.classify_news_story(
                "Order in the matter of Avadhut Sathe Trading Academy Private Limited",
                source_name=sebi_source,
            ),
            "capital_market",
        )
        self.assertEqual(
            news.classify_news_story(
                "Review of regulatory requirement for maintenance of call records of institutional clients by Research Analysts",
                source_name=sebi_source,
            ),
            "capital_market",
        )
        self.assertEqual(
            news.classify_news_story(
                "Auction of State Government Securities",
                source_name="RBI Press Releases",
            ),
            "capital_market",
        )
        self.assertEqual(
            news.classify_news_story(
                "Order in the matter of a cooperative bank",
                source_name="RBI Notifications",
            ),
            "economy",
        )
        self.assertEqual(
            news.classify_news_story("Supreme Court orders a company to refund investors"),
            "capital_market",
        )
        self.assertEqual(
            news.classify_news_story("Government orders banks to submit new lending data"),
            "economy",
        )
        self.assertEqual(
            news.classify_news_story(
                "CCI orders a company to pay a penalty for competition violations"
            ),
            "capital_market",
        )
        for title, source in (
            ("SEBI approves new IPO norms for NSE", sebi_source),
            ("Foreign institutional investors increase selling in Indian markets", sebi_source),
            ("Highway Infrastructure wins ₹340 crore NHAI contract", sebi_source),
            ("SEBI teams win at IOSCO TechSprint on investor education", sebi_source),
            ("Research analysts recommend these stocks as a buy", sebi_source),
            ("Tata Motors Q2 profit rises 18%", "RBI Press Releases"),
        ):
            with self.subTest(title=title, source=source):
                self.assertIsNone(news.classify_news_story(title, source_name=source))

    def test_official_regulator_rss_dates_are_parsed_in_ist(self):
        rbi_source = next(feed for feed in news.FEEDS if feed["name"] == "RBI Press Releases")
        rbi_xml = b"""<rss><channel><item>
            <title>Auction of State Government Securities</title>
            <link>https://rbi.org.in/markets/state-security-auction.htm</link>
            <pubDate>Fri, 23 Oct 2026 17:10:00</pubDate>
        </item></channel></rss>"""
        rbi_items = news.parse_rss(rbi_xml, rbi_source)
        self.assertEqual(len(rbi_items), 1)
        self.assertEqual(
            rbi_items[0]["published"],
            datetime(2026, 10, 23, 17, 10, tzinfo=news.IST),
        )

        sebi_source = next(feed for feed in news.FEEDS if feed["name"] == "SEBI RSS")
        sebi_xml = b"""<rss><channel>
        <item>
            <title>Order in the matter of a market participant</title>
            <link>https://www.sebi.gov.in/enforcement/orders/test-order.html</link>
            <pubDate>23 Oct, 2026 +0530</pubDate>
        </item>
        <item>
            <title>SEBI issues a new market circular</title>
            <link>https://www.sebi.gov.in/legal/circulars/test-circular.html</link>
            <pubDate>24 Oct 2026 14:00:02</pubDate>
        </item>
        </channel></rss>"""
        sebi_items = news.parse_rss(sebi_xml, sebi_source)
        self.assertEqual(len(sebi_items), 2)
        self.assertEqual(
            sebi_items[0]["published"],
            datetime(2026, 10, 23, 0, 0, tzinfo=news.IST),
        )
        self.assertEqual(
            sebi_items[1]["published"],
            datetime(2026, 10, 24, 14, 0, 2, tzinfo=news.IST),
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
                <item><title>Jio Platforms IPO opens with a price band of ₹1,200 to ₹1,300</title>
                    <link>https://{host}/markets/jio-ipo-test.html</link>
                    <pubDate>{pub_date}</pubDate>
                    <description>Initial public offering opens for subscription.</description></item>
                <item><title>FIIs sell ₹3,459 crore of Indian stocks as market falls</title>
                    <link>https://{host}/markets/fii-selling-test.html</link>
                    <pubDate>{pub_date}</pubDate>
                    <description>Foreign institutional flows were negative.</description></item>
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
            self.assertEqual(status["fresh_items"], 5)
            self.assertEqual(status["accepted_items"], 1)
            self.assertEqual(status["filtered_items"], 4)

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

    def test_excludes_all_ipo_fpo_and_fii_dii_related_headlines(self):
        excluded = (
            "Jio Platforms IPO opens with a price band of ₹1,200 to ₹1,300",
            "Paras Healthcare IPO fully subscribed on day 3",
            "Tonbo Imaging shares make stellar market debut; jump 66%",
            "Fusion CX shares list at 5.5% premium over IPO price on NSE",
            "Zetwerk rises over 5% in trading debut after $518 million IPO",
            "Company files DRHP with SEBI for proposed public issue",
            "New company shares debuted at a premium on the NSE",
            "SEBI approves new IPO norms for NSE",
            "Solidigm suspends review of US IPO, citing market volatility",
            "FIIs pull out ₹2,697 crore this week; DIIs pump in nearly ₹11,000 crore",
            "FPI investors sell Indian equities for a third straight session",
            "Foreign institutional investors increase selling in Indian markets",
            "Domestic institutions pump ₹11,000 crore into Indian stocks",
            "Foreign funds trim their Indian equity exposure",
            "Domestic funds pour money into Indian shares",
            "Mutual funds post record inflows into Indian equities",
            "Institutional investors record strong inflows into equities",
        )
        for title in excluded:
            with self.subTest(title=title):
                self.assertIsNone(news.classify_news_story(title))

        # Foreign direct investment is not the same as FII/FPI market flows.
        self.assertFalse(
            news._is_fii_dii_related_headline("Foreign direct investment inflows hit a record in August")
        )

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

    def test_excludes_stock_portfolio_and_wealth_loss_listicles(self):
        excluded = (
            "Portfolio Killers: 10 US stocks that wiped out up to 66% of investors’ wealth in 2026",
            "Radhakishan Damani portfolio: Top 10 stock holdings of the ace investor",
            "Top 10 stocks in Mukesh Ambani’s portfolio",
            "Portfolio holdings: 5 shares held by a famous investor",
            "Stocks that wiped out investors’ wealth this year",
        )
        for title in excluded:
            with self.subTest(title=title):
                self.assertTrue(news._is_stock_portfolio_listicle_headline(title))
                self.assertIsNone(news.classify_news_story(title))

        # Market or policy reporting that merely mentions a portfolio remains eligible.
        self.assertEqual(
            news.classify_news_story("RBI tightens portfolio concentration rules for banks"),
            "economy",
        )
        self.assertFalse(
            news._is_stock_portfolio_listicle_headline(
                "Share holdings at banks shift in new ownership data"
            )
        )

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

    def test_deduplicates_same_china_bear_market_event_but_not_other_markets(self):
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

        self.assertTrue(news._stories_are_duplicates(china_older, china_newer))
        self.assertFalse(news._stories_are_duplicates(china_newer, unrelated_bear_market))

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
        existing_item = self.item(
            "SEBI proposes automatic approval route for stock exchanges",
            hours_ago=30,
        )
        existing = self.record(existing_item, status="queued", post_id="queued-news-id")
        results = self.record(
            self.item("Tata Motors Q2 profit rises 18%", hours_ago=20),
            status="new",
        )
        archive = {"stories": [existing, results]}
        feed_items = [
            self.item("SEBI proposes an automatic approval route for stock exchanges", hours_ago=5),
            self.item("RBI keeps repo rate unchanged as inflation eases", hours_ago=2),
            self.item("Sell these defence stocks, says Goldman Sachs", hours_ago=1),
            self.item("Defence manufacturer bags 2000 crore order from MoD", hours_ago=1),
            self.item("Jio Platforms IPO opens with a price band of ₹1,200 to ₹1,300", hours_ago=1),
            self.item("FIIs sell ₹3,459 crore of Indian stocks as market falls", hours_ago=1),
        ]

        updated, added, changed_urls = news.merge_archive(
            archive,
            {
                "items": feed_items,
                "status": {"CNBC-TV18": {"fresh_items": 6, "filtered_items": 0}},
                "any_success": True,
            },
        )

        self.assertEqual(added, 1)
        self.assertEqual(len(updated["stories"]), 2)
        self.assertEqual(len({story["url"] for story in updated["stories"]}), 2)
        sebi = next(story for story in updated["stories"] if "SEBI proposes" in story["headline"])
        self.assertIn("automatic approval route", sebi["headline"])
        self.assertEqual(sebi["status"], "queued")
        self.assertEqual(sebi["post_id"], "queued-news-id")
        self.assertIn(sebi["url"], changed_urls)
        self.assertEqual(updated["last_run_stats"]["filtered_feed_items"], 4)
        self.assertEqual(updated["last_run_stats"]["duplicate_items_collapsed"], 1)
        self.assertEqual(updated["last_run_stats"]["archive_items_removed_by_curation"], 1)

    def test_merge_archive_retains_sebi_regulatory_order_from_official_feed(self):
        item = self.item(
            "Order in the matter of Avadhut Sathe Trading Academy Private Limited",
            source="SEBI RSS",
            priority=3,
            url="https://www.sebi.gov.in/enforcement/orders/official-order.html",
        )
        updated, added, _changed_urls = news.merge_archive(
            {"stories": []},
            {
                "items": [item],
                "status": {"SEBI RSS": {"fresh_items": 1, "filtered_items": 0}},
                "any_success": True,
            },
        )

        self.assertEqual(added, 1)
        self.assertEqual(len(updated["stories"]), 1)
        self.assertEqual(updated["stories"][0]["source"], "SEBI RSS")
        self.assertEqual(
            updated["stories"][0]["headline"],
            "Order in the matter of Avadhut Sathe Trading Academy Private Limited",
        )
        self.assertEqual(updated["stories"][0]["topic"], "capital_market")

    def test_daily_archive_run_enqueues_a_formatted_news_post(self):
        fixed_now = datetime(2026, 10, 24, 18, 30, tzinfo=news.IST)
        story = self.item(
            "RBI keeps repo rate unchanged as inflation eases",
            hours_ago=1,
            summary="The central bank kept its policy rate unchanged while inflation pressure eased.",
        )
        story["published"] = fixed_now - timedelta(hours=1)
        body = (
            "📰 Kya hua: RBI ne repo rate ko unchanged rakha, jabki official update mein inflation "
            "pressure kam hone ki baat kahi gayi. 🧩 News ko kaise padhein: rate ka decision policy "
            "stance batata hai; yeh apne aap loan rates ya kisi company ke results mein turant badlav "
            "ka proof nahi hai. 💡 Business mein iska matlab: borrowing conditions par asar tab samajh "
            "aayega jab banks ke lending rates aur credit demand mein actual movement dikhe. Isliye "
            "headline ko policy signal samjhein, guaranteed business outcome nahi. 🔭 Aage kya dekhein: "
            "agla official inflation data, RBI ka communication, bank lending rates aur credit growth "
            "track karein. Agar inflation pressure kam rehta hai, policy debate badal sakti hai; agar "
            "wapas badhta hai, rate stance lamba samay steady reh sakta hai. Aap is decision ko kis "
            "signal ke saath compare karenge?"
        )
        body += " Policy ko samajhne ke liye ek update ke bajay data aur baad ke decisions ka trend dekhein."
        ai_response = json.dumps({
            "skip": False,
            "selected_story_id": "story_1",
            "headline": "RBI holds repo rate as inflation pressure eases",
            "body": body,
        })

        with tempfile.TemporaryDirectory() as directory:
            archive_path = Path(directory) / "business_news_archive.json"
            queue_path = Path(directory) / "content_queue.json"
            state_path = Path(directory) / "daily_news_state.json"
            archive_path.write_text(json.dumps({
                "stories": [],
                "last_scraped_at": (fixed_now - timedelta(hours=3)).isoformat(),
            }), encoding="utf-8")
            queue_path.write_text(json.dumps({"queue": []}), encoding="utf-8")

            def fake_ai(prompt):
                self.assertIn("company/commercial order or contract wins", prompt)
                self.assertIn("FII/FPI/DII/institutional-flow stories", prompt)
                self.assertIn("Regulator, government, and court orders remain eligible", prompt)
                return ai_response

            with (
                patch.object(news, "NOW", fixed_now),
                patch.object(news, "ARCHIVE_FILE", str(archive_path)),
                patch.object(news, "QUEUE_FILE", str(queue_path)),
                patch.object(news, "STATE_FILE", str(state_path)),
                patch.object(news, "GEMINI_KEYS", ("test-key",)),
                patch.object(news, "GROQ_KEYS", ()),
                patch.object(news, "fetch_feeds", return_value={
                    "items": [story],
                    "status": {"CNBC-TV18": {"fresh_items": 1, "filtered_items": 0}},
                    "any_success": True,
                }),
                patch.object(news, "enrich_archive_stories", return_value={
                    "enriched": 0,
                    "insufficient_context": 0,
                    "not_added": 0,
                    "deferred_stories": 0,
                }),
                patch.object(news, "fetch_article_context", return_value=(
                    "The RBI policy statement describes the rate decision and its reasoning, "
                    "while noting inflation conditions and the balance with economic activity. "
                ) * 8),
                patch.object(news, "call_ai", side_effect=fake_ai),
            ):
                result = news.run_archive_and_queue()

            self.assertEqual(result, 0)
            queue = json.loads(queue_path.read_text(encoding="utf-8"))
            self.assertEqual(len(queue["queue"]), 1)
            item = queue["queue"][0]
            self.assertEqual(item["kind"], "business_news_insight")
            self.assertEqual(item["slot"], "C")
            self.assertEqual(item["scheduled_ist"], "2026-10-24 20:30")
            self.assertFalse(item["used"])
            self.assertIn("📊 <b>RBI holds repo rate", item["text"])
            self.assertIn("🔗 Source: <a href=", item["text"])
            self.assertIn("AI-assisted analysis of public business news", item["text"])
            self.assertIn("Educational only. Not investment advice.", item["text"])
            archive = json.loads(archive_path.read_text(encoding="utf-8"))
            self.assertEqual(archive["stories"][0]["status"], "queued")
            state = json.loads(state_path.read_text(encoding="utf-8"))
            self.assertEqual(state["generated_slots"], ["2026-10-24 18"])

    def test_business_post_queueing_obeys_existing_posting_window(self):
        queue = {"queue": []}
        state = {"generated_slots": [], "seen_story_keys": [], "seen_story_titles": []}
        midday = datetime(2026, 10, 24, 12, 0, tzinfo=news.IST)
        with patch.object(news, "NOW", midday), patch.object(
            news, "call_ai", side_effect=AssertionError("must not call AI outside the window")
        ):
            self.assertEqual(
                news._queue_business_news_post({}, queue, state, None, set()),
                (False, False),
            )


if __name__ == "__main__":
    unittest.main()
