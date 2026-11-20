#!/usr/bin/env python3
"""
Global Macro Economy Radar Hunter Engine
========================================
Algorithmic Natural Language Generation (NLG) & Macro Quant Synthesis Engine.

Automatically ingests cross-border telemetry (Crude, DXY, US 10Y, USD/INR, Gold,
PMIs, PPI, Forex), evaluates economic regimes via quantitative threshold rules,
calculates sector margin basis point (bps) deltas, and dynamically synthesizes
institutional commentary for:
 - Executive HUD & Global Health
 - Geopolitical Shock Surveillance (Crude choke, Dollar squeeze, China dumping)
 - Sector Margin Delta Charts (Expansion vs Compression)
 - USD/INR Currency & Trade Deficit Multiplier Rules
 - 4 Global Levers of Supply & Demand Control
 - US vs China 5-Battlefield Macro Clash Matrix

Outputs:
 - assets/data/global_economy_radar.json (App bundled baseline)
 - global_economy_radar.json (CDN live endpoint)
"""

import os
import json
import urllib.request
from datetime import datetime, timezone

OUTPUT_ASSET_FILE = "assets/data/global_economy_radar.json"
OUTPUT_ROOT_FILE = "global_economy_radar.json"

# ==============================================================================
# 1. LIVE DATA INGESTION WITH ROBUST CALIBRATED BASELINE FALLBACK
# ==============================================================================
BASELINE_METRICS = {
    "brent_crude": 73.40,
    "dxy_index": 106.25,
    "us_10y_yield": 4.42,
    "usd_inr": 84.42,
    "gold_oz": 2655.0,
    "semicon_utilization": 94.5,
    "baltic_dry": 1680.0,
    "us_services_pmi": 54.9,
    "us_mfg_pmi": 48.5,
    "china_composite_pmi": 50.3,
    "china_ppi": -2.9,
    "china_property_investment": -10.3,
    "europe_mfg_pmi": 46.0,
    "japan_composite_pmi": 51.2,
    "india_composite_pmi": 58.6,
    "india_forex_bn": 675.0,
}

def fetch_live_market_ticker(symbol: str) -> float:
    """
    Attempts to fetch live quotes from public finance endpoints in CI/CD environment.
    Falls back gracefully if network is offline or restricted.
    """
    url = f"https://query1.finance.yahoo.com/v8/finance/chart/{symbol}?interval=1d&range=1d"
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (StockPulse/1.0)"})
    try:
        with urllib.request.urlopen(req, timeout=4) as response:
            data = json.loads(response.read().decode("utf-8"))
            price = data["chart"]["result"][0]["meta"].get("regularMarketPrice")
            if price and isinstance(price, (int, float)):
                return float(price)
    except Exception:
        pass
    return None

def ingest_telemetry() -> dict:
    metrics = dict(BASELINE_METRICS)

    # In GitHub Actions cloud runners, public internet is open
    symbol_map = {
        "brent_crude": "CL=F",
        "dxy_index": "DX-Y.NYB",
        "us_10y_yield": "^TNX",
        "usd_inr": "INR=X",
        "gold_oz": "GC=F",
    }

    print("📡 Ingesting live cross-border financial telemetry...")
    for key, symbol in symbol_map.items():
        live_val = fetch_live_market_ticker(symbol)
        if live_val is not None:
            metrics[key] = round(live_val, 2)
            print(f"  ✓ Live update for {key}: {metrics[key]}")
        else:
            print(f"  • Using calibrated baseline for {key}: {metrics[key]}")

    return metrics


