import json
import os
import requests
from datetime import datetime

# GitHub repo ke root mein file ka naam
LOCAL_INPUT_FILE = "historical_5yr_ohlc.json"

# Agar local file na mile toh seedhe GitHub raw se uthayega
RAW_GITHUB_URL = "https://raw.githubusercontent.com/zxcty54/stock-crypto-tracker/main/historical_5yr_ohlc.json"

OUTPUT_JSON_FILE = "scanner_output.json"
MAX_HISTORY_DAYS = 10                   # 10 rolling trading days dashboard ke liye

def calculate_rsi(closes, period=14):
    """Standard 14-period Wilder/SMA RSI calculation"""
    if len(closes) < period + 1:
        return 0.0
    
    gains = []
    losses = []
    for i in range(1, len(closes)):
        diff = closes[i] - closes[i - 1]
        if diff >= 0:
            gains.append(diff)
            losses.append(0.0)
        else:
            gains.append(0.0)
            losses.append(abs(diff))
            
    recent_gains = gains[-period:]
    recent_losses = losses[-period:]
    
    avg_gain = sum(recent_gains) / period
    avg_loss = sum(recent_losses) / period
    
    if avg_loss == 0:
        return 100.0
    rs = avg_gain / avg_loss
    return 100.0 - (100.0 / (1.0 + rs))

def parse_date(date_str):
    for fmt in ("%Y-%m-%d", "%d-%b-%Y", "%d-%m-%Y"):
        try:
            return datetime.strptime(date_str, fmt)
        except ValueError:
            continue
    return datetime.min

