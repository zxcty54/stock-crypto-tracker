#!/usr/bin/env python3
"""
NSE AI EDITORIAL PIPELINE — v2 (Hardened)
=========================================
v1 ke saare bugs fixed + SEBI compliance guardrails.

CHANGES vs v1:
  [FIX] Persistent dedup (seen_hashes) — 24h purge ke baad duplicate repost band
  [FIX] analyzed_at ab actually set hota hai — retention kaam karta hai
  [FIX] attempts counter — failed filings hamesha retry nahi karenge
  [FIX] input_id int coercion — silent data loss band
  [FIX] BATCH_PAUSE_SECONDS actually used
  [FIX] API key dedup (GEMINI_API_KEY prioritized)
  [FIX] RESULT guardrail source-level pe (AI se pehle)
  [NEW] HTML sanitizer (invalid tags / markdown slip se post fail nahi hogi)
  [NEW] DISCLAIMER + AI-disclosure auto-inject (har post me)
  [NEW] Number verification — AI hallucination guard
  [NEW] SME / holdings / routine-keyword pre-filter (API cost bhi bachega)

ENV VARS:
  GEMINI_API_KEY, GOOGLE_API_KEY, GOOGLE_API_KEY2, GROQ_API_KEY, GROQ_API_KEY2
  GH_PAT_TOKEN                       (optional — repo push ke liye)
  MAX_FILING_AGE_DAYS=3              (optional)
  STRICT_NUMBER_CHECK=true           (optional — mismatch pe post drop)
  BLOCK_SME=true                     (optional)
"""

import os
import re
import json
import time
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
# CONFIG
# ============================================================

INPUT_FILE  = "nse_corporate_master.json"
OUTPUT_FILE = "nse_content_feed.json"
STATE_FILE  = "nse_pipeline_state.json"          # persistent dedup + attempts

TARGET_REPO        = "zxcty54/stock-crypto-tracker"
TARGET_FILE_PATH   = "nse_content_feed.json"
TARGET_STATE_PATH  = "nse_pipeline_state.json"
TARGET_BRANCH      = "main"
PUSH_STATE         = True                          # state bhi repo me push karo

BATCH_SIZE          = 2
BATCH_PAUSE_SECONDS = 20                           # [FIX] ab actually use hota hai
GROQ_CALL_PAUSE     = 1.0                          # free tier ke liye safety

MAX_FILING_AGE_DAYS  = int(os.environ.get("MAX_FILING_AGE_DAYS", "3"))
STRICT_NUMBER_CHECK  = os.environ.get("STRICT_NUMBER_CHECK", "true").lower() == "true"
BLOCK_SME            = os.environ.get("BLOCK_SME", "true").lower() == "true"
MAX_ATTEMPTS         = 3
HASH_HISTORY_DAYS    = 180
MAX_HASH_HISTORY     = 50000

# Tumhari personal holdings — in symbols ka post auto-skip (conflict of interest)
MY_HOLDINGS = {"EXAMPLE1", "EXAMPLE2"}             # <-- apne symbols daalo

# Manual blocklist — jin symbols ko post nahi karna (SME, illiquid, past issues)
BLOCKED_SYMBOLS = set()                            # <-- apne symbols daalo

IST = timezone(timedelta(hours=5, minutes=30))
NOW = datetime.now(IST)
CUTOFF_24H_ANALYZED = NOW - timedelta(hours=24)


MODEL_REGISTRY = [
    {"name": "openai/gpt-oss-20b",       "provider": "groq"},
    {"name": "openai/gpt-oss-120b",      "provider": "groq"},
    {"name": "gemini-2.5-flash",         "provider": "google"},
    {"name": "gemini-2.5-flash-lite",    "provider": "google"},
]

# [FIX] dedup — same key do env vars me ho to rotation useless ho jaati thi
def _collect_keys(names):
    vals = [os.environ.get(n, "").strip() for n in names]
    return list(dict.fromkeys([v for v in vals if v]))

