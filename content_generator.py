#!/usr/bin/env python3
"""
CONTENT FACTORY — Production Grade Engine
Automated, SEBI-compliant content generation for Telegram.
"""

import os
import re
import sys
import json
import time
import random
import difflib
from datetime import datetime, timezone, timedelta

# ============================================================
# CONFIGURATION & TUNING
# ============================================================
QUEUE_FILE   = "content_queue.json"
USED_FILE    = "content_topics_used.json"

BATCH_SIZE        = 6         # Safe token limit (6 posts per prompt prevents truncated JSON)
DEFAULT_COUNT     = 18        # Default 18 posts (~6 days buffer @ 3 posts/day)
MIN_RUNWAY_DAYS   = 20        # Skip generation if queue already has >= 20 days runway
SIMILARITY_MAX    = 0.72      # Reject posts if similarity > 72%
REUSE_AFTER_DAYS  = 180       # Cycle old topics only after 6 months

IST = timezone(timedelta(hours=5, minutes=30))
NOW = datetime.now(IST)

# Post presentation angles
ANGLES = [
    "step-by-step practical guide ki tarah likho",
    "common retail mistakes ki checklist banao",
    "ek relatable real trading scene se shuru karo",
    "myth vs reality clear comparison format me likho",
    "beginner friendly simple Hinglish me samjhao",
    "practical numbers aur capital example ke saath explain karo",
    "pehle kya galat hota hai aur uska sahi corrective process kya hai",
]

# ============================================================
# TOPIC POOL (10 PILLARS)
# ============================================================
TOPIC_POOL = {
    "psychology": [
        "FOMO", "revenge trading", "overtrading", "boredom trades", "loss acceptance",
        "patience kaise build karein", "comparison trap", "tilt kaise rokein",
        "greed ka management", "sunk cost fallacy", "ego aur trading",
        "fear of missing out vs fear of losing", "loss ke baad ka reset routine",
        "discipline kaise banayein (habit science)", "news ke reaction me trade karna"
    ],
    "risk": [
        "1% rule", "position sizing formula", "drawdown math", "max daily loss limit",
        "risk:reward ka jhoot", "leverage ka sach", "portfolio heat",
        "trailing stop ka use", "gap risk aur overnight risk", "risk of ruin",
        "max trades per day rule", "position size aur neend ka connection"
    ],
    "technical": [
        "support aur resistance ke 3 rule", "trend vs range", "market structure (HH-HL)",
        "volume ka matlab", "candlestick anatomy", "moving average ka sahi use",
        "RSI overbought oversold ka sach", "divergence kya batati hai", "breakout vs fakeout",
        "multiple timeframes kaise combine karein", "relative strength (stock vs index)"
    ],
    "process": [
        "trading journal ke columns", "pre-trade checklist", "trading plan kaise likhein",
        "daily routine 30 minute", "watchlist template", "pre-market preparation",
        "post-market review", "apne rules likhna", "edge kya hota hai"
    ],
    "corporate": [
        "bonus issue kaise kaam karta hai", "stock split vs bonus", "buyback ka mechanism",
        "dividend: record date aur ex-date", "order win ke 4 critical sawaal",
        "promoter pledge kaise dekhein", "auditor resignation red flag",
        "cash flow vs profit", "quarterly result ke 4 number"
    ],
    "business_model": [
        "bank paisa kaise kamata hai", "NBFC vs bank", "IT company ka model",
        "cement industry ka cycle", "insurance company ka float",
        "retail chain unit economics", "asset light vs asset heavy models"
    ],
    "market_mechanics": [
        "FII DII flow kaise padhein", "market breadth kya batati hai", "bid-ask spread",
        "liquidity ka matlab", "circuit limit kaise lagti hai", "ASM aur GSM list kya hai",
        "bulk deal vs block deal", "settlement cycle (T+1)"
    ],
    "awareness": [
        "SEBI registration kaise verify karein", "guaranteed returns myth",
        "free tips group ke red flags", "fake profit screenshots kaise pehchane",
        "loss recovery scam channels", "performance claims verify kaise karein"
    ],
    "tools": [
        "position size calculator ka use", "screener alerts setup",
        "tradingview layout management", "excel me P&L aur hit rate track karna"
    ],
    "lifestyle": [
        "kitna capital chahiye shuru karne ke liye", "emergency fund vs trading capital",
        "SIP vs trading ka honest comparison", "job ke saath part time trading",
        "screen time aur decision fatigue", "compounding ka patience"
    ]
}

