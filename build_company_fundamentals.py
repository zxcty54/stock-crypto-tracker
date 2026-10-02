import os
import json
import time
import requests
import pandas as pd
import yfinance as yf
from datetime import datetime

OUTPUT_FILE = "company_business_models.json"

STOCKS_LIST = [
    {"symbol": "ASIANPAINT", "ticker": "ASIANPAINT.NS", "name": "Asian Paints Limited", "sector": "Manufacturing - Paints & Home Decor", "sector_type": "MANUFACTURING"},
    {"symbol": "RELIANCE", "ticker": "RELIANCE.NS", "name": "Reliance Industries Limited", "sector": "Conglomerate - Energy, Retail & Telecom", "sector_type": "CONGLOMERATE"},
    {"symbol": "HDFCBANK", "ticker": "HDFCBANK.NS", "name": "HDFC Bank Limited", "sector": "Banking & Financial Services", "sector_type": "BANKING"},
    {"symbol": "TCS", "ticker": "TCS.NS", "name": "Tata Consultancy Services Limited", "sector": "IT Services & Consulting", "sector_type": "IT_SERVICES"},
    {"symbol": "MARUTI", "ticker": "MARUTI.NS", "name": "Maruti Suzuki India Limited", "sector": "Manufacturing - Automotive", "sector_type": "MANUFACTURING"},
    {"symbol": "POLYCAB", "ticker": "POLYCAB.NS", "name": "Polycab India Limited", "sector": "Manufacturing - Cables & FMEG", "sector_type": "MANUFACTURING"}
]

# Comprehensive Macro Tickers (Commodities + Currencies + Interest Rates)
MACRO_TICKERS = [
    # 1. Industrial Commodities (For Manufacturing & Auto)
    {"id": "brent_crude", "name": "Brent Crude Oil", "ticker": "BZ=F", "unit": "USD/bbl", "category": "COMMODITY", "impact_sectors": "Paints, Petrochemicals, Tyres, Aviation"},
    {"id": "copper", "name": "Refined Copper", "ticker": "HG=F", "unit": "USD/lb", "category": "COMMODITY", "impact_sectors": "Cables & Wires, Electricals, Auto, Capital Goods"},
    {"id": "natural_gas", "name": "Natural Gas", "ticker": "NG=F", "unit": "USD/MMBtu", "category": "COMMODITY", "impact_sectors": "Fertilizers, Ceramics, City Gas Distribution"},
    {"id": "aluminium", "name": "Aluminium", "ticker": "ALI=F", "unit": "USD/MT", "category": "COMMODITY", "impact_sectors": "Automotive Ancillary, Packaging, White Goods"},
    {"id": "cotton", "name": "Cotton", "ticker": "CT=F", "unit": "USc/lb", "category": "COMMODITY", "impact_sectors": "Textiles, Apparel, Yarn Mills"},
    {"id": "iron_ore", "name": "Iron Ore Proxy", "ticker": "TIO=F", "unit": "USD/dmt", "category": "COMMODITY", "impact_sectors": "Steel, Infrastructure, Commercial Vehicles"},
    
    # 2. Currency & Global Exposure (Crucial for IT Services & Exporters)
    {"id": "usd_inr", "name": "USD-INR Currency Pair", "ticker": "USDINR=X", "unit": "INR/USD", "category": "CURRENCY", "impact_sectors": "IT Services, Pharma, Importers & Exporters"},
    
    # 3. Sovereign Yields (Crucial for Banking & Cost of Capital)
    {"id": "us_10y_yield", "name": "US 10-Year Bond Yield", "ticker": "^TNX", "unit": "%", "category": "YIELD", "impact_sectors": "Banking, Global Capital Flows, Tech Valuations"}
]

MODELS_TO_TRY = [
    "gemini-3.5-flash-lite",
    "gemini-3.1-flash-lite"
]

# ==============================================================================
# 1. UNIFIED MACRO LAYER (COMMODITIES + FX + RATES)
# ==============================================================================

