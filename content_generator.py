#!/usr/bin/env python3
"""
CONTENT FACTORY — AI ka apna content engine
============================================
Ye tumhare channel ka content khud banata hai. Tumhe kisi ke paas jaane ki zarurat nahi.

KAISE KAAM KARTA HAI
  1. Topic pool se UNUSED topics chunta hai (topic memory se)
  2. AI (Groq/Gemini) se posts likhwata hai — un specific topics pe
  3. COMPLIANCE SCANNER se check karta hai (stock name? level? claim? banned word?)
  4. DUPLICATE CHECK (similarity) — purane posts se milta-julta to reject
  5. Pass hue posts ko content_queue.json me schedule karke add karta hai
  6. Kya banaya, kya reject hua — report deta hai

USAGE
  python content_generator.py                 # zarurat ho to generate (auto)
  python content_generator.py --count 30      # 30 posts
  python content_generator.py --dry-run       # sirf dikhao, save na karo
  python content_generator.py --force         # queue bhari ho to bhi generate
  python content_generator.py --report        # topic coverage report

ENV VARS
  GROQ_API_KEY / GROQ_API_KEY2 / GOOGLE_API_KEY / GOOGLE_API_KEY2 / GEMINI_API_KEY
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
# CONFIG
# ============================================================

QUEUE_FILE  = "content_queue.json"
USED_FILE   = "content_topics_used.json"

BATCH_SIZE       = 12        # ek AI call me kitne posts (zyada = zyada token)
MAX_AI_ATTEMPTS  = 3
MIN_RUNWAY_DAYS  = 20        # queue me itne din ka content ho to generation skip
DEFAULT_COUNT    = 24        # ek run me kitne posts generate karne hain
SIMILARITY_MAX   = 0.72      # isse zyada similar = duplicate, reject
REUSE_AFTER_DAYS = 180       # saare topics cover ho gaye to itne purane topics dobara use karo

# Post ke "angles" — ek hi topic different tarike se likha ja sakta hai,
# isliye content kabhi khatam nahi hota
ANGLES = [
    "step-by-step guide ki tarah likho",
    "common mistakes ki list banao",
    "ek relatable story/scene se shuru karo",
    "myth vs reality format me likho",
    "beginner ke liye bilkul simple bhasha me likho",
    "checklist format me likho",
    "numbers/example ke saath explain karo",
    "before vs after scenario dikhao",
    "ek sawaal se shuru karo, phir jawab do",
    "pehle kya galat hota hai, phir sahi tarika",
]

IST = timezone(timedelta(hours=5, minutes=30))
NOW = datetime.now(IST)

DRY_RUN = "--dry-run" in sys.argv
FORCE   = "--force" in sys.argv
REPORT  = "--report" in sys.argv
COUNT   = DEFAULT_COUNT
if "--count" in sys.argv:
    try:
        COUNT = int(sys.argv[sys.argv.index("--count") + 1])
    except (IndexError, ValueError):
        pass


# ============================================================
# 🎯 TOPIC POOL — 10 pillars × many angles
# Yeh tumhara "content syllabus" hai. AI inhi angles pe likhta hai.
# Ek baar khatam hone me saalon lag jaate hain — aur naye add karne hain to bas list badhao.
# ============================================================

TOPIC_POOL = {
    "psychology": [
        "FOMO", "revenge trading", "overtrading", "boredom trades", "loss acceptance",
        "patience kaise build karein", "comparison trap", "tilt kaise rokein",
        "greed ka management", "regret se kaise niklein", "sunk cost fallacy",
        "ego aur trading", "confidence vs over-confidence", "decision fatigue",
        "fear of missing out vs fear of losing", "hope trading ka nuksan",
        "loss ke baad ka reset routine", "profit lene ki jaldi", "impatience ke signs",
        "jeetne ke baad ka overconfidence", "market se emotional detachment",
        "discipline kaise banayein (habit science)", "social media aur trading",
        "loneliness of trading", "kab trading band karni chahiye (din me)",
        "mood aur decision quality", "news ke reaction me trade karna",
        "kya tum trader ho ya gambler (self test)",
    ],
    "risk": [
        "1% rule", "position sizing formula", "drawdown math", "max daily loss limit",
        "risk:reward ka jhoot", "expectancy kaise nikalein", "leverage ka sach",
        "portfolio heat", "correlated positions ka risk", "trailing stop ka use",
        "gap risk aur overnight risk", "risk of ruin", "volatility based sizing",
        "kelly formula ka simple version", "max trades per day rule",
        "weekly loss limit", "drawdown recovery ka math", "risk per idea vs risk per trade",
        "margin ka misuse", "stop loss ka psychological rok",
        "position size aur neend ka connection", "capital allocation kya hai",
        "paper trading se real trading tak risk kaise badhayein",
    ],
    "technical": [
        "support aur resistance ke 3 rule", "trend vs range", "market structure (HH-HL)",
        "volume ka matlab", "candlestick anatomy", "bull flag aur bear flag",
        "moving average ka sahi use", "RSI overbought oversold ka jhoot",
        "divergence kya batati hai", "breakout vs fakeout", "retest ka concept",
        "timeframes kaise combine karein", "gaps ke types", "consolidation ka matlab",
        "double top aur double bottom", "head and shoulders", "trendline kaise khinchein",
        "higher timeframe ka weight", "momentum vs value", "chart pe noise kaise kam karein",
        "candle patterns: pin bar, engulfing, doji", "weekly chart ka importance",
        "52 week high/low ka context", "relative strength (stock vs index)",
    ],
    "process": [
        "trading journal ke columns", "backtesting ka tarika", "trade review ke 4 sawal",
        "pre-trade checklist", "trading plan kaise likhein", "daily routine 30 minute",
        "watchlist template", "pre-market preparation", "post-market review",
        "apne rules likhna", "system kaise banayein", "paper trading ka sahi tarika",
        "forward testing", "edge kya hota hai", "statistics se apna system judge karna",
        "trade log se pattern dhoondhna", "mistake taxonomy (galtiyon ki list)",
        "kab system badalna chahiye kab nahi", "automation ka role",
        "trade ko kaise document karein", "monthly review ka format",
    ],
    "corporate": [
        "bonus issue kaise kaam karta hai", "stock split vs bonus", "buyback ka mechanism",
        "dividend: record date aur ex-date", "rights issue aur dilution", "QIP kya hota hai",
        "board meeting intimation kaise padhein", "order win ke 4 sawaal",
        "promoter pledge kaise dekhein", "merger vs acquisition vs demerger",
        "credit rating scale", "auditor resignation kyun red flag hai",
        "open offer kya hota hai", "delisting ka process", "ESOP ka dilution effect",
        "preferential allotment kya hai", "shareholding pattern kaise padhein",
        "insider trading ke rules", "related party transactions", "annual report ke 5 section",
        "cash flow vs profit", "quarterly result ke 4 number", "segment revenue kaise padhein",
        "contingent liabilities kya hoti hain",
    ],
    "business_model": [
        "bank paisa kaise kamata hai", "NBFC vs bank", "IT company ka model",
        "FMCG company kaise kamati hai", "pharma company ke revenue stream",
        "auto company ka economics", "cement industry ka cycle", "telecom ka ARPU model",
        "insurance company ka float", "AMC ka asset-light model",
        "stock exchange kaise kamata hai", "hotel industry ka RevPAR", "airline ka cost structure",
        "retail chain ka unit economics", "chemical company ka contract vs commodity",
        "steel industry ka cycle", "power company ka PPA", "real estate developer ka cash flow",
        "logistics company ka asset vs asset-light", "SaaS ka ARR aur churn",
        "hospital ka bed economics", "education company ka model",
        "cement vs paint: distribution ka role", "commodity business ka risk",
    ],
    "market_mechanics": [
        "FII DII flow kaise padhein", "market breadth kya batati hai", "bid-ask spread",
        "liquidity ka matlab", "circuit limit kaise lagti hai", "ASM aur GSM list kya hai",
        "operator stock kaise pehchane", "pump and dump ka mechanism",
        "settlement cycle (T+1)", "STT aur charges ka breakdown", "expiry day pe kya hota hai",
        "theta decay simple bhasha me", "open interest kya batata hai", "rollover ka matlab",
        "bulk deal vs block deal", "IPO ka process (ASBA)", "grey market premium kya hai",
        "index rebalancing ka asar", "short selling kaise hoti hai", "margin funding kya hai",
        "wash trading kaise pakdi jaati hai", "circuit to circuit ka matlab",
    ],
    "awareness": [
        "SEBI registration kaise check karein", "guaranteed returns myth",
        "free tips group ke red flags", "fake profit screenshots kaise pehchane",
        "tip provider ki psychology", "pump group me kaise phasate hain",
        "apna advisor verify karne ke 5 step", "charging for advice ke rules",
        "finfluencer rules kya kehte hain", "loss recover karne wale scams",
        "telegram scam channels ki pehchan", "fake trading apps",
        "demo account scam", "copy trading ka risk", "account handling ka khatra",
        "kyun koi apni strategy bechta hai", "performance claims verify kaise karein",
    ],
    "tools": [
        "position size calculator ka use", "journal template kaise bharein",
        "screener recipe banana", "tradingview alert kaise lagayein",
        "chart layout setup", "excel me P&L aur hit rate", "brokerage calculator ka use",
        "tax summary monthly kaise banayein", "watchlist ka format",
        "google sheets se trading journal", "checklist print karke use karna",
        "backtest tracker excel", "portfolio tracker", "trade notes ka format",
    ],
    "lifestyle": [
        "kitna capital chahiye shuru karne ke liye", "emergency fund vs trading capital",
        "SIP vs trading ka honest comparison", "part time trading kaise karein",
        "neend aur trading performance", "screen time ka budget",
        "job ke saath trading", "family ko trading kaise samjhayein",
        "tax filing ka basic (STCG/LTCG)", "kab tak sikhna chahiye shuru karne se pehle",
        "mentor kaise chunein", "course kharidne se pehle ke sawaal",
        "trading se income kya realistic hai", "failure se kaise wapas aayein",
        "5 saal ka realistic plan", "compounding ka patience",
    ],
}


# ============================================================
# 🛡️ COMPLIANCE SCANNER
# ============================================================

BANNED_WORDS = [
    "guaranteed", "guarantee", "sure shot", "sureshot", "jackpot", "multibagger",
    "risk free", "risk-free", "double your money", "assured return", "assured profit",
    "100% accuracy", "no loss", "pakka", "fixed return", "paisa double",
    "तीन गुना", "guaranteed profit",
]

# Common Indian listed companies — inka naam education post me nahi aana chahiye
COMPANY_NAMES = [
    "reliance", "tcs", "tata consultancy", "hdfc bank", "infosys", "icici bank",
    "state bank", "sbi", "bharti airtel", "airtel", "itc", "larsen", "l&t",
    "kotak", "axis bank", "maruti", "asian paints", "bajaj finance", "bajaj finserv",
    "hindustan unilever", "hul", "sun pharma", "titan", "wipro", "tech mahindra",
    "nestle", "ultratech", "power grid", "ntpc", "ongc", "coal india", "adani",
    "tata motors", "tata steel", "hcl tech", "jsw steel", "grasim", "hindalco",
    "dr reddy", "cipla", "eicher", "hero motocorp", "mahindra", "bajaj auto",
    "indusind", "sbi life", "hdfc life", "divi's", "apollo hospitals", "britannia",
    "bpcl", "indian oil", "ioc", "tata consumer", "shriram finance", "zomato",
    "paytm", "nykaa", "dmart", "avenue supermarts", "pidilite", "dabur", "marico",
    "havells", "godrej", "colgate", "vbl", "varun beverages", "trent", "siemens",
    "abb", "bosch", "bel", "hal", "ireda", "irfc", "rvnl", "lic", "gmr",
]

# Advice / call patterns
ADVICE_PATTERNS = [
    r"\b(buy|sell|long|short)\s+(above|below|at)\s+[\d₹]",
    r"\b(target|tgt|sl|stop\s?loss|entry)\s*[:\-=]?\s*₹?\s*\d",
    r"\bkeep\s+an?\s+eye\b", r"\bwatchlist\s+me\b", r"\bdekho\s+isko\b",
    r"\bposition\s+le\s+lo\b", r"\bentry\s+le\s+lo\b", r"\bnikal\s+jao\b",
    r"\bsomething\s+cooking\b", r"\bkuch\s+to\s+hai\b", r"\bhint\s*:",
    r"\bmultibagger\b", r"\b\d+\s*%\s*(return|profit|gain)",
    r"\b(tp|target)\s+hit\b", r"\bbook\s+(kar|profit)\b",
]

DANGER_EMOJI_COMBO = re.compile(r"[🔥🚀💰💥✅]\s*$")


def scan_compliance(text):
    """
    Return (ok: bool, reasons: list[str]).
    Ye scanner AI ke output ko SEBI-safe rakhta hai.
    """
    reasons = []
    low = text.lower()

    # 1) banned words
    for w in BANNED_WORDS:
        if w in low:
            reasons.append(f"banned word: '{w}'")

    # 2) company names
    for c in COMPANY_NAMES:
        if re.search(rf"\b{re.escape(c)}\b", low):
            reasons.append(f"company name: '{c}'")

    # 3) advice / level patterns
    for pat in ADVICE_PATTERNS:
        m = re.search(pat, low)
        if m:
            reasons.append(f"advice pattern: '{m.group(0)[:40]}'")

    # 4) stock ticker style (NSE: XYZ)
    if re.search(r"\b(NSE|BSE)\s*:\s*[A-Z]{2,}", text):
        reasons.append("ticker reference")

    # 5) disclaimer mandatory
    if "Not SEBI registered" not in text and "SEBI registered nahi" not in text:
        reasons.append("disclaimer missing")

    # 6) length
    if len(text) < 120:
        reasons.append("too short (<120 chars)")
    if len(text) > 2200:
        reasons.append("too long (>2200 chars)")

    # 7) hashtags
    if len(re.findall(r"#\w+", text)) < 1:
        reasons.append("no hashtag")

    return (len(reasons) == 0), reasons


# ============================================================
# DEDUPLICATION
# ============================================================

def normalize_for_sim(text):
    t = re.sub(r"#\w+", " ", text.lower())
    t = re.sub(r"⚠️|🤖|educational only|not investment advice|not sebi registered", " ", t)
    t = re.sub(r"[^a-z0-9\s]", " ", t)
    return re.sub(r"\s+", " ", t).strip()


def is_duplicate(text, existing_norm, threshold=SIMILARITY_MAX):
    """Purane posts se similar hai? (0.0-1.0 ratio)"""
    n = normalize_for_sim(text)
    if not n:
        return False, 0.0
    for other in existing_norm:
        ratio = difflib.SequenceMatcher(None, n[:900], other[:900]).ratio()
        if ratio >= threshold:
            return True, ratio
    return False, 0.0


def topic_key_of(label):
    """Topic label ka stable key."""
    return re.sub(r"[^a-z0-9]+", "_", label.lower()).strip("_")[:60]


# ============================================================
# AI CALL
# ============================================================

PROMPT_TEMPLATE = """Tu ek Indian stock market EDUCATION channel ke liye Telegram posts likh raha hai.
Channel: Nifty & BankNifty Trading Strategies (491 subscribers)

