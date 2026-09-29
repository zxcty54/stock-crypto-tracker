import json
import os
from datetime import datetime

INPUT_FILE = "stock_history_20d.json"
OUTPUT_JSON_FILE = "scanner_output.json"

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

    for symbol, records in sorted(history_data.items()):
        # Minimum 10 sessions required
        if len(records) < 10:
            continue

        # Schema: [0:date, 1:open, 2:high, 3:low, 4:close, 5:volume, 6:deliv_pct]
        last_10 = records[-10:]

        # Pichle 5 din ka base (Rows 4 to 8, index 4:9) aur Aaj ka din (Row 9, index 9)
        prev_base = last_10[4:9]
        today = last_10[9]

        today_date = today[0]
        today_close = today[4]
        today_volume = today[5]

        # 1. Base Metrics
        high_range = max(r[2] for r in prev_base)
        low_range = min(r[3] for r in prev_base)
        
        if low_range <= 0 or today_close <= 0:
            continue

        squeeze_pct = (high_range - low_range) / low_range
        avg_dry_vol = sum(r[5] for r in prev_base) / len(prev_base)
        vol_10_avg = sum(r[5] for r in last_10) / len(last_10)

        # 2. Delivery Check (NaN / 0 check handling)
        valid_deliveries = [r[6] for r in prev_base if r[6] is not None and r[6] > 0]
        delivery_ok = (sum(valid_deliveries) / len(valid_deliveries) >= 40.0) if valid_deliveries else True

        # 3. Triggers & Ratios
        vol_ratio = (today_volume / avg_dry_vol) if avg_dry_vol > 0 else 0
        price_breakout = today_close > high_range
        volume_blast = vol_ratio >= 2.0

        # ---------------- LOGIC 1: BUY TRIGGER (Rally Start) ----------------
        if squeeze_pct <= 0.10 and delivery_ok and price_breakout and volume_blast:
            triggers.append({
                "Symbol": symbol,
                "Date": today_date,
                "Close": round(today_close, 2),
                "Volume Spike": f"{round(vol_ratio, 1)}x",
                "Base Squeeze": f"{round(squeeze_pct * 100, 1)}%"
            })

        # ---------------- LOGIC 2: WATCHLIST (Pre-Breakout Coiling) ----------------
        is_tight_squeeze = squeeze_pct <= 0.08
        is_volume_dry = today_volume < (0.80 * vol_10_avg)
        
        # Near resistance: resistance se 3% ke andar ho aur breakout abhi na hua ho
        distance_to_res = (high_range - today_close) / today_close
        near_resistance = (distance_to_res <= 0.03) and not price_breakout

        if is_tight_squeeze and is_volume_dry and near_resistance and delivery_ok:
            watchlist.append({
                "Symbol": symbol,
                "Date": today_date,
                "Close": round(today_close, 2),
                "Trigger Level": round(high_range, 2),
                "Squeeze": f"{round(squeeze_pct * 100, 1)}%"
            })

    # Save structured output for Flutter App API
    app_payload = {
        "scan_time": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "triggers_count": len(triggers),
        "watchlist_count": len(watchlist),
        "triggers": triggers,
        "watchlist": watchlist
    }

    with open(OUTPUT_JSON_FILE, "w", encoding="utf-8") as out_f:
        json.dump(app_payload, out_f, indent=2, ensure_ascii=False)

    # Clean Console Output exactly matching your pandas layout
    print("=" * 75)
    print("🔥 CONFIRMED BUY TRIGGERS (Actionable Entry - 50%+ Setup)")
    print("=" * 75)
    if triggers:
        print(f"{'Symbol':<12} | {'Date':<12} | {'Close':<10} | {'Volume Spike':<14} | {'Base Squeeze':<12}")
        print("-" * 75)
        for t in triggers:
            print(f"{t['Symbol']:<12} | {t['Date']:<12} | ₹{t['Close']:<9} | {t['Volume Spike']:<14} | {t['Base Squeeze']:<12}")
    else:
        print("No stock triggered today.")

    print("\n" + "=" * 75)
    print("👀 WATCHLIST ALERTS (Range Squeezed + Volume Dry - Ready to Blast)")
    print("=" * 75)
    if watchlist:
        print(f"{'Symbol':<12} | {'Date':<12} | {'Close':<10} | {'Trigger Level':<14} | {'Squeeze':<10}")
        print("-" * 75)
        for w in watchlist:
            print(f"{w['Symbol']:<12} | {w['Date']:<12} | ₹{w['Close']:<9} | ₹{w['Trigger Level']:<13} | {w['Squeeze']:<10}")
    else:
        print("No stock coiling right now.")
    print("=" * 75)

if __name__ == "__main__":
    scan_market()
