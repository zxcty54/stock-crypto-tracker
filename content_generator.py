#!/usr/bin/env python3
"""
CONTENT FACTORY — Production Grade Engine
=========================================
Automated, SEBI-compliant content generation for Telegram.
Uses HTML formatting for 100% reliable bold text delivery.

🆕 AB PERFORMANCE WEIGHTS BHI PADHTA HAI
   performance.json se pata chalta hai kaunsa pillar chal raha hai
   → us pillar ke ZYADA topics chune jaate hain.
   (growth_engine.py roz 21:00 IST pe ye file banata hai)

USAGE
  python content_generator.py                 # auto (runway kam ho to)
  python content_generator.py --force         # abhi hi banao
  python content_generator.py --count 18      # ya --count=18
  python content_generator.py --dry-run       # save mat karo

ENV VARS
  GEMINI_API_KEY / GOOGLE_API_KEY (+2 variants)   ← primary
  GROQ_API_KEY / GROQ_API_KEY2                    ← fallback (apne endpoint pe jata hai)
  GEMINI_MODEL (optional) / GROQ_MODEL (optional)
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
PERF_FILE    = "performance.json"      # 🆕 growth_engine.py isse banata hai

BATCH_SIZE        = 6         # Safe token limit (6 posts per prompt prevents truncated JSON)
DEFAULT_COUNT     = 18        # Default 18 posts (~6 days buffer @ 3 posts/day)
MIN_RUNWAY_DAYS   = 20        # Skip generation if queue already has >= 20 days runway
SIMILARITY_MAX    = 0.72      # Reject posts if similarity > 72%
REUSE_AFTER_DAYS  = 180       # Cycle old topics only after 6 months

IST = timezone(timedelta(hours=5, minutes=30))
NOW = datetime.now(IST)

ANGLES = [
    "step-by-step practical guide ki tarah likho",
    "common retail mistakes ki checklist banao",
    "ek relatable real trading scene se shuru karo",
    "myth vs reality clear comparison format me likho",
    "beginner friendly simple Hinglish me samjhao",
    "practical numbers aur capital example ke saath explain karo",
    "pehle kya galat hota hai aur uska sahi corrective process kya hai",
]

# ── AI providers ────────────────────────────────────────────
GEMINI_DEFAULT   = "gemini-3.5-flash-lite"
GEMINI_FALLBACKS = ["gemini-3.1-flash-lite", "gemini-flash-lite-latest"]
GROQ_DEFAULT     = "llama-3.3-70b-versatile"

def _env_keys(*names):
    out = []
    for n in names:
        v = (os.environ.get(n) or "").strip()
        if v and v not in out:
            out.append(v)
    return out

GEMINI_KEYS = _env_keys("GEMINI_API_KEY", "GOOGLE_API_KEY", "GEMINI_API_KEY2", "GOOGLE_API_KEY2")
GROQ_KEYS   = _env_keys("GROQ_API_KEY", "GROQ_API_KEY2")

def gemini_models():
    m = (os.environ.get("GEMINI_MODEL") or "").strip() or GEMINI_DEFAULT
    return [m] + [x for x in GEMINI_FALLBACKS if x != m]

GROQ_MODEL = (os.environ.get("GROQ_MODEL") or "").strip() or GROQ_DEFAULT

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
    t = re.sub(r"<[^>]+>", " ", text) # Strip HTML tags for clean diffing
    t = re.sub(r"#\w+", " ", t.lower())
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
# 📊 PERFORMANCE WEIGHTS  (growth_engine.py se aate hain)
# ============================================================
def load_perf_weights():
    """
    performance.json se pillar weights padho — jo pillar chal raha hai uske zyada topics.
    File na ho / khaali ho / kharab ho → {} (normal rotation, crash nahi).
    """
    if not os.path.exists(PERF_FILE):
        return {}
    try:
        d = json.load(open(PERF_FILE, encoding="utf-8"))
    except Exception:
        return {}
    if d.get("status") != "ok" or not d.get("pillars"):
        return {}
    return {p: v.get("weight", 1.0) for p, v in d["pillars"].items()}

def weighted_pick(by_pillar, count, weights):
    """Weights ke hisaab se topics chuno (jo pillar chal raha hai, uske zyada)."""
    if not weights:
        # original round-robin
        names = list(by_pillar.keys())
        random.shuffle(names)
        out = []
        while len(out) < count and any(by_pillar.values()):
            for p in names:
                if len(out) >= count:
                    break
                if by_pillar[p]:
                    out.append(by_pillar[p].pop(0))
        return out

    # weighted rotation: har pillar ko uske weight ke hisaab se "tickets"
    tickets = []
    for p in by_pillar:
        w = weights.get(p, 1.0)
        tickets.extend([p] * max(1, int(round(w * 10))))
    random.shuffle(tickets)

    out = []
    i = 0
    while len(out) < count and any(by_pillar.values()):
        p = tickets[i % len(tickets)] if tickets else None
        i += 1
        if p and by_pillar.get(p):
            out.append(by_pillar[p].pop(0))
        elif any(by_pillar.values()):
            p = max(by_pillar, key=lambda k: len(by_pillar[k]))
            out.append(by_pillar[p].pop(0))
    return out

# ============================================================
# AI GENERATION ENGINE
# ============================================================
PROMPT_TEMPLATE = """You are an institutional trading educator writing educational posts for Indian traders.
Topics to cover:
{topics}

