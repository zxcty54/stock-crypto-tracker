import os
import json
import time
from datetime import datetime
import requests

OUTPUT_FILE = "macro_research_report.json"

COMMODITIES = [
    {
        "id": "crude_oil",
        "name": "Crude Oil (Brent)",
        "ticker": "BZ=F",
        "unit": "USD/bbl",
        "sector_relevance": "Paints, Tyres, Aviation, Petrochem, PVC Pipes, Upstream Oil",
        "import_profile": "87% Imported (High USD-INR & Middle East Geopolitical Sensitivity)"
    },
    {
        "id": "copper",
        "name": "Refined Copper",
        "ticker": "HG=F",
        "unit": "USD/lb",
        "sector_relevance": "Cables & Wires, Transformers, Consumer Durables (ACs/Fans), Auto",
        "import_profile": "92% Imported (Post-Tuticorin shutdown; high LME benchmark link)"
    },
    {
        "id": "natural_gas",
        "name": "Natural Gas",
        "ticker": "NG=F",
        "unit": "USD/MMBtu",
        "sector_relevance": "Ceramic Tiles, Urea & Nitrogen Fertilizers, City Gas Distribution",
        "import_profile": "52% Imported via Spot/Long-term LNG (High spot volatility)"
    },
    {
        "id": "aluminium",
        "name": "Aluminium",
        "ticker": "ALI=F",
        "unit": "USD/MT",
        "sector_relevance": "Auto Ancillary, Sheet Metal, Packaging, White Goods",
        "import_profile": "Indigenous/Export Surplus (Domestic pricing linked to LME parity)"
    },
    {
        "id": "cotton",
        "name": "Cotton",
        "ticker": "CT=F",
        "unit": "USc/lb",
        "sector_relevance": "Textiles, Yarn Spinning Mills, Garmenting, Home Textiles",
        "import_profile": "95% Domestic (Monsoon, Cotton MSP & Sowing acreage sensitive)"
    },
    {
        "id": "iron_ore",
        "name": "Iron Ore 62% Fe (Proxy)",
        "ticker": "TIO=F",
        "unit": "USD/dmt",
        "sector_relevance": "Steel Production, Secondary Steel, Commercial Vehicles, Infra Rebars",
        "import_profile": "100% Domestic (NMDC monthly price revisions benchmarked to global proxy)"
    }
]

def fetch_commodity_metrics():
    headers = {"User-Agent": "Mozilla/5.0"}
    gathered = []

    print("=" * 70)
    print("⏳ Step 1: Gathering Raw Commodity Multi-Period Data...")
    print("=" * 70)

    for item in COMMODITIES:
        ticker = item["ticker"]
        url = f"https://query1.finance.yahoo.com/v8/finance/chart/{ticker}?range=3y&interval=1d"

        try:
            res = requests.get(url, headers=headers, timeout=12)
            if res.status_code != 200:
                print(f"⚠️ Failed to fetch {item['name']}")
                continue

            data = res.json()
            result = data.get("chart", {}).get("result", [])[0]
            closes = [c for c in result.get("indicators", {}).get("quote", [])[0].get("close", []) if c is not None]

            if not closes:
                continue

            current_price = round(closes[-1], 2)
            p_1m = closes[-22] if len(closes) >= 22 else closes[0]
            p_6m = closes[-126] if len(closes) >= 126 else closes[0]
            p_1y = closes[-252] if len(closes) >= 252 else closes[0]
            p_3y = closes[0]

            def pct(new, old):
                return round(((new - old) / old) * 100, 2)

            item["current_price"] = current_price
            item["deltas"] = {
                "1M": pct(current_price, p_1m),
                "6M": pct(current_price, p_6m),
                "1Y": pct(current_price, p_1y),
                "3Y": pct(current_price, p_3y)
            }
            gathered.append(item)
            print(f"✅ {item['name']:<20}: {current_price:>8} {item['unit']:<8} | 1Y(YoY): {item['deltas']['1Y']:>6}%")
            time.sleep(0.3)

        except Exception as e:
            print(f"❌ Error fetching {item['name']}: {e}")

    return gathered

