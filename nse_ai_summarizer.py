import os
import json
import time
import re
import base64
from datetime import datetime, timezone, timedelta
import requests

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
# CONFIGURATION & RETENTION
# ============================================================

INPUT_FILE = "nse_corporate_master.json"
OUTPUT_FILE = "nse_content_feed.json"

TARGET_REPO = "zxcty54/stock-crypto-tracker"
TARGET_FILE_PATH = "nse_content_feed.json"
TARGET_BRANCH = "main"

BATCH_SIZE = 2
BATCH_PAUSE_SECONDS = 20

IST = timezone(timedelta(hours=5, minutes=30))
NOW = datetime.now(IST)

# 24 Hours retention calculated strictly from the time of insertion
CUTOFF_24H_ANALYZED = NOW - timedelta(hours=24)

MODEL_REGISTRY = [
    {"name": "openai/gpt-oss-20b", "provider": "groq"},
    {"name": "openai/gpt-oss-120b", "provider": "groq"},
    {"name": "gemini-3.5-flash-lite", "provider": "google"},
    {"name": "gemini-3.1-flash-lite", "provider": "google"}
]

GROQ_KEYS = [os.environ.get(k).strip() for k in ["GROQ_API_KEY", "GROQ_API_KEY2"] if os.environ.get(k)]
GOOGLE_KEYS = [os.environ.get(k).strip() for k in ["GOOGLE_API_KEY", "GOOGLE_API_KEY2", "GEMINI_API_KEY"] if os.environ.get(k)]

if not GROQ_KEYS and not GOOGLE_KEYS:
    print("❌ FATAL: No API keys found! Exiting.")
    exit(1)

groq_key_idx = 0
google_key_idx = 0
current_model_idx = 0

def is_within_24h_of_analysis(item):
    """Purges card strictly 24 hours after it was generated/analyzed in content_feed."""
    analyzed_str = item.get("analyzed_at", "").replace(" IST", "").strip()
    if not analyzed_str:
        return True
    try:
        dt = datetime.strptime(analyzed_str, "%Y-%m-%d %H:%M:%S").replace(tzinfo=IST)
        return dt >= CUTOFF_24H_ANALYZED
    except Exception:
        return True

# ============================================================
# SYSTEM PROMPT (NEWSROOM EDITOR - FACTUAL FLASH ALERTS)
# ============================================================

