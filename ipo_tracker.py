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
import re
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
    derive_demat_date,
    format_issue_size,
    CHANNEL_HANDLE,
)
from telegraph_publisher import TelegraphPublisher

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
    """Save tracked IPO master database and sync to Flutter asset directory."""
    try:
        # Sort by open_date or company_name
        items = list(master_dict.values())
        items.sort(key=lambda x: (x.get("open_date") or "9999-99-99", x.get("company_name") or ""), reverse=True)
        with open(MASTER_FILE, "w", encoding="utf-8") as f:
            json.dump(items, f, indent=2, ensure_ascii=False)
        logger.info(f"Saved {len(items)} IPO records to {MASTER_FILE}")

        # Also sync to Flutter asset bundle
        asset_master = os.path.join("assets", "data", "ipo_master.json")
        os.makedirs(os.path.dirname(asset_master), exist_ok=True)
        with open(asset_master, "w", encoding="utf-8") as f:
            json.dump(items, f, indent=2, ensure_ascii=False)
        logger.info(f"Synced {len(items)} IPO records to {asset_master}")
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


def is_active_mainboard_issue(ipo: dict, today_str: str) -> bool:
    """
    Check if an IPO is currently active or has a confirmed upcoming bidding schedule.
    Strictly excludes:
    - Already listed IPOs
    - Expired/closed IPOs (close_date < today_str)
    - Stale/draft filings with no confirmed bidding dates (open_date is None or 'TBA')
    """
    if is_already_listed(ipo, today_str):
        return False

    open_date = ipo.get("open_date")
    close_date = ipo.get("close_date")

    if not open_date or open_date == "TBA" or not isinstance(open_date, str):
        return False

    if not re.match(r"^\d{4}-\d{2}-\d{2}$", open_date):
        return False

    if close_date and close_date < today_str:
        return False

    if open_date > today_str:
        return True
    if close_date and open_date <= today_str <= close_date:
        return True
    if open_date == today_str:
        return True

    return False