Neeche {n} specific topics diye hain. HAR topic pe EK post likh. Diye gaye topics se hatna nahi.

STRICT RULES (ek bhi todna nahi):
- Koi bhi listed company ka naam nahi (Reliance, TCS, HDFC, Adani — kuch bhi nahi)
- Koi stock ya index ka price level, entry, stop-loss, target nahi
- Koi return / accuracy / win-rate claim nahi
- Koi "guaranteed", "sure shot", "multibagger", "risk free" jaise shabd nahi
- Koi live ya recent market data nahi — sirf evergreen concepts
- Koi buy/sell/hold view nahi, koi "ye stock dekho" nahi
- Koi recommendation nahi — sirf education aur process

Har post ka exact format:
1. Pehli line: "TOPIC LABEL: subject" (keyword-first — jaise "RISK MANAGEMENT: 1% rule kaise lagate hain")
2. 6-9 chhoti lines — concept, ek chhota example (numbers allowed jaise capital ₹1,00,000), practical use
3. Ek "Aaj ka homework" ya CTA line
4. 1-2 hashtags (#tradingpsychology #riskkmanagement type)
5. AAKHRI LINE EXACTLY: "⚠️ Educational only. Not investment advice. Not SEBI registered."

120-200 words per post. Simple Hinglish (Hindi + English mix), jaise Indian traders baat karte hain.
No jargon without explanation. Har post apne aap me complete ho.

TOPICS + ANGLE (har topic ka apna angle hai — usi tarike se likho):
{topics}

Return STRICTLY valid JSON, no markdown fences:
{{"posts": [{{"topic_key": "key", "text": "post text"}}]}}"""


def _keys():
    groq = [os.environ.get(k, "").strip() for k in ("GROQ_API_KEY", "GROQ_API_KEY2")]
    goog = [os.environ.get(k, "").strip() for k in ("GOOGLE_API_KEY", "GOOGLE_API_KEY2", "GEMINI_API_KEY")]
    return ([k for k in dict.fromkeys(groq) if k], [k for k in dict.fromkeys(goog) if k])


def _parse_posts(raw):
    if not raw:
        return []
    raw = re.sub(r"^```(?:json)?\s*", "", raw.strip())
    raw = re.sub(r"\s*```$", "", raw)
    try:
        data = json.loads(raw)
        posts = data.get("posts", data if isinstance(data, list) else [])
    except Exception:
        m = re.search(r"\[[\s\S]*\]", raw)
        if not m:
            return []
        try:
            posts = json.loads(m.group(0))
        except Exception:
            return []

    out = []
    for p in posts:
        if isinstance(p, str):
            out.append({"topic_key": "", "text": p.strip()})
        elif isinstance(p, dict):
            txt = (p.get("text") or "").strip()
            if txt:
                out.append({"topic_key": (p.get("topic_key") or "").strip(), "text": txt})
    return out


def call_ai(topics, angles):
    groq_keys, goog_keys = _keys()
    if not groq_keys and not goog_keys:
        print("   ⚠️ Koi AI key nahi mili — generation skip")
        return []

    topic_lines = "\n".join(f"- {t}  →  ANGLE: {a}" for t, a in zip(topics, angles))
    prompt = PROMPT_TEMPLATE.format(n=len(topics), topics=topic_lines)
    raw = None

    for attempt in range(MAX_AI_ATTEMPTS):
        if groq_keys:
            try:
                from groq import Groq
                c = Groq(api_key=random.choice(groq_keys))
                r = c.chat.completions.create(
                    model="openai/gpt-oss-120b",
                    messages=[{"role": "user", "content": prompt}],
                    temperature=0.75,
                    response_format={"type": "json_object"},
                )
                raw = r.choices[0].message.content
                if raw:
                    break
            except Exception as e:
                print(f"   ⚠️ Groq attempt {attempt+1} failed: {str(e)[:110]}")
                time.sleep(3)

        if goog_keys and not raw:
            try:
                from google import genai
                from google.genai import types
                c = genai.Client(api_key=random.choice(goog_keys))
                r = c.models.generate_content(
                    model="gemini-3.5-flash-lite",
                    contents=prompt,
                    config=types.GenerateContentConfig(temperature=0.75,
                                                       response_mime_type="application/json"),
                )
                raw = r.text
                if raw:
                    break
            except Exception as e:
                print(f"   ⚠️ Gemini attempt {attempt+1} failed: {str(e)[:110]}")
                time.sleep(3)

    return _parse_posts(raw)


# ============================================================
# QUEUE MANAGEMENT
# ============================================================

SLOTS = [("A", 8, 15), ("B", 12, 45), ("C", 20, 30)]


def load_json(path, default):
    if not os.path.exists(path):
        return default
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return default


def save_json(path, data):
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)


def queue_runway_days(queue):
    """Queue me kitne din ka content bacha hai."""
    items = queue.get("queue", [])
    if not items:
        return 0
    last = items[-1].get("scheduled_ist")
    if not last:
        return 0
    try:
        dt = datetime.strptime(last, "%Y-%m-%d %H:%M").replace(tzinfo=IST)
        return max(0, (dt - NOW).days)
    except Exception:
        return 0


def append_to_queue(queue, accepted):
    """Accepted posts ko queue ke end me schedule karke add karo (slot rotation continue)."""
    items = queue.setdefault("queue", [])
    used_ids = {i["id"] for i in items}
    last_id = max([int(re.sub(r"\D", "", i["id"]) or 0) for i in items] or [0])

    # kis slot/day se continue karna hai
    if items:
        last_sched = datetime.strptime(items[-1]["scheduled_ist"], "%Y-%m-%d %H:%M").replace(tzinfo=IST)
        day = last_sched.date()
        try:
            slot_i = [s[0] for s in SLOTS].index(items[-1]["slot"]) + 1
        except (KeyError, ValueError):
            slot_i = 0
    else:
        day = NOW.date()
        slot_i = 0

    added = []
    for i, post in enumerate(accepted, 1):
        if slot_i >= len(SLOTS):
            slot_i = 0
            day = day + timedelta(days=1)

        slot, hh, mm = SLOTS[slot_i]
        dt = datetime.combine(day, datetime.min.time()).replace(hour=hh, minute=mm, tzinfo=IST)

        new_id = f"ai{last_id + i:04d}"
        while new_id in used_ids:
            last_id += 1
            new_id = f"ai{last_id + i:04d}"

        items.append({
            "id": new_id,
            "slot": slot,
            "scheduled_ist": dt.strftime("%Y-%m-%d %H:%M"),
            "scheduled_utc": (dt - timedelta(hours=5, minutes=30)).strftime("%Y-%m-%d %H:%M"),
            "title": post["text"].split("\n")[0][:80],
            "text": post["text"],
            "used": False,
            "ai_generated": True,
            "topic_key": post.get("topic_key", ""),
            "generated_at": NOW.strftime("%Y-%m-%d %H:%M:%S IST"),
        })
        added.append(new_id)
        slot_i += 1

    queue["total"] = len(items)
    queue["last_scheduled"] = items[-1]["scheduled_ist"] if items else None
    queue["generated_at"] = NOW.strftime("%Y-%m-%d %H:%M:%S IST")
    return queue, added


# ============================================================
# TOPIC SELECTION
# ============================================================

def pick_topics(used, count):
    """
    Unused topics chuno, pillars rotate karke (balanced coverage).
    Saare topics cover ho gaye to REUSE_AFTER_DAYS se purane topics dobara chuno.
    """
    def collect(allow_reuse):
        by_pillar, chosen = {p: [] for p in TOPIC_POOL}, []
        cutoff = (NOW - timedelta(days=REUSE_AFTER_DAYS)).strftime("%Y-%m-%d")
        for pillar, labels in TOPIC_POOL.items():
            for label in labels:
                key = f"{pillar}:{topic_key_of(label)}"
                used_on = used.get(key)
                if used_on is None:
                    by_pillar[pillar].append((key, label))
                elif allow_reuse and used_on < cutoff:
                    by_pillar[pillar].append((key, label))
        pillar_names = list(TOPIC_POOL.keys())
        random.shuffle(pillar_names)
        while len(chosen) < count and any(by_pillar.values()):
            for p in pillar_names:
                if len(chosen) >= count:
                    break
                if by_pillar[p]:
                    chosen.append(by_pillar[p].pop(0))
        return chosen

    picked = collect(allow_reuse=False)
    if len(picked) < count:
        # naye topics khatam — purane topics dobara (fresh angle ke saath)
        extra = collect(allow_reuse=True)
        seen = {k for k, _ in picked}
        picked += [t for t in extra if t[0] not in seen][: count - len(picked)]
        if picked:
            print(f"   ♻️ Naye topics khatam — purane topics fresh angle ke saath reuse ho rahe hain")
    return picked


# ============================================================
# MAIN
# ============================================================

def main():
    print("=" * 78)
    print("🏭 CONTENT FACTORY — AI channel content engine")
    print(f"📅 {NOW.strftime('%d-%b-%Y %H:%M:%S IST')}")
    print("=" * 78)

    groq_keys, goog_keys = _keys()
    if not groq_keys and not goog_keys:
        print("\n❌ Koi AI key nahi mili (GROQ_API_KEY ya GOOGLE_API_KEY). Generation band.")
        print("   GitHub Secrets me key daalo, ya .env me set karo.")
        return

    queue = load_json(QUEUE_FILE, {"queue": []})
    used  = load_json(USED_FILE, {})

    total_topics = sum(len(v) for v in TOPIC_POOL.values())
    used_count = len(used)

    if REPORT:
        print(f"\n📊 TOPIC COVERAGE: {used_count}/{total_topics} used "
              f"({used_count / total_topics * 100:.1f}%)")
        for pillar, labels in TOPIC_POOL.items():
            u = sum(1 for l in labels if f"{pillar}:{topic_key_of(l)}" in used)
            bar = "█" * int(u / max(len(labels), 1) * 20)
            print(f"   {pillar:16} {u:3}/{len(labels):<3} {bar}")
        print(f"\n   Queue: {len(queue.get('queue', []))} posts | "
              f"runway: {queue_runway_days(queue)} din")
        return

    runway = queue_runway_days(queue)
    remaining = len([i for i in queue.get("queue", []) if not i.get("used")])
    print(f"\n📦 Queue: {remaining} posts | runway {runway} din | topics used {used_count}/{total_topics}")

    if runway >= MIN_RUNWAY_DAYS and not FORCE:
        print(f"✅ Runway {runway} din hai (>= {MIN_RUNWAY_DAYS}) — generation ki zarurat nahi.")
        print("   (Force karna ho: --force)")
        return

    need = COUNT
    picked = pick_topics(used, need)
    if not picked:
        print("🎉 Saare topics cover ho gaye! Naye topics TOPIC_POOL me add karo.")
        return

    print(f"\n🎯 {len(picked)} naye topics: " + ", ".join(l for _, l in picked[:5]) + "...")

    existing_norm = [normalize_for_sim(i["text"]) for i in queue.get("queue", [])]

    accepted, rejected = [], []
    attempts = 0

    while picked and attempts < MAX_AI_ATTEMPTS + 1:
        attempts += 1
        batch = picked[:BATCH_SIZE]
        angles = [random.choice(ANGLES) for _ in batch]
        print(f"\n⚡ AI batch {attempts} ({len(batch)} topics)...")

        results = call_ai([l for _, l in batch], angles)
        if not results:
            print("   ⚠️ AI se koi post nahi mili")
            continue

        used_keys = {k for k, _ in batch}
        for r in results:
            text = r["text"]
            key = r.get("topic_key") or ""

            # compliance
            ok, reasons = scan_compliance(text)
            if not ok:
                rejected.append({"text": text[:120], "reasons": reasons, "topic": key})
                print(f"   🚫 reject: {reasons[0]}")
                continue

            # duplicate check
            dup, ratio = is_duplicate(text, existing_norm)
            if dup:
                rejected.append({"text": text[:120], "reasons": [f"duplicate ({ratio:.2f})"], "topic": key})
                print(f"   🔁 duplicate ({ratio:.2f})")
                continue

            accepted.append({"text": text, "topic_key": key})
            existing_norm.append(normalize_for_sim(text))
            print(f"   ✅ accept ({len(text)} chars)")

        picked = picked[BATCH_SIZE:]
        # jo topics cover nahi hue, dobara try karo
        if not picked and len(accepted) < need and attempts < MAX_AI_ATTEMPTS + 1:
            more = pick_topics(used, need - len(accepted))
            picked = [t for t in more if t not in batch]
            if not picked:
                break
        time.sleep(2)

    print(f"\n{'=' * 78}")
    print(f"📊 RESULT: {len(accepted)} accepted | {len(rejected)} rejected")

    if accepted:
        if DRY_RUN:
            print("\n🧪 DRY RUN — queue me save nahi kiya. Sample:")
            print("-" * 60)
            print(accepted[0]["text"][:600])
            print("-" * 60)
        else:
            queue, added = append_to_queue(queue, accepted)
            save_json(QUEUE_FILE, queue)

            for a in accepted:
                k = a.get("topic_key")
                if k:
                    used[k] = NOW.strftime("%Y-%m-%d")
            save_json(USED_FILE, used)

            print(f"✅ {len(added)} posts queue me add hue")
            print(f"📅 Naya runway: {queue_runway_days(queue)} din "
                  f"(aakhri: {queue['last_scheduled']} IST)")
            print(f"🧠 Topics used: {len(used)}/{total_topics}")

    if rejected:
        print("\n🚫 Rejected samples (quality control):")
        for r in rejected[:5]:
            print(f"   • {r['reasons'][0]} → {r['text'][:70]}...")


if __name__ == "__main__":
    main()
