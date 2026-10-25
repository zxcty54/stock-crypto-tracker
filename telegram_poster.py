#!/usr/bin/env python3
"""
CHANNEL DISPATCHER (GitHub Actions Native)
===========================================
- Hardcoded Target: @bhaga_657 (No secret dependency for chat target)
- Public Telegraph pages; search-engine indexing is not guaranteed
- Telegram broadcast with HTML formatting & rate-limit handling
- Duplicate guard & JSON state management
"""

import os
import re
import sys
import json
import time
import html as html_lib
from datetime import datetime, timezone, timedelta

import requests

from telegraph_cache import find_cached_page, remember_page

# ============================================================
# CONFIG
# ============================================================

QUEUE_FILE = "content_queue.json"
FEED_FILE  = "nse_content_feed.json"
STATE_FILE = "telegraph_state.json"      # telegraph token + published pages
POSTED_LOG = "post_log.json"              # kaunsa post kab gaya (audit + dedup)

BOT_TOKEN = (os.environ.get("TELEGRAM_BOT_TOKEN")
             or os.environ.get("TELEGRAM_TOKEN") or "").strip()

# 🎯 Channel Target Hardcoded (Direct Broadcast)
CHAT_ID = "@niftytradingstrategies"

# Brand Details
CHANNEL_LINK = "https://t.me/bhaga_657"
AUTHOR_NAME  = "StockPulse Education"
SHORT_NAME   = "StockPulse"

# Corporate slot — 12 PM, 1 PM, 2 PM IST me corporate news prefer kare
CORPORATE_HOURS = [12, 13, 14]
DUPLICATE_WINDOW_HOURS = 2      # itne ghante me same post dobara nahi
POSTING_START_HOUR_IST = 8
POSTING_END_HOUR_IST = 22      # 10 PM ke baad aur 8 AM se pehle quiet hours

IST = timezone(timedelta(hours=5, minutes=30))
NOW = datetime.now(IST)

DRY_RUN = "--dry-run" in sys.argv
STATUS  = "--status" in sys.argv
TEST    = "--test" in sys.argv
QUEUE_ONLY = "--queue-only" in sys.argv

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
            print("   🔑 Telegraph account bana (ek baar ka kaam)")
            return token
        print(f"   ⚠️ Telegraph account fail: {r.get('error')}")
    except Exception as e:
        print(f"   ⚠️ Telegraph account exception: {e}")
    return None


def publish_to_telegraph(token, title, text):
    if not token:
        return "", "telegraph token nahi mila"

    clean_lines = []
    for line in text.split("\n"):
        t = line.strip()
        if not t:
            continue
        t = re.sub(
            r"<a\b[^>]*href\s*=\s*([\"'])(.*?)\1[^>]*>(.*?)</a\s*>",
            lambda match: f"{match.group(3)} ({match.group(2)})",
            t,
            flags=re.I | re.S,
        )
        t = re.sub(r"<[^>]+>", "", t)
        t = html_lib.unescape(t)
        t = t.strip()
        if not t:
            continue
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

    # Footer CTA
    nodes.append({"tag": "hr"})
    nodes.append({"tag": "p", "children": [
        "📢 Telegram pe join karo: ",
        {"tag": "a", "attrs": {"href": CHANNEL_LINK},
         "children": [CHAT_ID]}]})
    nodes.append({"tag": "p", "children": [
        {"tag": "em", "children": [
            "⚠️ Educational only. Not investment advice. Not SEBI registered."]}]})

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

            # Rate limit check
            if res.status_code == 429:
                wait = int(data.get("parameters", {}).get("retry_after", 30))
                print(f"   ⏳ Rate limit — {wait}s wait")
                time.sleep(wait + 2)
                continue

            # Fallback to plain text on HTML error
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
    entry = log.get(post_id)
    if not entry:
        return False
    try:
        when = datetime.strptime(entry["at"].replace(" IST", ""),
                                 "%Y-%m-%d %H:%M:%S").replace(tzinfo=IST)
        return (NOW - when) < timedelta(hours=DUPLICATE_WINDOW_HOURS)
    except Exception:
        return True


def is_posting_window(now=None):
    now = now or NOW
    return POSTING_START_HOUR_IST <= now.hour < POSTING_END_HOUR_IST


