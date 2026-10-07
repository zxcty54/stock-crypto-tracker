#!/usr/bin/env python3
"""
TELEGRAM & TELEGRAPH DISPATCHER (GitHub Actions Native)
Replaces Google Apps Script completely.
Handles:
  - Evergreen Queue (content_queue.json)
  - Corporate NSE Feed (nse_content_feed.json) on 12:45 PM Slot
  - Telegra.ph web publishing for SEO/Google indexing
  - Telegram Broadcast with HTML parsing & fallback
"""

import os
import sys
import json
import re
import requests
from datetime import datetime, timezone, timedelta

QUEUE_FILE = "content_queue.json"
FEED_FILE  = "nse_content_feed.json"

IST = timezone(timedelta(hours=5, minutes=30))
NOW = datetime.now(IST)

BOT_TOKEN = os.environ.get("TELEGRAM_BOT_TOKEN", "").strip()

# Target Channel
RAW_TARGET = os.environ.get("TELEGRAM_CHAT_ID", "").strip()
if RAW_TARGET and (RAW_TARGET.startswith("@") or RAW_TARGET.startswith("-100")):
    CHAT_ID = RAW_TARGET
else:
    CHAT_ID = "@bhaga_657"

DISCLAIMER = "\n\n⚠️ <i>Educational only. Not investment advice. Not SEBI registered.</i>"
AI_NOTICE  = "\n🤖 <i>AI-assisted summary of public corporate filing.</i>"


# ============================================================
# 🌐 TELEGRAPH PUBLISHER (For Webpage Indexing & Instant View)
# ============================================================
def publish_to_telegraph(title: str, text: str) -> str:
    try:
        acc_resp = requests.get(
            "https://api.telegra.ph/createAccount",
            params={
                "short_name": "StockPulse",
                "author_name": "StockPulse Education",
                "author_url": "https://t.me/bhaga_657"
            },
            timeout=10
        ).json()
        
        token = acc_resp.get("result", {}).get("access_token")
        if not token:
            return ""

        clean_lines = [l.strip() for l in text.split("\n") if l.strip()]
        nodes = []
        for line in clean_lines:
            clean_text = re.sub(r"<[^>]+>", "", line)
            nodes.append({"tag": "p", "children": [clean_text]})

        nodes.append({
            "tag": "p",
            "children": [
                "📢 Join Telegram: ",
                {"tag": "a", "attrs": {"href": "https://t.me/bhaga_657"}, "children": ["@bhaga_657"]}
            ]
        })

        page_resp = requests.post(
            "https://api.telegra.ph/createPage",
            json={
                "access_token": token,
                "title": title[:60] or "Market Update",
                "author_name": "StockPulse",
                "author_url": "https://t.me/bhaga_657",
                "content": nodes,
                "return_content": False
            },
            timeout=15
        ).json()

        if page_resp.get("ok"):
            return page_resp.get("result", {}).get("url", "")
    except Exception as e:
        print(f"⚠️ Telegraph error: {e}")
    return ""


# ============================================================
# 📨 TELEGRAM BROADCASTER
# ============================================================
def send_telegram_message(text: str):
    url = f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage"
    payload = {
        "chat_id": CHAT_ID,
        "text": text,
        "parse_mode": "HTML",
        "disable_web_page_preview": False
    }
    
    try:
        res = requests.post(url, json=payload, timeout=20)
        res_data = res.json()
        if res_data.get("ok"):
            return True, res_data.get("result", {}).get("message_id")
        else:
            print(f"⚠️ HTML failed ({res_data.get('description')}). Retrying as plain text...")
            plain_text = re.sub(r"<[^>]+>", "", text)
            payload["text"] = plain_text
            payload.pop("parse_mode", None)
            retry_res = requests.post(url, json=payload, timeout=15)
            retry_data = retry_res.json()
            if retry_data.get("ok"):
                return True, retry_data.get("result", {}).get("message_id")
            return False, None
    except Exception as e:
        print(f"⚠️ Telegram API exception: {e}")
        return False, None


# ============================================================
# 🎯 CONTENT SELECTION ENGINE
# ============================================================
def pick_corporate_post(feed_data):
    if not feed_data or not feed_data.get("content_feed"):
        return None, -1

    items = feed_data["content_feed"]
    # Reverse iteration to preserve chronological order
    for idx in range(len(items) - 1, -1, -1):
        item = items[idx]
        if not item.get("used", False) and item.get("telegram_post"):
            return item, idx
    return None, -1

