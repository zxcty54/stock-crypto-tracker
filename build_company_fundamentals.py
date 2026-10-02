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
# 1. UNIFIED MACRO DASHBOARD EXTRACTION
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
# 2. ZERO-GUESSWORK EXTRACTOR (Missing vs Actual 0 Distinction)
# ==============================================================================

def extract_metric(series, search_keys):
    """
    Returns float value if found.
    Returns None if metric is not disclosed (NO DEFAULT ZERO).
    """
    if series is None or series.empty:
        return None
    for idx in series.index:
        idx_str = str(idx).lower()
        if any(k.lower() in idx_str for k in search_keys):
            val = series.loc[idx]
            if pd.notna(val):
                return float(val)
    return None

def fetch_sector_specific_financials(ticker_symbol, sector_type):
    """
    Extracts strictly disclosed statutory items.
    Sector-specific: No inventory days for Banks/IT, no loan metrics for Mfg.
    """
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

        # Universal Metrics
        revenue = extract_metric(latest_income, ["total revenue", "operating revenue", "interest income"])
        net_income = extract_metric(latest_income, ["net income", "net profit"])
        operating_cf = extract_metric(latest_cf, ["operating cash flow", "cash from operations"])
        capex = extract_metric(latest_cf, ["capital expenditure", "capex"])
        total_debt = extract_metric(latest_balance, ["total debt"])
        equity = extract_metric(latest_balance, ["stockholders equity", "common stock equity"])

        base_report = {
            "financial_year": fy_label,
            "period_end_date": latest_date_dt.strftime("%Y-%m-%d"),
            "revenue_cr": round(revenue / 1e7, 2) if revenue is not None else "Disclosed Nahi Hai",
            "net_profit_cr": round(net_income / 1e7, 2) if net_income is not None else "Disclosed Nahi Hai",
            "operating_cash_flow_cr": round(operating_cf / 1e7, 2) if operating_cf is not None else "Disclosed Nahi Hai",
            "debt_to_equity": round(total_debt / equity, 2) if (total_debt is not None and equity is not None and equity > 0) else "Disclosed Nahi Hai",
            "capex_cr": round(abs(capex) / 1e7, 2) if capex is not None else "Disclosed Nahi Hai"
        }

        # -------------------------------------------------------------
        # SECTOR SPECIFIC EXTRACTION
        # -------------------------------------------------------------
        if sector_type in ["MANUFACTURING", "CONGLOMERATE"]:
            cogs = extract_metric(latest_income, ["cost of revenue", "cost of goods", "reconciled cost of revenue"])
            gross_profit = extract_metric(latest_income, ["gross profit"])
            if gross_profit is None and revenue is not None and cogs is not None:
                gross_profit = revenue - cogs

            receivables = extract_metric(latest_balance, ["accounts receivable", "receivables"])
            inventory = extract_metric(latest_balance, ["inventory", "inventories"])
            payables = extract_metric(latest_balance, ["accounts payable", "payables"])

            # Strict Calculation: Agar data missing hai, toh "Disclosed Nahi Hai"
            gm_pct = round((gross_profit / revenue) * 100, 2) if (revenue and gross_profit and revenue > 0) else "Disclosed Nahi Hai"
            debtor_days = round((receivables / revenue) * 365, 1) if (revenue and receivables and revenue > 0) else "Disclosed Nahi Hai"
            inv_days = round((inventory / cogs) * 365, 1) if (cogs and inventory and cogs > 0) else "Disclosed Nahi Hai"
            pay_days = round((payables / cogs) * 365, 1) if (cogs and payables and cogs > 0) else "Disclosed Nahi Hai"

            ccc = "Disclosed Nahi Hai"
            if isinstance(debtor_days, (int, float)) and isinstance(inv_days, (int, float)) and isinstance(pay_days, (int, float)):
                ccc = round(debtor_days + inv_days - pay_days, 1)

            # 5-Year Historical Gross Margin Corridor (Actual Data Only)
            historical_margins = []
            for col in income_stmt.columns[:5]:
                col_rev = extract_metric(income_stmt[col], ["total revenue", "operating revenue"])
                col_gp = extract_metric(income_stmt[col], ["gross profit"])
                if col_gp is None:
                    col_cogs = extract_metric(income_stmt[col], ["cost of revenue", "cost of goods"])
                    if col_rev and col_cogs:
                        col_gp = col_rev - col_cogs
                if col_rev and col_gp and col_rev > 0:
                    historical_margins.append(round((col_gp / col_rev) * 100, 2))

            historical_facts = {
                "five_year_data_available": len(historical_margins) > 0,
                "five_year_average_gross_margin": f"{round(sum(historical_margins) / len(historical_margins), 2)}%" if historical_margins else "Disclosed Nahi Hai",
                "five_year_lowest_historical_margin": f"{min(historical_margins)}%" if historical_margins else "Disclosed Nahi Hai"
            }

            base_report["manufacturing_metrics"] = {
                "gross_margin_pct": f"{gm_pct}%" if gm_pct != "Disclosed Nahi Hai" else "Disclosed Nahi Hai",
                "raw_material_cogs_cr": round(cogs / 1e7, 2) if cogs is not None else "Disclosed Nahi Hai",
                "debtor_collection_days": debtor_days,
                "inventory_holding_days": inv_days,
                "supplier_payable_days": pay_days,
                "cash_conversion_cycle_days": ccc,
                "historical_corridor": historical_facts
            }

        elif sector_type == "IT_SERVICES":
            employee_cost = extract_metric(latest_income, ["employee benefit", "salaries", "staff cost", "personnel"])
            emp_cost_pct = round((employee_cost / revenue) * 100, 2) if (revenue and employee_cost and revenue > 0) else "Disclosed Nahi Hai"
            receivables = extract_metric(latest_balance, ["accounts receivable", "receivables"])
            unbilled_rev = extract_metric(latest_balance, ["unbilled revenue", "other receivables"])
            dso_days = round((receivables / revenue) * 365, 1) if (revenue and receivables and revenue > 0) else "Disclosed Nahi Hai"

            # 5-Year Historical Operating Margin (EBIT) Corridor (Actual Data Only)
            historical_ebit_margins = []
            for col in income_stmt.columns[:5]:
                col_rev = extract_metric(income_stmt[col], ["total revenue", "operating revenue"])
                col_ebit = extract_metric(income_stmt[col], ["operating income", "ebit"])
                if col_rev and col_ebit and col_rev > 0:
                    historical_ebit_margins.append(round((col_ebit / col_rev) * 100, 2))

            base_report["it_services_metrics"] = {
                "employee_cost_cr": round(employee_cost / 1e7, 2) if employee_cost is not None else "Disclosed Nahi Hai",
                "employee_cost_pct_of_revenue": f"{emp_cost_pct}%" if emp_cost_pct != "Disclosed Nahi Hai" else "Disclosed Nahi Hai",
                "days_sales_outstanding_dso": dso_days,
                "historical_ebit_corridor": {
                    "five_year_data_available": len(historical_ebit_margins) > 0,
                    "five_year_average_ebit_margin": f"{round(sum(historical_ebit_margins) / len(historical_ebit_margins), 2)}%" if historical_ebit_margins else "Disclosed Nahi Hai",
                    "five_year_lowest_ebit_margin": f"{min(historical_ebit_margins)}%" if historical_ebit_margins else "Disclosed Nahi Hai"
                }
            }

        elif sector_type == "BANKING":
            interest_income = extract_metric(latest_income, ["interest income", "interest and dividend income"])
            interest_expense = extract_metric(latest_income, ["interest expense"])
            nii = (interest_income - interest_expense) if (interest_income and interest_expense) else None
            provisions = extract_metric(latest_income, ["provision for credit losses", "loan losses", "provisions"])
            total_deposits = extract_metric(latest_balance, ["total deposits", "deposits"])
            total_loans = extract_metric(latest_balance, ["loans and advances", "net loans", "gross loans"])

            cd_ratio = round((total_loans / total_deposits) * 100, 2) if (total_loans and total_deposits and total_deposits > 0) else "Disclosed Nahi Hai"

            base_report["banking_metrics"] = {
                "net_interest_income_cr": round(nii / 1e7, 2) if nii is not None else "Disclosed Nahi Hai",
                "loan_loss_provisions_cr": round(provisions / 1e7, 2) if provisions is not None else "Disclosed Nahi Hai",
                "total_deposits_cr": round(total_deposits / 1e7, 2) if total_deposits is not None else "Disclosed Nahi Hai",
                "total_loans_advances_cr": round(total_loans / 1e7, 2) if total_loans is not None else "Disclosed Nahi Hai",
                "credit_to_deposit_cd_ratio": f"{cd_ratio}%" if cd_ratio != "Disclosed Nahi Hai" else "Disclosed Nahi Hai"
            }

        return base_report

    except Exception as e:
        print(f"   ⚠️ Extraction error for {ticker_symbol}: {e}")
        return None

