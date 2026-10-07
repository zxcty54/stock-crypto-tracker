#!/usr/bin/env python3
"""
CHANNEL DISPATCHER (GitHub Actions Native)
===========================================
Tumhare script ka fixed version. Structure wahi — bugs fix.

KYA FIX HUA (test se confirm kiye gaye):
  🔴 1. HAR RUN pe naya Telegraph account ban raha tha (Account #1, #2, #3...)
        → ab token ek baar banta hai, telegraph_state.json me save rehta hai
  🔴 2. HTML entities saaf nahi ho rahe the (M&amp;M → page pe "M&amp;M" dikhta)
        → ab html.unescape
  🔴 3. Duplicate post ka koi guard nahi tha — workflow dobara chalao to same post
        → ab posted log + "used" flag dono, aur 2 ghante ka duplicate guard
  🟠 4. Channel hardcoded @bhaga_657 tha (3 jagah) → ab env var
  🟠 5. Telegram 429 (rate limit) pe kuch handling nahi → ab wait + retry
  🟠 6. Title me sirf 60 chars, SEO nahi → ab month + year (search me fresh dikhta)
  🟠 7. Telegraph link disclaimer ke baad aa raha tha → ab pehle (disclaimer last)
  🟡 8. Telegraph fail ho to bhi return "" — theek hai (post jaata rahega)

PURANE FILES ki jagah ye ek file:
  telegram_auto_poster.py    → delete
  telegram_dispatcher_v2.py  → delete
  telegram_publisher.py      → delete (ye file already web publish karta hai)
  Google Apps Script wala bhi zarurat nahi

USAGE
  python channel_dispatcher.py              # normal (GitHub Actions cron)
  python channel_dispatcher.py --dry-run    # sirf dikhao
  python channel_dispatcher.py --status     # queue status
  python channel_dispatcher.py --test       # ek post abhi bhejo (test)
"""

import os
import re
import sys
import json
import time
import html as html_lib
from datetime import datetime, timezone, timedelta

import requests

# ============================================================
# CONFIG
# ============================================================

QUEUE_FILE = "content_queue.json"
FEED_FILE  = "nse_content_feed.json"
STATE_FILE = "telegraph_state.json"      # telegraph token + published pages
POSTED_LOG = "post_log.json"             # kaunsa post kab gaya (audit + dedup)

BOT_TOKEN = (os.environ.get("TELEGRAM_BOT_TOKEN")
             or os.environ.get("TELEGRAM_TOKEN") or "").strip()

RAW_TARGET = (os.environ.get("TELEGRAM_CHANNEL")
              or os.environ.get("TELEGRAM_CHAT_ID") or "").strip()
CHAT_ID = RAW_TARGET if RAW_TARGET else "@bhaga_657"

# Brand — env var se, hardcode nahi
CHANNEL_LINK = os.environ.get("CHANNEL_LINK", "https://t.me/niftytradingstrategies")
AUTHOR_NAME  = os.environ.get("TELEGRAPH_AUTHOR", "Nifty & BankNifty Trading Strategies")
SHORT_NAME   = os.environ.get("TELEGRAPH_SHORT", "StockPulse")

# Corporate slot — kis ghante me corporate news prefer kare
CORPORATE_HOURS = [int(h) for h in os.environ.get("CORPORATE_HOURS", "12,13,14").split(",") if h.strip()]
DUPLICATE_WINDOW_HOURS = 2      # itne ghante me same post dobara nahi

IST = timezone(timedelta(hours=5, minutes=30))
NOW = datetime.now(IST)

DRY_RUN = "--dry-run" in sys.argv
STATUS  = "--status" in sys.argv
TEST    = "--test" in sys.argv

DISCLAIMER = "\n\n⚠️ <i>Educational only. Not investment advice. Not SEBI registered.</i>"
AI_NOTICE  = "\n🤖 <i>AI-assisted summary of public corporate filing.</i>"

MONTHS = ["January","February","March","April","May","June",
          "July","August","September","October","November","December"]


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
        json.dump(data, f, ensure_ascii=False, indent=2)


# ============================================================
# 🌐 TELEGRAPH PUBLISHER
# ============================================================

