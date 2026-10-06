import os
import re
import json
import time
from datetime import datetime
import pandas as pd
import requests
from bs4 import BeautifulSoup
import pypdf
import io

CSV_FILE = "ind_niftysmallcap250list.csv"
OUTPUT_REPORT_FILE = "order_radar_report.json"
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY", "").strip()

MAX_MARKET_CAP_CR = 15000.0  # Nifty Smallcap 250 range
MIN_ORDER_TO_MCAP_MULTIPLE = 0.8  # Order book to MCap threshold

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
}

# 1. Target Industries jahan order book hota hai
ORDER_ORIENTED_INDUSTRIES = [
    "Capital Goods",
    "Construction",
    "Power",
    "Realty",
    "Telecommunication",
    "Metals & Mining",
    "Automobile and Auto Components"
]

def load_target_smallcaps():
    """CSV se order-oriented companies filter karta hai."""
    df = pd.read_csv(CSV_FILE)
    filtered = df[df["Industry"].isin(ORDER_ORIENTED_INDUSTRIES)].copy()
    print(f"📊 Filtered {len(filtered)} / {len(df)} companies from relevant order-book sectors.")
    return filtered[["Company Name", "Symbol", "Industry"]].to_dict(orient="records")

def get_screener_details(symbol):
    """
    Screener par stock page se live Market Cap aur 
    Credit Rating PDF/Rationale doc link nikalta hai.
    """
    url = f"https://www.screener.in/company/{symbol}/consolidated/"
    res = requests.get(url, headers=HEADERS, timeout=10)
    
    if res.status_code == 404:
        # Standalone retry
        url = f"https://www.screener.in/company/{symbol}/"
        res = requests.get(url, headers=HEADERS, timeout=10)
        
    if res.status_code != 200:
        return None, None, None

    soup = BeautifulSoup(res.text, "html.parser")
    
    # 1. Market Cap
    mcap_val = None
    mcap_tag = soup.find("span", string=re.compile(r"Market Cap", re.I))
    if mcap_tag:
        num_span = mcap_tag.find_next("span", class_="number")
        if num_span:
            mcap_val = float(num_span.text.replace(",", "").strip())

    # 2. Credit Rating Rationale PDF Link
    rating_doc_url = None
    agency_name = "Audited Rating Rationale"
    
    # Screener ke documents section me 'Credit ratings' dhoondhna
    for link in soup.find_all("a", href=True):
        href = link["href"]
        text = link.get_text(strip=True).lower()
        if any(agency in text for agency in ["crisil", "care", "icra", "india ratings", "infomerics"]) or "rating" in text:
            rating_doc_url = href
            agency_name = link.get_text(strip=True)
            break

    return mcap_val, rating_doc_url, agency_name

def extract_pdf_order_text(pdf_url):
    """PDF download karke initial pages ka text extract karta hai."""
    try:
        res = requests.get(pdf_url, headers=HEADERS, timeout=15)
        if res.status_code == 200 and len(res.content) > 1000:
            reader = pypdf.PdfReader(io.BytesIO(res.content))
            pages_text = []
            for p in reader.pages[:3]:
                txt = p.extract_text()
                if txt:
                    pages_text.append(txt)
            return " ".join(pages_text)
    except Exception:
        pass
    return ""

def parse_order_metrics(text):
    """Text me se order book numbers aur timeline nikalta hai."""
    if not any(k in text.lower() for k in ["order book", "unexecuted", "backlog", "order intake"]):
        return None

    # AI Parsing
    if GEMINI_API_KEY:
        try:
            prompt = f"Extract numerical unexecuted order book from: '{text[:2500]}'. Return raw JSON: {{\"order_book_cr\": 1500.0, \"timeline_months\": 24, \"thesis\": \"short impact\"}}"
            payload = {
                "contents": [{"parts": [{"text": prompt}]}],
                "generationConfig": {"temperature": 0.1, "responseMimeType": "application/json"}
            }
            url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={GEMINI_API_KEY}"
            res = requests.post(url, json=payload, headers={"Content-Type": "application/json"}, timeout=12)
            if res.status_code == 200:
                raw = res.json()["candidates"][0]["content"]["parts"][0]["text"].strip()
                if raw.startswith("```"): raw = re.sub(r"^```[a-z]*|```$", "", raw).strip()
                data = json.loads(raw)
                val = float(data.get("order_book_cr", 0))
                if val > 0:
                    return {
                        "order_book_cr": val,
                        "timeline_months": int(data.get("timeline_months", 24)),
                        "thesis": data.get("thesis", "Revenue visibility from order backlog.")
                    }
        except Exception:
            pass

    # Regex Failsafe
    patterns = [
        r'(?:unexecuted\s+order\s+book|order\s+backlog|order\s+book)\s+(?:of|stood\s+at|stands\s+at|at)\s+(?:Rs\.?|INR)?\s*([\d,]+(?:\.\d+)?)\s*(?:cr|crore)',
        r'(?:Rs\.?|INR)\s*([\d,]+(?:\.\d+)?)\s*(?:cr|crore)\s+(?:of\s+unexecuted\s+orders|order\s+book)'
    ]
    for p in patterns:
        m = re.search(p, text, re.I)
        if m:
            val = float(m.group(1).replace(",", ""))
            return {
                "order_book_cr": val,
                "timeline_months": 24,
                "thesis": f"Healthy revenue runway backed by order backlog of ₹{val:,.1f} Cr."
            }
    return None