# ============================================================
# 🛡️ COMPLIANCE & SAFETY FILTERS
# ============================================================
BANNED_WORDS = [
    "guaranteed", "guarantee", "sure shot", "sureshot", "jackpot", "multibagger",
    "risk free", "risk-free", "double your money", "assured return", "assured profit",
    "100% accuracy", "no loss", "pakka", "fixed return", "paisa double"
]

COMPANY_NAMES = [
    "reliance", "tcs", "hdfc", "infosys", "icici", "sbi", "airtel", "itc", "l&t",
    "kotak", "axis", "maruti", "asian paints", "bajaj finance", "hul", "adani",
    "tata motors", "tata steel", "wipro", "zomato", "paytm", "nykaa", "dmart",
    "irfc", "rvnl", "ireda", "bhel", "hal"
]

ADVICE_PATTERNS = [
    r"\b(buy|sell|long|short)\s+(above|below|at|near|around)\s+[\d₹]",
    r"\b(target|tgt|sl|stop\s?loss|entry|exit)\s*[:\-=]\s*₹?\s*\d+(?!\s*%)",
    r"\b(entry|position|trade)\s+le\s*lo\b",
    r"\b(kharid|bech)\s*(lo|do|dena)\b",
    r"\b\d+\s*%\s*(return|profit|gain)\b"
]

def scan_compliance(text):
    reasons = []
    low = text.lower()

    for w in BANNED_WORDS:
        if w in low:
            reasons.append(f"Banned word: '{w}'")

    for c in COMPANY_NAMES:
        if re.search(rf"\b{re.escape(c)}\b", low):
            reasons.append(f"Company name: '{c}'")

    for pat in ADVICE_PATTERNS:
        m = re.search(pat, low)
        if m:
            reasons.append(f"Advice pattern: '{m.group(0)[:35]}'")

    # Regulatory Disclaimer check
    if "not sebi registered" not in low and "sebi registered nahi" not in low:
        reasons.append("Disclaimer missing")

    if len(text) < 120:
        reasons.append("Too short (<120 chars)")
    if len(text) > 2200:
        reasons.append("Too long (>2200 chars)")

    return (len(reasons) == 0), reasons

# ============================================================
# DEDUPLICATION & REUSE
# ============================================================
def normalize_text(text):
    t = re.sub(r"#\w+", " ", text.lower())
    t = re.sub(r"⚠️|not investment advice|not sebi registered", " ", t)
    t = re.sub(r"[^a-z0-9\s]", " ", t)
    return re.sub(r"\s+", " ", t).strip()

def is_duplicate(text, existing_norm, threshold=SIMILARITY_MAX):
    norm = normalize_text(text)
    if not norm:
        return False, 0.0
    for old in existing_norm:
        ratio = difflib.SequenceMatcher(None, norm[:800], old[:800]).ratio()
        if ratio >= threshold:
            return True, ratio
    return False, 0.0

def topic_key_of(label):
    return re.sub(r"[^a-z0-9]+", "_", label.lower()).strip("_")[:50]