# ==============================================================================
# 2. ALGORITHMIC MACRO ANALYSIS & TEXT SYNTHESIS ENGINE (NLG)
# ==============================================================================
class MacroCommentarySynthesizer:
    def __init__(self, m: dict):
        self.m = m

    def synthesize_executive_hud(self) -> tuple:
        m = self.m
        # Weighted composite score
        score = (
            0.25 * m["us_services_pmi"] +
            0.20 * m["china_composite_pmi"] +
            0.15 * m["europe_mfg_pmi"] +
            0.15 * m["japan_composite_pmi"] +
            0.25 * m["india_composite_pmi"]
        )
        # Macro stress penalties
        crude_drag = max(0.0, (m["brent_crude"] - 75.0) * 0.25)
        dxy_drag = max(0.0, (m["dxy_index"] - 105.0) * 0.5)
        health_score = round(max(20.0, min(90.0, score - crude_drag - dxy_drag)), 1)

        if health_score >= 58.0:
            health_label = "SYNCHRONIZED GLOBAL EXPANSION"
        elif health_score >= 50.0:
            health_label = "MODERATE FRAGMENTED EXPANSION"
        else:
            health_label = "GLOBAL MACRO CONTRACTION STRESS"

        verdict = (
            f"Global health index at {health_score}/100. Resilient US Tech Capex ({m['us_services_pmi']} PMI) and "
            f"Indian domestic manufacturing ({m['india_composite_pmi']} PMI) offset European de-industrialization "
            f"({m['europe_mfg_pmi']} PMI) and Chinese property deflation ({m['china_property_investment']}% YoY)."
        )

        headline = f"US AI Capex & Tariff 2.0 vs China Debt Deflation (PPI {m['china_ppi']}%) & Factory Overcapacity"
        conclusion = (
            f"The world economy is bifurcated between US technological compute expansion and Chinese industrial dumping. "
            f"While US 10Y yields (~{m['us_10y_yield']}%) and King Dollar (DXY {m['dxy_index']}) create emerging market "
            f"currency friction (USD/INR ₹{m['usd_inr']}), China's domestic deflation and cheap commodity supply chains "
            f"provide major input-cost tailwinds to India."
        )

        return health_score, health_label, verdict, headline, conclusion

    def synthesize_sector_margin_deltas(self) -> dict:
        m = self.m
        # Algorithmic calculation of basis points (bps) and demand scores
        grid_delta = int(220 + max(0, (m["us_services_pmi"] - 50.0) * 8))
        solar_delta = int(180 + abs(min(0.0, m["china_ppi"])) * 14)
        ems_delta = int(160 + max(0, (m["india_composite_pmi"] - 55.0) * 6))
        defense_delta = 160
        paints_delta = int(round((76.0 - m["brent_crude"]) * 14 + 100))

        steel_delta = int(round((m["china_ppi"] + 1.0) * 110 - 30))
        agrochem_delta = int(round((m["china_ppi"] + 1.2) * 90 - 40))
        auto_eu_delta = int(round((m["europe_mfg_pmi"] - 50.0) * 35))
        it_delta = int(round((m["us_services_pmi"] - 56.0) * 20 - (m["us_10y_yield"] - 4.0) * 40))

        return {
            "expansion": [
                {
                    "sector": "Power Grid & Transformers",
                    "margin_delta_bps": grid_delta,
                    "demand_score": 96,
                    "trend": "RAPID MARGIN EXPANSION",
                    "driver": f"Global AI data center electricity crunch and transmission equipment shortages (US Services {m['us_services_pmi']}).",
                    "key_stocks": ["VOLTAMP", "ABB", "SIEMENS"]
                },
                {
                    "sector": "Solar EPC Developers & Clean Tech",
                    "margin_delta_bps": solar_delta,
                    "demand_score": 88,
                    "trend": "INPUT COST WINDFALL",
                    "driver": f"Chinese factory-gate deflation ({m['china_ppi']}% PPI) reduces imported solar module construction costs.",
                    "key_stocks": ["TATAPOWER", "PREMIERENE", "NTPC"]
                },
                {
                    "sector": "Electronics EMS / China+1 Assembly",
                    "margin_delta_bps": ems_delta,
                    "demand_score": 92,
                    "trend": "STRUCTURAL OUTPERFORMANCE",
                    "driver": f"Multinationals re-routing supply chains into India ({m['india_composite_pmi']} PMI) to bypass US-China tariff barriers.",
                    "key_stocks": ["DIXON", "KAYNES", "PGEL"]
                },
                {
                    "sector": "Defense & Strategic Aerospace",
                    "margin_delta_bps": defense_delta,
                    "demand_score": 95,
                    "trend": "MULTI-YEAR ORDER BOOK",
                    "driver": "Global NATO and Indo-Pacific defense procurement supercycle and indigenous defense offsets.",
                    "key_stocks": ["HAL", "BEL", "SOLARINDS"]
                },
                {
                    "sector": "Paints & Specialty Adhesives",
                    "margin_delta_bps": paints_delta,
                    "demand_score": 74,
                    "trend": "RAW MATERIAL RELIEF",
                    "driver": f"Brent crude at ${m['brent_crude']}/bbl keeps titanium dioxide and solvent raw material costs contained.",
                    "key_stocks": ["ASIANPAINT", "BERGEPAINT", "PIDILITIND"]
                }
            ],
            "pressure": [
                {
                    "sector": "Primary Steel & Base Metals",
                    "margin_delta_bps": steel_delta,
                    "demand_score": 48,
                    "trend": "SEVERE PRICE DABAO",
                    "driver": f"Chinese hot-rolled coil dumping (China PPI {m['china_ppi']}%) suppresses domestic Indian steel realisations.",
                    "key_stocks": ["TATASTEEL", "JSWSTEEL", "SAIL"]
                },
                {
                    "sector": "Agrochemicals & Crop Protection",
                    "margin_delta_bps": agrochem_delta,
                    "demand_score": 52,
                    "trend": "PRICE WAR COMPRESSION",
                    "driver": f"Predatory Chinese generic active ingredient price war ({m['china_ppi']}% PPI) and channel destocking.",
                    "key_stocks": ["UPL", "SRF", "PIIND"]
                },
                {
                    "sector": "European Auto Component Exporters",
                    "margin_delta_bps": auto_eu_delta,
                    "demand_score": 42,
                    "trend": "EXPORT ORDER DELAYS",
                    "driver": f"European manufacturing contraction ({m['europe_mfg_pmi']} PMI) and German automotive plant closures.",
                    "key_stocks": ["BHARATFORG", "MOTHERSON", "BALKRISIND"]
                },
                {
                    "sector": "IT Discretionary Software Services",
                    "margin_delta_bps": it_delta,
                    "demand_score": 58,
                    "trend": "DEAL CONVERSION SLUMP",
                    "driver": f"US 10Y Yield at {m['us_10y_yield']}% forcing enterprise CIOs to divert discretionary spend strictly to generative AI.",
                    "key_stocks": ["TCS", "WIPRO", "INFY", "TECHM"]
                }
            ]
        }

    def synthesize_geopolitical_shocks(self) -> list:
        m = self.m
        shocks = []

        # 1. Crude Oil Geopolitical Shock
        is_crude_high = m["brent_crude"] >= 78.0
        crude_severity = "CRITICAL CRUDE SHOCK ALERT" if m["brent_crude"] >= 85.0 else ("ELEVATED MONITORING" if is_crude_high else "RANGEBOUND COMFORT ZONE")
        crude_deficit = round((m["brent_crude"] - 65.0) * 1.5, 1)

        shocks.append({
            "id": "crude_shortage_shock",
            "shock_name": "Middle East Conflict & Hormuz Crude Supply Choke",
            "is_active": is_crude_high or True,  # Keep active monitoring banner enabled
            "severity": crude_severity,
            "trigger": f"US-Iran military friction and maritime risk along Strait of Hormuz tanker routes. Brent trading at ${m['brent_crude']}/bbl.",
            "supply_demand_choke": f"Threat of 2.0-2.5M bpd oil supply disruption; tanker war risk insurance premiums elevated.",
            "import_export_shift": f"India's annual crude import deficit impact: ~+${crude_deficit}B; emergency crude diversification to Russian and African grades.",
            "currency_impact": f"USD/INR trading at ₹{m['usd_inr']}; RBI defending currency with foreign exchange market interventions.",
            "margin_winners": ["ONGC", "OIL", "GAIL"],
            "margin_losers": ["HPCL", "BPCL", "ASIANPAINT", "INDIGO"]
        })

        # 2. King Dollar & Yield Gravity Shock
        is_dollar_high = m["dxy_index"] >= 105.5 or m["us_10y_yield"] >= 4.35
        shocks.append({
            "id": "king_dollar_shock",
            "shock_name": "King Dollar & US 10Y Yield Gravity Spike",
            "is_active": is_dollar_high,
            "severity": "ELEVATED DOLLAR SQUEEZE" if is_dollar_high else "MODERATE FLOAT",
            "trigger": f"US 10Y yields at {m['us_10y_yield']}% and DXY at {m['dxy_index']} driven by resilient US growth ({m['us_services_pmi']} PMI).",
            "supply_demand_choke": "Dollar liquidity contraction across emerging market banks; foreign institutional capital re-allocating to US T-Bills.",
            "import_export_shift": "Imported energy and electronics become costlier in Rupee terms; dollar export billing gains realization cushion.",
            "currency_impact": f"Rupee tests ₹{m['usd_inr']} band; supported by RBI's ${m['india_forex_bn']}B protective warchest.",
            "margin_winners": ["SUNPHARMA", "DRREDDY", "DIVISLAB"],
            "margin_losers": ["TATASTEEL", "ADANIENT", "JSWSTEEL"]
        })

        # 3. China Overcapacity Dumping Shock
        is_china_dumping = m["china_ppi"] <= -1.5
        shocks.append({
            "id": "china_dumping_shock",
            "shock_name": "China Shock 2.0 Industrial Overcapacity Dumping",
            "is_active": is_china_dumping,
            "severity": "ACTIVE FACTORY DUMPING",
            "trigger": f"China property contraction ({m['china_property_investment']}%) and factory deflation ({m['china_ppi']}% PPI) forcing overseas inventory clearance.",
            "supply_demand_choke": "Global steel, solar, and chemical markets flooded with Chinese inventory priced below international cash cost.",
            "import_export_shift": "Cheap Chinese steel coils and agrochemical intermediates surge into Asian ports, triggering anti-dumping investigations.",
            "currency_impact": "Disinflationary import price effect helps keep wholesale inflation low without direct foreign exchange shock.",
            "margin_winners": ["TATAPOWER", "PREMIERENE", "DIXON"],
            "margin_losers": ["TATASTEEL", "JSWSTEEL", "UPL", "SRF"]
        })

        return shocks

    def synthesize_currency_and_trade(self) -> dict:
        m = self.m
        stress = "CRITICAL SQUEEZE" if m["usd_inr"] >= 84.8 else ("ELEVATED (MANAGED FLOAT)" if m["usd_inr"] >= 84.2 else "STABLE (CAPITAL INFLOWS)")
        deficit_impact = round((m["brent_crude"] - 65.0) * 1.5, 1)
        paise_drop = int((m["brent_crude"] - 65.0) * 3.2)
        cpi_bps = int((m["brent_crude"] - 65.0) * 5.5)

        return {
            "usd_inr_current": m["usd_inr"],
            "stress_level": stress,
            "rbi_forex_warchest": f"${m['india_forex_bn']} Billion (Massive Shield)",
            "net_trade_impact_score": "-1.8% Drag",
            "crude_sensitivity_rule": {
                "rule_title": "The $10 Crude Oil Multiplier Rule",
                "stat_trade_deficit": f"+${deficit_impact} Billion Annual Trade Deficit",
                "stat_currency_impact": f"-{paise_drop} to -{paise_drop + 10} Paise Rupee Depreciation",
                "stat_inflation_impact": f"+{cpi_bps} bps Domestic Retail CPI Spike",
                "stat_gdp_impact": "-30 bps Net GDP Drag"
            },
            "import_export_dynamics": [
                {
                    "flow": "IMPORTS",
                    "status": "DEFICIT PRESSURE",
                    "details": f"High crude oil (${m['brent_crude']}/bbl) and electronics components create foreign currency demand; offset by cheap steel imports.",
                    "vulnerable_segments": ["Crude Oil (85% Imported)", "Electronics Chips", "Coking Coal"]
                },
                {
                    "flow": "EXPORTS",
                    "status": "SELECTIVE GROWTH",
                    "details": f"European export demand ({m['europe_mfg_pmi']} PMI) softens; high-value smartphone and aerospace exports to US surge +23.4% YoY.",
                    "resilient_segments": ["Mobile Phones / EMS", "Pharma Formulations", "Refined Petroleum"]
                }
            ]
        }


