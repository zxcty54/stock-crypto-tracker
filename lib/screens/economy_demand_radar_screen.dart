import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'global_economy_radar_screen.dart';

class EconomyDemandRadarScreen extends StatefulWidget {
  const EconomyDemandRadarScreen({super.key});

  @override
  State<EconomyDemandRadarScreen> createState() => _EconomyDemandRadarScreenState();
}

class _EconomyDemandRadarScreenState extends State<EconomyDemandRadarScreen>
    with SingleTickerProviderStateMixin {
  static const List<String> dataUrls = [
    'https://raw.githubusercontent.com/zxcty54/stock-crypto-tracker/main/economy_demand_radar.json',
    'https://cdn.jsdelivr.net/gh/zxcty54/stock-crypto-tracker@main/economy_demand_radar.json',
    'https://fastly.jsdelivr.net/gh/zxcty54/stock-crypto-tracker@main/economy_demand_radar.json',
  ];

  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _payload;
  late TabController _tabController;

  static const Color bgDark = Color(0xFF090D16);
  static const Color surfaceCard = Color(0xFF131B2A);
  static const Color borderSubtle = Color(0xFF1E2B3E);
  static const Color accentCyan = Color(0xFF00E5FF);
  static const Color accentGreen = Color(0xFF00F5A0);
  static const Color accentAmber = Color(0xFFFFB300);
  static const Color accentRed = Color(0xFFFF5252);
  static const Color textMuted = Color(0xFF8896AB);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchRadarData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchRadarData({bool isRefresh = false}) async {
    if (isRefresh) HapticFeedback.lightImpact();
    setState(() => _isLoading = true);

    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // 1. Try Live Network CDNs first (Zero APK rebuild required)
    for (final baseUrl in dataUrls) {
      try {
        final uri = Uri.parse('$baseUrl?ts=$timestamp');
        final response = await http.get(
          uri,
          headers: {
            'Cache-Control': 'no-cache, no-store, must-revalidate',
            'Pragma': 'no-cache',
          },
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200 && response.body.isNotEmpty) {
          final decoded = jsonDecode(utf8.decode(response.bodyBytes));
          if (mounted) {
            setState(() {
              _payload = decoded;
              _isLoading = false;
              _errorMessage = null;
            });
            return;
          }
        }
      } catch (_) {
        // Try next CDN
        continue;
      }
    }

    // 2. Offline / Emergency Fallback (if airplane mode or all CDNs unreachable)
    try {
      final localJson = await rootBundle.loadString('assets/data/economy_demand_radar.json');
      final decoded = jsonDecode(localJson);
      if (mounted) {
        setState(() {
          _payload = decoded;
          _isLoading = false;
          _errorMessage = null;
        });
        return;
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not load telemetry radar: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C121E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "INDIAN ECONOMY DEMAND RADAR",
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 0.8,
              ),
            ),
            const Text(
              "FASTag Toll • Port Cargo • Diesel • 8-Core Physical Pulse",
              style: TextStyle(color: textMuted, fontSize: 10),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.public_rounded, color: Color(0xFF00E5FF), size: 21),
            tooltip: "Switch to Global Economy Radar",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const GlobalEconomyRadarScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: accentCyan, size: 20),
            tooltip: "Live Refresh",
            onPressed: () => _fetchRadarData(isRefresh: true),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: accentCyan,
          labelColor: accentCyan,
          unselectedLabelColor: textMuted,
          labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: "🎯 SECTOR DEMAND & STOCKS"),
            Tab(text: "📊 PHYSICAL TELEMETRY GAUGES"),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: accentCyan));
    }

    if (_errorMessage != null || _payload == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_rounded, color: accentRed, size: 48),
              const SizedBox(height: 12),
              Text(
                _errorMessage ?? "Unable to load telemetry data.",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E2B3E)),
                onPressed: () => _fetchRadarData(isRefresh: true),
                icon: const Icon(Icons.refresh, size: 16, color: accentCyan),
                label: const Text("Retry Connection", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    final headline = _payload!['economy_headline'] ?? {};
    final sectors = (_payload!['sector_demand_matrix'] as List?) ?? [];
    final modules = _payload!['telemetry_modules'] ?? {};

    return TabBarView(
      controller: _tabController,
      children: [
        // Tab 1: Sector Demand Trajectories & Beneficiary Stocks
        RefreshIndicator(
          color: accentCyan,
          backgroundColor: const Color(0xFF0C121E),
          onRefresh: () => _fetchRadarData(isRefresh: true),
          child: ListView(
            padding: const EdgeInsets.all(14),
            children: [
              _buildHeadlineBanner(headline),
              const SizedBox(height: 12),
              _buildEarningsAlphaExplainer(),
              const SizedBox(height: 16),
              Text(
                "ACTIONABLE SECTOR DEMAND SIGNALS (${sectors.length})",
                style: GoogleFonts.plusJakartaSans(
                  color: accentCyan,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 10),
              ...sectors.map((s) => _buildSectorDemandCard(s)),
              const SizedBox(height: 10),
              _buildSebiDisclaimerCard(),
            ],
          ),
        ),

        // Tab 2: Physical Telemetry Gauges (Toll, Ports, PPAC, 8-Core)
        RefreshIndicator(
          color: accentCyan,
          backgroundColor: const Color(0xFF0C121E),
          onRefresh: () => _fetchRadarData(isRefresh: true),
          child: ListView(
            padding: const EdgeInsets.all(14),
            children: [
              _buildEightCoreModule(modules['dpiit_eight_core']),
              const SizedBox(height: 14),
              _buildPortsModule(modules['ipa_major_ports']),
              const SizedBox(height: 14),
              _buildFuelModule(modules['ppac_fuel_freight']),
              const SizedBox(height: 14),
              _buildFastagModule(modules['netc_fastag_toll']),
              const SizedBox(height: 10),
              _buildSebiDisclaimerCard(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeadlineBanner(Map<String, dynamic> h) {
    final double coreGrowth = (h['core_infra_growth_pct'] as num?)?.toDouble() ?? 7.9;
    final double portGrowth = (h['port_cargo_growth_pct'] as num?)?.toDouble() ?? 10.2;
    final double dieselGrowth = (h['diesel_freight_growth_pct'] as num?)?.toDouble() ?? 5.6;
    final double tollGrowth = (h['fastag_toll_growth_pct'] as num?)?.toDouble() ?? 8.5;
    final String verdict = h['verdict'] ?? 'BROAD-BASED PHYSICAL EXPANSION';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF142038), Color(0xFF0C1424)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentCyan.withOpacity(0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: accentCyan.withOpacity(0.08),
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
                      color: accentCyan.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.bar_chart_rounded, color: accentCyan, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "CORE CONCLUSION (GROUND PULSE)",
                    style: GoogleFonts.plusJakartaSans(
                      color: accentCyan,
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
                  color: accentGreen.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: accentGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      verdict,
                      style: const TextStyle(
                        color: accentGreen,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Big Bold Conclusion
          Text(
            h['headline_summary'] ?? "India's Ground Economy Expanding at +8.0% YoY Volume Pace — Zero Industrial Slowdown",
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),

          // 📊 Vertical 4-Pillars Column Bar Chart
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
                    Text("PHYSICAL INFRASTRUCTURE & FREIGHT THROUGHPUT (YoY GROWTH %)",
                        style: TextStyle(color: Colors.white38, fontSize: 8.5, fontWeight: FontWeight.bold)),
                    Text("Zero Axis: 0%", style: TextStyle(color: Colors.white38, fontSize: 8.5)),
                  ],
                ),
                const SizedBox(height: 12),

                // 4 Column Bars
                SizedBox(
                  height: 100,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildPillarBar(
                        label: "8-CORE INFRA",
                        valStr: "+${coreGrowth.toStringAsFixed(1)}%",
                        heightRatio: (coreGrowth / 12.0).clamp(0.2, 1.0),
                        color: accentCyan,
                      ),
                      _buildPillarBar(
                        label: "PORT CARGO",
                        valStr: "+${portGrowth.toStringAsFixed(1)}%",
                        heightRatio: (portGrowth / 12.0).clamp(0.2, 1.0),
                        color: accentGreen,
                      ),
                      _buildPillarBar(
                        label: "FASTAG TOLL",
                        valStr: "+${tollGrowth.toStringAsFixed(1)}%",
                        heightRatio: (tollGrowth / 12.0).clamp(0.2, 1.0),
                        color: const Color(0xFF00E5FF),
                      ),
                      _buildPillarBar(
                        label: "DIESEL FREIGHT",
                        valStr: "+${dieselGrowth.toStringAsFixed(1)}%",
                        heightRatio: (dieselGrowth / 12.0).clamp(0.2, 1.0),
                        color: accentAmber,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Container(height: 1.5, color: Colors.white24),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Physical Economy Temperature Bar
          Builder(builder: (context) {
            final int momentumScore = (h['momentum_score'] as num?)?.toInt() ?? 84;
            final String momentumLabel = h['momentum_label'] ?? 'HIGH INDUSTRIAL PULSE';
            return Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("PHYSICAL MOMENTUM THERMOMETER",
                        style: TextStyle(color: Colors.white54, fontSize: 8.5, fontWeight: FontWeight.bold)),
                    Text("$momentumScore/100 ($momentumLabel)",
                        style: const TextStyle(color: accentGreen, fontSize: 8.5, fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    height: 7,
                    color: const Color(0xFF090D16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: (momentumScore / 100.0).clamp(0.05, 1.0),
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [accentAmber, accentCyan, accentGreen],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPillarBar({
    required String label,
    required String valStr,
    required double heightRatio,
    required Color color,
  }) {
    final double barHeight = (heightRatio * 60.0).clamp(16.0, 60.0);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.arrow_upward_rounded, color: accentGreen, size: 9),
            Text(
              valStr,
              style: GoogleFonts.robotoMono(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          width: 44,
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

  Widget _buildEarningsAlphaExplainer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.school_rounded, size: 14, color: Color(0xFF38BDF8)),
              const SizedBox(width: 6),
              Text(
                "WHY PHYSICAL TELEMETRY LEADS EARNINGS (45-DAY EDGE)",
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF38BDF8),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF090D16),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text("⏱️ 45-Day Advance Lead",
                          style: TextStyle(color: accentCyan, fontSize: 9.5, fontWeight: FontWeight.bold)),
                      SizedBox(height: 2),
                      Text("Govt telemetry reports monthly, far ahead of delayed quarterly results.",
                          style: TextStyle(color: Colors.white70, fontSize: 8.5, height: 1.25)),
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
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text("⚡ Operating Leverage",
                          style: TextStyle(color: accentGreen, fontSize: 9.5, fontWeight: FontWeight.bold)),
                      SizedBox(height: 2),
                      Text("High plant capacity utilization directly expands dispatches & margins.",
                          style: TextStyle(color: Colors.white70, fontSize: 8.5, height: 1.25)),
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

  Widget _buildSebiDisclaimerCard() {
    return Container(
      margin: const EdgeInsets.only(top: 14, bottom: 20),
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
            "2. NO BUY / SELL CALLS OR TIPS: Nothing on this app constitutes investment advice, portfolio management, stock tips, buy/sell recommendations, price targets, or financial guarantees.\n\n"
            "3. STATUTORY DATA AGGREGATION: All physical volume metrics are aggregated from official Government of India releases (DPIIT, PPAC, IPA, NPCI) solely for academic and educational macro-tracking purposes.\n\n"
            "4. INDEPENDENT ADVICE: Equity investments are subject to market risks. Users must consult a SEBI registered investment advisor before making any financial commitment.",
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

  Widget _buildSectorDemandCard(Map<String, dynamic> s) {
    final stocks = (s['beneficiary_equities'] as List?) ?? [];
    final badge = s['momentum_badge'] ?? '🟢 EXPANDING';
    final isSoft = badge.contains('SOFTENING') || badge.contains('CONTRACTION');
    final trendOutlook = s['macro_trend_outlook'] ?? s['earnings_outlook'];
    final correlationNote = s['macro_correlation_note'] ?? s['earnings_prediction_thesis'];
    final keyMetric = s['fundamental_metric_to_track'] ?? s['key_metric_to_watch'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSoft ? accentRed.withOpacity(0.3) : borderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  s['sector'] ?? '',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isSoft ? accentRed.withOpacity(0.15) : accentGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    color: isSoft ? accentRed : accentGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          // 📊 Demand Temperature Meter (Visual Bar)
          const SizedBox(height: 6),
          Row(
            children: [
              const Text(
                "DEMAND INTENSITY: ",
                style: TextStyle(color: textMuted, fontSize: 9, fontWeight: FontWeight.bold),
              ),
              Expanded(
                child: Row(
                  children: List.generate(5, (index) {
                    final int activeSegments = isSoft ? 2 : (badge.contains('RAPID') ? 5 : 4);
                    final bool isActive = index < activeSegments;
                    return Expanded(
                      child: Container(
                        height: 5,
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        decoration: BoxDecoration(
                          color: isActive
                              ? (isSoft ? accentRed : accentGreen)
                              : const Color(0xFF1B2433),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                isSoft ? "SOFTENING" : (badge.contains('RAPID') ? "PEAK (5/5)" : "HIGH (4/5)"),
                style: TextStyle(
                  color: isSoft ? accentRed : accentGreen,
                  fontSize: 8.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            s['primary_indicators'] ?? '',
            style: const TextStyle(color: accentCyan, fontSize: 11, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            s['economic_rationale'] ?? '',
            style: const TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.35),
          ),
          if (trendOutlook != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSoft
                    ? accentRed.withOpacity(0.08)
                    : const Color(0xFF0A1F1C),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSoft
                      ? accentRed.withOpacity(0.3)
                      : accentGreen.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isSoft
                            ? Icons.warning_amber_rounded
                            : Icons.insights_rounded,
                        size: 14,
                        color: isSoft ? accentRed : accentGreen,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "MACRO ACTIVITY TREND: $trendOutlook",
                          style: TextStyle(
                            color: isSoft ? accentRed : accentGreen,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (correlationNote != null) ...[
                    const SizedBox(height: 5),
                    Text(
                      correlationNote,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ],
                  if (keyMetric != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "🎯 Fundamental Driver: ",
                          style: TextStyle(
                            color: accentAmber,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            keyMetric,
                            style: const TextStyle(
                              color: Color(0xFFE2E8F0),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          const Divider(color: Color(0xFF1B2433), height: 1),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                "SECTOR REPRESENTATIVE PEERS (EDUCATIONAL STUDY):",
                style: GoogleFonts.plusJakartaSans(
                  color: textMuted,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          const Text(
            "Tickers listed below are representative industry case studies for macro sensitivity tracking, NOT buy/sell recommendations.",
            style: TextStyle(color: Colors.white38, fontSize: 9, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: stocks.map((st) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C1320),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF1E2D44)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      st['symbol'] ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "• ${st['name'] ?? ''}",
                      style: const TextStyle(color: textMuted, fontSize: 10),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // --- TELEMETRY GAUGES WIDGETS ---

  Widget _buildEightCoreModule(Map<String, dynamic>? c) {
    if (c == null) return const SizedBox.shrink();
    final comps = (c['components'] as Map<String, dynamic>?) ?? {};
    final history = (c['historical_13m_growth'] as List?) ?? [];

    return _telemetryCard(
      title: "1. 8-CORE INFRASTRUCTURE PRODUCTION",
      period: c['period'] ?? '',
      badgeText: "+${c['overall_yoy_growth_pct']}% YoY",
      badgeColor: accentGreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "SECTORAL INDUSTRIAL THROUGHPUT & PRODUCTION BARS (YoY %)",
            style: TextStyle(color: textMuted, fontSize: 9.5, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          // Horizontal Proportional Bar Chart for 8 Core Components
          ...comps.entries.map((e) {
            final val = e.value as Map<String, dynamic>;
            final yoy = (val['yoy_pct'] as num?)?.toDouble() ?? 0.0;
            final wt = (val['weight'] as num?)?.toDouble() ?? 0.0;
            final status = val['status'] ?? '';
            final isPos = yoy >= 0;
            final Color barColor = isPos ? accentGreen : accentRed;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0C1320),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderSubtle),
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
                            e.key,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E2B3E),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              "Wt: ${wt.toStringAsFixed(1)}%",
                              style: const TextStyle(color: textMuted, fontSize: 8),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: barColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              status.toString().replaceAll('_', ' '),
                              style: TextStyle(
                                color: barColor,
                                fontSize: 7.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "${isPos ? '+' : ''}${yoy.toStringAsFixed(1)}%",
                            style: GoogleFonts.robotoMono(
                              color: barColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),

                  // Proportional Horizontal Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: Container(
                      height: 6,
                      color: const Color(0xFF080D17),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: (yoy.abs() / 20.0).clamp(0.06, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isPos
                                    ? [accentCyan, accentGreen]
                                    : [accentRed, const Color(0xFFFF1744)],
                              ),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          // 13-Month Trend Sparkline Bar Chart
          if (history.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              "13-MONTH OVERALL CORE INDEX HISTOGRAM (ACCELERATION PULSE)",
              style: TextStyle(color: textMuted, fontSize: 9.5, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF080D17),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderSubtle),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: history.map((m) {
                    final double idxVal =
                        (m['Overall Index'] as num?)?.toDouble() ?? 0.0;
                    final String mName = (m['month'] ?? '').toString().split('-').first;
                    final bool isPeak = idxVal >= 7.0;

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            "${idxVal.toStringAsFixed(1)}%",
                            style: GoogleFonts.robotoMono(
                              color: isPeak ? accentGreen : Colors.white70,
                              fontSize: 7.5,
                              fontWeight: isPeak ? FontWeight.w900 : FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            width: 14,
                            height: (idxVal / 8.0 * 36.0).clamp(6.0, 40.0),
                            decoration: BoxDecoration(
                              color: isPeak ? accentGreen : accentCyan.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            mName,
                            style: const TextStyle(color: textMuted, fontSize: 7.5),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPortsModule(Map<String, dynamic>? p) {
    if (p == null) return const SizedBox.shrink();
    final comms = (p['major_commodities'] as Map<String, dynamic>?) ?? {};

    return _telemetryCard(
      title: "2. MAJOR PORTS EXIM TRADE (IPA)",
      period: p['period'] ?? '',
      badgeText: "${p['total_cargo_current_mmt']} MMT (+${p['cargo_yoy_growth_pct']}%)",
      badgeColor: accentCyan,
      child: Column(
        children: comms.entries.map((e) {
          final val = e.value as Map<String, dynamic>;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(e.key, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                Text(
                  "${val['volume_mmt']} MMT (${val['share_pct']}%)",
                  style: const TextStyle(color: accentCyan, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFuelModule(Map<String, dynamic>? f) {
    if (f == null) return const SizedBox.shrink();
    final fuels = (f['fuels'] as Map<String, dynamic>?) ?? {};

    return _telemetryCard(
      title: "3. FUEL CONSUMPTION & FREIGHT PULSE (PPAC)",
      period: f['period'] ?? '',
      badgeText: "${f['total_consumption_mmt']} MMT (+${f['total_consumption_yoy_pct']}%)",
      badgeColor: accentAmber,
      child: Column(
        children: fuels.entries.map((e) {
          final val = e.value as Map<String, dynamic>;
          final yoy = (val['yoy_growth_pct'] as num?)?.toDouble() ?? 0.0;
          final isPos = yoy >= 0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.key, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                    Text(val['metric_label'] ?? '', style: const TextStyle(color: textMuted, fontSize: 10)),
                  ],
                ),
                Text(
                  "${isPos ? '+' : ''}$yoy%",
                  style: TextStyle(
                    color: isPos ? accentGreen : accentRed,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFastagModule(Map<String, dynamic>? t) {
    if (t == null) return const SizedBox.shrink();
    final history = (t['rolling_12m_history'] as List?) ??
        (t['rolling_12m_series'] as List?) ??
        [];

    return _telemetryCard(
      title: "4. HIGHWAY FREIGHT & TOLL (NETC FASTAG)",
      period: t['period'] ?? t['latest_month'] ?? '',
      badgeText: "₹${t['monthly_collection_inr_cr'] ?? t['latest_toll_cr']} Cr (+${t['yoy_growth_pct']}%)",
      badgeColor: accentGreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Monthly Freight Volume:", style: TextStyle(color: textMuted, fontSize: 11)),
              Text("${t['monthly_vehicle_count_mn'] ?? t['latest_volume_mn']} Mn Vehicles",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 10),

          // 📊 12-Month Toll Revenue Bar Chart Histogram
          if (history.isNotEmpty) ...[
            const Text(
              "12-MONTH HIGHWAY TOLL REVENUE BAR CHART (₹ CRORE)",
              style: TextStyle(color: textMuted, fontSize: 9.5, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF080D17),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderSubtle),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: history.map((h) {
                    final double toll = (h['toll_cr'] as num?)?.toDouble() ?? 5800.0;
                    final String mName = (h['month'] ?? '').toString();
                    final bool isLatest = mName.contains('Sep');

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            "₹${(toll / 1000).toStringAsFixed(1)}k",
                            style: GoogleFonts.robotoMono(
                              color: isLatest ? accentGreen : Colors.white70,
                              fontSize: 7.5,
                              fontWeight: isLatest ? FontWeight.w900 : FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Container(
                            width: 16,
                            height: ((toll - 5000.0) / 1500.0 * 42.0).clamp(8.0, 45.0),
                            decoration: BoxDecoration(
                              color: isLatest ? accentGreen : const Color(0xFF2979FF),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            mName.split('-').first,
                            style: const TextStyle(color: textMuted, fontSize: 8),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _telemetryCard({
    required String title,
    required String period,
    required String badgeText,
    required Color badgeColor,
    required Widget child,
  }) {
    return Container(
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
                    Text(title, style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                    Text(period, style: const TextStyle(color: textMuted, fontSize: 10)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 10.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: Color(0xFF1B2433), height: 1),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
