import os
import re
import json
import time
from datetime import datetime, timedelta
import urllib.parse
import io
import requests
from bs4 import BeautifulSoup
import pypdf

OUTPUT_REPORT_FILE = "order_radar_report.json"
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY", "").strip()

MAX_MARKET_CAP_CR = 5000.0
MIN_ORDER_TO_MCAP_MULTIPLE = 1.0

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
    "Accept": "application/json, text/plain, */*",
    "Accept-Language": "en-US,en;q=0.9",
}

# -------------------------------------------------------------
# 1. CARE RATINGS DIRECT PUBLIC API SCRAPER
# -------------------------------------------------------------
def fetch_care_daily_rationales():
    """
    CARE Ratings ke live public API endpoint se recent rating rationales fetch karta hai.
    Zero hardcoding: daily published rationales ko dynamic read karega.
    """
    print("\n🔍 Fetching dynamic rationales from CARE Ratings portal...")
    discovered = []
    
    # CARE live reports listing endpoint
    api_url = "https://www.careratings.com/api/get-ratings-history"
    
    payload = {
        "page": 1,
        "limit": 50,
        "sector": "",
        "keyword": ""
    }
    
    try:
        res = requests.post(api_url, json=payload, headers=HEADERS, timeout=15)
        if res.status_code == 200:
            data = res.json()
            items = data.get("data", []) or data.get("items", [])
            for item in items:
                c_name = item.get("company_name") or item.get("companyName")
                pdf_url = item.get("pdf_url") or item.get("doc_path")
                if c_name and pdf_url:
                    if not pdf_url.startswith("http"):
                        pdf_url = f"https://www.careratings.com{pdf_url}"
                    discovered.append({
                        "company_name": c_name.strip(),
                        "doc_url": pdf_url,
                        "agency": "CARE Ratings Rationale"
                    })
    except Exception as e:
        print(f"   ⚠️ CARE direct API notice: {e}")

    # Fallback to ICRA public listing endpoint
    if not discovered:
        print("   🔍 Checking ICRA public releases table...")
        icra_url = "https://www.icra.in/Rating/RatingRationale"
        try:
            res = requests.get(icra_url, headers=HEADERS, timeout=15)
            if res.status_code == 200:
                soup = BeautifulSoup(res.text, "html.parser")
                for link in soup.find_all("a", href=True):
                    href = link["href"]
                    if "/Rationale/ShowRationaleReport" in href or href.endswith(".pdf"):
                        text = link.get_text(strip=True)
                        if len(text) > 3:
                            full_url = href if href.startswith("http") else f"https://www.icra.in{href}"
                            discovered.append({
                                "company_name": text,
                                "doc_url": full_url,
                                "agency": "ICRA Rating Rationale"
                            })
        except Exception as e:
            print(f"   ⚠️ ICRA scrape notice: {e}")

    print(f"✅ Discovered {len(discovered)} recent rating rationale publications.")
    return discovered

# -------------------------------------------------------------
# 2. PDF TEXT EXTRACTION
# -------------------------------------------------------------
def extract_text_from_pdf(pdf_url):
    """PDF ke initial pages download karke unexecuted order book section extract karta hai."""
    try:
        res = requests.get(pdf_url, headers=HEADERS, timeout=15)
        if res.status_code == 200 and len(res.content) > 1000:
            reader = pypdf.PdfReader(io.BytesIO(res.content))
            extracted_pages = []
            # Rating rationales ke pehle 2-3 pages me hi key financial drivers hote hain
            for page in reader.pages[:3]:
                extracted_pages.append(page.extract_text() or "")
            return " ".join(extracted_pages)
    except Exception:
        pass
    return ""

# -------------------------------------------------------------
# 3. SCREENER LIVE MARKET CAP LOOKUP
# -------------------------------------------------------------
def get_screener_data(company_name):
    """Screener API se exact listed symbol aur Market Cap read karta hai."""
    try:
        clean = re.sub(r'(?i)\b(ltd|limited|pvt|private|india|\(india\))\b', '', company_name)
        clean = re.sub(r'[^a-zA-Z0-9\s]', '', clean).strip()
        tokens = clean.split()[:2]
        query = urllib.parse.quote(" ".join(tokens))

        url = f"https://www.screener.in/api/company/search/?q={query}"
        
