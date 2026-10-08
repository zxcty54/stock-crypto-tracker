#!/usr/bin/env python3
"""
MODULE: MACRO QUANTITATIVE ENGINE (Pure Python Math)
- Auto-seeds DB if missing
- Computes QoQ Sequential Volume %, Cost Delta %, Operating Spread Score
- Writes guaranteed 'macro_predictions_computed.json'
"""

import os
import sys
import json
from datetime import datetime, timezone, timedelta

DB_FILE = "macro_historical_db.json"
OUTPUT_COMPUTED_FILE = "macro_predictions_computed.json"

IST = timezone(timedelta(hours=5, minutes=30))
NOW = datetime.now(IST)

def ensure_db_exists():
    """Agar DB file missing ho, toh seeder ko call karke create karo."""
    if not os.path.exists(DB_FILE):
        print(f"⚠️ '{DB_FILE}' not found. Attempting auto-seed...")
        if os.path.exists("seed_historical_macro_db.py"):
            import subprocess
            subprocess.run([sys.executable, "seed_historical_macro_db.py"], check=True)
        else:
            print("❌ 'seed_historical_macro_db.py' not found. Cannot proceed.")
            sys.exit(1)

def compute_all_metrics():
    ensure_db_exists()

    with open(DB_FILE, "r", encoding="utf-8") as f:
        db = json.load(f)

    subsectors = db.get("subsectors", {})
    analyzed_list = []

    print(f"🔍 Reading {len(subsectors)} sub-sectors from historical DB...")

    for key, data in subsectors.items():
        history = data.get("history", [])
        if len(history) < 2:
            continue

        name = data.get("name", key)
        unit = data.get("unit", "")

        # Dynamic split: agar 6 points hain toh 3-3, warna half-half
        mid = len(history) // 2
        prev_block = history[:mid]
        curr_block = history[mid:]

        q_prev_vol = sum(m.get("volume", 0.0) for m in prev_block)
        q_curr_vol = sum(m.get("volume", 0.0) for m in curr_block)

        q_prev_cost = sum(m.get("cost_index", 100.0) for m in prev_block) / max(len(prev_block), 1)
        q_curr_cost = sum(m.get("cost_index", 100.0) for m in curr_block) / max(len(curr_block), 1)

        if q_prev_vol <= 0:
            vol_growth = 0.0
        else:
            vol_growth = round(((q_curr_vol - q_prev_vol) / q_prev_vol) * 100, 2)

        cost_delta = round(((q_curr_cost - q_prev_cost) / q_prev_cost) * 100, 2)
        spread_score = round(vol_growth - cost_delta, 2)

        # Quantitative Classification
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

    # Atomic write to guarantee file creation
    with open(OUTPUT_COMPUTED_FILE, "w", encoding="utf-8") as f:
        json.dump(computed_payload, f, ensure_ascii=False, indent=2)

    print(f"✅ Success: Processed {len(analyzed_list)} sub-sectors.")
    print(f"💾 File generated at: '{OUTPUT_COMPUTED_FILE}' ({os.path.getsize(OUTPUT_COMPUTED_FILE)} bytes)")

if __name__ == "__main__":
    compute_all_metrics()
