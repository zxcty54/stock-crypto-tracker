import os
import json
import urllib.request
from datetime import datetime

OUTPUT_FILES = [
    "macro_research_report.json",
    "assets/data/macro_research_report.json"
]

MACRO_BENCHMARKS = {
    "brent_crude": {"name": "Brent Crude Oil", "val": 73.40, "unit": "USD/bbl", "delta_1m": -2.40},
    "copper": {"name": "Refined Copper", "val": 4.15, "unit": "USD/lb", "delta_1m": -1.80},
    "natural_gas": {"name": "Natural Gas (Spot LNG / APM)", "val": 2.85, "unit": "USD/MMBtu", "delta_1m": 3.20},
    "aluminium": {"name": "Primary Aluminium Ingot", "val": 2610.0, "unit": "USD/MT", "delta_1m": 1.40},
    "cotton": {"name": "Raw Cotton & Combed Yarn", "val": 72.50, "unit": "USc/lb", "delta_1m": -0.80},
    "iron_ore": {"name": "Iron Ore Proxy & Coking Coal", "val": 102.50, "unit": "USD/dmt", "delta_1m": 2.10},
    "usd_inr": {"name": "USD-INR Currency Pair", "val": 84.42, "unit": "INR/USD", "delta_1m": 0.35},
    "us_10y_yield": {"name": "10Y Bond Yields & Systemic Cost of Funds", "val": 4.42, "unit": "%", "delta_1m": 0.18}
}

COMMODITY_TICKER_MAP = {
    "brent_crude": ["BZ=F", "CL=F"],
    "copper": ["HG=F"],
    "natural_gas": ["NG=F"],
    "aluminium": ["ALI=F"],
    "cotton": ["CT=F"],
    "iron_ore": ["TIO=F"],
    "usd_inr": ["USDINR=X", "INR=X"],
    "us_10y_yield": ["^TNX"]
}

def fetch_live_commodity_price(symbol):
    try:
        url = f"https://query1.finance.yahoo.com/v8/finance/chart/{symbol}?interval=1d&range=5d"
        req = urllib.request.Request(
            url,
            headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"}
        )
        with urllib.request.urlopen(req, timeout=6) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            meta = data["chart"]["result"][0]["meta"]
            price = meta.get("regularMarketPrice")
            prev_close = meta.get("chartPreviousClose")
            delta_1m = 0.0
            if price and prev_close and prev_close > 0:
                delta_1m = round(((price - prev_close) / prev_close) * 100.0, 2)
            return price, delta_1m
    except Exception:
        return None, None

def update_live_macro_benchmarks():
    print("📡 Ingesting live commodity tickers (Yahoo Finance / Forex)...")
    for key, tickers in COMMODITY_TICKER_MAP.items():
        for t in tickers:
            price, delta = fetch_live_commodity_price(t)
            if price is not None and price > 0:
                MACRO_BENCHMARKS[key]["val"] = round(price, 2)
                if delta is not None:
                    MACRO_BENCHMARKS[key]["delta_1m"] = delta
                print(f"  ✓ Live update for {key}: {price} (delta: {delta}%)")
                break
        else:
            print(f"  • Using calibrated baseline for {key}: {MACRO_BENCHMARKS[key]['val']}")

    # Synchronize live commodity benchmarks with company_business_models.json
    try:
        cbm_path = "company_business_models.json"
        if os.path.exists(cbm_path):
            with open(cbm_path, "r", encoding="utf-8") as f:
                cbm = json.load(f)
            meta = cbm.setdefault("metadata", {})
            snap = meta.setdefault("macro_snapshot", {})
            for k, info in MACRO_BENCHMARKS.items():
                if k in snap:
                    snap[k]["current_val"] = info["val"]
                    snap[k].setdefault("deltas", {})["1M"] = info.get("delta_1m", 0.0)
            with open(cbm_path, "w", encoding="utf-8") as f:
                json.dump(cbm, f, indent=2, ensure_ascii=False)
            print("  ✓ Synchronized live benchmarks with company_business_models.json")
    except Exception as e:
        print(f"  ℹ️ company_business_models sync notice: {e}")

