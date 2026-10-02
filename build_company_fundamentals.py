import os
import json
import time
import requests
import pandas as pd
from bs4 import BeautifulSoup
import yfinance as yf
from datetime import datetime

OUTPUT_FILE = "company_business_models.json"

STOCKS_LIST = [
    {"symbol": "ASIANPAINT", "name": "Asian Paints Limited", "sector": "Manufacturing - Paints & Home Decor", "sector_type": "MANUFACTURING"},
    {"symbol": "RELIANCE", "name": "Reliance Industries Limited", "sector": "Conglomerate - Energy, Retail & Telecom", "sector_type": "CONGLOMERATE"},
    {"symbol": "HDFCBANK", "name": "HDFC Bank Limited", "sector": "Banking & Financial Services", "sector_type": "BANKING"},
    {"symbol": "TCS", "name": "Tata Consultancy Services Limited", "sector": "IT Services & Consulting", "sector_type": "IT_SERVICES"},
    {"symbol": "MARUTI", "name": "Maruti Suzuki India Limited", "sector": "Manufacturing - Automotive", "sector_type": "MANUFACTURING"},
    {"symbol": "POLYCAB", "name": "Polycab India Limited", "sector": "Manufacturing - Cables & FMEG", "sector_type": "MANUFACTURING"}
]

MACRO_TICKERS = [
    {"id": "brent_crude", "name": "Brent Crude Oil", "ticker": "BZ=F", "unit": "USD/bbl", "category": "COMMODITY"},
    {"id": "copper", "name": "Refined Copper", "ticker": "HG=F", "unit": "USD/lb", "category": "COMMODITY"},
    {"id": "natural_gas", "name": "Natural Gas", "ticker": "NG=F", "unit": "USD/MMBtu", "category": "COMMODITY"},
    {"id": "aluminium", "name": "Aluminium", "ticker": "ALI=F", "unit": "USD/MT", "category": "COMMODITY"},
    {"id": "cotton", "name": "Cotton", "ticker": "CT=F", "unit": "USc/lb", "category": "COMMODITY"},
    {"id": "iron_ore", "name": "Iron Ore Proxy", "ticker": "TIO=F", "unit": "USD/dmt", "category": "COMMODITY"},
    {"id": "usd_inr", "name": "USD-INR Currency Pair", "ticker": "USDINR=X", "unit": "INR/USD", "category": "CURRENCY"},
    {"id": "us_10y_yield", "name": "US 10-Year Bond Yield", "ticker": "^TNX", "unit": "%", "category": "YIELD"}
]

MODELS_TO_TRY = [
    "gemini-3.5-flash-lite",
    "gemini-3.1-flash-lite"
]

# ==============================================================================
# 1. UNIFIED MACRO DASHBOARD EXTRACTION (VIA YFINANCE)
# ==============================================================================

def fetch_unified_macro_dashboard():
    dashboard = {}
    print("\n" + "=" * 75)
    print("🌍 Step 1: Gathering Macro Dashboard (Commodities + FX + Yields)...")
    print("=" * 75)

    for item in MACRO_TICKERS:
        try:
            t = yf.Ticker(item["ticker"])
            hist = t.history(period="1y")
            if hist is None or hist.empty or len(hist) < 20:
                continue

            curr = round(float(hist['Close'].iloc[-1]), 2)
            p_1m = round(float(hist['Close'].iloc[-22]), 2) if len(hist) >= 22 else float(hist['Close'].iloc[0])
            p_6m = round(float(hist['Close'].iloc[-126]), 2) if len(hist) >= 126 else float(hist['Close'].iloc[0])
            p_1y = round(float(hist['Close'].iloc[0]), 2)

            dashboard[item["id"]] = {
                "name": item["name"],
                "category": item["category"],
                "current_val": curr,
                "unit": item["unit"],
                "52w_low": round(float(hist['Low'].min()), 2),
                "52w_high": round(float(hist['High'].max()), 2),
                "deltas": {
                    "1M": round(((curr - p_1m) / p_1m) * 100, 2),
                    "6M": round(((curr - p_6m) / p_6m) * 100, 2),
                    "1Y_YoY": round(((curr - p_1y) / p_1y) * 100, 2)
                }
            }
            print(f"   ✅ [{item['category']:<9}] {item['name']:<22}: {curr:>8} {item['unit']:<8} | 1Y YoY: {dashboard[item['id']]['deltas']['1Y_YoY']:>6}%")
            time.sleep(0.2)
        except Exception as e:
            print(f"   ❌ Error fetching {item['name']}: {e}")

    return dashboard

