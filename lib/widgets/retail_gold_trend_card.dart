import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class BullionTrendData {
  final double current24k;
  final double current22k;
  final double current18k;
  final double silverPerKg;
  final double ago1y24k;
  final double ago6m24k;
  final double cpiInflation;
  final double niftyReturn;
  final String updatedAt;
  final String source;

  BullionTrendData({
    required this.current24k,
    required this.current22k,
    required this.current18k,
    required this.silverPerKg,
    required this.ago1y24k,
    required this.ago6m24k,
    required this.cpiInflation,
    required this.niftyReturn,
    required this.updatedAt,
    required this.source,
  });

  factory BullionTrendData.fromJson(Map<String, dynamic> json) {
    final rates = json['rates_per_10g'] as Map<String, dynamic>? ?? {};
    final trend = json['trend_1y'] as Map<String, dynamic>? ?? {};

    return BullionTrendData(
      current24k: (rates['24k'] as num?)?.toDouble() ?? 76150.0,
      current22k: (rates['22k'] as num?)?.toDouble() ?? 69804.17,
      current18k: (rates['18k'] as num?)?.toDouble() ?? 57112.5,
      silverPerKg: (rates['silver_per_kg'] as num?)?.toDouble() ?? 92400.0,
      ago1y24k: (trend['rate_1y_ago_24k'] as num?)?.toDouble() ?? 60049.17,
      ago6m24k: (trend['rate_6m_ago_24k'] as num?)?.toDouble() ?? 68535.0,
      cpiInflation: (trend['cpi_inflation_1y'] as num?)?.toDouble() ?? 5.4,
      niftyReturn: (trend['nifty_1y_return'] as num?)?.toDouble() ?? -7.49,
      updatedAt: json['updated_at']?.toString() ?? 'Latest Benchmark',
      source: json['source']?.toString() ?? 'IBJA Benchmark',
    );
  }
}

class RetailGoldTrendCard extends StatefulWidget {
  const RetailGoldTrendCard({super.key});

  @override
  State<RetailGoldTrendCard> createState() => _RetailGoldTrendCardState();
}

class _RetailGoldTrendCardState extends State<RetailGoldTrendCard> {
  final String _dataUrl =
      'https://fastly.jsdelivr.net/gh/zxcty54/stock-crypto-tracker@main/ibja_rates.json';

  BullionTrendData _data = BullionTrendData(
    current24k: 76150.0,
    current22k: 69804.17,
    current18k: 57112.5,
    silverPerKg: 92400.0,
    ago1y24k: 60049.17,
    ago6m24k: 68535.0,
    cpiInflation: 5.4,
    niftyReturn: -7.49,
    updatedAt: 'Live',
    source: 'IBJA Official',
  );

  bool _isLoading = true;
  int _selectedAssetType = 0; // 0: 22K Jewelry, 1: 24K Coin/Bar, 2: Gold ETF (BeES)

  @override
  void initState() {
    super.initState();
    _fetchTrendData();
  }