STRICT SEBI & EDITORIAL GUIDELINES:
- No stock or company names (No Reliance, Tata, HDFC, Adani, etc.)
- No entry, stop-loss, target numbers, or trade calls.
- No profit/return claims (No 'guaranteed', 'multibagger', '100%').
- Language: Natural Hinglish (Hindi + English mix).

For EACH topic, provide structured conceptual breakdown fields:
- "topic": EXACT topic text as given in the list above, copied word-for-word
- "topic_key": Short identifier string
- "title": Short catchy headline in Hinglish (e.g. MA KA SAHI USE: Trend Pehchano)
- "hook": Relatable real trading emotion or situation (1-2 sentences)
- "mistake": The exact retail error or trap (1 clear sentence)
- "reality_check": Concrete risk/damage scenario with numbers e.g. ₹1,00,000 capital (1 clear sentence)
- "solution": Practical rule or system to handle this systematically (1 clear sentence)
- "golden_rule": One hard-hitting memorable punchline (1 crisp sentence)

Return ONLY valid JSON matching this schema:
{{"posts": [{{
  "topic": "exact topic text",
  "topic_key": "key",
  "title": "...",
  "hook": "...",
  "mistake": "...",
  "reality_check": "...",
  "solution": "...",
  "golden_rule": "..."
}}]}}"""

def has_api_keys():
    return bool(GEMINI_KEYS or GROQ_KEYS)

def get_api_key():
    return (GEMINI_KEYS or GROQ_KEYS or [""])[0]

def clean_html(text: str) -> str:
    """Removes HTML characters that could break Telegram HTML parser."""
    return text.replace("<", "").replace(">", "").replace("&", "&amp;").strip()

def assemble_telegram_post(p):
    """
    Constructs post using clean, un-breakable HTML bold tags.
    """
    title = clean_html(p.get("title", ""))
    hook = clean_html(p.get("hook", ""))
    mistake = clean_html(p.get("mistake", ""))
    reality = clean_html(p.get("reality_check", ""))
    solution = clean_html(p.get("solution", ""))
    golden_rule = clean_html(p.get("golden_rule", ""))

    return f"""📌 <b>{title}</b>

{hook}

• <b>The Trap:</b> {mistake}
• <b>The Damage:</b> {reality}
• <b>The Fix:</b> {solution}

💡 <b>Golden Rule:</b> {golden_rule}

