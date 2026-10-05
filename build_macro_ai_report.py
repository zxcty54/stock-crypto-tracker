import os
import json
import time
from datetime import datetime
import requests

INPUT_MODELS_FILE = "company_business_models.json"
OUTPUT_REPORT_FILE = "macro_research_report.json"

# ==============================================================================
# 🎯 AI CANDIDATE MODELS LIST (Gemini 3.7 Priority)
# ==============================================================================
CANDIDATE_MODELS = [
    "gemini-3.7-flash",
    
]

# ==============================================================================
# 🎯 17 GRANULAR SECTORS & 68 NEUTRAL CANDIDATE EQUITIES (4 PER SECTOR)
# ==============================================================================
SECTOR_REGISTRY = [
    {
        "id": "decorative_coatings",
        "name": "Decorative & Architectural Coatings",
        "benchmark_key": "brent_crude",
        "benchmark_label": "Brent Crude Oil",
        "transmission_note": "Monomers, solvents & TiO2 (~53% COGS); high inventory buffer.",
        "stocks": [
            {"symbol": "ASIANPAINT", "name": "Asian Paints Limited", "role": "Market leader in decorative paints with delayed price pass-through"},
            {"symbol": "BERGEPAINT", "name": "Berger Paints India", "role": "Decorative & protective coatings producer with aggressive dealer networks"},
            {"symbol": "KANSAINER",  "name": "Kansai Nerolac Paints", "role": "Industrial auto coatings specialist with indexed OEM contracts"},
            {"symbol": "PIDILITIND", "name": "Pidilite Industries", "role": "Adhesives & sealants brand with monopoly pricing power on VAM"}
        ]
    },
    {
        "id": "auto_tyres_rubber",
        "name": "Automotive Tyres & Synthetic Elastomers",
        "benchmark_key": "brent_crude",
        "benchmark_label": "Brent Crude Oil & Synthetic Rubber",
        "transmission_note": "Synthetic rubber, carbon black & natural rubber (~60% COGS).",
        "stocks": [
            {"symbol": "MRF",        "name": "MRF Limited", "role": "Domestic heavy radial tyre manufacturer with high retail replacement volume"},
            {"symbol": "CEATLTD",    "name": "CEAT Limited", "role": "2W & commercial tyre maker vulnerable to raw material spot spikes"},
            {"symbol": "BALKRISIND", "name": "Balkrishna Industries", "role": "Off-highway tyre exporter with global replacement margin defense"},
            {"symbol": "PCBL",       "name": "PCBL Chemical Limited", "role": "Upstream carbon black producer capturing crude feedstock spreads"}
        ]
    },
    {
        "id": "city_gas_upstream",
        "name": "City Gas Distribution & Gas Upstream",
        "benchmark_key": "natural_gas",
        "benchmark_label": "Natural Gas (Spot LNG / APM)",
        "transmission_note": "Sourcing cost for CGDs (~65% COGS) vs realization price for upstream producers.",
        "stocks": [
            {"symbol": "IGL",  "name": "Indraprastha Gas Limited", "role": "Delhi-NCR city gas distributor retaining CNG retail prices"},
            {"symbol": "MGL",  "name": "Mahanagar Gas Limited", "role": "Mumbai metropolitan city gas distributor with steady industrial demand"},
            {"symbol": "ONGC", "name": "Oil and Natural Gas Corp", "role": "Domestic natural gas & crude oil exploration producer"},
            {"symbol": "OIL",  "name": "Oil India Limited", "role": "Upstream crude & natural gas producer with regulated gas realization"}
        ]
    },
    {
        "id": "aviation_fuel_logistics",
        "name": "Aviation Logistics & Downstream Fuel",
        "benchmark_key": "brent_crude",
        "benchmark_label": "Brent Crude / ATF",
        "transmission_note": "Aviation Turbine Fuel represents 38-42% of total operational airline cost.",
        "stocks": [
            {"symbol": "INDIGO",    "name": "InterGlobe Aviation Limited", "role": "Low-cost passenger airline with fortnightly fuel burn and fare caps"},
            {"symbol": "SPICEJET",  "name": "SpiceJet Limited", "role": "Passenger airline sensitive to fuel price swings and aircraft dollar lease rentals"},
            {"symbol": "BPCL",      "name": "Bharat Petroleum Corp", "role": "Oil refiner and fuel marketing PSU capturing retail distribution margins"},
            {"symbol": "HINDPETRO", "name": "Hindustan Petroleum Corp", "role": "Downstream refining and marketing PSU with high auto fuel exposure"}
        ]
    },
    {
        "id": "specialty_chem_polymers",
        "name": "Specialty Chemicals, Phenol & Aromatics",
        "benchmark_key": "brent_crude",
        "benchmark_label": "Crude Naphtha & Benzene",
        "transmission_note": "Downstream benzene, toluene, and ethylene derivatives (~55% COGS).",
        "stocks": [
            {"symbol": "DEEPAKNTR",  "name": "Deepak Nitrite Limited", "role": "Basic intermediates & phenol-acetone spread converter"},
            {"symbol": "AARTIIND",   "name": "Aarti Industries", "role": "Benzene-based downstream specialty chemical maker with formula-linked contracts"},
            {"symbol": "NAVINFLUOR", "name": "Navin Fluorine International", "role": "High-margin fluorine specialty chemical and CDMO supplier"},
            {"symbol": "ATUL",       "name": "Atul Limited", "role": "Integrated chemical manufacturer exposed to basic chemical pricing cycles"}
        ]
    },
    {
        "id": "plastic_pipes_building_polymers",
        "name": "Plastic Pipes & Building Polymers",
        "benchmark_key": "brent_crude",
        "benchmark_label": "Crude PVC & CPVC Resins",
        "transmission_note": "Polymer resin represents 65-72% of pipe manufacturing cost.",
        "stocks": [
            {"symbol": "ASTRAL",     "name": "Astral Limited", "role": "CPVC & PVC plumbing pipe pioneer with high brand loyalty"},
            {"symbol": "SUPREMEIND", "name": "Supreme Industries", "role": "Plastic piping & molded packaging maker vulnerable to PVC destocking"},
            {"symbol": "FINPIPE",    "name": "Finolex Industries", "role": "Backward integrated PVC resin and agricultural pipe producer"},
            {"symbol": "PRINCEPIPE", "name": "Prince Pipes and Fittings", "role": "Regional & national piping manufacturer with volatile inventory spreads"}
        ]
    },
    {
        "id": "cables_and_power_wires",
        "name": "Power Transmission Cables & Building Wires",
        "benchmark_key": "copper",
        "benchmark_label": "Refined Copper & Aluminium",
        "transmission_note": "Copper & Aluminium cathodes comprise 68-72% of cable manufacturing cost.",
        "stocks": [
            {"symbol": "POLYCAB",   "name": "Polycab India Limited", "role": "Fast-moving electrical goods & cable brand with monthly price revisions"},
            {"symbol": "KEI",       "name": "KEI Industries Limited", "role": "EHV power transmission cable manufacturer with price variation clauses"},
            {"symbol": "RRKABEL",   "name": "R R Kabel Limited", "role": "Consumer wiring specialist with export presence and copper price pass-through"},
            {"symbol": "FINCABLES", "name": "Finolex Cables Limited", "role": "Electrical & telecommunication cable maker with automotive wiring exposure"}
        ]
    },
    {
        "id": "transformers_heavy_engineering",
        "name": "Heavy Electricals & Power Transformers",
        "benchmark_key": "copper",
        "benchmark_label": "Copper Winding & CRGO Steel",
        "transmission_note": "CRGO electrical steel and electrolytic copper form core cost in substation transformers.",
        "stocks": [
            {"symbol": "VOLTAMP",    "name": "Voltamp Transformers Limited", "role": "Industrial substation transformer manufacturer with fixed-price orders"},
            {"symbol": "TRITURBINE", "name": "Triveni Turbine Limited", "role": "Industrial steam turbine manufacturer with global delivery pricing power"},
            {"symbol": "SCHNEIDER",  "name": "Schneider Electric Infrastructure", "role": "Power distribution & switchgear player capturing grid capex"},
            {"symbol": "ABB",        "name": "ABB India Limited", "role": "High-efficiency robotics, motors, and electrification systems provider"}
        ]
    },
    {
        "id": "steel_structural_pipes",
        "name": "Primary Steel, Structural Tubes & Rebars",
        "benchmark_key": "iron_ore",
        "benchmark_label": "Iron Ore & Coking Coal",
        "transmission_note": "Iron ore and metallurgical coal represent ~60% of primary blast furnace steelmaking cost.",
        "stocks": [
            {"symbol": "TATASTEEL",  "name": "Tata Steel Limited", "role": "Integrated primary steelmaker with 100% captive domestic iron ore"},
            {"symbol": "JSWSTEEL",   "name": "JSW Steel Limited", "role": "Commercial steelmaker dependent on purchased iron ore and imported coking coal"},
            {"symbol": "APLAPOLLO",  "name": "APL Apollo Tubes Limited", "role": "Structural steel hollow tube maker operating on a conversion-margin model"},
            {"symbol": "JINDALSTEL", "name": "Jindal Steel & Power", "role": "Specialty plates, rails, and structural rebar producer with captive power"}
        ]
    },
    {
        "id": "aluminium_auto_castings",
        "name": "Primary Aluminium & Auto Castings",
        "benchmark_key": "aluminium",
        "benchmark_label": "Primary Aluminium Ingot",
        "transmission_note": "Aluminium ingots form direct cost base for automotive sheet metal and die-cast engine blocks.",
        "stocks": [
            {"symbol": "HINDALCO",   "name": "Hindalco Industries Limited", "role": "Integrated primary aluminium smelter and global can sheet maker (Novelis)"},
            {"symbol": "NATIONALUM", "name": "National Aluminium Co (NALCO)", "role": "Low-cost bauxite miner and primary aluminium ingot exporter"},
            {"symbol": "ENDURANCE",  "name": "Endurance Technologies", "role": "Auto die-casting and transmission component supplier to 2W/4W OEMs"},
            {"symbol": "BHARATFORG", "name": "Bharat Forge Limited", "role": "Heavy metal forging & machined components supplier to global automotive and defense"}
        ]
    },
    {
        "id": "ceramics_sanitaryware",
        "name": "Ceramic Tiles & Vitrified Sanitaryware",
        "benchmark_key": "natural_gas",
        "benchmark_label": "Natural Gas Kiln Fuel",
        "transmission_note": "Kiln fuel and electrical power represent 25-30% of manufacturing expense in tile kilns.",
        "stocks": [
            {"symbol": "KAJARIACER", "name": "Kajaria Ceramics Limited", "role": "Market leader in vitrified tiles with retail brand pricing power"},
            {"symbol": "SOMANYCERA", "name": "Somany Ceramics Limited", "role": "Ceramic and polished vitrified tile maker with regional gas sourcing"},
            {"symbol": "CERA",       "name": "Cera Sanitaryware Limited", "role": "Premium sanitaryware and faucet brand with low raw material beta"},
            {"symbol": "GUJGASLTD",  "name": "Gujarat Gas Limited", "role": "Gas pipeline supplier to Morbi ceramic hub balancing industrial pricing"}
        ]
    },
    {
        "id": "cement_building_materials",
        "name": "Cement & Building Concrete",
        "benchmark_key": "brent_crude",
        "benchmark_label": "Imported Petcoke & Thermal Coal",
        "transmission_note": "Power & fuel (petcoke, coal) plus logistics freight represent over 45% of cement production cost.",
        "stocks": [
            {"symbol": "ULTRACEMCO", "name": "UltraTech Cement Limited", "role": "Pan-India cement leader with captive WHRS energy efficiency and scale"},
            {"symbol": "AMBUJACEM",  "name": "Ambuja Cements Limited", "role": "Adani group cement producer optimizing green power and supply chain costs"},
            {"symbol": "DALBHARAT",  "name": "Dalmia Bharat Limited", "role": "Eastern and southern region cement player with high blending ratios"},
            {"symbol": "SHREECEM",   "name": "Shree Cement Limited", "role": "Low-cost operational producer with agile fuel procurement flexibility"}
        ]
    },
    {
        "id": "textiles_apparel_spinning",
        "name": "Textile Spinning, Denim & Branded Garments",
        "benchmark_key": "cotton",
        "benchmark_label": "Raw Cotton & Combed Yarn",
        "transmission_note": "Raw seed cotton constitutes 50-55% of yarn production cost; retail garments enjoy sticky pricing.",
        "stocks": [
            {"symbol": "PAGEIND",  "name": "Page Industries (Jockey)", "role": "Branded innerwear company with inelastic consumer pricing power"},
            {"symbol": "KPRMILL",  "name": "K.P.R. Mill Limited", "role": "Vertically integrated spinning and garment exporter with captive green energy"},
            {"symbol": "VTL",      "name": "Vardhman Textiles Limited", "role": "Pure yarn spinner exposed to domestic cotton MSP vs global cotton spread"},
            {"symbol": "TRIDENT",  "name": "Trident Limited", "role": "Home textiles and terry towel manufacturer exposed to export freight and cotton prices"}
        ]
    },
    {
        "id": "sugar_distilleries_fmcg",
        "name": "Sugar Mills, Bio-Ethanol & Sweeteners",
        "benchmark_key": "brent_crude",
        "benchmark_label": "Ethanol Pricing Linked to Energy",
        "transmission_note": "Sugarcane FRP set by government; ethanol procurement price benchmarked to national fuel blending.",
        "stocks": [
            {"symbol": "BALRAMCHIN", "name": "Balrampur Chini Mills", "role": "Integrated sugar mill with large grain/syrup ethanol distilleries"},
            {"symbol": "EIDPARRY",   "name": "E.I.D. - Parry (India)", "role": "South India sugar, nutraceuticals, and distillery producer"},
            {"symbol": "SHREERAMA",  "name": "Shree Renuka Sugars", "role": "Port-based sugar refiner capturing global white sugar trade flows"},
            {"symbol": "BRITANNIA",  "name": "Britannia Industries", "role": "Packaged food giant with high consumption of industrial sugar and palm oil"}
        ]
    },
    {
        "id": "fertilizers_agrochem",
        "name": "Fertilizers, Urea & Crop Protection",
        "benchmark_key": "natural_gas",
        "benchmark_label": "Natural Gas (Ammonia Feedstock)",
        "transmission_note": "Pooled natural gas forms 70-80% of urea manufacturing cost under government subsidy regimes.",
        "stocks": [
            {"symbol": "COROMANDEL", "name": "Coromandel International", "role": "Phosphatic fertilizer (DAP/NPK) and agrochemical manufacturer"},
            {"symbol": "CHAMBLFERT", "name": "Chambal Fertilisers and Chemicals", "role": "Urea producer with gas pooling subsidy pricing mechanism"},
            {"symbol": "GNFC",       "name": "Gujarat Narmada Valley Fertilizers", "role": "Chemicals and urea manufacturer exposed to industrial gas spreads"},
            {"symbol": "PIIND",      "name": "PI Industries Limited", "role": "Complex agrochem patent-commercialization firm with low commodity reliance"}
        ]
    },
    {
        "id": "it_services_digital",
        "name": "IT Services & Digital Engineering",
        "benchmark_key": "usd_inr",
        "benchmark_label": "USD-INR Currency Pair",
        "transmission_note": "80%+ revenue in USD/EUR while 60%+ costs in INR; 1% rupee depreciation expands EBIT margin by ~30-40 bps.",
        "stocks": [
            {"symbol": "TCS",      "name": "Tata Consultancy Services", "role": "Tier-1 IT leader with defensive margins and low subcontractor dependence"},
            {"symbol": "INFY",     "name": "Infosys Limited", "role": "Tier-1 digital services firm sensitive to US BFSI tech spend and currency swings"},
            {"symbol": "KPITTECH", "name": "KPIT Technologies", "role": "Automotive software & ER&D specialist with long-term dollar/euro OEM contracts"},
            {"symbol": "COFORGE",  "name": "Coforge Limited", "role": "High-growth midcap IT firm with high travel/insurance vertical dollar realization"}
        ]
    },
    {
        "id": "banking_nbfc_credit",
        "name": "Banking, Credit Intermediation & Housing Finance",
        "benchmark_key": "us_10y_yield",
        "benchmark_label": "10Y Bond Yields & Systemic Cost of Funds",
        "transmission_note": "Cost of money benchmark; floating loan repricing vs fixed deposit lag determines Net Interest Margin (NIM).",
        "stocks": [
            {"symbol": "HDFCBANK",   "name": "HDFC Bank Limited", "role": "Mega-lender managing post-merger liability cost vs high loan growth"},
            {"symbol": "ICICIBANK",  "name": "ICICI Bank Limited", "role": "Diversified private bank with high floating-rate EBLR loan mix and sharp NIM moat"},
            {"symbol": "FEDERALBNK", "name": "Federal Bank Limited", "role": "Mid-tier bank with low-cost NRI foreign remittances and retail credit momentum"},
            {"symbol": "BAJFINANCE", "name": "Bajaj Finance Limited", "role": "Wholesale bond-reliant NBFC with agile retail loan pricing transmission"}
        ]
    }
]

