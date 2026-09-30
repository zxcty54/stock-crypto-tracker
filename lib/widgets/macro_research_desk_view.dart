import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ---------------- DATA MODELS ----------------
class ImpactedStock {
  final String symbol;
  final String companyName;
  final String sector;
  final String impactType; // POSITIVE / NEGATIVE
  final String marginImpactBps;
  final int baselineBpsValue;
  final String rationale;
  final String? businessImpact;
  final int directExposurePct;

  const ImpactedStock({
    required this.symbol,
    required this.companyName,
    required this.sector,
    required this.impactType,
    required this.marginImpactBps,
    required this.baselineBpsValue,
    required this.rationale,
    this.businessImpact,
    this.directExposurePct = 50,
  });

  factory ImpactedStock.fromJson(Map<String, dynamic> json) {
    final rawBpsString = json['margin_impact_bps']?.toString() ?? '0';
    final cleaned = rawBpsString.replaceAll(RegExp(r'[^0-9\-]'), '');
    final parsedBps = int.tryParse(cleaned) ?? 0;

    return ImpactedStock(
      symbol: json['symbol'] ?? '',
      companyName: json['company_name'] ?? '',
      sector: json['sector'] ?? '',
      impactType: (json['impact_type'] ?? 'POSITIVE').toString().toUpperCase(),
      marginImpactBps: rawBpsString,
      baselineBpsValue: parsedBps,
      rationale: json['rationale'] ?? '',
      businessImpact: json['business_impact'],
      directExposurePct: json['direct_exposure_pct'] ?? (json['impact_type'] == 'POSITIVE' ? 75 : 50),
    );
  }
}

class MacroReportItem {
  final String commodityName;
  final String unit;
  final double currentPrice;
  final Map<String, dynamic> periodChanges;
  final String macroHeadline;
  final String forwardThesis;
  final String marginTrajectory;
  final String importContext;
  final String keyRisk;
  final List<ImpactedStock> impactedStocks;
  final double fiftyTwoWeekLow;
  final double fiftyTwoWeekHigh;
  final int transmissionLagDays;

  const MacroReportItem({
    required this.commodityName,
    required this.unit,
    required this.currentPrice,
    required this.periodChanges,
    required this.macroHeadline,
    required this.forwardThesis,
    required this.marginTrajectory,
    required this.importContext,
    required this.keyRisk,
    required this.impactedStocks,
    required this.fiftyTwoWeekLow,
    required this.fiftyTwoWeekHigh,
    this.transmissionLagDays = 60,
  });

  factory MacroReportItem.fromJson(Map<String, dynamic> json) {
    final price = (json['current_price'] as num?)?.toDouble() ?? 0.0;
    return MacroReportItem(
      commodityName: json['commodity_name'] ?? '',
      unit: json['unit'] ?? '',
      currentPrice: price,
      periodChanges: json['period_changes'] ?? {},
      macroHeadline: json['macro_headline'] ?? '',
      forwardThesis: json['forward_thesis'] ?? '',
      marginTrajectory: json['margin_trajectory'] ?? 'NEUTRAL',
      importContext: json['import_context'] ?? '',
      keyRisk: json['key_risk'] ?? '',
      fiftyTwoWeekLow: (json['fifty_two_week_low'] as num?)?.toDouble() ?? (price * 0.78),
      fiftyTwoWeekHigh: (json['fifty_two_week_high'] as num?)?.toDouble() ?? (price * 1.22),
      transmissionLagDays: json['transmission_lag_days'] ?? 60,
      impactedStocks: (json['impacted_stocks'] as List? ?? [])
          .map((e) => ImpactedStock.fromJson(e))
          .toList(),
    );
  }
}

// ---------------- MAIN WIDGET SCREEN ----------------
class MacroResearchDeskView extends StatefulWidget {
  final bool isDarkMode;
  const MacroResearchDeskView({super.key, this.isDarkMode = true});

  @override
  State<MacroResearchDeskView> createState() => _MacroResearchDeskViewState();
}

class _MacroResearchDeskViewState extends State<MacroResearchDeskView> {
  final String _jsonUrl =
      'https://raw.githubusercontent.com/zxcty54/stock-crypto-tracker/refs/heads/main/macro_research_report.json';

  List<MacroReportItem> _reports = [];
  String _lastUpdatedAt = '';
  int _selectedCommodityIndex = 0;
  bool _isLoading = true;
  String? _errorMessage;

  // Screener & Live Simulator State
  String _searchQuery = '';
  String _impactFilter = 'ALL'; // ALL, POSITIVE, NEGATIVE
  double _priceSimulationOffset = 0.0; // -20% to +20%

