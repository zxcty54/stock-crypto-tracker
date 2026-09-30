import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class IbjaRates {
  final double rate24k;
  final double rate22k;
  final double rate18k;
  final String updatedAt;

  IbjaRates({
    required this.rate24k,
    required this.rate22k,
    required this.rate18k,
    required this.updatedAt,
  });

  factory IbjaRates.fromJson(Map<String, dynamic> json) {
    final rates = json['rates_per_10g'] as Map<String, dynamic>? ?? {};
    return IbjaRates(
      rate24k: (rates['24k'] as num?)?.toDouble() ?? 76150.0,
      rate22k: (rates['22k'] as num?)?.toDouble() ?? 69804.17,
      rate18k: (rates['18k'] as num?)?.toDouble() ?? 57112.5,
      updatedAt: json['updated_at']?.toString() ?? 'Latest Benchmark',
    );
  }
}

class IbjaRetailCalculatorCard extends StatefulWidget {
  const IbjaRetailCalculatorCard({super.key});

  @override
  State<IbjaRetailCalculatorCard> createState() => _IbjaRetailCalculatorCardState();
}

class _IbjaRetailCalculatorCardState extends State<IbjaRetailCalculatorCard> {
  final String _ibjaUrl =
      'https://fastly.jsdelivr.net/gh/zxcty54/stock-crypto-tracker@main/ibja_rates.json';

  IbjaRates _rates = IbjaRates(
    rate24k: 76150.0,
    rate22k: 69804.17,
    rate18k: 57112.5,
    updatedAt: 'Live Benchmark',
  );

  bool _isLoading = true;
  int _selectedKarat = 22; // 24, 22, 18
  double _weightInGrams = 10.0;
  double _makingChargePercent = 12.0; // 2.5% for coin, 8-22% for jewelry
  bool _isCoin = false;
  String _selectedCity = 'Mumbai';

  final Map<String, double> _citySpread = {
    'Mumbai': 0.0,
    'Delhi': 0.25,
    'Patna': 0.60,
    'Chennai': 0.45,
    'Kolkata': 0.35,
    'Bengaluru': 0.30,
    'Ahmedabad': 0.15,
  };

  @override
  void initState() {
    super.initState();
    _fetchIbjaData();
  }

