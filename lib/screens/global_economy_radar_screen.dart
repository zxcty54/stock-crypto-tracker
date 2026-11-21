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

  double? _liveUsdInr;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadDataset();
    _fetchLiveForexRate();
  }

  Future<void> _fetchLiveForexRate() async {
    try {
      final uri = Uri.parse("https://open.er-api.com/v6/latest/USD");
      final response = await http.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final inr = (data['rates']?['INR'] as num?)?.toDouble();
        if (inr != null && inr > 60.0 && mounted) {
          setState(() {
            _liveUsdInr = double.parse(inr.toStringAsFixed(2));
          });
        }
      }
    } catch (_) {}
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
    }
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
            Text(
              _metadata['last_updated'] ?? "Worldwide Pressure vs Expansion Telemetry",
              style: const TextStyle(color: kTextMuted, fontSize: 9.5),
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
            Tab(text: "🗺️ SUPERPOWERS HUD"),
            Tab(text: "⚡ MARGINS & S-D RADAR"),
            Tab(text: "📊 STRESS BAROMETERS"),
            Tab(text: "🎯 SECTOR SENSITIVITY"),
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
                  child: _buildStressGaugesTab(),
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
  // TAB 1: 🗺️ SUPERPOWERS & EXECUTIVE HUD (DATA & GRAPH CENTRIC)
  // =============================================================
  Widget _buildSuperpowersTab() {
    final healthScore = _executiveHud['global_health_score'] ?? 52.4;
    final healthLabel = _executiveHud['global_health_label'] ?? 'EXPANDING';
    final pillars = (_executiveHud['core_pillars'] as List<dynamic>? ?? []);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // 1. Executive Telemetry Strip (Score + Live Quick Ticker)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF131B2A), Color(0xFF0F1726)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
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
                      Text(
                        "$healthScore",
                        style: GoogleFonts.robotoMono(
                          color: kAccentCyan,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Text("/100",
                          style: TextStyle(color: kTextMuted, fontSize: 11)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: kAccentCyan.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          healthLabel,
                          style: const TextStyle(
                            color: kAccentCyan,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _isLiveSynced
                          ? kAccentGreen.withOpacity(0.15)
                          : const Color(0xFF37474F),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _isLiveSynced ? "LIVE CDN" : "SYNCED",
                      style: TextStyle(
                        color: _isLiveSynced ? kAccentGreen : Colors.white70,
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: (healthScore as num).toDouble() / 100.0,
                  backgroundColor: const Color(0xFF1E2B3E),
                  valueColor: const AlwaysStoppedAnimation<Color>(kAccentCyan),
                  minHeight: 5,
                ),
              ),
              const SizedBox(height: 10),

              // Live Ticker Horizontal Scroll Row (Dynamically populated from live telemetry)
              Builder(builder: (context) {
                final double liveUsdInr = _liveUsdInr ??
                    (_currencyTradeTelemetry['usd_inr_current'] as num?)?.toDouble() ??
                    84.42;
                final String usdInrStr = liveUsdInr.toStringAsFixed(2);

                String brentStr = r"$73.40";
                String dxyStr = "106.25";
                String us10yStr = "4.42%";
                String goldStr = r"$2,655";
                String inPmiStr = "58.6";

                for (var g in _stressGauges) {
                  final id = g['id'];
                  final val = g['current_value'];
                  if (id == 'brent_crude' && val != null) brentStr = "\$$val";
                  if ((id == 'dxy' || id == 'dxy_dollar') && val != null) dxyStr = "$val";
                  if ((id == 'us10y' || id == 'us_10y_yield') && val != null) us10yStr = "$val%";
                  if (id == 'gold_spot' && val != null) goldStr = "\$$val";
                }

                for (var sp in _superpowers) {
                  final spId = sp['id'] ?? '';
                  final spName = sp['name'] ?? '';
                  if (spId == 'em_india' || spId == 'india' || spName.toString().contains('India')) {
                    final pmi = sp['vital_stats']?['composite_pmi'];
                    if (pmi != null) inPmiStr = "$pmi".split(' ').first;
                  }
                }

                final double brentNum = double.tryParse(brentStr.replaceAll(RegExp(r'[^\d.]'), '')) ?? 73.4;
                final Color brentCol = brentNum < 78.0 ? kAccentGreen : (brentNum < 85.0 ? kAccentAmber : kAccentRed);

                final Color usdInrCol = liveUsdInr < 83.5 ? kAccentGreen : (liveUsdInr < 84.5 ? kAccentAmber : kAccentRed);

                final double dxyNum = double.tryParse(dxyStr.replaceAll(RegExp(r'[^\d.]'), '')) ?? 106.0;
                final Color dxyCol = dxyNum < 103.0 ? kAccentGreen : (dxyNum < 105.5 ? kAccentAmber : kAccentRed);

                final double us10yNum = double.tryParse(us10yStr.replaceAll(RegExp(r'[^\d.]'), '')) ?? 4.4;
                final Color us10yCol = us10yNum < 4.0 ? kAccentGreen : (us10yNum < 4.35 ? kAccentAmber : kAccentRed);

                final double inPmiNum = double.tryParse(inPmiStr.replaceAll(RegExp(r'[^\d.]'), '')) ?? 58.0;
                final Color inPmiCol = inPmiNum >= 55.0 ? kAccentGreen : (inPmiNum >= 50.0 ? kAccentAmber : kAccentRed);

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildQuickMetricChip("BRENT", brentStr, brentCol),
                      _buildQuickMetricChip("USD/INR", "₹$usdInrStr", usdInrCol),
                      _buildQuickMetricChip("DXY", dxyStr, dxyCol),
                      _buildQuickMetricChip("US 10Y", us10yStr, us10yCol),
                      _buildQuickMetricChip("GOLD", goldStr, kAccentGreen),
                      _buildQuickMetricChip("IN PMI", inPmiStr, inPmiCol),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 2. Visual Regional PMI Column Chart
        _buildPmiColumnChart(pillars),
        const SizedBox(height: 12),

        // 3. Superpower Data Grids
        ..._superpowers.map((p) => _buildSuperpowerDataCard(p)),
      ],
    );
  }

  Widget _buildQuickMetricChip(String label, String val, Color col) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF090D16),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF1E2B3E)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("$label: ",
              style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 9,
                  fontWeight: FontWeight.bold)),
          Text(
            val,
            style: GoogleFonts.robotoMono(
              color: col,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPmiColumnChart(List<dynamic> pillars) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kCardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "COMPOSITE PMI BENCHMARK (50 = THRESHOLD)",
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: kAccentAmber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  "EXPANSION LINE: 50.0",
                  style: TextStyle(
                    color: kAccentAmber,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

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
              final double barHeight = heightFactor * 85.0;

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
                  const SizedBox(height: 3),
                  Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      Container(
                        width: 26,
                        height: 85,
                        decoration: BoxDecoration(
                          color: const Color(0xFF131B2A),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      Positioned(
                        bottom: 42.5,
                        child: Container(
                          width: 30,
                          height: 1.5,
                          color: kAccentAmber.withOpacity(0.4),
                        ),
                      ),
                      Container(
                        width: 26,
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
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(flag, style: const TextStyle(fontSize: 14)),
                  Text(
                    region.contains(' ') ? region.split(' ').first : region,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white70,
                      fontSize: 8,
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

  Widget _buildSuperpowerDataCard(Map<String, dynamic> p) {
    final name = p['name'] ?? '';
    final flag = p['flag'] ?? '';
    final statusLabel = p['status_label'] ?? '';
    final rate = p['central_bank_rate'] ?? '';
    final inflation = p['inflation_rate'] ?? '';
    final vitalStats = (p['vital_stats'] as Map<String, dynamic>? ?? {});
    final pressurePoints = (p['pressure_points'] as List<dynamic>? ?? []);
    final expansionEngines = (p['expansion_engines'] as List<dynamic>? ?? []);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kCardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(flag, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Text(
                    name,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              Builder(builder: (context) {
                final bool isNegativeStatus = statusLabel.contains('CONTRACTION') ||
                    statusLabel.contains('PRESSURE') ||
                    statusLabel.contains('SHOCK') ||
                    statusLabel.contains('DRAG') ||
                    statusLabel.contains('SLOWDOWN');
                final bool isPositiveStatus = statusLabel.contains('GROWTH') ||
                    statusLabel.contains('EXPANSION') ||
                    statusLabel.contains('RESILIENCE') ||
                    statusLabel.contains('REBOUND') ||
                    statusLabel.contains('LEADER');
                final Color statusCol = isNegativeStatus
                    ? kAccentRed
                    : (isPositiveStatus ? kAccentGreen : kAccentCyan);

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: statusCol.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusCol,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "Rate: $rate • Inflation: $inflation",
            style: const TextStyle(color: kTextMuted, fontSize: 9.5),
          ),
          const SizedBox(height: 8),

          // Vital Stats Grid (Compact Data Grid)
          if (vitalStats.isNotEmpty)
            Wrap(
              spacing: 5,
              runSpacing: 4,
              children: vitalStats.entries.map((entry) {
                final k = entry.key.replaceAll('_', ' ').toUpperCase();
                final v = entry.value.toString();
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF090D16),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF1E2B3E)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("$k: ",
                          style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 8,
                              fontWeight: FontWeight.bold)),
                      Text(
                        v,
                        style: GoogleFonts.robotoMono(
                          color: Colors.white,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 8),

          // Compact Pressure & Expansion Badges (Full text, no truncation)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("🔴 PRESSURE (DABAO)",
                        style: TextStyle(
                            color: kAccentRed,
                            fontSize: 8,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    ...pressurePoints.take(2).map((pt) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          "• ${pt['title']}",
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 8.5, height: 1.25),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("🟢 EXPANSION",
                        style: TextStyle(
                            color: kAccentGreen,
                            fontSize: 8,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    ...expansionEngines.take(2).map((en) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          "• ${en['title']}",
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 8.5, height: 1.25),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =============================================================
  // TAB 2: ⚡ MARGINS & SUPPLY-DEMAND (GRAPH & DATA CENTRIC)
  // =============================================================
  Widget _buildSupplyDemandAndMarginsTab() {
    final expansionSectors =
        (_sectorMarginMatrix['margin_expansion_sectors'] as List<dynamic>? ?? []);
    final pressureSectors =
        (_sectorMarginMatrix['margin_pressure_sectors'] as List<dynamic>? ?? []);

    final double usdInr = _liveUsdInr ??
        (_currencyTradeTelemetry['usd_inr_current'] as num?)?.toDouble() ??
        84.42;
    final inrStress = _currencyTradeTelemetry['stress_level'] ?? 'MANAGED FLOAT';
    final rbiForex = _currencyTradeTelemetry['rbi_forex_warchest'] ?? r'$675 Billion';
    final crudeRule =
        (_currencyTradeTelemetry['crude_sensitivity_rule'] as Map<String, dynamic>? ?? {});
    final eximDynamics =
        (_currencyTradeTelemetry['import_export_dynamics'] as List<dynamic>? ?? []);

    final shocks =
        (_shockTransmissionEngine['shocks'] as List<dynamic>? ?? []);
    final levers = (_supplyDemandLevers['levers'] as List<dynamic>? ?? []);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // 1. Live Geopolitical Shock Alert Strip
        if (shocks.isNotEmpty) _buildActiveShockStrip(shocks.first),
        const SizedBox(height: 12),

        // 2. 📊 GRAPHICAL CHART: Sector Margin Delta (Expansion vs Compression)
        _buildSectorMarginChart(expansionSectors, pressureSectors),
        const SizedBox(height: 12),

        // 3. 📊 GRAPHICAL GAUGE: USD/INR & Trade Deficit Sensitivity Meter
        _buildCurrencyAndTradeGauge(usdInr, inrStress, rbiForex, crudeRule, eximDynamics),
        const SizedBox(height: 12),

        // 4. 4 Global Levers of Supply & Demand Control (Data Architecture)
        Text(
          "4 GLOBAL LEVERS OF SUPPLY & DEMAND CONTROL",
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        ...levers.map((lev) => _buildLeverCompactCard(lev)),
      ],
    );
  }

  Widget _buildActiveShockStrip(Map<String, dynamic> shock) {
    final name = shock['shock_name'] ?? '';
    final severity = shock['severity'] ?? '';
    final winners = (shock['margin_winners'] as List<dynamic>? ?? []);
    final losers = (shock['margin_losers'] as List<dynamic>? ?? []);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: kCardDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kAccentAmber.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: kAccentAmber, size: 14),
                  const SizedBox(width: 5),
                  Text(
                    "LIVE SHOCK SURVEILLANCE",
                    style: GoogleFonts.plusJakartaSans(
                      color: kAccentAmber,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: kAccentRed.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  severity,
                  style: const TextStyle(
                    color: kAccentRed,
                    fontSize: 7.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: const TextStyle(
                color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),

          // Winners & Losers Stocks Strip (Full readability)
          if (winners.isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("🟢 WINNERS: ",
                    style: TextStyle(
                        color: kAccentGreen, fontSize: 8.5, fontWeight: FontWeight.bold)),
                Expanded(
                  child: Text(
                    winners.join(" • "),
                    style: GoogleFonts.robotoMono(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
          ],
          if (losers.isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("🔴 LOSERS: ",
                    style: TextStyle(
                        color: kAccentRed, fontSize: 8.5, fontWeight: FontWeight.bold)),
                Expanded(
                  child: Text(
                    losers.join(" • "),
                    style: GoogleFonts.robotoMono(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
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

  Widget _buildSectorMarginChart(List<dynamic> expansion, List<dynamic> pressure) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kCardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "SECTOR MARGIN DELTA (BPS) & DEMAND GRAPH",
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              const Text("Delta Bps",
                  style: TextStyle(color: kTextMuted, fontSize: 8.5)),
            ],
          ),
          const SizedBox(height: 10),

          // 🟢 EXPANSION BARS
          ...expansion.map((sec) => _buildMarginBar(sec, isExpansion: true)),

          const Divider(color: kBorderSubtle, height: 16),

          // 🔴 PRESSURE BARS
          ...pressure.map((sec) => _buildMarginBar(sec, isExpansion: false)),
        ],
      ),
    );
  }

  Widget _buildMarginBar(Map<String, dynamic> sec, {required bool isExpansion}) {
    final sector = sec['sector'] ?? '';
    final int delta = (sec['margin_delta_bps'] as num?)?.toInt() ?? 0;
    final int demand = (sec['demand_score'] as num?)?.toInt() ?? 50;
    final Color barColor = isExpansion ? kAccentGreen : kAccentRed;

    final double widthFactor = (delta.abs() / 280.0).clamp(0.12, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  sector,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: barColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      "${delta > 0 ? '+' : ''}$delta bps",
                      style: GoogleFonts.robotoMono(
                        color: barColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    "Score: $demand",
                    style: TextStyle(
                      color: demand > 75 ? kAccentGreen : Colors.white54,
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Visual Bar (Full width)
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kCardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kAccentCyan.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "USD / INR & TRADE DEFICIT SENSITIVITY GAUGE",
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: kAccentAmber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  inrStress,
                  style: const TextStyle(
                    color: kAccentAmber,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Rates Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "SPOT: ₹$usdInr",
                style: GoogleFonts.robotoMono(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                "WARCHEST: $rbiForex",
                style: GoogleFonts.robotoMono(
                  color: kAccentGreen,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 3-Band Color Gauge Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Row(
              children: [
                Expanded(
                  flex: 33,
                  child: Container(height: 6, color: kAccentGreen.withOpacity(0.7)),
                ),
                Expanded(
                  flex: 33,
                  child: Container(height: 6, color: kAccentAmber.withOpacity(0.7)),
                ),
                Expanded(
                  flex: 34,
                  child: Container(height: 6, color: kAccentRed.withOpacity(0.85)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("₹82.50 (Inflow)",
                  style: TextStyle(color: Colors.white54, fontSize: 7.5)),
              const Text("₹83.80 (Float)",
                  style: TextStyle(color: Colors.white54, fontSize: 7.5)),
              Text("₹${usdInr.toStringAsFixed(2)} (Current Float)",
                  style: const TextStyle(
                      color: kAccentRed,
                      fontSize: 8,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),

          // The $10 Crude Rule Infographic Box
          if (crudeRule.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF090D16),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF1E2B3E)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    crudeRule['rule_title'] ?? r'The $10 Crude Rule',
                    style: const TextStyle(
                      color: kAccentCyan,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "• Deficit: ${crudeRule['stat_trade_deficit'] ?? ''}",
                          style: const TextStyle(
                              color: kAccentAmber, fontSize: 8.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          "• INR: ${crudeRule['stat_currency_impact'] ?? ''}",
                          style: const TextStyle(
                              color: kAccentRed, fontSize: 8.5, fontWeight: FontWeight.bold),
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

  Widget _buildLeverCompactCard(Map<String, dynamic> lev) {
    final name = lev['name'] ?? '';
    final controller = lev['controller'] ?? '';
    final transmission = lev['india_transmission'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: kCardDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorderSubtle),
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
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            "Controller: $controller",
            style: const TextStyle(color: kAccentCyan, fontSize: 8.5),
          ),
          const SizedBox(height: 4),
          Text(
            transmission,
            style: const TextStyle(
                color: Colors.white70, fontSize: 9, height: 1.25),
          ),
        ],
      ),
    );
  }

  // =============================================================
  // TAB 3: 📊 STRESS BAROMETERS (DATA & GAUGE METERS)
  // =============================================================
  Widget _buildStressGaugesTab() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _buildStressBarometerOverview(),
        ..._stressGauges.map((g) => _buildStressGaugeCard(g)),
      ],
    );
  }

  Widget _buildStressBarometerOverview() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF131D2E), Color(0xFF0C1322)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
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
                  const Icon(Icons.speed_rounded, color: kAccentCyan, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    "GLOBAL MACRO STRESS BAROMETER",
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: kAccentAmber.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  "6 GAUGES ACTIVE",
                  style: TextStyle(
                    color: kAccentAmber,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Comparative Horizontal Bar Chart for all 6 items
          ..._stressGauges.map((g) {
            final name = g['name']?.toString().split('(').first.trim() ?? '';
            final val = g['current_value'];
            final unit = g['unit'] ?? '';
            final double ratio = (g['bar_ratio'] as num?)?.toDouble() ?? 0.5;
            final isPressure = g['flow_direction'] == 'PRESSURE';
            final Color color = isPressure ? kAccentRed : (ratio > 0.7 ? kAccentAmber : kAccentGreen);

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        "  (" + (ratio * 100).toInt().toString() + "%)",
                        style: GoogleFonts.robotoMono(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: SizedBox(
                      height: 5.5,
                      child: Stack(
                        children: [
                          Container(color: const Color(0xFF090D16)),
                          FractionallySizedBox(
                            widthFactor: ratio.clamp(0.05, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [color.withOpacity(0.6), color],
                                ),
                              ),
                            ),
                          ),
                        ],
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

  Widget _buildStressGaugeCard(Map<String, dynamic> g) {
    final name = g['name'] ?? '';
    final val = g['current_value'];
    final unit = g['unit'] ?? '';
    final statusLabel = g['status_label'] ?? '';
    final double barRatio = (g['bar_ratio'] as num?)?.toDouble() ?? 0.5;
    final isPressure = g['flow_direction'] == 'PRESSURE';
    final Color barColor = isPressure ? kAccentRed : kAccentGreen;
    final range = g['historical_range'] ?? '';
    final String indiaImpact = _getGaugeIndiaSummary(g['id'], g['market_impact'] ?? '');
    final List<String> assets = _getGaugeAssets(g['id']);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kCardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: barColor.withOpacity(0.25)),
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
                    fontSize: 12,
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

          // Big Metric Value & Range
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    "$val",
                    style: GoogleFonts.robotoMono(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    unit,
                    style: TextStyle(
                      color: barColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Text(
                "Range: $range",
                style: const TextStyle(color: kTextMuted, fontSize: 9.5),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Multi-Zone Visual Range Barometer
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final double pointerPos = (constraints.maxWidth * barRatio.clamp(0.04, 0.96)) - 4;
                  return Padding(
                    padding: EdgeInsets.only(left: pointerPos.clamp(0.0, constraints.maxWidth - 8)),
                    child: const Icon(Icons.arrow_drop_down, color: Colors.white, size: 12),
                  );
                },
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: SizedBox(
                  height: 6,
                  child: Row(
                    children: [
                      Expanded(
                        flex: 35,
                        child: Container(color: kAccentGreen.withOpacity(0.7)),
                      ),
                      const SizedBox(width: 1.5),
                      Expanded(
                        flex: 35,
                        child: Container(color: kAccentAmber.withOpacity(0.7)),
                      ),
                      const SizedBox(width: 1.5),
                      Expanded(
                        flex: 30,
                        child: Container(color: kAccentRed.withOpacity(0.7)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text("🟢 LOW / BENIGN", style: TextStyle(color: kTextMuted, fontSize: 8)),
                  Text("🟡 ELEVATED", style: TextStyle(color: kTextMuted, fontSize: 8)),
                  Text("🔴 SEVERE STRESS", style: TextStyle(color: kTextMuted, fontSize: 8)),
                ],
              ),
            ],
          ),

          // 🇮🇳 India Transmission Strip (Crisp, wrapped, no truncation)
          if (indiaImpact.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF090D16),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1.5),
                    child: Text("🇮🇳", style: TextStyle(fontSize: 11)),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      indiaImpact,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Impacted Asset Chips
          if (assets.isNotEmpty) ...[
            const SizedBox(height: 7),
            Wrap(
              spacing: 5,
              runSpacing: 4,
              children: assets.map((a) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C1320),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF1E2D44)),
                  ),
                  child: Text(
                    a,
                    style: GoogleFonts.robotoMono(
                      color: kAccentCyan,
                      fontWeight: FontWeight.w700,
                      fontSize: 8.5,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  String _getGaugeIndiaSummary(String? id, String defaultText) {
    switch (id) {
      case 'dxy':
      case 'dxy_dollar':
        return "Drains emerging market liquidity • Pressures Rupee toward 84.42 • FII outflow bias";
      case 'us10y':
      case 'us_10y_yield':
        return "Compresses equity PE multiples • Raises refinancing cost on dollar corporate debt";
      case 'brent_crude':
        return "Oil sweet spot keeps CAD manageable • Boosts operating margins for Paints, Chemicals & OMCs";
      case 'gold_spot':
        return "Confirms central bank reserve diversification (PBOC, RBI) into neutral physical assets";
      case 'semicon_utilization':
        return "Massive AI capex utilization spills over into Indian EMS & electronics packaging orderbooks";
      case 'baltic_dry':
        return "Steady raw material bulk shipments without pandemic maritime freight cost disruptions";
      default:
        return defaultText.split('.').first;
    }
  }

  List<String> _getGaugeAssets(String? id) {
    switch (id) {
      case 'dxy':
      case 'dxy_dollar':
        return ['USD/INR PAIR', 'FII FLOW BASKET', 'BANKING SECTOR'];
      case 'us10y':
      case 'us_10y_yield':
        return ['TECH EQUITIES', 'IT EXPORTERS', 'EM DEBT BASKET'];
      case 'brent_crude':
        return ['DECORATIVE PAINTS', 'SPECIALTY CHEMICALS', 'OIL REFINING'];
      case 'gold_spot':
        return ['GOLD SOVEREIGN', 'GEMS & JEWELLERY', 'GOLD NBFC BASKET'];
      case 'semicon_utilization':
        return ['ELECTRONICS EMS', 'AUTO ER&D', 'TECH HARDWARE'];
      case 'baltic_dry':
        return ['PORT INFRA', 'BULK METALS', 'MARITIME FREIGHT'];
      default:
        return [];
    }
  }

  // =============================================================
  // TAB 4: 🎯 SECTOR & INDUSTRY MACRO SENSITIVITY MATRIX
  // =============================================================
  Widget _buildEquityImpactTab() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // SEBI Statutory Notice Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1524),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF1E2B3E)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.shield_outlined, color: kAccentCyan, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "SEBI Statutory Notice: Sectoral macroeconomic research & input-cost sensitivity analysis. Not an investment recommendation, advisory, or buy/sell tip.",
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white70,
                    fontSize: 9.5,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
        ..._equityImpacts.map((e) => _buildIndustrySensitivityCard(e)),
      ],
    );
  }

  Widget _buildIndustrySensitivityCard(Map<String, dynamic> theme) {
    final tName = theme['theme'] ?? '';
    final direction = theme['impact_direction'] ?? '';
    final status = theme['status'] ?? (direction == 'BENEFICIARY' ? 'EXPANDING' : 'HEADWIND');
    final index = theme['benchmark_index'] ?? 'Sector Basket';
    final sensitivity = theme['cost_sensitivity'] ?? '';
    final channel = theme['transmission_channel'] ?? '';
    final segments = (theme['exposed_segments'] as List<dynamic>? ?? []);

    final bool isBeneficiary = direction == 'BENEFICIARY';
    final Color col = isBeneficiary ? kAccentGreen : kAccentRed;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
                  tName,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: col.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: col,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, color: kAccentCyan, size: 12),
              const SizedBox(width: 4),
              Text(
                "Benchmark Index: $index",
                style: GoogleFonts.robotoMono(
                  color: kAccentCyan,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Macro Input-Cost & Transmission Data Box
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: const Color(0xFF090D16),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF1E2B3E)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (sensitivity.isNotEmpty) ...[
                  Row(
                    children: const [
                      Icon(Icons.tune_rounded, color: Colors.white38, size: 11),
                      SizedBox(width: 4),
                      Text(
                        "INPUT-COST / COGS SENSITIVITY",
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    sensitivity,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 9.5,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (channel.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(Icons.sync_alt_rounded, color: col, size: 11),
                      const SizedBox(width: 4),
                      Text(
                        "MACRO TRANSMISSION CHANNEL",
                        style: TextStyle(
                          color: col,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    channel,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),

          if (segments.isNotEmpty) ...[
            const SizedBox(height: 9),
            Row(
              children: const [
                Icon(Icons.category_rounded, color: Colors.white38, size: 10),
                SizedBox(width: 4),
                Text(
                  "AFFECTED INDUSTRY SUB-SEGMENTS",
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Wrap(
              spacing: 5,
              runSpacing: 4,
              children: segments.map((seg) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10192A),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF22344D)),
                  ),
                  child: Text(
                    seg.toString(),
                    style: const TextStyle(color: Colors.white70, fontSize: 8.5),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