# ==============================================================================
# 2. SCREENER.IN COMPLETE AUDITED STATEMENT SCRAPER (PURE STATUTORY IND-AS)
# ==============================================================================

def scrape_screener_full_statements(symbol):
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
    }
    
    url = f"https://www.screener.in/company/{symbol}/consolidated/"
    res = requests.get(url, headers=headers, timeout=15)
    if res.status_code != 200:
        url = f"https://www.screener.in/company/{symbol}/"
        res = requests.get(url, headers=headers, timeout=15)
        if res.status_code != 200:
            print(f"   ❌ Failed to fetch Screener page for {symbol} (HTTP {res.status_code})")
            return None

    soup = BeautifulSoup(res.text, "lxml")
    
    def parse_section_table(section_id):
        section = soup.find("section", {"id": section_id})
        if not section:
            return None
        
        table = section.find("table")
        if not table:
            return None
        
        headers_row = table.find("thead")
        if not headers_row:
            headers_row = table.find("tr")
        
        cols = [th.text.strip() for th in headers_row.find_all(["th", "td"]) if th.text.strip()]
        if not cols:
            return None
        
        years = cols[1:]
        rows_data = {}
        tbody = table.find("tbody")
        rows = tbody.find_all("tr") if tbody else table.find_all("tr")[1:]
        
        for tr in rows:
            tds = tr.find_all("td")
            if not tds or len(tds) < len(years):
                continue
            
            raw_metric_name = tds[0].text.strip().replace("+", "").replace("-", "").strip()
            metric_name = " ".join(raw_metric_name.split())
            
            values = {}
            for yr, td in zip(years, tds[1:]):
                clean_val = td.text.strip().replace(",", "").replace("%", "")
                try:
                    values[yr] = float(clean_val)
                except ValueError:
                    values[yr] = clean_val if clean_val else "Disclosed Nahi Hai"
            
            rows_data[metric_name] = values
            
        return {
            "periods": years,
            "data": rows_data
        }

    p_and_l = parse_section_table("profit-loss")
    b_sheet = parse_section_table("balance-sheet")
    c_flow = parse_section_table("cash-flow")
    ratios = parse_section_table("ratios")

    if not p_and_l or not b_sheet:
        print(f"   ⚠️️ Fundamental tables not parsed for {symbol}")
        return None

    periods = p_and_l["periods"]
    audited_periods = [p for p in periods if "TTM" not in p.upper()]
    latest_audited_period = audited_periods[-1] if audited_periods else periods[-1]

    latest_pl = {k: v.get(latest_audited_period, "Disclosed Nahi Hai") for k, v in p_and_l["data"].items()}
    latest_bs = {k: v.get(latest_audited_period, "Disclosed Nahi Hai") for k, v in b_sheet["data"].items()} if b_sheet else {}
    latest_cf = {k: v.get(latest_audited_period, "Disclosed Nahi Hai") for k, v in c_flow["data"].items()} if c_flow else {}
    latest_rt = {k: v.get(latest_audited_period, "Disclosed Nahi Hai") for k, v in ratios["data"].items()} if ratios else {}

    pl_multi_year = {k: {yr: v.get(yr) for yr in audited_periods[-5:]} for k, v in p_and_l["data"].items()}

    print(f"   ✅ Screener Scraped: Period: {latest_audited_period} | Sales: ₹{latest_pl.get('Sales', 'N/A')} Cr | Net Profit: ₹{latest_pl.get('Net Profit', 'N/A')} Cr")

    return {
        "latest_period": latest_audited_period,
        "historical_periods": audited_periods[-5:],
        "audited_latest_year": {
            "profit_and_loss": latest_pl,
            "balance_sheet": latest_bs,
            "cash_flow": latest_cf,
            "efficiency_ratios": latest_rt
        },
        "multi_year_pl_trend": pl_multi_year
    }

# ==============================================================================
# 3. 2-COMPANIES BATCH PROMPT TEMPLATE (EXHAUSTIVE AUDITED DATA PASS)
# ==============================================================================