def load_business_models():
    """Reads audited financial snapshots and macro benchmark cards."""
    if not os.path.exists(INPUT_MODELS_FILE):
        print(f"❌ Error: '{INPUT_MODELS_FILE}' not found in the current working directory!")
        return None, None

    try:
        with open(INPUT_MODELS_FILE, "r", encoding="utf-8") as f:
            data = json.load(f)
        metadata = data.get("metadata", {})
        macro_snapshot = metadata.get("macro_snapshot", {})
        companies = data.get("companies", {})
        print(f"✅ Loaded audited financials for {len(companies)} companies.")
        print(f"✅ Loaded {len(macro_snapshot)} macro benchmarks.")
        return macro_snapshot, companies
    except Exception as e:
        print(f"❌ Error parsing {INPUT_MODELS_FILE}: {e}")
        return None, None

def call_gemini_with_fallback(prompt, api_key):
    """Executes prompt on candidate Gemini models with fallback."""
    payload = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {
            "temperature": 0.2,
            "maxOutputTokens": 6000,
            "responseMimeType": "application/json"
        }
    }

    for model_name in CANDIDATE_MODELS:
        for version in ["v1beta", "v1"]:
            url = f"https://generativelanguage.googleapis.com/{version}/models/{model_name}:generateContent?key={api_key}"
            headers = {"Content-Type": "application/json"}

            try:
                res = requests.post(url, json=payload, headers=headers, timeout=50)
                if res.status_code == 200:
                    raw_text = res.json()["candidates"][0]["content"]["parts"][0]["text"].strip()
                    if raw_text.startswith("```json"):
                        raw_text = raw_text[7:]
                    elif raw_text.startswith("```"):
                        raw_text = raw_text[3:]
                    if raw_text.endswith("```"):
                        raw_text = raw_text[:-3]

                    parsed = json.loads(raw_text.strip())
                    return parsed, f"{model_name} [{version}]"
                else:
                    if res.status_code != 404:
                        print(f"   ⚠ [{version}] {model_name} -> HTTP {res.status_code}")
                    time.sleep(0.5)

            except Exception:
                time.sleep(0.5)

    return None, None

