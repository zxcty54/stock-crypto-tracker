import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

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

  factory BacktestCandle.fromJson(Map<String, dynamic> json) {
    return BacktestCandle(
      date: DateTime.parse(json['date'] ?? json['datetime'] ?? DateTime.now().toIso8601String()),
      open: (json['open'] as num).toDouble(),
      high: (json['high'] as num).toDouble(),
      low: (json['low'] as num).toDouble(),
      close: (json['close'] as num).toDouble(),
      volume: (json['volume'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class BacktestService {
  static List<BacktestCandle> _parseData(String jsonString) {
    final decoded = jsonDecode(jsonString);
    final List list = decoded is List ? decoded : (decoded['candles'] ?? decoded['data'] ?? []);
    return list.map((item) => BacktestCandle.fromJson(item as Map<String, dynamic>)).toList();
  }

  /// Local asset se 3-Year Backtest Data load karein (Background Isolate ke sath)
  static Future<List<BacktestCandle>> loadLocalBacktestData() async {
    try {
      final raw = await rootBundle.loadString('assets/data/bactest.json');
      return await compute(_parseData, raw);
    } catch (e) {
      debugPrint("Asset load error: $e");
      return [];
    }
  }
}
