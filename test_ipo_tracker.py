#!/usr/bin/env python3
"""
UNIT TESTS FOR MAINBOARD IPO TRACKER
====================================
Tests scrapers, parsers, SME filters, formatters, and lifecycle dispatch engine.
"""

import unittest
from unittest.mock import MagicMock, patch
from datetime import datetime

from ipo_scrapers import (
    clean_company_name,
    sanitize_slug,
    parse_indian_date,
    is_sme_ipo,
    get_registrar_url,
    ChittorgarhScraper,
    InvestorGainScraper,
    IpoAggregator,
)
from ipo_formatter import (
    format_new_ipo_alert,
    format_opens_today_alert,
    format_closing_today_alert,
    format_allotment_out_alert,
    format_listing_today_alert,
    format_gmp_dashboard,
    format_ipo_post,
)
from ipo_tracker import evaluate_ipo_events, load_master, save_master


class TestIpoScraperHelpers(unittest.TestCase):
    def test_clean_company_name(self):
        self.assertEqual(clean_company_name("NTPC Green Energy Ltd IPO"), "NTPC Green Energy Ltd")
        self.assertEqual(clean_company_name("Swiggy Limited (Mainboard)"), "Swiggy Limited")
        self.assertEqual(clean_company_name("Waaree Energies IPO (BSE/NSE)"), "Waaree Energies")

    def test_sanitize_slug(self):
        self.assertEqual(sanitize_slug("NTPC Green Energy Limited"), "ntpc-green-energy")
        self.assertEqual(sanitize_slug("Swiggy Ltd IPO"), "swiggy")
        self.assertEqual(sanitize_slug("ACME Solar Holdings Pvt Ltd"), "acme-solar-holdings")

    def test_parse_indian_date(self):
        self.assertEqual(parse_indian_date("20-Nov-2024"), "2024-11-20")
        self.assertEqual(parse_indian_date("Nov 20, 2024"), "2024-11-20")
        self.assertEqual(parse_indian_date("20/11/2024"), "2024-11-20")
        self.assertEqual(parse_indian_date("2024-11-20"), "2024-11-20")
        self.assertIsNone(parse_indian_date(""))
        self.assertIsNone(parse_indian_date(None))

    def test_sme_filtering(self):
        # Mainboard IPO: Retail ticket size ~Rs 14k, normal lot size
        self.assertFalse(is_sme_ipo("NTPC Green Energy Limited", lot_size=138, min_investment=14904))
        self.assertFalse(is_sme_ipo("Swiggy Limited", lot_size=38, min_investment=14820))

        # SME IPO: Marked in title or high ticket size
        self.assertTrue(is_sme_ipo("Tech Innovations SME IPO", lot_size=1000, min_investment=120000))
        self.assertTrue(is_sme_ipo("Fintech Ventures (BSE SME)", lot_size=1200, min_investment=140000))
        self.assertTrue(is_sme_ipo("Random Corp", lot_size=2000, min_investment=150000))
        self.assertTrue(is_sme_ipo("Alpha Ltd", category="NSE Emerge"))

    def test_registrar_links(self):
        self.assertIn("linkintime.co.in", get_registrar_url("Link Intime India Private Ltd"))
        self.assertIn("kfintech.com", get_registrar_url("KFin Technologies Limited"))
        self.assertIn("bigshareonline.com", get_registrar_url("Bigshare Services Pvt Ltd"))
        self.assertIn("bseindia.com", get_registrar_url("Unknown Registrar"))