def evaluate_sector_batch_with_ai(sector_batch, macro_data, companies_data, api_key):
    """
    Submits 2 sectors (8 stocks) to Gemini 3.7 with their audited figures
    and live macro shock deltas.
    """
    batch_prompts = []

    for sec in sector_batch:
        bench_key = sec["benchmark_key"]
        macro_info = macro_data.get(bench_key, {})
        price_str = f"{macro_info.get('current_val', 'N/A')} {macro_info.get('unit', '')}"
        deltas = macro_info.get("deltas", {})
        d1m = deltas.get("1M", 0.0)
        d1y = deltas.get("1Y_YoY", 0.0)

        stocks_context = []
        for s in sec["stocks"]:
            sym = s["symbol"]
            comp = companies_data.get(sym, {})
            pnl = comp.get("audited_statement_snapshot", {}).get("profit_and_loss", {})
            eff = comp.get("audited_statement_snapshot", {}).get("efficiency_ratios", {})
            cf = comp.get("audited_statement_snapshot", {}).get("cash_flow", {})

            opm = pnl.get("OPM %", "N/A")
            inv_days = eff.get("Inventory Days", "N/A")
            ccc = eff.get("Cash Conversion Cycle", "N/A")
            cfo_op = cf.get("CFO/OP", "N/A")

            stocks_context.append(
                f"  - Stock: {sym} ({s['name']})\n"
                f"    Business Role: {s['role']}\n"
                f"    Audited OPM: {opm}% | Inventory Days: {inv_days}d | CCC: {ccc}d | CFO/OP: {cfo_op}%"
            )

        stocks_text = "\n".join(stocks_context)

        batch_prompts.append(
            f"=== SECTOR: {sec['name']} (ID: {sec['id']}) ===\n"
            f"Primary Macro Benchmark: {sec['benchmark_label']} ({price_str}) | 1M Delta: {d1m}% | 1Y Delta: {d1y}%\n"
            f"Transmission Mechanism: {sec['transmission_note']}\n"
            f"Candidate Equities Audited Snapshot:\n{stocks_text}"
        )

    full_sectors_input = "\n\n".join(batch_prompts)

    prompt = f"""
ACT AS: Senior Head of Institutional Equity Research & Corporate Margin Intelligence.
TASK: Analyze the following {len(sector_batch)} Indian market sectors (each having 4 stocks, total {len(sector_batch)*4} stocks) based strictly on real audited numbers and live macro deltas.

INPUT DATA:
{full_sectors_input}

MANDATE FOR AI CLASSIFICATION:
For EACH stock in each sector, analyze:
1. Operational business role (Consumer vs Producer vs Inelastic Brand).
2. Audited Inventory Days (e.g. 142 days means high delay in cost transmission).
3. Contractual pass-through ability / Pricing Power.

Decide whether each stock experiences 'MARGIN_EXPANSION' (Tailwinds) OR 'MARGIN_CONTRACTION' (Headwinds).
Provide an integer estimate for projected OPM change in bps (Positive for EXPANSION, Negative for CONTRACTION).

OUTPUT SCHEMA (Must be valid raw JSON list of sectors, without markdown):
[
  {{
    "sector_id": "sector_id_here",
    "sector_name": "Sector Name",
    "benchmark_commodity": "Benchmark Name",
    "benchmark_price": "Price + Unit",
    "benchmark_1m_delta_pct": 0.0,
    "sector_macro_thesis": "2 to 3 sentences in conversational business Hinglish explaining the macro transmission into upcoming quarterly results.",
    "evaluated_stocks": [
      {{
        "symbol": "NSE_SYMBOL",
        "company_name": "Full Name",
        "margin_trajectory": "MARGIN_EXPANSION or MARGIN_CONTRACTION",
        "projected_opm_change_bps": 220,
        "pricing_power": "HIGH or MODERATE or WEAK",
        "operational_transmission_rationale": "Crisp single-sentence Hinglish explaining inventory lag and cost absorption.",
        "quarterly_ebitda_outlook": "Crisp single-sentence forward-looking margin impact for upcoming Q3/Q4 results."
      }}
    ]
  }}
]
Ensure all {len(sector_batch)} sectors are returned in the list.
"""

    return call_gemini_with_fallback(prompt, api_key)

