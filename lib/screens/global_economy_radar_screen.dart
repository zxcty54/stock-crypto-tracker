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
  List<Map<String, dynamic>> _superpowers = [];
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
    _tabController = TabController(length: 4, vsync: this);
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
    _superpowers = List<Map<String, dynamic>>.from(
        data['global_superpowers'] ?? []);
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

    // 1. Offline bundled asset fallback first
    if (_superpowers.isEmpty) {
      try {
        final jsonStr = await rootBundle
            .loadString('assets/data/global_economy_radar.json');
        final data = jsonDecode(jsonStr);

        if (mounted && _superpowers.isEmpty) {
          setState(() {
            _populateData(data);
            _isLoading = false;
          });
        }
      } catch (e) {
        debugPrint("Error loading bundled global economy dataset: $e");
      }
    }

    // 2. Fetch live dynamic radar from CDNs
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    bool fetchedLive = false;

    for (final baseUrl in dataUrls) {
      try {
        final uri = Uri.parse('$baseUrl?ts=$timestamp');
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
      } catch (e) {
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
            content: Text("Baseline cached global radar active."),
            backgroundColor: Color(0xFF00838F),
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
        backgroundColor: kCardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: kBorderSubtle),
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
                "2. Pressure vs Expansion Matrix",
                "Detects where economic pain (de-industrialization, property debt, yield gravity) vs growth engines (AI capex, China+1, rate cuts) are active.",
                kAccentGreen,
              ),
              const SizedBox(height: 10),
              _buildInfoStep(
                "3. Global Stress Barometers",
                "Real-time monitoring of US Dollar Index (DXY), US 10Y yields, Brent Crude, and sovereign central bank Gold accumulation.",
                kAccentAmber,
              ),
              const SizedBox(height: 10),
              _buildInfoStep(
                "4. Equity Translation Impact",
                "Maps international geopolitical and macroeconomic shifts into affected sectors and listed equities.",
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
  // TAB 1: 🗺️ GLOBAL SUPERPOWERS & PRESSURE vs EXPANSION
  // =============================================================
  Widget _buildSuperpowersTab() {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // 1. Executive Global Conclusion HUD & Regional Bar Chart
        _buildExecutiveGlobalHUD(),
        const SizedBox(height: 16),

        // Section Title
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: const [
                Icon(Icons.account_balance_rounded,
                    color: kAccentCyan, size: 16),
                SizedBox(width: 6),
                Text(
                  "SUPERPOWER BLOCS (PRESSURE vs EXPANSION)",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Superpower Detailed Cards
        ..._superpowers.map((p) => _buildSuperpowerCard(p)),
      ],
    );
  }

  Widget _buildExecutiveGlobalHUD() {
    final pillars = (_executiveHud['core_pillars'] as List<dynamic>? ?? []);
    final score = _executiveHud['global_health_score'] ?? 68;
    final label = _executiveHud['global_health_label'] ??
        'MODERATE ASYMMETRIC EXPANSION';
    final conclusion = _metadata['global_conclusion'] ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF142038), Color(0xFF0C1424)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kAccentCyan.withOpacity(0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: kAccentCyan.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: kAccentCyan.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.public_rounded,
                        color: kAccentCyan, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "GLOBAL CONCLUSION (AT A GLANCE)",
                    style: GoogleFonts.plusJakartaSans(
                      color: kAccentCyan,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: kAccentGreen.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "$score/100 EXPANSION",
                  style: const TextStyle(
                    color: kAccentGreen,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Core Headline
          Text(
            "Global Asymmetric Fracturing: US Tech & India/Asia Booming vs European Contraction & China Deflation",
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),

          // 📊 Regional Output Column Bar Chart (PMI Comparison)
          Container(
            padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
            decoration: BoxDecoration(
              color: const Color(0xFF080D17),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1B283E)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text("REGIONAL ECONOMIC ACTIVITY & PMI BENCHMARK (50.0 = NEUTRAL)",
                        style: TextStyle(
                            color: Colors.white38,
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold)),
                    Text("Threshold: 50.0",
                        style: TextStyle(color: Colors.white38, fontSize: 8.5)),
                  ],
                ),
                const SizedBox(height: 12),

                // 5 Pillars
                SizedBox(
                  height: 100,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: pillars.map((p) {
                      final double pmi =
                          (p['growth_pmi'] as num?)?.toDouble() ?? 50.0;
                      final String flag = p['flag'] ?? '';
                      final String rName =
                          (p['region'] ?? '').toString().split(' ').first;
                      final bool isExpanding = pmi >= 50.0;
                      final Color col = isExpanding
                          ? (pmi > 55.0 ? kAccentGreen : kAccentCyan)
                          : kAccentRed;

                      return _buildRegionBar(
                        flag: flag,
                        name: rName,
                        pmiStr: pmi.toStringAsFixed(1),
                        heightRatio: (pmi / 60.0).clamp(0.2, 1.0),
                        color: col,
                        isExpanding: isExpanding,
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 6),
                Container(height: 1.5, color: Colors.white24),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Core Summary
          Text(
            conclusion,
            style: const TextStyle(
                color: Colors.white70, fontSize: 11, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _buildRegionBar({
    required String flag,
    required String name,
    required String pmiStr,
    required double heightRatio,
    required Color color,
    required bool isExpanding,
  }) {
    final double barHeight = (heightRatio * 58.0).clamp(16.0, 58.0);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(flag, style: const TextStyle(fontSize: 10)),
            const SizedBox(width: 2),
            Text(
              pmiStr,
              style: GoogleFonts.robotoMono(
                color: color,
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          width: 38,
          height: barHeight,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.95), color.withOpacity(0.45)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: color, width: 1),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        Text(
          name,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white70,
            fontSize: 8.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildSuperpowerCard(Map<String, dynamic> p) {
    final name = p['name'] ?? '';
    final flag = p['flag'] ?? '';
    final statusLabel = p['status_label'] ?? '';
    final rate = p['central_bank_rate'] ?? '';
    final inflation = p['inflation_rate'] ?? '';
    final pmi = p['pmi_summary'] ?? '';
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
            "Central Bank: $rate • Inflation: $inflation\n$pmi",
            style: const TextStyle(color: kTextMuted, fontSize: 10, height: 1.3),
          ),
        ),
        children: [
          const Divider(color: kBorderSubtle),

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
                color: const Color(0xFF1B0C14),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: kAccentRed.withOpacity(0.3)),
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
                color: const Color(0xFF0C1B14),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: kAccentGreen.withOpacity(0.3)),
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
                          en['impact'] ?? 'GROWTH',
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
  // TAB 2: 📊 GLOBAL STRESS GAUGES
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
                  color: kAccentCyan,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 3),
              Text(
                "Tracking the 6 macroeconomic barometers that govern foreign institutional (FII) flows, currency valuations, and raw material inflation.",
                style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.3),
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
                "Historical Range: $range",
                style: const TextStyle(color: kTextMuted, fontSize: 9.5),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 📊 Horizontal Gauge Meter
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 8,
              color: const Color(0xFF090D16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: barRatio.clamp(0.08, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isPressure
                            ? [kAccentAmber, kAccentRed]
                            : [kAccentCyan, kAccentGreen],
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          Text(
            impact,
            style: const TextStyle(
                color: Colors.white70, fontSize: 10.5, height: 1.3),
          ),
        ],
      ),
    );
  }

  // =============================================================
  // TAB 3: ⚖️ HEADWINDS vs TAILWINDS
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
  // TAB 4: 🎯 EQUITY IMPACT MATRIX
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
                "CROSS-BORDER EQUITY IMPACT RADAR",
                style: TextStyle(
                  color: kAccentCyan,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 3),
              Text(
                "Direct correlation tracking between global macro shifts (China dumping, US tech capex, EU auto slowdown) and listed equities.",
                style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.3),
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
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 9.5,
                          height: 1.25,
                        ),
                        textAlign: TextAlign.right,
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
