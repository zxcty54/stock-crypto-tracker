import os
import json
import time
from datetime import datetime
import requests

OUTPUT_FILE = "raw_material_macro_matrix.json"

# ---------------- MASTER COMMODITY & DEPENDENCY REGISTRY ----------------
RAW_MATERIALS_CONFIG = [
    {
        "id": "crude_oil",
        "name": "Crude Oil (Brent)",
        "ticker": "BZ=F",
        "unit": "USD/bbl",
        "category": "Energy & Petrochem Feedstock",
        "dependency": {
            "type": "HEAVILY_IMPORTED",
            "import_pct": 87,
            "origin": ["Russia", "Iraq", "Saudi Arabia", "UAE"],
            "currency_risk": "HIGH (USD-INR Sensitive)"
        },
        "impact_logic": "Price drop lowers solvent, monomer, and fuel cost, expanding EBITDA margins.",
        "beneficiaries": [
            {"symbol": "ASIANPAINT", "sector": "Paints", "cogs_share": "~50% raw petrochem"},
            {"symbol": "BERGEPAINT", "sector": "Paints", "cogs_share": "~50% raw petrochem"},
            {"symbol": "INDIGO", "sector": "Aviation", "cogs_share": "~40% ATF fuel"},
            {"symbol": "MRF", "sector": "Tyres", "cogs_share": "Synthetic rubber & carbon black"},
            {"symbol": "ASTRAL", "sector": "Pipes", "cogs_share": "PVC resin input"}
        ],
        "adversely_impacted_when_down": [
            {"symbol": "ONGC", "sector": "Upstream Oil", "reason": "Lower crude realization per barrel"},
            {"symbol": "OIL", "sector": "Upstream Oil", "reason": "Drop in upstream earnings"}
        ]
    },
    {
        "id": "copper",
        "name": "Refined Copper",
        "ticker": "HG=F",
        "unit": "USD/lb",
        "category": "Industrial Metals",
        "dependency": {
            "type": "HEAVILY_IMPORTED",
            "import_pct": 92,
            "origin": ["Chile", "Peru", "Australia", "Japan"],
            "currency_risk": "EXTREME (LME + Custom Duty)"
        },
        "impact_logic": "Price softening cuts direct raw material costs for wire drawing and electrical coils.",
        "beneficiaries": [
            {"symbol": "POLYCAB", "sector": "Cables & Wires", "cogs_share": "~65% copper content"},
            {"symbol": "KEI", "sector": "Cables & Wires", "cogs_share": "~60% copper & aluminium"},
            {"symbol": "HAVELLS", "sector": "Consumer Electricals", "cogs_share": "Motor windings & cables"},
            {"symbol": "VOLTAS", "sector": "Consumer Durables", "cogs_share": "Compressor & coils"}
        ],
        "adversely_impacted_when_down": [
            {"symbol": "HINDALCO", "sector": "Metals Extraction", "reason": "Lower copper smelting realization"}
        ]
    },
    {
        "id": "iron_ore",
        "name": "Iron Ore 62% Fe (Proxy)",
        "ticker": "TIO=F",
        "unit": "USD/dmt",
        "category": "Steel Feedstock",
        "dependency": {
            "type": "INDIGENOUS_DOMESTIC",
            "import_pct": 0,
            "origin": ["Odisha", "Chhattisgarh", "Karnataka (NMDC/OMC)"],
            "currency_risk": "LOW (Domestic NMDC Circular Pricing)"
        },
        "impact_logic": "Drop in iron ore reduces input cost for non-integrated secondary steel and auto parts.",
        "beneficiaries": [
            {"symbol": "MARUTI", "sector": "Automobiles", "cogs_share": "Sheet metal & casting inputs"},
            {"symbol": "TATAMOTORS", "sector": "Commercial Vehicles", "cogs_share": "Heavy chassis & body steel"},
            {"symbol": "LT", "sector": "Infrastructure", "cogs_share": "Reinforcement rebar & structural steel"}
        ],
        "adversely_impacted_when_down": [
            {"symbol": "NMDC", "sector": "Mining", "reason": "Direct drop in monthly lump/fines prices"},
            {"symbol": "TATASTEEL", "sector": "Integrated Steel", "reason": "Global steel realization price drops"}
        ]
    },
    {
        "id": "natural_gas",
        "name": "Natural Gas (Henry Hub Proxy)",
        "ticker": "NG=F",
        "unit": "USD/MMBtu",
        "category": "Fuel & Chemical Feedstock",
        "dependency": {
            "type": "PARTIALLY_IMPORTED",
            "import_pct": 52,
            "origin": ["Qatar", "UAE", "USA (Spot LNG)"],
            "currency_risk": "HIGH (Spot LNG volatility)"
        },
        "impact_logic": "Cheaper gas lowers kiln firing and reforming power costs drastically.",
        "beneficiaries": [
            {"symbol": "KAJARIACER", "sector": "Ceramic Tiles", "cogs_share": "~30% fuel & gas expenses"},
            {"symbol": "CHAMBLFERT", "sector": "Fertilizers", "cogs_share": "Feedstock for Urea/Ammonia"},
            {"symbol": "IGL", "sector": "City Gas", "cogs_share": "Sourcing gas cost drops"}
        ],
        "adversely_impacted_when_down": [
            {"symbol": "GAIL", "sector": "Gas Transmission", "reason": "Lesser marketing & transmission tariff margins"}
        ]
    },
    {
        "id": "aluminium",
        "name": "Aluminium (Primary)",
        "ticker": "ALI=F",
        "unit": "USD/MT",
        "category": "Industrial Metals",
        "dependency": {
            "type": "INDIGENOUS_DOMESTIC",
            "import_pct": 5,
            "origin": ["Odisha", "Gujarat (Nalco, Hindalco)"],
            "currency_risk": "MEDIUM (Domestic USD parity)"
        },
        "impact_logic": "Fall in metal cuts bill-of-materials for auto castings, foils, and packaging.",
        "beneficiaries": [
            {"symbol": "DIXON", "sector": "Electronics Manufacturing", "cogs_share": "Enclosures & heat sinks"},
            {"symbol": "SUBROS", "sector": "Auto Ancillary", "cogs_share": "Condensers & HVAC radiators"},
            {"symbol": "BAJAJ-AUTO", "sector": "2-Wheelers", "cogs_share": "Alloy wheels & engine blocks"}
        ],
        "adversely_impacted_when_down": [
            {"symbol": "NATIONALUM", "sector": "Alumina Extraction", "reason": "Lower export realization"}
        ]
    },
    {
        "id": "cotton",
        "name": "Cotton (Raw Fibres)",
        "ticker": "CT=F",
        "unit": "USc/lb",
        "category": "Agri Feedstock",
        "dependency": {
            "type": "INDIGENOUS_DOMESTIC",
            "import_pct": 4,
            "origin": ["Gujarat", "Maharashtra", "Telangana"],
            "currency_risk": "LOW (Monsoon & MSP sensitive)"
        },
        "impact_logic": "Price softening benefits spinning and garmenting mills with low raw inventory cost.",
        "beneficiaries": [
            {"symbol": "PAGEIND", "sector": "Innerwear & Apparel", "cogs_share": "Combed cotton yarn"},
            {"symbol": "TRIDENT", "sector": "Home Textiles", "cogs_share": "Raw lint for yarn spinning"},
            {"symbol": "KPRMILL", "sector": "Apparel & Textiles", "cogs_share": "Integrated cotton spinning"}
        ],
        "adversely_impacted_when_down": []
    }
]

