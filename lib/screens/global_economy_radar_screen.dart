import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'economy_demand_radar_screen.dart';
import 'company_intelligence_screen.dart';
import 'stock_delivery_history_screen.dart';
import '../widgets/macro_research_desk_view.dart';

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
  Map<String, dynamic> _fiiDiiFlows = {};
  Map<String, dynamic> _fiiDiiDerivatives = {};
  List<Map<String, dynamic>> _upcomingTriggers = [];
  Map<String, dynamic> _marketInternals = {};
  Map<String, dynamic> _promoterRadar = {};
  Map<String, dynamic> _bulkBlockDeals = {};
  String _selectedImpactFilter = 'ALL';

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
    _fiiDiiFlows = Map<String, dynamic>.from(data['fii_dii_flows'] ?? {});
    _fiiDiiDerivatives = Map<String, dynamic>.from(data['fii_dii_derivatives'] ?? {});
    _upcomingTriggers = List<Map<String, dynamic>>.from(
        data['upcoming_macro_triggers'] ?? []);
    _marketInternals = Map<String, dynamic>.from(data['market_internals'] ?? {});
    _promoterRadar = Map<String, dynamic>.from(data['promoter_insider_radar'] ?? {});
    _bulkBlockDeals = Map<String, dynamic>.from(data['smart_bulk_block_deals'] ?? {});
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

        // Institutional FII vs DII Flow Divergence Bar
        if (_fiiDiiFlows.isNotEmpty) ...[
          _buildFiiDiiDivergenceCard(),
          const SizedBox(height: 12),
        ],

        // Institutional Market Internals & Advance-Decline Camouflage Barometer
        if (_marketInternals.isNotEmpty) ...[
          _buildMarketInternalsCard(),
          const SizedBox(height: 12),
        ],

        // Institutional Smart Money: Promoter Pledge & Smart Bulk Deals
        if (_promoterRadar.isNotEmpty || _bulkBlockDeals.isNotEmpty) ...[
          _buildPromoterAndBulkDealsCard(),
          const SizedBox(height: 12),
        ],

        // Upcoming Macro Triggers Countdown
        if (_upcomingTriggers.isNotEmpty) ...[
          _buildUpcomingTriggersStrip(),
          const SizedBox(height: 12),
        ],

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

  Widget _buildFiiDiiDivergenceCard() {
    final double fiiNet = (_fiiDiiFlows['fii_net_crores'] as num?)?.toDouble() ?? -2450.0;
    final double diiNet = (_fiiDiiFlows['dii_net_crores'] as num?)?.toDouble() ?? 3180.0;
    final double netPulse = (_fiiDiiFlows['net_pulse_crores'] as num?)?.toDouble() ?? 730.0;
    final double absorption = (_fiiDiiFlows['absorption_ratio'] as num?)?.toDouble() ?? 1.3;
    final String verdict = _fiiDiiFlows['regime_verdict'] ?? 'DII Absorption Moat';
    final String tradeDate = _fiiDiiDerivatives['trade_date'] ??
        _fiiDiiFlows['trade_date'] ??
        'Market Close';

    final bool isNetPositive = netPulse >= 0;
    final Color netColor = isNetPositive ? kAccentGreen : kAccentRed;

    final double fiiFactor = (fiiNet.abs() / 5000.0).clamp(0.12, 1.0);
    final double diiFactor = (diiNet.abs() / 5000.0).clamp(0.12, 1.0);

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
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.compare_arrows_rounded,
                        color: kAccentCyan, size: 15),
                    const SizedBox(width: 5),
                    Text(
                      "INSTITUTIONAL CASH (FII vs DII)",
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF090D16),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Text(
                        tradeDate,
                        style: const TextStyle(
                          color: kTextMuted,
                          fontSize: 7,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: netColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  verdict,
                  style: TextStyle(
                    color: netColor,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Numbers Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("FOREIGN (FII)",
                      style: TextStyle(color: kAccentRed, fontSize: 8.5, fontWeight: FontWeight.bold)),
                  Text(
                    "${fiiNet > 0 ? '+' : ''}₹${fiiNet.toStringAsFixed(0)} Cr",
                    style: GoogleFonts.robotoMono(
                      color: fiiNet >= 0 ? kAccentGreen : kAccentRed,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF090D16),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: netColor.withOpacity(0.35)),
                ),
                child: Column(
                  children: [
                    const Text("NET PULSE",
                        style: TextStyle(color: Colors.white38, fontSize: 7.5, fontWeight: FontWeight.bold)),
                    Text(
                      "${netPulse > 0 ? '+' : ''}₹${netPulse.toStringAsFixed(0)} Cr",
                      style: GoogleFonts.robotoMono(
                        color: netColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text("DOMESTIC (DII)",
                      style: TextStyle(color: kAccentGreen, fontSize: 8.5, fontWeight: FontWeight.bold)),
                  Text(
                    "${diiNet > 0 ? '+' : ''}₹${diiNet.toStringAsFixed(0)} Cr",
                    style: GoogleFonts.robotoMono(
                      color: diiNet >= 0 ? kAccentGreen : kAccentRed,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Visual Divergence Gauge Bar
          Row(
            children: [
              // FII Bar (Left, Red)
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      flex: ((1.0 - fiiFactor) * 100).toInt(),
                      child: Container(height: 5, color: const Color(0xFF131B2A)),
                    ),
                    Expanded(
                      flex: (fiiFactor * 100).toInt(),
                      child: Container(
                        height: 5,
                        decoration: BoxDecoration(
                          color: kAccentRed,
                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(2)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 2,
                height: 10,
                color: Colors.white54,
              ),
              // DII Bar (Right, Green)
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      flex: (diiFactor * 100).toInt(),
                      child: Container(
                        height: 5,
                        decoration: BoxDecoration(
                          color: kAccentGreen,
                          borderRadius: const BorderRadius.horizontal(right: Radius.circular(2)),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: ((1.0 - diiFactor) * 100).toInt(),
                      child: Container(height: 5, color: const Color(0xFF131B2A)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text("OUTFLOW DABAO", style: TextStyle(color: Colors.white38, fontSize: 7.5)),
              Text("0 BASE", style: TextStyle(color: Colors.white38, fontSize: 7.5)),
              Text("SIP ABSORPTION", style: TextStyle(color: Colors.white38, fontSize: 7.5)),
            ],
          ),

          if (_fiiDiiDerivatives.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(height: 1, color: const Color(0xFF1E2B3E)),
            const SizedBox(height: 10),
            _buildDerivativesSentimentSection(),
          ],
        ],
      ),
    );
  }

  Widget _buildDerivativesSentimentSection() {
    final double fiiLongRatio = (_fiiDiiDerivatives['fii_long_ratio'] as num?)?.toDouble() ?? 19.4;
    final double fiiShortRatio = (_fiiDiiDerivatives['fii_short_ratio'] as num?)?.toDouble() ?? 80.6;
    final int fiiLong = (_fiiDiiDerivatives['fii_index_long_contracts'] as num?)?.toInt() ?? 28500;
    final int fiiShort = (_fiiDiiDerivatives['fii_index_short_contracts'] as num?)?.toInt() ?? 118500;
    final int fiiNet = (_fiiDiiDerivatives['fii_net_contracts'] as num?)?.toInt() ?? -90000;
    final double clientLongRatio = (_fiiDiiDerivatives['client_long_ratio'] as num?)?.toDouble() ?? 66.2;
    final double diiLongRatio = (_fiiDiiDerivatives['dii_long_ratio'] as num?)?.toDouble() ?? 40.0;
    final String zoneLabel = _fiiDiiDerivatives['zone_label'] ?? 'Extreme Short Squeeze (< 20% Long)';

    final bool isExtremeSqueeze = fiiLongRatio < 20.0;
    final Color badgeColor = isExtremeSqueeze ? kAccentRed : (fiiLongRatio < 40.0 ? kAccentAmber : kAccentGreen);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics_rounded, color: kAccentCyan, size: 14),
                const SizedBox(width: 5),
                Text(
                  "NSE INDEX FUTURES OI (NIFTY & BANKNIFTY)",
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: badgeColor.withOpacity(0.18),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: badgeColor.withOpacity(0.4)),
              ),
              child: Text(
                zoneLabel,
                style: TextStyle(
                  color: badgeColor,
                  fontSize: 7.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Long vs Short Ratio Numbers
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "LONG: ${(fiiLong / 1000).toStringAsFixed(1)}k (${fiiLongRatio.toStringAsFixed(1)}%)",
              style: GoogleFonts.robotoMono(
                color: kAccentGreen,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF090D16),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                "${fiiNet > 0 ? '+' : ''}${(fiiNet / 1000).toStringAsFixed(1)}k NET",
                style: GoogleFonts.robotoMono(
                  color: fiiNet >= 0 ? kAccentGreen : kAccentRed,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              "SHORT: ${(fiiShort / 1000).toStringAsFixed(1)}k (${fiiShortRatio.toStringAsFixed(1)}%)",
              style: GoogleFonts.robotoMono(
                color: kAccentRed,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Multi-segment Long vs Short Meter Bar
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Row(
            children: [
              Expanded(
                flex: (fiiLongRatio * 10).toInt().clamp(5, 950),
                child: Container(
                  height: 6,
                  color: kAccentGreen,
                ),
              ),
              Expanded(
                flex: (fiiShortRatio * 10).toInt().clamp(5, 950),
                child: Container(
                  height: 6,
                  color: kAccentRed,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),

        // Scale marker row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text("0% LONG", style: TextStyle(color: Colors.white38, fontSize: 7)),
            Text("20% SQUEEZE LINE", style: TextStyle(color: kAccentAmber, fontSize: 7, fontWeight: FontWeight.bold)),
            Text("50% NEUTRAL", style: TextStyle(color: Colors.white38, fontSize: 7)),
            Text("100% SHORT", style: TextStyle(color: Colors.white38, fontSize: 7)),
          ],
        ),
        const SizedBox(height: 8),

        // Counterparty Contrast Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF090D16),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text("RETAIL COUNTERPART: ", style: TextStyle(color: Colors.white54, fontSize: 8)),
                  Text(
                    "${clientLongRatio.toStringAsFixed(1)}% LONG",
                    style: GoogleFonts.robotoMono(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Row(
                children: [
                  const Text("DII FUTURES: ", style: TextStyle(color: Colors.white54, fontSize: 8)),
                  Text(
                    "${diiLongRatio.toStringAsFixed(1)}% LONG",
                    style: GoogleFonts.robotoMono(color: kAccentCyan, fontSize: 8.5, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMarketInternalsCard() {
    final int tot = (_marketInternals['total_stocks_screened'] as num?)?.toInt() ?? 1589;
    final int adv = (_marketInternals['advances_count'] as num?)?.toInt() ?? 545;
    final int dec = (_marketInternals['declines_count'] as num?)?.toInt() ?? 1040;
    final double breadthPct = (_marketInternals['breadth_thrust_pct'] as num?)?.toDouble() ?? 34.4;
    final double decPct = (100.0 - breadthPct).clamp(0.0, 100.0);

    final String regime = _marketInternals['market_regime'] ?? 'INDEX_CAMOUFLAGE';
    final String regimeTruth = _marketInternals['regime_truth'] ??
        'Heavyweights holding headline index while 65%+ broader stocks are in net decline.';

    final double vix = (_marketInternals['india_vix'] as num?)?.toDouble() ?? 13.4;
    final String vixLabel = _marketInternals['vix_label'] ?? 'Healthy Structural Trend (12.0 - 15.5)';

    final bool isCamouflage = regime == 'INDEX_CAMOUFLAGE';
    final bool isAccumulation = regime == 'BROAD_ACCUMULATION';
    final Color regimeColor = isCamouflage ? kAccentRed : (isAccumulation ? kAccentGreen : kAccentAmber);

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
              Row(
                children: [
                  const Icon(Icons.insights_rounded, color: kAccentCyan, size: 15),
                  const SizedBox(width: 5),
                  Text(
                    "MARKET INTERNALS & CAMOUFLAGE RADAR",
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: regimeColor.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: regimeColor.withOpacity(0.4)),
                ),
                child: Text(
                  isCamouflage ? "🚨 INDEX CAMOUFLAGE" : (isAccumulation ? "🟢 BROAD ACCUMULATION" : "BIFURCATED"),
                  style: TextStyle(
                    color: regimeColor,
                    fontSize: 7.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Advance vs Decline Numbers Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "ADVANCES: $adv (${breadthPct.toStringAsFixed(1)}%)",
                style: GoogleFonts.robotoMono(
                  color: kAccentGreen,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF090D16),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "$tot NSE STOCKS AUDITED",
                  style: const TextStyle(color: Colors.white54, fontSize: 8, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                "DECLINES: $dec (${decPct.toStringAsFixed(1)}%)",
                style: GoogleFonts.robotoMono(
                  color: kAccentRed,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Visual Breadth Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Row(
              children: [
                Expanded(
                  flex: (breadthPct * 10).toInt().clamp(5, 950),
                  child: Container(height: 6, color: kAccentGreen),
                ),
                Expanded(
                  flex: (decPct * 10).toInt().clamp(5, 950),
                  child: Container(height: 6, color: kAccentRed),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text("0% ADVANCES", style: TextStyle(color: Colors.white38, fontSize: 7)),
              Text("50% BREADTH PIVOT", style: TextStyle(color: Colors.white38, fontSize: 7)),
              Text("100% ADVANCES", style: TextStyle(color: Colors.white38, fontSize: 7)),
            ],
          ),
          const SizedBox(height: 6),

          // 1-line Camouflage Truth Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF090D16),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: regimeColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  isCamouflage ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                  color: regimeColor,
                  size: 12,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    regimeTruth,
                    style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 8.5, height: 1.25),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Divider
          Container(height: 1, color: const Color(0xFF1E2B3E)),
          const SizedBox(height: 8),

          // India VIX Barometer Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.speed_rounded, color: kAccentAmber, size: 13),
                  const SizedBox(width: 4),
                  Text(
                    "INDIA VIX: ${vix.toStringAsFixed(2)}",
                    style: GoogleFonts.robotoMono(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              Text(
                vixLabel,
                style: const TextStyle(color: kAccentCyan, fontSize: 8, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 5),

          // Multi-zone VIX meter
          Row(
            children: [
              Expanded(child: Container(height: 4, decoration: BoxDecoration(color: kAccentGreen.withOpacity(0.6), borderRadius: const BorderRadius.horizontal(left: Radius.circular(2))))),
              const SizedBox(width: 2),
              Expanded(child: Container(height: 4, color: kAccentCyan.withOpacity(0.6))),
              const SizedBox(width: 2),
              Expanded(child: Container(height: 4, color: kAccentAmber.withOpacity(0.6))),
              const SizedBox(width: 2),
              Expanded(child: Container(height: 4, decoration: BoxDecoration(color: kAccentRed.withOpacity(0.6), borderRadius: const BorderRadius.horizontal(right: Radius.circular(2))))),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text("< 12 COMPLACENCY", style: TextStyle(color: Colors.white38, fontSize: 6.5)),
              Text("12-15.5 STEADY", style: TextStyle(color: Colors.white38, fontSize: 6.5)),
              Text("15.5-21 EVENT", style: TextStyle(color: Colors.white38, fontSize: 6.5)),
              Text("> 21 PANIC BOTTOM", style: TextStyle(color: Colors.white38, fontSize: 6.5)),
            ],
          ),
          const SizedBox(height: 8),

          // Bottom Action: Inspect Delivery vs Churn Traps
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => _showDeliveryVsChurnSheet(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: kAccentCyan.withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: kAccentCyan.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    "Inspect Top 6 Real Delivery Buys vs Operator Churn Traps",
                    style: TextStyle(
                      color: kAccentCyan,
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: kAccentCyan, size: 13),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeliveryVsChurnSheet(BuildContext context) {
    final List<dynamic> realBuys = (_marketInternals['top_delivery_accumulations'] as List<dynamic>? ?? []);
    final List<dynamic> churnTraps = (_marketInternals['top_churn_distribution_traps'] as List<dynamic>? ?? []);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F1726),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          expand: false,
          builder: (context, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.layers_rounded, color: kAccentCyan, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      "INSTITUTIONAL TRUTH: DELIVERY vs CHURN",
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                const Text(
                  "Separating genuine demat share lock-in from operator day-trading volume traps.",
                  style: TextStyle(color: kTextMuted, fontSize: 9),
                ),
                const SizedBox(height: 14),

                // SECTION 1: REAL DELIVERY ACCUMULATION
                Row(
                  children: const [
                    Icon(Icons.lock_rounded, color: kAccentGreen, size: 12),
                    SizedBox(width: 5),
                    Text(
                      "🟢 REAL INSTITUTIONAL DEMAT ACCUMULATION (> 95% DELIVERY)",
                      style: TextStyle(
                        color: kAccentGreen,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                ...realBuys.map((st) {
                  final sym = st['symbol']?.toString().toUpperCase() ?? '';
                  final double chg = (st['change_pct'] as num?)?.toDouble() ?? 0.0;
                  final double deliv = (st['delivery_pct'] as num?)?.toDouble() ?? 0.0;
                  final int vol = (st['volume'] as num?)?.toInt() ?? 0;
                  final String volStr = vol > 1000000 ? "${(vol / 1000000).toStringAsFixed(1)}M" : "${(vol / 1000).toStringAsFixed(0)}k";

                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131B2A),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: kAccentGreen.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Text(
                          sym,
                          style: GoogleFonts.robotoMono(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "${chg >= 0 ? '+' : ''}$chg%",
                          style: GoogleFonts.robotoMono(
                            color: chg >= 0 ? kAccentGreen : kAccentRed,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: kAccentGreen.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "${deliv.toStringAsFixed(1)}% Delivery ($volStr)",
                            style: GoogleFonts.robotoMono(
                              color: kAccentGreen,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StockDeliveryHistoryScreen(initialSymbol: sym),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1F293D),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              "Delivery →",
                              style: TextStyle(color: kAccentCyan, fontSize: 8.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 14),

                // SECTION 2: OPERATOR CHURN TRAPS
                Row(
                  children: const [
                    Icon(Icons.shuffle_rounded, color: kAccentRed, size: 12),
                    SizedBox(width: 5),
                    Text(
                      "🔴 OPERATOR CHURN TRAPS (< 15% DELIVERY, DAY-TRADING CHURN)",
                      style: TextStyle(
                        color: kAccentRed,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                ...churnTraps.map((st) {
                  final sym = st['symbol']?.toString().toUpperCase() ?? '';
                  final double chg = (st['change_pct'] as num?)?.toDouble() ?? 0.0;
                  final double deliv = (st['delivery_pct'] as num?)?.toDouble() ?? 0.0;
                  final int vol = (st['volume'] as num?)?.toInt() ?? 0;
                  final String volStr = vol > 10000000 ? "${(vol / 10000000).toStringAsFixed(1)} Cr" : (vol > 100000 ? "${(vol / 100000).toStringAsFixed(1)}L" : "${(vol / 1000).toStringAsFixed(0)}k");

                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131B2A),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: kAccentRed.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Text(
                          sym,
                          style: GoogleFonts.robotoMono(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "${chg >= 0 ? '+' : ''}$chg%",
                          style: GoogleFonts.robotoMono(
                            color: chg >= 0 ? kAccentGreen : kAccentRed,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: kAccentRed.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "${deliv.toStringAsFixed(1)}% Delivery ($volStr Vol)",
                            style: GoogleFonts.robotoMono(
                              color: kAccentRed,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StockDeliveryHistoryScreen(initialSymbol: sym),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1F293D),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              "Delivery →",
                              style: TextStyle(color: kAccentCyan, fontSize: 8.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF090D16),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.shield_outlined, color: kAccentCyan, size: 12),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "SEBI Statutory Notice: Algorithmic delivery percentage scan from official NSE Bhavcopy. Strictly educational analysis; does not constitute investment advice or stock recommendations.",
                          style: TextStyle(color: Colors.white54, fontSize: 8, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPromoterAndBulkDealsCard() {
    final highPledgeList = (_promoterRadar['high_pledge_danger_zone'] as List<dynamic>? ?? []);
    final insiderBuys = (_promoterRadar['insider_promoter_accumulations'] as List<dynamic>? ?? []);
    final netAbsorptions = (_bulkBlockDeals['net_institutional_absorptions'] as List<dynamic>? ?? []);
    final churnTraps = (_bulkBlockDeals['filtered_operator_churn_traps'] as List<dynamic>? ?? []);

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
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified_user_rounded, color: kAccentCyan, size: 15),
                  const SizedBox(width: 5),
                  Text(
                    "PROMOTER PLEDGE & MARQUEE BULK DEALS",
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: kAccentCyan.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: kAccentCyan.withOpacity(0.4)),
                ),
                child: const Text(
                  "INSTITUTIONAL RADAR",
                  style: TextStyle(
                    color: kAccentCyan,
                    fontSize: 7.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // PART 1: Promoter Pledge & Insider SAST Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "PLEDGE RISK (> 25%): ${highPledgeList.length} STOCKS",
                style: GoogleFonts.robotoMono(
                  color: kAccentRed,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                "SAST INSIDER BUYS: ${insiderBuys.length}",
                style: GoogleFonts.robotoMono(
                  color: kAccentGreen,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),

          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => _showPledgeAndInsiderSheet(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: kAccentRed.withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: kAccentRed.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    "⚡ Inspect Margin Call Danger Zone & Insider SAST Purchases",
                    style: TextStyle(
                      color: kAccentRed,
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: kAccentRed, size: 13),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Divider
          Container(height: 1, color: const Color(0xFF1E2B3E)),
          const SizedBox(height: 8),

          // PART 2: Smart Bulk & Block Deals (Operator Churn Filtered)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "MARQUEE NET DEMAT (> ₹10 Cr): ${netAbsorptions.length}",
                style: GoogleFonts.robotoMono(
                  color: kAccentGreen,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                "OPERATOR CHURN: ${churnTraps.length} TRAPS",
                style: GoogleFonts.robotoMono(
                  color: kAccentAmber,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),

          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => _showSmartBulkDealsSheet(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: kAccentGreen.withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: kAccentGreen.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    "🏛️ Inspect Marquee Net Absorption vs Filtered Churn Traps",
                    style: TextStyle(
                      color: kAccentGreen,
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: kAccentGreen, size: 13),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPledgeAndInsiderSheet(BuildContext context) {
    final highPledge = (_promoterRadar['high_pledge_danger_zone'] as List<dynamic>? ?? []);
    final insiderBuys = (_promoterRadar['insider_promoter_accumulations'] as List<dynamic>? ?? []);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F1726),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          expand: false,
          builder: (context, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.shield_rounded, color: kAccentCyan, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      "PROMOTER PLEDGING & INSIDER SAST RADAR",
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                const Text(
                  "Tracking high lender pledge risk and personal promoter open-market share accumulation.",
                  style: TextStyle(color: kTextMuted, fontSize: 9),
                ),
                const SizedBox(height: 14),

                // SECTION 1: MARGIN CALL DANGER ZONE
                Row(
                  children: const [
                    Icon(Icons.warning_amber_rounded, color: kAccentRed, size: 12),
                    SizedBox(width: 5),
                    Text(
                      "⚠️ MARGIN CALL DANGER ZONE (> 25% PROMOTER PLEDGE)",
                      style: TextStyle(
                        color: kAccentRed,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                ...highPledge.map((st) {
                  final sym = st['symbol']?.toString().toUpperCase() ?? '';
                  final comp = st['company'] ?? sym;
                  final double pledge = (st['pledged_pct'] as num?)?.toDouble() ?? 0.0;
                  final double promoter = (st['promoter_holding'] as num?)?.toDouble() ?? 0.0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131B2A),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: kAccentRed.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sym,
                              style: GoogleFonts.robotoMono(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              comp,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: kTextMuted, fontSize: 8),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: kAccentRed.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "${pledge.toStringAsFixed(1)}% Pledged (${promoter.toStringAsFixed(1)}% Holding)",
                            style: GoogleFonts.robotoMono(
                              color: kAccentRed,
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CompanyIntelligenceScreen(initialSymbol: sym),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1F293D),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              "Model →",
                              style: TextStyle(color: Colors.white70, fontSize: 8.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 14),

                // SECTION 2: INSIDER PROMOTER BUYS
                Row(
                  children: const [
                    Icon(Icons.trending_up_rounded, color: kAccentGreen, size: 12),
                    SizedBox(width: 5),
                    Text(
                      "🟢 INSIDER PROMOTER ACCUMULATION (SEBI SAST REG 29 OPEN MARKET)",
                      style: TextStyle(
                        color: kAccentGreen,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                ...insiderBuys.map((st) {
                  final sym = st['symbol']?.toString().toUpperCase() ?? '';
                  final comp = st['company'] ?? sym;
                  final double stakeCr = (st['stake_acquired_cr'] as num?)?.toDouble() ?? 0.0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131B2A),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: kAccentGreen.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sym,
                              style: GoogleFonts.robotoMono(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              comp,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: kTextMuted, fontSize: 8),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: kAccentGreen.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "+₹${stakeCr.toStringAsFixed(1)} Cr Open-Market Buy",
                            style: GoogleFonts.robotoMono(
                              color: kAccentGreen,
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CompanyIntelligenceScreen(initialSymbol: sym),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1F293D),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              "Model →",
                              style: TextStyle(color: kAccentGreen, fontSize: 8.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF090D16),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.shield_outlined, color: kAccentCyan, size: 12),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "SEBI Statutory Notice: Pledged shareholding and SAST insider disclosures from official stock exchange filings. Strictly educational analysis; does not constitute investment advice.",
                          style: TextStyle(color: Colors.white54, fontSize: 8, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSmartBulkDealsSheet(BuildContext context) {
    final netAbsorptions = (_bulkBlockDeals['net_institutional_absorptions'] as List<dynamic>? ?? []);
    final churnTraps = (_bulkBlockDeals['filtered_operator_churn_traps'] as List<dynamic>? ?? []);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F1726),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          expand: false,
          builder: (context, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.account_balance_rounded, color: kAccentCyan, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      "SMART BULK/BLOCK ABSORPTION vs OPERATOR CHURN",
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                const Text(
                  "Isolating Marquee Institutional Net Demat Delivery from fake operator intraday churn.",
                  style: TextStyle(color: kTextMuted, fontSize: 9),
                ),
                const SizedBox(height: 14),

                // SECTION 1: MARQUEE NET ABSORPTION
                Row(
                  children: const [
                    Icon(Icons.verified_rounded, color: kAccentGreen, size: 12),
                    SizedBox(width: 5),
                    Text(
                      "🟢 MARQUEE NET INSTITUTIONAL ABSORPTION (> ₹10 Cr NET DEMAT)",
                      style: TextStyle(
                        color: kAccentGreen,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                ...netAbsorptions.map((st) {
                  final sym = st['symbol']?.toString().toUpperCase() ?? '';
                  final client = st['client_name'] ?? '';
                  final double netCr = (st['net_value_cr'] as num?)?.toDouble() ?? 0.0;
                  final double price = (st['avg_price'] as num?)?.toDouble() ?? 0.0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131B2A),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: kAccentGreen.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sym,
                              style: GoogleFonts.robotoMono(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              client,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: kTextMuted, fontSize: 8),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: kAccentGreen.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "+₹${netCr.toStringAsFixed(1)} Cr @ ₹${price.toStringAsFixed(0)}",
                            style: GoogleFonts.robotoMono(
                              color: kAccentGreen,
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StockDeliveryHistoryScreen(initialSymbol: sym),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1F293D),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              "Delivery →",
                              style: TextStyle(color: kAccentCyan, fontSize: 8.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 14),

                // SECTION 2: FILTERED OPERATOR CHURN TRAPS
                Row(
                  children: const [
                    Icon(Icons.block_rounded, color: kAccentAmber, size: 12),
                    SizedBox(width: 5),
                    Text(
                      "🔴 FILTERED OPERATOR INTRADAY CHURN (DAY-TRADING VOLUME BAIT)",
                      style: TextStyle(
                        color: kAccentAmber,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                ...churnTraps.map((st) {
                  final sym = st['symbol']?.toString().toUpperCase() ?? '';
                  final client = st['client_name'] ?? '';
                  final double grossCr = (st['gross_traded_cr'] as num?)?.toDouble() ?? 0.0;
                  final double netCr = (st['net_absorbed_cr'] as num?)?.toDouble() ?? 0.0;
                  final double churn = (st['churn_ratio_pct'] as num?)?.toDouble() ?? 99.0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131B2A),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: kAccentAmber.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sym,
                              style: GoogleFonts.robotoMono(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              client,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: kTextMuted, fontSize: 8),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: kAccentAmber.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "${churn.toStringAsFixed(1)}% Churn (₹${grossCr.toStringAsFixed(0)} Cr Traded / Net ₹${netCr.toStringAsFixed(2)} Cr)",
                            style: GoogleFonts.robotoMono(
                              color: kAccentAmber,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StockDeliveryHistoryScreen(initialSymbol: sym),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1F293D),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              "Delivery →",
                              style: TextStyle(color: kAccentCyan, fontSize: 8.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF090D16),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.shield_outlined, color: kAccentCyan, size: 12),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "SEBI Statutory Notice: Bulk and Block deal data processed via algorithmic netting from official exchange disclosures. Strictly educational analysis; does not constitute investment advice.",
                          style: TextStyle(color: Colors.white54, fontSize: 8, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildUpcomingTriggersStrip() {
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
              Row(
                children: [
                  const Icon(Icons.upcoming_rounded,
                      color: kAccentAmber, size: 15),
                  const SizedBox(width: 6),
                  Text(
                    "MACRO TRIGGERS (CALENDAR COUNTDOWN)",
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
              Text(
                "${_upcomingTriggers.length} UPCOMING",
                style: const TextStyle(color: kTextMuted, fontSize: 8.5),
              ),
            ],
          ),
          const SizedBox(height: 8),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _upcomingTriggers.map((trig) {
                final int days = (trig['days_remaining'] as num?)?.toInt() ?? 0;
                final String name = trig['name'] ?? '';
                final String date = trig['event_date'] ?? '';
                final String impact = trig['impact'] ?? 'HIGH';

                final bool isCritical = impact == 'CRITICAL';
                final Color impactColor = isCritical ? kAccentRed : kAccentAmber;

                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.all(8),
                  width: 150,
                  decoration: BoxDecoration(
                    color: const Color(0xFF090D16),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: impactColor.withOpacity(0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: impactColor.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              impact,
                              style: TextStyle(
                                color: impactColor,
                                fontSize: 7,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Text(
                            "${days}d LEFT",
                            style: GoogleFonts.robotoMono(
                              color: days <= 10 ? kAccentRed : Colors.white70,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        date,
                        style: const TextStyle(color: kTextMuted, fontSize: 8),
                      ),
                    ],
                  ),
                );
              }).toList(),
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

        // Deep 17-Sector Macro Margin Desk Launcher
        _buildDeepMarginDeskLauncher(),
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

  Widget _buildDeepMarginDeskLauncher() {
    return Container(
      decoration: BoxDecoration(
        color: kCardDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kAccentCyan.withOpacity(0.35)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const MacroResearchDeskView(),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: kAccentCyan.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.tune_rounded, color: kAccentCyan, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "17-SECTOR INPUT-COST MARGIN DESK",
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        "Inspect raw material COGS benchmarks & commodity divergence sliders",
                        style: TextStyle(color: kTextMuted, fontSize: 8.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: kAccentCyan.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: kAccentCyan.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        "Open Desk",
                        style: TextStyle(color: kAccentCyan, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(width: 2),
                      Icon(Icons.chevron_right_rounded, color: kAccentCyan, size: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
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
    final int beneficiariesCount = _equityImpacts
        .where((e) => e['impact_direction'] == 'BENEFICIARY')
        .length;
    final int headwindsCount = _equityImpacts
        .where((e) => e['impact_direction'] == 'HEADWIND')
        .length;

    final List<Map<String, dynamic>> filteredList = _selectedImpactFilter == 'ALL'
        ? _equityImpacts
        : _equityImpacts
            .where((e) => e['impact_direction'] == _selectedImpactFilter)
            .toList();

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

        // 1-Tap Filter Chip Row (Beneficiaries vs Headwinds)
        Row(
          children: [
            _buildImpactFilterChip("ALL", "ALL (${_equityImpacts.length})", Colors.white70),
            const SizedBox(width: 6),
            _buildImpactFilterChip("BENEFICIARY", "🟢 BENEFICIARIES ($beneficiariesCount)", kAccentGreen),
            const SizedBox(width: 6),
            _buildImpactFilterChip("HEADWIND", "🔴 HEADWINDS ($headwindsCount)", kAccentRed),
          ],
        ),
        const SizedBox(height: 12),

        ...filteredList.map((e) => _buildIndustrySensitivityCard(e)),
      ],
    );
  }

  Widget _buildImpactFilterChip(String filterKey, String label, Color activeCol) {
    final bool isSelected = _selectedImpactFilter == filterKey;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedImpactFilter = filterKey);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6.5),
          decoration: BoxDecoration(
            color: isSelected ? activeCol.withOpacity(0.18) : const Color(0xFF0F1726),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? activeCol.withOpacity(0.6) : const Color(0xFF1E2B3E),
              width: isSelected ? 1.2 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? activeCol : Colors.white60,
                fontSize: 8.5,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
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
      decoration: BoxDecoration(
        color: kCardDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: col.withOpacity(0.35)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _showSectorConstituentsSheet(context, theme),
          child: Padding(
            padding: const EdgeInsets.all(12),
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

                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(Icons.touch_app_rounded, color: col, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      "Tap to inspect constituent peers & delivery spikes →",
                      style: TextStyle(
                        color: col,
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSectorConstituentsSheet(
      BuildContext context, Map<String, dynamic> theme) {
    final tName = theme['theme'] ?? '';
    final direction = theme['impact_direction'] ?? '';
    final status = theme['status'] ?? (direction == 'BENEFICIARY' ? 'EXPANDING' : 'HEADWIND');
    final index = theme['benchmark_index'] ?? 'Sector Basket';
    final tickers = (theme['representative_tickers'] as List<dynamic>? ?? []);
    final segments = (theme['exposed_segments'] as List<dynamic>? ?? []);
    final bool isBeneficiary = direction == 'BENEFICIARY';
    final Color col = isBeneficiary ? kAccentGreen : kAccentRed;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F1726),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        tName,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: col.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: col.withOpacity(0.4)),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: col,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  "Benchmark Index: $index",
                  style: GoogleFonts.robotoMono(
                    color: kAccentCyan,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                if (segments.isNotEmpty) ...[
                  const Text(
                    "CORE SUB-SEGMENTS",
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 5,
                    children: segments.map((seg) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF162032),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: const Color(0xFF23354E)),
                        ),
                        child: Text(
                          seg.toString(),
                          style: const TextStyle(color: Colors.white70, fontSize: 9),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                const Text(
                  "PEER GROUP & DIRECT MICRO INTELLIGENCE",
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 8),

                if (tickers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      "No specific tickers mapped for this macro basket.",
                      style: TextStyle(color: kTextMuted, fontSize: 11),
                    ),
                  )
                else
                  ...tickers.map((t) {
                    final sym = t.toString().toUpperCase();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131B2A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF1E2B3E)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Text(
                              sym,
                              style: GoogleFonts.robotoMono(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const Spacer(),
                          InkWell(
                            onTap: () {
                              Navigator.pop(ctx);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => StockDeliveryHistoryScreen(
                                    initialSymbol: sym,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                color: kAccentCyan.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(color: kAccentCyan.withOpacity(0.35)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.bar_chart_rounded, color: kAccentCyan, size: 12),
                                  SizedBox(width: 4),
                                  Text(
                                    "Delivery Spikes",
                                    style: TextStyle(
                                      color: kAccentCyan,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () {
                              Navigator.pop(ctx);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CompanyIntelligenceScreen(
                                    initialSymbol: sym,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF21262D),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.business_rounded, color: Colors.white70, size: 12),
                                  SizedBox(width: 4),
                                  Text(
                                    "Business Model",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
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

                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF090D16),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.shield_outlined, color: kAccentCyan, size: 12),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "SEBI Notice: Constituent peers are for research and macro transmission reference only. Not an investment recommendation.",
                          style: TextStyle(color: Colors.white54, fontSize: 8, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
