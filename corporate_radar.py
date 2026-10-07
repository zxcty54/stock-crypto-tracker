#!/usr/bin/env python3
"""
CONSOLIDATED CORPORATE RADAR ENGINE (Scraper + AI Summarizer in 1 File)
Scrapes NSE announcements/results, processes forensics in-memory,
filters junk, calls Hybrid AI, and outputs directly to nse_content_feed.json.
Zero intermediate master files.
"""

import os
import io
import re
import sys
import json
import time
import hashlib
from datetime import datetime, timezone, timedelta
import requests
from curl_cffi import requests as cffi_requests
from pypdf import PdfReader

try:
    import pdfplumber
except ImportError:
    pdfplumber = None

try:
    from groq import Groq
except ImportError:
    Groq = None

try:
    from google import genai
    from google.genai import types
except ImportError:
    genai = None

# ============================================================
# CONFIGURATION
# ============================================================
OUTPUT_FILE = "nse_content_feed.json"
IST = timezone(timedelta(hours=5, minutes=30))
NOW = datetime.now(IST)
TODAY_STR = NOW.strftime("%d-%m-%Y")

BASE_URL = "https://www.nseindia.com"
MAX_PDF_DOWNLOADS = 15
BATCH_SIZE = 2
BATCH_PAUSE_SECONDS = 10

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
    "Accept": "application/json, text/plain, */*",
    "Accept-Language": "en-US,en;q=0.9",
    "Origin": "https://www.nseindia.com",
    "Referer": "https://www.nseindia.com/"
}

CATEGORY_PATTERNS = {
    "ORDER": re.compile(r'\b(order win|order received|awarded|contract|bagged|letter of intent|loi|work order|purchase order|commercial agreement)\b', re.I),
    "ACQUISITION": re.compile(r'\b(acquisition of.*business|takeover|acquires.*stake|acquiring.*stake|slump sale)\b', re.I),
    "DIVESTMENT": re.compile(r'\b(divestment|stake sale|sale of subsidiary|hive-off|demerger of)\b', re.I),
    "NEW_BUSINESS": re.compile(r'\b(new line of business|entry into|diversification into|commencement of new business)\b', re.I),
    "CAPACITY_EXPANSION": re.compile(r'\b(capacity expansion|new plant|capex|manufacturing facility|greenfield|brownfield)\b', re.I),
    "RESULT": re.compile(r'\b(financial results|audited results|unaudited results|quarterly results)\b', re.I),
    "BONUS": re.compile(r'\b(bonus issue|bonus shares|allotment of bonus)\b', re.I),
    "SPLIT": re.compile(r'\b(split|sub-division|subdivision|face value.*from.*to)\b', re.I),
    "BUYBACK": re.compile(r'\b(buyback|buy-back|tender offer|share repurchase)\b', re.I)
}

EXCLUDE_JUNK = re.compile(
    r'\b(newspaper|clipping|trading window|closure of trading|prior intimation|schedule of board meeting|'
    r'esop|stock option|loss of share|duplicate share|compliance certificate|investor grievance|'
    r'scrutinizer|postal ballot|book closure|inter-se transfer|transmission of shares|gift of shares|'
    r'annual general meeting|extraordinary general meeting|credit rating|care|crisil|icra|brickwork)\b',
    re.I
)

# ============================================================
# API KEY RESOLUTION & HYBRID AI SETUP
# ============================================================
def _collect_keys(names):
    vals = [os.environ.get(n, "").strip() for n in names]
    return list(dict.fromkeys([v for v in vals if v]))

GROQ_KEYS = _collect_keys(["GROQ_API_KEY", "GROQ_API_KEY2"])
GOOGLE_KEYS = _collect_keys(["GOOGLE_API_KEY", "GOOGLE_API_KEY2", "GEMINI_API_KEY"])

groq_key_idx = 0
google_key_idx = 0

SYSTEM_PROMPT = """You are a senior financial news editor. Convert corporate filings into SHORT, FACTUAL, TELEGRAM-READY updates.
Rules:
- 100% factual. No hype words (no 'bullish', 'multibagger', 'transformational').
- No target prices, no entry/exit recommendations.
- Output valid JSON: {"items": [{"input_id": 1, "content_worthy": true, "event_type": "ORDER_WIN", "headline": "...", "telegram_post": "..."}]}
- If routine/not worthy, return content_worthy: false.
- Telegram HTML layout:
📌 <b>#{EVENT_TYPE}</b> | <b>{company_name} (NSE: {symbol})</b>

<b>{headline}</b>
━━━━━━━━━━━━━━━━━━━━━
🔹 <b>Key Details:</b>
- <b>Field:</b> Value
- <b>Field:</b> Value

📍 <b>What happened:</b>
↳ {1-2 concise factual sentences}
━━━━━━━━━━━━━━━━━━━━━
📍 <b>Source:</b> <a href="{pdf_link}">NSE Corporate Filing</a>"""

