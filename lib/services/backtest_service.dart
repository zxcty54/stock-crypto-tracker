import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/backtest_candle.dart';

class BacktestService {
  // Background isolate parser
  static Map<String, List<BacktestCandle>> _parseJsonData(String jsonString) {
    final Map<String, dynamic> decoded = jsonDecode(jsonString);
    final Map<String, List<BacktestCandle>> result = {};

    decoded.forEach((ticker, candlesList) {
      if (candlesList is List) {
        result[ticker] = candlesList
            .map((c) => BacktestCandle.fromList(c as List<dynamic>))
            .toList();
      }
    });

    return result;
  }

  /// Poora multi-stock historical dataset load karein
  static Future<Map<String, List<BacktestCandle>>> loadAllStocksData() async {
    try {
      final raw = await rootBundle.loadString('assets/data/bactest.json');
      return await compute(_parseJsonData, raw);
    } catch (e) {
      debugPrint("Backtest JSON Load Error: $e");
      return {};
    }
  }

  /// Kisi specific stock (jaise 'TCS') ka data direct lene ke liye
  static Future<List<BacktestCandle>> loadStockData(String symbol) async {
    final allData = await loadAllStocksData();
    return allData[symbol.toUpperCase()] ?? [];
  }
}