class TestHtmlParsing(unittest.TestCase):
    def test_chittorgarh_mock_parsing(self):
        mock_html = """
        <html>
            <body>
                <table id="report_table">
                    <thead>
                        <tr>
                            <th>Issuer Company</th>
                            <th>Open</th>
                            <th>Close</th>
                            <th>Listing Date</th>
                            <th>Issue Price (Rs)</th>
                            <th>Issue Amount (Rs Cr)</th>
                            <th>Listing Price (Rs)</th>
                            <th>Listing Gain (%)</th>
                        </tr>
                    </thead>
                    <tbody>
                        <tr>
                            <td><a href="/ipo/ntpc-green-energy-ipo/1785/">NTPC Green Energy Limited IPO</a></td>
                            <td>19-Nov-2024</td>
                            <td>22-Nov-2024</td>
                            <td>27-Nov-2024</td>
                            <td>102 - 108</td>
                            <td>10,000</td>
                            <td>116</td>
                            <td>+7.41%</td>
                        </tr>
                        <tr>
                            <td><a href="/ipo/sme-sample/123/">Sample SME IPO</a></td>
                            <td>19-Nov-2024</td>
                            <td>22-Nov-2024</td>
                            <td>27-Nov-2024</td>
                            <td>100</td>
                            <td>20</td>
                            <td>110</td>
                            <td>+10%</td>
                        </tr>
                    </tbody>
                </table>
            </body>
        </html>
        """
        mock_session = MagicMock()
        mock_resp = MagicMock()
        mock_resp.status_code = 200
        mock_resp.text = mock_html
        mock_session.get.return_value = mock_resp

        scraper = ChittorgarhScraper(mock_session)
        items = scraper.fetch_mainboard_ipos()

        # Should extract NTPC Green Energy and filter out Sample SME IPO
        self.assertEqual(len(items), 1)
        self.assertEqual(items[0]["company_name"], "NTPC Green Energy Limited")
        self.assertEqual(items[0]["open_date"], "2024-11-19")
        self.assertEqual(items[0]["close_date"], "2024-11-22")
        self.assertEqual(items[0]["listing_date"], "2024-11-27")
        self.assertEqual(items[0]["price_band"], "102 - 108")
        self.assertEqual(items[0]["issue_size_cr"], "10,000")

    def test_investorgain_mock_parsing(self):
        mock_html = """
        <html>
            <body>
                <table>
                    <thead>
                        <tr>
                            <th>IPO Name</th>
                            <th>GMP (₹)</th>
                            <th>Est Listing</th>
                            <th>IPO Price</th>
                            <th>IPO Date</th>
                            <th>Lot Size</th>
                        </tr>
                    </thead>
                    <tbody>
                        <tr>
                            <td>NTPC Green Energy IPO</td>
                            <td>₹8 (7.4%)</td>
                            <td>₹116</td>
                            <td>₹108</td>
                            <td>19-Nov to 22-Nov</td>
                            <td>138</td>
                        </tr>
                    </tbody>
                </table>
            </body>
        </html>
        """
        mock_session = MagicMock()
        mock_resp = MagicMock()
        mock_resp.status_code = 200
        mock_resp.text = mock_html
        mock_session.get.return_value = mock_resp

        scraper = InvestorGainScraper(mock_session)
        items = scraper.fetch_live_gmp()

        self.assertEqual(len(items), 1)
        self.assertEqual(items[0]["company_name"], "NTPC Green Energy")
        self.assertEqual(items[0]["gmp"], "₹8 (7.4%)")
        self.assertEqual(items[0]["gmp_percent"], "7.4%")
        self.assertEqual(items[0]["lot_size"], 138)
        current_year = datetime.now().year
        self.assertEqual(items[0]["open_date"], f"{current_year}-11-19")
        self.assertEqual(items[0]["close_date"], f"{current_year}-11-22")