# ============================================================
# AI GENERATION ENGINE (GEMINI)
# ============================================================
PROMPT_TEMPLATE = """You are writing educational Telegram posts for an Indian stock market education channel.
Topics to cover:
{topics}

STRICT SEBI & EDITORIAL GUIDELINES:
- No company or stock names (No Reliance, TCS, HDFC, Adani, etc.)
- No price levels, entry, stop-loss, or target numbers.
- No profit or return claims (No 'guaranteed', 'multibagger', 'sure shot').
- Focus 100% on concepts, math, logic, risk management, and discipline.
- Language: Engaging Hinglish (Hindi + English) as Indian traders communicate.
- Length: 120-180 words per post.

TELEGRAM FORMATTING SPECIFICATION (Strictly maintain exact line breaks and spacing):
Line 1: 📌 TOPIC: Catchy Headline
[Blank line]
Hook line: Relatable question or real trading scenario that grabs attention.
[Blank line]
Core Breakdown (Use 3 bullet points using '•' with clear explanation):
• Point 1: Explanation with practical logic or capital example (e.g. ₹1,00,000 capital).
• Point 2: The common trap or retail mistake people make.
• Point 3: The practical corrective rule or solution.
[Blank line]
💡 Golden Rule: One memorable, impactful punchline.
[Blank line]
━━━━━━━━━━━━━━━━━━━━━
#TradingPsychology #RiskManagement
⚠️ Educational only. Not investment advice. Not SEBI registered.

Return ONLY valid JSON matching this schema:
{{"posts": [{{"topic_key": "key", "text": "complete post text"}}]}}"""

def get_api_key():
    return (os.environ.get("GEMINI_API_KEY") or 
            os.environ.get("GOOGLE_API_KEY") or 
            os.environ.get("GROQ_API_KEY") or "").strip()

def call_ai(topics, angles):
    api_key = get_api_key()
    if not api_key:
        print("❌ Error: No AI API Key found in environment variables.")
        return []

    topic_lines = "\n".join(f"- {t} (Angle: {a})" for t, a in zip(topics, angles))
    prompt = PROMPT_TEMPLATE.format(topics=topic_lines)

    # Gemini API Call (Direct REST endpoint, zero SDK dependencies)
    url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent?key={api_key}"
    payload = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {
            "temperature": 0.7,
            "responseMimeType": "application/json"
        }
    }

    try:
        import requests
        res = requests.post(url, json=payload, headers={"Content-Type": "application/json"}, timeout=30)
        if res.status_code == 200:
            raw = res.json()["candidates"][0]["content"]["parts"][0]["text"].strip()
            data = json.loads(raw)
            return data.get("posts", [])
        else:
            print(f"   ⚠️ Gemini returned HTTP {res.status_code}: {res.text[:150]}")
    except Exception as e:
        print(f"   ⚠️ AI call failed: {e}")

    return []

# ============================================================
# QUEUE SCHEDULER (3 POSTS/DAY)
# ============================================================
SLOTS = [("A", 8, 15), ("B", 12, 45), ("C", 20, 30)]

def load_json(path, default):
    if not os.path.exists(path):
        return default
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return default

def save_json(path, data):
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

def calculate_runway_days(queue):
    items = queue.get("queue", [])
    if not items:
        return 0
    last_item = items[-1].get("scheduled_ist")
    if not last_item:
        return 0
    try:
        dt = datetime.strptime(last_item, "%Y-%m-%d %H:%M").replace(tzinfo=IST)
        return max(0, (dt - NOW).days)
    except Exception:
        return 0

def append_to_queue(queue, accepted):
    items = queue.setdefault("queue", [])
    last_id = max([int(re.sub(r"\D", "", i["id"]) or 0) for i in items] or [0])

    if items:
        last_sched = datetime.strptime(items[-1]["scheduled_ist"], "%Y-%m-%d %H:%M").replace(tzinfo=IST)
        day = last_sched.date()
        try:
            slot_i = [s[0] for s in SLOTS].index(items[-1].get("slot", "A")) + 1
        except Exception:
            slot_i = 0
    else:
        day = NOW.date()
        slot_i = 0

    added = []
    for i, post in enumerate(accepted, 1):
        if slot_i >= len(SLOTS):
            slot_i = 0
            day += timedelta(days=1)

        slot, hh, mm = SLOTS[slot_i]
        dt = datetime.combine(day, datetime.min.time()).replace(hour=hh, minute=mm, tzinfo=IST)
        new_id = f"ai{last_id + i:04d}"

        items.append({
            "id": new_id,
            "slot": slot,
            "scheduled_ist": dt.strftime("%Y-%m-%d %H:%M"),
            "title": post["text"].split("\n")[0][:80],
            "text": post["text"],
            "used": False,
            "topic_key": post.get("topic_key", ""),
            "generated_at": NOW.strftime("%Y-%m-%d %H:%M:%S IST")
        })
        added.append(new_id)
        slot_i += 1

    queue["total"] = len(items)
    queue["last_scheduled"] = items[-1]["scheduled_ist"] if items else None
    return queue, added

