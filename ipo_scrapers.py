#!/usr/bin/env python3
"""
IPO SCRAPERS & COLLECTORS MODULE (ENHANCED)
===========================================
Fetches, parses, and normalizes Indian Mainboard IPO data from multiple web sources:
1. IPO Central Live GMP (Primary GMP Source: https://ipocentral.in/ipo-grey-market-premium-gmp/)
2. Chittorgarh Mainboard GMP (Report 82 GMP: https://www.chittorgarh.com/report/ipo-gmp-live-grey-market-premium/82/)
3. Chittorgarh Mainboard Dashboard & Active Issues (https://www.chittorgarh.com/ipo/ipo_dashboard.asp)
4. IPO Watch Live GMP (https://ipowatch.in/ipo-grey-market-premium-latest-ipo-gmp/)
5. InvestorGain Mainboard GMP (https://www.investorgain.com/report/live-ipo-gmp/331/)
6. SEBI DRHP / RHP Detail Parser (Objects of Issue, Financials, KPIs, Quotas, Promoters, Lead Managers)
7. NSE & BSE Public Equity APIs

Strictly filters for MAINBOARD IPOs (NSE / BSE Mainboard).
Strictly EXCLUDES SME IPOs and ALREADY-LISTED historical IPOs.
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


# ============================================================
# STRING & DATA SANITIZERS
# ============================================================

def sanitize_slug(name: str) -> str:
    """Generate a clean slug identifier from company name."""
    clean = re.sub(r"\[email\s*protected\]", "", name or "", flags=re.IGNORECASE)
    clean = re.sub(r"(?i)\s*ipo\s*[uoc]?$", "", clean)
    clean = re.sub(r"\b(ltd|limited|ipo|pvt|private|india)\b", "", clean, flags=re.IGNORECASE)
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


def sanitize_gmp(raw: str | None) -> tuple[str, str]:
    """
    Extract clean GMP amount and percentage from raw string.
    Removes arrows, Cloudflare artifacts, and rate counters.
    Example inputs:
      '₹8 (7.41%)' -> ('₹8', '+7.41%')
      '₹1.2(0.79%)1 ↓ / 30 ↑' -> ('₹1.2', '+0.79%')
      '+₹45' -> ('₹45', '')
      '--' -> ('', '')
    """
    if not raw or str(raw).strip() in ("--", "-", "0", "N/A", "TBA", "none"):
        return "", ""

    cleaned = re.sub(r"\[email\s*protected\]", "", str(raw), flags=re.IGNORECASE)
    cleaned = re.sub(r"[\u2191\u2193\u2192\u2190/\d+\s*]+$", "", cleaned).strip()

    # Extract percentage
    pct = ""
    m_pct = re.search(r"\(([+-]?\d+(?:\.\d+)?%?)\)", cleaned)
    if m_pct:
        pct = m_pct.group(1).strip()
        if not pct.endswith("%"):
            pct += "%"
        try:
            val_f = float(pct.rstrip("%"))
            if val_f > 0 and not pct.startswith("+"):
                pct = "+" + pct
        except ValueError:
            pass

    # Extract price amount with optional sign
    m_amt = re.search(r"([+-]?)\s*₹?\s*([+-]?\d+(?:\.\d+)?)", cleaned)
    amt = ""
    if m_amt:
        sign = m_amt.group(1) or ""
        val = m_amt.group(2).strip()
        if val.startswith(("+", "-")):
            sign = val[0]
            val = val[1:]
        if sign == "+":
            amt = f"+₹{val}"
        elif sign == "-":
            amt = f"-₹{val}"
        else:
            amt = f"₹{val}"

    return amt, pct


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


def is_already_listed(item: dict, today_str: str) -> bool:
    """
    Check if an IPO is already listed on the stock exchange.
    Already listed IPOs must NOT be announced as new IPOs.
    """
    # 1. Listing price or gain already present
    lp = str(item.get("listing_price", "")).strip()
    lg = str(item.get("listing_gain", "")).strip()
    if lp and lp not in ("TBA", "Updating...", "None", ""):
        return True
    if lg and lg not in ("TBA", "None", ""):
        return True

    # 2. Listing date in the past
    ld = item.get("listing_date")
    if ld and ld < today_str:
        return True

    # 3. Explicit status
    status = str(item.get("status", "")).upper()
    if status in ("LISTED", "CLOSED_PAST"):
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

    # Attempt regex for e.g. "19-Nov", "19 Nov" or "Nov 19", "Nov-19" (missing year -> assume current year)
    m1 = re.match(r"^(\d{1,2})[-/\s]+([a-zA-Z]{3,9})$", cleaned)
    m2 = re.match(r"^([a-zA-Z]{3,9})[-/\s]+(\d{1,2})$", cleaned)
    if m1 or m2:
        if m1:
            day_str, month_str = m1.group(1), m1.group(2)
        else:
            month_str, day_str = m2.group(1), m2.group(2)
        now_year = datetime.now(IST).year
        for year in (now_year, now_year + 1, now_year - 1):
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
# 1. IPOCENTRAL LIVE GMP SCRAPER (PRIMARY GMP SOURCE)
# ============================================================

class IpoCentralGmpScraper:
    """
    Scrapes IPO Central's official live Grey Market Premium page:
    URL: https://ipocentral.in/ipo-grey-market-premium-gmp/
    Provides live GMP, Kostak rates, Subject to Sauda, and expected gains.
    """

    GMP_URL = "https://ipocentral.in/ipo-grey-market-premium-gmp/"

    def __init__(self, session: requests.Session | None = None):
        self.session = session or requests.Session()

    def fetch_live_gmp(self) -> list[dict]:
        results = []
        try:
            resp = self.session.get(self.GMP_URL, headers=BROWSER_HEADERS, timeout=15)
            if resp.status_code != 200:
                logger.debug(f"IPOCentral GMP returned status {resp.status_code}")
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
                idx_gmp = find_idx(["gmp", "grey market"])
                idx_price = find_idx(["price", "issue price"])
                idx_gain = find_idx(["gain", "est gain", "%"])
                idx_kostak = find_idx(["kostak"])
                idx_sub2 = find_idx(["subject to sauda", "sub to sauda", "sub2sauda"])

                if idx_name == -1 or idx_gmp == -1:
                    continue

                for tr in rows[1:]:
                    tds = tr.find_all("td")
                    if len(tds) <= max(idx_name, idx_gmp):
                        continue

                    raw_name = tds[idx_name].get_text(strip=True)
                    if not raw_name or is_sme_ipo(raw_name):
                        continue

                    clean_name = clean_company_name(raw_name)
                    raw_gmp = tds[idx_gmp].get_text(strip=True) if idx_gmp >= 0 and idx_gmp < len(tds) else ""
                    gmp_amt, gmp_pct = sanitize_gmp(raw_gmp)

                    price_raw = tds[idx_price].get_text(strip=True) if idx_price >= 0 and idx_price < len(tds) else ""
                    gain_raw = tds[idx_gain].get_text(strip=True) if idx_gain >= 0 and idx_gain < len(tds) else ""
                    if not gmp_pct and gain_raw:
                        gmp_pct = gain_raw if gain_raw.endswith("%") else f"{gain_raw}%"

                    kostak = tds[idx_kostak].get_text(strip=True) if idx_kostak >= 0 and idx_kostak < len(tds) else ""
                    sub2sauda = tds[idx_sub2].get_text(strip=True) if idx_sub2 >= 0 and idx_sub2 < len(tds) else ""

                    results.append({
                        "source": "ipocentral_gmp",
                        "company_name": clean_name,
                        "raw_name": raw_name,
                        "gmp": gmp_amt,
                        "gmp_percent": gmp_pct,
                        "price_band": price_raw,
                        "kostak": kostak,
                        "sub2sauda": sub2sauda,
                        "is_mainboard": True,
                    })

        except Exception as e:
            logger.debug(f"IPOCentral GMP fetch note: {e}")

        return results


# ============================================================
# 2. CHITTORGARH MAINBOARD GMP SCRAPER (REPORT 82 GMP)
# ============================================================

class ChittorgarhGmpScraper:
    """
    Scrapes Chittorgarh's dedicated Mainboard Live GMP report:
    URL: https://www.chittorgarh.com/report/ipo-gmp-live-grey-market-premium/82/
    Strictly Report 82 (Mainboard Issues only).
    """

    REPORT_82_GMP_URL = "https://www.chittorgarh.com/report/ipo-gmp-live-grey-market-premium/82/"

    def __init__(self, session: requests.Session | None = None):
        self.session = session or requests.Session()

    def fetch_mainboard_gmp(self) -> list[dict]:
        results = []
        try:
            resp = self.session.get(self.REPORT_82_GMP_URL, headers=BROWSER_HEADERS, timeout=15)
            if resp.status_code != 200:
                return results

            soup = BeautifulSoup(resp.text, "html.parser")
            table = soup.find("table", {"id": "report_table"}) or soup.find("table")
            if not table:
                return results

            rows = table.find_all("tr")
            if len(rows) < 2:
                return results

            headers = [c.get_text(strip=True).lower() for c in rows[0].find_all(["th", "td"])]

            def find_idx(keywords):
                for idx, h in enumerate(headers):
                    if any(k in h for k in keywords):
                        return idx
                return -1

            idx_name = find_idx(["ipo", "company", "issuer"])
            idx_price = find_idx(["ipo price", "price"])
            idx_gmp = find_idx(["gmp(₹)", "gmp (₹)", "gmp"])
            idx_est = find_idx(["est listing", "estimated"])
            idx_sub2 = find_idx(["sub2sauda", "sub2 sauda", "sub to sauda"])

            if idx_name == -1 or idx_gmp == -1:
                return results

            for tr in rows[1:]:
                tds = tr.find_all("td")
                if len(tds) <= max(idx_name, idx_gmp):
                    continue

                a_tag = tds[idx_name].find("a")
                raw_name = a_tag.get_text(strip=True) if a_tag else tds[idx_name].get_text(strip=True)
                if not raw_name or is_sme_ipo(raw_name):
                    continue

                detail_url = urljoin(self.REPORT_82_GMP_URL, a_tag["href"]) if a_tag and a_tag.get("href") else ""
                clean_name = clean_company_name(raw_name)

                raw_gmp = tds[idx_gmp].get_text(strip=True) if idx_gmp >= 0 and idx_gmp < len(tds) else ""
                gmp_amt, gmp_pct = sanitize_gmp(raw_gmp)

                price_raw = tds[idx_price].get_text(strip=True) if idx_price >= 0 and idx_price < len(tds) else ""
                est_raw = tds[idx_est].get_text(strip=True) if idx_est >= 0 and idx_est < len(tds) else ""
                sub2 = tds[idx_sub2].get_text(strip=True) if idx_sub2 >= 0 and idx_sub2 < len(tds) else ""

                results.append({
                    "source": "chittorgarh_gmp",
                    "company_name": clean_name,
                    "raw_name": raw_name,
                    "detail_url": detail_url,
                    "gmp": gmp_amt,
                    "gmp_percent": gmp_pct,
                    "price_band": price_raw,
                    "est_listing_price": est_raw,
                    "sub2sauda": sub2,
                    "is_mainboard": True,
                })

        except Exception as e:
            logger.debug(f"Chittorgarh GMP Report 82 fetch note: {e}")

        return results


# ============================================================
# 3. CHITTORGARH MAINBOARD ISSUES & DASHBOARD SCRAPER
# ============================================================

class ChittorgarhScraper:
    """
    Scrapes Chittorgarh Mainboard IPO dashboard and active issues:
    - Report 82: https://www.chittorgarh.com/report/mainboard-ipo-list-in-india-bse-nse/82/
    - Dashboard: https://www.chittorgarh.com/ipo/ipo_dashboard.asp
    Strictly filters out already listed historical issues!
    """

    REPORT_URL = "https://www.chittorgarh.com/report/mainboard-ipo-list-in-india-bse-nse/82/"
    DASHBOARD_URL = "https://www.chittorgarh.com/ipo/ipo_dashboard.asp"

    def __init__(self, session: requests.Session | None = None):
        self.session = session or requests.Session()

    def fetch_mainboard_ipos(self, today_str: str | None = None) -> list[dict]:
        """Fetch and parse Mainboard IPOs, filtering out already listed past IPOs."""
        today_str = today_str or datetime.now(IST).strftime("%Y-%m-%d")
        results = []
        try:
            resp = self.session.get(self.REPORT_URL, headers=BROWSER_HEADERS, timeout=15)
            if resp.status_code != 200:
                logger.warning(f"Chittorgarh Report 82 returned status {resp.status_code}")
                return results

            soup = BeautifulSoup(resp.text, "html.parser")
            table = soup.find("table", {"id": "report_table"}) or soup.find("table", class_=re.compile(r"table"))
            if not table:
                return results

            rows = table.find_all("tr")
            if not rows:
                return results

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

                # Skip if marked SME
                if is_sme_ipo(raw_name):
                    continue

                detail_url = urljoin(self.REPORT_URL, a_tag["href"]) if a_tag and a_tag.get("href") else ""
                clean_name = clean_company_name(raw_name)

                open_date = parse_indian_date(tds[idx_open].get_text(strip=True)) if idx_open >= 0 and idx_open < len(tds) else None
                close_date = parse_indian_date(tds[idx_close].get_text(strip=True)) if idx_close >= 0 and idx_close < len(tds) else None
                listing_date = parse_indian_date(tds[idx_listing].get_text(strip=True)) if idx_listing >= 0 and idx_listing < len(tds) else None

                price_text = tds[idx_price].get_text(strip=True) if idx_price >= 0 and idx_price < len(tds) else ""
                size_text = tds[idx_amount].get_text(strip=True) if idx_amount >= 0 and idx_amount < len(tds) else ""

                list_price_text = tds[idx_list_price].get_text(strip=True) if idx_list_price >= 0 and idx_list_price < len(tds) else ""
                gain_text = tds[idx_gain].get_text(strip=True) if idx_gain >= 0 and idx_gain < len(tds) else ""

                # Check if already listed
                listed = False
                if list_price_text and list_price_text not in ("--", "-", "TBA", ""):
                    listed = True
                if gain_text and gain_text not in ("--", "-", "TBA", ""):
                    listed = True
                if listing_date and listing_date < today_str:
                    listed = True

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
                    "is_already_listed": listed,
                    "status": "LISTED" if listed else ("OPEN" if open_date and open_date <= today_str <= (close_date or today_str) else "UPCOMING"),
                }
                results.append(item)

        except Exception as e:
            logger.warning(f"Error scraping Chittorgarh Report 82: {e}")

        return results


# ============================================================
# 4. SEBI DRHP / RHP DETAIL PARSER (RICH OBJECTS & FINANCIALS)
# ============================================================

class DrhpDetailParser:
    """
    Parses SEBI DRHP / RHP details from Chittorgarh and exchange filing pages:
    - Objects of the Issue (DRHP Use of Proceeds: Debt repayment, Capex, GCP)
    - Quota Reservation (QIB %, NII/HNI %, Retail %, Employee discount)
    - 3-Year Restated Consolidated Financials (Revenue, PAT, Net Worth, Borrowings)
    - KPIs & Valuation (P/E ratio, Market Cap, RoNW, RoCE, EPS, Debt/Equity)
    - Promoters & Pre/Post Issue Shareholding
    - Book Running Lead Managers (BRLMs)
    - Official DRHP / RHP PDF Links
    """

    def __init__(self, session: requests.Session | None = None):
        self.session = session or requests.Session()

    def fetch_drhp_details(self, detail_url: str) -> dict:
        """Fetch and extract DRHP/RHP sections from an IPO detail page."""
        details: dict = {
            "objects_of_issue": [],
            "reservation": {},
            "financials": {},
            "kpis": {},
            "promoter_holding": {},
            "lead_managers": [],
            "drhp_url": "",
            "about": "",
        }

        if not detail_url or not detail_url.startswith("http"):
            return details

        try:
            resp = self.session.get(detail_url, headers=BROWSER_HEADERS, timeout=12)
            if resp.status_code != 200:
                return details

            soup = BeautifulSoup(resp.text, "html.parser")

            # 1. About the Company
            about_div = soup.find("div", {"id": "ipo-summary"}) or soup.find("div", class_=re.compile(r"ipo-about|summary"))
            if about_div:
                p_tags = about_div.find_all("p")
                if p_tags:
                    details["about"] = p_tags[0].get_text(strip=True)

            # 2. Objects of the Issue
            objects_section = soup.find(string=re.compile(r"objects of the issue", re.I))
            if objects_section:
                parent = objects_section.find_parent(["div", "section", "table", "p"])
                if parent:
                    # Look for bullet points or list items
                    ul = parent.find_next("ul") or parent.find("ul")
                    if ul:
                        for li in ul.find_all("li"):
                            txt = li.get_text(strip=True)
                            if txt and len(txt) > 5:
                                details["objects_of_issue"].append(txt)

            # 3. Reservation / Quota
            res_table = soup.find("table", class_=re.compile(r"table"))
            for tbl in soup.find_all("table"):
                tbl_text = tbl.get_text().lower()
                if "qib" in tbl_text and "retail" in tbl_text:
                    for row in tbl.find_all("tr"):
                        cells = [c.get_text(strip=True) for c in row.find_all(["th", "td"])]
                        if len(cells) >= 2:
                            k = cells[0].lower()
                            v = cells[-1]
                            if "qib" in k and "%" in v:
                                details["reservation"]["qib_pct"] = v
                            elif "nii" in k and "%" in v:
                                details["reservation"]["nii_pct"] = v
                            elif "retail" in k and "%" in v:
                                details["reservation"]["retail_pct"] = v

            # 4. Financial Information
            for tbl in soup.find_all("table"):
                txt = tbl.get_text().lower()
                if "revenue" in txt and ("pat" in txt or "profit after tax" in txt):
                    rows = tbl.find_all("tr")
                    if len(rows) >= 2:
                        header_cols = [c.get_text(strip=True).lower() for c in rows[0].find_all(["th", "td"])]
                        # Check column-oriented headers
                        rev_idx = next((i for i, h in enumerate(header_cols) if "revenue" in h), -1)
                        pat_idx = next((i for i, h in enumerate(header_cols) if "pat" in h or "profit after tax" in h), -1)
                        nw_idx = next((i for i, h in enumerate(header_cols) if "net worth" in h), -1)

                        if rev_idx != -1 or pat_idx != -1:
                            last_row = [c.get_text(strip=True) for c in rows[-1].find_all(["td", "th"])]
                            if rev_idx != -1 and rev_idx < len(last_row) and not details["financials"].get("revenue"):
                                details["financials"]["revenue"] = last_row[rev_idx]
                            if pat_idx != -1 and pat_idx < len(last_row) and not details["financials"].get("pat"):
                                details["financials"]["pat"] = last_row[pat_idx]
                            if nw_idx != -1 and nw_idx < len(last_row) and not details["financials"].get("net_worth"):
                                details["financials"]["net_worth"] = last_row[nw_idx]

                        # Check row-oriented labels
                        for r in rows[1:]:
                            c_list = [c.get_text(strip=True) for c in r.find_all(["td", "th"])]
                            if not c_list:
                                continue
                            label = c_list[0].lower()
                            if "revenue" in label and len(c_list) >= 2:
                                details["financials"]["revenue"] = c_list[-1]
                            elif ("profit after tax" in label or "pat" in label) and len(c_list) >= 2:
                                details["financials"]["pat"] = c_list[-1]
                            elif "net worth" in label and len(c_list) >= 2:
                                details["financials"]["net_worth"] = c_list[-1]

            # 5. KPIs & Valuation
            for tbl in soup.find_all("table"):
                txt = tbl.get_text().lower()
                if "p/e" in txt or "ronw" in txt or "market cap" in txt:
                    for r in tbl.find_all("tr"):
                        c_list = [c.get_text(strip=True) for c in r.find_all(["td", "th"])]
                        if len(c_list) >= 2:
                            k = c_list[0].lower()
                            v = c_list[1]
                            if "p/e" in k:
                                details["kpis"]["pe_ratio"] = v
                            elif "ronw" in k or "roe" in k:
                                details["kpis"]["ronw"] = v
                            elif "market cap" in k:
                                details["kpis"]["market_cap"] = v
                            elif "debt/equity" in k or "debt to equity" in k:
                                details["kpis"]["debt_to_equity"] = v

            # 6. Promoter Holding
            for tbl in soup.find_all("table"):
                txt = tbl.get_text().lower()
                if "promoter holding" in txt or "pre issue" in txt:
                    for r in tbl.find_all("tr"):
                        c_list = [c.get_text(strip=True) for c in r.find_all(["td", "th"])]
                        if len(c_list) >= 2:
                            k = c_list[0].lower()
                            v = c_list[-1]
                            if "pre" in k:
                                details["promoter_holding"]["pre_issue"] = v
                            elif "post" in k:
                                details["promoter_holding"]["post_issue"] = v

            # 7. Lead Managers
            lm_header = soup.find(string=re.compile(r"lead manager", re.I))
            if lm_header:
                parent = lm_header.find_parent(["div", "section", "p", "table"])
                if parent:
                    ol = parent.find_next(["ol", "ul"])
                    if ol:
                        for li in ol.find_all("li"):
                            details["lead_managers"].append(li.get_text(strip=True))

            # 8. DRHP Document Link
            for a in soup.find_all("a", href=True):
                href = a["href"].lower()
                if "drhp" in href or "rhp" in href:
                    details["drhp_url"] = urljoin(detail_url, a["href"])
                    break

        except Exception as e:
            logger.debug(f"DRHP details extraction note for {detail_url}: {e}")

        return details


# ============================================================
# 5. NSE & BSE OFFICIAL EQUITY APIS
# ============================================================

class NseIpoScraper:
    """
    Fetches official NSE public IPO API endpoints:
    Filters strictly for series='EQ' (Mainboard equities).
    """

    BASE_URL = "https://www.nseindia.com"
    ALL_IPO_URL = "https://www.nseindia.com/api/all-ipo-issues"

    def __init__(self, session: requests.Session | None = None):
        self.session = session or requests.Session()

    def fetch_nse_ipos(self) -> list[dict]:
        results = []
        try:
            self.session.get(self.BASE_URL, headers=NSE_HEADERS, timeout=10)
            resp = self.session.get(self.ALL_IPO_URL, headers=NSE_HEADERS, timeout=12)
            if resp.status_code == 200:
                data = resp.json()
                items = data.get("data", []) if isinstance(data, dict) else (data if isinstance(data, list) else [])
                for entry in items:
                    if not isinstance(entry, dict):
                        continue

                    series = entry.get("series", "").strip().upper()
                    if series and series not in ("EQ", "MAINBOARD", ""):
                        continue

                    sym = entry.get("symbol", "").strip()
                    comp_name = clean_company_name(entry.get("companyName") or entry.get("issueName") or sym)
                    if not comp_name or is_sme_ipo(comp_name):
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
            logger.debug(f"NSE IPO API fetch note: {e}")

        return results


# ============================================================
# 6. ENHANCED IPO AGGREGATOR & DEDUPLICATOR
# ============================================================

class IpoAggregator:
    """
    Coordinates all collectors, deduplicates by company slug,
    merges live GMP from IPO Central / Chittorgarh Report 82,
    enriches with DRHP objects & financials, and strictly excludes already listed IPOs.
    """

    def __init__(self, session: requests.Session | None = None):
        self.session = session or requests.Session()
        self.ipocentral_gmp = IpoCentralGmpScraper(self.session)
        self.chittorgarh_gmp = ChittorgarhGmpScraper(self.session)
        self.chittorgarh_issues = ChittorgarhScraper(self.session)
        self.nse = NseIpoScraper(self.session)
        self.drhp_parser = DrhpDetailParser(self.session)

    def collect_all_mainboard_ipos(self) -> list[dict]:
        """Collect and cross-merge Mainboard IPO data from all available sources."""
        today_str = datetime.now(IST).strftime("%Y-%m-%d")
        merged_map: dict[str, dict] = {}

        # 1. Fetch Mainboard Issues from Chittorgarh (Upcoming / Current / Dashboard)
        c_items = self.chittorgarh_issues.fetch_mainboard_ipos(today_str=today_str)
        logger.info(f"Collected {len(c_items)} entries from Chittorgarh Report 82")

        for item in c_items:
            slug = sanitize_slug(item.get("company_name", ""))
            if not slug:
                continue

            merged_map[slug] = {
                "id": slug,
                "company_name": item.get("company_name"),
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
                "gmp": "",
                "gmp_percent": "",
                "est_listing_price": "",
                "listing_price": item.get("listing_price") or "",
                "listing_gain": item.get("listing_gain") or "",
                "kostak": "",
                "sub2sauda": "",
                "subscription": {},
                "registrar": {"name": "", "url": ""},
                "drhp_objects": [],
                "reservation": {},
                "financials": {},
                "kpis": {},
                "promoter_holding": {},
                "lead_managers": [],
                "drhp_url": "",
                "about": "",
                "detail_url": item.get("detail_url") or "",
                "sources": [item.get("source")],
                "is_already_listed": item.get("is_already_listed", False),
                "status": item.get("status", "UPCOMING"),
            }

        # 2. Enrich with Primary Live GMP from IPO Central
        ipoc_gmp_items = self.ipocentral_gmp.fetch_live_gmp()
        logger.info(f"Collected {len(ipoc_gmp_items)} GMP entries from IPO Central")
        for gmp_item in ipoc_gmp_items:
            slug = sanitize_slug(gmp_item.get("company_name", ""))
            if not slug:
                continue

            target = merged_map.get(slug)
            if not target:
                # Add if upcoming or active
                target = {
                    "id": slug,
                    "company_name": gmp_item.get("company_name"),
                    "symbol": "",
                    "issue_type": "Mainboard",
                    "exchange": "NSE & BSE",
                    "open_date": None,
                    "close_date": None,
                    "allotment_date": None,
                    "listing_date": None,
                    "price_band": gmp_item.get("price_band") or "",
                    "issue_size_cr": "",
                    "gmp": gmp_item.get("gmp") or "",
                    "gmp_percent": gmp_item.get("gmp_percent") or "",
                    "kostak": gmp_item.get("kostak") or "",
                    "sub2sauda": gmp_item.get("sub2sauda") or "",
                    "sources": ["ipocentral_gmp"],
                    "is_already_listed": False,
                    "status": "UPCOMING",
                }
                merged_map[slug] = target
            else:
                if gmp_item.get("gmp"):
                    target["gmp"] = gmp_item["gmp"]
                if gmp_item.get("gmp_percent"):
                    target["gmp_percent"] = gmp_item["gmp_percent"]
                if gmp_item.get("kostak"):
                    target["kostak"] = gmp_item["kostak"]
                if gmp_item.get("sub2sauda"):
                    target["sub2sauda"] = gmp_item["sub2sauda"]

        # 3. Enrich with Secondary Live GMP from Chittorgarh Report 82
        c_gmp_items = self.chittorgarh_gmp.fetch_mainboard_gmp()
        logger.info(f"Collected {len(c_gmp_items)} GMP entries from Chittorgarh Report 82")
        for cg in c_gmp_items:
            slug = sanitize_slug(cg.get("company_name", ""))
            if slug in merged_map:
                target = merged_map[slug]
                if not target.get("gmp") and cg.get("gmp"):
                    target["gmp"] = cg["gmp"]
                if not target.get("gmp_percent") and cg.get("gmp_percent"):
                    target["gmp_percent"] = cg["gmp_percent"]
                if not target.get("est_listing_price") and cg.get("est_listing_price"):
                    target["est_listing_price"] = cg["est_listing_price"]
                if not target.get("detail_url") and cg.get("detail_url"):
                    target["detail_url"] = cg["detail_url"]

        # 4. Enrich with NSE Equity data
        nse_items = self.nse.fetch_nse_ipos()
        for ne in nse_items:
            slug = sanitize_slug(ne.get("company_name", ""))
            if slug in merged_map:
                target = merged_map[slug]
                if ne.get("symbol"):
                    target["symbol"] = ne["symbol"]
                if not target.get("open_date") and ne.get("open_date"):
                    target["open_date"] = ne["open_date"]
                if not target.get("close_date") and ne.get("close_date"):
                    target["close_date"] = ne["close_date"]

        # 5. Enrich active/upcoming issues with DRHP objects & financials
        for slug, ipo in merged_map.items():
            if ipo.get("is_already_listed"):
                continue

            detail_url = ipo.get("detail_url")
            if detail_url:
                drhp_data = self.drhp_parser.fetch_drhp_details(detail_url)
                if drhp_data.get("objects_of_issue"):
                    ipo["drhp_objects"] = drhp_data["objects_of_issue"]
                if drhp_data.get("reservation"):
                    ipo["reservation"] = drhp_data["reservation"]
                if drhp_data.get("financials"):
                    ipo["financials"] = drhp_data["financials"]
                if drhp_data.get("kpis"):
                    ipo["kpis"] = drhp_data["kpis"]
                if drhp_data.get("promoter_holding"):
                    ipo["promoter_holding"] = drhp_data["promoter_holding"]
                if drhp_data.get("lead_managers"):
                    ipo["lead_managers"] = drhp_data["lead_managers"]
                if drhp_data.get("drhp_url"):
                    ipo["drhp_url"] = drhp_data["drhp_url"]
                if drhp_data.get("about") and not ipo.get("about"):
                    ipo["about"] = drhp_data["about"]

            # Calculate cut_off_price and min_investment
            price_band = ipo.get("price_band", "")
            lot = ipo.get("lot_size")
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

        return list(merged_map.values())
