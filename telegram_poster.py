#!/usr/bin/env python3
import os
import json
import requests
from datetime import datetime, timezone, timedelta

QUEUE_FILE = "content_queue.json"
IST = timezone(timedelta(hours=5, minutes=30))
NOW = datetime.now(IST)

BOT_TOKEN = os.environ.get("TELEGRAM_BOT_TOKEN", "").strip()
CHAT_ID = os.environ.get("TELEGRAM_CHAT_ID", "").strip()

def send_telegram_message(text):
    url = f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage"
    payload = {
        "chat_id": CHAT_ID,
        "text": text,
        "parse_mode": "HTML"
    }
    res = requests.post(url, json=payload, timeout=15)
    return res.status_code == 200

def main():
    if not BOT_TOKEN or not CHAT_ID:
        print("❌ Telegram credentials missing.")
        return

    if not os.path.exists(QUEUE_FILE):
        print(f"❌ {QUEUE_FILE} not found.")
        return

    with open(QUEUE_FILE, "r", encoding="utf-8") as f:
        data = json.load(f)

    queue = data.get("queue", [])
    now_str = NOW.strftime("%Y-%m-%d %H:%M")

    # Find first unposted item whose scheduled time has arrived or passed
    target_post = None
    for item in queue:
        if not item.get("used", False):
            # Check if scheduled time is <= current time
            if item.get("scheduled_ist", "9999") <= now_str:
                target_post = item
                break

    # If no past-due post found, pick the next available unused post as fallback
    if not target_post:
        for item in queue:
            if not item.get("used", False):
                target_post = item
                break

    if not target_post:
        print("ℹ️ No pending posts in queue.")
        return

    # Telegram formatting
    text = target_post["text"]
    success = send_telegram_message(text)

    if success:
        target_post["used"] = True
        target_post["posted_at"] = NOW.strftime("%Y-%m-%d %H:%M:%S IST")
        
        with open(QUEUE_FILE, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)

        print(f"✅ Posted ID: {target_post['id']} to Telegram ({target_post.get('title')})")
    else:
        print("❌ Failed to broadcast to Telegram.")

if __name__ == "__main__":
    main()
