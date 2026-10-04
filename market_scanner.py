
Volume Breakout v2 - 5 Year Scanner + Backtest
================================================
Input : historical_5yr_ohlc.json  ->  {"SYMBOL": [[date, open, high, low, close, volume], ...]}
Output: breakout_signals.json  (signals + trade result + stats + today's status)

ENTRY (sab 6 ek hi din TRUE):
  1. Day move >= +3%
  2. Volume >= 3x (pichhle 20 din ka average, aaj ko chhod kar)
  3. Close >= 20DMA + 3%
  4. RSI(14) > 50          (Wilder RSI - TradingView/Zerodha jaisa)
  5. Close > pichhle 20 din ka highest High
  6. Close > 50DMA
  + 10-session cooldown (repeat signal ignore)

TRADE:
  Entry = signal din ka close
  SL    = signal din ka Low  -> exit sirf jab kisi din CLOSE iske neeche aaye (closing basis)
  Exit  = SL nahi laga to 20 sessions baad ka close
"""
import json
import os
from datetime import datetime

LOCAL_INPUT_FILE = "historical_5yr_ohlc.json"
RAW_GITHUB_URL = "https://raw.githubusercontent.com/zxcty54/stock-crypto-tracker/main/historical_5yr_ohlc.json"
OUTPUT_JSON_FILE = "breakout_signals.json"

# ---------------- RULE SETTINGS ----------------
DAY_MOVE_MIN = 3.0      # %
VOL_MULT = 3.0          # x of 20-day avg
DMA20_GAP = 3.0         # % above 20DMA
RSI_MIN = 50.0
COOLDOWN_DAYS = 10      # sessions
HOLD_DAYS = 20          # max holding sessions
RISK_PER_TRADE_PCT = 1.0  # position sizing: capital ka kitna % risk
CAPITAL = 500000        # sirf quantity example ke liye
BAD_JUMP_PCT = 25.0     # ek din mein itna move = split/bonus/data error warning


# ---------------- DATA ----------------
def parse_date(s):
    for fmt in ("%Y-%m-%d", "%d-%b-%Y", "%d-%m-%Y"):
        try:
            return datetime.strptime(str(s)[:11].strip(), fmt)
        except ValueError:
            continue
    return None


def load_historical_data():
    if os.path.exists(LOCAL_INPUT_FILE):
        print(f"ðŸ“‚ Local file load: {LOCAL_INPUT_FILE}")
        try:
            with open(LOCAL_INPUT_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception as e:
            print(f"âŒ Local file error: {e}")
    print("ðŸŒ GitHub se fetch ho raha hai...")
    try:
        import requests
        r = requests.get(RAW_GITHUB_URL, timeout=60)
        if r.status_code == 200:
            return r.json()
        print(f"âŒ HTTP {r.status_code}")
    except Exception as e:
        print(f"âŒ Fetch error: {e}")
    return None


def clean_records(raw):
    """Sort, duplicate date hatao, zero/blank rows hatao."""
    seen, rows = set(), []
    for r in raw:
        try:
            dt = parse_date(r[0])
            o, h, l, c, v = (float(x) for x in r[1:6])
        except (TypeError, ValueError, IndexError):
            continue
        if dt is None or dt in seen or c <= 0 or h <= 0 or l <= 0:
            continue
        seen.add(dt)
        rows.append((dt, o, h, l, c, v))
    rows.sort(key=lambda x: x[0])
    return rows


# ---------------- INDICATORS ----------------
def sma(values, n):
    out, s = [None] * len(values), 0.0
    for i, x in enumerate(values):
        s += x
        if i >= n:
            s -= values[i - n]
        if i >= n - 1:
            out[i] = s / n
    return out


def wilder_rsi(closes, period=14):
    out = [None] * len(closes)
    if len(closes) <= period:
        return out
    gains = losses = 0.0
    for i in range(1, period + 1):
        d = closes[i] - closes[i - 1]
        gains += max(d, 0)
        losses += max(-d, 0)
    ag, al = gains / period, losses / period
    out[period] = 100.0 if al == 0 else 100 - 100 / (1 + ag / al)
    for i in range(period + 1, len(closes)):
        d = closes[i] - closes[i - 1]
        ag = (ag * (period - 1) + max(d, 0)) / period
        al = (al * (period - 1) + max(-d, 0)) / period
        out[i] = 100.0 if al == 0 else 100 - 100 / (1 + ag / al)
    return out


# ---------------- SCAN ONE STOCK ----------------
def scan_symbol(symbol, rows):
    dates = [r[0] for r in rows]
    O = [r[1] for r in rows]; H = [r[2] for r in rows]
    L = [r[3] for r in rows]; C = [r[4] for r in rows]; V = [r[5] for r in rows]
    n = len(rows)
    dma20, dma50, rsi = sma(C, 20), sma(C, 50), wilder_rsi(C)

    # data quality warnings
    warnings = []
    for i in range(1, n):
        mv = (C[i] / C[i - 1] - 1) * 100
        if abs(mv) >= BAD_JUMP_PCT:
            warnings.append(f"{dates[i].date()}: {mv:+.1f}% ek din mein - split/bonus/data error check karein")

    def conditions(i):
        prev20 = range(i - 20, i)
        avg_vol = sum(V[j] for j in prev20) / 20
        high20 = max(H[j] for j in prev20)
        move = (C[i] / C[i - 1] - 1) * 100
        vr = V[i] / avg_vol if avg_vol > 0 else 0
        c = {
            "day_move": move >= DAY_MOVE_MIN,
            "volume_3x": vr >= VOL_MULT,
            "above_20dma_3pct": C[i] >= dma20[i] * (1 + DMA20_GAP / 100),
            "rsi_above_50": rsi[i] is not None and rsi[i] > RSI_MIN,
            "breakout_20d_high": C[i] > high20,
            "above_50dma": C[i] > dma50[i],
        }
        info = {"day_move_pct": round(move, 2), "volume_ratio": round(vr, 2),
                "rsi_14": round(rsi[i], 1) if rsi[i] else None,
                "dma_20": round(dma20[i], 2), "dma_50": round(dma50[i], 2),
                "high_20d": round(high20, 2)}
        return c, info

    trades, last_sig = [], -999
    for i in range(50, n):
        cond, info = conditions(i)
        if not all(cond.values()):
            continue
        if i - last_sig <= COOLDOWN_DAYS:
            continue
        last_sig = i

        entry, sl = C[i], L[i]
        risk_pct = (entry - sl) / entry * 100
        last_idx = min(i + HOLD_DAYS, n - 1)
        exit_idx, exit_px, status = None, None, None
        for j in range(i + 1, last_idx + 1):
            if C[j] < sl:
                exit_idx, exit_px, status = j, C[j], "SL_HIT"
                break
        if exit_idx is None:
            exit_idx, exit_px = last_idx, C[last_idx]
            status = "TIME_EXIT_20D" if i + HOLD_DAYS <= n - 1 else "OPEN"
        window = range(i + 1, exit_idx + 1)
        max_up = (max(H[j] for j in window) / entry - 1) * 100 if exit_idx > i else 0.0
        max_dn = (min(L[j] for j in window) / entry - 1) * 100 if exit_idx > i else 0.0
        qty = int((CAPITAL * RISK_PER_TRADE_PCT / 100) / (entry - sl)) if entry > sl else 0

        trades.append({
            "symbol": symbol,
            "entry_date": str(dates[i].date()),
            "entry_price": round(entry, 2),
            "stop_loss": round(sl, 2),
            "risk_pct": round(risk_pct, 2),
            "qty_for_1pct_risk": qty,
            **info,
            "extension_above_breakout_pct": round((entry / info["high_20d"] - 1) * 100, 2),
            "status": status,
            "exit_date": str(dates[exit_idx].date()),
            "exit_price": round(exit_px, 2),
            "pnl_pct": round((exit_px / entry - 1) * 100, 2),
            "r_multiple": round((exit_px - entry) / (entry - sl), 2) if entry > sl else None,
            "days_held": exit_idx - i,
            "max_gain_pct": round(max_up, 2),
            "max_drawdown_pct": round(max_dn, 2),
        })

    # today's status
    cond, info = conditions(n - 1)
    met = sum(cond.values())
    trig = all(cond.values()) and (n - 1 - last_sig > COOLDOWN_DAYS or last_sig == n - 1)
    today = {"date": str(dates[-1].date()), "close": round(C[-1], 2), **info,
             "conditions_met": f"{met}/6",
             "missing": [k for k, v in cond.items() if not v],
             "TRIGGER_TODAY": bool(trig and last_sig == n - 1)}
    return trades, today, warnings


# ---------------- STATS ----------------
def stats(trades):
    closed = [t for t in trades if t["status"] != "OPEN"]
    if not closed:
        return {"closed_trades": 0}
    wins = [t["pnl_pct"] for t in closed if t["pnl_pct"] > 0]
    losses = [t["pnl_pct"] for t in closed if t["pnl_pct"] <= 0]
    gross_l = -sum(losses)
    rs = [t["r_multiple"] for t in closed if t["r_multiple"] is not None]
    return {
        "closed_trades": len(closed),
        "open_trades": len(trades) - len(closed),
        "wins": len(wins), "losses": len(losses),
        "win_rate_pct": round(len(wins) / len(closed) * 100, 1),
        "sl_hit": sum(t["status"] == "SL_HIT" for t in closed),
        "avg_win_pct": round(sum(wins) / len(wins), 2) if wins else 0,
        "avg_loss_pct": round(sum(losses) / len(losses), 2) if losses else 0,
        "expectancy_pct_per_trade": round(sum(t["pnl_pct"] for t in closed) / len(closed), 2),
        "avg_R": round(sum(rs) / len(rs), 2) if rs else None,
        "profit_factor": round(sum(wins) / gross_l, 2) if gross_l > 0 else None,
        "best_pct": max(t["pnl_pct"] for t in closed),
        "worst_pct": min(t["pnl_pct"] for t in closed),
    }


def verdict(s):
    if not s.get("closed_trades"):
        return "Koi closed trade nahi"
    if s["closed_trades"] < 10:
        return "Sample chhota (<10 trades) - pakka nateeja nahi"
    e = s["expectancy_pct_per_trade"]
    if e >= 3:
        return "Rule is stock par kaam karta hai"
    if e > 0:
        return "Halka edge - cost ke baad marginal"
    return "Rule is stock par kaam NAHI karta"


# ---------------- MAIN ----------------
def main():
    data = load_historical_data()
    if not data:
        print("âŒ Data load nahi hua."); return

    all_trades, companies = [], {}
    print(f"\nðŸš€ Scanning {len(data)} stocks...\n" + "=" * 95)
    print(f"{'SYMBOL':<12}{'SIG':>4}{'WIN%':>7}{'SL':>4}{'AVG W':>8}{'AVG L':>8}{'EXP/TR':>8}{'PF':>6}   TODAY")
    for symbol in sorted(data):
        rows = clean_records(data[symbol] or [])
        if len(rows) < 71:
            print(f"{symbol:<12} âš ï¸ data kam ({len(rows)} rows), skip"); continue
        trades, today, warns = scan_symbol(symbol, rows)
        s = stats(trades)
        all_trades += trades
        companies[symbol] = {"stats": s, "verdict": verdict(s), "today": today,
                             "data_warnings": warns, "trades": trades}
        tflag = "ðŸ”” TRIGGER" if today["TRIGGER_TODAY"] else today["conditions_met"]
        if s.get("closed_trades"):
            print(f"{symbol:<12}{len(trades):>4}{s['win_rate_pct']:>6.0f}%{s['sl_hit']:>4}"
                  f"{s['avg_win_pct']:>+8.1f}{s['avg_loss_pct']:>+8.1f}{s['expectancy_pct_per_trade']:>+8.1f}"
                  f"{(s['profit_factor'] or 0):>6.1f}   {tflag}")
        else:
            print(f"{symbol:<12}{len(trades):>4}{'-':>7}   {tflag}")
        for w in warns:
            print(f"   âš ï¸ {w}")

    all_trades.sort(key=lambda t: t["entry_date"], reverse=True)
    overall = stats(all_trades)
    triggers_today = [{"symbol": k, **v["today"]} for k, v in companies.items() if v["today"]["TRIGGER_TODAY"]]
    open_trades = [t for t in all_trades if t["status"] == "OPEN"]

    print("=" * 95)
    if overall.get("closed_trades"):
        o = overall
        print(f"ðŸ“Š OVERALL: {o['closed_trades']} closed | Win {o['win_rate_pct']}% | SL hit {o['sl_hit']} | "
              f"Avg win {o['avg_win_pct']:+.2f}% | Avg loss {o['avg_loss_pct']:+.2f}%")
        print(f"   Expectancy {o['expectancy_pct_per_trade']:+.2f}%/trade | Avg R {o['avg_R']} | "
              f"PF {o['profit_factor']} | Best {o['best_pct']:+.1f}% | Worst {o['worst_pct']:+.1f}%")
        print(f"   Verdict: {verdict(o)}")
    print(f"ðŸ”” Aaj ke triggers: {', '.join(t['symbol'] for t in triggers_today) or 'koi nahi'}")
    ot = ", ".join("%s %s (%+.1f%%)" % (t["symbol"], t["entry_date"], t["pnl_pct"]) for t in open_trades)
    print("ðŸ“‚ Open trades: " + (ot or "koi nahi"))

    payload = {
        "metadata": {
            "generated_at": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "rule": "Volume Breakout v2",
            "settings": {"day_move_min": DAY_MOVE_MIN, "vol_mult": VOL_MULT, "dma20_gap": DMA20_GAP,
                         "rsi_min": RSI_MIN, "rsi_type": "Wilder", "cooldown": COOLDOWN_DAYS,
                         "hold_days": HOLD_DAYS, "stop": "close below signal-day low"},
            "stocks_scanned": len(companies),
            "total_signals": len(all_trades),
        },
        "overall_stats": overall,
        "overall_verdict": verdict(overall),
        "triggers_today": triggers_today,
        "open_trades": open_trades,
        "latest_signals": all_trades[:20],
        "all_signals_chronological": all_trades,
        "companies": companies,
    }
    with open(OUTPUT_JSON_FILE, "w", encoding="utf-8") as f:
        json.dump(payload, f, indent=2, ensure_ascii=False)
    print(f"ðŸ“ Saved: {OUTPUT_JSON_FILE}")


if __name__ == "__main__":
    main()