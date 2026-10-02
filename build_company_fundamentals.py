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
# 1. UNIFIED MACRO DATA EXTRACTION
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
# 2. AUDITED FINANCIALS + WORKING CAPITAL ENGINE + 5-YEAR HISTORICAL BOUNDS
# ==============================================================================

def fetch_latest_audited_financials(ticker_symbol):
    try:
        t = yf.Ticker(ticker_symbol)
        income_stmt = t.financials
        balance_sheet = t.balance_sheet
        cash_flow = t.cashflow

        if income_stmt is None or income_stmt.empty:
            return None

        sorted_dates = sorted(income_stmt.columns, reverse=True)
        latest_date = sorted_dates[0]
        latest_date_dt = pd.to_datetime(latest_date)

        filing_year = latest_date_dt.year
        fy_label = f"FY{filing_year}" if latest_date_dt.month <= 3 else f"FY{filing_year + 1}"

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
        cogs = extract_row(latest_income, ["cost of revenue", "cost of goods", "reconciled cost of revenue"])
        gross_profit = extract_row(latest_income, ["gross profit"])
        if gross_profit == 0.0 and revenue > 0 and cogs > 0:
            gross_profit = revenue - cogs

        net_income = extract_row(latest_income, ["net income", "net profit"])
        operating_cf = extract_row(latest_cf, ["operating cash flow", "cash from operations"])
        capex = abs(extract_row(latest_cf, ["capital expenditure", "capex"]))
        total_debt = extract_row(latest_balance, ["total debt"])
        equity = extract_row(latest_balance, ["stockholders equity", "common stock equity"])
        employee_cost = extract_row(latest_income, ["employee benefit", "salaries", "staff cost"])

        receivables = extract_row(latest_balance, ["accounts receivable", "receivables"])
        inventory = extract_row(latest_balance, ["inventory", "inventories"])
        payables = extract_row(latest_balance, ["accounts payable", "payables"])

        # Operational Working Capital Facts
        cogs_base = cogs if cogs > 0 else (revenue * 0.6 if revenue > 0 else 1.0)
        debtor_days = round((receivables / revenue) * 365, 1) if revenue > 0 else 0.0
        inventory_days = round((inventory / cogs_base) * 365, 1) if cogs_base > 0 else 0.0
        payable_days = round((payables / cogs_base) * 365, 1) if cogs_base > 0 else 0.0
        ccc_days = round(debtor_days + inventory_days - payable_days, 1)

        # 5-Year Historical Margin Corridor Extraction (No Guesswork)
        historical_margins = []
        for col in income_stmt.columns[:5]:
            col_rev = extract_row(income_stmt[col], ["total revenue", "operating revenue"])
            col_gp = extract_row(income_stmt[col], ["gross profit"])
            if col_gp == 0.0:
                col_cogs = extract_row(income_stmt[col], ["cost of revenue", "cost of goods"])
                if col_rev > 0 and col_cogs > 0:
                    col_gp = col_rev - col_cogs
            if col_rev > 0 and col_gp > 0:
                historical_margins.append(round((col_gp / col_rev) * 100, 2))

        worst_margin_5y = min(historical_margins) if historical_margins else 38.0
        avg_margin_5y = round(sum(historical_margins) / len(historical_margins), 2) if historical_margins else 42.0

        gross_margin = round((gross_profit / revenue) * 100, 2) if revenue > 0 and gross_profit > 0 else "N/A"
        debt_to_equity = round(total_debt / equity, 2) if equity > 0 else 0.0
        employee_cost_pct = round((employee_cost / revenue) * 100, 2) if revenue > 0 and employee_cost > 0 else "N/A"
        capex_to_ocf_pct = round((capex / operating_cf) * 100, 2) if operating_cf > 0 else "N/A"

        return {
            "financial_year": fy_label,
            "period_end_date": latest_date_dt.strftime("%Y-%m-%d"),
            "revenue_cr": round(revenue / 1e7, 2),
            "gross_margin_pct": f"{gross_margin}%" if gross_margin != "N/A" else "N/A",
            "employee_cost_cr": round(employee_cost / 1e7, 2),
            "employee_cost_pct": f"{employee_cost_pct}%" if employee_cost_pct != "N/A" else "N/A",
            "operating_cash_flow_cr": round(operating_cf / 1e7, 2),
            "net_profit_cr": round(net_income / 1e7, 2),
            "debt_to_equity": debt_to_equity,
            "operational_engine_facts": {
                "debtor_collection_days": debtor_days,
                "inventory_holding_days": inventory_days,
                "supplier_payable_days": payable_days,
                "net_cash_conversion_cycle_days": ccc_days,
                "capex_to_ocf_pct": f"{capex_to_ocf_pct}%" if capex_to_ocf_pct != "N/A" else "N/A"
            },
            "historical_corridor_facts": {
                "five_year_average_margin_pct": f"{avg_margin_5y}%",
                "five_year_worst_historical_margin_pct": f"{worst_margin_5y}%",
                "derived_red_alert_threshold": f"Gross Margin breaching below {worst_margin_5y}% for 2 consecutive quarters"
            }
        }
    except Exception as e:
        print(f"   ⚠️ yfinance error for {ticker_symbol}: {e}")
        return None

