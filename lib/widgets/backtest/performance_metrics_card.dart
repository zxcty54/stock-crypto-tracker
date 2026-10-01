import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/backtest_engine.dart';

class PerformanceMetricsCard extends StatelessWidget {
  final BacktestSummary summary;

  const PerformanceMetricsCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _kpiItem(
          'TOTAL RETURN',
          '${summary.totalPnlPercent >= 0 ? '+' : ''}${summary.totalPnlPercent.toStringAsFixed(1)}%',
          summary.totalPnlPercent >= 0 ? const Color(0xFF00E676) : const Color(0xFFFF5252),
        ),
        const SizedBox(width: 6),
        _kpiItem('WIN RATE', '${summary.winRate.toStringAsFixed(1)}%', const Color(0xFF00E5FF)),
        const SizedBox(width: 6),
        _kpiItem('MAX DRAWDOWN', '-${summary.maxDrawdownPercent.toStringAsFixed(1)}%', const Color(0xFFFF5252)),
        const SizedBox(width: 6),
        _kpiItem('TRADES', '${summary.totalTrades}', const Color(0xFFFFB300)),
      ],
    );
  }

  Widget _kpiItem(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF131B2A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF202C42)),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(color: Color(0xFF8896AB), fontSize: 8, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.robotoMono(color: color, fontSize: 12.5, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}
