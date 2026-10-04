"""
WEEKLY RALLY SCANNER  -  "Quiet Breakout + 3-Week Confirmation"
=================================================================
Input : historical_5yr_ohlc.json  ->  {"SYMBOL": [[date, open, high, low, close, volume], ...]}
        (local file na ho to GitHub raw URL se download)
Output: weekly_signals.json  +  console report

STAGES (har stock har hafte inme se kisi ek stage mein):
  0. NONE        - kuch nahi
  1. SETUP       - breakout ke paas, accumulation chal raha hai (watchlist)
  2. BREAKOUT    - quiet breakout hafta aaya, 3-hafte confirmation chal raha hai
  3. CONFIRMED   - 3 hafte pass -> ENTRY (is hafte ke close par)
  4. IN_TRADE    - confirmed ke baad trend chal raha hai (hold)
  x. FAILED      - confirmation fail / stop hit

RULES
  SETUP (watchlist, sab true):
    - Close > 30-week MA aur 30wMA 4 hafte pehle se upar
    - Close, 26-week high se <= 10% neeche (breakout ke paas)
    - Pichhle 10 hafte: up-weeks volume > down-weeks volume (accumulation)
    - Higher low: pichhle 13 hafte ka low > usse pehle ke 26 hafte ka low

  BREAKOUT HAFTA (sab true):
    - Weekly close > pichhle 26 hafte ka highest High
    - Volume >= 2x pichhle 20 hafte ka average
    - Close > 30-week MA
    - Hafte ka move <= +15%   (overheated breakout reject)

  3-HAFTE CONFIRMATION (sab true):
    - 3 hafte baad close > breakout hafte ka close
    - 3 mein se kam se kam 2 hafte green (close > pichhla close)
    - In 3 hafton ka lowest Low >= breakout close - 5%

  TRADE:
    Entry = confirmation (3rd) hafte ka close
    Stop  = breakout hafte ka Low   (weekly CLOSE iske neeche -> exit)
    Exit  = weekly CLOSE 30-week MA ke neeche
"""
import json
import os
import sys
from datetime import datetime

import pandas as pd
import numpy as np

LOCAL_INPUT_FILE = "historical_5yr_ohlc.json"
RAW_GITHUB_URL = "https://raw.githubusercontent.com/zxcty54/stock-crypto-tracker/main/historical_5yr_ohlc.json"
OUTPUT_JSON_FILE = "weekly_signals.json"

# ---------------- SETTINGS ----------------
BREAKOUT_LOOKBACK = 26     # weeks
VOL_MULT = 2.0             # x 20-week avg volume
MAX_BREAKOUT_WEEK = 15.0   # % max move in breakout week
CONFIRM_WEEKS = 3
CONFIRM_MIN_UP = 2
CONFIRM_MAX_DD = 5.0       # %
SETUP_NEAR_HIGH = 10.0     # % below 26w high
CAPITAL = 500000
RISK_PCT = 1.0


# ---------------- DATA ----------------
def load_data(path=LOCAL_INPUT_FILE):
    if os.path.exists(path):
        print(f"📂 Local file: {path}")
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    print("🌐 GitHub se download...")
    import requests
    r = requests.get(RAW_GITHUB_URL, timeout=60)
    r.raise_for_status()
    return r.json()


def to_weekly(records):
    d = pd.DataFrame(records, columns=["Date", "O", "H", "L", "C", "V"])
    d["Date"] = pd.to_datetime(d["Date"], errors="coerce", format="mixed")
    for k in "OHLCV":
        d[k] = pd.to_numeric(d[k], errors="coerce")
    d = d.dropna().query("C > 0").drop_duplicates("Date").sort_values("Date").set_index("Date")
    last_day = d.index[-1]
    w = pd.DataFrame({
        "O": d.O.resample("W-FRI").first(), "H": d.H.resample("W-FRI").max(),
        "L": d.L.resample("W-FRI").min(), "C": d.C.resample("W-FRI").last(),
        "V": d.V.resample("W-FRI").sum(), "LastDay": d.C.resample("W-FRI").apply(lambda s: s.index.max() if len(s) else pd.NaT),
    }).dropna(subset=["C"]).reset_index()
    c, h, l, v = w.C, w.H, w.L, w.V
    w["ma30"] = c.rolling(30, min_periods=20).mean()
    w["ma30_up"] = w.ma30 > w.ma30.shift(4)
    w["av20"] = v.rolling(20, min_periods=8).mean().shift()
    w["vx"] = v / w.av20
    w["hh"] = h.shift().rolling(BREAKOUT_LOOKBACK, min_periods=10).max()
    w["ret"] = c.pct_change() * 100
    up, dn = c > c.shift(), c < c.shift()
    w["udv"] = (v * up).rolling(10).sum() / (v * dn).rolling(10).sum().replace(0, np.nan)
    w["hl"] = l.rolling(13).min() > l.shift(13).rolling(26, min_periods=10).min()
    w["breakout"] = (c > w.hh) & (w.vx >= VOL_MULT) & (c > w.ma30) & (w.ret <= MAX_BREAKOUT_WEEK)
    w["hot_breakout"] = (c > w.hh) & (w.vx >= VOL_MULT) & (c > w.ma30) & (w.ret > MAX_BREAKOUT_WEEK)
    w["setup"] = (c > w.ma30) & w.ma30_up & (c >= w.hh * (1 - SETUP_NEAR_HIGH / 100)) & (c <= w.hh) & (w.udv > 1) & w.hl
    partial = last_day.weekday() < 4  # Friday nahi -> aakhri hafta adhoora
    return w, partial


