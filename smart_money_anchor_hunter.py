import json
import re
import time
from datetime import datetime, timedelta
import requests

OUTPUT_FILE = "smart_money_anchor_report.json"

NSE_HOME = "https://www.nseindia.com"
NSE_ANNOUNCEMENTS_API = "https://www.nseindia.com/api/corporate-announcements"

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
    "Accept": "*/*",
    "Accept-Language": "en-US,en;q=0.9",
    "Referer": "https://www.nseindia.com/companies-listing/corporate-filings-announcements"
}

TIER1_KEYWORDS = [
    "mutual fund", "sbi", "hdfc", "icici", "nippon", "kotak", "tata",
    "whiteoak", "nomura", "fidelity", "goldman", "morgan stanley",
    "gqg", "ashish kacholia", "mukul agrawal", "vijay kedia"
]

def init_nse_session():
    """NSE landing page se verified session cookies generate karta hai."""
    session = requests.Session()
    session.headers.update(HEADERS)
    try:
        res = session.get(NSE_HOME, timeout=15)
        if res.status_code == 200:
            print("🔑 NSE Session cookies initialized successfully.")
        time.sleep(1.5)
    except Exception as e:
        print(f"Warning initializing NSE session: {e}")
    return session

def fetch_nse_allotments(days_back=60):
    session = init_nse_session()
    
    to_date = datetime.now().strftime("%d-%m-%Y")
    from_date = (datetime.now() - timedelta(days=days_back)).strftime("%d-%m-%Y")

    params = {
        "index": "equities",
        "from_date": from_date,
        "to_date": to_date
    }

    try:
        response = session.get(NSE_ANNOUNCEMENTS_API, params=params, timeout=20)
        
        # Retry with delay agar initial delay ho
        if response.status_code != 200:
            print(f"NSE returned {response.status_code}, retrying after 3 seconds...")
            time.sleep(3)
            response = session.get(NSE_ANNOUNCEMENTS_API, params=params, timeout=20)

        if response.status_code != 200:
            print(f"❌ NSE API Error: HTTP {response.status_code}")
            return []

        filings = response.json()
        print(f"📦 Fetched {len(filings)} raw corporate announcements from NSE.")

        extracted = []

        for item in filings:
            subject = item.get("desc") or ""
            att_text = item.get("attchmntText") or ""
            full_text = f"{subject} {att_text}"
            
            # Sirf Allotment, QIP ya Preferential filings filter karein
            if not re.search(r'(?:allotment|qip|preferential|issue\s+price)', full_text, re.I):
                continue

            symbol = item.get("symbol") or ""
            company_name = item.get("sm_name") or symbol
            pdf_url = item.get("attchmntFile") or ""

            # Extract Issue Price (e.g. at Rs. 450 per share / price of Rs 65.50)
            price_match = re.search(
                r'(?:issue\s+price|price\s+of|at\s+a\s+price\s+of|allotment\s+at)\s*(?:of|at|is)?\s*(?:rs\.?|inr)?\s*([\d,]+(?:\.\d+)?)', 
                full_text, 
                re.I
            )

            if price_match:
                try:
                    floor_price = float(price_match.group(1).replace(",", ""))
                    is_tier1 = any(k in full_text.lower() for k in TIER1_KEYWORDS)
                    
                    # Capital raised extraction (e.g. 500 Cr)
                    size_match = re.search(r'([\d,]+(?:\.\d+)?)\s*(?:cr|crore)', full_text, re.I)
                    size_cr = float(size_match.group(1).replace(",", "")) if size_match else 0.0

                    extracted.append({
                        "symbol": symbol,
                        "company_name": company_name,
                        "cmp": floor_price, # Default anchor floor
                        "institutional_floor_price": floor_price,
                        "capital_raised_cr": size_cr,
                        "delta_to_floor_pct": 0.0,
                        "zone": "ACCUMULATION_BUFFER",
                        "zone_label": "Floor Anchor Detected",
                        "tier1_backed": is_tier1,
                        "filing_pdf": pdf_url,
                        "filing_context": full_text[:140]
                    })
                except ValueError:
                    continue

        return extracted
    except Exception as e:
        print(f"Error parsing NSE announcements: {e}")
        return []

def main():
    print("=" * 60)
    print("🚀 Running NSE Smart Money Anchor Hunter...")
    print("=" * 60)

    prime_setups = []
    buffer_setups = []
    all_setups = []

    try:
        all_setups = fetch_nse_allotments(days_back=60)
        for item in all_setups:
            if item.get("tier1_backed"):
                prime_setups.append(item)
            else:
                buffer_setups.append(item)
    except Exception as e:
        print(f"Execution Error: {e}")

    report = {
        "last_updated": datetime.now().strftime("%Y-%m-%d %H:%M:%S IST"),
        "total_anchors_discovered": len(all_setups),
        "prime_discount_opportunities": len(prime_setups),
        "buffer_safe_entries": len(buffer_setups),
        "prime_setups": prime_setups,
        "buffer_setups": buffer_setups,
        "all_setups": all_setups
    }

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(report, f, ensure_ascii=False, indent=2)

    print(f"✅ Finished! Generated {OUTPUT_FILE} with {len(all_setups)} entries.")

if __name__ == "__main__":
    main()
