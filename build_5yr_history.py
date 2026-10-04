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

# Nifty Smallcap 250 Stocks List
STOCKS_LIST = [
    {"symbol": "ACC", "name": "ACC Ltd.", "sector": "Construction Materials"},
    {"symbol": "ACMESOLAR", "name": "ACME Solar Holdings Ltd.", "sector": "Power"},
    {"symbol": "AWL", "name": "AWL Agri Business Ltd.", "sector": "Fast Moving Consumer Goods"},
    {"symbol": "AADHARHFC", "name": "Aadhar Housing Finance Ltd.", "sector": "Financial Services"},
    {"symbol": "AARTIIND", "name": "Aarti Industries Ltd.", "sector": "Chemicals"},
    {"symbol": "AAVAS", "name": "Aavas Financiers Ltd.", "sector": "Financial Services"},
    {"symbol": "ACE", "name": "Action Construction Equipment Ltd.", "sector": "Capital Goods"},
    {"symbol": "ACUTAAS", "name": "Acutaas Chemicals Ltd.", "sector": "Chemicals"},
    {"symbol": "ABREL", "name": "Aditya Birla Real Estate Ltd.", "sector": "Realty"},
    {"symbol": "ABSLAMC", "name": "Aditya Birla Sun Life AMC Ltd.", "sector": "Financial Services"},
    {"symbol": "AEGISLOG", "name": "Aegis Logistics Ltd.", "sector": "Oil Gas & Consumable Fuels"},
    {"symbol": "AFFLE", "name": "Affle (India) Ltd.", "sector": "Information Technology"},
    {"symbol": "AJANTPHARM", "name": "Ajanta Pharma Ltd.", "sector": "Healthcare"},
    {"symbol": "AKUMS", "name": "Akums Drugs and Pharmaceuticals Ltd.", "sector": "Healthcare"},
    {"symbol": "ALOKINDS", "name": "Alok Industries Ltd.", "sector": "Textiles"},
    {"symbol": "AMBER", "name": "Amber Enterprises India Ltd.", "sector": "Consumer Durables"},
    {"symbol": "ANANDRATHI", "name": "Anand Rathi Wealth Ltd.", "sector": "Financial Services"},
    {"symbol": "ANANTRAJ", "name": "Anant Raj Ltd.", "sector": "Realty"},
    {"symbol": "ANGELONE", "name": "Angel One Ltd.", "sector": "Financial Services"},
    {"symbol": "APARINDS", "name": "Apar Industries Ltd.", "sector": "Capital Goods"},
    {"symbol": "APLLTD", "name": "Alembic Pharmaceuticals Ltd.", "sector": "Healthcare"},
    {"symbol": "APPUS", "name": "Appus Finance Ltd.", "sector": "Financial Services"},
    {"symbol": "APTUS", "name": "Aptus Value Housing Finance India Ltd.", "sector": "Financial Services"},
    {"symbol": "ARE&M", "name": "Amara Raja Energy & Mobility Ltd.", "sector": "Automobile and Auto Components"},
    {"symbol": "ASAHIINDIA", "name": "Asahi India Glass Ltd.", "sector": "Automobile and Auto Components"},
    {"symbol": "ASHOKLEY", "name": "Ashok Leyland Ltd.", "sector": "Automobile and Auto Components"},
    {"symbol": "ASTERDM", "name": "Aster DM Healthcare Ltd.", "sector": "Healthcare"},
    {"symbol": "ASTRAL", "name": "Astral Ltd.", "sector": "Capital Goods"},
    {"symbol": "ASTRAZEN", "name": "AstraZeneca Pharma India Ltd.", "sector": "Healthcare"},
    {"symbol": "ATUL", "name": "Atul Ltd.", "sector": "Chemicals"},
    {"symbol": "AUBANK", "name": "AU Small Finance Bank Ltd.", "sector": "Financial Services"},
    {"symbol": "AUROPHARMA", "name": "Aurobindo Pharma Ltd.", "sector": "Healthcare"},
    {"symbol": "AVANTIFEED", "name": "Avanti Feeds Ltd.", "sector": "Fast Moving Consumer Goods"},
    {"symbol": "BAJAJELEC", "name": "Bajaj Electricals Ltd.", "sector": "Consumer Durables"},
    {"symbol": "BALAMINES", "name": "Balaji Amines Ltd.", "sector": "Chemicals"},
    {"symbol": "BALKRISIND", "name": "Balkrishna Industries Ltd.", "sector": "Automobile and Auto Components"},
    {"symbol": "BALRAMCHIN", "name": "Balrampur Chini Mills Ltd.", "sector": "Fast Moving Consumer Goods"},
    {"symbol": "BANDHANBNK", "name": "Bandhan Bank Ltd.", "sector": "Financial Services"},
    {"symbol": "BANKINDIA", "name": "Bank of India", "sector": "Financial Services"},
    {"symbol": "BATAINDIA", "name": "Bata India Ltd.", "sector": "Consumer Durables"},
    {"symbol": "BAYERCROP", "name": "Bayer Cropscience Ltd.", "sector": "Chemicals"},
    {"symbol": "BDL", "name": "Bharat Dynamics Ltd.", "sector": "Capital Goods"},
    {"symbol": "BERGEPAINT", "name": "Berger Paints India Ltd.", "sector": "Consumer Durables"},
    {"symbol": "BHARATFORG", "name": "Bharat Forge Ltd.", "sector": "Automobile and Auto Components"},
    {"symbol": "BBL", "name": "Bharat Bijlee Ltd.", "sector": "Capital Goods"},
    {"symbol": "BIOCON", "name": "Biocon Ltd.", "sector": "Healthcare"},
    {"symbol": "BIRLACORPN", "name": "Birla Corporation Ltd.", "sector": "Construction Materials"},
    {"symbol": "BLS", "name": "BLS International Services Ltd.", "sector": "Consumer Services"},
    {"symbol": "BLUEDART", "name": "Blue Dart Express Ltd.", "sector": "Services"},
    {"symbol": "BLUESTARCO", "name": "Blue Star Ltd.", "sector": "Consumer Durables"},
    {"symbol": "BSOFT", "name": "Birlasoft Ltd.", "sector": "Information Technology"},
    {"symbol": "CAMPUS", "name": "Campus Activewear Ltd.", "sector": "Consumer Durables"},
    {"symbol": "CAMS", "name": "Computer Age Management Services Ltd.", "sector": "Financial Services"},
    {"symbol": "CANFINHOME", "name": "Can Fin Homes Ltd.", "sector": "Financial Services"},
    {"symbol": "CAPL", "name": "Caplin Point Laboratories Ltd.", "sector": "Healthcare"},
    {"symbol": "CARBORUNIV", "name": "Carborundum Universal Ltd.", "sector": "Capital Goods"},
    {"symbol": "CASTROLIND", "name": "Castrol India Ltd.", "sector": "Oil Gas & Consumable Fuels"},
    {"symbol": "CEATLTD", "name": "CEAT Ltd.", "sector": "Automobile and Auto Components"},
    {"symbol": "CENTRALBK", "name": "Central Bank of India", "sector": "Financial Services"},
    {"symbol": "CENTURYPLY", "name": "Century Plyboards (India) Ltd.", "sector": "Consumer Durables"},
    {"symbol": "CENTURYTEX", "name": "Century Textiles & Industries Ltd.", "sector": "Realty"},
    {"symbol": "CERA", "name": "Cera Sanitaryware Ltd.", "sector": "Consumer Durables"},
    {"symbol": "CESC", "name": "CESC Ltd.", "sector": "Power"},
    {"symbol": "CGCL", "name": "Capri Global Capital Ltd.", "sector": "Financial Services"},
    {"symbol": "CHAMBLFERT", "name": "Chambal Fertilisers and Chemicals Ltd.", "sector": "Chemicals"},
    {"symbol": "CHEMPLASTS", "name": "Chemplast Sanmar Ltd.", "sector": "Chemicals"},
    {"symbol": "CHOLAHLDNG", "name": "Cholamandalam Financial Holdings Ltd.", "sector": "Financial Services"},
    {"symbol": "CLEAN", "name": "Clean Science and Technology Ltd.", "sector": "Chemicals"},
    {"symbol": "COCHINSHIP", "name": "Cochin Shipyard Ltd.", "sector": "Capital Goods"},
    {"symbol": "CONCOR", "name": "Container Corporation of India Ltd.", "sector": "Services"},
    {"symbol": "COROMANDEL", "name": "Coromandel International Ltd.", "sector": "Chemicals"},
    {"symbol": "CREDITACC", "name": "CreditAccess Grameen Ltd.", "sector": "Financial Services"},
   
]

