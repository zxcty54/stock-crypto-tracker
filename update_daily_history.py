import os
import json
import csv
import io
from datetime import datetime, timezone, timedelta

try:
    import requests
except ImportError:
    import urllib.request as urllib_req
    requests = None

HISTORY_FILE = "stock_history_20d.json"
MARKET_MOVERS_FILE = "market_movers.json"
ASSET_MOVERS_FILE = "assets/data/market_movers.json"

IST = timezone(timedelta(hours=5, minutes=30))
NOW = datetime.now(IST)

def download_latest_bhavcopy():
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
        "Accept": "*/*"
    }

    # Check today and up to 5 previous trading days for latest Bhavcopy
    for days_back in range(0, 5):
        target_date = NOW - timedelta(days=days_back)
        if target_date.weekday() in (5, 6):
            continue

        trade_date_str = target_date.strftime("%d%m%Y")
        iso_date_str = target_date.strftime("%Y-%m-%d")
        url = f"https://nsearchives.nseindia.com/products/content/sec_bhavdata_full_{trade_date_str}.csv"

        try:
            if requests:
                resp = requests.get(url, headers=headers, timeout=15)
                if resp.status_code == 200 and "SYMBOL" in resp.text:
                    return resp.text, iso_date_str
            else:
                req = urllib_req.Request(url, headers=headers)
                with urllib_req.urlopen(req, timeout=15) as r:
                    content = r.read().decode('utf-8', errors='ignore')
                    if "SYMBOL" in content:
                        return content, iso_date_str
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

def generate_market_movers_report(history_data):
    """Computes Weekly (5D), Monthly (20D), and High Delivery gainers/losers."""
    now_str = datetime.now(IST).strftime('%Y-%m-%d %I:%M %p IST')
    weekly_items = []
    monthly_items = []

    for sym, records in history_data.items():
        if not records or len(records) < 2:
            continue

        cmp = records[-1][4]
        vol = records[-1][5]
        deliv = records[-1][6]

        # 1-Week (5 trading sessions back)
        if len(records) >= 5:
            p_5d = records[-5][4]
            if p_5d > 0:
                chg_5d = round(((cmp - p_5d) / p_5d) * 100, 2)
                weekly_items.append({
                    'symbol': sym,
                    'cmp': cmp,
                    'ref_price': p_5d,
                    'change_pct': chg_5d,
                    'volume': vol,
                    'delivery_pct': deliv,
                    'period': '1-Week (5 Sessions)'
                })

        # Monthly (earliest recorded session in window, up to 22)
        p_month = records[0][4]
        days_span = len(records)
        if p_month > 0:
            chg_month = round(((cmp - p_month) / p_month) * 100, 2)
            monthly_items.append({
                'symbol': sym,
                'cmp': cmp,
                'ref_price': p_month,
                'change_pct': chg_month,
                'volume': vol,
                'delivery_pct': deliv,
                'days_tracked': days_span,
                'period': f'{days_span}-Session Month'
            })

    weekly_gainers = sorted([x for x in weekly_items if x['change_pct'] > 0], key=lambda x: x['change_pct'], reverse=True)[:35]
    weekly_losers = sorted([x for x in weekly_items if x['change_pct'] < 0], key=lambda x: x['change_pct'])[:35]

    monthly_gainers = sorted([x for x in monthly_items if x['change_pct'] > 0], key=lambda x: x['change_pct'], reverse=True)[:35]
    monthly_losers = sorted([x for x in monthly_items if x['change_pct'] < 0], key=lambda x: x['change_pct'])[:35]

    high_delivery_gainers = sorted([x for x in weekly_items if x['delivery_pct'] >= 50.0 and x['change_pct'] > 3.0], key=lambda x: x['change_pct'], reverse=True)[:30]

    report = {
        'last_updated': now_str,
        'total_stocks_screened': len(history_data),
        'weekly_gainers': weekly_gainers,
        'weekly_losers': weekly_losers,
        'monthly_gainers': monthly_gainers,
        'monthly_losers': monthly_losers,
        'high_delivery_accumulators': high_delivery_gainers
    }

    with open(MARKET_MOVERS_FILE, 'w', encoding='utf-8') as f:
        json.dump(report, f, indent=2)

    os.makedirs('assets/data', exist_ok=True)
    with open(ASSET_MOVERS_FILE, 'w', encoding='utf-8') as f:
        json.dump(report, f, indent=2)

    print(f"📊 Market Movers Generated: {len(weekly_gainers)} Weekly Gainers, {len(monthly_gainers)} Monthly Gainers.")

def update_rolling_history():
    if not os.path.exists(HISTORY_FILE):
        print(f"❌ {HISTORY_FILE} nahi mila.")
        return

    with open(HISTORY_FILE, "r", encoding="utf-8") as f:
        history_data = json.load(f)

    csv_text, iso_date = download_latest_bhavcopy()
    if csv_text:
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

            # 2. Retain up to 22 trading sessions (1 full calendar month)
            if len(history_data[symbol]) > 22:
                history_data[symbol] = history_data[symbol][-22:]

            updated_count += 1

        save_compact_one_liner_json(history_data, HISTORY_FILE)
        print(f"✅ History Updated for {iso_date}. Total Active Liquid Stocks: {updated_count}")
    else:
        print("ℹ️ Bhavcopy online nahi mili (offline/weekend). Existing history used.")

    # Always recompute market movers
    generate_market_movers_report(history_data)

if __name__ == "__main__":
    update_rolling_history()