def generate_ai_research_analysis(dataset):
    api_key = os.environ.get("GEMINI_API_KEY", "").strip()
    if not api_key:
        print("⚠️ GEMINI_API_KEY missing. Please add it to repo Secrets.")
        return []

    print("\n" + "=" * 70)
    print("🧠 Step 2: Triggering Gemini AI for Brokerage-Grade Sector Analysis...")
    print("=" * 70)

    ai_reports = []
    endpoint = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={api_key}"

    for item in dataset:
        prompt = f"""
You are the Head of Equity Research & Macro Strategist at a premier Indian Institutional Brokerage.
Analyze the following raw material price dynamics for Indian manufacturing and listed equities:

COMMODITY: {item['name']}
CURRENT PRICE: {item['current_price']} {item['unit']}
MULTI-PERIOD DELTAS: 1-Month: {item['deltas']['1M']}%, 6-Month: {item['deltas']['6M']}%, 1-Year (YoY): {item['deltas']['1Y']}%, 3-Year: {item['deltas']['3Y']}%
RELEVANT SECTORS: {item['sector_relevance']}
SOURCING CONTEXT: {item['import_profile']}

Respond ONLY with a valid JSON object matching this exact schema:
{{
  "commodity_name": "{item['name']}",
  "unit": "{item['unit']}",
  "current_price": {item['current_price']},
  "period_changes": {{
    "1M": {item['deltas']['1M']},
    "6M": {item['deltas']['6M']},
    "1Y": {item['deltas']['1Y']},
    "3Y": {item['deltas']['3Y']}
  }},
  "margin_trajectory": "EXPANDING" or "CONTRACTING" or "NEUTRAL",
  "macro_headline": "A punchy, single-line institutional takeaway highlighting price level and quarterly margin direction",
  "forward_thesis": "2 to 3 sentences explaining the 45-90 days inventory lag, cost pass-through dynamics, and expected corporate EBITDA impact for Indian manufacturers in upcoming quarters",
  "import_context": "{item['import_profile']}",
  "key_risk": "One primary risk factor (e.g., currency depreciation, freight spikes, or retaliatory tariffs)",
  "impacted_stocks": [
    {{
      "symbol": "NSE_SYMBOL (e.g. ASIANPAINT)",
      "company_name": "Full Company Name",
      "sector": "Sub-Sector",
      "impact_type": "POSITIVE" or "NEGATIVE",
      "margin_impact_bps": "+180 bps" or "-120 bps",
      "rationale": "Precise one-line explanation of raw material exposure, COGS percentage, or pricing power lag"
    }}
  ]
}}
Do NOT output markdown backticks like ```json. Output ONLY raw parseable JSON.
"""

        payload = {
            "contents": [{"parts": [{"text": prompt}]}],
            "generationConfig": {
                "temperature": 0.2,
                "responseMimeType": "application/json"
            }
        }

        try:
            res = requests.post(endpoint, json=payload, headers={"Content-Type": "application/json"}, timeout=30)
            if res.status_code == 200:
                raw_text = res.json()["candidates"][0]["content"]["parts"][0]["text"].strip()
                report_obj = json.loads(raw_text)
                ai_reports.append(report_obj)
                print(f"✨ AI Analysis compiled: {item['name']} ({len(report_obj.get('impacted_stocks', []))} stocks)")
            else:
                print(f"⚠️ AI call failed for {item['name']}: {res.status_code}")
            time.sleep(1.0)
        except Exception as e:
            print(f"❌ Exception in AI processing for {item['name']}: {e}")

    return ai_reports

if __name__ == "__main__":
    dataset = fetch_commodity_metrics()
    if dataset:
        reports = generate_ai_research_analysis(dataset)
        if reports:
            final_data = {
                "updated_at": datetime.now().strftime("%Y-%m-%d %H:%M:%S IST"),
                "total_reports": len(reports),
                "reports": reports
            }
            with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
                json.dump(final_data, f, ensure_ascii=False, indent=2)
            print(f"\n🎉 Successfully created '{OUTPUT_FILE}' locally in repo!")
