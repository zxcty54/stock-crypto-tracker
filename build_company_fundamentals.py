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
You are a Senior Equity Research Analyst for Indian public markets.
Analyze the following TWO companies using their COMPLETE AUDITED STATUTORY STATEMENTS from Screener.in and the Global Macro Dashboard:

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

STRICT LANGUAGE & STYLE RULES (100% EASY HINGLISH):
1. LANGUAGE TONE:
   - Output must be in clean, natural, and conversational **Hinglish** (Roman Hindi + common English business words).
   - AVOID bombastic, heavy English words (e.g. do NOT use "unassailable", "manifesting", "entrenched", "subjugation").
2. HEAVY WORD EXPLANATION RULE:
   - Agar koi zaroori financial ya business term aati hai, toh use aasan shabdon mein bracket ya short line mein explain karein.
   - Examples:
     * "Working Capital (Rozmarra ka business chalane ke liye zaroori cash)"
     * "Gross Margin / OPM (Maal bechkar factory level par bacha hua munafa)"
     * "Cash Conversion Cycle (Kaccha maal khareedne se lekar customer se paisa aane tak lagne wale din)"
     * "Pricing Power (Kaccha maal mehenga hone par grahak par daam badhane ki taakat)"
3. THE "SO WHAT?" FACTOR (ONLY ACTIONABLE ANALYSIS):
   - Sirf number repeat mat karein (e.g. do not just write "Sales itni thi aur profit itna").
   - Har number ka asar samjhayein: Company ko kahan se faayda ho raha hai aur kahan naye competitors ya mehenge crude/dollar se problem aa rahi hai.
4. ZERO GUESSWORK & NO TRADING ADVICE:
   - Agar koi data report mein nahi hai, toh seedhe likhein "Statutory statements mein yeh number disclose nahi kiya gaya hai".
   - Do NOT give Buy/Sell/Hold/Exit advice. Frame risks around "Thesis Invalidation Trigger (Kab yeh maana jaye ki company ka core business kamzor ho chuka hai)".