  // High-Contrast Terminal Styling
  static const Color bgDark = Color(0xFF090D16);
  static const Color surfaceCard = Color(0xFF131B2A);
  static const Color borderSubtle = Color(0xFF202C42);
  static const Color accentNeonGreen = Color(0xFF00E676);
  static const Color accentCyan = Color(0xFF00E5FF);
  static const Color accentFlame = Color(0xFFFF9100);
  static const Color textMuted = Color(0xFF94A3B8);

  @override
  void initState() {
    super.initState();
    _fetchAiResearchData();
  }

  Future<void> _fetchAiResearchData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final urlWithTs = '$_jsonUrl?ts=${DateTime.now().millisecondsSinceEpoch}';
      final response = await http.get(Uri.parse(urlWithTs)).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final Map<String, dynamic> decoded = jsonDecode(response.body);
        final List<dynamic> reportsList = decoded['reports'] ?? [];

        if (mounted) {
          setState(() {
            _lastUpdatedAt = decoded['updated_at'] ?? '';
            _reports = reportsList.map((e) => MacroReportItem.fromJson(e)).toList();
            if (_selectedCommodityIndex >= _reports.length) {
              _selectedCommodityIndex = 0;
            }
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Failed to load report (HTTP ${response.statusCode})';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Network Error: Check internet connection or JSON sync';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: bgDark,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: accentCyan),
              SizedBox(height: 16),
              Text(
                "Syncing Institutional Macro Radar...",
                style: TextStyle(color: textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null || _reports.isEmpty) {
      return Scaffold(
        backgroundColor: bgDark,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, color: Colors.redAccent, size: 48),
                const SizedBox(height: 12),
                Text(
                  _errorMessage ?? "No research reports available",
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: surfaceCard),
                  onPressed: _fetchAiResearchData,
                  child: const Text("Retry Sync", style: TextStyle(color: accentCyan)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final activeItem = _reports[_selectedCommodityIndex];

    final filteredStocks = activeItem.impactedStocks.where((s) {
      final matchesSearch = _searchQuery.isEmpty ||
          s.symbol.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.companyName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.sector.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesImpact = _impactFilter == 'ALL' || s.impactType == _impactFilter;
      return matchesSearch && matchesImpact;
    }).toList();

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: surfaceCard,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Text(
                  "MACRO MARGIN RADAR",
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 1.5,
                    color: accentCyan,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 6),
                Text(
                  "PRO V2",
                  style: TextStyle(
                    fontSize: 9,
                    color: accentNeonGreen,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            Text(
              _lastUpdatedAt.isNotEmpty ? "Synced: $_lastUpdatedAt" : "Corporate Input Cost Transmission",
              style: const TextStyle(fontSize: 11, color: textMuted),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 22),
            onPressed: _fetchAiResearchData,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: accentCyan,
        backgroundColor: surfaceCard,
        onRefresh: _fetchAiResearchData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCommodityRibbon(),
              const SizedBox(height: 16),
              _buildHeroPriceAndRangeCard(activeItem),
              const SizedBox(height: 14),
              _buildTransmissionPipeline(activeItem),
              const SizedBox(height: 14),
              _buildAiForecastDeck(activeItem),
              const SizedBox(height: 14),
              _buildSensitivitySimulator(activeItem),
              const SizedBox(height: 22),
              _buildScreenerHeader(filteredStocks.length),
              const SizedBox(height: 12),
              _buildScreenerControls(),
              const SizedBox(height: 14),
              _buildEquitiesList(filteredStocks),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  /// 1. Commodity Selector Ribbon
  Widget _buildCommodityRibbon() {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _reports.length,
        itemBuilder: (context, idx) {
          final isSelected = idx == _selectedCommodityIndex;
          final item = _reports[idx];
          final delta1M = (item.periodChanges['1M'] as num?)?.toDouble() ?? 0.0;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCommodityIndex = idx;
                _priceSimulationOffset = 0.0;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF223048) : surfaceCard,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isSelected ? accentCyan : borderSubtle,
                  width: isSelected ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Text(
                    item.commodityName,
                    style: TextStyle(
                      color: isSelected ? Colors.white : textMuted,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: (delta1M >= 0 ? accentNeonGreen : Colors.redAccent).withAlpha(40),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      "${delta1M >= 0 ? '+' : ''}${delta1M.toStringAsFixed(1)}%",
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        color: delta1M >= 0 ? accentNeonGreen : Colors.redAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 2. Hero Price + Real Dynamic 52-Week Range Card (Overlap-Proof)
  Widget _buildHeroPriceAndRangeCard(MacroReportItem item) {
    final isContracting = item.marginTrajectory.toUpperCase() == 'CONTRACTING';
    final badgeColor = isContracting ? Colors.redAccent : accentNeonGreen;

    final effectivePrice = item.currentPrice * (1 + (_priceSimulationOffset / 100));
    final range = item.fiftyTwoWeekHigh - item.fiftyTwoWeekLow;
    final position = range > 0
        ? ((effectivePrice - item.fiftyTwoWeekLow) / range).clamp(0.0, 1.0)
        : 0.5;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.commodityName,
                      style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    const Text("Direct Corporate Input Cost Radar", style: TextStyle(color: textMuted, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withAlpha(40),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: badgeColor.withAlpha(80)),
                ),
                child: Text(
                  "MARGINS: ${item.marginTrajectory}",
                  style: TextStyle(color: badgeColor, fontSize: 10.5, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                "${effectivePrice.toStringAsFixed(2)} ${item.unit}",
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: accentCyan),
              ),
              if (_priceSimulationOffset != 0.0) ...[
                const SizedBox(width: 8),
                Text(
                  "(${_priceSimulationOffset >= 0 ? '+' : ''}${_priceSimulationOffset.toInt()}% What-If)",
                  style: const TextStyle(fontSize: 12, color: Colors.amberAccent, fontWeight: FontWeight.bold),
                ),
              ]
            ],
          ),
          const SizedBox(height: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("52W Low: \$${item.fiftyTwoWeekLow.toStringAsFixed(1)}", style: const TextStyle(color: textMuted, fontSize: 11)),
                  Text(
                    "Position: ${(position * 100).toInt()}%",
                    style: const TextStyle(color: accentCyan, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  Text("52W High: \$${item.fiftyTwoWeekHigh.toStringAsFixed(1)}", style: const TextStyle(color: textMuted, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: position,
                  minHeight: 7,
                  backgroundColor: const Color(0xFF1E293B),
                  valueColor: AlwaysStoppedAnimation<Color>(isContracting ? Colors.amber : accentNeonGreen),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: borderSubtle, height: 1),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _deltaPill("1M Spike", item.periodChanges["1M"]),
              _deltaPill("6M Trend", item.periodChanges["6M"]),
              _deltaPill("1Y YoY", item.periodChanges["1Y"]),
              _deltaPill("3Y Cycle", item.periodChanges["3Y"]),
            ],
          ),
        ],
      ),
    );
  }

  Widget _deltaPill(String label, dynamic val) {
    final double value = (val as num?)?.toDouble() ?? 0.0;
    final isNegative = value < 0;
    return Column(
      children: [
        Text(label, style: const TextStyle(color: textMuted, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(
          "${isNegative ? '' : '+'}${value.toStringAsFixed(1)}%",
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
            color: isNegative ? Colors.redAccent : accentNeonGreen,
          ),
        ),
      ],
    );
  }

  /// 3. Visual Transmission Pipeline (Expanded Multi-Line - No Cutoff)
  Widget _buildTransmissionPipeline(MacroReportItem item) {
    final delta1Y = (item.periodChanges['1Y'] as num?)?.toDouble() ?? 0.0;
    final shockText = "${item.commodityName} ${delta1Y >= 0 ? '+' : ''}${delta1Y.toStringAsFixed(1)}% YoY";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentCyan.withAlpha(76)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "INPUT COST TRANSMISSION",
                style: TextStyle(color: accentCyan, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.1),
              ),
              Text("Est. Lag: ~${item.transmissionLagDays} Days", style: const TextStyle(color: textMuted, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _pipelineCard("1. Raw Shock", shockText, Colors.amber),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _pipelineCard(
                    "2. Sourcing Context",
                    item.importContext.isNotEmpty ? item.importContext : "Foreign Import Reliant",
                    Colors.lightBlueAccent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _pipelineCard("3. Inventory Lag", "${item.transmissionLagDays}d Inventory cycle", Colors.purpleAccent),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _pipelineCard("4. Corporate Margin", "Trajectory: ${item.marginTrajectory}", Colors.redAccent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pipelineCard(String title, String desc, Color col) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: col.withAlpha(70)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: TextStyle(color: col, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            desc,
            style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w500, height: 1.3),
            maxLines: 3, // Cutoff issue fixed
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// 4. AI Forecast Deck
  Widget _buildAiForecastDeck(MacroReportItem item) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.psychology, color: accentCyan, size: 22),
              SizedBox(width: 8),
              Text("AI STRATEGIST FORWARD THESIS", style: TextStyle(color: accentCyan, fontSize: 12.5, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          Text(item.macroHeadline, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, height: 1.4)),
          const SizedBox(height: 8),
          Text(item.forwardThesis, style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 13.5, height: 1.55)),
          if (item.keyRisk.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(76),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: accentFlame.withAlpha(76)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: accentFlame, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Key Catalyst Risk: ${item.keyRisk}",
                      style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12.5, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }

  /// 5. Live Interactive Sensitivity Simulator
  Widget _buildSensitivitySimulator(MacroReportItem item) {
    final simulatedPrice = item.currentPrice * (1 + _priceSimulationOffset / 100);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B4B).withAlpha(76),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _priceSimulationOffset != 0 ? Colors.amberAccent : Colors.indigoAccent.withAlpha(100),
          width: _priceSimulationOffset != 0 ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 16,
                    color: _priceSimulationOffset != 0 ? Colors.amberAccent : accentCyan,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    "SENSITIVITY SIMULATOR (WHAT-IF)",
                    style: TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Text(
                "\$${simulatedPrice.toStringAsFixed(1)} (${_priceSimulationOffset >= 0 ? '+' : ''}${_priceSimulationOffset.toInt()}%)",
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            "Slide to stress-test stock margins against commodity shocks in real-time:",
            style: TextStyle(color: textMuted, fontSize: 11),
          ),
          Slider(
            min: -20,
            max: 20,
            divisions: 8,
            value: _priceSimulationOffset,
            activeColor: _priceSimulationOffset != 0 ? Colors.amberAccent : accentCyan,
            inactiveColor: const Color(0xFF1E293B),
            onChanged: (val) => setState(() => _priceSimulationOffset = val),
          ),
          if (_priceSimulationOffset != 0.0) ...[
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () => setState(() => _priceSimulationOffset = 0.0),
                child: const Text(
                  "Reset to Baseline (0%)",
                  style: TextStyle(color: accentCyan, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildScreenerHeader(int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          "IMPACTED EQUITIES AUDIT",
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: textMuted),
        ),
        Text("$count Stocks Screened", style: const TextStyle(fontSize: 13, color: accentCyan, fontWeight: FontWeight.bold)),
      ],
    );
  }

  /// 6. Screener Controls
  Widget _buildScreenerControls() {
    return Column(
      children: [
        Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: surfaceCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderSubtle),
          ),
          child: TextField(
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: const InputDecoration(
              hintText: "Search ticker (e.g. ASIANPAINT, ONGC)...",
              hintStyle: TextStyle(color: textMuted, fontSize: 13),
              border: InputBorder.none,
              icon: Icon(Icons.search, size: 18, color: textMuted),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _impactFilterChip("ALL", "All Stocks"),
            const SizedBox(width: 8),
            _impactFilterChip("NEGATIVE", "🔴 Margin Drag"),
            const SizedBox(width: 8),
            _impactFilterChip("POSITIVE", "🟢 Beneficiary"),
          ],
        ),
      ],
    );
  }

  Widget _impactFilterChip(String val, String label) {
    final isSelected = _impactFilter == val;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _impactFilter = val),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? accentCyan : surfaceCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? accentCyan : borderSubtle),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.black : Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  /// 7. Equities List with Zero-Overlap Layout
  Widget _buildEquitiesList(List<ImpactedStock> list) {
    if (list.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: const Text("No stocks match your filter criteria", style: TextStyle(color: textMuted, fontSize: 13)),
      );
    }

    final isSimulating = _priceSimulationOffset != 0.0;

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      itemBuilder: (context, idx) {
        final stock = list[idx];

        final int simulatedBps = (stock.baselineBpsValue * (1 + (_priceSimulationOffset / 100))).round();
        final isPositive = simulatedBps >= 0;
        final displayBpsText = "${isPositive ? '+' : ''}$simulatedBps bps";

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: surfaceCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSimulating ? Colors.amberAccent.withAlpha(50) : borderSubtle,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ticker & Sector (Guaranteed safe boundary)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              stock.symbol,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                            ),
                            const SizedBox(width: 8),
                            // Flexible sector tag to avoid overlapping BPS badge
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  stock.sector,
                                  style: const TextStyle(color: accentCyan, fontSize: 11, fontWeight: FontWeight.w500),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          stock.companyName,
                          style: const TextStyle(color: textMuted, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Margin Impact Pill (Never gets pushed out)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: (isPositive ? accentNeonGreen : Colors.redAccent).withAlpha(40),
                          borderRadius: BorderRadius.circular(8),
                          border: isSimulating ? Border.all(color: Colors.amberAccent.withAlpha(120)) : null,
                        ),
                        child: Text(
                          displayBpsText,
                          style: TextStyle(
                            color: isPositive ? accentNeonGreen : Colors.redAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (isSimulating) ...[
                        const SizedBox(height: 2),
                        Text(
                          "Base: ${stock.marginImpactBps}",
                          style: const TextStyle(color: Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ]
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                stock.rationale,
                style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 13, height: 1.45),
              ),
            ],
          ),
        );
      },
    );
  }
}
