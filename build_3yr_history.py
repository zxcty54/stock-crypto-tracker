import os
import json
import time
import base64
from datetime import datetime
import requests

OUTPUT_FILE = "historical_5yr_ohlc.json"

TARGET_REPO = "zxcty54/stock-crypto-tracker"
TARGET_FILE_PATH = "historical_5yr_ohlc.json"
TARGET_BRANCH = "main"

# Multi-Sector Symbols (IT, Banking, Consumer, Metal)
SYMBOLS = ["TCS", "INFY", "HCLTECH", "SBIN", "TITAN", "JINDALSTEL"]

def fetch_5year_ohlc():
    master_store = {}
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
    }

    print("=" * 70)
    print("⏳ Fetching 5-Year Daily OHLCV Data...")
    print(f"🎯 Symbols: {', '.join(SYMBOLS)}")
    print("=" * 70)

    for symbol in SYMBOLS:
        ticker = f"{symbol}.NS"
        url = f"https://query1.finance.yahoo.com/v8/finance/chart/{ticker}?range=5y&interval=1d"

        try:
            res = requests.get(url, headers=headers, timeout=15)
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
            print(f"✅ {symbol}: {len(stock_candles)} sessions fetched (~5 years)")
            time.sleep(0.5)

        except Exception as e:
            print(f"❌ Error fetching {symbol}: {e}")

    # Local Save with clean indentation
    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(master_store, f, ensure_ascii=False, indent=2)

    print("=" * 70)
    print(f"💾 File Saved Locally with indent=2: '{OUTPUT_FILE}'")
    print("=" * 70)

    push_to_target_repo()


def push_to_target_repo():
    token = os.environ.get("GH_PAT_TOKEN", "").strip()
    if not token:
        print("⚠️ GH_PAT_TOKEN not found. Skipping remote push.")
        return

    if not os.path.exists(OUTPUT_FILE):
        print(f"⚠️ {OUTPUT_FILE} not found. Nothing to push.")
        return

    print(f"\n🚀 Direct-Pushing '{OUTPUT_FILE}' to '{TARGET_REPO}'...")

    with open(OUTPUT_FILE, "rb") as f:
        file_bytes = f.read()

    b64_content = base64.b64encode(file_bytes).decode("utf-8")
    api_url = f"https://api.github.com/repos/{TARGET_REPO}/contents/{TARGET_FILE_PATH}"

    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json",
        "User-Agent": "Multi-Stock-Sync-Engine"
    }

    sha = None
    try:
        check_res = requests.get(api_url, headers=headers, params={"ref": TARGET_BRANCH}, timeout=15)
        if check_res.status_code == 200:
            sha = check_res.json().get("sha")
    except Exception as e:
        print(f"⚠️ Notice while fetching SHA: {e}")

    payload = {
        "message": f"📊 Auto-Update: 5Y OHLCV for {len(SYMBOLS)} Stocks [{datetime.now().strftime('%d-%b-%Y')}]",
        "content": b64_content,
        "branch": TARGET_BRANCH
    }
    if sha:
        payload["sha"] = sha

    try:
        put_res = requests.put(api_url, headers=headers, json=payload, timeout=30)
        if put_res.status_code in [200, 201]:
            print(f"✅ Target repo updated: https://github.com/{TARGET_REPO}/blob/{TARGET_BRANCH}/{TARGET_FILE_PATH}")
        else:
            print(f"❌ Target repo push failed ({put_res.status_code}): {put_res.text}")
    except Exception as e:
        print(f"❌ Error during remote sync: {e}")


if __name__ == "__main__":
    fetch_5year_ohlc()
