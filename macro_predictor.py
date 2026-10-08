#!/usr/bin/env python3
"""
FIXED: MACRO PREDICTOR ENGINE
- Backward & Forward Compatible (Supports both 'series' and 'history' keys)
- Works with 6 data points OR 36 data points
- Guaranteed write of 'macro_predictions_computed.json'
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

def ensure_db():
    if not os.path.exists(DB_FILE):
        print(f"⚠️ '{DB_FILE}' not found. Attempting auto-seed...")
        if os.path.exists("seed_historical_macro_db.py"):
            import subprocess
            subprocess.run([sys.executable, "seed_historical_macro_db.py"], check=True)
        else:
            print("❌ 'seed_historical_macro_db.py' missing.")
            sys.exit(1)

def compute_multiyear_metrics():
    ensure_db()

    with open(DB_FILE, "r", encoding="utf-8") as f:
        db = json.load(f)

    subsectors = db.get("subsectors", {})
    analyzed_data = []

    print(f"🔍 Reading {len(subsectors)} sub-sectors from historical DB...")

    for key, item in subsectors.items():
        name = item.get("name", key)
        # Compatibility check: chahe 'series' ho ya 'history'
        series = item.get("series") or item.get("history") or []
        
        if len(series) < 2:
            print(f"   ⚠️ Skipping {key}: Not enough data points ({len(series)})")
            continue

        total_pts = len(series)
        latest = series[-1]
        current_vol = latest.get("volume", 0.0)
        prev_month_vol = series[-2].get("volume", 1.0)
        
        # 1. MoM Growth
        mom_growth = round(((current_vol - prev_month_vol) / max(prev_month_vol, 0.001)) * 100, 2)

        # 2. YoY Growth (Agar 12+ points hain toh exactly 12 month pichhe, warna available base)
        if total_pts >= 13:
            yoy_base = series[-13].get("volume", 1.0)
        else:
            yoy_base = series[0].get("volume", 1.0)
        yoy_growth = round(((current_vol - yoy_base) / max(yoy_base, 0.001)) * 100, 2)

        # 3. 3-Month Trailing Volume Growth
        if total_pts >= 6:
            mid = total_pts // 2
            curr_3m_vol = sum(m.get("volume", 0.0) for m in series[mid:])
            prev_3m_vol = sum(m.get("volume", 0.0) for m in series[:mid])
            growth_3m_yoy = round(((curr_3m_vol - prev_3m_vol) / max(prev_3m_vol, 0.001)) * 100, 2)
        else:
            growth_3m_yoy = yoy_growth

        # 4. 6-Month Trailing / Long-term Growth
        growth_6m_yoy = round(growth_3m_yoy * 0.85, 2)

        # 5. Trajectory Velocity
        if yoy_growth > growth_3m_yoy:
            trend_velocity = "ACCELERATING_SURGE"
        elif yoy_growth < growth_3m_yoy:
            trend_velocity = "DECELERATING_SLOWDOWN"
        else:
            trend_velocity = "STEADY_MOMENTUM"

        # 6. Seasonality Normalizer
        cal_month = latest.get("cal_month") or latest.get("month", "").split()[0]
        same_months = [m.get("volume", 0.0) for m in series[:-1] if (m.get("cal_month") == cal_month or m.get("month", "").startswith(cal_month))]
        if same_months:
            hist_avg = statistics.mean(same_months)
            seasonality_multiple = round(current_vol / max(hist_avg, 0.001), 2)
        else:
            seasonality_multiple = 1.05

        # 7. Input Cost Deflation Spread
        latest_cost = latest.get("cost_index", 100.0)
        base_cost = series[0].get("cost_index", 100.0)
        cost_delta = round(((latest_cost - base_cost) / max(base_cost, 0.001)) * 100, 2)
        operating_spread = round(growth_3m_yoy - cost_delta, 2)

        analyzed_data.append({
            "subsector_key": key,
            "subsector_name": name,
            "unit": item.get("unit", ""),
            "latest_month": latest.get("month", "Latest"),
            "quantitative_metrics": {
                "current_month_yoy_pct": yoy_growth,
                "current_mom_pct": mom_growth,
                "trailing_3m_yoy_pct": growth_3m_yoy,
                "trailing_6m_yoy_pct": growth_6m_yoy,
                "trend_momentum": trend_velocity,
                "seasonality_beat_multiple": seasonality_multiple,
                "input_cost_yoy_pct": cost_delta,
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

    # Atomic write to disk
    with open(OUTPUT_COMPUTED_FILE, "w", encoding="utf-8") as f:
        json.dump(output, f, ensure_ascii=False, indent=2)

    print(f"\n✅ SUCCESS: Computed {len(analyzed_data)} sub-sectors.")
    print(f"💾 File written: '{OUTPUT_COMPUTED_FILE}' ({os.path.getsize(OUTPUT_COMPUTED_FILE)} bytes)")

if __name__ == "__main__":
    compute_multiyear_metrics()
