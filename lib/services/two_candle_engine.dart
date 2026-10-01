import 'dart:math';
import '../models/backtest_candle.dart';
import '../models/backtest_engine.dart';
import '../models/two_candle_rule_model.dart';

class TwoCandleEngine {
  static BacktestSummary run({
    required List<BacktestCandle> candles,
    required TwoCandleStrategyConfig config,
    double initialCapital = 100000,
  }) {
    if (candles.length < 10) {
      return BacktestSummary(
        totalTrades: 0,
        winningTrades: 0,
        losingTrades: 0,
        winRate: 0,
        totalPnlPercent: 0,
        maxDrawdownPercent: 0,
        profitFactor: 0,
        trades: [],
      );
    }

    List<TradeLog> trades = [];
    double currentCapital = initialCapital;
    double peakCapital = initialCapital;
    double maxDD = 0.0;
    double grossProfit = 0.0;
    double grossLoss = 0.0;
    int inTradeUntil = -1;

    for (int i = 2; i < candles.length - 2; i++) {
      if (i <= inTradeUntil) continue;

      // 1. Check if Candle 1 & Candle 2 match setup
      if (config.matches(candles, i)) {
        final c1 = candles[i - 1];
        final c2 = candles[i];
        final nextBar = candles[i + 1];

        double entryPrice = 0.0;
        bool entryTriggered = false;

        // 2. Entry validation
        if (config.entryTrigger == EntryTriggerType.breakoutCandle2High) {
          if (nextBar.high >= c2.high) {
            entryPrice = max(nextBar.open, c2.high);
            entryTriggered = true;
          }
        } else if (config.entryTrigger == EntryTriggerType.nextBarOpen) {
          entryPrice = nextBar.open;
          entryTriggered = true;
        } else if (config.entryTrigger == EntryTriggerType.closeOfCandle2) {
          entryPrice = c2.close;
          entryTriggered = true;
        }

        if (!entryTriggered) continue;

        // 3. Stop loss & target calculation
        final slPrice = config.getStopLoss(c1, c2);
        final risk = (entryPrice - slPrice).abs();
        if (risk <= 0 || risk > (entryPrice * 0.08)) continue;

        final targetPrice = entryPrice + (risk * config.riskRewardRatio);
        bool closed = false;
        int exitIdx = i + 1;

        // 4. Forward bar simulation
        for (int j = i + 1; j < min(i + config.maxHoldingBars, candles.length); j++) {
          final bar = candles[j];

          // Check Stop Loss
          if (bar.low <= slPrice) {
            final pnlPct = -((entryPrice - slPrice) / entryPrice) * 100;
            final pnlAmt = currentCapital * (pnlPct / 100);
            currentCapital += pnlAmt;
            grossLoss += pnlAmt.abs();

            trades.add(TradeLog(
              entryDate: nextBar.date,
              exitDate: bar.date,
              entryPrice: entryPrice,
              exitPrice: slPrice,
              isWin: false,
              pnlPercent: pnlPct,
              pnlAmount: pnlAmt,
              exitReason: 'STOP LOSS HIT',
            ));
            exitIdx = j;
            closed = true;
            break;
          }

          // Check Target
          if (bar.high >= targetPrice) {
            final pnlPct = ((targetPrice - entryPrice) / entryPrice) * 100;
            final pnlAmt = currentCapital * (pnlPct / 100);
            currentCapital += pnlAmt;
            grossProfit += pnlAmt;

            trades.add(TradeLog(
              entryDate: nextBar.date,
              exitDate: bar.date,
              entryPrice: entryPrice,
              exitPrice: targetPrice,
              isWin: true,
              pnlPercent: pnlPct,
              pnlAmount: pnlAmt,
              exitReason: 'TARGET (1:${config.riskRewardRatio.toStringAsFixed(1)})',
            ));
            exitIdx = j;
            closed = true;
            break;
          }
        }

        // Holding timeout exit
        if (!closed && (i + config.maxHoldingBars) < candles.length) {
          final exitBar = candles[i + config.maxHoldingBars];
          final pnlPct = ((exitBar.close - entryPrice) / entryPrice) * 100;
          final pnlAmt = currentCapital * (pnlPct / 100);
          currentCapital += pnlAmt;
          if (pnlAmt >= 0) grossProfit += pnlAmt; else grossLoss += pnlAmt.abs();

          trades.add(TradeLog(
            entryDate: nextBar.date,
            exitDate: exitBar.date,
            entryPrice: entryPrice,
            exitPrice: exitBar.close,
            isWin: pnlPct > 0,
            pnlPercent: pnlPct,
            pnlAmount: pnlAmt,
            exitReason: 'TIMEOUT EXIT',
          ));
          exitIdx = i + config.maxHoldingBars;
          closed = true;
        }

        if (currentCapital > peakCapital) peakCapital = currentCapital;
        final dd = ((peakCapital - currentCapital) / peakCapital) * 100;
        if (dd > maxDD) maxDD = dd;
        if (closed) inTradeUntil = exitIdx;
      }
    }

    final winCount = trades.where((t) => t.isWin).length;
    final totalReturn = ((currentCapital - initialCapital) / initialCapital) * 100;

    return BacktestSummary(
      totalTrades: trades.length,
      winningTrades: winCount,
      losingTrades: trades.length - winCount,
      winRate: trades.isEmpty ? 0.0 : (winCount / trades.length) * 100,
      totalPnlPercent: totalReturn,
      maxDrawdownPercent: maxDD,
      profitFactor: grossLoss == 0 ? (grossProfit > 0 ? 99.0 : 0.0) : (grossProfit / grossLoss),
      trades: trades.reversed.toList(),
    );
  }
}
