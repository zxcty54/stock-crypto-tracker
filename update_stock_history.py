import os
import json
import csv
import io
import requests
from datetime import datetime, timezone, timedelta

OUTPUT_HISTORY_FILE = "stock_history_20d.json"
IST = timezone(timedelta(hours=5, minutes=30))
NOW = datetime.now(IST)

def download_latest_available_bhavcopy():
    """
    Downloads latest available NSE bhavcopy.
    Falls back up to 5 days to handle weekends, holidays, and late-night runs.
    """
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
        "Accept": "*/*"
    }

    for days_back in range(0, 5):
        target_date = NOW - timedelta(days=days_back)
        if target_date.weekday() in (5, 6):  # Skip Saturday & Sunday
            continue

        trade_date_str = target_date.strftime("%d%m%Y")
        iso_date_str = target_date.strftime("%Y-%m-%d")
        url = f"https://nsearchives.nseindia.com/products/content/sec_bhavdata_full_{trade_date_str}.csv"
        
        print(f"🔍 Checking Bhavcopy for: {trade_date_str} ({iso_date_str})...")
        try:
            resp = requests.get(url, headers=headers, timeout=15)
            if resp.status_code == 200 and "SYMBOL" in resp.text:
                print(f"✅ Found and downloaded Bhavcopy for: {trade_date_str}")
                return resp.text, iso_date_str
            elif resp.status_code == 404:
                print(f"   ℹ️ Not available for {trade_date_str} (HTTP 404). Trying previous day...")
        except Exception as e:
            print(f"   ⚠️ Network error for {trade_date_str}: {e}")

    return None, None

def save_compact_one_liner_json(data, filepath):
    """
    Saves JSON where each stock's full history is locked into a single clean line.
    Drastically compresses vertical lines from 17,000+ to ~1,000.
    """
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

def fetch_and_update_history():
    print("=" * 80)
    print("📊 NSE ROLLING 20-DAY HISTORY (EQ, Price >= ₹100, Liquid Counters Only)")
    print(f"📅 Timestamp: {NOW.strftime('%d-%b-%Y %H:%M:%S IST')}")
    print("=" * 80)

    csv_text, iso_date_str = download_latest_available_bhavcopy()
    if not csv_text:
        print("❌ Could not locate any valid Bhavcopy in the last 5 days. Exiting.")
        return

    history_data = {}
    if os.path.exists(OUTPUT_HISTORY_FILE):
        try:
            with open(OUTPUT_HISTORY_FILE, "r", encoding="utf-8") as f:
                history_data = json.load(f)
                if not isinstance(history_data, dict):
                    history_data = {}
        except Exception:
            history_data = {}

    reader = csv.DictReader(io.StringIO(csv_text))
    qualifying_count = 0

    for row in reader:
        clean_row = {k.strip(): v.strip() for k, v in row.items() if k}
        symbol = clean_row.get("SYMBOL", "")
        series = clean_row.get("SERIES", "")

        # 1. Strict Filter: Series EQ Only (No Bonds, SGBs, Warrants, SME)
        if series != "EQ":
            continue

        # 2. Strict Filter: Block ETFs
        if symbol.endswith("BEES") or symbol.endswith("ETF"):
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

        # 3. Price Filter: Minimum ₹100
        if close_px < 100.0:
            continue

        # 4. Strict Liquidity Filter: Minimum 10,000 shares traded AND ₹25 Lakhs turnover
        # (Filters out dead, illiquid and operator manipulated counters)
        if traded_qty < 10000 or turnover_lacs < 25.0:
            continue

        qualifying_count += 1

        # Format: [date, open, high, low, close, volume, deliv_pct]
        day_tuple = [
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

        # Deduplicate same-day entries on re-runs
        history_data[symbol] = [e for e in history_data[symbol] if e[0] != iso_date_str]
        history_data[symbol].append(day_tuple)

        # 5. Retain Strictly Last 20 Active Sessions
        if len(history_data[symbol]) > 20:
            history_data[symbol] = history_data[symbol][-20:]

    # Save compact one-liner structure
    save_compact_one_liner_json(history_data, OUTPUT_HISTORY_FILE)

    file_size_kb = os.path.getsize(OUTPUT_HISTORY_FILE) / 1024
    with open(OUTPUT_HISTORY_FILE, "r", encoding="utf-8") as f:
        total_lines = len(f.readlines())

    print("\n" + "=" * 80)
    print(f"✅ SUCCESS:")
    print(f"   • Captured Trade Date        : {iso_date_str}")
    print(f"   • Qualified Liquid Stocks    : {qualifying_count}")
    print(f"   • Total Active Tickers       : {len(history_data)}")
    print(f"   • Total JSON Lines           : {total_lines} lines")
    print(f"   • Output File Size           : {file_size_kb:.1f} KB")
    print(f"   • Saved to                   : '{OUTPUT_HISTORY_FILE}'")
    print("=" * 80)

if __name__ == "__main__":
    fetch_and_update_history()
