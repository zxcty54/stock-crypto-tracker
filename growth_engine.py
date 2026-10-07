#!/usr/bin/env python3
"""
GROWTH ENGINE — channel growth loop
===================================
Ek hi kaam: channel ko grow karna. Do tarah se:

  1. VIEWS      → kaunsa post/pillar chala → weights → content factory wahi zyada banata hai
  2. SUBSCRIBERS → roz snapshot → growth rate, target ka kitna door

Isse channel apne aap seekhta hai aur tumhe pata rehta hai ki badh raha hai ya nahi.

USAGE
  python growth_engine.py            # status
  python growth_engine.py perf       # views scrape → performance.json
  python growth_engine.py --status

ENV VARS
  TELEGRAM_BOT_TOKEN / TELEGRAM_TOKEN
  TELEGRAM_CHANNEL / TELEGRAM_CHAT_ID
"""

import os
import re
import sys
import json
import time
import random
import urllib.request
from datetime import datetime, timezone, timedelta

QUEUE_FILE = "content_queue.json"
POSTED_LOG = "post_log.json"
PERF_FILE  = "performance.json"
PERF_REPORT = "performance-report.md"
GROWTH_FILE = "growth_history.json"   # roz ka subscriber/post snapshot

SUBS_TARGET      = 1000   # channel growth ka target
MIN_SAMPLE       = 5      # itne posts se kam ho to weights nahi
MIN_PILLAR_POSTS = 3      # ek pillar ka weight tabhi jab uske 3+ posts hon

# purane infographic cards ko perf me na gino (wo repackaged content hai)
CARD_MARKER = "Poora post"

BOT_TOKEN = (os.environ.get("TELEGRAM_BOT_TOKEN")
             or os.environ.get("TELEGRAM_TOKEN") or "").strip()
CHAT_ID = (os.environ.get("TELEGRAM_CHANNEL")
           or os.environ.get("TELEGRAM_CHAT_ID") or "@bhaga_657").strip()
CHANNEL_USERNAME = CHAT_ID.lstrip("@")

CHANNEL_LINK = os.environ.get("CHANNEL_LINK", "https://t.me/niftytradingstrategies")
CHANNEL_NAME = "Nifty & BankNifty Trading Strategies"

IST = timezone(timedelta(hours=5, minutes=30))
NOW = datetime.now(IST)

DRY_RUN = "--dry-run" in sys.argv
STATUS  = "--status" in sys.argv
MODE = next((a for a in sys.argv[1:] if not a.startswith("--")), None)

UA = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"}


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


def fetch(url, timeout=15):
    try:
        req = urllib.request.Request(url, headers=UA)
        return urllib.request.urlopen(req, timeout=timeout).read().decode("utf-8", "ignore")
    except Exception as e:
        print(f"   ⚠️ fetch fail {url[:60]}: {str(e)[:80]}")
        return ""


def strip_html(t):
    t = re.sub(r"<br\s*/?>", "\n", t or "")
    t = re.sub(r'<a [^>]*href="([^"]+)"[^>]*>(.*?)</a>', r"\2", t, flags=re.S)
    t = re.sub(r"<[^>]+>", "", t)
    t = re.sub(r"\(\?q=[^)]*\)", "", t)          # Telegram hashtag link artifact
    t = re.sub(r"\(t\.me/[^)]*\)", "", t)        # link artifacts
    t = re.sub(r"[ \t]{2,}", " ", t)
    import html as _h
    return _h.unescape(t).strip()


def clean_title(t):
    """Perf report ke liye saaf title (emoji, hashtag, link artifacts hata ke)."""
    t = t or ""
    t = re.sub(r"\(\?q=[^)]*\)", " ", t)         # (?q=%23ORDER_WIN)
    t = re.sub(r"%23\w+", " ", t)                  # encoded hashtags
    t = re.sub(r"#\w+", " ", t)
    t = re.sub(r"\(t\.me/[^)]*\)", " ", t)
    t = re.sub(r"^[^\w]*", "", t)                  # shuru ke emoji
    t = re.sub(r"\s*\|\s*", " — ", t)
    t = re.sub(r"[ \t]{2,}", " ", t)
    return t.strip(" —")[:80]