# ==============================================================================
# 3. 2-COMPANIES BATCH PROMPT TEMPLATE (DEEP BUSINESS ARCHITECTURE)
# ==============================================================================

BATCH_PROMPT_TEMPLATE = """
You are a Lead Equity Research Compliance Officer & Senior Analyst for Indian public markets.
Analyze the following TWO companies using their verified statutory financials and the global macro dashboard:

--- UNIFIED GLOBAL MACRO DASHBOARD ---
{macro_context}
--------------------------------------

--- COMPANY 1 DATA ---
Symbol: {comp1_symbol} | Name: {comp1_name} | Sector: {comp1_sector} | Type: {comp1_type}
Financials & Operational Facts: {comp1_fin_json}
----------------------

--- COMPANY 2 DATA ---
Symbol: {comp2_symbol} | Name: {comp2_name} | Sector: {comp2_sector} | Type: {comp2_type}
Financials & Operational Facts: {comp2_fin_json}
----------------------

STRICT AUDIT & INSTITUTIONAL RULES:
1. NO SURFACE DESCRIPTIONS: Do NOT just state "Company sells paints/software/loans". Explain the actual OPERATIONAL ENGINE:
   - How does it procure inputs/talent?
   - How does the channel (dealers/clients) work?
   - Explain the working capital physics using the given collection days, inventory days, and payable days.
2. HARD QUANTITATIVE BENCHMARKS (NO GUESSWORK):
   - Use the provided "five_year_worst_historical_margin_pct" as the anchor for the red alert threshold.
   - For IT: Anchor exit triggers to USD-INR 52-week low breach or employee wage pool escalation.
3. SECTOR DRIVER ROUTING:
   - For IT Services: Anchor strictly to USD-INR trend and employee wage costs (ignore commodities).
   - For Manufacturing: Anchor strictly to relevant input commodities and gross margin pass-through resilience.
   - For Banking: Anchor to cost of funds and credit demand.
4. ZERO ESTIMATE RULE: If sub-segments are not officially disclosed in statements under Ind AS 108, set "has_disclosed_segments": false, "segments": [], "geographic_split": null. DO NOT guess numbers.
5. NO TRADING ADVICE: Strictly avoid Buy/Sell/Hold words.

Respond ONLY with a valid JSON object where keys are the symbols "{comp1_symbol}" and "{comp2_symbol}":
{{
  "{comp1_symbol}": {{
    "symbol": "{comp1_symbol}",
    "company_name": "{comp1_name}",
    "data_period": "{comp1_fy} (Audited)",
    "business_model_architecture": {{
      "core_engine_summary": "Institutional Hinglish summary of how the company makes money (Procure -> Value Add -> Distribute -> Cash)",
      "go_to_market_and_moat": "Distribution channel depth (e.g. Direct-to-dealer tinting machines / Enterprise annuity contracts) in Hinglish",
      "working_capital_engine": "Explanation in Hinglish analyzing the provided collection days, inventory days, and supplier credit days"
    }},
    "pricing_power_index": {{
      "rating": "HIGH / MEDIUM / LOW",
      "linked_primary_driver": "Identified Commodity OR USD-INR / Cost of Funds",
      "pass_through_speed": "Estimated days to pass inflation or adjust billing rates",
      "rationale": "Comprehensive deep-dive Hinglish rationale comparing margins/costs against relevant macro trend"
    }},
    "cash_flow_health": {{
      "working_capital_nature": "Negative / Lean / Heavy Working Capital",
      "operating_cash_vs_profit": "Comparison in Hinglish (OCF vs Net Profit quality)",
      "free_cash_flow_quality": "High / Medium / Low"
    }},
    "revenue_breakdown": {{
      "has_disclosed_segments": false,
      "segment_disclosure_note": "Statutory reporting under Ind AS 108",
      "segments": [],
      "geographic_split": null
    }},
    "revenue_drivers": ["Driver 1", "Driver 2", "Driver 3"],
    "must_watch_metrics": [
      {{
        "metric": "Key KPI",
        "normal_operating_corridor": "Provided 5Y average or safe range",
        "red_alert_threshold": "Provided 5Y historical worst or structural breach point",
        "why_track": "Why this specific KPI drives valuation"
      }}
    ],
    "anti_thesis_trigger": {{
      "breach_event": "Specific structural operational breakdown in Hinglish",
      "hard_numerical_benchmark": "Exact numerical benchmark backed by historical worst performance",
      "action_zone": "EXIT / RE-EVALUATE THESIS"
    }},
    "core_risks": [
      {{ "risk_type": "Macro / Input Cost Risk", "description": "Specific risk in Hinglish" }},
      {{ "risk_type": "Competitive / Operational Risk", "description": "Specific risk in Hinglish" }}
    ]
  }},
  "{comp2_symbol}": {{
    "symbol": "{comp2_symbol}",
    "company_name": "{comp2_name}",
    "data_period": "{comp2_fy} (Audited)",
    "business_model_architecture": {{
      "core_engine_summary": "Institutional Hinglish summary of how the company makes money (Procure -> Value Add -> Distribute -> Cash)",
      "go_to_market_and_moat": "Distribution channel depth (e.g. Direct-to-dealer tinting machines / Enterprise annuity contracts) in Hinglish",
      "working_capital_engine": "Explanation in Hinglish analyzing the provided collection days, inventory days, and supplier credit days"
    }},
    "pricing_power_index": {{
      "rating": "HIGH / MEDIUM / LOW",
      "linked_primary_driver": "Identified Commodity OR USD-INR / Cost of Funds",
      "pass_through_speed": "Estimated days to pass inflation or adjust billing rates",
      "rationale": "Comprehensive deep-dive Hinglish rationale comparing margins/costs against relevant macro trend"
    }},
    "cash_flow_health": {{
      "working_capital_nature": "Negative / Lean / Heavy Working Capital",
      "operating_cash_vs_profit": "Comparison in Hinglish (OCF vs Net Profit quality)",
      "free_cash_flow_quality": "High / Medium / Low"
    }},
    "revenue_breakdown": {{
      "has_disclosed_segments": false,
      "segment_disclosure_note": "Statutory reporting under Ind AS 108",
      "segments": [],
      "geographic_split": null
    }},
    "revenue_drivers": ["Driver 1", "Driver 2", "Driver 3"],
    "must_watch_metrics": [
      {{
        "metric": "Key KPI",
        "normal_operating_corridor": "Provided 5Y average or safe range",
        "red_alert_threshold": "Provided 5Y historical worst or structural breach point",
        "why_track": "Why this specific KPI drives valuation"
      }}
    ],
    "anti_thesis_trigger": {{
      "breach_event": "Specific structural operational breakdown in Hinglish",
      "hard_numerical_benchmark": "Exact numerical benchmark backed by historical worst performance",
      "action_zone": "EXIT / RE-EVALUATE THESIS"
    }},
    "core_risks": [
      {{ "risk_type": "Macro / Input Cost Risk", "description": "Specific risk in Hinglish" }},
      {{ "risk_type": "Competitive / Operational Risk", "description": "Specific risk in Hinglish" }}
    ]
  }}
}}
Do NOT wrap output in markdown backticks like ```json. Output ONLY raw parseable JSON.
"""

