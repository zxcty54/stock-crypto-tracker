import os
import json
import time
from datetime import datetime, timezone, timedelta
import requests

# ============================================================
# CONFIGURATION & REPO SECRETS MAPPING
# ============================================================

# Stage 2 Deep Analyst ka final output
INPUT_FILE = "nse_content_feed.json"
POSTED_LOG_FILE = "telegram_posted_log.json"

BOT_TOKEN = os.environ.get("TELEGRAM_TOKEN") or os.environ.get("TELEGRAM_BOT_TOKEN")

# Channel username
CHAT_ID = "@bhaga_657"

IST = timezone(timedelta(hours=5, minutes=30))

# ============================================================
# DISPATCH HELPER
# ============================================================

def send_to_telegram(text_payload):
    url = f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage"
    payload = {
        "chat_id": CHAT_ID,
        "text": text_payload,
        "parse_mode": "HTML",
        "disable_web_page_preview": True
    }
    try:
        resp = requests.post(url, json=payload, timeout=20)
        return resp.status_code == 200, resp.text
    except Exception as e:
        return False, str(e)

# ============================================================
# DISPATCH ENGINE
# ============================================================

def dispatch_feed():
    print("=" * 80)
    print("🚀 TELEGRAM INSTITUTIONAL FEED DISPATCHER")
    print(f"📅 Timestamp: {datetime.now(IST).strftime('%d-%b-%Y %H:%M:%S IST')}")
    print(f"🎯 Target Channel: {CHAT_ID}")
    print(f"📂 Reading Feed: {INPUT_FILE}")
    print("=" * 80)

    if not BOT_TOKEN:
        print("❌ FATAL: 'TELEGRAM_TOKEN' or 'TELEGRAM_BOT_TOKEN' missing in GitHub environment.")
        exit(1)

    if not os.path.exists(INPUT_FILE):
        print(f"ℹ️ Input feed file '{INPUT_FILE}' not found. Exiting cleanly.")
        return

    with open(INPUT_FILE, "r", encoding="utf-8") as f:
        try:
            feed_data = json.load(f)
        except Exception as e:
            print(f"❌ Error reading JSON: {e}")
            return

    content_cards = feed_data.get("content_feed", [])
    print(f"📦 Total cards in final content feed: {len(content_cards)}")

    posted_hashes = set()
    if os.path.exists(POSTED_LOG_FILE):
        try:
            with open(POSTED_LOG_FILE, "r", encoding="utf-8") as f:
                loaded = json.load(f)
                if isinstance(loaded, list):
                    posted_hashes = set(loaded)
        except Exception:
            pass

    # Reverse order so older filings in the batch post first, keeping chronological order in Telegram
    pending = [card for card in reversed(content_cards) if card.get("hash") not in posted_hashes]
    print(f"🎯 Fresh unposted corporate actions: {len(pending)}")

    if not pending:
        print("✅ No pending announcements to broadcast. Everything is up to date!")
        return

    dispatched = 0
    for card in pending:
        c_hash = card.get("hash")
        sym = card.get("symbol", "")
        post_text = card.get("telegram_post", "")

        if not post_text.strip():
            print(f"⚠️ Skipping {sym}: Empty telegram_post.")
            continue

        print(f"📤 Broadcasting: {sym}...")
        success, response_msg = send_to_telegram(post_text)

        if success:
            posted_hashes.add(c_hash)
            dispatched += 1
            time.sleep(3)  # Rate limit threshold safety for Telegram API
        else:
            print(f"   ⚠️ Telegram delivery failed for {sym}: {response_msg}")

    # Retain up to 2,000 hashes for state deduplication
    pruned_hashes = list(posted_hashes)[-2000:]
    with open(POSTED_LOG_FILE, "w", encoding="utf-8") as f:
        json.dump(pruned_hashes, f, indent=2)

    print("\n" + "=" * 80)
    print(f"✅ DISPATCH COMPLETE: {dispatched} new institutional notes broadcast to Telegram.")
    print("=" * 80)

if __name__ == "__main__":
    dispatch_feed()
