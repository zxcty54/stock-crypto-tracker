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

# Tickers List: Indices ke liye exact symbol, Stocks ke liye normal symbol
ASSETS_LIST = [
    {"id": "NIFTY50", "ticker": "^NSEI", "name": "Nifty 50 Index"},
    {"id": "BANKNIFTY", "ticker": "^NSEBANK", "name": "Nifty Bank Index"},
    {"id": "TCS", "ticker": "TCS.NS", "name": "Tata Consultancy Services"},
    {"id": "RELIANCE", "ticker": "RELIANCE.NS", "name": "Reliance Industries Ltd."},
    {"id": "HDFCBANK", "ticker": "HDFCBANK.NS", "name": "HDFC Bank Ltd."}
]

def fetch_10year_ohlc():
    master_store = {}
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
    }

    print("=" * 75)
    print(f"⏳ Fetching 10-Year Daily OHLCV Data for {len(ASSETS_LIST)} Assets...")
    print("=" * 75)

    for idx, asset in enumerate(ASSETS_LIST, 1):
        asset_id = asset["id"]
        ticker = asset["ticker"]
        
        # 10-year daily data endpoint
        url = f"https://query1.finance.yahoo.com/v8/finance/chart/{ticker}?range=10y&interval=1d"

        try:
            res = requests.get(url, headers=headers, timeout=20)
            if res.status_code != 200:
                print(f"⚠️ [{idx}/{len(ASSETS_LIST)}] Failed for {asset_id} (HTTP {res.status_code})")
                continue

            data = res.json()
            result_list = data.get("chart", {}).get("result", [])
            if not result_list:
                print(f"⚠️ [{idx}/{len(ASSETS_LIST)}] No data returned for {asset_id}")
                continue

            result = result_list[0]
            timestamps = result.get("timestamp", [])
            indicators = result.get("indicators", {}).get("quote", [])[0]

            opens = indicators.get("open", [])
            highs = indicators.get("high", [])
            lows = indicators.get("low", [])
            closes = indicators.get("close", [])
            volumes = indicators.get("volume", [])

            candles = []
            for i in range(len(timestamps)):
                # Skip invalid sessions
                if None in (opens[i], highs[i], lows[i], closes[i]):
                    continue

                date_str = datetime.fromtimestamp(timestamps[i]).strftime("%Y-%m-%d")
                candles.append([
                    date_str,
                    round(float(opens[i]), 2),
                    round(float(highs[i]), 2),
                    round(float(lows[i]), 2),
                    round(float(closes[i]), 2),
                    int(volumes[i] or 0)
                ])

            master_store[asset_id] = candles
            print(f"✅ [{idx}/{len(ASSETS_LIST)}] {asset_id} ({ticker}): {len(candles)} trading sessions fetched (~10 Years)")
            time.sleep(0.4)

        except Exception as e:
            print(f"❌ [{idx}/{len(ASSETS_LIST)}] Error fetching {asset_id}: {e}")

    # Local Save
    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(master_store, f, ensure_ascii=False, indent=2)

    print("=" * 75)
    print(f"💾 File Saved: '{OUTPUT_FILE}' ({len(master_store)} assets saved)")
    print("=" * 75)

    push_to_target_repo()


def push_to_target_repo():
    token = os.environ.get("GH_PAT_TOKEN", "").strip()
    if not token:
        print("⚠️ GH_PAT_TOKEN not found. Skipping remote push.")
        return

    if not os.path.exists(OUTPUT_FILE):
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
        "message": f"📊 Auto-Update: 10Y OHLCV for Nifty, BankNifty & Stocks [{datetime.now().strftime('%d-%b-%Y')}]",
        "content": b64_content,
        "branch": TARGET_BRANCH
    }
    if sha:
        payload["sha"] = sha

    try:
        put_res = requests.put(api_url, headers=headers, json=payload, timeout=45)
        if put_res.status_code in [200, 201]:
            print(f"✅ Target repo updated: https://github.com/{TARGET_REPO}/blob/{TARGET_BRANCH}/{TARGET_FILE_PATH}")
        else:
            print(f"❌ Target repo push failed ({put_res.status_code}): {put_res.text}")
    except Exception as e:
        print(f"❌ Error during remote sync: {e}")


if __name__ == "__main__":
    fetch_10year_ohlc()
