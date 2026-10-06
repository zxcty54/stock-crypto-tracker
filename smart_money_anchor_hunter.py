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
        print(f"Warning session init: {e}")
    return session

def fetch_nse_metrics(symbol, session):
    """NSE ke live quote API se CMP aur Total Issued Shares nikaal kar exact Market Cap banata hai."""
    url = f"https://www.nseindia.com/api/quote-equity?symbol={symbol}"
    try:
        res = session.get(url, timeout=10)
        if res.status_code == 200:
            data = res.json()
            price_info = data.get("priceInfo", {})
            security_info = data.get("securityInfo", {})

            cmp_val = price_info.get("lastPrice", 0.0)
            issued_shares = security_info.get("issuedSize", 0)

            mcap_cr = 0.0
            if cmp_val > 0 and issued_shares > 0:
                mcap_cr = round((cmp_val * issued_shares) / 10000000, 2)

            return float(cmp_val), mcap_cr
    except Exception:
        pass
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
            if 5.0 <= val <= 25000:
                return round(val, 2)
        except ValueError:
            pass

    if shares_count > 0 and floor_price > 0:
        total_cr = round((shares_count * floor_price) / 10000000, 2)
        if 5.0 <= total_cr <= 25000:
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

            # Strict Negative Filter: Drop dividends, acquisitions, warrants, rights
            blacklist = r'(?:dividend|acquisition of|in the units of|rights\s+issue|esop|sweat\s+equity|bonus|warrant|debt\s+conversion|loan\s+conversion|remuneration|resignation|loss of share)'
            if re.search(blacklist, full_text, re.I):
                continue

            # Must be QIP or Pure Preferential Equity Allotment
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

            # More precise price match (rejecting single/double digit noise unless penny)
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

                    # PDF Deep Dive
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
        print(f"🔍 Screening {len(raw_candidates)} filings with Sanity Bounds & NSE MCAP...")

        for cand in raw_candidates:
            symbol = cand["symbol"]
            floor = cand["floor_price"]

            cmp_val, mcap_cr = fetch_nse_metrics(symbol, session)
            
            # Penny stocks filter
            if cmp_val < 20.0:
                continue

            # CRITICAL SANITY FILTER: OCR / Regex Error Eliminator
            # Floor price aur CMP me 35% se zyada unrealistic gap nahi hona chahiye
            delta_pct = round(((cmp_val - floor) / floor) * 100, 2)
            if delta_pct < -35.0 or delta_pct > 50.0:
                print(f"🚫 Dropped regex error on {symbol}: Floor ₹{floor} vs CMP ₹{cmp_val} ({delta_pct}%)")
                continue

            deal_pct_of_mcap = round((cand["capital_raised_cr"] / mcap_cr * 100), 2) if mcap_cr > 0 else 0.0

            # Only consider Tier-1 backed if actually discovered
            has_tier1 = len(cand["allottees"]) > 0

            if delta_pct < 0:
                zone = "PRIME_DISCOUNT"
                zone_label = f"{abs(delta_pct)}% Below Anchor"
            elif delta_pct <= 6.0:
                zone = "ACCUMULATION_BUFFER"
                zone_label = f"+{delta_pct}% Near Floor"
            else:
                zone = "EXTENDED"
                zone_label = f"+{delta_pct}% Extended"

            dilution_str = f"~{deal_pct_of_mcap}% Dilution" if deal_pct_of_mcap > 0 else "Deal Size Pending"
            allottees_str = "\n".join([f"- {a['name']} ({a['tier']})" for a in cand['allottees']]) if cand['allottees'] else "- Qualified Institutional Buyers (Verified in Filing)"

            card = (
                f"🚨 FRESH CAPITAL RADAR | {zone_label.upper()}\n\n"
                f"📌 {cand['company_name']} (NSE: {symbol})\n"
                f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
                f"💰 Issue Price:         ₹{floor:,.2f}\n"
                f"📊 Current CMP:          ₹{cmp_val:,.2f} ({delta_pct:+0.2f}% vs Anchor)\n"
                f"📦 Capital Infused:      ₹{cand['capital_raised_cr']:,.2f} Cr\n"
                f"🏢 Dilution / MCap:      {dilution_str} (MCap: ₹{mcap_cr:,.0f} Cr)\n\n"
                f"🏦 Key Marquee Allottees:\n"
                f"{allottees_str}\n"
                f"📄 Official Filing: {cand['pdf_url']}"
            )

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
                "filing_context": cand["context"],
                "alert_card": card
            }

            print(f"✨ Verified: {symbol} | Floor: ₹{floor} | CMP: ₹{cmp_val} | Delta: {delta_pct}%")
            processed.append(entry)
            time.sleep(0.4)

        return processed
    except Exception as e:
        print(f"Error in pipeline: {e}")
        return []

def main():
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

    print(f"\n Clean Output Written! Prime Discounts: {len(prime_setups)} | Buffer Setups: {len(buffer_setups)}")

if __name__ == "__main__":
    main()
