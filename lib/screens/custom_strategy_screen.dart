import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

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
  bool _requireVolumeSurge = false; // 👈 Institutional 1.5x 20-MA Filter

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
    if (candles.isEmpty || candles.length < 35) return;

    List<TradeLog> trades = [];
    double capital = 100000;
    double currentCapital = capital;
    double peakCapital = capital;
    double maxDD = 0.0;
    double grossProfit = 0.0;
    double grossLoss = 0.0;
    int inTradeUntilIndex = -1;

    int maxLookback = 20;
    for (var r in _rules) {
      if (r.lookbackPeriod > maxLookback) maxLookback = r.lookbackPeriod;
    }

    int i = max(maxLookback + 1, 20);
    while (i < candles.length - 1) {
      // Overlapping trade avoid karein
      if (i <= inTradeUntilIndex) {
        i++;
        continue;
      }

      // Volume surge check (20-bar Volume MA)
      bool volumePassed = true;
      if (_requireVolumeSurge) {
        double volSum = 0;
        for (int v = i - 20; v < i; v++) {
          volSum += candles[v].volume;
        }
        final double volMA = volSum / 20;
        volumePassed = candles[i].volume >= (volMA * 1.5);
      }

      bool allTriggered = _rules.isNotEmpty && volumePassed;
      for (var rule in _rules) {
        if (!rule.evaluate(candles, i)) {
          allTriggered = false;
          break;
        }
      }

      if (allTriggered && i + 1 < candles.length) {
        final entryBar = candles[i + 1];
        final entryPrice = entryBar.open;
        final targetPrice = entryPrice * (1 + (_targetPct / 100));
        final slPrice = entryPrice * (1 - (_stopLossPct / 100));

        bool closed = false;
        int exitIdx = i + 1;

        // Forward trade simulation (Max 30 days holding period)
        for (int j = i + 1; j < min(i + 31, candles.length); j++) {
          final bar = candles[j];

          // Check SL
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
              exitReason: 'STOP LOSS',
            ));
            exitIdx = j;
            closed = true;
            break;
          }

          // Check Target
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
              exitReason: 'TARGET HIT',
            ));
            exitIdx = j;
            closed = true;
            break;
          }
        }

        // Holding timeout exit (Agar 30 din tak SL/TP na lage)
        if (!closed && (i + 30) < candles.length) {
          final exitBar = candles[i + 30];
          final pnlPct = ((exitBar.close - entryPrice) / entryPrice) * 100;
          final pnlAmt = currentCapital * (pnlPct / 100);
          currentCapital += pnlAmt;
          if (pnlAmt >= 0) grossProfit += pnlAmt; else grossLoss += pnlAmt.abs();

          trades.add(TradeLog(
            entryDate: entryBar.date,
            exitDate: exitBar.date,
            entryPrice: entryPrice,
            exitPrice: exitBar.close,
            isWin: pnlPct > 0,
            pnlPercent: pnlPct,
            pnlAmount: pnlAmt,
            exitReason: 'TIME DECAY EXIT',
          ));
          exitIdx = i + 30;
          closed = true;
        }

        if (currentCapital > peakCapital) peakCapital = currentCapital;
        final dd = ((peakCapital - currentCapital) / peakCapital) * 100;
        if (dd > maxDD) maxDD = dd;
        if (closed) inTradeUntilIndex = exitIdx;
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
        profitFactor: grossLoss == 0 ? (grossProfit > 0 ? 99.0 : 0.0) : (grossProfit / grossLoss),
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
        title: Text(
          'CUSTOM STRATEGY BUILDER',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)))
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 30),
              children: [
                // 1. Stock Selector Ribbon
                const Text(
                  'SELECT ASSET (FROM ASSETS/DATA/BACTEST.JSON)',
                  style: TextStyle(color: Color(0xFF8896AB), fontSize: 9.5, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 32,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _allStockData.keys.map((s) {
                      final isSel = _selectedStock == s;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedStock = s);
                          _runBacktest();
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                          decoration: BoxDecoration(
                            color: isSel ? const Color(0xFF00E5FF) : const Color(0xFF131B2A),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: isSel ? const Color(0xFF00E5FF) : const Color(0xFF202C42)),
                          ),
                          child: Text(
                            s,
                            style: TextStyle(
                              color: isSel ? Colors.black : Colors.white70,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 14),

                // 2. Dynamic Rule Cards List
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

                // 3. Add Condition Button
                OutlinedButton.icon(
                  onPressed: _addRule,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF00E5FF)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 16, color: Color(0xFF00E5FF)),
                  label: const Text(
                    'ADD CONDITION (AND LOGIC)',
                    style: TextStyle(color: Color(0xFF00E5FF), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 14),

                // 4. Risk & Filters Control Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131B2A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF202C42)),
                  ),
                  child: Column(
                    children: [
                      // Volume Surge Toggle
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.bar_chart_rounded, color: Color(0xFF00E5FF), size: 16),
                              SizedBox(width: 6),
                              Text('1.5x Volume Expansion Filter', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Switch(
                            value: _requireVolumeSurge,
                            activeColor: const Color(0xFF00E5FF),
                            onChanged: (val) {
                              setState(() => _requireVolumeSurge = val);
                              _runBacktest();
                            },
                          ),
                        ],
                      ),
                      const Divider(color: Color(0xFF202C42), height: 16),
                      // SL & TP Sliders
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Stop Loss: -${_stopLossPct.toStringAsFixed(1)}%', style: const TextStyle(color: Color(0xFFFF5252), fontSize: 11, fontWeight: FontWeight.bold)),
                                Slider(
                                  min: 0.5,
                                  max: 8.0,
                                  value: _stopLossPct,
                                  activeColor: const Color(0xFFFF5252),
                                  inactiveColor: const Color(0xFF202C42),
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
                                Text('Target: +${_targetPct.toStringAsFixed(1)}%', style: const TextStyle(color: Color(0xFF00E676), fontSize: 11, fontWeight: FontWeight.bold)),
                                Slider(
                                  min: 1.0,
                                  max: 20.0,
                                  value: _targetPct,
                                  activeColor: const Color(0xFF00E676),
                                  inactiveColor: const Color(0xFF202C42),
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
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 5. Performance Metrics Summary Card
                if (_summary != null) ...[
                  PerformanceMetricsCard(summary: _summary!),
                  const SizedBox(height: 14),

                  // 6. Executed Trades Audit Ledger
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131B2A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF202C42)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'SIMULATED TRADES LEDGER (${_summary!.trades.length})',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
                            ),
                            Text(
                              'Wins: ${_summary!.winningTrades} | Losses: ${_summary!.losingTrades}',
                              style: const TextStyle(color: Color(0xFF8896AB), fontSize: 10),
                            ),
                          ],
                        ),
                        const Divider(color: Color(0xFF202C42), height: 16),
                        if (_summary!.trades.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 18),
                            child: Center(
                              child: Text(
                                'No setups met the criteria across 3 years.',
                                style: TextStyle(color: Colors.white38, fontSize: 11),
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: min(_summary!.trades.length, 12),
                            separatorBuilder: (_, __) => const Divider(color: Color(0xFF182235), height: 12),
                            itemBuilder: (ctx, idx) {
                              final t = _summary!.trades[idx];
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${t.entryDate.toString().split(' ')[0]} ➔ ${t.exitDate.toString().split(' ')[0]}',
                                        style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        '₹${t.entryPrice.toStringAsFixed(1)} ➔ ₹${t.exitPrice.toStringAsFixed(1)} (${t.exitReason})',
                                        style: const TextStyle(color: Color(0xFF8896AB), fontSize: 9.5),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '${t.pnlPercent >= 0 ? '+' : ''}${t.pnlPercent.toStringAsFixed(1)}%',
                                    style: GoogleFonts.robotoMono(
                                      color: t.isWin ? const Color(0xFF00E676) : const Color(0xFFFF5252),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