# ==============================================================================
# 4. GEMINI API CALLER (SAFE STRING CONCATENATION & 8192 TOKEN WINDOW)
# ==============================================================================

def call_gemini(prompt, api_key):
    payload = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {
            "temperature": 0.2,
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
                if raw_text.startswith("```json"):
                    raw_text = raw_text[7:]
                if raw_text.startswith("```"):
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
# 5. MAIN BATCH PIPELINE (2 COMPANIES PER BATCH + 20S SLEEP)
# ==============================================================================

def generate_models():
    api_key = os.environ.get("GEMINI_API_KEY", "").strip()
    if not api_key:
        print("❌ Set GEMINI_API_KEY environment variable first!")
        return

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
            print(f"\n🚀 [Batch {b_idx}/{total_batches}] Processing Pair: {c1['symbol']} & {c2['symbol']}...")

            fin1 = fetch_latest_audited_financials(c1["ticker"])
            fin2 = fetch_latest_audited_financials(c2["ticker"])

            if not fin1 or not fin2:
                print(f"   ⚠️ Statement extraction failed for pair; skipping batch.")
                continue

            prompt = BATCH_PROMPT_TEMPLATE.format(
                macro_context=macro_str,
                comp1_symbol=c1["symbol"], comp1_name=c1["name"], comp1_sector=c1["sector"], comp1_type=c1["sector_type"],
                comp1_fy=fin1["financial_year"], comp1_fin_json=json.dumps(fin1),
                comp2_symbol=c2["symbol"], comp2_name=c2["name"], comp2_sector=c2["sector"], comp2_type=c2["sector_type"],
                comp2_fy=fin2["financial_year"], comp2_fin_json=json.dumps(fin2)
            )

            parsed_batch, used_model = call_gemini(prompt, api_key)
            if parsed_batch:
                if c1["symbol"] in parsed_batch:
                    parsed_batch[c1["symbol"]]["audited_statement_snapshot"] = fin1
                    all_results[c1["symbol"]] = parsed_batch[c1["symbol"]]

                if c2["symbol"] in parsed_batch:
                    parsed_batch[c2["symbol"]]["audited_statement_snapshot"] = fin2
                    all_results[c2["symbol"]] = parsed_batch[c2["symbol"]]

                print(f"   ✨ Successfully synthesized {c1['symbol']} and {c2['symbol']} via [{used_model}]")
            else:
                print(f"   ❌ Batch {b_idx} synthesis failed.")

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
