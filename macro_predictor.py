#!/usr/bin/env python3
"""
MACRO QUARTERLY EARNINGS PREDICTOR ENGINE
=========================================
- Reads 6-Month Rolling Time Series from 'macro_historical_db.json'
- Computes QoQ Sequential Volume Velocity vs Raw Input Cost Deflation
- Flags Positive Operating Leverage (Volume UP + Cost DOWN) vs Margin Pressure
- Outputs to 'macro_quarterly_predictions.json' and dispatches Telegram alert card
"""

import os
import sys
import json
import requests
from datetime import datetime, timezone, timedelta

DB_FILE = "macro_historical_db.json"
PREDICTIONS_OUTPUT = "macro_quarterly_predictions.json"

BOT_TOKEN = os.environ.get("TELEGRAM_BOT_TOKEN", "").strip()
CHAT_ID = os.environ.get("TELEGRAM_CHAT_ID", "@bhaga_657").strip()

IST = timezone(timedelta(hours=5, minutes=30))
NOW = datetime.now(IST)

def compute_subsector_trajectory(history_series):
    """
    Splits 6 months into two 3-month blocks:
    - Q_prev: [T-5, T-4, T-3]
    - Q_curr: [T-2, T-1, T]
    Calculates Volume Growth % and Input Cost Inflation/Deflation %.
    """
    if len(history_series) < 6:
        return None

    # Sequential quarterly volume calculation
    q_prev_vol = sum([m["volume"] for m in history_series[0:3]])
    q_curr_vol = sum([m["volume"] for m in history_series[3:6]])

    # Sequential quarterly cost index average
    q_prev_cost = sum([m["cost_index"] for m in history_series[0:3]]) / 3.0
    q_curr_cost = sum([m["cost_index"] for m in history_series[3:6]]) / 3.0

    if q_prev_vol <= 0 or q_prev_cost <= 0:
        return None

    vol_growth = round(((q_curr_vol - q_prev_vol) / q_prev_vol) * 100, 2)
    cost_delta = round(((q_curr_cost - q_prev_cost) / q_prev_cost) * 100, 2)
    
    # Margin Spread Proxy = Volume Growth - Cost Delta
    operating_spread = round(vol_growth - cost_delta, 2)

    # Latest month momentum vs 6-month average
    latest_month_vol = history_series[-1]["volume"]
    m6_avg = sum([m["volume"] for m in history_series]) / 6.0
    latest_vs_base = round(((latest_month_vol - m6_avg) / m6_avg) * 100, 2)

    # Institutional Signal Verdict Classification
    if vol_growth >= 10.0 and cost_delta <= 1.0:
        verdict = "STRONG_POSITIVE_EARNINGS_SURPRISE"
        badge = "🔥 STRONG BEAT EXPECTED"
        thesis = "Aggressive dispatch acceleration paired with input cost contraction confirms strong operating leverage & gross margin expansion."
    elif vol_growth >= 10.0 and cost_delta > 4.0:
        verdict = "TOPLINE_BEAT_MARGIN_COMPRESSION"
        badge = "⚠️ REVENUE SURGE / PAT SQUEEZE"
        thesis = "Topline volume robust, but elevated feedstock/energy costs will constrain EBITDA margin flow-through."
    elif vol_growth <= -5.0 and cost_delta >= 2.0:
        verdict = "EARNINGS_DOWNGRADE_RISK"
        badge = "🚨 DOWNGRADE RISK"
        thesis = "Physical dispatch slowdown coupled with sticky operational overhead points to acute negative operating deleverage."
    elif vol_growth <= -5.0 and cost_delta <= -4.0:
        verdict = "DEFENSIVE_MARGIN_STABILITY"
        badge = "🛡️ MARGIN RESILIENCE"
        thesis = "Soft volumes offset by aggressive raw material deflation; stable EBITDA margins on a muted revenue base."
    else:
        verdict = "IN_LINE_PERFORMANCE"
        badge = "⚖️ IN-LINE TRAJECTORY"
        thesis = "Volume run-rates and input pricing pacing consistent with seasonal historic baseline."

    return {
        "verdict": verdict,
        "badge": badge,
        "sequential_volume_growth_pct": vol_growth,
        "input_cost_delta_pct": cost_delta,
        "operating_spread_score": operating_spread,
        "latest_vs_6m_avg_pct": latest_vs_base,
        "thesis": thesis
    }

