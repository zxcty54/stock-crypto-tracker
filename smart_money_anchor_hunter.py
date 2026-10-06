import io
import json
import re
import time
from datetime import datetime, timedelta
import requests
from pypdf import PdfReader

OUTPUT_FILE = "smart_money_anchor_report.json"

NSE_HOME = "https://www.nseindia.com"
NSE_ANNOUNCEMENTS_API = "https://www.nseindia.com/api/corporate-announcements"

NSE_HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
    "Accept": "application/json,text/html,*/*",
    "Accept-Language": "en-US,en;q=0.9",
    "Referer": "https://www.nseindia.com/companies-listing/corporate-filings-announcements"
}

YFIN_HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
    "Accept": "*/*"
}

INSTITUTIONAL_DIRECTORY = {
    "Tier-1 DII / MF": [
        "sbi mutual", "hdfc mutual", "icici prudential", "nippon india",
        "kotak mutual", "kotak emerging", "kotak mahindra", "tata mutual",
        "mirae asset", "dsp mutual", "uti mutual", "axis mutual",
        "bandhan mutual", "whiteoak", "motilal oswal", "franklin templeton",
        "quant mutual", "invesco", "canara robeco", "sundaram"
    ],
    "Marquee FII / Sovereign": [
        "gqg partners", "nomura", "morgan stanley", "goldman sachs",
        "fidelity", "adia", "abu dhabi investment", "norges bank",
        "societe generale", "bnp paribas", "citigroup", "blackrock",
        "vanguard", "macquarie", "marshall wace", "ubs principal"
    ],
    "Marquee HNI": [
        "ashish kacholia", "mukul agrawal", "mukul mahavir", "vijay kedia",
        "dolly khanna", "porinju veliyath", "madhusudan kela", "madhu kela",
        "nemish shah", "radhakishan damani", "sunil singhania", "abakkus"
    ]
}

def init_nse_session():
    session = requests.Session()
    session.headers.update(NSE_HEADERS)
    try:
        session.get(NSE_HOME, timeout=15)
        time.sleep(1.0)
    except Exception as e:
        print(f"⚠️ Warning Session Init: {e}")
    return session

def fetch_financial_metrics_resilient(symbol, session=None):
    """Yahoo Finance V7 Quote API se live CMP aur accurate Market Cap (in Cr) fetch karta hai."""
    clean_sym = symbol.replace("&", "%26").strip()
    candidates = [f"{clean_sym}.NS", f"{clean_sym}.BO"]

    # 1. Primary: Yahoo Finance V7 Quote Endpoint (Market Cap + Price)
    for ticker in candidates:
        url = f"https://query1.finance.yahoo.com/v7/finance/quote?symbols={ticker}"
        try:
            res = requests.get(url, headers=YFIN_HEADERS, timeout=6)
            if res.status_code == 200:
                data = res.json()
                results = data.get("quoteResponse", {}).get("result", [])
                if results:
                    quote = results[0]
                    cmp_val = quote.get("regularMarketPrice", 0.0)
                    mcap_raw = quote.get("marketCap", 0)

                    mcap_cr = round(float(mcap_raw) / 10000000.0, 2) if mcap_raw else 0.0
                    if cmp_val and float(cmp_val) > 0:
                        return round(float(cmp_val), 2), mcap_cr
        except Exception:
            continue

    # 2. Secondary Fallback: Yahoo Finance Chart Module
    for ticker in candidates:
        url = f"https://query1.finance.yahoo.com/v8/finance/chart/{ticker}?interval=1d&range=1d"
        try:
            res = requests.get(url, headers=YFIN_HEADERS, timeout=6)
            if res.status_code == 200:
                data = res.json()
                meta = data.get("chart", {}).get("result", [{}])[0].get("meta", {})
                price = meta.get("regularMarketPrice") or meta.get("chartPreviousClose", 0.0)
                mcap_raw = meta.get("marketCap", 0)
                mcap_cr = round(float(mcap_raw) / 10000000.0, 2) if mcap_raw else 0.0
                if price and float(price) > 0:
                    return round(float(price), 2), mcap_cr
        except Exception:
            continue

    return 0.0, 0.0