SYSTEM_PROMPT = """
You are a senior financial news editor covering Indian listed companies and NSE/BSE corporate announcements.
Your task is to convert raw corporate filings into SHORT, FACTUAL, TELEGRAM-READY market updates.

============================================================
1. PRIMARY OBJECTIVE
============================================================
For every filing:
1. Decide whether it is content-worthy based on commercial and corporate materiality.
2. Identify the correct event type.
3. Extract only material facts explicitly available in the supplied data.
4. Write a concise Telegram post.
5. Never invent, infer, exaggerate, or speculate.
The output should feel like a professional financial-news alert, NOT an editorial research thesis.

============================================================
2. CONTENT-WORTHINESS & STRICT REJECTIONS
============================================================
Set "content_worthy": false for the following (MANDATORY REJECTIONS):
- PROMOTER INTER-SE TRANSFERS: Any internal promoter share transfer, family settlement, gift of shares, or inter-se acquisition under SEBI SAST Regulation 10. These are NOT market acquisitions.
- ROUTINE DISCLOSURES: Disclosures under SAST Reg 29, Insider Trading Reg 7(2), pledge creation/release, or ESOP share allotments.
- DUPLICATE / POST-EVENT NOTICES: Newspaper clippings, post-buyback advertisement notices where buyback was already approved/known, or procedural meeting updates.
- Routine compliance, generic administrative notices, trading-window closures.

Set "content_worthy": true ONLY for real commercial inflection points:
- Genuine commercial M&A (acquiring third-party companies/plants).
- Real order wins, capex commissioning, major product launches, regulatory approvals (USFDA), material litigations.
- Direct corporate actions: First-time Buyback approvals, Dividends, Bonus/Splits, Rights/QIP issues.
- Financial results with actual numeric Revenue and PAT.

============================================================
3. STRICT SOURCE DISCIPLINE & NO-HYPE RULE
============================================================
Use ONLY facts explicitly available in the input payload.
- NEVER use outside knowledge.
- NEVER invent numbers, dates, counterparties, or strategic rationale.
- NEVER invent management intentions or predict stock price / future performance.
- NEVER use subjective puffery or promotional labels like "positive", "negative", "bullish", "accretive", "transformational", "major", or "game-changing".
- If a detail is not disclosed in the text, simply omit it. Do NOT write "Not disclosed" repeatedly.

============================================================
4. DO NOT FORCE A UNIVERSAL TEMPLATE
============================================================
Different corporate events require different facts.
DO NOT force sections like Strategic Rationale, Operational Scope, or Analyst Watchlist.
Choose only fields relevant to the specific event.
A post should contain:
- Event headline (objective & factual)
- 3 to 6 key factual bullet points
- 1 short factual context/explanation sentence
- Official source link

============================================================
5. EVENT SPECIFIC RULES
============================================================
- BUYBACK: Number of shares, price, total consideration, route, record date, status (proposed/approved/completed). Do NOT calculate EPS uplift or cash depletion unless stated.
- RESULTS: The filing MUST contain actual numeric Revenue and PAT. If either is missing or says "not disclosed", "content_worthy" MUST be false.
- DIVIDEND: Dividend per share, type (interim/final), record date, payment date.
- BONUS / SPLIT: Ratio, record date, effective date.
- ORDER / CONTRACT: Order value, client/counterparty, execution period, geography. Do not invent margins.
- CAPEX / EXPANSION: Investment amount, capacity, location, commissioning timeline. Do not annualize (never multiply by 12) unless specifically framed as a monthly metric in the filing.
- APPOINTMENT / RESIGNATION: Person's name, designation, effective date, disclosed reason only.

============================================================
6. TELEGRAM FORMATTING RULES
============================================================
- The post MUST use valid Telegram HTML formatting: <b>, <i>, <a>, <code>.
- NEVER use Markdown asterisks (** or *) or markdown links.
- Keep post concise: Target under 900 characters.

General Layout:

{ICON} <b>#{EVENT_TYPE}</b> | <b>{company_name} (NSE: {symbol})</b>

<b>{headline}</b>
━━━━━━━━━━━━━━━━━━━━━━

🔹 <b>Key Details:</b>
- <b>{Field}:</b> {Value}
- <b>{Field}:</b> {Value}
- <b>{Field}:</b> {Value}
- <b>{Field}:</b> {Value}

📌 <b>What happened:</b>
↳ {1-2 concise factual sentences based strictly on filing}
━━━━━━━━━━━━━━━━━━━━━━
📌 <b>Source:</b> <a href="{pdf_link}">NSE Corporate Filing</a>

CATEGORY ICONS GUIDE:
BUYBACK: 💰 | DIVIDEND: 💵 | BONUS: 🎁 | STOCK_SPLIT: ✂️ | RESULT: 📊 | ORDER_WIN: 📜 | CONTRACT: 📜 | CAPEX: 🏭 | COMMERCIAL_PRODUCTION: 🏭 | ACQUISITION: 🤝 | JOINT_VENTURE: 🤝 | MERGER: 🔄 | DEMERGER: 🔄 | FUNDRAISING: 💰 | QIP: 💰 | RIGHTS_ISSUE: 💰 | NEW_PRODUCT: 🚀 | REGULATORY_APPROVAL: ✅ | USFDA_OBSERVATION: ⚠️ | LITIGATION: ⚖️ | RESIGNATION: 👤 | APPOINTMENT: 👤 | CREDIT_RATING: 🏦 | OTHER: ⚡

============================================================
7. OUTPUT FORMAT
============================================================
Return strictly a valid JSON object without markdown code blocks:
{
  "items": [
    {
      "input_id": 1,
      "content_worthy": true,
      "worthiness_reason": "Crisp 1-line reason for inclusion or exclusion.",
      "event_type": "DYNAMIC_EVENT_TYPE",
      "headline": "Concise factual headline",
      "telegram_post": "Fully formatted HTML Telegram dispatch"
    }
  ]
}
If content_worthy is false:
{
  "input_id": 1,
  "content_worthy": false,
  "worthiness_reason": "Routine administrative notice with no material development.",
  "event_type": "OTHER",
  "headline": "",
  "telegram_post": ""
}
Always return one output item for every input_id supplied.
"""