# ---------------- ENGINE ----------------
def run_symbol(sym, w):
    c, l, h = w.C.values, w.L.values, w.H.values
    ma30, n = w.ma30.values, len(w) - 1
    trades, i = [], 30
    state = {"stage": "NONE"}
    while i <= n:
        if not w.breakout.iat[i]:
            i += 1
            continue
        b = i
        bclose, blow = c[b], l[b]
        info = {"symbol": sym, "breakout_week": str(w.Date.iat[b].date()), "breakout_close": round(bclose, 2),
                "breakout_week_move_pct": round(w.ret.iat[b], 1), "breakout_vol_x": round(w.vx.iat[b], 1),
                "stop": round(blow, 2)}
        k = b + CONFIRM_WEEKS
        if k > n:   # confirmation chal raha hai
            done = n - b
            ups = int(sum(c[j] > c[j - 1] for j in range(b + 1, n + 1)))
            dd = (min(l[b + 1:n + 1]) / bclose - 1) * 100 if done else 0
            alive = (dd >= -CONFIRM_MAX_DD) and (c[n] >= blow)
            state = {"stage": "BREAKOUT" if alive else "FAILED", **info, "weeks_done": done,
                     "weeks_left": CONFIRM_WEEKS - done, "up_weeks_so_far": ups,
                     "max_dip_pct": round(dd, 1), "move_since_pct": round((c[n] / bclose - 1) * 100, 1)}
            break
        ups = int(sum(c[j] > c[j - 1] for j in range(b + 1, k + 1)))
        dd = (min(l[b + 1:k + 1]) / bclose - 1) * 100
        ok = c[k] > bclose and ups >= CONFIRM_MIN_UP and dd >= -CONFIRM_MAX_DD and min(c[b + 1:k + 1]) >= blow
        if not ok:
            if k == n:
                state = {"stage": "FAILED", **info, "reason": "3-hafte confirmation fail"}
            i = b + 1
            continue
        entry = c[k]
        risk = entry - blow
        j, exit_px, how = k + 1, None, None
        while j <= n:
            if c[j] < blow:
                exit_px, how = c[j], "STOP"; break
            if c[j] < ma30[j]:
                exit_px, how = c[j], "30wMA"; break
            j += 1
        t = {**info, "entry_week": str(w.Date.iat[k].date()), "entry": round(entry, 2),
             "risk_pct": round(risk / entry * 100, 1),
             "qty_1pct_risk": int(CAPITAL * RISK_PCT / 100 / risk) if risk > 0 else 0}
        if exit_px is None:
            t.update(status="OPEN", current=round(c[n], 2), pnl_pct=round((c[n] / entry - 1) * 100, 1),
                     weeks_held=n - k, trail_exit_below_30wMA=round(ma30[n], 2))
            trades.append(t)
            state = {"stage": "CONFIRMED" if k == n else "IN_TRADE", **t}
            break
        t.update(status=how, exit_week=str(w.Date.iat[j].date()), exit=round(exit_px, 2),
                 pnl_pct=round((exit_px / entry - 1) * 100, 1), weeks_held=j - k)
        trades.append(t)
        i = j + 1
    if state["stage"] == "NONE":
        if w.setup.iat[n]:
            state = {"stage": "SETUP", "symbol": sym, "close": round(c[n], 2),
                     "breakout_level": round(w.hh.iat[n], 2),
                     "distance_pct": round((w.hh.iat[n] / c[n] - 1) * 100, 1),
                     "updown_vol": round(w.udv.iat[n], 2)}
        elif w.hot_breakout.iat[n]:
            state = {"stage": "HOT_BREAKOUT", "symbol": sym, "week_move_pct": round(w.ret.iat[n], 1),
                     "note": "Breakout hafta 15% se zyada - rule isse skip karta hai (risky)"}
    state.setdefault("symbol", sym)
    state["last_week"] = str(w.Date.iat[n].date())
    state["last_close"] = round(c[n], 2)
    return trades, state