def download_and_parse_pdf(pdf_url, session):
    if not pdf_url or not pdf_url.endswith(".pdf"):
        return ""
    try:
        res = session.get(pdf_url, timeout=12)
        if res.status_code == 200:
            pdf_file = io.BytesIO(res.content)
            reader = PdfReader(pdf_file)
            extracted_pages = []
            for page in reader.pages[:4]:
                extracted_pages.append(page.extract_text() or "")
            return " ".join(extracted_pages)
    except Exception as e:
        print(f"⚠️ PDF parse skipped ({pdf_url}): {e}")
    return ""

def extract_allottees(text):
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

    unique = []
    seen = set()
    for a in found_allottees:
        if a["name"] not in seen:
            seen.add(a["name"])
            unique.append(a)
    return unique

def extract_deal_size_cr(text, shares_count=0, floor_price=0.0):
    cr_match = re.search(r'(?:aggregating\s+(?:up\s+to|to)?|worth|total\s+value\s+of)?\s*(?:rs\.?|inr)?\s*([\d,]+(?:\.\d+)?)\s*(?:cr|crore|crores)', text, re.I)
    if cr_match:
        try:
            val = float(cr_match.group(1).replace(",", ""))
            if 1.0 <= val <= 35000:
                return round(val, 2)
        except ValueError:
            pass

    if shares_count > 0 and floor_price > 0:
        total_cr = round((shares_count * floor_price) / 10000000, 2)
        if 1.0 <= total_cr <= 35000:
            return total_cr

    return 0.0