def pick_evergreen_post(queue_data):
    if not queue_data or not queue_data.get("queue"):
        return None, -1

    now_str = NOW.strftime("%Y-%m-%d %H:%M")
    items = queue_data["queue"]

    # 1. Scheduled post
    for idx, item in enumerate(items):
        if not item.get("used", False):
            if item.get("scheduled_ist", "9999") <= now_str:
                return item, idx

    # 2. Next unused fallback
    for idx, item in enumerate(items):
        if not item.get("used", False):
            return item, idx

    return None, -1


# ============================================================
# 🚀 MAIN RUNNER
# ============================================================
def main():
    if not BOT_TOKEN:
        print("❌ TELEGRAM_BOT_TOKEN missing.")
        sys.exit(1)

    # Slot checking based on current hour IST (12:00 to 14:00 is Slot B - Afternoon)
    is_corporate_slot = (12 <= NOW.hour <= 14)
    print(f"⏰ Current IST Time: {NOW.strftime('%Y-%m-%d %H:%M:%S')} (Corporate Preferred: {is_corporate_slot})")

    chosen_post = None
    post_source = None  # 'corporate' or 'evergreen'
    source_index = -1

    # Load JSON files
    queue_data = {}
    if os.path.exists(QUEUE_FILE):
        try:
            with open(QUEUE_FILE, "r", encoding="utf-8") as f:
                queue_data = json.load(f)
        except Exception:
            queue_data = {}

    feed_data = {}
    if os.path.exists(FEED_FILE):
        try:
            with open(FEED_FILE, "r", encoding="utf-8") as f:
                feed_data = json.load(f)
        except Exception:
            feed_data = {}

    # Prefer corporate news at 12:45 PM slot
    if is_corporate_slot and feed_data:
        chosen_post, source_index = pick_corporate_post(feed_data)
        if chosen_post:
            post_source = "corporate"
            print("📰 Selected fresh Corporate filing post.")

    # Fallback to evergreen queue
    if not chosen_post:
        chosen_post, source_index = pick_evergreen_post(queue_data)
        if chosen_post:
            post_source = "evergreen"
            print("📚 Selected Evergreen educational post.")

    if not chosen_post:
        print("ℹ️ No pending posts available in queue or feed.")
        return

    # Prepare text
    if post_source == "corporate":
        raw_text = chosen_post.get("telegram_post", "")
        post_title = chosen_post.get("headline") or chosen_post.get("symbol") or "Corporate News"
        post_id = chosen_post.get("hash", "corp")
        if "AI-assisted" not in raw_text:
            raw_text += AI_NOTICE
    else:
        raw_text = chosen_post.get("text", "")
        post_title = chosen_post.get("title", "Market Insights")
        post_id = chosen_post.get("id", "post")

    if "Not SEBI registered" not in raw_text:
        raw_text += DISCLAIMER

    # 1. Publish to Telegraph (Google indexing)
    print(f"🌐 Publishing [{post_id}] to Telegra.ph...")
    telegraph_url = publish_to_telegraph(post_title, raw_text)

    final_text = raw_text
    if telegraph_url:
        print(f"✅ Telegraph Live Link: {telegraph_url}")
        final_text += f"\n\n⚡ <b>Read on Web (Instant View):</b>\n{telegraph_url}"

    # 2. Send to Telegram Channel
    print(f"🚀 Dispatching to {CHAT_ID}...")
    success, msg_id = send_telegram_message(final_text)

    if success:
        # Mark used and save in respective JSON
        if post_source == "corporate":
            feed_data["content_feed"][source_index]["used"] = True
            feed_data["content_feed"][source_index]["posted_at"] = NOW.strftime("%Y-%m-%d %H:%M:%S IST")
            feed_data["content_feed"][source_index]["telegraph_url"] = telegraph_url
            with open(FEED_FILE, "w", encoding="utf-8") as f:
                json.dump(feed_data, f, ensure_ascii=False, indent=2)
            print(f"💾 Updated {FEED_FILE}")
        else:
            queue_data["queue"][source_index]["used"] = True
            queue_data["queue"][source_index]["posted_at"] = NOW.strftime("%Y-%m-%d %H:%M:%S IST")
            queue_data["queue"][source_index]["telegraph_url"] = telegraph_url
            with open(QUEUE_FILE, "w", encoding="utf-8") as f:
                json.dump(queue_data, f, ensure_ascii=False, indent=2)
            print(f"💾 Updated {QUEUE_FILE}")

        print(f"🎉 Successfully posted! Msg ID: {msg_id}")
    else:
        print("❌ Broadcast failed.")
        sys.exit(1)


if __name__ == "__main__":
    main()
