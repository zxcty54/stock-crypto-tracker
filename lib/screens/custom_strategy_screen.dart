import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/backtest_candle.dart';
import '../models/backtest_engine.dart';
import '../models/two_candle_rule_model.dart';
import '../services/backtest_service.dart';
import '../services/two_candle_engine.dart';
import '../widgets/backtest/performance_metrics_card.dart';
import '../widgets/backtest/two_candle_builder_widget.dart';

class CustomStrategyScreen extends StatefulWidget {
  const CustomStrategyScreen({super.key});

  @override
  State<CustomStrategyScreen> createState() => _CustomStrategyScreenState();
}

class _CustomStrategyScreenState extends State<CustomStrategyScreen> {
  bool _isLoading = true;
  Map<String, List<BacktestCandle>> _allStockData = {};
  String _selectedStock = 'TCS';

  // 2-Candle Sequence Configuration
  final TwoCandleStrategyConfig _config = TwoCandleStrategyConfig();
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

    final result = TwoCandleEngine.run(
      candles: candles,
      config: _config,
    );

    setState(() {
      _summary = result;
    });
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
                  'SELECT ASSET BENCHMARK (FROM BACTEST.JSON)',
                  style: TextStyle(
                    color: Color(0xFF8896AB),
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
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
                            border: Border.all(
                              color: isSel ? const Color(0xFF00E5FF) : const Color(0xFF202C42),
                            ),
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

                // 2. 2-Candle Visual Sequence Builder Block
                TwoCandleBuilderWidget(
                  config: _config,
                  onChanged: _runBacktest,
                ),
                const SizedBox(height: 14),

                // 3. Risk-to-Reward Control Box
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
                          const Text(
                            'RISK TO REWARD RATIO',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '1:${_config.riskRewardRatio.toStringAsFixed(1)} R:R',
                            style: const TextStyle(
                              color: Color(0xFF00E676),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        min: 1.0,
                        max: 5.0,
                        divisions: 8,
                        value: _config.riskRewardRatio,
                        activeColor: const Color(0xFF00E676),
                        inactiveColor: const Color(0xFF202C42),
                        onChanged: (v) {
                          setState(() => _config.riskRewardRatio = v);
                          _runBacktest();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 4. Performance KPI Output Card
                if (_summary != null) ...[
                  PerformanceMetricsCard(summary: _summary!),
                  const SizedBox(height: 14),

                  // 5. Executed Trades Audit Ledger
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
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              'Wins: ${_summary!.winningTrades} | Losses: ${_summary!.losingTrades}',
                              style: const TextStyle(
                                color: Color(0xFF8896AB),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                        const Divider(color: Color(0xFF202C42), height: 16),
                        if (_summary!.trades.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 18),
                            child: Center(
                              child: Text(
                                'No 2-candle setups met the criteria across 3 years.',
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
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '₹${t.entryPrice.toStringAsFixed(1)} ➔ ₹${t.exitPrice.toStringAsFixed(1)} (${t.exitReason})',
                                        style: const TextStyle(
                                          color: Color(0xFF8896AB),
                                          fontSize: 9.5,
                                        ),
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
