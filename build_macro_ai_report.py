import os
import json
import time
from datetime import datetime
import requests

OUTPUT_FILE = "macro_research_report.json"

# ==============================================================================
# 🎯 ACTIVE VALIDATED MODELS ONLY (No 404 Errors)
# ==============================================================================
CANDIDATE_MODELS = [
    "gemini-2.5-flash",
    "gemini-2.5-pro"
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
    print("⏳ Step 1: Gathering Raw Commodity Multi-Period & 52-Week Data...")
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
            quote = result.get("indicators", {}).get("quote", [])[0]

            closes = [c for c in quote.get("close", []) if c is not None]
            highs = [h for h in quote.get("high", []) if h is not None]
            lows = [l for l in quote.get("low", []) if l is not None]

            if not closes:
                continue

            current_price = round(closes[-1], 2)
            p_1m = closes[-22] if len(closes) >= 22 else closes[0]
            p_6m = closes[-126] if len(closes) >= 126 else closes[0]
            p_1y = closes[-252] if len(closes) >= 252 else closes[0]
            p_3y = closes[0]

            # 🎯 100% Real 52-Week Range (~252 trading sessions = 1 year)
            past_1y_highs = highs[-252:] if len(highs) >= 252 else highs
            past_1y_lows = lows[-252:] if len(lows) >= 252 else lows

            fifty_two_week_high = round(max(past_1y_highs), 2) if past_1y_highs else round(current_price * 1.15, 2)
            fifty_two_week_low = round(min(past_1y_lows), 2) if past_1y_lows else round(current_price * 0.85, 2)

            def pct(new, old):
                return round(((new - old) / old) * 100, 2)

            item["current_price"] = current_price
            item["fifty_two_week_low"] = fifty_two_week_low
            item["fifty_two_week_high"] = fifty_two_week_high
            item["deltas"] = {
                "1M": pct(current_price, p_1m),
                "6M": pct(current_price, p_6m),
                "1Y": pct(current_price, p_1y),
                "3Y": pct(current_price, p_3y)
            }
            gathered.append(item)
            print(f"✅ {item['name']:<22}: {current_price:>8} {item['unit']:<8} | 52W: [{fifty_two_week_low} - {fifty_two_week_high}] | 1Y: {item['deltas']['1Y']:>6}%")
            time.sleep(0.3)

        except Exception as e:
            print(f"❌ Error fetching {item['name']}: {e}")

    return gathered

def call_gemini_with_fallback(prompt, api_key):
    payload = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {
            "temperature": 0.25,
            "maxOutputTokens": 8192,
            "responseMimeType": "application/json"
        }
    }

    for model_name in CANDIDATE_MODELS:
        url = f"https://generativelanguage.googleapis.com/v1beta/models/{model_name}:generateContent?key={api_key}"
        headers = {"Content-Type": "application/json"}

        try:
            res = requests.post(url, json=payload, headers=headers, timeout=45)

            if res.status_code == 200:
                data = res.json()
                raw_text = data["candidates"][0]["content"]["parts"][0]["text"].strip()
                if raw_text.startswith("```json"):
                    raw_text = raw_text[7:]
                elif raw_text.startswith("```"):
                    raw_text = raw_text[3:]
                if raw_text.endswith("```"):
                    raw_text = raw_text[:-3]

                return json.loads(raw_text.strip()), f"{model_name} [v1beta]"
            else:
                error_detail = res.text[:220].replace("\n", " ")
                print(f"   ⚠️ HTTP {res.status_code} on {model_name} -> {error_detail}")
                time.sleep(1)

        except Exception as e:
            print(f"   ⚠️ Exception on {model_name}: {e}")
            time.sleep(1)

    return None, None