def get_telegraph_token(state):
    """
    FIX #1: token EK BAAR banao, state me save karo.
    (Pehle har run pe naya account banta tha — Account #1, #2, #3...)
    """
    if state.get("access_token"):
        return state["access_token"]

    try:
        r = requests.post("https://api.telegra.ph/createAccount",
                          data={"short_name": SHORT_NAME,
                                "author_name": AUTHOR_NAME,
                                "author_url": CHANNEL_LINK},
                          timeout=15).json()
        token = r.get("result", {}).get("access_token")
        if token:
            state["access_token"] = token
            state["account_created"] = NOW.strftime("%Y-%m-%d %H:%M:%S IST")
            print(f"   🔑 Telegraph account bana (ek baar ka kaam)")
            return token
        print(f"   ⚠️ Telegraph account fail: {r.get('error')}")
    except Exception as e:
        print(f"   ⚠️ Telegraph account exception: {e}")
    return None


def publish_to_telegraph(token, title, text):
    """(url, error). Token caller se aata hai (har run pe naya nahi banega)."""
    if not token:
        return "", "telegraph token nahi mila"

    # FIX #2: HTML entities saaf karo (M&amp;M → M&M)
    clean_lines = []
    for line in text.split("\n"):
        t = line.strip()
        if not t:
            continue
        t = re.sub(r"<[^>]+>", "", t)          # tags hatao
        t = html_lib.unescape(t)                # &amp; &gt; &quot; → asli chars
        t = t.strip()
        if not t:
            continue
        # disclaimer aur AI notice page pe alag se lagayenge
        if re.search(r"Not SEBI registered", t, re.I):
            continue
        if t.startswith("🤖"):
            continue
        if re.match(r"^#\w+", t):
            continue
        clean_lines.append(t)

    if not clean_lines:
        return "", "content khaali hai"

    nodes = []
    for line in clean_lines:
        if re.match(r"^(\d+[\.\)]|[-•*])\s", line):
            item = re.sub(r"^(\d+[\.\)]|[-•*])\s*", "", line)
            nodes.append({"tag": "ul", "children": [{"tag": "li", "children": [item]}]})
        else:
            nodes.append({"tag": "p", "children": [line]})

    # CTA
    nodes.append({"tag": "hr"})
    nodes.append({"tag": "p", "children": [
        "📢 Telegram pe join karo: ",
        {"tag": "a", "attrs": {"href": CHANNEL_LINK},
         "children": [AUTHOR_NAME]}]})
    nodes.append({"tag": "p", "children": [
        {"tag": "em", "children": [
            "⚠️ Educational only. Not investment advice. Not SEBI registered."]}]})

    # FIX #6: SEO title — month + year
    base = re.sub(r"\*\*|[*_`#]", "", str(title or "Market Update")).strip()
    base = re.sub(r"^[^\w]*", "", base)
    seo_title = f"{base[:120]} — {MONTHS[NOW.month-1]} {NOW.year}"

    if DRY_RUN:
        return f"(dry-run) {seo_title[:50]}", None

    try:
        r = requests.post("https://api.telegra.ph/createPage",
                          json={"access_token": token,
                                "title": seo_title[:256],
                                "author_name": AUTHOR_NAME,
                                "author_url": CHANNEL_LINK,
                                "content": nodes,
                                "return_content": False},
                          timeout=20).json()
        if r.get("ok"):
            return r["result"]["url"], None
        return "", str(r.get("error"))
    except Exception as e:
        print(f"   ⚠️ Telegraph exception: {e}")
        return "", str(e)


# ============================================================
# 📨 TELEGRAM BROADCASTER
# ============================================================

def send_telegram_message(text):
    """(ok, msg_id, error). HTML fail → plain text. 429 → wait + retry (FIX #5)."""
    if DRY_RUN:
        print("   (dry-run — post nahi bheja)")
        return True, 0, None

    url = f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage"
    payload = {"chat_id": CHAT_ID, "text": text[:4096],
               "parse_mode": "HTML", "disable_web_page_preview": False}

    for attempt in range(3):
        try:
            res = requests.post(url, json=payload, timeout=20)
            data = {}
            try:
                data = res.json()
            except Exception:
                pass

            if data.get("ok"):
                return True, data["result"]["message_id"], None

            desc = data.get("description", "")

            # FIX #5: rate limit
            if res.status_code == 429:
                wait = int(data.get("parameters", {}).get("retry_after", 30))
                print(f"   ⏳ Rate limit — {wait}s wait")
                time.sleep(wait + 2)
                continue

            # HTML parse error → plain text
            print(f"   ⚠️ HTML fail ({desc[:60]}) — plain text try")
            plain = html_lib.unescape(re.sub(r"<[^>]+>", "", text))
            p2 = {"chat_id": CHAT_ID, "text": plain[:4096],
                  "disable_web_page_preview": False}
            r2 = requests.post(url, json=p2, timeout=15).json()
            if r2.get("ok"):
                return True, r2["result"]["message_id"], None
            return False, None, r2.get("description", "plain text bhi fail")

        except Exception as e:
            print(f"   ⚠️ exception (attempt {attempt+1}): {str(e)[:100]}")
            time.sleep(4)

    return False, None, "3 attempts fail"


