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
      source: json['source']?.toString() ?? 'IBJA Official & Market Benchmark',
    );
  }
}

class RetailGoldTrendCardProV2 extends StatefulWidget {
  final bool isDarkMode;
  const RetailGoldTrendCardProV2({super.key, this.isDarkMode = true});

  @override
  State<RetailGoldTrendCardProV2> createState() => _RetailGoldTrendCardProV2State();
}

class _RetailGoldTrendCardProV2State extends State<RetailGoldTrendCardProV2> {
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

  // 🎨 Pro V2 Theme Palette
  static const Color bgDark = Color(0xFF0F1726);
  static const Color surfaceCard = Color(0xFF131B2A);
  static const Color borderSubtle = Color(0xFF1E2B3E);
  static const Color borderCard = Color(0xFF25334A);
  static const Color accentNeon = Color(0xFF00F5A0);
  static const Color accentGold = Color(0xFFFFD700);
  static const Color accentCyan = Color(0xFF00F0FF);
  static const Color accentRose = Color(0xFFFF2A6D);
  static const Color textMuted = Color(0xFF6B7A99);
  static const Color darkPillBg = Color(0xFF0A0F1A);

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
    // 1. Raw Gold Return
    final double rawGoldReturnPercent =
        ((_data.current24k - _data.ago1y24k) / _data.ago1y24k) * 100;

    // 2. Direct JSON Rate Matching (22k rate directly used from JSON)
    final double currentRatePer10g =
        _selectedAssetType == 0 ? _data.current22k : _data.current24k;
    final double rate1yAgoPer10g = _selectedAssetType == 0
        ? (_data.ago1y24k * (22 / 24))
        : _data.ago1y24k;

    final double unitFactor = _weightGrams / 10.0;

    // 3. Purchase Cost breakdown
    final double baseMetalCost1y = rate1yAgoPer10g * unitFactor;
    final double makingChargeAmt =
        _selectedAssetType == 2 ? 0.0 : baseMetalCost1y * (_makingChargePct / 100.0);
    final double gstAmt =
        _selectedAssetType == 2 ? 0.0 : (baseMetalCost1y + makingChargeAmt) * 0.03;
    final double totalBoughtCost1y = baseMetalCost1y + makingChargeAmt + gstAmt;

    // 4. Liquidation in-hand cash
    final double liquidationCashToday = currentRatePer10g * unitFactor;
    final double netGainAmount = liquidationCashToday - totalBoughtCost1y;
    final double netReturnPercent = (netGainAmount / totalBoughtCost1y) * 100;

