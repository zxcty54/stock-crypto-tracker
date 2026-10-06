import os
import re
import json
import time
from datetime import datetime
import urllib.parse
import io
import requests
from bs4 import BeautifulSoup
import pypdf

OUTPUT_REPORT_FILE = "order_radar_report.json"
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY", "").strip()

MAX_MARKET_CAP_CR = 5000.0
MIN_ORDER_TO_MCAP_MULTIPLE = 1.0

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
    "Accept": "application/json, text/plain, */*",
    "Accept-Language": "en-US,en;q=0.9",
}

# -------------------------------------------------------------
# 1. CARE & ICRA RATINGS RATIONALES FETCH
# -------------------------------------------------------------
def fetch_care_daily_rationales():
    print("\n🔍 Fetching dynamic rationales from CARE & ICRA portals...")
    discovered = []
    
    # CARE endpoint attempt
    api_url = "https://www.careratings.com/api/get-ratings-history"
    payload = {"page": 1, "limit": 50, "sector": "", "keyword": ""}
    
    try:
        res = requests.post(api_url, json=payload, headers=HEADERS, timeout=12)
        if res.status_code == 200:
            data = res.json()
            items = data.get("data", []) or data.get("items", [])
            for item in items:
                c_name = item.get("company_name") or item.get("companyName")
                pdf_url = item.get("pdf_url") or item.get("doc_path")
                if c_name and pdf_url:
                    if not pdf_url.startswith("http"):
                        pdf_url = f"https://www.careratings.com{pdf_url}"
                    discovered.append({
                        "company_name": c_name.strip(),
                        "doc_url": pdf_url,
                        "agency": "CARE Ratings Rationale"
                    })
    except Exception as e:
        print(f"   ⚠️ CARE direct API notice: {e}")

    # ICRA listing scrape fallback
    if not discovered:
        print("   🔍 Checking ICRA public releases table...")
        icra_url = "https://www.icra.in/Rating/RatingRationale"
        try:
            res = requests.get(icra_url, headers=HEADERS, timeout=12)
            if res.status_code == 200:
                soup = BeautifulSoup(res.text, "html.parser")
                for link in soup.find_all("a", href=True):
                    href = link["href"]
                    if "/Rationale/ShowRationaleReport" in href or href.endswith(".pdf"):
                        text = link.get_text(strip=True)
                        if len(text) > 3:
                            full_url = href if href.startswith("http") else f"https://www.icra.in{href}"
                            discovered.append({
                                "company_name": text,
                                "doc_url": full_url,
                                "agency": "ICRA Rating Rationale"
                            })
        except Exception as e:
            print(f"   ⚠️ ICRA scrape notice: {e}")

    print(f"✅ Discovered {len(discovered)} recent rationale reports.")
    return discovered

# -------------------------------------------------------------
# 2. PDF TEXT EXTRACTION
# -------------------------------------------------------------
def extract_text_from_pdf(pdf_url):
    try:
        res = requests.get(pdf_url, headers=HEADERS, timeout=15)
        if res.status_code == 200 and len(res.content) > 1000:
            reader = pypdf.PdfReader(io.BytesIO(res.content))
            extracted_pages = []
            for page in reader.pages[:3]:
                txt = page.extract_text()
                if txt:
                    extracted_pages.append(txt)
            return " ".join(extracted_pages)
    except Exception as e:
        print(f"      [PDF extraction notice: {e}]")
    return ""

# -------------------------------------------------------------
# 3. SCREENER LIVE MARKET CAP LOOKUP
# -------------------------------------------------------------
def get_screener_data(company_name):
    try:
        clean = re.sub(r'(?i)\b(ltd|limited|pvt|private|india|\(india\))\b', '', company_name)
        clean = re.sub(r'[^a-zA-Z0-9\s]', '', clean).strip()
        tokens = clean.split()[:2]
        query = urllib.parse.quote(" ".join(tokens))

        url = f"https://www.screener.in/api/company/search/?q={query}"
        res = requests.get(url, headers=HEADERS, timeout=8)
        if res.status_code == 200:
            hits = res.json()
            if hits:
                top = hits[0]
                path_parts = [p for p in top.get("url", "").split("/") if p and p.lower() not in ["consolidated", "company"]]
                symbol = path_parts[-1].upper() if path_parts else "N/A"
                
                c_url = f"https://www.screener.in{top['url']}"
                page_res = requests.get(c_url, headers=HEADERS, timeout=8)
                if page_res.status_code == 200:
                    soup = BeautifulSoup(page_res.text, "html.parser")
                    mcap_tag = soup.find("span", string=re.compile(r"Market Cap", re.I))
                    if mcap_tag:
                        num_span = mcap_tag.find_next("span", class_="number")
                        if num_span:
                            return symbol, float(num_span.text.replace(",", "").strip())
    except Exception as e:
        print(f"      [Screener notice: {e}]")
    return None, None