def fetch_unified_macro_dashboard():
    """
    yfinance se Commodities, USD-INR aur Yields ka 1Y YoY aur multi-period snapshot extract karta hai.
    """
    print("\n" + "=" * 75)
    print("🌍 Step 1: Gathering Unified Macro Dashboard (Commodities + FX + Rates)...")
    print("=" * 75)

    macro_data = {}

    for item in MACRO_TICKERS:
        ticker = item["ticker"]
        name = item["name"]
        try:
            t = yf.Ticker(ticker)
            hist = t.history(period="1y")

            if hist is None or hist.empty or len(hist) < 20:
                print(f"   ⚠️ Incomplete data for {name} ({ticker})")
                continue

            current_val = round(float(hist['Close'].iloc[-1]), 2)
            p_1m = round(float(hist['Close'].iloc[-22]), 2) if len(hist) >= 22 else float(hist['Close'].iloc[0])
            p_6m = round(float(hist['Close'].iloc[-126]), 2) if len(hist) >= 126 else float(hist['Close'].iloc[0])
            p_1y = round(float(hist['Close'].iloc[0]), 2)

            high_52w = round(float(hist['High'].max()), 2)
            low_52w = round(float(hist['Low'].min()), 2)

            def pct(latest, past):
                return round(((latest - past) / past) * 100, 2)

            macro_data[item["id"]] = {
                "name": name,
                "ticker": ticker,
                "category": item["category"],
                "unit": item["unit"],
                "relevant_sectors": item["impact_sectors"],
                "current_value": current_val,
                "fifty_two_week_low": low_52w,
                "fifty_two_week_high": high_52w,
                "deltas": {
                    "1M": pct(current_val, p_1m),
                    "6M": pct(current_val, p_6m),
                    "1Y_YoY": pct(current_val, p_1y)
                }
            }
            print(f"   ✅ [{item['category']:<9}] {name:<22}: {current_val:>8} {item['unit']:<8} | 1Y YoY: {macro_data[item['id']]['deltas']['1Y_YoY']:>6}%")
            time.sleep(0.3)
        except Exception as e:
            print(f"   ❌ Error fetching {name}: {e}")

    return macro_data

# ==============================================================================
# 2. STRICT AUDITED FINANCIALS EXTRACTION (WITH EMPLOYEE EXPENSE FOR IT)
# ==============================================================================

def fetch_latest_audited_financials(ticker_symbol):
    """
    yfinance se latest annual statements extract karta hai,
    descending date sort karke most recent period pakadta hai,
    aur exact Indian Financial Year (FY) calculate karta hai.
    """
    try:
        t = yf.Ticker(ticker_symbol)
        income_stmt = t.financials
        balance_sheet = t.balance_sheet
        cash_flow = t.cashflow

        if income_stmt is None or income_stmt.empty:
            return None

        # Descending date sorting
        sorted_dates = sorted(income_stmt.columns, reverse=True)
        latest_date = sorted_dates[0]
        latest_date_dt = pd.to_datetime(latest_date)
        latest_date_str = latest_date_dt.strftime("%Y-%m-%d")

        filing_year = latest_date_dt.year
        filing_month = latest_date_dt.month

        if filing_month <= 3:
            fy_label = f"FY{filing_year}"
        else:
            fy_label = f"FY{filing_year + 1}"

        days_old = (datetime.now() - latest_date_dt).days
        is_stale = days_old > 550

        latest_income = income_stmt[latest_date]
        latest_balance = balance_sheet[latest_date] if balance_sheet is not None and latest_date in balance_sheet else None
        latest_cf = cash_flow[latest_date] if cash_flow is not None and latest_date in cash_flow else None

        def extract_row(series, search_keys):
            if series is None or series.empty:
                return 0.0
            for idx in series.index:
                idx_str = str(idx).lower()
                if any(k.lower() in idx_str for k in search_keys):
                    val = series.loc[idx]
                    return float(val) if pd.notna(val) else 0.0
            return 0.0

        revenue = extract_row(latest_income, ["total revenue", "operating revenue"])
        gross_profit = extract_row(latest_income, ["gross profit"])
        net_income = extract_row(latest_income, ["net income", "net profit"])
        operating_cf = extract_row(latest_cf, ["operating cash flow", "cash from operations"])
        total_debt = extract_row(latest_balance, ["total debt"])
        equity = extract_row(latest_balance, ["stockholders equity", "common stock equity"])
        
        # 🎯 Key metric for IT/Services: Employee Benefit Expense / Staff Cost
        employee_cost = extract_row(latest_income, ["employee benefit", "salaries", "staff cost", "personnel"])

        gross_margin = round((gross_profit / revenue) * 100, 2) if revenue > 0 and gross_profit > 0 else "N/A"
        net_margin = round((net_income / revenue) * 100, 2) if revenue > 0 else "N/A"
        debt_to_equity = round(total_debt / equity, 2) if equity > 0 else 0.0
        employee_cost_pct = round((employee_cost / revenue) * 100, 2) if revenue > 0 and employee_cost > 0 else "N/A"

        return {
            "financial_year": fy_label,
            "period_end_date": latest_date_str,
            "is_stale": is_stale,
            "days_old": days_old,
            "currency": "INR",
            "revenue_cr": round(revenue / 1e7, 2),
            "gross_profit_cr": round(gross_profit / 1e7, 2),
            "employee_cost_cr": round(employee_cost / 1e7, 2),
            "employee_cost_pct": f"{employee_cost_pct}%" if employee_cost_pct != "N/A" else "N/A",
            "operating_cash_flow_cr": round(operating_cf / 1e7, 2),
            "net_profit_cr": round(net_income / 1e7, 2),
            "gross_margin_pct": f"{gross_margin}%" if gross_margin != "N/A" else "N/A",
            "net_margin_pct": f"{net_margin}%" if net_margin != "N/A" else "N/A",
            "debt_to_equity": debt_to_equity
        }

    except Exception as e:
        print(f"   ⚠️ yfinance error for {ticker_symbol}: {e}")
        return None