# ============================================================
# 🎯 CONTENT SELECTION
# ============================================================

def is_duplicate(post_id, log):
    """FIX #3: same post pichhle 2 ghante me gaya tha?"""
    entry = log.get(post_id)
    if not entry:
        return False
    try:
        when = datetime.strptime(entry["at"].replace(" IST", ""),
                                 "%Y-%m-%d %H:%M:%S").replace(tzinfo=IST)
        return (NOW - when) < timedelta(hours=DUPLICATE_WINDOW_HOURS)
    except Exception:
        return True          # parse fail = safe side, duplicate maano


def pick_corporate_post(feed_data, log):
    items = (feed_data or {}).get("content_feed", [])
    # ulta — purani filing pehle (Telegram me chronological order)
    for idx in range(len(items) - 1, -1, -1):
        item = items[idx]
        if item.get("used") or not item.get("telegram_post"):
            continue
        pid = item.get("hash", f"corp_{idx}")
        if is_duplicate(pid, log):
            print(f"   ⏭️ {item.get('symbol')} skip — duplicate window me")
            continue
        return item, idx
    return None, -1


def pick_evergreen_post(queue_data, log):
    items = (queue_data or {}).get("queue", [])
    now_str = NOW.strftime("%Y-%m-%d %H:%M")

    # 1. scheduled time nikal gaya wala
    for idx, item in enumerate(items):
        if item.get("used"):
            continue
        if item.get("scheduled_ist", "9999") <= now_str:
            if is_duplicate(item.get("id", ""), log):
                continue
            return item, idx

    # 2. agla koi bhi unused (scheduled time abhi aaya nahi)
    for idx, item in enumerate(items):
        if item.get("used"):
            continue
        if is_duplicate(item.get("id", ""), log):
            continue
        return item, idx

    return None, -1


def show_status(queue, feed, state, log):
    q = (queue or {}).get("queue", [])
    f = (feed or {}).get("content_feed", [])
    print("\n📊 CHANNEL DISPATCHER STATUS")
    print(f"   Channel          : {CHAT_ID}")
    print(f"   Evergreen queue  : {len([i for i in q if not i.get('used')])}/{len(q)} bache")
    print(f"   Corporate feed   : {len([c for c in f if not c.get('used')])}/{len(f)} bache")
    print(f"   Telegraph token  : {'✅ hai' if state.get('access_token') else '❌ nahi'}")
    print(f"   Pages published  : {len(state.get('published', {}))}")
    print(f"   Posts (log)      : {len(log)}")
    print(f"   Aaj ka slot      : {'CORPORATE' if NOW.hour in CORPORATE_HOURS else 'EVERGREEN'}")
    nxt = pick_evergreen_post(queue, log)
    if nxt[0]:
        print(f"   Agla post        : {nxt[0].get('scheduled_ist')} — {nxt[0].get('title','')[:45]}")


# ============================================================
# 🚀 MAIN
# ============================================================