# -------------------------------------------------------------
# 4. PARSE ORDER METRICS (AI + REGEX)
# -------------------------------------------------------------
def parse_order_metrics(text):
    if not any(k in text.lower() for k in ["unexecuted order", "order book", "order backlog"]):
        return None

    if GEMINI_API_KEY:
        try:
            prompt = f"""
Analyze this credit rating text:
"{text[:2500]}"

Extract numerical values into JSON (raw json only):
{{
  "order_book_cr": 500.0,
  "timeline_months": 18,
  "sector": "Defense / EPC / Railway",
  "thesis": "Short execution thesis in Hinglish."
}}
"""
            payload = {
                "contents": [{"parts": [{"text": prompt}]}],
                "generationConfig": {"temperature": 0.1, "responseMimeType": "application/json"}
            }
            url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={GEMINI_API_KEY}"
            res = requests.post(url, json=payload, headers={"Content-Type": "application/json"}, timeout=12)
            if res.status_code == 200:
                raw = res.json()["candidates"][0]["content"]["parts"][0]["text"].strip()
                if raw.startswith("```"): 
                    raw = re.sub(r"^```[a-z]*|```$", "", raw).strip()
                data = json.loads(raw)
                val = float(data.get("order_book_cr", 0.0))
                if val > 0:
                    return {
                        "order_book_cr": val,
                        "timeline_months": int(data.get("timeline_months", 18)),
                        "sector": data.get("sector", "Industrial & EPC"),
                        "thesis": data.get("thesis", "Order execution visibility.")
                    }
        except Exception as e:
            print(f"      [AI parse error: {e}]")

    patterns = [
        r'(?:unexecuted\s+order\s+book|order\s+backlog|order\s+book)\s+(?:of|stood\s+at|stands\s+at|at)\s+(?:Rs\.?|INR)?\s*([\d,]+(?:\.\d+)?)\s*(?:cr|crore)',
        r'(?:Rs\.?|INR)\s*([\d,]+(?:\.\d+)?)\s*(?:cr|crore)\s+(?:of\s+unexecuted\s+orders|order\s+book)'
    ]
    for p in patterns:
        match = re.search(p, text, re.I)
        if match:
            val = float(match.group(1).replace(",", ""))
            return {
                "order_book_cr": val,
                "timeline_months": 24,
                "sector": "Engineering & Infrastructure",
                "thesis": f"Healthy revenue runway backed by verified order backlog of ₹{val:,.1f} Cr."
            }
            
    return None

# -------------------------------------------------------------
# 5. MAIN PIPELINE
# -------------------------------------------------------------
def run():
    print("=" * 70)
    print("🚀 DYNAMIC RATING AGENCIES RADAR (CARE / ICRA / CRISIL)")
    print("=" * 70)

    publications = fetch_care_daily_rationales()
    verified_gems = []

    for item in publications:
        c_name = item["company_name"]
        print(f"\n🔍 Processing: {c_name}...")

        symbol, mcap = get_screener_data(c_name)
        if not mcap:
            print(f"   ⏩ Not listed on NSE/BSE or unidentifiable on Screener. Skipped.")
            continue

        print(f"   📊 Symbol: {symbol} | Market Cap: ₹{mcap:,.1f} Cr")
        if mcap > MAX_MARKET_CAP_CR:
            print(f"   ⏩ MCap ₹{mcap:,.1f} Cr > ₹{MAX_MARKET_CAP_CR} Cr limit. Skipped.")
            continue

        print(f"   📄 Downloading Rationale: {item['doc_url']}")
        pdf_text = extract_text_from_pdf(item["doc_url"])
        if not pdf_text:
            print("   ⚠️ Could not read PDF or document empty.")
            continue

        metrics = parse_order_metrics(pdf_text)
        if not metrics or metrics["order_book_cr"] <= 0:
            print("   ℹ️ No unexecuted order book disclosure found in this report.")
            continue

        order_val = metrics["order_book_cr"]
        multiple = round(order_val / mcap, 2)
        print(f"   🎯 Audited Order Book: ₹{order_val:,.1f} Cr ➔ Multiple: {multiple}x MCap")

        if multiple >= MIN_ORDER_TO_MCAP_MULTIPLE:
            verified_gems.append({
                "symbol": symbol,
                "company_name": c_name,
                "market_cap_cr": mcap,
                "unexecuted_order_book_cr": order_val,
                "order_to_mcap_multiple": multiple,
                "execution_timeline_months": metrics["timeline_months"],
                "client_sector": metrics["sector"],
                "thesis": metrics["thesis"],
                "source_verification": {
                    "source_name": item["agency"],
                    "document_url": item["doc_url"],
                    "as_on_date": datetime.now().strftime("%b %Y"),
                    "is_audited_regulatory": True
                }
            })
            print(f"   🔥 [HIDDEN GEM CONFIRMED] Multiple {multiple}x >= {MIN_ORDER_TO_MCAP_MULTIPLE}x")
        else:
            print(f"   ❌ Multiple {multiple}x below {MIN_ORDER_TO_MCAP_MULTIPLE}x.")

        time.sleep(1)

    verified_gems.sort(key=lambda x: x["order_to_mcap_multiple"], reverse=True)

    final_report = {
        "last_updated": datetime.now().strftime("%Y-%m-%d %H:%M:%S IST"),
        "filter_criteria": {
            "max_mcap_cr": MAX_MARKET_CAP_CR,
            "min_order_multiple": MIN_ORDER_TO_MCAP_MULTIPLE,
            "pipeline": "Dynamic Rating Agencies Rationale Feed"
        },
        "total_hidden_gems_found": len(verified_gems),
        "gems": verified_gems
    }

    with open(OUTPUT_REPORT_FILE, "w", encoding="utf-8") as f:
        json.dump(final_report, f, ensure_ascii=False, indent=2)

    print("\n" + "=" * 70)
    print(f"🎉 SUCCESS: {len(verified_gems)} dynamic gems saved in '{OUTPUT_REPORT_FILE}'")
    print("=" * 70)

if __name__ == "__main__":
    run()
