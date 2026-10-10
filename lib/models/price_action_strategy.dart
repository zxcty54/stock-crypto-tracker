import '../models/backtest_candle.dart';

enum CandleField { close, open, high, low }
enum ConditionOperator { crossesAbove, isGreaterThan, isLessThan, insideBar, hammerPinBar }
enum BenchmarkTarget { nBarHigh, nBarLow, prevHigh, prevLow, prevClose }

class PriceActionRule {
  String id;
  CandleField sourceField;
  ConditionOperator operator;
  BenchmarkTarget targetField;
  int lookbackPeriod;

  PriceActionRule({
    required this.id,
    this.sourceField = CandleField.close,
    this.operator = ConditionOperator.crossesAbove,
    this.targetField = BenchmarkTarget.nBarHigh,
    this.lookbackPeriod = 20,
  });

  bool evaluate(List<BacktestCandle> candles, int i) {
    if (i < lookbackPeriod + 2) return false;
    final curr = candles[i];
    final prev = candles[i - 1];

    if (operator == ConditionOperator.insideBar) {
      return curr.high < prev.high && curr.low > prev.low;
    }

    if (operator == ConditionOperator.hammerPinBar) {
      final body = (curr.close - curr.open).abs();
      final lowerWick = (curr.close > curr.open ? curr.open : curr.close) - curr.low;
      final totalRange = curr.high - curr.low;
      return totalRange > 0 && lowerWick >= (totalRange * 0.6) && body <= (totalRange * 0.25);
    }

    double sourceVal = curr.close;
    if (sourceField == CandleField.high) sourceVal = curr.high;
    if (sourceField == CandleField.low) sourceVal = curr.low;
    if (sourceField == CandleField.open) sourceVal = curr.open;

    double benchmarkVal = 0.0;
    if (targetField == BenchmarkTarget.prevHigh) benchmarkVal = prev.high;
    if (targetField == BenchmarkTarget.prevLow) benchmarkVal = prev.low;
    if (targetField == BenchmarkTarget.prevClose) benchmarkVal = prev.close;
    if (targetField == BenchmarkTarget.nBarHigh) {
      double maxH = 0;
      for (int k = i - lookbackPeriod; k < i; k++) {
        if (candles[k].high > maxH) maxH = candles[k].high;
      }
      benchmarkVal = maxH;
    }
    if (targetField == BenchmarkTarget.nBarLow) {
      double minL = double.infinity;
      for (int k = i - lookbackPeriod; k < i; k++) {
        if (candles[k].low < minL) minL = candles[k].low;
      }
      benchmarkVal = minL;
    }

    if (operator == ConditionOperator.crossesAbove) {
      double prevSource = prev.close;
      if (sourceField == CandleField.high) prevSource = prev.high;
      return prevSource <= benchmarkVal && sourceVal > benchmarkVal;
    }

    if (operator == ConditionOperator.isGreaterThan) return sourceVal > benchmarkVal;
    if (operator == ConditionOperator.isLessThan) return sourceVal < benchmarkVal;

    return false;
  }
}
