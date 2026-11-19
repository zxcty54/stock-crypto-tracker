#!/usr/bin/env python3
"""
MAINBOARD IPO TRACKER & TELEGRAM DISPATCHER
============================================
Tracks Indian Mainboard IPOs from the internet and automatically broadcasts
timely, high-value alerts to Telegram (@ipocentral).

Features:
- Multi-source scraper (Chittorgarh Report 82, InvestorGain GMP 331, NSE, BSE, IPOCentral)
- Strictly tracks MAINBOARD issues (NSE / BSE Mainboard) and rejects SME IPOs
- Full lifecycle alert management:
    1. NEW_IPO_ANNOUNCED (Initial overview with timetable, price, lot, issue size & GMP)
    2. IPO_OPENS_TODAY   (Opening day bidding call with live lot & GMP details)
    3. IPO_CLOSING_TODAY (Final day reminder with subscription numbers & cut-off deadline)
    4. ALLOTMENT_OUT     (Basis of allotment processed with 1-click direct registrar links)
    5. LISTING_TODAY     (Listing debut alert with issue vs listing price & gains)
    6. GMP_DASHBOARD     (Daily snapshot of active Mainboard IPOs)
- State persistence (ipo_master.json) & Deduplication guard (ipo_posted_log.json)
- Rate-limit safety & quiet hours compliance (08:00 AM - 22:00 PM IST)
"""

from __future__ import annotations

import os
import sys
import json
import time
import logging
from datetime import datetime, timezone, timedelta

import requests

from ipo_scrapers import IpoAggregator, sanitize_slug, is_already_listed
from ipo_formatter import (
    format_ipo_post,
    format_gmp_dashboard,
    format_test_verification_post,
    CHANNEL_HANDLE,
)

# ============================================================
# LOGGING CONFIGURATION
# ============================================================

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger("ipo_tracker")

# ============================================================
# SETTINGS & ENVIRONMENT
# ============================================================

MASTER_FILE = "ipo_master.json"
POSTED_LOG_FILE = "ipo_posted_log.json"

BOT_TOKEN = (
    os.environ.get("TELEGRAM_BOT_TOKEN")
    or os.environ.get("TELEGRAM_TOKEN")
    or ""
).strip()

CHAT_ID = (
    os.environ.get("IPO_TELEGRAM_CHAT_ID")
    or os.environ.get("TELEGRAM_CHAT_ID")
    or CHANNEL_HANDLE
).strip()

IST = timezone(timedelta(hours=5, minutes=30))
POSTING_START_HOUR_IST = 8
POSTING_END_HOUR_IST = 22

DRY_RUN = "--dry-run" in sys.argv
STATUS_ONLY = "--status" in sys.argv
TEST_MODE = "--test" in sys.argv
TEST_POST_MODE = "--test-post" in sys.argv
SUMMARY_ONLY = "--summary" in sys.argv
FORCE_EVENT_ARG = "--force-event" in sys.argv
IGNORE_QUIET = "--ignore-quiet-hours" in sys.argv or DRY_RUN or TEST_MODE or TEST_POST_MODE or FORCE_EVENT_ARG


# ============================================================
# STATE PERSISTENCE
# ============================================================

def load_master() -> dict[str, dict]:
    """Load tracked IPO master database."""
    if not os.path.exists(MASTER_FILE):
        return {}
    try:
        with open(MASTER_FILE, "r", encoding="utf-8") as f:
            data = json.load(f)
            if isinstance(data, list):
                return {item.get("id", sanitize_slug(item.get("company_name", ""))): item for item in data}
            if isinstance(data, dict):
                return data
    except Exception as e:
        logger.error(f"Error reading {MASTER_FILE}: {e}")
    return {}