def build_alert_card(entry):
    allottees_str = "\n".join([f"- {a['name']} ({a['tier']})" for a in entry['allottees']]) if entry['allottees'] else "- Qualified Institutional Buyers (QIB)"
    
    if entry['market_cap_cr'] > 0 and entry['deal_size_pct_mcap'] > 0:
        dilution_str = f"~{entry['deal_size_pct_mcap']}% Dilution (MCap: ₹{entry['market_cap_cr']:,.0f} Cr)"
    elif entry['market_cap_cr'] > 0:
        dilution_str = f"MCap: ₹{entry['market_cap_cr']:,.0f} Cr (Deal Size Pending)"
    else:
        dilution_str = "Deal Size Pending"

    card = (
        f"🚨 FRESH CAPITAL RADAR | {entry['zone_label'].upper()}\n\n"
        f"📌 {entry['company_name']} (NSE: {entry['symbol']})\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        f"💰 Issue Price:         ₹{entry['institutional_floor_price']:,.2f}\n"
        f"📊 Current CMP:          ₹{entry['cmp']:,.2f} ({entry['delta_to_floor_pct']:+0.2f}% vs Anchor)\n"
        f"📦 Capital Infused:      ₹{entry['capital_raised_cr']:,.2f} Cr\n"
        f"🏢 Dilution / MCap:      {dilution_str}\n\n"
        f"🏦 Key Marquee Allottees:\n"
        f"{allottees_str}\n"
        f"📄 Official Filing: {entry['filing_pdf']}"
    )
    return card

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
            print("❌ Failed to fetch announcements from NSE API.")
            return []

        filings = response.json()
        raw_candidates = []
        seen_symbols = set()

        for item in filings:
            subject = item.get("desc") or ""
            att_text = item.get("attchmntText") or ""
            full_text = f"{subject} {att_text}"

            # Strict negative filter: drop dividends, acquisitions, warrants, rights
            blacklist = r'(?:dividend|acquisition of|in the units of|rights\s+issue|esop|sweat\s+equity|bonus|warrant|debt\s+conversion|loan\s+conversion|remuneration|resignation|loss of share)'
            if re.search(blacklist, full_text, re.I):
                continue

            # QIP or Preferential Equity Allotment
            is_qip = bool(re.search(r'\bqip\b|qualified\s+institutions\s+placement', full_text, re.I))
            is_pref = bool(re.search(r'preferential\s+(?:allotment|issue).*(?:equity\s+shares)', full_text, re.I)) or \
                      bool(re.search(r'allotment\s+of\s+[\d,]+\s+equity\s+shares', full_text, re.I))

            if not (is_qip or is_pref):
                continue

            deal_type = "QIP (Institutions Only)" if is_qip else "Preferential Equity Allotment"

            symbol = item.get("symbol") or ""
            if not symbol or symbol in seen_symbols:
                continue

            company_name = item.get("sm_name") or symbol
            pdf_url = item.get("attchmntFile") or ""

            # Extract Issue Price
            price_match = re.search(
                r'(?:issue\s+price|price\s+of|allotment\s+price)\s*(?:of|is|at)?\s*(?:rs\.?|inr)?\s*([\d,]+(?:\.\d+)?)',
                full_text,
                re.I
            )

            shares_match = re.search(r'([\d,]+)\s*(?:equity\s+shares)', full_text, re.I)
            shares_count = int(shares_match.group(1).replace(",", "")) if shares_match else 0

            if price_match:
                try:
                    floor_price = float(price_match.group(1).replace(",", ""))

                    # PDF Parsing for Allottees & Capital Infusion
                    allottees = extract_allottees(full_text)
                    deal_size_cr = extract_deal_size_cr(full_text, shares_count, floor_price)

                    if not allottees and pdf_url:
                        pdf_content = download_and_parse_pdf(pdf_url, session)
                        if pdf_content:
                            allottees = extract_allottees(pdf_content)
                            if deal_size_cr == 0.0:
                                deal_size_cr = extract_deal_size_cr(pdf_content, shares_count, floor_price)

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
                    seen_symbols.add(symbol)
                except ValueError:
                    continue

        processed = []
        print(f"\n🔍 Screening {len(raw_candidates)} candidate filings with price sanity checks...")

        for cand in raw_candidates:
            symbol = cand["symbol"]
            floor = cand["floor_price"]

            cmp_val, mcap_cr = fetch_financial_metrics_resilient(symbol, session)

            if cmp_val <= 0:
                print(f"❌ Dropped {symbol}: Price fetch failed")
                continue

            if cmp_val < 15.0:
                print(f"❌ Dropped {symbol}: CMP ₹{cmp_val} is below penny cutoff (₹15.0)")
                continue

            delta_pct = round(((cmp_val - floor) / floor) * 100, 2)

            # OCR / Regex Anomaly Filter (-40% to +60%)
            if delta_pct < -40.0 or delta_pct > 60.0:
                print(f"🚫 Dropped OCR Error on {symbol}: Floor ₹{floor} vs CMP ₹{cmp_val} (Delta: {delta_pct}%)")
                continue

            deal_pct_of_mcap = round((cand["capital_raised_cr"] / mcap_cr * 100), 2) if mcap_cr > 0 else 0.0
            has_tier1 = len(cand["allottees"]) > 0

            # Classification
            if delta_pct < 0:
                zone = "PRIME_DISCOUNT"
                zone_label = f"{abs(delta_pct)}% Below Anchor"
            elif delta_pct <= 6.0:
                zone = "ACCUMULATION_BUFFER"
                zone_label = f"+{delta_pct}% Near Floor"
            else:
                zone = "EXTENDED"
                zone_label = f"+{delta_pct}% Extended"

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

            entry["alert_card"] = build_alert_card(entry)
            print(f"✨ Signal Verified: {symbol} | Floor: ₹{floor} | CMP: ₹{cmp_val} | MCap: ₹{mcap_cr} Cr | Zone: {zone}")
            processed.append(entry)
            time.sleep(0.3)

        return processed
    except Exception as e:
        print(f"Execution Pipeline Error: {e}")
        return []

def main():
    print("=" * 65)
    print("💎 EXECUTING RESILIENT FRESH CAPITAL ANCHOR ENGINE")
    print("=" * 65)

    prime_setups = []
    buffer_setups = []
    all_setups = fetch_institutional_anchors(days_back=60)

    for item in all_setups:
        if item["zone"] == "PRIME_DISCOUNT":
            prime_setups.append(item)
        elif item["zone"] == "ACCUMULATION_BUFFER":
            buffer_setups.append(item)

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

    print(f"\n🏆 Completed! Verified Anchors: {len(all_setups)} | Prime Discounts: {len(prime_setups)} | Buffer Setups: {len(buffer_setups)}")

if __name__ == "__main__":
    main()
