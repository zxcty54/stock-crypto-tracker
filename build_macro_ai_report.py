import os
import json
import time
from datetime import datetime
import requests

OUTPUT_FILE = "macro_research_report.json"

CANDIDATE_MODELS = [
    "gemini-2.0-flash",
    "gemini-1.5-flash",
    "gemini-2.5-flash",
    "gemini-1.5-pro"
]

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

def run_api_diagnostics(api_key):
    print("=" * 75)
    print("🔍 DIAGNOSTIC MODE: Checking Gemini API Key & Connection...")
    print("=" * 75)

    if not api_key:
        print("❌ CRITICAL ERROR: 'GEMINI_API_KEY' is EMPTY!")
        return False

    print(f"🔑 Key Detected: {api_key[:6]}...{api_key[-4:]} (Length: {len(api_key)} chars)")

    list_url = f"https://generativelanguage.googleapis.com/v1beta/models?key={api_key}"
    try:
        res = requests.get(list_url, timeout=15)
        print(f"📡 Testing Google API Gateway -> HTTP Status: {res.status_code}")

        if res.status_code == 200:
            models_data = res.json().get("models", [])
            gen_models = [m["name"].replace("models/", "") for m in models_data if "generateContent" in m.get("supportedGenerationMethods", [])]
            print("✅ API Key is 100% VALID! Active Models available:")
            print(f"   {', '.join(gen_models[:6])}")
            return True
        else:
            print("❌ Google Gateway Rejected Request! Raw Response:")
            print(f"   Status Code: {res.status_code}")
            print(f"   Response Body: {res.text}")
            return False

    except Exception as e:
        print(f"❌ Network/Connection Exception during diagnostic: {e}")
        return False

def fetch_commodity_metrics():
    headers = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"}
    gathered = []

    print("\n" + "=" * 75)
    print("⏳ Step 1: Gathering Raw Commodity Multi-Period Data...")
    print("=" * 75)

    for item in COMMODITIES:
        ticker = item["ticker"]
        url = f"https://query1.finance.yahoo.com/v8/finance/chart/{ticker}?range=3y&interval=1d"

        try:
            res = requests.get(url, headers=headers, timeout=12)
            if res.status_code != 200:
                print(f"⚠️ Failed to fetch {item['name']} (HTTP {res.status_code})")
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
            print(f"✅ {item['name']:<22}: {current_price:>8} {item['unit']:<8} | 1Y(YoY): {item['deltas']['1Y']:>6}%")
            time.sleep(0.3)

        except Exception as e:
            print(f"❌ Error fetching {item['name']}: {e}")

    return gathered

def call_gemini_with_fallback(prompt, api_key):
    payload = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {
            "temperature": 0.2,
            "responseMimeType": "application/json"
        }
    }

    for model_name in CANDIDATE_MODELS:
        for version in ["v1beta", "v1"]:
            url = f"https://generativelanguage.googleapis.com/{version}/models/{model_name}:generateContent?key={api_key}"
            headers = {"Content-Type": "application/json"}

            try:
                res = requests.post(url, json=payload, headers=headers, timeout=25)

                if res.status_code == 200:
                    raw_text = res.json()["candidates"][0]["content"]["parts"][0]["text"].strip()
                    if raw_text.startswith("```json"):
                        raw_text = raw_text[7:]
                    elif raw_text.startswith("```"):
                        raw_text = raw_text[3:]
                    if raw_text.endswith("```"):
                        raw_text = raw_text[:-3]

                    return json.loads(raw_text.strip()), f"{model_name} [{version}]"
                else:
                    error_detail = res.text[:220].replace("\n", " ")
                    print(f"   ⚠ [{version}] {model_name} -> HTTP {res.status_code} | Details: {error_detail}")
                    time.sleep(0.5)

            except Exception as e:
                print(f"   ⚠️ [{version}] {model_name} Exception: {e}")
                time.sleep(0.5)

    return None, None

