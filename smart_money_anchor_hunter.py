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
    "Accept": "*/*",
    "Accept-Language": "en-US,en;q=0.9",
    "Referer": "https://www.nseindia.com/companies-listing/corporate-filings-announcements"
}

YFIN_HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
}

# Marquee Funds & Super Investors Directory
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

def fetch_financial_metrics(symbol):
    clean_sym = symbol.replace("&", "%26").strip()
    candidates = [f"{clean_sym}.NS", f"{clean_sym}.BO"]

    for ticker in candidates:
        url = f"https://query2.finance.yahoo.com/v10/finance/quoteSummary/{ticker}?modules=price,summaryDetail"
        try:
            res = requests.get(url, headers=YFIN_HEADERS, timeout=8)
            if res.status_code == 200:
                data = res.json()
                price_module = data.get("quoteSummary", {}).get("result", [{}])[0].get("price", {})
                detail_module = data.get("quoteSummary", {}).get("result", [{}])[0].get("summaryDetail", {})
                
                cmp_val = price_module.get("regularMarketPrice", {}).get("raw", 0.0)
                mcap_raw = price_module.get("marketCap", {}).get("raw") or detail_module.get("marketCap", {}).get("raw", 0)
                
                mcap_cr = round(float(mcap_raw) / 10000000.0, 2) if mcap_raw else 0.0
                if cmp_val > 0:
                    return round(float(cmp_val), 2), mcap_cr
        except Exception:
            continue

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

def deep_scan_pdf(pdf_url, session):
    """
    BSE/NSE PDF circular ko RAM me load karke text, issue price,
    aur allottee tables/categories deeply scan karta hai.
    """
    if not pdf_url or not pdf_url.endswith(".pdf"):
        return "", None, []

    try:
        res = session.get(pdf_url, timeout=14)
        if res.status_code != 200:
            return "", None, []

        pdf_file = io.BytesIO(res.content)
        reader = PdfReader(pdf_file)
        
        extracted_pages = []
        for page in reader.pages[:8]:
            text = page.extract_text()
            if text:
                extracted_pages.append(text)
        
        full_text = " ".join(extracted_pages)
        if not full_text.strip():
            return "", None, []

        # 1. Regex hunt for Price inside PDF
        price_patterns = [
            r'(?:issue\s+price|allotment\s+price|price\s+of|allotted\s+at)\s*(?:of|at|is)?\s*(?:rs\.?|inr)?\s*([\d,]+(?:\.\d+)?)',
            r'(?:at\s+a\s+price\s+of\s+rs\.?)\s*([\d,]+(?:\.\d+)?)',
            r'rs\.?\s*([\d,]+(?:\.\d+)?)\s*(?:per\s+(?:equity\s+)?share)'
        ]
        
        discovered_price = None
        for pat in price_patterns:
            matches = re.findall(pat, full_text, re.I)
            for m in matches:
                try:
                    val = float(m.replace(",", ""))
                    if 10.0 <= val <= 80000.0:
                        discovered_price = val
                        break
                except ValueError:
                    continue
            if discovered_price:
                break

        # 2. Extract Allottees & Identify Promoter vs QIB
        discovered_allottees = extract_allottees(full_text)
        
        if not discovered_allottees:
            if re.search(r'\bpromoter\b|\bpromoter\s+group\b', full_text, re.I):
                discovered_allottees.append({
                    "name": "Promoter / Strategic Entities",
                    "tier": "Promoter Group Warrants/Equity"
                })
            elif re.search(r'\bnon-promoter\b|\bpublic\b', full_text, re.I):
                discovered_allottees.append({
                    "name": "Identified Strategic Investors",
                    "tier": "Non-Promoter Allottees"
                })

        return full_text, discovered_price, discovered_allottees

    except Exception as e:
        print(f"⚠️ PDF parse skipped ({pdf_url}): {e}")
        return "", None, []

def extract_allottees(text):
    found_allottees = []
    text_lower = text.lower()

    for tier, names in INSTITUTIONAL_DIRECTORY.items():
        for name in names:
            if re.search(r'\b' + re.escape(name) + r'\b', text_lower):
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
            if 1.0 <= val <= 60000:
                return round(val, 2)
        except ValueError:
            pass

    if shares_count > 0 and floor_price > 0:
        total_cr = round((shares_count * floor_price) / 10000000, 2)
        if 1.0 <= total_cr <= 60000:
            return total_cr

    return 0.0