def pick_corporate_post(feed_data, log):
    items = (feed_data or {}).get("content_feed", [])
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
    available = []
    for idx, item in enumerate(items):
        if item.get("used") or is_duplicate(item.get("id", ""), log):
            continue
        available.append((idx, item))

    due = [(idx, item) for idx, item in available
           if item.get("scheduled_ist", "9999") <= now_str]
    # The just-scraped, source-grounded business story should not sit behind
    # old evergreen entries when both are due in the same posting slot.
    for pool in (due, available):
        business_news = next(
            ((item, idx) for idx, item in pool
             if item.get("kind") == "business_news_insight"),
            None,
        )
        if business_news:
            return business_news
        if pool:
            idx, item = pool[0]
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
    slot_label = "QUEUE ONLY" if QUEUE_ONLY else (
        "CORPORATE" if NOW.hour in CORPORATE_HOURS else "EVERGREEN"
    )
    print(f"   Aaj ka slot      : {slot_label}")
    nxt = pick_evergreen_post(queue, log)
    if nxt[0]:
        print(f"   Agla post        : {nxt[0].get('scheduled_ist')} — {nxt[0].get('title','')[:45]}")


# ============================================================
# 🚀 MAIN
# ============================================================

def main():
    print("=" * 76)
    print(f"🚀 CHANNEL DISPATCHER — Telegram + Telegraph")
    print(f"📅 {NOW.strftime('%Y-%m-%d %H:%M:%S IST')} | channel: {CHAT_ID}")
    print("=" * 76)

    queue = load_json(QUEUE_FILE, {"queue": []})
    feed  = load_json(FEED_FILE, {"content_feed": []})
    state = load_json(STATE_FILE, {})
    if not isinstance(state, dict):
        state = {}
    if not isinstance(state.get("published"), dict):
        state["published"] = {}
    log   = load_json(POSTED_LOG, {})

    if STATUS:
        show_status(queue, feed, state, log)
        return

    if not is_posting_window():
        print("🌙 Quiet hours (22:00–08:00 IST); no Telegram post sent")
        return

    if not BOT_TOKEN and not DRY_RUN:
        print("❌ TELEGRAM_BOT_TOKEN missing.")
        sys.exit(1)

    is_corporate_slot = NOW.hour in CORPORATE_HOURS and not QUEUE_ONLY
    slot_label = "QUEUE ONLY" if QUEUE_ONLY else (
        "CORPORATE preferred" if is_corporate_slot else "EVERGREEN"
    )
    print(f"⏰ Slot: {slot_label}")

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

    # 1. Telegraph
    print(f"\n🌐 Telegraph publish [{pid}]...")
    existing_url = find_cached_page(state, pid, title, raw)
    if existing_url:
        t_url, t_err = existing_url, None
        print("   ♻️ Matching Telegraph page already exists — reusing it")
    else:
        token = get_telegraph_token(state)
        t_url, t_err = publish_to_telegraph(token, title, raw)
    if t_url:
        print(f"   ✅ {t_url}")
        if not DRY_RUN:
            remember_page(
                state, pid, title, raw, t_url, source,
                NOW.strftime("%Y-%m-%d %H:%M:%S IST"),
            )
            # Persist before Telegram delivery so a retry reuses the same page.
            save_json(STATE_FILE, state)
    else:
        print(f"   ⚠️ Web publish fail: {t_err} (Telegram post phir bhi jaayega)")

    # 2. Telegram message setup
    if t_url and not DRY_RUN:
        if DISCLAIMER.strip() in raw:
            raw = raw.replace(DISCLAIMER, f"\n\n⚡ <b>Read on Web:</b> {t_url}{DISCLAIMER}")
        else:
            raw += f"\n\n⚡ <b>Read on Web:</b> {t_url}"
    elif t_url and DRY_RUN:
        raw += f"\n\n⚡ <b>Read on Web:</b> {t_url}"

    if not is_posting_window(datetime.now(IST)):
        print("🌙 Quiet hours started before Telegram dispatch; leaving the queue item untouched")
        if not DRY_RUN:
            save_json(STATE_FILE, state)
        return

    print(f"\n🚀 Dispatching to {CHAT_ID}...")
    ok, msg_id, err = send_telegram_message(raw)

    if not ok:
        print(f"❌ Broadcast fail: {err}")
        sys.exit(1)

    # 3. State update
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

        state["last_run"] = NOW.strftime("%Y-%m-%d %H:%M:%S IST")
        save_json(STATE_FILE, state)

        log[pid] = {"at": NOW.strftime("%Y-%m-%d %H:%M:%S IST"), "kind": source,
                    "msg_id": msg_id, "title": str(title)[:80]}
        save_json(POSTED_LOG, log)

    print(f"\n🎉 Posted! msg_id={msg_id} | source={source} | id={pid} to {CHAT_ID}")


if __name__ == "__main__":
    main()
