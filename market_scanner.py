import json
import os
import requests
from datetime import datetime

LOCAL_INPUT_FILE = "historical_5yr_ohlc.json"
RAW_GITHUB_URL = "https://raw.githubusercontent.com/zxcty54/stock-crypto-tracker/main/historical_5yr_ohlc.json"
OUTPUT_JSON_FILE = "breakout_signals.json"
COOLDOWN_DAYS = 10  # Ek entry ke baad agle 10 sessions tak duplicate signal avoid karega

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
    if os.path.exists(LOCAL_INPUT_FILE):
        print(f"📂 Loading data from local file: '{LOCAL_INPUT_FILE}'...")
        try:
            with open(LOCAL_INPUT_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception as e:
            print(f"❌ Local file parse error: {e}")

    print(f"🌐 Fetching directly from GitHub raw URL...")
    try:
        res = requests.get(RAW_GITHUB_URL, timeout=30)
        if res.status_code == 200:
            return res.json()
        else:
            print(f"❌ GitHub fetch failed with HTTP {res.status_code}")
    except Exception as e:
        print(f"❌ Exception fetching from GitHub: {e}")

    return None

def scan_full_history():
    history_data = load_historical_data()
    if not history_data:
        print("❌ Error: Stock historical data load nahi ho saka.")
        return

    company_signals = {}
    all_triggered_events = []
    total_companies = len(history_data)

    print(f"\n🚀 Scanning full 5-year timeline for {total_companies} companies...")
    print("=" * 80)

    for symbol, raw_records in sorted(history_data.items()):
        if not raw_records or len(raw_records) < 51:
            print(f"⚠️ {symbol}: 50DMA ke liye data kam hai ({len(raw_records)} records), skipping.")
            continue

        # Chronological sort: sabse purani date index 0 par, sabse nayi aakhri mein
        sorted_records = sorted(raw_records, key=lambda x: parse_date(x[0]))
        total_records = len(sorted_records)

        symbol_triggers = []
        last_triggered_idx = -999  # 10-day cooldown track karne ke liye

        # Index 50 se lekar aakhri session tak har din check karega (Rolling 50DMA Window)
        for idx in range(50, total_records):
            # Agar pichhle 10 sessions ke andar trigger hua tha toh skip karein (No Repeat Filter)
            if (idx - last_triggered_idx) <= COOLDOWN_DAYS:
                continue

            curr_day = sorted_records[idx]
            prev_day = sorted_records[idx - 1]

            entry_date = curr_day[0]
            entry_close = float(curr_day[4])
            prev_close = float(prev_day[4])
            curr_volume = float(curr_day[5])

            if prev_close <= 0 or entry_close <= 0:
                continue

            # Data Slices up to current index
            # 1. Closes up to today
            closes_up_to_today = [float(r[4]) for r in sorted_records[:idx + 1]]
            
            # 2. Last 20 trading sessions prior to today (for 20D high & 20D avg volume)
            last_20_records = sorted_records[idx - 20:idx]
            
            # 3. Last 20 closes including today (for 20DMA)
            last_20_closes = closes_up_to_today[-20:]
            
            # 4. Last 50 closes including today (for 50DMA)
            last_50_closes = closes_up_to_today[-50:]

            # ---------------- 6 CONDITIONS CHECK ----------------
            
            # 1. Day Move >= +3%
            day_move_pct = ((entry_close - prev_close) / prev_close) * 100
            cond_1 = day_move_pct >= 3.0

            # 2. Volume >= 3x (Pichle 20 din ke average volume ka 3 guna)
            avg_vol_20d = sum(float(r[5]) for r in last_20_records) / 20.0
            vol_ratio = (curr_volume / avg_vol_20d) if avg_vol_20d > 0 else 0.0
            cond_2 = curr_volume >= (3.0 * avg_vol_20d)

            # 3. Close >= 20DMA + 3%
            dma_20 = sum(last_20_closes) / 20.0
            cond_3 = entry_close >= (dma_20 * 1.03)

            # 4. RSI(14) > 50
            rsi_14 = calculate_rsi(closes_up_to_today, 14)
            cond_4 = rsi_14 > 50.0

            # 5. 20-Day High Breakout (Close pichhle 20 din ke High ke upar)
            high_20d = max(float(r[2]) for r in last_20_records)
            cond_5 = entry_close > high_20d

            # 6. Trend Filter (Close > 50DMA)
            dma_50 = sum(last_50_closes) / 50.0
            cond_6 = entry_close > dma_50

            # Sabhi 6 conditions match hone par Trigger banega
            if cond_1 and cond_2 and cond_3 and cond_4 and cond_5 and cond_6:
                trigger_item = {
                    "symbol": symbol,
                    "entry_date": entry_date,
                    "entry_price": round(entry_close, 2),
                    "day_move": f"+{round(day_move_pct, 1)}%",
                    "volume_ratio": f"{round(vol_ratio, 1)}x",
                    "rsi_14": round(rsi_14, 1),
                    "dma_20": round(dma_20, 2),
                    "dma_50": round(dma_50, 2),
                    "breakout_high_20d": round(high_20d, 2)
                }

                symbol_triggers.append(trigger_item)
                all_triggered_events.append(trigger_item)
                last_triggered_idx = idx  # Cooldown lock lagao

        # Stock summary
        company_signals[symbol] = {
            "total_5yr_triggers": len(symbol_triggers),
            "latest_trigger": symbol_triggers[-1] if symbol_triggers else None,
            "all_historical_triggers": symbol_triggers
        }

        latest_info = f"Latest on {symbol_triggers[-1]['entry_date']} @ ₹{symbol_triggers[-1]['entry_price']}" if symbol_triggers else "No triggers in 5 years"
        print(f"📊 {symbol:<12} | Found {len(symbol_triggers):>2} triggers | {latest_info}")

    # Chronologically sort all signals across all companies (Latest first)
    all_triggered_events.sort(key=lambda x: parse_date(x["entry_date"]), reverse=True)

    final_payload = {
        "metadata": {
            "generated_at": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "total_companies_scanned": total_companies,
            "total_signals_found": len(all_triggered_events),
            "cooldown_period_days": COOLDOWN_DAYS
        },
        "latest_signals": all_triggered_events[:20],  # UI Dashboard ke liye Top 20 latest entries
        "all_signals_chronological": all_triggered_events,
        "companies": company_signals
    }

    with open(OUTPUT_JSON_FILE, "w", encoding="utf-8") as out_f:
        json.dump(final_payload, out_f, indent=2, ensure_ascii=False)

    print("=" * 80)
    print(f"🎉 5-Year Scan Completed!")
    print(f"🔥 Total Breakout Signals Found Across All Stocks: {len(all_triggered_events)}")
    print(f"📁 Output Saved: '{OUTPUT_JSON_FILE}'")
    print("=" * 80)

if __name__ == "__main__":
    scan_full_history()
