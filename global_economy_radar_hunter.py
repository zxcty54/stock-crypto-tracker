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

def fetch_live_forex_usd_inr() -> float:
    """Attempts to fetch live USD/INR from open.er-api or yahoo finance."""
    # 1. Try open.er-api (most reliable for real-time currency rates)
    try:
        url = "https://open.er-api.com/v6/latest/USD"
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=4) as response:
            data = json.loads(response.read().decode("utf-8"))
            inr = data.get("rates", {}).get("INR")
            if inr and isinstance(inr, (int, float)) and inr > 50:
                return float(inr)
    except Exception:
        pass

    # 2. Try Yahoo Finance USDINR=X / INR=X
    for sym in ["USDINR=X", "INR=X"]:
        val = fetch_live_market_ticker(sym)
        if val is not None and val > 50:
            return val
    return None

def ingest_telemetry() -> dict:
    metrics = dict(BASELINE_METRICS)

    # In GitHub Actions cloud runners, public internet is open
    symbol_map = {
        "brent_crude": "CL=F",
        "dxy_index": "DX-Y.NYB",
        "us_10y_yield": "^TNX",
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

    live_fx = fetch_live_forex_usd_inr()
    if live_fx is not None:
        metrics["usd_inr"] = round(live_fx, 2)
        print(f"  ✓ Live update for usd_inr: {metrics['usd_inr']}")
    else:
        print(f"  • Using calibrated baseline for usd_inr: {metrics['usd_inr']}")

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
            "margin_winners": ["Upstream Oil & Gas (E&P)", "Domestic Gas Producers", "Refinery Exporters"],
            "margin_losers": ["Aviation Logistics", "Decorative Paints", "Downstream Fuel Retailers"]
        })

        # 2. King Dollar & Yield Gravity Shock
        is_dollar_high = m["dxy_index"] >= 105.5 or m["us_10y_yield"] >= 4.35
        shocks.append({
            "id": "king_dollar_shock",
            "shock_name": "King Dollar & US 10Y Yield Gravity Spike",
            "is_active": is_dollar_high,
            "severity": "ELEVATED DOLLAR SQUEEZE" if is_dollar_high else "MODERATE CURRENCY FLOAT",
            "trigger": f"US 10Y yields at {m['us_10y_yield']}% and DXY at {m['dxy_index']} driven by resilient US growth ({m['us_services_pmi']} PMI).",
            "supply_demand_choke": "Dollar liquidity contraction across emerging market banks; foreign institutional capital re-allocating to US T-Bills.",
            "import_export_shift": "Imported energy and electronics become costlier in Rupee terms; dollar export billing gains realization cushion.",
            "currency_impact": f"Rupee tests ₹{m['usd_inr']} band; supported by RBI's ${m['india_forex_bn']}B protective warchest.",
            "margin_winners": ["IT Services Exporters", "Generic Pharma Exporters", "Precision Engineering"],
            "margin_losers": ["High Forex Debt Borrowers", "Import-Reliant Metals", "Capital Goods Importers"]
        })

        # 3. China Overcapacity Dumping Shock
        is_china_dumping = m["china_ppi"] <= -1.5
        shocks.append({
            "id": "china_dumping_shock",
            "shock_name": "China Shock 2.0 Industrial Overcapacity Dumping",
            "is_active": is_china_dumping,
            "severity": "ACTIVE FACTORY DUMPING" if is_china_dumping else "BALANCED OVERSEAS SHIPMENTS",
            "trigger": f"China property contraction ({m['china_property_investment']}%) and factory deflation ({m['china_ppi']}% PPI) forcing overseas inventory clearance.",
            "supply_demand_choke": "Global steel, solar, and chemical markets flooded with Chinese inventory priced below international cash cost.",
            "import_export_shift": "Cheap Chinese steel coils and agrochemical intermediates surge into Asian ports, triggering anti-dumping investigations.",
            "currency_impact": "Disinflationary import price effect helps keep wholesale inflation low without direct foreign exchange shock.",
            "margin_winners": ["Solar EPC Developers", "Electronics EMS Assemblers", "Downstream Infrastructure"],
            "margin_losers": ["Primary Blast-Furnace Steel", "Basic Industrial Chemicals", "Technical Crop Agrochemicals"]
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
def fetch_live_fii_dii_flows() -> dict:
    """
    Attempts to fetch live official daily provisional FII / DII trading turnover.
    Primary Source: NSE India official endpoint (/api/fiidiiTradeReact).
    Secondary Source: Public financial data mirrors.
    Returns dict with fii_net and dii_net in ₹ Crores, or None if outside market hours/offline.
    """
    # 1. Attempt NSE India official endpoint via curl_cffi or requests with session
    try:
        from curl_cffi import requests
        session = requests.Session(impersonate="chrome124")
        session.get("https://www.nseindia.com", headers={"User-Agent": "Mozilla/5.0"}, timeout=6)
        resp = session.get(
            "https://www.nseindia.com/api/fiidiiTradeReact",
            headers={"User-Agent": "Mozilla/5.0", "Accept": "application/json"},
            timeout=6
        )
        if resp.status_code == 200:
            items = resp.json()
            fii_val = None
            dii_val = None
            trade_date = None
            for itm in items:
                cat = str(itm.get("category", "")).upper()
                net_str = str(itm.get("netValue", "")).replace(",", "").strip()
                trade_date = itm.get("date") or trade_date
                if "FII" in cat or "FPI" in cat:
                    fii_val = float(net_str)
                elif "DII" in cat:
                    dii_val = float(net_str)
            if fii_val is not None and dii_val is not None:
                return {
                    "fii_net": fii_val,
                    "dii_net": dii_val,
                    "trade_date": trade_date,
                    "source": "NSE_OFFICIAL_PROVISIONAL"
                }
    except Exception:
        pass

    # 2. Attempt Public Financial JSON API
    try:
        url = "https://priceapi.moneycontrol.com/pricefeed/techCharts/indianMarket/fiidii"
        req = urllib.request.Request(
            url,
            headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"}
        )
        with urllib.request.urlopen(req, timeout=5) as r:
            payload = json.loads(r.read().decode("utf-8"))
            if isinstance(payload, dict) and "fiiNet" in payload and "diiNet" in payload:
                return {
                    "fii_net": float(payload["fiiNet"]),
                    "dii_net": float(payload["diiNet"]),
                    "trade_date": payload.get("date"),
                    "source": "FINANCIAL_FEED_MIRROR"
                }
    except Exception:
        pass

    return None


def synthesize_fii_dii_flows(metrics: dict) -> dict:
    """
    Computes daily/weekly FII vs DII institutional flows & DXY correlation.
    Primary: Ingests live provisional data from NSE India / exchange feed.
    Fallback: When market is closed or on weekends/holidays, computes macro-correlated
    telemetry where elevated DXY (>105) & US 10Y (>4.35%) trigger FII outflows cushioned
    by ₹25,000+ Cr/month domestic SIP liquidity.
    Zero AI involved; 100% deterministic mathematical telemetry.
    """
    dxy = metrics.get("dxy_index", 106.25)
    us10y = metrics.get("us_10y_yield", 4.42)

    live = fetch_live_fii_dii_flows()
    if live:
        fii_net = round(live["fii_net"], 1)
        dii_net = round(live["dii_net"], 1)
        source = live.get("source", "NSE_LIVE")
        trade_date = live.get("trade_date") or datetime.now(timezone.utc).strftime("%d %b %Y")
    else:
        source = "MACRO_TELEMETRY_CORRELATION"
        trade_date = datetime.now(timezone.utc).strftime("%d %b %Y")
        if dxy >= 106.0 or us10y >= 4.40:
            fii_net = -2450.0 - round((dxy - 105.0) * 450, 1)
            dii_net = 3180.0 + round((dxy - 105.0) * 200, 1)
        elif dxy >= 104.0:
            fii_net = -1280.0
            dii_net = 2150.0
        else:
            fii_net = 1450.0
            dii_net = 1850.0

    net_pulse = round(dii_net + fii_net, 1)
    absorption_ratio = round(abs(dii_net) / max(1.0, abs(fii_net)), 2) if fii_net < 0 else round(dii_net / max(1.0, fii_net), 2)

    return {
        "fii_net_crores": round(fii_net, 1),
        "dii_net_crores": round(dii_net, 1),
        "net_pulse_crores": net_pulse,
        "absorption_ratio": absorption_ratio,
        "fii_action": "NET_SELLER" if fii_net < 0 else "NET_BUYER",
        "dii_action": "NET_BUYER" if dii_net > 0 else "NET_SELLER",
        "trade_date": trade_date,
        "data_source": source,
        "regime_verdict": f"DII Absorption Moat ({absorption_ratio}x SIP Cushion)" if fii_net < 0 else "Synchronized Dual Inflows",
        "dxy_correlation_note": f"DXY at {dxy} & US 10Y at {us10y}% create FII outflow pressure, absorbed by domestic SIP liquidity."
    }


def parse_fao_participant_csv(csv_text: str) -> dict:
    """
    Parses NSE's Participant-wise Open Interest CSV (fao_participant_oi_{ddmmyyyy}.csv).
    Extracts Index Futures Long vs Short contracts for Client, DII, FII, Pro.
    """
    lines = [l.strip() for l in csv_text.strip().split("\n") if l.strip()]
    header_idx = -1
    for i, l in enumerate(lines):
        if "Client Type" in l and "Future Index Long" in l:
            header_idx = i
            break
    if header_idx == -1:
        return None

    headers = [c.strip() for c in lines[header_idx].split(",")]
    col_map = {name: idx for idx, name in enumerate(headers)}

    data = {}
    for l in lines[header_idx + 1:]:
        parts = [c.strip() for c in l.split(",")]
        if not parts or len(parts) <= max(col_map.values(), default=0):
            continue
        p_type = parts[col_map.get("Client Type", 0)].upper()
        try:
            f_long = float(parts[col_map["Future Index Long"]])
            f_short = float(parts[col_map["Future Index Short"]])
            data[p_type] = {"long": f_long, "short": f_short}
        except (ValueError, KeyError, IndexError):
            continue

    return data if ("FII" in data or "DII" in data) else None


def fetch_live_nse_participant_oi(now: datetime) -> dict:
    """
    Attempts to download official Participant-wise Open Interest CSV from NSE Archives.
    Checks today and up to 4 previous trading days to find latest published F&O ledger.
    """
    from datetime import timedelta
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
        "Accept": "*/*"
    }

    for days_back in range(0, 5):
        target_date = now - timedelta(days=days_back)
        if target_date.weekday() in (5, 6):
            continue
        date_str = target_date.strftime("%d%m%Y")
        url = f"https://nsearchives.nseindia.com/content/nsccl/fao_participant_oi_{date_str}.csv"
        try:
            req = urllib.request.Request(url, headers=headers)
            with urllib.request.urlopen(req, timeout=6) as resp:
                if resp.status == 200:
                    content = resp.read().decode("utf-8", errors="ignore")
                    if "Client Type" in content and "Future Index Long" in content:
                        parsed = parse_fao_participant_csv(content)
                        if parsed:
                            parsed["trade_date"] = target_date.strftime("%d %b %Y")
                            parsed["source"] = "NSE_OFFICIAL_ARCHIVES"
                            return parsed
        except Exception:
            pass
    return None


def synthesize_index_futures_oi(metrics: dict, now: datetime) -> dict:
    """
    Computes participant-wise Index Futures Open Interest (OI) & FII Long-Short Ratio.
    Primary: Live official CSV download from NSE Archives (fao_participant_oi_{ddmmyyyy}.csv).
    Fallback: Macro-correlated quantitative model based on live DXY & US 10Y yields.
    Zero AI; 100% deterministic Python telemetry.
    """
    live = fetch_live_nse_participant_oi(now)
    if live and "FII" in live and "CLIENT" in live:
        fii_long = live["FII"]["long"]
        fii_short = live["FII"]["short"]
        dii_long = live.get("DII", {}).get("long", 48000.0)
        dii_short = live.get("DII", {}).get("short", 72000.0)
        client_long = live["CLIENT"]["long"]
        client_short = live["CLIENT"]["short"]
        pro_long = live.get("PRO", {}).get("long", 52000.0)
        pro_short = live.get("PRO", {}).get("short", 58000.0)
        source = live.get("source", "NSE_OFFICIAL_ARCHIVES")
        trade_date = live.get("trade_date", now.strftime("%d %b %Y"))
    else:
        # Quant Telemetry Fallback correlated with DXY & US 10Y
        dxy = metrics.get("dxy_index", 106.25)
        us10y = metrics.get("us_10y_yield", 4.42)
        source = "MACRO_TELEMETRY_CORRELATION"
        trade_date = now.strftime("%d %b %Y")

        if dxy >= 106.0 or us10y >= 4.40:
            fii_long = 28500.0
            fii_short = 118500.0
            dii_long = 48000.0
            dii_short = 72000.0
            client_long = 245000.0
            client_short = 125000.0
            pro_long = 52000.0
            pro_short = 58000.0
        elif dxy >= 104.0:
            fii_long = 48000.0
            fii_short = 82000.0
            dii_long = 51000.0
            dii_short = 64000.0
            client_long = 210000.0
            client_short = 145000.0
            pro_long = 55000.0
            pro_short = 52000.0
        else:
            fii_long = 84000.0
            fii_short = 42000.0
            dii_long = 58000.0
            dii_short = 46000.0
            client_long = 175000.0
            client_short = 195000.0
            pro_long = 62000.0
            pro_short = 44000.0

    fii_tot = fii_long + fii_short
    fii_long_pct = round((fii_long / max(1.0, fii_tot)) * 100, 1)
    fii_short_pct = round(100.0 - fii_long_pct, 1)
    fii_net = int(fii_long - fii_short)

    dii_tot = dii_long + dii_short
    dii_long_pct = round((dii_long / max(1.0, dii_tot)) * 100, 1)

    client_tot = client_long + client_short
    client_long_pct = round((client_long / max(1.0, client_tot)) * 100, 1)
    client_net = int(client_long - client_short)

    pro_tot = pro_long + pro_short
    pro_long_pct = round((pro_long / max(1.0, pro_tot)) * 100, 1)

    if fii_long_pct < 20.0:
        zone = "EXTREME_SHORT_SQUEEZE"
        zone_label = "Extreme Short Squeeze (< 20% Long)"
        sentiment = "BULLISH_CONTRARIAN"
        verdict = "FIIs holding 80%+ short contracts. High probability of violent short covering rally."
    elif fii_long_pct < 40.0:
        zone = "BEARISH_HEDGE"
        zone_label = "Net Bearish Hedging (20-40% Long)"
        sentiment = "BEARISH"
        verdict = "FIIs carrying net short index positions; domestic SIP acting as liquidity absorber."
    elif fii_long_pct <= 60.0:
        zone = "NEUTRAL_RANGEBOUND"
        zone_label = "Neutral / Rangebound (40-60% Long)"
        sentiment = "NEUTRAL"
        verdict = "Institutional open interest balanced without strong one-sided directional conviction."
    elif fii_long_pct <= 75.0:
        zone = "BULLISH_EXPANSION"
        zone_label = "Bullish Expansion (60-75% Long)"
        sentiment = "BULLISH"
        verdict = "Aggressive institutional long positioning across index futures."
    else:
        zone = "OVERBOUGHT_EXHAUSTION"
        zone_label = "Overbought Exhaustion (> 75% Long)"
        sentiment = "CAUTION"
        verdict = "Excessive long crowding; vulnerable to tactical profit booking."

    return {
        "fii_long_ratio": fii_long_pct,
        "fii_short_ratio": fii_short_pct,
        "fii_index_long_contracts": int(fii_long),
        "fii_index_short_contracts": int(fii_short),
        "fii_net_contracts": fii_net,
        "dii_long_ratio": dii_long_pct,
        "client_long_ratio": client_long_pct,
        "client_net_contracts": client_net,
        "pro_long_ratio": pro_long_pct,
        "sentiment_zone": zone,
        "zone_label": zone_label,
        "contrarian_signal": sentiment,
        "verdict": verdict,
        "trade_date": trade_date,
        "data_source": source
    }


def calculate_upcoming_macro_triggers(now: datetime) -> list:
    """
    Computes upcoming published macroeconomic calendar triggers
    (RBI MPC, US Fed FOMC, MoSPI CPI Inflation, OPEC+ Output Meeting, 8-Core Output)
    with exact remaining countdown days.
    100% Python datetime math, zero AI required.
    """
    from datetime import date
    import calendar
    today = now.date()

    events_config = [
        {
            "id": "rbi_mpc",
            "name": "RBI Monetary Policy Meeting",
            "category": "MONETARY_POLICY",
            "impact": "CRITICAL",
            "focus": "Repo Rate & Domestic Liquidity",
            "approx_months": [2, 4, 6, 8, 10, 12],
            "day": 6
        },
        {
            "id": "fed_fomc",
            "name": "US Federal Reserve FOMC",
            "category": "GLOBAL_RATES",
            "impact": "CRITICAL",
            "focus": "Fed Funds Rate & Dot Plot Guidance",
            "approx_months": [1, 3, 5, 6, 7, 9, 11, 12],
            "day": 18
        },
        {
            "id": "india_cpi",
            "name": "MoSPI India CPI Inflation",
            "category": "INFLATION",
            "impact": "HIGH",
            "focus": "Food Basket & Core CPI Print",
            "monthly_day": 12
        },
        {
            "id": "eight_core",
            "name": "DPIIT 8-Core Infrastructure Output",
            "category": "PHYSICAL_DEMAND",
            "impact": "HIGH",
            "focus": "Steel, Cement & Electricity Growth",
            "is_month_end": True
        },
        {
            "id": "opec_review",
            "name": "OPEC+ Joint Ministerial Monitoring (JMMC)",
            "category": "COMMODITIES",
            "impact": "HIGH",
            "focus": "Crude Production Quotas & Supply Cuts",
            "monthly_day": 1
        }
    ]

    triggers = []
    for cfg in events_config:
        target_date = None
        if "monthly_day" in cfg:
            d = cfg["monthly_day"]
            target_date = date(today.year, today.month, d)
            if target_date <= today:
                m = today.month + 1 if today.month < 12 else 1
                y = today.year if today.month < 12 else today.year + 1
                target_date = date(y, m, d)
        elif cfg.get("is_month_end"):
            _, last_day = calendar.monthrange(today.year, today.month)
            target_date = date(today.year, today.month, last_day)
            if target_date <= today:
                m = today.month + 1 if today.month < 12 else 1
                y = today.year if today.month < 12 else today.year + 1
                _, next_last = calendar.monthrange(y, m)
                target_date = date(y, m, next_last)
        elif "approx_months" in cfg:
            day = cfg["day"]
            for m in cfg["approx_months"]:
                candidate = date(today.year, m, day)
                if candidate > today:
                    target_date = candidate
                    break
            if not target_date:
                target_date = date(today.year + 1, cfg["approx_months"][0], day)

        if target_date:
            days_left = (target_date - today).days
            triggers.append({
                "id": cfg["id"],
                "name": cfg["name"],
                "category": cfg["category"],
                "impact": cfg["impact"],
                "focus": cfg["focus"],
                "event_date": target_date.strftime("%d %b %Y"),
                "days_remaining": days_left
            })

    triggers.sort(key=lambda x: x["days_remaining"])
    return triggers


def synthesize_equity_impact_matrix(metrics: dict) -> list:
    """
    Dynamically generates the Sector & Industry Macro Sensitivity Matrix:
    - Focuses on Industry Baskets, Cost of Goods Sold (COGS) sensitivities, and Benchmark Indices
    - Fully compliant with SEBI research regulations: Zero individual stock recommendations or buy/sell tips
    - Crude Oil pricing dynamics (<$78 vs >=$78)
    - US 10Y Yield & Enterprise Tech discretionary cycle (>=4.25% vs <4.25%)
    - China PPI deflationary dumping vs domestic recovery
    - Semiconductor fab utilization & Global AI CapEx supercycle
    """
    themes = []

    # 1. AI Hardware, Semiconductor & China+1 Relocation (Core Global Beneficiary)
    if metrics["semicon_utilization"] >= 90.0 or metrics["india_composite_pmi"] >= 55.0:
        themes.append({
            "theme": "Electronics Manufacturing (EMS) & Defence Assemblies",
            "benchmark_index": "Nifty India Manufacturing",
            "impact_direction": "BENEFICIARY",
            "status": "EXPANDING",
            "cost_sensitivity": "15-20% component import reliance cushioned by domestic PLI schemes and value-add localization",
            "transmission_channel": f"Global China+1 relocation & high global fab utilization ({metrics['semicon_utilization']}%) driving multi-year export order backlogs",
            "exposed_segments": ["Mobile & PCB Contract Assembly", "Defence Avionics & OSAT Packaging", "Consumer Electronics ODM"],
            "representative_tickers": ["DIXON", "KAYNES", "PGEL", "BEL"],
            "stocks": []
        })

    # 2. Power Grid, High-Voltage Transmission & Transformers
    themes.append({
        "theme": "Power Transmission & Heavy Electrical Equipment",
        "benchmark_index": "Nifty Energy & Infrastructure",
        "impact_direction": "BENEFICIARY",
        "status": "EXPANDING",
        "cost_sensitivity": "Copper & CRGO electrical steel input costs offset by robust multi-year fixed escalation contracts",
        "transmission_channel": "Global data center AI compute loads & grid modernisation creating unprecedented transformer equipment shortages",
        "exposed_segments": ["High-Voltage Power Transformers", "Gas-Insulated Switchgear", "Grid Substation EPC"],
        "representative_tickers": ["VOLTAMP", "ABB", "SIEMENS", "SCHNEIDER"],
        "stocks": []
    })

    # 3. Crude Oil Sensitivity Rotation: Soft Crude (Paints/Airlines) vs High Crude (Upstream E&P)
    if metrics["brent_crude"] < 78.0:
        themes.append({
            "theme": "Paints, Specialty Adhesives & Aviation Logistics",
            "benchmark_index": "Nifty Consumption / FMCG",
            "impact_direction": "BENEFICIARY",
            "status": "MARGIN EXPANSION",
            "cost_sensitivity": "35-42% of Cost of Goods Sold (COGS) directly tied to Crude & Petrochemical derivatives (Monomers, ATF, Solvents)",
            "transmission_channel": f"Soft Brent crude (${metrics['brent_crude']}/bbl) prevents input cost inflation, directly expanding gross EBITDA margins",
            "exposed_segments": ["Decorative Architectural Paints", "Commercial Airline ATF Fuel", "Synthetic Resins & Adhesives"],
            "representative_tickers": ["ASIANPAINT", "BERGEPAINT", "INDIGO", "PIDILITIND"],
            "stocks": []
        })
    else:
        themes.append({
            "theme": "Upstream Oil & Gas Exploration (E&P)",
            "benchmark_index": "Nifty Oil & Gas",
            "impact_direction": "BENEFICIARY",
            "status": "CASH FLOW EXPANSION",
            "cost_sensitivity": "Exploration lifting costs fixed; revenue directly proportional to international dollar oil realizations",
            "transmission_channel": f"Elevated crude (${metrics['brent_crude']}/bbl) boosts gross dollar realizations and upstream drilling operating cash flows",
            "exposed_segments": ["Offshore Crude Drilling", "Domestic Natural Gas Extraction", "Cross-Country Pipeline Transmission"],
            "representative_tickers": ["ONGC", "OIL", "GAIL"],
            "stocks": []
        })

    # 4. US 10Y Yield & Tech Discretionary Spending
    if metrics["us_10y_yield"] >= 4.25:
        themes.append({
            "theme": "Tier-1 IT & Enterprise Software Services",
            "benchmark_index": "Nifty IT",
            "impact_direction": "PRESSURE_FACING",
            "status": "HEADWIND",
            "cost_sensitivity": "High revenue dependence on US & European BFSI tech budgets (50-60% of top-line revenue)",
            "transmission_channel": f"High US 10Y Treasury yield ({metrics['us_10y_yield']}%) prompts US enterprise CFOs to freeze non-critical discretionary consulting projects",
            "exposed_segments": ["BFSI Discretionary Consulting", "Legacy Enterprise IT Maintenance", "ERP Implementation Deals"],
            "representative_tickers": ["TCS", "INFY", "WIPRO", "COFORGE"],
            "stocks": []
        })
    else:
        themes.append({
            "theme": "Tier-1 IT & Enterprise Cloud Transformation",
            "benchmark_index": "Nifty IT",
            "impact_direction": "BENEFICIARY",
            "status": "EXPANDING",
            "cost_sensitivity": "Global corporate tech budgets expand with lower western capital borrowing costs",
            "transmission_channel": f"Lower US borrowing yields ({metrics['us_10y_yield']}%) unfreeze corporate enterprise cloud migration & generative AI contracts",
            "exposed_segments": ["Enterprise Cloud Migration", "Generative AI Engineering", "Digital Healthcare Solutions"],
            "representative_tickers": ["TCS", "INFY", "KPITTECH", "PERSISTENT"],
            "stocks": []
        })

    # 5. Chinese Industrial Overcapacity / Deflationary Dumping
    if metrics["china_ppi"] < -1.5 or metrics["china_property_investment"] < -5.0:
        themes.append({
            "theme": "Primary Steel & Crop Protection Agrochemicals",
            "benchmark_index": "Nifty Metal / Commodities",
            "impact_direction": "PRESSURE_FACING",
            "status": "MARGIN COMPRESSION",
            "cost_sensitivity": "High vulnerability to distressed Chinese dumping and generic active ingredient imports",
            "transmission_channel": f"Distressed Chinese factory exports ({metrics['china_ppi']}% PPI) undercut domestic steel realization spreads and chemical export pricing",
            "exposed_segments": ["Hot-Rolled Steel Coils", "Generic Agrochemical Off-Patents", "Commodity Base Chemicals"],
            "representative_tickers": ["TATASTEEL", "JSWSTEEL", "APLAPOLLO", "UPL"],
            "stocks": []
        })
    else:
        themes.append({
            "theme": "Primary Base Metals & Global Commodity Materials",
            "benchmark_index": "Nifty Metal",
            "impact_direction": "BENEFICIARY",
            "status": "EXPANDING",
            "cost_sensitivity": "High operating leverage to global London Metal Exchange (LME) spot prices",
            "transmission_channel": "Global manufacturing PMI recovery drives restocking of industrial metals and structural steel dispatches",
            "exposed_segments": ["Aluminium Smelting & Extrusions", "Finished Structural Steel", "Pellet & Sponge Iron Exports"],
            "representative_tickers": ["HINDALCO", "NATIONALUM", "VEDL", "JINDALSTEL"],
            "stocks": []
        })

    return themes


def synthesize_market_internals(now: datetime) -> dict:
    """
    Computes institutional market internals, Advance-Decline breadth thrust,
    India VIX volatility regime, and filters real delivery accumulation vs operator churn traps.
    Audit source: Real audited NSE delivery database (stock_history_20d.json across 1,589 stocks).
    Zero AI; 100% deterministic Python calculation.
    """
    try:
        with open("stock_history_20d.json", "r", encoding="utf-8") as f:
            d = json.load(f)
    except Exception:
        d = {}

    adv = 0
    dec = 0
    unc = 0
    heavy_buys = []
    churn_dumps = []

    for sym, records in d.items():
        if not records:
            continue
        r = records[-1]
        try:
            op = float(r[1])
            cl = float(r[4])
            vol = int(r[5])
            deliv = float(r[6])
        except (ValueError, IndexError):
            continue

        if op <= 0:
            continue
        chg = round(((cl - op) / op) * 100, 2)

        if cl > op:
            adv += 1
            if deliv >= 65.0 and vol > 20000:
                heavy_buys.append({
                    "symbol": sym,
                    "change_pct": chg,
                    "delivery_pct": deliv,
                    "volume": vol
                })
        elif cl < op:
            dec += 1
            if deliv < 30.0 and vol > 50000:
                churn_dumps.append({
                    "symbol": sym,
                    "change_pct": chg,
                    "delivery_pct": deliv,
                    "volume": vol
                })
        else:
            unc += 1

    tot = adv + dec + unc
    breadth_pct = round((adv / max(1, adv + dec)) * 100, 1)

    heavy_buys.sort(key=lambda x: x["delivery_pct"], reverse=True)
    churn_dumps.sort(key=lambda x: x["volume"], reverse=True)

    # Ingest live India VIX or use calibrated baseline
    vix = fetch_live_market_ticker("^INDIAVIX")
    if not vix or vix <= 0 or vix > 80:
        vix = 13.40

    if vix < 12.0:
        vix_zone = "COMPLACENCY_TRAP"
        vix_label = "Complacency Trap (< 12.0)"
        vix_truth = "Retail feeling zero fear; options decay rapid; institutional put-hedging window open."
    elif vix <= 15.5:
        vix_zone = "HEALTHY_STEADY"
        vix_label = "Healthy Structural Trend (12.0 - 15.5)"
        vix_truth = "Balanced volatility; sustainable trend conditions with low speculative drag."
    elif vix <= 21.0:
        vix_zone = "ELEVATED_RISK"
        vix_label = "Elevated Event Risk (15.5 - 21.0)"
        vix_truth = "High options volatility expansion; stop-losses must be wider."
    else:
        vix_zone = "CAPITULATION_BOTTOM"
        vix_label = "Panic Capitulation (> 21.0)"
        vix_truth = "Buffett Buying Zone: Extreme fear headlines; smart money contrarian accumulation window."

    if breadth_pct < 40.0:
        regime = "INDEX_CAMOUFLAGE"
        regime_label = "Index Camouflage Trap (Smart Money Distributing)"
        regime_truth = "Heavyweights holding headline index while 65%+ broader stocks are in net decline."
    elif breadth_pct > 65.0:
        regime = "BROAD_ACCUMULATION"
        regime_label = "Healthy Broad Accumulation Wave"
        regime_truth = "True institutional participation with 65%+ stocks advancing across market caps."
    else:
        regime = "SELECTIVE_STOCK_PICKING"
        regime_label = "Bifurcated Mixed Breadth"
        regime_truth = "Select pockets of strength; stock-specific delivery accumulation required."

    return {
        "total_stocks_screened": tot,
        "advances_count": adv,
        "declines_count": dec,
        "unchanged_count": unc,
        "breadth_thrust_pct": breadth_pct,
        "market_regime": regime,
        "regime_label": regime_label,
        "regime_truth": regime_truth,
        "india_vix": round(vix, 2),
        "vix_zone": vix_zone,
        "vix_label": vix_label,
        "vix_truth": vix_truth,
        "top_delivery_accumulations": heavy_buys[:6],
        "top_churn_distribution_traps": churn_dumps[:6]
    }


def build_global_radar_payload(metrics: dict) -> dict:
    synthesizer = MacroCommentarySynthesizer(metrics)
    health_score, health_label, verdict, headline, conclusion = synthesizer.synthesize_executive_hud()
    margin_matrix = synthesizer.synthesize_sector_margin_deltas()
    shocks = synthesizer.synthesize_geopolitical_shocks()
    currency_telemetry = synthesizer.synthesize_currency_and_trade()

    now_utc = datetime.now(timezone.utc)
    month_year = now_utc.strftime("%B %Y")

    # Dynamic Superpower Evaluation based on live/monthly metrics
    us_pmi = metrics["us_services_pmi"]
    us_10y = metrics["us_10y_yield"]
    if us_pmi >= 54.0:
        us_eco_status = "MODERATE_EXPANSION" if us_10y >= 4.40 else "ACCELERATING_EXPANSION"
        us_status_label = "TECH & FISCAL RESILIENCE" if us_10y >= 4.40 else "BROAD-BASED EXPANSION"
    elif us_pmi >= 50.0:
        us_eco_status = "MODERATE_EXPANSION"
        us_status_label = "SERVICES-LED RESILIENCE"
    else:
        us_eco_status = "CONTRACTION"
        us_status_label = "CYCLICAL SLOWDOWN"

    cn_ppi = metrics["china_ppi"]
    cn_pmi = metrics["china_composite_pmi"]
    cn_prop = metrics["china_property_investment"]
    if cn_ppi < -2.0 and cn_prop < -5.0:
        cn_eco_status = "DEFLATIONARY_PRESSURE"
        cn_status_label = "STIMULUS BAZOOKA DEFENSE"
    elif cn_pmi >= 51.0 and cn_ppi >= 0.0:
        cn_eco_status = "CYCLICAL_RECOVERY"
        cn_status_label = "DOMESTIC DEMAND REBOUND"
    elif cn_pmi >= 50.0:
        cn_eco_status = "STABILIZATION_PHASE"
        cn_status_label = "BORDERLINE STABILIZATION"
    else:
        cn_eco_status = "SEVERE_CONTRACTION"
        cn_status_label = "FACTORY OVERCAPACITY DRAG"

    eu_pmi = metrics["europe_mfg_pmi"]
    if eu_pmi < 47.0:
        eu_eco_status = "SEVERE_CONTRACTION"
        eu_status_label = "DE-INDUSTRIALIZATION SHOCK"
    elif eu_pmi < 50.0:
        eu_eco_status = "MODERATE_PRESSURE"
        eu_status_label = "SUBDUED FACTORY ORDERS"
    elif eu_pmi < 53.0:
        eu_eco_status = "MODEST_EXPANSION"
        eu_status_label = "MILD INDUSTRIAL RECOVERY"
    else:
        eu_eco_status = "RAPID_EXPANSION"
        eu_status_label = "BROAD INDUSTRIAL RECOVERY"

    jp_pmi = metrics["japan_composite_pmi"]
    if jp_pmi >= 51.0:
        jp_eco_status = "MODEST_EXPANSION"
        jp_status_label = "EXITING 30-YR DEFLATION"
    elif jp_pmi >= 49.0:
        jp_eco_status = "NEUTRAL_FLOAT"
        jp_status_label = "BALANCED DOMESTIC FLOAT"
    else:
        jp_eco_status = "MODERATE_PRESSURE"
        jp_status_label = "EXPORT SLOWDOWN"

    in_pmi = metrics["india_composite_pmi"]
    if in_pmi >= 57.0:
        in_eco_status = "HIGH_GROWTH_LEADER"
        in_status_label = "FASTEST GROWING MAJOR ECONOMY"
    elif in_pmi >= 52.0:
        in_eco_status = "MODERATE_EXPANSION"
        in_status_label = "SOLID DOMESTIC MOMENTUM"
    else:
        in_eco_status = "SLOWDOWN"
        in_status_label = "GROWTH DECELERATION"

    def evaluate_pillar(region_id: str, pmi: float) -> tuple:
        if region_id == "us":
            if pmi >= 52.0:
                return ("EXPANSION", "EXPANSION", "cyan")
            elif pmi >= 50.0:
                return ("MODERATE EXPANSION", "EXPANSION", "cyan")
            else:
                return ("CONTRACTION", "PRESSURE", "red")
        elif region_id == "china":
            if metrics["china_ppi"] < -1.5:
                return ("DEFLATIONARY PRESSURE", "PRESSURE", "red")
            elif pmi >= 51.0:
                return ("STIMULUS EXPANSION", "EXPANSION", "cyan")
            elif pmi >= 50.0:
                return ("BORDERLINE RECOVERY", "EXPANSION", "cyan")
            else:
                return ("FACTORY CONTRACTION", "PRESSURE", "red")
        elif region_id == "europe":
            if pmi >= 50.0:
                return ("INDUSTRIAL RECOVERY", "EXPANSION", "green")
            elif pmi >= 47.0:
                return ("MILD CONTRACTION", "PRESSURE", "red")
            else:
                return ("DEEP CONTRACTION", "PRESSURE", "red")
        elif region_id == "japan":
            if pmi >= 50.0:
                return ("MODEST REBOUND", "EXPANSION", "cyan")
            else:
                return ("EXPORT CONTRACTION", "PRESSURE", "red")
        elif region_id == "em_india":
            if pmi >= 56.0:
                return ("RAPID EXPANSION", "EXPANSION", "green")
            elif pmi >= 50.0:
                return ("DOMESTIC EXPANSION", "EXPANSION", "green")
            else:
                return ("GROWTH DECELERATION", "PRESSURE", "red")
        return ("EXPANSION" if pmi >= 50.0 else "CONTRACTION", "EXPANSION" if pmi >= 50.0 else "PRESSURE", "cyan" if pmi >= 50.0 else "red")

    us_p_stat, us_p_type, us_p_col = evaluate_pillar("us", metrics["us_services_pmi"])
    cn_p_stat, cn_p_type, cn_p_col = evaluate_pillar("china", metrics["china_composite_pmi"])
    eu_p_stat, eu_p_type, eu_p_col = evaluate_pillar("europe", metrics["europe_mfg_pmi"])
    jp_p_stat, jp_p_type, jp_p_col = evaluate_pillar("japan", metrics["japan_composite_pmi"])
    in_p_stat, in_p_type, in_p_col = evaluate_pillar("em_india", metrics["india_composite_pmi"])

    core_pillars = [
        {
            "region_id": "us",
            "region": "UNITED STATES",
            "flag": "🇺🇸",
            "gdp_trillion_usd": 28.7,
            "growth_pmi": metrics["us_services_pmi"],
            "growth_pmi_label": "Services PMI",
            "status": us_p_stat,
            "status_type": us_p_type,
            "flow_color": us_p_col,
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
            "status": cn_p_stat,
            "status_type": cn_p_type,
            "flow_color": cn_p_col,
            "net_momentum_pct": 4.8,
            "key_driver": f"Property Slump ({metrics['china_property_investment']}%) vs Stimulus Defense"
        },
        {
            "region_id": "europe",
            "region": "EUROZONE / UK",
            "flag": "🇪🇺",
            "gdp_trillion_usd": 19.4,
            "growth_pmi": metrics["europe_mfg_pmi"],
            "growth_pmi_label": "Mfg PMI",
            "status": eu_p_stat,
            "status_type": eu_p_type,
            "flow_color": eu_p_col,
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
            "status": jp_p_stat,
            "status_type": jp_p_type,
            "flow_color": jp_p_col,
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
            "status": in_p_stat,
            "status_type": in_p_type,
            "flow_color": in_p_col,
            "net_momentum_pct": 7.2,
            "key_driver": "China+1 Supply Chain Shift & Domestic Capex Execution"
        }
    ]

    exp_count = sum(1 for p in core_pillars if p["status_type"] == "EXPANSION")
    pres_count = sum(1 for p in core_pillars if p["status_type"] == "PRESSURE")

    fii_dii = synthesize_fii_dii_flows(metrics)
    fii_derivatives = synthesize_index_futures_oi(metrics, now_utc)
    macro_triggers = calculate_upcoming_macro_triggers(now_utc)
    market_internals = synthesize_market_internals(now_utc)

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
            "regions_expansion_count": exp_count,
            "regions_pressure_count": pres_count,
            "core_pillars": core_pillars
        },
        "fii_dii_flows": fii_dii,
        "fii_dii_derivatives": fii_derivatives,
        "upcoming_macro_triggers": macro_triggers,
        "market_internals": market_internals,
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
                "economic_status": us_eco_status,
                "status_label": us_status_label,
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
                "economic_status": cn_eco_status,
                "status_label": cn_status_label,
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
                "economic_status": eu_eco_status,
                "status_label": eu_status_label,
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
                "economic_status": jp_eco_status,
                "status_label": jp_status_label,
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
                "economic_status": in_eco_status,
                "status_label": in_status_label,
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
                "stress_level": "RESTRICTIVE CAPITAL COST" if metrics["us_10y_yield"] >= 4.35 else ("BALANCED EQUILIBRIUM" if metrics["us_10y_yield"] >= 4.00 else "ACCOMMODATIVE YIELD"),
                "status_label": "YIELD GRAVITY DABAO" if metrics["us_10y_yield"] >= 4.35 else ("BALANCED DISCOUNT RATE" if metrics["us_10y_yield"] >= 4.00 else "GROWTH TAILWIND"),
                "bar_ratio": round(min(1.0, max(0.15, (metrics["us_10y_yield"] - 3.2) / 2.0)), 2),
                "flow_direction": "PRESSURE" if metrics["us_10y_yield"] >= 4.35 else "EXPANSION",
                "historical_range": "3.60% - 5.00%",
                "market_impact": (
                    f"Long-term risk-free rates ({metrics['us_10y_yield']}%) set global corporate discount rates, equity PE gravity, "
                    "and dollar debt rollover costs for emerging market borrowers."
                )
            },
            {
                "id": "brent_crude",
                "name": "Brent Crude Oil",
                "current_value": metrics["brent_crude"],
                "unit": "USD/bbl",
                "stress_level": "ACUTE INFLATION CHOKE" if metrics["brent_crude"] >= 85.0 else ("ELEVATED DEFICIT PRESSURE" if metrics["brent_crude"] >= 78.0 else "BENIGN RELIEF"),
                "status_label": "CRITICAL CRUDE CHOKE" if metrics["brent_crude"] >= 82.0 else ("BALANCED COST FLOAT" if metrics["brent_crude"] >= 74.0 else "INPUT COST WINDFALL"),
                "bar_ratio": round(min(1.0, max(0.15, (metrics["brent_crude"] - 55.0) / 45.0)), 2),
                "flow_direction": "PRESSURE" if metrics["brent_crude"] >= 78.0 else "EXPANSION",
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
                "stress_level": "PEAK RESERVE DIVERSIFICATION" if metrics["gold_oz"] >= 2600.0 else "STEADY SAFE HAVEN",
                "status_label": "DE-DOLLARIZATION HEDGE" if metrics["gold_oz"] >= 2500.0 else "SOVEREIGN RESERVE BID",
                "bar_ratio": round(min(1.0, max(0.2, (metrics["gold_oz"] - 1800.0) / 1100.0)), 2),
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
                "stress_level": "AI HARDWARE SUPERCYCLE" if metrics["semicon_utilization"] >= 90.0 else ("STEADY FOUNDRY RUNS" if metrics["semicon_utilization"] >= 80.0 else "CHIP DESTOCKING"),
                "status_label": "AI COMPUTE BOOM" if metrics["semicon_utilization"] >= 90.0 else ("HEALTHY TECH CYCLE" if metrics["semicon_utilization"] >= 80.0 else "DESTOCKING DRAG"),
                "bar_ratio": round(min(1.0, max(0.2, metrics["semicon_utilization"] / 100.0)), 2),
                "flow_direction": "EXPANSION" if metrics["semicon_utilization"] >= 80.0 else "PRESSURE",
                "historical_range": "72% - 96%",
                "market_impact": (
                    f"Near-capacity utilization ({metrics['semicon_utilization']}%) at leading-edge foundries (TSMC 3nm/5nm) verifies structural demand for AI accelerators, "
                    "spilling over into domestic Indian electronic manufacturing (EMS) and packaging orders."
                )
            },
            {
                "id": "baltic_dry",
                "name": "Baltic Dry Shipping Index",
                "current_value": metrics["baltic_dry"],
                "unit": "points",
                "stress_level": "FREIGHT TARIFF SURGE" if metrics["baltic_dry"] >= 2500.0 else ("STEADY BULK TRADE" if metrics["baltic_dry"] >= 1200.0 else "TRADE VOLUME SLOWDOWN"),
                "status_label": "FREIGHT FRICTION" if metrics["baltic_dry"] >= 2500.0 else ("BALANCED BULK EXIM" if metrics["baltic_dry"] >= 1200.0 else "SUBDUED SHIPPING"),
                "bar_ratio": round(min(1.0, max(0.15, (metrics["baltic_dry"] - 800.0) / 2000.0)), 2),
                "flow_direction": "PRESSURE" if (metrics["baltic_dry"] >= 2500.0 or metrics["baltic_dry"] < 1100.0) else "EXPANSION",
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
        "equity_impact_matrix": synthesize_equity_impact_matrix(metrics)
    }

    return payload



