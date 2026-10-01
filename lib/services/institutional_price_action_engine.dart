import 'dart:math';
import '../models/backtest_candle.dart';

enum PriceActionPattern {
  liquiditySweepReclaim,
  openingRangeBreakout,
  insideBarBreakout,
  pinBarRejection,
}

class BacktestTradeResult {
  final DateTime entryTime;
  final DateTime exitTime;
  final String side; // LONG or SHORT
  final double entryPrice;
  final double exitPrice;
  final double stopLoss;
  final double targetPrice;
  final double pnlPercent;
  final bool isWin;
  final String exitReason;

  BacktestTradeResult({
    required this.entryTime,
    required this.exitTime,
    required this.side,
    required this.entryPrice,
    required this.exitPrice,
    required this.stopLoss,
    required this.targetPrice,
    required this.pnlPercent,
    required this.isWin,
    required this.exitReason,
  });
}

class BacktestSummary {
  final int totalTrades;
  final int winningTrades;
  final int losingTrades;
  final double winRate;
  final double totalReturnPercent;
  final double maxDrawdownPercent;
  final double profitFactor;
  final List<BacktestTradeResult> trades;

  BacktestSummary({
    required this.totalTrades,
    required this.winningTrades,
    required this.losingTrades,
    required this.winRate,
    required this.totalReturnPercent,
    required this.maxDrawdownPercent,
    required this.profitFactor,
    required this.trades,
  });
}