def stats(trades):
    closed = [t for t in trades if t["status"] != "OPEN"]
    if not closed:
        return {"closed": 0, "open": len(trades)}
    p = np.array([t["pnl_pct"] for t in closed])
    w, lo = p[p > 0], p[p <= 0]
    return {"closed": len(closed), "open": len(trades) - len(closed),
            "win_rate_pct": round(len(w) / len(p) * 100, 1),
            "avg_pct": round(p.mean(), 1), "median_pct": round(float(np.median(p)), 1),
            "avg_win_pct": round(w.mean(), 1) if len(w) else 0,
            "avg_loss_pct": round(lo.mean(), 1) if len(lo) else 0,
            "best_pct": round(p.max(), 1), "worst_pct": round(p.min(), 1),
            "stops_hit": sum(t["status"] == "STOP" for t in closed),
            "avg_weeks_held": round(np.mean([t["weeks_held"] for t in closed]), 1)}


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else LOCAL_INPUT_FILE
    data = load_data(path)
    all_trades, states, partial_any = [], [], False
    for sym in sorted(data):
        try:
            w, partial = to_weekly(data[sym])
        except Exception as e:
            print(f"⚠️ {sym}: {e}"); continue
        if len(w) < 40:
            print(f"⚠️ {sym}: sirf {len(w)} hafte ka data, skip"); continue
        partial_any |= partial
        tr, st = run_symbol(sym, w)
        all_trades += tr
        states.append(st)

    order = {"CONFIRMED": 0, "BREAKOUT": 1, "SETUP": 2, "IN_TRADE": 3, "HOT_BREAKOUT": 4, "FAILED": 5, "NONE": 6}
    states.sort(key=lambda s: order.get(s["stage"], 9))
    S = stats(all_trades)

    print("\n" + "=" * 90)
    print("📈 WEEKLY RALLY SCANNER  —  Quiet Breakout + 3-Week Confirmation")
    if partial_any:
        print("⚠️  Aakhri hafte mein Friday ka data nahi (holiday tha to ignore karein) - warna signal Friday close ke baad hi maanein")
    print("=" * 90)
    for s in states:
        st = s["stage"]
        if st == "CONFIRMED":
            print(f"✅ CONFIRMED  {s['symbol']:<12} ENTRY ₹{s['entry']}  STOP ₹{s['stop']} ({s['risk_pct']}%)  Qty(1% risk) {s['qty_1pct_risk']}")
        elif st == "BREAKOUT":
            print(f"🔔 BREAKOUT   {s['symbol']:<12} week {s['breakout_week']} (+{s['breakout_week_move_pct']}%, {s['breakout_vol_x']}x vol) "
                  f"| {s['weeks_left']} hafte baaki | green {s['up_weeks_so_far']} | dip {s['max_dip_pct']}%")
        elif st == "SETUP":
            print(f"👀 SETUP      {s['symbol']:<12} close ₹{s['close']}  breakout level ₹{s['breakout_level']} ({s['distance_pct']}% door)  U/D vol {s['updown_vol']}")
        elif st == "IN_TRADE":
            print(f"📊 IN TRADE   {s['symbol']:<12} entry {s['entry_week']} ₹{s['entry']} -> ₹{s['current']} ({s['pnl_pct']:+}%)  exit if close < ₹{s['trail_exit_below_30wMA']}")
        elif st == "HOT_BREAKOUT":
            print(f"🔥 HOT        {s['symbol']:<12} hafta +{s['week_move_pct']}% - skip (overheated)")
        elif st == "FAILED":
            print(f"❌ FAILED     {s['symbol']:<12} breakout {s.get('breakout_week')} confirm nahi hua")
        else:
            print(f"   —          {s['symbol']:<12} ₹{s['last_close']}")
    print("-" * 90)
    if S.get("closed"):
        print(f"📊 BACKTEST: {S['closed']} closed trades | Win {S['win_rate_pct']}% | Avg {S['avg_pct']:+}% | Median {S['median_pct']:+}% "
              f"| Avg W {S['avg_win_pct']:+}% / L {S['avg_loss_pct']:+}% | Stops {S['stops_hit']} | Avg hold {S['avg_weeks_held']} wk")
    else:
        print("📊 BACKTEST: koi closed trade nahi")
    print(f"   Open trades: {S.get('open', 0)}")

    out = {"generated_at": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
           "rule": "Weekly Quiet Breakout + 3-Week Confirmation",
           "settings": {"lookback_weeks": BREAKOUT_LOOKBACK, "vol_mult": VOL_MULT, "max_breakout_week_pct": MAX_BREAKOUT_WEEK,
                        "confirm_weeks": CONFIRM_WEEKS, "confirm_min_up": CONFIRM_MIN_UP, "confirm_max_dd_pct": CONFIRM_MAX_DD,
                        "setup_near_high_pct": SETUP_NEAR_HIGH},
           "last_week_partial": partial_any,
           "backtest_stats": S,
           "current_status": states,
           "confirmed_now": [s for s in states if s["stage"] == "CONFIRMED"],
           "breakout_watch": [s for s in states if s["stage"] == "BREAKOUT"],
           "setup_watchlist": [s for s in states if s["stage"] == "SETUP"],
           "all_trades": sorted(all_trades, key=lambda t: t["entry_week"], reverse=True)}
    with open(OUTPUT_JSON_FILE, "w", encoding="utf-8") as f:
        json.dump(out, f, indent=2, ensure_ascii=False, default=str)
    print(f"📁 Saved: {OUTPUT_JSON_FILE}")


if __name__ == "__main__":
    main()