PILLAR_RULES = [
    ("risk",       ["risk", "sizing", "drawdown", "stop loss", "expectancy", "leverage", "position"]),
    ("psychology", ["psychology", "fomo", "revenge", "fear", "greed", "discipline", "emotion",
                    "tilt", "confidence", "patience", "mindset"]),
    ("technical",  ["chart", "price action", "support", "resistance", "trend", "candle", "volume",
                    "breakout", "structure", "moving average", "rsi", "timeframe"]),
    ("process",    ["journal", "routine", "backtest", "checklist", "process", "plan", "review",
                    "system", "record"]),
    ("corporate",  ["bonus", "split", "dividend", "buyback", "rights", "qip", "result", "order",
                    "capex", "merger", "acquisition", "board", "announcement", "filing"]),
    ("business_model", ["business model", "bank", "nbfc", "fmcg", "it company", "pharma", "auto",
                        "cement", "insurance", "amc", "hotel", "airline", "revenue"]),
    ("market_mechanics", ["fii", "dii", "expiry", "circuit", "liquidity", "open interest", "breadth",
                          "bid", "settlement", "bulk deal", "ipo"]),
    ("awareness",  ["sebi", "scam", "fraud", "fake", "awareness", "guaranteed", "tips group",
                    "registration", "verify"]),
    ("tools",      ["tool", "excel", "calculator", "template", "screener", "sheet", "dashboard"]),
    ("lifestyle",  ["capital", "tax", "sip", "lifestyle", "job", "family", "mentor", "course",
                    "part time", "realistic"]),
]

# hashtag = pakka signal (news posts me sabse bharosemand)
PILLAR_TAGS = {
    "order_win": "corporate", "capex": "corporate", "result": "corporate", "results": "corporate",
    "acquisition": "corporate", "merger": "corporate", "dividend": "corporate", "bonus": "corporate",
    "split": "corporate", "buyback": "corporate", "qip": "corporate", "rights": "corporate",
    "joint_venture": "corporate", "jv": "corporate", "commercial_production": "corporate",
    "board_meeting": "corporate", "expansion": "corporate",
}


def topic_pillar(title, body=""):
    """
    Title + body se pillar nikalo.

    Pehle: word-boundary matching (warna 'infraSTRUCTURE' → technical, 'PLAN' → process — galat).
    Phir:   title ke words ka 3x wazan (title hi asli topic batata hai).
    Aur:    hashtag mile to seedha wahi pillar (news posts ke liye sabse sahi).
    """
    t = (title or "").lower()
    b = (body or "").lower()

    for tag, pillar in PILLAR_TAGS.items():
        pat = r"#\s*" + tag + r"\b"
        if re.search(pat, t) or re.search(pat, b):
            return pillar

    scores = {}
    for pillar, keys in PILLAR_RULES:
        s = 0
        for k in keys:
            pat = r"\b" + k.replace(" ", r"\s+") + r"\b"
            if re.search(pat, t):
                s += 3
            elif re.search(pat, b):
                s += 1
        if s:
            scores[pillar] = s

    if not scores:
        return "other"
    return max(scores.items(), key=lambda x: x[1])[0]


def parse_views(raw):
    """'1.2K' → 1200 | '20' → 20 | '3.4M' → 3400000"""
    if not raw:
        return 0
    s = raw.strip().replace(",", "").upper()
    try:
        if s.endswith("K"):
            return int(float(s[:-1]) * 1000)
        if s.endswith("M"):
            return int(float(s[:-1]) * 1000000)
        return int(float(s))
    except Exception:
        return 0


# ============================================================
# 1️⃣ PERFORMANCE LOOP
# ============================================================

def scrape_channel_views(pages=3):
    """
    t.me/s/<channel> se posts ke views nikalo.
    (Telegram Bot API views nahi deta — isliye public preview page.)
    """
    rows, seen = [], set()
    url = f"https://t.me/s/{CHANNEL_USERNAME}"

    for page in range(pages):
        html = fetch(url)
        if not html:
            break
        blocks = re.split(r'data-post="', html)[1:]
        if not blocks:
            break

        oldest = None
        for b in blocks:
            try:
                pid = int(b.split('"')[0].split("/")[-1])
            except (ValueError, IndexError):
                continue
            if pid in seen:
                continue
            seen.add(pid)

            v = re.search(r'tgme_widget_message_views">([^<]*)', b)
            txt = re.search(r'tgme_widget_message_text[^>]*>(.*?)</div>', b, re.S)
            dt = re.search(r'datetime="([^"]+)"', b)
            reacts = re.findall(r'tgme_widget_message_reaction[^>]*>.*?(\d+)\s*<', b, re.S)

            full = strip_html(txt.group(1)) if txt else ""
            rows.append({
                "post_id": pid,
                "views": parse_views(v.group(1) if v else ""),
                "reactions": sum(int(x) for x in reacts) if reacts else 0,
                "snippet": full[:120],      # perf matching ke liye (halka)
                "text": full[:1500],        # card + live-check ke liye (poora)
                "posted": dt.group(1) if dt else "",
            })
            if oldest is None or pid < oldest:
                oldest = pid

        if not oldest:
            break
        url = f"https://t.me/s/{CHANNEL_USERNAME}?before={oldest}"
        time.sleep(0.6)

    return rows