def save_master(master_dict: dict[str, dict]) -> None:
    """Save tracked IPO master database."""
    try:
        # Sort by open_date or company_name
        items = list(master_dict.values())
        items.sort(key=lambda x: (x.get("open_date") or "9999-99-99", x.get("company_name") or ""), reverse=True)
        with open(MASTER_FILE, "w", encoding="utf-8") as f:
            json.dump(items, f, indent=2, ensure_ascii=False)
        logger.info(f"Saved {len(items)} IPO records to {MASTER_FILE}")
    except Exception as e:
        logger.error(f"Error saving {MASTER_FILE}: {e}")


def load_posted_log() -> list[str]:
    """Load list of posted event IDs for deduplication."""
    if not os.path.exists(POSTED_LOG_FILE):
        return []
    try:
        with open(POSTED_LOG_FILE, "r", encoding="utf-8") as f:
            data = json.load(f)
            if isinstance(data, list):
                return data
    except Exception as e:
        logger.error(f"Error reading {POSTED_LOG_FILE}: {e}")
    return []


def save_posted_log(posted_log: list[str]) -> None:
    """Save posted event IDs."""
    try:
        # Keep latest 2000 events
        pruned = posted_log[-2000:]
        with open(POSTED_LOG_FILE, "w", encoding="utf-8") as f:
            json.dump(pruned, f, indent=2)
    except Exception as e:
        logger.error(f"Error saving {POSTED_LOG_FILE}: {e}")


# ============================================================
# TELEGRAM DISPATCHER
# ============================================================

def send_telegram_message(
    text: str,
    bot_token: str | None = None,
    chat_id: str | None = None,
    disable_web_page_preview: bool = True,
) -> tuple[bool, str]:
    """Dispatch an HTML formatted message to Telegram channel."""
    token = bot_token or BOT_TOKEN
    target = chat_id or CHAT_ID

    if DRY_RUN:
        logger.info(f"[DRY-RUN] Would send to {target}:\n{text}\n")
        return True, "dry-run-ok"

    if not token:
        return False, "Missing TELEGRAM_BOT_TOKEN"

    url = f"https://api.telegram.org/bot{token}/sendMessage"
    payload = {
        "chat_id": target,
        "text": text,
        "parse_mode": "HTML",
        "disable_web_page_preview": disable_web_page_preview,
    }

    try:
        resp = requests.post(url, json=payload, timeout=25)
        if resp.status_code == 200:
            return True, "ok"
        return False, f"Telegram API error {resp.status_code}: {resp.text}"
    except Exception as e:
        return False, f"Request exception: {e}"


def test_telegram_connection(send_sample: bool = False) -> bool:
    """Test Telegram Bot credentials, channel permissions, and optionally dispatch a live verification post."""
    if not BOT_TOKEN:
        logger.error("❌ TELEGRAM_BOT_TOKEN or TELEGRAM_TOKEN is not set.")
        return False

    logger.info(f"Testing Telegram connection with target channel: {CHAT_ID}")

    # 1. Test getMe
    try:
        resp = requests.get(f"https://api.telegram.org/bot{BOT_TOKEN}/getMe", timeout=15)
        if resp.status_code != 200:
            logger.error(f"❌ getMe failed: {resp.text}")
            return False
        bot_info = resp.json().get("result", {})
        logger.info(f"✅ Bot is valid: @{bot_info.get('username')} ({bot_info.get('first_name')})")
    except Exception as e:
        logger.error(f"❌ Failed to reach Telegram API: {e}")
        return False

    # 2. Test getChat
    try:
        resp = requests.get(
            f"https://api.telegram.org/bot{BOT_TOKEN}/getChat",
            params={"chat_id": CHAT_ID},
            timeout=15,
        )
        if resp.status_code != 200:
            logger.error(f"❌ getChat failed for {CHAT_ID}: {resp.text}")
            logger.warning("Ensure the bot is added as an administrator to the channel!")
            return False
        chat_info = resp.json().get("result", {})
        logger.info(f"✅ Channel verified: {chat_info.get('title')} ({chat_info.get('username') or CHAT_ID})")
    except Exception as e:
        logger.error(f"❌ Failed to verify chat {CHAT_ID}: {e}")
        return False

    # 3. Dispatch Live Test Post if requested
    if send_sample:
        logger.info(f"📨 Broadcasting live verification test post to {CHAT_ID}...")
        test_html = format_test_verification_post()
        success, msg = send_telegram_message(test_html)
        if success:
            logger.info(f"🎉 Live verification test post successfully delivered to {CHAT_ID}!")
            return True
        else:
            logger.error(f"❌ Failed to deliver live verification test post: {msg}")
            return False

    return True