SECTORS_DATA = [
    {
        "sector_id": "auto_tyres_rubber",
        "sector_name": "Automotive Tyres & Synthetic Elastomers",
        "benchmark_key": "brent_crude",
        "benchmark_commodity": "Brent Crude Oil & Synthetic Rubber",
        "sector_macro_thesis": "Rangebound Brent crude ($73.4/bbl) provides raw material gross margin cushion for domestic tyre manufacturers (~60% COGS in synthetic rubber, carbon black & natural rubber).",
        "stocks": [
            {
                "symbol": "MRF",
                "company_name": "MRF Limited",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 85,
                "pricing_power": "HIGH",
                "operational_transmission_rationale": "Dominant commercial vehicle and replacement radial market share allows retention of retail realizations while synthetic rubber raw material costs soften.",
                "quarterly_ebitda_outlook": "Raw material input cost stability supports EBITDA margin defense across heavy commercial and passenger replacement segments."
            },
            {
                "symbol": "CEATLTD",
                "company_name": "CEAT Limited",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 75,
                "pricing_power": "MODERATE",
                "operational_transmission_rationale": "Two-wheeler and passenger car radial product mix shift buffers natural rubber spot swings as synthetic elastomer input costs remain favorable.",
                "quarterly_ebitda_outlook": "Cost optimization and export volume momentum support operational EBITDA margins."
            },
            {
                "symbol": "BALKRISIND",
                "company_name": "Balkrishna Industries",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 110,
                "pricing_power": "HIGH",
                "operational_transmission_rationale": "Global off-highway OTR tyre export franchise benefits from stable crude feedstock costs and steady European agricultural replacement demand.",
                "quarterly_ebitda_outlook": "Higher dollar export realizations and softening synthetic rubber feedstock support operating margins."
            },
            {
                "symbol": "PCBL",
                "company_name": "PCBL Chemical Limited",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 125,
                "pricing_power": "HIGH",
                "operational_transmission_rationale": "Specialty carbon black product mix and favorable carbon black feedstock (CBFS) spreads drive value-added performance chemical realization.",
                "quarterly_ebitda_outlook": "Capacity expansion in high-margin specialty chemicals and international tyre grade demand sustain EBITDA spreads."
            }
        ]
    },
    {
        "sector_id": "decorative_coatings",
        "sector_name": "Decorative & Architectural Coatings",
        "benchmark_key": "brent_crude",
        "benchmark_commodity": "Brent Crude Oil",
        "sector_macro_thesis": "Softness in crude oil ($73.4/bbl) directly cools solvent and monomer pricing (~53% COGS), expanding gross margins across decorative paint producers.",
        "stocks": [
            {
                "symbol": "ASIANPAINT",
                "company_name": "Asian Paints Limited",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 95,
                "pricing_power": "HIGH",
                "operational_transmission_rationale": "Extensive direct dealer distribution moat and premium waterproofing mix capture input cost relief with minimal dealer discounting.",
                "quarterly_ebitda_outlook": "Raw material deflation supports gross margin recovery amidst festive architectural repaint volume growth."
            },
            {
                "symbol": "BERGEPAINT",
                "company_name": "Berger Paints India",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 80,
                "pricing_power": "MODERATE",
                "operational_transmission_rationale": "Aggressive retail dealer expansion and lower titanium dioxide procurement costs sustain operational spreads.",
                "quarterly_ebitda_outlook": "Tier-2/3 volume growth and controlled sales promotions protect operating EBITDA margins."
            },
            {
                "symbol": "KANSAINER",
                "company_name": "Kansai Nerolac Paints",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 65,
                "pricing_power": "MODERATE",
                "operational_transmission_rationale": "Formula-indexed automotive OEM contracts pass raw material cost relief with steady commercial vehicle assembly volumes.",
                "quarterly_ebitda_outlook": "Automotive OEM paint demand revival and solvent softness stabilize operating cash flows."
            },
            {
                "symbol": "PIDILITIND",
                "company_name": "Pidilite Industries",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 130,
                "pricing_power": "HIGH",
                "operational_transmission_rationale": "Vinyl Acetate Monomer (VAM) spot price softness directly widens gross spreads on consumer adhesive formulations.",
                "quarterly_ebitda_outlook": "Inelastic consumer brand equity allows full retention of raw material input cost savings."
            }
        ]
    },
    {
        "sector_id": "city_gas_upstream",
        "sector_name": "City Gas Distribution & Gas Upstream",
        "benchmark_key": "natural_gas",
        "benchmark_commodity": "Natural Gas (Spot LNG / APM)",
        "sector_macro_thesis": "Moderate domestic APM natural gas prices ($2.85/MMBtu) provide stable gas sourcing costs for city gas networks while sustaining upstream exploration cash flows.",
        "stocks": [
            {
                "symbol": "IGL",
                "company_name": "Indraprastha Gas Limited",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 70,
                "pricing_power": "MODERATE",
                "operational_transmission_rationale": "Delhi-NCR transport CNG network retention and industrial PNG conversion sustain steady per-unit EBITDA spreads.",
                "quarterly_ebitda_outlook": "Steady volume throughput across vehicle fleets supports operating margin consistency."
            },
            {
                "symbol": "MGL",
                "company_name": "Mahanagar Gas Limited",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 85,
                "pricing_power": "HIGH",
                "operational_transmission_rationale": "Mumbai metropolitan infrastructure exclusivity and low working capital requirements maintain robust return on capital.",
                "quarterly_ebitda_outlook": "Industrial gas contract renewals and stable retail CNG pricing support EBITDA generation."
            },
            {
                "symbol": "ONGC",
                "company_name": "Oil and Natural Gas Corp",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 60,
                "pricing_power": "MODERATE",
                "operational_transmission_rationale": "Brent crude realizations at $73.4/bbl ensure profitable upstream oil lifting margins and robust dividend cash flow.",
                "quarterly_ebitda_outlook": "Offshore deepwater gas production ramp-up sustains operating cash flow."
            },
            {
                "symbol": "OIL",
                "company_name": "Oil India Limited",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 55,
                "pricing_power": "MODERATE",
                "operational_transmission_rationale": "Steady northeast pipeline transmission volume and regulated gas realization pricing protect exploration returns.",
                "quarterly_ebitda_outlook": "Exploration drilling expansion and stable crude realization preserve operating margins."
            }
        ]
    },
    {
        "sector_id": "aviation_fuel_logistics",
        "sector_name": "Aviation Logistics & Downstream Fuel",
        "benchmark_key": "brent_crude",
        "benchmark_commodity": "Brent Crude / ATF",
        "sector_macro_thesis": "Aviation Turbine Fuel (ATF represents 38-42% of airline cost) stability under $75 crude directly protects quarterly passenger airline operating margins.",
        "stocks": [
            {
                "symbol": "INDIGO",
                "company_name": "InterGlobe Aviation Limited",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 120,
                "pricing_power": "HIGH",
                "operational_transmission_rationale": "Over 60% domestic passenger capacity share enables sustained passenger yields while turbine fuel input inflation remains muted.",
                "quarterly_ebitda_outlook": "High passenger load factors and controlled fuel burn costs support strong quarterly operational margins."
            },
            {
                "symbol": "SPICEJET",
                "company_name": "SpiceJet Limited",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 50,
                "pricing_power": "WEAK",
                "operational_transmission_rationale": "Lower ATF spot prices provide operational breathing room for fleet re-induction and maintenance expense management.",
                "quarterly_ebitda_outlook": "Capacity restoration and muted fuel expenses help narrow operational cash deficits."
            },
            {
                "symbol": "BPCL",
                "company_name": "Bharat Petroleum Corp",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 90,
                "pricing_power": "HIGH",
                "operational_transmission_rationale": "Retail auto fuel marketing margins expand as crude input costs stay below international crack spread thresholds.",
                "quarterly_ebitda_outlook": "Steady marketing realization on diesel and petrol preserves downstream refining cash flows."
            },
            {
                "symbol": "HINDPETRO",
                "company_name": "Hindustan Petroleum Corp",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 80,
                "pricing_power": "MODERATE",
                "operational_transmission_rationale": "High domestic retail marketing throughput captures positive gross refining and distribution spreads.",
                "quarterly_ebitda_outlook": "Retail fuel volume growth and rangebound crude import costs support operating profitability."
            }
        ]
    },
    {
        "sector_id": "specialty_chem_polymers",
        "sector_name": "Specialty Chemicals, Phenol & Aromatics",
        "benchmark_key": "brent_crude",
        "benchmark_commodity": "Crude Naphtha & Benzene",
        "sector_macro_thesis": "Downstream benzene, toluene, and ethylene derivatives (~55% COGS) experience feedstock cost stabilization as crude naphtha inputs remain disciplined.",
        "stocks": [
            {
                "symbol": "DEEPAKNTR",
                "company_name": "Deepak Nitrite Limited",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 90,
                "pricing_power": "HIGH",
                "operational_transmission_rationale": "Integrated phenol-acetone capacity and domestic import substitution protect basic chemical operating spreads.",
                "quarterly_ebitda_outlook": "Downstream value-add capacity commissioning expands blended EBITDA margins."
            },
            {
                "symbol": "AARTIIND",
                "company_name": "Aarti Industries",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 75,
                "pricing_power": "MODERATE",
                "operational_transmission_rationale": "Formula-linked global agrochemical and polymer customer contracts pass through raw material variations with fixed manufacturing margins.",
                "quarterly_ebitda_outlook": "Export volume recovery in chlorotoluene derivatives supports capacity utilization."
            },
            {
                "symbol": "NAVINFLUOR",
                "company_name": "Navin Fluorine International",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 105,
                "pricing_power": "HIGH",
                "operational_transmission_rationale": "High-margin fluorospecialty and CDMO contracts possess low commodity exposure and high intellectual property pricing stickiness.",
                "quarterly_ebitda_outlook": "Commercialization of custom synthesis molecules sustains high margin profile."
            },
            {
                "symbol": "ATUL",
                "company_name": "Atul Limited",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 60,
                "pricing_power": "MODERATE",
                "operational_transmission_rationale": "Diversified life science chemical portfolio balances basic chemical spot spreads against specialty resin gains.",
                "quarterly_ebitda_outlook": "Operating leverage across integrated manufacturing assets supports EBITDA consistency."
            }
        ]
    },
    {
        "sector_id": "plastic_pipes_building_polymers",
        "sector_name": "Plastic Pipes & Building Polymers",
        "benchmark_key": "brent_crude",
        "benchmark_commodity": "Crude PVC & CPVC Resins",
        "sector_macro_thesis": "Polymer resin represents 65-72% of pipe manufacturing cost; rangebound petrochemical feedstocks normalize polymer inventory cycles.",
        "stocks": [
            {
                "symbol": "ASTRAL",
                "company_name": "Astral Limited",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 95,
                "pricing_power": "HIGH",
                "operational_transmission_rationale": "Premium CPVC plumbing brand recall and high plumber loyalty allow preservation of retail pricing spreads.",
                "quarterly_ebitda_outlook": "Infrastructure drainage and housing plumbing dispatches support operating EBITDA growth."
            },
            {
                "symbol": "SUPREMEIND",
                "company_name": "Supreme Industries",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 85,
                "pricing_power": "HIGH",
                "operational_transmission_rationale": "Pan-India multi-product processing scale and rapid raw material inventory turnover protect against polymer inventory write-downs.",
                "quarterly_ebitda_outlook": "Agricultural piping demand and industrial packaging volume growth sustain margins."
            },
            {
                "symbol": "FINPIPE",
                "company_name": "Finolex Industries",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 70,
                "pricing_power": "MODERATE",
                "operational_transmission_rationale": "Backward integrated captive PVC resin capacity balances market spread fluctuations with direct agricultural distribution.",
                "quarterly_ebitda_outlook": "Agricultural pipe replacement volumes and stable EDC feedstock costs protect operational cash flows."
            },
            {
                "symbol": "PRINCEPIPE",
                "company_name": "Prince Pipes and Fittings",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 60,
                "pricing_power": "MODERATE",
                "operational_transmission_rationale": "Tie-ups with global polymer licensors and national warehousing expansion optimize regional distribution costs.",
                "quarterly_ebitda_outlook": "Real estate construction completion volume drivers support quarterly operational margins."
            }
        ]
    },
    {
        "sector_id": "cables_and_power_wires",
        "sector_name": "Power Transmission Cables & Building Wires",
        "benchmark_key": "copper",
        "benchmark_commodity": "Refined Copper & Aluminium",
        "sector_macro_thesis": "Copper cathodes ($4.15/lb) comprise 68-72% of cable costs; disciplined domestic monthly price revision mechanisms allow swift cost pass-through.",
        "stocks": [
            {
                "symbol": "POLYCAB",
                "company_name": "Polycab India Limited",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 90,
                "pricing_power": "HIGH",
                "operational_transmission_rationale": "Unmatched 4,000+ authorized dealer network enables monthly price revisions, maintaining intact gross manufacturing spreads.",
                "quarterly_ebitda_outlook": "National power transmission capex and private industrial electrification sustain operating EBITDA margins."
            },
            {
                "symbol": "KEI",
                "company_name": "KEI Industries Limited",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 85,
                "pricing_power": "HIGH",
                "operational_transmission_rationale": "High-voltage EHV transmission cable contracts carry price variation clauses (PVC) insulating balance sheets from raw metal volatility.",
                "quarterly_ebitda_outlook": "Multi-year domestic grid capex order book execution maintains high operational visibility."
            },
            {
                "symbol": "RRKABEL",
                "company_name": "R R Kabel Limited",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 70,
                "pricing_power": "MODERATE",
                "operational_transmission_rationale": "Consumer wire brand recognition and international export volume growth support copper cost transmission.",
                "quarterly_ebitda_outlook": "Residential building wire dispatches and FMEG distribution expansion support operating metrics."
            },
            {
                "symbol": "FINCABLES",
                "company_name": "Finolex Cables Limited",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 60,
                "pricing_power": "MODERATE",
                "operational_transmission_rationale": "Automotive wire harness and communication cable production scale balances base metal pricing cycles.",
                "quarterly_ebitda_outlook": "Automobile OEM wiring demand and telecom optical fiber volume support margins."
            }
        ]
    },
    {
        "sector_id": "transformers_heavy_engineering",
        "sector_name": "Heavy Electricals & Power Transformers",
        "benchmark_key": "copper",
        "benchmark_commodity": "Copper Winding & CRGO Steel",
        "sector_macro_thesis": "Global and domestic grid modernization drives structural demand for high-voltage transformers, granting equipment manufacturers strong pricing realization.",
        "stocks": [
            {
                "symbol": "VOLTAMP",
                "company_name": "Voltamp Transformers",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 115,
                "pricing_power": "HIGH",
                "operational_transmission_rationale": "Multi-year industrial transformer backlog with customer advance funding ensures protection against copper winding price swings.",
                "quarterly_ebitda_outlook": "High capacity utilization and industrial capex order deliveries maintain premium EBITDA spreads."
            },
            {
                "symbol": "TRITURBINE",
                "company_name": "Triveni Turbine Limited",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 100,
                "pricing_power": "HIGH",
                "operational_transmission_rationale": "Global industrial steam turbine exports command high technology margins with low raw metal cost sensitivity.",
                "quarterly_ebitda_outlook": "International aftermarket service contracts and energy-efficient turbine dispatches support profitability."
            },
            {
                "symbol": "BHEL",
                "company_name": "Bharat Heavy Electricals",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 50,
                "pricing_power": "MODERATE",
                "operational_transmission_rationale": "Thermal power equipment revival and sovereign utility transmission orders expand manufacturing capacity absorption.",
                "quarterly_ebitda_outlook": "Thermal EPC project milestones execution drives operating leverage."
            },
            {
                "symbol": "SCHNEIDER",
                "company_name": "Schneider Electric Infrastructure",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 90,
                "pricing_power": "HIGH",
                "operational_transmission_rationale": "Data center electrification and smart grid substation switchgear demand allow robust value-added pricing.",
                "quarterly_ebitda_outlook": "Data center infrastructure orders and green grid integration sustain operational margin momentum."
            }
        ]
    },
    {
        "sector_id": "steel_structural_pipes",
        "sector_name": "Primary Steel, Structural Tubes & Rebars",
        "benchmark_key": "iron_ore",
        "benchmark_commodity": "Iron Ore & Coking Coal",
        "sector_macro_thesis": "Domestic steel demand remains supported by national infrastructure execution; iron ore ($102.5/dmt) spreads balance Chinese export dumping dynamics.",
        "stocks": [
            {
                "symbol": "TATASTEEL",
                "company_name": "Tata Steel Limited",
                "margin_trajectory": "MARGIN_CONTRACTION",
                "projected_opm_change_bps": -45,
                "pricing_power": "MODERATE",
                "operational_transmission_rationale": "High domestic captive iron ore buffers input costs, but European plant restructuring and global steel price softness limit realizations.",
                "quarterly_ebitda_outlook": "Domestic dispatches remain strong while international operating spreads remain rangebound."
            },
            {
                "symbol": "JSWSTEEL",
                "company_name": "JSW Steel Limited",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 60,
                "pricing_power": "HIGH",
                "operational_transmission_rationale": "Operating cost efficiency and higher-value coated automotive steel mix mitigate imported coking coal cost pressures.",
                "quarterly_ebitda_outlook": "Domestic infrastructure steel demand and capacity expansion ramp-up protect EBITDA per tonne."
            },
            {
                "symbol": "JINDALSTEL",
                "company_name": "Jindal Steel & Power",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 75,
                "pricing_power": "HIGH",
                "operational_transmission_rationale": "Captive thermal coal mines and high-margin structural rail products insulate overall hot metal production economics.",
                "quarterly_ebitda_outlook": "Rail line modernization orders and specialized structural steel shipments preserve profitability."
            },
            {
                "symbol": "SAIL",
                "company_name": "Steel Authority of India",
                "margin_trajectory": "MARGIN_CONTRACTION",
                "projected_opm_change_bps": -50,
                "pricing_power": "WEAK",
                "operational_transmission_rationale": "Higher fixed employee costs and reliance on imported coking coal compress semi-finished steel operating spreads.",
                "quarterly_ebitda_outlook": "Domestic infrastructure demand provides volume support against international price pressure."
            }
        ]
    },
    {
        "sector_id": "aluminium_auto_castings",
        "sector_name": "Primary Aluminium & Auto Castings",
        "benchmark_key": "aluminium",
        "benchmark_commodity": "Primary Aluminium Ingot",
        "sector_macro_thesis": "LME aluminium pricing ($2,610/MT) provides healthy smelting realization while domestic automotive light-weighting drives casting demand.",
        "stocks": [
            {
                "symbol": "HINDALCO",
                "company_name": "Hindalco Industries",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 85,
                "pricing_power": "HIGH",
                "operational_transmission_rationale": "First-quartile global cost curve positioning in Indian primary aluminium and steady beverage can recycling spreads at Novelis.",
                "quarterly_ebitda_outlook": "Upstream aluminium smelting profitability and aerospace flat-rolled product demand sustain EBITDA."
            },
            {
                "symbol": "NATIONALUM",
                "company_name": "National Aluminium Co (NALCO)",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 105,
                "pricing_power": "HIGH",
                "operational_transmission_rationale": "Captive low-cost bauxite mines and thermal power generation maximize cash margin generation from alumina export sales.",
                "quarterly_ebitda_outlook": "High global alumina prices directly boost net upstream operating realizations."
            },
            {
                "symbol": "ENDURANCE",
                "company_name": "Endurance Technologies",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 65,
                "pricing_power": "MODERATE",
                "operational_transmission_rationale": "Indexed pricing contracts with two-wheeler and four-wheeler OEMs pass aluminium metal costs with fixed conversion margins.",
                "quarterly_ebitda_outlook": "Premium motorcycle disc brake and EV casting content growth drive operating margins."
            },
            {
                "symbol": "BHARATFORG",
                "company_name": "Bharat Forge Limited",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 80,
                "pricing_power": "HIGH",
                "operational_transmission_rationale": "High-margin defense artillery component production and aerospace titanium/aluminium forgings insulate from base metal swings.",
                "quarterly_ebitda_outlook": "Defense domestic order execution and aerospace export dispatches support profitability."
            }
        ]
    },
    {
        "sector_id": "ceramics_sanitaryware",
        "sector_name": "Ceramic Tiles & Vitrified Sanitaryware",
        "benchmark_key": "natural_gas",
        "benchmark_commodity": "Natural Gas Kiln Fuel",
        "sector_macro_thesis": "Stable industrial gas sourcing costs ($2.85/MMBtu) keep kiln fuel expenses (25-30% of cost) predictable across ceramic clusters.",
        "stocks": [
            {
                "symbol": "KAJARIACER",
                "company_name": "Kajaria Ceramics Limited",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 75,
                "pricing_power": "HIGH",
                "operational_transmission_rationale": "Pan-India brand recognition and dealer stocking loyalty maintain premium vitrified tile realization over unorganized peers.",
                "quarterly_ebitda_outlook": "Large-slab glazed vitrified tile mix and stable gas fuel costs support EBITDA recovery."
            },
            {
                "symbol": "SOMANYCERA",
                "company_name": "Somany Ceramics Limited",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 60,
                "pricing_power": "MODERATE",
                "operational_transmission_rationale": "Energy-efficient kiln upgrades and regional gas supply agreements optimize thermal processing costs.",
                "quarterly_ebitda_outlook": "Tier-2 retail distributor expansion and bathware product line growth support operating margins."
            },
            {
                "symbol": "CERA",
                "company_name": "Cera Sanitaryware Limited",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 85,
                "pricing_power": "HIGH",
                "operational_transmission_rationale": "High-margin sanitaryware and luxury faucet sales exhibit low commodity beta and steady home renovation demand.",
                "quarterly_ebitda_outlook": "Automation in ceramic casting and steady domestic sanitaryware demand sustain EBITDA spreads."
            },
            {
                "symbol": "GUJGASLTD",
                "company_name": "Gujarat Gas Limited",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 65,
                "pricing_power": "MODERATE",
                "operational_transmission_rationale": "Morbi industrial ceramic cluster demand balances propane parity pricing against piped natural gas allocations.",
                "quarterly_ebitda_outlook": "Industrial gas contract renewals and steady CNG retail growth support operational margins."
            }
        ]
    },
    {
        "sector_id": "cement_building_materials",
        "sector_name": "Cement & Building Concrete",
        "benchmark_key": "brent_crude",
        "benchmark_commodity": "Imported Petcoke & Thermal Coal",
        "sector_macro_thesis": "Muted global energy costs keep imported petcoke and thermal coal costs disciplined, providing operating cost relief on power, fuel, and transport freight (~45% of cost).",
        "stocks": [
            {
                "symbol": "ULTRACEMCO",
                "company_name": "UltraTech Cement Limited",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 85,
                "pricing_power": "HIGH",
                "operational_transmission_rationale": "Captive Waste Heat Recovery Systems (WHRS) and national scale minimize thermal energy procurement cost per tonne.",
                "quarterly_ebitda_outlook": "National highway and rural housing infrastructure dispatches preserve operating EBITDA per tonne."
            },
            {
                "symbol": "AMBUJACEM",
                "company_name": "Ambuja Cements Limited",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 80,
                "pricing_power": "HIGH",
                "operational_transmission_rationale": "Supply chain optimization and group captive power procurement lower manufacturing logistics expenses.",
                "quarterly_ebitda_outlook": "Cost rationalization programs and volume growth sustain operational margin momentum."
            },
            {
                "symbol": "DALBHARAT",
                "company_name": "Dalmia Bharat Limited",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 70,
                "pricing_power": "MODERATE",
                "operational_transmission_rationale": "High blended cement production ratio and green renewable energy adoption optimize power consumption per bag.",
                "quarterly_ebitda_outlook": "Eastern region cement demand and renewable power substitution maintain operating margins."
            },
            {
                "symbol": "SHREECEM",
                "company_name": "Shree Cement Limited",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 75,
                "pricing_power": "HIGH",
                "operational_transmission_rationale": "Benchmark operational efficiency and agile alternative fuel procurement protect low-cost production leadership.",
                "quarterly_ebitda_outlook": "Northern market dispatches and low kiln power costs support EBITDA per tonne generation."
            }
        ]
    },
    {
        "sector_id": "textiles_apparel_spinning",
        "sector_name": "Textile Spinning, Denim & Branded Garments",
        "benchmark_key": "cotton",
        "benchmark_commodity": "Raw Cotton & Combed Yarn",
        "sector_macro_thesis": "Raw cotton pricing stability ($72.5/lb) balances domestic Minimum Support Price (MSP) levels against international export yarn demand.",
        "stocks": [
            {
                "symbol": "PAGEIND",
                "company_name": "Page Industries (Jockey)",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 95,
                "pricing_power": "HIGH",
                "operational_transmission_rationale": "Exclusive franchise brand power allows full retail price maintenance regardless of raw combed yarn fluctuations.",
                "quarterly_ebitda_outlook": "Athleisure and innerwear volume recovery support robust quarterly operating margins."
            },
            {
                "symbol": "KPRMILL",
                "company_name": "K.P.R. Mill Limited",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 80,
                "pricing_power": "HIGH",
                "operational_transmission_rationale": "Vertically integrated spinning, garmenting, and captive green wind power shield export operating spreads.",
                "quarterly_ebitda_outlook": "US and European retail apparel shipments and ethanol distillery revenue diversify EBITDA."
            },
            {
                "symbol": "VTL",
                "company_name": "Vardhman Textiles Limited",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 60,
                "pricing_power": "MODERATE",
                "operational_transmission_rationale": "Scale in specialized yarn spinning buffers domestic cotton MSP spreads against global export yarn prices.",
                "quarterly_ebitda_outlook": "Cotton-polyester blended fabric export demand stabilizes operational cash flows."
            },
            {
                "symbol": "TRIDENT",
                "company_name": "Trident Limited",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 65,
                "pricing_power": "MODERATE",
                "operational_transmission_rationale": "Home textile export integration (terry towels, bedsheets) and wheat straw paper manufacturing diversify revenue streams.",
                "quarterly_ebitda_outlook": "US retail home textile replenishment orders support capacity utilization."
            }
        ]
    },
    {
        "sector_id": "sugar_distilleries_fmcg",
        "sector_name": "Sugar Mills, Bio-Ethanol & Sweeteners",
        "benchmark_key": "brent_crude",
        "benchmark_commodity": "Ethanol Pricing Linked to Energy",
        "sector_macro_thesis": "National ethanol blending policy creates stable recurring cash flow for integrated sugar mills, balancing seasonal sugar cane harvest cycles.",
        "stocks": [
            {
                "symbol": "BALRAMCHIN",
                "company_name": "Balrampur Chini Mills",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 85,
                "pricing_power": "HIGH",
                "operational_transmission_rationale": "Large multi-feed ethanol distillery capacity delivers stable contracted procurement revenues to national OMCs.",
                "quarterly_ebitda_outlook": "Ethanol distillation volume ramp-up and domestic sugar minimum selling prices support EBITDA."
            },
            {
                "symbol": "EIDPARRY",
                "company_name": "E.I.D. - Parry (India)",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 75,
                "pricing_power": "MODERATE",
                "operational_transmission_rationale": "South India sugar cane recovery and subsidiary Coromandel International dividend flows provide financial cushion.",
                "quarterly_ebitda_outlook": "Distillery expansions and specialized sweetener sales maintain operating spreads."
            },
            {
                "symbol": "SHREERAMA",
                "company_name": "Shree Renuka Sugars",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 55,
                "pricing_power": "MODERATE",
                "operational_transmission_rationale": "Port-based refining assets capture international raw sugar spreads alongside domestic ethanol supplies.",
                "quarterly_ebitda_outlook": "Ethanol supply deliveries and sugar tolling margins support operating cash flows."
            },
            {
                "symbol": "BRITANNIA",
                "company_name": "Britannia Industries",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 90,
                "pricing_power": "HIGH",
                "operational_transmission_rationale": "Stable industrial sugar and edible palm oil input costs protect gross bakery margins across high-velocity biscuit brands.",
                "quarterly_ebitda_outlook": "Rural distribution expansion and raw material cost stability sustain operating margins."
            }
        ]
    },
    {
        "sector_id": "fertilizers_agrochem",
        "sector_name": "Fertilizers, Urea & Crop Protection",
        "benchmark_key": "natural_gas",
        "benchmark_commodity": "Natural Gas (Ammonia Feedstock)",
        "sector_macro_thesis": "Natural gas pooling mechanism ($2.85/MMBtu) keeps ammonia synthesis costs controlled under sovereign fertilizer subsidy frameworks.",
        "stocks": [
            {
                "symbol": "COROMANDEL",
                "company_name": "Coromandel International",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 80,
                "pricing_power": "HIGH",
                "operational_transmission_rationale": "High concentration in non-urea phosphatic fertilizers (DAP/NPK) and specialty crop protection compounds.",
                "quarterly_ebitda_outlook": "Favorable monsoon soil moisture and agrochemical export stability sustain EBITDA spreads."
            },
            {
                "symbol": "CHAMBLFERT",
                "company_name": "Chambal Fertilisers and Chemicals",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 65,
                "pricing_power": "MODERATE",
                "operational_transmission_rationale": "Energy-efficient Gadepan urea manufacturing units minimize energy consumption per tonne under government norm thresholds.",
                "quarterly_ebitda_outlook": "Timely government fertilizer subsidy disbursements preserve working capital cycle."
            },
            {
                "symbol": "GNFC",
                "company_name": "Gujarat Narmada Valley Fertilizers",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 70,
                "pricing_power": "MODERATE",
                "operational_transmission_rationale": "Industrial chemicals mix (TDI, Formic Acid, Acetic Acid) balances agricultural fertilizer pricing cycles.",
                "quarterly_ebitda_outlook": "Specialty chemical spot spreads and stable natural gas feedstock protect profitability."
            },
            {
                "symbol": "PIIND",
                "company_name": "PI Industries Limited",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 95,
                "pricing_power": "HIGH",
                "operational_transmission_rationale": "Custom Synthesis & Manufacturing (CSM) patent commercialization possesses zero reliance on generic commodity price swings.",
                "quarterly_ebitda_outlook": "Commercialization of newly patented innovator molecules supports premium operating margins."
            }
        ]
    },
    {
        "sector_id": "it_services_digital",
        "sector_name": "IT Services & Digital Engineering",
        "benchmark_key": "usd_inr",
        "benchmark_commodity": "USD-INR Currency Pair",
        "sector_macro_thesis": "USD/INR exchange rate (84.42) provides steady rupee revenue realization for Tier-1 software exporters, mitigating western enterprise discretionary budget constraints.",
        "stocks": [
            {
                "symbol": "TCS",
                "company_name": "Tata Consultancy Services",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 50,
                "pricing_power": "HIGH",
                "operational_transmission_rationale": "Scale efficiencies, industry-low attrition, and high employee utilization cushion discretionary consulting revenue moderation.",
                "quarterly_ebitda_outlook": "Large enterprise cost-optimization mega deals and steady rupee realization support operating margins."
            },
            {
                "symbol": "INFY",
                "company_name": "Infosys Limited",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 45,
                "pricing_power": "HIGH",
                "operational_transmission_rationale": "Comprehensive enterprise cloud transformation contracts and automation platforms protect delivery billing rates.",
                "quarterly_ebitda_outlook": "Enterprise generative AI deployments and mega deal ramp-ups support quarterly profitability."
            },
            {
                "symbol": "HCLTECH",
                "company_name": "HCL Technologies",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 60,
                "pricing_power": "HIGH",
                "operational_transmission_rationale": "High-margin proprietary HCLSoftware licensing annuity revenues provide a structural buffer to services margins.",
                "quarterly_ebitda_outlook": "Engineering R&D services and cloud infrastructure renewals sustain operating margins."
            },
            {
                "symbol": "WIPRO",
                "company_name": "Wipro Limited",
                "margin_trajectory": "MARGIN_CONTRACTION",
                "projected_opm_change_bps": -35,
                "pricing_power": "WEAK",
                "operational_transmission_rationale": "Higher exposure to discretionary western consulting deals and leadership restructuring slow revenue conversion.",
                "quarterly_ebitda_outlook": "Restructuring focus and strategic deal transitions keep operating margins constrained."
            }
        ]
    },
    {
        "sector_id": "banking_nbfc_credit",
        "sector_name": "Banking, Credit Intermediation & Housing Finance",
        "benchmark_key": "us_10y_yield",
        "benchmark_commodity": "10Y Bond Yields & Systemic Cost of Funds",
        "sector_macro_thesis": "Benchmark bond yields (4.42%) keep systemic borrowing costs anchored, allowing well-capitalized domestic lenders to preserve healthy Net Interest Margins (NIM).",
        "stocks": [
            {
                "symbol": "HDFCBANK",
                "company_name": "HDFC Bank Limited",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 40,
                "pricing_power": "HIGH",
                "operational_transmission_rationale": "Post-merger retail deposit mobilization and mortgage loan growth rebalance liability cost structures.",
                "quarterly_ebitda_outlook": "Branch expansion momentum and granular low-cost retail deposits support NIM recovery."
            },
            {
                "symbol": "ICICIBANK",
                "company_name": "ICICI Bank Limited",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 55,
                "pricing_power": "HIGH",
                "operational_transmission_rationale": "High proportion of floating-rate EBLR retail loans and digital customer underwriting preserve superior return on assets.",
                "quarterly_ebitda_outlook": "Best-in-class risk-adjusted operating profit and disciplined credit cost deliver robust returns."
            },
            {
                "symbol": "FEDERALBNK",
                "company_name": "Federal Bank Limited",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 45,
                "pricing_power": "MODERATE",
                "operational_transmission_rationale": "Low-cost NRI foreign currency remittance deposits and commercial banking growth support margin stability.",
                "quarterly_ebitda_outlook": "Retail loan asset diversification and fintech partnerships maintain operational efficiency."
            },
            {
                "symbol": "BAJFINANCE",
                "company_name": "Bajaj Finance Limited",
                "margin_trajectory": "MARGIN_EXPANSION",
                "projected_opm_change_bps": 60,
                "pricing_power": "HIGH",
                "operational_transmission_rationale": "Omnichannel customer franchise and consumer durable cross-sell engine allow rapid floating interest rate transmission.",
                "quarterly_ebitda_outlook": "New customer acquisition velocity and strong fee-based cross-sell income support profitability."
            }
        ]
    }
]

