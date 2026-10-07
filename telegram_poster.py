#!/usr/bin/env python3
import os
import json
import requests
from datetime import datetime, timezone, timedelta

QUEUE_FILE = "content_queue.json"
IST = timezone(timedelta(hours=5, minutes=30))
NOW = datetime.now(IST)

BOT_TOKEN = os.environ.get("TELEGRAM_BOT_TOKEN", "").strip()

# 🎯 Channel Target Configuration:
# Agar secret set hai toh wo lega, warna directly aapke channel @bhaga_657 par post karega
RAW_CHAT_ID = os.environ.get("TELEGRAM_CHAT_ID", "").strip()
if RAW_CHAT_ID and (RAW_CHAT_ID.startswith("@") or RAW_CHAT_ID.startswith("-100")):
    CHAT_ID = RAW_CHAT_ID
else:
    # Fallback to direct channel username
    CHAT_ID = "@bhaga_657"

def send_telegram_message(text):
    url = f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage"
    payload = {
        "chat_id": CHAT_ID,
        "text": text,
        "disable_web_page_preview": True
    }
    
    try:
        res = requests.post(url, json=payload, timeout=20)
        res_data = res.json()
        if res_data.get("ok"):
            return True, res_data.get("result", {}).get("message_id")
        else:
            print(f"❌ Telegram API Error: {res_data.get('description')}")
            return False, None
    except Exception as e:
        print(f"⚠️ Network error while calling Telegram API: {e}")
        return False, None

def main():
    if not BOT_TOKEN:
        print("❌ TELEGRAM_BOT_TOKEN environment variable is missing.")
        return

    print(f"📢 Target Destination: {CHAT_ID}")

    if not os.path.exists(QUEUE_FILE):
        print(f"❌ {QUEUE_FILE} not found.")
        return

    try:
        with open(QUEUE_FILE, "r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception as e:
        print(f"❌ Failed to parse {QUEUE_FILE}: {e}")
        return

    queue = data.get("queue", [])
    now_str = NOW.strftime("%Y-%m-%d %H:%M")

    # 1. First priority: Jo scheduled time cross kar chuka ho
    target_post = None
    for item in queue:
        if not item.get("used", False):
            if item.get("scheduled_ist", "9999") <= now_str:
                target_post = item
                break

    # 2. Fallback: Agla unused post
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

        print(f"✅ Success! Message ID {msg_id} broadcast to channel {CHAT_ID}!")
    else:
        print("❌ Broadcast failed. Check if Bot is an administrator in @bhaga_657 with 'Post Messages' permission.")

if __name__ == "__main__":
    main()