def format_telegram_alert(prediction):
    m = prediction["metrics"]
    vol_sign = "+" if m["sequential_volume_growth_pct"] >= 0 else ""
    cost_sign = "+" if m["input_cost_delta_pct"] >= 0 else ""
    spread_sign = "+" if m["operating_spread_score"] >= 0 else ""

    return f"""🎯 <b>MACRO PRE-EARNINGS RADAR: {m['badge']}</b>
━━━━━━━━━━━━━━━━━━━━━
📍 <b>Sub-Sector:</b>
<b>{prediction['subsector']}</b>

📊 <b>6-Month Trajectory vs Input Cost Spread:</b>
• <b>Sequential Volume Trend (QoQ):</b> <b>{vol_sign}{m['sequential_volume_growth_pct']}%</b>
• <b>Input Cost / Fuel Delta:</b> <b>{cost_sign}{m['input_cost_delta_pct']}%</b>
• <b>Operating Leverage Spread:</b> <b>{spread_sign}{m['operating_spread_score']} pts</b>

💡 <b>Quarterly Forecast Thesis:</b>
↳ {m['thesis']}

📌 <b>Lead Indicator Edge:</b>
Physical commodity dispatches reflect actual ground execution 30-45 days before corporate earnings declarations.
━━━━━━━━━━━━━━━━━━━━━
#EarningsRadar #{prediction['key'][:18]} #MacroIntelligence
⚠️ <i>Educational supply-chain telemetry only. No stock recommendations.</i>"""

def main():
    print("=" * 75)
    print("🧠 MACRO PREDICTOR: COMPUTING 6-MONTH ROLLING EARNINGS TRAJECTORIES")
    print(f"📅 Run Time: {NOW.strftime('%Y-%m-%d %H:%M:%S IST')}")
    print("=" * 75)

    if not os.path.exists(DB_FILE):
        print(f"❌ '{DB_FILE}' not found! Run seeder or scraper first.")
        sys.exit(1)

    with open(DB_FILE, "r", encoding="utf-8") as f:
        db = json.load(f)

    subsectors = db.get("subsectors", {})
    all_predictions = []

    for key, data in subsectors.items():
        name = data.get("name", key)
        history = data.get("history", [])

        metrics = compute_subsector_trajectory(history)
        if metrics:
            all_predictions.append({
                "key": key,
                "subsector": name,
                "unit": data.get("unit", ""),
                "metrics": metrics,
                "recent_history": history[-3:]  # Latest quarter snapshot
            })

    print(f"✅ Processed {len(all_predictions)} sub-sectors successfully.")

    # Save output feed
    output_data = {
        "generated_at": NOW.strftime("%Y-%m-%d %H:%M:%S IST"),
        "total_analyzed": len(all_predictions),
        "predictions": all_predictions
    }
    with open(PREDICTIONS_OUTPUT, "w", encoding="utf-8") as f:
        json.dump(output_data, f, ensure_ascii=False, indent=2)
    print(f"💾 Detailed predictions saved to '{PREDICTIONS_OUTPUT}'.")

    # High conviction filters (Strong Positive or Acute Risk)
    conviction_alerts = [
        p for p in all_predictions 
        if p["metrics"]["verdict"] in ("STRONG_POSITIVE_EARNINGS_SURPRISE", "EARNINGS_DOWNGRADE_RISK", "TOPLINE_BEAT_MARGIN_COMPRESSION")
    ]

    if not conviction_alerts:
        print("ℹ️ All sub-sectors tracking in-line with seasonal averages.")
        return

    # Sort by operating spread score descending to pick top breakout
    top_prediction = max(conviction_alerts, key=lambda x: x["metrics"]["operating_spread_score"])
    telegram_card = format_telegram_alert(top_prediction)

    print("\n" + telegram_card + "\n")

    # Dispatch to Telegram if bot token configured
    if BOT_TOKEN:
        print(f"🚀 Broadcasting Pre-Earnings Radar Card to {CHAT_ID}...")
        try:
            url = f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage"
            payload = {
                "chat_id": CHAT_ID,
                "text": telegram_card,
                "parse_mode": "HTML",
                "disable_web_page_preview": True
            }
            res = requests.post(url, json=payload, timeout=20).json()
            if res.get("ok"):
                print("✅ Successfully broadcasted alert to Telegram!")
            else:
                print(f"❌ Telegram broadcast failed: {res.get('description')}")
        except Exception as e:
            print(f"⚠️ Network error while dispatching: {e}")
    else:
        print("ℹ️ TELEGRAM_BOT_TOKEN not provided in environment. Card logged locally.")

if __name__ == "__main__":
    main()