  Future<void> _fetchIbjaData() async {
    try {
      final res = await http.get(
        Uri.parse('$_ibjaUrl?ts=${DateTime.now().millisecondsSinceEpoch}'),
        headers: {'Cache-Control': 'no-cache'},
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _rates = IbjaRates.fromJson(data);
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

  double _getBase10gRate() {
    switch (_selectedKarat) {
      case 24:
        return _rates.rate24k;
      case 22:
        return _rates.rate22k;
      case 18:
        return _rates.rate18k;
      default:
        return _rates.rate22k;
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
    final double raw10gBase = _getBase10gRate();
    final double cityMultiplier = 1 + ((_citySpread[_selectedCity] ?? 0.0) / 100);
    final double cityAdjustedPerGram = (raw10gBase / 10) * cityMultiplier;

    // Metal Base Value
    final double metalBaseCost = cityAdjustedPerGram * _weightInGrams;

    // Making Charges: Coin 2.5%, Jewelry as selected
    final double appliedMakingPercent = _isCoin ? 2.5 : _makingChargePercent;
    final double makingAmount = metalBaseCost * (appliedMakingPercent / 100);

    // GST Rules: 3% on metal, 5% on making charges
    final double gstMetal = metalBaseCost * 0.03;
    final double gstMaking = makingAmount * 0.05;
    final double totalGst = gstMetal + gstMaking;

    // Final Counter Billing
    final double finalCounterBill = metalBaseCost + makingAmount + totalGst;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1726),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E2B3E), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.4)),
                    ),
                    child: Text(
                      'IBJA BENCHMARK',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFFFD700),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _rates.updatedAt.contains('IST') ? 'Synced' : _rates.updatedAt,
                    style: const TextStyle(color: Color(0xFF6B7A99), fontSize: 9.5),
                  ),
                ],
              ),
              Row(
                children: [
                  _modeButton('JEWELRY', !_isCoin, () {
                    setState(() {
                      _isCoin = false;
                      _selectedKarat = 22;
                    });
                  }),
                  const SizedBox(width: 4),
                  _modeButton('COIN/BAR', _isCoin, () {
                    setState(() {
                      _isCoin = true;
                      _selectedKarat = 24;
                    });
                  }),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 2. City Selector & Karat Switcher
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF162032),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF25334A)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCity,
                    dropdownColor: const Color(0xFF0F1726),
                    style: const TextStyle(
                      color: Color(0xFF00F0FF),
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                    ),
                    items: _citySpread.keys.map((city) {
                      return DropdownMenuItem(value: city, child: Text(city));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedCity = val);
                      }
                    },
                  ),
                ),
              ),
              Row(
                children: [24, 22, 18].map((karat) {
                  final isSelected = _selectedKarat == karat;
                  return InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _selectedKarat = karat;
                        if (karat == 24) _isCoin = true;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFFFD700) : const Color(0xFF162032),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${karat}K',
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.white70,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 3. Weight Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Weight: ${_weightInGrams.toStringAsFixed(1)}g',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              Text(
                'Rate: ₹${_formatInr(cityAdjustedPerGram * 10)} / 10g',
                style: const TextStyle(color: Color(0xFF00F0FF), fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              trackHeight: 3,
            ),
            child: Slider(
              value: _weightInGrams,
              min: 1.0,
              max: 50.0,
              divisions: 49,
              activeColor: const Color(0xFF00F0FF),
              inactiveColor: const Color(0xFF1E2B3E),
              onChanged: (val) => setState(() => _weightInGrams = val),
            ),
          ),

          // 4. Making Charge Control (Jewelry ke liye)
          if (!_isCoin) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Making Charges (Shop Markup):',
                  style: TextStyle(color: Colors.white70, fontSize: 10.5),
                ),
                Text(
                  '${_makingChargePercent.toInt()}% (₹${_formatInr(makingAmount)})',
                  style: const TextStyle(color: Color(0xFFFF9800), fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                trackHeight: 3,
              ),
              child: Slider(
                value: _makingChargePercent,
                min: 6.0,
                max: 25.0,
                divisions: 19,
                activeColor: const Color(0xFFFF9800),
                inactiveColor: const Color(0xFF1E2B3E),
                onChanged: (val) => setState(() => _makingChargePercent = val),
              ),
            ),
          ],

          const SizedBox(height: 6),

          // 5. Final Invoice Breakdown Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF141C2B),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF1E2B3E)),
            ),
            child: Column(
              children: [
                _invoiceRow('Base Gold Value (${_weightInGrams.toStringAsFixed(1)}g)', '₹${_formatInr(metalBaseCost)}'),
                const SizedBox(height: 4),
                _invoiceRow(
                  _isCoin ? 'Minting / Coin Charge (2.5%)' : 'Making Charges (${appliedMakingPercent.toInt()}%)',
                  '₹${_formatInr(makingAmount)}',
                  color: const Color(0xFFFF9800),
                ),
                const SizedBox(height: 4),
                _invoiceRow('GST (3% Metal + 5% Making)', '₹${_formatInr(totalGst)}', color: Colors.white54),
                const Divider(color: Color(0xFF25334A), height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Estimated Counter Bill:',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'In $_selectedCity showroom',
                          style: const TextStyle(color: Color(0xFF6B7A99), fontSize: 8.5),
                        ),
                      ],
                    ),
                    Text(
                      '₹${_formatInr(finalCounterBill)}',
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
          ),
        ],
      ),
    );
  }

  Widget _modeButton(String title, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00F0FF).withOpacity(0.18) : const Color(0xFF162032),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? const Color(0xFF00F0FF) : const Color(0xFF25334A)),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? const Color(0xFF00F0FF) : Colors.white54,
            fontSize: 8.5,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _invoiceRow(String label, String value, {Color color = Colors.white70}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
        Text(value, style: GoogleFonts.robotoMono(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
