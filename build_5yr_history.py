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

# User Provided Stocks List
STOCKS_LIST = [
    {"symbol": "ABB", "name": "ABB India Limited", "sector": "Capital Goods / Engineering"},
    {"symbol": "ADANIENSOL", "name": "Adani Energy Solutions Limited", "sector": "Power / Transmission"},
    {"symbol": "ADANIENT", "name": "Adani Enterprises Limited", "sector": "Metals & Mining / Diversified"},
    {"symbol": "ADANIGREEN", "name": "Adani Green Energy Limited", "sector": "Renewable Energy"},
    {"symbol": "ADANIPORTS", "name": "Adani Ports and Special Economic Zone Limited", "sector": "Infrastructure / Ports"},
    {"symbol": "ADANIPOWER", "name": "Adani Power Limited", "sector": "Power Generation"},
    {"symbol": "AMBUJACEM", "name": "Ambuja Cements Limited", "sector": "Construction Materials / Cement"},
    {"symbol": "APOLLOHOSP", "name": "Apollo Hospitals Enterprise Limited", "sector": "Healthcare Services"},
    {"symbol": "ASIANPAINT", "name": "Asian Paints Limited", "sector": "Consumer Durables / Paints"},
    {"symbol": "DMART", "name": "Avenue Supermarts Limited", "sector": "Consumer Services / Retail"},
    {"symbol": "AXISBANK", "name": "Axis Bank Limited", "sector": "Banking & Financial Services"},
    {"symbol": "BAJAJ-AUTO", "name": "Bajaj Auto Limited", "sector": "Automobile / 2 & 3 Wheelers"},
    {"symbol": "BAJFINANCE", "name": "Bajaj Finance Limited", "sector": "Financial Services / NBFC"},
    {"symbol": "BAJAJFINSV", "name": "Bajaj Finserv Limited", "sector": "Financial Services / Holding Company"},
    {"symbol": "BAJAJHLDNG", "name": "Bajaj Holdings & Investment Limited", "sector": "Financial Services / Investment"},
    {"symbol": "BANKBARODA", "name": "Bank of Baroda", "sector": "Public Sector Bank"},
    {"symbol": "BEL", "name": "Bharat Electronics Limited", "sector": "Aerospace & Defense"},
    {"symbol": "BHEL", "name": "Bharat Heavy Electricals Limited", "sector": "Capital Goods / Power Equipment"},
    {"symbol": "BPCL", "name": "Bharat Petroleum Corporation Limited", "sector": "Oil, Gas & Consumable Fuels"},
    {"symbol": "BHARTIARTL", "name": "Bharti Airtel Limited", "sector": "Telecommunication Services"},
    {"symbol": "BOSCHLTD", "name": "Bosch Limited", "sector": "Automobile Ancillaries"},
    {"symbol": "BRITANNIA", "name": "Britannia Industries Limited", "sector": "FMCG / Food Products"},
    {"symbol": "CANBK", "name": "Canara Bank", "sector": "Public Sector Bank"},
    {"symbol": "CHOLAFIN", "name": "Cholamandalam Investment and Finance Company Limited", "sector": "Financial Services / NBFC"},
    {"symbol": "CIPLA", "name": "Cipla Limited", "sector": "Pharmaceuticals"},
    {"symbol": "COALINDIA", "name": "Coal India Limited", "sector": "Metals & Mining / Coal"},
    {"symbol": "COLPAL", "name": "Colgate-Palmolive (India) Limited", "sector": "FMCG / Personal Care"},
    {"symbol": "DLF", "name": "DLF Limited", "sector": "Real Estate"},
    {"symbol": "DABUR", "name": "Dabur India Limited", "sector": "FMCG / Personal Care"},
    {"symbol": "DIVISLAB", "name": "Divi's Laboratories Limited", "sector": "Pharmaceuticals / Active Ingredients"},
    {"symbol": "DRREDDY", "name": "Dr. Reddy's Laboratories Limited", "sector": "Pharmaceuticals"},
    {"symbol": "EICHERMOT", "name": "Eicher Motors Limited", "sector": "Automobile / 2 Wheelers & CVs"},
    {"symbol": "GAIL", "name": "GAIL (India) Limited", "sector": "Gas Transmission & Marketing"},
    {"symbol": "GODREJCP", "name": "Godrej Consumer Products Limited", "sector": "FMCG / Personal Care"},
    {"symbol": "GRASIM", "name": "Grasim Industries Limited", "sector": "Diversified / Cement & Chemicals"},
    {"symbol": "HCLTECH", "name": "HCL Technologies Limited", "sector": "Information Technology"},
    {"symbol": "HDFCAMC", "name": "HDFC Asset Management Company Limited", "sector": "Asset Management / Financials"},
    {"symbol": "HDFCBANK", "name": "HDFC Bank Limited", "sector": "Private Sector Bank"},
    {"symbol": "HDFCLIFE", "name": "HDFC Life Insurance Company Limited", "sector": "Life Insurance"},
    {"symbol": "HAVELLS", "name": "Havells India Limited", "sector": "Consumer Electricals"},
    {"symbol": "HEROMOTOCO", "name": "Hero MotoCorp Limited", "sector": "Automobile / 2 Wheelers"},
    {"symbol": "HINDALCO", "name": "Hindalco Industries Limited", "sector": "Metals & Mining / Aluminium"},
    {"symbol": "HAL", "name": "Hindustan Aeronautics Limited", "sector": "Aerospace & Defense"},
    {"symbol": "HINDPETRO", "name": "Hindustan Petroleum Corporation Limited", "sector": "Oil, Gas & Consumable Fuels"},
    {"symbol": "HINDUNILVR", "name": "Hindustan Unilever Limited", "sector": "FMCG / Diversified"},
    {"symbol": "ICICIBANK", "name": "ICICI Bank Limited", "sector": "Private Sector Bank"},
    {"symbol": "ICICIGI", "name": "ICICI Lombard General Insurance Company Limited", "sector": "General Insurance"},
    {"symbol": "ICICIPRULI", "name": "ICICI Prudential Life Insurance Company Limited", "sector": "Life Insurance"},
    {"symbol": "ITC", "name": "ITC Limited", "sector": "Diversified / FMCG, Cigarettes, Hotels"},
    {"symbol": "INDIANB", "name": "Indian Bank", "sector": "Public Sector Bank"},
    {"symbol": "INDHOTEL", "name": "The Indian Hotels Company Limited", "sector": "Consumer Services / Hospitality"},
    {"symbol": "IOC", "name": "Indian Oil Corporation Limited", "sector": "Oil, Gas & Consumable Fuels"},
    {"symbol": "IRCTC", "name": "Indian Railway Catering and Tourism Corporation Limited", "sector": "Consumer Services / Tourism & Rail"},
    {"symbol": "IRFC", "name": "Indian Railway Finance Corporation Limited", "sector": "Financial Services / Rail Financing"},
    {"symbol": "INDUSINDBK", "name": "IndusInd Bank Limited", "sector": "Private Sector Bank"},
    {"symbol": "NAUKRI", "name": "Info Edge (India) Limited", "sector": "Internet Software & Services"},
    {"symbol": "INFY", "name": "Infosys Limited", "sector": "Information Technology"},
    {"symbol": "INDIGO", "name": "InterGlobe Aviation Limited", "sector": "Aviation / Airlines"},
    {"symbol": "JSWENERGY", "name": "JSW Energy Limited", "sector": "Power Generation"},
    {"symbol": "JSWSTEEL", "name": "JSW Steel Limited", "sector": "Metals & Mining / Steel"},
    {"symbol": "JINDALSTEL", "name": "Jindal Steel & Power Limited", "sector": "Metals & Mining / Steel"},
    {"symbol": "JIOFIN", "name": "Jio Financial Services Limited", "sector": "Financial Services / NBFC"},
    {"symbol": "KOTAKBANK", "name": "Kotak Mahindra Bank Limited", "sector": "Private Sector Bank"},
    {"symbol": "LTIM", "name": "LTIMindtree Limited", "sector": "Information Technology"},
    {"symbol": "LT", "name": "Larsen & Toubro Limited", "sector": "Infrastructure & Engineering"},
    {"symbol": "LICHSGFIN", "name": "LIC Housing Finance Limited", "sector": "Financial Services / Housing Finance"},
    {"symbol": "LICI", "name": "Life Insurance Corporation of India", "sector": "Life Insurance"},
    {"symbol": "M&M", "name": "Mahindra & Mahindra Limited", "sector": "Automobile / Commercial & UVs"},
    {"symbol": "MARICO", "name": "Marico Limited", "sector": "FMCG / Personal Care"},
    {"symbol": "MARUTI", "name": "Maruti Suzuki India Limited", "sector": "Automobile / Passenger Cars"},
    {"symbol": "MAXHEALTH", "name": "Max Healthcare Institute Limited", "sector": "Healthcare Services / Hospitals"},
    {"symbol": "MUTHOOTFIN", "name": "Muthoot Finance Limited", "sector": "Financial Services / Gold Loan NBFC"},
    {"symbol": "NTPC", "name": "NTPC Limited", "sector": "Power Generation"},
    {"symbol": "NESTLEIND", "name": "Nestle India Limited", "sector": "FMCG / Food & Beverages"},
    {"symbol": "ONGC", "name": "Oil & Natural Gas Corporation Limited", "sector": "Oil & Gas Exploration & Production"},
    {"symbol": "PIDILITIND", "name": "Pidilite Industries Limited", "sector": "Specialty Chemicals / Adhesives"},
    {"symbol": "PFC", "name": "Power Finance Corporation Limited", "sector": "Financial Services / Power Financing"},
    {"symbol": "POWERGRID", "name": "Power Grid Corporation of India Limited", "sector": "Power / Transmission"},
    {"symbol": "PNB", "name": "Punjab National Bank", "sector": "Public Sector Bank"},
    {"symbol": "RECLTD", "name": "REC Limited", "sector": "Financial Services / Power Infrastructure"},
    {"symbol": "RELIANCE", "name": "Reliance Industries Limited", "sector": "Energy, Retail, Telecom"},
    {"symbol": "SBICARD", "name": "SBI Cards and Payment Services Limited", "sector": "Financial Services / Credit Cards"},
    {"symbol": "SBILIFE", "name": "SBI Life Insurance Company Limited", "sector": "Life Insurance"},
    {"symbol": "SRF", "name": "SRF Limited", "sector": "Specialty Chemicals & Materials"},
    {"symbol": "SHREECEM", "name": "Shree Cement Limited", "sector": "Construction Materials / Cement"},
    {"symbol": "SHRIRAMFIN", "name": "Shriram Finance Limited", "sector": "Financial Services / Asset Financing"},
    {"symbol": "SIEMENS", "name": "Siemens Limited", "sector": "Capital Goods / Industrial Tech"},
    {"symbol": "SBIN", "name": "State Bank of India", "sector": "Public Sector Bank"},
    {"symbol": "SUNPHARMA", "name": "Sun Pharmaceutical Industries Limited", "sector": "Pharmaceuticals"},
    {"symbol": "TATACONSUM", "name": "Tata Consumer Products Limited", "sector": "FMCG / Foods & Beverages"},
    {"symbol": "TATAMOTORS", "name": "Tata Motors Limited", "sector": "Automobile / Commercial & EV"},
    {"symbol": "TATAPOWER", "name": "Tata Power Company Limited", "sector": "Power / Integrated Utilities"},
    {"symbol": "TATASTEEL", "name": "Tata Steel Limited", "sector": "Metals & Mining / Steel"},
    {"symbol": "TCS", "name": "Tata Consultancy Services Limited", "sector": "Information Technology"},
    {"symbol": "TECHM", "name": "Tech Mahindra Limited", "sector": "Information Technology"},
    {"symbol": "TITAN", "name": "Titan Company Limited", "sector": "Consumer Discretionary / Jewellery"},
    {"symbol": "TORNTPHARM", "name": "Torrent Pharmaceuticals Limited", "sector": "Pharmaceuticals"},
    {"symbol": "TRENT", "name": "Trent Limited", "sector": "Consumer Discretionary / Retail"},
    {"symbol": "ULTRACEMCO", "name": "UltraTech Cement Limited", "sector": "Construction Materials / Cement"},
    {"symbol": "UNIONBANK", "name": "Union Bank of India", "sector": "Public Sector Bank"},
    {"symbol": "UNITDSPR", "name": "United Spirits Limited", "sector": "Beverages / AlcoBev"},
    {"symbol": "VBL", "name": "Varun Beverages Limited", "sector": "FMCG / Beverages Bottler"},
    {"symbol": "VEDL", "name": "Vedanta Limited", "sector": "Metals & Mining / Diversified Natural Resources"},
    {"symbol": "WIPRO", "name": "Wipro Limited", "sector": "Information Technology"},
    {"symbol": "ZOMATO", "name": "Zomato Limited", "sector": "Consumer Services / Food Delivery & Quick Commerce"},
    {"symbol": "ZYDUSLIFE", "name": "Zydus Lifesciences Limited", "sector": "Pharmaceuticals"}
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