def calculate_returns(closes):
    cur = closes[-1]
    p_1m = closes[-22] if len(closes) >= 22 else closes[0]
    p_6m = closes[-126] if len(closes) >= 126 else closes[0]
    p_1y = closes[-252] if len(closes) >= 252 else closes[0]
    p_3y = closes[0]

    def delta(curr, past):
        return round(((curr - past) / past) * 100, 2)

    return {
        "1M": delta(cur, p_1m),
        "6M": delta(cur, p_6m),
        "1Y": delta(cur, p_1y),
        "3Y": delta(cur, p_3y)
    }

def run_raw_material_pipeline():
    headers = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"}
    processed_records = []

    print("=" * 75)
    print("🌍 Scraping Raw Material Benchmarks & Indian Industry Impact Matrix...")
    print("=" * 75)

    for item in RAW_MATERIALS_CONFIG:
        ticker = item["ticker"]
        url = f"https://query1.finance.yahoo.com/v8/finance/chart/{ticker}?range=3y&interval=1d"

        try:
            res = requests.get(url, headers=headers, timeout=12)
            if res.status_code != 200:
                print(f"⚠️ Failed for {item['name']} (HTTP {res.status_code})")
                continue

            data = res.json()
            result = data.get("chart", {}).get("result", [])[0]
            closes = [c for c in result.get("indicators", {}).get("quote", [])[0].get("close", []) if c is not None]

            if not closes:
                continue

            current_rate = round(closes[-1], 2)
            returns = calculate_returns(closes)

            # 6-Month trend direction
            is_falling = returns["6M"] < 0
            trend_label = "COOLING (Margin Positive)" if is_falling else "HEATING UP (Margin Drag)"

            record = {
                "id": item["id"],
                "name": item["name"],
                "category": item["category"],
                "benchmark_ticker": item["ticker"],
                "unit": item["unit"],
                "current_price": current_rate,
                "trend_status": trend_label,
                "multi_period_trend": returns,
                "sourcing_profile": item["dependency"],
                "impact_analysis": {
                    "logic": item["impact_logic"],
                    "favorable_stocks": item["beneficiaries"],
                    "margin_drag_stocks": item["adversely_impacted_when_down"]
                }
            }

            processed_records.append(record)
            print(f"✅ {item['name']:<24} | Price: {current_rate:>8} {item['unit']:<8} | 6M: {returns['6M']:>6}% | 1Y: {returns['1Y']:>6}%")
            time.sleep(0.4)

        except Exception as e:
            print(f"❌ Error processing {item['name']}: {e}")

    final_payload = {
        "generated_at": datetime.now().strftime("%Y-%m-%d %H:%M:%S IST"),
        "total_commodities_tracked": len(processed_records),
        "materials": processed_records
    }

    # Clean local save with indent=2 (GitHub UI rendering friendly)
    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(final_payload, f, ensure_ascii=False, indent=2)

    print("=" * 75)
    print(f"💾 File Saved Locally: '{OUTPUT_FILE}' ({len(processed_records)} commodities)")
    print("=" * 75)

if __name__ == "__main__":
    run_raw_material_pipeline()
