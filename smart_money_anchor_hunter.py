import json
import re
import time
from datetime import datetime, timedelta
import requests

OUTPUT_FILE = "smart_money_anchor_report.json"

NSE_HOME = "https://www.nseindia.com"
NSE_ANNOUNCEMENTS_API = "https://www.nseindia.com/api/corporate-announcements"

NSE_HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
    "Accept": "*/*",
    "Accept-Language": "en-US,en;q=0.9",
    "Referer": "https://www.nseindia.com/companies-listing/corporate-filings-announcements"
}

YFIN_HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
}

# Institutional Tiers Directory for Regex Matching
INSTITUTIONAL_DIRECTORY = {
    "Tier-1 DII / MF": [
        "sbi mutual", "hdfc mutual", "icici prudential", "nippon india",
        "kotak mutual", "kotak emerging", "tata mutual", "mirae asset",
        "dsp mutual", "uti mutual", "axis mutual", "bandhan mutual",
        "whiteoak capital", "motilal oswal mutual", "franklin templeton"
    ],
    "Marquee FII / Sovereign": [
        "gqg partners", "nomura", "morgan stanley", "goldman sachs",
        "fidelity", "adia", "abu dhabi investment", "norges bank",
        "societe generale", "bnp paribas", "citigroup", "blackrock"
    ],
    "Marquee HNI": [
        "ashish kacholia", "mukul agrawal", "vijay kedia", "dolly khanna",
        "porinju veliyath", "madhusudan kela", "madhu kela", "nemish shah",
        "radhakishan damani", "sunil singhania", "abakkus"
    ]
}

def init_nse_session():
    session = requests.Session()
    session.headers.update(NSE_HEADERS)
    try:
        session.get(NSE_HOME, timeout=15)
        time.sleep(1.0)
    except Exception as e:
        print(f"Warning session init: {e}")
    return session

def fetch_financial_metrics(symbol):
    """Yahoo Finance se CMP aur Market Cap (in Cr) fetch karta hai."""
    clean_sym = symbol.replace("&", "%26").strip()
    candidates = [f"{clean_sym}.NS", f"{clean_sym}.BO"]

    for ticker in candidates:
        url = f"https://query1.finance.yahoo.com/v8/finance/chart/{ticker}?interval=1d&range=1d"
        try:
            res = requests.get(url, headers=YFIN_HEADERS, timeout=6)
            if res.status_code == 200:
                data = res.json()
                meta = data.get("chart", {}).get("result", [{}])[0].get("meta", {})
                price = meta.get("regularMarketPrice") or meta.get("chartPreviousClose")
                mcap_raw = meta.get("marketCap", 0)
                mcap_cr = round(mcap_raw / 10000000, 2) if mcap_raw else 0.0

                if price and float(price) > 0:
                    return round(float(price), 2), mcap_cr
        except Exception:
            continue
    return 0.0, 0.0

def extract_allottees(text):
    """Filing text se Tier-1 Institutional aur Marquee investors ko match karta hai."""
    found_allottees = []
    text_lower = text.lower()

    for tier, names in INSTITUTIONAL_DIRECTORY.items():
        for name in names:
            if name in text_lower:
                clean_title = " ".join(w.capitalize() for w in name.split())
                found_allottees.append({
                    "name": clean_title,
                    "tier": tier
                })

    unique_allottees = []
    seen = set()
    for a in found_allottees:
        if a["name"] not in seen:
            seen.add(a["name"])
            unique_allottees.append(a)

    return unique_allottees

def extract_deal_size_cr(text, shares_count=0, floor_price=0.0):
    """Total capital raised in Crores extract karta hai."""
    cr_match = re.search(r'(?:aggregating\s+up\s+to|sum\s+of|total\s+amount\s+of|worth)?\s*(?:rs\.?|inr)?\s*([\d,]+(?:\.\d+)?)\s*(?:cr|crore|crores)', text, re.I)
    if cr_match:
        try:
            val = float(cr_match.group(1).replace(",", ""))
            if 0.5 <= val <= 50000:
                return round(val, 2)
        except ValueError:
            pass

    if shares_count > 0 and floor_price > 0:
        total_cr = round((shares_count * floor_price) / 10000000, 2)
        if 0.5 <= total_cr <= 50000:
            return total_cr

    return 0.0

