import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class MacroResearchDeskView extends StatefulWidget {
  const MacroResearchDeskView({super.key});

  @override
  State<MacroResearchDeskView> createState() => _MacroResearchDeskViewState();
}

class _MacroResearchDeskViewState extends State<MacroResearchDeskView> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic> _reportData = {};
  List<dynamic> _sectors = [];

  int _selectedFilterIndex = 0; // 0: All Sectors, 1: 🟢 Expanding, 2: 🔴 Contracting
  String _searchQuery = "";

  // Institutional Dark Design Palette
  static const Color kBgDark = Color(0xFF090D16);
  static const Color kCardBg = Color(0xFF131823);
  static const Color kSurfaceBg = Color(0xFF1A2232);
  static const Color kBorderDark = Color(0xFF263042);
  static const Color kGreenAccent = Color(0xFF00E676);
  static const Color kRedAccent = Color(0xFFFF5252);
  static const Color kMutedText = Color(0xFF8B949E);

  @override
  void initState() {
    super.initState();
    _loadReportJson();
  }

  Future<void> _loadReportJson() async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    // 🎯 Primary Direct GitHub + ISP Bypass CDN Endpoints
    final List<String> endpoints = [
      'https://raw.githubusercontent.com/zxcty54/stock-crypto-tracker/main/macro_research_report.json?ts=$timestamp',
      'https://cdn.jsdelivr.net/gh/zxcty54/stock-crypto-tracker@main/macro_research_report.json?ts=$timestamp',
      'https://cdn.staticaly.com/gh/zxcty54/stock-crypto-tracker/main/macro_research_report.json',
    ];

    for (final urlString in endpoints) {
      try {
        final response = await http.get(
          Uri.parse(urlString),
          headers: {'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 12));

        if (response.statusCode == 200) {
          final decoded = json.decode(utf8.decode(response.bodyBytes));
          if (mounted) {
            setState(() {
              _reportData = decoded;
              _sectors = decoded['sectors'] ?? [];
              _isLoading = false;
              _errorMessage = null;
            });
          }
          return;
        }
      } catch (e) {
        debugPrint("Endpoint failed ($urlString): $e");
      }
    }

    // 🎯 Tier 4: Offline Local Assets Fallback
    try {
      final localJson = await rootBundle.loadString('assets/data/macro_research_report.json');
      final decoded = json.decode(localJson);
      if (mounted) {
        setState(() {
          _reportData = decoded;
          _sectors = decoded['sectors'] ?? [];
          _isLoading = false;
          _errorMessage = null;
        });
        return;
      }
    } catch (e) {
      debugPrint("Local asset fallback failed: $e");
    }

    if (mounted) {
      setState(() {
        _errorMessage = "Network issue: Unable to fetch data from CDN endpoints.";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgDark,
      appBar: AppBar(
        backgroundColor: kBgDark,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                "MACRO MARGIN RADAR",
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 1),
            Text(
              "Cost Transmission & Margin Sensitivity",
              style: TextStyle(fontSize: 9.5, color: kMutedText.withOpacity(0.85)),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12, top: 12, bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: kSurfaceBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kBorderDark),
            ),
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: kGreenAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  "${_sectors.length} SECTORS",
                  style: const TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: kGreenAccent),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, color: kRedAccent, size: 44),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: kMutedText, fontSize: 13),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                  });
                  _loadReportJson();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kSurfaceBg,
                  side: const BorderSide(color: kBorderDark),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                child: const Text("Retry Connection", style: TextStyle(color: Colors.white)),
              )
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        _buildSearchAndFilters(),
        _buildTopNotice(),
        Expanded(
          child: _sectors.isEmpty
              ? const Center(
                  child: Text("No sectors available", style: TextStyle(color: kMutedText)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _sectors.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _sectors.length) {
                      return _buildSebiDisclaimerCard();
                    }
                    final sector = _sectors[index];
                    return _buildSectorCard(sector);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTopNotice() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1524),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1E2B3E)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.shield_outlined, color: kGreenAccent, size: 14),
          SizedBox(width: 7),
          Expanded(
            child: Text(
              "SEBI Statutory Notice: Sectoral macroeconomic research & raw material cost transmission analysis. Strictly educational; does not constitute investment advice or individual stock recommendations.",
              style: TextStyle(color: Colors.white70, fontSize: 8.5, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        children: [
          // Search Box
          Container(
            height: 42,
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kBorderDark),
            ),
            child: TextField(
              style: const TextStyle(fontSize: 13, color: Colors.white),
              onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
              decoration: const InputDecoration(
                hintText: "Search company symbol or sector...",
                hintStyle: TextStyle(fontSize: 12, color: kMutedText),
                prefixIcon: Icon(Icons.search, size: 18, color: kMutedText),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Filter Tabs
          Container(
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kBorderDark),
            ),
            child: Row(
              children: [
                _buildSegmentTab("All Sectors", 0),
                _buildSegmentTab("🟢 Expanding", 1),
                _buildSegmentTab("🔴 Contracting", 2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentTab(String title, int index) {
    final isSelected = _selectedFilterIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilterIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF238636) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : kMutedText,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectorCard(Map<String, dynamic> sector) {
    final sectorName = sector['sector_name'] ?? '';
    final allStocks = (sector['evaluated_stocks'] as List<dynamic>? ?? []);

    final filteredStocks = allStocks.where((s) {
      final sym = (s['symbol'] ?? '').toString().toLowerCase();
      final name = (s['company_name'] ?? '').toString().toLowerCase();
      final sName = sectorName.toLowerCase();

      final matchesSearch = _searchQuery.isEmpty ||
          sym.contains(_searchQuery) ||
          name.contains(_searchQuery) ||
          sName.contains(_searchQuery);

      if (!matchesSearch) return false;

      if (_selectedFilterIndex == 1) return s['margin_trajectory'] == "MARGIN_EXPANSION";
      if (_selectedFilterIndex == 2) return s['margin_trajectory'] == "MARGIN_CONTRACTION";
      return true;
    }).toList();

    if (filteredStocks.isEmpty) return const SizedBox.shrink();

    final expandingCount = allStocks.where((s) => s['margin_trajectory'] == "MARGIN_EXPANSION").length;
    final totalCount = allStocks.isNotEmpty ? allStocks.length : 1;
    final expandingRatio = expandingCount / totalCount;

    final delta = (sector['benchmark_1m_delta_pct'] ?? 0.0) as num;
    final isDeltaUp = delta >= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🎯 1. Sector Title (Full Width Layout - No Squeezing)
          Text(
            sectorName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),

          // 🎯 2. Commodity Driver Ribbon (Wrap Layout)
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: kSurfaceBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: kBorderDark),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt, size: 12, color: Colors.amberAccent),
                    const SizedBox(width: 4),
                    Text(
                      "${sector['benchmark_commodity']}: ${sector['benchmark_price']}",
                      style: const TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "${isDeltaUp ? '+' : ''}${delta.toStringAsFixed(1)}%",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDeltaUp ? kRedAccent : kGreenAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 🎯 3. Sector Macro Thesis
          Text(
            sector['sector_macro_thesis'] ?? '',
            style: const TextStyle(fontSize: 12, color: kMutedText, height: 1.4),
          ),
          const SizedBox(height: 12),

          // 🎯 4. Sector Trajectory Ratio Bar
          Row(
            children: [
              Text(
                "SECTOR TRAJECTORY RATIO ($expandingCount/$totalCount EXPANDING)",
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: kMutedText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 5,
              child: Row(
                children: [
                  Expanded(
                    flex: max(1, (expandingRatio * 100).toInt()),
                    child: Container(color: kGreenAccent),
                  ),
                  Expanded(
                    flex: max(1, ((1 - expandingRatio) * 100).toInt()),
                    child: Container(color: kRedAccent),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 🎯 5. Equities Cards
          ...filteredStocks.map((stock) => _buildStockVisualCard(stock)),
        ],
      ),
    );
  }

  Widget _buildStockVisualCard(Map<String, dynamic> stock) {
    final isExpanding = stock['margin_trajectory'] == "MARGIN_EXPANSION";
    final int bps = (stock['projected_opm_change_bps'] ?? 0) as int;
    final color = isExpanding ? kGreenAccent : kRedAccent;

    // Normalizing divergence bar (300 bps max ceiling)
    final double normalizedWidth = min(1.0, bps.abs() / 300.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kBgDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stock['symbol'] ?? '',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                    Text(
                      stock['company_name'] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10, color: kMutedText),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color.withOpacity(0.4)),
                ),
                child: Text(
                  "${bps > 0 ? '+' : ''}$bps bps",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Zero-Center Divergence Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("MARGIN CONTRACTION", style: TextStyle(fontSize: 8, color: kRedAccent, fontWeight: FontWeight.bold)),
                  const Text("BASE (0)", style: TextStyle(fontSize: 8, color: kMutedText)),
                  const Text("MARGIN EXPANSION", style: TextStyle(fontSize: 8, color: kGreenAccent, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 3),
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: kSurfaceBg,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Row(
                  children: [
                    // Contraction Left Half
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: FractionallySizedBox(
                          widthFactor: !isExpanding ? normalizedWidth : 0.0,
                          child: Container(
                            decoration: const BoxDecoration(
                              color: kRedAccent,
                              borderRadius: BorderRadius.horizontal(left: Radius.circular(3)),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Center Line
                    Container(width: 2, color: Colors.white38),
                    // Expansion Right Half
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: isExpanding ? normalizedWidth : 0.0,
                          child: Container(
                            decoration: const BoxDecoration(
                              color: kGreenAccent,
                              borderRadius: BorderRadius.horizontal(right: Radius.circular(3)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Operational Transmission Explanation
          Text(
            stock['operational_transmission_rationale'] ?? '',
            style: const TextStyle(fontSize: 11, color: Color(0xFFC9D1D9), height: 1.35),
          ),
          const SizedBox(height: 8),

          // Pricing Power & Transmission Details Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: kSurfaceBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: kBorderDark),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF090D16),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    "PRICING POWER: ${stock['pricing_power'] ?? 'MODERATE'}",
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      color: stock['pricing_power'] == 'HIGH' ? kGreenAccent : Colors.white70,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    stock['quarterly_ebitda_outlook'] ?? '',
                    style: const TextStyle(fontSize: 9.5, color: Colors.white70, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSebiDisclaimerCard() {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 24),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D131F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFB300).withOpacity(0.35)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.gavel_rounded, color: Color(0xFFFFB300), size: 15),
              SizedBox(width: 8),
              Text(
                "SEBI COMPLIANCE & STATUTORY DISCLAIMER",
                style: TextStyle(
                  color: Color(0xFFFFB300),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            "1. NOT SEBI REGISTERED: StockPulse and its developers are NOT registered with the Securities and Exchange Board of India (SEBI) as Research Analysts (RA) or Investment Advisers (IA).\n\n"
            "2. NO BUY / SELL CALLS OR TIPS: Margin projections (OPM bps, pricing power, commodity delta) are theoretical financial models solely for educational study. Nothing constitutes stock recommendations or financial advice.\n\n"
            "3. MARKET RISK: Corporate margins depend on several dynamic operational factors. Consult a SEBI registered investment advisor before taking any financial decision.",
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 10,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