# ============================================================
# TOPIC PICKER
# ============================================================
def pick_topics(used, count):
    candidates = []
    for pillar, labels in TOPIC_POOL.items():
        for label in labels:
            key = f"{pillar}:{topic_key_of(label)}"
            if key not in used:
                candidates.append((key, label))

    random.shuffle(candidates)
    if len(candidates) >= count:
        return candidates[:count]

    # Recycle older topics if pool exhausted
    cutoff = (NOW - timedelta(days=REUSE_AFTER_DAYS)).strftime("%Y-%m-%d")
    reusable = [
        (f"{p}:{topic_key_of(l)}", l)
        for p, labels in TOPIC_POOL.items()
        for l in labels
        if used.get(f"{p}:{topic_key_of(l)}", "") < cutoff
    ]
    random.shuffle(reusable)
    combined = candidates + [t for t in reusable if t not in candidates]
    return combined[:count]

# ============================================================
# MAIN ORCHESTRATION
# ============================================================
def main():
    force_run = "--force" in sys.argv
    dry_run = "--dry-run" in sys.argv
    count = DEFAULT_COUNT

    for arg in sys.argv:
        if arg.startswith("--count="):
            count = int(arg.split("=")[1])

    print("=" * 65)
    print("🏭 CONTENT FACTORY: AUTOMATED EXECUTION")
    print("=" * 65)

    if not get_api_key():
        print("❌ GEMINI_API_KEY environment variable missing. Exiting safely.")
        return

    queue = load_json(QUEUE_FILE, {"queue": []})
    used = load_json(USED_FILE, {})

    runway = calculate_runway_days(queue)
    print(f"📦 Current Buffer: {runway} Days Runway (Minimum target: {MIN_RUNWAY_DAYS} Days)")

    if runway >= MIN_RUNWAY_DAYS and not force_run:
        print(f"✅ Runway is sufficient ({runway} >= {MIN_RUNWAY_DAYS} days). Skipping generation.")
        return

    topics = pick_topics(used, count)
    if not topics:
        print("⚠️ No topics available to generate.")
        return

    print(f"🎯 Selected {len(topics)} topics. Starting batch execution...")
    existing_norm = [normalize_text(i["text"]) for i in queue.get("queue", [])]
    
    accepted = []
    rejected = []

    # Process in chunks of BATCH_SIZE (6 posts at a time)
    for i in range(0, len(topics), BATCH_SIZE):
        chunk = topics[i:i + BATCH_SIZE]
        angles = [random.choice(ANGLES) for _ in chunk]
        
        posts = call_ai([t[1] for t in chunk], angles)
        for p in posts:
            text = p.get("text", "")
            ok, reasons = scan_compliance(text)
            if not ok:
                rejected.append({"reasons": reasons, "text": text[:60]})
                continue

            dup, _ = is_duplicate(text, existing_norm)
            if dup:
                rejected.append({"reasons": ["Duplicate content"], "text": text[:60]})
                continue

            accepted.append(p)
            existing_norm.append(normalize_text(text))

        time.sleep(2)  # Cooldown between API chunks

    print(f"\n📊 Run Summary: {len(accepted)} Accepted | {len(rejected)} Rejected")

    if accepted and not dry_run:
        queue, added = append_to_queue(queue, accepted)
        save_json(QUEUE_FILE, queue)

        for a in accepted:
            k = a.get("topic_key")
            if k:
                used[k] = NOW.strftime("%Y-%m-%d")
        save_json(USED_FILE, used)

        new_runway = calculate_runway_days(queue)
        print(f"✅ Successfully scheduled {len(added)} new posts!")
        print(f"📅 New Queue Runway: {new_runway} Days (Last: {queue.get('last_scheduled')})")
    elif dry_run:
        print("🧪 Dry Run Mode: Nothing was saved to disk.")

if __name__ == "__main__":
    main()