# ============================================================
# EVENT DETECTION & SCHEDULING
# ============================================================

def is_posting_window(now: datetime) -> bool:
    """Check if current time is within Indian trading/daytime posting window."""
    if IGNORE_QUIET:
        return True
    return POSTING_START_HOUR_IST <= now.hour < POSTING_END_HOUR_IST


def evaluate_ipo_events(ipo: dict, today_str: str, posted_events_set: set[str]) -> list[tuple[str, str]]:
    """
    Evaluate an IPO against today's date to determine which lifecycle alerts are pending.
    Strictly excludes already-listed historical IPOs.
    Returns a list of (event_type, event_id).
    """
    events = []
    ipo_id = ipo.get("id") or sanitize_slug(ipo.get("company_name", ""))
    open_date = ipo.get("open_date")
    close_date = ipo.get("close_date")
    allotment_date = ipo.get("allotment_date")
    listing_date = ipo.get("listing_date")
    allotment_out = ipo.get("allotment_out", False)

    # 0. Reject already listed or expired past issues
    if is_already_listed(ipo, today_str):
        return []

    if close_date and close_date < today_str:
        return []

    if listing_date and listing_date < today_str:
        return []

    # 1. NEW_IPO_ANNOUNCED vs IPO_OPENS_TODAY
    # If opening today, trigger IPO_OPENS_TODAY as the urgent alert (suppressing duplicate NEW_IPO_ANNOUNCED)
    new_event_id = f"ipo:{ipo_id}:announced"
    opens_event_id = f"ipo:{ipo_id}:opens_today"

    if open_date and open_date == today_str:
        if opens_event_id not in posted_events_set:
            events.append(("IPO_OPENS_TODAY", opens_event_id))
            posted_events_set.add(new_event_id)
    elif new_event_id not in posted_events_set:
        is_relevant = False
        if open_date and open_date > today_str:
            is_relevant = True
        elif open_date and close_date and open_date < today_str <= close_date:
            is_relevant = True

        if is_relevant:
            events.append(("NEW_IPO_ANNOUNCED", new_event_id))

    # 2. IPO_CLOSING_TODAY
    closing_event_id = f"ipo:{ipo_id}:closing_today"
    if close_date and close_date == today_str and closing_event_id not in posted_events_set:
        events.append(("IPO_CLOSING_TODAY", closing_event_id))

    # 4. ALLOTMENT_OUT
    allot_event_id = f"ipo:{ipo_id}:allotment_out"
    if allot_event_id not in posted_events_set:
        if allotment_out or (allotment_date and allotment_date == today_str):
            events.append(("ALLOTMENT_OUT", allot_event_id))

    # 5. LISTING_TODAY
    list_event_id = f"ipo:{ipo_id}:listing_today"
    if listing_date and listing_date == today_str and list_event_id not in posted_events_set:
        events.append(("LISTING_TODAY", list_event_id))

    return events


# ============================================================
# MAIN ORCHESTRATOR
# ============================================================