def _norm(s):
    """Text ko compare karne layak banao (lowercase, hashtag/emoji hata ke)."""
    s = (s or "").lower()
    s = re.sub(r"#\w+", " ", s)
    s = re.sub(r"[^a-z0-9\u0900-\u097f]+", " ", s)
    return re.sub(r"\s+", " ", s).strip()


def _queue_index(queue):
    """content_queue ke posts ka normalized-title index (text match ke liye)."""
    idx = {}
    for item in queue.get("queue", []):
        for raw in (item.get("title", ""), strip_html(item.get("text", ""))):
            k = _norm(raw)[:60]
            if len(k) >= 15:
                idx.setdefault(k, item)
    return idx


def _queue_hit(snippet, idx):
    """Channel post ka text queue ke kisi post se match karta hai?"""
    s = _norm(snippet)
    if len(s) < 15:
        return None
    head = s[:60]
    for key, item in idx.items():
        if key[:40] in s or head[:40] in key:
            return item
    return None



def _eta_text(days):
    """9063 din → '24 saal' — insaani bhasha."""
    if days is None:
        return ""
    if days <= 60:
        return f"~{days} din"
    if days <= 730:
        return f"~{round(days / 30)} mahine"
    return f"~{round(days / 365, 1)} saal"


def scrape_channel_meta():
    """Channel ka subscriber count nikalo (public preview page se)."""
    html = fetch(f"https://t.me/s/{CHANNEL_USERNAME}")
    if not html:
        return {}
    m = re.search(r'tgme_header_counter">\s*([0-9][0-9,\s.]*?)\s*(subscribers|members)', html)
    if not m:
        return {}
    raw = re.sub(r"[,\s]", "", m.group(1))
    try:
        return {"subscribers": int(float(raw)), "kind": m.group(2)}
    except ValueError:
        return {}


def record_growth(n_posts):
    """Aaj ka snapshot growth_history.json me likho + growth nikalo."""
    hist = load_json(GROWTH_FILE, {"history": []})
    rows = [r for r in hist.get("history", []) if isinstance(r, dict)]
    meta = scrape_channel_meta()
    subs = meta.get("subscribers")
    today = NOW.strftime("%Y-%m-%d")

    rows = [r for r in rows if r.get("date") != today]
    rows.append({"date": today, "subs": subs, "posts": n_posts})
    rows.sort(key=lambda r: r.get("date", ""))
    save_json(GROWTH_FILE, {"history": rows[-120:]})       # 120 din ka record

    out = {"today": subs, "snapshots": len(rows), "delta_7d": None,
           "per_day": None, "days_to_target": None, "target": SUBS_TARGET}

    have = [r for r in rows if r.get("subs") is not None]
    if subs is not None and len(have) >= 2:
        first = have[0]
        days = max(1, (NOW.date() - datetime.strptime(first["date"], "%Y-%m-%d").date()).days)

        # 7-din wala delta (ya sabse purana record agar 7 din se kam hai)
        base = None
        for r in have[:-1]:
            d = (NOW.date() - datetime.strptime(r["date"], "%Y-%m-%d").date()).days
            if d >= 7:
                base = r
            else:
                break
        if base is None:
            base = first
        out["delta_7d"]  = subs - base["subs"]
        out["days_span"] = days
        out["per_day"]   = round((subs - first["subs"]) / days, 2)
        if out["per_day"] > 0 and subs < SUBS_TARGET:
            out["days_to_target"] = int((SUBS_TARGET - subs) / out["per_day"])
    return out


