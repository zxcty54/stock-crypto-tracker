import json
import re
import time
from datetime import datetime, timedelta
import requests

OUTPUT_FILE = "smart_money_anchor_report.json"

BSE_API_URL = "https://api.bseindia.com/BseIndiaAPI/api/AnnSubCategoryGetData/w"

# Complete Chrome 124 browser footprint
BROWSER_HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
    "Accept": "application/json, text/plain, */*",
    "Accept-Language": "en-US,en;q=0.9",
    "Accept-Encoding": "gzip, deflate, br",
    "Origin": "https://www.bseindia.com",
    "Referer": "https://www.bseindia.com/corporates/ann.html",
    "Sec-Ch-Ua": '"Not-A.Brand";v="99", "Chromium";v="124", "Google Chrome";v="124"',
    "Sec-Ch-Ua-Mobile": "?0",
    "Sec-Ch-Ua-Platform": '"Windows"',
    "Sec-Fetch-Dest": "empty",
    "Sec-Fetch-Mode": "cors",
    "Sec-Fetch-Site": "same-site",
    "Connection": "keep-alive"
}

TIER1_KEYWORDS = [
    "mutual fund", "sbi", "hdfc", "icici", "nippon", "kotak", "tata",
    "whiteoak", "nomura", "fidelity", "goldman", "morgan stanley",
    "gqg", "ashish kacholia", "mukul agrawal", "vijay kedia"
]

def create_authenticated_session():
    """BSE landing page visit karke valid cookies gather karta hai taaki 403 block na ho."""
    session = requests.Session()
    session.headers.update(BROWSER_HEADERS)
    try:
        # Step 1: Pre-flight hit on announcements page for authentic session cookies
        landing_url = "https://www.bseindia.com/corporates/ann.html"
        res = session.get(landing_url, timeout=15)
        if res.status_code == 200:
            print("🔑 Successfully initialized BSE session cookies.")
        time.sleep(1.5)
    except Exception as e:
        print(f"Session initialization warning: {e}")
    return session

def fetch_bse_allotments(days_back=45):
    session = create_authenticated_session()
    
    to_date = datetime.now().strftime("%Y%m%d")
    from_date = (datetime.now() - timedelta(days=days_back)).strftime("%Y%m%d")

    params = {
        "pageno": "1",
        "strCat": "Company Update",
        "strPrevDate": from_date,
        "strScrip": "",
        "strSearch": "P",
        "strToDate": to_date,
        "strType": "C",
        "subcategory": "Allotment of Securities"
    }

    try:
        response = session.get(BSE_API_URL, params=params, timeout=20)
        
        # Agar pehla attempt block ho toh backup general query
        if response.status_code == 403:
            print("⚠️ Initial endpoint 403, attempting alternative query route...")
            params["subcategory"] = ""
            params["strSearch"] = "Allotment"
            time.sleep(2)
            response = session.get(BSE_API_URL, params=params, timeout=20)

        if response.status_code != 200:
            print(f"❌ BSE API returned HTTP {response.status_code}")
            return []

        data = response.json()
        filings = data.get("Table", [])
        print(f"📦 Fetched {len(filings)} raw corporate announcements from BSE.")

        extracted = []

        for item in filings:
            head = item.get("NEWSSUB") or ""
            details = f"{item.get('HEADLINE') or ''} {item.get('MORE') or ''}"
            symbol = item.get("scrip_cd") or ""
            company_name = item.get("SLONGNAME") or symbol
            pdf_name = item.get("ATTACHMENTNAME") or ""
            pdf_url = f"https://www.bseindia.com/xml-data/corpfiling/AttachLive/{pdf_name}" if pdf_name else ""

            # Regex: Extract Issue / Allotment Price
            price_match = re.search(
                r'(?:issue\s+price|price\s+of|at\s+a\s+price\s+of|allotment\s+at)\s*(?:of|at|is)?\s*(?:rs\.?|inr)?\s*([\d,]+(?:\.\d+)?)', 
                details, 
                re.I
            )

            if price_match:
                try:
                    floor_price = float(price_match.group(1).replace(",", ""))
                    is_tier1 = any(k in details.lower() for k in TIER1_KEYWORDS)
                    
                    # Capital raised extraction (e.g. Rs 250 Cr)
                    size_match = re.search(r'([\d,]+(?:\.\d+)?)\s*(?:cr|crore)', details, re.I)
                    size_cr = float(size_match.group(1).replace(",", "")) if size_match else 0.0

                    extracted.append({
                        "symbol": symbol,
                        "company_name": company_name,
                        "cmp": floor_price,
                        "institutional_floor_price": floor_price,
                        "capital_raised_cr": size_cr,
                        "delta_to_floor_pct": 0.0,
                        "zone": "ACCUMULATION_BUFFER",
                        "zone_label": "Floor Anchor Detected",
                        "tier1_backed": is_tier1,
                        "filing_pdf": pdf_url,
                        "filing_context": details[:140]
                    })
                except ValueError:
                    continue

        return extracted
    except Exception as e:
        print(f"BSE Fetch Error: {e}")
        return []

def main():
    print("=" * 60)
    print("🚀 Running BSE Smart Money Anchor Hunter...")
    print("=" * 60)

    prime_setups = []
    buffer_setups = []
    all_setups = []

    try:
        all_setups = fetch_bse_allotments(days_back=60)
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
