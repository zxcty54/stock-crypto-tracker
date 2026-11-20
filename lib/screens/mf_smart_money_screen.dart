import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

class MfSmartMoneyScreen extends StatefulWidget {
  const MfSmartMoneyScreen({super.key});

  @override
  State<MfSmartMoneyScreen> createState() => _MfSmartMoneyScreenState();
}

class _MfSmartMoneyScreenState extends State<MfSmartMoneyScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  bool _isSyncing = false;
  bool _isLiveSynced = false;

  Map<String, dynamic> _metadata = {};
  Map<String, dynamic> _marketCapRotation = {};
  List<Map<String, dynamic>> _sectorMoneyFlows = [];
  List<Map<String, dynamic>> _smartMoneyTactics = [];
  List<Map<String, dynamic>> _institutionalExits = [];
  List<Map<String, dynamic>> _exitChecklist = [];
  List<Map<String, dynamic>> _topFunds = [];
  List<Map<String, dynamic>> _infiltrations = [];

  // Filter states
  String _infiltrationFilter = "ALL"; // ALL, FRESH_ENTRY, AGGRESSIVE_ACCUMULATION, SILENT_DUMPING
  String _fundCategoryFilter = "ALL"; // ALL, Flexi Cap, Small Cap, Mid Cap, Large & Mid Cap, Contra / Value

  // Overlap Tool State
  int _selectedFundAIdx = 0; // default PPFAS
  int _selectedFundBIdx = 3; // default HDFC Mid-Cap

  final NumberFormat _currencyFormat = NumberFormat('#,##,##0.00', 'en_IN');

  // Dynamic remote data CDNs (Auto-updated every month via GitHub Actions)
  static const List<String> dataUrls = [
    'https://raw.githubusercontent.com/zxcty54/stock-crypto-tracker/main/assets/data/mf_smart_money_radar.json',
    'https://raw.githubusercontent.com/zxcty54/stock-crypto-tracker/main/mf_smart_money_radar.json',
    'https://cdn.jsdelivr.net/gh/zxcty54/stock-crypto-tracker@main/assets/data/mf_smart_money_radar.json',
    'https://cdn.jsdelivr.net/gh/zxcty54/stock-crypto-tracker@main/mf_smart_money_radar.json',
    'https://fastly.jsdelivr.net/gh/zxcty54/stock-crypto-tracker@main/assets/data/mf_smart_money_radar.json',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadDataset();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _populateData(Map<String, dynamic> data) {
    _metadata = Map<String, dynamic>.from(data['metadata'] ?? {});
    _marketCapRotation =
        Map<String, dynamic>.from(data['market_cap_rotation'] ?? {});
    _sectorMoneyFlows =
        List<Map<String, dynamic>>.from(data['sector_money_flows'] ?? []);
    _smartMoneyTactics =
        List<Map<String, dynamic>>.from(data['smart_money_tactics'] ?? []);
    _institutionalExits = List<Map<String, dynamic>>.from(
        data['institutional_exits_and_traps'] ?? []);
    _exitChecklist =
        List<Map<String, dynamic>>.from(data['exit_timing_checklist'] ?? []);
    _topFunds =
        List<Map<String, dynamic>>.from(data['top_20_funds'] ?? []);
    _infiltrations = List<Map<String, dynamic>>.from(
        data['smart_money_infiltrations'] ?? []);
  }

  Future<void> _loadDataset({bool isRefresh = false}) async {
    if (isRefresh) {
      HapticFeedback.lightImpact();
      setState(() => _isSyncing = true);
    }

    // 1. First, load bundled asset baseline if not yet populated
    if (_topFunds.isEmpty) {
      try {
        final jsonStr =
            await rootBundle.loadString('assets/data/mf_smart_money_radar.json');
        final data = jsonDecode(jsonStr);

        if (mounted && _topFunds.isEmpty) {
          setState(() {
            _populateData(data);
            _isLoading = false;
          });
        }
      } catch (e) {
        debugPrint("Error loading local bundled MF dataset: $e");
      }
    }

    // 2. Fetch live dynamic radar from CDNs (auto-updated every month)
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
          if (parsed is Map<String, dynamic> && parsed['top_20_funds'] != null) {
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
                    "✅ Live Institutional Radar Synced (${_metadata['last_updated'] ?? 'Latest'})",
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
            content: Text("Baseline cached radar active."),
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
        backgroundColor: const Color(0xFF0F1726),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF1E2B3E)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF00E5FF).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_mode_rounded,
                  color: Color(0xFF00E5FF), size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "Dynamic Monthly Engine",
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
                "1. SEBI 10th Mandate",
                "By Indian securities law (SEBI), every Mutual Fund AMC must disclose its complete portfolio by the 10th of every month.",
                const Color(0xFF00E5FF),
              ),
              const SizedBox(height: 10),
              _buildInfoStep(
                "2. Automated Monthly Job",
                "GitHub Actions runs on the 11th of every month (cron: 0 14 11 * *) to automatically fetch portfolio filings, compute month-over-month holding changes, and identify institutional moves.",
                const Color(0xFF00FF88),
              ),
              const SizedBox(height: 10),
              _buildInfoStep(
                "3. Live AMFI Scheme API",
                "Integrated with the official AMFI Open API (api.mfapi.in) using scheme codes (e.g. 122639) for daily real-time NAVs and returns.",
                const Color(0xFFFFB703),
              ),
              const SizedBox(height: 10),
              _buildInfoStep(
                "4. Zero-Update Cloud Sync",
                "New monthly data streams instantly via raw GitHub / CDN to your app without needing any Play Store update or APK rebuild.",
                const Color(0xFFE040FB),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CLOSE",
                style: TextStyle(
                    color: Color(0xFF00E5FF), fontWeight: FontWeight.bold)),
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

  // -------------------------------------------------------------
  // Overlap Calculation Engine
  // -------------------------------------------------------------
  Map<String, dynamic> _computeOverlap(
      Map<String, dynamic> fundA, Map<String, dynamic> fundB) {
    final listA = (fundA['top_10_holdings'] as List<dynamic>? ?? []);
    final listB = (fundB['top_10_holdings'] as List<dynamic>? ?? []);

    Map<String, double> mapA = {};
    for (var h in listA) {
      if (h is Map) {
        mapA[h['symbol'].toString().toUpperCase()] =
            (h['weight'] as num?)?.toDouble() ?? 0.0;
      }
    }

    Map<String, double> mapB = {};
    for (var h in listB) {
      if (h is Map) {
        mapB[h['symbol'].toString().toUpperCase()] =
            (h['weight'] as num?)?.toDouble() ?? 0.0;
      }
    }

    List<Map<String, dynamic>> common = [];
    double overlapWeight = 0.0;

    mapA.forEach((sym, wtA) {
      if (mapB.containsKey(sym)) {
        final wtB = mapB[sym]!;
        final minWt = wtA < wtB ? wtA : wtB;
        overlapWeight += minWt;
        common.add({
          'symbol': sym,
          'weight_a': wtA,
          'weight_b': wtB,
        });
      }
    });

    final double overlapScore = (overlapWeight * 2.0).clamp(0.0, 100.0);

    return {
      'overlap_pct': overlapScore,
      'common_stocks': common,
      'fund_a_unique': mapA.length - common.length,
      'fund_b_unique': mapB.length - common.length,
    };
  }

  @override
  Widget build(BuildContext context) {
    final double totalAum =
        (_metadata['total_aum_tracked_cr'] as num?)?.toDouble() ?? 710600.0;
    final String aumStr = totalAum >= 100000
        ? "₹${(totalAum / 100000).toStringAsFixed(1)}L Cr"
        : "₹${_currencyFormat.format(totalAum)} Cr";

    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1726),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.radar_rounded,
                    color: Color(0xFF00E5FF), size: 18),
                const SizedBox(width: 6),
                Text(
                  "MF SMART MONEY RADAR",
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
              "Top ${_topFunds.isNotEmpty ? _topFunds.length : 20} Marquee Funds • $aumStr Tracked",
              style: const TextStyle(color: Colors.white54, fontSize: 9.5),
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
                      color: Color(0xFF00E5FF),
                    ),
                  )
                : const Icon(Icons.sync_rounded,
                    color: Color(0xFF00E5FF), size: 20),
            tooltip: "Refresh Live Institutional Data",
            onPressed: _isSyncing ? null : () => _loadDataset(isRefresh: true),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline_rounded,
                color: Colors.white70, size: 20),
            tooltip: "Automated Monthly Pipeline",
            onPressed: () => _showPipelineInfoDialog(context),
          ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: const Color(0xFF00E5FF),
          indicatorWeight: 2.5,
          labelColor: const Color(0xFF00E5FF),
          unselectedLabelColor: Colors.white54,
          labelStyle: GoogleFonts.plusJakartaSans(
              fontSize: 11, fontWeight: FontWeight.w800),
          unselectedLabelStyle: GoogleFonts.plusJakartaSans(
              fontSize: 11, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: "🌊 MONEY FLOW"),
            Tab(text: "🚨 EXITS & TRAPS"),
            Tab(text: "🕵️ INFILTRATIONS"),
            Tab(text: "⚖️ OVERLAP SCANNER"),
            Tab(text: "🏛️ TOP 20 & CASH"),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                RefreshIndicator(
                  color: const Color(0xFF00E5FF),
                  backgroundColor: const Color(0xFF0F1726),
                  onRefresh: () => _loadDataset(isRefresh: true),
                  child: _buildMoneyFlowTab(),
                ),
                RefreshIndicator(
                  color: const Color(0xFF00E5FF),
                  backgroundColor: const Color(0xFF0F1726),
                  onRefresh: () => _loadDataset(isRefresh: true),
                  child: _buildExitsAndTrapsTab(),
                ),
                RefreshIndicator(
                  color: const Color(0xFF00E5FF),
                  backgroundColor: const Color(0xFF0F1726),
                  onRefresh: () => _loadDataset(isRefresh: true),
                  child: _buildInfiltrationsTab(),
                ),
                RefreshIndicator(
                  color: const Color(0xFF00E5FF),
                  backgroundColor: const Color(0xFF0F1726),
                  onRefresh: () => _loadDataset(isRefresh: true),
                  child: _buildOverlapScannerTab(),
                ),
                RefreshIndicator(
                  color: const Color(0xFF00E5FF),
                  backgroundColor: const Color(0xFF0F1726),
                  onRefresh: () => _loadDataset(isRefresh: true),
                  child: _buildCashAndDirectoryTab(),
                ),
              ],
            ),
    );
  }

  // =============================================================
  // 📊 EXECUTIVE CONCLUSION HUD & NET FLOW COLUMN BAR CHART
  // =============================================================
  Widget _buildExecutiveBarChart() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF142038), Color(0xFF0C1424)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withOpacity(0.08),
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
                      color: const Color(0xFF00E5FF).withOpacity(0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.bar_chart_rounded,
                        color: Color(0xFF00E5FF), size: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "CORE CONCLUSION (AT A GLANCE)",
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF00E5FF),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FF88).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  "🔥 LIVE REGIME",
                  style: TextStyle(
                    color: Color(0xFF00FF88),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Big Bold Verdict
          Text(
            "Institutions are pouring +₹12,800 Cr into Large Caps while DUMPING Small Caps (-₹4,600 Cr)",
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),

          // 📊 Vertical Net Capital Flow Column Bar Chart
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
                    Text("NET 30-DAY INSTITUTIONAL CAPITAL FLOW (₹ CRORE)",
                        style: TextStyle(color: Colors.white38, fontSize: 8.5, fontWeight: FontWeight.bold)),
                    Text("Zero Baseline: ₹0 Cr",
                        style: TextStyle(color: Colors.white38, fontSize: 8.5)),
                  ],
                ),
                const SizedBox(height: 12),

                // The 4 Columns
                SizedBox(
                  height: 110,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildFlowColumn(
                        label: "LARGE CAP",
                        amountStr: "+₹12.8k Cr",
                        heightRatio: 1.0,
                        isPositive: true,
                        color: const Color(0xFF00FF88),
                        icon: Icons.arrow_upward_rounded,
                      ),
                      _buildFlowColumn(
                        label: "CASH / REPO",
                        amountStr: "+₹2.1k Cr",
                        heightRatio: 0.32,
                        isPositive: true,
                        color: const Color(0xFF00E5FF),
                        icon: Icons.arrow_upward_rounded,
                      ),
                      _buildFlowColumn(
                        label: "MID CAP",
                        amountStr: "-₹1.2k Cr",
                        heightRatio: 0.24,
                        isPositive: false,
                        color: const Color(0xFFFF9100),
                        icon: Icons.arrow_downward_rounded,
                      ),
                      _buildFlowColumn(
                        label: "SMALL CAP",
                        amountStr: "-₹4.6k Cr",
                        heightRatio: 0.58,
                        isPositive: false,
                        color: const Color(0xFFFF2A6D),
                        icon: Icons.arrow_downward_rounded,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                // Zero baseline indicator
                Container(
                  height: 1.5,
                  color: Colors.white24,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 3 Bullet Conclusions (Crystal clear)
          _buildTakeawayItem(
            Icons.check_circle_rounded,
            const Color(0xFF00FF88),
            "73% Fresh SIP Allocation into Large Caps",
            "Institutions are parking the bulk of domestic SIP inflows into resilient Private Banks and Utilities for capital safety.",
          ),
          const SizedBox(height: 6),
          _buildTakeawayItem(
            Icons.cancel_rounded,
            const Color(0xFFFF2A6D),
            "Small-Cap De-risking & Distribution",
            "Small-cap median P/E reached an unsustainable >45x. Marquee funds are cutting positions to secure 2-year multibagger gains.",
          ),
          const SizedBox(height: 6),
          _buildTakeawayItem(
            Icons.savings_rounded,
            const Color(0xFFFFB703),
            "₹55,100+ Cr Cash Dry Powder Waiting",
            "High 7.76% liquidity buffer held by funds like PPFAS & Quant, waiting to buy steep market crash dips.",
          ),
        ],
      ),
    );
  }

  Widget _buildFlowColumn({
    required String label,
    required String amountStr,
    required double heightRatio,
    required bool isPositive,
    required Color color,
    required IconData icon,
  }) {
    final double barHeight = (heightRatio * 65.0).clamp(16.0, 65.0);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 9),
            const SizedBox(width: 2),
            Text(
              amountStr,
              style: GoogleFonts.robotoMono(
                color: color,
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),

        // Vertical Column Bar
        Container(
          width: 42,
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
        const SizedBox(height: 6),

        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white70,
            fontSize: 8.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildTakeawayItem(
      IconData icon, Color color, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  color: color,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                desc,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 10, height: 1.3),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =============================================================
  // TAB 1: 🌊 MONEY FLOW & MARKET CAP ROTATION
  // =============================================================
  Widget _buildMoneyFlowTab() {
    final tiers = (_marketCapRotation['tiers'] as List<dynamic>? ?? []);
    final regimeTitle = _marketCapRotation['regime_title'] ?? 'Flight to Quality';
    final regimeSummary = _marketCapRotation['regime_summary'] ??
        'Marquee DII managers are rotating capital into defensive Large-Caps while trimming frothy Small-Caps.';

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // 🌟 0. EXECUTIVE CONCLUSION HUD & COLUMN BAR CHART (Ek Baar Me Saaf)
        _buildExecutiveBarChart(),
        const SizedBox(height: 16),

        // 1. Regime Banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF131F37), Color(0xFF0D1424)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.waves_rounded,
                          color: Color(0xFF00E5FF), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        "CAPITAL FLOW REGIME",
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF00E5FF),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00FF88).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      "🛡️ FLIGHT TO QUALITY",
                      style: TextStyle(
                        color: Color(0xFF00FF88),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                regimeTitle,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                regimeSummary,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 11, height: 1.35),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Market Cap Shift Barometer Header
        Row(
          children: const [
            Icon(Icons.pie_chart_rounded,
                color: Color(0xFF00E5FF), size: 16),
            SizedBox(width: 6),
            Text(
              "MARKET CAP ROTATION (LARGE vs MID vs SMALL)",
              style: TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Visual Stacked Bar
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 12,
            child: Row(
              children: [
                Expanded(
                  flex: 58,
                  child: Container(color: const Color(0xFF00E5FF)),
                ),
                const SizedBox(width: 1),
                Expanded(
                  flex: 24,
                  child: Container(color: const Color(0xFF2979FF)),
                ),
                const SizedBox(width: 1),
                Expanded(
                  flex: 10,
                  child: Container(color: const Color(0xFFFF9100)),
                ),
                const SizedBox(width: 1),
                Expanded(
                  flex: 8,
                  child: Container(color: const Color(0xFF00FF88)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text("■ Large (58.4%)",
                style: TextStyle(
                    color: Color(0xFF00E5FF),
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold)),
            Text("■ Mid (24.2%)",
                style: TextStyle(
                    color: Color(0xFF2979FF),
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold)),
            Text("■ Small (9.6%)",
                style: TextStyle(
                    color: Color(0xFFFF9100),
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold)),
            Text("■ Cash (7.8%)",
                style: TextStyle(
                    color: Color(0xFF00FF88),
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 10),

        // Tier Breakdown Cards
        ...tiers.map((t) => _buildMarketCapTierCard(t)),
        const SizedBox(height: 16),

        // 3. Sector Rotation Heatmap Header
        Row(
          children: const [
            Icon(Icons.sync_alt_rounded, color: Color(0xFF00E5FF), size: 16),
            SizedBox(width: 6),
            Text(
              "SECTOR ROTATION RADAR (INFLOWS vs OUTFLOWS)",
              style: TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._sectorMoneyFlows.map((s) => _buildSectorFlowCard(s)),
        const SizedBox(height: 16),

        // 4. Modus Operandi Guide ("Kaise Kar Rahe Hain")
        Row(
          children: const [
            Icon(Icons.psychology_rounded,
                color: Color(0xFF00E5FF), size: 16),
            SizedBox(width: 6),
            Text(
              "INSTITUTIONAL EXECUTION TACTICS (HOW THEY BUY)",
              style: TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._smartMoneyTactics.map((t) => _buildTacticCard(t)),
      ],
    );
  }

  Widget _buildMarketCapTierCard(dynamic tier) {
    if (tier is! Map) return const SizedBox.shrink();
    final name = tier['name'] ?? '';
    final double pct = (tier['allocation_pct'] as num?)?.toDouble() ?? 0.0;
    final double mom = (tier['mom_change_pct'] as num?)?.toDouble() ?? 0.0;
    final double flow = (tier['net_flow_cr'] as num?)?.toDouble() ?? 0.0;
    final status = tier['status'] ?? '';
    final reason = tier['reason'] ?? '';
    final sectors = (tier['preferred_sectors'] as List<dynamic>? ?? []);

    final bool isPositive = mom >= 0;
    final Color badgeColor = isPositive ? const Color(0xFF00FF88) : const Color(0xFFFF5252);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1726),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E2B3E)),
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
                    name,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      "${isPositive ? '▲ +' : '▼ '}${mom.toStringAsFixed(1)}% MoM",
                      style: TextStyle(
                        color: badgeColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                "${pct.toStringAsFixed(1)}%",
                style: GoogleFonts.robotoMono(
                  color: const Color(0xFF00E5FF),
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Net 30D Flow: ${flow >= 0 ? '+' : ''}₹${_currencyFormat.format(flow)} Cr",
                style: GoogleFonts.robotoMono(
                  color: isPositive ? const Color(0xFF00FF88) : const Color(0xFFFF5252),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2B3E),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  status,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            reason,
            style: const TextStyle(color: Colors.white60, fontSize: 10.5, height: 1.3),
          ),
          if (sectors.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 5,
              runSpacing: 4,
              children: sectors.map((sec) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF090D16),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF1E2B3E)),
                  ),
                  child: Text(
                    sec.toString(),
                    style: const TextStyle(color: Colors.white54, fontSize: 9),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectorFlowCard(Map<String, dynamic> s) {
    final sector = s['sector'] ?? '';
    final double flow = (s['net_flow_cr'] as num?)?.toDouble() ?? 0.0;
    final double mom = (s['mom_change_pct'] as num?)?.toDouble() ?? 0.0;
    final thesis = s['thesis'] ?? '';
    final bought = (s['top_bought'] as List<dynamic>? ?? []);
    final trimmed = (s['top_trimmed'] as List<dynamic>? ?? []);

    final bool isInflow = flow >= 0;
    final Color color = isInflow ? const Color(0xFF00FF88) : const Color(0xFFFF5252);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1726),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E2B3E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  sector,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "${isInflow ? '+' : ''}₹${_currencyFormat.format(flow)} Cr (${mom >= 0 ? '+' : ''}${mom.toStringAsFixed(1)}%)",
                  style: GoogleFonts.robotoMono(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          // 📊 Horizontal Comparative Bar Chart
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 7,
              color: const Color(0xFF090D16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: (flow.abs() / 4850.0).clamp(0.06, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isInflow
                            ? [const Color(0xFF00E5FF), const Color(0xFF00FF88)]
                            : [const Color(0xFFFF5252), const Color(0xFFFF1744)],
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            thesis,
            style: const TextStyle(color: Colors.white70, fontSize: 10.5, height: 1.3),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (bought.isNotEmpty) ...[
                const Text("BOUGHT: ",
                    style: TextStyle(
                        color: Color(0xFF00FF88),
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900)),
                Expanded(
                  child: Text(
                    bought.join(', '),
                    style: GoogleFonts.robotoMono(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
              if (trimmed.isNotEmpty) ...[
                const SizedBox(width: 8),
                const Text("TRIMMED: ",
                    style: TextStyle(
                        color: Color(0xFFFF5252),
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900)),
                Expanded(
                  child: Text(
                    trimmed.join(', '),
                    style: GoogleFonts.robotoMono(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTacticCard(Map<String, dynamic> t) {
    final title = t['title'] ?? '';
    final tag = t['tag'] ?? '';
    final desc = t['description'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1424),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1B283E)),
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
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  tag,
                  style: const TextStyle(
                    color: Color(0xFF00E5FF),
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: const TextStyle(color: Colors.white60, fontSize: 10.5, height: 1.35),
          ),
        ],
      ),
    );
  }

  // =============================================================
  // TAB 2: 🚨 EXITS & RETAIL TRAPS ("Kab Nikal Rahe Hain")
  // =============================================================
  Widget _buildExitsAndTrapsTab() {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // 1. Alert Banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF28111A), Color(0xFF140B10)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFF2A6D).withOpacity(0.4)),
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
                          color: Color(0xFFFF2A6D), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        "INSTITUTIONAL EXIT FORENSICS",
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFFFF2A6D),
                          fontSize: 11,
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
                      color: const Color(0xFFFF2A6D).withOpacity(0.18),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      "🚨 RETAIL TRAP DETECTOR",
                      style: TextStyle(
                        color: Color(0xFFFF2A6D),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                "When Do Institutions Dump & Exit Stocks?",
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                "Real-time alerts tracking where marquee DIIs are cutting stakes, liquidating positions, and offloading shares into retail liquidity during euphoria.",
                style: TextStyle(
                    color: Colors.white70, fontSize: 11, height: 1.35),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. 4-Rule Exit Checklist Header
        Row(
          children: const [
            Icon(Icons.checklist_rtl_rounded,
                color: Color(0xFF00E5FF), size: 16),
            SizedBox(width: 6),
            Text(
              "4 GOLDEN RULES: HOW TO SPOT INSTITUTIONAL EXITS",
              style: TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._exitChecklist.map((c) => _buildChecklistCard(c)),
        const SizedBox(height: 16),

        // 3. Active Institutional Exits & Dumping Radar
        Row(
          children: const [
            Icon(Icons.exit_to_app_rounded, color: Color(0xFFFF2A6D), size: 16),
            SizedBox(width: 6),
            Text(
              "ACTIVE INSTITUTIONAL DUMPING & TRAP RADAR",
              style: TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._institutionalExits.map((e) => _buildExitCard(e)),
      ],
    );
  }

  Widget _buildChecklistCard(Map<String, dynamic> c) {
    final numStr = c['rule_number'] ?? '';
    final title = c['title'] ?? '';
    final exp = c['explanation'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1726),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1E2B3E)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF00E5FF).withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              numStr,
              style: GoogleFonts.robotoMono(
                color: const Color(0xFF00E5FF),
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  exp,
                  style: const TextStyle(
                      color: Colors.white60, fontSize: 10.5, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExitCard(Map<String, dynamic> e) {
    final sym = e['symbol'] ?? '';
    final name = e['company_name'] ?? '';
    final tier = e['market_cap_tier'] ?? '';
    final action = e['action'] ?? '';
    final double drop = (e['dii_stake_drop_pct'] as num?)?.toDouble() ?? 0.0;
    final double sellingCr =
        (e['estimated_selling_cr'] as num?)?.toDouble() ?? 0.0;
    final retail = e['retail_holding_change'] ?? '';
    final catalyst = e['catalyst_reason'] ?? '';
    final funds = (e['exiting_funds'] as List<dynamic>? ?? []);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1726),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF2A6D).withOpacity(0.35)),
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
                    sym,
                    style: GoogleFonts.robotoMono(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2B3E),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      tier,
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF2A6D).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  action.replaceAll('_', ' '),
                  style: const TextStyle(
                    color: Color(0xFFFF2A6D),
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            name,
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
          const SizedBox(height: 10),

          // Key metrics row
          Row(
            children: [
              Expanded(
                child: _buildExitMetricBox(
                  "DII STAKE DROP",
                  "${drop.toStringAsFixed(1)}%",
                  const Color(0xFFFF5252),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildExitMetricBox(
                  "EST. SELLING",
                  "₹${_currencyFormat.format(sellingCr.abs())} Cr",
                  const Color(0xFFFF9100),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 📊 Retail Divergence Visualizer Dual-Bar Graph
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1B0C14),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFF2A6D).withOpacity(0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "DII INSTITUTIONAL SLASHDOWN",
                      style: TextStyle(
                        color: Color(0xFFFF5252),
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      "${drop.toStringAsFixed(1)}% Dumped",
                      style: GoogleFonts.robotoMono(
                        color: const Color(0xFFFF5252),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Container(
                    height: 6,
                    color: const Color(0xFF0D060A),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: (drop.abs() / 60.0).clamp(0.1, 1.0),
                        child: Container(color: const Color(0xFFFF2A6D)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "RETAIL INFLOW ABSORPTION (TRAP)",
                      style: TextStyle(
                        color: Color(0xFFFFB703),
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      retail,
                      style: GoogleFonts.robotoMono(
                        color: const Color(0xFFFFB703),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Container(
                    height: 6,
                    color: const Color(0xFF0D060A),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: 0.65,
                        child: Container(color: const Color(0xFFFFB703)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: const [
                    Icon(Icons.warning_amber_rounded,
                        color: Color(0xFFFF2A6D), size: 12),
                    SizedBox(width: 4),
                    Text(
                      "ALERT: Smart money selling into retail euphoria!",
                      style: TextStyle(
                        color: Color(0xFFFF80AB),
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            catalyst,
            style: const TextStyle(
                color: Colors.white70, fontSize: 10.5, height: 1.3),
          ),
          if (funds.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              "Exiting Funds: ${funds.join(' • ')}",
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white38,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExitMetricBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF090D16),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white38, fontSize: 8)),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.robotoMono(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  // =============================================================
  // TAB 3: SMART MONEY STOCK INFILTRATIONS
  // =============================================================
  Widget _buildInfiltrationsTab() {
    List<Map<String, dynamic>> filtered = _infiltrations;
    if (_infiltrationFilter != "ALL") {
      filtered = filtered
          .where((i) => (i['action_type'] ?? '') == _infiltrationFilter)
          .toList();
    }

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // Summary Macro Ribbon
        _buildInfiltrationSummaryBanner(),
        const SizedBox(height: 12),

        // Action Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip("ALL", "ALL (${_infiltrations.length})",
                  _infiltrationFilter == "ALL", () {
                setState(() => _infiltrationFilter = "ALL");
              }),
              const SizedBox(width: 6),
              _buildFilterChip(
                "FRESH_ENTRY",
                "🟢 FRESH BUYS (New)",
                _infiltrationFilter == "FRESH_ENTRY",
                () => setState(() => _infiltrationFilter = "FRESH_ENTRY"),
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                "AGGRESSIVE_ACCUMULATION",
                "🚀 ACCUMULATIONS (+25%)",
                _infiltrationFilter == "AGGRESSIVE_ACCUMULATION",
                () => setState(
                    () => _infiltrationFilter = "AGGRESSIVE_ACCUMULATION"),
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                "SILENT_DUMPING",
                "🔴 SILENT EXITS",
                _infiltrationFilter == "SILENT_DUMPING",
                () => setState(() => _infiltrationFilter = "SILENT_DUMPING"),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Stock Cards
        if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(
              child: Text("No infiltration signals matching this filter",
                  style: TextStyle(color: Colors.white38)),
            ),
          )
        else
          ...filtered.map((item) => _buildInfiltrationCard(item)),
      ],
    );
  }

  Widget _buildInfiltrationSummaryBanner() {
    final String lastUpdated =
        _metadata['last_updated'] ?? 'Latest SEBI Disclosures';
    final double totalAum =
        (_metadata['total_aum_tracked_cr'] as num?)?.toDouble() ?? 710600.0;
    final double avgCash =
        (_metadata['average_cash_level_pct'] as num?)?.toDouble() ?? 7.76;
    final String aumStr = totalAum >= 100000
        ? "₹${(totalAum / 100000).toStringAsFixed(1)}L Cr"
        : "₹${_currencyFormat.format(totalAum)} Cr";

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF101726),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E2B3E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.bolt_rounded,
                      color: Color(0xFF00E5FF), size: 16),
                  const SizedBox(width: 6),
                  Text(
                    "INSTITUTIONAL DELTA SIGNAL",
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _isLiveSynced
                      ? const Color(0xFF00FF88).withOpacity(0.15)
                      : const Color(0xFF00E5FF).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _isLiveSynced ? "🟢 LIVE CLOUD SYNCED" : "⚡ AUTOMATED DII RADAR",
                  style: TextStyle(
                    color: _isLiveSynced
                        ? const Color(0xFF00FF88)
                        : const Color(0xFF00E5FF),
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "Cycle: $lastUpdated • $aumStr Assets • ${avgCash.toStringAsFixed(1)}% Dry Powder",
            style: const TextStyle(
                color: Color(0xFF8896AB),
                fontSize: 9.5,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            _metadata['stance_summary'] ??
                "Marquee DII managers maintain selective accumulation in electronics, defence, and capital markets.",
            style: const TextStyle(
                color: Colors.white70, fontSize: 11, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _buildInfiltrationCard(Map<String, dynamic> item) {
    final sym = item['symbol'] ?? '';
    final name = item['company_name'] ?? '';
    final sector = item['sector'] ?? '';
    final action = item['action_type'] ?? '';
    final funds = (item['participating_funds'] as List<dynamic>? ?? []);
    final double volumeCr =
        (item['estimated_buying_cr'] as num?)?.toDouble() ?? 0.0;
    final double changePct =
        (item['avg_holding_increase_pct'] as num?)?.toDouble() ?? 0.0;
    final thesis = item['catalyst_thesis'] ?? '';

    Color tagColor = const Color(0xFF00FF88);
    String tagLabel = "FRESH ENTRY";
    IconData tagIcon = Icons.auto_awesome_rounded;

    if (action == "AGGRESSIVE_ACCUMULATION") {
      tagColor = const Color(0xFF00E5FF);
      tagLabel = "HEAVY ACCUMULATION (+${changePct.toInt()}%)";
      tagIcon = Icons.trending_up_rounded;
    } else if (action == "SILENT_DUMPING") {
      tagColor = const Color(0xFFFF2A6D);
      tagLabel = "SILENT DUMPING (${changePct.toInt()}%)";
      tagIcon = Icons.warning_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1726),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E2B3E)),
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
                    sym,
                    style: GoogleFonts.robotoMono(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2B3E),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      sector,
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 9,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                decoration: BoxDecoration(
                  color: tagColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(tagIcon, color: tagColor, size: 10),
                    const SizedBox(width: 4),
                    Text(
                      tagLabel,
                      style: TextStyle(
                        color: tagColor,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            name,
            style: const TextStyle(color: Colors.white54, fontSize: 10.5),
          ),
          const SizedBox(height: 10),

          // Flow Box
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF090D16),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("ESTIMATED CAPITAL DELTA",
                        style: TextStyle(color: Colors.white38, fontSize: 8.5)),
                    const SizedBox(height: 2),
                    Text(
                      volumeCr >= 0
                          ? "+₹${_currencyFormat.format(volumeCr)} Cr"
                          : "-₹${_currencyFormat.format(volumeCr.abs())} Cr",
                      style: GoogleFonts.robotoMono(
                        color: volumeCr >= 0
                            ? const Color(0xFF00FF88)
                            : const Color(0xFFFF2A6D),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text("ACTIVE BUYERS / HOLDERS",
                        style: TextStyle(color: Colors.white38, fontSize: 8.5)),
                    const SizedBox(height: 2),
                    Text(
                      "${funds.length} Top Funds",
                      style: GoogleFonts.robotoMono(
                        color: const Color(0xFF00E5FF),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            thesis,
            style: const TextStyle(
                color: Colors.white70, fontSize: 11, height: 1.3),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: funds.map((f) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF141C2B),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF22324B)),
                ),
                child: Text(
                  f.toString(),
                  style: const TextStyle(color: Colors.white60, fontSize: 9),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // =============================================================
  // TAB 4: OVERLAP SCANNER
  // =============================================================
  Widget _buildOverlapScannerTab() {
    if (_topFunds.length < 2) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)));
    }

    final fundA = _topFunds[_selectedFundAIdx.clamp(0, _topFunds.length - 1)];
    final fundB = _topFunds[_selectedFundBIdx.clamp(0, _topFunds.length - 1)];

    final overlapResult = _computeOverlap(fundA, fundB);
    final double overlapPct = overlapResult['overlap_pct'] as double;
    final List<Map<String, dynamic>> commonStocks =
        List<Map<String, dynamic>>.from(overlapResult['common_stocks'] ?? []);

    Color scoreColor = const Color(0xFF00FF88);
    String verdict = "DIVERSIFIED (LOW OVERLAP)";
    if (overlapPct > 45) {
      scoreColor = const Color(0xFFFF2A6D);
      verdict = "CLONED PORTFOLIO (FEE LEAKAGE)";
    } else if (overlapPct > 25) {
      scoreColor = const Color(0xFFFFB703);
      verdict = "MODERATE OVERLAP";
    }

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF101726),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF1E2B3E)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                "DUAL-FUND OVERLAP AUDIT",
                style: TextStyle(
                  color: Color(0xFF00E5FF),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 3),
              Text(
                "Compare underlying stock holdings across any two marquee funds to detect fee leakage and clone portfolios.",
                style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.3),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Selectors
        Row(
          children: [
            Expanded(
              child: _buildFundSelectorBox(
                "FUND A",
                fundA['short_name'] ?? fundA['name'],
                (newIdx) => setState(() => _selectedFundAIdx = newIdx),
                _selectedFundAIdx,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.compare_arrows_rounded, color: Color(0xFF00E5FF), size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: _buildFundSelectorBox(
                "FUND B",
                fundB['short_name'] ?? fundB['name'],
                (newIdx) => setState(() => _selectedFundBIdx = newIdx),
                _selectedFundBIdx,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Big Overlap Result Gauge
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1726),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: scoreColor.withOpacity(0.4)),
          ),
          child: Column(
            children: [
              Text(
                "${overlapPct.toStringAsFixed(1)}%",
                style: GoogleFonts.robotoMono(
                  color: scoreColor,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                "PORTFOLIO OVERLAP",
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white54,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: scoreColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  verdict,
                  style: TextStyle(
                    color: scoreColor,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildOverlapMiniStat("Common Stocks", "${commonStocks.length}"),
                  _buildOverlapMiniStat(
                      "Unique to A", "${overlapResult['fund_a_unique']}"),
                  _buildOverlapMiniStat(
                      "Unique to B", "${overlapResult['fund_b_unique']}"),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Overlapping Stocks List
        Row(
          children: const [
            Icon(Icons.layers_rounded, color: Color(0xFF00E5FF), size: 16),
            SizedBox(width: 6),
            Text(
              "COMMON UNDERLYING HOLDINGS",
              style: TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (commonStocks.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F1726),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Text(
                "Zero common holdings in Top 10 — Excellent diversification!",
                style: TextStyle(color: Color(0xFF00FF88), fontSize: 11),
              ),
            ),
          )
        else
          ...commonStocks.map((s) {
            final sym = s['symbol'] ?? '';
            final double wtA = (s['weight_a'] as num?)?.toDouble() ?? 0.0;
            final double wtB = (s['weight_b'] as num?)?.toDouble() ?? 0.0;

            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F1726),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF1E2B3E)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    sym,
                    style: GoogleFonts.robotoMono(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        "Fund A: $wtA%",
                        style: const TextStyle(
                            color: Color(0xFF00E5FF),
                            fontSize: 10,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        "Fund B: $wtB%",
                        style: const TextStyle(
                            color: Color(0xFFFFB703),
                            fontSize: 10,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildFundSelectorBox(
      String label, String currentName, Function(int) onSelect, int currentIdx) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1726),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1E2B3E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 8.5)),
          const SizedBox(height: 4),
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: currentIdx.clamp(0, _topFunds.length - 1),
              isExpanded: true,
              dropdownColor: const Color(0xFF141C2B),
              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF00E5FF)),
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
              items: _topFunds.asMap().entries.map((entry) {
                final idx = entry.key;
                final f = entry.value;
                return DropdownMenuItem<int>(
                  value: idx,
                  child: Text(
                    f['short_name'] ?? f['name'],
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) onSelect(val);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverlapMiniStat(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: GoogleFonts.robotoMono(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9.5)),
      ],
    );
  }

  // =============================================================
  // TAB 5: 🏛️ TOP 20 & INSTITUTIONAL CASH BAROMETER
  // =============================================================
  Widget _buildCashAndDirectoryTab() {
    final double avgCash =
        (_metadata['average_cash_level_pct'] as num?)?.toDouble() ?? 7.8;
    final double totalAum =
        (_metadata['total_aum_tracked_cr'] as num?)?.toDouble() ?? 710600.0;
    final double dryPowderCr = (totalAum * (avgCash / 100.0));

    // Category filter for funds
    List<Map<String, dynamic>> filtered = _topFunds;
    if (_fundCategoryFilter != "ALL") {
      filtered = filtered
          .where((f) =>
              (f['category'] ?? '').toString().contains(_fundCategoryFilter))
          .toList();
    }

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // Cash Macro Gauge
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF101726),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF1E2B3E)),
          ),
          child: Column(
            children: [
              Text(
                "${avgCash.toStringAsFixed(2)}%",
                style: GoogleFonts.robotoMono(
                  color: const Color(0xFF00FF88),
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                "WEIGHTED INSTITUTIONAL CASH LEVEL",
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white54,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              // 🔋 Segmented visual liquid tank gauge
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  height: 12,
                  color: const Color(0xFF090D16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: (avgCash / 15.0).clamp(0.08, 1.0),
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF00E5FF), Color(0xFF00FF88)],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text("0% (Overheated)", style: TextStyle(color: Colors.white38, fontSize: 8)),
                  Text("7.5% (Discipline Target)", style: TextStyle(color: Color(0xFF00E5FF), fontSize: 8, fontWeight: FontWeight.bold)),
                  Text("15% (Extreme Liquid)", style: TextStyle(color: Colors.white38, fontSize: 8)),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "≈ ₹${_currencyFormat.format(dryPowderCr)} Cr DRY POWDER READY TO BUY DIPS",
                  style: GoogleFonts.robotoMono(
                    color: const Color(0xFF00E5FF),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "When average cash is above 7.5%, marquee managers are exercising defensive discipline, awaiting valuation pullbacks before deploying fresh inflows.",
                style: TextStyle(color: Colors.white70, fontSize: 10.5, height: 1.3),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Section Title: Top 20 Funds Directory
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: const [
                Icon(Icons.account_balance_rounded,
                    color: Color(0xFF00E5FF), size: 16),
                SizedBox(width: 6),
                Text(
                  "TOP 20 ALPHA FUNDS DIRECTORY",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Category Filter
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip("ALL", "ALL (20)", _fundCategoryFilter == "ALL", () {
                setState(() => _fundCategoryFilter = "ALL");
              }),
              const SizedBox(width: 6),
              _buildFilterChip(
                  "Flexi Cap", "FLEXI CAP", _fundCategoryFilter == "Flexi Cap", () {
                setState(() => _fundCategoryFilter = "Flexi Cap");
              }),
              const SizedBox(width: 6),
              _buildFilterChip(
                  "Small Cap", "SMALL CAP", _fundCategoryFilter == "Small Cap", () {
                setState(() => _fundCategoryFilter = "Small Cap");
              }),
              const SizedBox(width: 6),
              _buildFilterChip(
                  "Mid Cap", "MID CAP", _fundCategoryFilter == "Mid Cap", () {
                setState(() => _fundCategoryFilter = "Mid Cap");
              }),
              const SizedBox(width: 6),
              _buildFilterChip(
                  "Large", "LARGE / MULTI", _fundCategoryFilter == "Large", () {
                setState(() => _fundCategoryFilter = "Large");
              }),
            ],
          ),
        ),
        const SizedBox(height: 12),

        ...filtered.map((fund) => _buildFundCard(fund)),
      ],
    );
  }

  Widget _buildFundCard(Map<String, dynamic> fund) {
    final name = fund['name'] ?? '';
    final category = fund['category'] ?? '';
    final manager = fund['fund_manager'] ?? '';
    final double aumCr = (fund['aum_cr'] as num?)?.toDouble() ?? 0.0;
    final double nav = (fund['nav'] as num?)?.toDouble() ?? 0.0;
    final double navChg = (fund['nav_change_pct'] as num?)?.toDouble() ?? 0.0;
    final double cagr1y = (fund['cagr_1y'] as num?)?.toDouble() ?? 0.0;
    final double cagr3y = (fund['cagr_3y'] as num?)?.toDouble() ?? 0.0;
    final double cagr5y = (fund['cagr_5y'] as num?)?.toDouble() ?? 0.0;
    final double cashPct = (fund['cash_holding_pct'] as num?)?.toDouble() ?? 0.0;
    final double downside =
        (fund['downside_capture_ratio'] as num?)?.toDouble() ?? 100.0;
    final holdings = (fund['top_10_holdings'] as List<dynamic>? ?? []);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1726),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E2B3E)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        iconColor: const Color(0xFF00E5FF),
        collapsedIconColor: Colors.white38,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    category,
                    style: const TextStyle(
                      color: Color(0xFF00E5FF),
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  "AUM: ₹${_currencyFormat.format(aumCr)} Cr",
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              name,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              "Manager: $manager",
              style: const TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildFundMiniPerf("NAV", "₹${nav.toStringAsFixed(2)}",
                  navChg >= 0 ? const Color(0xFF00FF88) : const Color(0xFFFF2A6D)),
              _buildFundMiniPerf("1Y CAGR", "+$cagr1y%", const Color(0xFF00FF88)),
              _buildFundMiniPerf("3Y CAGR", "+$cagr3y%", const Color(0xFF00E5FF)),
              _buildFundMiniPerf("5Y CAGR", "+$cagr5y%", const Color(0xFFFFB703)),
            ],
          ),
        ),
        children: [
          const Divider(color: Color(0xFF1E2B3E)),
          // Defensive Metrics Row
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF090D16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("CASH DRY POWDER",
                          style: TextStyle(color: Colors.white38, fontSize: 8.5)),
                      const SizedBox(height: 2),
                      Text(
                        "${cashPct.toStringAsFixed(1)}% (${cashPct > 10 ? 'High Reserve' : 'Deployed'})",
                        style: GoogleFonts.robotoMono(
                          color: cashPct > 10
                              ? const Color(0xFF00FF88)
                              : Colors.white70,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
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
                    color: const Color(0xFF090D16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("DOWNSIDE CAPTURE",
                          style: TextStyle(color: Colors.white38, fontSize: 8.5)),
                      const SizedBox(height: 2),
                      Text(
                        "${downside.toStringAsFixed(1)}% (Capital Shield)",
                        style: GoogleFonts.robotoMono(
                          color: downside < 70
                              ? const Color(0xFF00E5FF)
                              : Colors.white70,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Top Holdings
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "TOP 10 UNDERLYING STOCKS",
              style: TextStyle(
                color: Colors.white54,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 6),

          Wrap(
            spacing: 6,
            runSpacing: 5,
            children: holdings.map((h) {
              final s = h['symbol'] ?? '';
              final wt = (h['weight'] as num?)?.toDouble() ?? 0.0;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF141C2B),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: const Color(0xFF22324B)),
                ),
                child: Text(
                  "$s $wt%",
                  style: GoogleFonts.robotoMono(
                      color: Colors.white70, fontSize: 9.5),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),

          // AMFI Live API Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF090D16),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF1E2B3E)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.api_rounded,
                        color: Color(0xFF00E5FF), size: 14),
                    const SizedBox(width: 6),
                    Text(
                      "AMFI Scheme: ${fund['scheme_code'] ?? 'Official Registry'}",
                      style: GoogleFonts.robotoMono(
                        color: Colors.white70,
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FF88).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    "OPEN AMFI API",
                    style: TextStyle(
                      color: Color(0xFF00FF88),
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFundMiniPerf(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 8)),
        const SizedBox(height: 1),
        Text(value,
            style: GoogleFonts.robotoMono(
                color: color, fontSize: 10.5, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildFilterChip(
      String code, String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00E5FF).withOpacity(0.18)
              : const Color(0xFF0F1726),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? const Color(0xFF00E5FF) : const Color(0xFF1E2B3E),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: isSelected ? const Color(0xFF00E5FF) : Colors.white54,
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
