import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/backtest_candle.dart';
import '../models/backtest_engine.dart';
import '../models/price_action_strategy.dart';
import '../services/backtest_service.dart';
import '../widgets/backtest/performance_metrics_card.dart';
import '../widgets/backtest/rule_card_widget.dart';

class CustomStrategyScreen extends StatefulWidget {
  const CustomStrategyScreen({super.key});

  @override
  State<CustomStrategyScreen> createState() => _CustomStrategyScreenState();
}

class _CustomStrategyScreenState extends State<CustomStrategyScreen> {
  bool _isLoading = true;
  Map<String, List<BacktestCandle>> _allStockData = {};
  String _selectedStock = 'TCS';

  double _stopLossPct = 2.0;
  double _targetPct = 5.0;

  final List<PriceActionRule> _rules = [
    PriceActionRule(
      id: 'rule_1',
      sourceField: CandleField.close,
      operator: ConditionOperator.crossesAbove,
      targetField: BenchmarkTarget.nBarHigh,
      lookbackPeriod: 20,
    ),
  ];

  BacktestSummary? _summary;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await BacktestService.loadAllStocksData();
    if (mounted) {
      setState(() {
        _allStockData = data;
        if (!_allStockData.containsKey(_selectedStock) && _allStockData.isNotEmpty) {
          _selectedStock = _allStockData.keys.first;
        }
        _isLoading = false;
      });
      _runBacktest();
    }
  }

  void _runBacktest() {
    final candles = _allStockData[_selectedStock] ?? [];
    if (candles.isEmpty) return;

    // Simulation logic using _rules
    List<TradeLog> trades = [];
    double capital = 100000;
    double currentCapital = capital;
    double peakCapital = capital;
    double maxDD = 0.0;
    double grossProfit = 0.0;
    double grossLoss = 0.0;

    int maxLookback = 20;
    for (var r in _rules) {
      if (r.lookbackPeriod > maxLookback) maxLookback = r.lookbackPeriod;
    }

    int i = maxLookback + 1;
    while (i < candles.length - 1) {
      bool allTriggered = _rules.isNotEmpty;
      for (var rule in _rules) {
        if (!rule.evaluate(candles, i)) {
          allTriggered = false;
          break;
        }
      }

      if (allTriggered) {
        final entryBar = candles[i + 1];
        final entryPrice = entryBar.open;
        final targetPrice = entryPrice * (1 + (_targetPct / 100));
        final slPrice = entryPrice * (1 - (_stopLossPct / 100));

        bool closed = false;
        int exitIdx = i + 1;

        for (int j = i + 1; j < candles.length; j++) {
          final bar = candles[j];
          if (bar.low <= slPrice) {
            final pnlAmt = currentCapital * (-_stopLossPct / 100);
            currentCapital += pnlAmt;
            grossLoss += pnlAmt.abs();
            trades.add(TradeLog(
              entryDate: entryBar.date,
              exitDate: bar.date,
              entryPrice: entryPrice,
              exitPrice: slPrice,
              isWin: false,
              pnlPercent: -_stopLossPct,
              pnlAmount: pnlAmt,
              exitReason: 'SL_HIT',
            ));
            exitIdx = j;
            closed = true;
            break;
          }
          if (bar.high >= targetPrice) {
            final pnlAmt = currentCapital * (_targetPct / 100);
            currentCapital += pnlAmt;
            grossProfit += pnlAmt;
            trades.add(TradeLog(
              entryDate: entryBar.date,
              exitDate: bar.date,
              entryPrice: entryPrice,
              exitPrice: targetPrice,
              isWin: true,
              pnlPercent: _targetPct,
              pnlAmount: pnlAmt,
              exitReason: 'TP_HIT',
            ));
            exitIdx = j;
            closed = true;
            break;
          }
        }
        if (currentCapital > peakCapital) peakCapital = currentCapital;
        final dd = ((peakCapital - currentCapital) / peakCapital) * 100;
        if (dd > maxDD) maxDD = dd;
        if (closed) i = exitIdx;
      }
      i++;
    }

    final winCount = trades.where((t) => t.isWin).length;
    setState(() {
      _summary = BacktestSummary(
        totalTrades: trades.length,
        winningTrades: winCount,
        losingTrades: trades.length - winCount,
        winRate: trades.isEmpty ? 0 : (winCount / trades.length) * 100,
        totalPnlPercent: ((currentCapital - capital) / capital) * 100,
        maxDrawdownPercent: maxDD,
        profitFactor: grossLoss == 0 ? 99.0 : grossProfit / grossLoss,
        trades: trades.reversed.toList(),
      );
    });
  }

  void _addRule() {
    HapticFeedback.selectionClick();
    setState(() {
      _rules.add(PriceActionRule(
        id: 'rule_${DateTime.now().millisecondsSinceEpoch}',
        sourceField: CandleField.close,
        operator: ConditionOperator.isGreaterThan,
        targetField: BenchmarkTarget.prevHigh,
      ));
    });
    _runBacktest();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090D16),
        elevation: 0,
        title: const Text('CUSTOM STRATEGY BUILDER', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)))
          : ListView(
              padding: const EdgeInsets.all(14),
              children: [
                // Stock Selector
                SizedBox(
                  height: 32,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _allStockData.keys.map((s) {
                      final isSel = _selectedStock == s;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedStock = s);
                          _runBacktest();
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: isSel ? const Color(0xFF00E5FF) : const Color(0xFF131B2A),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(s, style: TextStyle(color: isSel ? Colors.black : Colors.white70, fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 14),

                // Rule Cards List
                ..._rules.asMap().entries.map((entry) {
                  return RuleCardWidget(
                    rule: entry.value,
                    index: entry.key,
                    canDelete: _rules.length > 1,
                    onDelete: () {
                      setState(() => _rules.removeAt(entry.key));
                      _runBacktest();
                    },
                    onChanged: _runBacktest,
                  );
                }),

                // Add Condition Button
                OutlinedButton.icon(
                  onPressed: _addRule,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF00E5FF)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.add, size: 16, color: Color(0xFF00E5FF)),
                  label: const Text('ADD CONDITION (AND)', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 14),

                // SL & TP Sliders
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131B2A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('SL: -${_stopLossPct.toStringAsFixed(1)}%', style: const TextStyle(color: Color(0xFFFF5252), fontSize: 11, fontWeight: FontWeight.bold)),
                            Slider(
                              min: 0.5,
                              max: 8.0,
                              value: _stopLossPct,
                              activeColor: const Color(0xFFFF5252),
                              onChanged: (v) {
                                setState(() => _stopLossPct = v);
                                _runBacktest();
                              },
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('TP: +${_targetPct.toStringAsFixed(1)}%', style: const TextStyle(color: Color(0xFF00E676), fontSize: 11, fontWeight: FontWeight.bold)),
                            Slider(
                              min: 1.0,
                              max: 20.0,
                              value: _targetPct,
                              activeColor: const Color(0xFF00E676),
                              onChanged: (v) {
                                setState(() => _targetPct = v);
                                _runBacktest();
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Performance Output
                if (_summary != null) PerformanceMetricsCard(summary: _summary!),
              ],
            ),
    );
  }
}
