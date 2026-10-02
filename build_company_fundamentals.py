import os
import json
import time
import requests
import pandas as pd
import yfinance as yf
from datetime import datetime

OUTPUT_FILE = "company_business_models.json"

STOCKS_LIST = [
    {"symbol": "ASIANPAINT", "ticker": "ASIANPAINT.NS", "name": "Asian Paints Limited", "sector": "Paints & Home Decor"},
    {"symbol": "RELIANCE", "ticker": "RELIANCE.NS", "name": "Reliance Industries Limited", "sector": "Energy, Retail & Telecom"},
    {"symbol": "HDFCBANK", "ticker": "HDFCBANK.NS", "name": "HDFC Bank Limited", "sector": "Banking & Financial Services"},
    {"symbol": "TCS", "ticker": "TCS.NS", "name": "Tata Consultancy Services Limited", "sector": "IT Services & Consulting"},
    {"symbol": "MARUTI", "ticker": "MARUTI.NS", "name": "Maruti Suzuki India Limited", "sector": "Automotive"},
    {"symbol": "POLYCAB", "ticker": "POLYCAB.NS", "name": "Polycab India Limited", "sector": "Cables & Fast Moving Electrical Goods"}
]

MODELS_TO_TRY = [
    "gemini-3.5-flash-lite",
    "gemini-3.1-flash-lite"
]