def build_alert_card(entry):
    allottees_str = "\n".join([f"- {a['name']} ({a['tier']})" for a in entry['allottees']]) if entry['allottees'] else "- Qualified Institutional Buyers (QIB Allotment in PDF)"
    dilution_str = f"~{entry['deal_size_pct_mcap']}% Dilution" if entry['deal_size_pct_mcap'] > 0 else "Deal Size Pending"

    card = (
        f"🚨 SMART MONEY ANCHOR | {entry['zone_label'].upper()}\n\n"
        f"📌 {entry['company_name']} (NSE: {entry['symbol']})\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        f"💰 Anchor Floor Price:   ₹{entry['institutional_floor_price']:,.2f}\n"
        f"📊 Current CMP:          ₹{entry['cmp']:,.2f} ({entry['delta_to_floor_pct']:+0.2f}% vs Anchor)\n"
        f"📦 Capital Infused:      ₹{entry['capital_raised_cr']:,.2f} Cr\n"
        f"🏢 Dilution / MCap:      {dilution_str}\n\n"
        f"🏦 Verified Allottees:\n"
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
            return []

        filings = response.json()
        raw_candidates = []
        seen_symbols = set()

        for item in filings:
            subject = item.get("desc") or ""
            att_text = item.get("attchmntText") or ""
            full_text = f"{subject} {att_text}"
            
            # Filter non-equity / retail-only operations
            if re.search(r'(?:esop|sweat\s+equity|bonus\s+shares|debt\s+conversion|loan\s+conversion|remuneration|audit\s+committee|cancellation|withdrawn)', full_text, re.I):
                continue

            is_qip = bool(re.search(r'\bqip\b|qualified\s+institutions\s+placement', full_text, re.I))
            is_pref = bool(re.search(r'preferential\s+(?:allotment|issue)', full_text, re.I)) or bool(re.search(r'allotment\s+of\s+.*(?:equity|shares|warrants)', full_text, re.I))

            if not (is_qip or is_pref):
                continue

            deal_type = "QIP (Institutions Only)" if is_qip else "Preferential Issue / Warrants"

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

            shares_match = re.search(r'([\d,]+)\s*(?:equity\s+shares|shares|warrants)', full_text, re.I)
            shares_count = int(shares_match.group(1).replace(",", "")) if shares_match else 0

            floor_price = None
            if price_match:
                try:
                    floor_price = float(price_match.group(1).replace(",", ""))
                except ValueError:
                    floor_price = None

            allottees = extract_allottees(full_text)
            deal_size_cr = extract_deal_size_cr(full_text, shares_count, floor_price or 0.0)

            # Deep Scan PDF fallback if price or allottees missing in snippet
            if (not floor_price or not allottees) and pdf_url:
                pdf_text, pdf_price, pdf_allottees = deep_scan_pdf(pdf_url, session)
                if not floor_price and pdf_price:
                    floor_price = pdf_price
                if not allottees and pdf_allottees:
                    allottees = pdf_allottees
                if deal_size_cr == 0.0 and pdf_text:
                    deal_size_cr = extract_deal_size_cr(pdf_text, shares_count, floor_price or 0.0)

            if not floor_price or floor_price < 10.0:
                continue

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

        processed = []
        print(f"🔍 Screening {len(raw_candidates)} verified institutional & preferential issues...")

        for cand in raw_candidates:
            symbol = cand["symbol"]
            floor = cand["floor_price"]
            
            cmp_val, mcap_cr = fetch_financial_metrics(symbol)
            if cmp_val <= 0 or cmp_val < 10.0:
                continue

            deal_pct_of_mcap = round((cand["capital_raised_cr"] / mcap_cr * 100), 2) if mcap_cr > 0 else 0.0

            delta_pct = round(((cmp_val - floor) / floor) * 100, 2)
            has_tier1 = any(a.get("tier") in ["Tier-1 DII / MF", "Marquee FII / Sovereign", "Marquee HNI"] for a in cand["allottees"]) or "QIP" in cand["deal_type"]

            if delta_pct < 0:
                zone = "PRIME_DISCOUNT"
                zone_label = f"{abs(delta_pct)}% Below Anchor"
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

            entry["alert_card"] = build_alert_card(entry)
            print(f"✨ [{cand['deal_type']}] {symbol} | Floor: ₹{floor} | CMP: ₹{cmp_val} | Allottees: {len(cand['allottees'])}")
            processed.append(entry)
            time.sleep(0.2)

        return processed
    except Exception as e:
        print(f"Error in pipeline: {e}")
        return []

def main():
    print("=" * 65)
    print("💎 EXECUTING ALPHA PRODUCT ENGINE (DEEP PDF SCAN + ALLOTTEES)")
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
        "prime_discount_