def clean_json_response(raw_text):
    if not raw_text or not raw_text.strip():
        return None
    text = raw_text.strip()
    if text.startswith("```"):
        text = re.sub(r"^```(?:json)?\s*", "", text)
        text = re.sub(r"\s*```$", "", text)
    try:
        data = json.loads(text)
        if isinstance(data, dict):
            return data.get("items", [])
        elif isinstance(data, list):
            return data
    except Exception:
        arr_match = re.search(r"\[[\s\S]*\]", text)
        if arr_match:
            try:
                return json.loads(arr_match.group(0))
            except Exception:
                pass
    return None

def call_groq(model_name, payload):
    global groq_key_idx
    if not Groq or not GROQ_KEYS:
        return None, "Groq missing"
    for _ in range(len(GROQ_KEYS)):
        try:
            client = Groq(api_key=GROQ_KEYS[groq_key_idx])
            completion = client.chat.completions.create(
                model=model_name,
                messages=[
                    {"role": "system", "content": SYSTEM_PROMPT},
                    {"role": "user", "content": payload}
                ],
                temperature=0.1,
                response_format={"type": "json_object"}
            )
            parsed = clean_json_response(completion.choices[0].message.content)
            if parsed:
                return parsed, None
        except Exception as e:
            if "429" in str(e) or "rate_limit" in str(e).lower():
                groq_key_idx = (groq_key_idx + 1) % len(GROQ_KEYS)
                time.sleep(2)
                continue
            return None, str(e)
    return None, "Groq keys exhausted"

def call_google(model_name, payload):
    global google_key_idx
    if not genai or not GOOGLE_KEYS:
        return None, "Google GenAI missing"
    for _ in range(len(GOOGLE_KEYS)):
        try:
            client = genai.Client(api_key=GOOGLE_KEYS[google_key_idx])
            response = client.models.generate_content(
                model=model_name,
                contents=payload,
                config=types.GenerateContentConfig(
                    system_instruction=SYSTEM_PROMPT,
                    temperature=0.1,
                    response_mime_type="application/json"
                )
            )
            parsed = clean_json_response(response.text)
            if parsed:
                return parsed, None
        except Exception as e:
            if "429" in str(e) or "RESOURCE_EXHAUSTED" in str(e):
                google_key_idx = (google_key_idx + 1) % len(GOOGLE_KEYS)
                time.sleep(2)
                continue
            return None, str(e)
    return None, "Google keys exhausted"

def call_hybrid_ai(batch_prompt):
    global current_model_idx
    total = len(MODEL_REGISTRY)

    while current_model_idx < total:
        target = MODEL_REGISTRY[current_model_idx]
        m_name = target["name"]
        provider = target["provider"]

        if provider == "groq":
            res, err = call_groq(m_name, batch_prompt)
        else:
            res, err = call_google(m_name, batch_prompt)

        if res:
            return res

        print(f"   ⚠️ Fail on {m_name}. Switching to next fallback...")
        current_model_idx += 1

    time.sleep(45)
    current_model_idx = 0
    return None

# ============================================================
# TARGET REPO DISPATCHER (PUSH VIA GITHUB REST API)
# ============================================================

def push_to_target_repo():
    """Pushes OUTPUT_FILE to target repository using GH_PAT_TOKEN via GitHub REST API."""
    token = os.environ.get("GH_PAT_TOKEN", "").strip()
    if not token:
        print("⚠️ GH_PAT_TOKEN not found in environment. Skipping cross-repo push.")
        return

    if not os.path.exists(OUTPUT_FILE):
        print(f"⚠️ {OUTPUT_FILE} not found. Nothing to push.")
        return

    print(f"\n🚀 Direct-Pushing '{OUTPUT_FILE}' to target repo ({TARGET_REPO})...")

    with open(OUTPUT_FILE, "rb") as f:
        file_bytes = f.read()

    b64_content = base64.b64encode(file_bytes).decode("utf-8")
    api_url = f"https://api.github.com/repos/{TARGET_REPO}/contents/{TARGET_FILE_PATH}"

    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json",
        "User-Agent": "NSE-AI-Sync-Engine"
    }

    # 1. Fetch current blob SHA if the file already exists in target repo
    sha = None
    try:
        check_res = requests.get(api_url, headers=headers, params={"ref": TARGET_BRANCH}, timeout=15)
        if check_res.status_code == 200:
            sha = check_res.json().get("sha")
    except Exception as e:
        print(f"⚠️ Warning while fetching existing SHA: {e}")

    # 2. Commit and Overwrite the file on target repo
    payload = {
        "message": f"⚡ Auto-Feed Sync: Corporate Updates [{(datetime.now(IST)).strftime('%d-%b-%Y %H:%M IST')}]",
        "content": b64_content,
        "branch": TARGET_BRANCH
    }
    if sha:
        payload["sha"] = sha

    try:
        put_res = requests.put(api_url, headers=headers, json=payload, timeout=20)
        if put_res.status_code in [200, 201]:
            print(f"✅ Target repo updated successfully: https://github.com/{TARGET_REPO}/blob/{TARGET_BRANCH}/{TARGET_FILE_PATH}")
        else:
            print(f"❌ Target repo push failed with status {put_res.status_code}: {put_res.text}")
    except Exception as e:
        print(f"❌ Error during target repo push: {e}")