# ==============================================================================
# 1. STRICT LATEST FINANCIAL YEAR EXTRACTION (NO STALE/OLD DATA)
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

        # 1. Strict Date Sorting (Descending: [2025-03-31, 2024-03-31, ...])
        sorted_dates = sorted(income_stmt.columns, reverse=True)
        latest_date = sorted_dates[0]
        latest_date_dt = pd.to_datetime(latest_date)
        latest_date_str = latest_date_dt.strftime("%Y-%m-%d")

        filing_year = latest_date_dt.year
        filing_month = latest_date_dt.month

        # Indian Financial Year Logic (Apr - Mar)
        if filing_month <= 3:
            fy_label = f"FY{filing_year}"
        else:
            fy_label = f"FY{filing_year + 1}"

        # 2. Staleness Guard (Alert if data is older than ~550 days)
        days_old = (datetime.now() - latest_date_dt).days
        is_stale = days_old > 550

        # 3. Column Data Extraction
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

        gross_margin = round((gross_profit / revenue) * 100, 2) if revenue > 0 and gross_profit > 0 else "N/A"
        net_margin = round((net_income / revenue) * 100, 2) if revenue > 0 else "N/A"
        debt_to_equity = round(total_debt / equity, 2) if equity > 0 else 0.0

        return {
            "financial_year": fy_label,
            "period_end_date": latest_date_str,
            "is_stale": is_stale,
            "days_old": days_old,
            "currency": "INR",
            "revenue_cr": round(revenue / 1e7, 2),
            "gross_profit_cr": round(gross_profit / 1e7, 2),
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
# 2. PROMPT TEMPLATE (STRICT AUDIT & PROVENANCE PROTOCOL)
# ==============================================================================

PROMPT_TEMPLATE = """
You are a Lead Equity Research Compliance Officer & Analyst for Indian public markets.
Analyze {company_name} (NSE: {symbol}) strictly anchored to these official financial figures extracted from statutory statements:

--- VERIFIED LATEST AUDITED STATEMENTS ---
Financial Period: {financial_year} (Audited Year Ended: {period_end_date})
Total Revenue: INR {revenue_cr} Cr
Gross Margin: {gross_margin_pct}
Operating Cash Flow: INR {operating_cash_flow_cr} Cr
Net Profit: INR {net_profit_cr} Cr
Debt to Equity: {debt_to_equity}
------------------------------------------

Extract the business model in clean, factual business HINGLISH.

STRICT AUDIT & ANTI-HALLUCINATION RULES:
1. ANCHOR TO GIVEN FINANCIAL YEAR: "data_period" must be strictly set to "{financial_year} (Audited)". Do NOT cite past years.
2. ZERO ESTIMATE RULE: If sub-segment percentages are not officially disclosed in statutory Ind AS 108 notes, set:
   "has_disclosed_segments": false,
   "segments": [],
   "geographic_split": null
   DO NOT fabricate percentages.
3. PRICING POWER: Explain whether the company can pass raw material inflation to customers based on gross margin behavior.
4. CASH QUALITY: Explain whether Net Profit converts into real Operating Cash Flow (look at OCF vs Net Profit numbers).
5. NO TRADING ADVICE: Strictly avoid Buy/Sell/Hold recommendations.

Respond ONLY with valid JSON conforming to this schema:
{{
  "symbol": "{symbol}",
  "company_name": "{company_name}",
  "data_period": "{financial_year} (Audited)",
  "period_end_date": "{period_end_date}",
  "core_identity": {{
    "what_it_sells": "Clear Hinglish line: company kya bechti hai",
    "who_is_customer": "Customer profile (B2C, B2B, OEMs, etc.)"
  }},
  "economic_moat": {{
    "moat_type": "Distribution / Switching Cost / Cost Advantage / Brand",
    "moat_description": "2-line operational explanation in Hinglish"
  }},
  "pricing_power_index": {{
    "rating": "HIGH / MEDIUM / LOW",
    "pass_through_speed": "Estimated days to pass inflation",
    "rationale": "Reason based on gross margin and competition"
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
    "Driver 1 (volume, pricing, order book, or capacity expansion)",
    "Driver 2",
    "Driver 3"
  ],
  "must_watch_metrics": [
    {{
      "metric": "Company-specific metric",
      "benchmark_normal": "Healthy target range",
      "why_track": "Why this specific KPI drives valuation"
    }},
    {{
      "metric": "Company-specific metric",
      "benchmark_normal": "Healthy target range",
      "why_track": "Why this specific KPI drives valuation"
    }}
  ],
  "anti_thesis_trigger": "Specific operational or competitive event that breaks the investment thesis",
  "core_risks": [
    {{
      "risk_type": "Risk Classification",
      "description": "Specific operational risk in Hinglish"
    }},
    {{
      "risk_type": "Risk Classification",
      "description": "Specific operational risk in Hinglish"
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
# 3. GEMINI API CALLER (SAFE STRING CONCATENATION)
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
# 4. MAIN BATCH PIPELINE
# ==============================================================================

def generate_models():
    api_key = os.environ.get("GEMINI_API_KEY", "").strip()
    if not api_key:
        print("❌ Set GEMINI_API_KEY environment variable first!")
        return

    results = {}
    total = len(STOCKS_LIST)

    for idx, item in enumerate(STOCKS_LIST, 1):
        print(f"\n📦 [{idx}/{total}] Processing: {item['name']} ({item['ticker']})...")

        # 1. Fetch Verified Audited Financials
        fin = fetch_latest_audited_financials(item["ticker"])
        if not fin:
            print(f"   ❌ Skipping {item['symbol']} due to missing financial statement data.")
            continue

        print(f"   📊 Period Detected: {fin['financial_year']} (Ended: {fin['period_end_date']}) | Revenue: ₹{fin['revenue_cr']} Cr")

        if fin["is_stale"]:
            print(f"   ⚠️ WARNING: Latest reported data is {fin['days_old']} days old.")

        # 2. Inject Verified Financials into Prompt
        prompt = PROMPT_TEMPLATE.format(
            company_name=item["name"],
            symbol=item["symbol"],
            financial_year=fin["financial_year"],
            period_end_date=fin["period_end_date"],
            revenue_cr=fin["revenue_cr"],
            gross_margin_pct=fin["gross_margin_pct"],
            operating_cash_flow_cr=fin["operating_cash_flow_cr"],
            net_profit_cr=fin["net_profit_cr"],
            debt_to_equity=fin["debt_to_equity"]
        )

        # 3. Gemini Synthesis
        parsed_data, used_model = call_gemini(prompt, api_key)
        if parsed_data:
            # Inject raw verified metrics as proof of truth
            parsed_data["audited_statement_snapshot"] = fin
            results[item["symbol"]] = parsed_data
            print(f"   ✨ Successfully extracted via [{used_model}] | Financial Year: {fin['financial_year']}")
        else:
            print(f"   ❌ Synthesis failed for {item['symbol']}")

        if idx < total:
            print("   ⏳ Cooldown 15 seconds...")
            time.sleep(15)

    # 4. Save Final JSON
    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=2)

    print(f"\n🎉 Successfully compiled {len(results)} verified business models to '{OUTPUT_FILE}'")

if __name__ == "__main__":
    generate_models()
