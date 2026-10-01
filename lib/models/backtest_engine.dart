class TradeLog {
  final DateTime entryDate;
  final DateTime exitDate;
  final double entryPrice;
  final double exitPrice;
  final bool isWin;
  final double pnlPercent;
  final double pnlAmount;
  final String exitReason;

  TradeLog({
    required this.entryDate,
    required this.exitDate,
    required this.entryPrice,
    required this.exitPrice,
    required this.isWin,
    required this.pnlPercent,
    required this.pnlAmount,
    required this.exitReason,
  });
}

class BacktestSummary {
  final int totalTrades;
  final int winningTrades;
  final int losingTrades;
  final double winRate;
  final double totalPnlPercent;
  final double maxDrawdownPercent;
  final double profitFactor;
  final List<TradeLog> trades;

  BacktestSummary({
    required this.totalTrades,
    required this.winningTrades,
    required this.losingTrades,
    required this.winRate,
    required this.totalPnlPercent,
    required this.maxDrawdownPercent,
    required this.profitFactor,
    required this.trades,
  });
}