GROQ_KEYS   = _collect_keys(["GROQ_API_KEY", "GROQ_API_KEY2"])
# 🎯 GEMINI_API_KEY ko pehli priority di gayi hai:
GOOGLE_KEYS = _collect_keys(["GEMINI_API_KEY", "GOOGLE_API_KEY", "GOOGLE_API_KEY2"])

if not GROQ_KEYS and not GOOGLE_KEYS:
    print("❌ FATAL: No API keys found! Exiting.")
    raise SystemExit(1)

groq_key_idx = 0
google_key_idx = 0
current_model_idx = 0


# ============================================================
# PRE-FILTER (routine disclosures — API call se pehle hi reject)
# ============================================================

ROUTINE_PATTERNS = [
    r"newspaper (publication|clipping|advertisement|notice)",
    r"publication (of|in) newspaper",
    r"trading window",
    r"\besop\b",
    r"employee stock option",
    r"loss of share certificate",
    r"duplicate share certificate",
    r"compliance certificate",
    r"investor grievance",
    r"scrutinizer",
    r"postal ballot",
    r"book closure",
    r"regulation\s*7\s*\(\s*2\s*\)",
    r"regulation\s*29\b",
    r"inter-?se\s+transfer",
    r"transmission of shares",
    r"gift of shares",
    r"(release|creation) of pledge",
    r"pledge of shares",
    r"encumbrance",
    r"annual general meeting",
    r"extraordinary general meeting",
    r"board meeting intimation",
    r"intimation of (the )?board meeting",
]
ROUTINE_RE = re.compile("|".join(ROUTINE_PATTERNS), re.I)

SME_RE = re.compile(r"\bSME\b|\bNSE\s?Emerge\b|\bBSE\s?SME\b", re.I)


def prefilter(item):
    """Return skip-reason string, or None if it should go to AI."""
    text = f"{item.get('company_name','')} {item.get('subject','')} {item.get('category','')}"

    if ROUTINE_RE.search(text):
        return "routine_disclosure_prefilter"

    if BLOCK_SME and SME_RE.search(text):
        return "sme_company"

    sym = (item.get("symbol") or "").upper().strip()
    if sym in BLOCKED_SYMBOLS:
        return "blocked_symbol"
    if sym in MY_HOLDINGS:
        return "my_holding_conflict"

    return None


# ============================================================
# SYSTEM PROMPT (NEWSROOM EDITOR — FACTUAL FLASH ALERTS)
# ============================================================

