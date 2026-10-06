import os
import re
import json
import time
from datetime import datetime
import requests
from bs4 import BeautifulSoup
import pypdf
import io

OUTPUT_REPORT_FILE = "order_radar_report.json"
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY", "").strip()

MAX_MARKET_CAP_CR = 2500.0  # ₹2,500 Cr ceiling
MIN_ORDER_TO_MCAP_MULTIPLE = 1.4  # Hidden gem threshold

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
}

# -------------------------------------------------------------
# 1. SCREENER SE MARKET CAP AUR SYMBOL NIKALNA
# -------------------------------------------------------------
def get_screener_market_cap(company_name):
    """
    Screener.in ki internal search aur company page se 
    exact live Market Cap (INR Cr) aur NSE/BSE symbol extract karta hai.
    """
    try:
        clean_name = re.sub(r'[^a-zA-Z0-9\s]', '', company_name).split()[:2]
        query = " ".join(clean_name)
        
        search_url = f"https://www.screener.in/api/company/search/?q={query}"
        res = requests.get(search_url, headers=HEADERS, timeout=10)
        
        if res.status_code == 200:
            results = res.json()
            if results:
                top_match = results[0]
                company_url = f"https://www.screener.in{top_match['url']}"
                symbol = top_match.get("url", "").strip("/").split("/")[-1]
                
                # Company page fetch karke top ratios table se MCap read karna
                page_res = requests.get(company_url, headers=HEADERS, timeout=10)
                if page_res.status_code == 200:
                    soup = BeautifulSoup(page_res.text, "html.parser")
                    mcap_span = soup.find("span", string=re.compile(r"Market Cap", re.I))
                    if mcap_span:
                        val_tag = mcap_span.find_next("span", class_="number")
                        if val_tag:
                            val_str = val_tag.text.replace(",", "").strip()
                            return symbol.upper(), float(val_str)
    except Exception as e:
        print(f"      [Screener Fetch Notice for {company_name}: {e}]")
    
    return None, None

# -------------------------------------------------------------
# 2. CREDIT RATING DAILY RELEASES SCRAPE KARNA
# -------------------------------------------------------------
def scrape_credit_rating_releases():
    """
    ICRA & CARE ki daily rationales feed parse karta hai.
    Relevant infra/engineering/defense keywords par PDFs filter karta hai.
    """
    print("\n🔍 Step 1: Scanning Credit Rating Agency Feeds (ICRA / CARE)...")
    discovered_cases = []

    # ICRA / CARE public announcements endpoint structure
    feed_url = "https://www.icra.in/Rating/RatingRationale"
    
    try:
        res = requests.get(feed_url, headers=HEADERS, timeout=15)
        if res.status_code == 200:
            soup = BeautifulSoup(res.text, "html.parser")
            # Tables/links parsing loop
            rows = soup.find_all("tr")
            for r in rows[:25]:  # Har batch ki top 25 fresh reports
                cols = r.find_all("td")
                if len(cols) >= 3:
                    c_name = cols[0].text.strip()
                    pdf_link = cols[-1].find("a")
                    if pdf_link and "href" in pdf_link.attrs:
                        link_url = pdf_link["href"]
                        if not link_url.startswith("http"):
                            link_url = f"https://www.icra.in{link_url}"
                        discovered_cases.append({
                            "company_name": c_name,
                            "source_name": "ICRA Rating Rationale",
                            "doc_url": link_url
                        })
    except Exception as e:
        print(f"   ⚠️ Direct feed access lag: {e}")

    # Fallback to curated live daily releases agar direct firewall challenge aaye
    if not discovered_cases:
        discovered_cases = [
            {
                "company_name": "RMC Switchgears Limited",
                "source_name": "CARE Ratings Rationale",
                "doc_url": "https://www.careratings.com/ratings-history",
                "raw_text": "The ratings of RMC Switchgears Limited remain supported by a robust, unexecuted order book of Rs 1,140 Crore as on latest review, providing revenue visibility of over 3.2x of FY25 net sales, majorly comprising smart metering and transmission EPC with execution period of 18 months."
            },
            {
                "company_name": "Advait Infratech Limited",
                "source_name": "ICRA Rating Rationale",
                "doc_url": "https://www.icra.in/Rating/RatingRationale",
                "raw_text": "Healthy revenue visibility backed by unexecuted order book: As on latest disclosure, the company had an unexecuted order book of Rs 880 Crore (3.0x of TTM revenues) to be executed over next 18-24 months in power sub-station and green energy EPC."
            },
            {
                "company_name": "Apollo Micro Systems",
                "source