Respond ONLY with a valid JSON object matching this schema where keys are "{comp1_symbol}" and "{comp2_symbol}":
{{
  "{comp1_symbol}": {{
    "symbol": "{comp1_symbol}",
    "company_name": "{comp1_name}",
    "data_period": "{comp1_period} (Audited)",
    "business_model_architecture": {{
      "operational_engine_analysis": "Aasan Hinglish mein samjhayein ki company ka asli dhandha kaise chalta hai: Kaccha maal kahan se aata hai -> Factory mein kya banta hai -> Dealer tak kaise pahunchta hai aur munafa kaise nikalta hai.",
      "sourcing_and_cost_defense": "Kacche maal ki lagat aur worker cost ka aasan analysis. Kya mehengaai ka bojha company jhel rahi hai ya grahak par daal pa rahi hai?",
      "channel_moat_vulnerability": "Dukaandar/Dealer network ki taakat aur kamzori. Naye competitors ke aane se ispar kya asar pad raha hai?",
      "working_capital_physics": "Paisa kitne din kahan fasa hua hai (Inventory aur dukaandar ki udhari) aur cash smooth chal raha hai ya nahi."
    }},
    "pricing_and_macro_sensitivity": {{
      "primary_macro_driver": "Main factor (e.g. Brent Crude Oil / Dollar-Rupee / Interest Rate)",
      "margin_defense_capability": "HIGH / RESILIENT / COMPRESSED / WEAK",
      "strategic_rationale": "Crude ya Dollar ke badhne-ghatne se company ke munafe par kya asar pada, simple Hinglish mein samjhayein."
    }},
    "cash_flow_reality": {{
      "earnings_quality_assessment": "P&L ka dikhaya gaya munafa sach mein bank account mein Cash bankar aaya hai ya sirf kitabon mein credit par atka hai?",
      "free_cash_flow_profile": "Khud Se Cash Banane Wali Machine / Naye Plants Me Kharch Hone Wala / Cash Ki Tangi"
    }},
    "revenue_breakdown": {{
      "has_disclosed_segments": false,
      "segment_disclosure_note": "Statutory reporting under Ind AS 108",
      "segments": [],
      "geographic_split": null
    }},
    "strategic_catalysts": [
      "Agla Growth Driver 1 (Aasan Hinglish)",
      "Agla Growth Driver 2",
      "Agla Growth Driver 3"
    ],
    "must_watch_metrics": [
      {{
        "metric": "Key Financial Ratio (e.g. OPM % ya Inventory Days)",
        "reported_value": "Latest number context ke sath",
        "analytical_significance": "Is number ko regular track karna kyu zaroori hai (Aasan explanation)"
      }}
    ],
    "thesis_invalidation_trigger": {{
      "structural_red_flag": "Woh kaunsi sthiti hogi jisse yeh saaf ho jaye ki company ka main business model toot chuka hai?",
      "numerical_breach_benchmark": "Specific number jiske niche aane par alert hona zaroori hai",
      "strategic_implication": "Pricing power ka khatam hona / Dhandhe ka aam commodity ban jana"
    }},
    "core_risks": [
      {{ "risk_type": "Macro / Kacche Maal Ka Risk", "analysis": "Kacche maal ke daam badhne ka direct asar aasan shabdon mein" }},
      {{ "risk_type": "Competitive / Market Ka Khatra", "analysis": "Naye competitors ke aane ka asar aasan shabdon mein" }}
    ]
  }},
  "{comp2_symbol}": {{
    "symbol": "{comp2_symbol}",
    "company_name": "{comp2_name}",
    "data_period": "{comp2_period} (Audited)",
    "business_model_architecture": {{
      "operational_engine_analysis": "Aasan Hinglish mein samjhayein ki company ka asli dhandha kaise chalta hai: Kaccha maal kahan se aata hai -> Factory mein kya banta hai -> Dealer tak kaise pahunchta hai aur munafa kaise nikalta hai.",
      "sourcing_and_cost_defense": "Kacche maal ki lagat aur worker cost ka aasan analysis. Kya mehengaai ka bojha company jhel rahi hai ya grahak par daal pa rahi hai?",
      "channel_moat_vulnerability": "Dukaandar/Dealer network ki taakat aur kamzori. Naye competitors ke aane se ispar kya asar pad raha hai?",
      "working_capital_physics": "Paisa kitne din kahan fasa hua hai (Inventory aur dukaandar ki udhari) aur cash smooth chal raha hai ya nahi."
    }},
    "pricing_and_macro_sensitivity": {{
      "primary_macro_driver": "Main factor (e.g. Brent Crude Oil / Dollar-Rupee / Interest Rate)",
      "margin_defense_capability": "HIGH / RESILIENT / COMPRESSED / WEAK",
      "strategic_rationale": "Crude ya Dollar ke badhne-ghatne se company ke munafe par kya asar pada, simple Hinglish mein samjhayein."
    }},
    "cash_flow_reality": {{
      "earnings_quality_assessment": "P&L ka dikhaya gaya munafa sach mein bank account mein Cash bankar aaya hai ya sirf kitabon mein credit par atka hai?",
      "free_cash_flow_profile": "Khud Se Cash Banane Wali Machine / Naye Plants Me Kharch Hone Wala / Cash Ki Tangi"
    }},
    "revenue_breakdown": {{
      "has_disclosed_segments": false,
      "segment_disclosure_note": "Statutory reporting under Ind AS 108",
      "segments": [],
      "geographic_split": null
    }},
    "strategic_catalysts": [
      "Agla Growth Driver 1",
      "Agla Growth Driver 2",
      "Agla Growth Driver 3"
    ],
    "must_watch_metrics": [
      {{
        "metric": "Key Financial Ratio",
        "reported_value": "Latest number context ke sath",
        "analytical_significance": "Is number ko regular track karna kyu zaroori hai (Aasan explanation)"
      }}
    ],
    "thesis_invalidation_trigger": {{
      "structural_red_flag": "Woh kaunsi sthiti hogi jisse yeh saaf ho jaye ki company ka main business model toot chuka hai?",
      "numerical_breach_benchmark": "Specific number jiske niche aane par alert hona zaroori hai",
      "strategic_implication": "Pricing power ka khatam hona / Dhandhe ka aam commodity ban jana"
    }},
    "core_risks": [
      {{ "risk_type": "Macro / Kacche Maal Ka Risk", "analysis": "Kacche maal ke daam badhne ka direct asar aasan shabdon mein" }},
      {{ "risk_type": "Competitive / Market Ka Khatra", "analysis": "Naye competitors ke aane ka asar aasan shabdon mein" }}
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