def run_pipeline():
    api_key = os.environ.get("GEMINI_API_KEY", "").strip()
    if not api_key:
        print("❌ CRITICAL ERROR: 'GEMINI_API_KEY' environment variable is missing!")
        exit(1)

    macro_data, companies_data = load_business_models()
    if not macro_data or not companies_data:
        print("🛑 Pipeline Aborted: Missing source data.")
        exit(1)

    print("\n" + "=" * 75)
    print("🚀 Running 17-Sector Macro Margin Radar Pipeline (Batch Size: 2 Sectors / 8 Stocks)")
    print("=" * 75)

    # 2-2 sectors ke batches banate hain
    sector_pairs = [SECTOR_REGISTRY[i:i + 2] for i in range(0, len(SECTOR_REGISTRY), 2)]
    total_batches = len(sector_pairs)
    all_sector_reports = []

    for batch_idx, batch in enumerate(sector_pairs, 1):
        names = " & ".join([s["name"] for s in batch])
        print(f"\n📦 [Batch {batch_idx}/{total_batches}] Processing {len(batch)} Sectors: {names}...")

        reports, engine = evaluate_sector_batch_with_ai(batch, macro_data, companies_data, api_key)

        if reports and isinstance(reports, list):
            all_sector_reports.extend(reports)
            stocks_count = sum(len(r.get("evaluated_stocks", [])) for r in reports)
            print(f"   ✨ Success! Evaluated {stocks_count} stocks using [{engine}]")
        else:
            print(f"   ❌ Batch failed for: {names}")

        # ⏳ 10-Second Cooldown (Aakhri batch ke baad sleep nahi lagega)
        if batch_idx < total_batches:
            print("   ⏳ Sleeping 10s to maintain safe rate limits...")
            time.sleep(10)

    # Aggregation into Outcome-First Matrix
    expanding_stocks_global = []
    contracting_stocks_global = []

    for sec in all_sector_reports:
        s_name = sec.get("sector_name", "")
        driver = sec.get("benchmark_commodity", "")
        for st in sec.get("evaluated_stocks", []):
            item = {
                "symbol": st.get("symbol", ""),
                "company_name": st.get("company_name", ""),
                "sector": s_name,
                "macro_driver": driver,
                "bps_impact": st.get("projected_opm_change_bps", 0),
                "pricing_power": st.get("pricing_power", "MODERATE"),
                "rationale": st.get("operational_transmission_rationale", ""),
                "outlook": st.get("quarterly_ebitda_outlook", "")
            }
            if st.get("margin_trajectory") == "MARGIN_EXPANSION":
                expanding_stocks_global.append(item)
            else:
                contracting_stocks_global.append(item)

    # Sort by absolute BPS impact
    expanding_stocks_global.sort(key=lambda x: x["bps_impact"], reverse=True)
    contracting_stocks_global.sort(key=lambda x: x["bps_impact"])

    final_payload = {
        "updated_at": datetime.now().strftime("%Y-%m-%d %H:%M:%S IST"),
        "macro_pulse_summary": {
            "total_sectors_analyzed": len(all_sector_reports),
            "total_stocks_screened": len(expanding_stocks_global) + len(contracting_stocks_global),
            "total_expanding_equities": len(expanding_stocks_global),
            "total_contracting_equities": len(contracting_stocks_global)
        },
        "sectors": all_sector_reports,
        "margin_expanding_tailwinds": expanding_stocks_global,
        "margin_contracting_headwinds": contracting_stocks_global
    }

    with open(OUTPUT_REPORT_FILE, "w", encoding="utf-8") as f:
        json.dump(final_payload, f, ensure_ascii=False, indent=2)

    print("\n" + "=" * 75)
    print(f"🎉 SUCCESS: Generated '{OUTPUT_REPORT_FILE}'!")
    print(f"   🟢 Margin Expanding Equities: {len(expanding_stocks_global)}")
    print(f"   🔴 Margin Contracting Equities: {len(contracting_stocks_global)}")
    print("=" * 75)

if __name__ == "__main__":
    run_pipeline()
