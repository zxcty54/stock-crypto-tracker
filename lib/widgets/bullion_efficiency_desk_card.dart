import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class BullionDeskData {
  final double current24k;
  final double current22k;
  final double silverPerKg;
  final double ago1y24k;
  final double cpiInflation;
  final double niftyReturn;
  final String updatedAt;

  const BullionDeskData({
    required this.current24k,
    required this.current22k,
    required this.silverPerKg,
    required this.ago1y24k,
    required this.cpiInflation,
    required this.niftyReturn,
    required this.updatedAt,
  });

  factory BullionDeskData.fromJson(Map<String, dynamic> json) {
    final rates = json['rates_per_10g'] as Map<String, dynamic>? ?? {};
    final trend = json['trend_1y'] as Map<String, dynamic>? ?? {};

    return BullionDeskData(
      current24k: (rates['24k'] as num?)?.toDouble() ?? 76150.0,
      current22k: (rates['22k'] as num?)?.toDouble() ?? 69804.17,
      silverPerKg: (rates['silver_per_kg'] as num?)?.toDouble() ?? 92400.0,
      ago1y24k: (trend['rate_1y_ago_24k'] as num?)?.toDouble() ?? 60029.42,
      cpiInflation: (trend['cpi_inflation_1y'] as num?)?.toDouble() ?? 5.4,
      niftyReturn: (trend['nifty_1y_return'] as num?)?.toDouble() ?? -8.09,
      updatedAt: json['updated_at']?.toString() ?? 'Live Benchmark',
    );
  }
}

class BullionEfficiencyDeskCard extends StatefulWidget {
  final bool isDarkMode;
  const BullionEfficiencyDeskCard({super.key, this.isDarkMode = true});

  @override
  State<BullionEfficiencyDeskCard> createState() => _BullionEfficiencyDeskCardState();
}

class _BullionEfficiencyDeskCardState extends State<BullionEfficiencyDeskCard> {
  final String _dataUrl =
      'https://fastly.jsdelivr.net/gh/zxcty54/stock-crypto-tracker@main/ibja_rates.json';

  BullionDeskData _data = const BullionDeskData(
    current24k: 76150.0,
    current22k: 69804.17,
    silverPerKg: 92400.0,
    ago1y24k: 60029.42,
    cpiInflation: 5.4,
    niftyReturn: -8.09,
    updatedAt: 'Live',
  );

