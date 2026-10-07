#!/usr/bin/env python3
"""
TELEGRAM POSTER
Broadcaster script to deliver scheduled educational content to Telegram channel.
Uses parse_mode='HTML' for reliable bold tag support.
"""

import os
import sys
import json
import requests
from datetime import datetime, timezone, timedelta

QUEUE_FILE = "content_queue.json"
IST = timezone(timedelta(hours=5, minutes=30))
NOW = datetime.now(IST)

BOT_TOKEN = os.environ.get("TELEGRAM_BOT_TOKEN", "").strip()

# Target channel resolution:
# Takes secret if provided and valid channel identifier; otherwise falls back to @bhaga_657
RAW_TARGET = os.environ.get("TELEGRAM_CHAT_ID", "").strip()
if RAW_TARGET and (RAW_TARGET.startswith("@") or RAW_TARGET.startswith("-100")):
    CHAT_ID = RAW_TARGET
else:
    CHAT_ID = "@bhaga_657"


def send_telegram_message(text: str):
    """
    Sends message using HTML mode.
    Includes fallback to plain text if HTML tags fail to parse.
    """
    url = f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage"
    payload = {
        "chat_id": CHAT_ID,
        "text": text,
        "parse_mode": "HTML",
        "disable_web_page_preview": True
    }
    
    try:
        res = requests.post(url, json=payload, timeout=20)
        res_data = res.json()
        if res_data.get("ok"):
            return True, res_data.get("result", {}).get("message_id")
        else:
            print(f"⚠️ HTML parse failed: {res_data.get('description')}. Retrying without HTML tags...")
            # Fallback: Strip HTML tags and send plain text
            import re
            plain_text = re.sub(r"<[^>]+>", "", text)
            payload["text"] = plain_text
            payload.pop("parse_mode", None)
            retry_res = requests.post(url, json=payload, timeout=15)
            retry_data = retry_res.json()
            if retry_data.get("ok"):
                return True, retry_data.get("result", {}).get("message_id")
            return False, None
    except Exception as e:
        print(f"⚠️ Network error while dispatching to Telegram: {e}")
        return False, None


def main():
    if not BOT_TOKEN:
        print("❌ TELEGRAM_BOT_TOKEN environment variable is missing.")
        sys.exit(1)

    print(f"📢 Target Channel: {CHAT_ID}")

    if not os.path.exists(QUEUE_FILE):
        print(f"❌ {QUEUE_FILE} not found.")
        sys.exit(0)

    try:
        with open(QUEUE_FILE, "r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception as e:
        print(f"❌ Failed to parse {QUEUE_FILE}: {e}")
        sys.exit(1)

    queue = data.get("queue", [])
    now_str = NOW.strftime("%Y-%m-%d %H:%M")

    # Priority 1: Pick post whose scheduled IST time has passed
    target_post = None
    for item in queue:
        if not item.get("used", False):
            if item.get("scheduled_ist", "9999") <= now_str:
                target_post = item
                break

    # Priority 2: Fallback to first available unused post
    if not target_post:
        for item in queue:
            if not item.get("used", False):
                target_post = item
                break

    if not target_post:
        print("ℹ️ No pending posts in queue.")
        return

    text = target_post.get("text", "").strip()
    post_id = target_post.get("id", "UNKNOWN")

    print(f"🚀 Dispatching Post [{post_id}] to {CHAT_ID}...")
    success, msg_id = send_telegram_message(text)

    if success:
        target_post["used"] = True
        target_post["posted_at"] = NOW.strftime("%Y-%m-%d %H:%M:%S IST")
        
        with open(QUEUE_FILE, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)

        print(f"✅ Success! Message ID {msg_id} posted to {CHAT_ID}")
    else:
        print("❌ Broadcast failed. Check Bot permissions in the channel.")
        sys.exit(1)


if __name__ == "__main__":
    main()