def main():
    print("=" * 76)
    print("🚀 CHANNEL DISPATCHER — Telegram + Telegraph")
    print(f"📅 {NOW.strftime('%Y-%m-%d %H:%M:%S IST')} | channel: {CHAT_ID}")
    print("=" * 76)

    if not BOT_TOKEN and not DRY_RUN:
        print("❌ TELEGRAM_BOT_TOKEN missing.")
        sys.exit(1)

    queue = load_json(QUEUE_FILE, {"queue": []})
    feed  = load_json(FEED_FILE, {"content_feed": []})
    state = load_json(STATE_FILE, {})
    state.setdefault("published", {})
    log   = load_json(POSTED_LOG, {})

    if STATUS:
        show_status(queue, feed, state, log)
        return

    is_corporate_slot = NOW.hour in CORPORATE_HOURS
    print(f"⏰ Slot: {'CORPORATE preferred' if is_corporate_slot else 'EVERGREEN'}")

    chosen, source, idx = None, None, -1

    if is_corporate_slot:
        chosen, idx = pick_corporate_post(feed, log)
        if chosen:
            source = "corporate"
            print(f"📰 Corporate filing: {chosen.get('symbol')}")

    if not chosen:
        chosen, idx = pick_evergreen_post(queue, log)
        if chosen:
            source = "evergreen"
            print(f"📚 Evergreen: {chosen.get('title','')[:50]}")

    if not chosen:
        print("ℹ️ Kuch pending nahi — sab post ho gaya")
        return

    # ── text tayyar karo ──
    if source == "corporate":
        raw = chosen.get("telegram_post", "")
        title = chosen.get("headline") or chosen.get("symbol") or "Corporate Update"
        pid = chosen.get("hash", f"corp_{idx}")
        if "AI-assisted" not in raw:
            raw += AI_NOTICE
    else:
        raw = chosen.get("text", "")
        title = chosen.get("title", "Market Insights")
        pid = chosen.get("id", f"ev_{idx}")

    if "Not SEBI registered" not in raw:
        raw += DISCLAIMER

    # ── 1. Telegraph ──
    print(f"\n🌐 Telegraph publish [{pid}]...")
    existing = (state.get("published", {}) or {}).get(pid)
    if existing and existing.get("url"):
        # pehle se publish ho chuka (kisi doosre tool ne ya pichhle run me)
        t_url, t_err = existing["url"], None
        print(f"   ♻️ Page pehle se hai — wahi use kar rahe hain (duplicate page nahi banega)")
    else:
        token = get_telegraph_token(state)
        t_url, t_err = publish_to_telegraph(token, title, raw)
    if t_url:
        print(f"   ✅ {t_url}")
    else:
        print(f"   ⚠️ Web publish fail: {t_err}  (Telegram post phir bhi jaayega)")

    # ── 2. Telegram ──
    # FIX #7: web link disclaimer ke PEHLE (disclaimer hamesha last rahe)
    if t_url and not DRY_RUN:
        if DISCLAIMER.strip() in raw:
            raw = raw.replace(DISCLAIMER, f"\n\n⚡ <b>Read on Web:</b> {t_url}{DISCLAIMER}")
        else:
            raw += f"\n\n⚡ <b>Read on Web:</b> {t_url}"
    elif t_url and DRY_RUN:
        raw += f"\n\n⚡ <b>Read on Web:</b> {t_url}"

    print(f"\n🚀 Dispatching to {CHAT_ID}...")
    ok, msg_id, err = send_telegram_message(raw)

    if not ok:
        print(f"❌ Broadcast fail: {err}")
        sys.exit(1)          # Actions RED — chup-chaap fail nahi

    # ── 3. State save ──
    if not DRY_RUN:
        if source == "corporate":
            feed["content_feed"][idx]["used"] = True
            feed["content_feed"][idx]["posted_at"] = NOW.strftime("%Y-%m-%d %H:%M:%S IST")
            feed["content_feed"][idx]["telegraph_url"] = t_url
            save_json(FEED_FILE, feed)
        else:
            queue["queue"][idx]["used"] = True
            queue["queue"][idx]["posted_at"] = NOW.strftime("%Y-%m-%d %H:%M:%S IST")
            queue["queue"][idx]["telegraph_url"] = t_url
            save_json(QUEUE_FILE, queue)

        if t_url:
            state["published"][pid] = {"url": t_url, "kind": source,
                                       "at": NOW.strftime("%Y-%m-%d %H:%M:%S IST")}
        state["last_run"] = NOW.strftime("%Y-%m-%d %H:%M:%S IST")
        save_json(STATE_FILE, state)

        log[pid] = {"at": NOW.strftime("%Y-%m-%d %H:%M:%S IST"), "kind": source,
                    "msg_id": msg_id, "title": str(title)[:80]}
        save_json(POSTED_LOG, log)

    print(f"\n🎉 Posted! msg_id={msg_id} | source={source} | id={pid}")
    print(f"   State save: queue/feed + {STATE_FILE} + {POSTED_LOG}")


if __name__ == "__main__":
    main()