# ==============================================================================
# 3. SECTOR-AWARE PROMPT TEMPLATE (DYNAMIC ROUTING)
# ==============================================================================

PROMPT_TEMPLATE = """
You are a Lead Equity Research Compliance Officer & Senior Sector Analyst for Indian equity markets.
Analyze {company_name} (NSE: {symbol}) categorized as [{sector} - Type: {sector_type}] using verified statutory figures and global macro conditions:

--- VERIFIED LATEST AUDITED STATEMENTS ---
Financial Period: {financial_year} (Audited Year Ended: {period_end_date})
Total Revenue: INR {revenue_cr} Cr
Gross Margin: {gross_margin_pct}
Employee Cost: INR {employee_cost_cr} Cr ({employee_cost_pct} of Revenue)
Operating Cash Flow: INR {operating_cash_flow_cr} Cr
Net Profit: INR {net_profit_cr} Cr
Debt to Equity: {debt_to_equity}
------------------------------------------

--- UNIFIED GLOBAL MACRO DASHBOARD (COMMODITIES, FX, YIELDS) ---
{macro_context}
----------------------------------------------------------------

Extract the business model in clean, factual business HINGLISH.

STRICT AUDIT & SECTOR-SPECIFIC EVALUATION PROTOCOL:
1. ANCHOR TO GIVEN FINANCIAL YEAR: "data_period" must be strictly set to "{financial_year} (Audited)".
2. ZERO ESTIMATE RULE: If sub-segment percentages are not officially disclosed in statutory Ind AS 108 notes, set "has_disclosed_segments": false, "segments": [], "geographic_split": null. DO NOT guess numbers.
3. DYNAMIC SECTOR DRIVER ROUTING:
   - IF {sector_type} == "IT_SERVICES":
     * DO NOT CITE COMMODITIES. Software engineers and currency are the primary drivers.
     * Set "linked_primary_driver": "USD-INR Currency Pair & Employee Cost Pool"
     * Evaluate how the 1-Year USD-INR trend impacts billings vs domestic wage inflation (Employee Cost: {employee_cost_pct}).
     * Evaluate client discretionary spend risk (US BFSI & Tech enterprise budgets).
   - IF {sector_type} == "BANKING":
     * DO NOT CITE COMMODITIES.
     * Set "linked_primary_driver": "Cost of Funds, CASA Deposits & Bond Yields"
     * Evaluate credit growth, Net Interest Margin (NIM) sensitivity, and yield dynamics.
   - IF {sector_type} == "MANUFACTURING" or "CONGLOMERATE":
     * Match to the relevant input commodity (e.g. Brent Crude for Paints/O2C, Copper for Cables, Aluminium for Auto).
     * Compare 1Y YoY commodity price movement against the company's Gross Margin ({gross_margin_pct}) to evaluate cost pass-through speed and pricing power.
4. CASH QUALITY: Evaluate whether Net Profit converts into real Operating Cash Flow (OCF vs Net Profit).
5. NO TRADING ADVICE: Strictly avoid Buy/Sell/Hold recommendations.

Respond ONLY with valid JSON conforming to this schema:
{{
  "symbol": "{symbol}",
  "company_name": "{company_name}",
  "data_period": "{financial_year} (Audited)",
  "period_end_date": "{period_end_date}",
  "core_identity": {{
    "what_it_sells": "Clear Hinglish line: company kya bechti hai ya service deti hai",
    "who_is_customer": "Customer profile (B2C, B2B, US/EU Enterprises, OEMs, etc.)"
  }},
  "economic_moat": {{
    "moat_type": "Distribution / Switching Cost / Cost Advantage / Brand / Client Stickiness",
    "moat_description": "2-line operational explanation in Hinglish"
  }},
  "pricing_power_index": {{
    "rating": "HIGH / MEDIUM / LOW",
    "linked_primary_driver": "Relevant Commodity (for Manufacturing) OR USD-INR / Cost of Funds (for IT/Banking)",
    "pass_through_speed": "Estimated days to pass inflation or adjust billing rates",
    "rationale": "In-depth sector-specific Hinglish explanation comparing margins/costs against relevant macro trend"
  }},
  "cash_flow_health": {{
    "working_capital_nature": "Negative / Lean / Heavy Working Capital",
    "operating_cash_vs_profit": "Comparison in Hinglish (OCF vs Net Profit quality)",
    "free_cash_flow_quality": "High / Medium / Low"
  }},
  "revenue_breakdown": {{
    "has_disclosed_segments": true,
    "segment_disclosure_note": "Statutory reporting under Ind AS 108",
    "segments": [
      {{ "name": "Segment Name", "share_pct": 00.0, "is_verifiable": true }}
    ],
    "geographic_split": {{
      "domestic_pct": 00.0,
      "international_pct": 00.0
    }}
  }},
  "revenue_drivers": [
    "Driver 1 (volume, billing realization, order book, or capacity)",
    "Driver 2",
    "Driver 3"
  ],
  "must_watch_metrics": [
    {{
      "metric": "Company/Sector specific metric (e.g. Volume Growth for Paints, Utilization/Attrition for IT, NIM/NPA for Banks)",
      "benchmark_normal": "Healthy target range",
      "why_track": "Why this specific KPI drives valuation"
    }},
    {{
      "metric": "Company/Sector specific metric",
      "benchmark_normal": "Healthy target range",
      "why_track": "Why this specific KPI drives valuation"
    }}
  ],
  "anti_thesis_trigger": "Specific sector disruption, currency shift, or raw material surge that breaks the investment thesis",
  "core_risks": [
    {{
      "risk_type": "Macro or Input Cost Risk",
      "description": "Specific operational risk in Hinglish (commodity inflation for Mfg, wage hike/US slowdown for IT, NPA spike for Bank)"
    }},
    {{
      "risk_type": "Competitive or Structural Risk",
      "description": "Specific business risk in Hinglish"
    }}
  ],
  "sources": [
    {{
      "title": "{company_name} Annual Report {financial_year}",
      "filing_type": "Audited Statutory Annual Filing",
      "page_or_section": "Segment Information (Ind AS 108) & Cash Flow Statement",
      "period": "{financial_year}"
    }}
  ]
}}
Do NOT wrap output in markdown backticks like ```json. Output ONLY raw parseable JSON.
"""

