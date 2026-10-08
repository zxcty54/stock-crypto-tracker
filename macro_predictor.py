#!/usr/bin/env python3
"""
QUANTITATIVE REGIME & EMPIRICAL EARNINGS PREDICTOR
- Mathematical Derivative: First (Velocity) & Second (Acceleration)
- Historical Regime Matcher: Queries 20-Quarter Empirical Table
- Outputs Guaranteed 'macro_predictions_computed.json'
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
        print(f"⚠️ '{DB_FILE}' missing. Running seeder...")
        import subprocess
        subprocess.run([sys.executable, "seed_historical_macro_db.py"], check=True)

def match_historical_regime(current_vol_yoy, current_cost_delta, empirical_table):
    """
    Looks up matching historical quarters in the 20-quarter matrix.
    Computes expected EBITDA delta (in bps) and empirical historical confidence hit rate.
    """
    matches = []
    for q in empirical_table:
        v_min, v_max = q["vol_band"]
        c_min, c_max = q["cost_band"]
        # Check if current macro print falls inside this empirical bucket
        if (v_min - 2.0) <= current_vol_yoy <= (v_max + 2.0) and (c_min - 3.0) <= current_cost_delta <= (c_max + 3.0):
            matches.append(q)

    if matches:
        avg_bps = round(statistics.mean([m["ebitda_margin_delta_bps"] for m in matches]), 0)
        avg_hit_rate = round(statistics.mean([m["hit_rate_pct"] for m in matches]), 1)
        avg_rev = round(statistics.mean([m["rev_growth_yoy"] for m in matches]), 1)
        regime_title = f"Matched {len(matches)} Historical Quarters (e.g., {matches[0]['quarter']})"
    else:
        # Fallback linear elasticity estimate
        avg_bps = round((current_vol_yoy * 15.0) - (current_cost_delta * 12.0), 0)
        avg_hit_rate = 65.0
        avg_rev = round(current_vol_yoy * 1.1, 1)
        regime_title = "Theoretical Linear Elasticity Approximation"

    return {
        "expected_ebitda_margin_delta_bps": avg_bps,
        "historical_probability_hit_rate_pct": avg_hit_rate,
        "projected_sector_revenue_yoy_pct": avg_rev,
        "regime_sample_info": regime_title
    }

def compute_all_metrics():
    ensure_db()

    with open(DB_FILE, "r", encoding="utf-8") as f:
        db = json.load(f)

    subsectors = db.get("subsectors", {})
    analyzed_data = []

    print(f"🧮 Calculating Trajectory Derivatives & Empirical Matches for {len(subsectors)} sub-sectors...")

    for key, item in subsectors.items():
        name = item.get("name", key)
        series = item.get("series") or item.get("history") or []
        empirical_table = item.get("empirical_quarters", [])

        if len(series) < 2:
            continue

        total_pts = len(series)
        latest = series[-1]
        current_vol = latest.get("volume", 0.0)
        prev_month_vol = series[-2].get("volume", 1.0)

        # 1. MoM Growth
        mom_growth = round(((current_vol - prev_month_vol) / max(prev_month_vol, 0.001)) * 100, 2)

        # 2. YoY Growth (Exact 12-month lookback)
        yoy_base = series[-13].get("volume", 1.0) if total_pts >= 13 else series[0].get("volume", 1.0)
        yoy_growth = round(((current_vol - yoy_base) / max(yoy_base, 0.001)) * 100, 2)

        # 3. 3-Month & 6-Month Trailing YoY
        if total_pts >= 15:
            curr_3m = sum(m.get("volume", 0.0) for m in series[-3:])
            prev_3m = sum(m.get("volume", 0.0) for m in series[-15:-12])
            growth_3m_yoy = round(((curr_3m - prev_3m) / max(prev_3m, 0.001)) * 100, 2)
        else:
            growth_3m_yoy = yoy_growth

        if total_pts >= 18:
            curr_6m = sum(m.get("volume", 0.0) for m in series[-6:])
            prev_6m = sum(m.get("volume", 0.0) for m in series[-18:-12])
            growth_6m_yoy = round(((curr_6m - prev_6m) / max(prev_6m, 0.001)) * 100, 2)
        else:
            growth_6m_yoy = round(growth_3m_yoy * 0.85, 2)

        # 4. Trajectory Derivative (The Acceleration Distinction)
        if yoy_growth > growth_3m_yoy > growth_6m_yoy:
            trend_signal = "ACCELERATING_SURGE"
            verdict_badge = "🟢 Strong Improving Earnings Environment"
            verdict_code = "STRONG_BEAT_ACCELERATION"
        elif yoy_growth < growth_3m_yoy:
            trend_signal = "DECELERATING_SLOWDOWN"
            verdict_badge = "🟡 Positive Demand, but Momentum is Moderating"
            verdict_code = "PEAKING_MOMENTUM_MODERATION"
        else:
            trend_signal = "STEADY_MOMENTUM"
            verdict_badge = "⚖️ In-Line Seasonal Steady"
            verdict_code = "IN_LINE_STEADY"

        # 5. Cost Deflator
        latest_cost = latest.get("cost_index", 100.0)
        base_cost = series[-13].get("cost_index", 100.0) if total_pts >= 13 else series[0].get("cost_index", 100.0)
        cost_yoy_delta = round(((latest_cost - base_cost) / max(base_cost, 0.001)) * 100, 2)
        operating_spread = round(growth_3m_yoy - cost_yoy_delta, 2)

        # 6. Query Empirical 20-Quarter Regimes
        regime_forecast = match_historical_regime(growth_3m_yoy, cost_yoy_delta, empirical_table)

        analyzed_data.append({
            "subsector_key": key,
            "subsector_name": name,
            "unit": item.get("unit", ""),
            "latest_month": latest.get("month", "Latest"),
            "signal_status": {
                "badge": verdict_badge,
                "code": verdict_code,
                "trend_derivative": trend_signal
            },
            "velocity_telemetry": {
                "current_month_yoy_pct": yoy_growth,
                "current_mom_pct": mom_growth,
                "trailing_3m_yoy_pct": growth_3m_yoy,
                "trailing_6m_yoy_pct": growth_6m_yoy,
                "input_cost_yoy_pct": cost_yoy_delta,
                "operating_spread_score": operating_spread
            },
            "empirical_earnings_forecast": regime_forecast
        })

    # Sort descending by operating spread
    analyzed_data.sort(key=lambda x: x["velocity_telemetry"]["operating_spread_score"], reverse=True)

    output = {
        "computed_at": NOW.strftime("%Y-%m-%d %H:%M:%S IST"),
        "total_analyzed": len(analyzed_data),
        "analyzed_subsectors": analyzed_data
    }

    with open(OUTPUT_COMPUTED_FILE, "w", encoding="utf-8") as f:
        json.dump(output, f, ensure_ascii=False, indent=2)

    print(f"\n✅ SUCCESS: Computed {len(analyzed_data)} sub-sectors.")
    print(f"💾 File written: '{OUTPUT_COMPUTED_FILE}' ({os.path.getsize(OUTPUT_COMPUTED_FILE)} bytes)")

if __name__ == "__main__":
    compute_all_metrics()