BATCH_PROMPT_TEMPLATE = """
You are a Principal Institutional Equity Analyst at a Tier-1 Investment Bank. 
Analyze the two companies provided below. 

DO NOT JUST READ OR SUMMARIZE THE NUMBERS. The reader can already see the raw tables. 
Your job is to provide RIGOROUS OPERATIONAL & STRATEGIC ANALYSIS ("THE 'SO WHAT?' FACTOR").

--- UNIFIED GLOBAL MACRO DASHBOARD ---
{macro_context}
--------------------------------------

--- COMPANY 1: {comp1_symbol} ({comp1_name}) ---
Sector: {comp1_sector} | Type: {comp1_type} | Period: {comp1_period}
Audited Statements & Ratios:
{comp1_statements_json}
------------------------------------------------

--- COMPANY 2: {comp2_symbol} ({comp2_name}) ---
Sector: {comp2_sector} | Type: {comp2_type} | Period: {comp2_period}
Audited Statements & Ratios:
{comp2_statements_json}
------------------------------------------------

STRICT INSTITUTIONAL ANALYSIS RULES:
1. THE "SO WHAT?" MANDATE: 
   - Never say "Debtor days is 46 and Inventory days is 142".
   - Say: "142 days of inventory holding (vs historical norms) highlights channel stress / sluggish product off-take, forced by competitive price wars, but offset by strong 81-day supplier bargaining power."
   - Explain the STRATEGIC REALITY behind every metric.
2. COMPETITIVE & COMMODITY TENSION:
   - For Manufacturing: Connect Crude/Copper delta directly to gross margin defense. Are they able to hike prices, or are competitors forcing them to absorb the inflation?
   - For IT: Connect USD-INR depreciation to whether it actually protected margins against wage hikes and subcontractor leakages.
   - For Banking: Connect Loan vs Deposit growth. Is growth coming from cheap CASA or high-cost bulk deposits squeezing NIMs?
3. ZERO RECITATION OF STANDALONE FIGURES: 
   - Writing sentences like "Sales was INR X Cr and profit was INR Y Cr" is STRICTLY FORBIDDEN. Use numbers strictly as supporting evidence inside analytical arguments.
4. HONEST UNCERTAINTY:
   - Where audited disclosures do not reveal a sub-metric (e.g. unhedged currency ratio or exact pass-through days), state the analytical limitation directly rather than inventing facts.
5. NO TRADING ADVICE: Strictly avoid Buy/Sell/Exit terminology. Frame risks around "Thesis Invalidation Trigger" and "Monitorable Corridor".

Respond ONLY with a valid JSON object matching this schema where keys are "{comp1_symbol}" and "{comp2_symbol}":
{{
  "{comp1_symbol}": {{
    "symbol": "{comp1_symbol}",
    "company_name": "{comp1_name}",
    "data_period": "{comp1_period} (Audited)",
    "business_model_architecture": {{
      "operational_engine_analysis": "Analytical breakdown of the economic engine: Procurement bargaining power -> Value-addition -> Channel extraction. Why does this model generate or fail to generate high return on capital?",
      "sourcing_and_cost_defense": "Analysis of raw material/payroll pressures vs pricing power. Are margins being defended via price hikes, cost optimization, or being squeezed by input inflation?",
      "channel_moat_vulnerability": "Critical assessment of their distribution channel and customer lock-in. Where is the moat strong, and where is it vulnerable to new competitors or tech disruption?",
      "working_capital_physics": "In-depth critique of the cash conversion engine. Analyze the tension between inventory days, receivables, and payables. Is cash stuck or flowing freely?"
    }},
    "pricing_and_macro_sensitivity": {{
      "primary_macro_driver": "Identified macro benchmark (e.g. Brent Crude / USD-INR / Yields)",
      "margin_defense_capability": "HIGH / RESILIENT / COMPRESSED / WEAK",
      "strategic_rationale": "Deep institutional thesis on how recent 1-year macro movements interacted with the company's operating margin (OPM %)"
    }},
    "cash_flow_reality": {{
      "earnings_quality_assessment": "Analyze whether reported Net Profit is backed by genuine Cash Flow from Operations, or inflated by working capital build-up",
      "free_cash_flow_profile": "Self-Funding Cash Machine / Reinvestment Heavy / Capital Constrained"
    }},
    "revenue_breakdown": {{
      "has_disclosed_segments": false,
      "segment_disclosure_note": "Statutory reporting under Ind AS 108",
      "segments": [],
      "geographic_split": null
    }},
    "strategic_catalysts": [
      "Catalyst 1 (e.g. Product premiumization, capacity ramp-up, or distribution expansion)",
      "Catalyst 2",
      "Catalyst 3"
    ],
    "must_watch_metrics": [
      {{
        "metric": "Key Analytical Metric (e.g. OPM %, Inventory Holding, Debtor Days)",
        "reported_value": "Latest figure with context",
        "analytical_significance": "Why this specific number is the pulse of the company's competitive health"
      }}
    ],
    "thesis_invalidation_trigger": {{
      "structural_red_flag": "The exact operational breakdown that would prove the bull thesis is dead",
      "numerical_breach_benchmark": "Specific threshold derived from historical stress periods",
      "strategic_implication": "Loss of pricing power / commoditization of business"
    }},
    "core_risks": [
      {{ "risk_type": "Macro / Input Cost Disruption", "analysis": "Detailed strategic risk in Hinglish" }},
      {{ "risk_type": "Competitive / Structural Threat", "analysis": "Detailed competitive risk in Hinglish" }}
    ]
  }},
  "{comp2_symbol}": {{
    "symbol": "{comp2_symbol}",
    "company_name": "{comp2_name}",
    "data_period": "{comp2_period} (Audited)",
    "business_model_architecture": {{
      "operational_engine_analysis": "Analytical breakdown of the economic engine: Procurement bargaining power -> Value-addition -> Channel extraction. Why does this model generate or fail to generate high return on capital?",
      "sourcing_and_cost_defense": "Analysis of raw material/payroll pressures vs pricing power. Are margins being defended via price hikes, cost optimization, or being squeezed by input inflation?",
      "channel_moat_vulnerability": "Critical assessment of their distribution channel and customer lock-in. Where is the moat strong, and where is it vulnerable to new competitors or tech disruption?",
      "working_capital_physics": "In-depth critique of the cash conversion engine. Analyze the tension between inventory days, receivables, and payables. Is cash stuck or flowing freely?"
    }},
    "pricing_and_macro_sensitivity": {{
      "primary_macro_driver": "Identified macro benchmark (e.g. Brent Crude / USD-INR / Yields)",
      "margin_defense_capability": "HIGH / RESILIENT / COMPRESSED / WEAK",
      "strategic_rationale": "Deep institutional thesis on how recent 1-year macro movements interacted with the company's operating margin (OPM %)"
    }},
    "cash_flow_reality": {{
      "earnings_quality_assessment": "Analyze whether reported Net Profit is backed by genuine Cash Flow from Operations, or inflated by working capital build-up",
      "free_cash_flow_profile": "Self-Funding Cash Machine / Reinvestment Heavy / Capital Constrained"
    }},
    "revenue_breakdown": {{
      "has_disclosed_segments": false,
      "segment_disclosure_note": "Statutory reporting under Ind AS 108",
      "segments": [],
      "geographic_split": null
    }},
    "strategic_catalysts": [
      "Catalyst 1",
      "Catalyst 2",
      "Catalyst 3"
    ],
    "must_watch_metrics": [
      {{
        "metric": "Key Analytical Metric",
        "reported_value": "Latest figure with context",
        "analytical_significance": "Why this specific number is the pulse of the company's competitive health"
      }}
    ],
    "thesis_invalidation_trigger": {{
      "structural_red_flag": "The exact operational breakdown that would prove the bull thesis is dead",
      "numerical_breach_benchmark": "Specific threshold derived from historical stress periods",
      "strategic_implication": "Loss of pricing power / commoditization of business"
    }},
    "core_risks": [
      {{ "risk_type": "Macro / Input Cost Disruption", "analysis": "Detailed strategic risk in Hinglish" }},
      {{ "risk_type": "Competitive / Structural Threat", "analysis": "Detailed competitive risk in Hinglish" }}
    ]
  }}
}}
Do NOT wrap output in markdown backticks. Output ONLY raw parseable JSON.
"""

