import json
import re
import time
from datetime import datetime, timedelta
import requests

OUTPUT_FILE = "smart_money_anchor_report.json"

NSE_HOME = "https://www.nseindia.com"
NSE_ANNOUNCEMENTS_API = "https://www.nseindia.com/api/corporate-announcements"
NSE_QUOTE_API = "https://www.nseindia.com/api/quote-equity?symbol="

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
    session = requests.Session()
    session.headers.update(HEADERS)
    try:
        session.get(NSE_HOME, timeout=15)
        time.sleep(1.0)
    except Exception as e:
        print(f"Warning session init: {e}")
    return session

def get_live_cmp(session, symbol):
    """NSE equity quote API se live market price fetch karta hai."""
    try:
        url = f"{NSE_QUOTE_API}{requests.utils.quote(symbol)}"
        res = session.get(url, timeout=6)
        if res.status_code == 200:
            data = res.json()
            return float(data.get("priceInfo", {}).get("lastPrice", 0.0))
    except Exception:
        pass
    return 0.0

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
        if response.status_code != 200:
            time.sleep(2)
            response = session.get(NSE_ANNOUNCEMENTS_API, params=params, timeout=20)

        if response.status_code != 200:
            return []

        filings = response.json()
        raw_candidates = []
        seen_symbols = set()

        for item in filings:
            subject = item.get("desc") or ""
            att_text = item.get("attchmntText") or ""
            full_text = f"{subject} {att_text}"
            
            # Reject cancellations and withdrawals
            if re.search(r'(?:cancellation|withdrawal|withdrawn|cancelled)', full_text, re.I):
                continue

            # Must contain allotment / placement / issue keyword
            if not re.search(r'(?:allotment|qip|preferential|rights\s+issue|issue\s+price)', full_text, re.I):
                continue

            symbol = item.get("symbol") or ""
            if not symbol or symbol in seen_symbols:
                continue

            company_name = item.get("sm_name") or symbol
            pdf_url = item.get("attchmntFile") or ""

            # Extract Issue Price
            price_match = re.search(
                r'(?:issue\s+price|price\s+of|at\s+a\s+price\s+of|allotment\s+at)\s*(?:of|at|is)?\s*(?:rs\.?|inr)?\s*([\d,]+(?:\.\d+)?)', 
                full_text, 
                re.I
            )

            if price_match:
                try:
                    floor_price = float(price_match.group(1).replace(",", ""))
                    if floor_price <= 0:
                        continue

                    is_tier1 = any(k in full_text.lower() for k in TIER1_KEYWORDS)
                    
                    # Capital raised extraction
                    size_match = re.search(r'([\d,]+(?:\.\d+)?)\s*(?:cr|crore)', full_text, re.I)
                    size_cr = float(size_match.group(1).replace(",", "")) if size_match else 0.0

                    seen_symbols.add(symbol)
                    raw_candidates.append({
                        "symbol": symbol,
                        "company_name": company_name,
                        "floor_price": floor_price,
                        "size_cr": size_cr,
                        "is_tier1": is_tier1,
                        "pdf_url": pdf_url,
                        "context": full_text[:140]
                    })
                except ValueError:
                    continue

        processed = []
        print(f"🔍 Fetching live CMP for {len(raw_candidates)} qualified companies...")

        for cand in raw_candidates:
            symbol = cand["symbol"]
            floor = cand["floor_price"]
            
            live_price = get_live_cmp(session, symbol)
            # Fallback agar quote market closed/delayed ho
            cmp_val = live_price if live_price > 0 else floor

            delta_pct = round(((cmp_val - floor) / floor) * 100, 2)

            # Zone classification
            if delta_pct < 0:
                zone = "PRIME_DISCOUNT"
                zone_label = f"{abs(delta_pct)}% Below Smart Money"
            elif delta_pct <= 6.0:
                zone = "ACCUMULATION_BUFFER"
                zone_label = f"+{delta_pct}% Near Floor"
            elif delta_pct <= 25.0:
                zone = "EXTENDED"
                zone_label = f"+{delta_pct}% Extended"
            else:
                zone = "OVERBOUGHT"
                zone_label = f"+{delta_pct}% High Exhaustion"

            processed.append({
                "symbol": symbol,
                "company_name": cand["company_name"],
                "cmp": cmp_val,
                "institutional_floor_price": floor,
                "capital_raised_cr": cand["size_cr"],
                "delta_to_floor_pct": delta_pct,
                "zone": zone,
                "zone_label": zone_label,
                "tier1_backed": cand["is_tier1"],
                "filing_pdf": cand["pdf_url"],
                "filing_context": cand["context"]
            })
            time.sleep(0.3)

        return processed
    except Exception as e:
        print(f"Error parsing announcements: {e}")
        return []

def main():
    print("=" * 60)
    print("🚀 Running NSE Smart Money Floor Pipeline with Live Quotes...")
    print("=" * 60)

    prime_setups = []
    buffer_setups = []
    all_setups = []

    try:
        all_setups = fetch_nse_allotments(days_back=60)
        for item in all_setups:
            if item["zone"] == "PRIME_DISCOUNT":
                prime_setups.append(item)
            elif item["zone"] == "ACCUMULATION_BUFFER":
                buffer_setups.append(item)
    except Exception as e:
        print(f"Execution Error: {e}")

    prime_setups.sort(key=lambda x: x["delta_to_floor_pct"])
    buffer_setups.sort(key=lambda x: x["delta_to_floor_pct"])

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

    print(f"✅ Generated {OUTPUT_FILE}: {len(prime_setups)} Prime Discounts, {len(buffer_setups)} Buffer entries.")

if __name__ == "__main__":
    main()