    // 5. Alpha calculations
    final double vsInflationAlpha = netReturnPercent - _data.cpiInflation;
    final double vsNiftyAlpha = netReturnPercent - _data.niftyReturn;
    final double breakEvenRallyRequired =
        ((1 + _makingChargePct / 100.0) * 1.03 - 1) * 100;
    final double goldSilverRatio =
        (_data.current24k * 100) / (_data.silverPerKg > 0 ? _data.silverPerKg : 1.0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderSubtle, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header Bar (V2 Gold Dot & Stylized typography)
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
                        child: CircularProgressIndicator(strokeWidth: 1.5, color: accentGold),
                      )
                    else
                      const Icon(Icons.sync_rounded, color: accentGold, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      _data.updatedAt.contains('IST') ? 'Synced' : 'Live',
                      style: const TextStyle(color: accentGold, fontSize: 9.5, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 2. Asset Selector Chips (V2 Gold-accent theme)
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

          // 3. Weight Customizer Strip (V2 Card Style)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: surfaceCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderSubtle),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Weight:', style: TextStyle(color: textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
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

          // 4. Interactive Making Charge Slider
          if (_selectedAssetType != 2) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: surfaceCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderSubtle),
              ),
              child: Row(
                children: [
                  Text(
                    'Making: ${_makingChargePct.toInt()}%',
                    style: const TextStyle(color: accentGold, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                  Expanded(
                    child: Slider(
                      min: 2,
                      max: 25,
                      divisions: 23,
                      value: _makingChargePct,
                      activeColor: accentGold,
                      inactiveColor: const Color(0xFF1E2B3E),
                      onChanged: (val) => setState(() => _makingChargePct = val),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // 5. Core Comparison Card (V2 High-Contrast Card Style)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: surfaceCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderCard),
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
                        const Text('Cash In-Hand Today (Sellback)', style: TextStyle(color: textMuted, fontSize: 9.5)),
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
                    Text(
                      'Net Liquidation Gain (${_weightGrams.toStringAsFixed(1)}g):',
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
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

          // 6. Educational Break-Even Warning (Jewelry)
          if (_selectedAssetType == 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2A101A),
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

          // 7. Triple Alpha Badges (V2 Card Style)
          Row(
            children: [
              Expanded(child: _metricBadge('PAPER GAIN', '+${rawGoldReturnPercent.toStringAsFixed(1)}%', '24K Base Spot', accentCyan)),
              const SizedBox(width: 6),
              Expanded(child: _metricBadge('VS INFLATION', '${vsInflationAlpha >= 0 ? '+' : ''}${vsInflationAlpha.toStringAsFixed(1)}%', 'Real Alpha', vsInflationAlpha >= 0 ? accentNeon : Colors.amber)),
              const SizedBox(width: 6),
              Expanded(child: _metricBadge('VS NIFTY 50', '${vsNiftyAlpha >= 0 ? '+' : ''}${vsNiftyAlpha.toStringAsFixed(1)}%', 'Equity Alpha', vsNiftyAlpha >= 0 ? accentNeon : accentRose)),
            ],
          ),

          const SizedBox(height: 10),

          // 8. Existing Takeaway Insight Box (Styled with V2 Neon/Amber borders)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF141C2B),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: vsNiftyAlpha >= 0
                    ? accentNeon.withOpacity(0.25)
                    : Colors.amber.withOpacity(0.25),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  vsNiftyAlpha >= 0 ? Icons.trending_up_rounded : Icons.info_outline,
                  color: vsNiftyAlpha >= 0 ? accentNeon : Colors.amber,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedAssetType == 0
                        ? 'Due to ${_makingChargePct.toInt()}% making charges + 3% GST, 22K jewelry gives ${netReturnPercent.toStringAsFixed(1)}% cash return vs +${rawGoldReturnPercent.toStringAsFixed(1)}% paper gain.'
                        : 'Gold generated ${vsNiftyAlpha >= 0 ? '+' : ''}${vsNiftyAlpha.toStringAsFixed(1)}% alpha over Nifty 50 in the last 1 year, preserving capital against stock market drawdowns.',
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

          // 9. Live Gold / Silver Ratio Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: darkPillBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderSubtle),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Gold/Silver Ratio: ${goldSilverRatio.toStringAsFixed(1)}x',
                  style: const TextStyle(color: accentGold, fontSize: 9.5, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Silver: ₹${_formatInr(_data.silverPerKg)}/kg',
                  style: GoogleFonts.robotoMono(color: Colors.white70, fontSize: 9.5),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // 10. Existing Timeline Stepper Strip (1Y Ago -> 6M Ago -> Today 24K)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: darkPillBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderSubtle),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _milestoneItem('1Y Ago', '₹${_formatInr(_data.ago1y24k)}'),
                const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 14),
                _milestoneItem('6M Ago', '₹${_formatInr(_data.ago6m24k)}'),
                const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 14),
                _milestoneItem(
                  'Today (24K)',
                  '₹${_formatInr(_data.current24k)}',
                  color: accentGold,
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
            color: isSelected ? accentGold.withOpacity(0.2) : surfaceCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? accentGold : borderSubtle),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? accentGold : Colors.white60,
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
          color: isSelected ? accentGold : bgDark,
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
        color: const Color(0xFF101724),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: textMuted, fontSize: 8, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(val, style: GoogleFonts.robotoMono(color: col, fontSize: 12, fontWeight: FontWeight.w900)),
          Text(sub, style: const TextStyle(color: Colors.white30, fontSize: 7)),
        ],
      ),
    );
  }

  Widget _milestoneItem(String label, String value, {Color color = Colors.white70}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: textMuted, fontSize: 8.5)),
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