# ============================================================
# HELPER FUNCTIONS
# ============================================================
def generate_hash(text):
    clean = re.sub(r'[^a-zA-Z0-9]+', '', str(text).lower().strip())
    return hashlib.md5(clean.encode('utf-8')).hexdigest()[:12]

def sanitize_telegram_html(text):
    if not text:
        return ""
    text = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", text, flags=re.S)
    return text.strip()

def inject_disclaimer(post):
    if "Not SEBI registered" in post:
        return post
    disclaimer = "\n\n⚠️ <i>Educational only. Not investment advice. Not SEBI registered.</i>\n🤖 <i>AI-assisted factual summary.</i>"
    return post.rstrip() + disclaimer

def extract_pdf_data(session, pdf_url):
    if not pdf_url:
        return ""
    headers = {"User-Agent": HEADERS["User-Agent"], "Referer": "https://www.nseindia.com/"}
    try:
        resp = session.get(pdf_url, headers=headers, timeout=25)
        if resp.status_code != 200 or not resp.content.startswith(b'%PDF'):
            return ""
        pdf_bytes = resp.content
        extracted_text = ""
        if pdfplumber:
            try:
                with pdfplumber.open(io.BytesIO(pdf_bytes)) as pdf:
                    pages = [p.extract_text() for p in pdf.pages[:3] if p.extract_text()]
                    extracted_text = " ".join(" ".join(pages).split())[:3500]
            except Exception:
                pass
        if not extracted_text:
            reader = PdfReader(io.BytesIO(pdf_bytes))
            pages = [p.extract_text() for p in reader.pages[:3] if p.extract_text()]
            extracted_text = " ".join(" ".join(pages).split())[:3500]
        return extracted_text
    except Exception:
        return ""

def call_ai(payload):
    global groq_key_idx, google_key_idx
    # Try Groq
    if Groq and GROQ_KEYS:
        try:
            client = Groq(api_key=GROQ_KEYS[groq_key_idx])
            resp = client.chat.completions.create(
                model="openai/gpt-oss-120b",
                messages=[{"role": "system", "content": SYSTEM_PROMPT}, {"role": "user", "content": payload}],
                temperature=0.1,
                response_format={"type": "json_object"}
            )
            raw = resp.choices[0].message.content
            return json.loads(raw).get("items", [])
        except Exception:
            groq_key_idx = (groq_key_idx + 1) % len(GROQ_KEYS)

    # Fallback to Google Gemini
    if genai and GOOGLE_KEYS:
        try:
            client = genai.Client(api_key=GOOGLE_KEYS[google_key_idx])
            resp = client.models.generate_content(
                model="gemini-2.5-flash",
                contents=payload,
                config=types.GenerateContentConfig(system_instruction=SYSTEM_PROMPT, temperature=0.1, response_mime_type="application/json")
            )
            return json.loads(resp.text).get("items", [])
        except Exception:
            google_key_idx = (google_key_idx + 1) % len(GOOGLE_KEYS)
            
    return []