def check_significant_gmp_movement(old_gmp: str | None, new_gmp: str | None) -> tuple[bool, str]:
    """
    Check if GMP movement is significant enough to warrant a dedicated breaking post.
    Thresholds:
      - Absolute change >= ₹8/share
      - OR Relative change >= 25% with at least ₹3 change
    """
    if not new_gmp or new_gmp in ("--", "0", ""):
        return False, ""
    if not old_gmp or old_gmp in ("--", "0", ""):
        return False, ""

    def parse_amt(val_str: str) -> float | None:
        m = re.search(r"[-+]?\d+(?:\.\d+)?", val_str.replace(",", ""))
        return float(m.group(0)) if m else None

    old_val = parse_amt(old_gmp)
    new_val = parse_amt(new_gmp)
    if old_val is None or new_val is None:
        return False, ""

    diff = new_val - old_val
    abs_diff = abs(diff)
    if abs_diff < 3.0:
        return False, ""

    is_significant = False
    if abs_diff >= 8.0:
        is_significant = True
    elif old_val > 0 and (abs_diff / old_val) >= 0.25:
        is_significant = True

    if not is_significant:
        return False, ""

    if old_val > 0:
        pct = (diff / old_val) * 100
        direction = "Surge 📈" if pct > 0 else "Drop 📉"
        pct_sign = "+" if pct > 0 else ""
        surge_text = f"({pct_sign}{pct:.1f}% {direction})"
    else:
        surge_text = "📈"

    return True, surge_text


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

    # 6. GMP_UPDATE (Significant GMP Movement Alert - Option 3)
    last_posted_gmp = ipo.get("last_posted_gmp")
    current_gmp = ipo.get("gmp")
    if current_gmp and is_active_mainboard_issue(ipo, today_str):
        if not last_posted_gmp:
            ipo["last_posted_gmp"] = current_gmp
        else:
            is_sig, surge_text = check_significant_gmp_movement(last_posted_gmp, current_gmp)
            if is_sig:
                gmp_event_id = f"ipo:{ipo_id}:gmp_update:{current_gmp}"
                if gmp_event_id not in posted_events_set:
                    ipo["surge_text"] = surge_text
                    events.append(("GMP_UPDATE", gmp_event_id))

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
            for key in ("open_date", "close_date", "allotment_date", "listing_date", "demat_credit_date",
                        "price_band", "lot_size", "issue_size_cr", "gmp", "gmp_percent",
                        "est_listing_price", "listing_price", "listing_gain", "symbol", "telegraph_url"):
                val = item.get(key)
                if val:
                    # Protect issue_size_cr from raw share counts (> 1,000,000 without Cr)
                    if key == "issue_size_cr" and existing.get("issue_size_cr"):
                        s_val = str(val).strip().replace(",", "")
                        if s_val.isdigit() and len(s_val) >= 7:
                            continue
                    existing[key] = val

            # Update live subscription from official exchange feed
            if item.get("subscription"):
                existing.setdefault("subscription", {}).update(item["subscription"])
            if item.get("demand_graph"):
                existing["demand_graph"] = item["demand_graph"]

            # Recalculate status based on current date
            open_d = existing.get("open_date")
            close_d = existing.get("close_date")
            if existing.get("is_already_listed") or existing.get("listing_price"):
                existing["status"] = "LISTED"
            elif open_d and close_d:
                if open_d <= today_str <= close_d:
                    existing["status"] = "OPEN"
                elif open_d > today_str:
                    existing["status"] = "UPCOMING"
                elif today_str > close_d:
                    existing["status"] = "CLOSED"
            elif open_d and open_d > today_str:
                existing["status"] = "UPCOMING"

            # Always populate demat_credit_date if not set
            if not existing.get("demat_credit_date"):
                derived = derive_demat_date(existing.get("allotment_date"), existing.get("listing_date"), existing.get("close_date"))
                if derived and derived != "Prior to Listing":
                    existing["demat_credit_date"] = derived

            existing["last_updated"] = now.isoformat()
            updated_ipos_count += 1

    logger.info(f"Master state updated: {new_ipos_count} new, {updated_ipos_count} refreshed.")

    # 4b. Ensure Telegraph DRHP analysis is published for active mainboard IPOs
    telegraph = TelegraphPublisher()
    telegraph_published = 0
    for ipo_id, item in master.items():
        if not item.get("telegraph_url") and is_active_mainboard_issue(item, today_str):
            try:
                tg_url = telegraph.publish_ipo_review(item)
                if tg_url:
                    item["telegraph_url"] = tg_url
                    telegraph_published += 1
                    logger.info(f"📝 Published Telegraph DRHP review for {item.get('company_name')}: {tg_url}")
            except Exception as e:
                logger.warning(f"⚠️ Telegraph publish failed for {item.get('company_name')}: {e}")

    if telegraph_published > 0:
        logger.info(f"Published {telegraph_published} new Telegraph DRHP articles.")

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
            if is_active_mainboard_issue(ipo, today_str)
        ]
        if not active_ipos:
            logger.info("ℹ️ No active Mainboard IPOs currently open or upcoming.")
            return 0

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
        active_ipos = [
            ipo for ipo in master.values()
            if is_active_mainboard_issue(ipo, today_str)
        ]
        if not active_ipos:
            logger.info("ℹ️ No active Mainboard IPOs currently open or upcoming. Skipping GMP dashboard broadcast.")
            return 0

        logger.info(f"ℹ️ Broadcasting live Mainboard IPO GMP Dashboard for {len(active_ipos)} active IPOs...")
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
                if event_type == "GMP_UPDATE":
                    ipo["last_posted_gmp"] = ipo.get("gmp")
                    ipo.pop("surge_text", None)
                elif not ipo.get("last_posted_gmp"):
                    ipo["last_posted_gmp"] = ipo.get("gmp")

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
