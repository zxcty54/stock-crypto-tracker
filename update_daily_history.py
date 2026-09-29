import os
import json
import csv
import io
import requests
from datetime import datetime, timezone, timedelta

HISTORY_FILE = "stock_history_20d.json"
IST = timezone(timedelta(hours=5, minutes=30))
NOW = datetime.now(IST)

def download_latest_bhavcopy():
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
        "Accept": "*/*"
    }

    # Aaj ya previous trading day ka bhavcopy check karein
    for days_back in range(0, 5):
        target_date = NOW - timedelta(days=days_back)
        if target_date.weekday() in (5, 6):
            continue

        trade_date_str = target_date.strftime("%d%m%Y")
        iso_date_str = target_date.strftime("%Y-%m-%d")
        url = f"https://nsearchives.nseindia.com/products/content/sec_bhavdata_full_{trade_date_str}.csv"
        
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

def update_rolling_history():
    csv_text, iso_date = download_latest_bhavcopy()
    if not csv_text:
        print("❌ Valid Bhavcopy nahi mili.")
        return

    if not os.path.exists(HISTORY_FILE):
        print(f"❌ {HISTORY_FILE} nahi mila. Pehle bootstrap script ek baar run karein.")
        return

    with open(HISTORY_FILE, "r", encoding="utf-8") as f:
        history_data = json.load(f)

    reader = csv.DictReader(io.StringIO(csv_text))
    updated_count = 0

    for row in reader:
        clean_row = {k.strip(): v.strip() for k, v in row.items() if k}
        symbol = clean_row.get("SYMBOL", "")
        series = clean_row.get("SERIES", "")

        # Strict Filters: Series EQ only, No ETFs
        if series != "EQ" or any(symbol.endswith(s) for s in ["BEES", "ETF", "NIFTY", "LIQUID"]):
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

        # Filters: Price >= 100, Volume >= 50k, Turnover >= 50L
        if close_px < 100.0 or traded_qty < 50000 or turnover_lacs < 50.0:
            continue

        new_record = [
            iso_date,
            round(open_px, 2),
            round(high_px, 2),
            round(low_px, 2),
            round(close_px, 2),
            traded_qty,
            round(deliv_pct, 2)
        ]

        if symbol not in history_data:
            history_data[symbol] = []

        # Duplicate check agar script do baar chal jaye
        history_data[symbol] = [r for r in history_data[symbol] if r[0] != iso_date]
        
        # 1. Naya din add hua
        history_data[symbol].append(new_record)

        # 2. Purana 11th din automatic delete (Strictly last 10 sessions retain)
        if len(history_data[symbol]) > 10:
            history_data[symbol] = history_data[symbol][-10:]
            
        updated_count += 1

    save_compact_one_liner_json(history_data, HISTORY_FILE)
    print(f"✅ History Updated for {iso_date}. Total Active Liquid Stocks: {updated_count}")

if __name__ == "__main__":
    update_rolling_history()