# ============================================================
# MASTER ORCHESTRATION (DIRECT IN-MEMORY)
# ============================================================
def main():
    print("=" * 70)
    print("🚀 CORPORATE RADAR: INTEGRATED ENGINE RUNNING")
    print(f"📅 Date: {TODAY_STR} | Time: {NOW.strftime('%H:%M:%S IST')}")
    print("=" * 70)

    # 1. Load Existing Feed (Acts as Persistent Dedup)
    feed_archive = {"generated_at": NOW.strftime("%Y-%m-%d %H:%M:%S IST"), "content_feed": []}
    if os.path.exists(OUTPUT_FILE):
        try:
            with open(OUTPUT_FILE, "r", encoding="utf-8") as f:
                feed_archive = json.load(f)
        except Exception:
            pass

    existing_hashes = {i.get("hash") for i in feed_archive.get("content_feed", []) if i.get("hash")}

    # 2. Handshake with NSE
    session = cffi_requests.Session(impersonate="chrome124")
    try:
        session.get(BASE_URL, headers=HEADERS, timeout=20)
    except Exception as e:
        print(f"❌ Handshake failed: {e}")
        return

    # 3. Fetch Announcements
    url = f"https://www.nseindia.com/api/corporate-announcements?index=equities&from_date={TODAY_STR}&to_date={TODAY_STR}"
    try:
        res = session.get(url, headers=HEADERS, timeout=25)
        raw_items = res.json() if res.status_code == 200 else []
    except Exception as e:
        print(f"❌ Scrape failed: {e}")
        return

    print(f"📥 Scraped {len(raw_items)} announcements today.")

    # 4. In-Memory Filter & PDF Parse
    candidates = []
    pdf_count = 0

    for item in raw_items:
        symbol = str(item.get("symbol", "")).strip()
        subject = str(item.get("desc") or item.get("subject", "")).strip()
        summary = str(item.get("attchmntText", "")).strip()
        broadcast_dt = str(item.get("an_dt") or item.get("broadcastDate", "")).strip()
        att_file = str(item.get("attchmntFile", "")).strip()

        if not symbol or not subject or EXCLUDE_JUNK.search(f"{subject} {summary}"):
            continue

        category = None
        for cat, pattern in CATEGORY_PATTERNS.items():
            if pattern.search(f"{subject} {summary}"):
                category = cat
                break
        if not category:
            continue

        item_hash = generate_hash(f"{symbol}_{subject}_{broadcast_dt}")
        if item_hash in existing_hashes:
            continue

        pdf_url = att_file if att_file.startswith("http") else (f"https://nsearchives.nseindia.com/corporate/{att_file}" if att_file else "")
        pdf_text = ""
        if pdf_url and pdf_count < MAX_PDF_DOWNLOADS:
            print(f"   📄 [{pdf_count+1}] Extracting PDF: {symbol}...")
            pdf_text = extract_pdf_data(session, pdf_url)
            if pdf_text:
                pdf_count += 1
            time.sleep(1.5)

        candidates.append({
            "hash": item_hash,
            "symbol": symbol,
            "company_name": str(item.get("sm_name") or item.get("companyName", "")).strip(),
            "category": category,
            "subject": subject,
            "summary": summary,
            "pdf_link": pdf_url,
            "details": (pdf_text or summary)[:4000],
            "broadcast_date": broadcast_dt
        })

    print(f"🎯 Actionable Candidates for AI: {len(candidates)}")
    if not candidates:
        print("✅ No new actionable filings. Exiting cleanly.")
        return

    # 5. Direct In-Memory AI Summarization
    new_worthy = 0
    for i in range(0, len(candidates), BATCH_SIZE):
        batch = candidates[i:i + BATCH_SIZE]
        batch_payload = [{"input_id": idx, **itm} for idx, itm in enumerate(batch, 1)]
        
        prompt = "Evaluate filings and generate Telegram market updates:\n" + json.dumps(batch_payload, ensure_ascii=False)
        results = call_ai(prompt)

        result_map = {r.get("input_id"): r for r in results if isinstance(r, dict)}

        for idx, itm in enumerate(batch, 1):
            res = result_map.get(idx)
            if res and res.get("content_worthy"):
                post = sanitize_telegram_html(res.get("telegram_post", ""))
                post = inject_disclaimer(post)
                feed_archive["content_feed"].insert(0, {
                    "hash": itm["hash"],
                    "analyzed_at": NOW.strftime("%Y-%m-%d %H:%M:%S IST"),
                    "symbol": itm["symbol"],
                    "headline": res.get("headline") or itm["subject"],
                    "telegram_post": post,
                    "used": False
                })
                existing_hashes.add(itm["hash"])
                new_worthy += 1
                print(f"   ⭐ Added Worthy: {itm['symbol']} ({itm['category']})")

        time.sleep(BATCH_PAUSE_SECONDS)

    # 6. Save Direct to Single Output File
    if new_worthy > 0:
        # Retention: Keep last 250 posts only
        feed_archive["content_feed"] = feed_archive["content_feed"][:250]
        with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
            json.dump(feed_archive, f, ensure_ascii=False, indent=2)
        print(f"💾 Successfully saved {new_worthy} posts directly to '{OUTPUT_FILE}'!")
    else:
        print("ℹ️ Filings processed, but none passed high-materiality AI threshold.")

if __name__ == "__main__":
    main()