class TestIpoFormatters(unittest.TestCase):
    def setUp(self):
        self.sample_ipo = {
            "id": "ntpc-green-energy",
            "company_name": "NTPC Green Energy Limited",
            "symbol": "NTPCGREEN",
            "open_date": "2024-11-19",
            "close_date": "2024-11-22",
            "allotment_date": "2024-11-25",
            "listing_date": "2024-11-27",
            "price_band": "₹102 to ₹108",
            "cut_off_price": 108,
            "lot_size": 138,
            "min_investment": 14904,
            "issue_size_cr": "10,000",
            "fresh_issue_cr": "10,000",
            "ofs_cr": "0",
            "gmp": "8",
            "gmp_percent": "+7.41%",
            "est_listing_price": "₹116.00",
            "listing_price": "₹116.00",
            "listing_gain": "+7.41%",
            "subscription": {
                "qib": "3.28x",
                "nii": "1.82x",
                "retail": "1.44x",
                "total": "2.42x",
            },
            "registrar": {
                "name": "KFin Technologies Limited",
                "url": "https://kosmic.kfintech.com/ipostatus/",
            },
            "about": "India's premier renewable energy enterprise.",
        }

    def test_new_ipo_alert(self):
        msg = format_new_ipo_alert(self.sample_ipo)
        self.assertIn("NEW MAINBOARD IPO ANNOUNCED", msg)
        self.assertIn("NTPC Green Energy Limited", msg)
        self.assertIn("@ipocentral", msg)
        self.assertIn("₹102 to ₹108", msg)
        self.assertIn("138 Shares", msg)
        self.assertIn("₹14,904", msg)
        self.assertIn("KFin Technologies Limited", msg)
        self.assertLess(len(msg), 4000)

    def test_opens_today_alert(self):
        msg = format_opens_today_alert(self.sample_ipo)
        self.assertIn("IPO OPENS TODAY", msg)
        self.assertIn("Bidding Window", msg)
        self.assertIn("@ipocentral", msg)
        self.assertLess(len(msg), 4000)

    def test_closing_today_alert(self):
        msg = format_closing_today_alert(self.sample_ipo)
        self.assertIn("IPO CLOSING TODAY", msg)
        self.assertIn("2.42x", msg)
        self.assertIn("5:00 PM IST", msg)
        self.assertIn("@ipocentral", msg)
        self.assertLess(len(msg), 4000)

    def test_allotment_out_alert(self):
        msg = format_allotment_out_alert(self.sample_ipo)
        self.assertIn("IPO ALLOTMENT OUT", msg)
        self.assertIn("https://kosmic.kfintech.com/ipostatus/", msg)
        self.assertIn("bseindia.com", msg)
        self.assertIn("@ipocentral", msg)
        self.assertLess(len(msg), 4000)

    def test_listing_today_alert(self):
        msg = format_listing_today_alert(self.sample_ipo)
        self.assertIn("IPO LISTING TODAY", msg)
        self.assertIn("NTPCGREEN", msg)
        self.assertIn("₹116.00", msg)
        self.assertIn("@ipocentral", msg)
        self.assertLess(len(msg), 4000)

    def test_gmp_dashboard(self):
        msg = format_gmp_dashboard([self.sample_ipo], as_of_date="19-Nov-2024")
        self.assertIn("MAINBOARD IPO: LATEST GMP", msg)
        self.assertIn("NTPC Green Energy Limited", msg)
        self.assertIn("₹8 (+7.41%)", msg)
        self.assertIn("@ipocentral", msg)
        self.assertLess(len(msg), 4000)

    def test_dispatcher(self):
        self.assertIsNotNone(format_ipo_post("NEW_IPO_ANNOUNCED", self.sample_ipo))
        self.assertIsNotNone(format_ipo_post("IPO_OPENS_TODAY", self.sample_ipo))
        self.assertIsNotNone(format_ipo_post("IPO_CLOSING_TODAY", self.sample_ipo))
        self.assertIsNotNone(format_ipo_post("ALLOTMENT_OUT", self.sample_ipo))
        self.assertIsNotNone(format_ipo_post("LISTING_TODAY", self.sample_ipo))
        self.assertIsNone(format_ipo_post("UNKNOWN_EVENT", self.sample_ipo))


