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
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
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

def fetch_financial_metrics_resilient(symbol, session):
    """Pehle NSE live API hit karta hai, cookie/session drop hone par Yahoo Finance backup use karta hai."""
    clean_sym = symbol.replace("&", "%26").strip()
    
    # 1. Primary: NSE Live Quote
    url_nse = f"https://www.nseindia.com/api/quote-equity?symbol={clean_sym}"
    try:
        res = session.get(url_nse, timeout=6)
        if res.status_code == 200:
            data = res.json()
            price_info = data.get("priceInfo", {})
            security_info = data.get("securityInfo", {})
            cmp_val = price_info.get("lastPrice", 0.0)
            issued_shares = security_info.get("issuedSize", 0)

            mcap_cr = 0.0
            if cmp_val and issued_shares:
                mcap_cr = round((float(cmp_val) * float(issued_shares)) / 10000000.0, 2)

            if cmp_val and float(cmp_val) > 0:
                return float(cmp_val), mcap_cr
    except Exception:
        pass

    # 2. Resilient Fallback: Yahoo Finance Chart Endpoint
    candidates = [f"{clean_sym}.NS", f"{clean_sym}.BO"]
    for ticker in candidates:
        url_yf = f"https://query1.finance.yahoo.com/v8/finance/chart/{ticker}?interval=1d&range=1d"
        try:
            res = requests.get(url_yf, headers=YFIN_HEADERS, timeout=6)
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
    dilution_str = f"~{entry['deal_size_pct_mcap']}% Dilution" if entry['deal_size_pct_mcap'] > 0 else "Deal Size Pending"

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

            # Strict elimination of non-equity dilution events
            blacklist = r'(?:dividend|acquisition of|in the units of|rights\s+issue|esop|sweat\s+equity|bonus|warrant|debt\s+conversion|loan\s+conversion|remuneration|resignation|loss of share)'
            if re.search(blacklist, full_text, re.I):
                continue

            # Must be QIP or Preferential Equity Allotment
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
                r'(?:issue\s+price|price\s+of|allotment\s+price)\s*(?:of|is|at)?\s*(?:rs\.?|inr)?
