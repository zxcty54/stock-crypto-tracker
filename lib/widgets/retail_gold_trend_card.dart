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
      ago1y24k: (trend['rate_1y_ago_24k'] as num?)?.toDouble() ?? 60029.42,
      ago6m24k: (trend['rate_6m_ago_24k'] as num?)?.toDouble() ?? 68535.0,
      cpiInflation: (trend['cpi_inflation_1y'] as num?)?.toDouble() ?? 5.4,
      niftyReturn: (trend['nifty_1y_return'] as num?)?.toDouble() ?? -8.09,
      updatedAt: json['updated_at']?.toString() ?? 'Latest Benchmark',
      source: json['source']?.toString() ?? 'IBJA Benchmark',
    );
  }
}

class RetailGoldTrendCard extends StatefulWidget {
  final bool isDarkMode;
  const RetailGoldTrendCard({super.key, this.isDarkMode = true});

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
    ago1y24k: 60029.42,
    ago6m24k: 68535.0,
    cpiInflation: 5.4,
    niftyReturn: -8.09,
    updatedAt: 'Live',
    source: 'IBJA Official',
  );

  bool _isLoading = true;
  int _selectedAssetType = 0; // 0: 22K Jewelry, 1: 24K Coin/Bar, 2: Gold ETF (BeES)
  double _weightGrams = 10.0;
  double _makingChargePct = 14.0;

  // Stock Market Theme Palette
  static const Color bgDark = Color(0xFF090D16);
  static const Color surfaceCard = Color(0xFF131B2A);
  static const Color innerCard = Color(0xFF0F172A);
  static const Color borderSubtle = Color(0xFF202C42);
  static const Color accentNeon = Color(0xFF00E676);
  static const Color accentGold = Color(0xFFFFB300);
  static const Color accentCyan = Color(0xFF00E5FF);
  static const Color accentRose = Color(0xFFFF5252);
  static const Color textMuted = Color(0xFF94A3B8);

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

  void _onAssetTypeSelected(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedAssetType = index;
      if (index == 0) {
        _makingChargePct = 14.0;
      } else if (index == 1) {
        _makingChargePct = 3.0;
      } else {
        _makingChargePct = 0.0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final double rawGoldReturnPercent =
        ((_data.current24k - _data.ago1y24k) / _data.ago1y24k) * 100;

    final double purityMultiplier = _selectedAssetType == 0 ? (22 / 24) : 1.0;
    final double unitFactor = _weightGrams / 10.0;

    final double baseMetalCost1y = _data.ago1y24k * purityMultiplier * unitFactor;
    final double makingChargeAmt = baseMetalCost1y * (_makingChargePct / 100.0);
    final double gstAmt = (baseMetalCost1y + makingChargeAmt) * 0.03;
    final double totalBoughtCost1y = baseMetalCost1y + makingChargeAmt + gstAmt;

    final double liquidationCashToday = _data.current24k * purityMultiplier * unitFactor;
    final double netGainAmount = liquidationCashToday - totalBoughtCost1y;
    final double netReturnPercent = (netGainAmount / totalBoughtCost1y) * 100;

    final double vsInflationAlpha = netReturnPercent - _data.cpiInflation;
    final double vsNiftyAlpha = netReturnPercent - _data.niftyReturn;
    final double breakEvenRallyRequired = ((1 + _makingChargePct / 100.0) * 1.03 - 1) * 100;
    final double goldSilverRatio = (_data.current24k * 100) / _data.silverPerKg;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderSubtle, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.45),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(color: accentGold, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'RETAIL GOLD ALPHA & SELLBACK RADAR',
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
                        child: CircularProgressIndicator(strokeWidth: 1.5, color: accentCyan),
                      )
                    else
                      const Icon(Icons.sync_rounded, color: accentCyan, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      _data.updatedAt.contains('IST') ? 'Synced' : 'Live',
                      style: const TextStyle(
                        color: accentCyan,
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

          // 2. Asset Type Selector
          Row(
            children: [
              _assetChip(0, '22K JEWELRY'),
              const SizedBox(width: 6),
              _assetChip(1, '24K COIN / BAR'),
              const SizedBox(width: 6),
              _assetChip(2, 'GOLD ETF (BEES)'),
            ],
          ),

          const SizedBox(height: 10),

          // 3. Weight Customizer Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: innerCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderSubtle),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Weight:',
                  style: TextStyle(color: textMuted, fontSize: 10, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    _weightPreset(8.0, '8g (1 Sov)'),
                    const SizedBox(width: 4),
                    _weightPreset(10.0, '10g (Std)'),
                    const SizedBox(width: 4),
                    _weightPreset(11.66, '11.66g (Tola)'),
                    const SizedBox(width: 4),
                    _weightPreset(50.0, '50g (Set)'),
                  ],
                ),
              ],
            ),
          ),

          // 4. Making Charge Slider (Only for physical jewelry / coins)
          if (_selectedAssetType != 2) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: innerCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderSubtle),
              ),
              child: Row(
                children: [
                  Text(
                    'Making: ${_makingChargePct.toInt()}%',
                    style: const TextStyle(
                      color: accentGold,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      min: 2,
                      max: 25,
                      divisions: 23,
                      value: _makingChargePct,
                      activeColor: accentGold,
                      inactiveColor: const Color(0xFF1E293B),
                      onChanged: (val) => setState(() => _makingChargePct = val),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // 5. Core Comparison Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: innerCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderSubtle),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bought 1Y Ago (${_weightGrams.toStringAsFixed(1)}g Total Cost)',
                          style: const TextStyle(color: textMuted, fontSize: 9.5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '₹${_formatInr(totalBoughtCost1y)}',
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
                          'Cash In-Hand Today (Sellback)',
                          style: TextStyle(color: textMuted, fontSize: 9.5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '₹${_formatInr(liquidationCashToday)}',
                          style: GoogleFonts.robotoMono(
                            color: accentNeon,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(color: borderSubtle, height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Net Cash Liquidation Gain:',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    Text(
                      '${netGainAmount >= 0 ? '+' : ''}₹${_formatInr(netGainAmount)} (${netReturnPercent.toStringAsFixed(1)}%)',
                      style: GoogleFonts.robotoMono(
                        color: netGainAmount >= 0 ? accentNeon : accentRose,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 6. Educational Sellback Deduction Warning
          if (_selectedAssetType == 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: accentRose.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: accentRose, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Jewellery Break-even: Gold spot must rise +${breakEvenRallyRequired.toStringAsFixed(1)}% just to recover ${_makingChargePct.toInt()}% making charges + 3% GST.',
                      style: const TextStyle(color: Color(0xFFFFB4C9), fontSize: 9.5, height: 1.25),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),

          // 7. Triple Alpha Badges
          Row(
            children: [
              Expanded(
                child: _metricBadge(
                  'PAPER GAIN',
                  '+${rawGoldReturnPercent.toStringAsFixed(1)}%',
                  '24K Base Spot',
                  accentCyan,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _metricBadge(
                  'VS INFLATION',
                  '${vsInflationAlpha >= 0 ? '+' : ''}${vsInflationAlpha.toStringAsFixed(1)}%',
                  'Real Alpha',
                  vsInflationAlpha >= 0 ? accentNeon : Colors.amber,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _metricBadge(
                  'VS NIFTY 50',
                  '${vsNiftyAlpha >= 0 ? '+' : ''}${vsNiftyAlpha.toStringAsFixed(1)}%',
                  'Equity Alpha',
                  vsNiftyAlpha >= 0 ? accentNeon : accentRose,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // 8. Gold / Silver Ratio & Milestone
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: innerCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderSubtle),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Gold/Silver Ratio: ${goldSilverRatio.toStringAsFixed(1)}x',
                  style: const TextStyle(
                    color: accentGold,
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '1Y: ₹${_formatInr(_data.ago1y24k)} -> Today: ₹${_formatInr(_data.current24k)}',
                  style: GoogleFonts.robotoMono(color: textMuted, fontSize: 9.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _assetChip(int index, String label) {
    final isSelected = _selectedAssetType == index;
    return Expanded(
      child: InkWell(
        onTap: () => _onAssetTypeSelected(index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? accentCyan.withOpacity(0.15) : innerCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? accentCyan : borderSubtle),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? accentCyan : Colors.white70,
              fontSize: 9.5,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _weightPreset(double g, String text) {
    final isSelected = _weightGrams == g;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _weightGrams = g);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? accentCyan : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white70,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _metricBadge(String title, String val, String sub, Color col) {
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: innerCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: textMuted, fontSize: 8, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(
            val,
            style: GoogleFonts.robotoMono(color: col, fontSize: 12, fontWeight: FontWeight.w900),
          ),
          Text(sub, style: const TextStyle(color: Colors.white38, fontSize: 7)),
        ],
      ),
    );
  }
}