  Future<void> _fetchTrendData() async {
    try {
      final res = await http.get(
        Uri.parse('$_dataUrl?ts=${DateTime.now().millisecondsSinceEpoch}'),
        headers: {'Cache-Control': 'no-cache'},
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final parsed = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _data = BullionTrendData.fromJson(parsed);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatInr(num val) {
    return val.round().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  @override
  Widget build(BuildContext context) {
    final double rawGoldReturnPercent =
        ((_data.current24k - _data.ago1y24k) / _data.ago1y24k) * 100;

    double purityMultiplier = 1.0;
    double buyMakingChargePercent = 0.0;

    if (_selectedAssetType == 0) {
      purityMultiplier = 22 / 24;
      buyMakingChargePercent = 14.0;
    } else if (_selectedAssetType == 1) {
      purityMultiplier = 1.0;
      buyMakingChargePercent = 3.0;
    } else {
      purityMultiplier = 1.0;
      buyMakingChargePercent = 0.0;
    }

    final double cost1yAgo = (_data.ago1y24k * purityMultiplier) *
        (1 + (buyMakingChargePercent / 100)) *
        1.03;

    final double liquidationCashToday = _data.current24k * purityMultiplier;

    final double netReturnPercent =
        ((liquidationCashToday - cost1yAgo) / cost1yAgo) * 100;
    final double netGainAmount = liquidationCashToday - cost1yAgo;

    final double vsInflationAlpha = netReturnPercent - _data.cpiInflation;
    final double vsNiftyAlpha = netReturnPercent - _data.niftyReturn;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1726),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E2B3E), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF00F5A0),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '1-YEAR RETAIL ALPHA & TREND',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _isLoading = true);
                  _fetchTrendData();
                },
                child: Row(
                  children: [
                    if (_isLoading)
                      const SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: Color(0xFF00F0FF),
                        ),
                      )
                    else
                      const Icon(Icons.sync_rounded, color: Color(0xFF00F0FF), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      _data.updatedAt.contains('IST') ? 'Synced' : 'Live',
                      style: const TextStyle(
                        color: Color(0xFF00F0FF),
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Asset Selector Chips
          Row(
            children: [
              _filterTab(0, '22K JEWELRY'),
              const SizedBox(width: 6),
              _filterTab(1, '24K COIN / BAR'),
              const SizedBox(width: 6),
              _filterTab(2, 'GOLD ETF (BEES)'),
            ],
          ),

          const SizedBox(height: 12),

          // Comparison Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF131B2A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF25334A)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bought 1-Yr Ago (Cost + Tax)',
                          style: TextStyle(color: Color(0xFF6B7A99), fontSize: 9.5),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '₹${_formatInr(cost1yAgo)}',
                          style: GoogleFonts.robotoMono(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const Icon(Icons.arrow_forward_rounded, color: Colors.white24, size: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Cash In-Hand Today (Sell-Back)',
                          style: TextStyle(color: Color(0xFF6B7A99), fontSize: 9.5),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '₹${_formatInr(liquidationCashToday)}',
                          style: GoogleFonts.robotoMono(
                            color: const Color(0xFF00F5A0),
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(color: Color(0xFF1E2B3E), height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Net Liquidation Gain per 10g:',
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11),
                    ),
                    Text(
                      '${netGainAmount >= 0 ? '+' : ''}₹${_formatInr(netGainAmount)} (${netReturnPercent.toStringAsFixed(1)}%)',
                      style: GoogleFonts.robotoMono(
                        color: netReturnPercent >= 0
                            ? const Color(0xFF00F5A0)
                            : const Color(0xFFFF2A6D),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // 3 Alpha Badges
          Row(
            children: [
              Expanded(
                child: _metricBadge(
                  title: 'PAPER GAIN',
                  value: '+${rawGoldReturnPercent.toStringAsFixed(1)}%',
                  subtitle: '24K Base Spot',
                  color: const Color(0xFF00F0FF),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metricBadge(
                  title: 'VS INFLATION',
                  value: '${vsInflationAlpha >= 0 ? '+' : ''}${vsInflationAlpha.toStringAsFixed(1)}%',
                  subtitle: 'Real Wealth Alpha',
                  color: vsInflationAlpha >= 0
                      ? const Color(0xFF00F5A0)
                      : const Color(0xFFFF9800),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metricBadge(
                  title: 'VS NIFTY 50',
                  value: '${vsNiftyAlpha >= 0 ? '+' : ''}${vsNiftyAlpha.toStringAsFixed(1)}%',
                  subtitle: 'Equity Alpha',
                  color: vsNiftyAlpha >= 0
                      ? const Color(0xFF00F5A0)
                      : const Color(0xFFFF2A6D),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Takeaway Insight
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF141C2B),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: vsNiftyAlpha >= 0
                    ? const Color(0xFF00F5A0).withOpacity(0.25)
                    : const Color(0xFFFF9800).withOpacity(0.25),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  vsNiftyAlpha >= 0 ? Icons.trending_up_rounded : Icons.info_outline,
                  color: vsNiftyAlpha >= 0 ? const Color(0xFF00F5A0) : const Color(0xFFFF9800),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedAssetType == 0
                        ? 'Due to 14% making charges + 3% GST, 22K jewelry gives ${netReturnPercent.toStringAsFixed(1)}% cash return vs +${rawGoldReturnPercent.toStringAsFixed(1)}% paper gain.'
                        : 'Gold outperformed Nifty 50 by +${vsNiftyAlpha.toStringAsFixed(1)}% in the last 1 year, preserving capital against stock market drawdowns.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 10,
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Stepper Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0F1A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _milestoneItem('1Y Ago', '₹${_formatInr(_data.ago1y24k)}'),
                const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 14),
                _milestoneItem('6M Ago', '₹${_formatInr(_data.ago6m24k)}'),
                const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 14),
                _milestoneItem('Today (24K)', '₹${_formatInr(_data.current24k)}',
                    color: const Color(0xFFFFD700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterTab(int index, String label) {
    final isSelected = _selectedAssetType == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedAssetType = index);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF00F0FF).withOpacity(0.18)
                : const Color(0xFF131B2A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? const Color(0xFF00F0FF) : const Color(0xFF1E2B3E),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? const Color(0xFF00F0FF) : Colors.white60,
              fontSize: 9.5,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _metricBadge({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF101724),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1E2B3E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF6B7A99),
              fontSize: 8.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: GoogleFonts.robotoMono(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 1),
          Text(subtitle, style: const TextStyle(color: Colors.white30, fontSize: 7.5)),
        ],
      ),
    );
  }

  Widget _milestoneItem(String label, String value, {Color color = Colors.white70}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF6B7A99), fontSize: 8.5)),
        const SizedBox(height: 1),
        Text(
          value,
          style: GoogleFonts.robotoMono(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
