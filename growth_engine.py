#!/usr/bin/env python3
"""
GROWTH ENGINE — 2 tools in one
===============================
1. perf        → kaunsa post kitna chala (views) → content factory ko guide karo (self-improving)
2. infographic → post ki image banao → Telegram pe bhejo (visual = zyada forward)

(Poll/quiz alag: quiz_bank.json — content_generator.py me daalna hai)
(Blogger alag file me hai: blogger_publisher.py — wo LAST step hai)

USAGE
  python growth_engine.py perf
  python growth_engine.py infographic --count 2
  python growth_engine.py --status            # sab ka haal

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
import warnings
import textwrap
import urllib.request
from datetime import datetime, timezone, timedelta

# ============================================================
# CONFIG
# ============================================================

QUEUE_FILE     = "content_queue.json"
POSTED_LOG     = "post_log.json"
PERF_FILE      = "performance.json"
PERF_REPORT    = "performance-report.md"
INFO_STATE     = "infographic_state.json"

MIN_SAMPLE       = 5      # itne posts se kam ho to weights nahi
MIN_PILLAR_POSTS = 3      # ek pillar ka weight tabhi jab uske 3+ posts hon
CARD_MARKER      = "Poora post channel me"   # infographic caption ki pehchaan

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
COUNT = 3
if "--count" in sys.argv:
    try:
        COUNT = int(sys.argv[sys.argv.index("--count") + 1])
    except (IndexError, ValueError):
        pass

UA = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"}


# ============================================================
# HELPERS
# ============================================================

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
    t = re.sub(r"\s{2,}", " ", t)
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
    t = re.sub(r"\s{2,}", " ", t)
    return t.strip(" —")[:80]


def topic_pillar(title):
    """Post title se pillar nikaalo (content factory ke pillars se match)."""
    t = (title or "").lower()
    rules = [
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
    for pillar, keys in rules:
        if any(k in t for k in keys):
            return pillar
    return "other"


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

            rows.append({
                "post_id": pid,
                "views": parse_views(v.group(1) if v else ""),
                "reactions": sum(int(x) for x in reacts) if reacts else 0,
                "snippet": strip_html(txt.group(1))[:120] if txt else "",
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
            pillar = topic_pillar(info.get("title", "") + " " + text)
            src    = "log"
        else:
            hit = _queue_hit(text, qidx)            # 2) queue text match
            if hit:
                title  = clean_title(hit.get("title", "")) or f"Post #{v['post_id']}"
                pillar = topic_pillar(hit.get("title", "") + " " + text)
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
        "status": "ok",
        "pillars": pillars,
        "top_posts": [{"title": m["title"], "views": m["views"], "pillar": m["pillar"]} for m in top],
        "weak_posts": [{"title": m["title"], "views": m["views"], "pillar": m["pillar"]} for m in bottom],
    })

    md = [f"# 📊 Performance Report\n",
          f"**{NOW.strftime('%d-%b-%Y %H:%M IST')}** | {len(matched)} posts tracked "
          f"| channel avg **{overall:.0f} views**\n",
          f"*{identified} posts pehchaane gaye, {src_count['inferred']} ka pillar "
          f"text se nikala gaya. {cards} infographic cards skip kiye.*\n",
          "## Pillar performance\n",
          "| Pillar | Posts | Avg views | Weight |", "|---|---|---|---|"]
    for p, d in sorted(pillars.items(), key=lambda x: -x[1]["avg_views"]):
        md.append(f"| {p} | {d['posts']} | {d['avg_views']:.0f} | {d['weight']} |")
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
# 2️⃣ INFOGRAPHIC
# ============================================================

PILLAR_COLORS = {
    "risk": "#E63946", "psychology": "#6A4C93", "technical": "#118AB2",
    "process": "#0D9488", "corporate": "#F77F00", "business_model": "#2A9D8F",
    "market_mechanics": "#4A4E69", "awareness": "#D62828", "tools": "#3A86FF",
    "lifestyle": "#8D99AE", "other": "#1D3557",
}

RUPEE, CHECK, ARROW = "\u20b9", "\u2713", "\u2192"


def clean_for_image(text):
    """Emoji/tofu hatao (DejaVu font me nahi hote)."""
    out = []
    for ch in text:
        o = ord(ch)
        if ch in (RUPEE, CHECK, ARROW, "•", "—", "–", "’", "“", "”", "⚠"):
            out.append(ch)
        elif o < 0x2500 and o not in (0x200D, 0xFE0F, 0x20E3):
            out.append(ch)
        elif o in (0x20B9, 0x2713):
            out.append(ch)
        else:
            out.append(" ")          # emoji → space
    return re.sub(r" {2,}", " ", "".join(out)).strip()


def _measure(fig, text, size, weight="normal"):
    """Text ki width — figure width ke fraction me (0-1). Exact measurement."""
    import matplotlib.pyplot as plt
    t = fig.text(0.0, -5.0, text, fontsize=size, fontweight=weight)
    try:
        bb = t.get_window_extent(renderer=fig.canvas.get_renderer())
        w = bb.width / fig.bbox.width
    except Exception:
        w = len(text) * size * 0.6 / (fig.bbox.width * 72 / fig.dpi)
    t.remove()
    return w


def _wrap_to_width(fig, text, size, max_w, weight="normal"):
    """Text ko todkar lines banao — measured width ke hisaab se (guess nahi)."""
    words, lines, cur = text.split(), [], ""
    for w in words:
        trial = (cur + " " + w).strip()
        if _measure(fig, trial, size, weight) <= max_w or not cur:
            cur = trial
        else:
            lines.append(cur)
            cur = w
    if cur:
        lines.append(cur)
    return lines


def make_card(title, body_lines, pillar, out_path, footer_lines=None):
    """Ek saaf infographic card banao (1080x1080). Measured layout — kuch nahi katega."""
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    accent = PILLAR_COLORS.get(pillar, PILLAR_COLORS["other"])
    label = pillar.replace("_", " ").upper()

    fig = plt.figure(figsize=(10.8, 10.8), dpi=100)
    fig.patch.set_facecolor("#FFFFFF")
    ax = fig.add_axes([0, 0, 1, 1])
    ax.axis("off")
    ax.set_xlim(0, 1)
    ax.set_ylim(0, 1)
    fig.canvas.draw()

    X, MAX_W = 0.06, 0.88          # left margin + max text width (fraction)

    # ── top accent bar ──
    ax.add_patch(plt.Rectangle((0, 0.875), 1, 0.125, color=accent, zorder=1))
    ax.text(X, 0.9375, label, color="white", fontsize=27, fontweight="bold",
            va="center", ha="left", zorder=2)

    # ── title: size + wrap measured ──
    title_clean = clean_for_image(title)
    t_size, t_lines = 34, [title_clean]
    for size in range(34, 19, -2):
        lines = _wrap_to_width(fig, title_clean, size, MAX_W, "bold")
        if len(lines) <= 4:
            t_size, t_lines = size, lines
            break
    # agar phir bhi bahut lamba → truncate
    if len(t_lines) > 4:
        t_lines = t_lines[:4]
        t_lines[-1] = t_lines[-1][:max(1, len(t_lines[-1]))] 
        if not t_lines[-1].endswith("..."):
            t_lines[-1] = t_lines[-1][:-3].rstrip() + "..."

    y = 0.815
    t_lh = (t_size / 34.0) * 0.058
    for ln in t_lines:
        ax.text(X, y, ln, fontsize=t_size, fontweight="bold", color="#111827",
                va="top", ha="left")
        y -= t_lh

    # accent underline
    y -= 0.006
    ax.add_patch(plt.Rectangle((X, y), 0.14, 0.006, color=accent))
    y -= 0.045

    # ── body: largest size where sab fit ho ──
    BODY_BOTTOM = 0.185
    avail = y - BODY_BOTTOM

    def layout(size, lh_factor=0.00185):
        lh = size * lh_factor
        out = []
        for raw in body_lines:
            txt = clean_for_image(raw)
            if not txt:
                continue
            out += _wrap_to_width(fig, txt, size, MAX_W)
            out.append("")
        return out, lh

    chosen_lines, chosen_size, chosen_lh = None, 13, 0.025
    for size in range(23, 12, -1):
        lines, lh = layout(size)
        content = len([l for l in lines if l])
        need = content * lh + lines.count("") * (lh * 0.5)
        if need <= avail:
            chosen_lines, chosen_size, chosen_lh = lines, size, lh
            break

    if chosen_lines is None:               # bahut zyada text → 13pt + truncate
        chosen_lines, chosen_lh = layout(13)
        cap = max(3, int(avail / chosen_lh))
        if len(chosen_lines) > cap:
            chosen_lines = chosen_lines[:cap]
            if chosen_lines and chosen_lines[-1]:
                chosen_lines[-1] = chosen_lines[-1][:-3].rstrip() + "..."

    ty = y
    for ln in chosen_lines:
        if not ln:
            ty -= chosen_lh * 0.5
            continue
        if ty < BODY_BOTTOM + chosen_lh:
            break
        ax.text(X, ty, ln, fontsize=chosen_size, color="#1F2937", va="top", ha="left")
        ty -= chosen_lh

    # ── footer ──
    ax.add_patch(plt.Rectangle((X, 0.125), 0.88, 0.002, color="#E5E7EB"))
    ax.text(X, 0.082, f"@{CHANNEL_USERNAME}", fontsize=21, fontweight="bold",
            color=accent, va="center")
    ax.text(X, 0.045, "Educational only. Not investment advice. Not SEBI registered.",
            fontsize=14, color="#6B7280", va="center")

    fig.savefig(out_path, facecolor="#FFFFFF")
    plt.close(fig)
    return out_path


def send_photo(path, caption):
    url = f"https://api.telegram.org/bot{BOT_TOKEN}/sendPhoto"
    with open(path, "rb") as f:
        r = __import__("requests").post(
            url,
            data={"chat_id": CHAT_ID, "caption": caption[:1024], "parse_mode": "HTML"},
            files={"photo": f}, timeout=60)
    try:
        d = r.json()
    except Exception:
        d = {}
    return d.get("ok", False), d.get("description", r.text[:120])


def run_infographic():
    print("\n🖼️ INFOGRAPHIC GENERATOR")
    print("-" * 60)

    queue = load_json(QUEUE_FILE, {"queue": []})
    state = load_json(INFO_STATE, {"done": {}})
    state.setdefault("done", {})

    todo = [i for i in queue.get("queue", [])
            if i["id"] not in state["done"] and len(i.get("text", "")) > 200][:COUNT]

    if not todo:
        print("   ℹ️ Sab posts ke infographic ban chuke hain")
        return

    for item in todo:
        pid = item["id"]
        title = item.get("title", "Market Education")
        pillar = topic_pillar(title)

        # body lines: first line heading + baaki
        raw_lines = [l.strip() for l in strip_html(item["text"]).split("\n")]
        raw_lines = [l for l in raw_lines if l and "Not SEBI registered" not in l]
        body = raw_lines[1:] if raw_lines else []
        # hashtags/CTA hatao
        body = [l for l in body if not l.startswith("#") and "homework" not in l.lower()]

        out_path = f"card_{pid}.png"
        make_card(title, body, pillar, out_path)
        size_kb = os.path.getsize(out_path) // 1024
        print(f"\n   🎨 {pid} — {title[:45]}")
        print(f"      card: {out_path} ({size_kb} KB) | pillar: {pillar}")

        caption = (f"<b>{title[:90]}</b>\n\n"
                   f"📖 Poora post channel me — <a href=\"{CHANNEL_LINK}\">{CHANNEL_NAME}</a>\n"
                   f"⚠️ <i>Educational only. Not investment advice. Not SEBI registered.</i>")

        if DRY_RUN:
            print(f"      (dry-run — image nahi bheji)")
            continue

        ok, err = send_photo(out_path, caption)
        if ok:
            state["done"][pid] = {"at": NOW.strftime("%Y-%m-%d %H:%M IST"),
                                  "pillar": pillar, "file": out_path}
            print(f"      ✅ Telegram pe bhej di")
        else:
            print(f"      ❌ fail: {err}")
        time.sleep(3)

    if not DRY_RUN:
        save_json(INFO_STATE, state)
    print(f"\n   Total infographics: {len(state['done'])}")


# ============================================================
# STATUS + MAIN
# ============================================================

def show_status():
    print("\n📊 GROWTH ENGINE STATUS")
    print("=" * 60)
    perf = load_json(PERF_FILE, {})
    info = load_json(INFO_STATE, {"done": {}})
    queue = load_json(QUEUE_FILE, {"queue": []})

    tot = len(queue.get("queue", []))
    print(f"   Channel          : {CHAT_ID}")
    print(f"   Queue posts      : {tot}")
    print()
    print(f"   1️⃣ Perf loop      : {'✅ ' + str(perf.get('sample_size', 0)) + ' posts tracked' if perf.get('status')=='ok' else '⏳ data collect ho raha hai'}")
    print(f"   2️⃣ Infographics   : {len(info.get('done', {}))}/{tot} posts")
    print()
    if perf.get("pillars"):
        print("   Pillar weights (content factory inhe use karta hai):")
        for p, d in sorted(perf["pillars"].items(), key=lambda x: -x[1]["weight"])[:5]:
            print(f"      {p:18} {d['weight']}x  ({d['avg_views']:.0f} avg views)")
    print()
    print(f"   Telegram setup : {'✅' if BOT_TOKEN else '❌ (TELEGRAM_BOT_TOKEN secret chahiye)'}")
    print(f"   Blogger        : alag file — blogger_publisher.py (last step)")
    print("=" * 60)


def main():
    print("=" * 60)
    print("⚙️ GROWTH ENGINE")
    print(f"📅 {NOW.strftime('%d-%b-%Y %H:%M IST')} | mode: {MODE or 'status'}")
    print("=" * 60)

    if STATUS or not MODE:
        show_status()
        return

    if MODE == "perf":
        run_perf()
    elif MODE == "infographic":
        run_infographic()
    else:
        print(f"❌ Unknown mode: {MODE}")
        print("   Modes: perf | infographic | --status")


if __name__ == "__main__":
    main()