def generate_ai_research_analysis(dataset, api_key):
    print("\n" + "=" * 75)
    print("🧠 Step 2: Triggering Gemini AI with Model Fallbacks...")
    print("=" * 75)

    ai_reports = []

    # Safe Schema Definition without string interpolation bugs
    schema_template = """{
  "commodity_name": "__COMMODITY__",
  "unit": "__UNIT__",
  "current_price": __PRICE__,
  "period_changes": {
    "1M": __D1M__,
    "6M": __D6M__,
    "1Y": __D1Y__,
    "3Y": __D3Y__
  },
  "margin_trajectory": "EXPANDING or CONTRACTING or NEUTRAL",
  "macro_headline": "A punchy single-line institutional takeaway",
  "forward_thesis": "2 to 3 sentences explaining the 45-90 days inventory lag and corporate EBITDA impact",
  "import_context": "__IMPORT__",
  "key_risk": "One primary risk factor",
  "impacted_stocks": [
    {
      "symbol": "NSE_SYMBOL (e.g. ASIANPAINT)",
      "company_name": "Full Company Name",
      "sector": "Sub-Sector",
      "impact_type": "POSITIVE or NEGATIVE",
      "margin_impact_bps": "+180 bps or -120 bps",
      "rationale": "One-line explanation of raw material exposure"
    }
  ]
}"""

    for item in dataset:
        print(f"\n📡 Requesting AI Analysis for: {item['name']}...")

        prompt = (
            "You are the Head of Equity Research & Macro Strategist at a premier Indian Institutional Brokerage.\n"
            "Analyze the following raw material price dynamics for Indian manufacturing and listed equities:\n\n"
            f"COMMODITY: {item['name']}\n"
            f"CURRENT PRICE: {item['current_price']} {item['unit']}\n"
            f"MULTI-PERIOD DELTAS: 1-Month: {item['deltas']['1M']}%, 6-Month: {item['deltas']['6M']}%, "
            f"1-Year (YoY): {item['deltas']['1Y']}%, 3-Year: {item['deltas']['3Y']}%\n"
            f"RELEVANT SECTORS: {item['sector_relevance']}\n"
            f"SOURCING CONTEXT: {item['import_profile']}\n\n"
            "Respond ONLY with a valid JSON object matching this exact schema template:\n"
            + schema_template.replace("__COMMODITY__", item['name'])
                             .replace("__UNIT__", item['unit'])
                             .replace("__PRICE__", str(item['current_price']))
                             .replace("__D1M__", str(item['deltas']['1M']))
                             .replace("__D6M__", str(item['deltas']['6M']))
                             .replace("__D1Y__", str(item['deltas']['1Y']))
                             .replace("__D3Y__", str(item['deltas']['3Y']))
                             .replace("__IMPORT__", item['import_profile'])
            + "\n\nEnsure the impacted_stocks array contains EXACTLY 8 to 10 listed Indian companies.\n"
            "Do NOT output markdown backticks like ```json. Output ONLY raw parseable JSON."
        )

        report_obj, engine = call_gemini_with_fallback(prompt, api_key)
        if report_obj:
            ai_reports.append(report_obj)
            print(f"✨ AI Analysis Success: {item['name']} via {engine} ({len(report_obj.get('impacted_stocks', []))} stocks)")
        else:
            print(f"❌ Failed to generate report for {item['name']}")

        time.sleep(1.2)

    return ai_reports

if __name__ == "__main__":
    api_key = os.environ.get("GEMINI_API_KEY", "").strip()

    is_api_ready = run_api_diagnostics(api_key)

    if not is_api_ready:
        print("\n🛑 Pipeline Aborted: Fix the API Key issue above to continue.")
        exit(1)

    dataset = fetch_commodity_metrics()
    if dataset:
        reports = generate_ai_research_analysis(dataset, api_key)
        if reports:
            final_data = {
                "updated_at": datetime.now().strftime("%Y-%m-%d %H:%M:%S IST"),
                "total_reports": len(reports),
                "reports": reports
            }
            with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
                json.dump(final_data, f, ensure_ascii=False, indent=2)
            print(f"\n🎉 Successfully created '{OUTPUT_FILE}' locally in repo!")
        else:
            print("\n⚠️ No reports were generated.")
