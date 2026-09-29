import os
import json
import time
from datetime import datetime
import requests

OUTPUT_FILE = "historical_3yr_ohlc.json"

# Jin stocks par aapko backtesting karni hai
SYMBOLS = [
    "RELIANCE", "TCS", "INFY", "HDFCBANK", "ICICIBANK",
    "TATAMOTORS", "SBIN", "BHARTIARTL", "ITC", "LT"
]

def fetch_3year_ohlc():
    master_store = {}
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
    }

    print("=" * 70)
    print("⏳ Downloading 3-Year Historical OHLCV Data...")
    print("=" * 70)

    for symbol in SYMBOLS:
        ticker = f"{symbol}.NS"
        url = f"https://query1.finance.yahoo.com/v8/finance/chart/{ticker}?range=3y&interval=1d"

        try:
            res = requests.get(url, headers=headers, timeout=10)
            if res.status_code != 200:
                print(f"⚠️ Failed for {symbol} (HTTP {res.status_code})")
                continue

            data = res.json()
            result = data.get("chart", {}).get("result", [])[0]
            
            timestamps = result.get("timestamp", [])
            indicators = result.get("indicators", {}).get("quote", [])[0]

            opens = indicators.get("open", [])
            highs = indicators.get("high", [])
            lows = indicators.get("low", [])
            closes = indicators.get("close", [])
            volumes = indicators.get("volume", [])

            stock_candles = []
            for i in range(len(timestamps)):
                # Null values ko filter karein
                if None in (opens[i], highs[i], lows[i], closes[i]):
                    continue

                date_str = datetime.fromtimestamp(timestamps[i]).strftime("%Y-%m-%d")
                stock_candles.append([
                    date_str,
                    round(opens[i], 2),
                    round(highs[i], 2),
                    round(lows[i], 2),
                    round(closes[i], 2),
                    int(volumes[i] or 0)
                ])

            master_store[symbol] = stock_candles
            print(f"✅ {symbol}: {len(stock_candles)} trading days loaded (~3 years)")
            time.sleep(0.5)

        except Exception as e:
            print(f"❌ Error loading {symbol}: {e}")

    # Save to local file
    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(master_store, f, ensure_ascii=False)

    print("=" * 70)
    print(f"🎉 Saved complete 3-year historical dataset to '{OUTPUT_FILE}'")
    print(f"📦 Total Stocks Saved: {len(master_store)}")
    print("=" * 70)

if __name__ == "__main__":
    fetch_3year_ohlc()