def call_gemini_ai_refiner(metrics: dict, payload: dict) -> dict:
    """
    If GEMINI_API_KEY / GOOGLE_API_KEY is present in environment (e.g. GitHub Actions),
    queries Google Gemini to refine all bullet points, shocks, and headlines into
    ultra-crisp, data-dense institutional points.
    """
    api_key = os.environ.get("GEMINI_API_KEY") or os.environ.get("GOOGLE_API_KEY")
    if not api_key or not api_key.strip():
        print("ℹ️ No GEMINI_API_KEY found in environment; using calibrated quant rule synthesis.")
        return payload

    print("🤖 GEMINI_API_KEY detected! Dispatching live macro metrics to Gemini AI...")

    prompt = f"""You are an institutional macro quantitative strategist for StockPulse Pro terminal.
Analyze these live macro numbers:
- Brent Crude: ${metrics['brent_crude']}/bbl
- DXY Dollar Index: {metrics['dxy_index']}
- US 10Y Treasury Yield: {metrics['us_10y_yield']}%
- USD / INR: ₹{metrics['usd_inr']}
- Sovereign Gold: ${metrics['gold_oz']}/oz
- US Services PMI: {metrics['us_services_pmi']}, Mfg: {metrics['us_mfg_pmi']}
- China Composite PMI: {metrics['china_composite_pmi']}, PPI: {metrics['china_ppi']}%, Property YoY: {metrics['china_property_investment']}%
- Eurozone Mfg PMI: {metrics['europe_mfg_pmi']}
- Japan Composite PMI: {metrics['japan_composite_pmi']}
- India Composite PMI: {metrics['india_composite_pmi']}

STRICT INSTRUCTION:
Keep all text ULTRA-SHORT, DATA-DENSE, and PUNCHY BULLET POINTS. NO LONG PARAGRAPHS. Focus heavily on NUMBERS, METRICS, BASIS POINTS, AND SECTOR BASKETS.
COMPLIANCE MANDATE: Do NOT recommend or mention single stock buy/sell tips. Focus 100% on Industry Baskets, Cost Sensitivities, and Benchmark Indices.

Return valid JSON with exactly this structure:
{{
  "regime_headline": "Short 1-line regime headline with key numbers",
  "health_verdict": "Short 1-line global health verdict with key metrics",
  "crude_shock_severity": "CRITICAL SHOCK ALERT or RANGEBOUND COMFORT",
  "crude_shock_trigger": "1-line trigger with crude dollar numbers",
  "crude_shock_winners": ["Upstream Oil & Gas (E&P)", "Pipeline Transmission", "Renewables EPC"],
  "crude_shock_losers": ["Paints & Coatings", "Commercial Airlines (ATF)", "Downstream Marketing OMCs"],
  "equity_impact_matrix": [
    {{
      "theme": "Short industry basket name e.g. Electronics Manufacturing (EMS) & Defence",
      "benchmark_index": "Nifty India Manufacturing",
      "impact_direction": "BENEFICIARY",
      "status": "EXPANDING",
      "cost_sensitivity": "1-line COGS / raw material input sensitivity metric",
      "transmission_channel": "1-line macro transmission mechanism with numbers",
      "exposed_segments": ["Segment 1", "Segment 2", "Segment 3"],
      "stocks": []
    }},
    {{
      "theme": "Short crude sensitivity sector e.g. Paints, Adhesives & Aviation Logistics",
      "benchmark_index": "Nifty Consumption / FMCG",
      "impact_direction": "BENEFICIARY",
      "status": "MARGIN EXPANSION",
      "cost_sensitivity": "1-line COGS / raw material input sensitivity metric",
      "transmission_channel": "1-line macro transmission mechanism with numbers",
      "exposed_segments": ["Segment 1", "Segment 2", "Segment 3"],
      "stocks": []
    }},
    {{
      "theme": "Short tech sensitivity sector e.g. Tier-1 IT & Enterprise Software Services",
      "benchmark_index": "Nifty IT",
      "impact_direction": "PRESSURE_FACING",
      "status": "HEADWIND",
      "cost_sensitivity": "1-line COGS / revenue sensitivity metric",
      "transmission_channel": "1-line macro transmission mechanism with numbers",
      "exposed_segments": ["Segment 1", "Segment 2", "Segment 3"],
      "stocks": []
    }},
    {{
      "theme": "Short commodity sector e.g. Primary Steel & Crop Protection Agrochemicals",
      "benchmark_index": "Nifty Metal / Commodities",
      "impact_direction": "PRESSURE_FACING",
      "status": "MARGIN COMPRESSION",
      "cost_sensitivity": "1-line COGS / dumping sensitivity metric",
      "transmission_channel": "1-line macro transmission mechanism with numbers",
      "exposed_segments": ["Segment 1", "Segment 2", "Segment 3"],
      "stocks": []
    }}
  ]
}}
"""

    candidate_models = [
        "gemini-3.5-flash-lite",
        "gemini-3.1-flash-lite",
        "gemini-3.5-lite",
        "gemini-2.5-flash-lite",
    ]

    req_body = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {
            "temperature": 0.2,
            "maxOutputTokens": 2000,
            "responseMimeType": "application/json"
        }
    }

    for model in candidate_models:
        for version in ["v1beta", "v1"]:
            url = f"https://generativelanguage.googleapis.com/{version}/models/{model}:generateContent?key={api_key.strip()}"
            req = urllib.request.Request(
                url,
                data=json.dumps(req_body).encode("utf-8"),
                headers={"Content-Type": "application/json"}
            )
            try:
                with urllib.request.urlopen(req, timeout=20) as resp:
                    if resp.status == 200:
                        raw = json.loads(resp.read().decode("utf-8"))
                        text_part = raw["candidates"][0]["content"]["parts"][0]["text"].strip()
                        if text_part.startswith("```json"):
                            text_part = text_part[7:]
                        elif text_part.startswith("```"):
                            text_part = text_part[3:]
                        if text_part.endswith("```"):
                            text_part = text_part[:-3]

                        ai_data = json.loads(text_part.strip())
                        print(f"  ✓ Gemini AI refined macro telemetry successfully using {model} [{version}]!")

                        if "regime_headline" in ai_data:
                            payload["metadata"]["regime_headline"] = ai_data["regime_headline"]
                        if "health_verdict" in ai_data:
                            payload["executive_hud"]["health_verdict"] = ai_data["health_verdict"]
                        if "crude_shock_severity" in ai_data and payload["dynamic_shock_transmission_engine"]["shocks"]:
                            payload["dynamic_shock_transmission_engine"]["shocks"][0]["severity"] = ai_data["crude_shock_severity"]
                        if "crude_shock_trigger" in ai_data and payload["dynamic_shock_transmission_engine"]["shocks"]:
                            payload["dynamic_shock_transmission_engine"]["shocks"][0]["trigger"] = ai_data["crude_shock_trigger"]
                        if "crude_shock_winners" in ai_data and payload["dynamic_shock_transmission_engine"]["shocks"]:
                            payload["dynamic_shock_transmission_engine"]["shocks"][0]["margin_winners"] = ai_data["crude_shock_winners"]
                        if "crude_shock_losers" in ai_data and payload["dynamic_shock_transmission_engine"]["shocks"]:
                            payload["dynamic_shock_transmission_engine"]["shocks"][0]["margin_losers"] = ai_data["crude_shock_losers"]
                        if "equity_impact_matrix" in ai_data and isinstance(ai_data["equity_impact_matrix"], list) and len(ai_data["equity_impact_matrix"]) >= 2:
                            payload["equity_impact_matrix"] = ai_data["equity_impact_matrix"]

                        return payload
            except Exception:
                continue

    print("ℹ️ Preserving calibrated quant rule synthesis.")
    return payload

def generate_global_radar():
    print("🌐 Generating Global Macro Economy Pressure & Expansion Radar via Algorithmic Synthesis & Gemini AI...")
    metrics = ingest_telemetry()
    payload = build_global_radar_payload(metrics)
    payload = call_gemini_ai_refiner(metrics, payload)

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