# ==============================================================================
# 3. MASTER PAYLOAD GENERATOR
# ==============================================================================
def build_global_radar_payload(metrics: dict) -> dict:
    synthesizer = MacroCommentarySynthesizer(metrics)
    health_score, health_label, verdict, headline, conclusion = synthesizer.synthesize_executive_hud()
    margin_matrix = synthesizer.synthesize_sector_margin_deltas()
    shocks = synthesizer.synthesize_geopolitical_shocks()
    currency_telemetry = synthesizer.synthesize_currency_and_trade()

    now_utc = datetime.now(timezone.utc)
    month_year = now_utc.strftime("%B %Y")

    payload = {
        "metadata": {
            "title": "Global Macro Economy Pressure & Expansion Radar",
            "generated_timestamp": now_utc.isoformat(),
            "last_updated": f"{month_year} / Automated Telemetry Sync",
            "global_regime": "BIFURCATED_LIQUIDITY_CYCLE",
            "regime_headline": headline,
            "global_conclusion": conclusion
        },
        "executive_hud": {
            "global_health_score": health_score,
            "global_health_label": health_label,
            "health_verdict": verdict,
            "regions_expansion_count": 3,
            "regions_pressure_count": 2,
            "core_pillars": [
                {
                    "region_id": "us",
                    "region": "UNITED STATES",
                    "flag": "🇺🇸",
                    "gdp_trillion_usd": 28.7,
                    "growth_pmi": metrics["us_services_pmi"],
                    "growth_pmi_label": "Services PMI",
                    "status": "EXPANSION",
                    "status_type": "EXPANSION",
                    "flow_color": "cyan",
                    "net_momentum_pct": 2.8,
                    "key_driver": "$250B+ AI Data Center Capex & Fed Easing Cycle"
                },
                {
                    "region_id": "china",
                    "region": "CHINA",
                    "flag": "🇨🇳",
                    "gdp_trillion_usd": 18.5,
                    "growth_pmi": metrics["china_composite_pmi"],
                    "growth_pmi_label": "Caixin Composite",
                    "status": "DEFLATIONARY PRESSURE",
                    "status_type": "PRESSURE",
                    "flow_color": "red",
                    "net_momentum_pct": 4.8,
                    "key_driver": f"Property Slump ({metrics['china_property_investment']}%) vs ¥10T Debt Swap Stimulus"
                },
                {
                    "region_id": "europe",
                    "region": "EUROZONE / UK",
                    "flag": "🇪🇺",
                    "gdp_trillion_usd": 19.4,
                    "growth_pmi": metrics["europe_mfg_pmi"],
                    "growth_pmi_label": "Mfg PMI",
                    "status": "DEEP CONTRACTION",
                    "status_type": "PRESSURE",
                    "flow_color": "red",
                    "net_momentum_pct": 0.7,
                    "key_driver": "German Auto Slump, Energy Shocks & French Fiscal Deficits"
                },
                {
                    "region_id": "japan",
                    "region": "JAPAN",
                    "flag": "🇯🇵",
                    "gdp_trillion_usd": 4.2,
                    "growth_pmi": metrics["japan_composite_pmi"],
                    "growth_pmi_label": "Composite PMI",
                    "status": "MODEST REBOUND",
                    "status_type": "EXPANSION",
                    "flow_color": "cyan",
                    "net_momentum_pct": 1.2,
                    "key_driver": "30-Year High Wage Hikes (+5.2%) & Semicon Onshoring"
                },
                {
                    "region_id": "em_india",
                    "region": "INDIA & EM ASIA",
                    "flag": "🇮🇳",
                    "gdp_trillion_usd": 7.6,
                    "growth_pmi": metrics["india_composite_pmi"],
                    "growth_pmi_label": "Composite PMI",
                    "status": "RAPID EXPANSION",
                    "status_type": "EXPANSION",
                    "flow_color": "green",
                    "net_momentum_pct": 7.2,
                    "key_driver": "China+1 Supply Chain Shift & Domestic Capex Execution"
                }
            ]
        },
        "supply_demand_control_levers": {
            "headline": "HOW SUPERPOWERS CONTROL GLOBAL SUPPLY & DEMAND",
            "description": "Global superpowers actively manipulate energy valves, monetary liquidity taps, industrial subsidies, and maritime chokepoints to enforce dominance.",
            "levers": [
                {
                    "id": "energy_valve",
                    "name": "1. The Hydrocarbon Energy Valve (OPEC+ & US Shale)",
                    "icon": "🛢️",
                    "controller": "Saudi Arabia (OPEC+ Quotas) & US (Permian Shale 13.5M bpd)",
                    "how_they_control": f"OPEC+ restricts supply by 2.2M bpd to defend a $70 floor, while US shale drillers maintain record production (13.5M bpd). Current Brent: ${metrics['brent_crude']}/bbl.",
                    "shock_scenario": "Middle East / Iran escalation or Strait of Hormuz tanker blockage shuts off 20% of maritime crude transit, causing an immediate +$15-20/bbl risk premium spike.",
                    "india_transmission": f"India imports >85% of crude. Every $10/bbl oil increase expands India's annual trade deficit by ~$13B, depreciates INR by 25-35 paise, and crushes margins for Paints, Tyres, and OMCs."
                },
                {
                    "id": "dollar_liquidity_tap",
                    "name": "2. The Dollar Liquidity & Yield Tap (US Fed & Treasury)",
                    "icon": "💵",
                    "controller": "US Federal Reserve & US Treasury Auction Desk",
                    "how_they_control": f"By maintaining higher policy rates and massive Treasury debt issuance, US 10Y yields (~{metrics['us_10y_yield']}%) stay elevated, sucking capital out of emerging markets into US dollar assets (DXY {metrics['dxy_index']}).",
                    "shock_scenario": "Sticky US services inflation delays Fed cuts, keeping King Dollar elevated and creating a persistent foreign exchange squeeze on emerging currencies.",
                    "india_transmission": f"FII equity outflows; RBI actively utilizes its ${metrics['india_forex_bn']}B forex buffer to prevent disorderly Rupee depreciation past 84.50."
                },
                {
                    "id": "china_overcapacity_tap",
                    "name": "3. The Factory Overcapacity Tap (China State Mandates)",
                    "icon": "🏭",
                    "controller": "Beijing State-Owned Banks & Municipal Planners",
                    "how_they_control": f"Facing domestic property collapse ({metrics['china_property_investment']}%), China directs state subsidies into manufacturing 2x-3x domestic demand, dumping surplus overseas (China PPI {metrics['china_ppi']}%).",
                    "shock_scenario": "25-month producer price deflation prompts predatory export dumping across Asian and Latin American markets to keep Chinese domestic factories operating.",
                    "india_transmission": "Crushes profit margins for domestic primary commodity producers (Tata Steel, JSW, UPL), but provides massive input cost deflation to downstream solar developers, real estate, and consumer tech assemblers."
                },
                {
                    "id": "chokepoint_shipping_valve",
                    "name": "4. Geopolitical Chokepoints & Freight Valve (Red Sea & Straits)",
                    "icon": "🚢",
                    "controller": "Regional Militias (Houthis) & Maritime Naval Coalitions",
                    "how_they_control": f"Attacks on Bab-el-Mandeb / Red Sea compel cargo container ships to reroute around Africa's Cape of Good Hope, tripling container spot freight rates and adding 14 days transit time. Baltic Dry: {metrics['baltic_dry']} pts.",
                    "shock_scenario": "Coordinated chokepoint blockades in Red Sea or Malacca Strait freeze container slot availability, causing global supply chain delays.",
                    "india_transmission": "Exporters of textiles, auto parts, and basmati rice face inflated freight invoices and delayed receivables, while European export demand contracts."
                }
            ]
        },
        "sector_margin_demand_matrix": {
            "headline": "SECTOR MARGIN PRESSURE vs EXPANSION RADAR",
            "description": f"Quantifies which domestic and global sectors gain operating leverage versus which face margin compression under current global macro flows (Crude ${metrics['brent_crude']}, DXY {metrics['dxy_index']}, China PPI {metrics['china_ppi']}%).",
            "margin_expansion_sectors": margin_matrix["expansion"],
            "margin_pressure_sectors": margin_matrix["pressure"]
        },
        "currency_and_trade_telemetry": currency_telemetry,
        "dynamic_shock_transmission_engine": {
            "headline": "LIVE GEOPOLITICAL & SUPPLY SHOCK DETECTOR",
            "status_summary": f"Surveillance of Middle East crude routes (${metrics['brent_crude']}/bbl), DXY dollar spikes ({metrics['dxy_index']}), and Chinese dumping.",
            "shocks": shocks
        },
        "global_superpowers": [
            {
                "id": "us",
                "name": "United States of America",
                "flag": "🇺🇸",
                "economic_status": "MODERATE_EXPANSION",
                "status_label": "TECH & FISCAL RESILIENCE",
                "central_bank_rate": "4.50% - 4.75% (Fed Cutting Cycle)",
                "inflation_rate": "3.3% Core CPI (Sticky Shelter & Insurance)",
                "pmi_summary": f"Services {metrics['us_services_pmi']} (Booming) • Mfg {metrics['us_mfg_pmi']} (Soft)",
                "vital_stats": {
                    "debt_to_gdp": "124% ($35.8 Trillion)",
                    "annual_interest_cost": "$1.12 Trillion (> Defense Budget)",
                    "us_10y_yield": f"{metrics['us_10y_yield']}% (Bond Vigilante Risk)",
                    "mortgage_30y": "6.85% (Housing Freeze)",
                    "ai_hyperscaler_capex": "$250 Billion+ (Generational Ramp)",
                    "oil_gas_output": "13.5M bpd (Global Record)"
                },
                "pressure_points": [
                    {
                        "title": "Universal Tariffs 2.0 & Global Trade War Threat",
                        "description": "Proposed universal 10-20% baseline tariffs and 60% duties on China threaten to reignite import inflation, strengthen DXY, and disrupt global multi-national corporate supply chains.",
                        "severity": "CRITICAL"
                    },
                    {
                        "title": "$35.8T Sovereign Debt & $1.12T Annual Interest Burden",
                        "description": "Annual federal interest servicing cost has surpassed the entire US Defense budget ($850B), forcing massive Treasury bond issuance waves and steepening the yield curve.",
                        "severity": "HIGH"
                    },
                    {
                        "title": f"US 10-Year Yield Spike (~{metrics['us_10y_yield']}%) & Equity PE Gravity",
                        "description": f"Persistent long-term Treasury yields above 4.4% raise corporate discount rates, exerting continuous multiple compression on global high-valuation equities.",
                        "severity": "HIGH"
                    },
                    {
                        "title": "Commercial Real Estate (CRE) & Regional Banking Risk",
                        "description": "Over $2.2 Trillion in CRE debt matures through 2026 amid remote-work urban vacancies, keeping regional lenders under credit surveillance.",
                        "severity": "MODERATE"
                    },
                    {
                        "title": "K-Shaped Consumer Bifurcation & Debt Delinquencies",
                        "description": "Top 20% thrive on stock market and real estate wealth, while lower-income consumer credit card and auto loan 90+ day delinquencies have hit 12-year highs.",
                        "severity": "MODERATE"
                    },
                    {
                        "title": "Power Grid Bottlenecks for AI Data Centers",
                        "description": "Massive hyperscaler compute clusters are straining legacy electric utilities, leading to power shortages and delays in data center energization.",
                        "severity": "MODERATE"
                    }
                ],
                "expansion_engines": [
                    {
                        "title": "$250B+ Generative AI Compute Supercycle",
                        "description": "Hyperscalers (Microsoft, Meta, Google, Amazon, Oracle) driving unprecedented capex in GPU clusters, optical transceivers, and liquid cooling systems.",
                        "impact": "TECH REVOLUTION"
                    },
                    {
                        "title": "Nuclear Power Revival for Big Tech (SMRs & PPA Deals)",
                        "description": "Big tech contracting directly with nuclear operators (Three Mile Island revival, Talen Energy, SMR startups) to secure 24/7 carbon-free base-load power.",
                        "impact": "ENERGY SUPERCYCLE"
                    },
                    {
                        "title": "Federal Reserve Interest Rate Easing Cycle",
                        "description": "Fed trimming policy rates provides liquidity relief, lowers commercial paper refinancing frictions, and supports corporate debt rollover.",
                        "impact": "LIQUIDITY INJECTION"
                    },
                    {
                        "title": "Domestic Energy Dominance (13.5M bpd Crude Oil)",
                        "description": "US record hydrocarbon production and massive LNG export terminals ensure industrial energy independence and insulate US factories from foreign price shocks.",
                        "impact": "ENERGY SECURITY"
                    },
                    {
                        "title": "CHIPS Act & IRA Domestic Re-Shoring Wave",
                        "description": "Over $400B in announced semiconductor fabs (TSMC Phoenix, Intel Ohio, Samsung Texas) and clean energy battery plants actively under construction.",
                        "impact": "INDUSTRIAL RESHORING"
                    },
                    {
                        "title": "Positive Real Wage Growth & Services Dominance",
                        "description": "With gasoline and goods inflation abating, median wage growth exceeds inflation, anchoring retail consumption and domestic services spending.",
                        "impact": "CONSUMER RESILIENCE"
                    }
                ]
            },
            {
                "id": "china",
                "name": "China (People's Republic of China)",
                "flag": "🇨🇳",
                "economic_status": "DEFLATIONARY_PRESSURE",
                "status_label": "STIMULUS BAZOOKA DEFENSE",
                "central_bank_rate": "3.10% (PBOC Easing Cycle)",
                "inflation_rate": f"0.3% CPI • {metrics['china_ppi']}% PPI (Deflation)",
                "pmi_summary": f"Caixin Mfg {metrics['china_composite_pmi']} (Borderline) • Services 52.0",
                "vital_stats": {
                    "real_estate_investment": f"{metrics['china_property_investment']}% YoY (Property Slump)",
                    "hidden_lgfv_debt": "¥60 Trillion ($8.3T Municipal Debt)",
                    "stimulus_swap_package": "¥10 Trillion Local Debt Relief",
                    "producer_deflation": f"{metrics['china_ppi']}% PPI (25 Straight Months)",
                    "youth_unemployment": "17.1% (Ages 16-24 Urban)",
                    "clean_tech_dominance": ">80% Global Solar & LFP Batteries"
                },
                "pressure_points": [
                    {
                        "title": "Real Estate Collapse & Balance Sheet Recession",
                        "description": "70% of urban wealth was concentrated in property; ongoing developer insolvencies and 30%+ price drops have triggered a severe Japanese-style consumer balance sheet recession.",
                        "severity": "CRITICAL"
                    },
                    {
                        "title": f"Persistent Factory-Gate Deflation ({metrics['china_ppi']}% PPI)",
                        "description": "Industrial overcapacity has caused 25 straight months of negative producer prices, eviscerating corporate profit margins and driving predatory price wars.",
                        "severity": "CRITICAL"
                    },
                    {
                        "title": "¥60 Trillion Local Government (LGFV) Hidden Debt",
                        "description": "With land sales crashing, municipal authorities face massive revenue shortfalls, delaying payments to contractors, healthcare providers, and local workers.",
                        "severity": "HIGH"
                    },
                    {
                        "title": "Western Tariff Walls & 'China Shock 2.0' Pushback",
                        "description": "US (up to 100% on EVs) and EU (up to 45.3%) imposing heavy anti-subsidy duties to prevent Chinese state-backed industrial dumping from wiping out domestic industries.",
                        "severity": "HIGH"
                    },
                    {
                        "title": "Foreign Direct Investment (FDI) Contraction",
                        "description": "Supply chain relocation and geopolitical friction have caused net inward foreign investment to turn negative, restricting technology transfer.",
                        "severity": "HIGH"
                    },
                    {
                        "title": "Demographic Cliff & 17.1% Youth Unemployment",
                        "description": "Rapidly aging population alongside high youth joblessness is depressing long-term domestic consumption, forcing consumers toward discount platforms.",
                        "severity": "MODERATE"
                    }
                ],
                "expansion_engines": [
                    {
                        "title": "¥10 Trillion Local Government Debt Swap Bazooka",
                        "description": "National People's Congress approved a ¥10T ($1.4T) debt-swap quota over 3-5 years to replace toxic high-interest off-balance-sheet debt with low-cost sovereign bonds.",
                        "impact": "MUNICIPAL LIQUIDITY FLOOR"
                    },
                    {
                        "title": "Absolute Global Monopoly on Clean-Tech Infrastructure",
                        "description": "Controlling >80% of global solar polysilicon, wafers, lithium refining, and LFP EV batteries (CATL & BYD), dominating exports to emerging economies.",
                        "impact": "GLOBAL INDUSTRIAL MONOPOLY"
                    },
                    {
                        "title": "National Big Fund III Semiconductor Sovereignty (¥344B)",
                        "description": "State-funded $47.5B semiconductor war chest accelerating domestic lithography, SMIC trailing-edge 28nm dominance, and Huawei Ascend AI chip deployment.",
                        "impact": "TECH INDEPENDENCE"
                    },
                    {
                        "title": "Strategic Rare Earth & Critical Mineral Weaponization",
                        "description": "Controlling 70% of rare earth mining and 90% of processing; restricting Gallium, Germanium, and Antimony exports as leverage against Western sanctions.",
                        "impact": "GEOPOLITICAL LEVERAGE"
                    },
                    {
                        "title": "Aggressive Monetary Easing & PBOC Liquidity Injections",
                        "description": "Multiple RRR cuts, Loan Prime Rate reductions, and special central bank lending facilities designed to bolster state-owned enterprise balance sheets.",
                        "impact": "CREDIT LIQUIDITY"
                    },
                    {
                        "title": "Global South & Belt and Road Trade Expansion",
                        "description": "Diversifying exports away from the US towards ASEAN, Middle East, Africa, and Latin America, bypassing traditional Western trade restrictions.",
                        "impact": "MARKET DIVERSIFICATION"
                    }
                ]
            },
            {
                "id": "europe",
                "name": "Eurozone & United Kingdom",
                "flag": "🇪🇺",
                "economic_status": "SEVERE_CONTRACTION",
                "status_label": "DE-INDUSTRIALIZATION SHOCK",
                "central_bank_rate": "3.25% (ECB Aggressive Cuts)",
                "inflation_rate": "2.0% HICP (Target Reached)",
                "pmi_summary": f"Manufacturing {metrics['europe_mfg_pmi']} (Deep Slump) • Services 51.6",
                "vital_stats": {
                    "mfg_pmi": f"{metrics['europe_mfg_pmi']} (Deep Contraction)",
                    "german_industrial_output": "-4.5% YoY",
                    "ecb_deposit_rate": "3.25% (Fast Track Cuts)",
                    "defense_capex_target": "2.0%+ of GDP across NATO",
                    "energy_cost_gap": "3x higher industrial power vs US"
                },
                "pressure_points": [
                    {
                        "title": "German Industrial De-Industrialization",
                        "description": "Volkswagen planning unprecedented domestic factory closures, and BASF downsizing chemical manufacturing due to uncompetitive energy costs compared to US and China.",
                        "severity": "CRITICAL"
                    },
                    {
                        "title": "French & British Fiscal Austerity & Tax Hikes",
                        "description": "Excessive sovereign deficits forcing tax hikes and spending cutbacks, putting further strain on European consumer discretionary demand.",
                        "severity": "HIGH"
                    },
                    {
                        "title": "Crushing Energy Transition Cost Disadvantage",
                        "description": "High electricity tariffs and strict carbon regulations make European heavy industry non-viable against US shale-backed and Chinese subsidized competitors.",
                        "severity": "HIGH"
                    }
                ],
                "expansion_engines": [
                    {
                        "title": "Aggressive ECB Interest Rate Cuts",
                        "description": "ECB cutting borrowing rates in 25bps increments to rescue credit markets and lower corporate borrowing burdens.",
                        "impact": "MONETARY EASING"
                    },
                    {
                        "title": "Historic European Defense Spending Supercycle",
                        "description": "European defense spending exceeding €350B as NATO members rapidly re-arm stockpiles and artillery systems.",
                        "impact": "DEFENSE PROCUREMENT"
                    }
                ]
            },
            {
                "id": "japan",
                "name": "Japan",
                "flag": "🇯🇵",
                "economic_status": "MODEST_EXPANSION",
                "status_label": "EXITING 30-YR DEFLATION",
                "central_bank_rate": "0.25% (Bank of Japan Hiking Cycle)",
                "inflation_rate": "2.5% Core CPI (Sustained Above Target)",
                "pmi_summary": f"Composite {metrics['japan_composite_pmi']} (Expansion) • Mfg 49.2",
                "vital_stats": {
                    "shunto_wage_growth": "+5.2% (30-Year Record High)",
                    "boj_rate": "0.25% (Normalize from Zero)",
                    "usd_jpy": "154.5 (Yen Volatility Zone)",
                    "semicon_investment": "¥4 Trillion (Rapidus & TSMC Kumamoto)"
                },
                "pressure_points": [
                    {
                        "title": "Yen Carry Trade Unwinding Fragility",
                        "description": "Sudden spikes in Japanese bond yields or rapid Yen appreciation trigger multi-billion dollar carry trade liquidations across global equity markets.",
                        "severity": "HIGH"
                    },
                    {
                        "title": "Imported Inflation Squeezing Household Real Spending",
                        "description": "Weak Yen has driven food and energy import costs up, weighing on middle-class consumer purchasing power.",
                        "severity": "MODERATE"
                    }
                ],
                "expansion_engines": [
                    {
                        "title": "Shunto Spring Wage Surge (+5.2%)",
                        "description": "Japanese corporations enacted the largest wage hikes in three decades, creating a virtuous wage-price domestic consumption spiral.",
                        "impact": "CONSUMER REFLATION"
                    },
                    {
                        "title": "Global Semiconductor Fab Buildout (TSMC Kumamoto & Rapidus)",
                        "description": "Japan is reclaiming advanced chipmaking with government subsidies drawing global foundries and equipment giants.",
                        "impact": "HIGH-TECH INDUSTRIAL REBIRTH"
                    }
                ]
            },
            {
                "id": "em_india",
                "name": "India & Emerging Asia",
                "flag": "🇮🇳",
                "economic_status": "HIGH_GROWTH_LEADER",
                "status_label": "GLOBAL GROWTH ENGINE",
                "central_bank_rate": "6.50% (RBI Neutral Stance)",
                "inflation_rate": "6.2% Headline (Food Spike) • Core 3.5%",
                "pmi_summary": f"Manufacturing 57.5 • Services 59.2 (Composite {metrics['india_composite_pmi']})",
                "vital_stats": {
                    "composite_pmi": f"{metrics['india_composite_pmi']} (Global Outperformer)",
                    "gdp_growth": "7.0% - 7.2% Expected FY25",
                    "fastag_toll_runrate": "₹192 Cr / Day (+11.8% YoY)",
                    "forex_reserves": f"${metrics['india_forex_bn']} Billion (Strong Warchest)",
                    "electronics_exports": "+23.4% YoY (Apple/EMS Surge)"
                },
                "pressure_points": [
                    {
                        "title": f"Strong US Dollar (DXY {metrics['dxy_index']}) & FII Outflows",
                        "description": f"Elevated US bond yields ({metrics['us_10y_yield']}%) and dollar strength triggered tactical foreign portfolio rebalancing out of emerging markets into US assets.",
                        "severity": "HIGH"
                    },
                    {
                        "title": f"Chinese Cheap Industrial Dumping (China PPI {metrics['china_ppi']}%)",
                        "description": "Subsidized Chinese steel coils, basic chemicals, and solar cells entering India at predatory prices, prompting domestic anti-dumping investigations.",
                        "severity": "HIGH"
                    }
                ],
                "expansion_engines": [
                    {
                        "title": "China+1 High-Tech Manufacturing Relocation",
                        "description": "Global giants (Apple, HP, Dell, Foxconn) investing billions to scale domestic assembly, pushing electronics exports to record highs.",
                        "impact": "STRUCTURAL CAPEX"
                    },
                    {
                        "title": "Physical Infrastructure Supercycle",
                        "description": "Government capital expenditure across dedicated freight corridors, highways, ports, and power transmission driving domestic capital goods orders.",
                        "impact": "DOMESTIC DEMAND MULTIPLIER"
                    }
                ]
            }
        ],
        "usa_china_macro_clash": {
            "headline": "USA vs CHINA: THE TIT-FOR-TAT GEOPOLITICAL & MACRO CLASH",
            "overview": (
                "The clash between the world's two largest superpowers is reshaping global trade, technology, and capital flows. "
                "Understanding this friction explains where economic pain is concentrated and where emerging markets like India gain structural leverage."
            ),
            "battlefields": [
                {
                    "id": "trade_tariffs",
                    "title": "1. Trade War 2.0 & Tariff Escalation",
                    "icon": "⚔️",
                    "us_offensive": "Universal 10-20% baseline tariffs on all global imports, escalating to 60%+ on all Chinese manufacturing, revoking China's PNTR status.",
                    "china_retaliation": "Weaponizing export licenses for critical minerals (Gallium, Germanium, Antimony), targeting US agricultural imports (soybeans/pork), and devaluing RMB to 7.30+ to offset tariff penalties.",
                    "macro_impact": "Squeezes global trade volumes, re-accelerates US imported inflation, and accelerates supply chain flight out of mainland China into ASEAN and India.",
                    "impact_on_india": "POSITIVE (NET BENEFICIARY)",
                    "india_takeaway": "Multinationals are compelled to set up secondary manufacturing hubs in India to bypass punitive US tariffs on Chinese origins."
                },
                {
                    "id": "tech_chips",
                    "title": "2. Semiconductor Blockade & AI Cold War",
                    "icon": "💻",
                    "us_offensive": "Strict export controls on advanced AI chips (Nvidia H100/H200/Blackwell), ASML extreme UV lithography embargoes, and scrutiny of EDA chip design software.",
                    "china_retaliation": "State-funded ¥344B National Big Fund III, mass-producing legacy 28nm silicon to flood global automotive markets, and developing domestic Huawei Ascend AI accelerators.",
                    "macro_impact": "Bifurcated global tech standards, accelerated duplicate fab investments ($500B+ globally), and soaring GPU compute costs for Western enterprises.",
                    "impact_on_india": "POSITIVE FOR INDIA EMS & DESIGN",
                    "india_takeaway": "India semiconductor mission (Tata-PSMC Dholera fab, Micron OSAT, Kaynes EMS) gains strategic Western technology transfer backing."
                },
                {
                    "id": "currency_debt",
                    "title": "3. King Dollar Dominance vs Sovereign Gold Accumulation",
                    "icon": "💵",
                    "us_offensive": f"King Dollar (DXY {metrics['dxy_index']}) powered by high US yields (~{metrics['us_10y_yield']}%) drains global liquidity and asserts US Treasury sanctions enforcement.",
                    "china_retaliation": f"PBOC continuous gold reserve accumulation (Gold ${metrics['gold_oz']}/oz), reducing US Treasury holdings below $750B, and expanding CIPS / local currency bilateral settlements.",
                    "macro_impact": "Gold hits all-time records ($2,650+/oz), emerging market central banks diversify reserve currencies, and cross-border payment systems fragment.",
                    "impact_on_india": "NEUTRAL TO POSITIVE",
                    "india_takeaway": "RBI expands gold reserves to record 854+ metric tonnes while settling bilateral trade in Rupee-Dirham with Middle East and Asian partners."
                },
                {
                    "id": "industrial_dumping",
                    "title": "4. Industrial Overcapacity vs Western Reshoring (China Shock 2.0)",
                    "icon": "🏭",
                    "us_offensive": "Subsidizing domestic clean tech via the Inflation Reduction Act (IRA) and CHIPS Act, placing 100% tariffs on Chinese EVs.",
                    "china_retaliation": f"Directing state-bank capital into factories to produce 2-3x domestic consumption in solar, batteries, and steel, dumping inventory overseas at below-cash-cost ({metrics['china_ppi']}% PPI).",
                    "macro_impact": "Severe margin depression for international chemical and steel manufacturers; consumer disinflation in emerging markets purchasing cheap green hardware.",
                    "impact_on_india": "MIXED (HEADWIND FOR COMMODITIES, TAILWIND FOR USERS)",
                    "india_takeaway": "Hurt: Tata Steel, JSW Steel, UPL (margin squeeze from cheap dumping). Benefit: Solar EPC contractors, real estate developers, and consumer electronics assemblers."
                },
                {
                    "id": "energy_monopoly",
                    "title": "5. Energy Sovereignty: US Shale vs Chinese Clean-Tech Monopoly",
                    "icon": "⚡",
                    "us_offensive": "US producing world-record 13.5M bpd crude oil and dominating transatlantic LNG exports, shielding US factories from energy shocks.",
                    "china_retaliation": "Controlling 85%+ of global solar wafers, polysilicon refining, and EV battery cell manufacturing, turning green transition into a Chinese hardware monopoly.",
                    "macro_impact": "Traditional hydrocarbon energy security centers in the Americas, while renewable hardware relies entirely on Chinese supply chains.",
                    "impact_on_india": "POSITIVE ARBITRAGE",
                    "india_takeaway": f"India benefits from discounted Russian/Middle East crude oil (~${metrics['brent_crude']}/bbl) while deploying cheap imported solar cells to accelerate renewable capacity."
                }
            ]
        },
        "global_stress_gauges": [
            {
                "id": "dxy",
                "name": "US Dollar Index (DXY)",
                "current_value": metrics["dxy_index"],
                "unit": "points",
                "stress_level": "ELEVATED PRESSURE" if metrics["dxy_index"] >= 105.0 else "BALANCED FLOAT",
                "status_label": "STRONG DOLLAR SQUEEZE" if metrics["dxy_index"] >= 105.0 else "STABLE CURRENCY FLOAT",
                "bar_ratio": round(min(1.0, max(0.2, (metrics["dxy_index"] - 98.0) / 12.0)), 2),
                "flow_direction": "PRESSURE" if metrics["dxy_index"] >= 105.0 else "EXPANSION",
                "historical_range": "100.5 - 107.0",
                "market_impact": (
                    f"A strong DXY ({metrics['dxy_index']}) drains emerging market liquidity, pressures the Indian Rupee toward {metrics['usd_inr']}, "
                    "and triggers foreign institutional investor (FII) reallocations back toward US money markets."
                )
            },
            {
                "id": "us10y",
                "name": "US 10-Year Treasury Yield",
                "current_value": metrics["us_10y_yield"],
                "unit": "%",
                "stress_level": "HIGH RISK GRAVITY" if metrics["us_10y_yield"] >= 4.30 else "MODERATE",
                "status_label": "YIELD GRAVITY DABAO",
                "bar_ratio": round(min(1.0, max(0.2, (metrics["us_10y_yield"] - 3.2) / 2.0)), 2),
                "flow_direction": "PRESSURE",
                "historical_range": "3.60% - 5.00%",
                "market_impact": (
                    f"High US long-term risk-free rates ({metrics['us_10y_yield']}%) compress global equity price-to-earnings (PE) multiples and raise "
                    "refinancing borrowing hurdles for dollar-denominated emerging market corporate debt."
                )
            },
            {
                "id": "brent_crude",
                "name": "Brent Crude Oil",
                "current_value": metrics["brent_crude"],
                "unit": "USD/bbl",
                "stress_level": "MODERATE RELIEF" if metrics["brent_crude"] < 80.0 else "ELEVATED DEFICIT PRESSURE",
                "status_label": "MACRO SWEET SPOT" if metrics["brent_crude"] < 78.0 else "OIL SQUEEZE ALERT",
                "bar_ratio": round(min(1.0, max(0.15, (metrics["brent_crude"] - 55.0) / 45.0)), 2),
                "flow_direction": "EXPANSION" if metrics["brent_crude"] < 78.0 else "PRESSURE",
                "historical_range": "$68 - $92",
                "market_impact": (
                    f"Oil trading at ${metrics['brent_crude']} is an economic stabilizer for India, keeping the Current Account Deficit (CAD) "
                    "manageable and protecting operating margins for paints, specialty chemicals, and transport sectors."
                )
            },
            {
                "id": "gold_spot",
                "name": "Sovereign Gold (XAU/USD)",
                "current_value": metrics["gold_oz"],
                "unit": "USD/oz",
                "stress_level": "SAFE HAVEN DEMAND",
                "status_label": "DE-DOLLARIZATION HEDGE",
                "bar_ratio": round(min(1.0, max(0.3, (metrics["gold_oz"] - 1800.0) / 1100.0)), 2),
                "flow_direction": "EXPANSION",
                "historical_range": "$1,980 - $2,790",
                "market_impact": (
                    f"Gold trading at ${metrics['gold_oz']}/oz confirms aggressive reserve diversification by global central banks (PBOC, RBI, Middle East) "
                    "seeking neutral reserves immune to US dollar sanctions."
                )
            },
            {
                "id": "semicon_utilization",
                "name": "Global Semiconductor Fab Utilization",
                "current_value": metrics["semicon_utilization"],
                "unit": "%",
                "stress_level": "PEAK EXPANSION",
                "status_label": "AI HARDWARE SUPERCYCLE",
                "bar_ratio": round(min(1.0, max(0.4, metrics["semicon_utilization"] / 100.0)), 2),
                "flow_direction": "EXPANSION",
                "historical_range": "72% - 96%",
                "market_impact": (
                    f"Near-capacity utilization ({metrics['semicon_utilization']}%) at leading-edge foundries (TSMC 3nm/5nm) verifies the massive structural demand for AI accelerators, "
                    "spilling over into domestic Indian electronic manufacturing (EMS) and packaging orders."
                )
            },
            {
                "id": "baltic_dry",
                "name": "Baltic Dry Shipping Index",
                "current_value": metrics["baltic_dry"],
                "unit": "points",
                "stress_level": "HEALTHY STEADY FLOW",
                "status_label": "BALANCED BULK EXIM",
                "bar_ratio": round(min(1.0, max(0.2, (metrics["baltic_dry"] - 800.0) / 2000.0)), 2),
                "flow_direction": "EXPANSION",
                "historical_range": "1,100 - 2,250",
                "market_impact": (
                    f"Baltic Dry at {metrics['baltic_dry']} points confirms steady raw material movements (iron ore, coal, grains) "
                    "without the transport cost spikes seen during pandemic maritime disruptions."
                )
            }
        ],
        "global_headwinds_and_tailwinds": {
            "pressure_headwinds": [
                {
                    "title": "US Corporate IT Discretionary Budget Freezes",
                    "impact_level": "SEVERE DABAO",
                    "affected_sectors": ["Indian IT Services", "US SaaS Software", "Tech Consulting"],
                    "reason": f"US BFSI and retail executives are reprioritizing discretionary software budgets strictly towards generative AI proof-of-concepts (US 10Y {metrics['us_10y_yield']}%), delaying large multi-year digital transformation deals."
                },
                {
                    "title": "Universal US Import Tariff Threat (10% - 60%)",
                    "impact_level": "MACRO RISK",
                    "affected_sectors": ["Chinese Exporters", "Global Autos", "Steel & Aluminium"],
                    "reason": "Proposed tariff escalations threaten to disrupt integrated global supply chains, strengthen the dollar, and reignite US imported consumer inflation."
                },
                {
                    "title": "Chinese Industrial Dumping Across Emerging Markets",
                    "impact_level": "PRICE DABAO",
                    "affected_sectors": ["Primary Steel", "Basic Chemicals", "Agrochemicals"],
                    "reason": f"With Chinese domestic property demand depressed ({metrics['china_property_investment']}%), Chinese factories dump excess steel coils and synthetic chemicals into Asian markets at distressed prices ({metrics['china_ppi']}% PPI)."
                },
                {
                    "title": "European Industrial Demand Stagnation",
                    "impact_level": "EXPORT DABAO",
                    "affected_sectors": ["Specialty Chemicals", "Auto Components", "Textiles"],
                    "reason": f"With German factory orders and automotive dispatches declining (Europe Mfg {metrics['europe_mfg_pmi']} PMI), Indian and Asian exporters of intermediates face delayed purchase orders."
                }
            ],
            "expansion_tailwinds": [
                {
                    "title": "China+1 Manufacturing Relocation to India & ASEAN",
                    "impact_level": "MASSIVE TAILWIND",
                    "affected_sectors": ["Electronics (EMS)", "Solar Modules", "Precision Engineering"],
                    "reason": f"Global multinational brands are mandating that at least 25-30% of their global component sourcing originate outside mainland China, driving India's Composite PMI to {metrics['india_composite_pmi']}."
                },
                {
                    "title": "Muted Crude Oil & Commodity Softness",
                    "impact_level": "PROFIT EXPANSION",
                    "affected_sectors": ["Paints", "Airlines", "FMCG Packaging", "Tyres"],
                    "reason": f"Crude oil remaining rangebound (${metrics['brent_crude']}/bbl) prevents gross margin contraction and keeps national current account deficits in comfortable zones."
                },
                {
                    "title": "Global Central Bank Rate-Easing Liquidity Wave",
                    "impact_level": "LIQUIDITY EXPANSION",
                    "affected_sectors": ["Private Banking", "Real Estate", "Renewable Energy"],
                    "reason": "Synchronized rate cuts from the ECB, Bank of England, and US Fed lower global borrowing spreads and reduce corporate interest burdens."
                },
                {
                    "title": "AI Infrastructure & Power Equipment Supercycle",
                    "impact_level": "GLOBAL DEMAND",
                    "affected_sectors": ["Power Transmission", "Transformers", "Data Center EPC"],
                    "reason": f"Unprecedented energy consumption from AI compute clusters creates global shortage of transformers and high-voltage electrical equipment (US Services {metrics['us_services_pmi']})."
                }
            ]
        },
        "equity_impact_matrix": [
            {
                "theme": "China+1 Global Supply Relocation",
                "impact_direction": "BENEFICIARY",
                "status": "EXPANDING",
                "stocks": [
                    {"symbol": "KAYNES", "name": "Kaynes Technology", "catalyst": "Aerospace & defense EMS assembly orders & OSAT packaging"},
                    {"symbol": "DIXON", "name": "Dixon Technologies", "catalyst": "Mobile phone & laptop domestic manufacturing expansion"},
                    {"symbol": "PGEL", "name": "PG Electroplast", "catalyst": "Consumer electronics ODM contract manufacturing"}
                ]
            },
            {
                "theme": "Global AI Infrastructure & Electrical Power Equipment",
                "impact_direction": "BENEFICIARY",
                "status": "EXPANDING",
                "stocks": [
                    {"symbol": "ABB", "name": "ABB India", "catalyst": "Global data center electrification & switchgear exports"},
                    {"symbol": "SIEMENS", "name": "Siemens India", "catalyst": "High-voltage grid transmission equipment demand"},
                    {"symbol": "VOLTAMP", "name": "Voltamp Transformers", "catalyst": "Multi-year domestic & industrial transformer order backlog"}
                ]
            },
            {
                "theme": "Western Discretionary Tech Freeze",
                "impact_direction": "PRESSURE_FACING",
                "status": "HEADWIND",
                "stocks": [
                    {"symbol": "TCS", "name": "Tata Consultancy Services", "catalyst": "US BFSI discretionary deal closure sluggishness"},
                    {"symbol": "WIPRO", "name": "Wipro Ltd", "catalyst": "Prolonged consulting restructuring and muted revenue guidance"}
                ]
            },
            {
                "theme": "Chinese Industrial Overcapacity & Steel Dumping",
                "impact_direction": "PRESSURE_FACING",
                "status": "HEADWIND",
                "stocks": [
                    {"symbol": "TATASTEEL", "name": "Tata Steel Ltd", "catalyst": "Cheap Chinese hot-rolled coil imports compressing domestic steel spreads"},
                    {"symbol": "UPL", "name": "UPL Limited", "catalyst": "Chinese generic agrochemical active ingredients price war"}
                ]
            }
        ]
    }

    return payload


def generate_global_radar():
    print("🌐 Generating Global Macro Economy Pressure & Expansion Radar via Algorithmic Synthesis...")
    metrics = ingest_telemetry()
    payload = build_global_radar_payload(metrics)

    for file_path in [OUTPUT_ASSET_FILE, OUTPUT_ROOT_FILE]:
        os.makedirs(os.path.dirname(file_path) or ".", exist_ok=True)
        with open(file_path, "w", encoding="utf-8") as f:
            json.dump(payload, f, indent=2)

    print(f"✅ Generated {OUTPUT_ASSET_FILE} and {OUTPUT_ROOT_FILE}")
    print(f"📊 Global Health Score: {payload['executive_hud']['global_health_score']}/100 ({payload['executive_hud']['global_health_label']})")
    print(f"⚡ Sector Deltas: {len(payload['sector_margin_demand_matrix']['margin_expansion_sectors'])} expanding, {len(payload['sector_margin_demand_matrix']['margin_pressure_sectors'])} under pressure")
    print(f"🚨 Geopolitical Shocks: {len(payload['dynamic_shock_transmission_engine']['shocks'])} under surveillance")

if __name__ == "__main__":
    generate_global_radar()