# ==============================================================================
# 4. GEMINI API CALLER (SAFE STRING CONCATENATION & ROBUST STRIPPING)
# ==============================================================================

def call_gemini(prompt, api_key):
    payload = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {
            "temperature": 0.15,
            "maxOutputTokens": 8192,
            "responseMimeType": "application/json"
        }
    }

    scheme = "https://"
    domain = "generativelanguage.googleapis.com"
    endpoint = "/v1beta/models/"

    for model in MODELS_TO_TRY:
        url = scheme + domain + endpoint + model + ":generateContent?key=" + api_key
        try:
            res = requests.post(url, json=payload, headers={"Content-Type": "application/json"}, timeout=55)
            if res.status_code == 200:
                raw_text = res.json()["candidates"][0]["content"]["parts"][0]["text"].strip()
                
                # Robust markdown code block stripping
                if raw_text.startswith("```json"):
                    raw_text = raw_text[7:]
                elif raw_text.startswith("```"):
                    raw_text = raw_text[3:]
                
                if raw_text.endswith("```"):
                    raw_text = raw_text[:-3]

                return json.loads(raw_text.strip()), model
            else:
                print(f"   ⚠️ Model '{model}' HTTP {res.status_code}: {res.text[:120]}")
        except Exception as e:
            print(f"   ⚠️ Exception on '{model}': {e}")
            time.sleep(0.5)

    return None, None