━━━━━━━━━━━━━━━━━━━━━
#TradingPsychology #RiskManagement
⚠️ Educational only. Not investment advice. Not SEBI registered."""

def _parse_ai_json(raw):
    """AI ke response se posts nikalo (dono format support — 'topic' bhi le lo)."""
    data = json.loads(raw)
    out = []
    for item in data.get("posts", []):
        if "title" in item and "mistake" in item:
            out.append({
                "topic": item.get("topic", ""),
                "topic_key": item.get("topic_key", ""),
                "text": assemble_telegram_post(item),
            })
        elif "text" in item and len(item["text"]) > 100:
            out.append({
                "topic": item.get("topic", ""),
                "topic_key": item.get("topic_key", ""),
                "text": item["text"],
            })
    return out

def _call_gemini(prompt):
    """Gemini — model fallback + retry (429/5xx pe)."""
    import requests
    payload = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {"temperature": 0.7, "responseMimeType": "application/json"},
    }
    for model in gemini_models():
        for key in GEMINI_KEYS:
            for attempt in range(3):
                try:
                    r = requests.post(
                        f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={key}",
                        json=payload, headers={"Content-Type": "application/json"}, timeout=90)
                except Exception as e:
                    print(f"   ⚠️ Gemini network error: {str(e)[:80]}")
                    time.sleep(5)
                    continue

                if r.status_code == 200:
                    return r.json()["candidates"][0]["content"]["parts"][0]["text"].strip()

                if r.status_code == 404:
                    print(f"   ⚠️ Model '{model}' nahi mila — agla model try kar rahe hain")
                    break
                if r.status_code in (429, 500, 503):
                    wait = 5 * (attempt + 1)
                    print(f"   ⏳ Gemini {r.status_code} — {wait}s ruk ke dobara (#{attempt + 1})")
                    time.sleep(wait)
                    continue

                print(f"   ⚠️ Gemini HTTP {r.status_code}: {r.text[:140]}")
                break
            else:
                continue
            continue
    return None

def _call_groq(prompt):
    """Groq (OpenAI-compatible endpoint) — sirf jab Gemini key na ho ya fail ho."""
    import requests
    for key in GROQ_KEYS:
        try:
            r = requests.post(
                "https://api.groq.com/openai/v1/chat/completions",
                headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
                json={"model": GROQ_MODEL,
                      "messages": [{"role": "user", "content": prompt}],
                      "temperature": 0.7,
                      "response_format": {"type": "json_object"}},
                timeout=90)
        except Exception as e:
            print(f"   ⚠️ Groq network error: {str(e)[:80]}")
            continue
        if r.status_code == 200:
            return r.json()["choices"][0]["message"]["content"].strip()
        print(f"   ⚠️ Groq HTTP {r.status_code}: {r.text[:140]}")
    return None

def call_ai(topics, angles):
    """Ek batch banao. Gemini pehle, Groq fallback."""
    if not has_api_keys():
        print("❌ Error: Koi AI API key nahi mili (GEMINI_API_KEY / GROQ_API_KEY).")
        return []

    topic_lines = "\n".join(f"- {t} (Angle: {a})" for t, a in zip(topics, angles))
    prompt = PROMPT_TEMPLATE.format(topics=topic_lines)

    raw = None
    if GEMINI_KEYS:
        raw = _call_gemini(prompt)
    if raw is None and GROQ_KEYS:
        print("   🔁 Gemini nahi chala — Groq try kar rahe hain")
        raw = _call_groq(prompt)
    if not raw:
        return []

    try:
        return _parse_ai_json(raw)
    except Exception as e:
        print(f"   ⚠️ JSON parse fail: {str(e)[:100]}")
        return []

# ============================================================
# QUEUE SCHEDULER
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

        # 🔧 GUARD: bhoot me schedule na ho (warna dispatcher ek saath sab bhej dega)
        while dt <= NOW + timedelta(minutes=5):
            slot_i += 1
            if slot_i >= len(SLOTS):
                slot_i = 0
                day += timedelta(days=1)
            slot, hh, mm = SLOTS[slot_i]
            dt = datetime.combine(day, datetime.min.time()).replace(hour=hh, minute=mm, tzinfo=IST)

        new_id = f"ai{last_id + i:04d}"

        # Clean title for logging
        clean_title = re.sub(r"<[^>]+>", "", post["text"].split("\n")[0]).replace("📌", "").strip()

        items.append({
            "id": new_id,
            "slot": slot,
            "scheduled_ist": dt.strftime("%Y-%m-%d %H:%M"),
            "title": clean_title[:80],
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
# TOPIC PICKER  (weights ke saath)
# ============================================================
def pick_topics(used, count, weights=None):
    """
    Topics chuno. Pehle unused, phir REUSE_AFTER_DAYS se purane.
    weights mile to jo pillar chal raha hai uske ZYADA topics.
    """
    cutoff = (NOW - timedelta(days=REUSE_AFTER_DAYS)).strftime("%Y-%m-%d")
    fresh  = {p: [] for p in TOPIC_POOL}
    reuse  = {p: [] for p in TOPIC_POOL}

    for pillar, labels in TOPIC_POOL.items():
        for label in labels:
            key = f"{pillar}:{topic_key_of(label)}"
            if key not in used:
                fresh[pillar].append((key, label))
            elif used.get(key, "") < cutoff:
                reuse[pillar].append((key, label))

    picked = weighted_pick(fresh, count, weights)

    if len(picked) < count:
        extra = weighted_pick(reuse, count - len(picked), weights)
        seen = {k for k, _ in picked}
        picked += [t for t in extra if t[0] not in seen][: count - len(picked)]

    return picked

# ============================================================
# MAIN ORCHESTRATION
# ============================================================
def main():
    force_run = "--force" in sys.argv
    dry_run = "--dry-run" in sys.argv
    count = DEFAULT_COUNT

    for i, arg in enumerate(sys.argv):
        if arg.startswith("--count="):
            try:
                count = int(arg.split("=", 1)[1])
            except ValueError:
                pass
        elif arg == "--count" and i + 1 < len(sys.argv):
            try:
                count = int(sys.argv[i + 1])
            except ValueError:
                pass

    print("=" * 65)
    print("🏭 CONTENT FACTORY: AUTOMATED EXECUTION")
    print("=" * 65)

    if not has_api_keys():
        print("❌ GEMINI_API_KEY / GROQ_API_KEY dono missing. Exiting safely.")
        return

    if GEMINI_KEYS:
        print(f"🤖 Provider: Gemini ({gemini_models()[0]})")
    else:
        print(f"🤖 Provider: Groq ({GROQ_MODEL})")

    queue = load_json(QUEUE_FILE, {"queue": []})
    used = load_json(USED_FILE, {})

    runway = calculate_runway_days(queue)
    print(f"📦 Current Buffer: {runway} Days Runway (Minimum target: {MIN_RUNWAY_DAYS} Days)")

    if runway >= MIN_RUNWAY_DAYS and not force_run:
        print(f"✅ Runway is sufficient ({runway} >= {MIN_RUNWAY_DAYS} days). Skipping generation.")
        return

    # 📊 performance.json se weights
    weights = load_perf_weights()
    if weights:
        top = sorted(weights.items(), key=lambda x: -x[1])[:3]
        print("📊 Performance weights active: " + ", ".join(f"{p} {w}x" for p, w in top))
    else:
        print("📊 Performance weights: nahi mile (normal rotation)")

    topics = pick_topics(used, count, weights)
    if not topics:
        print("⚠️ No topics available to generate.")
        return

    # topic label → pool key (Marking ke liye)
    label_map = {}
    for key, label in topics:
        label_map.setdefault(normalize_text(label), key)

    print(f"🎯 Selected {len(topics)} topics. Starting batch execution...")
    existing_norm = [normalize_text(i.get("text", "")) for i in queue.get("queue", [])]

    accepted = []
    rejected = []
    accepted_keys = set()

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

            # 🔧 kaunsa pool topic tha → wahi mark hoga "used"
            t_norm = normalize_text(p.get("topic", ""))
            tkey = label_map.get(t_norm)
            if not tkey and t_norm:
                best, best_r = None, 0.0
                for lab, k in label_map.items():
                    rr = difflib.SequenceMatcher(None, t_norm, lab).ratio()
                    if rr > best_r:
                        best, best_r = k, rr
                if best_r >= 0.6:
                    tkey = best
            if tkey:
                accepted_keys.add(tkey)

        time.sleep(2)

    print(f"\n📊 Run Summary: {len(accepted)} Accepted | {len(rejected)} Rejected")
    if rejected:
        for r in rejected[:5]:
            print(f"   ❌ {', '.join(r['reasons'])[:80]}")

    if accepted and not dry_run:
        queue, added = append_to_queue(queue, accepted)
        save_json(QUEUE_FILE, queue)

        for k in accepted_keys:
            used[k] = NOW.strftime("%Y-%m-%d")
        save_json(USED_FILE, used)

        new_runway = calculate_runway_days(queue)
        print(f"✅ Successfully scheduled {len(added)} new posts!")
        print(f"📅 New Queue Runway: {new_runway} Days (Last: {queue.get('last_scheduled')})")
        print(f"🧠 Topics marked used: {len(accepted_keys)}/{len(topics)}"
              + ("" if accepted_keys else "  ⚠️ AI ne 'topic' field nahi diya — agla run baaki topics lega"))
    elif dry_run:
        print("🧪 Dry Run Mode: Nothing was saved to disk.")

if __name__ == "__main__":
    main()
