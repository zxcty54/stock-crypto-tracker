import json
import os
from datetime import datetime

INPUT_FILE = "stock_history_20d.json"
OUTPUT_JSON_FILE = "scanner_output.json"
MAX_HISTORY_DAYS = 10  # Backtesting ke liye pichle 10 dino ka result store rahega

def scan_market():
    if not os.path.exists(INPUT_FILE):
        print(f"❌ Error: '{INPUT_FILE}' nahi mila.")
        return

    with open(INPUT_FILE, "r", encoding="utf-8") as f:
        try:
            history_data = json.load(f)
        except Exception as e:
            print(f"❌ JSON error: {e}")
            return

    triggers = []
    watchlist = []
    scan_date = None

    for symbol, records in sorted(history_data.items()):
        # Minimum 10 sessions required
        if len(records) < 10:
            continue

        # Schema: [0:date, 1:open, 2:high, 3:low, 4:close, 5:volume, 6:deliv_pct]
        last_10 = records[-10:]

        prev_base = last_10[4:9]
        today = last_10[9]

        today_date = today[0]
        today_close = today[4]
        today_volume = today[5]
        scan_date = today_date

        # 1. Base Metrics
        high_range = max(r[2] for r in prev_base)
        low_range = min(r[3] for r in prev_base)
        
        if low_range <= 0 or today_close <= 0:
            continue

        squeeze_pct = (high_range - low_range) / low_range
        avg_dry_vol = sum(r[5] for r in prev_base) / len(prev_base)
        vol_10_avg = sum(r[5] for r in last_10) / len(last_10)

        # 2. Delivery Check
        valid_deliveries = [r[6] for r in prev_base if r[6] is not None and r[6] > 0]
        delivery_ok = (sum(valid_deliveries) / len(valid_deliveries) >= 40.0) if valid_deliveries else True

        # 3. Triggers & Ratios
        vol_ratio = (today_volume / avg_dry_vol) if avg_dry_vol > 0 else 0
        price_breakout = today_close > high_range
        volume_blast = vol_ratio >= 2.0

        # LOGIC 1: BUY TRIGGER
        if squeeze_pct <= 0.10 and delivery_ok and price_breakout and volume_blast:
            triggers.append({
                "symbol": symbol,
                "close": round(today_close, 2),
                "volume_spike": f"{round(vol_ratio, 1)}x",
                "base_squeeze": f"{round(squeeze_pct * 100, 1)}%"
            })

        # LOGIC 2: WATCHLIST
        is_tight_squeeze = squeeze_pct <= 0.08
        is_volume_dry = today_volume < (0.80 * vol_10_avg)
        distance_to_res = (high_range - today_close) / today_close
        near_resistance = (distance_to_res <= 0.03) and not price_breakout

        if is_tight_squeeze and is_volume_dry and near_resistance and delivery_ok:
            watchlist.append({
                "symbol": symbol,
                "close": round(today_close, 2),
                "trigger_level": round(high_range, 2),
                "squeeze": f"{round(squeeze_pct * 100, 1)}%"
            })

    if not scan_date:
        print("⚠️ Koi data scan nahi ho paya.")
        return

    # --- 10-DAY ROLLING APPEND LOGIC ---
    existing_store = {}
    if os.path.exists(OUTPUT_JSON_FILE):
        try:
            with open(OUTPUT_JSON_FILE, "r", encoding="utf-8") as f:
                loaded = json.load(f)
                # Purani file se 'history' read karein agar maujood ho
                existing_store = loaded.get("history", {})
        except Exception:
            existing_store = {}

    # Aaj ka result specific date key ke andar update/append hoga
    existing_store[scan_date] = {
        "triggers_count": len(triggers),
        "watchlist_count": len(watchlist),
        "triggers": triggers,
        "watchlist": watchlist
    }

    # Sorted dates preserve karein aur strictly last 10 dates retain karein
    sorted_dates = sorted(existing_store.keys())
    if len(sorted_dates) > MAX_HISTORY_DAYS:
        dates_to_keep = sorted_dates[-MAX_HISTORY_DAYS:]
        existing_store = {d: existing_store[d] for d in dates_to_keep}
        sorted_dates = dates_to_keep

    latest_date = sorted_dates[-1]

    # Final Payload Structure:
    # 'latest' field Flutter app ke direct dashboard ke liye,
    # 'history' field backtesting aur pichle 10 dino ke records dekhne ke liye.
    final_payload = {
        "last_updated": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "tracked_dates": sorted_dates,
        "latest": {
            "date": latest_date,
            "triggers_count": existing_store[latest_date]["triggers_count"],
            "watchlist_count": existing_store[latest_date]["watchlist_count"],
            "triggers": existing_store[latest_date]["triggers"],
            "watchlist": existing_store[latest_date]["watchlist"]
        },
        "history": existing_store
    }

    with open(OUTPUT_JSON_FILE, "w", encoding="utf-8") as out_f:
        json.dump(final_payload, out_f, indent=2, ensure_ascii=False)

    print("=" * 75)
    print(f"📊 Strategy Scan Completed for: {scan_date}")
    print(f"🔥 Today's Triggers : {len(triggers)}")
    print(f"👀 Today's Watchlist: {len(watchlist)}")
    print(f"🗓️ History Preserved: {len(sorted_dates)} Days ({sorted_dates[0]} to {sorted_dates[-1]})")
    print(f"📁 Saved to         : '{OUTPUT_JSON_FILE}'")
    print("=" * 75)

if __name__ == "__main__":
    scan_market()
