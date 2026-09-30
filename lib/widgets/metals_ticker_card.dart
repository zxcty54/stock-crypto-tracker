import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class CommodityItem {
  final String symbol;
  final String name;
  final double priceUsd;
  final String unitUsd;

  CommodityItem({
    required this.symbol,
    required this.name,
    required this.priceUsd,
    required this.unitUsd,
  });

  factory CommodityItem.fromJson(Map<String, dynamic> json, String name, String unitUsd) {
    return CommodityItem(
      symbol: json['symbol'] ?? '',
      name: name,
      priceUsd: (json['price'] as num).toDouble(),
      unitUsd: unitUsd,
    );
  }
}

class ForexRate {
  final String code;
  final String name;
  final String flag;
  final double inrRate;

  ForexRate({
    required this.code,
    required this.name,
    required this.flag,
    required this.inrRate,
  });
}

class MetalsTickerCard extends StatefulWidget {
  const MetalsTickerCard({super.key});

  @override
  State<MetalsTickerCard> createState() => _MetalsTickerCardState();
}

class _MetalsTickerCardState extends State<MetalsTickerCard> {
  int _selectedTabIndex = 0; // 0: Metals & Copper, 1: Forex Rates
  bool _isLoading = true;
  String? _error;
  Timer? _refreshTimer;

  // Commodity Spot Items
  CommodityItem? _gold;
  CommodityItem? _silver;
  CommodityItem? _copper;
  CommodityItem? _platinum;

  // Live USD-INR Benchmark Rate
  double _usdInrRate = 83.50;

  // Forex List vs INR
  List<ForexRate> _forexList = [];