# ==============================================================================
# 4. GEMINI API CALLER (SAFE STRING CONCATENATION)
# ==============================================================================

def call_gemini(prompt, api_key):
    payload = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {
            "temperature": 0.15,
            "responseMimeType": "application/json"
        }
    }

    scheme = "https://"
    domain = "generativelanguage.googleapis.com"
    endpoint = "/v1beta/models/"

    for model in MODELS_TO_TRY:
        url = scheme + domain + endpoint + model + ":generateContent?key=" + api_key

        try:
            res = requests.post(url, json=payload, headers={"Content-Type": "application/json"}, timeout=35)
            if res.status_code == 200:
                raw_text = res.json()["candidates"][0]["content"]["parts"][0]["text"].strip()
                if raw_text.startswith("```json"):
                    raw_text = raw_text[7:]
                if raw_text.startswith("```"):
                    raw_text = raw_text[3:]
                if raw_text.endswith("```"):
                    raw_text = raw_text[:-3]

                return json.loads(raw_text.strip()), model
            else:
                err_brief = res.text[:120].replace("\n", " ")
                print(f"   ⚠️ Model '{model}' HTTP {res.status_code}: {err_brief}")
        except Exception as e:
            print(f"   ⚠️ Exception on '{model}': {e}")
            time.sleep(0.5)

    return None, None