# Extract ticker symbols directly
SYMBOLS = [item["symbol"] for item in STOCKS_LIST]

def fetch_5year_ohlc():
    master_store = {}
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
    }

    print("=" * 70)
    print(f"⏳ Fetching 5-Year Daily OHLCV Data for {len(SYMBOLS)} Stocks...")
    print("=" * 70)

    for idx, symbol in enumerate(SYMBOLS, 1):
        ticker = f"{symbol}.NS"
        url = f"https://query1.finance.yahoo.com/v8/finance/chart/{ticker}?range=5y&interval=1d"

        try:
            res = requests.get(url, headers=headers, timeout=15)
            if res.status_code != 200:
                print(f"⚠️ [{idx}/{len(SYMBOLS)}] Failed for {symbol} (HTTP {res.status_code})")
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
            print(f"✅ [{idx}/{len(SYMBOLS)}] {symbol}: {len(stock_candles)} sessions fetched")
            time.sleep(0.3)

        except Exception as e:
            print(f"❌ [{idx}/{len(SYMBOLS)}] Error fetching {symbol}: {e}")

    # Local Save with clean indentation
    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(master_store, f, ensure_ascii=False, indent=2)

    print("=" * 70)
    print(f"💾 File Saved Locally: '{OUTPUT_FILE}' ({len(master_store)} stocks stored)")
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
        put_res = requests.put(api_url, headers=headers, json=payload, timeout=45)
        if put_res.status_code in [200, 201]:
            print(f"✅ Target repo updated: https://github.com/{TARGET_REPO}/blob/{TARGET_BRANCH}/{TARGET_FILE_PATH}")
        else:
            print(f"❌ Target repo push failed ({put_res.status_code}): {put_res.text}")
    except Exception as e:
        print(f"❌ Error during remote sync: {e}")


if __name__ == "__main__":
    fetch_5year_ohlc()
