#!/usr/bin/env python3
"""
IPO SCRAPERS & COLLECTORS MODULE
=================================
Fetches, parses, and normalizes Indian Mainboard IPO data from multiple web sources:
1. Chittorgarh (Mainboard IPO Report 82 & Dashboard)
2. InvestorGain (Live Mainboard IPO GMP & Status Report 331)
3. NSE India Public API (Equity IPO issues, series='EQ')
4. BSE India Public API (Equity IPO Master)
5. IPOCentral RSS & Calendar (Mainboard announcements & reviews)

Strictly filters for MAINBOARD IPOs (NSE / BSE Mainboard).
Excludes SME IPOs (BSE SME / NSE Emerge).
"""

from __future__ import annotations

import re
import html
import json
import logging
from datetime import datetime, timezone, timedelta
from urllib.parse import urljoin
import xml.etree.ElementTree as ET

import requests
from bs4 import BeautifulSoup

logger = logging.getLogger("ipo_tracker.scrapers")

IST = timezone(timedelta(hours=5, minutes=30))

BROWSER_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9,hi;q=0.8",
    "Cache-Control": "no-cache",
}

NSE_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept": "*/*",
    "Accept-Language": "en-US,en;q=0.9",
    "Referer": "https://www.nseindia.com/market-data/all-upcoming-issues-ipo",
}

REGISTRAR_LINKS = {
    "link intime": "https://linkintime.co.in/initial_offer/public-issues.html",
    "kfin": "https://kosmic.kfintech.com/ipostatus/",
    "kfintech": "https://kosmic.kfintech.com/ipostatus/",
    "bigshare": "https://www.bigshareonline.com/ipo_Allotment.html",
    "cameo": "https://ipo.cameoindia.com/",
    "skyline": "https://www.skylinerta.com/ipo.php",
    "integrated": "https://www.integratedindia.in/",
    "purva": "https://www.purvashare.com/queries/",
    "mas services": "https://www.masserv.com/opt.asp",
    "bse": "https://www.bseindia.com/investors/appli_check.aspx",
    "nse": "https://www.nseindia.com/products/dynaContent/equities/ipos/ipo_login.jsp",
}


def sanitize_slug(name: str) -> str:
    """Generate a clean slug identifier from company name."""
    clean = re.sub(r"\b(ltd|limited|ipo|pvt|private|india)\b", "", name, flags=re.IGNORECASE)
    clean = re.sub(r"[^a-zA-Z0-9]+", "-", clean.strip().lower()).strip("-")
    return clean or "ipo"


def clean_company_name(raw: str) -> str:
    """Standardize company name, removing clutter like '(Mainboard)', 'IPO', Cloudflare artifacts, badges, etc."""
    text = re.sub(r"\s+", " ", raw or "").strip()
    # Remove Cloudflare email protected artifacts
    text = re.sub(r"\[email\s*protected\]", "", text, flags=re.IGNORECASE)
    # Remove listing gain percentage badges e.g. (10.98%) or (-5.56%)
    text = re.sub(r"\([+-]?\d+(?:\.\d+)?%\)", "", text)
    # Remove trailing status tags like IPO U, IPO O, IPO C, or bare IPO (even without space e.g. ZetwerkIPO)
    text = re.sub(r"(?i)\s*ipo\s*[uoc]?$", "", text)
    text = re.sub(r"\bIPO\s*[UOC]?\b", "", text, flags=re.IGNORECASE)
    text = re.sub(r"\(Mainboard\)", "", text, flags=re.IGNORECASE)
    text = re.sub(r"\(BSE/NSE\)", "", text, flags=re.IGNORECASE)
    text = re.sub(r"\s+", " ", text).strip(" -–:,")
    return text


def is_sme_ipo(name: str, lot_size: int | None = None, min_investment: float | None = None, category: str = "") -> bool:
    """
    Check if an issue is an SME IPO.
    Mainboard IPO retail ticket size is mandated by SEBI to be ~Rs 14,000 - 15,000.
    SME IPOs have retail ticket size of Rs 1,00,000 to Rs 1,40,000 and lot size typically >= 800.
    """
    combined = f"{name} {category}".lower()
    if any(keyword in combined for keyword in ["sme", "nse emerge", "bse sme", "emerge"]):
        return True

    # High ticket size check
    if min_investment and min_investment > 50000:
        return True

    if lot_size and lot_size >= 800:
        return True

    return False


def parse_indian_date(date_str: str) -> str | None:
    """
    Parse Indian financial date formats into YYYY-MM-DD.
    Examples: '20-Nov-2024', 'Nov 20, 2024', '20/11/2024', '20-11-2024', '20 Nov 2024'
    """
    if not date_str or not isinstance(date_str, str):
        return None

    cleaned = date_str.strip().replace(",", " ")
    cleaned = re.sub(r"\s+", " ", cleaned).strip()

    # If already YYYY-MM-DD
    if re.match(r"^\d{4}-\d{2}-\d{2}$", cleaned):
        return cleaned

    # Common formats
    formats = [
        "%d-%b-%Y",
        "%d-%b-%y",
        "%d %b %Y",
        "%d %b %y",
        "%b %d %Y",
        "%b %d %y",
        "%d-%m-%Y",
        "%d/%m/%Y",
        "%Y/%m/%d",
        "%d-%B-%Y",
        "%B %d %Y",
    ]

    for fmt in formats:
        try:
            dt = datetime.strptime(cleaned, fmt)
            return dt.strftime("%Y-%m-%d")
        except ValueError:
            continue

    # Attempt regex for e.g. "19-Nov", "19 Nov" or "Nov 19", "Nov-19" (missing year -> assume current/next/prev year)
    m1 = re.match(r"^(\d{1,2})[-/\s]+([a-zA-Z]{3,9})$", cleaned)
    m2 = re.match(r"^([a-zA-Z]{3,9})[-/\s]+(\d{1,2})$", cleaned)
    if m1 or m2:
        if m1:
            day_str, month_str = m1.group(1), m1.group(2)
        else:
            month_str, day_str = m2.group(1), m2.group(2)
        now_year = datetime.now(IST).year
        for year in (now_year, now_year - 1, now_year + 1, now_year - 2):
            try:
                dt = datetime.strptime(f"{day_str} {month_str} {year}", "%d %b %Y")
                return dt.strftime("%Y-%m-%d")
            except ValueError:
                pass

    return None


def get_registrar_url(registrar_name: str) -> str:
    """Match registrar name to its direct allotment lookup page."""
    if not registrar_name:
        return REGISTRAR_LINKS["bse"]
    lower = registrar_name.lower()
    for key, url in REGISTRAR_LINKS.items():
        if key in lower:
            return url
    return REGISTRAR_LINKS["bse"]


# ============================================================
# 1. CHITTORGARH SCRAPER
# ============================================================

class ChittorgarhScraper:
    """
    Scrapes Chittorgarh Mainboard IPO report (Report 82).
    URL: https://www.chittorgarh.com/report/mainboard-ipo-list-in-india-bse-nse/82/
    Dashboard: https://www.chittorgarh.com/ipo/ipo_dashboard.asp
    """

    REPORT_URL = "https://www.chittorgarh.com/report/mainboard-ipo-list-in-india-bse-nse/82/"
    DASHBOARD_URL = "https://www.chittorgarh.com/ipo/ipo_dashboard.asp"

    def __init__(self, session: requests.Session | None = None):
        self.session = session or requests.Session()

    def fetch_mainboard_ipos(self) -> list[dict]:
        """Fetch and parse Mainboard IPOs from Chittorgarh Report 82."""
        results = []
        try:
            resp = self.session.get(self.REPORT_URL, headers=BROWSER_HEADERS, timeout=15)
            if resp.status_code != 200:
                logger.warning(f"Chittorgarh Report 82 returned status {resp.status_code}")
                return results

            soup = BeautifulSoup(resp.text, "html.parser")
            table = soup.find("table", {"id": "report_table"}) or soup.find("table", class_=re.compile(r"table"))
            if not table:
                logger.warning("Chittorgarh report table not found in HTML response")
                return results

            rows = table.find_all("tr")
            if not rows:
                return results

            # Map headers
            header_cells = rows[0].find_all(["th", "td"])
            headers = [c.get_text(strip=True).lower() for c in header_cells]

            def find_idx(keywords):
                for idx, h in enumerate(headers):
                    if any(k in h for k in keywords):
                        return idx
                return -1

            idx_name = find_idx(["issuer", "company", "ipo name"])
            idx_open = find_idx(["open"])
            idx_close = find_idx(["close"])
            idx_listing = find_idx(["listing date", "list date"])
            idx_price = find_idx(["issue price", "price (rs)"])
            idx_amount = find_idx(["issue amount", "size (rs cr)", "amount"])
            idx_list_price = find_idx(["listing price"])
            idx_gain = find_idx(["listing gain", "% change"])

            if idx_name == -1:
                idx_name = 0

            for tr in rows[1:]:
                tds = tr.find_all("td")
                if not tds or len(tds) < 3:
                    continue

                a_tag = tds[idx_name].find("a")
                raw_name = a_tag.get_text(strip=True) if a_tag else tds[idx_name].get_text(strip=True)
                if not raw_name:
                    continue

                detail_url = urljoin(self.REPORT_URL, a_tag["href"]) if a_tag and a_tag.get("href") else ""
                clean_name = clean_company_name(raw_name)

                # Skip if marked SME
                if is_sme_ipo(raw_name):
                    continue

                open_date = parse_indian_date(tds[idx_open].get_text(strip=True)) if idx_open >= 0 and idx_open < len(tds) else None
                close_date = parse_indian_date(tds[idx_close].get_text(strip=True)) if idx_close >= 0 and idx_close < len(tds) else None
                listing_date = parse_indian_date(tds[idx_listing].get_text(strip=True)) if idx_listing >= 0 and idx_listing < len(tds) else None

                price_text = tds[idx_price].get_text(strip=True) if idx_price >= 0 and idx_price < len(tds) else ""
                size_text = tds[idx_amount].get_text(strip=True) if idx_amount >= 0 and idx_amount < len(tds) else ""

                list_price_text = tds[idx_list_price].get_text(strip=True) if idx_list_price >= 0 and idx_list_price < len(tds) else ""
                gain_text = tds[idx_gain].get_text(strip=True) if idx_gain >= 0 and idx_gain < len(tds) else ""

                item = {
                    "source": "chittorgarh",
                    "company_name": clean_name,
                    "raw_name": raw_name,
                    "detail_url": detail_url,
                    "open_date": open_date,
                    "close_date": close_date,
                    "listing_date": listing_date,
                    "price_band": price_text,
                    "issue_size_cr": size_text,
                    "listing_price": list_price_text,
                    "listing_gain": gain_text,
                    "is_mainboard": True,
                }
                results.append(item)

        except Exception as e:
            logger.warning(f"Error scraping Chittorgarh Report 82: {e}")

        return results


# ============================================================
# 2. INVESTORGAIN SCRAPER (LIVE GMP & MAINBOARD IPOS)
# ============================================================

class InvestorGainScraper:
    """
    Scrapes InvestorGain Live Mainboard IPO GMP report (Report 331).
    URL: https://www.investorgain.com/report/live-ipo-gmp/331/
    Provides live Grey Market Premium (GMP), estimated listing price, and dates.
    """

    GMP_URL = "https://www.investorgain.com/report/live-ipo-gmp/331/"

    def __init__(self, session: requests.Session | None = None):
        self.session = session or requests.Session()

    def fetch_live_gmp(self) -> list[dict]:
        """Fetch live Mainboard IPO GMP and status from InvestorGain."""
        results = []
        try:
            resp = self.session.get(self.GMP_URL, headers=BROWSER_HEADERS, timeout=15)
            if resp.status_code != 200:
                logger.warning(f"InvestorGain GMP returned status {resp.status_code}")
                return results

            soup = BeautifulSoup(resp.text, "html.parser")
            tables = soup.find_all("table")

            for table in tables:
                rows = table.find_all("tr")
                if len(rows) < 2:
                    continue

                headers = [c.get_text(strip=True).lower() for c in rows[0].find_all(["th", "td"])]
                if not any("gmp" in h for h in headers):
                    continue

                def find_idx(keywords):
                    for idx, h in enumerate(headers):
                        if any(k in h for k in keywords):
                            return idx
                    return -1

                idx_name = find_idx(["ipo", "company", "name"])
                idx_gmp = find_idx(["gmp(₹)", "gmp (₹)", "gmp", "grey market"])
                idx_price = find_idx(["ipo price", "price(₹)", "price (₹)", "price"])
                idx_est = find_idx(["est listing", "est. listing", "estimated"])
                idx_date = find_idx(["ipo date", "date"])
                idx_lot = find_idx(["lot", "lot size"])

                if idx_name == -1 or idx_gmp == -1:
                    continue

                for tr in rows[1:]:
                    tds = tr.find_all("td")
                    if len(tds) <= max(idx_name, idx_gmp):
                        continue

                    raw_name = tds[idx_name].get_text(strip=True)
                    if not raw_name:
                        continue

                    # Filter out SME IPOs
                    if is_sme_ipo(raw_name):
                        continue

                    gmp_raw = tds[idx_gmp].get_text(strip=True) if idx_gmp >= 0 and idx_gmp < len(tds) else ""
                    price_raw = tds[idx_price].get_text(strip=True) if idx_price >= 0 and idx_price < len(tds) else ""
                    est_raw = tds[idx_est].get_text(strip=True) if idx_est >= 0 and idx_est < len(tds) else ""
                    date_raw = tds[idx_date].get_text(strip=True) if idx_date >= 0 and idx_date < len(tds) else ""
                    lot_raw = tds[idx_lot].get_text(strip=True) if idx_lot >= 0 and idx_lot < len(tds) else ""

                    # Parse lot size
                    lot_val = None
                    m_lot = re.search(r"(\d+)", lot_raw)
                    if m_lot:
                        lot_val = int(m_lot.group(1))

                    # Parse GMP value & percentage
                    # e.g. "₹8 (7.4%)" or "8" or "--"
                    gmp_val = gmp_raw
                    gmp_pct = ""
                    m_pct = re.search(r"\(([+-]?\d+(?:\.\d+)?%?)\)", gmp_raw)
                    if m_pct:
                        gmp_pct = m_pct.group(1)
                        if not gmp_pct.endswith("%"):
                            gmp_pct += "%"

                    # Parse dates if e.g. "20-Nov to 22-Nov"
                    open_d = None
                    close_d = None
                    if "to" in date_raw:
                        parts = date_raw.split("to")
                        open_d = parse_indian_date(parts[0].strip())
                        close_d = parse_indian_date(parts[1].strip())
                    else:
                        open_d = parse_indian_date(date_raw)

                    clean_name = clean_company_name(raw_name)

                    item = {
                        "source": "investorgain",
                        "company_name": clean_name,
                        "raw_name": raw_name,
                        "gmp": gmp_val,
                        "gmp_percent": gmp_pct,
                        "price_band": price_raw,
                        "est_listing_price": est_raw,
                        "open_date": open_d,
                        "close_date": close_d,
                        "lot_size": lot_val,
                        "is_mainboard": True,
                    }
                    results.append(item)

        except Exception as e:
            logger.warning(f"Error scraping InvestorGain GMP: {e}")

        return results


# ============================================================
# 3. NSE INDIA OFFICIAL IPO SCRAPER
# ============================================================

class NseIpoScraper:
    """
    Fetches official NSE public IPO API endpoints:
    - https://www.nseindia.com/api/all-ipo-issues
    - https://www.nseindia.com/api/ipo-current-issue
    Filters for series='EQ' (Mainboard equities).
    """

    BASE_URL = "https://www.nseindia.com"
    ALL_IPO_URL = "https://www.nseindia.com/api/all-ipo-issues"
    CURRENT_IPO_URL = "https://www.nseindia.com/api/ipo-current-issue"

    def __init__(self, session: requests.Session | None = None):
        self.session = session or requests.Session()

    def fetch_nse_ipos(self) -> list[dict]:
        results = []
        try:
            # 1. Initialize session cookie on main page
            self.session.get(self.BASE_URL, headers=NSE_HEADERS, timeout=10)

            # 2. Query all issues
            resp = self.session.get(self.ALL_IPO_URL, headers=NSE_HEADERS, timeout=12)
            if resp.status_code == 200:
                data = resp.json()
                items = data.get("data", []) if isinstance(data, dict) else (data if isinstance(data, list) else [])
                for entry in items:
                    if not isinstance(entry, dict):
                        continue

                    # Filter for Mainboard Series 'EQ'
                    series = entry.get("series", "").strip().upper()
                    if series and series not in ("EQ", "MAINBOARD", ""):
                        continue

                    sym = entry.get("symbol", "").strip()
                    comp_name = clean_company_name(entry.get("companyName") or entry.get("issueName") or sym)
                    if not comp_name:
                        continue

                    if is_sme_ipo(comp_name):
                        continue

                    open_d = parse_indian_date(entry.get("issueStartDate") or entry.get("openDate"))
                    close_d = parse_indian_date(entry.get("issueEndDate") or entry.get("closeDate"))
                    price_b = entry.get("priceBand") or entry.get("issuePrice") or ""
                    size_cr = entry.get("issueSize") or ""

                    results.append({
                        "source": "nse",
                        "symbol": sym,
                        "company_name": comp_name,
                        "open_date": open_d,
                        "close_date": close_d,
                        "price_band": str(price_b),
                        "issue_size_cr": str(size_cr),
                        "is_mainboard": True,
                    })

        except Exception as e:
            logger.debug(f"NSE IPO API fetch note (expected if blocked/captcha): {e}")

        return results


# ============================================================
# 4. IPOCENTRAL RSS SCRAPER
# ============================================================

class IpoCentralRssScraper:
    """
    Fetches latest IPO articles and updates from IPOCentral RSS feed.
    URL: https://ipocentral.in/feed/
    Provides company overviews, SEBI approvals, and IPO insights.
    """

    FEED_URL = "https://ipocentral.in/feed/"

    def __init__(self, session: requests.Session | None = None):
        self.session = session or requests.Session()

    def fetch_latest_updates(self) -> list[dict]:
        results = []
        try:
            resp = self.session.get(self.FEED_URL, headers=BROWSER_HEADERS, timeout=12)
            if resp.status_code != 200:
                return results

            root = ET.fromstring(resp.content)
            channel = root.find("channel")
            if channel is None:
                return results

            for item in channel.findall("item"):
                title = item.findtext("title", "")
                link = item.findtext("link", "")
                pub_date = item.findtext("pubDate", "")
                desc = item.findtext("description", "")

                if not title:
                    continue

                if is_sme_ipo(title):
                    continue

                # Strip HTML from description
                soup = BeautifulSoup(desc, "html.parser")
                clean_desc = soup.get_text(separator=" ", strip=True)

                results.append({
                    "source": "ipocentral_rss",
                    "title": title,
                    "link": link,
                    "pub_date": pub_date,
                    "description": clean_desc,
                })

        except Exception as e:
            logger.debug(f"IPOCentral RSS fetch note: {e}")

        return results


# ============================================================
# 5. DATA AGGREGATOR & MERGER
# ============================================================

class IpoAggregator:
    """
    Coordinates all collectors, deduplicates by company name / slug,
    merges data points, and standardizes Mainboard IPO records.
    """

    def __init__(self, session: requests.Session | None = None):
        self.session = session or requests.Session()
        self.chittorgarh = ChittorgarhScraper(self.session)
        self.investorgain = InvestorGainScraper(self.session)
        self.nse = NseIpoScraper(self.session)
        self.ipocentral = IpoCentralRssScraper(self.session)

    def collect_all_mainboard_ipos(self) -> list[dict]:
        """Collect and cross-merge Mainboard IPO data from all available sources."""
        raw_items = []

        # 1. Fetch from Chittorgarh
        c_items = self.chittorgarh.fetch_mainboard_ipos()
        raw_items.extend(c_items)
        logger.info(f"Collected {len(c_items)} entries from Chittorgarh")

        # 2. Fetch from InvestorGain
        ig_items = self.investorgain.fetch_live_gmp()
        raw_items.extend(ig_items)
        logger.info(f"Collected {len(ig_items)} entries from InvestorGain")

        # 3. Fetch from NSE
        nse_items = self.nse.fetch_nse_ipos()
        raw_items.extend(nse_items)
        logger.info(f"Collected {len(nse_items)} entries from NSE")

        # Group and merge by normalized key
        merged_map: dict[str, dict] = {}

        for item in raw_items:
            c_name = item.get("company_name", "")
            slug = sanitize_slug(c_name)
            if not slug:
                continue

            if slug not in merged_map:
                merged_map[slug] = {
                    "id": slug,
                    "company_name": c_name,
                    "symbol": item.get("symbol") or "",
                    "issue_type": "Mainboard",
                    "exchange": "NSE & BSE",
                    "open_date": item.get("open_date"),
                    "close_date": item.get("close_date"),
                    "allotment_date": item.get("allotment_date"),
                    "listing_date": item.get("listing_date"),
                    "price_band": item.get("price_band") or "",
                    "lot_size": item.get("lot_size"),
                    "issue_size_cr": item.get("issue_size_cr") or "",
                    "fresh_issue_cr": item.get("fresh_issue_cr") or "",
                    "ofs_cr": item.get("ofs_cr") or "",
                    "gmp": item.get("gmp") or "",
                    "gmp_percent": item.get("gmp_percent") or "",
                    "est_listing_price": item.get("est_listing_price") or "",
                    "listing_price": item.get("listing_price") or "",
                    "listing_gain": item.get("listing_gain") or "",
                    "subscription": item.get("subscription") or {},
                    "registrar": item.get("registrar") or {"name": "", "url": ""},
                    "about": item.get("about") or "",
                    "sources": [item.get("source")],
                }
            else:
                existing = merged_map[slug]
                # Merge missing or better fields
                if not existing.get("open_date") and item.get("open_date"):
                    existing["open_date"] = item["open_date"]
                if not existing.get("close_date") and item.get("close_date"):
                    existing["close_date"] = item["close_date"]
                if not existing.get("listing_date") and item.get("listing_date"):
                    existing["listing_date"] = item["listing_date"]
                if not existing.get("allotment_date") and item.get("allotment_date"):
                    existing["allotment_date"] = item["allotment_date"]

                if not existing.get("price_band") and item.get("price_band"):
                    existing["price_band"] = item["price_band"]
                if not existing.get("lot_size") and item.get("lot_size"):
                    existing["lot_size"] = item["lot_size"]
                if not existing.get("issue_size_cr") and item.get("issue_size_cr"):
                    existing["issue_size_cr"] = item["issue_size_cr"]

                if item.get("gmp"):
                    existing["gmp"] = item["gmp"]
                if item.get("gmp_percent"):
                    existing["gmp_percent"] = item["gmp_percent"]
                if item.get("est_listing_price"):
                    existing["est_listing_price"] = item["est_listing_price"]

                if item.get("listing_price"):
                    existing["listing_price"] = item["listing_price"]
                if item.get("listing_gain"):
                    existing["listing_gain"] = item["listing_gain"]

                if item.get("symbol") and not existing.get("symbol"):
                    existing["symbol"] = item["symbol"]

                src = item.get("source")
                if src and src not in existing.get("sources", []):
                    existing["sources"].append(src)

        # Post-process min_investment, cut_off_price, and registrar link
        for ipo in merged_map.values():
            price_band = ipo.get("price_band", "")
            lot = ipo.get("lot_size")

            # Extract max price (cut-off price)
            prices = re.findall(r"\d+(?:\.\d+)?", price_band.replace(",", ""))
            if prices:
                try:
                    num_prices = [float(p) for p in prices]
                    cut_off = max(num_prices)
                    ipo["cut_off_price"] = int(cut_off) if cut_off.is_integer() else cut_off
                    if lot and not ipo.get("min_investment"):
                        ipo["min_investment"] = int(round(cut_off * lot))
                except Exception:
                    pass

            # Fix registrar URL if name is known
            reg = ipo.get("registrar", {})
            if isinstance(reg, dict) and reg.get("name") and not reg.get("url"):
                reg["url"] = get_registrar_url(reg["name"])

        return list(merged_map.values())
