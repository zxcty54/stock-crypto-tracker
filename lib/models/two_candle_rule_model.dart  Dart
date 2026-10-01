import 'dart:math';
import '../models/backtest_candle.dart';

enum CandleColorType { any, bullishGreen, bearishRed }
enum WickBiasType { any, longLowerWick, longUpperWick }
enum InterCandleRelation {
  any,
  higherHigh,
  higherClose,
  breakoutAboveHigh,
  insideBar,
  bullishEngulfing,
}
enum EntryTriggerType {
  breakoutCandle2High,
  closeOfCandle2,
  nextBarOpen,
}
enum StructuralStopLossType {
  candle2Low,
  candle1Low,
  lowestOfBoth,
}

class TwoCandleStrategyConfig {
  CandleColorType candle1Color;
  WickBiasType candle1Wick;
  CandleColorType candle2Color;
  WickBiasType candle2Wick;
  InterCandleRelation relation;
  EntryTriggerType entryTrigger;
  StructuralStopLossType slType;
  double riskRewardRatio;
  int maxHoldingBars;

  TwoCandleStrategyConfig({
    this.candle1Color = CandleColorType.bullishGreen,
    this.candle1Wick = WickBiasType.any,
    this.candle2Color = CandleColorType.bullishGreen,
    this.candle2Wick = WickBiasType.any,
    this.relation = InterCandleRelation.higherHigh,
    this.entryTrigger = EntryTriggerType.breakoutCandle2High,
    this.slType = StructuralStopLossType.lowestOfBoth,
    this.riskRewardRatio = 2.0,
    this.maxHoldingBars = 25,
  });

  bool matches(List<BacktestCandle> candles, int i) {
    if (i < 2) return false;

    final c1 = candles[i - 1];
    final c2 = candles[i];

    if (candle1Color == CandleColorType.bullishGreen && c1.close <= c1.open) return false;
    if (candle1Color == CandleColorType.bearishRed && c1.close >= c1.open) return false;

    final range1 = c1.high - c1.low;
    if (range1 > 0) {
      final lowerWick1 = min(c1.open, c1.close) - c1.low;
      final upperWick1 = c1.high - max(c1.open, c1.close);
      if (candle1Wick == WickBiasType.longLowerWick && (lowerWick1 / range1) < 0.50) return false;
      if (candle1Wick == WickBiasType.longUpperWick && (upperWick1 / range1) < 0.50) return false;
    }

    if (candle2Color == CandleColorType.bullishGreen && c2.close <= c2.open) return false;
    if (candle2Color == CandleColorType.bearishRed && c2.close >= c2.open) return false;

    final range2 = c2.high - c2.low;
    if (range2 > 0) {
      final lowerWick2 = min(c2.open, c2.close) - c2.low;
      final upperWick2 = c2.high - max(c2.open, c2.close);
      if (candle2Wick == WickBiasType.longLowerWick && (lowerWick2 / range2) < 0.50) return false;
      if (candle2Wick == WickBiasType.longUpperWick && (upperWick2 / range2) < 0.50) return false;
    }

    switch (relation) {
      case InterCandleRelation.higherHigh:
        return c2.high > c1.high;
      case InterCandleRelation.higherClose:
        return c2.close > c1.close;
      case InterCandleRelation.breakoutAboveHigh:
        return c2.close > c1.high;
      case InterCandleRelation.insideBar:
        return c2.high <= c1.high && c2.low >= c1.low;
      case InterCandleRelation.bullishEngulfing:
        return c1.close < c1.open &&
            c2.close > c2.open &&
            c2.open <= c1.close &&
            c2.close >= c1.open;
      case InterCandleRelation.any:
        return true;
    }
  }

  double getStopLoss(BacktestCandle c1, BacktestCandle c2) {
    switch (slType) {
      case StructuralStopLossType.candle2Low:
        return c2.low - (c2.high - c2.low) * 0.05;
      case StructuralStopLossType.candle1Low:
        return c1.low - (c1.high - c1.low) * 0.05;
      case StructuralStopLossType.lowestOfBoth:
        return min(c1.low, c2.low) - (c2.high - c2.low) * 0.05;
    }
  }
}