# ============================================================
# MAIN ORCHESTRATOR
# ============================================================

def process_corporate_actions_feed():
    print("=" * 80)
    print("🚀 AI EDITORIAL GATEKEEPER & TELEGRAM DISPATCH PRODUCER")
    print(f"📅 Timestamp: {NOW.strftime('%d-%b-%Y %H:%M:%S IST')}")
    print("=" * 80)

    feed_archive = {
        "generated_at": NOW.strftime("%Y-%m-%d %H:%M:%S IST"),
        "worthy_count": 0,
        "skipped_count": 0,
        "content_feed": [],
        "skipped_archive": []
    }

    if os.path.exists(OUTPUT_FILE):
        try:
            with open(OUTPUT_FILE, "r", encoding="utf-8") as f:
                loaded = json.load(f)
                if isinstance(loaded, dict):
                    feed_archive = loaded
                    feed_archive["content_feed"] = [
                        item for item in feed_archive.get("content_feed", [])
                        if is_within_24h_of_analysis(item)
                    ]
                    feed_archive["skipped_archive"] = [
                        item for item in feed_archive.get("skipped_archive", [])
                        if is_within_24h_of_analysis(item)
                    ]
        except Exception:
            pass
    else:
        with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
            json.dump(feed_archive, f, ensure_ascii=False, indent=2)

    if not os.path.exists(INPUT_FILE):
        print(f"❌ '{INPUT_FILE}' not found! Run scraper first.")
        return

    with open(INPUT_FILE, "r", encoding="utf-8") as f:
        master_data = json.load(f)

    processed_hashes = {item["hash"] for item in feed_archive.get("content_feed", []) if "hash" in item}
    processed_hashes.update({item["hash"] for item in feed_archive.get("skipped_archive", []) if "hash" in item})

    candidates = []

    # 1. Actionable Announcements from Master Archive
    for a in master_data.get("corporate_announcements", []):
        if a.get("hash") not in processed_hashes and a.get("pdf_extracted_text"):
            candidates.append({
                "type": "ANNOUNCEMENT",
                "hash": a.get("hash"),
                "symbol": a.get("symbol"),
                "company_name": a.get("company_name"),
                "category": a.get("category"),
                "subject": a.get("subject"),
                "summary": a.get("summary"),
                "payload_text": a.get("pdf_extracted_text")[:12000],
                "broadcast_date": a.get("broadcast_date"),
                "pdf_link": a.get("pdf_link")
            })

    # 2. Financial Results from Master Archive
    for r in master_data.get("financial_results", []):
        if r.get("hash") not in processed_hashes:
            summary_str = (
                f"Revenue: ₹{r.get('revenue')} Cr (YoY: {r.get('yoy_revenue_growth')}%), "
                f"PAT: ₹{r.get('pat')} Cr (YoY: {r.get('yoy_pat_growth')}%), "
                f"Signal: {r.get('signal_tag')}, Exceptional: ₹{r.get('exceptional_items')} Cr"
            )
            candidates.append({
                "type": "FINANCIAL_RESULT",
                "hash": r.get("hash"),
                "symbol": r.get("symbol"),
                "company_name": r.get("company_name"),
                "category": "RESULT",
                "subject": f"Quarterly Result - Revenue ₹{r.get('revenue')} Cr | PAT ₹{r.get('pat')} Cr",
                "summary": summary_str,
                "payload_text": json.dumps(r, indent=2),
                "broadcast_date": r.get("result_date"),
                "pdf_link": r.get("pdf_link")
            })

    print(f"🎯 Total pending filings for processing: {len(candidates)}")

    if not candidates:
        print("✅ No pending items. Content feed is fully synchronized!")
        feed_archive["worthy_count"] = len(feed_archive["content_feed"])
        feed_archive["skipped_count"] = len(feed_archive["skipped_archive"])
        with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
            json.dump(feed_archive, f, ensure_ascii=False, indent=2)
        push_to_target_repo()
        return

    total_batches = (len(candidates) + BATCH_SIZE - 1) // BATCH_SIZE
    i = 0
    batch_counter = 1

    while i < len(candidates):
        batch = candidates[i : i + BATCH_SIZE]
        print(f"\n⚡ Processing Batch {batch_counter}/{total_batches} ({len(batch)} items)...")

        batch_payload = []
        for idx, itm in enumerate(batch, 1):
            batch_payload.append({
                "input_id": idx,
                "type": itm["type"],
                "symbol": itm["symbol"],
                "company_name": itm["company_name"],
                "category": itm["category"],
                "subject": itm["subject"],
                "summary": itm["summary"],
                "pdf_link": itm["pdf_link"],
                "details": itm["payload_text"]
            })

        prompt_str = "Evaluate filings and produce concise, factual Telegram market updates:\n" + json.dumps(batch_payload, ensure_ascii=False)
        batch_result = call_hybrid_ai(prompt_str)

        if not batch_result:
            print(f"⚠️ Batch {batch_counter} failed across all providers. Skipping batch.")
            i += BATCH_SIZE
            batch_counter += 1
            continue

        result_map = {res.get("input_id"): res for res in batch_result if isinstance(res, dict)}

        for idx, itm in enumerate(batch, 1):
            res = result_map.get(idx)
            if not res:
                continue

            is_worthy = res.get("content_worthy", False)
            headline = res.get("headline") or itm["subject"]
            telegram_post = res.get("telegram_post", "").strip()
            event_type = res.get("event_type") or itm["category"]

            # Guardrail: Drop financial results if revenue/pat figures are null or missing
            if is_worthy and itm.get("category") == "RESULT":
                post_lower = telegram_post.lower()
                if "not disclosed" in post_lower and ("revenue" in post_lower or "pat" in post_lower):
                    is_worthy = False
                    res["worthiness_reason"] = "Dropped: Zero profit/revenue metrics in results filing."

            record = {
                "hash": itm["hash"],
                "symbol": itm["symbol"],
                "company_name": itm["company_name"],
                "category": itm["category"],
                "event_type": event_type,
                "broadcast_date": itm["broadcast_date"],
                "pdf_link": itm["pdf_link"],
                "headline": headline,
                "content_worthy": is_worthy,
                "worthiness_reason": res.get("worthiness_reason", ""),
                "telegram_post": telegram_post if is_worthy else "",
                "analyzed_at": datetime.now(IST).strftime("%Y-%m-%d %H:%M:%S IST")
            }

            if is_worthy and telegram_post:
                print(f"  ⭐ [APPROVED] {itm['symbol']} | {event_type}")
                feed_archive["content_feed"].insert(0, record)
            else:
                print(f"  ⏭️ [SKIPPED]  {itm['symbol']}: {res.get('worthiness_reason', '')[:50]}")
                feed_archive["skipped_archive"].insert(0, record)

        feed_archive["content_feed"] = [item for item in feed_archive["content_feed"] if is_within_24h_of_analysis(item)]
        feed_archive["skipped_archive"] = [item for item in feed_archive["skipped_archive"] if is_within_24h_of_analysis(item)]

        feed_archive["generated_at"] = datetime.now(IST).strftime("%Y-%m-%d %H:%M:%S IST")
        feed_archive["worthy_count"] = len(feed_archive["content_feed"])
        feed_archive["skipped_count"] = len(feed_archive["skipped_archive"])

        with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
            json.dump(feed_archive, f, ensure_ascii=False, indent=2)

        i += BATCH_SIZE
        batch_counter += 1

        if i < len(candidates):
            print(f"⏳ Cooling down {BATCH_PAUSE_SECONDS}s to avoid rate limits...")
            time.sleep(BATCH_PAUSE_SECONDS)

    print("\n" + "=" * 80)
    print("✅ WORKFLOW COMPLETE:")
    print(f"   • Active Posts in Feed : {feed_archive['worthy_count']}")
    print(f"   • Filtered Records     : {len(feed_archive['skipped_archive'])}")
    print(f"💾 File Saved to          : '{OUTPUT_FILE}'")
    print("=" * 80)

    # Automatically sync final output to target app repo
    push_to_target_repo()

if __name__ == "__main__":
    process_corporate_actions_feed()
