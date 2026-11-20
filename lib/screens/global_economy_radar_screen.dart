import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'economy_demand_radar_screen.dart';

class GlobalEconomyRadarScreen extends StatefulWidget {
  const GlobalEconomyRadarScreen({super.key});

  @override
  State<GlobalEconomyRadarScreen> createState() =>
      _GlobalEconomyRadarScreenState();
}

class _GlobalEconomyRadarScreenState extends State<GlobalEconomyRadarScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  bool _isSyncing = false;
  bool _isLiveSynced = false;

  Map<String, dynamic> _metadata = {};
  Map<String, dynamic> _executiveHud = {};
  Map<String, dynamic> _supplyDemandLevers = {};
  Map<String, dynamic> _sectorMarginMatrix = {};
  Map<String, dynamic> _currencyTradeTelemetry = {};
  Map<String, dynamic> _shockTransmissionEngine = {};
  List<Map<String, dynamic>> _superpowers = [];
  Map<String, dynamic> _usaChinaClash = {};
  List<Map<String, dynamic>> _stressGauges = [];
  Map<String, dynamic> _headwindsTailwinds = {};
  List<Map<String, dynamic>> _equityImpacts = [];

  // Theme Colors
  static const Color kBgDark = Color(0xFF090D16);
  static const Color kCardDark = Color(0xFF0F1726);
  static const Color kBorderSubtle = Color(0xFF1E2B3E);
  static const Color kAccentCyan = Color(0xFF00E5FF);
  static const Color kAccentGreen = Color(0xFF00FF88);
  static const Color kAccentAmber = Color(0xFFFFB703);
  static const Color kAccentRed = Color(0xFFFF2A6D);
  static const Color kTextMuted = Color(0xFF8896AB);

  // Dynamic remote data CDNs
  static const List<String> dataUrls = [
    'https://raw.githubusercontent.com/zxcty54/stock-crypto-tracker/main/assets/data/global_economy_radar.json',
    'https://raw.githubusercontent.com/zxcty54/stock-crypto-tracker/main/global_economy_radar.json',
    'https://cdn.jsdelivr.net/gh/zxcty54/stock-crypto-tracker@main/assets/data/global_economy_radar.json',
    'https://cdn.jsdelivr.net/gh/zxcty54/stock-crypto-tracker@main/global_economy_radar.json',
    'https://fastly.jsdelivr.net/gh/zxcty54/stock-crypto-tracker@main/assets/data/global_economy_radar.json',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadDataset();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _populateData(Map<String, dynamic> data) {
    _metadata = Map<String, dynamic>.from(data['metadata'] ?? {});
    _executiveHud = Map<String, dynamic>.from(data['executive_hud'] ?? {});
    _supplyDemandLevers =
        Map<String, dynamic>.from(data['supply_demand_control_levers'] ?? {});
    _sectorMarginMatrix =
        Map<String, dynamic>.from(data['sector_margin_demand_matrix'] ?? {});
    _currencyTradeTelemetry =
        Map<String, dynamic>.from(data['currency_and_trade_telemetry'] ?? {});
    _shockTransmissionEngine =
        Map<String, dynamic>.from(data['dynamic_shock_transmission_engine'] ?? {});
    _superpowers = List<Map<String, dynamic>>.from(
        data['global_superpowers'] ?? []);
    _usaChinaClash = Map<String, dynamic>.from(
        data['usa_china_macro_clash'] ?? {});
    _stressGauges = List<Map<String, dynamic>>.from(
        data['global_stress_gauges'] ?? []);
    _headwindsTailwinds =
        Map<String, dynamic>.from(data['global_headwinds_and_tailwinds'] ?? {});
    _equityImpacts = List<Map<String, dynamic>>.from(
        data['equity_impact_matrix'] ?? []);
  }

  Future<void> _loadDataset({bool isRefresh = false}) async {
    if (isRefresh) {
      HapticFeedback.lightImpact();
      setState(() => _isSyncing = true);
    }

    try {
      final localJson = await rootBundle
          .loadString('assets/data/global_economy_radar.json');
      final dynamic parsed = jsonDecode(localJson);
      if (parsed is Map<String, dynamic> &&
          parsed['global_superpowers'] != null) {
        if (mounted) {
          setState(() {
            _populateData(parsed);
            _isLoading = false;
          });
        }
      }
    } catch (_) {}

    bool fetchedLive = false;
    for (final url in dataUrls) {
      try {
        final uri = Uri.parse("$url?t=${DateTime.now().millisecondsSinceEpoch}");
        final response = await http.get(
          uri,
          headers: {
            'Cache-Control': 'no-cache, no-store, must-revalidate',
            'Pragma': 'no-cache',
          },
        ).timeout(const Duration(seconds: 6));

        if (response.statusCode == 200 && response.body.isNotEmpty) {
          final dynamic parsed = jsonDecode(utf8.decode(response.bodyBytes));
          if (parsed is Map<String, dynamic> &&
              parsed['global_superpowers'] != null) {
            if (mounted) {
              setState(() {
                _populateData(parsed);
                _isLiveSynced = true;
                _isSyncing = false;
                _isLoading = false;
              });
            }
            fetchedLive = true;
            if (isRefresh && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    "✅ Global Macro Telemetry Synced (${_metadata['last_updated'] ?? 'Latest'})",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: const Color(0xFF00C853),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
            break;
          }
        }
      } catch (_) {
        continue;
      }
    }

    if (!fetchedLive && mounted) {
      setState(() {
        _isSyncing = false;
        _isLoading = false;
      });
      if (isRefresh) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "ℹ️ Operating on Local Macro Baseline (Offline Fallback)",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Color(0xFF37474F),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showPipelineInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0C121E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF1E2B3E)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: kAccentCyan.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.public_rounded,
                  color: kAccentCyan, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "Global Macro Architecture",
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoStep(
                "1. Cross-Border Macro Telemetry",
                "Aggregates official Central Bank rates (Fed, PBOC, ECB, BoJ, RBI), S&P Global PMIs, and sovereign bond yields.",
                kAccentCyan,
              ),
              const SizedBox(height: 10),
              _buildInfoStep(
                "2. Supply-Demand Control Levers",
                "Tracks how OPEC+ energy valves, US Fed dollar taps, and Chinese factory overcapacity dictate global margins and trade.",
                kAccentGreen,
              ),
              const SizedBox(height: 10),
              _buildInfoStep(
                "3. US vs China Macro Clash",
                "Analyzes tit-for-tat friction across tariffs, semiconductor embargoes, critical minerals, and emerging market relocation.",
                kAccentAmber,
              ),
              const SizedBox(height: 10),
              _buildInfoStep(
                "4. Currency & Trade Deficit Transmission",
                "Monitors USD/INR exchange rate sensitivity, crude oil multiplier rules, and direct impact on domestic company margins.",
                kAccentRed,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CLOSE",
                style: TextStyle(
                    color: kAccentCyan, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoStep(String title, String desc, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF090D16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: const TextStyle(
                color: Colors.white70, fontSize: 10.5, height: 1.3),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgDark,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C121E),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.public_rounded,
                    color: kAccentCyan, size: 18),
                const SizedBox(width: 6),
                Text(
                  "GLOBAL ECONOMY RADAR",
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const Text(
              "Worldwide Pressure Points, Expansion Engines & Superpowers",
              style: TextStyle(color: kTextMuted, fontSize: 9.5),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: _isSyncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: kAccentCyan,
                    ),
                  )
                : const Icon(Icons.sync_rounded,
                    color: kAccentCyan, size: 20),
            tooltip: "Refresh Global Telemetry",
            onPressed: _isSyncing ? null : () => _loadDataset(isRefresh: true),
          ),
          IconButton(
            icon: const Icon(Icons.factory_rounded,
                color: Color(0xFFFF9100), size: 20),
            tooltip: "Switch to India Economy Radar",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const EconomyDemandRadarScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.info_outline_rounded,
                color: Colors.white70, size: 20),
            tooltip: "Global Pipeline Architecture",
            onPressed: () => _showPipelineInfoDialog(context),
          ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: kAccentCyan,
          indicatorWeight: 2.5,
          labelColor: kAccentCyan,
          unselectedLabelColor: Colors.white54,
          labelStyle: GoogleFonts.plusJakartaSans(
              fontSize: 11, fontWeight: FontWeight.w800),
          unselectedLabelStyle: GoogleFonts.plusJakartaSans(
              fontSize: 11, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: "🗺️ SUPERPOWERS (KAHA DABAO)"),
            Tab(text: "⚡ SUPPLY-DEMAND & MARGINS"),
            Tab(text: "⚔️ US vs CHINA CLASH"),
            Tab(text: "📊 GLOBAL STRESS GAUGES"),
            Tab(text: "⚖️ HEADWINDS vs TAILWINDS"),
            Tab(text: "🎯 EQUITY IMPACT MATRIX"),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: kAccentCyan),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                RefreshIndicator(
                  color: kAccentCyan,
                  backgroundColor: kCardDark,
                  onRefresh: () => _loadDataset(isRefresh: true),
                  child: _buildSuperpowersTab(),
                ),
                RefreshIndicator(
                  color: kAccentCyan,
                  backgroundColor: kCardDark,
                  onRefresh: () => _loadDataset(isRefresh: true),
                  child: _buildSupplyDemandAndMarginsTab(),
                ),
                RefreshIndicator(
                  color: kAccentCyan,
                  backgroundColor: kCardDark,
                  onRefresh: () => _loadDataset(isRefresh: true),
                  child: _buildUsChinaClashTab(),
                ),
                RefreshIndicator(
                  color: kAccentCyan,
                  backgroundColor: kCardDark,
                  onRefresh: () => _loadDataset(isRefresh: true),
                  child: _buildStressGaugesTab(),
                ),
                RefreshIndicator(
                  color: kAccentCyan,
                  backgroundColor: kCardDark,
                  onRefresh: () => _loadDataset(isRefresh: true),
                  child: _buildHeadwindsTailwindsTab(),
                ),
                RefreshIndicator(
                  color: kAccentCyan,
                  backgroundColor: kCardDark,
                  onRefresh: () => _loadDataset(isRefresh: true),
                  child: _buildEquityImpactTab(),
                ),
              ],
            ),
    );
  }

  // =============================================================
  // TAB 1: 🗺️ SUPERPOWERS & EXECUTIVE HUD
  // =============================================================
  Widget _buildSuperpowersTab() {
    final healthScore = _executiveHud['global_health_score'] ?? 54.0;
    final healthLabel = _executiveHud['global_health_label'] ?? 'EXPANDING';
    final verdict = _executiveHud['health_verdict'] ?? '';
    final headline = _metadata['regime_headline'] ?? '';
    final conclusion = _metadata['global_conclusion'] ?? '';
    final pillars = (_executiveHud['core_pillars'] as List<dynamic>? ?? []);

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // Executive HUD Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF131B2A), Color(0xFF0F1726)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kAccentCyan.withOpacity(0.35)),
            boxShadow: [
              BoxShadow(
                color: kAccentCyan.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
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
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: kAccentCyan.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.analytics_rounded,
                            color: kAccentCyan, size: 16),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "GLOBAL MACRO BAROMETER",
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: _isLiveSynced
                          ? kAccentGreen.withOpacity(0.15)
                          : const Color(0xFF37474F),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isLiveSynced ? Icons.wifi_rounded : Icons.offline_bolt_rounded,
                          color: _isLiveSynced ? kAccentGreen : Colors.white70,
                          size: 11,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isLiveSynced ? "LIVE CDN SYNC" : "BASELINE",
                          style: TextStyle(
                            color: _isLiveSynced ? kAccentGreen : Colors.white70,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Score Meter Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "$healthScore",
                    style: GoogleFonts.robotoMono(
                      color: kAccentCyan,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 6, left: 4),
                    child: Text(
                      "/ 100",
                      style: TextStyle(color: kTextMuted, fontSize: 13),
                    ),
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: kAccentCyan.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          healthLabel,
                          style: const TextStyle(
                            color: kAccentCyan,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _metadata['last_updated'] ?? 'Latest Baseline',
                        style: const TextStyle(
                            color: kTextMuted, fontSize: 9.5),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Visual Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (healthScore as num).toDouble() / 100.0,
                  backgroundColor: const Color(0xFF1E2B3E),
                  valueColor: const AlwaysStoppedAnimation<Color>(kAccentCyan),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 10),

              // Verdict & Headline
              if (headline.isNotEmpty)
                Text(
                  headline,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                verdict.isNotEmpty ? verdict : conclusion,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Visual Benchmark Column Chart
        _buildPmiColumnChart(pillars),
        const SizedBox(height: 14),

        // Section Title
        Row(
          children: const [
            Icon(Icons.public_rounded, color: kAccentCyan, size: 16),
            SizedBox(width: 6),
            Text(
              "ECONOMIC SUPERPOWERS TELEMETRY",
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Superpower Cards List
        ..._superpowers.map((p) => _buildSuperpowerCard(p)),
      ],
    );
  }

  Widget _buildPmiColumnChart(List<dynamic> pillars) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "REGIONAL COMPOSITE PMI BENCHMARK",
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: kAccentAmber,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    "50 = Expansion Threshold",
                    style: TextStyle(color: kTextMuted, fontSize: 9),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Columns Layout
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: pillars.map((item) {
              final String region = item['region'] ?? '';
              final String flag = item['flag'] ?? '';
              final double pmi = (item['growth_pmi'] as num?)?.toDouble() ?? 50.0;
              final isAbove50 = pmi >= 50.0;
              final Color barColor = isAbove50
                  ? (pmi > 55.0 ? kAccentGreen : kAccentCyan)
                  : kAccentRed;

              final double heightFactor = ((pmi - 35.0) / 30.0).clamp(0.15, 1.0);
              final double barHeight = heightFactor * 100.0;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    pmi.toStringAsFixed(1),
                    style: GoogleFonts.robotoMono(
                      color: barColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      Container(
                        width: 28,
                        height: 100,
                        decoration: BoxDecoration(
                          color: const Color(0xFF131B2A),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      Positioned(
                        bottom: 50.0,
                        child: Container(
                          width: 32,
                          height: 1.5,
                          color: kAccentAmber.withOpacity(0.4),
                        ),
                      ),
                      Container(
                        width: 28,
                        height: barHeight,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              barColor.withOpacity(0.7),
                              barColor,
                            ],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(flag, style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(
                    region.contains(' ') ? region.split(' ').first : region,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white70,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSuperpowerCard(Map<String, dynamic> p) {
    final name = p['name'] ?? '';
    final flag = p['flag'] ?? '';
    final statusLabel = p['status_label'] ?? '';
    final rate = p['central_bank_rate'] ?? '';
    final inflation = p['inflation_rate'] ?? '';
    final pmi = p['pmi_summary'] ?? '';
    final vitalStats = (p['vital_stats'] as Map<String, dynamic>? ?? {});
    final pressurePoints = (p['pressure_points'] as List<dynamic>? ?? []);
    final expansionEngines = (p['expansion_engines'] as List<dynamic>? ?? []);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: kCardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorderSubtle),
      ),
      child: ExpansionTile(
        initiallyExpanded: name.contains('United States') || name.contains('India'),
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        iconColor: kAccentCyan,
        collapsedIconColor: Colors.white38,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(flag, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(
                  name,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: statusLabel.contains('CONTRACTION') ||
                        statusLabel.contains('PRESSURE')
                    ? kAccentRed.withOpacity(0.15)
                    : kAccentCyan.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                  color: statusLabel.contains('CONTRACTION') ||
                          statusLabel.contains('PRESSURE')
                      ? kAccentRed
                      : kAccentCyan,
                  fontSize: 8.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            "Central Bank: $rate • Inflation: $inflation • $pmi",
            style: const TextStyle(color: kTextMuted, fontSize: 10, height: 1.3),
          ),
        ),
        children: [
          const Divider(color: kBorderSubtle),

          if (vitalStats.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: vitalStats.entries.map((entry) {
                final k = entry.key.replaceAll('_', ' ').toUpperCase();
                final v = entry.value.toString();
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF090D16),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: const Color(0xFF1E2B3E)),
                  ),
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 8.5),
                      children: [
                        TextSpan(
                          text: "$k: ",
                          style: const TextStyle(
                            color: Colors.white54,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(
                          text: v,
                          style: GoogleFonts.robotoMono(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
          ],

          // 🔴 Pressure Points Section (Kaha Dabao Hai)
          Row(
            children: const [
              Icon(Icons.arrow_downward_rounded, color: kAccentRed, size: 14),
              SizedBox(width: 4),
              Text(
                "PRESSURE POINTS (WHERE PAIN & DABAO IS BUILDING)",
                style: TextStyle(
                  color: kAccentRed,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...pressurePoints.map((pt) {
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF090D16),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: kAccentRed.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          pt['title'] ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: kAccentRed.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          pt['severity'] ?? 'HIGH',
                          style: const TextStyle(
                            color: kAccentRed,
                            fontSize: 7.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    pt['description'] ?? '',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 10, height: 1.3),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 10),

          // 🟢 Expansion Engines Section (Kaha Expansion Ho Raha Hai)
          Row(
            children: const [
              Icon(Icons.arrow_upward_rounded, color: kAccentGreen, size: 14),
              SizedBox(width: 4),
              Text(
                "EXPANSION ENGINES (WHERE GROWTH & CAPEX IS SURGING)",
                style: TextStyle(
                  color: kAccentGreen,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...expansionEngines.map((en) {
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF090D16),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: kAccentGreen.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          en['title'] ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: kAccentGreen.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          en['impact'] ?? 'EXPANSION',
                          style: const TextStyle(
                            color: kAccentGreen,
                            fontSize: 7.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    en['description'] ?? '',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 10, height: 1.3),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // =============================================================
  // TAB 2: ⚡ SUPPLY-DEMAND, MARGINS & CURRENCY RADAR
  // =============================================================
  Widget _buildSupplyDemandAndMarginsTab() {
    final leversHeadline = _supplyDemandLevers['headline'] ??
        'HOW SUPERPOWERS CONTROL GLOBAL SUPPLY & DEMAND';
    final leversDesc = _supplyDemandLevers['description'] ?? '';
    final levers = (_supplyDemandLevers['levers'] as List<dynamic>? ?? []);

    final marginDesc = _sectorMarginMatrix['description'] ?? '';
    final expansionSectors =
        (_sectorMarginMatrix['margin_expansion_sectors'] as List<dynamic>? ?? []);
    final pressureSectors =
        (_sectorMarginMatrix['margin_pressure_sectors'] as List<dynamic>? ?? []);

    final usdInr = _currencyTradeTelemetry['usd_inr_current'] ?? 84.42;
    final inrStress = _currencyTradeTelemetry['stress_level'] ?? 'MANAGED FLOAT';
    final rbiForex = _currencyTradeTelemetry['rbi_forex_warchest'] ?? r'$675 Billion';
    final crudeRule =
        (_currencyTradeTelemetry['crude_sensitivity_rule'] as Map<String, dynamic>? ?? {});
    final eximDynamics =
        (_currencyTradeTelemetry['import_export_dynamics'] as List<dynamic>? ?? []);

    final shocks =
        (_shockTransmissionEngine['shocks'] as List<dynamic>? ?? []);

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // Intro Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF131B2A), Color(0xFF1A1A2E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kAccentCyan.withOpacity(0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.bolt_rounded, color: kAccentCyan, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      leversHeadline,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                leversDesc,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 10.5, height: 1.35),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Live Geopolitical Shock Alert
        if (shocks.isNotEmpty) ...[
          _buildActiveShockBanner(shocks.first),
          const SizedBox(height: 14),
        ],

        // 📊 GRAPHICAL CHART 1: Sector Margin Delta (Expansion vs Pressure)
        _buildSectorMarginChart(expansionSectors, pressureSectors, marginDesc),
        const SizedBox(height: 14),

        // 📊 GRAPHICAL CHART 2: USD/INR Currency & Trade Deficit Gauge
        _buildCurrencyAndTradeGauge(usdInr, inrStress, rbiForex, crudeRule, eximDynamics),
        const SizedBox(height: 14),

        // 4 Global Supply-Demand Levers
        Row(
          children: const [
            Icon(Icons.tune_rounded, color: kAccentAmber, size: 16),
            SizedBox(width: 6),
            Text(
              "4 GLOBAL LEVERS CONTROLLING WORLD SUPPLY & DEMAND",
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...levers.map((lev) => _buildLeverCard(lev)),
      ],
    );
  }

  Widget _buildActiveShockBanner(Map<String, dynamic> shock) {
    final name = shock['shock_name'] ?? '';
    final trigger = shock['trigger'] ?? '';
    final supplyChoke = shock['supply_demand_choke'] ?? '';
    final eximShift = shock['import_export_shift'] ?? '';
    final inrImpact = shock['currency_impact'] ?? '';
    final winners = (shock['margin_winners'] as List<dynamic>? ?? []);
    final losers = (shock['margin_losers'] as List<dynamic>? ?? []);

    return Container(
      decoration: BoxDecoration(
        color: kCardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kAccentAmber.withOpacity(0.5)),
      ),
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        iconColor: kAccentAmber,
        collapsedIconColor: Colors.white54,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: kAccentAmber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  color: kAccentAmber, size: 16),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        "LIVE SHOCK SURVEILLANCE",
                        style: TextStyle(
                          color: kAccentAmber,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: kAccentRed.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text(
                          "ACTIVE TRIGGER",
                          style: TextStyle(
                            color: kAccentRed,
                            fontSize: 7.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    name,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        children: [
          const Divider(color: kBorderSubtle),
          const SizedBox(height: 4),

          // Transmission Flow Diagram (Steps)
          _buildShockFlowStep("1. GLOBAL TRIGGER", trigger, kAccentAmber),
          _buildShockFlowStep("2. SUPPLY-DEMAND CHOKE", supplyChoke, kAccentCyan),
          _buildShockFlowStep("3. EXPORT-IMPORT SHIFT", eximShift, Colors.white70),
          _buildShockFlowStep("4. CURRENCY (INR) IMPACT", inrImpact, kAccentRed),

          const SizedBox(height: 6),
          // Winners & Losers Row
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: kAccentGreen.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: kAccentGreen.withOpacity(0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "🟢 MARGIN EXPANSION",
                        style: TextStyle(
                          color: kAccentGreen,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        winners.join(" • "),
                        style: GoogleFonts.robotoMono(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: kAccentRed.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: kAccentRed.withOpacity(0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "🔴 MARGIN PRESSURE",
                        style: TextStyle(
                          color: kAccentRed,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        losers.join(" • "),
                        style: GoogleFonts.robotoMono(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShockFlowStep(String tag, String text, Color col) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: col.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              tag,
              style: TextStyle(
                color: col,
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectorMarginChart(
      List<dynamic> expansion, List<dynamic> pressure, String desc) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "SECTOR MARGIN DELTA CHART (BPS)",
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              const Text(
                "+ / - Basis Points",
                style: TextStyle(color: kTextMuted, fontSize: 9.5),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: const TextStyle(color: Colors.white60, fontSize: 10),
          ),
          const SizedBox(height: 12),

          // 🟢 EXPANSION SECTION
          Row(
            children: const [
              Icon(Icons.trending_up_rounded, color: kAccentGreen, size: 14),
              SizedBox(width: 4),
              Text(
                "MARGIN EXPANSION (GLOBAL TAILWINDS)",
                style: TextStyle(
                  color: kAccentGreen,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...expansion.map((sec) => _buildMarginBarRow(sec, isExpansion: true)),

          const SizedBox(height: 14),

          // 🔴 PRESSURE SECTION
          Row(
            children: const [
              Icon(Icons.trending_down_rounded, color: kAccentRed, size: 14),
              SizedBox(width: 4),
              Text(
                "MARGIN PRESSURE (GLOBAL INPUT & DUMPING DABAO)",
                style: TextStyle(
                  color: kAccentRed,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...pressure.map((sec) => _buildMarginBarRow(sec, isExpansion: false)),
        ],
      ),
    );
  }

  Widget _buildMarginBarRow(Map<String, dynamic> sec,
      {required bool isExpansion}) {
    final sector = sec['sector'] ?? '';
    final int delta = (sec['margin_delta_bps'] as num?)?.toInt() ?? 0;
    final int demand = (sec['demand_score'] as num?)?.toInt() ?? 50;
    final driver = sec['driver'] ?? '';
    final stocks = (sec['key_stocks'] as List<dynamic>? ?? []);
    final Color barColor = isExpansion ? kAccentGreen : kAccentRed;

    final double widthFactor = (delta.abs() / 300.0).clamp(0.15, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF090D16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: barColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                sector,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: barColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      "${delta > 0 ? '+' : ''}$delta bps",
                      style: GoogleFonts.robotoMono(
                        color: barColor,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "Demand: $demand",
                    style: TextStyle(
                      color: demand > 75 ? kAccentGreen : Colors.white54,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Visual Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Row(
              children: [
                Expanded(
                  flex: (widthFactor * 100).toInt(),
                  child: Container(
                    height: 5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          barColor.withOpacity(0.5),
                          barColor,
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: ((1.0 - widthFactor) * 100).toInt(),
                  child: Container(
                    height: 5,
                    color: const Color(0xFF1E2B3E),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          Text(
            driver,
            style: const TextStyle(
                color: Colors.white60, fontSize: 9.5, height: 1.25),
          ),
          if (stocks.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Text(
                  "Plays: ",
                  style: TextStyle(color: kTextMuted, fontSize: 8.5),
                ),
                Text(
                  stocks.join(", "),
                  style: GoogleFonts.robotoMono(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCurrencyAndTradeGauge(
      dynamic usdInr,
      String inrStress,
      String rbiForex,
      Map<String, dynamic> crudeRule,
      List<dynamic> eximDynamics) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kAccentCyan.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.currency_exchange_rounded,
                      color: kAccentCyan, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    "USD / INR & TRADE DEFICIT RADAR",
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: kAccentAmber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  inrStress,
                  style: const TextStyle(
                    color: kAccentAmber,
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Rate & Warchest Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("CURRENT SPOT RATE",
                      style: TextStyle(color: kTextMuted, fontSize: 9)),
                  Text(
                    "₹$usdInr",
                    style: GoogleFonts.robotoMono(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text("RBI FOREX WARCHEST",
                      style: TextStyle(color: kTextMuted, fontSize: 9)),
                  Text(
                    rbiForex,
                    style: GoogleFonts.robotoMono(
                      color: kAccentGreen,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 3-Zone Visual Color Gauge Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Row(
              children: [
                Expanded(
                  flex: 33,
                  child: Container(
                    height: 8,
                    color: kAccentGreen.withOpacity(0.7),
                  ),
                ),
                Expanded(
                  flex: 33,
                  child: Container(
                    height: 8,
                    color: kAccentAmber.withOpacity(0.7),
                  ),
                ),
                Expanded(
                  flex: 34,
                  child: Container(
                    height: 8,
                    color: kAccentRed.withOpacity(0.85),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text("₹82.50 (Inflow)",
                  style: TextStyle(color: Colors.white54, fontSize: 8)),
              Text("₹83.80 (Float)",
                  style: TextStyle(color: Colors.white54, fontSize: 8)),
              Text("₹84.42 (DXY Dabao)",
                  style: TextStyle(
                      color: kAccentRed,
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),

          // The $10 Crude Oil Rule Box
          if (crudeRule.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF090D16),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF1E2B3E)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    crudeRule['rule_title'] ?? r'The $10 Crude Rule',
                    style: const TextStyle(
                      color: kAccentCyan,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildRulePoint(
                      Icons.arrow_forward_rounded,
                      crudeRule['stat_trade_deficit'] ?? '',
                      kAccentAmber),
                  _buildRulePoint(
                      Icons.arrow_forward_rounded,
                      crudeRule['stat_currency_impact'] ?? '',
                      kAccentRed),
                  _buildRulePoint(
                      Icons.arrow_forward_rounded,
                      crudeRule['stat_inflation_impact'] ?? '',
                      Colors.white70),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Exim Flows Row
          ...eximDynamics.map((dyn) {
            final flow = dyn['flow'] ?? '';
            final status = dyn['status'] ?? '';
            final details = dyn['details'] ?? '';
            final bool isImport = flow == 'IMPORTS';

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isImport
                      ? kAccentRed.withOpacity(0.06)
                      : kAccentGreen.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isImport
                        ? kAccentRed.withOpacity(0.2)
                        : kAccentGreen.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          flow,
                          style: TextStyle(
                            color: isImport ? kAccentRed : kAccentGreen,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          status,
                          style: TextStyle(
                            color: isImport ? kAccentRed : kAccentGreen,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      details,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 9.5, height: 1.25),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRulePoint(IconData icon, String text, Color col) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Icon(icon, color: col, size: 11),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: col,
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeverCard(Map<String, dynamic> lev) {
    final name = lev['name'] ?? '';
    final controller = lev['controller'] ?? '';
    final how = lev['how_they_control'] ?? '';
    final shock = lev['shock_scenario'] ?? '';
    final transmission = lev['india_transmission'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kCardDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            "Controller: $controller",
            style: const TextStyle(color: kAccentCyan, fontSize: 9.5),
          ),
          const SizedBox(height: 6),
          Text(
            how,
            style: const TextStyle(
                color: Colors.white70, fontSize: 10, height: 1.3),
          ),
          const SizedBox(height: 6),

          // Shock & India Note
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF090D16),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: kAccentAmber.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "🇮🇳 INDIA TRANSMISSION & SHOCK IMPACT",
                  style: TextStyle(
                    color: kAccentAmber,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  transmission,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 9.5, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =============================================================
  // TAB 3: ⚔️ USA vs CHINA MACRO CLASH DESK
  // =============================================================
  Widget _buildUsChinaClashTab() {
    final headline = _usaChinaClash['headline'] ?? 'USA vs CHINA MACRO CLASH';
    final overview = _usaChinaClash['overview'] ?? '';
    final battlefields =
        (_usaChinaClash['battlefields'] as List<dynamic>? ?? []);

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // Top Banner Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kAccentCyan.withOpacity(0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text("🇺🇸", style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 6),
                  const Text("⚔️", style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 6),
                  const Text("🇨🇳", style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      headline,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                overview,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Battlefields List
        ...battlefields.map((bf) => _buildBattlefieldCard(bf)),
      ],
    );
  }

  Widget _buildBattlefieldCard(Map<String, dynamic> bf) {
    final title = bf['title'] ?? '';
    final usOffensive = bf['us_offensive'] ?? '';
    final chinaRetaliation = bf['china_retaliation'] ?? '';
    final macroImpact = bf['macro_impact'] ?? '';
    final impactOnIndia = bf['impact_on_india'] ?? '';
    final indiaTakeaway = bf['india_takeaway'] ?? '';

    final isIndiaPositive = impactOnIndia.contains('POSITIVE') ||
        impactOnIndia.contains('BENEFICIARY');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),

          // US Offensive Box
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1829),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kAccentCyan.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Text("🇺🇸", style: TextStyle(fontSize: 14)),
                    SizedBox(width: 6),
                    Text(
                      "US OFFENSIVE & LEVERAGE",
                      style: TextStyle(
                        color: kAccentCyan,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  usOffensive,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // China Counter Box
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF24121A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kAccentRed.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Text("🇨🇳", style: TextStyle(fontSize: 14)),
                    SizedBox(width: 6),
                    Text(
                      "CHINA COUNTER & RETALIATION",
                      style: TextStyle(
                        color: kAccentRed,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  chinaRetaliation,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Global Macro Impact Note
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF090D16),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF1E2B3E)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.public_rounded, color: kAccentAmber, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 10, height: 1.3),
                      children: [
                        const TextSpan(
                          text: "Global Impact: ",
                          style: TextStyle(
                            color: kAccentAmber,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(
                          text: macroImpact,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // India Impact Box
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isIndiaPositive
                  ? kAccentGreen.withOpacity(0.08)
                  : kAccentAmber.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isIndiaPositive
                    ? kAccentGreen.withOpacity(0.3)
                    : kAccentAmber.withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Text("🇮🇳", style: TextStyle(fontSize: 14)),
                        SizedBox(width: 6),
                        Text(
                          "INDIA TAKEAWAY & ARBITRAGE",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: isIndiaPositive
                            ? kAccentGreen.withOpacity(0.2)
                            : kAccentAmber.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        impactOnIndia,
                        style: TextStyle(
                          color: isIndiaPositive ? kAccentGreen : kAccentAmber,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  indiaTakeaway,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =============================================================
  // TAB 4: 📊 GLOBAL STRESS GAUGES
  // =============================================================
  Widget _buildStressGaugesTab() {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // Explainer Banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: kCardDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kBorderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                "GLOBAL CROSS-BORDER STRESS GAUGES",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 4),
              Text(
                "Real-time visual meters monitoring sovereign liquidity stress, raw commodity flows, and currency pressures.",
                style: TextStyle(color: Colors.white70, fontSize: 10.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        ..._stressGauges.map((g) => _buildStressGaugeCard(g)),
      ],
    );
  }

  Widget _buildStressGaugeCard(Map<String, dynamic> g) {
    final name = g['name'] ?? '';
    final val = g['current_value'];
    final unit = g['unit'] ?? '';
    final statusLabel = g['status_label'] ?? '';
    final double barRatio = (g['bar_ratio'] as num?)?.toDouble() ?? 0.5;
    final isPressure = g['flow_direction'] == 'PRESSURE';
    final Color barColor = isPressure ? kAccentRed : kAccentGreen;
    final range = g['historical_range'] ?? '';
    final impact = g['market_impact'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: barColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: barColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: barColor,
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Value Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "$val $unit",
                style: GoogleFonts.robotoMono(
                  color: barColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                "Range: $range",
                style: const TextStyle(color: kTextMuted, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Horizontal Gauge Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: barRatio.clamp(0.05, 1.0),
              backgroundColor: const Color(0xFF131B2A),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),

          // Market Impact Note
          Text(
            impact,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10.5,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  // =============================================================
  // TAB 5: ⚖️ HEADWINDS vs TAILWINDS
  // =============================================================
  Widget _buildHeadwindsTailwindsTab() {
    final headwinds =
        (_headwindsTailwinds['pressure_headwinds'] as List<dynamic>? ?? []);
    final tailwinds =
        (_headwindsTailwinds['expansion_tailwinds'] as List<dynamic>? ?? []);

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // 🔴 Global Headwinds Section (Kaha Dabao Aa Raha Hai)
        Row(
          children: const [
            Icon(Icons.arrow_downward_rounded, color: kAccentRed, size: 16),
            SizedBox(width: 6),
            Text(
              "GLOBAL MACRO HEADWINDS (WHERE PRESSURE HITS)",
              style: TextStyle(
                color: kAccentRed,
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...headwinds.map((h) => _buildWindCard(h, isHeadwind: true)),
        const SizedBox(height: 16),

        // 🟢 Global Tailwinds Section (Kaha Expansion Ho Raha Hai)
        Row(
          children: const [
            Icon(Icons.arrow_upward_rounded, color: kAccentGreen, size: 16),
            SizedBox(width: 6),
            Text(
              "GLOBAL MACRO TAILWINDS (WHERE WE BENEFIT)",
              style: TextStyle(
                color: kAccentGreen,
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...tailwinds.map((t) => _buildWindCard(t, isHeadwind: false)),
      ],
    );
  }

  Widget _buildWindCard(Map<String, dynamic> item, {required bool isHeadwind}) {
    final title = item['title'] ?? '';
    final impact = item['impact_level'] ?? '';
    final sectors = (item['affected_sectors'] as List<dynamic>? ?? []);
    final reason = item['reason'] ?? '';
    final Color col = isHeadwind ? kAccentRed : kAccentGreen;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kCardDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: col.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: col.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  impact,
                  style: TextStyle(
                    color: col,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            reason,
            style: const TextStyle(
                color: Colors.white70, fontSize: 10.5, height: 1.3),
          ),
          if (sectors.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  isHeadwind ? "Impacted: " : "Beneficiaries: ",
                  style: TextStyle(
                    color: col,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Expanded(
                  child: Text(
                    sectors.join(', '),
                    style: GoogleFonts.robotoMono(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // =============================================================
  // TAB 6: 🎯 EQUITY IMPACT MATRIX
  // =============================================================
  Widget _buildEquityImpactTab() {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // Intro Banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: kCardDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kBorderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                "CROSS-BORDER EQUITY TRANSLATION MATRIX",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 4),
              Text(
                "Direct translation of global geopolitical, tariff, and monetary catalysts into listed domestic equities.",
                style: TextStyle(color: Colors.white70, fontSize: 10.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        ..._equityImpacts.map((e) => _buildEquityThemeCard(e)),
      ],
    );
  }

  Widget _buildEquityThemeCard(Map<String, dynamic> theme) {
    final tName = theme['theme'] ?? '';
    final direction = theme['impact_direction'] ?? '';
    final bool isBeneficiary = direction == 'BENEFICIARY';
    final Color col = isBeneficiary ? kAccentGreen : kAccentRed;
    final stocks = (theme['stocks'] as List<dynamic>? ?? []);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: col.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  tName,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: col.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isBeneficiary ? "🟢 EXPANDING" : "🔴 PRESSURE FACING",
                  style: TextStyle(
                    color: col,
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Listed Equities
          ...stocks.map((st) {
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF090D16),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF1E2B3E)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        st['symbol'] ?? '',
                        style: GoogleFonts.robotoMono(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        st['name'] ?? '',
                        style: const TextStyle(
                            color: kTextMuted, fontSize: 9.5),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Text(
                        st['catalyst'] ?? '',
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          color: col,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