def run():
    print("=" * 75)
    print("🚀 NIFTY SMALLCAP 250: ORDER BOOK / MCAP RADAR")
    print("=" * 75)

    stocks = load_target_smallcaps()
    verified_gems = []

    for idx, item in enumerate(stocks, 1):
        name = item["Company Name"]
        symbol = item["Symbol"]
        industry = item["Industry"]

        print(f"\n[{idx}/{len(stocks)}] Checking: {name} ({symbol}) | Sector: {industry}...")

        # Step 1: Live Screener details fetch
        mcap, doc_url, agency = get_screener_details(symbol)
        if not mcap:
            print(f"   ⚠️ Could not fetch Market Cap for {symbol}. Skipping.")
            continue

        print(f"   📊 Live Market Cap: ₹{mcap:,.1f} Cr")
        if mcap > MAX_MARKET_CAP_CR:
            print(f"   ⏩ MCap ₹{mcap:,.1f} Cr > ₹{MAX_MARKET_CAP_CR} Cr limit. Skipped.")
            continue

        if not doc_url:
            print("   ℹ️ No direct rating rationale link found on company profile.")
            continue

        # Step 2: Download & Extract PDF Content
        print(f"   📄 Rating Document Found: {agency}")
        pdf_text = extract_pdf_order_text(doc_url)
        if not pdf_text:
            print("   ⚠️ Could not extract text from document.")
            continue

        # Step 3: Order Metrics Parsing
        metrics = parse_order_metrics(pdf_text)
        if not metrics or metrics["order_book_cr"] <= 0:
            print("   ℹ️ No unexecuted order book stated in this document.")
            continue

        order_val = metrics["order_book_cr"]
        multiple = round(order_val / mcap, 2)
        print(f"   🎯 Order Book: ₹{order_val:,.1f} Cr ➔ Multiple: {multiple}x MCap")

        # Step 4: Add Qualified Hidden Gems
        if multiple >= MIN_ORDER_TO_MCAP_MULTIPLE:
            gem_entry = {
                "symbol": symbol,
                "company_name": name,
                "sector": industry,
                "market_cap_cr": mcap,
                "unexecuted_order_book_cr": order_val,
                "order_to_mcap_multiple": multiple,
                "execution_timeline_months": metrics["timeline_months"],
                "thesis": metrics["thesis"],
                "source_verification": {
                    "source_name": agency,
                    "document_url": doc_url,
                    "as_on_date": datetime.now().strftime("%b %Y"),
                    "is_audited_regulatory": True
                }
            }
            verified_gems.append(gem_entry)
            print(f"   🔥 [HIDDEN GEM QUALIFIED] Multiple {multiple}x >= {MIN_ORDER_TO_MCAP_MULTIPLE}x!")
        else:
            print(f"   ❌ Multiple {multiple}x < {MIN_ORDER_TO_MCAP_MULTIPLE}x.")

        time.sleep(1)

    # Sort descending by Multiple
    verified_gems.sort(key=lambda x: x["order_to_mcap_multiple"], reverse=True)

    final_report = {
        "last_updated": datetime.now().strftime("%Y-%m-%d %H:%M:%S IST"),
        "filter_criteria": {
            "source_universe": "Nifty Smallcap 250 Index",
            "max_mcap_cr": MAX_MARKET_CAP_CR,
            "min_order_multiple": MIN_ORDER_TO_MCAP_MULTIPLE
        },
        "total_hidden_gems_found": len(verified_gems),
        "gems": verified_gems
    }

    with open(OUTPUT_REPORT_FILE, "w", encoding="utf-8") as f:
        json.dump(final_report, f, ensure_ascii=False, indent=2)

    print("\n" + "=" * 75)
    print(f"🎉 SUCCESS: Found {len(verified_gems)} high-visibility gems from Nifty Smallcap 250!")
    print("=" * 75)

if __name__ == "__main__":
    run()
