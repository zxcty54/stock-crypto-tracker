import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

class MacroResearchDeskView extends StatefulWidget {
  // 🎯 'const' constructor enabled - news_screen.dart mein 'const' se build fail nahi hoga
  const MacroResearchDeskView({super.key});

  @override
  State<MacroResearchDeskView> createState() => _MacroResearchDeskViewState();
}

class _MacroResearchDeskViewState extends State<MacroResearchDeskView> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic> _reportData = {};
  List<dynamic> _sectors = [];

  int _selectedFilterIndex = 0; // 0: All Sectors, 1: 🟢 Expanding Only, 2: 🔴 Contracting Only
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
    try {
      final jsonString = await rootBundle.loadString('assets/macro_research_report.json');
      final decoded = json.decode(jsonString);

      if (mounted) {
        setState(() {
          _reportData = decoded;
          _sectors = decoded['sectors'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to load report: $e";
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgDark,
      appBar: AppBar(
        backgroundColor: kBgDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "MACRO MARGIN RADAR",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
                color: Colors.white,
              ),
            ),
            Text(
              "Audited Balance Sheets vs Live Commodity Transmission",
              style: TextStyle(fontSize: 10, color: kMutedText),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 12, bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                const SizedBox(width: 6),
                const Text(
                  "17 SECTORS",
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
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
              const Icon(Icons.error_outline, color: kRedAccent, size: 40),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: kMutedText, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                  });
                  _loadReportJson();
                },
                style: ElevatedButton.styleFrom(backgroundColor: kSurfaceBg),
                child: const Text("Retry", style: TextStyle(color: Colors.white)),
              )
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        _buildSearchAndFilters(),
        Expanded(
          child: _sectors.isEmpty
              ? const Center(
                  child: Text("No sectors available", style: TextStyle(color: kMutedText)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _sectors.length,
                  itemBuilder: (context, index) {
                    final sector = _sectors[index];
                    return _buildSectorCard(sector);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        children: [
          // Search Input
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
          // 3-Way Segment Tabs
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

    // Filter stocks by query & expanding/contracting intent
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

    // Trajectory Ratio
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
          // Sector Title + Commodity Driver Pill
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  sectorName,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: kSurfaceBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: kBorderDark),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bolt, size: 12, color: Colors.amberAccent),
                    const SizedBox(width: 3),
                    Text(
                      "${sector['benchmark_commodity']}: ${sector['benchmark_price']}",
                      style: const TextStyle(fontSize: 10, color: Colors.white70),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      "${isDeltaUp ? '+' : ''}${delta.toStringAsFixed(1)}%",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isDeltaUp ? kRedAccent : kGreenAccent,
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 8),

          // Sector Macro Thesis
          Text(
            sector['sector_macro_thesis'] ?? '',
            style: const TextStyle(fontSize: 11, color: kMutedText, height: 1.4),
          ),
          const SizedBox(height: 12),

          // Sector Trajectory Ratio Bar
          Row(
            children: [
              Text(
                "SECTOR TRAJECTORY RATIO ($expandingCount/$totalCount EXPANDING)",
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: kMutedText),
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

          // Equities List
          ...filteredStocks.map((stock) => _buildStockVisualCard(stock)),
        ],
      ),
    );
  }

  Widget _buildStockVisualCard(Map<String, dynamic> stock) {
    final isExpanding = stock['margin_trajectory'] == "MARGIN_EXPANSION";
    final int bps = (stock['projected_opm_change_bps'] ?? 0) as int;
    final color = isExpanding ? kGreenAccent : kRedAccent;

    // Normalizing divergence bar (300 bps baseline ceiling)
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
          // Header: Symbol, Name, BPS Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stock['symbol'] ?? '',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                  Text(
                    stock['company_name'] ?? '',
                    style: const TextStyle(fontSize: 10, color: kMutedText),
                  ),
                ],
              ),
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
                    // Negative / Contraction Half
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
                    // Center Zero Line
                    Container(width: 2, color: Colors.white38),
                    // Positive / Expansion Half
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
            style: const TextStyle(fontSize: 11, color: Color(0xFFC9D1D9), height: 1.3),
          ),
          const SizedBox(height: 8),

          // Pricing Power Badge + Quarterly Outlook
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: kSurfaceBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "PRICING POWER: ${stock['pricing_power'] ?? 'MODERATE'}",
                  style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white70),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Outlook: ${stock['quarterly_ebitda_outlook'] ?? ''}",
                  style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: color.withOpacity(0.9)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
