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
    _tabController = TabController(length: 4, vsync: this);
    _loadDataset();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
            _metadata = Map<String, dynamic>.from(data['metadata'] ?? {});
            _topFunds =
                List<Map<String, dynamic>>.from(data['top_20_funds'] ?? []);
            _infiltrations = List<Map<String, dynamic>>.from(
                data['smart_money_infiltrations'] ?? []);
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
                _metadata = Map<String, dynamic>.from(parsed['metadata'] ?? {});
                _topFunds = List<Map<String, dynamic>>.from(
                    parsed['top_20_funds'] ?? []);
                _infiltrations = List<Map<String, dynamic>>.from(
                    parsed['smart_money_infiltrations'] ?? []);
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
        // Try next fallback CDN
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

    // Normalized overlap score based on top holdings
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
            Tab(text: "🕵️ INFILTRATIONS"),
            Tab(text: "⚖️ OVERLAP SCANNER"),
            Tab(text: "🏛️ TOP 20 FUNDS"),
            Tab(text: "⏱️ CASH BAROMETER"),
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
                  child: _buildTopFundsTab(),
                ),
                RefreshIndicator(
                  color: const Color(0xFF00E5FF),
                  backgroundColor: const Color(0xFF0F1726),
                  onRefresh: () => _loadDataset(isRefresh: true),
                  child: _buildCashBarometerTab(),
                ),
              ],
            ),
    );
  }

  // =============================================================
  // TAB 1: SMART MONEY STOCK INFILTRATIONS
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
              _buildFilterChip("ALL", "ALL (${_infiltrations.length})", _infiltrationFilter == "ALL", () {
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
                () => setState(() => _infiltrationFilter = "AGGRESSIVE_ACCUMULATION"),
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
    final double volumeCr = (item['estimated_buying_cr'] as num?)?.toDouble() ?? 0.0;
    final double changePct = (item['avg_holding_increase_pct'] as num?)?.toDouble() ?? 0.0;
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
      tagLabel = "SILENT EXIT / DUMPING";
      tagIcon = Icons.warning_amber_rounded;
    }

    final bool isBuy = volumeCr >= 0;

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
          // Header: Symbol & Tag
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
                    ),
                    child: Text(
                      sym,
                      style: GoogleFonts.robotoMono(
                        color: const Color(0xFF00E5FF),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    sector,
                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: tagColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Row(
                  children: [
                    Icon(tagIcon, color: tagColor, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      tagLabel,
                      style: GoogleFonts.plusJakartaSans(
                        color: tagColor,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Company Name & Est Volume
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                "${isBuy ? '+' : ''}₹${volumeCr.abs().toStringAsFixed(0)} Cr",
                style: GoogleFonts.robotoMono(
                  color: isBuy ? const Color(0xFF00FF88) : const Color(0xFFFF2A6D),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Participating Funds Pills
          Wrap(
            spacing: 5,
            runSpacing: 4,
            children: funds.map((f) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF151F32),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF22324B)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.account_balance_rounded,
                        color: Colors.white38, size: 10),
                    const SizedBox(width: 4),
                    Text(
                      f.toString(),
                      style: const TextStyle(color: Colors.white70, fontSize: 9.5),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),

          // Thesis Box
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF090D16),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.insights_rounded,
                    color: Color(0xFF00E5FF), size: 13),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    thesis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10.5,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Copy Action
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: "$sym: $name"));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("$sym copied to clipboard"),
                    backgroundColor: const Color(0xFF00E5FF),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.copy_rounded, color: Colors.white38, size: 12),
                    SizedBox(width: 4),
                    Text("Copy Symbol",
                        style: TextStyle(color: Colors.white54, fontSize: 10)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =============================================================
  // TAB 2: PORTFOLIO OVERLAP & FEE LEAKAGE SCANNER
  // =============================================================
  Widget _buildOverlapScannerTab() {
    if (_topFunds.length < 2) {
      return const Center(child: Text("Need at least 2 funds for comparison"));
    }

    final fundA = _topFunds[_selectedFundAIdx];
    final fundB = _topFunds[_selectedFundBIdx];
    final overlapData = _computeOverlap(fundA, fundB);
    final double overlapPct = overlapData['overlap_pct'] as double;
    final commonStocks = (overlapData['common_stocks'] as List<dynamic>? ?? []);

    Color scoreColor = const Color(0xFF00FF88);
    String verdict = "EXCELLENT DIVERSIFICATION";
    if (overlapPct >= 50) {
      scoreColor = const Color(0xFFFF2A6D);
      verdict = "SEVERE OVERLAP (FEE LEAKAGE DETECTED)";
    } else if (overlapPct >= 30) {
      scoreColor = const Color(0xFFFFB703);
      verdict = "MODERATE OVERLAP";
    }

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // Headline
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
                  style: GoogleFonts.plusJakartaSans(
                    color: scoreColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Sub statistics
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildOverlapMiniStat("Common Stocks", "${commonStocks.length}"),
                  _buildOverlapMiniStat("Fund A Unique", "${overlapData['fund_a_unique']}"),
                  _buildOverlapMiniStat("Fund B Unique", "${overlapData['fund_b_unique']}"),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Common Holdings List
        Row(
          children: const [
            Icon(Icons.layers_rounded, color: Color(0xFF00E5FF), size: 16),
            SizedBox(width: 6),
            Text(
              "COMMON UNDERLYING STOCKS",
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
                "Zero common holdings in top allocations! Both funds have distinct alpha portfolios.",
                style: TextStyle(color: Color(0xFF00FF88), fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          ...commonStocks.map((c) {
            final sym = c['symbol'] ?? '';
            final wtA = (c['weight_a'] as num?)?.toDouble() ?? 0.0;
            final wtB = (c['weight_b'] as num?)?.toDouble() ?? 0.0;

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
                        "Fund A: ${wtA.toStringAsFixed(1)}%",
                        style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 10),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        "Fund B: ${wtB.toStringAsFixed(1)}%",
                        style: const TextStyle(color: Color(0xFFFFB703), fontSize: 10),
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
      String label, String fundName, Function(int) onSelect, int currentIdx) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1726),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1E2B3E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: currentIdx,
              isExpanded: true,
              dropdownColor: const Color(0xFF101726),
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
  // TAB 3: TOP 20 MARQUEE FUNDS
  // =============================================================
  Widget _buildTopFundsTab() {
    List<Map<String, dynamic>> filtered = _topFunds;
    if (_fundCategoryFilter != "ALL") {
      filtered = filtered
          .where((f) => (f['category'] ?? '').toString().contains(_fundCategoryFilter))
          .toList();
    }

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // Category Filter
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip("ALL", "ALL (20)", _fundCategoryFilter == "ALL", () {
                setState(() => _fundCategoryFilter = "ALL");
              }),
              const SizedBox(width: 6),
              _buildFilterChip("Flexi Cap", "FLEXI CAP", _fundCategoryFilter == "Flexi Cap", () {
                setState(() => _fundCategoryFilter = "Flexi Cap");
              }),
              const SizedBox(width: 6),
              _buildFilterChip("Small Cap", "SMALL CAP", _fundCategoryFilter == "Small Cap", () {
                setState(() => _fundCategoryFilter = "Small Cap");
              }),
              const SizedBox(width: 6),
              _buildFilterChip("Mid Cap", "MID CAP", _fundCategoryFilter == "Mid Cap", () {
                setState(() => _fundCategoryFilter = "Mid Cap");
              }),
              const SizedBox(width: 6),
              _buildFilterChip("Large", "LARGE / MULTI", _fundCategoryFilter == "Large", () {
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
    final double downside = (fund['downside_capture_ratio'] as num?)?.toDouble() ?? 100.0;
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
              _buildFundMiniPerf("NAV", "₹${nav.toStringAsFixed(2)}", navChg >= 0 ? const Color(0xFF00FF88) : const Color(0xFFFF2A6D)),
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
                          color: cashPct > 10 ? const Color(0xFF00FF88) : Colors.white70,
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
                          color: downside < 70 ? const Color(0xFF00E5FF) : Colors.white70,
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
                  style: GoogleFonts.robotoMono(color: Colors.white70, fontSize: 9.5),
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

  // =============================================================
  // TAB 4: INSTITUTIONAL CASH BAROMETER
  // =============================================================
  Widget _buildCashBarometerTab() {
    final double avgCash =
        (_metadata['average_cash_level_pct'] as num?)?.toDouble() ?? 7.8;
    final double totalAum =
        (_metadata['total_aum_tracked_cr'] as num?)?.toDouble() ?? 710600.0;
    final double dryPowderCr = (totalAum * (avgCash / 100.0));

    // Sort funds by cash % descending
    List<Map<String, dynamic>> cashRanked = List.from(_topFunds);
    cashRanked.sort((a, b) {
      final ca = (a['cash_holding_pct'] as num?)?.toDouble() ?? 0.0;
      final cb = (b['cash_holding_pct'] as num?)?.toDouble() ?? 0.0;
      return cb.compareTo(ca);
    });

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
              const SizedBox(height: 12),
              const Text(
                "When average cash is above 7.5%, marquee managers are exercising defensive discipline, awaiting valuation pullbacks before deploying fresh inflows.",
                style: TextStyle(color: Colors.white70, fontSize: 10.5, height: 1.3),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Cash Ranking Leaderboard
        Row(
          children: const [
            Icon(Icons.savings_rounded, color: Color(0xFF00E5FF), size: 16),
            SizedBox(width: 6),
            Text(
              "DRY POWDER CASH RANKINGS (TOP 20)",
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

        ...cashRanked.map((f) {
          final sName = f['short_name'] ?? f['name'];
          final double cPct = (f['cash_holding_pct'] as num?)?.toDouble() ?? 0.0;
          final double fAum = (f['aum_cr'] as num?)?.toDouble() ?? 0.0;
          final double cashCr = fAum * (cPct / 100.0);

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
                Expanded(
                  child: Text(
                    sName,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Row(
                  children: [
                    Text(
                      "₹${cashCr.toStringAsFixed(0)} Cr",
                      style: const TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: cPct > 10
                            ? const Color(0xFF00FF88).withOpacity(0.15)
                            : const Color(0xFF1E2B3E),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        "${cPct.toStringAsFixed(1)}%",
                        style: GoogleFonts.robotoMono(
                          color: cPct > 10 ? const Color(0xFF00FF88) : Colors.white70,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
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
