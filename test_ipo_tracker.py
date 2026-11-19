#!/usr/bin/env python3
"""
UNIT TESTS FOR MAINBOARD IPO TRACKER (ENHANCED)
===============================================
Tests scrapers, parsers, SME filters, DRHP detail extractor, formatters, and lifecycle engine.
"""

import unittest
from unittest.mock import MagicMock
from datetime import datetime

from ipo_scrapers import (
    clean_company_name,
    sanitize_slug,
    sanitize_gmp,
    parse_indian_date,
    is_sme_ipo,
    is_already_listed,
    get_registrar_url,
    ChittorgarhScraper,
    IpoCentralGmpScraper,
    ChittorgarhGmpScraper,
    DrhpDetailParser,
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
from ipo_tracker import evaluate_ipo_events


class TestIpoScraperHelpers(unittest.TestCase):
    def test_clean_company_name(self):
        self.assertEqual(clean_company_name("NTPC Green Energy Ltd IPO"), "NTPC Green Energy Ltd")
        self.assertEqual(clean_company_name("Swiggy Limited (Mainboard)"), "Swiggy Limited")
        self.assertEqual(clean_company_name("ZetwerkIPO[email protected](5.46%)"), "Zetwerk")
        self.assertEqual(clean_company_name("Mahanadi CoalfieldsIPOU"), "Mahanadi Coalfields")
        self.assertEqual(clean_company_name("Crystal Crop ProtectionIPOO"), "Crystal Crop Protection")

    def test_sanitize_slug(self):
        self.assertEqual(sanitize_slug("NTPC Green Energy Limited"), "ntpc-green-energy")
        self.assertEqual(sanitize_slug("Swiggy Ltd IPO"), "swiggy")
        self.assertEqual(sanitize_slug("ZetwerkIPO"), "zetwerk")

    def test_sanitize_gmp(self):
        amt, pct = sanitize_gmp("₹8 (7.41%)")
        self.assertEqual(amt, "₹8")
        self.assertEqual(pct, "+7.41%")

        amt, pct = sanitize_gmp("₹1.2(0.79%)1 ↓ / 30 ↑")
        self.assertEqual(amt, "₹1.2")
        self.assertEqual(pct, "+0.79%")

        amt, pct = sanitize_gmp("+₹45 (15.5%)")
        self.assertEqual(amt, "+₹45")
        self.assertEqual(pct, "+15.5%")

        amt, pct = sanitize_gmp("--")
        self.assertEqual(amt, "")
        self.assertEqual(pct, "")

    def test_parse_indian_date(self):
        self.assertEqual(parse_indian_date("20-Nov-2024"), "2024-11-20")
        self.assertEqual(parse_indian_date("Nov 20, 2024"), "2024-11-20")
        self.assertEqual(parse_indian_date("20/11/2024"), "2024-11-20")
        self.assertEqual(parse_indian_date("2024-11-20"), "2024-11-20")
        self.assertIsNone(parse_indian_date(""))
        self.assertIsNone(parse_indian_date(None))

    def test_sme_filtering(self):
        self.assertFalse(is_sme_ipo("NTPC Green Energy Limited", lot_size=138, min_investment=14904))
        self.assertFalse(is_sme_ipo("Swiggy Limited", lot_size=38, min_investment=14820))
        self.assertTrue(is_sme_ipo("Tech Innovations SME IPO", lot_size=1000, min_investment=120000))
        self.assertTrue(is_sme_ipo("Fintech Ventures (BSE SME)", lot_size=1200, min_investment=140000))
        self.assertTrue(is_sme_ipo("Random Corp", lot_size=2000, min_investment=150000))

    def test_is_already_listed(self):
        # Already listed with price or gain
        self.assertTrue(is_already_listed({"listing_price": "₹412.00"}, today_str="2026-11-19"))
        self.assertTrue(is_already_listed({"listing_gain": "+5.64%"}, today_str="2026-11-19"))
        self.assertTrue(is_already_listed({"listing_date": "2024-11-13"}, today_str="2026-11-19"))
        self.assertTrue(is_already_listed({"status": "LISTED"}, today_str="2026-11-19"))

        # Upcoming / active issue
        self.assertFalse(is_already_listed({"listing_date": "2026-12-15", "listing_price": ""}, today_str="2026-11-19"))
        self.assertFalse(is_already_listed({"listing_date": None, "listing_price": ""}, today_str="2026-11-19"))

    def test_registrar_links(self):
        self.assertIn("linkintime.co.in", get_registrar_url("Link Intime India Private Ltd"))
        self.assertIn("kfintech.com", get_registrar_url("KFin Technologies Limited"))
        self.assertIn("bigshareonline.com", get_registrar_url("Bigshare Services Pvt Ltd"))
        self.assertIn("bseindia.com", get_registrar_url("Unknown Registrar"))


class TestDrhpParser(unittest.TestCase):
    def test_drhp_detail_parsing(self):
        mock_html = """
        <html>
            <body>
                <div id="ipo-summary">
                    <p>India's leading retail hypermarket chain.</p>
                </div>
                <div>
                    <h3>Objects of the Issue</h3>
                    <ul>
                        <li>Funding capital expenditure towards setting up new stores.</li>
                        <li>Prepayment or repayment of certain borrowings.</li>
                        <li>General corporate purposes.</li>
                    </ul>
                </div>
                <table>
                    <tr><th>Category</th><th>Allocation</th></tr>
                    <tr><td>QIB Shares Offered</td><td>50%</td></tr>
                    <tr><td>NII (HNI) Shares Offered</td><td>15%</td></tr>
                    <tr><td>Retail Shares Offered</td><td>35%</td></tr>
                </table>
                <table>
                    <tr><th>Period</th><th>Revenue</th><th>Profit After Tax</th><th>Net Worth</th></tr>
                    <tr><td>FY24</td><td>8,911.90</td><td>461.94</td><td>2,410.50</td></tr>
                </table>
                <table>
                    <tr><th>KPI</th><th>Values</th></tr>
                    <tr><td>P/E (x)</td><td>38.5</td></tr>
                    <tr><td>RoNW</td><td>19.16%</td></tr>
                    <tr><td>Market Cap (Rs Cr)</td><td>35,000</td></tr>
                </table>
                <table>
                    <tr><th>Promoter</th><th>Holding</th></tr>
                    <tr><td>Pre Issue Share Holding</td><td>96.46%</td></tr>
                    <tr><td>Post Issue Share Holding</td><td>74.50%</td></tr>
                </table>
                <p>Lead Manager(s):</p>
                <ul>
                    <li>Kotak Mahindra Capital</li>
                    <li>ICICI Securities</li>
                </ul>
                <a href="/documents/rhp_filing.pdf">Download RHP</a>
            </body>
        </html>
        """
        parser = DrhpDetailParser()
        details = parser.parse_drhp_details(mock_html) if hasattr(parser, "parse_drhp_details") else {}
        # Or test fetch_drhp_details with mock session
        mock_session = MagicMock()
        mock_resp = MagicMock()
        mock_resp.status_code = 200
        mock_resp.text = mock_html
        mock_session.get.return_value = mock_resp

        parser.session = mock_session
        res = parser.fetch_drhp_details("https://www.chittorgarh.com/ipo/sample/123/")

        self.assertEqual(len(res["objects_of_issue"]), 3)
        self.assertEqual(res["reservation"]["qib_pct"], "50%")
        self.assertEqual(res["reservation"]["retail_pct"], "35%")
        self.assertEqual(res["financials"]["revenue"], "8,911.90")
        self.assertEqual(res["financials"]["pat"], "461.94")
        self.assertEqual(res["kpis"]["pe_ratio"], "38.5")
        self.assertEqual(res["kpis"]["ronw"], "19.16%")
        self.assertEqual(res["promoter_holding"]["pre_issue"], "96.46%")
        self.assertEqual(len(res["lead_managers"]), 2)
        self.assertIn("rhp_filing.pdf", res["drhp_url"])


class TestIpoFormatters(unittest.TestCase):
    def setUp(self):
        self.sample_ipo = {
            "id": "vishal-mega-mart",
            "company_name": "Vishal Mega Mart Limited",
            "symbol": "VISHAL",
            "open_date": "2024-12-11",
            "close_date": "2024-12-13",
            "allotment_date": "2024-12-16",
            "listing_date": "2024-12-18",
            "price_band": "₹74 to ₹78",
            "cut_off_price": 78,
            "lot_size": 190,
            "min_investment": 14820,
            "issue_size_cr": "8,000",
            "fresh_issue_cr": "0",
            "ofs_cr": "8,000",
            "gmp": "+₹18.00",
            "gmp_percent": "+23.08%",
            "est_listing_price": "₹96.00",
            "kostak": "₹400",
            "sub2sauda": "₹2,500",
            "reservation": {
                "qib_pct": "50%",
                "nii_pct": "15%",
                "retail_pct": "35%",
            },
            "financials": {
                "revenue": "8,911.90",
                "pat": "461.94",
            },
            "kpis": {
                "pe_ratio": "38.5",
                "ronw": "19.16%",
                "market_cap": "35,000",
            },
            "drhp_objects": [
                "Achieve listing benefits on stock exchanges",
                "Offer for Sale by Samayat Services LLP",
            ],
            "promoter_holding": {
                "pre_issue": "96.46%",
                "post_issue": "74.50%",
            },
            "lead_managers": ["Kotak Mahindra Capital", "ICICI Securities"],
            "registrar": {
                "name": "KFin Technologies Limited",
                "url": "https://kosmic.kfintech.com/ipostatus/",
            },
            "about": "One of India's leading hypermarket operators.",
        }

    def test_new_ipo_alert(self):
        msg = format_new_ipo_alert(self.sample_ipo)
        self.assertIn("NEW MAINBOARD IPO ANNOUNCED", msg)
        self.assertIn("Vishal Mega Mart Limited", msg)
        self.assertIn("@ipocentral", msg)
        self.assertIn("SEBI DRHP ISSUE ALLOCATION", msg)
        self.assertIn("QIB Quota:</b> 50%", msg)
        self.assertIn("FINANCIAL HIGHLIGHTS", msg)
        self.assertIn("OBJECTS OF THE ISSUE", msg)
        self.assertIn("Kostak:</b> ₹400", msg)
        self.assertIn("KFin Technologies Limited", msg)
        self.assertLess(len(msg), 4000)

    def test_opens_today_alert(self):
        msg = format_opens_today_alert(self.sample_ipo)
        self.assertIn("IPO OPENS TODAY", msg)
        self.assertIn("Kostak:</b> ₹400", msg)
        self.assertLess(len(msg), 4000)

    def test_closing_today_alert(self):
        msg = format_closing_today_alert(self.sample_ipo)
        self.assertIn("IPO CLOSING TODAY", msg)
        self.assertLess(len(msg), 4000)

    def test_allotment_out_alert(self):
        msg = format_allotment_out_alert(self.sample_ipo)
        self.assertIn("IPO ALLOTMENT OUT", msg)
        self.assertIn("https://kosmic.kfintech.com/ipostatus/", msg)
        self.assertLess(len(msg), 4000)

    def test_listing_today_alert(self):
        self.sample_ipo["listing_price"] = "₹98.00"
        self.sample_ipo["listing_gain"] = "+25.64%"
        msg = format_listing_today_alert(self.sample_ipo)
        self.assertIn("IPO LISTING TODAY", msg)
        self.assertIn("₹98.00", msg)
        self.assertLess(len(msg), 4000)

    def test_gmp_dashboard(self):
        msg = format_gmp_dashboard([self.sample_ipo], as_of_date="19-Nov-2024")
        self.assertIn("MAINBOARD IPO: LIVE GMP DASHBOARD", msg)
        self.assertIn("Vishal Mega Mart Limited", msg)
        self.assertIn("+₹18.00 (+23.08%)", msg)
        self.assertIn("Kostak: ₹400", msg)
        self.assertLess(len(msg), 4000)


class TestLifecycleEngine(unittest.TestCase):
    def test_already_listed_ipos_not_announced(self):
        # A past listed IPO must NEVER trigger NEW_IPO_ANNOUNCED
        listed_ipo = {
            "id": "swiggy",
            "company_name": "Swiggy Limited",
            "listing_price": "₹412.00",
            "listing_gain": "+5.64%",
            "listing_date": "2024-11-13",
            "status": "LISTED",
            "is_already_listed": True,
        }
        events = evaluate_ipo_events(listed_ipo, today_str="2026-11-19", posted_events_set=set())
        self.assertEqual(len(events), 0)

    def test_active_upcoming_ipo_announcement(self):
        upcoming_ipo = {
            "id": "future-ipo",
            "company_name": "Future Tech Limited",
            "open_date": "2026-12-01",
            "close_date": "2026-12-03",
            "listing_date": "2026-12-08",
            "price_band": "₹200 to ₹210",
            "issue_size_cr": "1,000",
            "is_already_listed": False,
        }
        events = evaluate_ipo_events(upcoming_ipo, today_str="2026-11-19", posted_events_set=set())
        event_types = [e[0] for e in events]
        self.assertIn("NEW_IPO_ANNOUNCED", event_types)


if __name__ == "__main__":
    unittest.main()