def run_tracker(now: datetime | None = None) -> int:
    """Run the complete scraping, event detection, and Telegram broadcast pipeline."""
    now = now or datetime.now(IST)
    today_str = now.strftime("%Y-%m-%d")

    logger.info("=" * 70)
    logger.info("🚀 MAINBOARD IPO TRACKER & TELEGRAM BROADCASTER")
    logger.info(f"📅 Timestamp: {now.strftime('%d-%b-%Y %H:%M:%S IST')} (Today: {today_str})")
    logger.info(f"🎯 Target Channel: {CHAT_ID}")
    logger.info(f"🛡️ Dry Run: {DRY_RUN} | Status Only: {STATUS_ONLY}")
    logger.info("=" * 70)

    # 1. Load existing state
    master = load_master()
    posted_log = load_posted_log()
    posted_set = set(posted_log)
    logger.info(f"Loaded {len(master)} tracked IPOs and {len(posted_log)} historical posted events.")

    # 2. Check quiet hours
    if not is_posting_window(now) and not STATUS_ONLY:
        logger.info(f"🌙 Quiet hours active ({now.hour}:00 IST). Non-critical broadcasts paused until 08:00 IST.")

    # 3. Scrape and aggregate live internet data
    logger.info("🌐 Fetching latest Mainboard IPO data from online sources...")
    try:
        aggregator = IpoAggregator()
        scraped_ipos = aggregator.collect_all_mainboard_ipos()
        logger.info(f"Aggregated {len(scraped_ipos)} Mainboard IPO records from web.")
    except Exception as e:
        logger.error(f"Error during scraping: {e}")
        scraped_ipos = []

    # 4. Merge scraped data into master
    new_ipos_count = 0
    updated_ipos_count = 0

    for item in scraped_ipos:
        ipo_id = item.get("id") or sanitize_slug(item.get("company_name", ""))
        if not ipo_id:
            continue

        if ipo_id not in master:
            master[ipo_id] = item
            master[ipo_id]["created_at"] = now.isoformat()
            master[ipo_id]["posted_events"] = []
            new_ipos_count += 1
            logger.info(f"🆕 Discovered new Mainboard IPO: {item.get('company_name')} (ID: {ipo_id})")
        else:
            # Update existing with latest GMP, dates, and prices
            existing = master[ipo_id]
            for key in ("open_date", "close_date", "allotment_date", "listing_date",
                        "price_band", "lot_size", "issue_size_cr", "gmp", "gmp_percent",
                        "est_listing_price", "listing_price", "listing_gain", "symbol"):
                val = item.get(key)
                if val:
                    existing[key] = val

            existing["last_updated"] = now.isoformat()
            updated_ipos_count += 1

    logger.info(f"Master state updated: {new_ipos_count} new, {updated_ipos_count} refreshed.")

    # Save merged state
    save_master(master)

    # Status check mode
    if STATUS_ONLY:
        print("\n" + "=" * 70)
        print("📋 TRACKED MAINBOARD IPOS STATUS REPORT")
        print("=" * 70)
        for idx, (k, ipo) in enumerate(master.items(), start=1):
            name = ipo.get("company_name", "Unknown")
            dates = f"{ipo.get('open_date') or 'TBA'} to {ipo.get('close_date') or 'TBA'}"
            price = ipo.get("price_band") or "TBA"
            gmp = ipo.get("gmp") or "None"
            print(f"{idx}. {name} | Dates: {dates} | Price: {price} | GMP: {gmp}")
        return 0

    # Summary mode: Broadcast daily GMP Dashboard
    if SUMMARY_ONLY:
        logger.info("Generating Mainboard IPO GMP Dashboard summary...")
        active_ipos = [
            ipo for ipo in master.values()
            if not ipo.get("is_already_listed")
        ]
        if not active_ipos:
            active_ipos = list(master.values())[:6]

        dashboard_text = format_gmp_dashboard(active_ipos, as_of_date=now.strftime("%d-%b-%Y"))
        success, msg = send_telegram_message(dashboard_text)
        if success:
            logger.info("✅ Mainboard IPO GMP Dashboard successfully sent to Telegram!")
            return 0
        else:
            logger.error(f"❌ Failed to send summary: {msg}")
            return 1

    # Force Event mode: Force trigger a specific event for testing/manual dispatch
    if FORCE_EVENT_ARG:
        try:
            f_idx = sys.argv.index("--force-event")
            f_ipo_id = sys.argv[f_idx + 1] if len(sys.argv) > f_idx + 1 else "ntpc-green-energy"
            f_event = sys.argv[f_idx + 2] if len(sys.argv) > f_idx + 2 else "NEW_IPO_ANNOUNCED"
        except Exception:
            f_ipo_id, f_event = "ntpc-green-energy", "NEW_IPO_ANNOUNCED"

        ipo_obj = master.get(f_ipo_id) or list(master.values())[0]
        logger.info(f"⚡ Force Event Trigger: {f_event} for {ipo_obj.get('company_name')}")
        msg_text = format_ipo_post(f_event, ipo_obj)
        if not msg_text:
            logger.error(f"Invalid event type: {f_event}")
            return 1
        success, msg = send_telegram_message(msg_text)
        if success:
            logger.info(f"✅ Force event [{f_event}] successfully sent!")
            return 0
        else:
            logger.error(f"❌ Force event failed: {msg}")
            return 1

    # 5. Evaluate Lifecycle Events
    pending_dispatches = []
    for ipo_id, ipo in master.items():
        events = evaluate_ipo_events(ipo, today_str, posted_set)
        for event_type, event_id in events:
            pending_dispatches.append((ipo, event_type, event_id))

    logger.info(f"🎯 Total pending lifecycle alerts to dispatch: {len(pending_dispatches)}")

    if not pending_dispatches:
        logger.info("ℹ️ No pending lifecycle events. Broadcasting live Mainboard IPO GMP Dashboard to channel...")
        active_ipos = [
            ipo for ipo in master.values()
            if not ipo.get("is_already_listed")
        ]
        if not active_ipos:
            active_ipos = list(master.values())[:6]

        dashboard_text = format_gmp_dashboard(active_ipos, as_of_date=now.strftime("%d-%b-%Y"))
        success, msg = send_telegram_message(dashboard_text)
        if success:
            logger.info(f"✅ Mainboard IPO GMP Dashboard broadcasted to {CHAT_ID}!")
            return 0
        else:
            logger.error(f"❌ Failed to broadcast dashboard: {msg}")
            return 1

    # 6. Dispatch Alerts
    dispatched_count = 0
    for ipo, event_type, event_id in pending_dispatches:
        comp_name = ipo.get("company_name", "Unknown")
        logger.info(f"📤 Preparing alert [{event_type}] for: {comp_name}...")

        message_html = format_ipo_post(event_type, ipo)
        if not message_html:
            logger.warning(f"⚠️ Could not format message for event {event_type}")
            continue

        if not is_posting_window(now) and not DRY_RUN:
            logger.info(f"🌙 Pausing dispatch of {event_id} due to quiet hours.")
            continue

        success, msg = send_telegram_message(message_html)
        if success:
            if not DRY_RUN:
                posted_log.append(event_id)
                posted_set.add(event_id)
                if "posted_events" not in ipo:
                    ipo["posted_events"] = []
                if event_type not in ipo["posted_events"]:
                    ipo["posted_events"].append(event_type)

            dispatched_count += 1
            logger.info(f"   ✅ Successfully broadcasted [{event_type}] for {comp_name}")
            time.sleep(3)  # Rate limit threshold safety for Telegram API
        else:
            logger.error(f"   ❌ Telegram delivery failed for {comp_name}: {msg}")

    # 7. Persist updated posted log and master
    if not DRY_RUN:
        save_posted_log(posted_log)
        save_master(master)

    logger.info("=" * 70)
    logger.info(f"🎉 RUN COMPLETE: {dispatched_count} alerts broadcasted to {CHAT_ID}")
    logger.info("=" * 70)

    return 0


# ============================================================
# ENTRY POINT
# ============================================================

if __name__ == "__main__":
    if TEST_POST_MODE:
        ok = test_telegram_connection(send_sample=True)
        sys.exit(0 if ok else 1)

    if TEST_MODE:
        ok = test_telegram_connection(send_sample=False)
        sys.exit(0 if ok else 1)

    exit_code = run_tracker()
    sys.exit(exit_code)