class TestLifecycleEngine(unittest.TestCase):
    def test_evaluate_lifecycle_events(self):
        sample = {
            "id": "test-ipo",
            "company_name": "Test Company Limited",
            "open_date": "2024-11-20",
            "close_date": "2024-11-22",
            "allotment_date": "2024-11-25",
            "listing_date": "2024-11-27",
            "allotment_out": False,
        }

        # 1. On announcement date (before open)
        events = evaluate_ipo_events(sample, today_str="2024-11-15", posted_events_set=set())
        event_types = [e[0] for e in events]
        self.assertIn("NEW_IPO_ANNOUNCED", event_types)

        # 2. On opening date
        events = evaluate_ipo_events(sample, today_str="2024-11-20", posted_events_set={"ipo:test-ipo:announced"})
        event_types = [e[0] for e in events]
        self.assertIn("IPO_OPENS_TODAY", event_types)

        # 3. On closing date
        events = evaluate_ipo_events(sample, today_str="2024-11-22", posted_events_set={"ipo:test-ipo:announced", "ipo:test-ipo:opens_today"})
        event_types = [e[0] for e in events]
        self.assertIn("IPO_CLOSING_TODAY", event_types)

        # 4. On allotment date
        events = evaluate_ipo_events(sample, today_str="2024-11-25", posted_events_set={"ipo:test-ipo:announced", "ipo:test-ipo:opens_today", "ipo:test-ipo:closing_today"})
        event_types = [e[0] for e in events]
        self.assertIn("ALLOTMENT_OUT", event_types)

        # 5. On listing date
        events = evaluate_ipo_events(sample, today_str="2024-11-27", posted_events_set={"ipo:test-ipo:announced", "ipo:test-ipo:opens_today", "ipo:test-ipo:closing_today", "ipo:test-ipo:allotment_out"})
        event_types = [e[0] for e in events]
        self.assertIn("LISTING_TODAY", event_types)

        # 6. Deduplication: If all posted, no new events
        all_posted = {
            "ipo:test-ipo:announced",
            "ipo:test-ipo:opens_today",
            "ipo:test-ipo:closing_today",
            "ipo:test-ipo:allotment_out",
            "ipo:test-ipo:listing_today",
        }
        events = evaluate_ipo_events(sample, today_str="2024-11-27", posted_events_set=all_posted)
        self.assertEqual(len(events), 0)


    def test_aggregator_merging(self):
        aggregator = IpoAggregator()
        aggregator.chittorgarh.fetch_mainboard_ipos = MagicMock(return_value=[
            {
                "source": "chittorgarh",
                "company_name": "Test Energy Limited",
                "open_date": "2024-11-20",
                "close_date": "2024-11-22",
                "price_band": "₹100 to ₹105",
                "issue_size_cr": "1,500",
            }
        ])
        aggregator.investorgain.fetch_live_gmp = MagicMock(return_value=[
            {
                "source": "investorgain",
                "company_name": "Test Energy Limited",
                "gmp": "₹15",
                "gmp_percent": "+14.28%",
                "lot_size": 140,
            }
        ])
        aggregator.nse.fetch_nse_ipos = MagicMock(return_value=[
            {
                "source": "nse",
                "company_name": "Test Energy Limited",
                "symbol": "TESTENERGY",
            }
        ])

        merged = aggregator.collect_all_mainboard_ipos()
        self.assertEqual(len(merged), 1)
        ipo = merged[0]
        self.assertEqual(ipo["company_name"], "Test Energy Limited")
        self.assertEqual(ipo["symbol"], "TESTENERGY")
        self.assertEqual(ipo["open_date"], "2024-11-20")
        self.assertEqual(ipo["close_date"], "2024-11-22")
        self.assertEqual(ipo["gmp"], "₹15")
        self.assertEqual(ipo["lot_size"], 140)
        self.assertEqual(ipo["cut_off_price"], 105)
        self.assertEqual(ipo["min_investment"], 14700)  # 105 * 140


if __name__ == "__main__":
    unittest.main()