def run_perf():
    print("\n📊 PERFORMANCE LOOP")
    print("-" * 60)

    log   = load_json(POSTED_LOG, {})          # optional — sirf dispatcher likhta hai
    queue = load_json(QUEUE_FILE, {"queue": []})
    views = scrape_channel_views(pages=3)
    print(f"   Channel se {len(views)} posts ka data mila")

    # (a) exact match: channel post_id ↔ post_log msg_id
    by_msgid = {}
    for internal_id, entry in log.items():
        mid = entry.get("msg_id")
        if mid:
            by_msgid[int(mid)] = {"internal_id": internal_id, **entry}
    qidx = _queue_index(queue)

    # (b) har post ko score karo — match na ho to pillar text se nikalo
    scored, cards = [], 0
    src_count = {"log": 0, "queue": 0, "inferred": 0}

    for v in views:
        text = v["snippet"]

        if CARD_MARKER in text:                     # infographic card — repackaged
            cards += 1
            continue

        info = by_msgid.get(v["post_id"])
        if info:                                    # 1) pakka match
            title  = clean_title(info.get("title", "")) or f"Post #{v['post_id']}"
            pillar = topic_pillar(info.get("title", ""), text)
            src    = "log"
        else:
            hit = _queue_hit(text, qidx)            # 2) queue text match
            if hit:
                title  = clean_title(hit.get("title", "")) or f"Post #{v['post_id']}"
                pillar = topic_pillar(hit.get("title", ""), text)
                src    = "queue"
            else:                                   # 3) text se pillar infer
                title  = clean_title(text.split("\n")[0]) or f"Post #{v['post_id']}"
                pillar = topic_pillar(text)
                src    = "inferred"

        src_count[src] += 1
        scored.append({**v, "title": title[:70], "pillar": pillar, "source": src})

    identified = src_count["log"] + src_count["queue"]
    print(f"   Score kiye: {len(scored)} posts "
          f"({identified} pehchaane, {len(scored) - identified} pillar text se)")
    if cards:
        print(f"   Infographic cards: {cards} (skip — repackaged content)")

    if len(scored) < MIN_SAMPLE:
        print(f"\n   ⚠️ Data kam hai ({len(scored)} posts). Kam se kam {MIN_SAMPLE} chahiye.")
        save_json(PERF_FILE, {"generated_at": NOW.strftime("%Y-%m-%d %H:%M IST"),
                              "sample_size": len(scored), "status": "collecting_data",
                              "pillars": {}})
        print(f"      Channel public hona chahiye + posts dikhne chahiye.")
        return

    matched = scored   # aage ka code wahi rahega

    growth = record_growth(len(views))
    if growth.get("today") is not None:
        line = f"   Subscribers: {growth['today']}"
        if growth.get("delta_7d") is not None:
            sign = "+" if growth["delta_7d"] >= 0 else ""
            line += f"   (7 din me {sign}{growth['delta_7d']})"
        print(line)

    # pillar-wise
    overall = sum(m["views"] for m in matched) / len(matched)
    by_pillar = {}
    for m in matched:
        p = m["pillar"]
        by_pillar.setdefault(p, []).append(m["views"])

    pillars = {}
    print(f"\n   Channel average views: {overall:.0f}\n")
    print(f"   {'PILLAR':18} {'POSTS':>6} {'AVG VIEWS':>10} {'WEIGHT':>8}")
    print("   " + "-" * 46)
    for p, vals in sorted(by_pillar.items(), key=lambda x: -sum(x[1]) / len(x[1])):
        avg = sum(vals) / len(vals)
        thin = len(vals) < MIN_PILLAR_POSTS
        raw_w = avg / overall if overall else 1.0
        weight = 1.0 if thin else max(0.5, min(2.0, raw_w))
        pillars[p] = {"posts": len(vals), "avg_views": round(avg, 1),
                      "weight": round(weight, 2), "low_sample": thin}
        bar = "█" * int(weight * 8)
        note = "  (sample kam — neutral)" if thin else ""
        print(f"   {p:18} {len(vals):>6} {avg:>10.0f} {weight:>8.2f} {bar}{note}")

    matched.sort(key=lambda x: -x["views"])
    top, bottom = matched[:5], matched[-3:]

    save_json(PERF_FILE, {
        "generated_at": NOW.strftime("%Y-%m-%d %H:%M IST"),
        "sample_size": len(matched),
        "identified": identified,
        "inferred": src_count["inferred"],
        "cards_skipped": cards,
        "channel_avg_views": round(overall, 1),
        "growth": growth,
        "status": "ok",
        "pillars": pillars,
        "top_posts": [{"title": m["title"], "views": m["views"], "pillar": m["pillar"]} for m in top],
        "weak_posts": [{"title": m["title"], "views": m["views"], "pillar": m["pillar"]} for m in bottom],
    })

    md = [f"# 📊 Performance Report\n",
          f"**{NOW.strftime('%d-%b-%Y %H:%M IST')}** | {len(matched)} posts tracked "
          f"| channel avg **{overall:.0f} views**\n",
          f"*{identified} posts pehchaane gaye, {src_count['inferred']} ka pillar "
          f"text se nikala gaya. {cards} repackaged cards skip kiye.*\n",
          "## Pillar performance\n",
          "| Pillar | Posts | Avg views | Weight |", "|---|---|---|---|"]
    for p, d in sorted(pillars.items(), key=lambda x: -x[1]["avg_views"]):
        md.append(f"| {p} | {d['posts']} | {d['avg_views']:.0f} | {d['weight']} |")
    md += ["\n## 📈 Channel Growth\n"]
    if growth.get("today") is not None:
        md.append(f"**Subscribers: {growth['today']}** "
                  f"(target {growth['target']})\n")
        if growth.get("delta_7d") is not None:
            sign = "+" if growth["delta_7d"] >= 0 else ""
            md.append(f"- Pichhle 7 din me: **{sign}{growth['delta_7d']}**")
            md.append(f"- Average: **{growth['per_day']}/din**")
            if growth.get("days_to_target"):
                md.append(f"- Isi raftaar se {growth['target']} subs: **{_eta_text(growth['days_to_target'])}**")
            md.append("")
    else:
        md.append("_Subscriber data nahi mila (channel public hai?)_\n")

    md += ["\n## 🏆 Top posts\n"]
    for m in top:
        md.append(f"- **{m['views']} views** — {m['title']}  \n  `{m['pillar']}`")
    md += ["\n## ⚠️ Kam chale posts\n"]
    for m in bottom:
        md.append(f"- {m['views']} views — {m['title']}  \n  `{m['pillar']}`")
    md += ["\n---\n",
           "**Content factory ab in weights ke hisaab se topics chunega** — "
           "jo pillar chal raha hai uske zyada posts banenge.\n",
           "Ye file har hafte update hoti hai."]
    open(PERF_REPORT, "w", encoding="utf-8").write("\n".join(md))

    print(f"\n   ✅ {PERF_FILE} + {PERF_REPORT} ban gaye")
    print(f"   🏆 Best: {top[0]['title'][:50]} ({top[0]['views']} views)")
    print(f"   ⚠️ Weak: {bottom[0]['title'][:50]} ({bottom[0]['views']} views)")
    print(f"\n   Ab content factory in weights ka use karega (agli generate run se).")