def generate_ai_research_analysis(dataset, api_key):
    print("\n" + "=" * 75)
    print("🧠 Step 2: Dedicated 1-Commodity-Per-Batch Engine (15s Cooldown)")
    print("⚡ Full 8,192 token window enabled for exhaustive Hinglish breakdown")
    print("=" * 75)

    ai_reports = []

    schema_template = """{
  "commodity_name": "__COMMODITY__",
  "unit": "__UNIT__",
  "current_price": __PRICE__,
  "fifty_two_week_low": __52W_LOW__,
  "fifty_two_week_high": __52W_HIGH__,
  "period_changes": {
    "1M": __D1M__,
    "6M": __D6M__,
    "1Y": __D1Y__,
    "3Y": __D3Y__
  },
  "margin_trajectory": "EXPANDING or CONTRACTING or NEUTRAL",
  "retail_badge": "🔴 Lagat Badhegi (Margin Pressure) or 🟢 Lagat Ghategi (Margin Rahat) or ⚪ Neutral (Santulit)",
  "macro_headline": "Comprehensive single-line institutional summary in conversational Hinglish explaining price trend and affected manufacturing sectors",
  "forward_thesis": "In-depth 3 to 4 sentences in clean Hinglish explaining the exact 45 to 90 days inventory lag, cost pass-through limitations, and how input costs will specifically impact upcoming quarterly EBITDA results (Q3/Q4)",
  "import_context": "Detailed explanation in Hinglish covering India import dependence percentage, shipping routes, currency sensitivity (USD-INR), and global supply choke points",
  "key_risk": "Deep explanation of the single largest macro or geopolitical risk factor that could disrupt this thesis",
  "impacted_stocks": [
    {
      "symbol": "NSE_SYMBOL (e.g. ASIANPAINT)",
      "company_name": "Full Company Name",
      "sector": "Sub-Sector",
      "impact_type": "POSITIVE or NEGATIVE",
      "margin_impact_bps": "-2.5% (-250 bps) or +1.8% (+180 bps)",
      "rationale": "Exhaustive multi-sentence Hinglish breakdown explaining the company's precise raw material exposure, estimated percentage share in total COGS, and why profit margins face headwinds or tailwinds",
      "business_impact": "Direct operational business reality (e.g. Raw material mahanga hone se gross margin par dabaav aayega, passing on price hikes to end-users will be delayed by 2 quarters)"
    }
  ]
}"""

    total_items = len(dataset)

    for index, item in enumerate(dataset, 1):
        print(f"\n📦 [Batch {index}/{total_items}] Running deep research for: {item['name']}...")

        prompt = (
            "You are a Senior Equity Research & Macro Strategist analyzing raw materials for Indian retail investors.\n"
            "Provide an EXHAUSTIVE, UNTRUNCATED, AND THOROUGH deep-dive analysis in conversational business HINGLISH (English script).\n\n"
            "IMPORTANT DEPTH & CONTENT RULES:\n"
            "1. DO NOT SHORTEN OR SUMMARIZE. Write full, complete, high-quality sentences for every field.\n"
            "2. EXACTLY 8 TO 10 LISTED INDIAN STOCKS: For each stock, provide detailed rationale mentioning the specific raw material derivative and its approximate percentage in cost of goods sold (COGS).\n"
            "3. NO DIRECT INVESTMENT ADVICE: Strictly avoid words like 'Buy', 'Sell', 'Hold'. Focus 100% on operational business reality, lagat (costs), and quarterly profit margin dynamics.\n"
            "4. CLEAR HINGLISH EXPLANATION: Replace complex jargon with intuitive explanations (e.g., lagat badhna, purana stock inventory, quarterly results par dabaav).\n"
            "5. PRESERVE 52-WEEK VALUES: Directly preserve the provided fifty_two_week_low and fifty_two_week_high values into the final JSON.\n\n"
            f"COMMODITY: {item['name']}\n"
            f"CURRENT PRICE: {float(item['current_price'])} {item['unit']}\n"
            f"52-WEEK RANGE: Low: {float(item['fifty_two_week_low'])}, High: {float(item['fifty_two_week_high'])}\n"
            f"MULTI-PERIOD DELTAS: 1M: {float(item['deltas']['1M'])}%, 6M: {float(item['deltas']['6M'])}%, "
            f"1Y: {float(item['deltas']['1Y'])}%, 3Y: {float(item['deltas']['3Y'])}%\n"
            f"RELEVANT SECTORS: {item['sector_relevance']}\n"
            f"SOURCING CONTEXT: {item['import_profile']}\n\n"
            "Respond ONLY with a valid JSON object matching this exact schema template:\n"
            + schema_template.replace("__COMMODITY__", str(item['name']))
                             .replace("__UNIT__", str(item['unit']))
                             .replace("__PRICE__", str(float(item['current_price'])))
                             .replace("__52W_LOW__", str(float(item['fifty_two_week_low'])))
                             .replace("__52W_HIGH__", str(float(item['fifty_two_week_high'])))
                             .replace("__D1M__", str(float(item['deltas']['1M'])))
                             .replace("__D6M__", str(float(item['deltas']['6M'])))
                             .replace("__D1Y__", str(float(item['deltas']['1Y'])))
                             .replace("__D3Y__", str(float(item['deltas']['3Y'])))
            + "\n\nDo NOT output markdown backticks like ```json. Output ONLY raw parseable JSON."
        )

        report_obj, engine = call_gemini_with_fallback(prompt, api_key)
        if report_obj:
            # Guarantee 52W numbers are present
            report_obj["fifty_two_week_low"] = float(item["fifty_two_week_low"])
            report_obj["fifty_two_week_high"] = float(item["fifty_two_week_high"])
            ai_reports.append(report_obj)
            stock_count = len(report_obj.get('impacted_stocks', []))
            print(f"   ✨ Success! Compiled report ({stock_count} stocks) using [{engine}]")
        else:
            print(f"   ❌ Failed to generate report for {item['name']}")

        if index < total_items:
            print(f"   ⏳ Batch cooldown active: Sleeping for 15 seconds...")
            time.sleep(15)

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
            print(f"\n🎉 Successfully created '{OUTPUT_FILE}' with real 52-week metrics!")
        else:
            print("\n⚠️ No reports were generated.")
