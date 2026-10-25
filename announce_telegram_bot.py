import os
import json
import html
import time
from datetime import datetime, timezone, timedelta
import requests

from telegram_poster import get_telegraph_token, publish_to_telegraph
from telegraph_cache import find_cached_page, remember_page

# ============================================================
# CONFIGURATION & REPO SECRETS MAPPING
# ============================================================

# Stage 2 Deep Analyst ka final output
INPUT_FILE = "nse_content_feed.json"
POSTED_LOG_FILE = "telegram_posted_log.json"
TELEGRAPH_STATE_FILE = "nse_telegraph_state.json"
SHARED_TELEGRAPH_STATE_FILE = "telegraph_state.json"

BOT_TOKEN = os.environ.get("TELEGRAM_TOKEN") or os.environ.get("TELEGRAM_BOT_TOKEN")

# Channel username
CHAT_ID = "@niftytradingstrategies"

IST = timezone(timedelta(hours=5, minutes=30))
MAX_ANNOUNCEMENT_AGE = timedelta(minutes=30)
POSTING_START_HOUR_IST = 8
POSTING_END_HOUR_IST = 22


def parse_broadcast_datetime(value):
    """Parse NSE broadcast timestamps as IST; return None for missing/invalid dates."""
    if not isinstance(value, str) or not value.strip():
        return None

    clean_value = value.strip().replace(" IST", "").strip()
    parsed = None

    try:
        parsed = datetime.fromisoformat(clean_value.replace("Z", "+00:00"))
    except ValueError:
        for date_format in (
            "%d-%b-%Y %H:%M:%S",
            "%d-%b-%Y %H:%M",
            "%Y-%m-%d %H:%M:%S",
            "%Y-%m-%d %H:%M",
            "%d-%b-%Y",
            "%Y-%m-%d",
        ):
            try:
                parsed = datetime.strptime(clean_value, date_format)
                break
            except ValueError:
                continue

    if parsed is None:
        return None

    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=IST)

    return parsed.astimezone(IST)


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


def load_telegraph_state():
    try:
        with open(TELEGRAPH_STATE_FILE, "r", encoding="utf-8") as state_file:
            state = json.load(state_file)
    except (OSError, json.JSONDecodeError):
        state = {}
    if not isinstance(state, dict):
        state = {}

    # Reuse the existing Telegraph account token without sharing page-state writes
    # with the content-queue workflow.
    if not state.get("access_token"):
        try:
            with open(SHARED_TELEGRAPH_STATE_FILE, "r", encoding="utf-8") as state_file:
                shared_state = json.load(state_file)
            if isinstance(shared_state, dict) and shared_state.get("access_token"):
                state["access_token"] = shared_state["access_token"]
        except (OSError, json.JSONDecodeError):
            pass

    if not isinstance(state.get("published"), dict):
        state["published"] = {}
    return state


def save_telegraph_state(state):
    with open(TELEGRAPH_STATE_FILE, "w", encoding="utf-8") as state_file:
        json.dump(state, state_file, ensure_ascii=False, indent=2)


def append_read_on_web(text, url):
    if not url or url.startswith("(dry-run)"):
        return text
    safe_url = html.escape(url, quote=True)
    return f'{text.rstrip()}\n\n⚡ <b>Read on Web:</b> <a href="{safe_url}">Full announcement</a>'


# ============================================================
# DISPATCH ENGINE
# ============================================================

def is_posting_window(now):
    return POSTING_START_HOUR_IST <= now.hour < POSTING_END_HOUR_IST


def dispatch_feed(now=None):
    now = now or datetime.now(IST)

    print("=" * 80)
    print("🚀 TELEGRAM INSTITUTIONAL FEED DISPATCHER")
    print(f"📅 Timestamp: {now.strftime('%d-%b-%Y %H:%M:%S IST')}")
    print(f"🎯 Target Channel: {CHAT_ID}")
    print(f"📂 Reading Feed: {INPUT_FILE}")
    print("=" * 80)

    if not is_posting_window(now):
        print("🌙 Quiet hours (22:00–08:00 IST); NSE announcement sending is paused")
        return

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

    # Sirf pichhle 30 minutes mein NSE par broadcast hui filings bhejein.
    # Purani/backfill announcements late alert ke roop mein nahi bheji jayengi.
    pending = []
    stale_count = 0
    invalid_date_count = 0

    for card in reversed(content_cards):
        if card.get("hash") in posted_hashes:
            continue

        broadcast_at = parse_broadcast_datetime(card.get("broadcast_date"))
        if broadcast_at is None:
            invalid_date_count += 1
            continue

        age = now - broadcast_at
        if age < timedelta(0) or age > MAX_ANNOUNCEMENT_AGE:
            stale_count += 1
            continue

        pending.append(card)

    print(f"🎯 New unposted announcements in the last 30 minutes: {len(pending)}")

    if stale_count:
        print(
            f"⏭️ Ignoring {stale_count} older/future announcements "
            "outside the 30-minute window."
        )

    if invalid_date_count:
        print(
            f"⏭️ Ignoring {invalid_date_count} announcements "
            "with missing/invalid broadcast dates."
        )

    if not pending:
        print("✅ No pending announcements to broadcast. Everything is up to date!")
        return

    dispatched = 0
    telegraph_state = load_telegraph_state()

    for card in pending:
        if not is_posting_window(datetime.now(IST)):
            print("🌙 Quiet hours started; pausing remaining NSE announcement sends")
            break

        c_hash = card.get("hash")
        sym = card.get("symbol", "")
        post_text = card.get("telegram_post", "")
        if not post_text.strip():
            print(f"⚠️ Skipping {sym}: Empty telegram_post.")
            continue

        headline = card.get("headline") or card.get("company_name") or sym or "NSE Announcement"
        page_id = f"nse:{c_hash}"
        page_text = post_text
        source_url = card.get("pdf_link")
        if source_url and source_url not in page_text:
            page_text = f"{page_text.rstrip()}\n\n🔗 Official NSE filing: {source_url}"

        page_url = find_cached_page(telegraph_state, page_id, headline, page_text)
        if page_url:
            print(f"   ♻️ Reusing matching Telegraph page for {sym}")
        else:
            token = get_telegraph_token(telegraph_state)
            if token:
                # Persist a newly created account token even if page creation fails.
                save_telegraph_state(telegraph_state)
                page_url, page_error = publish_to_telegraph(token, headline, page_text)
            else:
                page_url, page_error = "", "Telegraph account token unavailable"
            if page_url:
                remember_page(
                    telegraph_state,
                    page_id,
                    headline,
                    page_text,
                    page_url,
                    "nse_announcement",
                    datetime.now(IST).strftime("%Y-%m-%d %H:%M:%S IST"),
                )
                # Save before Telegram delivery so retries don't create duplicate pages.
                save_telegraph_state(telegraph_state)
                print(f"   ✅ Telegraph page: {page_url}")
            else:
                print(f"   ⚠️ Telegraph publish failed for {sym}: {page_error}; sending without web link")

        telegram_text = append_read_on_web(post_text, page_url)
        print(f"📤 Broadcasting: {sym}...")
        success, response_msg = send_to_telegram(telegram_text)

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