# ==============================================================================
# 5. MAIN PIPELINE (2 COMPANIES PER BATCH + 20S SLEEP)
# ==============================================================================

def generate_models():
    api_key = os.environ.get("GEMINI_API_KEY", "").strip()
    if not api_key:
        print("❌ Set GEMINI_API_KEY environment variable first!")
        return

    # Step 1: Fetch Macro Data
    macro_data = fetch_unified_macro_dashboard()
    macro_str = json.dumps(macro_data, indent=2)

    all_results = {}
    batch_size = 2
    batches = [STOCKS_LIST[i:i + batch_size] for i in range(0, len(STOCKS_LIST), batch_size)]
    total_batches = len(batches)

    print(f"\n📦 Starting Batch Pipeline: Total {len(STOCKS_LIST)} stocks divided into {total_batches} batches.")
    print("⏳ Interval Policy: Exact 20 seconds cooldown between batches.")

    for b_idx, batch in enumerate(batches, 1):
        if len(batch) == 2:
            c1, c2 = batch[0], batch[1]
            print(f"\n🚀 [Batch {b_idx}/{total_batches}] Scraping & Processing Pair: {c1['symbol']} & {c2['symbol']}...")

            # Step 2: Scrape Complete Screener.in Statements
            s1_data = scrape_screener_full_statements(c1["symbol"])
            time.sleep(1.0)
            s2_data = scrape_screener_full_statements(c2["symbol"])

            if not s1_data or not s2_data:
                print(f"   ⚠️ Statement scraping failed for pair; skipping batch.")
                continue

            # Step 3: Inject into Batch Prompt
            prompt = BATCH_PROMPT_TEMPLATE.format(
                macro_context=macro_str,
                comp1_symbol=c1["symbol"], comp1_name=c1["name"], comp1_sector=c1["sector"], comp1_type=c1["sector_type"],
                comp1_period=s1_data["latest_period"], comp1_statements_json=json.dumps(s1_data),
                comp2_symbol=c2["symbol"], comp2_name=c2["name"], comp2_sector=c2["sector"], comp2_type=c2["sector_type"],
                comp2_period=s2_data["latest_period"], comp2_statements_json=json.dumps(s2_data)
            )

            # Step 4: Call Gemini
            parsed_batch, used_model = call_gemini(prompt, api_key)
            if parsed_batch:
                if c1["symbol"] in parsed_batch:
                    parsed_batch[c1["symbol"]]["audited_statement_snapshot"] = s1_data["audited_latest_year"]
                    all_results[c1["symbol"]] = parsed_batch[c1["symbol"]]

                if c2["symbol"] in parsed_batch:
                    parsed_batch[c2["symbol"]]["audited_statement_snapshot"] = s2_data["audited_latest_year"]
                    all_results[c2["symbol"]] = parsed_batch[c2["symbol"]]

                print(f"   ✨ Successfully synthesized {c1['symbol']} and {c2['symbol']} via [{used_model}]")
            else:
                print(f"   ❌ Batch {b_idx} synthesis failed.")

        # Step 5: 20-second interval between batches
        if b_idx < total_batches:
            print(f"   ⏳ Batch completed. Sleeping for 20 seconds to guarantee full rate-limit headroom...")
            time.sleep(20)

    final_payload = {
        "metadata": {
            "generated_at": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "total_companies": len(all_results),
            "macro_snapshot": macro_data
        },
        "companies": all_results
    }

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(final_payload, f, ensure_ascii=False, indent=2)

    print(f"\n🎉 Successfully compiled {len(all_results)} companies across {total_batches} batches to '{OUTPUT_FILE}'!")

if __name__ == "__main__":
    generate_models()