# ==============================================================================
# 5. MAIN BATCH PIPELINE
# ==============================================================================

def generate_models():
    api_key = os.environ.get("GEMINI_API_KEY", "").strip()
    if not api_key:
        print("❌ Set GEMINI_API_KEY environment variable first!")
        return

    # 1. Fetch Unified Macro Context (Commodities + FX + Yields)
    macro_dashboard = fetch_unified_macro_dashboard()
    macro_context_str = json.dumps(macro_dashboard, indent=2) if macro_dashboard else "Macro dashboard unavailable"

    results = {}
    total = len(STOCKS_LIST)

    print("\n" + "=" * 75)
    print("🏢 Step 2: Processing Sector-Specific Company Business Models...")
    print("=" * 75)

    for idx, item in enumerate(STOCKS_LIST, 1):
        print(f"\n📦 [{idx}/{total}] Processing: {item['name']} ({item['ticker']}) | Sector: {item['sector_type']}...")

        # 2. Fetch Latest Audited Company Financials
        fin = fetch_latest_audited_financials(item["ticker"])
        if not fin:
            print(f"   ❌ Skipping {item['symbol']} due to missing financial statement data.")
            continue

        print(f"   📊 Period Detected: {fin['financial_year']} (Ended: {fin['period_end_date']}) | Revenue: ₹{fin['revenue_cr']} Cr")

        # 3. Formulate Sector-Aware Prompt
        prompt = PROMPT_TEMPLATE.format(
            company_name=item["name"],
            symbol=item["symbol"],
            sector=item["sector"],
            sector_type=item["sector_type"],
            financial_year=fin["financial_year"],
            period_end_date=fin["period_end_date"],
            revenue_cr=fin["revenue_cr"],
            gross_margin_pct=fin["gross_margin_pct"],
            employee_cost_cr=fin["employee_cost_cr"],
            employee_cost_pct=fin["employee_cost_pct"],
            operating_cash_flow_cr=fin["operating_cash_flow_cr"],
            net_profit_cr=fin["net_profit_cr"],
            debt_to_equity=fin["debt_to_equity"],
            macro_context=macro_context_str
        )

        # 4. Synthesize via Gemini
        parsed_data, used_model = call_gemini(prompt, api_key)
        if parsed_data:
            parsed_data["audited_statement_snapshot"] = fin
            results[item["symbol"]] = parsed_data
            print(f"   ✨ Successfully extracted via [{used_model}] | Financial Year: {fin['financial_year']}")
        else:
            print(f"   ❌ Synthesis failed for {item['symbol']}")

        if idx < total:
            print("   ⏳ Cooldown 15 seconds...")
            time.sleep(15)

    # 5. Save Output
    final_output = {
        "metadata": {
            "generated_at": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "total_companies": len(results),
            "macro_snapshot": macro_dashboard
        },
        "companies": results
    }

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(final_output, f, ensure_ascii=False, indent=2)

    print(f"\n🎉 Successfully compiled {len(results)} verified business models to '{OUTPUT_FILE}'")

if __name__ == "__main__":
    generate_models()