SYSTEM_PROMPT = """
You are a senior financial news editor covering Indian listed companies and NSE/BSE corporate announcements.

Your task is to convert raw corporate filings into SHORT, FACTUAL, TELEGRAM-READY market updates.

============================================================
1. PRIMARY OBJECTIVE
============================================================
For every filing:
1. Decide whether it is content-worthy based on commercial and corporate materiality.
​2. Identify the correct event type.
3. Extract only material facts explicitly available in the supplied data.
4. Write a concise Telegram post.
5. Never invent, infer, exaggerate, or speculate.

The output should feel like a professional financial-news alert, NOT an editorial research thesis.

============================================================
2. CONTENT-WORTHINESS & STRICT REJECTIONS
============================================================
Set "content_worthy": false for the following (MANDATORY REJECTIONS):
- PROMOTER INTER-SE TRANSFERS: internal promoter share transfer, family settlement, gift of shares, or inter-se acquisition under SEBI SAST Regulation 10.
- ROUTINE DISCLOSURES: SAST Reg 29, Insider Trading Reg 7(2), pledge creation/release, ESOP share allotments.
- DUPLICATE / POST-EVENT NOTICES: newspaper clippings, post-buyback advertisement notices, procedural meeting updates.
- Routine compliance, generic administrative notices, trading-window closures.

Set "content_worthy": true ONLY for real commercial inflection points:
- Genuine commercial M&A (acquiring third-party companies/plants).
- Real order wins, capex commissioning, major product launches, regulatory approvals (USFDA), material litigations.
- Direct corporate actions: first-time buyback approvals, dividends, bonus/splits, rights/QIP issues.
- Financial results with actual numeric Revenue and PAT.

============================================================
3. STRICT SOURCE DISCIPLINE & NO-HYPE RULE
============================================================
Use ONLY facts explicitly available in the input payload.
- NEVER use outside knowledge.
- NEVER invent numbers, dates, counterparties, or strategic rationale.
- NEVER invent management intentions or predict stock price / future performance.
- NEVER state or imply price levels, entry, stop-loss, targets, or "watch this stock".
- NEVER use subjective puffery or promotional labels like "positive", "negative", "bullish", "accretive", "transformational", "major", "game-changing".
- NEVER calculate derived figures (growth %, EPS impact, annualised values) unless that exact figure is present in the payload.
- If a detail is not disclosed, simply omit it. Do NOT write "Not disclosed" repeatedly.

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

Do NOT add any disclaimer or AI-notice line — the system appends that automatically.

============================================================
5. EVENT SPECIFIC RULES
============================================================
- BUYBACK: shares, price, total consideration, route, record date, status (proposed/approved/completed). Do NOT calculate EPS uplift or cash depletion unless stated.
- RESULTS: filing MUST contain actual numeric Revenue and PAT. If either is missing/"not disclosed", set content_worthy false.
- DIVIDEND: DPS, type (interim/final), record date, payment date.
- BONUS / SPLIT: ratio, record date, effective date.
- ORDER / CONTRACT: order value, client/counterparty, execution period, geography. Do not invent margins.
- CAPEX / EXPANSION: investment amount, capacity, location, commissioning timeline. Never annualise unless the filing frames it as a monthly metric.
- APPOINTMENT / RESIGNATION: name, designation, effective date, disclosed reason only.

============================================================
6. TELEGRAM FORMATTING RULES
============================================================
- Use valid Telegram HTML: <b>, <i>, <a>, <code>. No markdown asterisks, no markdown links.
- Keep post under 900 characters.

Layout:

{ICON} <b>#{EVENT_TYPE}</b> | <b>{company_name} (NSE: {symbol})</b>

<b>{headline}</b>
━━━━━━━━━━━━━━━━━━━━━

🔹 <b>Key Details:</b>
- <b>{Field}:</b> {Value}
- <b>{Field}:</b> {Value}
- <b>{Field}:</b> {Value}

📍 <b>What happened:</b>
↳ {1-2 concise factual sentences based strictly on filing}
━━━━━━━━━━━━━━━━━━━━━
📍 <b>Source:</b> <a href="{pdf_link}">NSE Corporate Filing</a>

CATEGORY ICONS: BUYBACK 💰 | DIVIDEND 💵 | BONUS 🎁 | STOCK_SPLIT ✂️ | RESULT 📊 |
ORDER_WIN 📜 | CONTRACT 📜 | CAPEX 🏭 | COMMERCIAL_PRODUCTION 🏭 | ACQUISITION 🤝 |
JOINT_VENTURE 🤝 | MERGER 🔄 | DEMERGER 🔄 | FUNDRAISING 💰 | QIP 💰 | RIGHTS_ISSUE 💰 |
NEW_PRODUCT 🚀 | REGULATORY_APPROVAL ✅ | USFDA_OBSERVATION ⚠️ | LITIGATION ⚖️ |
RESIGNATION 👤 | APPOINTMENT 👤 | CREDIT_RATING 🏦 | OTHER ⚡

============================================================
7. OUTPUT FORMAT
============================================================
Return strictly a valid JSON object without markdown code blocks:

{
  "items": [
    {
      "input_id": 1,
      "content_worthy": true,
      "worthiness_reason": "Crisp 1-line reason.",
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


# ============================================================
# HTML SANITIZER + DISCLAIMER
# ============================================================

ALLOWED_TAGS = {"b", "strong", "i", "em", "u", "s", "code", "pre", "a", "br"}


def sanitize_telegram_html(text):
    """Telegram Bot API (parse_mode=HTML) ke liye safe banao."""
    if not text:
        return ""

    text = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", text, flags=re.S)

    def _tag(m):
        tag = m.group(2).lower()
        return m.group(0) if tag in ALLOWED_TAGS else ""

    text = re.sub(r"<(/?)([a-zA-Z][a-zA-Z0-9]*)([^<>]*)>", _tag, text)
    text = re.sub(r"<(?![a-zA-Z/])", "&lt;", text)
    text = re.sub(r"(?<![\"=a-zA-Z])>(?![a-zA-Z])", "&gt;", text)
    text = re.sub(r"&(?!(amp|lt|gt|quot|apos|#\d+|#x[0-9a-fA-F]+);)", "&amp;", text)

    return text.strip()


DISCLAIMER_BLOCK = (
    "\n\n⚠️ <i>Educational only. Not investment advice. Not SEBI registered.</i>\n"
    "🤖 <i>AI-assisted summary of public filing. Numbers verify karne ke liye "
    "source link dekho.</i>"
)


def inject_disclaimer(post):
    """Har post me disclaimer — agar already nahi hai to."""
    if not post:
        return post
    if "Not SEBI registered" in post:
        return post
    return post.rstrip() + DISCLAIMER_BLOCK


# ============================================================
# NUMBER VERIFICATION (hallucination guard)
# ============================================================

NUM_RE = re.compile(r"\d[\d,]*(?:\.\d+)?")


def _extract_numbers(text):
    out = []
    for m in NUM_RE.finditer(text or ""):
        raw = m.group(0)
        try:
            val = float(raw.replace(",", ""))
        except ValueError:
            continue
        ctx = (text or "")[max(0, m.start() - 14): m.end() + 14]
        out.append((raw, val, ctx))
    return out


MONTH_RE = r"(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)"


def _is_context_number(raw, val, ctx):
    if re.search(r"\d\s*:\s*\d", ctx):
        return True

    is_int = "." not in raw

    if is_int and 2000 <= val <= 2100:
        return True

    if is_int and 1 <= val <= 31:
        if re.search(rf"\b\d{{1,2}}\s*[-\s]?\s*{MONTH_RE}", ctx, re.I):
            return True
        if re.search(r"\d{1,2}\s*[/-]\s*\d{1,2}", ctx):
            return True

    return False


def verify_numbers(post_html, source_text):
    src_canon, src_vals = set(), set()
    for raw, val, _ in _extract_numbers(source_text):
        src_canon.add(raw.replace(",", ""))
        src_vals.add(round(val, 2))

    missing = []
    for raw, val, ctx in _extract_numbers(post_html):
        if raw.replace(",", "") in src_canon or round(val, 2) in src_vals:
            continue
        if _is_context_number(raw, val, ctx):
            continue
        missing.append(raw)
    return missing


# ============================================================
# PROVIDERS
# ============================================================

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
        if isinstance(data, list):
            return data
    except Exception:
        arr = re.search(r"\[[\s\S]*\]", text)
        if arr:
            try:
                return json.loads(arr.group(0))
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
                    {"role": "user", "content": payload},
                ],
                temperature=0.1,
                response_format={"type": "json_object"},
            )
            parsed = clean_json_response(completion.choices[0].message.content)
            if parsed:
                return parsed, None
            return None, "empty/unparsable response"
        except Exception as e:
            low = str(e).lower()
            if "429" in str(e) or "rate_limit" in low or "rate limit" in low:
                groq_key_idx = (groq_key_idx + 1) % len(GROQ_KEYS)
                time.sleep(2)
                continue
            return None, str(e)
        finally:
            time.sleep(GROQ_CALL_PAUSE)
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
                    response_mime_type="application/json",
                ),
            )
            parsed = clean_json_response(response.text)
            if parsed:
                return parsed, None
            return None, "empty/unparsable response"
        except Exception as e:
            if "429" in str(e) or "RESOURCE_EXHAUSTED" in str(e):
                google_key_idx = (google_key_idx + 1) % len(GOOGLE_KEYS)
                time.sleep(2)
                continue
            return None, str(e)
        finally:
            time.sleep(GROQ_CALL_PAUSE)
    return None, "Google keys exhausted"


def call_hybrid_ai(batch_prompt):
    global current_model_idx
    total = len(MODEL_REGISTRY)

    while current_model_idx < total:
        target = MODEL_REGISTRY[current_model_idx]
        provider = target["provider"]
        print(f"   🤖 trying {target['name']} ({provider})")

        res, err = (call_groq(target["name"], batch_prompt) if provider == "groq"
                    else call_google(target["name"], batch_prompt))

        if res:
            return res

        print(f"   ⚠️ Fail on {target['name']}: {err}. Switching fallback...")
        current_model_idx += 1

    time.sleep(45)
    current_model_idx = 0
    return None


# ============================================================
# STATE (persistent dedup + attempts)
# ============================================================

def load_state():
    state = {"seen_hashes": {}, "attempts": {}, "last_run": None}
    if os.path.exists(STATE_FILE):
        try:
            with open(STATE_FILE, "r", encoding="utf-8") as f:
                loaded = json.load(f)
                if isinstance(loaded, dict):
                    state.update(loaded)
        except Exception:
            pass

    cutoff = (NOW - timedelta(days=HASH_HISTORY_DAYS)).strftime("%Y-%m-%d")
    seen = {h: d for h, d in state.get("seen_hashes", {}).items() if d >= cutoff}
    if len(seen) > MAX_HASH_HISTORY:
        newest = sorted(seen.items(), key=lambda kv: kv[1], reverse=True)[:MAX_HASH_HISTORY]
        seen = dict(newest)
    state["seen_hashes"] = seen
    state["attempts"] = {h: n for h, n in state.get("attempts", {}).items() if h in seen}
    return state


def save_state(state):
    state["last_run"] = NOW.strftime("%Y-%m-%d %H:%M:%S IST")
    with open(STATE_FILE, "w", encoding="utf-8") as f:
        json.dump(state, f, ensure_ascii=False, indent=2)


def is_within_24h_of_analysis(item):
    analyzed_str = (item.get("analyzed_at") or "").replace(" IST", "").strip()
    if not analyzed_str:
        return True
    try:
        dt = datetime.strptime(analyzed_str, "%Y-%m-%d %H:%M:%S").replace(tzinfo=IST)
        return dt >= CUTOFF_24H_ANALYZED
    except Exception:
        return True


def is_recent_enough(date_str):
    if not date_str:
        return True
    for fmt in ("%Y-%m-%d", "%d-%b-%Y", "%d-%m-%Y", "%Y-%m-%d %H:%M:%S"):
        try:
            dt = datetime.strptime(str(date_str)[:19], fmt).replace(tzinfo=IST)
            return (NOW - dt) <= timedelta(days=MAX_FILING_AGE_DAYS)
        except Exception:
            continue
    return True


# ============================================================
# REPO PUSH
# ============================================================

def push_file_to_repo(local_path, remote_path, commit_prefix="⚡ Auto-Feed Sync"):
    token = os.environ.get("GH_PAT_TOKEN", "").strip()
    if not token:
        print("⚠️ GH_PAT_TOKEN not found. Skipping repo push.")
        return
    if not os.path.exists(local_path):
        print(f"⚠️ {local_path} not found. Nothing to push.")
        return

    with open(local_path, "rb") as f:
        b64_content = base64.b64encode(f.read()).decode("utf-8")

    api_url = f"[https://api.github.com/repos/](https://api.github.com/repos/){TARGET_REPO}/contents/{remote_path}"
    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json",
        "User-Agent": "NSE-AI-Sync-Engine",
    }

    sha = None
    existing_b64 = None
    try:
        r = requests.get(api_url, headers=headers, params={"ref": TARGET_BRANCH}, timeout=15)
        if r.status_code == 200:
            j = r.json()
            sha = j.get("sha")
            existing_b64 = (j.get("content") or "").replace("\n", "")
    except Exception as e:
        print(f"⚠️ SHA fetch warning: {e}")

    if existing_b64 and existing_b64 == b64_content:
        print(f"ℹ️ {remote_path} unchanged — push skipped.")
        return

    payload = {
        "message": f"{commit_prefix}: {remote_path} [{NOW.strftime('%d-%b-%Y %H:%M IST')}]",
        "content": b64_content,
        "branch": TARGET_BRANCH,
    }
    if sha:
        payload["sha"] = sha

    for attempt in range(3):
        try:
            put = requests.put(api_url, headers=headers, json=payload, timeout=20)
            if put.status_code in (200, 201):
                print(f"✅ pushed: {remote_path}")
                return
            print(f"❌ push failed {put.status_code}: {put.text[:200]}")
        except Exception as e:
            print(f"❌ push error: {e}")
        time.sleep(3 * (attempt + 1))
    print(f"❌ Giving up on {remote_path}")


def push_to_target_repo():
    print(f"\n🚀 Pushing to {TARGET_REPO}...")
    push_file_to_repo(OUTPUT_FILE, TARGET_FILE_PATH)
    if PUSH_STATE:
        push_file_to_repo(STATE_FILE, TARGET_STATE_PATH, commit_prefix="🧠 Pipeline State")


# ============================================================
# MAIN
# ============================================================

def process_corporate_actions_feed():
    print("=" * 80)
    print("🚀 AI EDITORIAL GATEKEEPER v2 — NSE CORPORATE FEED")
    print(f"📅 {NOW.strftime('%d-%b-%Y %H:%M:%S IST')}")
    print("=" * 80)

    state = load_state()
    seen_hashes = state["seen_hashes"]
    attempts = state["attempts"]

    feed_archive = {
        "generated_at": NOW.strftime("%Y-%m-%d %H:%M:%S IST"),
        "worthy_count": 0,
        "skipped_count": 0,
        "content_feed": [],
        "skipped_archive": [],
    }

    if os.path.exists(OUTPUT_FILE):
        try:
            with open(OUTPUT_FILE, "r", encoding="utf-8") as f:
                loaded = json.load(f)
            if isinstance(loaded, dict):
                feed_archive.update({
                    "content_feed": [i for i in loaded.get("content_feed", [])
                                     if is_within_24h_of_analysis(i)],
                    "skipped_archive": [i for i in loaded.get("skipped_archive", [])
                                        if is_within_24h_of_analysis(i)],
                })
        except Exception as e:
            print(f"⚠️ Feed load warning: {e}")

    if not os.path.exists(INPUT_FILE):
        print(f"❌ '{INPUT_FILE}' not found! Run scraper first.")
        return

    with open(INPUT_FILE, "r", encoding="utf-8") as f:
        master_data = json.load(f)

    already = set(seen_hashes.keys())
    already.update(i.get("hash") for i in feed_archive["content_feed"] if i.get("hash"))
    already.update(i.get("hash") for i in feed_archive["skipped_archive"] if i.get("hash"))

    candidates = []

    for a in master_data.get("corporate_announcements", []):
        h = a.get("hash")
        if h and h not in already and a.get("pdf_extracted_text"):
            candidates.append({
                "type": "ANNOUNCEMENT",
                "hash": h,
                "symbol": a.get("symbol"),
                "company_name": a.get("company_name"),
                "category": a.get("category"),
                "subject": a.get("subject"),
                "summary": a.get("summary"),
                "payload_text": (a.get("pdf_extracted_text") or "")[:12000],
                "broadcast_date": a.get("broadcast_date"),
                "pdf_link": a.get("pdf_link"),
            })

    for r in master_data.get("financial_results", []):
        h = r.get("hash")
        if not h or h in already:
            continue
        if r.get("revenue") is None or r.get("pat") is None:
            seen_hashes[h] = NOW.strftime("%Y-%m-%d")
            feed_archive["skipped_archive"].append({
                "hash": h, "symbol": r.get("symbol"),
                "company_name": r.get("company_name"),
                "reason": "missing_revenue_or_pat_in_source",
                "analyzed_at": NOW.strftime("%Y-%m-%d %H:%M:%S IST"),
            })
            continue
        candidates.append({
            "type": "FINANCIAL_RESULT",
            "hash": h,
            "symbol": r.get("symbol"),
            "company_name": r.get("company_name"),
            "category": "RESULT",
            "subject": f"Quarterly Result - Revenue ₹{r.get('revenue')} Cr | PAT ₹{r.get('pat')} Cr",
            "summary": (
                f"Revenue: ₹{r.get('revenue')} Cr (YoY: {r.get('yoy_revenue_growth')}%), "
                f"PAT: ₹{r.get('pat')} Cr (YoY: {r.get('yoy_pat_growth')}%), "
                f"Signal: {r.get('signal_tag')}, Exceptional: ₹{r.get('exceptional_items')} Cr"
            ),
            "payload_text": json.dumps(r, indent=2, ensure_ascii=False),
            "broadcast_date": r.get("result_date"),
            "pdf_link": r.get("pdf_link"),
        })

    filtered = []
    for itm in candidates:
        h = itm["hash"]

        skip = prefilter(itm)
        if skip:
            seen_hashes[h] = NOW.strftime("%Y-%m-%d")
            feed_archive["skipped_archive"].append({
                "hash": h, "symbol": itm.get("symbol"),
                "company_name": itm.get("company_name"),
                "reason": skip,
                "analyzed_at": NOW.strftime("%Y-%m-%d %H:%M:%S IST"),
            })
            continue

        if not is_recent_enough(itm.get("broadcast_date")):
            seen_hashes[h] = NOW.strftime("%Y-%m-%d")
            feed_archive["skipped_archive"].append({
                "hash": h, "symbol": itm.get("symbol"),
                "company_name": itm.get("company_name"),
                "reason": f"older_than_{MAX_FILING_AGE_DAYS}_days",
                "analyzed_at": NOW.strftime("%Y-%m-%d %H:%M:%S IST"),
            })
            continue

        filtered.append(itm)

    print(f"🎯 Candidates: {len(candidates)} → after pre-filter: {len(filtered)}")

    if not filtered:
        print("✅ Nothing pending. Feed synchronized.")
        _finalize(feed_archive, state)
        return

    total_batches = (len(filtered) + BATCH_SIZE - 1) // BATCH_SIZE
    i = 0
    batch_counter = 1

    while i < len(filtered):
        batch = filtered[i:i + BATCH_SIZE]
        print(f"\n⚡ Batch {batch_counter}/{total_batches} ({len(batch)} items)")

        batch_payload = [{
            "input_id": idx,
            "type": itm["type"],
            "symbol": itm["symbol"],
            "company_name": itm["company_name"],
            "category": itm["category"],
            "subject": itm["subject"],
            "summary": itm["summary"],
            "pdf_link": itm["pdf_link"],
            "details": itm["payload_text"],
        } for idx, itm in enumerate(batch, 1)]

        prompt_str = ("Evaluate filings and produce concise, factual Telegram market updates:\n"
                      + json.dumps(batch_payload, ensure_ascii=False))

        batch_result = call_hybrid_ai(prompt_str)

        if not batch_result:
            print(f"⚠️ Batch {batch_counter} failed on all providers.")
            for itm in batch:
                h = itm["hash"]
                attempts[h] = attempts.get(h, 0) + 1
                seen_hashes.setdefault(h, NOW.strftime("%Y-%m-%d"))
                if attempts[h] >= MAX_ATTEMPTS:
                    feed_archive["skipped_archive"].append({
                        "hash": h, "symbol": itm.get("symbol"),
                        "company_name": itm.get("company_name"),
                        "reason": f"processing_failed_after_{MAX_ATTEMPTS}_attempts",
                        "analyzed_at": NOW.strftime("%Y-%m-%d %H:%M:%S IST"),
                    })
            i += BATCH_SIZE
            batch_counter += 1
            continue

        result_map = {}
        for r in batch_result:
            if not isinstance(r, dict):
                continue
            try:
                result_map[int(r.get("input_id"))] = r
            except (TypeError, ValueError):
                continue

        for idx, itm in enumerate(batch, 1):
            res = result_map.get(idx)
            h = itm["hash"]
            analyzed_at = NOW.strftime("%Y-%m-%d %H:%M:%S IST")

            if not res:
                print(f"   ⚠️ No AI result for input_id={idx} ({itm.get('symbol')})")
                attempts[h] = attempts.get(h, 0) + 1
                continue

            is_worthy = bool(res.get("content_worthy", False))
            headline = res.get("headline") or itm["subject"]
            event_type = res.get("event_type") or itm.get("category") or "OTHER"
            post = sanitize_telegram_html(res.get("telegram_post", ""))
            reason = res.get("worthiness_reason", "")

            if is_worthy and post:
                source_blob = " ".join(str(x) for x in [
                    itm.get("subject"), itm.get("summary"), itm.get("payload_text"),
                ])
                missing = verify_numbers(post, source_blob)
                if missing:
                    note = f"unverified_numbers: {', '.join(missing[:5])}"
                    print(f"   🚷 {itm.get('symbol')}: {note}")
                    if STRICT_NUMBER_CHECK:
                        is_worthy = False
                        reason = f"Numeric mismatch (source me nahi mila): {', '.join(missing[:5])}"
                    else:
                        reason = f"{reason} | ⚠️ {note}"

            if is_worthy and post:
                post = inject_disclaimer(post)

            if is_worthy and post:
                feed_archive["content_feed"].append({
                    "hash": h,
                    "analyzed_at": analyzed_at,
                    "symbol": itm.get("symbol"),
                    "company_name": itm.get("company_name"),
                    "event_type": event_type,
                    "headline": headline,
                    "worthiness_reason": reason,
                    "broadcast_date": itm.get("broadcast_date"),
                    "pdf_link": itm.get("pdf_link"),
                    "telegram_post": post,
                })
                print(f"   ✅ {itm.get('symbol')} — {event_type}")
            else:
                feed_archive["skipped_archive"].append({
                    "hash": h,
                    "analyzed_at": analyzed_at,
                    "symbol": itm.get("symbol"),
                    "company_name": itm.get("company_name"),
                    "event_type": event_type,
                    "headline": headline,
                    "reason": reason or "not_content_worthy",
                    "analyzed_at_24h": analyzed_at,
                })
                print(f"   ⏭️ {itm.get('symbol')} skipped — {(reason or 'not worthy')[:70]}")

            seen_hashes[h] = NOW.strftime("%Y-%m-%d")
            attempts.pop(h, None)

        i += BATCH_SIZE
        batch_counter += 1

        if i < len(filtered):
            print(f"   💤 pause {BATCH_PAUSE_SECONDS}s (rate-limit safety)")
            time.sleep(BATCH_PAUSE_SECONDS)

    _finalize(feed_archive, state)


def _finalize(feed_archive, state):
    feed_archive["worthy_count"] = len(feed_archive["content_feed"])
    feed_archive["skipped_count"] = len(feed_archive["skipped_archive"])

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(feed_archive, f, ensure_ascii=False, indent=2)
    print(f"\n📄 {OUTPUT_FILE}: {feed_archive['worthy_count']} worthy, "
          f"{feed_archive['skipped_count']} skipped")

    save_state(state)
    print(f"🧠 state saved: {len(state['seen_hashes'])} hashes remembered")

    push_to_target_repo()


if __name__ == "__main__":
    process_corporate_actions_feed()
