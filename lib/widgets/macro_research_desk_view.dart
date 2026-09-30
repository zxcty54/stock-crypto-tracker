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
  final String rationale;

  ImpactedStock({
    required this.symbol,
    required this.companyName,
    required this.sector,
    required this.impactType,
    required this.marginImpactBps,
    required this.rationale,
  });

  factory ImpactedStock.fromJson(Map<String, dynamic> json) {
    return ImpactedStock(
      symbol: json['symbol'] ?? '',
      companyName: json['company_name'] ?? '',
      sector: json['sector'] ?? '',
      impactType: json['impact_type'] ?? 'POSITIVE',
      marginImpactBps: json['margin_impact_bps'] ?? '',
      rationale: json['rationale'] ?? '',
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

  MacroReportItem({
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
  });

  factory MacroReportItem.fromJson(Map<String, dynamic> json) {
    return MacroReportItem(
      commodityName: json['commodity_name'] ?? '',
      unit: json['unit'] ?? '',
      currentPrice: (json['current_price'] as num?)?.toDouble() ?? 0.0,
      periodChanges: json['period_changes'] ?? {},
      macroHeadline: json['macro_headline'] ?? '',
      forwardThesis: json['forward_thesis'] ?? '',
      marginTrajectory: json['margin_trajectory'] ?? 'NEUTRAL',
      importContext: json['import_context'] ?? '',
      keyRisk: json['key_risk'] ?? '',
      impactedStocks: (json['impacted_stocks'] as List? ?? [])
          .map((e) => ImpactedStock.fromJson(e))
          .toList(),
    );
  }
}

// ---------------- MAIN WIDGET SCREEN ----------------
class MacroResearchDeskView extends StatefulWidget {
  const MacroResearchDeskView({super.key});

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

  static const Color bgDark = Color(0xFF090D16);
  static const Color surfaceCard = Color(0xFF131B2A);
  static const Color borderSubtle = Color(0xFF202C42);
  static const Color accentNeonGreen = Color(0xFF00E676);
  static const Color accentFlame = Color(0xFFFF9100);
  static const Color accentCyan = Color(0xFF00E5FF);
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
      final response = await http.get(Uri.parse(urlWithTs)).timeout(
        const Duration(seconds: 12),
      );

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
                "Syncing AI Macro Radar...",
                style: TextStyle(color: textMuted, fontSize: 14),
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
                const SizedBox(height: 14),
                Text(
                  _errorMessage ?? "No research reports available yet.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 15),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: surfaceCard,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    side: const BorderSide(color: borderSubtle),
                  ),
                  onPressed: _fetchAiResearchData,
                  child: const Text("Retry Sync", style: TextStyle(color: accentCyan, fontSize: 15)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final activeItem = _reports[_selectedCommodityIndex];

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: surfaceCard,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "MACRO MARGIN RADAR",
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 1.5,
                color: accentCyan,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _lastUpdatedAt.isNotEmpty ? "Synced: $_lastUpdatedAt" : "Sector Impact & Forecast",
              style: const TextStyle(fontSize: 13, color: textMuted),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 24),
            onPressed: _fetchAiResearchData,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: accentCyan,
        backgroundColor: surfaceCard,
        onRefresh: _fetchAiResearchData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCommodityTabs(),
              const SizedBox(height: 18),
              _buildPriceOverviewCard(activeItem),
              const SizedBox(height: 16),
              _buildForwardAnalysisCard(activeItem),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "IMPACTED EQUITIES AUDIT",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: textMuted,
                    ),
                  ),
                  Text(
                    "${activeItem.impactedStocks.length} Stocks Screened",
                    style: const TextStyle(
                      fontSize: 13,
                      color: accentCyan,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildStocksList(activeItem.impactedStocks),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommodityTabs() {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _reports.length,
        itemBuilder: (context, idx) {
          final isSelected = idx == _selectedCommodityIndex;
          return GestureDetector(
            onTap: () => setState(() => _selectedCommodityIndex = idx),
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF223048) : surfaceCard,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isSelected ? accentCyan : borderSubtle,
                  width: isSelected ? 1.5 : 1.0,
                ),
              ),
              child: Center(
                child: Text(
                  _reports[idx].commodityName,
                  style: TextStyle(
                    color: isSelected ? Colors.white : textMuted,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPriceOverviewCard(MacroReportItem item) {
    final isExpanding = item.marginTrajectory.toUpperCase() == "EXPANDING";
    final badgeColor = isExpanding ? accentNeonGreen : Colors.redAccent;

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                item.commodityName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: badgeColor.withAlpha(38),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "MARGINS: ${item.marginTrajectory}",
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "${item.currentPrice.toStringAsFixed(2)} ${item.unit}",
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          const Divider(color: borderSubtle, height: 1),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDeltaPill("1-Month", item.periodChanges["1M"]),
              _buildDeltaPill("6-Month", item.periodChanges["6M"]),
              _buildDeltaPill("1-Year (YoY)", item.periodChanges["1Y"]),
              _buildDeltaPill("3-Year", item.periodChanges["3Y"]),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeltaPill(String label, dynamic val) {
    final double value = (val as num?)?.toDouble() ?? 0.0;
    final isNegative = value < 0;
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: textMuted, fontSize: 12, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Text(
          "${isNegative ? "" : "+"}${value.toStringAsFixed(1)}%",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isNegative ? Colors.redAccent : accentNeonGreen,
          ),
        ),
      ],
    );
  }

  Widget _buildForwardAnalysisCard(MacroReportItem item) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentCyan.withAlpha(76)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.psychology_alt_rounded, color: accentCyan, size: 24),
              SizedBox(width: 10),
              Text(
                "AI STRATEGIST FORECAST",
                style: TextStyle(
                  color: accentCyan,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.macroHeadline,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            item.forwardThesis,
            style: const TextStyle(
              color: Color(0xFFE2E8F0),
              fontSize: 14,
              height: 1.6,
            ),
          ),
          if (item.importContext.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blueGrey.withAlpha(40),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blueGrey.withAlpha(70)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.public, color: accentCyan, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.importContext,
                      style: const TextStyle(
                        color: Color(0xFFCBD5E1),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
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
              color: Colors.black.withAlpha(76),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, color: accentFlame, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Key Catalyst Risk: ${item.keyRisk}",
                    style: const TextStyle(
                      color: Color(0xFFCBD5E1),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStocksList(List<ImpactedStock> list) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final stock = list[index];
        final isBeneficiary = stock.impactType.toUpperCase() == "POSITIVE";

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: surfaceCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderSubtle),
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
                          stock.symbol,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "${stock.companyName} • ${stock.sector}",
                          style: const TextStyle(color: textMuted, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: (isBeneficiary ? accentNeonGreen : Colors.redAccent).withAlpha(35),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      stock.marginImpactBps,
                      style: TextStyle(
                        color: isBeneficiary ? accentNeonGreen : Colors.redAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                stock.rationale,
                style: const TextStyle(
                  color: Color(0xFFCBD5E1),
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
