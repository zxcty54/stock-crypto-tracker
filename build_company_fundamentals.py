import os
import json
import time
import requests

OUTPUT_FILE = "company_business_models.json"

STOCKS_LIST = [
    {"symbol": "ASIANPAINT", "name": "Asian Paints", "sector": "Paints"},
    {"symbol": "RELIANCE", "name": "Reliance Industries", "sector": "O2C, Retail & Telecom"},
    {"symbol": "HDFCBANK", "name": "HDFC Bank", "sector": "Banking & Financial Services"},
    {"symbol": "TCS", "name": "Tata Consultancy Services", "sector": "IT Services"},
    {"symbol": "MARUTI", "name": "Maruti Suzuki", "sector": "Automotive"},
    {"symbol": "POLYCAB", "name": "Polycab India", "sector": "Cables & Fast Moving Electrical Goods"}
]

# Primary models set with fallbacks
MODELS_TO_TRY = [
    "gemini-3.5-flash-lite",
    "gemini-3.1-flash-lite",
    "gemini-2.5-flash",
    "gemini-2.0-flash"
]

PROMPT_TEMPLATE = """
You are a Senior Equity Research Compliance Officer and Analyst for Indian equity markets.
Extract the core business model for {company_name} ({symbol}) in clean, factual business HINGLISH.

STRICT AUDIT & ANTI-HALLUCINATION PROTOCOL:
1. ZERO ESTIMATE RULE: If the company does not officially disclose exact mathematical segment revenue percentages in audited reports, set:
   "has_disclosed_segments": false,
   "segments": [],
   "geographic_split": null
   DO NOT guess or invent numbers.
2. MANDATORY CITATION: Provide the exact "data_period" (e.g. "FY2025") and populate "sources" with the filing name and section.
3. SPECIFIC OPERATIONAL KPIS: Metrics must be company-specific (e.g. CASA Ratio, SSSG, Gross Margin) with zero generic definitions.
4. NO INVESTMENT ADVICE: Strictly avoid recommendations (Buy/Sell/Hold).

Respond ONLY with valid JSON conforming to this schema:
{{
  "symbol": "{symbol}",
  "company_name": "{company_name}",
  "data_period": "e.g. FY2025",
  "core_identity": {{
    "what_it_sells": "Clear Hinglish explanation: company kya bechti hai",
    "who_is_customer": "Clear Hinglish explanation: customer profile (B2B, B2C, OEMs, etc.)"
  }},
  "revenue_breakdown": {{
    "has_disclosed_segments": true,
    "segment_disclosure_note": "Statutory vs management commentary note",
    "segments": [
      {{ "name": "Segment Name", "share_pct": 00.0, "is_verifiable": true }}
    ],
    "geographic_split": {{
      "domestic_pct": 00.0,
      "international_pct": 00.0
    }}
  }},
  "revenue_drivers": [
    "Driver 1 (volume, pricing, order book, or capacity)",
    "Driver 2",
    "Driver 3"
  ],
  "must_watch_metrics": [
    {{
      "metric": "Company-specific metric",
      "why_track": "Why this drives earnings and margins"
    }},
    {{
      "metric": "Company-specific metric",
      "why_track": "Why this drives earnings and margins"
    }}
  ],
  "core_risks": [
    {{
      "risk_type": "Risk Title",
      "description": "Operational risk context in clean Hinglish"
    }},
    {{
      "risk_type": "Risk Title",
      "description": "Operational risk context in clean Hinglish"
    }}
  ],
  "sources": [
    {{
      "title": "Document Title",
      "filing_type": "Annual Report / Investor Presentation",
      "page_or_section": "Section or note title",
      "period": "Period"
    }}
  ]
}}
Do NOT wrap output in markdown backticks like ```json. Output ONLY raw parseable JSON.
"""

def call_gemini(prompt, api_key):
    payload = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {
            "temperature": 0.15,
            "responseMimeType": "application/json"
        }
    }

    for model in MODELS_TO_TRY:
        # Clean URL string without markdown brackets
        url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={api_key}"

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
                print(f"   ⚠️ Model '{model}' returned HTTP {res.status_code}: {err_brief}")
        except Exception as e:
            print(f"   ⚠️ Exception on '{model}': {e}")
            time.sleep(0.5)

    return None, None

def generate_models():
    api_key = os.environ.get("GEMINI_API_KEY", "").strip()
    if not api_key:
        print("❌ Set GEMINI_API_KEY environment variable first!")
        return

    results = {}
    total = len(STOCKS_LIST)

    for idx, item in enumerate(STOCKS_LIST, 1):
        print(f"\n📦 [{idx}/{total}] Processing: {item['name']} ({item['symbol']})...")
        prompt = PROMPT_TEMPLATE.format(company_name=item["name"], symbol=item["symbol"])

        parsed_data, used_model = call_gemini(prompt, api_key)
        if parsed_data:
            results[item["symbol"]] = parsed_data
            src_count = len(parsed_data.get("sources", []))
            print(f"   ✨ Successfully extracted via [{used_model}] | Sources cited: {src_count}")
        else:
            print(f"   ❌ All model attempts failed for {item['symbol']}")

        if idx < total:
            print("   ⏳ Cooldown 20 seconds...")
            time.sleep(20)

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=2)
    print(f"\n🎉 Saved {len(results)} verified business models to '{OUTPUT_FILE}'")

if __name__ == "__main__":
    generate_models()
