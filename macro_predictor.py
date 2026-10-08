#!/usr/bin/env python3
"""
REPLACED: ADVANCED QUANTITATIVE PREDICTOR (Multi-Horizon & Seasonality Normalizer)
- Computes: Current Month YoY, MoM, 3M YoY, 6M YoY
- Trajectory Derivative: ACCELERATING vs PEAKING vs DECELERATING
- Same-Month Multi-Year Baseline (Is Sep 2026 normal seasonal vs Sep 2025/2024?)
- Writes pre-computed facts to 'macro_predictions_computed.json'
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

def compute_multiyear_metrics():
    if not os.path.exists(DB_FILE):
        print(f"⚠️ '{DB_FILE}' missing. Running seeder...")
        import subprocess
        subprocess.run([sys.executable, "seed_historical_macro_db.py"], check=True)

    with open(DB_FILE, "r", encoding="utf-8") as f:
        db = json.load(f)

    subsectors = db.get("subsectors", {})
    analyzed_data = []

    print(f"🧮 Processing multi-horizon seasonality for {len(subsectors)} sub-sectors...")

    for key, item in subsectors.items():
        name = item.get("name", key)
        series = item.get("series", [])
        if len(series) < 24:
            continue

        # Latest pointers
        latest = series[-1]
        cal_month = latest["cal_month"] # e.g. "Sep"
        current_vol = latest["volume"]
        prev_month_vol = series[-2]["volume"]

        # 1. MoM Growth
        mom_growth = round(((current_vol - prev_month_vol) / prev_month_vol) * 100, 2)

        # 2. YoY (Latest month vs exactly 12 months ago)
        yoy_base = series[-13]["volume"]
        yoy_growth = round(((current_vol - yoy_base) / yoy_base) * 100, 2)

        # 3. 3-Month Trailing YoY Average
        curr_3m_vol = sum(m["volume"] for m in series[-3:])
        prev_3m_vol = sum(m["volume"] for m in series[-15:-12])
        growth_3m_yoy = round(((curr_3m_vol - prev_3m_vol) / prev_3m_vol) * 100, 2)

        # 4. 6-Month Trailing YoY Average
        curr_6m_vol = sum(m["volume"] for m in series[-6:])
        prev_6m_vol = sum(m["volume"] for m in series[-18:-12])
        growth_6m_yoy = round(((curr_6m_vol - prev_6m_vol) / prev_6m_vol) * 100, 2)

        # 5. Trajectory Velocity Derivative
        if yoy_growth > growth_3m_yoy > growth_6m_yoy:
            trend_velocity = "ACCELERATING_SURGE"
        elif yoy_growth < growth_3m_yoy < growth_6m_yoy:
            trend_velocity = "DECELERATING_SLOWDOWN"
        elif yoy_growth > growth_3m_yoy and growth_3m_yoy <= growth_6m_yoy:
            trend_velocity = "EARLY_INFLECTION"
        else:
            trend_velocity = "STEADY_MATURE"

        # 6. Seasonality Normalizer (Same-Month Historical Average)
        same_months_hist = [m["volume"] for m in series if m["cal_month"] == cal_month and m != latest]
        historical_same_month_avg = statistics.mean(same_months_hist)
        seasonality_beat_ratio = round(current_vol / historical_same_month_avg, 2)

        # 7. Input Cost Deflation Spread
        curr_cost_3m = sum(m["cost_index"] for m in series[-3:]) / 3.0
        prev_cost_3m = sum(m["cost_index"] for m in series[-15:-12]) / 3.0
        cost_yoy_delta = round(((curr_cost_3m - prev_cost_3m) / prev_cost_3m) * 100, 2)
        operating_spread = round(growth_3m_yoy - cost_yoy_delta, 2)

        analyzed_data.append({
            "subsector_key": key,
            "subsector_name": name,
            "unit": item.get("unit", ""),
            "latest_month": latest["month"],
            "quantitative_metrics": {
                "current_month_yoy_pct": yoy_growth,
                "current_mom_pct": mom_growth,
                "trailing_3m_yoy_pct": growth_3m_yoy,
                "trailing_6m_yoy_pct": growth_6m_yoy,
                "trend_momentum": trend_velocity,
                "seasonality_beat_multiple": seasonality_beat_ratio,
                "input_cost_yoy_pct": cost_yoy_delta,
                "operating_spread_score": operating_spread
            },
            "financial_elasticity_anchor": item.get("financial_elasticity", {})
        })

    # Sort descending by operating spread
    analyzed_data.sort(key=lambda x: x["quantitative_metrics"]["operating_spread_score"], reverse=True)

    output = {
        "computed_at": NOW.strftime("%Y-%m-%d %H:%M:%S IST"),
        "total_analyzed": len(analyzed_data),
        "analyzed_subsectors": analyzed_data
    }

    with open(OUTPUT_COMPUTED_FILE, "w", encoding="utf-8") as f:
        json.dump(output, f, ensure_ascii=False, indent=2)

    print(f"✅ Success: Generated Multi-Horizon Computed File at '{OUTPUT_COMPUTED_FILE}'.")

if __name__ == "__main__":
    compute_multiyear_metrics()
