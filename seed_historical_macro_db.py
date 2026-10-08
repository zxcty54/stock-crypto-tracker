#!/usr/bin/env python3
"""
STRICT GOVERNMENT SCRAPER & HISTORICAL DB HARVESTER
- Crawls live dynamic publication links directly from DPIIT
- Parses real press release tables using 'pdfplumber'
- Zero dummy data / Zero synthetic fallback
- Updates: 'macro_historical_db.json'
"""

import os
import sys
import io
import re
import json
import urllib.request
from datetime import datetime, timezone, timedelta
from bs4 import BeautifulSoup

DB_FILE = "macro_historical_db.json"
IST = timezone(timedelta(hours=5, minutes=30))
NOW = datetime.now(IST)

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9",
    "Connection": "keep-alive"
}

def get_html(url):
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=25) as resp:
        return resp.read().decode("utf-8", errors="ignore")

def download_bytes(url):
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=30) as resp:
        return resp.read()

def discover_dpiit_latest_url():
    """DPIIT home page se latest active Core 8 PDF ka live dynamic link dhoondta hai."""
    print("🔍 Crawling DPIIT portal for dynamic Core 8 publication link...")
    base_domain = "https://eaindustry.nic.in"
    html = get_html(base_domain)
    soup = BeautifulSoup(html, "html.parser")

    discovered_url = None
    for link in soup.find_all("a", href=True):
        href = link["href"].strip()
        text = link.get_text().lower()
        if "core" in href.lower() or "eight" in text or "core" in text:
            if href.endswith(".pdf"):
                discovered_url = href if href.startswith("http") else f"{base_domain}/{href.lstrip('/')}"
                print(f"   🎯 Discovered live release: {discovered_url}")
                break

    if not discovered_url:
        raise FileNotFoundError("Could not dynamically resolve active Eight Core Industries link from DPIIT landing page.")

    return discovered_url

def parse_core8_data(url):
    print(f"📦 Fetching live content from: {url}")
    import pdfplumber

    content = download_bytes(url)
    cement_val = None
    steel_val = None
    cement_index = None
    steel_index = None
    period_str = None

    with pdfplumber.open(io.BytesIO(content)) as pdf:
        print(f"   📄 Scanning {len(pdf.pages)} pages in Core 8 release...")

        # Strategy 1: Structured Table Extraction (Detects Cell Boundaries)
        for page_idx, page in enumerate(pdf.pages):
            text_raw = page.extract_text() or ""
            if not period_str:
                month_match = re.search(r"for\s+([A-Za-z]+),\s+(202\d)", text_raw, re.IGNORECASE)
                if month_match:
                    period_str = f"{month_match.group(1)} {month_match.group(2)}"

            tables = page.extract_tables() or []
            for tbl in tables:
                for row in tbl:
                    if not row:
                        continue
                    # Footnotes (*, ^) aur spaces strip karna
                    row_clean = [re.sub(r"[\*\^\#]", "", str(c or "")).strip() for c in row if c is not None]
                    row_str = " ".join(row_clean).lower()

                    # Find cement row
                    if "cement" in row_str and not cement_val:
                        nums = [float(n) for n in re.findall(r"\b\d+\.?\d*\b", " ".join(row_clean)) if float(n) > 0]
                        for