class InstitutionalPriceActionEngine {
  static BacktestSummary run({
    required List<BacktestCandle> candles,
    required PriceActionPattern pattern,
    required double targetRatio, // e.g. 2.0 (1:2 R:R)
    required double minVolumeMultiplier, // e.g. 1.5x of 20-MA
    bool allowShort = false, // Cash equity ke liye Long-only default
    int maxHoldingBars = 30,
  }) {
    if (candles.length < 35) {
      return BacktestSummary(
        totalTrades: 0,
        winningTrades: 0,
        losingTrades: 0,
        winRate: 0,
        totalReturnPercent: 0,
        maxDrawdownPercent: 0,
        profitFactor: 0,
        trades: [],
      );
    }

    final List<BacktestTradeResult> trades = [];
    int inTradeUntilIndex = -1;

    double capital = 100000;
    double currentCapital = capital;
    double peakCapital = capital;
    double maxDrawdown = 0.0;
    double grossProfit = 0.0;
    double grossLoss = 0.0;

    for (int i = 20; i < candles.length - 2; i++) {
      if (i <= inTradeUntilIndex) continue;

      final current = candles[i];
      final prev = candles[i - 1];

      // 1. Math Properties
      final double range = current.high - current.low;
      final double body = (current.close - current.open).abs();
      final double upperWick = current.high - max(current.open, current.close);
      final double lowerWick = min(current.open, current.close) - current.low;
      final bool isBullish = current.close > current.open;

      // 2. Volume Surge Filter
      double volSum = 0;
      for (int v = i - 20; v < i; v++) {
        volSum += candles[v].volume;
      }
      final double volMA = volSum / 20;
      final bool hasVolumeSurge = current.volume >= (volMA * minVolumeMultiplier);

      bool triggerLong = false;
      bool triggerShort = false;
      double slPrice = 0.0;

      // 3. Pattern Recognition Logic
      switch (pattern) {
        case PriceActionPattern.liquiditySweepReclaim:
          final double prevSwingHigh = candles.sublist(i - 10, i).map((c) => c.high).reduce(max);
          final double prevSwingLow = candles.sublist(i - 10, i).map((c) => c.low).reduce(min);

          // Bullish Sweep: Low swept liquidity, closed higher with >50% wick
          if (current.low < prevSwingLow && current.close > prevSwingLow) {
            if (range > 0 && (lowerWick / range) >= 0.50) {
              triggerLong = true;
              slPrice = current.low - (range * 0.1);
            }
          }
          // Bearish Sweep
          else if (allowShort && current.high > prevSwingHigh && current.close < prevSwingHigh) {
            if (range > 0 && (upperWick / range) >= 0.50) {
              triggerShort = true;
              slPrice = current.high + (range * 0.1);
            }
          }
          break;

        case PriceActionPattern.openingRangeBreakout:
          if (hasVolumeSurge && range > 0 && (body / range) >= 0.55) {
            if (isBullish && current.close > prev.high) {
              triggerLong = true;
              slPrice = current.low;
            } else if (allowShort && !isBullish && current.close < prev.low) {
              triggerShort = true;
              slPrice = current.high;
            }
          }
          break;

        case PriceActionPattern.insideBarBreakout:
          final bool isInside = current.high <= prev.high && current.low >= prev.low;
          if (isInside && i + 1 < candles.length) {
            final breakoutBar = candles[i + 1];
            if (breakoutBar.close > prev.high) {
              triggerLong = true;
              slPrice = prev.low;
              i++;
            } else if (allowShort && breakoutBar.close < prev.low) {
              triggerShort = true;
              slPrice = prev.high;
              i++;
            }
          }
          break;

        case PriceActionPattern.pinBarRejection:
          if (range > 0) {
            if ((lowerWick / range) >= 0.55 && isBullish) {
              triggerLong = true;
              slPrice = current.low - (range * 0.05);
            } else if (allowShort && (upperWick / range) >= 0.55 && !isBullish) {
              triggerShort = true;
              slPrice = current.high + (range * 0.05);
            }
          }
          break;
      }

      // 4. Trade Execution Simulation
      if (triggerLong && slPrice > 0) {
        final double entry = current.close;
        final double risk = (entry - slPrice).abs();
        if (risk <= 0 || risk > (entry * 0.06)) continue; // 6% se bada structural risk reject karein

        final double target = entry + (risk * targetRatio);
        bool tradeClosed = false;

        for (int f = i + 1; f < min(i + maxHoldingBars, candles.length); f++) {
          final bar = candles[f];

          // Check SL
          if (bar.low <= slPrice) {
            final pnlPct = -((entry - slPrice) / entry) * 100;
            final pnlAmt = currentCapital * (pnlPct / 100);
            currentCapital += pnlAmt;
            grossLoss += pnlAmt.abs();

            trades.add(BacktestTradeResult(
              entryTime: current.date,
              exitTime: bar.date,
              side: 'LONG',
              entryPrice: entry,
              exitPrice: slPrice,
              stopLoss: slPrice,
              targetPrice: target,
              pnlPercent: pnlPct,
              isWin: false,
              exitReason: 'STOP LOSS',
            ));
            inTradeUntilIndex = f;
            tradeClosed = true;
            break;
          }

          // Check Target
          if (bar.high >= target) {
            final pnlPct = ((target - entry) / entry) * 100;
            final pnlAmt = currentCapital * (pnlPct / 100);
            currentCapital += pnlAmt;
            grossProfit += pnlAmt;

            trades.add(BacktestTradeResult(
              entryTime: current.date,
              exitTime: bar.date,
              side: 'LONG',
              entryPrice: entry,
              exitPrice: target,
              stopLoss: slPrice,
              targetPrice: target,
              pnlPercent: pnlPct,
              isWin: true,
              exitReason: 'TARGET (1:${targetRatio.toStringAsFixed(1)})',
            ));
            inTradeUntilIndex = f;
            tradeClosed = true;
            break;
          }
        }

        // Timeout Exit agar 30 bars tak SL ya Target na aaye
        if (!tradeClosed && (i + maxHoldingBars) < candles.length) {
          final exitBar = candles[i + maxHoldingBars];
          final pnlPct = ((exitBar.close - entry) / entry) * 100;
          final pnlAmt = currentCapital * (pnlPct / 100);
          currentCapital += pnlAmt;
          if (pnlAmt >= 0) grossProfit += pnlAmt; else grossLoss += pnlAmt.abs();

          trades.add(BacktestTradeResult(
            entryTime: current.date,
            exitTime: exitBar.date,
            side: 'LONG',
            entryPrice: entry,
            exitPrice: exitBar.close,
            stopLoss: slPrice,
            targetPrice: target,
            pnlPercent: pnlPct,
            isWin: pnlPct > 0,
            exitReason: 'TIME DECAY EXIT',
          ));
          inTradeUntilIndex = i + maxHoldingBars;
        }

        // Drawdown update
        if (currentCapital > peakCapital) peakCapital = currentCapital;
        final dd = ((peakCapital - currentCapital) / peakCapital) * 100;
        if (dd > maxDrawdown) maxDrawdown = dd;
      }
    }

    final winCount = trades.where((t) => t.isWin).length;
    final lossCount = trades.length - winCount;
    final winRate = trades.isEmpty ? 0.0 : (winCount / trades.length) * 100;
    final totalReturn = ((currentCapital - capital) / capital) * 100;
    final profitFactor = grossLoss == 0 ? (grossProfit > 0 ? 99.0 : 0.0) : (grossProfit / grossLoss);

    return BacktestSummary(
      totalTrades: trades.length,
      winningTrades: winCount,
      losingTrades: lossCount,
      winRate: winRate,
      totalReturnPercent: totalReturn,
      maxDrawdownPercent: maxDrawdown,
      profitFactor: profitFactor,
      trades: trades.reversed.toList(),
    );
  }
}
