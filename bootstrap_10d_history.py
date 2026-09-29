import os
import json
import csv
import io
import requests
from datetime import datetime, timezone, timedelta

OUTPUT_HISTORY_FILE = "stock_history_20d.json"
IST = timezone(timedelta(hours=5, minutes=30))
NOW = datetime.now(IST)

def download_bhavcopy_for_date(target_date):
    trade_date_str = target_date.strftime("%d%m%Y")
    iso_date_str = target_date.strftime("%Y-%m-%d")
    url = f"https://nsearchives.nseindia.com/products/content/sec_bhavdata_full_{trade_date_str}.csv"
    
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
        "Accept": "*/*"
    }

    try:
        resp = requests.get(url, headers=headers, timeout=15)
        if resp.status_code == 200 and "SYMBOL" in resp.text:
            return resp.text, iso_date_str
    except Exception:
        pass
    return None, None

def save_compact_one_liner_json(data, filepath):
    lines = ["{"]
    symbols = sorted(data.keys())
    for s_idx, sym in enumerate(symbols):
        records = data[sym]
        records_str = ", ".join(json.dumps(r) for r in records)
        comma = "," if s_idx < len(symbols) - 1 else ""
        lines.append(f'  "{sym}": [{records_str}]{comma}')
    lines.append("}")
    
    with open(filepath, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))

def backfill_last_10_trading_days():
    print("=" * 75)
    print("⏳ FETCHING LAST 10 SESSIONS (STRICT EQ & HIGH-LIQUIDITY ONLY)...")
    print("=" * 75)

    valid_sessions = []
    for days_back in range(0, 25):
        target_date = NOW - timedelta(days=days_back)
        if target_date.weekday() in (5, 6):
            continue

        csv_text, iso_date = download_bhavcopy_for_date(target_date)
        if csv_text:
            print(f"  ✅ Session {len(valid_sessions) + 1}/10: {iso_date}")
            valid_sessions.append((iso_date, csv_text))
            if len(valid_sessions) == 10:
                break

    if len(valid_sessions) < 10:
        print(f"\n⚠️ Total {len(valid_sessions)} sessions available. Processing...")

    valid_sessions.reverse()
    history_data = {}

    print("\n⚙️ Filtering SME, Penny (<₹100) & Illiquid Counters...")

    for iso_date_str, csv_text in valid_sessions:
        reader = csv.DictReader(io.StringIO(csv_text))
        
        for row in reader:
            clean_row = {k.strip(): v.strip() for k, v in row.items() if k}
            symbol = clean_row.get("SYMBOL", "")
            series = clean_row.get("SERIES", "")

            # 1. STRICT SERIES FILTER: Sirf standard EQ allowed
            # Block SME ('SM', 'ST'), Trade-to-trade ('BE', 'BZ'), Index/Mutual funds ('GB', 'GS')
            if series != "EQ":
                continue

            # Block ETFs, Gold Bees, Liquid Bees
            if any(symbol.endswith(suffix) for suffix in ["BEES", "ETF", "NIFTY", "LIQUID"]):
                continue

            try:
                open_px = float(clean_row.get("OPEN_PRICE", 0.0))
                high_px = float(clean_row.get("HIGH_PRICE", 0.0))
                low_px = float(clean_row.get("LOW_PRICE", 0.0))
                close_px = float(clean_row.get("CLOSE_PRICE", 0.0))
                traded_qty = int(clean_row.get("TTL_TRD_QNTY", 0))
                deliv_pct = float(clean_row.get("DELIV_PER", 0.0))
                turnover_lacs = float(clean_row.get("TURNOVER_LACS", 0.0))
            except (ValueError, TypeError):
                continue

            # 2. LIQUIDITY & PRICE THRESHOLDS:
            # Price >= 100, Volume >= 50,000 shares, Turnover >= ₹50 Lakhs
            if close_px < 100.0 or traded_qty < 50000 or turnover_lacs < 50.0:
                continue

            record = [
                iso_date_str,
                round(open_px, 2),
                round(high_px, 2),
                round(low_px, 2),
                round(close_px, 2),
                traded_qty,
                round(deliv_pct, 2)
            ]

            if symbol not in history_data:
                history_data[symbol] = []

            history_data[symbol] = [e for e in history_data[symbol] if e[0] != iso_date_str]
            history_data[symbol].append(record)

    # Retain stocks that maintain liquidity across all 10 sessions
    final_history = {k: v[-10:] for k, v in history_data.items() if len(v) >= 10}

    save_compact_one_liner_json(final_history, OUTPUT_HISTORY_FILE)

    file_size_kb = os.path.getsize(OUTPUT_HISTORY_FILE) / 1024
    print("=" * 75)
    print(f"🎉 10-DAY CLEAN LIQUID DATA BUILT!")
    print(f"   • Qualified High-Liquid Stocks : {len(final_history)}")
    print(f"   • Output Destination           : '{OUTPUT_HISTORY_FILE}'")
    print(f"   • Database Size                : {file_size_kb:.1f} KB")
    print("=" * 75)

if __name__ == "__main__":
    backfill_last_10_trading_days()
