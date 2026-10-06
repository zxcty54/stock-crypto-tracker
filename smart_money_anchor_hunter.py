import json
import re
import time
from datetime import datetime, timedelta
import requests

OUTPUT_FILE = "smart_money_anchor_report.json"

BSE_API_URL = "https://api.bseindia.com/BseIndiaAPI/api/AnnSubCategoryGetData/w"

BSE_HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/124.0.0.0 Safari/537.36",
    "Origin": "https://www.bseindia.com",
    "Referer": "https://www.bseindia.com/",
    "Accept": "application/json, text/plain, */*"
}

TIER1_KEYWORDS = [
    "mutual fund", "sbi", "hdfc", "icici", "nippon", "kotak", "tata",
    "whiteoak", "nomura", "fidelity", "goldman", "morgan stanley",
    "gqg", "ashish kacholia", "mukul agrawal", "vijay kedia"
]

def fetch_bse_allotments(days_back=30):
    to_date = datetime.now().strftime("%Y%m%d")
    from_date = (datetime.now() - timedelta(days=days_back)).strftime("%Y%m%d")

    params = {
        "pageno": 1,
        "strCat": "Company Update",
        "strPrevDate": from_date,
        "strScrip": "",
        "strSearch": "P",
        "strToDate": to_date,
        "strType": "C",
        "subcategory": "Allotment of Securities"
    }

    try:
        response = requests.get(BSE_API_URL, headers=BSE_HEADERS, params=params, timeout=12)
        if response.status_code != 200:
            print(f"BSE API returned HTTP {response.status_code}")
            return []

        data = response.json()
        filings = data.get("Table", [])
        extracted = []

        for item in filings:
            details = (item.get("HEADLINE") or "") + " " + (item.get("MORE") or "")
            symbol = item.get("scrip_cd", "")
            company_name = item.get("SLONGNAME", symbol)
            pdf_name = item.get("ATTACHMENTNAME", "")
            pdf_url = f"https://www.bseindia.com/xml-data/corpfiling/AttachLive/{pdf_name}" if pdf_name else ""

            # Extract Issue Price
            price_match = re.search(r'(?:issue\s+price|price\s+of|at\s+a\s+price\s+of)\s*(?:of|at|is)?\s*(?:rs\.?|inr)?\s*([\d,]+(?:\.\d+)?)', details, re.I)
            
            if price_match:
                try:
                    floor_price = float(price_match.group(1).replace(",", ""))
                    is_tier1 = any(k in details.lower() for k in TIER1_KEYWORDS)
                    extracted.append({
                        "symbol": symbol,
                        "company_name": company_name,
                        "cmp": floor_price, # Base CMP placeholder
                        "institutional_floor_price": floor_price,
                        "capital_raised_cr": 0.0,
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
        all_setups = fetch_bse_allotments(days_back=45)
        for item in all_setups:
            if item.get("tier1_backed"):
                prime_setups.append(item)
            else:
                buffer_setups.append(item)
    except Exception as e:
        print(f"Unexpected Execution Error: {e}")

    report = {
        "last_updated": datetime.now().strftime("%Y-%m-%d %H:%M:%S IST"),
        "total_anchors_discovered": len(all_setups),
        "prime_discount_opportunities": len(prime_setups),
        "buffer_safe_entries": len(buffer_setups),
        "prime_setups": prime_setups,
        "buffer_setups": buffer_setups,
        "all_setups": all_setups
    }

    # Hamesha file likhega taaki git add kabhi fail na ho
    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(report, f, ensure_ascii=False, indent=2)

    print(f"✅ Finished! Generated {OUTPUT_FILE} with {len(all_setups)} entries.")

if __name__ == "__main__":
    main()