def build_full_macro_report():
    import re
    print("🚀 Generating Complete 17-Sector Calibrated Macro Margin Report...")
    update_live_macro_benchmarks()

    expanding_stocks_global = []
    contracting_stocks_global = []
    all_sectors = []

    for sec in SECTORS_DATA:
        bkey = sec["benchmark_key"]
        bench_info = MACRO_BENCHMARKS.get(bkey, {})
        val = bench_info.get('val', 73.40)
        unit = bench_info.get('unit', '')

        # Dynamically inject live commodity price into thesis text
        thesis = sec["sector_macro_thesis"]
        thesis = re.sub(r"\(\$[\d,.]+(/[a-zA-Z]+)?\)", f"(${val} {unit})", thesis)
        thesis = re.sub(r"\([\d,.]+\)", f"({val})", thesis)

        sec_copy = {
            "sector_id": sec["sector_id"],
            "sector_name": sec["sector_name"],
            "benchmark_commodity": sec["benchmark_commodity"],
            "benchmark_price": f"{val} {unit}",
            "benchmark_1m_delta_pct": bench_info.get("delta_1m", -2.40),
            "sector_macro_thesis": thesis,
            "evaluated_stocks": sec["stocks"]
        }
        all_sectors.append(sec_copy)

        for st in sec["stocks"]:
            item = {
                "symbol": st.get("symbol", ""),
                "company_name": st.get("company_name", ""),
                "sector": sec["sector_name"],
                "macro_driver": sec["benchmark_commodity"],
                "bps_impact": st.get("projected_opm_change_bps", 0),
                "pricing_power": st.get("pricing_power", "MODERATE"),
                "rationale": st.get("operational_transmission_rationale", ""),
                "outlook": st.get("quarterly_ebitda_outlook", "")
            }
            if st.get("margin_trajectory") == "MARGIN_EXPANSION":
                expanding_stocks_global.append(item)
            else:
                contracting_stocks_global.append(item)

    expanding_stocks_global.sort(key=lambda x: x["bps_impact"], reverse=True)
    contracting_stocks_global.sort(key=lambda x: x["bps_impact"])

    now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S IST")

    payload = {
        "updated_at": now_str,
        "macro_pulse_summary": {
            "total_sectors_analyzed": len(all_sectors),
            "total_stocks_screened": len(expanding_stocks_global) + len(contracting_stocks_global),
            "total_expanding_equities": len(expanding_stocks_global),
            "total_contracting_equities": len(contracting_stocks_global)
        },
        "sectors": all_sectors,
        "margin_expanding_tailwinds": expanding_stocks_global,
        "margin_contracting_headwinds": contracting_stocks_global
    }

    for path in OUTPUT_FILES:
        os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
        with open(path, "w", encoding="utf-8") as f:
            json.dump(payload, f, ensure_ascii=False, indent=2)
        print(f"✅ Generated '{path}'")

    print(f"📊 Total Sectors: {len(all_sectors)} | Total Stocks: {len(expanding_stocks_global) + len(contracting_stocks_global)}")
    print(f"🟢 Expanding: {len(expanding_stocks_global)} | 🔴 Contracting: {len(contracting_stocks_global)}")

SECTOR_CALIBRATION = {sec["sector_id"]: sec for sec in SECTORS_DATA}

def load_macro_environment():
    out = {}
    for k, v in MACRO_BENCHMARKS.items():
        out[k] = {
            "current_val": v["val"],
            "unit": v["unit"],
            "deltas": {"1M": v.get("delta_1m", 0.0)}
        }
    return out

def evaluate_stock_calibrated(symbol, stock_cfg, bench_item, bench_delta):
    return {
        "symbol": symbol,
        "company_name": stock_cfg.get("company_name", symbol),
        "margin_trajectory": stock_cfg.get("margin_trajectory", "MARGIN_EXPANSION"),
        "projected_opm_change_bps": stock_cfg.get("projected_opm_change_bps", 80),
        "pricing_power": stock_cfg.get("pricing_power", "HIGH"),
        "operational_transmission_rationale": stock_cfg.get("operational_transmission_rationale", ""),
        "quarterly_ebitda_outlook": stock_cfg.get("quarterly_ebitda_outlook", "")
    }

if __name__ == "__main__":
    build_full_macro_report()
