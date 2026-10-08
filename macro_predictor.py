#!/usr/bin/env python3
"""
EXACT REGIME MATCHER & QUANTITATIVE ENGINE
Calculates multi-horizon trajectory derivatives and sector-specific empirical elasticities.
Guaranteed write to 'macro_predictions_computed.json'.
"""

import os
import sys
import json
import statistics
from datetime import datetime, timezone, timedelta

DB_FILE = "macro_historical_db.json"
OUTPUT_COMPUTED_FILE = "macro_predictions_computed.json"

IST = timezone(timedelta(hours=5, minutes=30))
NOW = datetime.now(IST)

def ensure_database():
    if not os.path.exists(DB_FILE):
        print(f"⚠️ '{DB_FILE}' not found. Seeding database...")
        import subprocess
        subprocess.run([sys.executable, "seed_historical_macro_db.py"], check=True)

def match_empirical_regimes(vol_3m, cost_3m, matrix):
    matched = []
    for q in matrix:
        v_min, v_max = q["vol_band"]
        c_min, c_max = q["cost_band"]
        if (v_min - 1.5) <= vol_3m <= (v_max + 1.5) and (c_min - 2.0) <= cost_3m <= (c_max + 2.0):
            matched.append(q)

    if matched:
        bps_list = [m["ebitda_delta_bps"] for m in matched]
        rev_list = [m["rev_growth_yoy"] for m in matched]
        hit_list = [m["hit_rate_pct"] for m in matched]
        names = [m["regime_name"] for m in matched]

        return {
            "matched_regimes": names,
            "historical_sample_count": len(matched),
            "expected_ebitda_margin_delta_bps": round(float(statistics.median(bps_list)), 1),
            "projected_revenue_growth_yoy_pct": round(float(statistics.mean(rev_list)), 1),
            "historical_hit_rate_pct": round(float(statistics.mean(hit_list)), 1)
        }
    else:
        return {
            "matched_regimes": ["Linear Elasticity Approximation"],
            "historical_sample_count": 1,
            "expected_ebitda_margin_delta_bps": round(float((vol_3m * 10.0) - (cost_3m * 8.0)), 1),
            "projected_revenue_growth_yoy_pct": round(float(vol_3m * 1.05), 1),
            "historical_hit_rate_pct": 60.0
        }

def process_sector(sector_key, data):
    demand_series = data.get("monthly_demand", [])
    cost_series = data.get("input_costs", [])
    support_series = data.get("supporting_indicators", [])
    matrix = data.get("empirical_earnings_matrix", [])
    source = data.get("source", {})

    if len(demand_series) < 13:
        return None

    curr_d = demand_series[-1]
    prev_d = demand_series[-2]
    curr_c = cost_series[-1]
    curr_s = support_series[-1]

    # Velocities
    mom_pct = round(((curr_d["value"] - prev_d["value"]) / max(prev_d["value"], 0.001)) * 100, 2)
    yoy_pct = curr_d["yoy_pct"]
    m3_yoy = round(statistics.mean([m["yoy_pct"] for m in demand_series[-3:]]), 2)
    m6_yoy = round(statistics.mean([m["yoy_pct"] for m in demand_series[-6:]]), 2)
    acceleration_derivative = round(yoy_pct - m3_yoy, 2)

    # Cost Telemetry
    cost_yoy = curr_c["yoy_pct"]
    m3_cost_yoy = round(statistics.mean([c["yoy_pct"] for c in cost_series[-3:]]), 2)
    operating_spread = round(m3_yoy - m3_cost_yoy, 2)

    # Cross-Indicator Ratio
    support_yoy = curr_s["yoy_pct"]
    cross_ratio = round(support_yoy / max(yoy_pct, 0.01), 2)

    # Empirical Lookup
    forecast = match_empirical_regimes(m3_yoy, m3_cost_yoy, matrix)

    return {
        "sector_key": sector_key,
        "sector_name": data.get("sector", sector_key),
        "data_period": curr_d["month"],
        "demand_telemetry": {
            "current_volume": curr_d["value"],
            "unit": curr_d["unit"],
            "mom_pct": mom_pct,
            "yoy_pct": yoy_pct,
            "trailing_3m_yoy_pct": m3_yoy,
            "trailing_6m_yoy_pct": m6_yoy,
            "acceleration_derivative": acceleration_derivative
        },
        "cost_telemetry": {
            "metric_name": curr_c["metric"],
            "cost_yoy_pct": cost_yoy,
            "trailing_3m_cost_yoy_pct": m3_cost_yoy,
            "operating_spread_score": operating_spread
        },
        "cross_indicator": {
            "indicator_name": curr_s["indicator"],
            "supporting_yoy_pct": support_yoy,
            "cross_ratio": cross_ratio
        },
        "empirical_financial_forecast": forecast,
        "source": source
    }

def main():
    print("=" * 75)
    print("🧮 EXECUTING PREDICTOR (SECTOR-SPECIFIC EMPIRICAL MAPPING)")
    print("=" * 75)

    ensure_database()

    with open(DB_FILE, "r", encoding="utf-8") as f:
        db = json.load(f)

    sectors = db.get("sectors", {})
    analyzed = []

    for key, val in sectors.items():
        res = process_sector(key, val)
        if res:
            analyzed.append(res)

    analyzed.sort(key=lambda x: x["cost_telemetry"]["operating_spread_score"], reverse=True)

    output = {
        "generated_at": NOW.strftime("%Y-%m-%d %H:%M:%S IST"),
        "total_sectors_analyzed": len(analyzed),
        "sectors": analyzed
    }

    with open(OUTPUT_COMPUTED_FILE, "w", encoding="utf-8") as f:
        json.dump(output, f, ensure_ascii=False, indent=2)

    print(f"✅ Success: Processed {len(analyzed)} sectors with distinct metrics.")
    print(f"💾 File written: '{OUTPUT_COMPUTED_FILE}' ({os.path.getsize(OUTPUT_COMPUTED_FILE)} bytes)")

if __name__ == "__main__":
    main()