  bool _isLoading = true;
  int _selectedVehicle = 0; // 0: 22K Physical, 1: 24K Minted Bar, 2: Paper ETF
  double _holdingGrams = 10.0;
  double _customFrictionPct = 12.0;

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
    _fetchDeskData();
  }

  Future<void> _fetchDeskData() async {
    try {
      final res = await http.get(
        Uri.parse('$_dataUrl?ts=${DateTime.now().millisecondsSinceEpoch}'),
        headers: {'Cache-Control': 'no-cache'},
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final parsed = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _data = BullionDeskData.fromJson(parsed);
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

  void _onVehicleChanged(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedVehicle = index;
      if (index == 0) _customFrictionPct = 12.0;
      else if (index == 1) _customFrictionPct = 3.0;
      else _customFrictionPct = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final double rawGoldReturnPercent =
        ((_data.current24k - _data.ago1y24k) / _data.ago1y24k) * 100;

    final double purityMultiplier = _selectedVehicle == 0 ? (22 / 24) : 1.0;
    final double unitFactor = _holdingGrams / 10.0;

    final double baseMetalCost1y = _data.ago1y24k * purityMultiplier * unitFactor;
    final double premiumExpense = baseMetalCost1y * (_customFrictionPct / 100.0);
    final double statutoryTax = (_selectedVehicle == 2) ? 0.0 : (baseMetalCost1y + premiumExpense) * 0.03;
    final double totalCapitalDeployed = baseMetalCost1y + premiumExpense + statutoryTax;

    final double exitRealizationToday = _data.current24k * purityMultiplier * unitFactor;
    final double netDeltaAmount = exitRealizationToday - totalCapitalDeployed;
    final double netRealizedYield = (netDeltaAmount / totalCapitalDeployed) * 100;

    final double hurdleBreakeven = _selectedVehicle == 2
        ? 0.0
        : (((1 + _customFrictionPct / 100.0) * 1.03) - 1) * 100;
    final double frictionDragLoss = premiumExpense + statutoryTax;
    final double vsInflationAlpha = netRealizedYield - _data.cpiInflation;
    final double vsNiftyAlpha = netRealizedYield - _data.niftyReturn;
    final double goldSilverRatio = (_data.current24k * 100) / _data.silverPerKg;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderSubtle, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(color: accentGold, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'BULLION LIQUIDATION & FRICTION RADAR',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _isLoading = true);
                  _fetchDeskData();
                },
                child: Row(
                  children: [
                    if (_isLoading)
                      const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: accentCyan))
                    else
                      const Icon(Icons.sync_rounded, color: accentCyan, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      _data.updatedAt.contains('IST') ? 'Live Feed' : 'Synced',
                      style: const TextStyle(color: accentCyan, fontSize: 9.5, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _vehicleChip(0, '22K PHYSICAL'),
              const SizedBox(width: 6),
              _vehicleChip(1, '24K MINTED BAR'),
              const SizedBox(width: 6),
              _vehicleChip(2, 'GOLD ETF (BEES)'),
            ],
          ),
          const SizedBox(height: 10),
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
                const Text('Position Lot:', style: TextStyle(color: textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    _lotPreset(8.0, '8g (1 Sov)'),
                    const SizedBox(width: 4),
                    _lotPreset(10.0, '10g (Std)'),
                    const SizedBox(width: 4),
                    _lotPreset(11.66, '11.66g (Tola)'),
                    const SizedBox(width: 4),
                    _lotPreset(50.0, '50g (Instl)'),
                  ],
                ),
              ],
            ),
          ),
          if (_selectedVehicle != 2) ...[
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
                    'Entry Markup: ${_customFrictionPct.toInt()}%',
                    style: const TextStyle(color: accentGold, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                  Expanded(
                    child: Slider(
                      min: 1,
                      max: 20,
                      divisions: 19,
                      value: _customFrictionPct,
                      activeColor: accentGold,
                      inactiveColor: const Color(0xFF1E293B),
                      onChanged: (val) => setState(() => _customFrictionPct = val),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
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
                        const Text('Capital Outlay (1Y Ago)', style: TextStyle(color: textMuted, fontSize: 9.5)),
                        const SizedBox(height: 2),
                        Text('₹${_formatInr(totalCapitalDeployed)}', style: GoogleFonts.robotoMono(color: Colors.white70, fontSize: 13.5, fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const Icon(Icons.arrow_forward_rounded, color: Colors.white24, size: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Exit Realization (IBJA Spot)', style: TextStyle(color: textMuted, fontSize: 9.5)),
                        const SizedBox(height: 2),
                        Text('₹${_formatInr(exitRealizationToday)}', style: GoogleFonts.robotoMono(color: accentNeon, fontSize: 15.5, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ],
                ),
                const Divider(color: borderSubtle, height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Net Realized Yield:', style: TextStyle(color: Colors.white70, fontSize: 11)),
                    Text(
                      '${netDeltaAmount >= 0 ? '+' : ''}₹${_formatInr(netDeltaAmount)} (${netRealizedYield.toStringAsFixed(1)}%)',
                      style: GoogleFonts.robotoMono(
                        color: netRealizedYield >= 0 ? accentNeon : accentRose,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_selectedVehicle != 2) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withOpacity(0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.tune_rounded, color: Colors.amber, size: 15),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Friction Drag: ₹${_formatInr(frictionDragLoss)} lost in premiums & taxes. Gold required +${hurdleBreakeven.toStringAsFixed(1)}% rally just to achieve capital break-even.',
                      style: const TextStyle(color: Color(0xFFFDE68A), fontSize: 9.5, height: 1.25),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _metricBadge('SPOT 24K DELTA', '+${rawGoldReturnPercent.toStringAsFixed(1)}%', 'Paper Benchmark', accentCyan)),
              const SizedBox(width: 6),
              Expanded(child: _metricBadge('REAL YIELD (CPI)', '${vsInflationAlpha >= 0 ? '+' : ''}${vsInflationAlpha.toStringAsFixed(1)}%', 'Inflation Alpha', vsInflationAlpha >= 0 ? accentNeon : Colors.amber)),
              const SizedBox(width: 6),
              Expanded(child: _metricBadge('EQUITY ALPHA', '${vsNiftyAlpha >= 0 ? '+' : ''}${vsNiftyAlpha.toStringAsFixed(1)}%', 'vs Nifty 50', vsNiftyAlpha >= 0 ? accentNeon : accentRose)),
            ],
          ),
          const SizedBox(height: 10),
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
                  'Gold / Silver Ratio: ${goldSilverRatio.toStringAsFixed(1)}x',
                  style: const TextStyle(color: accentGold, fontSize: 9.5, fontWeight: FontWeight.bold),
                ),
                Text(
                  '1Y Base: ₹${_formatInr(_data.ago1y24k)} -> Current: ₹${_formatInr(_data.current24k)}',
                  style: GoogleFonts.robotoMono(color: textMuted, fontSize: 9.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _vehicleChip(int index, String label) {
    final isSelected = _selectedVehicle == index;
    return Expanded(
      child: InkWell(
        onTap: () => _onVehicleChanged(index),
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

  Widget _lotPreset(double g, String text) {
    final isSelected = _holdingGrams == g;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _holdingGrams = g);
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
          Text(val, style: GoogleFonts.robotoMono(color: col, fontSize: 12, fontWeight: FontWeight.w900)),
          Text(sub, style: const TextStyle(color: Colors.white38, fontSize: 7)),
        ],
      ),
    );
  }
}