# ============================================================
# STATUS + MAIN
# ============================================================

def show_status():
    print("\n📊 GROWTH ENGINE STATUS")
    print("=" * 60)
    perf  = load_json(PERF_FILE, {})
    queue = load_json(QUEUE_FILE, {"queue": []})
    tot = len(queue.get("queue", []))

    print(f"   Channel          : {CHAT_ID}")
    print(f"   Queue posts      : {tot}")
    print()
    if perf.get("status") == "ok":
        print(f"   Perf loop        : ✅ {perf.get('sample_size', 0)} posts tracked "
              f"(identified {perf.get('identified', 0)}, text-se {perf.get('inferred', 0)})")
    else:
        print(f"   Perf loop        : ⏳ data collect ho raha hai")
    print(f"   Report           : {PERF_REPORT if os.path.exists(PERF_REPORT) else 'abhi nahi bana'}")
    print()
    g = perf.get("growth", {})
    if g.get("today") is not None:
        line = f"   Subscribers      : {g['today']} / {g.get('target', SUBS_TARGET)}"
        if g.get("delta_7d") is not None:
            sign = "+" if g["delta_7d"] >= 0 else ""
            line += f"  (7d: {sign}{g['delta_7d']}, {g.get('per_day')}/din)"
            if g.get("days_to_target"):
                line += f"  → target {_eta_text(g['days_to_target'])}"
        print(line)

    if perf.get("pillars"):
        print("\n   Pillar weights (content factory inhe use karta hai):")
        for p, d in sorted(perf["pillars"].items(), key=lambda x: -x[1]["weight"])[:6]:
            note = "  (sample kam — neutral)" if d.get("low_sample") else ""
            print(f"      {p:18} {d['weight']}x  ({d['avg_views']:.0f} avg views){note}")
    print()
    print(f"   Telegram setup   : {'✅' if BOT_TOKEN else '❌ (TELEGRAM_BOT_TOKEN secret chahiye)'}")
    print("=" * 60)


def main():
    print("=" * 60)
    print("⚙️ GROWTH ENGINE")
    print(f"📅 {NOW.strftime('%d-%b-%Y %H:%M IST')} | mode: {MODE or 'status'}")
    print("=" * 60)

    if STATUS or not MODE or MODE == "status":
        show_status()
        return

    if MODE == "perf":
        run_perf()
    else:
        print(f"❌ Unknown mode: {MODE}")
        print("   Modes: status | perf   (ya --status)")


if __name__ == "__main__":
    main()