def fetch_institutional_anchors(days_back=60):
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
            
            # Strict rejection: Rights, ESOP, warrants, bonus, loans
            if re.search(r'(?:rights\s+issue|esop|sweat\s+equity|bonus\s+shares|warrant|debt\s+conversion|loan\s+conversion|remuneration|audit\s+committee|cancellation|withdrawn)', full_text, re.I):
                continue

            # Pure QIP or Preferential allotment of equity shares
            is_qip = bool(re.search(r'\bqip\b|qualified\s+institutions\s+placement', full_text, re.I))
            is_pref = bool(re.search(r'preferential\s+(?:allotment|issue).*(?:equity\s+shares)', full_text, re.I)) or bool(re.search(r'allotment\s+of\s+.*equity\s+shares', full_text, re.I))

            if not (is_qip or is_pref):
                continue

            deal_type = "QIP (Institutions Only)" if is_qip else "Preferential Equity Allotment"

            symbol = item.get("symbol") or ""
            if not symbol or symbol in seen_symbols:
                continue

            company_name = item.get("sm_name") or symbol
            pdf_url = item.get("attchmntFile") or ""

            price_match = re.search(
                r'(?:issue\s+price|price\s+of|at\s+a\s+price\s+of|allotment\s+at)\s*(?:of|at|is)?\s*(?:rs\.?|inr)?\s*([\d,]+(?:\.\d+)?)', 
                full_text, 
                re.I
            )

            shares_match = re.search(r'([\d,]+)\s*(?:equity\s+shares|shares)', full_text, re.I)
            shares_count = 0
            if shares_match:
                try:
                    shares_count = int(shares_match.group(1).replace(",", ""))
                except ValueError:
                    shares_count = 0

            if price_match:
                try:
                    floor_price = float(price_match.group(1).replace(",", ""))
                    
                    # Cutoff: Penny stock guard
                    if floor_price < 15.0:
                        continue

                    deal_size_cr = extract_deal_size_cr(full_text, shares_count, floor_price)
                    allottees = extract_allottees(full_text)

                    seen_symbols.add(symbol)
                    raw_candidates.append({
                        "symbol": symbol,
                        "company_name": company_name,
                        "deal_type": deal_type,
                        "floor_price": floor_price,
                        "capital_raised_cr": deal_size_cr,
                        "allottees": allottees,
                        "pdf_url": pdf_url,
                        "context": full_text[:160]
                    })
                except ValueError:
                    continue

        processed = []
        print(f"🔍 Screening {len(raw_candidates)} Institutional / QIP candidates with market depth...")

        for cand in raw_candidates:
            symbol = cand["symbol"]
            floor = cand["floor_price"]
            
            cmp_val, mcap_cr = fetch_financial_metrics(symbol)
            if cmp_val <= 0 or cmp_val < 15.0:
                continue

            # Deal size as % of Market Cap
            deal_pct_of_mcap = round((cand["capital_raised_cr"] / mcap_cr * 100), 2) if mcap_cr > 0 else 0.0

            # ==========================================
            # MINIMUM 1% DEAL SIZE CUTOFF FILTER
            # ==========================================
            # Agar Market Cap available hai aur deal size 1% se kam hai, toh ignore karo
            if mcap_cr > 0 and cand["capital_raised_cr"] > 0:
                if deal_pct_of_mcap < 1.0:
                    print(f"⏩ Dropping {symbol}: Deal size {deal_pct_of_mcap}% is below 1% threshold.")
                    continue

            delta_pct = round(((cmp_val - floor) / floor) * 100, 2)
            has_tier1 = len(cand["allottees"]) > 0 or "QIP" in cand["deal_type"]
            
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

            entry = {
                "symbol": symbol,
                "company_name": cand["company_name"],
                "deal_type": cand["deal_type"],
                "cmp": cmp_val,
                "institutional_floor_price": floor,
                "capital_raised_cr": cand["capital_raised_cr"],
                "market_cap_cr": mcap_cr,
                "deal_size_pct_mcap": deal_pct_of_mcap,
                "delta_to_floor_pct": delta_pct,
                "zone": zone,
                "zone_label": zone_label,
                "tier1_backed": has_tier1,
                "allottees": cand["allottees"],
                "filing_pdf": cand["pdf_url"],
                "filing_context": cand["context"]
            }

            print(f"✨ [{cand['deal_type']}] {symbol} | Floor: ₹{floor} | CMP: ₹{cmp_val} | Delta: {delta_pct}% | Deal: {deal_pct_of_mcap}% of Mcap")
            processed.append(entry)
            time.sleep(0.2)

        return processed
    except Exception as e:
        print(f"Error in pipeline: {e}")
        return []

def main():
    print("=" * 65)
    print("💎 RUNNING INSTITUTIONAL SMART MONEY ALPHA ENGINE (QIP / PREF ONLY)")
    print("=" * 65)

    prime_setups = []
    buffer_setups = []
    all_setups = []

    try:
        all_setups = fetch_institutional_anchors(days_back=60)
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

    print(f"\n🏆 Pipeline Finished cleanly!")
    print(f"• Prime Discounts: {len(prime_setups)}")
    print(f"• Buffer Setups: {len(buffer_setups)}")
    print(f"• Total Qualified Institutions: {len(all_setups)}")

if __name__ == "__main__":
    main()