def load_historical_data():
    # 1. Check local directory first (Fastest for GitHub Actions)
    if os.path.exists(LOCAL_INPUT_FILE):
        print(f"📂 Loading data from local file: '{LOCAL_INPUT_FILE}'...")
        try:
            with open(LOCAL_INPUT_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception as e:
            print(f"❌ Local file parse error: {e}")

    # 2. Fallback to GitHub Raw URL
    print(f"🌐 Local file nahi mili, fetching directly from GitHub raw URL...")
    try:
        res = requests.get(RAW_GITHUB_URL, timeout=30)
        if res.status_code == 200:
            return res.json()
        else:
            print(f"❌ GitHub fetch failed with HTTP {res.status_code}")
    except Exception as e:
        print(f"❌ Exception fetching from GitHub: {e}")

    return None

def scan_market():
    history_data = load_historical_data()
    if not history_data:
        print("❌ Error: Stock historical data load nahi ho saka.")
        return

    triggers = []
    scan_date = None
    scanned_count = 0

    for symbol, raw_records in sorted(history_data.items()):
        # 50DMA aur 20-Day High ke liye minimum 51 records zaroori hain
        if not raw_records or len(raw_records) < 51:
            continue

        scanned_count += 1

        # Date Sorting Safety: Purana pehle, latest aakhri mein
        sorted_records = sorted(raw_records, key=lambda x: parse_date(x[0]))

        # Aakhri 60 sessions slice kar rahe hain (Speed & Accuracy)
        records = sorted_records[-60:]

        today = records[-1]          # Sabse Latest Session (Current Scan Date)
        prev_day = records[-2]       # Kal ka Session

        today_date = today[0]
        today_close = float(today[4])
        prev_close = float(prev_day[4])
        today_volume = float(today[5])
        scan_date = today_date

        if prev_close <= 0 or today_close <= 0:
            continue

        # Data Slices for Indicators
        all_closes = [float(r[4]) for r in records]
        last_20_records = records[-21:-1]   # Pichhle 20 trading sessions (today ko chhod kar)
        last_20_closes = all_closes[-20:]   # Today ko milakar 20 sessions (20DMA)
        last_50_closes = all_closes[-50:]   # Today ko milakar 50 sessions (50DMA)

        # ---------------- 6 CONDITIONS CALCULATION ----------------
        
        # 1. Day Move >= +3%
        day_move_pct = ((today_close - prev_close) / prev_close) * 100
        cond_1 = day_move_pct >= 3.0

        # 2. Volume >= 3x (Pichle 20 sessions ke average volume ka 3 guna)
        avg_vol_20d = sum(float(r[5]) for r in last_20_records) / 20.0
        vol_ratio = (today_volume / avg_vol_20d) if avg_vol_20d > 0 else 0.0
        cond_2 = today_volume >= (3.0 * avg_vol_20d)

        # 3. Close >= 20DMA + 3%
        dma_20 = sum(last_20_closes) / 20.0
        cond_3 = today_close >= (dma_20 * 1.03)

        # 4. RSI(14) > 50
        rsi_14 = calculate_rsi(all_closes, 14)
        cond_4 = rsi_14 > 50.0

        # 5. 20-Day High Breakout (Close pichhle 20 sessions ke highest high se upar)
        high_20d = max(float(r[2]) for r in last_20_records)
        cond_5 = today_close > high_20d

        # 6. Primary Trend Filter (Close > 50DMA)
        dma_50 = sum(last_50_closes) / 50.0
        cond_6 = today_close > dma_50

        # Sabhi 6 conditions ek sath TRUE honi chahiye
        if cond_1 and cond_2 and cond_3 and cond_4 and cond_5 and cond_6:
            triggers.append({
                "symbol": symbol,
                "close": round(today_close, 2),
                "day_move": f"+{round(day_move_pct, 1)}%",
                "volume_ratio": f"{round(vol_ratio, 1)}x",
                "dma_20": round(dma_20, 2),
                "dma_50": round(dma_50, 2),
                "rsi_14": round(rsi_14, 1),
                "high_20d": round(high_20d, 2)
            })

    if not scan_date:
        print("⚠️ Koi valid trading data scan nahi ho saka.")
        return

    # ---------------- 10-DAY REPEAT FILTER & ROLLING STORAGE ----------------
    existing_store = {}
    if os.path.exists(OUTPUT_JSON_FILE):
        try:
            with open(OUTPUT_JSON_FILE, "r", encoding="utf-8") as f:
                existing_store = json.load(f).get("history", {})
        except Exception:
            existing_store = {}

    # Pichle 10 dates ke symbols extract karein
    past_dates_sorted = sorted(existing_store.keys(), key=parse_date)
    recent_10_dates = past_dates_sorted[-10:] if len(past_dates_sorted) >= 10 else past_dates_sorted
    
    recent_triggered_symbols = set()
    for d in recent_10_dates:
        for item in existing_store[d].get("triggers", []):
            recent_triggered_symbols.add(item["symbol"])

    # Repeat Filter Apply
    filtered_triggers = [t for t in triggers if t["symbol"] not in recent_triggered_symbols]

    # Save current date's scan
    existing_store[scan_date] = {
        "triggers_count": len(filtered_triggers),
        "triggers": filtered_triggers
    }

    # Strictly last 10 trading dates maintain karna
    all_dates = sorted(existing_store.keys(), key=parse_date)
    if len(all_dates) > MAX_HISTORY_DAYS:
        keep = all_dates[-MAX_HISTORY_DAYS:]
        existing_store = {d: existing_store[d] for d in keep}
        all_dates = keep

    latest_date = all_dates[-1]

    final_payload = {
        "last_updated": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "total_scanned_stocks": scanned_count,
        "tracked_dates": all_dates,
        "latest": {
            "date": latest_date,
            "triggers_count": existing_store[latest_date]["triggers_count"],
            "triggers": existing_store[latest_date]["triggers"]
        },
        "history": existing_store
    }

    with open(OUTPUT_JSON_FILE, "w", encoding="utf-8") as out_f:
        json.dump(final_payload, out_f, indent=2, ensure_ascii=False)

    print("=" * 80)
    print(f"📊 6-Conditions Scan Completed for Date: {scan_date}")
    print(f"📈 Total Stocks Evaluated: {scanned_count}")
    print(f"🔥 Qualified Triggers (Repeat Filter Passed): {len(filtered_triggers)}")
    print(f"📁 Output Saved: '{OUTPUT_JSON_FILE}'")
    print("=" * 80)
    for t in filtered_triggers:
        print(f"Stock: {t['symbol']:<12} | Close: ₹{t['close']:<8} | Move: {t['day_move']} | Vol: {t['volume_ratio']} | RSI: {t['rsi_14']}")

if __name__ == "__main__":
    scan_market()