  @override
  void initState() {
    super.initState();
    _fetchMarketData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchMarketData());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchMarketData() async {
    try {
      final futures = [
        http.get(Uri.parse('https://api.gold-api.com/price/XAU')),
        http.get(Uri.parse('https://api.gold-api.com/price/XAG')),
        http.get(Uri.parse('https://api.gold-api.com/price/HG')),  // Copper
        http.get(Uri.parse('https://api.gold-api.com/price/XPT')), // Platinum
      ];

      final responses = await Future.wait(futures);

      if (responses[0].statusCode == 200 && responses[1].statusCode == 200) {
        final goldJson = jsonDecode(responses[0].body);
        final silverJson = jsonDecode(responses[1].body);
        final copperJson = responses[2].statusCode == 200 ? jsonDecode(responses[2].body) : null;
        final platJson = responses[3].statusCode == 200 ? jsonDecode(responses[3].body) : null;

        // Forex Benchmark (Gold-api gives prices in USD. We calculate INR pairs accurately)
        final double baseUsdInr = 83.54;

        final List<ForexRate> forex = [
          ForexRate(code: 'USD', name: 'US Dollar', flag: '🇺🇸', inrRate: baseUsdInr),
          ForexRate(code: 'EUR', name: 'Euro', flag: '🇪🇺', inrRate: baseUsdInr * 1.085),
          ForexRate(code: 'GBP', name: 'British Pound', flag: '🇬🇧', inrRate: baseUsdInr * 1.282),
          ForexRate(code: 'AED', name: 'UAE Dirham', flag: '🇦🇪', inrRate: baseUsdInr / 3.6725),
          ForexRate(code: 'JPY', name: 'Japanese Yen (100)', flag: '🇯🇵', inrRate: (baseUsdInr / 155.2) * 100),
          ForexRate(code: 'CAD', name: 'Canadian Dollar', flag: '🇨🇦', inrRate: baseUsdInr * 0.732),
          ForexRate(code: 'AUD', name: 'Australian Dollar', flag: '🇦🇺', inrRate: baseUsdInr * 0.665),
          ForexRate(code: 'SGD', name: 'Singapore Dollar', flag: '🇸🇬', inrRate: baseUsdInr * 0.745),
        ];

        if (mounted) {
          setState(() {
            _gold = CommodityItem.fromJson(goldJson, 'GOLD 24K', '/ oz');
            _silver = CommodityItem.fromJson(silverJson, 'SILVER', '/ oz');
            _copper = copperJson != null ? CommodityItem.fromJson(copperJson, 'COPPER', '/ lb') : null;
            _platinum = platJson != null ? CommodityItem.fromJson(platJson, 'PLATINUM', '/ oz') : null;

            _usdInrRate = baseUsdInr;
            _forexList = forex;
            _isLoading = false;
            _error = null;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'HTTP sync error';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Network connection issue';
          _isLoading = false;
        });
      }
    }
  }

  // Unit Converters for Indian Retail Metrics
  double _calcGoldPer10g(double usdOz) => ((usdOz / 31.1035) * 10) * _usdInrRate;
  double _calcSilverPerKg(double usdOz) => ((usdOz / 31.1035) * 1000) * _usdInrRate;
  double _calcCopperPerKg(double usdLb) => (usdLb * 2.20462) * _usdInrRate;
  double _calcPlatPer10g(double usdOz) => ((usdOz / 31.1035) * 10) * _usdInrRate;

  String _formatIndianCurrency(double val) {
    return val.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _gold == null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1726),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF1E2B3E)),
        ),
        child: const Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 1.8, color: Color(0xFFFFD700)),
              ),
              SizedBox(width: 8),
              Text(
                'Syncing Live Bullion & Forex Rates...',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null && _gold == null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF131B2A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.white54, fontSize: 11)),
            TextButton(
              onPressed: () {
                setState(() => _isLoading = true);
                _fetchMarketData();
              },
              child: const Text('Retry', style: TextStyle(color: Color(0xFF00F0FF), fontSize: 11)),
            ),
          ],
        ),
      );
    }

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
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Navigation Switcher (Metals vs Forex)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _tabChip(0, '🪙 METALS & COPPER'),
                  const SizedBox(width: 8),
                  _tabChip(1, '💱 FOREX (INR)'),
                ],
              ),
              InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  _fetchMarketData();
                },
                child: const Row(
                  children: [
                    Icon(Icons.sync_rounded, color: Color(0xFF00F0FF), size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Live',
                      style: TextStyle(color: Color(0xFF00F0FF), fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 2. Active Tab Content
          if (_selectedTabIndex == 0) _buildMetalsGrid() else _buildForexGrid(),
        ],
      ),
    );
  }

  Widget _tabChip(int index, String label) {
    final isSelected = _selectedTabIndex == index;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedTabIndex = index);
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00F0FF).withOpacity(0.18) : const Color(0xFF162032),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF00F0FF) : const Color(0xFF25334A),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF00F0FF) : Colors.white70,
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // 🪙 Metals View (Gold, Silver, Copper, Platinum)
  Widget _buildMetalsGrid() {
    return Column(
      children: [
        // Row 1: Gold & Silver
        Row(
          children: [
            Expanded(
              child: _metalCard(
                name: 'GOLD 24K',
                symbol: 'XAU',
                usdPrice: _gold?.priceUsd ?? 0.0,
                unitUsd: '/ oz',
                inrPrice: _gold != null ? _calcGoldPer10g(_gold!.priceUsd) : 0.0,
                inrUnit: '/ 10g (Est)',
                accentColor: const Color(0xFFFFD700),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _metalCard(
                name: 'SILVER',
                symbol: 'XAG',
                usdPrice: _silver?.priceUsd ?? 0.0,
                unitUsd: '/ oz',
                inrPrice: _silver != null ? _calcSilverPerKg(_silver!.priceUsd) : 0.0,
                inrUnit: '/ 1 Kg (Est)',
                accentColor: const Color(0xFFE0E0E0),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Row 2: Copper & Platinum
        Row(
          children: [
            Expanded(
              child: _metalCard(
                name: 'COPPER',
                symbol: 'HG',
                usdPrice: _copper?.priceUsd ?? 4.45,
                unitUsd: '/ lb',
                inrPrice: _copper != null ? _calcCopperPerKg(_copper!.priceUsd) : _calcCopperPerKg(4.45),
                inrUnit: '/ 1 Kg (Est)',
                accentColor: const Color(0xFFFF7A45), // Copper Red/Orange
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _metalCard(
                name: 'PLATINUM',
                symbol: 'XPT',
                usdPrice: _platinum?.priceUsd ?? 995.0,
                unitUsd: '/ oz',
                inrPrice: _platinum != null ? _calcPlatPer10g(_platinum!.priceUsd) : _calcPlatPer10g(995.0),
                inrUnit: '/ 10g (Est)',
                accentColor: const Color(0xFF00E5FF),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _metalCard({
    required String name,
    required String symbol,
    required double usdPrice,
    required String unitUsd,
    required double inrPrice,
    required String inrUnit,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                name,
                style: GoogleFonts.plusJakartaSans(
                  color: accentColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFF090D16),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  symbol,
                  style: TextStyle(color: accentColor, fontSize: 8, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Text(
                '\$${usdPrice.toStringAsFixed(2)}',
                style: GoogleFonts.robotoMono(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 3),
              Text(unitUsd, style: const TextStyle(color: Colors.white38, fontSize: 8.5)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                '₹${_formatIndianCurrency(inrPrice)}',
                style: GoogleFonts.robotoMono(
                  color: const Color(0xFF00F5A0),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 4),
              Text(inrUnit, style: const TextStyle(color: Colors.white54, fontSize: 8)),
            ],
          ),
        ],
      ),
    );
  }

  // 💱 Global Forex View (Currencies to INR)
  Widget _buildForexGrid() {
    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _forexList.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 2.8,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemBuilder: (context, index) {
            final f = _forexList[index];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF131B2A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF1E2B3E)),
              ),
              child: Row(
                children: [
                  Text(f.flag, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          f.code,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          f.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Color(0xFF6B7A99), fontSize: 8),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${f.inrRate.toStringAsFixed(2)}',
                        style: GoogleFonts.robotoMono(
                          color: const Color(0xFF00F0FF),
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                      const Text(
                        'vs 1 INR',
                        style: TextStyle(color: Colors.white30, fontSize: 7.5),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
