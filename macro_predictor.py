#!/usr/bin/env python3
"""
MODULE: MACRO QUANTITATIVE ENGINE (Pure Python Math)
- Reads: 'macro_historical_db.json'
- Computes: Sequential QoQ Volume %, Cost Inflation %, Operating Spread Score
- Filters: Outperformers, Margin Pressure & Downside Risk
- Writes: 'macro_predictions_computed.json'
"""

import os
import sys
import json
from datetime import datetime, timezone, timedelta

DB_FILE = "macro_historical_db.json"
OUTPUT_COMPUTED_FILE = "macro_predictions_computed.json"

IST = timezone(timedelta(hours=5, minutes=30))
NOW = datetime.now(IST)

def compute_all_metrics():
    if not os.path.exists(DB_FILE):
        print(f"❌ Error: '{DB_FILE}' not found. Seed historical data first.")
        sys.exit(1)

    with open(DB_FILE, "r", encoding="utf-8") as f:
        db = json.load(f)

    subsectors = db.get("subsectors", {})
    analyzed_list = []

    for key, data in subsectors.items():
        history = data.get("history", [])
        if len(history) < 6:
            continue

        name = data.get("name", key)
        unit = data.get("unit", "")

        # Block 1: Q_prev (T-5, T-4, T-3)
        # Block 2: Q_curr (T-2, T-1, T)
        q_prev_vol = sum(m["volume"] for m in history[0:3])
        q_curr_vol = sum(m["volume"] for m in history[3:6])

        q_prev_cost = sum(m["cost_index"] for m in history[0:3]) / 3.0
        q_curr_cost = sum(m["cost_index"] for m in history[3:6]) / 3.0

        if q_prev_vol <= 0 or q_prev_cost <= 0:
            continue

        vol_growth = round(((q_curr_vol - q_prev_vol) / q_prev_vol) * 100, 2)
        cost_delta = round(((q_curr_cost - q_prev_cost) / q_prev_cost) * 100, 2)
        spread_score = round(vol_growth - cost_delta, 2)

        # Classification based on operating leverage dynamics
        if vol_growth >= 10.0 and cost_delta <= 1.5:
            classification = "OPERATING_LEVERAGE_OUTPERFORMER"
        elif vol_growth >= 10.0 and cost_delta > 4.0:
            classification = "MARGIN_SQUEEZE_RISK"
        elif vol_growth <= -5.0 and cost_delta >= 2.0:
            classification = "VOLUME_DELEVERAGE_DOWNGRADE"
        elif vol_growth <= -5.0 and cost_delta <= -4.0:
            classification = "DEFENSIVE_MARGIN_RESILIENCE"
        else:
            classification = "IN_LINE_SEASONAL"

        analyzed_list.append({
            "subsector_key": key,
            "subsector_name": name,
            "unit": unit,
            "classification": classification,
            "sequential_vol_growth_pct": vol_growth,
            "input_cost_inflation_pct": cost_delta,
            "operating_spread_score": spread_score,
            "q_prev_volume_agg": round(q_prev_vol, 2),
            "q_curr_volume_agg": round(q_curr_vol, 2)
        })

    # Sort descending by operating spread
    analyzed_list.sort(key=lambda x: x["operating_spread_score"], reverse=True)

    # Segmentations for downstream AI synthesis
    outperformers = [s for s in analyzed_list if s["classification"] == "OPERATING_LEVERAGE_OUTPERFORMER"]
    margin_squeezes = [s for s in analyzed_list if s["classification"] == "MARGIN_SQUEEZE_RISK"]
    risks = [s for s in analyzed_list if s["classification"] == "VOLUME_DELEVERAGE_DOWNGRADE"]

    computed_payload = {
        "calculated_at": NOW.strftime("%Y-%m-%d %H:%M:%S IST"),
        "total_subsectors_analyzed": len(analyzed_list),
        "summary": {
            "outperformers_count": len(outperformers),
            "margin_squeeze_count": len(margin_squeezes),
            "downgrade_risk_count": len(risks)
        },
        "top_outperformers": outperformers,
        "margin_pressure_sectors": margin_squeezes,
        "all_ranked_subsectors": analyzed_list
    }

    with open(OUTPUT_COMPUTED_FILE, "w", encoding="utf-8") as f:
        json.dump(computed_payload, f, ensure_ascii=False, indent=2)

    print(f"🧮 Math Engine Complete: {len(analyzed_list)} sub-sectors calculated.")
    print(f"💾 Output saved to: '{OUTPUT_COMPUTED_FILE}'")

if __name__ == "__main__":
    compute_all_metrics()