# ==============================================================================
# 3. 2-COMPANIES BATCH PROMPT TEMPLATE (FACTS-ONLY & COMPLIANT)
# ==============================================================================

BATCH_PROMPT_TEMPLATE = """
You are a Senior Equity Research Compliance Officer & Analyst for Indian markets.
Analyze the following TWO companies strictly using the provided facts and macro dashboard:

--- UNIFIED GLOBAL MACRO DASHBOARD ---
{macro_context}
--------------------------------------

--- COMPANY 1 DATA ---
Symbol: {comp1_symbol} | Name: {comp1_name} | Sector: {comp1_sector} | Type: {comp1_type}
Disclosed Financials & Operational Facts: {comp1_fin_json}
----------------------

--- COMPANY 2 DATA ---
Symbol: {comp2_symbol} | Name: {comp2_name} | Sector: {comp2_sector} | Type: {comp2_type}
Disclosed Financials & Operational Facts: {comp2_fin_json}
----------------------

STRICT ANTI-HALLUCINATION & COMPLIANCE RULES:
1. NO ESTIMATES / NO GUESSING: If any metric is marked "Disclosed Nahi Hai" or not present, explicitly state "Company ne statutory statements mein disclose nahi kiya hai". DO NOT assume or invent numbers.
2. NO PRICING-PASS-THROUGH GUESSES: If pass-through speed (number of days) is not disclosed in filings, state "Statutory disclosure mein pass-through days uplabdh nahi hain".
3. NO TRADING ADVICE / NO "EXIT" WORDS: Do NOT use words like "Buy", "Sell", "Exit", "Hold", "Accumulate". Use strictly institutional phrasing like "Key Monitorable Level" or "Thesis Invalidation Trigger".
4. SECTOR RELEVANCE:
   - For IT: Anchor strictly to USD-INR trend, talent wage cost ratio, and client tech spending. Do NOT mention commodities.
   - For Manufacturing: Anchor strictly to raw material trends (Crude/Metals), inventory cycle, and gross margin behavior.
   - For Banking: Anchor to NII, Credit-Deposit dynamics, and interest rates. Do NOT mention inventory or factory metrics.
5. ZERO-ESTIMATE SEGMENTS: If segments are not officially disclosed under Ind AS 108 in data, set "has_disclosed_segments": false, "segments": [], "geographic_split": null.

Respond ONLY with a valid JSON object matching this schema where keys are "{comp1_symbol}" and "{comp2_symbol}":
{{
  "{comp1_symbol}": {{
    "symbol": "{comp1_symbol}",
    "company_name": "{comp1_name}",
    "data_period": "{comp1_fy} (Audited)",
    "business_model_architecture": {{
      "operational_summary": "Factual operational summary in Hinglish explaining how value is created",
      "revenue_engine_and_channel": "Distribution and client engagement model in Hinglish",
      "capital_and_working_cycle": "Hinglish analysis grounded strictly in the disclosed sector metrics (or state 'Data available nahi hai' if undisclosed)"
    }},
    "pricing_and_margin_dynamics": {{
      "linked_macro_driver": "Identified driver (Relevant Commodity / USD-INR / Yields)",
      "pass_through_reality": "Factual statement (if days are unknown, state 'Disclosed nahi hai')",
      "margin_behavior_rationale": "Deep-dive Hinglish rationale comparing margins against recent macro trends"
    }},
    "cash_flow_quality": {{
      "operating_cash_vs_profit": "Comparison in Hinglish (OCF vs Net Profit quality)",
      "free_cash_flow_profile": "High / Medium / Low / Data Available Nahi Hai"
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
        "metric": "Key Sector KPI",
        "historical_benchmark": "Disclosed 5-year average or statutory target (or 'Disclosed nahi hai')",
        "caution_threshold": "Disclosed 5-year lowest or operational red-line",
        "why_track": "Why this KPI is critical in Hinglish"
      }}
    ],
    "thesis_invalidation_trigger": {{
      "event": "Operational breakdown event in Hinglish",
      "benchmark_reference": "Based on 5-year worst historical performance or 'Data Disclosed Nahi Hai'",
      "analytical_interpretation": "Thesis breach / structural margin compression"
    }},
    "core_risks": [
      {{ "risk_type": "Macro / Input Cost Risk", "description": "Specific risk in Hinglish" }},
      {{ "risk_type": "Operational / Regulatory Risk", "description": "Specific risk in Hinglish" }}
    ]
  }},
  "{comp2_symbol}": {{
    "symbol": "{comp2_symbol}",
    "company_name": "{comp2_name}",
    "data_period": "{comp2_fy} (Audited)",
    "business_model_architecture": {{
      "operational_summary": "Factual operational summary in Hinglish explaining how value is created",
      "revenue_engine_and_channel": "Distribution and client engagement model in Hinglish",
      "capital_and_working_cycle": "Hinglish analysis grounded strictly in the disclosed sector metrics (or state 'Data available nahi hai' if undisclosed)"
    }},
    "pricing_and_margin_dynamics": {{
      "linked_macro_driver": "Identified driver (Relevant Commodity / USD-INR / Yields)",
      "pass_through_reality": "Factual statement (if days are unknown, state 'Disclosed nahi hai')",
      "margin_behavior_rationale": "Deep-dive Hinglish rationale comparing margins against recent macro trends"
    }},
    "cash_flow_quality": {{
      "operating_cash_vs_profit": "Comparison in Hinglish (OCF vs Net Profit quality)",
      "free_cash_flow_profile": "High / Medium / Low / Data Available Nahi Hai"
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
        "metric": "Key Sector KPI",
        "historical_benchmark": "Disclosed 5-year average or statutory target (or 'Disclosed nahi hai')",
        "caution_threshold": "Disclosed 5-year lowest or operational red-line",
        "why_track": "Why this KPI is critical in Hinglish"
      }}
    ],
    "thesis_invalidation_trigger": {{
      "event": "Operational breakdown event in Hinglish",
      "benchmark_reference": "Based on 5-year worst historical performance or 'Data Disclosed Nahi Hai'",
      "analytical_interpretation": "Thesis breach / structural margin compression"
    }},
    "core_risks": [
      {{ "risk_type": "Macro / Input Cost Risk", "description": "Specific risk in Hinglish" }},
      {{ "risk_type": "Operational / Regulatory Risk", "description": "Specific risk in Hinglish" }}
    ]
  }}
}}
Do NOT output markdown backticks like ```json. Output ONLY raw parseable JSON.
"""

# ==============================================================================
# 4. GEMINI API CALLER (SAFE STRING CONCATENATION & 8192 TOKEN WINDOW)
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
# 5. MAIN PIPELINE (2 COMPANIES PER BATCH + 20S SLEEP)
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

            fin1 = fetch_sector_specific_financials(c1["ticker"], c1["sector_type"])
            fin2 = fetch_sector_specific_financials(c2["ticker"], c2["sector_type"])

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
