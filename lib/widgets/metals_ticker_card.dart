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
      symbol: json['symbol']?.toString() ?? '',
      name: name,
      priceUsd: (json['price'] as num?)?.toDouble() ?? 0.0,
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
  int _selectedTabIndex = 0; // 0: Metals, 1: Forex
  bool _isLoading = true;
  Timer? _refreshTimer;

  // Default / Fallback Benchmark Rates (Incase network latency ho)
  final double _usdInrRate = 83.54;

  late CommodityItem _gold;
  late CommodityItem _silver;
  late CommodityItem _copper;
  late CommodityItem _platinum;
  late List<ForexRate> _forexList;

  @override
  void initState() {
    super.initState();
    _initDefaults();
    _fetchMarketData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 45), (_) => _fetchMarketData());
  }

  void _initDefaults() {
    _gold = CommodityItem(symbol: 'XAU', name: 'GOLD 24K', priceUsd: 2650.40, unitUsd: '/ oz');
    _silver = CommodityItem(symbol: 'XAG', name: 'SILVER', priceUsd: 31.85, unitUsd: '/ oz');
    _copper = CommodityItem(symbol: 'HG', name: 'COPPER', priceUsd: 4.45, unitUsd: '/ lb');
    _platinum = CommodityItem(symbol: 'XPT', name: 'PLATINUM', priceUsd: 985.00, unitUsd: '/ oz');

    _forexList = [
      ForexRate(code: 'USD', name: 'US Dollar', flag: '🇺🇸', inrRate: _usdInrRate),
      ForexRate(code: 'EUR', name: 'Euro', flag: '🇪🇺', inrRate: _usdInrRate * 1.085),
      ForexRate(code: 'GBP', name: 'British Pound', flag: '🇬🇧', inrRate: _usdInrRate * 1.282),
      ForexRate(code: 'AED', name: 'UAE Dirham', flag: '🇦🇪', inrRate: _usdInrRate / 3.6725),
      ForexRate(code: 'JPY', name: 'Japanese Yen (100)', flag: '🇯🇵', inrRate: (_usdInrRate / 155.2) * 100),
      ForexRate(code: 'CAD', name: 'Canadian Dollar', flag: '🇨🇦', inrRate: _usdInrRate * 0.732),
      ForexRate(code: 'AUD', name: 'Australian Dollar', flag: '🇦🇺', inrRate: _usdInrRate * 0.665),
      ForexRate(code: 'SGD', name: 'Singapore Dollar', flag: '🇸🇬', inrRate: _usdInrRate * 0.745),
    ];
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // Safe HTTP GET with Browser Headers to bypass bot blocks
  Future<dynamic> _safeGet(String url) async {
    try {
      final res = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        },
      ).timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (_) {}
    return null;
  }

  Future<void> _fetchMarketData() async {
    try {
      final goldData = await _safeGet('https://api.gold-api.com/price/XAU');
      final silverData = await _safeGet('https://api.gold-api.com/price/XAG');
      final copperData = await _safeGet('https://api.gold-api.com/price/HG');
      final platData = await _safeGet('https://api.gold-api.com/price/XPT');

      if (mounted) {
        setState(() {
          if (goldData != null && goldData['price'] != null) {
            _gold = CommodityItem.fromJson(goldData, 'GOLD 24K', '/ oz');
          }
          if (silverData != null && silverData['price'] != null) {
            _silver = CommodityItem.fromJson(silverData, 'SILVER', '/ oz');
          }
          if (copperData != null && copperData['price'] != null) {
            _copper = CommodityItem.fromJson(copperData, 'COPPER', '/ lb');
          }
          if (platData != null && platData['price'] != null) {
            _platinum = CommodityItem.fromJson(platData, 'PLATINUM', '/ oz');
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Conversions for Indian Domestic Reference
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
          // Selector Chips (Metals vs Forex)
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
                  setState(() => _isLoading = true);
                  _fetchMarketData();
                },
                child: Row(
                  children: [
                    if (_isLoading)
                      const SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF00F0FF)),
                      )
                    else
                      const Icon(Icons.sync_rounded, color: Color(0xFF00F0FF), size: 14),
                    const SizedBox(width: 4),
                    const Text(
                      'Live',
                      style: TextStyle(color: Color(0xFF00F0FF), fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Active Tab Content
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

  Widget _buildMetalsGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _metalCard(
                name: _gold.name,
                symbol: _gold.symbol,
                usdPrice: _gold.priceUsd,
                unitUsd: _gold.unitUsd,
                inrPrice: _calcGoldPer10g(_gold.priceUsd),
                inrUnit: '/ 10g (Est)',
                accentColor: const Color(0xFFFFD700),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _metalCard(
                name: _silver.name,
                symbol: _silver.symbol,
                usdPrice: _silver.priceUsd,
                unitUsd: _silver.unitUsd,
                inrPrice: _calcSilverPerKg(_silver.priceUsd),
                inrUnit: '/ 1 Kg (Est)',
                accentColor: const Color(0xFFE0E0E0),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _metalCard(
                name: _copper.name,
                symbol: _copper.symbol,
                usdPrice: _copper.priceUsd,
                unitUsd: _copper.unitUsd,
                inrPrice: _calcCopperPerKg(_copper.priceUsd),
                inrUnit: '/ 1 Kg (Est)',
                accentColor: const Color(0xFFFF7A45),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _metalCard(
                name: _platinum.name,
                symbol: _platinum.symbol,
                usdPrice: _platinum.priceUsd,
                unitUsd: _platinum.unitUsd,
                inrPrice: _calcPlatPer10g(_platinum.priceUsd),
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
                  fontSize: 13.5,
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
              Expanded(
                child: Text(
                  inrUnit,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildForexGrid() {
    return GridView.builder(
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
    );
  }
}
