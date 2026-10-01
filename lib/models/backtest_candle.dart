class BacktestCandle {
  final DateTime date;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  BacktestCandle({
    required this.date,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  // [ "2023-09-29", 3537.2, 3568.45, 3505.55, 3528.6, 2243791 ] format parse karne ke liye
  factory BacktestCandle.fromList(List<dynamic> list) {
    return BacktestCandle(
      date: DateTime.parse(list[0].toString()),
      open: (list[1] as num).toDouble(),
      high: (list[2] as num).toDouble(),
      low: (list[3] as num).toDouble(),
      close: (list[4] as num).toDouble(),
      volume: (list[5] as num).toDouble(),
    );
  }
}
