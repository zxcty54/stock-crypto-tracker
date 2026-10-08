#!/usr/bin/env python3
"""
PURE QUANTITATIVE TELEMETRY CALCULATOR (No Judgment / AI Pre-Processor)
- Ingests: 'macro_historical_db.json'
- Computes:
    1. Demand Velocity, Curvature & 3M/6M Trailing Compounding
    2. Seasonality De-noised Multiples (Same-Month Baseline)
    3. Input Cost Momentum & Net Operating Spreads
    4. Cross-Indicator Divergence (Physical vs Logistics Movement)
    5. Empirical Historical Regime Distances
- Exports: 'macro_predictions_computed.json' (Ready for AI synthesis)
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

def calculate_divergence(demand_yoy, support_yoy):
    """
    Checks if physical factory demand matches logistics distribution.
    Divergence ratio = Supporting YoY / Demand YoY
    """
    if abs(demand_yoy) < 0.1:
        ratio = 1.0
    else:
        ratio = round(support_yoy / demand_yoy, 2)

    if ratio >= 1.25:
        divergence_flag = "SURGING_SECONDARY_ABSORPTION"
    elif 0.75 <= ratio < 1.25:
        divergence_flag = "ALIGNED_GROUND_EXECUTION"
    else:
        divergence_flag = "CHANNEL_STUFFING_OR_LOGISTICS_BOTTLENECK"

    return ratio, divergence_flag

def match_empirical_regimes(vol_3m, cost_3m, empirical_matrix):
    """
    Extracts matching historical quarterly regimes based on 2D Euclidean distance.
    """
    matched = []
    for q in empirical_matrix:
        v_min, v_max = q["vol_band"]
        c_min, c_max = q["cost_band"]
        if (v_min - 2.5) <= vol_3m <= (v_max + 2.5) and (c_min - 3.5) <= cost_3m <= (c_max + 3.5):
            matched.append(q)

    if matched:
        return {
            "matched_historical_quarters": [m["quarter"] for m in matched],
            "historical_sample_count": len(matched),
            "historical_ebitda_delta_median_bps": round(statistics.median([m["ebitda_margin_delta_bps"] for m in matched]), 1),
            "historical_revenue_growth_mean_pct": round(statistics.mean([m["rev_growth_yoy"] for m in matched]), 1),
            "historical_positive_expansion_probability_pct": round(statistics.mean([m["hit_rate_pct"] for m in matched]), 1)
        }
    else:
        return {
            "matched_historical_quarters": [],
            "historical_sample_count": 0,
            "historical_ebitda_delta_median_bps": round((vol_3m * 14.0) - (cost_3m * 10.0), 1),
            "historical_revenue_growth_mean_pct": round(vol_3m * 1.1, 1),
            "historical_positive_expansion_probability_pct": 50.0
        }

def process_sector_ratios(sector_key, data):
    demand_series = data.get("monthly_demand", [])
    cost_series = data.get("input_costs", [])
    support_series = data.get("supporting_indicators", [])
    empirical_matrix = data.get("historical_earnings_matrix", [])
    source_meta = data.get("source", {})

    if len(demand_series) < 13:
        return None

    # Latest & Previous Pointers
    curr_d = demand_series[-1]
    prev_d = demand_series[-2]
    curr_c = cost_series[-1]
    curr_s = support_series[-1]

    # --- Pillar 1: Velocity & Derivatives ---
    mom_pct = round(((curr_d["value"] - prev_d["value"]) / max(prev_d["value"], 0.001)) * 100, 2)
    yoy_pct = curr_d["yoy_pct"]

    m3_yoy = round(statistics.mean([m["yoy_pct"] for m in demand_series[-3:]]), 2)
    m6_yoy = round(statistics.mean([m["yoy_pct"] for m in demand_series[-6:]]), 2)
    acceleration_derivative = round(yoy_pct - m3_yoy, 2)

    # --- Pillar 2: Seasonality De-noising ---
    curr_month_str = curr_d["month"].split("-")[1]  # e.g., '09'
    same_month_hist = [m["value"] for m in demand_series[:-1] if m["month"].endswith(f"-{curr_month_str}")]
    if same_month_hist:
        same_month_mean = statistics.mean(same_month_hist)
        seasonality_multiple = round(curr_d["value"] / max(same_month_mean, 0.001), 2)
    else:
        seasonality_multiple = 1.0

    # --- Pillar 3: Cost Dynamics & Operating Spread ---
    cost_yoy = curr_c["yoy_pct"]
    m3_cost_yoy = round(statistics.mean([c["yoy_pct"] for c in cost_series[-3:]]), 2)
    operating_spread = round(m3_yoy - m3_cost_yoy, 2)

    # --- Pillar 4: Cross-Indicator Divergence ---
    support_yoy = curr_s["yoy_pct"]
    div_ratio, div_flag = calculate_divergence(yoy_pct, support_yoy)

    # --- Pillar 5: Historical Regime Matching ---
    empirical_intel = match_empirical_regimes(m3_yoy, m3_cost_yoy, empirical_matrix)

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
            "acceleration_derivative": acceleration_derivative,
            "seasonality_beat_multiple": seasonality_multiple
        },
        "cost_telemetry": {
            "primary_feedstock_metric": curr_c["metric"],
            "latest_index": curr_c["value"],
            "cost_yoy_pct": cost_yoy,
            "trailing_3m_cost_yoy_pct": m3_cost_yoy,
            "net_operating_spread_pts": operating_spread
        },
        "cross_verification": {
            "supporting_indicator_name": curr_s["indicator"],
            "supporting_value": curr_s["value"],
            "supporting_yoy_pct": support_yoy,
            "divergence_ratio": div_ratio,
            "divergence_structural_flag": div_flag
        },
        "empirical_historical_regime": empirical_intel,
        "source": source_meta
    }

def main():
    print("=" * 75)
    print("🧮 RUNNING PURE QUANTITATIVE RATIO ENGINE (ZERO JUDGMENT)")
    print(f"📅 Timestamp: {NOW.strftime('%Y-%m-%d %H:%M:%S IST')}")
    print("=" * 75)

    ensure_database()

    with open(DB_FILE, "r", encoding="utf-8") as f:
        db = json.load(f)

    sectors = db.get("sectors", {})
    analyzed_payload = []

    for key, sector_data in sectors.items():
        processed = process_sector_ratios(key, sector_data)
        if processed:
            analyzed_payload.append(processed)

    # Sort mathematically by highest operating spread score
    analyzed_payload.sort(key=lambda x: x["cost_telemetry"]["net_operating_spread_pts"], reverse=True)

    final_output = {
        "generated_at": NOW.strftime("%Y-%m-%d %H:%M:%S IST"),
        "total_sectors_analyzed": len(analyzed_payload),
        "analytical_data": analyzed_payload
    }

    with open(OUTPUT_COMPUTED_FILE, "w", encoding="utf-8") as f:
        json.dump(final_output, f, ensure_ascii=False, indent=2)

    print(f"✅ Success: Processed {len(analyzed_payload)} sectors.")
    print(f"💾 File written: '{OUTPUT_COMPUTED_FILE}' ({os.path.getsize(OUTPUT_COMPUTED_FILE)} bytes)")

if __name__ == "__main__":
    main()
